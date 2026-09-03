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

  /// Warm dark parchment, mirror-folded and seamless — the notable-result
  /// plate (`ActivityResultCard`, FMPO02 wave2). Low-contrast by
  /// authoring, since this is the one surface tile drawn directly under
  /// body type rather than a section's background.
  notable,
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
        PanelSurface.notable: SurfaceTile(
          assetPath: '$_dir/grain_notable_plate.png',
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

/// The two authored **button plates** (FMPO02 wave 2).
///
/// ## Why these are not rows in [PanelSkins]
///
/// [PanelRole] names kinds of *panel*, and the registry's whole property is
/// that emptying it reverts every panel in one commit. A button is not a
/// panel: it is a control with a hit region, a pressed state and a disabled
/// state, and folding it into the panel registry would mean the panel
/// kill-switch also silently unstyles every action in the product. Two named
/// constants keep both reversions separate and both one-line.
///
/// ## The geometry is what the model drew, not what the brief asked for
///
/// `ART-02_ui_brief.md` asked for corner 8 / band 4 on the plate and corner 6 /
/// band 3 on the compact. PixelLab drew a thinner rim than that on every
/// candidate, and the sidecars beside the PNGs carry the **measured** figures.
/// Declaring the brief over the asset is the exact defect
/// `PIXELLAB_UI_PRODUCTION_PLAN.md` § 3.2.1 exists to prevent — a frame whose
/// declared geometry disagrees with its pixels renders wrong in a way that
/// looks like a layout bug.
abstract final class ButtonPlates {
  const ButtonPlates._();

  static const String _dir = 'assets/ui/v1/button';

  /// The screen's game action — `Gather`, `Set out`, `Craft`.
  ///
  /// **`band` is 1, and the asset's measured band is 0.** That is not a
  /// disagreement with the sidecar; it is [PanelSkin]'s own invariant, which
  /// asserts `band > 0` because a frame with no material depth is a surface
  /// rather than a frame. The measurement stands: `btn_plate.json` records 0,
  /// and PROD-UI's integration note says a 0 band is legal *for a button and
  /// only for a button*, because a button's interior is a face with a label on
  /// it and the inset is Flutter's padding. Declaring 1 spends two logical
  /// pixels of inset the label already had to spare, and keeps the assert
  /// honest for every panel that comes after. **Do not carry a 0 band to a
  /// panel, and do not weaken the assert to allow one.**
  static const PanelSkin primary = PanelSkin(
    assetPath: '$_dir/btn_plate.png',
    nativeWidth: 58,
    nativeHeight: 26,
    corner: 4,
    band: 1,
    scale: 2,
  );

  /// The utility control — `Sync steps`, `Cancel`, `Retreat`. Measured corner
  /// 5 / band 2, exactly as the sidecar records them.
  static const PanelSkin compact = PanelSkin(
    assetPath: '$_dir/btn_compact.png',
    nativeWidth: 46,
    nativeHeight: 22,
    corner: 5,
    band: 2,
    scale: 2,
  );
}

// =============================================================================
// EPO03 — THE KIT
//
// `DECISIONS/0029` gives a raster exactly three jobs: a panel's **edge**, a
// panel's interior as a low-variation tiled **surface**, and a discrete
// **ornament** Flutter positions. The three registries below are those three
// jobs, named, so that eight screen teams rebuilding in parallel reach for one
// vocabulary instead of eight.
//
// ## Why these are not rows in [PanelSkins]
//
// [PanelSkins] answers "what is the frame around a **panel**", and
// `test/panel_skin_test.dart` pins it to exactly two roles and exactly one
// asset — because VAWO01 registered a frame against every role and the owner's
// device verdict was that the frame had become wallpaper. That cap is a
// finding, not an accident, and the kit must not route around it: a well cut
// into leather, a ribbon behind a level, a tab on a folio's edge are **not
// panels**, they are the furniture inside one. Separate registries keep the
// panel kill-switch and the kit's own reversibility independent, exactly as
// [ButtonPlates] does for controls.
//
// ## The property every row here has
//
// A missing row resolves to null, the widget paints its declared fallback, and
// **the layout figure is the same either way** — the `...For()` lookups return
// the declared geometry whether or not the art exists. So a screen team codes
// against a name today, the art lands later, and nothing reflows on the day it
// does. That is `PanelSkins.insetFor`'s doctrine applied to the whole kit, and
// it is what the wave-2 contract
// (`MILESTONES/evidence/EPO03/wave2/KIT_CONTRACT.md`) promises seven teams in
// writing.
// =============================================================================

/// A piece of authored chrome cut as a nine-patch: corners drawn once, edges
/// tiled, interior never drawn.
///
/// Every member is furniture inside a panel — a well, a plate, a ribbon, a tab.
/// None of them is a panel's own border; that is [PanelRole]'s job and it is
/// capped at one family on purpose.
enum KitFrame {
  /// A window cut into the page for a figure — the bust, the equipped
  /// traveller. Inventory and Character.
  insetWell,

  /// A single compartment: an equipment slot, an item well, a station plinth.
  slotWell,

  /// A window that frames a picture rather than a panel — the gather stage,
  /// the creature on an encounter plate.
  insetStage,

  /// Combat's heavy frame. The gauges hang from its lower band.
  ///
  /// **L-18a is why this is chrome and not a plane.** `DECISIONS/0031` fixes
  /// density as a property of a plane: the stage's backdrop and figures share
  /// this frame but not its plane. It draws at its own scale, shares no ground
  /// line, overlaps no figure and is crossed by no tool arc, so it adds no
  /// third density and needs no amendment to L-18a.
  stageFrame,

  /// A sealed page in the recipe book — Craft's locked tiers.
  pageSealed,

  /// A pinned slip. Adventure's goals.
  slipPinned,

  /// The plate behind a short label: a level, a rarity, a boss mark, a cost.
  /// **The words are Flutter's**; this is only what they sit on.
  ribbonLabel,

  /// An index tab on a folio's edge (Craft), and the leather tab on the World
  /// peek strip.
  tabPlate,

  /// The World peek strip's leather plate.
  peekPlate,

  /// An atlas marker's label plate, and its selected, ember-edged twin.
  labelPlate,
  labelPlateSelected,

  /// The bottom nav's stamped well, and the raised lit plate on the active tab.
  navWell,
  navPlateActive,

  /// The one primary action plate per screen. Replaces `btn_plate` when its
  /// geometry is measured, not before.
  btnPlateV2,
}

/// Frame to authored nine-patch.
///
/// Empty today by measurement rather than by plan. Fourteen `pixen` rolls
/// across three prompt strategies produced no usable flat nine-patch: the model
/// draws a lit object in perspective, decorated with studs, above the `#7C7263`
/// ceiling. FMPO02 recorded the same boundary for `modal_128`,
/// `strap_corner_64`, `corner_mark_48`, `tab_index_32x16` and `nav_plate_32`
/// and shipped none of them. `MISTAKES.md` M-05 forbids re-rolling into a
/// reason already written down, so the round spent its remaining budget where
/// the model succeeds — material strips and material sheets — and every
/// consumer below draws its declared fallback. The ledger is
/// `GAME_BIBLE/ART/exploration/EPO03/ledger/UI_KIT.md`.
abstract final class KitFrames {
  const KitFrames._();

  static const String _dir = 'assets/ui/v1/kit';

  /// The registry. A row lands with a device read, never with a compile.
  ///
  /// Three rows, all from `create_image_pro` with an accepted grain tile as the
  /// style reference and `chassis_64` as the construction reference. Every
  /// figure below is **measured** — `tools/frame-measure.js` for the band,
  /// `tools/ninepatch-proof.js` for the corner — never taken from the brief.
  static const Map<KitFrame, PanelSkin> authored = <KitFrame, PanelSkin>{
    KitFrame.insetWell: PanelSkin(
      assetPath: '$_dir/inset_well.png',
      nativeWidth: 61,
      nativeHeight: 61,
      corner: 16,
      band: 15,
      // ×1. Band 15 at ×2 would inset every well by 30 logical px a side.
      scale: 1,
    ),
    KitFrame.slotWell: PanelSkin(
      assetPath: '$_dir/slot_well.png',
      nativeWidth: 32,
      nativeHeight: 32,
      corner: 6,
      // Measured 5/4/5/4; the MINIMUM is declared, so the frame never draws
      // over content on the two shallower sides.
      band: 4,
      scale: 2,
    ),
    KitFrame.pageSealed: PanelSkin(
      assetPath: '$_dir/page_sealed.png',
      nativeWidth: 61,
      nativeHeight: 61,
      corner: 18,
      band: 15,
      scale: 1,
    ),
    KitFrame.btnPlateV2: PanelSkin(
      assetPath: '$_dir/btn_plate_v2.png',
      nativeWidth: 56,
      nativeHeight: 24,
      // Corner 8, not the band's 5: at 5 the rounded corner is clipped and the
      // plate reads square (`review/ui/np_btn5.png`).
      corner: 8,
      band: 5,
      scale: 2,
    ),
    KitFrame.stageFrame: PanelSkin(
      assetPath: '$_dir/stage_frame.png',
      nativeWidth: 114,
      nativeHeight: 114,
      // **26, not 19, and the difference is the whole asset.** The band is 19,
      // but the iron corner cap is wider than that: with corner 19 the cap
      // falls inside the edge strip and repeats along every beam, which
      // `ninepatch-proof.js` renders and `review/ui/np_stage19.png` shows. At
      // 26 the cap is drawn once per corner and the beams run unbroken.
      corner: 26,
      band: 19,
      scale: 1,
    ),
  };

  /// The geometry each frame is **declared** to have, whether or not it has
  /// art. This is what a caller insets by, so the day a row lands nothing
  /// moves — the material changes and the layout does not.
  static const Map<KitFrame, double> _declaredInset = <KitFrame, double>{
    // The three landed rows declare exactly what their art measures, so
    // `insetFor` returns one number either way — see the class doc.
    KitFrame.insetWell: 15,
    KitFrame.slotWell: 8,
    KitFrame.insetStage: 12,
    KitFrame.stageFrame: 19,
    KitFrame.pageSealed: 15,
    KitFrame.slipPinned: 10,
    KitFrame.ribbonLabel: 6,
    KitFrame.tabPlate: 6,
    KitFrame.peekPlate: 16,
    KitFrame.labelPlate: 4,
    KitFrame.labelPlateSelected: 4,
    KitFrame.navWell: 4,
    KitFrame.navPlateActive: 8,
    KitFrame.btnPlateV2: 10,
  };

  /// The frame for [frame], or null while it is still painted.
  static PanelSkin? of(KitFrame frame) => authored[frame];

  /// How much [frame] insets its content — the authored figure once art
  /// exists, the declared one until then, and they are the same number.
  static double insetFor(KitFrame frame) =>
      authored[frame]?.inset ?? _declaredInset[frame] ?? 0;

  /// Where a row's asset will live, so the contract and the tree cannot drift.
  static String pathFor(KitFrame frame) => '$_dir/${frame.name}.png';
}

/// A strip repeated along one axis at integer scale, the last repeat clipped.
///
/// The class the model is actually good at, and the class [EdgeStrip] already
/// renders: material where a painted line was.
enum KitTile {
  /// Ruled lines, one per page material: the journal, the bench, the chart.
  ruleJournal,
  ruleBench,
  ruleChart,

  /// A pocket divider on the pack (Inventory).
  pocketRule,

  /// A torn page foot — sealed pages, slips.
  edgeTorn,

  /// The book's spine, down a page's left edge. **Vertical.**
  edgeSpine,

  /// The equipment case's strap.
  caseStrap,

  /// The station shelf (Craft) and the command rail's ground (Combat).
  railShelf,
  railStrap,

  /// The nav strap's stitch welt — and, at the same period and scale, the
  /// header shelf's. One chassis, one stitch (DIR-15 section 2).
  navWelt,

  /// The docked sheet's top edge (World).
  sheetEdge,
}

/// A longitudinal tile: its repeat period, its thickness, and which way it runs.
@immutable
final class KitStrip {
  const KitStrip({
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
    this.axis = Axis.horizontal,
  }) : assert(scale >= 1, 'integer scale only (L-18)'),
       assert(nativeWidth > 0 && nativeHeight > 0);

  final String assetPath;

  /// The tile's own width — its repeat period in source pixels when it runs
  /// horizontally.
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  /// Horizontal strips repeat left to right and are [thickness] tall; vertical
  /// strips repeat top to bottom and are [thickness] wide.
  final Axis axis;

  /// The strip's extent across its run, in logical pixels. **Reserve this
  /// unconditionally** — the same doctrine as `EdgeStrip.displayHeight`.
  double get thickness => axis == Axis.horizontal
      ? (nativeHeight * scale).toDouble()
      : (nativeWidth * scale).toDouble();
}

/// Tile to authored strip.
abstract final class KitTiles {
  const KitTiles._();

  static const String _kit = 'assets/ui/v1/kit';

  /// The registry.
  ///
  /// `navWelt` is the round's first landed row: a saddle stitch cut from a
  /// `pixen` leather master, ceiling-clamped, then reduced to its
  /// best-wrapping 8 x 6 window by the same deterministic search that produced
  /// the shipped `nav_welt`. Sidecar and recipe:
  /// `assets/ui/v1/nav/nav_welt_v2.json`.
  static const Map<KitTile, KitStrip> authored = <KitTile, KitStrip>{
    KitTile.navWelt: KitStrip(
      assetPath: 'assets/ui/v1/nav/nav_welt_v2.png',
      nativeWidth: 8,
      nativeHeight: 6,
    ),
    // The two rules ship on a **transparent** ground: the model cannot draw a
    // line on nothing, so it drew one on paper and the paper was keyed out
    // (`tools/rule-cut.js`). What tiles is the ink, over whatever page
    // material the screen already has.
    KitTile.ruleJournal: KitStrip(
      assetPath: '$_kit/rule_journal.png',
      nativeWidth: 8,
      nativeHeight: 6,
    ),
    KitTile.ruleChart: KitStrip(
      assetPath: '$_kit/rule_chart.png',
      nativeWidth: 8,
      nativeHeight: 4,
    ),
    // The book's spine, repeated DOWN the page's left edge. Period 7 is the
    // binding cords' own measured spacing, not a chosen number.
    KitTile.edgeSpine: KitStrip(
      assetPath: '$_kit/edge_spine.png',
      nativeWidth: 32,
      nativeHeight: 7,
      scale: 1,
      axis: Axis.vertical,
    ),
    // Picture class: 384 wide at ×1, drawn once and clipped, exactly like a
    // band. The stone wall the model drew above and below the plank is not the
    // shelf and was cropped off.
    KitTile.railShelf: KitStrip(
      assetPath: '$_kit/rail_shelf.png',
      nativeWidth: 384,
      nativeHeight: 32,
      scale: 1,
    ),
  };

  /// What each strip is **declared** to cost across its run, art or no art.
  static const Map<KitTile, double> _declaredThickness = <KitTile, double>{
    KitTile.ruleJournal: 12,
    KitTile.ruleBench: 8,
    KitTile.ruleChart: 8,
    KitTile.pocketRule: 12,
    KitTile.edgeTorn: 12,
    KitTile.edgeSpine: 32,
    KitTile.caseStrap: 32,
    KitTile.railShelf: 32,
    KitTile.railStrap: 40,
    KitTile.navWelt: 12,
    KitTile.sheetEdge: 12,
  };

  static KitStrip? of(KitTile tile) => authored[tile];

  /// The room [tile] takes across its run. Spend it whether or not the raster
  /// decodes, so a strip that fails to load changes the material and not the
  /// layout.
  static double thicknessFor(KitTile tile) =>
      authored[tile]?.thickness ?? _declaredThickness[tile] ?? 0;

  /// Which way [tile] runs — declared here so a caller can lay out against a
  /// row that has no art yet.
  static Axis axisFor(KitTile tile) => switch (tile) {
    KitTile.edgeSpine => Axis.vertical,
    _ => Axis.horizontal,
  };
}

/// A discrete ornament Flutter positions and draws once at integer scale.
enum KitMark {
  /// The ornate rule under a name — Character, an encounter species plate, a
  /// chapter opening.
  ruleOrnateA,
  ruleOrnateB,

  /// The two ends of a [KitTile] rule. **Authored, never mirrored**: a mirror
  /// flips the key light to the upper right.
  ruleCapLeft,
  ruleCapRight,

  /// Combat's gauge hangers, under the stage frame's lower band.
  gaugeBracketLeft,
  gaugeBracketRight,

  /// The leather tab and the grip on the World peek strip and its sheet.
  peekTab,
  sheetGrip,

  /// The ends of a quiet underlined action.
  btnQuietCapLeft,
  btnQuietCapRight,

  /// The plate behind a short label — a level, a rarity, a boss mark, a cost.
  ///
  /// **An ornament, not a frame.** A ribbon is a *three*-patch: two fixed
  /// swallowtail ends with a tiling middle. [PixelFrame] only draws
  /// nine-patches, and the ribbon's left and right "bands" measure 0 because
  /// the notches are transparent at mid-height, so it cannot carry one uniform
  /// inset. It ships at its authored 96 × 32 and holds a short label; anything
  /// wider needs a three-patch painter, which is a separate change.
  ribbonLabel,

  /// A folio's index tab.
  ///
  /// **An ornament, not a frame**, and the measurement is why: the authored
  /// tab's rim is 19/1/28/1 — wildly asymmetric — so it cannot carry one inset
  /// and cannot be a nine-patch. FMPO02 rejected `banked_cartouche` for the
  /// same shape. A tab is a fixed object anyway, so nothing is lost.
  tabPlate,
}

/// A discrete ornament: drawn once, never tiled, never stretched.
@immutable
final class KitOrnamentArt {
  const KitOrnamentArt({
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
  }) : assert(scale >= 1, 'integer scale only (L-18)');

  final String assetPath;
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  Size get size =>
      Size((nativeWidth * scale).toDouble(), (nativeHeight * scale).toDouble());
}

/// Mark to authored ornament.
///
/// Empty for the same measured reason as [KitFrames]; every consumer reserves
/// [KitMarks.sizeFor] and draws its own fallback until a row lands.
abstract final class KitMarks {
  const KitMarks._();

  static const String _dir = 'assets/ui/v1/kit';

  static const Map<KitMark, KitOrnamentArt> authored =
      <KitMark, KitOrnamentArt>{
        KitMark.ruleOrnateA: KitOrnamentArt(
          assetPath: '$_dir/rule_ornate_a.png',
          nativeWidth: 192,
          nativeHeight: 16,
          scale: 1,
        ),
        KitMark.ribbonLabel: KitOrnamentArt(
          assetPath: '$_dir/ribbon_label.png',
          nativeWidth: 89,
          nativeHeight: 22,
          scale: 1,
        ),
        KitMark.tabPlate: KitOrnamentArt(
          assetPath: '$_dir/tab_plate.png',
          nativeWidth: 48,
          nativeHeight: 32,
          scale: 1,
        ),
      };

  static const Map<KitMark, Size> _declaredSize = <KitMark, Size>{
    KitMark.ruleOrnateA: Size(192, 16),
    KitMark.ruleOrnateB: Size(192, 16),
    KitMark.ruleCapLeft: Size(24, 8),
    KitMark.ruleCapRight: Size(24, 8),
    KitMark.gaugeBracketLeft: Size(96, 32),
    KitMark.gaugeBracketRight: Size(96, 32),
    KitMark.peekTab: Size(96, 24),
    KitMark.sheetGrip: Size(48, 12),
    KitMark.btnQuietCapLeft: Size(32, 48),
    KitMark.btnQuietCapRight: Size(32, 48),
    KitMark.ribbonLabel: Size(89, 22),
    KitMark.tabPlate: Size(48, 32),
  };

  static KitOrnamentArt? of(KitMark mark) => authored[mark];

  static Size sizeFor(KitMark mark) =>
      authored[mark]?.size ?? _declaredSize[mark] ?? Size.zero;

  static String pathFor(KitMark mark) => '$_dir/${mark.name}.png';
}
