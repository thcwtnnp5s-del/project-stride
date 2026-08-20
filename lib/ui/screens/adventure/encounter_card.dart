/// One enemy at this location, what fighting it means, and the action.
///
/// Reads an [EncounterOption] projection and dispatches
/// `SessionController.startEncounter`. It carries **no step cost anywhere**:
/// starting an encounter is free by decision (`DECISIONS/0020` §3), and a cost
/// tile here would be the most convincing lie on the tab.
///
/// ## The creature is present before the fight
///
/// The card opens with the enemy itself — its committed combat idle, grounded
/// on a small stage band — so the tab says "this creature is here, and I can
/// choose to fight it" rather than listing one (`ACTIVITY_FEEL_PRESENTATION_01`
/// §1.3). It is deliberately **not** an inventory icon and not a boss overlay:
/// the same art the combat stage will fell, at the same grounding rule, on the
/// same `surfaceBlock` band the gather card stands its figure on. The idle
/// loops for one bounded visit and then holds its first frame — a figure that
/// never stops moving implies something is happening, and nothing is — and
/// resumes on a return to the app, exactly as `CombatStage` and
/// `AmbientPlayer` reason. An enemy the art table does not know renders the
/// card as it always was: no strip, no empty box, no crash (`RULES.md` E-5).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show EnemyBehavior;

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/grounded_sprite.dart';
import '../../components/surfaces.dart';
import '../../icons/combat_assets.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class EncounterCard extends StatelessWidget {
  const EncounterCard({super.key, required this.option});

  final EncounterOption option;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final EncounterOption o = option;
    final CombatantArt? art = CombatAssets.enemyFor(o.enemyId);

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (art != null) ...<Widget>[
            _EnemyStage(art: art),
            const SizedBox(height: StrideSpace.s10),
          ],
          Text(o.name, style: StrideType.cardTitle, maxLines: 2),
          Text(
            o.isBoss ? 'Guards this place' : 'Roams here',
            style: StrideType.sub,
            maxLines: 1,
          ),
          const SizedBox(height: StrideSpace.s10),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              if (o.isBoss) const RequirementGate(label: 'Boss'),
              RequirementGate(label: _behaviorLabel(o.behavior)),
            ],
          ),
          const SizedBox(height: StrideSpace.s10),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(label: 'Health', value: '${o.maxHealth}'),
              LabeledValueTile(label: 'Attack', value: '${o.attack}'),
              LabeledValueTile(label: 'Defence', value: '${o.defence}'),
            ],
          ),
          const SizedBox(height: StrideSpace.s8),
          Text(
            _rewards(o),
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 2,
          ),
          const SizedBox(height: StrideSpace.s12),
          StrideButton(
            label: c.busy ? 'Starting…' : 'Start Combat',
            subLabel: c.busy ? null : _subLabel(o),
            onPressed: c.busy || !o.available
                ? null
                : () => c.startEncounter(o.enemyId),
          ),
        ],
      ),
    );
  }

  static String _behaviorLabel(EnemyBehavior b) => switch (b) {
    EnemyBehavior.steady => 'One strike a turn',
    EnemyBehavior.flurry => 'Two light strikes a turn',
    EnemyBehavior.guarded => 'Heavy strike every third turn',
  };

  static String _rewards(EncounterOption o) {
    final String xp = '${o.xp} XP';
    if (o.drops.isEmpty) return 'Rewards: $xp';
    final String names = o.drops.map((DropPreview d) => d.name).join(', ');
    return 'Rewards: $xp, $names';
  }

  /// What the button says under itself: how much of this visit is left, or the
  /// truthful reason it is disabled, in the engine's order.
  ///
  /// An available enemy now carries a figure rather than nothing, because
  /// "you can fight this" and "you can fight this twice more before you have
  /// to travel" are different pieces of planning and the second is the one a
  /// player with a route in mind is actually asking about
  /// (`DECISIONS/0021` §1). The spent line is unchanged, word for word: the
  /// player's experience of it did not change, only how many wins it took.
  static String? _subLabel(EncounterOption o) => o.available
      ? '${o.remainingThisVisit} of ${o.encountersPerVisit} this visit'
      : _reasonText(o.reason);

  /// The truthful reason the button is disabled, in the engine's order.
  static String? _reasonText(String? reason) => switch (reason) {
    null => null,
    'enemy_driven_off' => 'Driven off — returns after you travel',
    'encounter_in_progress' => 'Finish your current encounter',
    'session_not_ready' => 'Reload before fighting',
    _ => 'Not available right now',
  };
}

