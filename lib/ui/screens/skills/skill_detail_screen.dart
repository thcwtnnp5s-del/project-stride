/// The Skill Detail screen — one profession's whole plannable future, as a
/// road rather than a list (EPO03, `DIR-07`).
///
/// ## What the owner's device read said
///
/// "The Skills detail screen still stacks rounded rectangles." It was
/// literally true: two `SectionCard`s on a flat fill, a third rounded box per
/// unlock, a level chip, an 8 dp bar — a settings list wearing a fantasy
/// palette. Nothing on it said *passed / here / next / far*, which is the one
/// question a roadmap exists to answer, and nothing on it was illustrated.
///
/// ## What it is now
///
/// The overview's own buckram, full bleed, with **no card on it at all**. The
/// trade's band, then the gauge — a hero emblem in a well beside a framed
/// gauge the existing `ProgressRule` fills — and then a **road**: an inked
/// track down the left gutter with a joint at every level the walker can
/// stand on. Four joints, told apart by shape: a driven waystone behind them,
/// a lit lantern cairn where they are (the one node with a backplate), a
/// bronze-rimmed stone next with its true XP distance, a faded stake far off.
/// Unlocks hang off the road on spurs — a 48 dp well, a name, one line of
/// effect, a seal where something else still gates it. Empty runs and the
/// road already walked sink into folds. An end cap closes it at the content
/// horizon.
///
/// No padlock, no coin, no timer, no teal, nothing that counts up
/// (`L-15/16/17/19`). Nothing is illustrated with a number baked into it: a
/// level badge is a blank stone and `LV n` is set in type over it (`L-18`), so
/// the frame-removal test passes and the four states survive greyscale.
///
/// ## Every fact is still the projection's
///
/// `SkillRoadmap` comes from `StrideSession.skillRoadmapFor` — the same
/// `unlocksFor` ordering the spine reads, the same `SkillDefinition` curve the
/// engine gates with, detail lines pre-capped in the projection (`RULES.md`
/// E-2, F-07). The only thing this route decides is what is folded away, and
/// that decision is a pure function in `journey_model.dart`, tested on its
/// own. **No new data, no new content.**
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, SkillStanding;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/band_plate.dart';
import '../../components/data_display.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rules.dart';
import '../../components/screen_header.dart';
import '../../components/stride_scaffold.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/reward_art.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'journey_model.dart';
import 'skills_screen.dart' show SkillProgressBar, SkillProgressCaption;
import 'track_art.dart';

class SkillDetailScreen extends StatefulWidget {
  const SkillDetailScreen({super.key, required this.skill});

  final ContentId skill;

