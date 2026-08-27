/// The app-scoped audio controller — the presentation audio layer's one
/// owner (AUDIO_PRESENTATION_01).
///
/// ## What this is, and deliberately is not
///
/// Three conceptual buses: MUSIC (active — one region track at a time),
/// SFX (active — one accepted cue per profession), and AMBIENCE (the volume
/// field and the architecture exist; no ambience content ships yet). It is
/// **presentation only**, all the way down:
///
/// - It reads the current location as a string and maps it to a track
///   (`AudioCues`). It never reads domain state, never mutates it, and is
///   reachable from nothing in `stride_core`.
/// - Cues fire when a visible working animation crosses its strike frame —
///   `AmbientStage.onActivityBeat` — so sound follows what the player
///   *watches*, never activity duration, step consumption, or a background
///   queue reconciling. Leaving the screen unmounts the loop; the beats stop
///   with it, and the engine's arithmetic never knows.
/// - Losing every field here loses volume preferences and nothing else.
///
/// ## Single ownership, no widget players
///
/// Exactly one instance lives beside `SessionController` in the app root.
/// Widgets reach it through `AudioScope` and call [playSkillCue]; none of
/// them constructs a player, so a rebuild storm cannot duplicate one — the
/// defect class the integration brief names is unrepresentable rather than
/// avoided.
///
/// ## Timers
///
/// The crossfade and the settings-save debounce run on **one-shot** timers
/// (chained for the fade steps). `Timer.periodic` is a background-execution
/// primitive this repository forbids in `lib/` outright
/// (`s01a_vertical_slice_test.dart` §14), and nothing here needs it.
library;

import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import 'audio_cues.dart';
import 'audio_output.dart';
import 'audio_settings.dart';
import 'audio_settings_store.dart';

/// Starts a one-shot timer. Production is `Timer(duration, onFire)`; tests
/// substitute a fake that fires on demand — the same seam shape as
/// `ActivityTiming`, kept separate because audio must not import UI state.
typedef AudioTimerFactory =
    Timer Function(Duration duration, void Function() onFire);

/// How the region crossfade moves: [steps] volume writes across [total].
/// Stepped rather than curved because the platform call is a volume set, not
/// an animation — nine writes over ~1.1 s reads as a fade on a phone speaker,
/// and the step count is small enough to cost nothing.
const int _fadeSteps = 9;
const Duration _fadeTotal = Duration(milliseconds: 1080);

/// How long a settings change waits before the file write, so a slider drag
/// is one write, not sixty.
const Duration _saveDebounce = Duration(milliseconds: 400);

class AudioController extends ChangeNotifier with WidgetsBindingObserver {
  AudioController({
    required this._output,
    required this._settings,
    this._store,
    AudioTimerFactory? timerFactory,
    int Function()? nowMillis,
  }) : _timer = timerFactory ?? _realTimer,
       _nowMillis = nowMillis ?? _monotonicMillis {
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
  }

  /// The production entry: opens the settings store, loads what the player
  /// last chose, and initialises the platform output. Called once, in
  /// `main`, before `runApp` — the file is a few hundred bytes and the read
  /// keeps the first frame's settings truthful, the same reasoning the
  /// session gets.
  static Future<AudioController> start({
    AudioOutput? output,
    AudioSettingsStore? store,
  }) async {
    final AudioOutput out = output ?? AudioplayersOutput();
    final AudioSettingsStore st = store ?? await AudioSettingsStore.open();
    final AudioSettings settings = await st.load();
    await out.init();
    return AudioController(output: out, store: st, settings: settings);
  }

  static Timer _realTimer(Duration duration, void Function() onFire) =>
      Timer(duration, onFire);

  /// Monotonic, not wall-clock: cue spacing is a fact about playback, and a
  /// wall-clock jump must not silence a minute of strikes. (`DateTime.now`
  /// also remains forbidden UI-side — Q-UI-9 — and this layer keeps the same
  /// discipline.)
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static int _monotonicMillis() => _stopwatch.elapsedMilliseconds;

  final AudioOutput _output;

  /// Null means no persistence — the widget-test fallback `StrideApp`
  /// constructs when it is given no controller. The app always has one.
  final AudioSettingsStore? _store;
  final AudioTimerFactory _timer;
  final int Function() _nowMillis;

  AudioSettings _settings;

  /// The current preferences, for the settings block to render.
  AudioSettings get settings => _settings;

  // -- MUSIC bus --------------------------------------------------------------

  /// The asset ID the music bus is assigned, playing or not (audio disabled,
  /// app backgrounded). Null is deliberate silence.
  String? _musicAssetId;

  /// The one live channel, and the one on its way out. Never more than these
  /// two exist, and the fade timer is the only thing that touches the dying
  /// one.
  MusicChannel? _music;
  MusicChannel? _fadingOut;

  /// Increments on every region change; an async start that comes back to
  /// find a newer epoch disposes itself instead of installing — the guard
  /// that makes rapid travel taps end with exactly one track.
  int _musicEpoch = 0;

