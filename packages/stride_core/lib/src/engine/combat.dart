import 'package:meta/meta.dart';

import '../content/content_id.dart';

/// A fight in progress, as one immutable value inside `GameState`
/// (`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md` §9, `DECISIONS/0020` §1).
///
/// ## Snapshotted, not derived
///
/// The player's figures are computed by `CombatRules.loadoutFor` at encounter
/// start and copied here, so a fight is a closed system: swapping armour
/// mid-fight changes nothing until the next one, and a replay of the round's
/// events reproduces the committed HP without consulting content.
///
/// ## Always at the start of a player turn
///
/// One round — the player's action and the enemy's reply — is one command and
/// one commit (`DECISIONS/0020` §2). A durable `EncounterState` therefore never
/// records "the enemy owes you a hit"; [turn] is the number of the turn the
/// player is about to take.
@immutable
final class EncounterState {
  const EncounterState({
    required this.enemy,
    required this.location,
    required this.seed,
    required this.turn,
    required this.playerHp,
    required this.playerMaxHp,
    required this.playerAttack,
    required this.playerDefence,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.telegraph,
  });

  final ContentId enemy;

  /// Where the fight is happening. Recorded rather than read off the world so
  /// the encounter is self-describing after a reload.
  final ContentId location;

  /// Derived from the event sequence and the enemy id at encounter start; every
  /// roll in the fight is a pure function of it (`CombatRules.roll`).
  final int seed;

  /// 1-based. The turn the player is about to take.
  final int turn;

  final int playerHp;
  final int playerMaxHp;
  final int playerAttack;
  final int playerDefence;
  final int enemyHp;
  final int enemyMaxHp;

  /// True when the enemy's next reply is a heavy strike (guarded behaviour).
  /// Set at the end of the round *before* the heavy turn.
  final bool telegraph;

  EncounterState copyWith({
    int? turn,
    int? playerHp,
    int? enemyHp,
    bool? telegraph,
  }) => EncounterState(
    enemy: enemy,
    location: location,
    seed: seed,
    turn: turn ?? this.turn,
    playerHp: playerHp ?? this.playerHp,
    playerMaxHp: playerMaxHp,
    playerAttack: playerAttack,
    playerDefence: playerDefence,
    enemyHp: enemyHp ?? this.enemyHp,
    enemyMaxHp: enemyMaxHp,
    telegraph: telegraph ?? this.telegraph,
  );

  @override
  bool operator ==(Object other) =>
      other is EncounterState &&
      other.enemy == enemy &&
      other.location == location &&
      other.seed == seed &&
      other.turn == turn &&
      other.playerHp == playerHp &&
      other.playerMaxHp == playerMaxHp &&
      other.playerAttack == playerAttack &&
      other.playerDefence == playerDefence &&
      other.enemyHp == enemyHp &&
      other.enemyMaxHp == enemyMaxHp &&
      other.telegraph == telegraph;

  @override
  int get hashCode => Object.hash(
    enemy,
    location,
    seed,
    turn,
    playerHp,
    playerMaxHp,
    playerAttack,
    playerDefence,
    enemyHp,
    enemyMaxHp,
    telegraph,
  );

  @override
  String toString() =>
      'EncounterState($enemy@$location;seed=$seed;turn=$turn;'
      'player=$playerHp/$playerMaxHp atk $playerAttack def $playerDefence;'
      'enemy=$enemyHp/$enemyMaxHp${telegraph ? ';telegraph' : ''})';
}
