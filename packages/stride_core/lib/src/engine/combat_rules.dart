import 'dart:collection';

import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/content_registry.dart';
import '../content/definitions.dart';
import 'game_state.dart';

/// The player's combat figures for one encounter, as derived by
/// [CombatRules.loadoutFor] and snapshotted into `EncounterState`.
@immutable
final class PlayerCombatLoadout {
  const PlayerCombatLoadout({
    required this.maxHp,
    required this.attack,
    required this.defence,
    this.weaponItem,
    this.armorItem,
  });

  final int maxHp;
  final int attack;
  final int defence;

  /// The item in the weapon slot that counted, if any. Diagnostic; the figure
  /// is [attack].
  final ContentId? weaponItem;

  /// The item in the armor slot that counted, if any. Diagnostic; the figure
  /// is [defence].
  final ContentId? armorItem;

  @override
  bool operator ==(Object other) =>
      other is PlayerCombatLoadout &&
      other.maxHp == maxHp &&
      other.attack == attack &&
      other.defence == defence &&
      other.weaponItem == weaponItem &&
      other.armorItem == armorItem;

  @override
  int get hashCode =>
      Object.hash(maxHp, attack, defence, weaponItem, armorItem);

  @override
  String toString() =>
      'PlayerCombatLoadout(hp $maxHp, atk $attack, def $defence, '
      'weapon $weaponItem, armor $armorItem)';
}

/// The rules of the one player archetype and of a round of combat
/// (`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md` §4, §6; `DECISIONS/0020`).
///
/// ## Every figure here is PROVISIONAL test balance
///
/// These constants are rules of the single character archetype, not authored
/// content, which is why they live in code rather than in a content file. They
/// move to content the day a second archetype exists. Nothing here is a design
/// decision: `DECISIONS/0003` locked the *model*, and the numbers are the
/// slice's first guess, to be retuned after device play.
///
/// ## Pure
///
/// Every function is a pure function of its arguments. There is no `Random`
/// and no clock (`RULES.md` E-1): the roll is a small integer hash of the
/// encounter seed, the turn and a salt, so the same state and the same command
/// produce the same outcome, and a replay agrees with the original run.
abstract final class CombatRules {
  /// Max HP at level 1.
  static const int baseHealth = 40;

  /// Max HP gained per level above 1.
  static const int healthPerLevel = 4;

  /// Attack with nothing in the weapon slot.
  static const int unarmedAttack = 1;

  /// Cumulative character XP required for level 1..10. Level 10 is the cap.
  static const List<int> levelThresholds = <int>[
    0,
    100,
    300,
    600,
    1000,
    1500,
    2100,
    2800,
    3600,
    4500,
  ];

  /// The highest level whose threshold [experience] meets. Capped at 10.
  static int levelFor(int experience) {
    int level = 1;
    for (int i = 1; i < levelThresholds.length; i++) {
      if (experience >= levelThresholds[i]) level = i + 1;
    }
    return level;
  }

  /// `40 + 4 * (level - 1)`.
  static int maxHpFor(int level) => baseHealth + healthPerLevel * (level - 1);

  /// `(level - 1) ~/ 2`: a small, slow attack contribution from level.
  static int attackBonusFor(int level) => (level - 1) ~/ 2;

  /// The player's combat figures right now, from state and content.
  ///
  /// Weapon = the item in [EquipmentSlot.weapon] (`power`), else
  /// [unarmedAttack]; plus [attackBonusFor]. Defence = the item in
  /// [EquipmentSlot.armor] (`power`), else 0. **Tools never count**, whatever
  /// slot they occupy: an item whose own `slot` is not the slot it sits in, or
  /// whose `toolKind` is not `none`, contributes nothing, so a content pack
  /// that puts a hatchet in the weapon slot cannot make it a sword by accident.
  static PlayerCombatLoadout loadoutFor(
    GameState state,
    ContentRegistry registry,
  ) {
    final int level = state.player.level;

    final ContentId? weaponId = state.equipment.inSlot(EquipmentSlot.weapon);
    final ItemDefinition? weapon = weaponId == null
        ? null
        : registry.items[weaponId];
    final bool weaponCounts =
        weapon != null &&
        weapon.slot == EquipmentSlot.weapon &&
        weapon.toolKind == ToolKind.none;

    final ContentId? armorId = state.equipment.inSlot(EquipmentSlot.armor);
    final ItemDefinition? armor = armorId == null
        ? null
        : registry.items[armorId];
    final bool armorCounts =
        armor != null &&
        armor.slot == EquipmentSlot.armor &&
        armor.toolKind == ToolKind.none;

    return PlayerCombatLoadout(
      maxHp: maxHpFor(level),
      attack:
          (weaponCounts ? weapon.power : unarmedAttack) + attackBonusFor(level),
      defence: armorCounts ? armor.power : 0,
      weaponItem: weaponCounts ? weaponId : null,
      armorItem: armorCounts ? armorId : null,
    );
  }