  final Map<MusicChannel, Timer> _fades = <MusicChannel, Timer>{};
  Timer? _saveTimer;
  bool _disposed = false;

  /// What the music bus is assigned right now — read by tests and available
  /// to a debug overlay; the UI itself has no reason to ask.
  String? get currentMusicAssetId => _musicAssetId;

  /// Points the music bus at [locationId]'s track (`AudioCues.regionMusic`).
  ///
  /// Same assignment → **nothing happens.** That single early return is the
  /// acceptance line "same-region navigation does not restart music": tab
  /// changes, screen pushes and combat all re-announce the same location,
  /// and all of them land here and leave.
  ///
  /// A new assignment crossfades: the playing track fades to silence and is
  /// disposed; the new one starts at zero and fades up to the music volume.
  Future<void> setRegion(String? locationId) async {
    if (_disposed) return;
    final String? assetId = AudioCues.musicForRegion(locationId);
    if (assetId == _musicAssetId) return;
    _musicAssetId = assetId;
    final int epoch = ++_musicEpoch;

    _retireCurrentMusic();
    if (assetId == null || !_settings.enabled) return;

    final MusicChannel channel = await _output.startMusic(
      AudioCues.files[assetId]!,
      volume: 0,
    );
    if (_disposed || epoch != _musicEpoch) {
      // A newer assignment landed while this start was in flight. This
      // channel lost; it never becomes audible.
      await channel.dispose();
      return;
    }
    _music = channel;
    if (_halted) {
      // Assigned while backgrounded: hold silently; the resume plays it.
      await channel.pause();
      return;
    }
    _animateVolume(channel, from: 0, to: _settings.musicVolume);
  }

  /// Moves the live channel into the fade-out slot and starts its descent.
  /// Anything already fading is disposed on the spot — two dying tracks
  /// under a new one is a mush no crossfade needs.
  void _retireCurrentMusic() {
    final MusicChannel? dying = _fadingOut;
    if (dying != null) {
      _cancelFade(dying);
      _fadingOut = null;
      unawaited(dying.dispose());
    }
    final MusicChannel? current = _music;
    if (current == null) return;
    _music = null;
    _cancelFade(current);
    if (_halted || !_settings.enabled) {
      // Inaudible either way; a fade would be theatre for nobody.
      unawaited(current.dispose());
      return;
    }
    _fadingOut = current;
    _animateVolume(
      current,
      from: _settings.musicVolume,
      to: 0,
      onDone: () {
        if (_fadingOut == current) _fadingOut = null;
        unawaited(current.dispose());
      },
    );
  }

  /// Steps [channel]'s volume from [from] to [to] on chained one-shot
  /// timers. The first step is immediate, so a fade-in becomes audible on
  /// the call rather than a step later.
  void _animateVolume(
    MusicChannel channel, {
    required double from,
    required double to,
    void Function()? onDone,
  }) {
    _cancelFade(channel);
    int step = 0;
    void advance() {
      step += 1;
      final double t = step / _fadeSteps;
      unawaited(channel.setVolume(from + (to - from) * t));
      if (step >= _fadeSteps) {
        _fades.remove(channel);
        onDone?.call();
        return;
      }
      _fades[channel] = _timer(_fadeTotal ~/ _fadeSteps, advance);
    }

    advance();
  }

  void _cancelFade(MusicChannel channel) {
    _fades.remove(channel)?.cancel();
  }

  // -- SFX bus ----------------------------------------------------------------

  final Map<String, int> _lastCueAt = <String, int>{};

  /// Fires [skill]'s accepted action cue, if its cooldown has elapsed.
  ///
  /// Called by the stage when a **visible** working loop crosses its strike
  /// frame, and when a single successful gather's one-shot begins — the two
  /// shapes of "the player is watching the action happen". The cooldown is
  /// the anti-stack floor `ActionCue.cooldownMillis` documents, never a
  /// scheduler: no beat, no sound.
  void playSkillCue(String skill) {
    if (_disposed || _halted) return;
    if (!_settings.enabled || _settings.sfxVolume <= 0) return;
    final ActionCue? cue = AudioCues.cueForSkill(skill);
    if (cue == null) return;
    final int now = _nowMillis();
    final int? last = _lastCueAt[cue.assetId];
    if (last != null && now - last < cue.cooldownMillis) return;
    _lastCueAt[cue.assetId] = now;
    unawaited(
      _output.playCue(
        AudioCues.files[cue.assetId]!,
        volume: _settings.sfxVolume,
      ),
    );
  }

  // -- Settings ---------------------------------------------------------------

  void setEnabled(bool enabled) {
    if (enabled == _settings.enabled) return;
    _settings = _settings.copyWith(enabled: enabled);
    if (!enabled) {
      // Off is silence now: the live track pauses (the assignment is kept,
      // so ON resumes the same place), the dying one just dies.
      final MusicChannel? dying = _fadingOut;
      if (dying != null) {
        _cancelFade(dying);
        _fadingOut = null;
        unawaited(dying.dispose());
      }
      final MusicChannel? current = _music;
      if (current != null) {
        _cancelFade(current);
        unawaited(current.pause());
      }
    } else {
      _resumeAssignedMusic();
    }
    _scheduleSave();
    notifyListeners();
  }

