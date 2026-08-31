/// The guard reading against the **engine**, not against a copy of it.
///
/// `combat_guard_reading_test.dart` sweeps 546 combinations, and every one of
/// them compares the projection to arithmetic hand-typed into that same test
/// file. Adversarial review named the hole exactly: if `_enemyReply` ever
/// gains a term the copy does not, both stay internally consistent, all 546
/// cases stay green, and the game promises 4 while dealing 11. The test would
/// be guarding the copy against the copy.
///
/// So this file fights. It boots a real session, starts a real encounter,
/// reads the reading the player would see, then issues the command and
/// asserts the damage the engine **actually emitted** falls where the reading
/// said it would — attacking and bracing, on a flurry enemy and on a guarded
/// one, on an ordinary turn and on a heavy turn.
///
/// If the resolver changes, this fails. That is the whole point.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey _phone = StepOriginKey('a1b2c3d4e5f60718');
const int _hour = 60 * 60 * 1000;
const int _t0 = 1750000000000;

SyncFetch _page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: _phone,
          bucket: TimeBucket(startMillis: _t0, endMillis: _t0 + _hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: _t0 + _hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{_phone}),
        intervalStartMillis: _t0,
        intervalEndMillis: _t0 + _hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId bear = ContentId.unchecked('enemy.oakback_bear');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stride_guard_live');
  });
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<StrideSession> funded() async {
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync()), _page(400000)],
      ),
    );
    // The real sync path: first fetch is the new-game baseline
    // (`DECISIONS/0019`), the second banks the page.
    await s.syncSteps();
    await s.syncSteps();
    expect((await s.equip(trainingSword)).succeeded, isTrue);
    expect((await s.equip(tunic)).succeeded, isTrue);
    return s;
  }

  /// Every damage figure the enemy actually dealt in [r].
  List<int> enemyDamage(CombatReport r) => r.events
      .whereType<EnemyStruckBeat>()
      .map((EnemyStruckBeat e) => e.damage)
      .toList();

  /// Fights [enemy] at [at] until the guard reading appears — i.e. until the
  /// creature is Studied — and leaves an encounter open with it.
  ///
  /// Victories are per-visit-limited, so this travels away and back to open a
  /// fresh visit rather than trying to grind one location.
  Future<StrideSession> studiedOn(ContentId enemy, ContentId at) async {
    final StrideSession s = await funded();
    // Victories are limited per VISIT, so reaching Studied means leaving and
    // coming back. Travel is best-effort here: a refusal (already there, or an
    // encounter still open) is a reason to try the other leg, not a failure —
    // what this helper asserts is only that the tier is eventually reached.
    for (int step = 0; step < 40; step++) {
      if (s.currentLocation != at) {
        await s.travel(at);
      }
      if (s.currentLocation == at) {
        final CombatReport open = await s.startEncounter(enemy);
        if (open.succeeded) {
          if (s.encounter?.guardReading != null) return s;
          while (s.encounter != null) {
            final CombatReport r = await s.combatAttack();
            if (!r.succeeded || r.outcome != null) break;
          }
          continue;
        }
      }
      // Cannot fight here right now: take a trip so the visit counter clears.
      await s.travel(haven);
    }
    fail('never reached Studied on ${enemy.value}');
  }


  test('an ATTACK round: every blow lands inside the band it promised', () async {
    final StrideSession s = await studiedOn(wolf, woods);
    final CombatGuardReading g = s.encounter!.guardReading!;

    final CombatReport r = await s.combatAttack();
    expect(r.succeeded, isTrue, reason: '${r.rejection}');

    final List<int> dealt = enemyDamage(r);
    expect(dealt, isNotEmpty, reason: 'the wolf did not reply');
    for (final int d in dealt) {
      expect(
        d,
        inInclusiveRange(g.lowest, g.highest),
        reason:
            'the reading promised ${g.lowest}–${g.highest} and the engine '
            'dealt $d',
      );
    }
    // A flurry: the reading must have said so, and said the round total.
    expect(g.strikes, dealt.length);
  });

  test('a BRACED round lands inside the braced band, not the ordinary one',
      () async {
    final StrideSession s = await studiedOn(wolf, woods);
    final CombatGuardReading g = s.encounter!.guardReading!;

    final CombatReport r = await s.combatBrace();
    expect(r.succeeded, isTrue, reason: '${r.rejection}');

    final List<int> dealt = enemyDamage(r);
    expect(dealt, isNotEmpty, reason: 'the wolf did not reply to a brace');
    for (final int d in dealt) {
      expect(
        d,
        inInclusiveRange(g.bracedLowest, g.bracedHighest),
        reason:
            'braced, the reading promised ${g.bracedLowest}–${g.bracedHighest} '
            'and the engine dealt $d',
      );
    }
  });

  // NOT covered here, and deliberately not faked: a **live** heavy round.
  //
  // Every guarded enemy in the game (bear 55/11/3, salamander 34/8/2, the
  // guardians) beats a starting-gear player, so a fixture that fights its way
  // to Studied on one cannot exist without first crafting through the bronze
  // ladder. The heavy case is instead covered exhaustively by the sweep in
  // `combat_guard_reading_test.dart` — which asserts exact equality, not a
  // band, for every guarded enemy on every armour at every turn of the cycle —
  // and by its explicit brace-before-frost-guard ordering case.
  //
  // Recorded as a gap rather than papered over: a geared live fixture is the
  // right way to close it, and it is worth doing when one exists for other
  // reasons.
}
