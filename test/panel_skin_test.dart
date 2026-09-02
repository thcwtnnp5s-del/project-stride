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
  group('the registry is exactly what was reviewed', () {
    test('only the picture and the interruption are framed', () {
      // VAWO01 registered the chassis against every role, and the owner's
      // device verdict on that build was that the frame had become wallpaper:
      // "large leather frame containing ordinary rounded dark cards",
      // everywhere. FMPO02 inverted the registry — one framed element per
      // screen (its picture, `heroPlate`) plus the raised interruption
      // (`modalFrame`); every other role is a surface and differs by material.
      //
      // The exact-set form is kept: **if this fails without a device review
      // having happened, the chassis moved by accident** — in either direction.
      expect(PanelSkins.authored.keys.toSet(), <PanelRole>{
        PanelRole.heroPlate,
        PanelRole.modalFrame,
      });

      // One family app-wide (L-18 as amended). Eleven unrelated borders is
      // the failure mode this direction is most likely to produce.
      expect(
        PanelSkins.authored.values.map((PanelSkin s) => s.assetPath).toSet(),
        hasLength(1),
      );
    });

    test('a framed role reserves its inset; a surface role reserves nothing', () {
      // The reserve is the figure used if the asset fails to decode. For a
      // framed role it equals the real inset, so a failed decode changes the
      // material and not the layout. For a surface role it is zero: a panel
      // that is not waiting for a frame must not keep sixteen logical px of
      // air on every side for art that will never come.
      for (final PanelRole role in PanelRole.values) {
        final PanelSkin? skin = PanelSkins.of(role);
        expect(
          PanelSkins.insetFor(role),
          skin?.inset ?? 0,
          reason: role.name,
        );
      }
    });

    test('every authored surface names a tile at integer scale', () {
      // The surface axis is the half of `DECISIONS/0029` that VAWO01 never
      // built. A row is a 32² native tile at ×2; a tile at a fractional scale
      // is pixel art that has stopped being pixel art (L-18).
      expect(PanelSurfaces.of(PanelSurface.none), isNull);
      for (final MapEntry<PanelSurface, SurfaceTile> e
          in PanelSurfaces.authored.entries) {
        expect(e.value.assetPath, startsWith('assets/ui/v1/surface/grain_'));
        expect(e.value.scale, 2, reason: e.key.name);
        expect(e.value.extent, e.value.native * 2.0);
      }
    });

    test('the chassis geometry matches the asset it declares', () {
      // Geometry is measured from the PNG, never guessed — a frame whose
      // declared geometry disagrees with its file renders wrong in a way that
      // looks like a layout bug, the most expensive kind of art defect to
      // diagnose. These figures are mirrored in
      // `assets/ui/v1/frame/chassis_64.json` for the tile-seam guard, and the
      // band/corner distinction is the one § 3.2.1 of the production plan was
      // written about.
      final PanelSkin chassis = PanelSkins.of(PanelRole.heroPlate)!;
      expect(chassis.assetPath, 'assets/ui/v1/frame/chassis_64.png');
      expect(chassis.nativeWidth, 64);
      expect(chassis.nativeHeight, 64);
      expect(chassis.corner, 16);
      expect(chassis.band, 8);
      expect(chassis.scale, 2);
      // Content is inset by the BAND, not the corner block. Insetting by the
      // corner would cost every panel 32 logical px per side.
      expect(chassis.inset, 16);
      expect(chassis.cornerExtent, 32);
    });

    testWidgets('a framed panel still carries its painted fallback', (
      WidgetTester tester,
    ) async {
      // `SectionCard` hands `PixelFrame` exactly the rectangle it used to
      // draw. That is what `DECISIONS/0029`'s reversibility rests on — a
      // frame that fails to decode, or a registry emptied to revert the
      // direction in one commit, degrades to what shipped rather than to a
      // hole.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(
            role: PanelRole.heroPlate,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );

      final PixelFrame frame = tester.widget<PixelFrame>(
        find.byType(PixelFrame),
      );
      final BoxDecoration d = frame.fallback! as BoxDecoration;
      expect(d.color, StrideColors.surfaceCard);
      expect(d.borderRadius, StrideRadius.card);
      expect(d.border, Border.all(color: StrideColors.borderDefault));
    });

    testWidgets('a framed role routes through PixelFrame; a surface role does '
        'not', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(
            role: PanelRole.heroPlate,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );
      expect(find.byType(PixelFrame), findsOneWidget);

      // The default card is a surface, and a surface has no frame — the
      // whole correction FMPO02 made to VAWO01's registry.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(child: SizedBox(width: 100, height: 20)),
        ),
      );
      expect(find.byType(PixelFrame), findsNothing);
    });

    testWidgets('an authored surface tiles under the child, framed or not', (
      WidgetTester tester,
    ) async {
      // A surface is drawn by `SurfaceFill` on an unframed card and by the
      // frame's own painter on a framed one. Either way the card's flat fill
      // is painted first, so a missing tile is today's card and never a hole.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(
            surface: PanelSurface.journalLeaf,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );
      expect(find.byType(SurfaceFill), findsOneWidget);
      expect(find.byType(PixelFrame), findsNothing);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SectionCard(
            role: PanelRole.heroPlate,
            surface: PanelSurface.journalLeaf,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );
      final PixelFrame frame = tester.widget<PixelFrame>(
        find.byType(PixelFrame),
      );
      expect(frame.surface, PanelSurfaces.of(PanelSurface.journalLeaf));
      expect(find.byType(SurfaceFill), findsNothing);
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

      // A framed role's content box is actually narrower by the frame, not
      // merely declared to be; a surface role's content box gives up nothing
      // but the card's own padding. Both halves are asserted, because the
      // second is the one that keeps a list's full width now that the frame
      // has left it.
      for (final PanelRole role in PanelRole.values) {
        final double content = await contentWidthFor(role);
        final double inset = PanelSkins.of(role)?.inset ?? 0;
        expect(
          content,
          lessThanOrEqualTo(320 - (inset * 2)),
          reason:
              '${role.name}: the frame is not actually taking its width, so '
              'it will overlap the words it surrounds',
        );
        // And not *more* than the frame plus the card's own interior gap —
        // which is what catches the frame and the padding double-charging for
        // the same space, the regression that cost "Woodcutting" 10 dp at the
        // accessibility text scale.
        expect(
          content,
          greaterThan(320 - (inset * 2) - 32),
          reason: '${role.name}: something is charging twice for the edge',
        );
      }
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
