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

  /// Item icons — 20 × 20 native, 40 logical at ×2.
  const PixelAsset.item(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 20,
      nativeHeight = 20;

  /// Skill icons — **12 × 12**, not 14 × 14.
  ///
  /// `UI_SYSTEM_PROPOSED_01.md` §5 records 14 × 14; that is wrong. Measured from
  /// the PNG headers, and `build_html.js` agrees (`SKILL = px(n,[12,12],2)`).
  const PixelAsset.skill(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 12,
      nativeHeight = 12;

  /// Navigation glyphs — 14 × 14.
  const PixelAsset.nav(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 14,
      nativeHeight = 14;

  /// The steps and arrow glyphs — 12 × 12.
  const PixelAsset.glyph(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 12,
      nativeHeight = 12;

  /// The character portrait — 48 × 48.
  const PixelAsset.portrait(this.assetPath, {super.key, this.scale = 2})
    : nativeWidth = 48,
      nativeHeight = 48;

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
