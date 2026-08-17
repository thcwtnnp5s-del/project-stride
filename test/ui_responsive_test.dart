/// Responsive layout, real-world values, and the regression proof for **D-01**.
///
/// ## Why this file exists rather than another overflow test
///
/// Playable Demo Phase 1 shipped five overflow tests, at 320 / 360 / 375 / 393 /
/// 430 dp, each asserting `tester.takeException()` is null. All five passed
/// while the header clipped the last digit off `455,281` on the owner's phone.
///
/// **They could not have caught it.** `TextOverflow.clip` paints no stripe and
/// raises no exception; a clipped `Text` is indistinguishable, to
/// `takeException`, from one that fits. The goldens could not catch it either —
/// they render `12,480`, which is six characters and fits the 72 dp box that
/// seven characters did not. `MISTAKES.md` M-06, third occurrence.
///
/// So this file asserts a **different kind of property**:
///
/// 1. **The string is whole.** The header's `Text.data` equals
///    `formatSteps(value)` in full — every digit and both separators.
/// 2. **The box is big enough for it.** For every single-line paragraph in the
///    tree, the width the text *needs* is compared against the width it was
///    *given*. That is measured off the live `RenderParagraph`, so it uses the
///    resolved style, the real scaler, and the actual laid-out box — no
///    assumption about font metrics is written down here.
///
/// (2) is the assertion D-01 would have failed. It is also screen-wide rather
/// than header-specific, because the fixed-box-around-growing-value shape was
/// never unique to the header.
///
/// ## The stress values are the owner's, not round numbers
///
/// `455,281` is the exact banked figure the defect was found at
/// (`MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md` §3). The rest bracket
/// it: the digit-count boundaries either side, and 9,999,999 as the practical
/// ceiling for a walking human.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/adaptive_text.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/screen_header.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/stride_typography.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

/// The supported width matrix.
const List<double> kWidths = <double>[320, 360, 393, 430];

/// Real-world banked values. `455,281` is the device-acceptance figure D-01 was
/// found at; the others are the digit-count boundaries around it.
const List<int> kBankedStress = <int>[
  0,
  999,
  12480,
  455281,
  999999,
  1000000,
  9999999,
];

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

