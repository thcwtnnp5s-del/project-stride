/// The pixel plate and its variant family
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4): construction per variant,
/// the 2 px press travel as a state swap, disabled's flat recession, the
/// semantics contract, and the geometry floors.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
