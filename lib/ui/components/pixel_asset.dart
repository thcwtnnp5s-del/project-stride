/// The one place `ART_DIRECTION.md` **L-18** is enforced.
///
/// > Every pixel asset is displayed at an exact integer multiple of its native
/// > size, with nearest-neighbour filtering and no sub-pixel positioning, in a
/// > container that layout cannot compress.
///
/// The constructor takes a **native size and an integer scale**. It does not
/// take a width. A fractional displayed size is therefore *unrepresentable*
/// rather than merely discouraged — the same technique the progress track uses
/// when it refuses a caller-supplied fill fraction.
///
/// ## The failure this exists to prevent, and why Flutter's version is worse
///
/// Round 03 spent three wrong diagnoses on portrait "softness" — called
/// non-integer scaling, then sub-pixel positioning, then finally measured as a
/// 1 px `border-box` clip eating the asset's own frame ring.
///
/// Flutter has the same failure with a different mechanism, and it is worse
/// because Flutter **shrinks silently instead of clipping**. `Container` with a
/// border does not behave like `border-box`: the border is added to the child's
/// padding, so a `Container` constrained to 96 gives its child 94. And when a
/// parent passes down a bounded constraint smaller than the child's declared
/// size, `SizedBox` **honours the parent** — it can only tighten within incoming
/// constraints. There is no overflow stripe, no console warning, and nothing on
/// screen to point at: the sprite is simply drawn at 4.7× instead of 5×.
///
/// So this widget carries a debug assert that turns the invisible failure into a
/// loud one, at the exact frame it happens, at zero release cost.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'panel_skin.dart';

/// A pixel-art sprite, drawn at an exact integer multiple of its native size.
///
/// Prefer the named constructors — they bind each asset class to the native size
/// measured from the PNG headers, so a wrong size is a deliberate choice rather
/// than a typo.
class PixelAsset extends StatelessWidget {
  const PixelAsset({
    super.key,
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
  }) : assert(scale >= 1, 'integer multiples only, and at least 1');

  /// Item icons — **48 × 48**, the PixelLab family, 48 logical at ×1.
  ///
  /// This replaced a 20 × 20 code-rendered set. The Training Axe is why the
  /// swap was worth its layout cost: three rounds of the code-rendered icon
  /// were read as "hammer" by blind reviewers in-grid, and the PixelLab edit
  /// was the first ever read as an axe
  /// (`PIXELLAB_STABILIZATION_01/README.md` §3 item 4).
  ///
  /// ×1, not ×2. A 96 logical px icon does not fit a four-column grid at 320 dp,
  /// and dropping to ×1 keeps four columns at every supported width. The sprite
  /// is still magnified on screen — every phone this targets has a device pixel
  /// ratio of 2 or more.
  const PixelAsset.item(this.assetPath, {super.key, this.scale = 1})
    : nativeWidth = 48,
      nativeHeight = 48;

  /// Skill icons — **24 × 24 native, drawn ×1**, since Transformation Build 01.
  ///
  /// The temporary set was 12 × 12 at ×2. The OD-04 second round is a PixelLab
  /// set authored at 24 (the tool cannot go below 16), and it ships at ×1 so the
  /// icon keeps the same 24 logical px footprint in every row and chip. That is
  /// a deliberate density exception to the ×2 UI grid, recorded in
  /// `assets/ui/v1/README.md`; the 12 px nearest-neighbour reductions exist in
  /// the round's output and lost the log rings and the anvil horn.
  const PixelAsset.skill(this.assetPath, {super.key, this.scale = 1})
    : nativeWidth = 24,
      nativeHeight = 24;

