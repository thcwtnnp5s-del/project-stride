/// The pixel plate and its variant family
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4): construction per variant,
/// the 2 px press travel as a state swap, disabled's flat recession, the
/// semantics contract, and the geometry floors.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/adaptive_text.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/theme/stride_colors.dart';

void main() {
  Widget host(Widget child, {double textScale = 1}) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Center(
        child: SizedBox(width: 300, child: child),
      ),
    ),
  );

  /// The plate's fill and outline.
  ///
  /// **Two homes since FMPO02, and the same rectangle in both.** An enabled
  /// control now draws its face through PixelFrame against an authored plate,
  /// and hands the painted construction over as that frame's `fallback` —
  /// what it degrades to while the raster is in flight, and forever if the
  /// raster never decodes. A disabled control has no plate and keeps its own
  /// Container. Both are searched, so every assertion below still tests the
  /// construction rather than where it happens to live.
  BoxDecoration? plateOf(WidgetTester tester) {
    for (final PixelFrame f in tester.widgetList<PixelFrame>(
      find.descendant(
        of: find.byType(StrideButton),
        matching: find.byType(PixelFrame),
      ),
    )) {
      if (f.fallback case final BoxDecoration d) return d;
    }
    for (final Container c in tester.widgetList<Container>(
      find.descendant(
        of: find.byType(StrideButton),
        matching: find.byType(Container),
      ),
    )) {
      if (c.decoration is BoxDecoration) return c.decoration! as BoxDecoration;
    }
    return null;
  }

  /// The under-ledge and the one glow — the drawn thickness BELOW the plate.
  ///
  /// Flutter's on both paths, and outside anything the authored raster covers.
  /// That is what lets the variant registers stay legible without tinting art:
  /// attack, defense and ready differ here. Empty while the control is pressed
  /// (it is sitting on the ledge) and while it is disabled (an unpressable
  /// thing has no thickness).
  List<BoxShadow> ledgeOf(WidgetTester tester) {
    for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(StrideButton),
        matching: find.byType(DecoratedBox),
      ),
    )) {
      final Decoration deco = box.decoration;
      if (deco is BoxDecoration && deco.boxShadow != null) {
        return deco.boxShadow!;
      }
    }
    return const <BoxShadow>[];
  }

  group('construction', () {
    testWidgets('each variant wears its own outline and ledge', (
      WidgetTester tester,
    ) async {
      final Map<StrideButtonVariant, (Color, Color)> expected =
          <StrideButtonVariant, (Color, Color)>{
        StrideButtonVariant.commit: (
          StrideColors.actionEdge,
          StrideColors.surfaceGround,
        ),
        StrideButtonVariant.attack: (
          StrideColors.dangerDim,
          StrideColors.dangerDim,
        ),
        StrideButtonVariant.defense: (
          StrideColors.defenseEdge,
          StrideColors.surfaceGround,
        ),
        StrideButtonVariant.ready: (
          StrideColors.positiveReady,
          StrideColors.positiveReadyDim,
        ),
      };
      for (final MapEntry<StrideButtonVariant, (Color, Color)> e
          in expected.entries) {
        await tester.pumpWidget(
          host(
            StrideButton(label: 'Act', variant: e.key, onPressed: () {}),
          ),
        );
        final BoxDecoration deco = plateOf(tester)!;
        expect(deco.color, StrideColors.surfaceRaised, reason: '${e.key}');
        expect((deco.border! as Border).top.color, e.value.$1,
            reason: '${e.key} outline');
        final BoxShadow ledge = ledgeOf(tester).first;
        expect(ledge.color, e.value.$2, reason: '${e.key} ledge');
        expect(ledge.blurRadius, 0, reason: 'a drawn ledge, not a glow');
        expect(ledge.offset, const Offset(0, 2), reason: '${e.key}');
      }
    });

    testWidgets('only the glow bearer glows', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(StrideButton(label: 'Set out', glow: true, onPressed: () {})),
      );
      expect(
        ledgeOf(tester).any(
          (BoxShadow s) => s.color == StrideColors.actionGlow,
        ),
        isTrue,
      );
      await tester.pumpWidget(
        host(StrideButton(label: 'Gather', onPressed: () {})),
      );
      expect(
        ledgeOf(tester).any(
          (BoxShadow s) => s.color == StrideColors.actionGlow,
        ),
        isFalse,
        reason: 'the glow is Set out\'s alone',
      );
    });

    testWidgets('disabled is flat: no outline, no ledge, no lit edge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(const StrideButton(label: 'Craft', onPressed: null)),
      );
      final BoxDecoration deco = plateOf(tester)!;
      expect(deco.color, StrideColors.surfaceBlock);
      expect(deco.border, isNull);
      expect(ledgeOf(tester), isEmpty);
    });
  });

  group('the press', () {
    testWidgets('a held pointer sits the plate down onto its ledge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(StrideButton(label: 'Gather', onPressed: () {})),
      );
      Offset travel() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(StrideButton),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .let((v) => Offset(v.x, v.y));
      expect(travel(), Offset.zero);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Gather')),
      );
      await tester.pump();
      expect(travel(), const Offset(0, 2), reason: 'down onto the ledge');
      expect(ledgeOf(tester), isEmpty,
          reason: 'the ledge is what it sits on');
      await gesture.up();
      await tester.pump();
      expect(travel(), Offset.zero);
    });
  });

  group('geometry and semantics', () {
    testWidgets('the primary floor holds, and holds at large text', (
      WidgetTester tester,
    ) async {
      for (final double scale in <double>[1, 2]) {
        await tester.pumpWidget(
          host(
            StrideButton(
              label: 'Gather — 9,999,999 steps',
              subLabel: 'Walk 240 more steps',
              onPressed: () {},
            ),
            textScale: scale,
          ),
        );
        final Size size = tester.getSize(find.byType(StrideButton));
        expect(size.height, greaterThanOrEqualTo(48), reason: 'scale $scale');
        expect(tester.takeException(), isNull,
            reason: 'no overflow at scale $scale');
      }
    });

    testWidgets('the semantics node keeps role, state, and composed label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          StrideButton(
            label: 'Brace',
            subLabel: 'Half damage',
            variant: StrideButtonVariant.defense,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(StrideButton)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Brace. Half damage',
          hasTapAction: true,
        ),
      );
      await tester.pumpWidget(
        host(const StrideButton(label: 'Brace', onPressed: null)),
      );
      expect(
        tester.getSemantics(find.byType(StrideButton)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Brace',
        ),
      );
      semantics.dispose();
    });
  });

  // =========================================================================
  // The face under the plate (FMPO02 wave 3, FINAL-10 #1)
  // =========================================================================

  group('the interior is a face, not a hole', () {
    /// The control's own pixels, with the authored plate actually decoded.
    ///
    /// This is the only kind of test that could have caught the defect. Every
    /// assertion above reads the *painted* construction — `plateOf` returns
    /// `PixelFrame.fallback`, the rectangle drawn while the raster is in
    /// flight — and that rectangle was always `surfaceRaised` and always
    /// right. What shipped to the device was the other path: the nine-patch
    /// arrived, the fallback switched off, and the frame's transparent middle
    /// let `surfaceGround` through. So the raster is precached first and the
    /// answer is read off the rendered image.
    Future<(ui.Image, ByteData)> render(
      WidgetTester tester,
      Widget button,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        // On the page's own ground, because that is the whole defect: an
        // interior that draws nothing composites to whatever is behind it,
        // and behind it is `surfaceGround`.
        host(
          ColoredBox(
            color: StrideColors.surfaceGround,
            child: RepaintBoundary(
              key: const ValueKey<String>('b'),
              child: button,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final Element e in find.byType(PixelFrame).evaluate()) {
          await precacheImage(
            AssetImage((e.widget as PixelFrame).skin.assetPath),
            e,
          );
        }
      });
      await tester.pumpAndSettle();
      final ui.Image image = (await tester.runAsync(
        () => captureImage(
          find.byKey(const ValueKey<String>('b')).evaluate().single,
        ),
      ))!;
      final ByteData bytes = (await tester.runAsync(
        () async =>
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
      ))!;
      return (image, bytes);
    }

    Color at(ui.Image image, ByteData px, int x, int y) {
      final int i = (y * image.width + x) * 4;
      return Color.fromARGB(
        px.getUint8(i + 3),
        px.getUint8(i),
        px.getUint8(i + 1),
        px.getUint8(i + 2),
      );
    }

    /// Every distinct colour inside the control's face.
    ///
    /// Inset past the 6 dp corner radius, past the plate's own rim, and past
    /// the 2 px the under-ledge occupies at the bottom of the box — so what is
    /// counted is the interior the label sits on and nothing else.
    Set<Color> interior(ui.Image image, ByteData px) => <Color>{
      for (int y = 8; y < image.height - 8; y++)
        for (int x = 12; x < image.width - 12; x++) at(image, px, x, y),
    };

    testWidgets('a commit primary paints a lit face, not the page ground', (
      WidgetTester tester,
    ) async {
      final (ui.Image image, ByteData px) = await render(
        tester,
        StrideButton(label: 'Travel', onPressed: () {}),
      );
      // The pixel the review sampled: row 539 of the world inspector was one
      // flat run of #14120F across the whole of the Travel button.
      expect(
        at(image, px, image.width ~/ 2, image.height ~/ 2),
        isNot(StrideColors.surfaceGround),
        reason: 'the commit control is a window onto the page background',
      );
      final Set<Color> inks = interior(image, px);
      expect(
        inks,
        isNot(contains(StrideColors.surfaceGround)),
        reason: 'not one interior pixel may be the page ground',
      );
      expect(
        inks,
        contains(StrideColors.surfaceRaised),
        reason: 'the raised face is what the plate frames',
      );
      image.dispose();
    });

    testWidgets('the ready variant keeps its moss', (
      WidgetTester tester,
    ) async {
      final (ui.Image image, ByteData px) = await render(
        tester,
        StrideButton(
          label: 'Craft',
          variant: StrideButtonVariant.ready,
          onPressed: () {},
        ),
      );
      final Set<Color> inks = interior(image, px);
      // The one register that already read as a face rather than a hole, and
      // the reason: `ready`'s ledge is the same moss, so what showed through
      // the transparent middle was moss too. This holds the token now that the
      // fill is painted deliberately rather than leaking from below.
      expect(inks, contains(StrideColors.positiveReadyDim));
      expect(inks, isNot(contains(StrideColors.surfaceGround)));
      image.dispose();
    });

    testWidgets('the utility control is lighter than nothing, and darker '
        'than the primary', (WidgetTester tester) async {
      final (ui.Image image, ByteData px) = await render(
        tester,
        StrideButton.secondary(label: 'Sync steps', onPressed: () {}),
      );
      final Set<Color> inks = interior(image, px);
      // The hierarchy the review found inverted: the secondary sat on
      // `surfaceBlock` while the primary above it showed the page through.
      expect(inks, contains(StrideColors.surfaceBlock));
      expect(inks, isNot(contains(StrideColors.surfaceGround)));
      image.dispose();
    });
  });

  // =========================================================================
  // The dressing survives disablement (FMPO02 wave 3, FINAL-01 #1)
  // =========================================================================

  group('a held control keeps its identity', () {
    testWidgets('the emblem and the glyph are dimmed, not dropped', (
      WidgetTester tester,
    ) async {
      const Key emblem = ValueKey<String>('emblem');
      const Key glyph = ValueKey<String>('glyph');
      Widget command({required bool enabled}) => StrideButton(
        label: 'Attack',
        variant: StrideButtonVariant.attack,
        emblem: const SizedBox(key: emblem, width: 64, height: 32),
        leading: const SizedBox(key: glyph, width: 32, height: 32),
        onPressed: enabled ? () {} : null,
      );

      await tester.pumpWidget(host(command(enabled: true)));
      expect(find.byKey(emblem), findsOneWidget);
      expect(find.byKey(glyph), findsOneWidget);

      await tester.pumpWidget(host(command(enabled: false)));
      // Both still there — the four combat cells stop changing shape between
      // turns — and both quieter.
      expect(find.byKey(emblem), findsOneWidget);
      expect(find.byKey(glyph), findsOneWidget);
      for (final Key k in <Key>[emblem, glyph]) {
        final Opacity o = tester.widget<Opacity>(
          find
              .ancestor(of: find.byKey(k), matching: find.byType(Opacity))
              .first,
        );
        expect(o.opacity, closeTo(StrideButton.disabledDressing, 0.001), reason: '$k');
      }
      // And the words still carry the state.
      expect(
        tester.widget<AdaptiveText>(find.byType(AdaptiveText).first).color,
        StrideColors.textMuted,
      );
    });

    testWidgets('a disabled control that says why keeps the words, not the '
        'glyph', (WidgetTester tester) async {
      const Key glyph = ValueKey<String>('glyph');
      await tester.pumpWidget(
        host(
          const StrideButton(
            label: 'Eat',
            subLabel: 'No food in the bag',
            leading: SizedBox(key: glyph, width: 32, height: 32),
            onPressed: null,
          ),
        ),
      );
      // A 32 dp icon row plus two lines does not fit the combat cluster's
      // 56 dp cell, and the line that says why is never the one squeezed out.
      expect(find.byKey(glyph), findsNothing);
      expect(find.text('No food in the bag'), findsOneWidget);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