  /// Pushes the roadmap, re-wrapped in the pushing context's controller —
  /// the `StepTrackerScreen.open` pattern, so the route reads the same
  /// session the spine did.
  static Future<void> open(BuildContext context, ContentId skill) {
    final SessionController session = SessionScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScope(
          controller: session,
          child: SkillDetailScreen(skill: skill),
        ),
      ),
    );
  }

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  /// Whether the road already walked is unfolded — ephemeral presentation.
  bool _passedOpen = false;

  /// The one expanded unlock, by (level, name) — one open at a time, the
  /// Craft-row selection grammar.
  (int, String)? _expanded;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final SkillRoadmap? roadmap = controller.session.skillRoadmapFor(
      widget.skill,
    );

    return StrideScaffold(
      header: ScreenHeader(
        eyebrow: 'SKILLS',
        title: roadmap?.standing.displayName ?? 'Skill',
        trailing: Semantics(
          button: true,
          label: 'Close',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(StrideSpace.s8),
              child: Text(
                'CLOSE',
                style: StrideType.microLabel.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
      // The handbook's own material, full bleed — the push reads as turning
      // the page rather than as opening a dialog over it. `buckram` is the
      // overview's grain; a route on the same material as the list it came
      // from is the same book.
      body: roadmap == null
          ? const SizedBox.shrink()
          : PageGround(
              surface: PanelSurface.buckram,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  StrideSpace.screenGutter,
                  StrideSpace.s12,
                  StrideSpace.screenGutter,
                  StrideSpace.rhythmHero,
                ),
                children: <Widget>[
                  // The trade's own place, at the head of its road (FMPO02).
                  // Untitled: the header two lines above already names the
                  // skill, and a band under a heading it repeats is the same
                  // word twice.
                  if (StrideBands.forSkill(widget.skill.value)
                      case final StrideBand b) ...<Widget>[
                    BandPlate(band: b),
                    const SizedBox(height: StrideSpace.rhythmGroup),
                  ],
                  TradeGauge(roadmap: roadmap, skill: widget.skill),
                  const SizedBox(height: StrideSpace.rhythmHero),
                  JourneyTrack(
                    stops: JourneyModel.from(roadmap, passedOpen: _passedOpen),
                    skill: widget.skill,
                    passedOpen: _passedOpen,
                    onTogglePassed: () =>
                        setState(() => _passedOpen = !_passedOpen),
                    expanded: _expanded,
                    onToggleRow: ((int, String) key) => setState(
                      () => _expanded = _expanded == key ? null : key,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// The gauge
// =============================================================================

/// The trade at the head of its own road: the hero emblem, the name in the
/// trade's ink, the level, the gauge, and the two figures under it.
///
/// This is what the two `SectionCard`s said, said once and on the ground. The
/// old `_NextBlock` is gone with them: the overview's spine already carries
/// the next three lines, and on this route the *next joint* answers "what
/// next" in its own place on the road, which is where the question belongs.
class TradeGauge extends StatelessWidget {
  const TradeGauge({super.key, required this.roadmap, required this.skill});

  final SkillRoadmap roadmap;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final SkillStanding standing = roadmap.standing;
    final Color accent = StrideColors.forSkill(skill);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _EmblemWell(skill: skill),
        const SizedBox(width: StrideSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: AdaptiveText(
                      standing.displayName,
                      style: StrideType.cardTitle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: StrideSpace.s8),
                  AdaptiveText(
                    standing.isMaxLevel ? 'MAX' : 'LV ${standing.level}',
                    style: StrideType.numericValue,
                  ),
                ],
              ),
              const SizedBox(height: StrideSpace.s8),
              _Gauge(standing: standing, ink: accent),
              const SizedBox(height: StrideSpace.s8),
              SkillProgressCaption(standing: standing),
              const SizedBox(height: StrideSpace.s4),
              Text(
                roadmap.totalCount == 0
                    ? 'Nothing in this content pack uses it yet.'
                    : '${roadmap.openCount} of ${roadmap.totalCount} '
                          'unlocks open',
                style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The trade's hero emblem in a well — its 64² mark when one lands, and its
/// existing 24² spine icon centred in the same well until then. The well is
/// the same size either way.
class _EmblemWell extends StatelessWidget {
  const _EmblemWell({required this.skill});

  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final TrackMark? hero = TrackArt.emblemFor(skill);
    final String? icon = PixelIcons.skillFor(skill);
    return InsetWell.square(
      contentSize: TrackArt.emblem,
      child: ExcludeSemantics(
        child: hero != null
            ? PixelAsset(
                assetPath: hero.assetPath,
                nativeWidth: hero.nativeWidth,
                nativeHeight: hero.nativeHeight,
                scale: hero.scale,
              )
            : icon == null
            ? const SizedBox.shrink()
            : PixelAsset.skill(icon, scale: 2),
      ),
    );
  }
}

/// The gauge: an authored frame whose window the existing [ProgressRule]
/// fills.
///
/// The frame's band is spent whether or not the raster is there — the painted
/// fallback is a one-weight recess of exactly the same thickness — so the
/// gauge does not move when the art lands.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.standing, required this.ink});

  final SkillStanding standing;
  final Color ink;

  /// The frame material's thickness, and the window inside it.
  static const double band = 3;
  static const double window = 12;

  @override
  Widget build(BuildContext context) {
    // Keyed by level so a level-up snaps to the new ladder rather than
    // rewinding through it (the `SkillProgressBar` finding).
    final Widget fill = ProgressRule(
      key: ValueKey<int>(standing.level),
      fraction: standing.isMaxLevel ? 1 : standing.progress,
      ink: ink,
      height: window,
    );

    final Widget framed = TrackArt.gaugeFrame == null
        ? Container(
            padding: const EdgeInsets.all(band),
            decoration: const BoxDecoration(
              color: StrideColors.surfaceGround,
              border: Border.fromBorderSide(
                BorderSide(color: StrideColors.borderDefault),
              ),
            ),
            child: fill,
          )
        : PixelFrame(
            skin: TrackArt.gaugeFrame!,
            child: Padding(
              padding: const EdgeInsets.all(band),
              child: fill,
            ),
          );

    return Semantics(
      label: SkillProgressBar.semanticsLabelFor(standing),
      child: ExcludeSemantics(child: framed),
    );
  }
}

// =============================================================================
// The road
// =============================================================================

/// The journey line: an inked road down the gutter with a joint at every stop.
///
/// The road is painted **behind** the column of stops rather than assembled
/// out of one segment per row, which is what makes it continuous: a track
/// built out of per-row pieces gains a seam at every row boundary and drifts
/// the moment one row grows under Dynamic Type. The joints are Flutter-placed
/// in a reserved [TrackArt.rail] gutter, so each one is centred on the road
/// whatever the row beside it does.
class JourneyTrack extends StatelessWidget {
  const JourneyTrack({
    super.key,
    required this.stops,
    required this.skill,
    required this.passedOpen,
    required this.onTogglePassed,
    required this.expanded,
    required this.onToggleRow,
  });

  final List<JourneyStop> stops;
  final ContentId skill;
  final bool passedOpen;
  final VoidCallback onTogglePassed;
  final (int, String)? expanded;
  final ValueChanged<(int, String)> onToggleRow;

  @override
  Widget build(BuildContext context) {
    final List<Widget> along = <Widget>[];
    EndStop? end;

    for (final JourneyStop stop in stops) {
      switch (stop) {
        case MilestoneStop():
          along.add(
            _Milestone(
              stop: stop,
              skill: skill,
              expanded: expanded,
              onToggleRow: onToggleRow,
            ),
          );
        case FoldStop():
          along.add(
            _Fold(
              stop: stop,
              open: passedOpen,
              onTap: stop.kind == FoldKind.passed ? onTogglePassed : null,
            ),
          );
        case EndStop():
          end = stop;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Stack(
          children: <Widget>[
            // The road runs the whole height of the stops it serves and stops
            // where they stop — the end cap below is the road's own end.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: TrackArt.rail,
              child: const _Road(),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: along,
            ),
          ],
        ),
        if (end case final EndStop e) _EndCap(stop: e),
      ],
    );
  }
}

/// The road's own material: the tiled strip when it lands, and a painted
/// inked track — two edges and a broken centre line — until it does.
class _Road extends StatelessWidget {
  const _Road();

  @override
  Widget build(BuildContext context) {
    final TrackStrip? strip = TrackArt.road;
    final Widget surface = strip == null
        ? const CustomPaint(painter: _RoadPainter())
        : DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                // `scale` is how many source pixels go to one logical pixel:
                // 0.5 is the ×2 UI grid, and the repeat tiles at that size, so
                // the strip is never stretched and the last tile is clipped.
                image: ExactAssetImage(
                  strip.assetPath,
                  scale: 1 / strip.scale,
                ),
                repeat: ImageRepeat.repeatY,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
              ),
            ),
          );
    // `Center` would loosen the constraints and a `CustomPaint` with no child
    // takes the smallest size it is offered — which is how the road painted
    // nothing at all in its first render. Padding keeps the run tight to the
    // rail's full height and inset to the road's own width.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: (TrackArt.rail - TrackArt.roadWidth) / 2,
      ),
      child: SizedBox.expand(child: surface),
    );
  }
}