  void setMusicVolume(double volume) {
    _settings = _settings.copyWith(musicVolume: volume);
    final MusicChannel? current = _music;
    if (current != null && _fades[current] == null) {
      unawaited(current.setVolume(_settings.musicVolume));
    }
    _scheduleSave();
    notifyListeners();
  }

  void setSfxVolume(double volume) {
    _settings = _settings.copyWith(sfxVolume: volume);
    _scheduleSave();
    notifyListeners();
  }

  void setHapticsEnabled(bool enabled) {
    if (enabled == _settings.hapticsEnabled) return;
    _settings = _settings.copyWith(hapticsEnabled: enabled);
    _scheduleSave();
    notifyListeners();
  }

  // -- Haptic punctuation (Fable V2 Iteration 02) ---------------------------
  //
  // The one seam every haptic in the app fires through, so the toggle and
  // the scarcity discipline live in one place a grep can audit. Haptics are
  // punctuation for commits and payoffs — a reward layer rising, a journey
  // set out on, a heavy blow landing — never loop beats: a ten-minute
  // gather queue pulsing the wrist would numb the channel and turn feedback
  // into upkeep. Fire-and-forget platform calls; nothing here blocks.
  // Deliberately independent of Reduce Motion — separate accessibility
  // axes — and beneath the OS's own System Haptics switch either way.

  void hapticLight() {
    if (_settings.hapticsEnabled) unawaited(HapticFeedback.lightImpact());
  }

  void hapticMedium() {
    if (_settings.hapticsEnabled) unawaited(HapticFeedback.mediumImpact());
  }

  void hapticHeavy() {
    if (_settings.hapticsEnabled) unawaited(HapticFeedback.heavyImpact());
  }

  void hapticSelection() {
    if (_settings.hapticsEnabled) unawaited(HapticFeedback.selectionClick());
  }

  /// Brings the assigned track back after enable/resume: resumes the held
  /// channel when one exists, or starts the assignment fresh when none does
  /// (the region changed while audio was off).
  void _resumeAssignedMusic() {
    if (_halted || !_settings.enabled) return;
    final MusicChannel? current = _music;
    if (current != null) {
      unawaited(current.setVolume(_settings.musicVolume));
      unawaited(current.resume());
      return;
    }
    final String? assetId = _musicAssetId;
    if (assetId == null) return;
    final int epoch = ++_musicEpoch;
    unawaited(() async {
      final MusicChannel channel = await _output.startMusic(
        AudioCues.files[assetId]!,
        volume: 0,
      );
      if (_disposed || epoch != _musicEpoch) {
        await channel.dispose();
        return;
      }
      _music = channel;
      _animateVolume(channel, from: 0, to: _settings.musicVolume);
    }());
  }

  void _scheduleSave() {
    final AudioSettingsStore? store = _store;
    if (store == null) return;
    _saveTimer?.cancel();
    _saveTimer = _timer(_saveDebounce, () {
      _saveTimer = null;
      unawaited(store.save(_settings));
    });
  }

  // -- Lifecycle ----------------------------------------------------------------

  AppLifecycleState? _lifecycle;

  /// Null — never reported; the widget-test harness and a fresh launch — is
  /// treated as foreground, the same seam `ActivityController` documents.
  bool get _halted =>
      _lifecycle != null && _lifecycle != AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    final bool wasHalted = _halted;
    _lifecycle = state;
    if (_halted == wasHalted) return;

    if (_halted) {
      // Background: pause the live track (it resumes where it left off —
      // "do not restart tracks unnecessarily"), finish the dying one
      // silently. Cues stop themselves: [playSkillCue] refuses while halted,
      // and the loops that fire it are not being drawn anyway.
      final MusicChannel? dying = _fadingOut;
      if (dying != null) {
        _cancelFade(dying);
        _fadingOut = null;
        unawaited(dying.dispose());
      }
      final MusicChannel? current = _music;
      if (current != null) {
        _cancelFade(current);
        unawaited(current.pause());
      }
      return;
    }
    _resumeAssignedMusic();
  }

  @override
  void dispose() {
    _disposed = true;
    final bool savePending = _saveTimer != null;
    _saveTimer?.cancel();
    _saveTimer = null;
    // Flush a debounced settings change rather than losing it.
    if (savePending) unawaited(_store?.save(_settings));
    for (final Timer timer in _fades.values) {
      timer.cancel();
    }
    _fades.clear();
    final MusicChannel? current = _music;
    final MusicChannel? dying = _fadingOut;
    _music = null;
    _fadingOut = null;
    if (current != null) unawaited(current.dispose());
    if (dying != null) unawaited(dying.dispose());
    unawaited(_output.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
