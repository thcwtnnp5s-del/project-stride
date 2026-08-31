/// The audio layer's one seam onto `package:audioplayers` — everything the
/// controller needs, and nothing else it could grow to depend on.
///
/// `AudioController` holds the policy (what plays, when, how loud) and this
/// holds the plugin. The split is what lets the controller's tests run under
/// `dart test` with a fake output instead of a device: region mapping,
/// crossfade ownership, cooldowns, lifecycle and settings are all provable
/// without a platform channel in the room.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// One playing music track. The controller owns at most two at a time — the
/// current track and the one crossfading out — and every channel is disposed
/// by the controller that started it.
abstract interface class MusicChannel {
  Future<void> setVolume(double volume);
  Future<void> pause();
  Future<void> resume();

  /// Stops and releases the underlying player. Terminal.
  Future<void> dispose();
}

abstract interface class AudioOutput {
  /// One-time platform setup. Called once by `AudioController.start`.
  Future<void> init();

  /// Starts [assetPath] (relative to `assets/`) looping at [volume] and
  /// returns its channel. Every call is a **new** channel; the caller is
  /// responsible for retiring the old one — that ownership being explicit is
  /// what makes "exactly one region track" testable.
  Future<MusicChannel> startMusic(String assetPath, {required double volume});

  /// Fires one short cue at [volume]. Fire-and-forget; overlapping calls for
  /// the same path retrigger rather than layer.
  Future<void> playCue(String assetPath, {required double volume});

  Future<void> dispose();
}

/// The production output.
final class AudioplayersOutput implements AudioOutput {
  AudioplayersOutput();

  /// One persistent player per cue path, created on first use. Five cues ship;
  /// a player each keeps retrigger latency at "already loaded" rather than
  /// "construct, route, decode" — and retriggering through one player is what
  /// keeps the same cue from layering copies of itself.
  final Map<String, AudioPlayer> _cuePlayers = <String, AudioPlayer>{};

  @override
  Future<void> init() async {
    // `respectSilence` gives iOS the *ambient* session category: game audio
    // honours the ring/silent switch, mixes politely, and is silenced by the
    // OS in the background — which is the milestone's lifecycle contract (no
    // background playback, no background-mode entitlement).
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(respectSilence: true).build(),
    );
  }

  @override
  Future<MusicChannel> startMusic(
    String assetPath, {
    required double volume,
  }) async {
    final AudioPlayer player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(assetPath), volume: volume);
    return _AudioplayersMusicChannel(player);
  }

  @override
  Future<void> playCue(String assetPath, {required double volume}) async {
    AudioPlayer? player = _cuePlayers[assetPath];
    if (player == null) {
      final AudioPlayer p = AudioPlayer();
      // Short transients want the low-latency path (SoundPool on Android);
      // stop-not-release keeps the decoded source warm between strikes.
      //
      // **Awaited** (PRESENTATION_COMBAT_EVOLUTION_01). These were
      // fire-and-forget inside a `putIfAbsent`, with `play()` issued on the
      // next line — so the very first strike of every cue path raced its own
      // player configuration. A first hit that is sometimes silent, and only
      // ever on the first hit, is the hardest kind of audio bug to believe.
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      // Re-check: an interleaved call for the same path may have installed one
      // while this was awaiting. Losing the race means disposing our own.
      final AudioPlayer? raced = _cuePlayers[assetPath];
      if (raced != null) {
        unawaited(p.dispose());
        player = raced;
      } else {
        _cuePlayers[assetPath] = p;
        player = p;
      }
    }
    await player.stop();
    await player.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> dispose() async {
    for (final AudioPlayer player in _cuePlayers.values) {
      await player.dispose();
    }
    _cuePlayers.clear();
  }
}

final class _AudioplayersMusicChannel implements MusicChannel {
  _AudioplayersMusicChannel(this._player);

  final AudioPlayer _player;
  bool _disposed = false;

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    await _player.resume();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.stop();
    await _player.dispose();
  }
}
