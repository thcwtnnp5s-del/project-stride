/// The **band**: the third identity axis `DECISIONS/0029` named, and the one
/// FMPO02 wave 2 actually authored.
///
/// > A panel may differ from its neighbour by **band, surface, picture** — and
/// > never by a second border.
///
/// `panel_skin.dart` owns the other two. A [PanelSurface] says what a panel is
/// *made of*; a [PanelSkin] says what its edge is. A band says what the section
/// is *about*: a strip of the trade's own place, drawn once under the heading —
/// the forge's coals under `Forge`, the trail under `Expedition kit`.
///
/// ## Picture class, so ×1 and clipped
///
/// A band is not a tile and not a nine-patch. It is a **picture**, and it
/// belongs to the same class as the region map and the location vignette
/// (`PixelScene`): drawn once at ×1, clipped to whatever width its container
/// has, never tiled and never stretched.
///
/// The arithmetic is the reason. Every band is authored 384 × 48, and the four
/// supported phone widths are 320, 360, 393 and 430 dp. There is no integer
/// scale at which 384 fits 320, and the three ways out of that are not equal —
/// downscaling drops whole columns out of a picture of an anvil, authoring per
/// width means authoring five times, and clipping costs only the outermost
/// pixels of a picture framed with nothing load-bearing at its edges. So at 393
/// dp the 384 band is centred and the 9 dp remainder shows the panel's own
/// fill; at 320 dp the band clips 32 px, 16 a side. That is the design, not a
/// concession to it.
///
/// ## Type sits on it, which is why the exposure was lowered
///
/// Every other piece of authored chrome sits *beside* the words, and
/// `ART_DIRECTION.md`'s `#7C7263` ceiling is what keeps it there. A band sits
/// **under** them, and PROD-UI measured the brightest legal chrome ink at
/// 4.26:1 against `textPrimary` — under the 4.5:1 floor every readable surface
/// is held to. Each band therefore carries one linear-light gain (×0.87–×0.93)
/// applied at packaging time, so its brightest pixel clears 4.5:1 and a title
/// may legally be drawn over it
/// (`MILESTONES/evidence/FMPO02/wave2/UI_report.md` §3.3).
///
/// `test/band_plate_test.dart` measures that claim against the shipped PNG
/// rather than trusting the report, because a re-roll that skipped `--textsafe`
/// would put body type on a 4.2:1 ground and nothing else in the build would
/// notice.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show LocationKind, Terrain;

import '../../runtime/stride_session.dart' show PlaceIdentity;
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'pixel_asset.dart';

/// Which place a band shows. A small closed set, one per section that has a
/// place — not one per screen.
enum StrideBand {
  /// The smithy's coals. Craft's forge station, and Smithing.
  forge,

  /// The cooking fire. Craft's cookfire station, and Cooking.
  cookfire,

  /// The woodworking bench. Craft's bench station, and Woodcutting.
  bench,

  /// Hedgerow and herb. Foraging.
  foraging,

  /// The cut face. Mining.
  mining,

  /// The navigator's chart table. The atlas inspector.
  worldChart,

  /// Trodden ground. The encounter list.
  encounterGround,

  /// The road out. Adventure's expedition kit.
  adventureTrail,

  /// The notice board's battens. The goal board.
  boardsBatten,

  /// The field kit.
  ///
  /// **Authored, packaged, and deliberately not drawn.** Combat's screen
  /// already has a picture — the stage the fight happens on — and PROD-UI's
  /// integration note is that a band above it would be a second picture
  /// competing with the first. Kept because the asset exists and the round
  /// that authored it should not have to be repeated to use it; unwired until
  /// a combat pass asks for it.
  combatKit,
}

/// Band → authored strip.
abstract final class StrideBands {
  const StrideBands._();

  static const String _dir = 'assets/ui/v1/band';

  /// The registry. Every band is 384 × 48, drawn ×1.
  static const Map<StrideBand, String> authored = <StrideBand, String>{
    StrideBand.forge: '$_dir/band_forge.png',
    StrideBand.cookfire: '$_dir/band_cookfire.png',
    StrideBand.bench: '$_dir/band_bench.png',
    StrideBand.foraging: '$_dir/band_foraging.png',
    StrideBand.mining: '$_dir/band_mining.png',
    StrideBand.worldChart: '$_dir/band_world_chart.png',
    StrideBand.encounterGround: '$_dir/band_encounter_ground.png',
    StrideBand.adventureTrail: '$_dir/band_adventure_trail.png',
    StrideBand.boardsBatten: '$_dir/band_boards_batten.png',
    StrideBand.combatKit: '$_dir/band_combat_kit.png',
  };

