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

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
