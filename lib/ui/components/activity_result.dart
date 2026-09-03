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
import 'adaptive_text.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'rarity_item_title.dart';
import 'surfaces.dart';

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
///
/// ## The slip, and why it is not a box
///
/// Until EPO03 this was a `surfaceCard` rectangle with a 48 px icon, a grey
/// micro verb and a line of type: Copper Ore, Oak Log and Herb Broth were one
/// picture, and DIR-13's first finding was that the universal result had
/// become a **toast**. It is now a **tally slip** — a deckled paper page
/// (`KitFrame.pageSealed`) with the item's icon at integer ×2, the verb on its
/// own ribbon, and the facts written on ruled lines with the figures aligned
/// down the right margin, the way a ledger is written.
///
/// ## Rarity is material, never area-fill
///
/// The rank changes what the slip is **made of** and what is pressed into it,
/// and it never floods the card with a hue (`rarity_item_title.dart` states
/// that rule; this is one of the surfaces it binds):
///
/// | rank | material | mark |
/// |---|---|---|
/// | common / unknown | paper (`journalLeaf`) | — |
/// | uncommon | cloth (`buckram`) | — |
/// | rare, epic, legendary | warm parchment (`notable`) | the drop sack, and a wax seal in the rank's own tone |
/// | a bonus proc at any rank | warm parchment | the bonus mark |
///
/// The three wax tones are the point rather than a flourish: the producer's
/// running note on the recipe book is that six identical saturated red seals
/// read as a grid of stamps, so this family's seals differ by tone before they
/// ship (`RewardArt.sealWaxRare`).
///
/// ## Motion
///
/// Three beats, each once, each at most 180 ms, and nothing after 400 ms: the
/// host's *settle*, the ribbon's *stamp* (opacity and a 1.10 → 1.0 press) and
/// the seal's *press* (1.06 → 1.0). Nothing flashes, nothing counts up,
/// nothing loops (`RULES.md` P-6). Under Reduce Motion every one of them is
/// drawn at its final frame from the first — and **only** the motion goes: the
/// arrival haptic in [ActivityResultHost] is not gated on it, because an
/// accessibility setting may not remove a feedback channel it does not name
/// (`MISTAKES.md` M-16).
class ActivityResultCard extends StatelessWidget {
  const ActivityResultCard({super.key, required this.result});

  final ActivityResult result;

  /// Widest the slip gets; a phone is narrower and takes the gutter.
  static const double maxWidth = 361;

  /// The hero's integer scale. 48² native at ×2 = 96 logical px — the icon
  /// the player has been squinting at, finally shown at the size of the thing
  /// it is celebrating (L-18: an integer multiple, never a fitted box).
  static const int heroScale = 2;

  /// What the slip is made of, by rank. Material is the escalation; the hue
  /// stays on the name and the marks.
  static PanelSurface surfaceFor(ActivityResult result) {
    final Rarity? rarity = result.rarity;
    if (result.bonusQuantity > 0) return PanelSurface.notable;
    if (rarity == null) return PanelSurface.journalLeaf;
    if (rarity.rank >= Rarity.rare.rank) return PanelSurface.notable;
    if (rarity.rank >= Rarity.uncommon.rank) return PanelSurface.buckram;
    return PanelSurface.journalLeaf;
  }

  /// The wax seal a Rare-or-better find is sealed with, or null.
  ///
  /// **Null for Common and Uncommon on purpose.** A seal on every result is a
  /// seal on nothing, and the two lower ranks already say what they are in
  /// their material and their ink.
  static String? sealFor(Rarity? rarity) => switch (rarity) {
    Rarity.rare => RewardArt.sealWaxRare,
    Rarity.epic => RewardArt.sealWaxEpic,
    Rarity.legendary => RewardArt.sealWaxLegendary,
    Rarity.common || Rarity.uncommon || null => null,
  };