/// The creature on its ground: a small stage band carrying the enemy's combat
/// idle, grounded, bottom-aligned, with the headroom above it.
///
/// The band is the gather stage's visual language at encounter size —
/// `surfaceBlock` (a multiply contact shadow needs something bright enough to
/// darken, `gather_node_card.dart` records the finding), the default border,
/// the inner radius, the figure seated low. It is a strip, not a scene: no
/// backdrop, no position, no camera.
class _EnemyStage extends StatelessWidget {
  const _EnemyStage({required this.art});

  final CombatantArt art;

  /// The band's interior height. 120 seats the ×2 wolf-class figures exactly
  /// (56 canvas + 4 shadow bleed, ×2) and keeps the card compact — the
  /// creature reads first without the card becoming a second combat screen.
  static const double height = 120;

  /// ×2 where the figure fits — the combat stage's own scale, so the creature
  /// here and the creature in the fight are the same size of thing — and ×1
  /// (native, the crispest reduction) for the guardian-class 96 canvases,
  /// which at ×2 would need a 200 dp band. Integer scales only: pixel art
  /// never lands between multiples.
  static int scaleFor(CombatTrack idle) =>
      (idle.canvasHeight + ContactShadowSpec.bleed) * 2 <= height ? 2 : 1;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: StrideColors.surfaceBlock,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.inner,
    ),
    // Clipped at the band's own rounded edge, as the gather stage is: a
    // figure exactly the band's height must not paint over the border.
    child: ClipRRect(
      borderRadius: StrideRadius.inner,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _EnemyIdle(track: art.idle, scale: scaleFor(art.idle)),
      ),
    ),
  );
}

/// The enemy's idle track, played as a bounded visit.
///
/// One `AnimationController`, no `Timer`, no clock read — `CombatStage`'s
/// idle machine at its smallest. The track loops for [_visit] after mount and
/// after every return to the app, then holds its first frame; `TickerMode`
/// mutes it, the lifecycle stops it, and reduced motion holds the first frame
/// throughout (`MediaQuery.disableAnimationsOf`, the convention
/// `AmbientPlayer` set). Bounded is also what lets every widget test
/// `pumpAndSettle`.
class _EnemyIdle extends StatefulWidget {
  const _EnemyIdle({required this.track, required this.scale});

  final CombatTrack track;
  final int scale;

  @override
  State<_EnemyIdle> createState() => _EnemyIdleState();
}

class _EnemyIdleState extends State<_EnemyIdle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// How long the idle loops before holding its first frame. Shorter than the
  /// combat stage's eight seconds: this is a card among cards, not the fight.
  static const Duration _visit = Duration(seconds: 6);

  /// Built in `initState`, not lazily: under reduced motion nothing ever
  /// reads a lazy controller, so its initialiser would run from `dispose` —
  /// an ancestor lookup on a deactivated element (`AmbientPlayer`'s finding).
  late final AnimationController _controller;

  int _frame = 0;
  bool _started = false;
  bool _reduceMotion = false;
  bool _heldByLifecycle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _visit)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _reduceMotion = reduce;
      for (final String frame in widget.track.track.frames) {
        precacheImage(AssetImage(frame), context);
      }
      // Started here rather than in `initState`, so the first decision
      // already knows whether the platform asked for reduced motion.
      if (!reduce) _begin();
      return;
    }
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _controller.stop();
      _hold();
    } else {
      _begin();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_reduceMotion) {
        _heldByLifecycle = false;
        return;
      }
      if (_heldByLifecycle) {
        _heldByLifecycle = false;
        _controller.forward();
      } else if (!_controller.isAnimating) {
        // Coming back to the app is what a visit is.
        _begin();
      }
      return;
    }
    if (_controller.isAnimating) {
      _heldByLifecycle = true;
      _controller.stop();
    }
  }

  void _begin() {
    _heldByLifecycle = false;
    _controller.forward(from: 0);
  }

  /// The visit is spent: the first frame, and nothing scheduled.
  void _hold() {
    if (_frame == 0) return;
    setState(() => _frame = 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _hold();
  }

  void _onTick() {
    final CombatTrack t = widget.track;
    final int passUs = t.duration.inMicroseconds;
    if (passUs <= 0) return;
    final Duration elapsed = _visit * _controller.value;
    // A modulo over the track's own pass, so the loop never freezes on the
    // pass's last slot mid-visit.
    final int next = t.frameAt(
      Duration(microseconds: elapsed.inMicroseconds % passUs),
    );
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CombatTrack t = widget.track;
    return GroundedSprite(
      assetPath: t.frame(_frame),
      footprint: t.footprint,
      scale: widget.scale,
      canvas: t.canvasWidth,
      canvasHeight: t.canvasHeight,
    );
  }
}
