// The step-sync reward moment: what a sync is allowed to celebrate.
//
// ## The two device faults this file exists for
//
// The owner's physical Adventure screen showed one card carrying both of
// them at once:
//
// ```text
// +0 STEPS BANKED
// Journey Ready
// Frostmere can now be reached.
// ```
//
// Neither line was true. Nothing had been banked, and Frostmere had been
// affordable for hours.
//
// - **"+0"** came from the banner reading `lastSync`, which the five-second
//   result timer clears while the banner itself waits — deliberately — for a
//   tap. The figure outlived its source.
// - **"can now be reached"** came from asking "what is true right now" after
//   the sync and celebrating the answer. Every standing fact re-announced
//   itself on every granting sync.
//
// A reward that fires when nothing happened devalues the one that fires when
// something did, so the rule these tests pin is: **a sync celebrates only
// what that sync made true, and says exactly what it banked.**

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

final ContentId woods = ContentId.unchecked('location.whispering_woods');

SyncFetch page(int steps, {required int index}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c$index'),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_reward'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A baselined session (DECISIONS/0019) tracking the Whispering Woods
  /// journey — 500 steps from Haven's Rest, so the threshold is crossable
  /// inside one page and the *second* page can be spent above it.
  Future<(StrideSession, SessionController)> boot(List<int> pages) async {
    final StrideSession session = (await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[
          SyncFetch(const NoChangeSync()),
          for (final (int i, int steps) in pages.indexed)
            page(steps, index: i),
        ],
      ),
    ));
    await session.syncSteps();
    expect(session.baselinePending, isFalse);
    expect(session.usableEnergy, 0);
    await session.trackGoal(GoalSlot.journey, woods);

    final SessionController c = SessionController(session);
    addTearDown(c.dispose);
    return (session, c);
  }

  test('crossing the threshold is the moment, and it is announced once', () async {
    final (StrideSession session, SessionController c) = await boot(<int>[
      600,
      400,
    ]);

    // Below → above. This is the transition, and the only sync entitled to
    // say "can now be reached".
    await c.syncSteps();
    expect(session.usableEnergy, 600);
    expect(
      c.lastOpportunities.map((SyncOpportunity o) => o.kind),
      <SyncOpportunityKind>[SyncOpportunityKind.journeyReady],
    );
    expect(c.lastOpportunities.single.detail, contains('Whispering Woods'));
    expect(c.lastOpportunityBanked, 600);

    c.acknowledgeOpportunities();

    // Above → further above. Real steps banked, nothing newly possible: the
    // sync feedback stays, the celebration does not repeat.
    await c.syncSteps();
    expect(session.usableEnergy, 1000);
    expect(c.lastSync!.newlyGranted, 400);
    expect(
      c.lastOpportunities,
      isEmpty,
      reason:
          'Journey Ready must fire on NOT READY → READY, not on every sync '
          'that happens while it is already true',
    );
    expect(c.lastOpportunityBanked, 0);
  });

  test('a sync that banks nothing celebrates nothing', () async {
    final (StrideSession session, SessionController c) = await boot(<int>[600]);

    await c.syncSteps();
    expect(c.lastOpportunities, isNotEmpty);
    c.acknowledgeOpportunities();

    // The script is exhausted; this sync grants zero. The owner's device
    // raised a full reward card here.
    await c.syncSteps();
    expect(c.lastSync!.newlyGranted, 0);
    expect(c.lastOpportunities, isEmpty);
    expect(c.lastOpportunityBanked, 0);
    expect(session.usableEnergy, 600);
  });

  test('the banner keeps its figure after the result timer clears the sync', () async {
    // The "+0" itself, reproduced exactly. The result timer nulls
    // `lastSync` five seconds in — by design, the sync line is transient —
    // while the opportunities banner is held for an explicit tap. Anything
    // the banner renders must therefore be owned by the banner.
    //
    // Waited in real time rather than faked: the controller's timer is armed
    // inside the session's real-I/O zone, where a fake clock does not reach.
    // Six seconds once is a fair price for the only test that can see this.
    final (StrideSession session, SessionController c) = await boot(<int>[600]);

    await c.syncSteps();
    expect(c.lastOpportunityBanked, 600);
    expect(c.lastSync, isNotNull);

    await Future<void>.delayed(const Duration(seconds: 6));

    expect(c.lastSync, isNull, reason: 'the sync line is transient');
    expect(
      c.lastOpportunities,
      isNotEmpty,
      reason: 'the reward waits for a tap, not for a clock',
    );
    expect(
      c.lastOpportunityBanked,
      600,
      reason: 'the banner must not read a figure the timer nulled',
    );
    expect(session.usableEnergy, 600);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
