/// Everything the inspector says about a place, in the words it says it in.
///
/// ## Why this file exists at all
///
/// The inspector's job is to expose **real** systems: the gathering nodes that
/// actually stand at a place and the encounters that actually wait there. Those
/// come from `StrideSession.placeDetailsFor` and `RegionPlace.kind`
/// (`DECISIONS/0021` §5). Rather than invent a second derivation of them in a
/// widget (`RULES.md` E-2), every widget in `world/` renders from
/// [AtlasPlaceInfo], and [AtlasPlaceInfo.from] is the only place that touches
/// the session for place detail.
///
/// ## What this is not
///
/// It is not a cache, not durable state, and not a rule. It is built fresh in
/// `build` from projections the engine re-checks, and it computes nothing the
/// engine does not also compute: the kind word, the terrain word and the
/// behaviour word are translations, and the lists are copies.
library;

import 'package:stride_core/stride_core.dart'
    show EnemyBehavior, LocationKind, Terrain;

import '../../../../runtime/stride_session.dart';

/// What kind of place this is, as the atlas draws and names it.
///
/// Mirrors `LocationKind` in `stride_core` — the four kinds a place can be —
/// and adds [landmark], which is not a place at all but is drawn from the same
/// glyph table. Kept local so the *word* a player reads is decided here, in the
/// UI, rather than in the domain.
enum AtlasPlaceKind {
  /// Somewhere with people in it. Safe.
  haven('Settlement', 'haven'),

  /// Open country. Things live there.
  wilds('Wilds', 'wilds'),

  /// Somewhere worked — a mine, a quarry, a forge camp.
  worksite('Worksite', 'worksite'),

  /// Somewhere that will fight back.
  perilous('Perilous', 'perilous'),

  /// **Not a place.** Named geography — a ruin, a ferry, a far town. It is in
  /// this enum because it is in the same glyph table (`world/marker_landmark`)
  /// and the vocabulary is worth having in one list; no [AtlasPlaceInfo] is
  /// ever built with it, because a landmark has no panel to build one for.
  landmark('Landmark', 'landmark');

  const AtlasPlaceKind(this.word, this.markerKind);

  /// The word the inspector prints. A player's word, not an enum name.
  final String word;

  /// The `kindMarkers` key in `atlas_layout.json`, which is also the tail of
  /// the art key `world/marker_<kind>`.
  final String markerKind;
}

/// One gatherable node standing at a place.
///
/// [eligible] and [gap] are the same `GatherEligibility` verdict the
/// Adventure card disables its button with, asked here so a 2,400-step
/// journey is never planned toward a node the player cannot work (Fable V2,
/// `DECISIONS/0027`). [gap] is the one short reason — the level, the tool
/// tier, or the project — in the engine's own refusal order.
typedef AtlasGatherLine = ({
  String name,
  String skill,
  int level,
  String? tool,
  bool eligible,
  String? gap,
});

/// One location's board, at a glance — the World inspector's restatement of
/// `BoardSummaryView` (Fable V2, `DECISIONS/0027`).
typedef AtlasBoardLine = ({
  String boardName,
  int openContracts,
  int readyToComplete,
  String? projectName,
  bool projectHasSomethingToGive,
  bool carryingSomethingWanted,
});

/// One encounter waiting at a place.
///
/// [remaining] and [isCurrentLocation] are what let the inspector say *2 of 2
/// this visit* where the player is standing and *2 per visit* where they are
/// not — the same distinction `DECISIONS/0021` draws.
typedef AtlasEncounterLine = ({
  String name,
  bool isBoss,
  String behaviorWord,
  int perVisit,
  int remaining,
  bool isCurrentLocation,
});

/// The inspector's whole view of one place.
final class AtlasPlaceInfo {
  const AtlasPlaceInfo({
    required this.kind,
    required this.terrainWord,
    required this.isSafe,
    required this.isCurrent,
    required this.isUnlocked,
    required this.gatherSites,
    required this.encounters,
    this.developmentWord,
    this.board,
  });

  final AtlasPlaceKind kind;

  /// `Grassland`, `Forest`, `Foothills`, `Alpine`.
  final String terrainWord;

  final bool isSafe;
  final bool isCurrent;
  final bool isUnlocked;

  final List<AtlasGatherLine> gatherSites;
  final List<AtlasEncounterLine> encounters;