  /// Navigation glyphs — 14 × 14.
  const PixelAsset.nav(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 14,
      nativeHeight = 14;

  /// The steps and arrow glyphs — 12 × 12.
  const PixelAsset.glyph(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 12,
      nativeHeight = 12;

  /// The character portrait — **64 × 64**, PixelLab.
  const PixelAsset.portrait(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 64,
      nativeHeight = 64;

  /// A standalone character sprite — 64 × 64.
  ///
  /// A separate asset class from the portrait even though both are 64 × 64: a
  /// sprite stands on ground and needs [GroundedSprite], a portrait sits in a
  /// frame and must never be given a shadow.
  const PixelAsset.sprite(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 64,
      nativeHeight = 64;

  /// An activity illustration — 40 × 40.
  const PixelAsset.activity(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 40,
      nativeHeight = 40;

  final String assetPath;
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  double get displayWidth => (nativeWidth * scale).toDouble();
  double get displayHeight => (nativeHeight * scale).toDouble();

  @override
  Widget build(BuildContext context) {
    return _ExactSizeBox(
      width: displayWidth,
      height: displayHeight,
      assetPath: assetPath,
      child: Image.asset(
        assetPath,
        width: displayWidth,
        height: displayHeight,

        // `fill` is correct *given* the box is exactly the declared size, and
        // the assert in _ExactSizeBox is what makes that "given" hold.
        // `contain` would letterbox to a non-integer scale rather than failing;
        // `none` would crop; `cover` and `scaleDown` are wrong for both reasons.
        fit: BoxFit.fill,

        // Nearest neighbour. `Image`'s default is FilterQuality.low, which is
        // bilinear — the single most likely way crispness leaks away, and the
        // reason `Image.asset` is confined to this file by a guard rule.
        filterQuality: FilterQuality.none,
        isAntiAlias: false,

        // cacheWidth / cacheHeight are DELIBERATELY not set. They resample at
        // decode time, permanently, before filterQuality is ever consulted — on
        // a 20 px source that drops whole columns. The asset must decode at
        // native size so Skia performs an integer magnification at draw.
        //
        // There are also no 2.0x/ or 3.0x/ variant directories. AssetImage
        // resolves variants by devicePixelRatio and sets ImageInfo.scale
        // accordingly, which would change the intrinsic size out from under the
        // explicit width and height above.
        excludeFromSemantics: true,
        gaplessPlayback: true,
      ),
    );
  }
}

/// A scene-class pixel asset — a region map or a location vignette — shown at
/// an exact integer scale in a viewport that may be **smaller than it is**.
///
/// ## Why this is a different widget rather than a flag on [PixelAsset]
///
/// [PixelAsset] asserts when its parent offers less room than the sprite needs,
/// because for UI chrome that situation is always a bug: the fix is to widen the
/// container or lower the scale, and Flutter's silent rescale is the failure
/// worth shouting about.
///
/// Scene art has no such fix available. The region map is 384 px wide and the
/// vignette's source was 512; the supported phones are 320, 360, 393 and 430 dp.
/// There is no integer scale at which a 384 px map fits a 320 dp screen, and the
/// three ways out are not equal:
///
/// - **Downscale.** Non-integer, so whole columns are dropped. A map of thin
///   roads and a palisade of evenly spaced posts are the worst possible subjects
///   for that; the posts would beat visibly.
/// - **Shrink the art to the narrowest phone.** Every wider phone then shows a
///   small picture in a wide gap, and the art is authored twice.
/// - **Clip.** Nothing is resampled, the centre is always visible, and a wider
///   phone simply sees more of the world. The cost is the outermost pixels on a
///   narrow phone, which is why the framing of each scene asset puts nothing
///   load-bearing at its edges — the map's flanks are forest and cliff, and the
///   vignette is framed once, in `Scripts/art/package-art.js`, where the choice
///   is reviewable.
///
/// So this widget never scales and never asserts: it **clips, and says so**.
class PixelScene extends StatelessWidget {
  const PixelScene({
    super.key,
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 1,
    this.viewportHeight,
    this.alignment = Alignment.center,
    this.overlay,
  }) : assert(scale >= 1, 'integer multiples only, and at least 1');

  /// The illustrated region map — 384 × 640.
  const PixelScene.regionMap(
    this.assetPath, {
    super.key,
    this.viewportHeight,
    this.alignment = Alignment.center,
    this.overlay,
  }) : nativeWidth = 384,
       nativeHeight = 640,
       scale = 1;

  /// A location arrival vignette — 384 × 176, framed at packaging time.
  const PixelScene.vignette(
    this.assetPath, {
    super.key,
    this.viewportHeight,
    this.alignment = Alignment.center,
    this.overlay,
  }) : nativeWidth = 384,
       nativeHeight = 176,
       scale = 1;

  final String assetPath;
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  /// The height of the window onto the scene. Defaults to the whole thing, so a
  /// scene only ever clips vertically when a caller deliberately asks it to.
  final double? viewportHeight;

  /// Which part of the scene stays visible when the viewport is smaller than it
  /// is.
  final Alignment alignment;

  /// Drawn in the scene's own pixel coordinate space, on top of the image, and
  /// clipped and aligned with it. This is how a [GroundedSprite] stays put
  /// relative to the scenery as the viewport width changes.
  final Widget? overlay;

  double get displayWidth => (nativeWidth * scale).toDouble();
  double get displayHeight => (nativeHeight * scale).toDouble();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: viewportHeight ?? displayHeight,
      width: double.infinity,
      child: ClipRect(
        // OverflowBox is what PixelAsset's error message tells callers never to
        // reach for, and the distinction is exact: there it would hide a sprite
        // that is being silently rescaled, here nothing is being rescaled at
        // all. The child is given tight constraints at its true size, so it
        // renders at 1:1 and the clip is the only thing the viewport does.
        child: OverflowBox(
          alignment: alignment,
          minWidth: displayWidth,
          maxWidth: displayWidth,
          minHeight: displayHeight,
          maxHeight: displayHeight,
          child: Stack(
            children: <Widget>[
              Image.asset(
                assetPath,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              ),
              ?overlay,
            ],
          ),
        ),
      ),
    );
  }
}

/// An authored panel frame, drawn as a **tiled** nine-patch.
///
/// The third member of this file's family, and it lives here for the same
/// reason the other two do: `Scripts/check-ui-boundary.sh` confines image
/// painting to this one file so `filterQuality: none` has a single home. That
/// guard was extended in the same change that added this widget — it used to
/// match only the `Image.*` constructors, so a frame written the obvious way,
/// with a `DecorationImage` in a `BoxDecoration`, would have rendered bilinear
/// and passed CI in silence. A guard with a hole shaped like the next feature
/// is worse than no guard, because it is trusted.
///
/// ## Tiled, never stretched — and why `centerSlice` is refused
///
/// Flutter ships a nine-patch: `Image`'s `centerSlice`. It is wrong here.
/// `centerSlice` **stretches** the edge bands and the middle to fill, and
/// stretching pixel art is the exact failure L-18's first paragraph exists to
/// prevent. A 2 px rivet stretched over 300 px is a smear.
///
/// So the edges **repeat**. Corners draw once at 1:1 integer scale; the strips
/// between them tile until they run out, and the last tile is clipped. That
/// imposes a real constraint on the art, and it is recorded in the production
/// plan rather than discovered later: **no once-only ornament may live inside
/// a repeating strip**, and a frame must be reviewed at two different panel
/// heights, because a seam that reads at one repeat count can beat at another.
///
/// ## What it deliberately does not draw
///
/// The interior. The panel's own fill — or an optional low-variation surface
/// tile — owns the middle, so body text never sits on frame art and the
/// contrast question never arises. A frame is an edge.
/// ## Nothing is drawn until the image is decoded
///
/// The frame resolves its asset and repaints when it arrives. Before then it
/// draws the [fallback] — today's painted decoration — so a panel is never
/// briefly frameless and never flashes. That is also what makes the widget
/// honest in a widget test, where images resolve on a fake codec.
class PixelFrame extends StatefulWidget {
  const PixelFrame({
    super.key,
    required this.skin,
    required this.child,
    this.fallback,
    this.surface,
    this.childBuilder,
  });

  final PanelSkin skin;
  final Widget child;

  /// Built instead of [child], told whether the frame image is actually
  /// drawing.
  ///
  /// [fallback] already switches a caller's painted **decoration** off the
  /// moment the raster arrives, because two edges in the same place is the
  /// obvious defect. A control whose painted construction is not a decoration
  /// has the same problem and no lever for it: `StrideButton` draws a lit top
  /// edge as a child widget, and left in place it would sit on top of the
  /// authored plate's own rim. So this is the same switch, one layer in.
  ///
  /// Null — the default — is every existing call site: [child], always.
  final Widget Function(BuildContext context, bool framed)? childBuilder;

  /// Painted while the image is in flight, and forever if it fails to load. A
  /// missing frame must degrade to the rectangle it replaced, never to a hole.
  final Decoration? fallback;

  /// An optional interior tile, drawn **inside the band** and under the
  /// child — the `surfacePath` lever `PanelSkin` declared in
  /// PRESENTATION_COMBAT_EVOLUTION_01 and nothing rendered until FMPO02.
  /// Integer-scaled from the interior's top-left, clipped at the far edges,
  /// never rescaled. The panel's own fill stays underneath, so a tile that
  /// fails to load degrades to the flat card.
  final SurfaceTile? surface;

  @override
  State<PixelFrame> createState() => _PixelFrameState();
}

/// Resolves one asset image and repaints its owner when it arrives; silent
/// on failure, because a missing raster is a material change and never a
/// crash. Shared by the frame and its interior surface, which are two
/// images with one lifecycle.
class _AssetImageSlot {
  _AssetImageSlot(this.onChanged);

  final VoidCallback onChanged;
  ui.Image? image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  void resolve(BuildContext context, String? assetPath) {
    if (assetPath == null) {
      detach();
      if (image != null) {
        image = null;
        onChanged();
      }
      return;
    }
    final ImageStream stream = AssetImage(
      assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    detach();
    _stream = stream;
    _listener = ImageStreamListener((ImageInfo info, bool _) {
      image = info.image;
      onChanged();
    }, onError: (Object _, StackTrace? _) {});
    stream.addListener(_listener!);
  }

  void detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }
}

class _PixelFrameState extends State<PixelFrame> {
  late final _AssetImageSlot _frame = _AssetImageSlot(_changed);
  late final _AssetImageSlot _surface = _AssetImageSlot(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PixelFrame old) {
    super.didUpdateWidget(old);
    if (old.skin.assetPath != widget.skin.assetPath ||
        old.surface?.assetPath != widget.surface?.assetPath) {
      _resolve();
    }
  }

  void _resolve() {
    _frame.resolve(context, widget.skin.assetPath);
    _surface.resolve(context, widget.surface?.assetPath);
  }

  @override
  void dispose() {
    _frame.detach();
    _surface.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double c = widget.skin.inset;
    final ui.Image? image = _frame.image;
    final ui.Image? grain = widget.surface == null ? null : _surface.image;
    return CustomPaint(
      painter: image == null
          ? null
          : _FramePainter(
              skin: widget.skin,
              image: image,
              surface: widget.surface,
              grain: grain,
            ),
      foregroundPainter: null,
      child: DecoratedBox(
        // Once the frame paints, the fallback's border would double the edge.
        decoration: image == null
            ? (widget.fallback ?? const BoxDecoration())
            : const BoxDecoration(),
        child: Padding(
          padding: EdgeInsets.all(c),
          child:
              widget.childBuilder?.call(context, image != null) ?? widget.child,
        ),
      ),
    );
  }
}

/// Tiles a [SurfaceTile] across [rect] at integer scale: nearest neighbour,
/// clipped at the far edges, never rescaled. Shared by the frame's interior
/// and by [SurfaceFill].
void paintSurfaceTile(
  Canvas canvas,
  Rect rect,
  SurfaceTile tile,
  ui.Image grain,
) {
  final Paint paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final double e = tile.extent;
  final Rect src = Rect.fromLTWH(
    0,
    0,
    grain.width.toDouble(),
    grain.height.toDouble(),
  );
  canvas.save();
  canvas.clipRect(rect);
  for (double y = rect.top; y < rect.bottom; y += e) {
    for (double x = rect.left; x < rect.right; x += e) {
      canvas.drawImageRect(grain, src, Rect.fromLTWH(x, y, e, e), paint);
    }
  }
  canvas.restore();
}

/// A tiled material surface behind a child, for an **unframed** panel.
///
/// This is the surface roles' half of the family system: a card that has no
/// frame still differs from its neighbour by what it is made of. Draws the
/// flat [fill] first (so a tile that fails to load degrades to today's card),
/// then the grain, clipped to [radius].
class SurfaceFill extends StatefulWidget {
  const SurfaceFill({
    super.key,
    required this.tile,
    required this.fill,
    required this.child,
    this.radius,
  });

  final SurfaceTile tile;
  final Color fill;
  final BorderRadius? radius;
  final Widget child;

  @override
  State<SurfaceFill> createState() => _SurfaceFillState();
}

class _SurfaceFillState extends State<SurfaceFill> {
  late final _AssetImageSlot _slot = _AssetImageSlot(() {
    if (mounted) setState(() {});
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot.resolve(context, widget.tile.assetPath);
  }

  @override
  void didUpdateWidget(SurfaceFill old) {
    super.didUpdateWidget(old);
    if (old.tile.assetPath != widget.tile.assetPath) {
      _slot.resolve(context, widget.tile.assetPath);
    }
  }

  @override
  void dispose() {
    _slot.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? grain = _slot.image;
    return CustomPaint(
      painter: _SurfacePainter(
        tile: widget.tile,
        grain: grain,
        fill: widget.fill,
        radius: widget.radius,
      ),
      child: widget.child,
    );
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.tile,
    required this.grain,
    required this.fill,
    required this.radius,
  });

  final SurfaceTile tile;
  final ui.Image? grain;
  final Color fill;
  final BorderRadius? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = (radius ?? BorderRadius.zero).toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = fill);
    if (grain != null) paintSurfaceTile(canvas, rect, tile, grain!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.grain != grain ||
      old.tile.assetPath != tile.assetPath ||
      old.fill != fill ||
      old.radius != radius;
}

/// The frame painter, for a test that needs to paint into its own canvas and
/// read the pixels back.
///
/// "Edges tile rather than stretch" is the one claim in this file that cannot
/// be checked by inspecting a widget tree — it is only true or false in the
/// rendered pixels, and it is the exact property that separates this renderer
/// from `centerSlice`. So the painter gets a seam rather than the test getting
/// a golden file it would have to eyeball.
@visibleForTesting
CustomPainter debugFramePainter(PanelSkin skin, ui.Image image) =>
    _FramePainter(skin: skin, image: image);

/// Paints [PanelSkin]'s eight patches: four corners at integer scale, four
/// tiled strips, and **no interior**.
class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.skin,
    required this.image,
    this.surface,
    this.grain,
  });

