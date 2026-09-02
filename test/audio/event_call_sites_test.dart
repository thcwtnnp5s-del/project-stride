/// Every wired event has a **caller**, not just a table row.
///
/// ## The defect this exists to make impossible
///
/// `AUDIO_PRODUCTION_QUEUE_02.md` §2 promised that landing any of the twenty
/// combat/reward/completion sounds was "a row in `AudioCues.files` and a file
/// on disk. **Nothing else changes.**" That was false for all twenty:
/// `grep -rn "playEvent(" lib/` returned the definition and one call site
/// (`AudioEvents.commit`). Dropping a file in and adding the row would have
/// produced silence forever, because no game moment ever asked for the sound.
///
/// It is the same shape as `MISTAKES.md` M-16 — the caller is what goes
/// missing, and the caller is the one thing a table-consistency suite cannot
/// see. `event_cue_readiness_test.dart` checks that the tables and the queue
/// documents agree with each other; every assertion in it passes with a
/// codebase that never plays a sound at all. This file is the other half.
///
/// ## Why a source scan and not a widget test
///
/// A widget test proves one path. There are twenty here, several of them
/// reachable only through a heavy blow, a brace, a signature drop or a
/// character level — states a test would have to manufacture, and would then
/// be asserting about the fixture rather than about the game. The cheap,
/// total question is "does an id appear next to a `playEvent` anywhere in
/// `lib/`", and that is exactly the question a deleted caller answers "no" to.
///
/// The cost of the scan is a constraint on the call sites: each id must be
/// written as a **literal** at the moment it means, never threaded through a
/// variable. That is why `combat_choreography.dart` carries a `StageCue` enum
/// rather than event-id strings, and why the reward and craft call sites
/// switch and then call rather than computing an id and passing it on.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/audio/audio_cues.dart';

/// Every `.dart` file under `lib/`, with its path.
List<(String, String)> _libSources() {
  final Directory lib = Directory('lib');
  // A plain throw, not `expect`: this runs while `main` is being built, and
  // an expectation outside a test body is an `OutsideTestException`.
  if (!lib.existsSync()) {
    throw StateError('no lib/ here — run this from the app root');
  }
  return <(String, String)>[
    for (final FileSystemEntity e in lib.listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart'))
        (e.path.replaceAll(r'\', '/'), e.readAsStringSync()),
  ];
}

void main() {
  final List<(String, String)> sources = _libSources();

  /// The files calling `playEvent('<event>')`, by exact literal.
  List<String> callersOf(String event) {
    // Both quote styles, because a formatter is allowed to change its mind
    // about which one a string wears.
    final RegExp call = RegExp(
      'playEvent\\(\\s*(?:\'${RegExp.escape(event)}\'|'
      '"${RegExp.escape(event)}")\\s*[,)]',
    );
    return <String>[
      for (final (String path, String text) in sources)
        if (call.hasMatch(text)) path,
    ];
  }

  test('every wired event is actually played by game code', () {
    // `ui.commit` is exempt from the *shape* only: it is fired through
    // `AudioEvents.commit`, the one-line convenience every primary-commit
    // press shares, so its literal lives at a single definition rather than
    // at each press. Its call sites are asserted separately below.
    final List<String> unwired = <String>[
      for (final String event in EventCues.all)
        if (event != 'ui.commit' && callersOf(event).isEmpty) event,
    ];
    expect(
      unwired,
      isEmpty,
      reason:
          'these events resolve, duck and arbitrate correctly and can never '
          'be heard, because nothing in lib/ calls playEvent for them: '
          '${unwired.join(", ")}. A cue table without a caller is silence '
          'with paperwork (FINAL-07 finding 1, MISTAKES.md M-16). Add the '
          'call at the game moment the id names, beside the haptic if there '
          'is one — do not relax this test.',
    );
  });

  test('ui.commit reaches game code through AudioEvents.commit', () {
    // The shared convenience must itself keep its one call to `playEvent`,
    // and at least one screen must still call the convenience — otherwise
    // the commit family is as dead as the twenty above were, and the
    // exemption in the previous test would hide it.
    expect(
      callersOf('ui.commit'),
      contains('lib/audio/audio_events.dart'),
      reason: 'AudioEvents.commit no longer fires the ui.commit cue',
    );
    final List<String> pressers = <String>[
      for (final (String path, String text) in sources)
        if (path != 'lib/audio/audio_events.dart' &&
            text.contains('AudioEvents.commit('))
          path,
    ];
    expect(
      pressers,
      isNotEmpty,
      reason:
          'no screen fires AudioEvents.commit, so every primary-commit press '
          'in the game is silent (FINAL-07 finding 2)',
    );
  });

  test('the combat events fire from the stage, not from a screen', () {
    // Placement, not merely existence. The fight's sounds belong to the
    // segment machine that also owns their timing — the same place the
    // heavy haptic fires — so a screen cannot start guessing when a blow
    // landed (`GAME_BIBLE/COMBAT/02` §10: a replay of facts already
    // durable).
    for (final String event in EventCues.combat.keys) {
      expect(
        callersOf(event),
        contains('lib/ui/screens/combat/combat_stage.dart'),
        reason: '$event must be fired by the stage that times it',
      );
    }
  });

  test('no event is played from a name the tables do not know', () {
    // The mirror of the test above: a call site that misspells its id is
    // silence that looks wired. `EventCues.of` returns null for an unknown
    // event and `playEvent` returns false, so nothing ever complains.
    final RegExp anyCall = RegExp(r'''playEvent\(\s*['"]([a-z0-9_.]+)['"]''');
    final Set<String> known = EventCues.all.toSet();
    for (final (String path, String text) in sources) {
      for (final RegExpMatch m in anyCall.allMatches(text)) {
        final String id = m.group(1)!;
        expect(
          known,
          contains(id),
          reason:
              '$path plays "$id", which is in no EventCues table — it '
              'resolves to null and is silence forever',
        );
      }
    }
  });
}
