/// The pixel plate and its variant family
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4): construction per variant,
/// the 2 px press travel as a state swap, disabled's flat recession, the
/// semantics contract, and the geometry floors.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/data_display.dart';
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

  /// The plate's decorated container: the one carrying a BoxDecoration
  /// with a border or a fill, nearest the button root.
  BoxDecoration? plateOf(WidgetTester tester) {
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
        final BoxShadow ledge = deco.boxShadow!.first;
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
        plateOf(tester)!.boxShadow!.any(
          (BoxShadow s) => s.color == StrideColors.actionGlow,
        ),
        isTrue,
      );
      await tester.pumpWidget(
        host(StrideButton(label: 'Gather', onPressed: () {})),
      );
      expect(
        plateOf(tester)!.boxShadow!.any(
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
      expect(deco.boxShadow, isNull);
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
      expect(plateOf(tester)!.boxShadow, isEmpty,
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
