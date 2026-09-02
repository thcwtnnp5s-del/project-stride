/// The universal activity result — one answer, everywhere, to "what did I
/// just do, what did I get, how much, what progressed?"
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, device correction 01).
///
/// ## Why this exists
///
/// The device verdict on the first pass was blunt: rare crafts celebrated,
/// and ordinary completions read as **nothing happened** — a small text
/// beat inside whichever recipe or node card happened to be expanded, easy
/// to scroll past and gone on a timer. The owner's requirement is
/// universal: EVERY completed activity gets a visible result. The strength
/// may vary; the existence may not.
///
/// ## What this is
///
/// - [ActivityResult] — a presentation snapshot of a completed activity,
///   built from the session's own reports (`ActionReport`, `CraftReport`,
///   the queue controllers' committed aggregates). Nothing here recomputes
///   a figure; every number arrived on a report (`RULES.md` E-2).
/// - [ActivityResultCard] — the one visual language: the item's 48 px
///   icon, the verb, the name ×quantity in rarity ink, the bonus line, the
///   +XP line in the skill's hue. A notable result (bonus yield, an
///   Uncommon-or-better output) takes the warm reward-light frame; held
///   MEDIUM/MAJOR results are not this file's job — they keep the reward
///   layer (`reward_layer.dart`), which speaks the same language larger.
/// - [ActivityResultHost] — the overlay that owns the card's life on a
///   gameplay surface: it **snapshots** each result (so the session's 5 s
///   result timer clearing a report cannot blank a card mid-read), merges
///   rapid repeats of the same item instead of stacking popups, holds a
///   readable ~3.2 s (notable ~4 s) and fades, restarting whenever a new
///   result lands. Its clock is a ticker: a hidden tab's card **waits** —
///   `TickerMode` pauses it — so a queue that finishes while the player is
///   elsewhere greets them with its summary instead of having quietly
///   expired. A tap dismisses early; nothing blocks the surface beneath.
///
/// Presentation only, by construction: no report is created here, no state
/// is persisted, and dismissing a card changes nothing but pixels.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

import '../../audio/audio_controller.dart';
import '../icons/pixel_icons.dart';
import '../icons/reward_art.dart';
import '../state/audio_scope.dart';
import '../theme/rarity_style.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'rarity_item_title.dart';

/// The verb an activity's result leads with, from the skill that did the
/// work. A skill this table does not know gathered *something* — the
/// fallback is honest, and content stays data (`RULES.md` E-5).
String activityVerbFor(String? skillId) => switch (skillId) {
  'skill.mining' => 'MINED',
  'skill.woodcutting' => 'CHOPPED',
  'skill.foraging' => 'FORAGED',
  'skill.cooking' => 'COOKED',
  'skill.smithing' => 'FORGED',
  _ => 'GATHERED',
};

/// One completed activity, as the card presents it. Immutable; every field
/// is copied from a report or a controller's committed aggregate.
final class ActivityResult {
  const ActivityResult({
    required this.verb,
    required this.itemName,
    required this.quantity,
    this.itemId,
    this.bonusQuantity = 0,
    this.skill,
    this.skillName,
    this.xp = 0,
    this.rarity,
    this.incremental = false,
  });

  /// `CRAFTED`, `MINED`, `GATHERING COMPLETE`, …
  final String verb;

  /// The primary item, for its icon. Null renders no icon rather than a
  /// wrong one.
  final ContentId? itemId;

  final String itemName;
  final int quantity;

  /// How much of [quantity] a yield bonus contributed — shown as its own
  /// line so the proc is visible, exactly as the report states it.
  final int bonusQuantity;

  /// The skill that progressed, for its hue; null tints nothing.
  final ContentId? skill;
  final String? skillName;
  final int xp;

  /// The output's authored rarity, when the report carries one.
  final Rarity? rarity;

  /// True when this result is one more repetition of an ongoing action
  /// (a tapped gather) rather than a cumulative restatement — the host
  /// then **adds** it to a same-item card instead of replacing the totals.
  final bool incremental;

  /// The tier-2 read: a bonus proc or an Uncommon-or-better output takes
  /// the reward-light treatment. MEDIUM/MAJOR significance never reaches
  /// this card — the reward layer holds those.
  bool get notable =>
      bonusQuantity > 0 ||
      (rarity != null && rarity!.rank >= Rarity.uncommon.rank);

  ActivityResult merged(ActivityResult next) => ActivityResult(
    verb: next.verb,
    itemId: itemId ?? next.itemId,
    itemName: itemName,
    quantity: quantity + next.quantity,
    bonusQuantity: bonusQuantity + next.bonusQuantity,
    skill: skill ?? next.skill,
    skillName: skillName ?? next.skillName,
    xp: xp + next.xp,
    rarity: rarity ?? next.rarity,
    incremental: true,
  );
}

/// The card itself — pure presentation of one [ActivityResult].
class ActivityResultCard extends StatelessWidget {
  const ActivityResultCard({super.key, required this.result});

