/// The visible-equipment foundation's contract
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5): the projection derives
/// from the same equipped state the engine consults, changing equipment
/// changes the value, the resolver is total with the base strips as its
/// floor — and, this pass, behaviorally inert: with the variant tables
/// empty, every resolution is byte-identical to the art every surface drew
/// before the seam existed.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/icons/traveler_art.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId kSword = ContentId.unchecked('item.training_sword');
final ContentId kTunic = ContentId.unchecked('item.traveler_tunic');
final ContentId kAxe = ContentId.unchecked('item.training_axe');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_equipvis'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> boot() => StrideSession.start(
    overrideRoot: root,
    source: MockStepSource(script: <SyncFetch>[SyncFetch(const NoChangeSync())]),
  );

  test('the projection derives from the engine\'s own equipped state', () async {
    final StrideSession session = await boot();
    expect(session.equipmentVisualState, EquipmentVisualState.none);

    await session.equip(kSword);
    await session.equip(kTunic);
    await session.equip(kAxe);

    final EquipmentVisualState state = session.equipmentVisualState;
    expect(state.weapon?.itemId, 'item.training_sword');
    expect(state.weapon?.toolKind, 'none');
    expect(state.armor?.itemId, 'item.traveler_tunic');
    expect(state.tool?.itemId, 'item.training_axe');
    expect(state.tool?.toolKind, 'axe');
    expect(state.tool?.tier, 0);

    // The projection agrees with the summary over the same map.
    final List<EquippedSummary> summary = session.equippedSummary;
    expect(summary.map((EquippedSummary e) => e.itemId.value),
        containsAll(<String>[kSword.value, kTunic.value, kAxe.value]));
  });

  test('changing equipment changes the value; an unchanged loadout is equal',
      () async {
    final StrideSession session = await boot();
    await session.equip(kSword);
    final EquipmentVisualState before = session.equipmentVisualState;
    final EquipmentVisualState again = session.equipmentVisualState;
    expect(again, before, reason: 'derived twice, equal by value');

    await session.unequip(EquipmentSlot.weapon);
    expect(session.equipmentVisualState, isNot(before));
    expect(session.equipmentVisualState.weapon, isNull);
  });

  test('the resolver is total, and honest about what is held', () async {
    final StrideSession session = await boot();
    await session.equip(kSword);
    await session.equip(kTunic);

    // The lie the VAWO01 weapon round existed to remove: an empty weapon slot
    // used to fall through to the base set, whose 28 frames all bake a sword.
    expect(
      TravelerArt.combatantFor(EquipmentVisualState.none),
      same(CombatAssets.travelerUnarmed),
      reason: 'nothing equipped must draw empty hands',
    );

    // The training sword keeps the base set, and that is the truth for it —
    // the baked blade is a plain steel training sword.
    expect(
      TravelerArt.combatantFor(session.equipmentVisualState),
      same(CombatAssets.traveler),
    );

    // The bronze-tier blades that share the bronze set — which, since EPO03,
    // is no longer all of them. `item.bronze_longsword` moved to its own
    // `weapon.longsword` class: DIR-08's first failure was that the epic
    // longsword *was* the uncommon bronze sword, one blade shape in one
    // colour, so the reward at the end of a crafting chain looked exactly
    // like the ingredient that went into it. Its own assertion is below.
    // `item.fanghilt_sword` is still honestly bronze — the fang class is
    // named in the matrix and unauthored, and the bronze blade it is a
    // variant of is the nearest true picture of it.
    for (final String id in <String>[
      'item.bronze_sword',
      'item.fanghilt_sword',
    ]) {
      expect(
        TravelerArt.combatantFor(
          EquipmentVisualState(
            weapon: EquippedVisualFact(itemId: id, tier: 1, toolKind: 'none'),
          ),
        ),
        same(CombatAssets.travelerBronze),
        reason: '$id draws the bronze blade it is',
      );
    }

    // The longsword draws a longer blade, and it is a different strip — not
    // the bronze set under another name, which is what the round exists to
    // end. Checked as art rather than as identity so the assertion survives a
    // re-author: no frame of the longsword idle may be a bronze-set frame.
    final CombatantArt longsword = TravelerArt.combatantFor(
      const EquipmentVisualState(
        weapon: EquippedVisualFact(
          itemId: 'item.bronze_longsword',
          tier: 1,
          toolKind: 'none',
        ),
      ),
    );
    expect(longsword, isNot(same(CombatAssets.travelerBronze)));
    expect(longsword.idle.frame(0), contains('longsword'));
    expect(
      longsword.idle.track.frames.toSet().intersection(
        CombatAssets.travelerBronze.idle.track.frames.toSet(),
      ),
      isEmpty,
      reason: 'the longsword is still drawing the bronze sword\'s frames',
    );

    // An *equipped* item no table knows still degrades to the base rather than
    // to a hole (`RULES.md` E-5) — unlike an empty slot, which is a value.
    expect(
      TravelerArt.combatantFor(
        const EquipmentVisualState(
          weapon: EquippedVisualFact(
            itemId: 'item.not_in_any_pack',
            tier: 9,
            toolKind: 'none',
          ),
        ),
      ),
      same(CombatAssets.traveler),
      reason: 'base combat set, never null, never faked',
    );

    for (final EquipmentVisualState state in <EquipmentVisualState>[
      EquipmentVisualState.none,
      session.equipmentVisualState,
    ]) {
      expect(TravelerArt.walkWestFor(state),
          TravelerArt.travelerWalkWestFrames,
          reason: 'base walk, never null');
    }

    // The base walk is the exact strip the card always drew.
    expect(TravelerArt.travelerWalkWestFrames, <String>[
      for (int i = 0; i < 6; i++) 'assets/art/v1/anim/traveler_walk_west_f$i.png',
    ]);
  });

  test('reading the projection commits nothing', () async {
    final StrideSession session = await boot();
    await session.equip(kSword);
    final Map<EquipmentSlot, ContentId> before =
        Map<EquipmentSlot, ContentId>.of(
      session.engine!.state.equipment.bySlot,
    );
    // Read repeatedly; derive-on-read must not write, migrate, or move
    // anything in the state it projects.
    for (int i = 0; i < 3; i++) {
      session.equipmentVisualState;
    }
    expect(session.engine!.state.equipment.bySlot, before);
  });
}