  final PanelSkin skin;
  final ui.Image image;

  /// The interior tile and its decoded image; either null paints no interior,
  /// which is what every framed panel did before FMPO02.
  final SurfaceTile? surface;
  final ui.Image? grain;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = skin.corner;
    final double s = skin.scale.toDouble();
    final double c = n * s;

    // The interior first, under the band, so the frame's inner line always
    // sits on top of the grain. Inset by the band (the material's depth), not
    // the corner block — the same distinction `PanelSkin.band` documents.
    if (surface != null && grain != null) {
      final double b = skin.inset;
      paintSurfaceTile(
        canvas,
        Rect.fromLTWH(b, b, size.width - 2 * b, size.height - 2 * b),
        surface!,
        grain!,
      );
    }

    // Nearest neighbour, no anti-aliasing: the same contract PixelAsset holds.
    final Paint paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    void patch(Rect src, Rect dst) =>
        canvas.drawImageRect(image, src, dst, paint);

    final int iw = skin.nativeWidth;
    final int ih = skin.nativeHeight;

    // Corners, once each, at exact integer scale.
    patch(Rect.fromLTWH(0, 0, n * 1.0, n * 1.0), Rect.fromLTWH(0, 0, c, c));
    patch(
      Rect.fromLTWH((iw - n) * 1.0, 0, n * 1.0, n * 1.0),
      Rect.fromLTWH(size.width - c, 0, c, c),
    );
    patch(
      Rect.fromLTWH(0, (ih - n) * 1.0, n * 1.0, n * 1.0),
      Rect.fromLTWH(0, size.height - c, c, c),
    );
    patch(
      Rect.fromLTWH((iw - n) * 1.0, (ih - n) * 1.0, n * 1.0, n * 1.0),
      Rect.fromLTWH(size.width - c, size.height - c, c, c),
    );

