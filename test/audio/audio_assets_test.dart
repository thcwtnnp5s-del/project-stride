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
}
