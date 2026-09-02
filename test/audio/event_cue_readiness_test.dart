/// Every combat and reward event can accept its future sound with **no code
/// change** (VAWO01, owner ruling; `DECISIONS/0032`).
///
/// The event cue architecture landed in this workstream ahead of the audio
/// itself: twenty events name asset IDs, ten files are bundled, and the rest
/// resolve to silence. That is a deliberate state, and it is only safe while
/// the last mile really is a one-row addition to `AudioCues.files`.
///
/// These tests are what make that claim checkable rather than asserted. If a
/// future session produces `combat.impact.player.01`, drops the file into
/// `assets/audio/v1/sfx/`, and adds its row, every one of these already
/// passes — nothing else in the codebase has to move.
///
/// `audio_assets_test.dart` holds the equivalent invariants for the *shipped*
/// tables; this file holds them for the unshipped ones, which that file
/// deliberately does not reach.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/audio/audio_cues.dart';

/// `<category>.<subject>.<variant>` — the manifest convention, widened to the
/// two categories this workstream added.
final RegExp _convention = RegExp(
  r'^(music|gather|craft|combat|reward)\.[a-z_]+(\.[a-z_]+)*\.\d{2}$',
);

void main() {
  test('every event names an asset ID in the manifest convention', () {
    for (final String event in EventCues.all) {
      final EventCue e = EventCues.of(event)!;
      expect(
        _convention.hasMatch(e.assetId),
        isTrue,
        reason:
            '$event names "${e.assetId}", which does not follow '
            '<category>.<subject>.<variant> — the manifest could not file it',
      );
    }
  });

  test('no two events share a sound', () {
    // Two events on one asset ID would mean the game cannot tell the player
    // apart two things that happened, and no amount of mixing fixes that.
    final Map<String, String> owner = <String, String>{};
    for (final String event in EventCues.all) {
      final EventCue e = EventCues.of(event)!;
      final String? already = owner[e.assetId];
      expect(
        already,
        isNull,
        reason: '$event and $already both claim "${e.assetId}"',
      );
      owner[e.assetId] = event;
    }
  });

  test('every event resolves today — to a real file, or to silence', () {
    // The fallback contract (`AudioCues.fileFor`): an unproduced ID is
    // silence, never a crash and never some other sound. A `!` here once took
    // a screen down from inside an animation tick.
    for (final String event in EventCues.all) {
      final EventCue e = EventCues.of(event)!;
      final String? file = AudioCues.fileFor(e.assetId);
      if (file == null) continue;
      expect(
        File('assets/$file').existsSync(),
        isTrue,
        reason: '$event names bundled file "$file", which is not on disk',
      );
    }
  });

  test('the last mile is a table row, not a code change', () {
    // Simulate what a future audio session does: take an unproduced event and
    // check that everything downstream of `files` is already in place —
    // priority, gap, ducking and trim are authored, and the only thing
    // missing is the row. If this list is ever empty, the round is finished.
    final List<String> unproduced = <String>[
      for (final String event in EventCues.all)
        if (AudioCues.fileFor(EventCues.of(event)!.assetId) == null) event,
    ];
    expect(
      unproduced,
      isNotEmpty,
      reason:
          'every event now has a sound — delete this test and its queue '
          'document rather than letting it assert a thing that is finished',
    );
    for (final String event in unproduced) {
      final EventCue cue = EventCues.of(event)!;
      // Everything the mixer needs is authored ahead of the file.
      expect(cue.priority, greaterThan(0), reason: '$event has no priority');
      expect(
        cue.minGapMillis,
        greaterThan(0),
        reason: '$event has no gap floor, so it could machine-gun',
      );
      expect(cue.duckDb, lessThanOrEqualTo(0), reason: '$event ducks upward');
      expect(cue.trimDb, lessThanOrEqualTo(0), reason: '$event boosts');
    }
  });

  test('the queue document names exactly the unproduced events', () {
    // A queue that has drifted from the tables is worse than none: it sends a
    // future session to produce sounds the game will not play, or leaves an
    // event silent because nobody knew to make it.
    final File queue = File('AUDIO/AUDIO_PRODUCTION_QUEUE_02.md');
    expect(
      queue.existsSync(),
      isTrue,
      reason: 'the VAWO01 event queue is missing',
    );
    final String text = queue.readAsStringSync();
    for (final String event in EventCues.all) {
      final EventCue e = EventCues.of(event)!;
      if (AudioCues.fileFor(e.assetId) != null) continue;
      expect(
        text.contains(e.assetId),
        isTrue,
        reason:
            '${e.assetId} is unproduced and is not in the queue — no '
            'future session would know to make it',
      );
    }
  });
}