    // Edge strips, REPEATED — never stretched (see the class doc). The final
    // tile in each run is clipped, which is why no once-only ornament may be
    // authored inside a strip.
    final double stripW = (iw - 2 * n) * s;
    final double stripH = (ih - 2 * n) * s;
    if (stripW <= 0 || stripH <= 0) return;

    final Rect topSrc = Rect.fromLTWH(n * 1.0, 0, (iw - 2 * n) * 1.0, n * 1.0);
    final Rect botSrc = Rect.fromLTWH(
      n * 1.0,
      (ih - n) * 1.0,
      (iw - 2 * n) * 1.0,
      n * 1.0,
    );
    final Rect leftSrc = Rect.fromLTWH(0, n * 1.0, n * 1.0, (ih - 2 * n) * 1.0);
    final Rect rightSrc = Rect.fromLTWH(
      (iw - n) * 1.0,
      n * 1.0,
      n * 1.0,
      (ih - 2 * n) * 1.0,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = c; x < size.width - c; x += stripW) {
      final double w = math.min(stripW, size.width - c - x);
      final Rect src = Rect.fromLTWH(
        topSrc.left,
        topSrc.top,
        topSrc.width * (w / stripW),
        topSrc.height,
      );
      patch(src, Rect.fromLTWH(x, 0, w, c));
      patch(
        Rect.fromLTWH(botSrc.left, botSrc.top, src.width, botSrc.height),
        Rect.fromLTWH(x, size.height - c, w, c),
      );
    }
    for (double y = c; y < size.height - c; y += stripH) {
      final double h = math.min(stripH, size.height - c - y);
      final Rect src = Rect.fromLTWH(
        leftSrc.left,
        leftSrc.top,
        leftSrc.width,
        leftSrc.height * (h / stripH),
      );
      patch(src, Rect.fromLTWH(0, y, c, h));
      patch(
        Rect.fromLTWH(rightSrc.left, rightSrc.top, rightSrc.width, src.height),
        Rect.fromLTWH(size.width - c, y, c, h),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.image != image ||
      old.skin.assetPath != skin.assetPath ||
      old.grain != grain ||
      old.surface?.assetPath != surface?.assetPath;
}

/// A box of exactly [width] × [height] that complains, in debug, when its
/// parent will not give it that much room.
class _ExactSizeBox extends SingleChildRenderObjectWidget {
  const _ExactSizeBox({
    required this.width,
    required this.height,
    required this.assetPath,
    required super.child,
  });

  final double width;
  final double height;
  final String assetPath;

  @override
  _RenderExactSizeBox createRenderObject(BuildContext context) =>
      _RenderExactSizeBox(width, height, assetPath);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderExactSizeBox renderObject,
  ) {
    renderObject
      ..width = width
      ..height = height
      ..assetPath = assetPath;
  }
}

class _RenderExactSizeBox extends RenderProxyBox {
  _RenderExactSizeBox(this._width, this._height, this._assetPath);

