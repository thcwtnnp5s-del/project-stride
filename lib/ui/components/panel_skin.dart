/// What a panel is made of — the seam that lets authored frame art replace a
/// painted rectangle without touching a single call site.
///
/// ## The problem this exists to solve
///
/// Wave 0 of PRESENTATION_COMBAT_EVOLUTION_01 audited the owner's standing
/// criticism — the product "still looks too much like generic / AI-authored
/// Flutter UI" — and found it accurate but misattributed. There is no stock
/// Material anywhere in this app: no `Card`, no `Chip`, no `ListTile`, no
/// `ElevatedButton`, no `LinearProgressIndicator`, no `AlertDialog`, no
/// `Icons.*`. The genericness comes from something narrower and harder to see:
///
/// **`SectionCard` draws one rectangle — radius 14, one 1 px border in one
/// colour, one fill — at thirty-four call sites**, and thirty-one of those do
/// not take even the optional hue wash. The washes that do exist are authored
/// within ~6 L\* of the card colour, so they are sub-perceptual by
/// construction and cannot carry identity however they are used.
///
/// Meanwhile 896 files of hand-authored pixel art render every creature, item,
/// place and character in the game. Hand-made sprites, sitting inside
/// machine-drawn rectangles. That seam is what "an authored RPG versus an
/// application displaying RPG data" describes, from the player's side.
///
/// ## Why this is a registry and not a parameter
///
/// A call site names a **role** — what this panel *is* — and this file decides
/// whether that role has art yet. So:
///
/// - Today [PanelSkins.authored] is **empty**, every role resolves to null,
///   and every panel paints exactly what it painted before. The architecture
///   lands with zero visual risk and zero device regression surface.
/// - When a frame family is produced, one map entry lights up every panel of
///   that role at once. No call site changes, ever.
/// - If device review rejects the direction, emptying the map reverts the
///   entire product in one commit. That reversibility is a deliberate property
///   and must survive future edits to this file.
///
/// ## The rule this obeys
///
/// `DECISIONS/0029` (owner ruling, 2026-08-31) amended `ART_DIRECTION.md`
/// L-18, which previously read *"the interface is not pixelated; the content
/// is."* Interface chrome may now be authored pixel art. The boundary it
/// replaced that sentence with is enforced here and in [PixelFrame]:
///
/// > A raster asset may occupy only a panel's outer **edge**, a panel's
/// > interior as a low-variation tiled **surface**, or a discrete **ornament**
/// > Flutter positions. It may never carry a word, a number, a state, or a
/// > boundary Flutter needs to measure.
///
/// **The enforcing test** — `test/panel_skin_test.dart` — is that with the
/// registry empty the app must still lay out, read and navigate identically.
/// Art may change how Stride feels; it may never change what Stride does.
library;

import 'package:flutter/widgets.dart';

/// What a panel *is*, independent of what it is currently made of.
///
/// Deliberately a small closed set. The failure mode this direction is most
/// likely to produce is eleven unrelated borders — one per screen — so roles
/// name **kinds of surface**, not screens. Two screens showing the same kind
/// of thing share a role and therefore share a frame.
enum PanelRole {
  /// The ordinary content container. The overwhelming majority of panels, and
  /// the one whose appearance defines the product's register.
  card,

  /// The single focal panel on a screen — the one thing the eye should land
  /// on. At most one per screen, by convention, and never rendered when its
  /// subject is absent (an empty hero reads worse than none).
  heroPlate,

  /// A panel raised over a scrim: the reward layer, an outcome, a modal. The
  /// one place a heavier, more ornate edge belongs, because an interruption
  /// should feel like one.
  modalFrame,

  /// The compartment grid of a kit — inventory tiles, ingredient slots. Wants
  /// a surface, not a frame; the wells around the items already read.
  kitTray,

  /// The fight's own ground. Distinct from [modalFrame] because combat is not
  /// an interruption, it is a place.
  combatFrame,

  /// A pinned note or ledger strip — board contracts, project slips.
  boardSlip,
}

/// An authored frame for a [PanelRole]: which pixels are corner, which repeat,
/// and how much room the frame needs inside the panel.
///
/// Every field is measured from the asset, never guessed. A frame whose
/// declared geometry disagrees with its PNG renders wrong in a way that looks
/// like a layout bug, which is the most expensive kind of art defect to
/// diagnose — so [PixelFrame] asserts the arithmetic in debug.
@immutable
final class PanelSkin {
  const PanelSkin({
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    required this.corner,
    required this.band,
    required this.scale,
    this.surfacePath,
    this.surfaceNative = 32,
  }) : assert(corner > 0, 'a frame with no corner is a surface, not a frame'),
       assert(scale >= 1, 'integer scale only (L-18)'),
       assert(
         band > 0 && band <= corner,
         'the band is the frame material inside the corner block, so it is '
         'at least one pixel and never wider than the block that contains it',
       ),
       assert(
         nativeWidth > corner * 2 && nativeHeight > corner * 2,
         'the asset must have edge strip left over after both corners',
       );

  /// The nine-patch source: corners in the four corners, tileable edge strips
  /// between them, and an interior that is **never drawn** (the panel's own
  /// fill or [surfacePath] owns it).
  final String assetPath;

  final int nativeWidth;
  final int nativeHeight;