/// The painted road: a sunk track between two edges, with a broken centre
/// line down it. One weight, three tokens, no gradient.
class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bed = Paint()..color = StrideColors.surfaceCard;
    canvas.drawRect(Offset.zero & size, bed);

    final Paint edge = Paint()..color = StrideColors.borderDefault;
    canvas.drawRect(Rect.fromLTWH(0, 0, 1, size.height), edge);
    canvas.drawRect(Rect.fromLTWH(size.width - 1, 0, 1, size.height), edge);

    // The centre line, broken — a track that is walked, not a pipe.
    final Paint dash = Paint()..color = StrideColors.separator;
    const double period = 16;
    const double mark = 8;
    final double x = (size.width / 2).floorToDouble() - 1;
    for (double y = 0; y < size.height; y += period) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, 2, mark.clamp(0, size.height - y)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => false;
}

/// One level the road stops at: its joint, its badge, and everything the
/// level opens hanging off the road on spurs.
class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.stop,
    required this.skill,
    required this.expanded,
    required this.onToggleRow,
  });

  final MilestoneStop stop;
  final ContentId skill;
  final (int, String)? expanded;
  final ValueChanged<(int, String)> onToggleRow;

  @override
  Widget build(BuildContext context) {
    final bool here = stop.join == JoinState.current;

    final Widget badge = _LevelBadge(
      level: stop.level,
      join: stop.join,
      skill: skill,
    );

    final Widget head = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // The one node with a backplate — and it is a **backplate**, cut to
        // the badge and the words on it. Run full width it would be another
        // rounded rectangle, which is the thing this screen was named for.
        if (!here)
          badge
        else
          Container(
            padding: const EdgeInsets.fromLTRB(
              StrideSpace.s6,
              StrideSpace.s6,
              StrideSpace.s10,
              StrideSpace.s6,
            ),
            decoration: const BoxDecoration(
              color: StrideColors.surfaceCard,
              border: Border.fromBorderSide(
                BorderSide(color: StrideColors.actionEdge),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                badge,
                const SizedBox(width: StrideSpace.s8),
                Text(
                  'YOU ARE HERE',
                  style: StrideType.microLabel.copyWith(
                    color: StrideColors.forSkill(skill),
                  ),
                ),
              ],
            ),
          ),
        if (stop.xpAway case final int away) ...<Widget>[
          const Spacer(),
          Text(
            '$away XP away',
            style: StrideType.micro.copyWith(
              color: StrideColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        head,
        if (stop.entries.isEmpty && here)
          Padding(
            padding: const EdgeInsets.only(top: StrideSpace.s4),
            child: Text(
              'Nothing new at this level.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ),
      ],
    );

    return Semantics(
      container: true,
      label: switch (stop.join) {
        JoinState.reached => 'Level ${stop.level}, reached',
        JoinState.current => 'Level ${stop.level}, you are here',
        JoinState.next =>
          'Level ${stop.level}, next'
              '${stop.xpAway == null ? '' : ', ${stop.xpAway} experience away'}',
        JoinState.far => 'Level ${stop.level}, further along the road',
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: TrackArt.rail,
                child: _Joint(join: stop.join, skill: skill),
              ),
              const SizedBox(width: StrideSpace.s10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: StrideSpace.s6,
                  ),
                  child: body,
                ),
              ),
            ],
          ),
          for (final SkillUnlock u in stop.entries)
            _Entry(
              unlock: u,
              join: stop.join,
              expanded: expanded == (stop.level, u.displayName),
              onTap: () => onToggleRow((stop.level, u.displayName)),
            ),
          const SizedBox(height: StrideSpace.rhythmGroup),
        ],
      ),
    );
  }
}