  double _width;
  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  double _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  String _assetPath;
  set assetPath(String value) => _assetPath = value;

  @override
  void performLayout() {
    assert(() {
      const double tolerance = precisionErrorTolerance;
      if (constraints.maxWidth + tolerance < _width ||
          constraints.maxHeight + tolerance < _height) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('PixelAsset was given less room than its sprite needs.'),
          ErrorDescription(
            '$_assetPath is drawn at ${_width}x$_height logical px, but its '
            'parent offered at most ${constraints.maxWidth}x'
            '${constraints.maxHeight}.',
          ),
          ErrorHint(
            'A container narrower than its pixel content silently rescales the '
            'sprite off its integer multiple, with no overflow stripe and '
            'nothing on screen to point at. Widen the container, or lower the '
            'scale.',
          ),
          ErrorHint(
            'Do NOT wrap this in OverflowBox, UnconstrainedBox or FittedBox. '
            'Those hide the defect rather than fixing it — the sprite still '
            'renders wrong, and the next reader has no way to find out why.',
          ),
        ]);
      }
      return true;
    }());

    final Size size = constraints.constrain(Size(_width, _height));
    child?.layout(BoxConstraints.tight(size));
    this.size = size;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _width;
  @override
  double computeMaxIntrinsicWidth(double height) => _width;
  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// A longitudinal strip tiled along one **horizontal** edge — the nav bar's