  static String pathOf(StrideBand band) => authored[band]!;

  /// The band for a craft station kind — `AmbientAssets`' own vocabulary, so
  /// the station strip's art table and this one cannot drift.
  static StrideBand? forStation(String kind) => switch (kind) {
    'forge' => StrideBand.forge,
    'woodbench' => StrideBand.bench,
    'cookfire' => StrideBand.cookfire,
    _ => null,
  };

  /// The band for a trade.
  ///
  /// Smithing and Woodcutting share their bands with the Craft stations they
  /// work at, which is the point: a player who learns the forge on the Craft
  /// screen meets the same forge at the head of the Smithing roadmap. A trade
  /// with no place yet gets no band rather than a borrowed one.
  static StrideBand? forSkill(String skill) => switch (skill) {
    'mining' => StrideBand.mining,
    'foraging' => StrideBand.foraging,
    'woodcutting' => StrideBand.bench,
    'smithing' => StrideBand.forge,
    'cooking' => StrideBand.cookfire,
    _ => null,
  };

  /// The band for the **place the player is standing in** — Adventure's
  /// expedition kit (FMPO02 wave 3, FINAL-10 #2).
  ///
  /// The kit shipped with `adventureTrail` nailed above it everywhere, and the
  /// review's diff found the strip **100.0 % pixel-identical** between a
  /// grassland settlement, a deep forest and the inside of a mine: a
  /// green-grass-and-split-rail shelf above the ore seams. One band above
  /// every location is the clearest single proof a chassis was applied rather
  /// than designed, so the location now owns its own.
  ///
  /// Read from [PlaceIdentity] — the same pair the header's breadcrumb prints
  /// (`AtlasPlaceInfo.descriptorFor`) — so the band cannot disagree with the
  /// two words directly above it. Kind is asked first because it is the
  /// stronger fact: a worksite is a cut face whatever ground it sits on, and a
  /// **perilous** place gets no band at all. The Hollow is a threshold, and a
  /// cheerful strip of trail over the one location with a boss in it would be
  /// the same mistake at a different address.
  ///
  /// No new art: the five outcomes are bands the round already authored.
  static StrideBand? forPlace(PlaceIdentity identity) => switch (identity) {
    // The boss's ground. Nothing.
    (kind: LocationKind.perilous, terrain: _) => null,
    // A cutting is a cutting: Stonefall reads as the mine it is, and so would
    // a quarry laid on grass.
    (kind: LocationKind.worksite, terrain: _) => StrideBand.mining,
    (kind: _, terrain: Terrain.grassland) => StrideBand.adventureTrail,
    (kind: _, terrain: Terrain.forest) => StrideBand.foraging,
    (kind: _, terrain: Terrain.foothills) => StrideBand.mining,
    // Frostmere: hedgerow and herb is the closest authored ground to a place
    // whose work is gathering under snow. The alpine strip is `§6` art debt,
    // not a plate this round may invent.
    (kind: _, terrain: Terrain.alpine) => StrideBand.foraging,
  };
}

/// A band, full-bleed across its container, with an optional title over it.
class BandPlate extends StatelessWidget {
  const BandPlate({super.key, required this.band, this.title});

  final StrideBand band;

  /// Drawn over the band in the display face. Null draws the picture alone,
  /// which is what a section whose heading is already above it wants.
  final String? title;

  /// Every band's authored canvas.
  static const int nativeWidth = 384;
  static const int nativeHeight = 48;

  @override
  Widget build(BuildContext context) {
    final Widget picture = PixelScene(
      assetPath: StrideBands.pathOf(band),
      nativeWidth: nativeWidth,
      nativeHeight: nativeHeight,
      // ×1. See the library doc: a band is a picture, and 384 has no integer
      // scale that fits a 320 dp phone.
      scale: 1,
    );

    if (title == null) return picture;

    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        picture,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s12),
          child: AdaptiveText(
            title!,
            // Cinzel, the display face — the same register every other section
            // heading speaks in. The band changes what the heading sits on,
            // never what it is.
            style: StrideType.sectionHeading,
          ),
        ),
      ],
    );
  }
}