/// Every single-line paragraph whose text is wider than the box it was given.
///
/// **This is the D-01 measurement.** `RenderParagraph.getMaxIntrinsicWidth` is
/// the width the string needs at its resolved style and the ambient scaler;
/// `size.width` is what layout actually handed it. When the first exceeds the
/// second, characters are not drawn — silently, with no exception and no
/// stripe.
///
/// Restricted to `maxLines == 1`, because a paragraph allowed to wrap is
/// *supposed* to be narrower than its natural single-line width; that is
/// wrapping, not clipping.
List<String> clippedLines(WidgetTester tester) {
  final List<String> found = <String>[];

  void visit(RenderObject node) {
    if (node is RenderParagraph && node.maxLines == 1) {
      final double needs = node.getMaxIntrinsicWidth(double.infinity);
      // Half a logical pixel of slack: layout rounds, and a subpixel excess is
      // not a missing character.
      if (needs > node.size.width + 0.5) {
        found.add(
          '"${node.text.toPlainText()}" needs '
          '${needs.toStringAsFixed(1)} dp and was given '
          '${node.size.width.toStringAsFixed(1)}',
        );
      }
    }
    node.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_responsive'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A cold launch with [banked] steps already synced and nothing spent.
  ///
  /// Real session, real reconciliation, real save — the figure under test is
  /// the one the engine produced, not a literal handed to a widget. A literal
  /// would make this test pass against a hardcoded readout, which is the defect
  /// class half of these files exist to catch.
  Future<StrideSession> bootWith(WidgetTester tester, int banked) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[if (banked > 0) page(banked)],
        ),
      ),
    ))!;
    if (banked > 0) await tester.runAsync(() => session.syncSteps());
    return session;
  }

  void sizeTo(WidgetTester tester, double width, {double height = 852}) {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget scaled(Widget child, double factor) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(factor)),
    child: child,
  );

  // =========================================================================
  // D-01 — the banked figure
  // =========================================================================

  group('D-01 · the banked-steps readout', () {
    for (final int banked in kBankedStress) {
      for (final double width in kWidths) {
        testWidgets(
          'renders ${formatSteps(banked)} whole at ${width.toInt()} dp',
          (WidgetTester tester) async {
            sizeTo(tester, width);
            final StrideSession session = await bootWith(tester, banked);
            expect(
              session.usableEnergy,
              banked,
              reason: 'the fixture must actually reach the stress value',
            );

            await tester.pumpWidget(StrideApp(session: session));
            await tester.pumpAndSettle();

            // 1. The whole string is present, character for character.
            final String expected = formatSteps(banked);
            final Finder figure = find.descendant(
              of: find.byType(BankedStepsReadout),
              matching: find.text(expected),
            );
            expect(
              figure,
              findsOneWidget,
              reason:
                  'the header must print $expected in full — this is the '
                  'assertion that fails when a digit is dropped',
            );

            // 2. And the box it was given is wide enough to draw it.
            //
            // At 72 dp with `TextOverflow.clip` — the shipped Phase 1 code —
            // `455,281` needed about 77 dp and got 72, and nothing anywhere
            // said so. This says so.
            final RenderParagraph paragraph = tester
                .renderObject<RenderParagraph>(figure);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason:
                  '$expected is clipped inside its own box at '
                  '${width.toInt()} dp',
            );

            // 3. And nothing else on the screen is clipped either.
            expect(clippedLines(tester), isEmpty);
          },
        );
      }
    }

    /// The stability the fixed 72 dp box was there to buy, kept.
    ///
    /// The point of the original `SizedBox` was that a growing figure must not
    /// shift the eyebrow beside it. Removing it outright would have traded a
    /// clipped digit for a header that jitters every time the player syncs, so
    /// the minimum width is still enforced — and this is what proves it, rather
    /// than the comment claiming it.
    testWidgets('short figures do not shift the header', (
      WidgetTester tester,
    ) async {
      sizeTo(tester, 393);

      final List<double> lefts = <double>[];
      for (final int banked in <int>[0, 90, 999]) {
        final Directory slot = Directory.systemTemp.createTempSync('stride_st');
        addTearDown(() {
          try {
            slot.deleteSync(recursive: true);
          } on FileSystemException {
            // Windows handle lag.
          }
        });
        final StrideSession session = (await tester.runAsync(
          () => StrideSession.start(
            overrideRoot: slot,
            source: MockStepSource(
              script: <SyncFetch>[if (banked > 0) page(banked)],
            ),
          ),
        ))!;
        if (banked > 0) await tester.runAsync(() => session.syncSteps());

        await tester.pumpWidget(StrideApp(session: session));
        await tester.pumpAndSettle();
        lefts.add(tester.getTopLeft(find.byType(BankedStepsReadout)).dx);
      }
      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        lefts.toSet(),
        hasLength(1),
        reason:
            'below the minimum width the readout must not move, or the '
            'eyebrow beside it shifts on every sync',
      );
    });
  });

  // =========================================================================
  // The whole app, at every width and every screen
  // =========================================================================

  group('every screen at every width', () {
    for (final double width in kWidths) {
      testWidgets('nothing clips at ${width.toInt()} dp with a real save', (
        WidgetTester tester,
      ) async {
        sizeTo(tester, width);
        // The device-acceptance figure, then a gather, so inventory and skill
        // XP are non-zero on the screens that show them.
        final StrideSession session = await bootWith(tester, 455281);
        await tester.runAsync(
          () =>
              session.gather(ContentId.unchecked('resource_node.meadow_patch')),
        );

        await tester.pumpWidget(StrideApp(session: session));
        await tester.pumpAndSettle();
        expect(clippedLines(tester), isEmpty, reason: 'Adventure');
        expect(tester.takeException(), isNull);

        for (final String tab in <String>['Character', 'Inventory', 'World']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(clippedLines(tester), isEmpty, reason: tab);
          expect(tester.takeException(), isNull, reason: tab);
        }
      });
    }
  });

  // =========================================================================
  // Text scaling
  // =========================================================================

  group('accessibility text scale', () {
    /// 1.0, 1.2 and 1.4 are the pass required by the facelift brief. The bar is
    /// *primary information must not be silently removed* — not that the layout
    /// is beautiful at 1.4.
    ///
    /// The tab bar is deliberately exempt: its labels run under
    /// `MediaQuery.withNoTextScaling`, an accessibility cost taken on purpose
    /// and documented in `stride_tab_bar.dart`, so they are not scaled and
    /// cannot clip.
    for (final double factor in <double>[1.0, 1.2, 1.4]) {
      for (final double width in <double>[320, 393]) {
        testWidgets('x$factor at ${width.toInt()} dp keeps every value whole', (
          WidgetTester tester,
        ) async {
          sizeTo(tester, width);
          final StrideSession session = await bootWith(tester, 455281);
          await tester.runAsync(
            () => session.gather(
              ContentId.unchecked('resource_node.meadow_patch'),
            ),
          );

          await tester.pumpWidget(scaled(StrideApp(session: session), factor));
          await tester.pumpAndSettle();

          // The banked figure survives in full at every scale. This is the
          // one value the header exists for.
          //
          // Read back off the session rather than written as a literal: the
          // gather above spends 90, so the header's figure is 455,191 and a
          // hardcoded 455,281 would be asserting the wrong number.
          expect(
            find.descendant(
              of: find.byType(BankedStepsReadout),
              matching: find.text(formatSteps(session.usableEnergy)),
            ),
            findsOneWidget,
          );

          expect(clippedLines(tester), isEmpty, reason: 'Adventure');
          expect(tester.takeException(), isNull);

          for (final String tab in <String>[
            'Character',
            'Inventory',
            'World',
          ]) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();
            expect(clippedLines(tester), isEmpty, reason: tab);
            expect(tester.takeException(), isNull, reason: tab);
          }
        });
      }
    }
  });

  // =========================================================================
  // Primitive-level stress, for values the domain cannot cheaply reach
  // =========================================================================

  /// Inventory counts near 999 and skill XP near 999,999 are real layout stress
  /// cases and are **not** cheaply reachable through the engine — 999 Meadow
  /// Herb is 500 gathers, and 999,999 Foraging XP is 99,999 of them. Driving
  /// the engine that far would be a slow test that proves a layout property, so
  /// the layout property is tested where it lives: on the primitives those
  /// screens are built from.
  ///
  /// Stated plainly so nobody reads this as game-state coverage. It is not.
  /// `s01a_vertical_slice_test.dart` owns the value arithmetic; this owns the
  /// box the value is drawn in.
  group('primitive stress at values the domain cannot cheaply reach', () {
    Widget harness(Widget child, double width, double factor) => MediaQuery(
      data: MediaQueryData(
        size: Size(width, 852),
        textScaler: TextScaler.linear(factor),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          // `ConstrainedBox`, not `SizedBox`, and the difference is load-bearing.
          //
          // `SizedBox(width: w)` hands its child a **tight** width, and
          // `SizedBox.enforce` then clamps any narrower box inside it back up
          // to w — so a `SizedBox(width: 20)` nested in one is silently 393 dp
          // wide and every stress case below would have been measured at full
          // screen width while appearing to test a narrow tile. A max-width
          // constraint leaves the child free to be smaller, which is what a
          // real screen's gutters and grid cells do.
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: child,
            ),
          ),
        ),
      ),
    );

    for (final double width in kWidths) {
      for (final double factor in <double>[1.0, 1.2, 1.4]) {
        testWidgets(
          'value tiles hold 999,999 and 9,999,999 at ${width.toInt()} dp x$factor',
          (WidgetTester tester) async {
            sizeTo(tester, width);
            await tester.pumpWidget(
              harness(
                const Padding(
                  // Two gutters and the card's own padding, which is the
                  // narrowest a tile ever is on a real screen.
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: ValueTileRow(
                    tiles: <LabeledValueTile>[
                      LabeledValueTile(
                        label: 'Total skill XP',
                        value: '999,999',
                        unit: 'across every skill',
                      ),
                      LabeledValueTile(
                        label: 'Total walked',
                        value: '9,999,999',
                        unit: 'steps earned',
                      ),
                    ],
                  ),
                ),
                width,
                factor,
              ),
            );
            await tester.pumpAndSettle();
            expect(clippedLines(tester), isEmpty);
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'the item count reads x999 at ${width.toInt()} dp x$factor',
          (WidgetTester tester) async {
            sizeTo(tester, width);
            // The narrowest an inventory tile gets: four columns, 320 dp,
            // two 16 dp gutters and three 8 dp gaps.
            const double tile = (320 - 32 - 24) / 4;
            await tester.pumpWidget(
              harness(
                const SizedBox(
                  width: tile,
                  child: Text(
                    '×999',
                    style: StrideType.itemCount,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                width,
                factor,
              ),
            );
            await tester.pumpAndSettle();
            expect(clippedLines(tester), isEmpty);
          },
        );
      }
    }

    /// The floor is a floor. `AdaptiveText` must refuse to shrink past
    /// [AdaptiveText.minScale], because an unbounded `FittedBox(scaleDown)` —
    /// what `LabeledValueTile` used before — renders a 22 px numeral at about
    /// 9 px in a narrow tile and calls that success.
    testWidgets('AdaptiveText stops shrinking at its floor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 20,
            child: AdaptiveText(
              '9,999,999',
              style: StrideType.numericValue,
              minScale: 0.8,
            ),
          ),
          393,
          1.0,
        ),
      );
      await tester.pumpAndSettle();

      final Text rendered = tester.widget<Text>(find.text('9,999,999'));
      expect(
        rendered.style!.fontSize,
        closeTo(StrideType.numericValue.fontSize! * 0.8, 0.01),
        reason: 'it must bottom out at the floor rather than vanish',
      );
    });
  });
}