/// A joint on the road: the shape that says where this level stands relative
/// to the walker.
///
/// Four shapes, drawn in one weight until the marks land: a driven waystone
/// (a squat block with a tick cut in it), a lit cairn (a stack with a light
/// on it), a bronze-rimmed stone, and a thin faded stake. **State is in the
/// shape**, so the four survive greyscale and the raster carries no word.
class _Joint extends StatelessWidget {
  const _Joint({required this.join, required this.skill});

  final JoinState join;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final TrackMark? mark = TrackArt.jointFor(join);
    return SizedBox(
      height: TrackArt.jointExtent,
      width: TrackArt.rail,
      child: Center(
        child: mark != null
            ? ExcludeSemantics(
                child: PixelAsset(
                  assetPath: mark.assetPath,
                  nativeWidth: mark.nativeWidth,
                  nativeHeight: mark.nativeHeight,
                  scale: mark.scale,
                ),
              )
            : CustomPaint(
                size: const Size(TrackArt.jointExtent, TrackArt.jointExtent),
                painter: _JointPainter(
                  join: join,
                  ink: StrideColors.forSkill(skill),
                ),
              ),
      ),
    );
  }
}

class _JointPainter extends CustomPainter {
  const _JointPainter({required this.join, required this.ink});

  final JoinState join;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = (size.width / 2).floorToDouble();
    final double cy = (size.height / 2).floorToDouble();
    void box(double w, double h, Color fill, {Color? rim, double dy = 0}) {
      final Rect r = Rect.fromLTWH(
        cx - w / 2,
        cy - h / 2 + dy,
        w,
        h,
      );
      canvas.drawRect(r, Paint()..color = fill);
      if (rim != null) {
        canvas.drawRect(
          r,
          Paint()
            ..color = rim
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    switch (join) {
      // Driven flush with the road, and ticked: a stone already passed.
      case JoinState.reached:
        box(22, 22, StrideColors.surfaceRaised, rim: StrideColors.borderDefault);
        canvas.drawRect(
          Rect.fromLTWH(cx - 6, cy - 1, 12, 2),
          Paint()..color = StrideColors.textMuted,
        );
      // A cairn with a lantern on it: the tallest, widest, brightest shape.
      case JoinState.current:
        box(28, 18, StrideColors.surfaceRaised, rim: ink, dy: 6);
        box(14, 14, StrideColors.rewardLightInk, dy: -10);
        canvas.drawRect(
          Rect.fromLTWH(cx - 3, cy - 12, 6, 6),
          Paint()..color = StrideColors.surfaceGround,
        );
      // Standing, unlit, bronze-rimmed: the next stone up the road.
      case JoinState.next:
        box(18, 26, StrideColors.surfaceBlock, rim: StrideColors.actionEdge);
      // A thin stake, faded: far enough off to be a mark and not a place.
      case JoinState.far:
        box(8, 24, StrideColors.surfaceRaised);
    }
  }

  @override
  bool shouldRepaint(_JointPainter old) =>
      old.join != join || old.ink != ink;
}

/// The level's badge: a blank stone plate with `LV n` set in type over it.
///
/// **L-18 in one widget.** The plate is worn or lit; the numeral is Flutter's,
/// in the trade's ink where the walker stands and in the ladder's ink
/// elsewhere. Remove the raster and the number, the state and the reading are
/// all still there.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.join,
    required this.skill,
  });

  final int level;
  final JoinState join;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final bool lit = join != JoinState.reached;
    final TrackMark? plate = TrackArt.badgePlate(lit: lit);
    final Color ink = switch (join) {
      JoinState.current => StrideColors.forSkill(skill),
      JoinState.next => StrideColors.textPrimary,
      JoinState.reached => StrideColors.textMuted,
      JoinState.far => StrideColors.textSecondary,
    };

    final Widget numeral = Text(
      'LV $level',
      style: StrideType.numericValue.copyWith(color: ink, fontSize: 15),
    );

    if (plate == null) {
      // The painted plate: a stone the numeral is stamped into, lit on its
      // top edge or worn flat. Same box as the raster's.
      return Container(
        constraints: BoxConstraints(minWidth: TrackArt.badge.width),
        padding: const EdgeInsets.symmetric(
          horizontal: StrideSpace.s8,
          vertical: StrideSpace.s4,
        ),
        decoration: BoxDecoration(
          color: lit ? StrideColors.surfaceBlock : StrideColors.surfaceCard,
          border: Border(
            top: BorderSide(
              color: lit
                  ? StrideColors.actionEdge
                  : StrideColors.borderDefault,
            ),
            left: const BorderSide(color: StrideColors.borderDefault),
            right: const BorderSide(color: StrideColors.borderDefault),
            bottom: const BorderSide(color: StrideColors.surfaceGround),
          ),
        ),
        child: Center(widthFactor: 1, child: numeral),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        ExcludeSemantics(
          child: PixelAsset(
            assetPath: plate.assetPath,
            nativeWidth: plate.nativeWidth,
            nativeHeight: plate.nativeHeight,
            scale: plate.scale,
          ),
        ),
        numeral,
      ],
    );
  }
}

