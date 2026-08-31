/// The audio tables against the repository they describe: every asset ID
/// resolves to a file that exists AND is declared in `pubspec.yaml`, every
/// region key is a real location, every skill key a real skill — the
/// "asset that does not exist" and "content nobody reviewed" failure modes,
/// caught at `flutter test` rather than on the device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:stride/audio/audio_cues.dart';

void main() {
  test('every audio asset in the tables exists and is declared', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    for (final MapEntry<String, String> e in AudioCues.files.entries) {
      final String path = 'assets/${e.value}';
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '${e.key} points at $path, which does not exist',
      );
      expect(
        pubspec.contains('- $path'),
        isTrue,
        reason:
            '${e.key} points at $path, which pubspec.yaml does not declare — '
            'an undeclared file is audio that does not exist on the device',
      );
    }
  });

  test('every region music key is a shipped location', () {
    final List<dynamic> locations =
        (jsonDecode(File('assets/content/v1/locations.json').readAsStringSync())
                as Map<String, dynamic>)['entries']
            as List<dynamic>;
    final Set<String> ids = locations
        .map((dynamic l) => (l as Map<String, dynamic>)['id'] as String)
        .toSet();
    for (final String key in AudioCues.regionMusic.keys) {
      expect(ids, contains(key), reason: '$key is not in locations.json');
    }
  });

  test('every playable region with a track: the five shipped locations', () {
    // The acceptance list, verbatim: Haven, Woods, Stonefall, Frostmere,
    // Hollow each use correct music. A sixth location added later without a
    // track goes quiet (documented behaviour), but losing one of THESE five
    // is a regression against the owner's accepted foundation.
    expect(
      AudioCues.regionMusic.keys.toSet(),
      <String>{
        'location.havens_rest',
        'location.whispering_woods',
        'location.stonefall_mine',
        'location.frostmere',
        'location.forgotten_hollow',
      },
    );
  });

  test('every action-cue key is a shipped skill', () {
    final List<dynamic> skills =
        (jsonDecode(File('assets/content/v1/skills.json').readAsStringSync())
                as Map<String, dynamic>)['entries']
            as List<dynamic>;
    final Set<String> ids = skills
        .map((dynamic s) => (s as Map<String, dynamic>)['id'] as String)
        .toSet();
    for (final String key in AudioCues.skillCues.keys) {
      expect(ids, contains(key), reason: '$key is not in skills.json');
    }
  });

  test('every cue asset ID follows the manifest convention', () {
    // <category>.<subject>.<variant> (AUDIO/AUDIO_ASSET_MANIFEST.md).
    final RegExp convention = RegExp(r'^(music|gather|craft)\.[a-z_]+\.\d{2}$');
    for (final String id in AudioCues.files.keys) {
      expect(convention.hasMatch(id), isTrue, reason: id);
    }
  });

  // -- The referential invariants (PRESENTATION_COMBAT_EVOLUTION_01) --------
  //
  // Every test above iterates a table and checks the world against it. None of
  // them could see the one defect that actually reaches the player: a cue
  // naming an asset ID that no table defines. `playSkillCue` resolved that
  // with `AudioCues.files[id]!`, so a single mistyped character threw a
  // `_CastError` out of an animation tick — inside a `setState` frame — and
  // took the screen down instead of going quiet. The lookup is null-safe now
  // (`AudioCues.fileFor`), and these two tests are what stop a dangling
  // reference from reaching a device in the first place.

  test('every skill cue names an asset the tables define', () {
    for (final MapEntry<String, ActionCue> e in AudioCues.skillCues.entries) {
      expect(
        AudioCues.files.containsKey(e.value.assetId),
        isTrue,
        reason:
            '${e.key} names asset "${e.value.assetId}", which AudioCues.files '
            'does not define — the sound would silently never play',
      );
    }
  });

  test('every region music key names an asset the tables define', () {
    for (final MapEntry<String, String> e in AudioCues.regionMusic.entries) {
      expect(
        AudioCues.files.containsKey(e.value),
        isTrue,
        reason:
            '${e.key} names asset "${e.value}", which AudioCues.files does '
            'not define — the region would be silent',
      );
    }
  });

  test('a cue naming an unknown asset resolves to silence, never a throw', () {
    // The fallback contract itself, stated as a test so it cannot regress
    // back into a `!`. Both a missing ID and a null resolve to null.
    expect(AudioCues.fileFor('combat.nothing.produced.yet.01'), isNull);
    expect(AudioCues.fileFor(null), isNull);
    expect(
      AudioCues.fileFor('gather.mining.01'),
      'audio/v1/sfx/sfx_gather_mining_01.wav',
    );
  });
}