  /// The square corner block's native size, in source pixels. Everything
  /// outside the corners on each side is the repeating strip.
  ///
  /// This is a **drawing** figure, not a layout one: the block is larger than
  /// the frame material it contains, because it also holds the rounded corner
  /// and the transparent bite outside it. Do not inset content by it — see
  /// [band].
  final int corner;

  /// The frame material's thickness, in source pixels — how far the drawn edge
  /// actually reaches inward from the panel's boundary.
  ///
  /// **This, not [corner], is what content is inset by.** The distinction is
  /// not pedantic: a 16 px corner block at ×2 would inset every panel by 32
  /// logical pixels a side — 64 of a 320 dp phone's width, a fifth of the
  /// screen — and the resulting text-wrap regression would be blamed on the
  /// art rather than on the arithmetic. Caught in review before any asset
  /// existed, which is the only cheap time to catch it.
  final int band;

  /// Integer display scale (L-18). Never fractional, never derived from
  /// available width — a frame that rescales to fit is a frame that has
  /// stopped being pixel art.
  final int scale;

  /// An optional seamless interior tile. Low tonal variation only: this sits
  /// behind body text, so it is grain, not pattern.
  final String? surfacePath;
  final int surfaceNative;

  /// How much room the frame occupies inside the panel, in logical pixels.
  /// Content is inset by this so the frame never overlaps text.
  double get inset => (band * scale).toDouble();

  /// The corner block's drawn size in logical pixels — the painter's figure.
  double get cornerExtent => (corner * scale).toDouble();
}

/// Role → authored frame. **Empty by design.**
///
/// This is the whole integration surface of `DECISIONS/0029`. The
/// post-refresh production queue in
/// `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` produces assets; landing
/// them is adding rows here.
abstract final class PanelSkins {
  const PanelSkins._();

  /// The registry.
  ///
  /// **Adding a row is a visual change to every panel of that role at once.**
  /// That is the point, and it is also the risk: a row lands with a device
  /// review, not with a compile.
  ///
  /// Authored in VAWO01 (`DECISIONS/0030`, which reopened the PixelLab budget
  /// that `0029` recorded as exhausted).
  ///
  /// **Every role, one asset.** That is L-18 as amended read literally — "one
  /// chassis family app-wide; screens differ by band, surface and picture,
  /// never by eleven different borders" — and it is a correction to this
  /// registry's first shape, which framed three roles and left three painted.
  ///
  /// Three framed and three painted was defensible per role and wrong as a
  /// product: it put an authored leather edge on Skills, Character and
  /// Adventure while Inventory and Combat kept the machine-drawn rectangle the
  /// whole direction exists to remove. The player does not experience roles,
  /// they experience screens, and half a chassis reads as an unfinished one.
  ///
  /// The per-role differentiation the production plan reserves — a heavier
  /// modal band, combat's own scarred edge — remains the right destination. It
  /// is a **later batch**, and until it exists the honest state is one family
  /// everywhere rather than a family and a gap.
  static const Map<PanelRole, PanelSkin> authored = <PanelRole, PanelSkin>{
    PanelRole.card: _chassis,
    PanelRole.heroPlate: _chassis,
    PanelRole.boardSlip: _chassis,
    PanelRole.kitTray: _chassis,
    PanelRole.combatFrame: _chassis,
    PanelRole.modalFrame: _chassis,
  };

  /// The chassis: oiled leather welt with a continuous stitch line and
  /// reinforced corner caps, from a traveller's journal cover.
  ///
  /// Geometry is measured from the PNG, never guessed, and is mirrored in
  /// `assets/ui/v1/frame/chassis_64.json` for the tile-seam guard. `band` is 8
  /// and `corner` is 16: the corner block has to contain the whole corner cap,
  /// while the band is only the material depth — insetting by `corner` would
  /// cost every panel 32 logical px per side (production plan § 3.2.1).
  static const PanelSkin _chassis = PanelSkin(
    assetPath: 'assets/ui/v1/frame/chassis_64.png',
    nativeWidth: 64,
    nativeHeight: 64,
    corner: 16,
    band: 8,
    scale: 2,
  );

  /// The frame for [role], or null when that role is still painted.
  static PanelSkin? of(PanelRole role) => authored[role];

  /// How much a [role] insets its content, authored or not.
  ///
  /// Returns the **same** figure whether or not art exists, so a frame landing
  /// later changes the material and not the layout. Without this, every panel
  /// in the product would reflow on the day the first asset shipped, and the
  /// art would be blamed for the reflow.
  static double insetFor(PanelRole role) =>
      authored[role]?.inset ?? _reserve[role] ?? 0;

  /// The room each role keeps for a frame it does not have yet. Chosen to
  /// match the geometry the production plan specifies, so the reserve is a
  /// prediction the art must honour rather than a number the art will fight.
  /// The fallback figure used if the asset fails to decode. Every role now
  /// resolves to the chassis, so every reserve equals its real inset — which is
  /// what makes a failed decode change the material and not the layout.
  static const Map<PanelRole, double> _reserve = <PanelRole, double>{
    PanelRole.card: 16,
    PanelRole.kitTray: 16,
    PanelRole.heroPlate: 16,
    PanelRole.boardSlip: 16,
    PanelRole.combatFrame: 16,
    PanelRole.modalFrame: 16,
  };
}
