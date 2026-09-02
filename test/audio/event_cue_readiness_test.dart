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
/// categories this workstream and ART-11 (FMPO02 wave 1) added. `ui` is the
/// shared commit-press category: one id, `ui.commit.01`, covers every
/// primary-commit press (`AudioCues.EventCues.ui`).
final RegExp _convention = RegExp(
  r'^(music|gather|craft|combat|reward|ui)\.[a-z_]+(\.[a-z_]+)*\.\d{2}$',
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

  test('the queue documents name exactly the unproduced events', () {
    // A queue that has drifted from the tables is worse than none: it sends a
    // future session to produce sounds the game will not play, or leaves an
    // event silent because nobody knew to make it.
    //
    // Two documents now share this contract: QUEUE_02 named the original
    // twenty combat/reward events, QUEUE_03 named the ART-11 delta (the `ui`
    // table). Each event is checked against the queue that actually claims
    // it, so a `ui.commit.01` typo in QUEUE_03 cannot hide behind QUEUE_02
    // happening to contain unrelated text.
    final File queue02 = File('AUDIO/AUDIO_PRODUCTION_QUEUE_02.md');
    final File queue03 = File('AUDIO/AUDIO_PRODUCTION_QUEUE_03.md');
    expect(
      queue02.existsSync(),
      isTrue,
      reason: 'the VAWO01 event queue is missing',
    );
    expect(
      queue03.existsSync(),
      isTrue,
      reason: 'the ART-11 event queue (FMPO02 wave 1) is missing',
    );
    final String text02 = queue02.readAsStringSync();
    final String text03 = queue03.readAsStringSync();

    void checkAgainst(
      Iterable<String> events,
      String docText,
      String docName,
    ) {
      for (final String event in events) {
        final EventCue e = EventCues.of(event)!;
        if (AudioCues.fileFor(e.assetId) != null) continue;
        expect(
          docText.contains(e.assetId),
          isTrue,
          reason:
              '${e.assetId} is unproduced and is not in $docName — no '
              'future session would know to make it',
        );
      }
    }

    checkAgainst(EventCues.combat.keys, text02, 'QUEUE_02');
    checkAgainst(EventCues.reward.keys, text02, 'QUEUE_02');
    checkAgainst(EventCues.ui.keys, text03, 'QUEUE_03');
  });

  test('QUEUE_03 also names the cooking-transient swap', () {
    // craft.cooking.stir.01 is not an EventCue — it is a one-row ActionCue
    // swap for `skillCues['skill.cooking']` (ART-11 §3), landing only once
    // the file exists (`audio_cues.dart:166`). It has no table entry to check
    // automatically today, so this pins the queue doc's own self-consistency:
    // both the outgoing and incoming asset IDs must be named, so a future
    // session finds the swap instead of re-discovering the no-transient
    // defect from scratch.
    final File queue03 = File('AUDIO/AUDIO_PRODUCTION_QUEUE_03.md');
    expect(
      queue03.existsSync(),
      isTrue,
      reason: 'the ART-11 event queue (FMPO02 wave 1) is missing',
    );
    final String text = queue03.readAsStringSync();
    expect(
      text.contains('craft.cooking.stir.01'),
      isTrue,
      reason: 'QUEUE_03 must name the replacement asset ID',
    );
    expect(
      text.contains('craft.cooking.01'),
      isTrue,
      reason: 'QUEUE_03 must name what craft.cooking.stir.01 replaces',
    );
    expect(
      AudioCues.skillCues['skill.cooking']!.assetId,
      'craft.cooking.01',
      reason:
          'the swap is documentation-only until the file lands — if this '
          'ever reads craft.cooking.stir.01, the file exists and QUEUE_03 '
          'should be closed instead of asserting a finished swap',
    );
  });
}