  @override
  Widget build(BuildContext context) {
    final bool notable = result.notable;
    final Color skillInk = result.skill == null
        ? StrideColors.textSecondary
        : StrideColors.forSkill(result.skill!);
    final String? seal = sealFor(result.rarity);

    final List<Widget> facts = <Widget>[
      if (result.bonusQuantity > 0)
        _RuledFact(
          mark: RewardArt.markBonusYield,
          label: 'Bonus yield',
          figure: '+${result.bonusQuantity}',
          ink: StrideColors.positiveReady,
        ),
      if (result.rarity case final Rarity r when r.rank >= Rarity.rare.rank)
        _RuledFact(
          mark: RewardArt.markRareDrop,
          label: '${r.label} drop',
          ink: RarityStyle.of(r).ink,
        ),
      if (result.xp > 0 && result.skillName != null)
        _RuledFact(
          mark: RewardArt.markExp,
          label: '${result.skillName} experience',
          figure: '+${result.xp}',
          ink: skillInk,
        ),
    ];

    final Widget page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (result.itemId case final ContentId id) ...<Widget>[
              PixelAsset.item(PixelIcons.itemFor(id), scale: heroScale),
              const SizedBox(width: StrideSpace.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Stamp(verb: result.verb, skill: result.skill),
                  const SizedBox(height: StrideSpace.s6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: RarityName.wrapping(
                          name: result.itemName,
                          rarity: result.rarity,
                          style: StrideType.sub,
                        ),
                      ),
                      if (result.quantity > 1) ...<Widget>[
                        const SizedBox(width: StrideSpace.s6),
                        Text(
                          '×${result.quantity}',
                          style: StrideType.numericValue.copyWith(
                            color: StrideColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (seal case final String wax) ...<Widget>[
              const SizedBox(width: StrideSpace.s6),
              _WaxSeal(asset: wax),
            ],
          ],
        ),
        if (result.quantity >= _TallyRow.threshold) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          _TallyRow(quantity: result.quantity),
        ],
        ...facts,
      ],
    );

    final Widget slip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        // A floating slip needs an edge against whatever scrolls beneath it,
        // and that is all this is. **The reward glow is gone** (DIR-13 finding
        // 4): a warm bloom around a rounded dark card read as a focus ring
        // rather than as significance, and the escalation is now the slip's
        // own material and the bracket. One shadow, every tier, no pulse.
        decoration: const BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x8014120F),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: KitPlate(
          frame: KitFrame.pageSealed,
          fill: StrideColors.surfaceCard,
          surface: surfaceFor(result),
          child: page,
        ),
      ),
    );

    if (!notable) return slip;
    // The notable escalation is **material, not motion** — a bronze bracket
    // in two corners and the rarity's ink, nothing that flashes or counts up.
    // `DECISIONS/0029` allows a raster as a discrete ornament Flutter
    // positions, which is what this is; it carries no word, number or state,
    // and it is drawn outside the content box so it can never sit under type.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        slip,
        const Positioned(top: 0, left: 0, child: _Bracket(quarter: 0)),
        const Positioned(bottom: 0, right: 0, child: _Bracket(quarter: 2)),
      ],
    );
  }
}

/// The verb, stamped on its skill's own ribbon.
///
/// The ribbon is one drawing in six tones (`RewardArt.stampVerbFor`) and its
/// centre is transparent, so the word is **type over the slip's own fill** and
/// no label is ever baked into a raster (L-18). A verb longer than the ribbon
/// shrinks within [AdaptiveText]'s floor rather than overflowing it; the
/// longest the table produces is `GATHERING COMPLETE`, which is why the label
/// is `compactLabel` rather than `microLabel`.
///
/// The *stamp* beat: 120 ms, opacity 0 → 1 and a 1.10 → 1.0 press, once, on
/// first build. Never `easeOutBack` — the overshoot is the jackpot register
/// the owner ruled out.
class _Stamp extends StatefulWidget {
  const _Stamp({required this.verb, required this.skill});

  final String verb;
  final ContentId? skill;