  // -- The seeded resolver ---------------------------------------------------

  /// A 32-bit integer mix of ([seed], [turn], [salt]).
  ///
  /// FNV-1a over the three values' low four bytes each, then a final avalanche
  /// (murmur3's fmix32). Every intermediate is masked to 32 bits so the result
  /// is identical on the VM and on the web, where `int` loses precision past
  /// 2^53. Not cryptographic and not meant to be: it only has to be
  /// deterministic, well spread across salts and turns, and cheap.
  static int _mix(int seed, int turn, int salt) {
    const int mask = 0xFFFFFFFF;
    int h = 0x811C9DC5;
    void feed(int value) {
      int v = value & mask;
      for (int i = 0; i < 4; i++) {
        h ^= v & 0xFF;
        h = (h * 0x01000193) & mask;
        v >>= 8;
      }
    }

    feed(seed);
    feed(turn);
    feed(salt);
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & mask;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & mask;
    h ^= h >> 16;
    return h;
  }

  /// A deterministic roll in {-1, 0, +1} from the encounter [seed], the [turn]
  /// and a [salt] that tells one roll in a turn from another (the player's
  /// strike, the enemy's first strike, its second).
  static int roll(int seed, int turn, int salt) =>
      _mix(seed, turn, salt) % 3 - 1;

  /// A deterministic roll in 0..99, for drop chances: a drop lands when
  /// `percentRoll(seed, dropIndex, salt) < chancePercent`.
  static int percentRoll(int seed, int index, int salt) =>
      _mix(seed, index, salt) % 100;

  /// The encounter seed: the event sequence at start mixed with the enemy id.
  ///
  /// The sequence alone would give two different enemies started at the same
  /// point identical rolls; the id alone would give every fight with a wolf
  /// the same script. Together they make each encounter its own, and both are
  /// facts already in the state and the command, so no ambient input enters.
  static int seedFor(int eventSequence, ContentId enemy) {
    int h = 0x811C9DC5;
    for (final int unit in enemy.value.codeUnits) {
      h ^= unit & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return _mix(h, eventSequence, 0x5EED);
  }

  // -- Damage ----------------------------------------------------------------

  /// `max(1, attack - defence + roll)`. A hit always lands for at least 1.
  static int strike(int attack, int defence, int roll) {
    final int damage = attack - defence + roll;
    return damage < 1 ? 1 : damage;
  }

  /// A guarded enemy's heavy strike: `max(1, 2 * attack - defence)`, no roll.
  static int heavyStrike(int attack, int defence) {
    final int damage = 2 * attack - defence;
    return damage < 1 ? 1 : damage;
  }

  /// Whether a guarded enemy strikes heavy on [turn]: every third turn.
  static bool isHeavyTurn(int turn) => turn % 3 == 0;

  /// The salt of the player's strike in a round.
  static const int playerStrikeSalt = 1;

  /// The enemy's strikes use `enemyStrikeSalt + strikeIndex` (0 or 1).
  static const int enemyStrikeSalt = 2;

  // -- Retreat ---------------------------------------------------------------

  /// The nearest safe location by BFS over `LocationDefinition.connections`
  /// from where the player stands (`DECISIONS/0020` §4).
  ///
  /// If the current location is safe, it is the answer. Ties at the same
  /// depth break by [ContentId] ordering. If nothing safe is reachable, which
  /// the shipped content cannot produce but a pack could, the player stays
  /// put rather than being sent somewhere the graph does not connect.
  static ContentId retreatDestination(
    GameState state,
    ContentRegistry registry,
  ) {
    final ContentId start = state.world.currentLocation;
    final LocationDefinition? here = registry.locations[start];
    if (here == null || here.isSafe) return start;

    final Set<ContentId> seen = <ContentId>{start};
    List<ContentId> frontier = <ContentId>[start];
    while (frontier.isNotEmpty) {
      // Sorted, so the first safe location found at a depth is the least id.
      final SplayTreeSet<ContentId> next = SplayTreeSet<ContentId>();
      for (final ContentId id in frontier) {
        final LocationDefinition? location = registry.locations[id];
        if (location == null) continue;
        for (final LocationConnection c in location.connections) {
          if (seen.add(c.to)) next.add(c.to);
        }
      }
      for (final ContentId id in next) {
        if (registry.locations[id]?.isSafe ?? false) return id;
      }
      frontier = next.toList();
    }
    return start;
  }
}
