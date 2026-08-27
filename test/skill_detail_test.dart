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

  testWidgets('the card opens the route; the ladder reads as a plan', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, const SkillsScreen()));
    await tester.pumpAndSettle();

    // The cards carry the roadmap hint (the last may sit below the test
    // viewport's fold — the ListView is lazy); tapping one pushes the
    // route.
    expect(find.text('ROADMAP'), findsWidgets);
    await tester.tap(find.text('Mining'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillDetailScreen), findsOneWidget);
    // The route's own heading (SectionHeading renders uppercase).
    expect(find.text('ROADMAP'), findsOneWidget);

    // The current band, the next band's distance, and a collapsed dead
    // run are all on screen.
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('120 XP away'), findsOneWidget);
    expect(find.textContaining('nothing yet'), findsWidgets);

    // Expanding an unlock shows its pre-capped story and the Pursuit
    // control.
    await tester.tap(find.textContaining('Tin Seam at Stonefall').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Yields Tin Ore'), findsOneWidget);
    expect(find.text('Track as Pursuit'), findsOneWidget);

    // CLOSE pops back to the five trades.
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillDetailScreen), findsNothing);
    expect(find.text('ROADMAP'), findsWidgets);
  });
}