  static const Duration press = Duration(milliseconds: 120);

  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: _Stamp.press,
    value: 1,
  );

  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion arrives at the final frame and stays there. The controller
    // is still created and still disposed, so the widget's life is identical
    // either way and nothing else in the card branches on this.
    if (_pressed) return;
    _pressed = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _press
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget ribbon = SizedBox(
      width: RewardArt.stampWidth.toDouble(),
      height: RewardArt.stampHeight.toDouble(),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: PixelAsset(
              assetPath: RewardArt.stampVerbFor(widget.skill?.value),
              nativeWidth: RewardArt.stampWidth,
              nativeHeight: RewardArt.stampHeight,
              scale: 1,
            ),
          ),
          Padding(
            // The ribbon's swallowtail ends are notches, not label room.
            padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s12),
            child: AdaptiveText(
              widget.verb,
              style: StrideType.compactLabel,
              color: StrideColors.textPrimary,
              minScale: 0.7,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: _press,
      child: ribbon,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutCubic.transform(_press.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 1.10 - 0.10 * t, child: child),
        );
      },
    );
  }
}

/// The rank's wax seal, pressed into the slip's top-right corner.
///
/// The *seal press* beat: 1.06 → 1.0 over 180 ms on `easeOutCubic`, once.
/// Decorative — the `Rare drop` line below states the fact in words, and a
/// screen reader must not hear it twice.
class _WaxSeal extends StatefulWidget {
  const _WaxSeal({required this.asset});

  final String asset;

  static const Duration press = Duration(milliseconds: 180);

  @override
  State<_WaxSeal> createState() => _WaxSealState();
}

class _WaxSealState extends State<_WaxSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: _WaxSeal.press,
    value: 1,
  );

  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pressed) return;
    _pressed = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _press
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _press,
    child: ExcludeSemantics(
      child: PixelAsset(
        assetPath: widget.asset,
        nativeWidth: RewardArt.sealWaxExtent,
        nativeHeight: RewardArt.sealWaxExtent,
        scale: 1,
      ),
    ),
    builder: (BuildContext context, Widget? child) => Transform.scale(
      scale: 1.06 - 0.06 * Curves.easeOutCubic.transform(_press.value),
      child: child,
    ),
  );
}

/// A batch's tally, in five-bar gate strokes.
///
/// One glyph per five, at most two of them, and then the numeral does the
/// work — a ledger strokes out two gates and then writes the number. **Static
/// by construction**: the strokes are laid out at full size from the first
/// frame and nothing counts up (`RULES.md` P-6). Decorative: the `×n` beside
/// the name is the fact.
class _TallyRow extends StatelessWidget {
  const _TallyRow({required this.quantity});

  final int quantity;

  /// Below five there is nothing to tally — one or two of a thing is a
  /// number, not a count worth stroking out.
  static const int threshold = 5;

  /// Above this the strokes stop being a picture and become a wall.
  static const int strokeCeiling = 10;

  @override
  Widget build(BuildContext context) {
    if (quantity < threshold || quantity > strokeCeiling) {
      return const SizedBox.shrink();
    }
    final int glyphs = quantity ~/ 5;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < glyphs; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: StrideSpace.s6),
            const PixelAsset(
              assetPath: RewardArt.glyphTally,
              nativeWidth: RewardArt.tallyWidth,
              nativeHeight: RewardArt.tallyHeight,
              scale: 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// One fact, written on a ruled line: its mark, the words, and the figure
/// aligned down the right margin.
///
/// The rule is the kit's own journal tile (`KitTile.ruleJournal`), drawn above
/// the line it introduces, so a slip with three facts reads as three entries
/// in a ledger rather than three rows of a settings screen. The mark is 24
/// logical px and the words are `micro`, so the row is mark-height — the mark
/// is what the eye catches on a card that is about to fade, and the words are
/// the detail underneath it.
class _RuledFact extends StatelessWidget {
  const _RuledFact({
    required this.mark,
    required this.label,
    required this.ink,
    this.figure,
  });

  final String mark;
  final String label;
  final Color ink;

  /// The right-aligned figure — `+12`, `+1`. Null for a fact that is only a
  /// fact, like `Rare drop`.
  final String? figure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const SizedBox(height: StrideSpace.s4),
      const KitEdge(tile: KitTile.ruleJournal),
      Row(
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
          Expanded(
            child: Text(label, style: StrideType.micro.copyWith(color: ink)),
          ),
          if (figure case final String f) ...<Widget>[
            const SizedBox(width: StrideSpace.s6),
            Text(f, style: StrideType.micro.copyWith(color: ink)),
          ],
        ],
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
