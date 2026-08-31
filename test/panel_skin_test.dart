/// The panel-skin seam, and the boundary `DECISIONS/0029` draws around it.
///
/// The owner amended `ART_DIRECTION.md` L-18 so PixelLab may author interface
/// art. The clause that keeps that from becoming "the UI is now a pile of
/// images" is this one:
///
/// > With every frame asset removed from the build, the app must still lay
/// > out, still read and still be navigable. Art may change how Stride
/// > *feels*; it may never change what Stride *does*.
///
/// This file is that clause, executable. It also pins the two properties the
/// architecture is *for*: that an empty registry paints exactly what shipped
/// before, and that a registered frame **tiles** its edges rather than
/// stretching them — because stretching pixel art is the failure L-18's
/// surviving paragraph exists to prevent, and `centerSlice`, Flutter's own
/// nine-patch, does precisely that.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/panel_skin.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride/ui/theme/stride_metrics.dart';

/// A frame fixture: 12 × 12, 4 px corners, so each edge strip is 4 px wide.
/// Corners are opaque red, strips opaque green, interior transparent — three
/// values a painter test can tell apart without a golden file.
const PanelSkin _fixture = PanelSkin(
  assetPath: 'test/fixture_frame_12.png',
  nativeWidth: 12,
  nativeHeight: 12,
  corner: 4,
  band: 4,
  scale: 2,
);

