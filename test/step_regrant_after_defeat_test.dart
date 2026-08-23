// The suspected duplicate Health-step grant after defeat and relaunch
// (`MILESTONES/PLAYABLE_EXPERIENCE_REFINEMENT_01.md` §0).
//
// ## The device observation
//
// About 3,000 banked → defeat away from Haven → retreat to Haven's Rest →
// the app fully closed → reopened → the bank reads about 6,000.
//
// ## What this file proves, and at which boundary
//
// Every case runs the REAL `StrideSession` over the REAL repository and file
// layout in a temp directory — the same commit, the same journal, the same
// slot selection a phone goes through — with the platform adapter replaced by
// `MockStepSource` so the *same Health samples* can be served again and again,
// exactly as HealthKit would restate an already-read hour. A "restart" here is
// a brand-new `StrideSession.start` over the same root: the in-memory engine
// is thrown away and everything is rebuilt from disk.
//
// The invariants under test (`RULES.md` H-1, H-2, H-3, H-5):
//
// | Case | Sequence | Must hold |
// |---|---|---|
// | A | same samples, restart, same samples | zero new grant |
// | B | same samples, defeat, save, restart, same samples | zero new grant |
// | C | same samples, defeat, manual sync before restart | zero duplicate |
// | D | defeat, restart repeatedly, same samples each time | zero every time |
// | E | after all that, genuinely new samples | granted exactly once |
//
// And beside them: retreat loses no inventory, equipment, skill XP or
// character XP; HP is restored at the safe destination; the adapter is read
// only when the session is explicitly asked (no background delivery); the
// economy epoch never moves; the persisted cursor is forward-only.
//
// ## The multi-origin characterisation at the end
//
// The last group does not test an invariant — it records how the ledger
// treats two origins reporting the same hour, because that is the one
// arithmetic path by which a bank can legitimately double on a phone that
// has more than one step source. See the milestone record for the verdict.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
final StepOriginKey watch = StepOriginKey('0f1e2d3c4b5a6978');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

/// The owner's "current-day steps": one origin, one closed hour, an absolute
/// figure. Served again, it is the same hour restated — the adapter's ordinary
/// answer for a bucket HealthKit re-reports.
SyncFetch todaysWalk({
  int steps = 3000,
  int index = 0,
  String cursor = 'c1',
  StepOriginKey? origin,
}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: origin ?? phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{origin ?? phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

/// The same hour restated through the RECOVERY path — what the adapter sends
/// when a persisted anchor cannot be honoured and the window is re-read
/// authoritatively. Absolute figures, per origin and bucket, no new cursor.
SyncFetch todaysWalkRescanned({int steps = 3000}) => SyncFetch(
  CursorInvalidatedSync(
    window: const RescanWindow(
      startMillis: t0 - 6 * hour,
      endMillis: t0 + 2 * hour,
      truncated: false,
    ),
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: const TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    completeness: RecoveryCompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0 - 6 * hour,
        intervalEndMillis: t0 + hour,
        queryGeneration: 2,
      ),
    ),
  ),
);

/// Everything the defeat must not touch, captured as comparable values.
typedef Possessions = ({
  String inventory,
  String skills,
  int level,
  int experience,
  String? weapon,
  String? armor,
  EconomyEpoch epoch,
  int totalGranted,
  int totalSpent,
  int banked,
});

