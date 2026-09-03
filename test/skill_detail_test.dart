/// The Skill Detail roadmap (Fable V2 Iteration 03): a profession's whole
/// plannable future, derived from the same projections the card reads.
///
/// Held here: the card opens the route; the ladder shows the current
/// level, the next-with-content band's true XP distance, collapsed dead
/// runs, and the earned fold; an expanded unlock says what it yields and
/// what that feeds, pre-capped by the projection; the roadmap and the
/// card cannot disagree because both read `unlocksFor`'s one ordering.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/screens/skills/journey_model.dart';
import 'package:stride/ui/screens/skills/skill_detail_screen.dart';
import 'package:stride/ui/screens/skills/skills_screen.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart' show MockStepSource;

import 'support/real_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_roadmap'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<SessionController> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final StrideSession s = (await tester.runAsync(
      () => StrideSession.start(overrideRoot: root, source: MockStepSource()),
    ))!;
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);
    return c;
  }

  Widget shell(SessionController c, Widget child) => MaterialApp(
    home: SessionScope(controller: c, child: child),
  );

  test('the roadmap projection derives states, distance, and caps', () async {
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(),
    );

    final SkillRoadmap mining = s.skillRoadmapFor(
      ContentId.unchecked('skill.mining'),
    )!;
    expect(mining.standing.level, 1);
    // Level 1 is current; the next level with content is 2 (+10% copper),
    // and its distance is the curve's own threshold — 120 XP from zero.
    final RoadmapLevel current = mining.levels.first;
    expect(current.state, RoadmapLevelState.current);
    final RoadmapLevel next = mining.levels.firstWhere(
      (RoadmapLevel l) => l.state == RoadmapLevelState.next,
    );
    expect(next.level, 2);
    expect(next.xpAway, 120);
    // Only the next band carries a distance — a distance on every row is
    // the spreadsheet.
    expect(
      mining.levels.where((RoadmapLevel l) => l.xpAway != null),
      hasLength(1),
    );
    // The horizon is the last level content touches (Old Workings' bonus
    // at 10), never padded toward the curve's 20.
    expect(mining.levels.last.level, 10);

    // Detail lines are pre-capped at two, and a site entry names its
    // yield first.
    for (final RoadmapLevel level in mining.levels) {
      for (final SkillUnlock u in level.entries) {
        expect(
          u.detailLines.length,
          lessThanOrEqualTo(2),
          reason: u.displayName,
        );
        if (u.kind == SkillUnlockKind.site) {
          expect(u.detailLines.first, startsWith('Yields '));
          expect(u.trackableItem, isNotNull);
        }
      }
    }
  });

  // ---------------------------------------------------------------------
  // The journey model (EPO03, `DIR-07`): the grouping the road is placed
  // from, tested as the pure function it now is rather than through a
  // pumped screen.
  // ---------------------------------------------------------------------

  test('the journey folds empty runs and caps the road', () async {
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(),
    );
    final SkillRoadmap mining = s.skillRoadmapFor(
      ContentId.unchecked('skill.mining'),
    )!;
    final List<JourneyStop> stops = JourneyModel.from(mining);

    // Every joint the model places is a level the projection gave it, in the
    // projection's order, and no level number is invented or skipped.
    final List<int> covered = <int>[
      for (final JourneyStop stop in stops)
        if (stop is MilestoneStop)
          stop.level
        else if (stop is FoldStop) ...<int>[
          for (int l = stop.fromLevel; l <= stop.toLevel; l++) l,
        ],
    ];
    expect(covered, equals(List<int>.generate(10, (int i) => i + 1)));

    // The walker is at level 1, so exactly one joint is the lit cairn and
    // exactly one is the bronze-rimmed next stone carrying the distance.
    final List<MilestoneStop> milestones = stops
        .whereType<MilestoneStop>()
        .toList();
    expect(
      milestones.where((MilestoneStop m) => m.join == JoinState.current),
      hasLength(1),
    );
    final MilestoneStop nextStop = milestones.singleWhere(
      (MilestoneStop m) => m.join == JoinState.next,
    );
    expect(nextStop.level, 2);
    expect(nextStop.xpAway, 120);
    // A distance belongs to the next joint alone.
    expect(
      milestones.where((MilestoneStop m) => m.xpAway != null),
      hasLength(1),
    );

    // The road ends where content ends, with the projection's own sentence.
    expect(stops.last, isA<EndStop>());
    expect(
      (stops.last as EndStop).sentence,
      contains('The road runs out here'),
    );

    // Nothing is behind a level-1 walker, so there is no walked fold.
    expect(
      stops.whereType<FoldStop>().where(
        (FoldStop f) => f.kind == FoldKind.passed,
      ),
      isEmpty,
    );
  });

  testWidgets('the spine opens the route; the road reads as a journey', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, const SkillsScreen()));
    await tester.pumpAndSettle();

    // **The `ROADMAP` hint is gone from the list** (FMPO02, `ART-12` §4):
    // the whole 64 dp spine is the control, and a row that is entirely a
    // button does not need a word saying so. Five spines, one card.
    expect(find.text('ROADMAP'), findsNothing);
    expect(find.byType(SkillSpine), findsNWidgets(5));

    await tester.tap(find.text('Mining'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillDetailScreen), findsOneWidget);

    // **No card on the route at all** (EPO03, `DIR-07`): the owner's device
    // read named this screen for stacking rounded rectangles, and the two
    // `SectionCard`s and the box round every unlock are what it meant. The
    // page is the overview's own buckram, and the roadmap is a road.
    expect(find.byType(SectionCard), findsNothing);
    expect(find.byType(PageGround), findsOneWidget);
    expect(find.byType(JourneyTrack), findsOneWidget);

    // Position is said in words as well as in shape: the lit joint, the
    // bronze one's true distance, and the honest end of the road.
    expect(find.text('YOU ARE HERE'), findsOneWidget);
    expect(find.text('120 XP away'), findsOneWidget);
    expect(find.textContaining('The road runs out here'), findsOneWidget);

    // The trade's gauge is the head of the road, and the census line under
    // it is the projection's, not a count made here.
    expect(find.byType(TradeGauge), findsOneWidget);
    expect(find.textContaining('unlocks open'), findsOneWidget);

    // An entry carries its effect line collapsed — the roadmap is a plan you
    // read, not a list of names you have to open one at a time — and opening
    // it adds the rest of the projection's story and the Pursuit control.
    expect(find.textContaining('Yields Tin Ore'), findsWidgets);
    expect(find.text('Track as Pursuit'), findsNothing);
    await tester.tap(find.textContaining('Tin Seam at Stonefall').last);
    await tester.pumpAndSettle();
    expect(find.text('Track as Pursuit'), findsOneWidget);

    // CLOSE pops back to the five trades.
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillDetailScreen), findsNothing);
    expect(find.byType(SkillSpine), findsNWidgets(5));
  });
}
