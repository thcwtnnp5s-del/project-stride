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

/// What a panel's **interior** is made of — the second identity axis.
///
/// `DECISIONS/0029` gave a panel three ways to differ from its neighbour:
/// **band, surface, picture.** VAWO01 built the frame and none of the other
/// two, so one leather chassis carried every identity and became wallpaper —
/// the owner's device verdict on 4d9a81f was "large leather frame containing
/// ordinary rounded dark cards", everywhere. This enum is the surface axis.
///
/// It is **orthogonal** to [PanelRole]: a role selects a frame, a surface
/// selects an interior, and no combination adds a border. Eleven screen
/// families ride eight materials (`ART-13_material_brief.md`), and the
/// materials are *materials* — grain, not pattern, no depicted object, no
/// light source of their own — so body text can sit on any of them.
enum PanelSurface {
  /// The flat `surfaceCard` fill: what every panel had before FMPO02.
  none,

  /// Aged parchment — the field journal (Adventure), the recipe folio
  /// (Craft), the traveler folio (Character), the field guide (Encounters).
  journalLeaf,

  /// Waxed canvas — the materials tray (Craft), the pack (Inventory).
  oilcloth,

  /// Vellum — the guild handbook (Skills).
  buckram,

  /// Oiled leather — the field combat kit.
  leather,

  /// Dark bench oak — the crafting station header.
  benchOak,

  /// Steel plate — combat command surfaces.
  steel,

  /// Slate — the bestiary board.
  slate,

  /// Linen backing — the navigator's atlas.
  chartVellum,

  /// Cork — pinned notices (Boards).
  cork,

  /// Chalked slate — the construction ledger (Projects).
  planLinen,
}

/// A seamless interior tile: drawn at integer scale from a panel's inner
/// top-left corner, clipped, never rescaled.
@immutable
final class SurfaceTile {
  const SurfaceTile({
    required this.assetPath,
    required this.native,
    this.scale = 2,
  }) : assert(native > 0),
       assert(scale >= 1, 'integer scale only (L-18)');

  final String assetPath;

  /// The square tile's native edge, in source pixels.
  final int native;

  /// Integer display scale (L-18).
  final int scale;

  /// The tile's drawn edge in logical pixels.
  double get extent => (native * scale).toDouble();
}

/// Surface → authored tile.
///
/// A missing row is [PanelSurface.none] by construction: the panel paints the
/// flat fill it always painted. Rows land with a device review, not a compile.
abstract final class PanelSurfaces {
  const PanelSurfaces._();

  static const String _dir = 'assets/ui/v1/surface';

  /// The registry. Every tile is 32² native at ×2 unless its row says
  /// otherwise; geometry is measured from the PNG and mirrored in the
  /// tile-seam guard's JSON.
  static const Map<PanelSurface, SurfaceTile> authored =
      <PanelSurface, SurfaceTile>{
        PanelSurface.journalLeaf: SurfaceTile(
          assetPath: '$_dir/grain_journal_leaf.png',
          native: 32,
        ),
        PanelSurface.oilcloth: SurfaceTile(
          assetPath: '$_dir/grain_oilcloth.png',
          native: 32,
        ),
        PanelSurface.buckram: SurfaceTile(
          assetPath: '$_dir/grain_buckram.png',
          native: 32,
        ),
        PanelSurface.leather: SurfaceTile(
          assetPath: '$_dir/grain_leather.png',
          native: 32,
        ),
        PanelSurface.benchOak: SurfaceTile(
          assetPath: '$_dir/grain_bench_oak.png',
          native: 32,
        ),
        PanelSurface.steel: SurfaceTile(
          assetPath: '$_dir/grain_steel.png',
          native: 32,
        ),
        PanelSurface.slate: SurfaceTile(
          assetPath: '$_dir/grain_slate.png',
          native: 32,
        ),
        PanelSurface.chartVellum: SurfaceTile(
          assetPath: '$_dir/grain_chart_vellum.png',
          native: 32,
        ),
        PanelSurface.cork: SurfaceTile(
          assetPath: '$_dir/grain_cork.png',
          native: 32,
        ),
        PanelSurface.planLinen: SurfaceTile(
          assetPath: '$_dir/grain_plan_linen.png',
          native: 32,
        ),
      };

  /// The tile for [surface], or null for the flat fill.
  static SurfaceTile? of(PanelSurface surface) => authored[surface];
}

/// Role → authored frame.
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
  /// ## One framed element per screen (FMPO02)
  ///
  /// VAWO01 registered the chassis against **every** role, and the owner's
  /// device verdict on that build was the exact failure `panel_skin.dart`'s
  /// own header predicted: the frame became wallpaper. A leather welt around
  /// a five-line list, a button pair and a portrait alike means nothing, and
  /// the product read as "one big leather frame containing ordinary rounded
  /// dark cards" on every tab.
  ///
  /// So the registry is inverted on purpose. The frame belongs to the one
  /// thing a screen is *about* — its picture ([PanelRole.heroPlate]) and an
  /// interruption raised over the screen ([PanelRole.modalFrame]). Every
  /// other role is a **surface**: it differs from its neighbour by material
  /// ([PanelSurface]), by band, by picture — never by a second border. That
  /// is L-18 as amended read literally, and it is the doctrine of
  /// `MILESTONES/evidence/FMPO02/wave1/ART-01_executive_doctrine.md` §4 R1.
  ///
  /// Removing four rows is delivered work here, not a regression.
  static const Map<PanelRole, PanelSkin> authored = <PanelRole, PanelSkin>{
    PanelRole.heroPlate: _chassis,
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

  /// The room each role keeps for a frame it does not have. The two framed
  /// roles reserve their real inset, so a failed decode changes the material
  /// and not the layout. The surface roles reserve **zero**: they are not
  /// waiting for a frame — a frame is the wrong answer for them — and a
  /// reserve here would be sixteen logical pixels of air on every side of
  /// every list in the app, kept for art that must never arrive.
  static const Map<PanelRole, double> _reserve = <PanelRole, double>{
    PanelRole.heroPlate: 16,
    PanelRole.modalFrame: 16,
  };
}