  final ActivityResult result;

  @override
  Widget build(BuildContext context) {
    final bool notable = result.notable;
    final Color frame = notable
        ? (RarityStyle.maybe(result.rarity)?.accent ??
              StrideColors.rewardLightInk)
        : StrideColors.borderDefault;
    final Color skillInk = result.skill == null
        ? StrideColors.textSecondary
        : StrideColors.forSkill(result.skill!);
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
          if (result.itemId case final ContentId id) ...<Widget>[
            PixelAsset.item(PixelIcons.itemFor(id)),
            const SizedBox(width: StrideSpace.s10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  result.verb,
                  style: StrideType.microLabel.copyWith(
                    color: notable
                        ? StrideColors.rewardLightInk
                        : StrideColors.textSecondary,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: StrideSpace.s2),
                RarityName.wrapping(
                  name: '${result.itemName} ×${result.quantity}',
                  rarity: result.rarity,
                  style: StrideType.sub,
                ),
                if (result.bonusQuantity > 0) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  _MarkedLine(
                    mark: RewardArt.markBonusYield,
                    text: '+${result.bonusQuantity} bonus yield',
                    ink: StrideColors.positiveReady,
                  ),
                ],
                if (result.rarity != null &&
                    result.rarity!.rank >= Rarity.rare.rank) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  _MarkedLine(
                    mark: RewardArt.markRareDrop,
                    text: '${result.rarity!.label} drop',
                    ink:
                        RarityStyle.maybe(result.rarity)?.accent ??
                        StrideColors.rewardLightInk,
                  ),
                ],
                if (result.xp > 0 && result.skillName != null) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  _MarkedLine(
                    mark: RewardArt.markExp,
                    text: '+${result.xp} ${result.skillName} XP',
                    ink: skillInk,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    // Notable results sit on the one plate tile authored for this escalation
    // (`PanelSurface.notable`, FMPO02 wave2) — grain under the row, never a
    // second border; the flat fill still paints first, so a tile that fails
    // to load is the plain card underneath it.
    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 361),
      decoration: BoxDecoration(
        color: StrideColors.surfaceCard,
        borderRadius: StrideRadius.inner,
        border: Border.all(color: frame, width: notable ? 2 : 1),
        boxShadow: <BoxShadow>[
          // A floating card needs an edge against whatever scrolls beneath
          // it; the notable tier adds the one warm glow family.
          const BoxShadow(
            color: Color(0x8014120F),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
          if (notable)
            const BoxShadow(color: StrideColors.rewardGlow, blurRadius: 14),
        ],
      ),
      child: notable
          ? SurfaceFill(
              tile: PanelSurfaces.of(PanelSurface.notable)!,
              fill: StrideColors.surfaceCard,
              radius: StrideRadius.inner,
              child: Padding(
                padding: const EdgeInsets.all(StrideSpace.blockPadding),
                child: content,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(StrideSpace.blockPadding),
              child: content,
            ),
    );
    if (!notable) return card;
    // The notable escalation is **material, not motion** — a bronze bracket
    // in two corners and the rarity's ink, nothing that flashes or counts up.
    // `DECISIONS/0029` allows a raster as a discrete ornament Flutter
    // positions, which is what this is; it carries no word, number or state,
    // and it is drawn outside the content box so it can never sit under type.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        card,
        const Positioned(top: 0, left: 0, child: _Bracket(quarter: 0)),
        const Positioned(bottom: 0, right: 0, child: _Bracket(quarter: 2)),
      ],
    );
  }
}

/// One reward line: its authored mark, then the words.
///
/// The mark is 24 logical px and the line is `micro`, so the row is
/// mark-height. That is deliberate — the mark is the thing the eye catches on
/// a card that scrolls past, and the words are the detail underneath it.
class _MarkedLine extends StatelessWidget {
  const _MarkedLine({
    required this.mark,
    required this.text,
    required this.ink,
  });

  final String mark;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      // Decorative: the words beside it already say the whole fact, so a
      // screen reader must not hear it twice.
      ExcludeSemantics(
        child: PixelAsset(
          assetPath: mark,
          nativeWidth: 24,
          nativeHeight: 24,
          scale: 1,
        ),
      ),
      const SizedBox(width: StrideSpace.s6),
      Flexible(
        child: Text(text, style: StrideType.micro.copyWith(color: ink)),
      ),
    ],
  );
}

/// One corner of the notable card's bracket, rotated into place.
///
/// One authored asset, four possible orientations — a transform of a drawing,
/// never four drawings (`RULES.md` A-2).
class _Bracket extends StatelessWidget {
  const _Bracket({required this.quarter});

  /// Quarter turns clockwise from the authored top-left orientation.
  final int quarter;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RotatedBox(
      quarterTurns: quarter,
      child: const PixelAsset(
        assetPath: RewardArt.ornamentCorner,
        nativeWidth: 32,
        nativeHeight: 32,
        scale: 1,
      ),
    ),
  );
}

