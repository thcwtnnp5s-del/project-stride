/// Persists [AudioSettings] as one small JSON file in the application
/// support directory.
///
/// ## Where this stands with `DECISIONS/0013` (single-writer persistence)
///
/// It deliberately does **not** touch the save directory
/// (`<support>/project_stride/`), construct any of the persistence types, or
/// run anywhere but the root isolate. The single-writer guard's subject is
/// the game save's compare-and-swap world; this file is a preference sidecar
/// beside it, with nothing transactional to protect — the write is
/// temp-then-rename so a torn write costs a default, never a corrupt game.
///
/// Nothing here is health data, and nothing here identifies anything
/// (`RULES.md` H-7 has no subject in this file).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import 'audio_settings.dart';

class AudioSettingsStore {
  AudioSettingsStore(this._file);

  /// Opens the store at its production path,
  /// `<application support>/audio_settings.json`.
  static Future<AudioSettingsStore> open() async {
    final Directory support = await getApplicationSupportDirectory();
    return AudioSettingsStore(File('${support.path}/audio_settings.json'));
  }

  final File _file;

  /// The stored settings, or defaults when the file is absent or unreadable.
  /// Never throws: a preference file must not be able to block startup.
  Future<AudioSettings> load() async {
    try {
      if (!await _file.exists()) return const AudioSettings();
      final Object? decoded =
          jsonDecode(await _file.readAsString()) as Object?;
      if (decoded is! Map<String, Object?>) return const AudioSettings();
      return AudioSettings.fromJson(decoded);
    } on Object catch (e) {
      debugPrint('audio settings load failed, using defaults: $e');
      return const AudioSettings();
    }
  }

  /// Writes [settings] atomically enough for a preference: full content to a
  /// sidecar, then rename over the target. Failures are logged and swallowed
  /// — the running controller keeps the in-memory value either way, and the
  /// next successful save repairs the file.
  Future<void> save(AudioSettings settings) async {
    try {
      final File tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await tmp.rename(_file.path);
    } on Object catch (e) {
      debugPrint('audio settings save failed: $e');
    }
  }
}