/// welt and the header's shelf.
///
/// ## Why chrome's edges are a widget and not a `Border`
///
/// A `Border` is one flat line in one colour, and both edges this replaces
/// were exactly that: a 1 px `borderDefault` rule across the top of the tab
/// bar, and the header's 24 %-alpha region hairline. `DECISIONS/0029` allows a
/// panel's **edge** to be authored raster, and an edge is the one place the
/// amended L-18 is unambiguous — no word, no number, no boundary Flutter has
/// to measure, just material where a line used to be.
///
/// Tiles horizontally only, at integer scale, from the left. The last tile is
/// clipped and never rescaled, which is why `check-tile-seam.js` measures these
/// two strips at their declared period before they ship: a join that beats
/// every 16 logical px along the bottom of every screen is the most visible
/// possible place to get it wrong.
///
/// ## The room is reserved whether or not the art decodes
///
/// [displayHeight] is the caller's layout figure, and the caller must spend it
/// unconditionally — the same doctrine as `PanelSkins.insetFor`. Until the
/// image resolves, and forever if it fails, the strip paints [fallbackColor] as
/// the one-logical-pixel line it replaced. So a missing raster changes the
/// material and not the layout, and the bar it terminates never briefly loses
/// its edge.
class EdgeStrip extends StatefulWidget {
  const EdgeStrip({
    super.key,
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
    this.fallbackColor,
    this.fallbackAtBottom = false,
    this.axis = Axis.horizontal,
  }) : assert(scale >= 1, 'integer multiples only, and at least 1');

