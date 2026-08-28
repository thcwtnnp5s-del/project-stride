/// Which recipes have ever been crafted — a **presentation memory**, so the
/// first make of a meaningful recipe can be presented more strongly than its
/// hundredth (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1).
///
/// ## Why a sidecar file and not the save
///
/// First-craft state is not derivable from durable state — `ProgressState`
/// keeps no craft counts and the journal compacts — and this workstream may
/// not touch the save format. So the memory lives on the exact seam
/// `AudioSettingsStore` proved: one small JSON file in the application
/// support directory, **beside** — never inside — the save directory
/// (`DECISIONS/0013` untouched; nothing transactional to protect).
///
/// ## What losing it costs, and why that is acceptable
///
/// A reinstall or a cleared support directory forgets the set, and the next
/// craft of an old recipe is presented as a first again — once. Because of
/// exactly that, the elevated presentation **never makes a lifetime factual
/// claim** ("FIRST EVER" is banned copy); it only presents the moment more
/// strongly. A wrong emphasis is a shrug; a wrong sentence would be a lie.
/// No economy figure, no game state, and no health fact is read or written
/// here (`RULES.md` H-7 has no subject in this file).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

class CraftMemory {
  CraftMemory._(this._file, this._crafted);

  /// An empty in-memory instance for tests and for callers that want the
  /// significance path without a filesystem.
  CraftMemory.ephemeral() : this._(null, <String>{});

  /// Opens the memory at its production path,
  /// `<application support>/craft_memory.json`. Never throws: a presentation
  /// memory must not be able to block startup — unreadable means empty.
  static Future<CraftMemory> open() async {
    File? file;
    Set<String> crafted = <String>{};
    try {
      final Directory support = await getApplicationSupportDirectory();
      file = File('${support.path}/craft_memory.json');
      if (await file.exists()) {
        final Object? decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?> &&
            decoded['crafted'] is List<Object?>) {
          crafted = (decoded['crafted'] as List<Object?>)
              .whereType<String>()
              .toSet();
        }
      }
    } on Object catch (e) {
      debugPrint('craft memory load failed, starting empty: $e');
    }
    return CraftMemory._(file, crafted);
  }

  final File? _file;
  final Set<String> _crafted;

  /// Whether [recipe] has ever finished a craft on this install.
  bool crafted(ContentId recipe) => _crafted.contains(recipe.value);

  /// Records that [recipe] completed at least once. Monotonic — nothing is
  /// ever removed — and persisted fire-and-forget: a torn write costs one
  /// repeated elevation, never anything the game rules read.
  void markCrafted(ContentId recipe) {
    if (!_crafted.add(recipe.value)) return;
    _persist();
  }

  Future<void> _persist() async {
    final File? file = _file;
    if (file == null) return;
    try {
      final File tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode(<String, Object?>{'crafted': _crafted.toList()..sort()}),
        flush: true,
      );
      await tmp.rename(file.path);
    } on Object catch (e) {
      debugPrint('craft memory save failed: $e');
    }
  }
}
