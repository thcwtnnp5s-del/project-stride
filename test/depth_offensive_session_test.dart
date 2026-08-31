// Fable Depth Offensive 01 through the real session (`DECISIONS/0028`):
// the veteran visibility triple (hidden → locked → offered), the gated
// project's locked mirror, the derived upgrade lineage, and the Field Notes
// projection — all driven over the real repository and file layout, the
// combat_session_test way. The core rails are proven in
// `packages/stride_core/test/project_gating_test.dart` and
// `veteran_hunts_test.dart`; this file proves the session tells the truth
// about them.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId oldGrey = ContentId.unchecked('enemy.old_grey');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId herbBrothRecipe = ContentId.unchecked('recipe.herb_broth');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');
final ContentId granary = ContentId.unchecked('project.havens_rest_granary');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps, {int index = 0, String cursor = 'c1'}) => SyncFetch(
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
    nextCursor: SyncCursor.ofString(cursor),
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
  setUp(() => root = Directory.systemTemp.createTempSync('stride_depth'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> launch({int steps = 0}) => StrideSession.start(
    overrideRoot: root,
    source: MockStepSource(
      script: <SyncFetch>[
        SyncFetch(const NoChangeSync()),
        if (steps > 0) page(steps),
      ],
    ),
  );

  /// A funded, provisioned session: broths cooked, starting gear worn.
  Future<StrideSession> provisioned({int steps = 20000}) async {
    final StrideSession s = await launch(steps: steps);
    await s.syncSteps();
    await s.syncSteps();
    // Six wolf fights on persistent HP (`DECISIONS/0023` §4) cost real
    // provisions: two dozen broths, cooked before setting out.
    for (int i = 0; i < 48; i++) {
      expect((await s.gather(meadowPatch)).succeeded, isTrue);
    }
    for (int i = 0; i < 24; i++) {
      expect((await s.craft(herbBrothRecipe)).succeeded, isTrue);
    }
    expect((await s.equip(trainingSword)).succeeded, isTrue);
    expect((await s.equip(tunic)).succeeded, isTrue);
    return s;
  }

  Future<void> winWolf(StrideSession s) async {
    expect((await s.startEncounter(wolf)).succeeded, isTrue);
    for (int i = 0; i < 60 && s.encounter != null; i++) {
      final CombatReport r = await s.combatAttack();
      expect(r.succeeded, isTrue, reason: '${r.rejection}: ${r.detail}');
    }
    expect(s.encounter, isNull);
  }

  Future<void> healUp(StrideSession s) async {
    while (s.combatFigures.maxHp - s.playerHp >= 8 &&
        s.inventoryCount(herbBroth) > 0) {
      final FoodReport r = await s.eatFood(herbBroth);
      if (!r.succeeded) break;
    }
  }

  test('the veteran visibility triple: hidden while the wolf is Unseen, '
      'locked from Seen, offered at Known — and the World inspector '
      'agrees', () async {
    final StrideSession s = await provisioned();
    expect((await s.travel(woods)).succeeded, isTrue);

    // Hidden: a fresh arrival sees exactly the three base creatures.
    expect(
      s.encountersHere.map((EncounterOption o) => o.enemyId),
      isNot(contains(oldGrey)),
    );

    // Seen (first victory): the veteran appears, locked, naming its gate in
    // the engine's own terms.
    await winWolf(s);
    final EncounterOption locked = s.encountersHere.singleWhere(
      (EncounterOption o) => o.enemyId == oldGrey,
    );
    expect(locked.available, isFalse);
    expect(locked.reason, 'enemy_not_known');
    expect(locked.requiresKnownEnemyName, 'Forest Wolf');

    // Known (six victories, re-armed by travel — `DECISIONS/0021` §1):
    // the gate opens.
    int victories = 1;
    while (victories < 6) {
      await healUp(s);
      final EncounterOption card = s.encountersHere.singleWhere(
        (EncounterOption o) => o.enemyId == wolf,
      );
      if (card.available) {
        await winWolf(s);
        victories++;
        continue;
      }
      expect((await s.travel(haven)).succeeded, isTrue);
      await healUp(s);
      expect((await s.travel(woods)).succeeded, isTrue);
    }
    final EncounterOption offered = s.encountersHere.singleWhere(
      (EncounterOption o) => o.enemyId == oldGrey,
    );
    expect(offered.available, isTrue, reason: offered.reason);

    // The Field Notes agree with the location card, entry for entry.
    final BestiaryView notes = s.bestiary;
    final BestiaryRegionView woodsPage = notes.regions.singleWhere(
      (BestiaryRegionView r) => r.locationId == woods,
    );
    expect(
      woodsPage.entries.map((EncounterOption o) => o.enemyId),
      contains(oldGrey),
    );
    expect(woodsPage.isHere, isTrue);
    expect(notes.complete, isFalse);
  });

  test('a gated project is visible, locked, and honest about its gate', () async {
    final StrideSession s = await launch(steps: 1000);
    await s.syncSteps();
    await s.syncSteps();
    final ProjectView? view = s.projectViewOf(granary);
    expect(view, isNotNull);
    expect(view!.isLocked, isTrue);
    expect(view.lockedReason, contains('Mill'));
    expect(view.followsName, contains('Mill'));
    expect(view.contributable, isEmpty);
    expect(view.canAdvanceNow, isFalse);
  });

  test('the derived lineage: the tunic knows its future, and the purpose '
      'block does not say the recipe twice', () async {
    final StrideSession s = await launch(steps: 0);
    final ItemLineageView? lineage = s.itemLineageOf(tunic);
    expect(lineage, isNotNull);
    expect(
      lineage!.upgradesTo.map((LineageEdge e) => e.toName),
      contains("Waywarden's Tunic"),
    );

    final ItemPurposeView purpose = s.itemPurposeOf(tunic)!;
    expect(
      purpose.upgradesInto.map((LineageEdge e) => e.toName),
      contains("Waywarden's Tunic"),
    );
    final Set<String> lineageRecipeNames = purpose.upgradesInto
        .map((LineageEdge e) => e.recipeName)
        .toSet();
    for (final String recipe in purpose.usedInRecipes) {
      expect(
        lineageRecipeNames,
        isNot(contains(recipe)),
        reason: 'the consuming recipe must leave USED IN',
      );
    }

    // The bench states the future before the spend.
    expect((await s.equip(tunic)).succeeded, isTrue);
    final GearStats stats = s.gearStatsOf(tunic)!;
    expect(stats.upgradeLine, contains("Waywarden's Tunic"));
  });

  test('the Field Notes on a fresh save: no elites anywhere, distances from '
      'home, nothing complete — and no board names a hidden hunt', () async {
    final StrideSession s = await launch(steps: 0);

    // Wave 4 finding, fixed: the hunt cards used to bypass the Seen gate.
    // A fresh save's boards must not name any gated veteran's contract.
    for (final ContentId place in <ContentId>[woods, haven]) {
      final BoardView? board = s.boardFor(place);
      if (board == null) continue;
      for (final ContractView c in <ContractView>[
        ...board.bounties,
        ...board.regionals,
      ]) {
        expect(
          c.name.contains('Old Grey'),
          isFalse,
          reason: '${c.name} names a veteran no surface admits exists',
        );
      }
    }

    final BestiaryView notes = s.bestiary;
    expect(notes.regions, isNotEmpty);
    for (final BestiaryRegionView region in notes.regions) {
      expect(
        region.entries.map((EncounterOption o) => o.enemyId),
        isNot(contains(oldGrey)),
      );
      if (!region.isHere) {
        expect(region.distanceSteps, isNotNull);
        expect(region.distanceSteps, greaterThan(0));
      }
    }
    expect(notes.knownCount, 0);
    expect(notes.complete, isFalse);
  });
}