  /// The nav bar's top welt — 8 × 4, period 8, drawn ×2. The boundary it
  /// replaces is the bar's top, so the fallback line is drawn there.
  const EdgeStrip.navWelt({super.key, this.fallbackColor, this.scale = 2})
    : assetPath = 'assets/ui/v1/nav/nav_welt.png',
      nativeWidth = 8,
      nativeHeight = 4,
      fallbackAtBottom = false,
      axis = Axis.horizontal;

  /// The screen header's bottom shelf — 8 × 6, period 8, drawn ×2. The
  /// boundary it replaces is the header's bottom, so the fallback line goes
  /// along the strip's last row rather than its first.
  const EdgeStrip.headerShelf({super.key, this.fallbackColor, this.scale = 2})
    : assetPath = 'assets/ui/v1/header/header_shelf.png',
      nativeWidth = 8,
      nativeHeight = 6,
      fallbackAtBottom = true,
      axis = Axis.horizontal;

  final String assetPath;

  /// The tile's own width — its repeat period, in source pixels.
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  /// Which way the run travels.
  ///
  /// Horizontal is a rule under a header or over a nav bar: full width, the
  /// tile repeating left to right, [displayHeight] deep. Vertical is a
  /// binding down a page's edge: full height, the tile repeating top to
  /// bottom, [displayHeight] wide.
  ///
  /// Defaults to horizontal, which is what every named constructor and every
  /// caller before EPO03 wants. It exists because [KitEdge] has always known
  /// its tile's axis and handled it in the *fallback* path, while this widget
  /// forced a horizontal run the moment the raster landed — so a vertical
  /// tile silently reversed its own geometry on arrival and threw an
  /// unbounded-width exception in any column that had reserved it.
  final Axis axis;

  /// The line drawn in the strip's place while the raster is absent. Null
  /// leaves the edge blank, which only a caller that draws its own line wants.
  final Color? fallbackColor;

  /// Which row of the reserved strip the fallback line sits on — the boundary
  /// the strip replaces. False is the strip's first row, true its last.
  final bool fallbackAtBottom;

  /// The strip's height in logical pixels — a horizontal run's thickness, and
  /// a vertical run's repeat period. **Reserve this, always.**
  double get displayHeight => (nativeHeight * scale).toDouble();

