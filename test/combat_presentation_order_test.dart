/// The presentation order of a combat round, frame by frame, against a real
/// session — the defect class the owner saw on the device.
///
/// `combat_ui_test.dart` proves the screen *after* every command has settled
/// (`tapAndSettle` pumps until the controller leaves busy), which is exactly
/// why it never saw this: the engine applies a round to in-memory state
/// synchronously and only the disk commit awaits, so on a device there is a
/// rendered frame **between the tap and the report** in which the committed
/// figures are already next round's and the report is still null. This file
/// pumps that frame deliberately and holds the screen to the contract:
///
/// - shown HP never snaps to the committed value before its beat's tween;
/// - shown player HP never increases inside an attack round (no heal-back);
/// - each wolf hit produces its own distinct decrease;
/// - the outcome panel never appears while the winning round still replays,
///   and a skip lands on the exact committed figures.
///
/// The screen is hosted directly under a [SessionScope] rather than through
/// `StrideApp`, so the file proves `CombatScreen` + `CombatStage` and nothing
/// above them.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/screens/combat/combat_screen.dart';
import 'package:stride/ui/screens/combat/combat_stage.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('stride_combat_order'),
  );
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// Boots inside `runAsync` (real file I/O never completes under
  /// `FakeAsync`), standing in the Whispering Woods — armed and armoured
  /// unless [armed] is false (an unarmed Traveler loses to the wolf's
  /// flurry, which is how the defeat presentation is reached).
  /// Since the VAWO01 weapon round, [armed] also decides which combat art
  /// the stage resolves: an unarmed Traveler goes down empty-handed on the
  /// `traveler_unarmed_*` strips, an armed one on the base set. The defeat
  /// cases below boot unarmed, so they assert the unarmed kneel — which is
  /// the stronger claim, because it is the loadout that actually loses.
  Future<StrideSession> boot(WidgetTester tester, {bool armed = true}) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    return (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(5000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      if (armed) {
        await s.equip(trainingSword);
        await s.equip(tunic);
      }
      final TravelReport t = await s.travel(woods);
      expect(t.succeeded, isTrue, reason: '${t.rejection}');
      return s;
    }))!;
  }

  Widget shell(SessionController c) => MediaQuery(
    data: const MediaQueryData(size: Size(393, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SessionScope(
        controller: c,
        child: const SingleChildScrollView(child: CombatScreen()),
      ),
    ),
  );

  /// The HUD's one exact `hp / max` figure for the combatant with [max].
  /// The log's prose never matches the exact pattern, so this cannot read a
  /// narration line by mistake.
  int shown(WidgetTester tester, int max) {
    final RegExp re = RegExp(
      r'^(\d+) / '
      '$max'
      r'$',
    );
    final List<int> hits = <int>[
      for (final Text t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data != null && re.hasMatch(t.data!))
          int.parse(re.firstMatch(t.data!)!.group(1)!),
    ];
    expect(hits, hasLength(1), reason: 'one HUD figure per combatant');
    return hits.single;
  }

  /// Waits for the in-flight command's commit to land — without pumping, so
  /// the frames around it stay under the test's control.
  Future<void> landCommit(WidgetTester tester, SessionController c) async {
    for (int i = 0; i < 500 && c.busy; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(c.busy, isFalse, reason: 'the command never returned');
  }

  void expectNonIncreasing(List<int> series, String what) {
    for (int i = 1; i < series.length; i++) {
      expect(
        series[i] <= series[i - 1],
        isTrue,
        reason:
            '$what rose mid-round — $series shows '
            '${series[i - 1]} → ${series[i]} at sample $i',
      );
    }
  }

  testWidgets('the in-flight frame keeps the pre-round figures, and the '
      'replay presents the wolf round in event order with no heal-back', (
    WidgetTester tester,
  ) async {
    final StrideSession s = await boot(tester);
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpWidget(shell(c));
    await tester.pumpAndSettle();
    expect(shown(tester, 40), 40);
    expect(shown(tester, 20), 20);

    // Attack. The engine resolves the round synchronously; the commit is
    // still in flight when the next frame builds — the frame the device
    // showed the snapped figures on.
    await tester.tap(find.text('Attack'));
    await tester.pump();
    expect(c.busy, isTrue, reason: 'the commit must still be in flight');
    expect(
      s.encounter!.playerHp,
      lessThan(40),
      reason: 'the round has already resolved in memory',
    );
    expect(
      shown(tester, 40),
      40,
      reason:
          'shown player HP must not snap to the committed value '
          'before the replay has presented the blows',
    );
    expect(
      shown(tester, 20),
      20,
      reason:
          'shown enemy HP must not snap to the committed value '
          'before the strike has landed',
    );
    // The in-flight state holds across frames, not just one.
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(tester, 40), 40);
    expect(shown(tester, 20), 20);

    // The commit lands and the report arrives: the replay begins from the
    // pre-round figures.
    await landCommit(tester, c);
    await tester.pump();
    final CombatReport report = c.lastCombat!;
    expect(report.succeeded, isTrue);
    final PlayerStruckBeat strike = report.events
        .whereType<PlayerStruckBeat>()
        .single;
    final List<EnemyStruckBeat> hits = report.events
        .whereType<EnemyStruckBeat>()
        .toList();
    expect(hits, hasLength(2), reason: 'the wolf is a flurry enemy');
    expect(shown(tester, 40), 40, reason: 'nothing has landed yet');
    expect(shown(tester, 20), 20);

    // Sample the whole replay. Player HP must never rise (the heal-back),
    // both bars must end on the committed figures, and each wolf hit must
    // show its own value on the way down.
    final List<int> player = <int>[40];
    final List<int> enemy = <int>[20];
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      player.add(shown(tester, 40));
      enemy.add(shown(tester, 20));
    }
    expectNonIncreasing(player, 'shown player HP');
    expectNonIncreasing(enemy, 'shown enemy HP');
    expect(player.last, hits.last.playerHpAfter);
    expect(enemy.last, strike.enemyHpAfter);
    expect(
      player,
      contains(hits.first.playerHpAfter),
      reason: 'the first wolf hit must produce its own distinct decrease',
    );
    // The player is not struck until the traveler's whole strike segment has
    // played (617 ms): the wolf replies only after being hit.
    for (int i = 0; i < 6; i++) {
      expect(
        player[i],
        40,
        reason: 'the wolf must not appear to strike before the traveler has',
      );
    }

    await tester.pumpAndSettle();
    expect(find.text('TURN 2'), findsOneWidget);
    expect(shown(tester, 40), hits.last.playerHpAfter);
    expect(shown(tester, 20), strike.enemyHpAfter);
  });

  testWidgets('the outcome panel waits for the winning replay, and a skip '
      'lands on the exact committed figures', (WidgetTester tester) async {
    final StrideSession s = await boot(tester);
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpWidget(shell(c));
    await tester.pumpAndSettle();

    for (int round = 0; round < 60 && s.encounter != null; round++) {
      await tester.tap(find.text('Attack'));
      await tester.pump();
      // The in-flight frame: never an outcome, never a vanished stage.
      expect(find.text('VICTORY'), findsNothing);
      expect(find.byType(CombatStage), findsOneWidget);

      await landCommit(tester, c);
      await tester.pump();
      if (c.lastCombat?.outcome is! WonBeat) {
        await tester.pumpAndSettle();
        continue;
      }

      // The winning report arrived this frame: the replay owns the screen
      // and the panel is not up yet.
      expect(
        find.text('VICTORY'),
        findsNothing,
        reason: 'the outcome panel must wait for the replay',
      );
      expect(find.byType(CombatStage), findsOneWidget);

      // Skip: the stage jumps to the exact committed end state and the
      // panel follows.
      await tester.tap(find.byType(CombatStage));
      await tester.pump();
      expect(shown(tester, 20), 0, reason: 'skip lands on committed figures');
      expect(find.text('VICTORY'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('VICTORY'), findsOneWidget);
      return;
    }
    fail('the wolf never fell');
  });

  testWidgets('DRIVEN BACK waits for the stagger and the settle — never the '
      'frame the shown HP reaches 0', (WidgetTester tester) async {
    final StrideSession s = await boot(tester, armed: false);
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpWidget(shell(c));
    await tester.pumpAndSettle();

    for (int round = 0; round < 60 && s.encounter != null; round++) {
      await tester.tap(find.text('Attack'));
      await tester.pump();
      expect(find.text('DRIVEN BACK'), findsNothing);
      expect(find.byType(CombatStage), findsOneWidget);

      await landCommit(tester, c);
      await tester.pump();
      if (c.lastCombat?.outcome is! LostBeat) {
        await tester.pumpAndSettle();
        continue;
      }

      // The losing report arrived this frame: the replay owns the screen and
      // the panel is not up.
      expect(find.text('DRIVEN BACK'), findsNothing);

      // Sample the whole defeat. The device defect was the panel appearing
      // with the 0 HP frame; now the killing blow settles the bar, the
      // Traveler staggers to a knee (1125 ms), the wolf holds its ground
      // over him (500 ms), and only then does the panel arrive.
      int zeroAt = -1;
      int panelAt = -1;
      bool sawStagger = false;
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('DRIVEN BACK').evaluate().isNotEmpty) {
          panelAt = i;
          break;
        }
        if (zeroAt < 0 && shown(tester, 40) == 0) zeroAt = i;
        sawStagger =
            sawStagger ||
            tester
                .widgetList<GroundedSprite>(find.byType(GroundedSprite))
                .any(
                  (GroundedSprite g) =>
                      g.assetPath.contains('traveler_unarmed_stagger'),
                );
      }
      expect(zeroAt, isNonNegative, reason: 'the killing blow must present');
      expect(panelAt, isNonNegative, reason: 'the panel must arrive unaided');
      expect(
        panelAt - zeroAt,
        greaterThanOrEqualTo(10),
        reason:
            'DRIVEN BACK must wait out the stagger and the settle '
            '(zero at sample $zeroAt, panel at sample $panelAt)',
      );
      expect(sawStagger, isTrue, reason: 'the Traveler must visibly go down');
      // The kneel outlasts the panel's arrival: overwhelmed, not dead.
      expect(
        tester
            .widgetList<GroundedSprite>(find.byType(GroundedSprite))
            .any(
              (GroundedSprite g) =>
                  g.assetPath.endsWith('traveler_unarmed_stagger_f8.png'),
            ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('DRIVEN BACK'), findsOneWidget);
      return;
    }
    fail('the wolf never won');
  });

  testWidgets('a tap on the stage mid-defeat lands on the committed figures '
      'with DRIVEN BACK shown', (WidgetTester tester) async {
    final StrideSession s = await boot(tester, armed: false);
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpWidget(shell(c));
    await tester.pumpAndSettle();

    for (int round = 0; round < 60 && s.encounter != null; round++) {
      await tester.tap(find.text('Attack'));
      await tester.pump();
      await landCommit(tester, c);
      await tester.pump();
      if (c.lastCombat?.outcome is! LostBeat) {
        await tester.pumpAndSettle();
        continue;
      }

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DRIVEN BACK'), findsNothing);

      // Skip: the stage jumps to the exact committed end state — HP 0, the
      // kneel held — and the panel follows at once.
      await tester.tap(find.byType(CombatStage));
      await tester.pump();
      expect(shown(tester, 40), 0, reason: 'skip lands on committed figures');
      expect(find.text('DRIVEN BACK'), findsOneWidget);
      expect(
        tester
            .widgetList<GroundedSprite>(find.byType(GroundedSprite))
            .any(
              (GroundedSprite g) =>
                  g.assetPath.endsWith('traveler_unarmed_stagger_f8.png'),
            ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('DRIVEN BACK'), findsOneWidget);
      return;
    }
    fail('the wolf never won');
  });
}
