/// The audio controller's policy, proven without a platform channel:
/// region → track mapping, single-ownership of the music bus, the crossfade
/// ending with exactly one live channel, cue mapping and the anti-stack
/// cooldown, the master switch, lifecycle pause/resume, and settings
/// persistence through the store.
///
/// The output is a fake and the timers are hand-fired — the same seam
/// discipline as `ActivityTiming` — so every assertion here is about the
/// controller's decisions, not the plugin's behaviour. What the plugin does
/// with those decisions is the physical device review's subject.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stride/audio/audio_controller.dart';
import 'package:stride/audio/audio_cues.dart';
import 'package:stride/audio/audio_output.dart';
import 'package:stride/audio/audio_settings.dart';
import 'package:stride/audio/audio_settings_store.dart';

final class _FakeChannel implements MusicChannel {
  _FakeChannel(this.path);

  final String path;
  final List<double> volumes = <double>[];
  bool paused = false;
  bool resumed = false;
  bool disposed = false;

  double get volume => volumes.isEmpty ? -1 : volumes.last;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async {
    paused = false;
    resumed = true;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

final class _FakeOutput implements AudioOutput {
  final List<_FakeChannel> channels = <_FakeChannel>[];
  final List<(String, double)> cues = <(String, double)>[];

  _FakeChannel get lastChannel => channels.last;

  @override
  Future<void> init() async {}

  @override
  Future<MusicChannel> startMusic(
    String assetPath, {
    required double volume,
  }) async {
    final _FakeChannel channel = _FakeChannel(assetPath)..volumes.add(volume);
    channels.add(channel);
    return channel;
  }

  @override
  Future<void> playCue(String assetPath, {required double volume}) async =>
      cues.add((assetPath, volume));

  @override
  Future<void> dispose() async {}
}

/// A hand-fired one-shot timer. [flush] runs the queue to quiescence, which
/// terminates because every chain here (the fade's steps, the save debounce)
/// is finite by construction.
final class _FakeTimers {
  final List<void Function()> pending = <void Function()>[];

  Timer create(Duration duration, void Function() onFire) {
    final _FakeTimer timer = _FakeTimer();
    pending.add(() {
      if (timer.cancelled) return;
      timer.fired = true;
      onFire();
    });
    return timer;
  }

  void flush() {
    while (pending.isNotEmpty) {
      final void Function() next = pending.removeAt(0);
      next();
    }
  }
}

final class _FakeTimer implements Timer {
  bool cancelled = false;
  bool fired = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeOutput output;
  late _FakeTimers timers;
  late int now;
  late AudioController controller;

  AudioController build({AudioSettings? settings, AudioSettingsStore? store}) {
    output = _FakeOutput();
    timers = _FakeTimers();
    now = 0;
    return controller = AudioController(
      output: output,
      settings: settings ?? const AudioSettings(),
      store: store,
      timerFactory: timers.create,
      nowMillis: () => now,
    );
  }

  tearDown(() => controller.dispose());

  group('region music mapping', () {
    test('every playable region starts its accepted track', () async {
      build();
      const Map<String, String> expected = <String, String>{
        'location.havens_rest': 'music.haven.01',
        'location.whispering_woods': 'music.whispering_woods.01',
        'location.stonefall_mine': 'music.stonefall_mine.01',
        'location.frostmere': 'music.frostmere.01',
        'location.forgotten_hollow': 'music.forgotten_hollow.01',
      };
      for (final MapEntry<String, String> e in expected.entries) {
        await controller.setRegion(e.key);
        timers.flush();
        expect(controller.currentMusicAssetId, e.value, reason: e.key);
        expect(output.lastChannel.path, AudioCues.files[e.value]!);
      }
    });

    test('the same region never restarts the track', () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      // Tab changes, screen pushes, combat: all re-announce the same place.
      await controller.setRegion('location.havens_rest');
      await controller.setRegion('location.havens_rest');
      expect(output.channels.length, 1);
      expect(output.channels.single.disposed, isFalse);
    });

    test('a region change ends with exactly one live channel, faded in',
        () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      final _FakeChannel haven = output.channels.single;

      await controller.setRegion('location.frostmere');
      timers.flush();

      expect(haven.disposed, isTrue, reason: 'the old track is retired');
      final _FakeChannel frostmere = output.channels[1];
      expect(frostmere.disposed, isFalse);
      expect(
        frostmere.volume,
        moreOrLessEquals(AudioSettings.defaultMusicVolume),
        reason: 'the new track fades up to the music volume',
      );
    });

    test('an unknown or null location is deliberate silence', () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      await controller.setRegion('location.uncharted');
      timers.flush();
      expect(controller.currentMusicAssetId, isNull);
      expect(output.channels.single.disposed, isTrue);
      await controller.setRegion(null);
      expect(output.channels.length, 1, reason: 'silence starts nothing');
    });
  });

  group('action cues', () {
    test('each profession fires its one accepted cue at its trimmed volume', () {
      build();
      const Map<String, String> expected = <String, String>{
        'skill.mining': 'gather.mining.01',
        'skill.woodcutting': 'gather.woodcutting.01',
        'skill.foraging': 'gather.foraging.01',
        'skill.smithing': 'craft.smithing.01',
        'skill.cooking': 'craft.cooking.01',
      };
      for (final MapEntry<String, String> e in expected.entries) {
        now += 10000; // past every cooldown
        controller.playSkillCue(e.key);
        expect(output.cues.last.$1, AudioCues.files[e.value]!, reason: e.key);
        // The cue's level is the player's volume scaled by that cue's own
        // trim (`ActionCue.trimDb`) — the level-matching pass. Was a bare
        // `defaultSfxVolume` before the five shipped cues were measured and
        // found to span 10.4 dB of LUFS-M max.
        expect(
          output.cues.last.$2,
          closeTo(
            AudioSettings.defaultSfxVolume *
                AudioCues.skillCues[e.key]!.gain,
            1e-9,
          ),
          reason: e.key,
        );
      }
      expect(output.cues.length, expected.length);
    });

    test('a trim only ever attenuates, and mining is the untouched floor', () {
      build(); // only so the shared tearDown has something to dispose.
      // The invariant that keeps this table honest: `trimDb` can never make a
      // cue louder than the player asked for, so it can never clip a file
      // already mastered to −1.0 dBTP.
      for (final MapEntry<String, ActionCue> e in AudioCues.skillCues.entries) {
        expect(
          e.value.trimDb,
          lessThanOrEqualTo(0),
          reason: '${e.key} boosts, which can clip',
        );
        expect(e.value.gain, lessThanOrEqualTo(1.0), reason: e.key);
        expect(e.value.gain, greaterThan(0), reason: e.key);
      }
      // Mining is the measured quietest cue; nothing may pull it lower.
      expect(AudioCues.skillCues['skill.mining']!.trimDb, 0);
      expect(AudioCues.skillCues['skill.mining']!.gain, 1.0);
    });

    test('cooking fires on every stir, not every other one', () {
      build(); // only so the shared tearDown has something to dispose.
      // 7 frames ping-ponged to 12 slots at 110 ms = 1,320 ms per cycle. A
      // floor above that skipped a cycle; the floor must stay under it.
      expect(
        AudioCues.skillCues['skill.cooking']!.cooldownMillis,
        lessThan(1320),
      );
    });

    test('the cooldown floor swallows a double-fire, not the next beat', () {
      build();
      controller.playSkillCue('skill.mining');
      controller.playSkillCue('skill.mining'); // same instant: a stack
      expect(output.cues.length, 1);
      now += AudioCues.skillCues['skill.mining']!.cooldownMillis;
      controller.playSkillCue('skill.mining'); // the next visible strike
      expect(output.cues.length, 2);
    });

    test('a skill with no cue is silent, not an error', () {
      build();
      controller.playSkillCue('skill.unheard_of');
      expect(output.cues, isEmpty);
    });
  });

  group('the master switch', () {
    test('off pauses music, refuses cues, and remembers the assignment',
        () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      controller.setEnabled(false);
      expect(output.channels.single.paused, isTrue);
      controller.playSkillCue('skill.mining');
      expect(output.cues, isEmpty);
      expect(controller.currentMusicAssetId, 'music.haven.01');
    });

    test('off then travelling then on plays the NEW region, once', () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      controller.setEnabled(false);
      await controller.setRegion('location.frostmere');
      expect(output.channels.length, 1, reason: 'nothing starts while off');
      controller.setEnabled(true);
      // The fresh start is async behind the toggle; flushing the fade after
      // the microtask queue drains gets it audible.
      await Future<void>.delayed(Duration.zero);
      timers.flush();
      expect(output.channels.length, 2);
      expect(
        output.channels[1].path,
        AudioCues.files['music.frostmere.01']!,
      );
      expect(output.channels[1].disposed, isFalse);
    });
  });

  group('lifecycle', () {
    test('background pauses, resume resumes the same channel', () async {
      build();
      await controller.setRegion('location.havens_rest');
      timers.flush();
      final _FakeChannel channel = output.channels.single;

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(channel.paused, isTrue);
      controller.playSkillCue('skill.mining');
      expect(output.cues, isEmpty, reason: 'no cues while backgrounded');

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(channel.resumed, isTrue);
      expect(output.channels.length, 1, reason: 'no duplicate player');
    });
  });

  group('settings persistence', () {
    test('a change survives into a fresh store', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('stride_audio');
      // Best-effort: on Windows the just-renamed settings file can hold its
      // handle a beat longer than the test; a leaked temp dir is not a
      // failure of the thing under test.
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } on FileSystemException {
          // Leave it to the OS temp cleaner.
        }
      });
      final File file = File('${tmp.path}/audio_settings.json');

      build(store: AudioSettingsStore(file));
      controller.setMusicVolume(0.3);
      controller.setSfxVolume(0.7);
      controller.setEnabled(false);
      timers.flush(); // the debounced save
      // The save is fire-and-forget inside the controller; give the real
      // file IO time to land rather than racing it with one microtask.
      for (int i = 0; i < 200 && !file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final AudioSettings reloaded = await AudioSettingsStore(file).load();
      expect(reloaded.enabled, isFalse);
      expect(reloaded.musicVolume, moreOrLessEquals(0.3));
      expect(reloaded.sfxVolume, moreOrLessEquals(0.7));
    });

    test('a missing or corrupt file loads defaults, never throws', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('stride_audio');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } on FileSystemException {
          // Best effort, as above.
        }
      });
      final File file = File('${tmp.path}/audio_settings.json');

      expect(await AudioSettingsStore(file).load(), const AudioSettings());
      await file.writeAsString('not json at all {{{');
      expect(await AudioSettingsStore(file).load(), const AudioSettings());
      await file.writeAsString('{"musicVolume": "loud"}');
      expect(await AudioSettingsStore(file).load(), const AudioSettings());

      // Uses `build` only so the shared tearDown has something to dispose.
      build();
    });
  });
}