  /// The strip's width in logical pixels — a vertical run's thickness, and a
  /// horizontal run's repeat period.
  double get displayWidth => (nativeWidth * scale).toDouble();

  @override
  State<EdgeStrip> createState() => _EdgeStripState();
}

class _EdgeStripState extends State<EdgeStrip> {
  late final _AssetImageSlot _slot = _AssetImageSlot(() {
    if (mounted) setState(() {});
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot.resolve(context, widget.assetPath);
  }

  @override
  void didUpdateWidget(EdgeStrip old) {
    super.didUpdateWidget(old);
    if (old.assetPath != widget.assetPath) {
      _slot.resolve(context, widget.assetPath);
    }
  }

  @override
  void dispose() {
    _slot.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool horizontal = widget.axis == Axis.horizontal;
    // The run's THICKNESS is the tile's cross-axis size, and the tile repeats
    // along the main axis. A horizontal rule is `nativeHeight` deep and
    // repeats every `nativeWidth`; a vertical binding is `nativeWidth` wide
    // and repeats every `nativeHeight`. Taking the thickness from the same
    // dimension either way would clip the spine — `edge_spine` is 32 × 7, so
    // a 7-wide box would show a fifth of it.
    final Widget run = SizedBox(
      width: horizontal ? double.infinity : widget.displayWidth,
      height: horizontal ? widget.displayHeight : double.infinity,
      child: CustomPaint(
        painter: _EdgeStripPainter(
          image: _slot.image,
          scale: widget.scale.toDouble(),
          fallbackColor: widget.fallbackColor,
          fallbackAtBottom: widget.fallbackAtBottom,
          axis: widget.axis,
        ),
      ),
    );
    // `double.infinity` on the main axis means "as long as the parent allows",
    // and throws outright when the parent allows anything at all — a scroll
    // view, an intrinsic pass, or a Row child without an Expanded. A strip is
    // decoration: it should take the run it is given and draw nothing extra
    // when there is no run to take, never bring the frame down. LimitedBox
    // applies its bound *only* under an unbounded constraint, so bounded
    // callers are byte-identical to before and unbounded ones get a finite
    // run instead of an exception.
    return LimitedBox(
      maxWidth: horizontal ? 0 : double.infinity,
      maxHeight: horizontal ? double.infinity : 0,
      child: run,
    );
  }
}

class _EdgeStripPainter extends CustomPainter {
  _EdgeStripPainter({
    required this.image,
    required this.scale,
    required this.fallbackColor,
    required this.fallbackAtBottom,
    this.axis = Axis.horizontal,
  });

  final ui.Image? image;
  final double scale;
  final Color? fallbackColor;

  /// Which end of the run the fallback line sits on: the strip's first row or
  /// column when false, its last when true.
  final bool fallbackAtBottom;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final bool horizontal = axis == Axis.horizontal;
    final ui.Image? img = image;
    if (img == null) {
      if (fallbackColor case final Color c) {
        canvas.drawRect(
          horizontal
              ? Rect.fromLTWH(
                  0,
                  fallbackAtBottom ? size.height - 1 : 0,
                  size.width,
                  1,
                )
              : Rect.fromLTWH(
                  fallbackAtBottom ? size.width - 1 : 0,
                  0,
                  1,
                  size.height,
                ),
          Paint()..color = c,
        );
      }
      return;
    }
    final Paint paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final Rect src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final double w = img.width * scale;
    final double h = img.height * scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (horizontal) {
      for (double x = 0; x < size.width; x += w) {
        canvas.drawImageRect(img, src, Rect.fromLTWH(x, 0, w, h), paint);
      }
    } else {
      // A vertical run repeats down its own length. The tile is authored for
      // a horizontal rule, so it is drawn unrotated and simply stacked: the
      // kit's vertical tiles (the page binding) are authored that way.
      for (double y = 0; y < size.height; y += h) {
        canvas.drawImageRect(img, src, Rect.fromLTWH(0, y, w, h), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgeStripPainter old) =>
      old.image != image ||
      old.scale != scale ||
      old.fallbackColor != fallbackColor ||
      old.fallbackAtBottom != fallbackAtBottom ||
      old.axis != axis;
}
