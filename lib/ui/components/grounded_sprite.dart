/// The composition rule for standalone characters: a footprint-derived contact
/// shadow, applied wherever a sprite is placed on a background.
///
/// ## The finding this implements
///
/// A blind reviewer, asked about grounding in the Haven's Rest scene, volunteered
/// the diagnosis unprompted:
///
/// > "The palisade posts bite into the slope and follow its contour… the
/// > woodshed, forge canopy, well and swing frame all have darkened bases and
/// > cast contact darkening onto the dirt. **The environment is grounded. The
/// > three figures are the only floating elements.**"
///
/// That narrows the problem sharply, and it is the reason this widget exists
/// rather than a grounding pass over every asset. **PixelLab grounds what it
/// generates inside a scene.** The recurring floating defect is specific to
/// compositing a sprite *onto* a background — which is exactly, and only, what
/// this widget does.
///
/// ## Why the shadow is derived rather than authored
///
/// The width comes from [SpriteFootprint], measured from the sprite's own lowest
/// opaque rows at packaging time. A caller places a sprite; it cannot pass a
/// shadow width, because there is no parameter for one. So the shadow cannot
/// disagree with the figure standing on it, and it cannot drift between scenes —
/// the two ways a hand-placed shadow goes wrong.
///
/// The alternative was tested and rejected. Asking PixelLab to `inpaint_image` a
/// shadow onto the floor produced one, and a reviewer independently found
/// "a distinct patch — hard-edged, flatter plank treatment, different value",
/// because inpainting re-renders the whole masked band and the floor tone shifts
/// with it. This route is free, exact, deterministic, and touches nothing but
/// the pixels under the feet.
library;

import 'package:flutter/widgets.dart';

import '../icons/sprite_footprints.dart';
import 'pixel_asset.dart';

/// How the contact shadow is shaped, in **sprite-native pixels**.
///
/// Tuned once, here, so every grounded sprite in the product matches. The
/// numbers are not the ones that look right in isolation: at the first tuning
/// (strength 0.45, squash 0.22) a blind reviewer **could not perceive the shadow
/// at all** against a busy background at play scale.
abstract final class ContactShadowSpec {
  const ContactShadowSpec._();

  /// Peak darkening directly under the figure, as a multiply factor.
  ///
  /// Multiply, never a painted grey: the result is `background × (1 - strength)`,
  /// so the shadow takes the ground's own hue with it. A grey ellipse would be
  /// the same colour on grass and on floorboards, which is the tell that gives
  /// away a fake shadow instantly.
  static const double strength = 0.72;

  /// Ellipse height as a fraction of its width. A contact shadow is short —
  /// anything taller reads as a cast shadow and therefore as a light source the
  /// scene does not have.
  static const double squash = 0.30;

  /// Native pixels wider, each side, than the contact span itself.
  static const double spread = 3;

  /// Native pixels above the sprite's lowest row, so the shadow sits under the
  /// feet rather than behind them.
  static const double inset = 1;

  /// Native pixels of room reserved below the sprite for the ellipse's lower
  /// half, which would otherwise be clipped by the sprite's own box.
  static const double bleed = 4;
}

/// A sprite composited onto a background, with its contact shadow.
///
/// Use this for **every** standalone character placed on scenery. A bare
/// [PixelAsset.sprite] on a background is the floating defect.
class GroundedSprite extends StatelessWidget {
  const GroundedSprite({
    super.key,
    required this.assetPath,
    required this.footprint,
    this.scale = 2,
    this.canvas = 64,
    this.canvasHeight,
  });

  final String assetPath;

  /// Native frame width, in sprite pixels. 64 for a Traveler sprite; smaller
  /// for an ambient companion layer such as the cat. Every canvas gets the same
  /// footprint-derived shadow, which is the point of the widget.
  final int canvas;

  /// Native frame height; defaults to [canvas] (square). Three ambient scenes
  /// are 80 × 64 and one is 96 × 64 — see `ambient_assets.dart`.
  final int? canvasHeight;

  /// Where this sprite meets the ground, measured at packaging time.
  final SpriteFootprint footprint;

  final int scale;

  @override
  Widget build(BuildContext context) {
    final int height = canvasHeight ?? canvas;
    final PixelAsset sprite = canvas == 64 && height == 64
        ? PixelAsset.sprite(assetPath, scale: scale)
        : PixelAsset(
            assetPath: assetPath,
            nativeWidth: canvas,
            nativeHeight: height,
            scale: scale,
          );
    final double bleed = ContactShadowSpec.bleed * scale;

    return SizedBox(
      width: sprite.displayWidth,
      height: sprite.displayHeight + bleed,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _ContactShadowPainter(
                footprint: footprint,
                scale: scale.toDouble(),
              ),
            ),
          ),
          // Top-left, not centred: the bleed is room for the shadow, and
          // centring inside it would lift the sprite off its own feet by half
          // of it.
          Positioned(top: 0, left: 0, child: sprite),
        ],
      ),
    );
  }
}

class _ContactShadowPainter extends CustomPainter {
  const _ContactShadowPainter({required this.footprint, required this.scale});

  final SpriteFootprint footprint;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = footprint.centerX * scale;
    final double centerY = (footprint.bottom - ContactShadowSpec.inset) * scale;
    final double rx = (footprint.width / 2 + ContactShadowSpec.spread) * scale;
    final double ry = rx * ContactShadowSpec.squash;

    final Rect oval = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: rx * 2,
      height: ry * 2,
    );

    // The falloff mirrors the reference implementation exactly: alpha at
    // normalised radius r is `(1 - r²) × strength`. The stops below sample that
    // curve rather than approximating it with a straight ramp, which would put
    // a visible hard rim on the ellipse.
    const double s = ContactShadowSpec.strength;
    canvas.drawOval(
      oval,
      Paint()
        // Multiply against what is already painted beneath — the scenery, or a
        // card's fill. This is why a grounded sprite must share a layer with
        // its background rather than sitting behind an opacity or a shader
        // mask of its own.
        ..blendMode = BlendMode.multiply
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF000000).withValues(alpha: s),
            const Color(0xFF000000).withValues(alpha: s * 0.75),
            const Color(0xFF000000).withValues(alpha: s * 0.4375),
            const Color(0x00000000),
          ],
          stops: const <double>[0, 0.5, 0.75, 1],
        ).createShader(oval),
    );
  }

  @override
  bool shouldRepaint(_ContactShadowPainter old) =>
      old.footprint != footprint || old.scale != scale;
}