/// The overlay host: [child] is the surface; the latest result floats over
/// its foot. Feed it a new [result] under a changed [resultToken] and the
/// card appears, merges, or restarts its readable hold.
class ActivityResultHost extends StatefulWidget {
  const ActivityResultHost({
    super.key,
    required this.child,
    required this.result,
    required this.resultToken,
    this.onExpired,
  });

  final Widget child;

  /// The latest completed activity, or null when none stands. A token
  /// change with a null result changes nothing: the card on stage lives
  /// out its own hold — a controller's result timer clearing its report
  /// must never blank a card mid-read.
  final ActivityResult? result;

  /// Identity of [result]; the host reacts only when it changes.
  final Object? resultToken;

  /// Runs when a shown card expires or is tapped away — the craft screen's
  /// summary acknowledgement. Never runs for a merely replaced card.
  final VoidCallback? onExpired;

  /// The readable hold before the fade, by tier — inside the corrected
  /// brief's 2.5–4 s window.
  static const Duration hold = Duration(milliseconds: 3200);
  static const Duration holdNotable = Duration(milliseconds: 4000);
  static const Duration fade = Duration(milliseconds: 300);
  static const Duration rise = Duration(milliseconds: 150);

  @override
  State<ActivityResultHost> createState() => _ActivityResultHostState();
}

class _ActivityResultHostState extends State<ActivityResultHost>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState — a `late final` cascade would create the
  // controller on first touch, and on a surface that never shows a card
  // that first touch is dispose, where the vsync registration looks up a
  // deactivated ancestor (the travel card's own recorded lesson).
  late final AnimationController _life;

  ActivityResult? _shown;

  /// Whether this surface is in front of the player (`TickerMode`): a
  /// hidden tab's card **waits** — its clock frozen where it stood — so a
  /// queue that finishes elsewhere greets the player with its summary
  /// instead of having quietly expired. Explicit, not delegated to ticker
  /// muting: a muted ticker's elapsed time keeps running underneath and
  /// would leap the card straight past its hold on return.
  bool _ticking = true;

  @override
  void initState() {
    super.initState();
    _life = AnimationController(vsync: this)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) _expire();
      });
    _consider(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool ticking = TickerMode.valuesOf(context).enabled;
    if (ticking == _ticking) return;
    _ticking = ticking;
    if (!ticking) {
      _life.stop();
    } else if (_shown != null && _life.value < 1) {
      _life.forward();
    }
  }

  @override
  void didUpdateWidget(ActivityResultHost old) {
    super.didUpdateWidget(old);
    if (widget.resultToken != old.resultToken) _consider(_shown);
  }

  void _consider(ActivityResult? current) {
    final ActivityResult? next = widget.result;
    if (next == null) return;
    ActivityResult landed = next;
    if (current != null &&
        next.incremental &&
        _life.isAnimating &&
        current.itemId == next.itemId &&
        current.verb == next.verb) {
      landed = current.merged(next);
    } else if (next.notable && !(current?.notable ?? false)) {
      // The tier-2 arrival's one light tap — on promotion, never per merge
      // and never for ordinary cards (their boundary feedback is the
      // surface's own). Gated on the Sound & feel toggle inside.
      final AudioController? audio = AudioScope.maybeRead(context);
      audio?.hapticLight();
    }
    setState(() => _shown = landed);
    _life
      ..duration =
          (landed.notable
              ? ActivityResultHost.holdNotable
              : ActivityResultHost.hold) +
          ActivityResultHost.fade
      ..value = 0;
    if (_ticking) _life.forward();
  }

  void _expire() {
    if (_shown == null) return;
    setState(() => _shown = null);
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ActivityResult? shown = _shown;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: <Widget>[
        widget.child,
        if (shown != null)
          Positioned(
            left: StrideSpace.screenGutter,
            right: StrideSpace.screenGutter,
            bottom: StrideSpace.s12,
            child: AnimatedBuilder(
              animation: _life,
              builder: (BuildContext context, Widget? card) {
                final double totalMs = _life.duration!.inMilliseconds
                    .toDouble();
                final double t = _life.value * totalMs;
                // Entrance rise/fade-in, then the hold, then the fade-out.
                // Reduced motion: full presence for the whole life — the
                // information never depends on the motion.
                final double riseMs = ActivityResultHost.rise.inMilliseconds
                    .toDouble();
                final double fadeStart =
                    totalMs - ActivityResultHost.fade.inMilliseconds;
                double opacity = 1;
                double lift = 0;
                if (!reduced) {
                  if (t < riseMs) {
                    opacity = t / riseMs;
                    lift = 6 * (1 - t / riseMs);
                  } else if (t > fadeStart) {
                    opacity = 1 - (t - fadeStart) / (totalMs - fadeStart);
                  }
                }
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, lift),
                    child: card,
                  ),
                );
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _life.stop();
                  _expire();
                },
                child: Semantics(
                  liveRegion: true,
                  child: Center(child: ActivityResultCard(result: shown)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
