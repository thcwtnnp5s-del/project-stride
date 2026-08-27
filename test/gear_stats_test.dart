// Gear is evaluable without guessing (PLAYABLE_POLISH_01 §6).
//
// `gearStatsOf` is the one projection the Inventory tile and the Craft
// detail both read, so the bag and the bench cannot disagree about a piece.
// These cases pin its verdicts to content figures the engine itself reads
// (`combat_rules.dart` takes `weapon.power` and `armor.power`; a tool's
// worth is the tier its kind opens), and pin the tile line's wording.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/gear_stats.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId wolfhide = ContentId.unchecked('item.wolfhide_jerkin');
final ContentId frostlined = ContentId.unchecked('item.frostlined_jerkin');
final ContentId reinforcedPick = ContentId.unchecked('item.reinforced_pickaxe');
final ContentId herb = ContentId.unchecked('item.meadow_herb');
final ContentId trainingAxe = ContentId.unchecked('item.training_axe');
final ContentId trainingPick = ContentId.unchecked('item.training_pickaxe');
final ContentId bronzeAxe = ContentId.unchecked('item.bronze_axe');
final ContentId bronzePick = ContentId.unchecked('item.bronze_pickaxe');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_gear'));
  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  /// A synced session wearing the training sword and tunic from the bag —
  /// a fresh Traveler carries them, and equips nothing on their own.
  Future<StrideSession> boot() async {
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync())],
      ),
    );
    await s.syncSteps();
    for (final ContentId item in <ContentId>[trainingSword, tunic]) {
      final EquipReport on = await s.equip(item);
      expect(on.succeeded, isTrue, reason: on.rejection);
    }
    return s;
  }

  test('a material has no gear stats; equipment has its slot stat', () async {
    final StrideSession s = await boot();
    expect(s.gearStatsOf(herb), isNull);

    final GearStats sword = s.gearStatsOf(bronzeSword)!;
    expect(sword.slot, EquipmentSlot.weapon);
    expect(sword.statName, 'Attack');
    expect(sword.power, 9);
  });

  test('the verdict is against what is worn in the slot', () async {
    final StrideSession s = await boot();
    final GearStats worn = s.gearStatsOf(trainingSword)!;
    expect(worn.verdict, GearVerdict.equipped);
    expect(GearStatLine.textOf(worn), 'ATK 3');

    final GearStats better = s.gearStatsOf(bronzeSword)!;
    expect(better.verdict, GearVerdict.upgrade);
    expect(better.wornName, 'Training Sword');
    expect(better.wornPower, 3);
    expect(better.deltaLabel, '+6');
    expect(GearStatLine.textOf(better), 'ATK 9 +6');

    // Armour compares against the tunic (2): a jerkin at 4 is +2.
    final GearStats jerkin = s.gearStatsOf(wolfhide)!;
    expect(jerkin.statName, 'Defence');
    expect(jerkin.verdict, GearVerdict.upgrade);
    expect(jerkin.deltaLabel, '+2');
  });

  test('passives are spelled out in player words', () async {
    final StrideSession s = await boot();
    expect(
      s.gearStatsOf(frostlined)!.passives,
      contains('Cold weather: −2 damage taken in alpine fights'),
    );
    expect(
      s.gearStatsOf(wolfhide)!.passives.single,
      'Wilderness ready: 10% chance of +1 yield when woodcutting or foraging',
    );
    final GearStats pick = s.gearStatsOf(reinforcedPick)!;
    expect(pick.passives, contains('Works mining sites up to tier 2'));
    expect(
      pick.passives,
      contains('15% chance of +1 yield at sites this tool works'),
    );
  });

  test(
    'a tool names the sites it opens, and the site the next tier would',
    () async {
      // The physical-device polish pass, item 5: "Tier 1" is functional;
      // naming the sites is a reason to want the tool. Both lines read the
      // same node fields the engine gates a gather with.
      final StrideSession s = await boot();

      // Tier 0 pick: the two open seams, and the tier-1 site as the gap —
      // the Deep Tin Seam (`DECISIONS/0027`) is the Bronze Pickaxe's first
      // reason to exist, so the gap line finally names a tier-1 want.
      final GearStats training = s.gearStatsOf(trainingPick)!;
      expect(training.passives, contains('Mines: Copper Seam, Tin Seam'));
      expect(training.passives, contains('Tier 1 opens Deep Tin Seam'));

      // Tier 2 pick: every pickaxe site — Iteration 03's Old Workings
      // included — and no gap line; the pack holds nothing above tier 2.
      final GearStats reinforced = s.gearStatsOf(reinforcedPick)!;
      expect(
        reinforced.passives,
        contains(
          'Mines: Copper Seam, Tin Seam, Deep Tin Seam, Hardened Copper '
          'Seam, Old Workings',
        ),
      );
      expect(
        reinforced.passives.where((String p) => p.startsWith('Tier ')),
        isEmpty,
      );

      // Axes read the same way, in their own verb — and the bronze axe now
      // has a want above it too (`DECISIONS/0027`: the Old-Growth Frostpine
      // is the Hornbound Bronze Axe's job).
      final GearStats axe = s.gearStatsOf(trainingAxe)!;
      expect(axe.passives, contains('Chops: Oak Stand'));
      expect(axe.passives, contains('Tier 1 opens Frostpine Stand'));
      expect(
        s.gearStatsOf(bronzeAxe)!.passives,
        contains('Chops: Oak Stand, Frostpine Stand, Heartwood Oak'),
      );
      expect(
        s.gearStatsOf(bronzeAxe)!.passives,
        contains('Tier 2 opens Old-Growth Frostpine'),
      );
    },
  );

  test(
    'an axe over a pickaxe is a TOOL SWAP, never a power comparison',
    () async {
      final StrideSession s = await boot();
      expect((await s.equip(trainingPick)).succeeded, isTrue);

      // The device case: Bronze Axe crafted while a pickaxe is worn. It is
      // not a sidegrade and there is no "Tool power 4 → 4".
      final GearStats axe = s.gearStatsOf(bronzeAxe)!;
      expect(axe.verdict, GearVerdict.toolSwap);
      expect(axe.verdictLabel, 'TOOL SWAP');
      expect(axe.profession, 'Woodcutting');
      expect(axe.tier, 1);
      expect(axe.wornName, 'Training Pickaxe');
      expect(axe.wornToolKind, ToolKind.pickaxe);
      expect(axe.wornTier, 0);
      expect(axe.deltaLabel, isNull, reason: 'no figure is compared');
      expect(GearStatLine.textOf(axe), 'TIER 1');

      // The same profession compares by tier: a bronze pickaxe over the
      // training pickaxe is an upgrade; the training pickaxe over bronze a
      // downgrade; worn is worn.
      expect(s.gearStatsOf(bronzePick)!.verdict, GearVerdict.upgrade);
      expect(s.gearStatsOf(trainingPick)!.verdict, GearVerdict.equipped);
      // Nothing is worn in the tool slot once the pickaxe comes off: the axe
      // is then first in an empty slot, not a swap.
      expect((await s.unequip(EquipmentSlot.tool)).succeeded, isTrue);
      expect(s.gearStatsOf(trainingAxe)!.verdict, GearVerdict.firstInSlot);
    },
  );

  test('a tool is described by what it opens, not by a figure', () async {
    final StrideSession s = await boot();
    final GearStats pick = s.gearStatsOf(reinforcedPick)!;
    expect(pick.slot, EquipmentSlot.tool);
    expect(pick.profession, 'Mining');
    expect(GearStatLine.textOf(pick), 'TIER 2');
    expect(s.gearStatsOf(bronzeSword)!.profession, isNull);
  });

  test('a downgrade says so', () async {
    final StrideSession s = await boot();
    // Unequip the sword, wear nothing: the training sword is then the first
    // thing in an empty slot.
    final EquipReport off = await s.unequip(EquipmentSlot.weapon);
    expect(off.succeeded, isTrue, reason: off.rejection);
    expect(s.gearStatsOf(trainingSword)!.verdict, GearVerdict.firstInSlot);
    expect(GearStatLine.textOf(s.gearStatsOf(trainingSword)!), 'ATK 3');
  });
}