  /// The settlement's named development state — `Struggling`, `Watched` —
  /// or null where none is authored. The word community projects change.
  final String? developmentWord;

  /// The place's board at a glance, or null where it keeps none.
  final AtlasBoardLine? board;

  /// The word for [kind] — `Settlement`, `Wilds`, `Worksite`, `Perilous`.
  String get kindWord => kind.word;

  /// Reads the session for [place].
  ///
  /// Wired to `StrideSession.placeDetailsFor` and `RegionPlace.kind`
  /// (`DECISIONS/0021` §5): the lists are copies of what the engine projects,
  /// the words are translations. A location the session does not know (null
  /// details) yields the narrower truth — kind and terrain, no sections —
  /// rather than an invented row.
  static AtlasPlaceInfo from(StrideSession session, RegionPlace place) {
    final PlaceDetails? d = session.placeDetailsFor(place.id);
    final BoardSummaryView? board = session.boardSummaryFor(place.id);
    return AtlasPlaceInfo(
      kind: kindOf(session, place),
      terrainWord: terrainWordFor(place.terrain),
      isSafe: place.isSafe,
      isCurrent: place.isCurrent,
      isUnlocked: place.isUnlocked,
      developmentWord: session.developmentStateOf(place.id),
      board: board == null
          ? null
          : (
              boardName: board.boardName,
              openContracts: board.openContracts,
              readyToComplete: board.readyToComplete,
              projectName: board.projectName,
              projectHasSomethingToGive: board.projectHasSomethingToGive,
              carryingSomethingWanted: board.carryingSomethingWanted,
            ),
      gatherSites: <AtlasGatherLine>[
        if (d != null)
          for (final GatherSiteLine g in d.gatherSites)
            () {
              final GatherEligibility e = session.gatherEligibilityOf(g.id);
              return (
                name: g.name,
                skill: g.skillName,
                level: g.requiredLevel,
                tool: g.toolWord,
                eligible: e.eligible,
                gap: gapWordFor(e),
              );
            }(),
      ],
      encounters: <AtlasEncounterLine>[
        if (d != null)
          for (final PlaceEncounterLine e in d.encounters)
            (
              name: e.name,
              isBoss: e.isBoss,
              behaviorWord: behaviorWordFor(e.behavior),
              perVisit: e.encountersPerVisit,
              remaining: e.remainingThisVisit,
              isCurrentLocation: place.isCurrent,
            ),
      ],
    );
  }

  /// Which glyph a place's marker is drawn from — `RegionPlace.kind` mapped
  /// across. Separate from [from] because the marker layer needs the kind of
  /// *every* place on every build while the inspector needs the details of one.
  static AtlasPlaceKind kindOf(StrideSession session, RegionPlace place) =>
      switch (place.kind) {
        LocationKind.haven => AtlasPlaceKind.haven,
        LocationKind.wilds => AtlasPlaceKind.wilds,
        LocationKind.worksite => AtlasPlaceKind.worksite,
        LocationKind.perilous => AtlasPlaceKind.perilous,
      };

  /// An enemy's behaviour as a player's word. Presentation only; the figures
  /// stay on the encounter card.
  static String behaviorWordFor(EnemyBehavior behavior) => switch (behavior) {
    EnemyBehavior.steady => 'Steady',
    EnemyBehavior.flurry => 'Quick',
    EnemyBehavior.guarded => 'Guarded',
  };

  /// The one short reason a gather line is out of reach, in the engine's
  /// own refusal order — level first, then tool, then the project gate —
  /// or null when every static prerequisite is met.
  static String? gapWordFor(GatherEligibility e) {
    if (!e.skillMet) return 'you are Lv ${e.currentLevel}';
    if (!e.toolMet) {
      final int? held = e.equippedToolTier;
      return held == null
          ? 'no tool equipped'
          : 'needs tier ${e.requiredToolTier} — yours is tier $held';
    }
    if (e.lockedByProjectName case final String project) {
      return 'opens with $project';
    }
    return null;
  }

  /// The terrain, as a word a player would use rather than an enum name.
  static String terrainWordFor(Terrain terrain) => switch (terrain) {
    Terrain.grassland => 'Grassland',
    Terrain.forest => 'Forest',
    Terrain.foothills => 'Foothills',
    Terrain.alpine => 'Alpine',
  };
}