void main() {
  group('the empty registry is the shipped product', () {
    test('no role has authored art yet', () {
      // The state `DECISIONS/0029` ships in: architecture landed, art queued
      // for after the 2026-09-16 PixelLab reset. If this ever fails without a
      // device review having happened, a frame family landed by accident.
      expect(PanelSkins.authored, isEmpty);
      for (final PanelRole role in PanelRole.values) {
        expect(PanelSkins.of(role), isNull, reason: role.name);
      }
    });

    testWidgets('a card with no skin paints the rectangle it always painted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(child: SizedBox(width: 100, height: 20)),
        ),
      );

      // Exactly the pre-existing decoration: one fill, one 1 px border in one
      // colour, radius 14. No PixelFrame anywhere in the tree.
      expect(find.byType(PixelFrame), findsNothing);
      final Container box = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BoxDecoration d = box.decoration! as BoxDecoration;
      expect(d.color, StrideColors.surfaceCard);
      expect(d.borderRadius, StrideRadius.card);
      expect(d.border, Border.all(color: StrideColors.borderDefault));
    });

    testWidgets('every role still lays out at the same size', (
      WidgetTester tester,
    ) async {
      // The layout claim, per role: naming a role must not move anything while
      // the registry is empty.
      for (final PanelRole role in PanelRole.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 300,
                child: SectionCard(
                  role: role,
                  child: const SizedBox(height: 40),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(SectionCard)).width,
          300,
          reason: role.name,
        );
      }
    });
  });

  group('the inset reserve', () {
    // Review caught the first version of this group asserting `insetFor >= 0`
    // and `modalFrame > card` — neither of which tests the reserve, both of
    // which pass whether or not the reserve does anything. It did not:
    // `SectionCard` ignored it entirely, so the reflow the reserve exists to
    // prevent would have happened on the first asset, with a green test.

    testWidgets('a role\'s content box is the same width with a reserve', (
      WidgetTester tester,
    ) async {
      // The property that matters: a role that reserves room must ALREADY be
      // giving that room up while unskinned. Otherwise the day art lands,
      // every panel of that role narrows by the frame's width at once.
      Future<double> contentWidthFor(PanelRole role) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                child: SectionCard(
                  role: role,
                  child: SizedBox(key: ValueKey<PanelRole>(role), height: 20),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byKey(ValueKey<PanelRole>(role))).width;
      }

      final double card = await contentWidthFor(PanelRole.card);
      final double modal = await contentWidthFor(PanelRole.modalFrame);

      // A modal reserves the heaviest edge, so its content box is narrower by
      // exactly twice the reserve — now, before any art exists.
      expect(
        card - modal,
        PanelSkins.insetFor(PanelRole.modalFrame) * 2,
        reason:
            'the reserve is not being applied; the frame will reflow every '
            'panel of this role on the day it ships',
      );
    });

    testWidgets('an unreserved role is byte-identical to what shipped', (
      WidgetTester tester,
    ) async {
      // The other half: `card` and `kitTray` reserve nothing, so the
      // overwhelming majority of the product must be untouched by all of this.
      expect(PanelSkins.insetFor(PanelRole.card), 0);
      expect(PanelSkins.insetFor(PanelRole.kitTray), 0);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              child: SectionCard(
                child: SizedBox(key: Key('c'), height: 20),
              ),
            ),
          ),
        ),
      );
      // 320, less the card's own 14 dp padding each side, less the 1 px border
      // each side that `Container` adds to the child's inset — and nothing
      // else. No reserve, no frame, no change from what shipped.
      expect(tester.getSize(find.byKey(const Key('c'))).width, 320 - 28 - 2);
    });
  });

  group('PixelFrame', () {
    testWidgets('falls back to the painted decoration while loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PixelFrame(
            skin: _fixture,
            fallback: BoxDecoration(
              color: StrideColors.surfaceCard,
              border: Border.all(color: StrideColors.borderDefault),
            ),
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );
      // The asset does not resolve in this harness, which is exactly the
      // "frame failed to load" case: a panel must degrade to the rectangle it
      // replaced, never to a hole.
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect((box.decoration as BoxDecoration).color, StrideColors.surfaceCard);
    });

    testWidgets('insets its child by the corner, at integer scale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: PixelFrame(
                skin: _fixture,
                child: Container(key: const Key('inner')),
              ),
            ),
          ),
        ),
      );
      // corner 4 × scale 2 = 8 logical px on every side.
      expect(_fixture.inset, 8);
      final Size inner = tester.getSize(find.byKey(const Key('inner')));
      expect(inner.width, 200 - 16);
      expect(inner.height, 120 - 16);
    });

    test('the geometry refuses a frame that cannot tile', () {
      // A frame whose corners consume the whole asset has no strip to repeat,
      // so there is nothing to draw between the corners. Caught at
      // construction rather than discovered as a visual gap.
      expect(
        () => PanelSkin(
          assetPath: 'x.png',
          nativeWidth: 8,
          nativeHeight: 8,
          corner: 4,
          band: 4,
          scale: 2,
        ),
        throwsA(isA<AssertionError>()),
      );
      // Fractional scale is unrepresentable for the same reason PixelAsset
      // refuses it (L-18, first paragraph — untouched by the amendment).
      expect(
        () => PanelSkin(
          assetPath: 'x.png',
          nativeWidth: 12,
          nativeHeight: 12,
          corner: 4,
          band: 4,
          scale: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('edges TILE rather than stretch', () {
      // The claim that separates this renderer from `centerSlice`, which would
      // smear a 4 px strip across the whole span. Asserted on the DRAW CALLS
      // rather than on sampled pixels: "tiling" means the strip is issued many
      // times at its own width, and a recording canvas says that directly — no
      // golden to eyeball, no async decode, and it fails loudly if anyone
      // swaps in a stretching implementation.
      final _RecordingCanvas canvas = _RecordingCanvas();
      debugFramePainter(
        _fixture,
        _StubImage(),
      ).paint(canvas, const Size(200, 120));

      // 4 corners, plus the tiles along all four edges.
      expect(canvas.calls.length, greaterThan(4));

      // Strip width is (12 - 2*4) = 4 source px at scale 2 = 8 logical px.
      const double strip = 8;
      final List<Rect> topTiles = canvas.calls
          .map((_DrawCall c) => c.dst)
          .where((Rect r) => r.top == 0 && r.left >= 8 && r.right <= 192)
          .toList();
      expect(
        topTiles.length,
        greaterThan(10),
        reason:
            'a 184 px run of 8 px tiles should be ~23 draws; a stretched edge '
            'would be exactly one',
      );
      // No tile is ever widened to fit — that would be stretching.
      for (final Rect r in topTiles) {
        expect(r.width, lessThanOrEqualTo(strip));
      }
      // The interior is never drawn: a frame is an edge, and body text sits on
      // the panel's own fill rather than on art.
      for (final _DrawCall c in canvas.calls) {
        final bool insideH = c.dst.left >= 8 && c.dst.right <= 192;
        final bool insideV = c.dst.top >= 8 && c.dst.bottom <= 112;
        expect(insideH && insideV, isFalse, reason: 'painted the interior');
      }
    });
  });
}

@immutable
final class _DrawCall {
  const _DrawCall(this.src, this.dst);
  final Rect src;
  final Rect dst;
}

/// Records `drawImageRect` and ignores everything else.
class _RecordingCanvas implements Canvas {
  final List<_DrawCall> calls = <_DrawCall>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    // The nearest-neighbour contract, checked on every single patch rather
    // than once at construction.
    expect(paint.filterQuality, FilterQuality.none);
    expect(paint.isAntiAlias, isFalse);
    calls.add(_DrawCall(src, dst));
  }

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A stand-in for a decoded frame: the painter only hands it to
/// `drawImageRect`, which [_RecordingCanvas] intercepts.
class _StubImage implements ui.Image {
  @override
  int get width => 12;
  @override
  int get height => 12;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