Possessions possessionsOf(StrideSession s) {
  final StepLedger ledger = s.engine!.state.steps;
  final CombatFigures f = s.combatFigures;
  return (
    inventory: s.inventoryEntries
        .map((InventoryEntry e) => "${e.id.value}:${e.count}")
        .join(","),
    skills: s.skillSummaries
        .map((SkillSummary k) => "${k.id.value}:${k.experience}")
        .join(","),
    level: f.level,
    experience: f.experience,
    weapon: f.weaponName,
    armor: f.armorName,
    epoch: ledger.epoch,
    totalGranted: ledger.totalGranted,
    totalSpent: ledger.totalSpent,
    banked: ledger.banked,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_regrant'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A cold launch over [root]. The adapter is handed back so a case can
  /// enqueue the same samples later and count how often it was read.
  Future<(StrideSession, MockStepSource)> launch(List<SyncFetch> script) async {
    final MockStepSource source = MockStepSource(script: script);
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: source,
    );
    return (s, source);
  }

  /// A new game, baselined (`DECISIONS/0019`) and then credited with today's
  /// walk exactly once: 3,000 banked, standing at Haven's Rest.
  Future<(StrideSession, MockStepSource)> fundedGame() async {
    final (StrideSession s, MockStepSource source) = await launch(<SyncFetch>[
      SyncFetch(const NoChangeSync()),
      todaysWalk(),
    ]);
    await s.syncSteps(); // the baseline
    expect(s.baselinePending, isFalse);
    final SyncReport first = await s.syncSteps();
    expect(first.newlyGranted, 3000);
    expect(s.usableEnergy, 3000);
    return (s, source);
  }

  /// Walks to the Woods unarmed and fights the wolf until the encounter
  /// resolves — which, with attack 1 against a flurry, is a defeat.
  /// Returns what the walk there cost, so a case can frame the bank after
  /// the defeat against it: the travel debit is the only legitimate change.
  Future<int> loseToTheWolf(StrideSession s) async {
    final int bankedBefore = s.usableEnergy;
    expect((await s.travel(woods)).succeeded, isTrue);
    final int cost = bankedBefore - s.usableEnergy;
    expect(cost, greaterThan(0), reason: "travel spends banked steps");
    expect((await s.startEncounter(wolf)).succeeded, isTrue);
    for (int i = 0; i < 60 && s.encounter != null; i++) {
      final CombatReport r = await s.combatAttack();
      expect(r.succeeded, isTrue, reason: '${r.rejection}: ${r.detail}');
      final CombatBeat? outcome = r.outcome;
      if (outcome != null) {
        expect(outcome, isA<LostBeat>());
        expect((outcome as LostBeat).retreatToName, "Haven's Rest");
        return cost;
      }
    }
    fail('the fight did not resolve');
  }

  /// Defeat may change exactly two ledger figures — the travel debit, and the
  /// bank by the same amount — and nothing the player owns or has learned.
  void expectNothingLost(
    Possessions before,
    Possessions after, {
    required int spent,
  }) {
    expect(after.inventory, before.inventory, reason: 'inventory');
    expect(after.skills, before.skills, reason: 'skill XP');
    expect(after.level, before.level, reason: 'character level');
    expect(after.experience, before.experience, reason: 'character XP');
    expect(after.weapon, before.weapon, reason: 'weapon');
    expect(after.armor, before.armor, reason: 'armour');
    expect(after.epoch, before.epoch, reason: 'economy epoch');
    expect(after.totalGranted, before.totalGranted, reason: 'granted');
    expect(after.totalSpent, before.totalSpent + spent, reason: 'spent');
    expect(after.banked, before.banked - spent, reason: 'banked');
  }

  group('same samples are granted once, whatever happens in between', () {
    test('A: same samples → restart → same samples → zero new grant', () async {
      final (StrideSession s, MockStepSource source) = await fundedGame();
      final Possessions before = possessionsOf(s);
      final SyncCursor? cursorBefore = s.engine!.state.steps.checkpoint.cursor;

      // The same hour restated in the live session.
      source.enqueue(todaysWalk());
      final SyncReport replay = await s.syncSteps();
      expect(replay.status, SyncStatus.reconciled);
      expect(replay.newlyGranted, 0);
      expect(s.usableEnergy, 3000);

      // Restart: rebuilt from disk, then the same hour again.
      final (StrideSession again, MockStepSource source2) = await launch(
        <SyncFetch>[todaysWalk()],
      );
      expect(again.usableEnergy, 3000, reason: 'the disk holds the grant');
      final SyncReport afterRestart = await again.syncSteps();
      expect(afterRestart.newlyGranted, 0);
      expect(again.usableEnergy, 3000);
      expect(possessionsOf(again), before);
      expect(again.engine!.state.steps.checkpoint.cursor, cursorBefore);
      expect(source2.fetchCount, 1, reason: 'one read for one explicit sync');
    });

    test('A′: the same hour through the recovery path grants nothing', () async {
      final (StrideSession s, MockStepSource source) = await fundedGame();
      source.enqueue(todaysWalkRescanned());
      final SyncReport rescan = await s.syncSteps();
      expect(rescan.deliveryKind, 'recovery');
      expect(rescan.newlyGranted, 0);
      expect(s.usableEnergy, 3000);
    });

    test('B: same samples → defeat → save → restart → same samples → zero', () async {
      final (StrideSession s, _) = await fundedGame();
      final Possessions before = possessionsOf(s);
      final int maxHp = s.combatFigures.maxHp;

      final int cost = await loseToTheWolf(s);
      expect(s.currentLocation, haven);
      expect(s.encounter, isNull);
      expect(s.playerHp, maxHp, reason: 'safe rest restores HP on retreat');
      expectNothingLost(before, possessionsOf(s), spent: cost);

      // The process dies. The next launch reads the disk the defeat wrote.
      final (StrideSession again, MockStepSource source2) = await launch(
        <SyncFetch>[todaysWalk()],
      );
      expect(again.currentLocation, haven);
      expect(
        again.usableEnergy,
        3000 - cost,
        reason: 'the defeat save carries the ledger',
      );
      final SyncReport afterRestart = await again.syncSteps();
      expect(afterRestart.newlyGranted, 0);
      expect(again.usableEnergy, 3000 - cost);
      expect(again.totalGranted, before.totalGranted);
      expectNothingLost(before, possessionsOf(again), spent: cost);
      expect(again.playerHp, maxHp);
      expect(source2.fetchCount, 1);
    });

    test('C: same samples → defeat → manual sync before restart → zero', () async {
      final (StrideSession s, MockStepSource source) = await fundedGame();
      final Possessions before = possessionsOf(s);
      final int cost = await loseToTheWolf(s);

      source.enqueue(todaysWalk());
      final SyncReport manual = await s.syncSteps();
      expect(manual.newlyGranted, 0);
      expect(s.usableEnergy, 3000 - cost);
      expectNothingLost(before, possessionsOf(s), spent: cost);

      // And the restart after that manual sync is equally quiet.
      final (StrideSession again, _) = await launch(<SyncFetch>[todaysWalk()]);
      expect((await again.syncSteps()).newlyGranted, 0);
      expect(again.usableEnergy, 3000 - cost);
      expectNothingLost(before, possessionsOf(again), spent: cost);
    });

    test('D: defeat → restart repeatedly with the same samples → zero each time', () async {
      final (StrideSession s, _) = await fundedGame();
      final Possessions before = possessionsOf(s);
      final int cost = await loseToTheWolf(s);

      for (int relaunch = 1; relaunch <= 4; relaunch++) {
        final (StrideSession again, MockStepSource source) = await launch(
          <SyncFetch>[todaysWalk()],
        );
        // Two syncs a launch: the startup one and a manual one after it.
        final SyncReport startup = await again.syncSteps();
        source.enqueue(todaysWalk());
        final SyncReport manual = await again.syncSteps();
        expect(startup.newlyGranted, 0, reason: 'relaunch $relaunch, startup');
        expect(manual.newlyGranted, 0, reason: 'relaunch $relaunch, manual');
        expect(again.usableEnergy, 3000 - cost, reason: 'relaunch $relaunch');
        expect(again.totalGranted, before.totalGranted);
        expectNothingLost(before, possessionsOf(again), spent: cost);
        expect(
          again.engine!.state.steps.checkpoint.syncCount,
          greaterThan(0),
        );
      }
    });

    test('E: after all of that, genuinely new steps are granted exactly once', () async {
      final (StrideSession s, _) = await fundedGame();
      final int cost = await loseToTheWolf(s);
      final (StrideSession again, MockStepSource source) = await launch(
        <SyncFetch>[todaysWalk()],
      );
      expect((await again.syncSteps()).newlyGranted, 0);
      final int grantedBefore = again.totalGranted;

      // The same hour grows by 500 — the player kept walking inside it — and
      // a new hour arrives with 700. Absolute figures, as HealthKit reports.
      source.enqueue(todaysWalk(steps: 3500, cursor: 'c2'));
      source.enqueue(todaysWalk(steps: 700, index: 1, cursor: 'c3'));
      final SyncReport grown = await again.syncSteps();
      expect(grown.newlyGranted, 500);
      final SyncReport newHour = await again.syncSteps();
      expect(newHour.newlyGranted, 700);
      expect(again.usableEnergy, 3000 - cost + 500 + 700);
      expect(again.totalGranted, grantedBefore + 1200);

      // Replayed, both hours grant nothing more — in this launch or the next.
      source.enqueue(todaysWalk(steps: 3500, cursor: 'c2'));
      source.enqueue(todaysWalk(steps: 700, index: 1, cursor: 'c3'));
      expect((await again.syncSteps()).newlyGranted, 0);
      expect((await again.syncSteps()).newlyGranted, 0);
      final (StrideSession third, _) = await launch(<SyncFetch>[
        todaysWalk(steps: 3500, cursor: 'c2'),
        todaysWalk(steps: 700, index: 1, cursor: 'c3'),
      ]);
      expect((await third.syncSteps()).newlyGranted, 0);
      expect((await third.syncSteps()).newlyGranted, 0);
      expect(third.usableEnergy, 4200 - cost);
      expect(third.totalGranted, grantedBefore + 1200);
      expect(
        third.engine!.state.steps.checkpoint.cursor,
        SyncCursor.ofString('c3'),
        reason: 'the cursor is the furthest one authorised, never earlier',
      );
    });
  });

  group('the invariants around the sequence', () {
    test('the adapter is read only when the session is explicitly asked', () async {
      final (StrideSession s, MockStepSource source) = await fundedGame();
      final int readsAfterFunding = source.fetchCount;
      expect(readsAfterFunding, 2, reason: 'baseline + the walk');

      // Defeat, retreat, commits, projections: none of it reads Health.
      final int cost = await loseToTheWolf(s);
      s.encountersHere;
      s.inventoryEntries;
      s.combatFigures;
      expect(source.fetchCount, readsAfterFunding);

      // A relaunch reads nothing until asked either: the save is rendered
      // from disk first (`startup_sync_test.dart`), and the read is the
      // explicit foreground sync — never a background delivery (H-5).
      final (StrideSession again, MockStepSource source2) = await launch(
        <SyncFetch>[todaysWalk()],
      );
      expect(source2.fetchCount, 0);
      expect(again.usableEnergy, 3000 - cost);
      await again.syncSteps();
      expect(source2.fetchCount, 1);
    });

    test('the economy epoch never moves, and spending is the only debit', () async {
      final (StrideSession s, _) = await fundedGame();
      final EconomyEpoch epoch = s.engine!.state.steps.epoch;
      expect(epoch.isOrigin, isFalse, reason: 'the baseline set the mark');
      final int cost = await loseToTheWolf(s);
      expect(s.engine!.state.steps.epoch, epoch);
      final (StrideSession again, _) = await launch(<SyncFetch>[todaysWalk()]);
      await again.syncSteps();
      expect(again.engine!.state.steps.epoch, epoch);
      expect(again.totalSpent, cost, reason: 'the walk there, and nothing else');
    });

    test('equipped gear survives defeat and relaunch', () async {
      final (StrideSession s, _) = await fundedGame();
      expect((await s.equip(trainingSword)).succeeded, isTrue);
      expect((await s.equip(tunic)).succeeded, isTrue);
      // Armed, the wolf is beatable — so strip the sword back off for the
      // loss, and keep the tunic on to prove equipment survives.
      expect((await s.unequip(EquipmentSlot.weapon)).succeeded, isTrue);
      expect(s.combatFigures.armorName, 'Traveler Tunic');
      await loseToTheWolf(s);
      expect(s.combatFigures.armorName, 'Traveler Tunic');
      final (StrideSession again, _) = await launch(const <SyncFetch>[]);
      expect(again.combatFigures.armorName, 'Traveler Tunic');
      expect(
        again.inventoryEntries.any((InventoryEntry e) => e.id == trainingSword),
        isTrue,
        reason: 'the unequipped sword is still in the bag',
      );
    });
  });

  group('characterisation: two origins reporting the same hour', () {
    test('the ledger sums origins; a walk recorded by two devices banks twice', () async {
      final (StrideSession s, MockStepSource source) = await fundedGame();
      // A second source — a watch, a second phone, a third-party app writing
      // steps — reports the SAME hour. HealthKit's own merged total would
      // de-duplicate the overlap; the per-origin ledger cannot know it is
      // the same walk, so it credits the second origin in full.
      source.enqueue(todaysWalk(origin: watch, cursor: 'c2'));
      final SyncReport second = await s.syncSteps();
      expect(second.originCount, 1);
      expect(second.newlyGranted, 3000);
      expect(s.usableEnergy, 6000);
      // And it is stable: the same two origins again grant nothing more.
      source.enqueue(todaysWalk(cursor: 'c2'));
      source.enqueue(todaysWalk(origin: watch, cursor: 'c2'));
      expect((await s.syncSteps()).newlyGranted, 0);
      expect((await s.syncSteps()).newlyGranted, 0);
      expect(s.usableEnergy, 6000);

      // The instrument: the count of contributing sources is persisted with
      // the ledger and survives a relaunch — so a player whose bank doubled
      // can see that two sources built it, without either being named.
      expect(s.ledgerOriginCount, 2);
      final (StrideSession again, _) = await launch(const <SyncFetch>[]);
      expect(again.ledgerOriginCount, 2);
      expect(again.usableEnergy, 6000);
    });

    test('the banner names the source count only when it exceeds one', () async {
      // Funded small, so each sync below crosses a journey threshold and
      // raises the banner: 300 banked against the Woods' 500.
      final (StrideSession s, MockStepSource source) = await launch(<SyncFetch>[
        SyncFetch(const NoChangeSync()),
        todaysWalk(steps: 300),
      ]);
      await s.syncSteps();
      await s.syncSteps();
      expect(s.usableEnergy, 300);
      final SessionController c = SessionController(s);
      addTearDown(c.dispose);
      await s.trackGoal(GoalSlot.journey, woods);

      // One source, a threshold crossed: the banner shows, with no count.
      source.enqueue(todaysWalk(steps: 300, index: 1, cursor: 'c2'));
      await c.syncSteps();
      expect(c.lastOpportunityBanked, 300);
      expect(c.lastOpportunityOrigins, 1);
      c.acknowledgeOpportunities();
      expect(c.lastOpportunityOrigins, 0);

      // Two sources on one sync, and the next threshold crossed by their sum.
      await s.trackGoal(GoalSlot.journey, ContentId.unchecked('location.stonefall_mine'));
      source.enqueue(
        SyncFetch(
          IncrementalSync(
            observations: <StepObservation>[
              StepObservation.of(
                origin: phone,
                startMillis: t0 + 2 * hour,
                endMillis: t0 + 3 * hour,
                steps: 2000,
              ),
              StepObservation.of(
                origin: watch,
                startMillis: t0 + 2 * hour,
                endMillis: t0 + 3 * hour,
                steps: 2000,
              ),
            ],
            nextCursor: SyncCursor.ofString('c3'),
          ),
        ),
      );
      await c.syncSteps();
      expect(c.lastSync!.originCount, 2);
      if (c.lastOpportunities.isNotEmpty) {
        expect(c.lastOpportunityOrigins, 2);
      }
    });
  });
}