/// One unlock, hung off the road on a spur: a well, a name, one line of
/// effect, and a seal when something beyond the level still gates it.
///
/// **Unboxed.** The row that used to be a bordered rectangle is now a picture
/// and two lines on the page; the only thing that changes when it is open is
/// that the rest of the projection's story appears under it.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.unlock,
    required this.join,
    required this.expanded,
    required this.onTap,
  });

  final SkillUnlock unlock;
  final JoinState join;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool far = join == JoinState.far;
    final Color ink = unlock.unlocked
        ? StrideColors.textSecondary
        : far
        ? StrideColors.textMuted
        : StrideColors.textPrimary;
    final bool expandable = unlock.detailLines.isNotEmpty;
    final List<String> rest = unlock.detailLines.length > 1
        ? unlock.detailLines.sublist(1)
        : const <String>[];

    return Semantics(
      button: expandable,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: expandable ? onTap : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The spur: 16 dp of track from the road to what hangs off it.
            SizedBox(
              width: TrackArt.rail,
              height: TrackArt.wellContent + StrideSpace.s8,
              child: CustomPaint(painter: const _SpurPainter()),
            ),
            const SizedBox(width: StrideSpace.s10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: StrideSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _EntryWell(unlock: unlock),
                        const SizedBox(width: StrideSpace.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AdaptiveText(
                                unlock.where == null
                                    ? unlock.displayName
                                    : '${unlock.displayName} at '
                                          '${unlock.where}',
                                style: StrideType.sub,
                                color: ink,
                              ),
                              if (unlock.detailLines.isNotEmpty)
                                Text(
                                  unlock.detailLines.first,
                                  style: StrideType.micro.copyWith(
                                    color: StrideColors.textSecondary,
                                  ),
                                ),
                              if (unlock.gate case final String gate)
                                _GateSeal(gate: gate),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (expanded) ...<Widget>[
                      const SizedBox(height: StrideSpace.s6),
                      for (final String line in rest)
                        Text(
                          line,
                          style: StrideType.micro.copyWith(
                            color: StrideColors.textSecondary,
                          ),
                        ),
                      if (unlock.trackableItem case final ContentId item)
                        Padding(
                          padding: const EdgeInsets.only(top: StrideSpace.s6),
                          child: StrideButton.secondary(
                            label: 'Track as Pursuit',
                            onPressed: () =>
                                SessionScope.read(context).trackGoalPursuit(item),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The spur that ties an entry to the road: a short run of track out of the
/// road's right edge, at the height of the well beside it.
class _SpurPainter extends CustomPainter {
  const _SpurPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double y = (TrackArt.wellContent / 2).floorToDouble();
    final double from = ((size.width - TrackArt.roadWidth) / 2).floorToDouble();
    canvas.drawRect(
      Rect.fromLTWH(from + TrackArt.roadWidth - 4, y - 1, 20, 2),
      Paint()..color = StrideColors.textMuted,
    );
  }

  @override
  bool shouldRepaint(_SpurPainter old) => false;
}

/// An unlock's 48 dp well: the item it yields or makes, or the milestone
/// cairn for the one kind of unlock that stands for the level itself.
class _EntryWell extends StatelessWidget {
  const _EntryWell({required this.unlock});

  final SkillUnlock unlock;

  @override
  Widget build(BuildContext context) {
    final Widget art = switch (unlock.kind) {
      SkillUnlockKind.milestone => const PixelAsset(
        assetPath: RewardArt.badgeMilestone,
        nativeWidth: 48,
        nativeHeight: 48,
        scale: 1,
      ),
      SkillUnlockKind.site || SkillUnlockKind.recipe =>
        unlock.trackableItem == null
            ? const SizedBox.shrink()
            : PixelAsset.item(PixelIcons.itemFor(unlock.trackableItem!)),
    };
    return InsetWell.square(
      contentSize: TrackArt.wellContent,
      child: ExcludeSemantics(child: art),
    );
  }
}

/// The gate: a seal and the sentence, never a padlock (L-17).
class _GateSeal extends StatelessWidget {
  const _GateSeal({required this.gate});

  final String gate;

  @override
  Widget build(BuildContext context) {
    final TrackMark? seal = TrackArt.gateSeal;
    return Padding(
      padding: const EdgeInsets.only(top: StrideSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: TrackArt.seal,
            height: TrackArt.seal,
            child: seal == null
                ? const CustomPaint(painter: _SealPainter())
                : ExcludeSemantics(
                    child: PixelAsset(
                      assetPath: seal.assetPath,
                      nativeWidth: seal.nativeWidth,
                      nativeHeight: seal.nativeHeight,
                      scale: seal.scale,
                    ),
                  ),
          ),
          const SizedBox(width: StrideSpace.s6),
          Expanded(
            child: Text(
              'Also needs $gate',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The painted seal: a wax disc with a bar across it. Not a lock, not a coin
/// — a mark pressed on a thing that is spoken for.
class _SealPainter extends CustomPainter {
  const _SealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(
      (size.width / 2).floorToDouble(),
      (size.height / 2).floorToDouble(),
    );
    canvas.drawCircle(c, 7, Paint()..color = StrideColors.surfaceBlock);
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..color = StrideColors.borderDefault
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 8, height: 2),
      Paint()..color = StrideColors.textMuted,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
}

/// A fold in the road: an empty run ahead, or the stretch already walked.
///
/// The numbers are never skipped — the fold says which levels it swallowed —
/// and the walked fold unfolds on a tap.
class _Fold extends StatelessWidget {
  const _Fold({required this.stop, required this.open, this.onTap});

  final FoldStop stop;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TrackMark? mark = TrackArt.fold;
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: TrackArt.rail,
          height: TrackArt.foldHeight,
          child: Center(
            child: mark != null
                ? ExcludeSemantics(
                    child: PixelAsset(
                      assetPath: mark.assetPath,
                      nativeWidth: mark.nativeWidth,
                      nativeHeight: mark.nativeHeight,
                      scale: mark.scale,
                    ),
                  )
                : const CustomPaint(
                    size: Size(TrackArt.roadWidth, TrackArt.foldHeight),
                    painter: _FoldPainter(),
                  ),
          ),
        ),
        const SizedBox(width: StrideSpace.s10),
        Expanded(
          child: Text(
            stop.label,
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
          ),
        ),
        if (onTap != null)
          Text(
            open ? 'FOLD' : 'UNFOLD',
            style: StrideType.microLabel.copyWith(
              color: StrideColors.textSecondary,
            ),
          ),
      ],
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: open ? 'Fold the road already walked' : 'Unfold ${stop.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// The painted fold: the track narrowing into a pleat and out again.
class _FoldPainter extends CustomPainter {
  const _FoldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bed = Paint()..color = StrideColors.surfaceCard;
    final Paint edge = Paint()..color = StrideColors.borderDefault;
    final double w = size.width;
    final double h = size.height;
    // Full width at both ends, pinched to a third across the middle third.
    final Path p = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.68, h * 0.36)
      ..lineTo(w * 0.68, h * 0.64)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(w * 0.32, h * 0.64)
      ..lineTo(w * 0.32, h * 0.36)
      ..close();
    canvas.drawPath(p, bed);
    canvas.drawPath(
      p,
      Paint()
        ..color = edge.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // The pleat's shadow line, so the pinch reads as folded rather than cut.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.32, h / 2 - 1, w * 0.36, 2),
      Paint()..color = StrideColors.separator,
    );
  }

  @override
  bool shouldRepaint(_FoldPainter old) => false;
}

/// The end of the road: a cap on the track and the projection's own honest
/// sentence about why it stops (`DECISIONS/0028` §6).
class _EndCap extends StatelessWidget {
  const _EndCap({required this.stop});

  final EndStop stop;

  @override
  Widget build(BuildContext context) {
    final TrackMark? mark = TrackArt.endCap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: TrackArt.rail,
          height: TrackArt.capHeight,
          child: Center(
            child: mark != null
                ? ExcludeSemantics(
                    child: PixelAsset(
                      assetPath: mark.assetPath,
                      nativeWidth: mark.nativeWidth,
                      nativeHeight: mark.nativeHeight,
                      scale: mark.scale,
                    ),
                  )
                : const CustomPaint(
                    size: Size(TrackArt.roadWidth, TrackArt.capHeight),
                    painter: _EndCapPainter(),
                  ),
          ),
        ),
        const SizedBox(width: StrideSpace.s10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: StrideSpace.s6),
            child: Text(
              stop.sentence,
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// The painted cap: the track running out into two courses of loose stone.
class _EndCapPainter extends CustomPainter {
  const _EndCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bed = Paint()..color = StrideColors.surfaceCard;
    final Paint edge = Paint()..color = StrideColors.borderDefault;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 12), bed);
    canvas.drawRect(Rect.fromLTWH(0, 0, 1, 12), edge);
    canvas.drawRect(Rect.fromLTWH(size.width - 1, 0, 1, 12), edge);
    // Two courses of loose stone, then nothing.
    for (final (int row, double inset) in <(int, double)>[
      (0, 4),
      (1, 10),
    ]) {
      final double y = 14 + row * 8.0;
      canvas.drawRect(
        Rect.fromLTWH(inset, y, size.width - inset * 2, 4),
        Paint()..color = row == 0 ? edge.color : StrideColors.separator,
      );
    }
  }

  @override
  bool shouldRepaint(_EndCapPainter old) => false;
}
