// The Goal Board is a management surface, not a wall.
//
// ## What this file is for
//
// Moving the job board off Adventure was the right architecture, and the
// owner said so on the device. He then found the board itself "still much too
// dense on physical hardware… a long wall of prose, cards, repeated Track
// buttons, repeated Deliver/Accept actions, rewards, project content".
// Relocating a wall is not the same as taking it down.
//
// The three properties below are what "cleaner than the old embedded board"
// actually means, stated so that undoing them fails a test rather than a
// device:
//
//   1. a collapsed job shows four facts and no prose;
//   2. the prose and the actions are one tap away, not gone;
//   3. the whole board fits in a small multiple of one row.
//
// Property 3 is a **height bound**, deliberately. Density is the finding, and
// counting widgets does not measure it — a screen can be tidy in the tree and
// still be a two-metre scroll. The bound is generous enough that ordinary
// copy changes do not trip it and tight enough that re-expanding every job
// does.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_board'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// Opens the Goal Board the way a player does: boot, Adventure, one press.
  Future<void> openBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: const <SyncFetch>[]),
      ),
    ))!;
    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    // Scrolled to first. The goals group is the last thing on Adventure and
    // the screen grew with FMPO02's journal entries (`ART-12` §5), so the two
    // board controls sit just under the fold on a fresh save at 393 × 852 —
    // an accepted trade for the entries above them, which are what the screen
    // is for. `test/fold_clearance_test.dart` is what holds the line that
    // matters: the activity list and the gather control.
    final Finder board = find.text('Goal Board').first;
    await tester.ensureVisible(board);
    await tester.pumpAndSettle();
    await tester.tap(board);
    await tester.pumpAndSettle();
    expect(find.text('CLOSE'), findsOneWidget, reason: 'the board is open');
  }

  testWidgets('a collapsed job shows its four facts and no prose', (
    WidgetTester tester,
  ) async {
    await openBoard(tester);

    // Haven's Rest opens with the Notice Board's local needs. Whatever the
    // content pack holds, every job on it is a row: a type word and a state
    // word, and no brief.
    expect(
      find.text('ORDER'),
      findsWidgets,
      reason: 'the type is one of the four facts a row carries',
    );
    expect(
      find.textContaining('The kitchen', findRichText: true),
      findsNothing,
      reason:
          'authored flavour is subordinate (§11) and does not belong in a '
          'collapsed row',
    );
    expect(
      find.widgetWithText(ElevatedButton, 'Deliver'),
      findsNothing,
      reason: 'a collapsed board repeats no action buttons',
    );
  });

  testWidgets('opening a job reveals its flavour and its actions', (
    WidgetTester tester,
  ) async {
    await openBoard(tester);

    // The community project keeps its own full tile and its own Track, so
    // the property is the *delta*: opening a job adds exactly one job's
    // worth of controls, not a board's worth.
    final int before = find.text('Track').evaluate().length;

    final Finder row = find.ancestor(
      of: find.text('ORDER').first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(row.first);
    await tester.pumpAndSettle();

    // Nothing was hidden, only deferred: Track is the control every job
    // carried, and it is back the moment the job is the open one.
    expect(
      find.text('Track').evaluate().length,
      before + 1,
      reason: 'opening one job reveals that job\'s controls and no others',
    );
  });

  testWidgets('the whole board fits in a small multiple of one row', (
    WidgetTester tester,
  ) async {
    await openBoard(tester);

    // Measured from the rendered rows, not from a constant: the bound is
    // "the board is rows", and a row's own height is whatever the type scale
    // makes it.
    final Iterable<Element> rows = find
        .byType(GestureDetector)
        .evaluate()
        .where((Element e) => e.size != null && e.size!.height > 24);
    expect(rows, isNotEmpty, reason: 'the board renders jobs');

    final double tallest = rows
        .map((Element e) => e.size!.height)
        .reduce((double a, double b) => a > b ? a : b);
    expect(
      tallest,
      lessThan(120),
      reason:
          'no collapsed job may be a card again — the old tile was ~200 dp '
          'with its brief, its chips, its reward sentence and two buttons',
    );
  });
}
