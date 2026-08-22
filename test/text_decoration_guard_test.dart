// No string in this product is underlined, on any route.
//
// ## The defect this exists for
//
// `MaterialApp` supplies a theme but not a `Material`. Text with no `Material`
// ancestor inherits Flutter's fallback `DefaultTextStyle` — whose own debug
// label says "consider putting your text in a Material" — and that style
// carries `TextDecoration.underline`, in double yellow. Every `StrideType`
// role sets a colour, a size and a weight but never a `decoration`, so the
// fallback's decoration reaches all of them and the screen renders exactly as
// designed except for a yellow rule under every word.
//
// It has now been shipped **twice**. The first time it was the whole app, and
// the fix was a `Material` around `MaterialApp.home`. That fixed the tabs and
// left a trap: `home` is one route, and the Navigator builds a pushed route
// outside it. The Goal Board — the product's first full-screen push — walked
// into the trap, and the owner's device showed the whole surface underlined:
// title, headings, job titles, descriptions, rewards, buttons, CLOSE.
//
// ## Why no existing test saw it, either time
//
// Widget tests read strings, not their decoration. The golden harness loads a
// real font but the underline is a hairline against a 3× capture, and a
// reviewer comparing two goldens sees a diff, not a defect. Nothing in the
// suite ever asked the question this file asks.
//
// So the assertion is on the **resolved** style of every rendered `Text` —
// what the framework will actually paint, after inheritance — rather than on
// what any widget was constructed with. A screen can only pass this by
// genuinely having no underline anywhere in it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

/// Every `Text` in the tree, with the style it will actually be painted in.
///
/// `Text` merges its own style over the inherited `DefaultTextStyle` unless it
/// sets `style.inherit = false`, so this reproduces the framework's own
/// resolution rather than trusting either half of it.
Iterable<({String text, TextStyle style})> paintedText(WidgetTester tester) {
  return tester.widgetList<Text>(find.byType(Text)).map((Text t) {
    final BuildContext context = tester.element(find.byWidget(t));
    final TextStyle inherited = DefaultTextStyle.of(context).style;
    final TextStyle? own = t.style;
    return (
      text: t.data ?? t.textSpan?.toPlainText() ?? '<span>',
      style: own == null || own.inherit ? inherited.merge(own) : own,
    );
  });
}

/// The assertion itself, named so a failure says which screen and which word.
void expectNothingUnderlined(WidgetTester tester, String surface) {
  final List<String> offenders = <String>[
    for (final (:String text, :TextStyle style) in paintedText(tester))
      if (style.decoration != null &&
          style.decoration != TextDecoration.none)
        '"$text" (${style.decoration}, ${style.color})',
  ];
  expect(
    offenders,
    isEmpty,
    reason:
        '$surface renders ${offenders.length} underlined string(s). This is '
        'Flutter\'s missing-Material fallback, not a design choice — see the '
        'header of this file.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_decor'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    return (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: const <SyncFetch>[]),
      ),
    ))!;
  }

  testWidgets('the tab screens carry no underline', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);
    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    for (final String tab in <String>['ADVENTURE', 'CRAFT', 'WORLD', 'YOU']) {
      final Finder chip = find.text(tab);
      if (chip.evaluate().isEmpty) continue;
      await tester.tap(chip.first);
      await tester.pumpAndSettle();
      expectNothingUnderlined(tester, 'The $tab tab');
    }
  });

  testWidgets('the pushed Goal Board carries no underline', (
    WidgetTester tester,
  ) async {
    // The route the device fault was found on, reached the way the player
    // reaches it: a push out of Adventure, past the scopes, past `home`.
    final StrideSession session = await boot(tester);
    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    final Finder open = find.text('Goal Board');
    expect(
      open,
      findsWidgets,
      reason: 'Adventure must offer the one-press entry (§8)',
    );
    await tester.tap(open.first);
    await tester.pumpAndSettle();

    expect(find.text('CLOSE'), findsOneWidget, reason: 'the board is open');
    expectNothingUnderlined(tester, 'The pushed Goal Board');
  });
}
