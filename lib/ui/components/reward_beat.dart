/// The one reward language (PLAYABLE_EXPERIENCE_REFINEMENT_01 §29, §31, §32).
///
/// ## Why one component
///
/// The owner's device review found every gameplay result inventing its own
/// card: a craft wrote its result into the recipe card and left it there, a
/// level-up appended `SMITHING LEVEL 4` to whatever screen happened to
/// trigger it, combat stacked an XP block and reward rows under a static
/// heading, and a finished gather printed a line that read like a log. Each
/// was truthful; together they were five visual languages for one idea —
/// *something you did just paid off*.
///
/// This file is that idea, once. Every result fits one of three tiers:
///
/// | Tier | What | Treatment |
/// |---|---|---|
/// | MINOR | an ordinary gather, craft, or drop | a quiet block: eyebrow, one title line, one or two detail lines |
/// | MEDIUM | a level-up, an equipment craft, a contract handed in, a knowledge stage | a framed beat in its own accent, heading weight, the facts beneath |
/// | MAJOR | a project completed, a significant discovery, a signature item | the same frame, card-title weight, a heavier rule |
///
/// A beat says what happened (the eyebrow), names the thing (the title), and
/// gives the facts (the lines). Nothing here loops, bursts, or waits to be
/// opened (`RULES.md` P-6): the only motion is [StaggeredReveal], which
/// resolves a list of beats top to bottom once and then holds still.
///
/// ## Transient by contract (§32)
///
/// A beat is built from a **report** — the command's own return value — and
/// never from state. It clears when its owner clears the report: a timer for
/// minor results, an acknowledgement for medium and major. Nothing here can
/// outlive the moment it describes, so no screen can grow a log.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

import '../icons/pixel_icons.dart';
import '../icons/reward_art.dart';
import '../theme/rarity_style.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'data_display.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'rarity_badge.dart';
import 'rarity_item_title.dart';
import 'surfaces.dart';

/// How much a result matters — the only axis presentation may vary on.
enum RewardTier { minor, medium, major }

/// Marks the subtree inside a reward layer (`reward_layer.dart`).
///
/// Inside it, beats drop their own frames and item rows keep a rarity frame
/// only from Uncommon up: the layer is the one strong frame, and a box
/// inside a box inside a box was the device finding the correction pass
/// answers (finding E). Outside it — inline on a card — a beat frames
/// itself as before.
class RewardLayerScope extends InheritedWidget {
  const RewardLayerScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RewardLayerScope>() != null;

  @override
  bool updateShouldNotify(RewardLayerScope oldWidget) => false;
}

/// One result, as a beat.
class RewardBeat extends StatelessWidget {
  const RewardBeat({
    super.key,
    required this.tier,
    required this.eyebrow,
    required this.title,
    this.lines = const <String>[],
    this.rarity,
    this.accent,
    this.icon,
    this.child,
    this.onContinue,
    this.continueLabel = 'OK',
  });

  final RewardTier tier;

  /// What happened, in a word or two: `CRAFTED`, `VICTORY`, `STUDIED`.
  final String eyebrow;

  /// The thing: `Oak Plank ×1`, `Bronze Sword`, `Forest Wolf`.
  final String title;

  /// The facts beneath, one per line. Kept short by the caller.
  final List<String> lines;

  /// Colours the frame and the title when the result has a rarity.
  final Rarity? rarity;

  /// Colours the frame and the eyebrow when the result has no rarity but
  /// belongs to something — a skill, the step accent. Ignored when [rarity]
  /// is set. Null falls back to the default border.
  final Color? accent;

  /// The thing's picture, leading the title — a crafted item's approved
  /// 48 px icon (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1: a completion
  /// that shows the thing beats one that only names it). Carries no motion
  /// of its own, so pixel art lands on whole pixels (`RULES.md` A-2).
  final Widget? icon;

  /// Anything structured beneath the lines — reward rows, an Equip button.
  final Widget? child;

  /// Medium and major beats are acknowledged, not timed out. Null hides the
  /// control (the caller owns a different dismissal, or the tier is minor).
  final VoidCallback? onContinue;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final RarityStyle? rarityStyle = RarityStyle.maybe(rarity);
    final Color frame =
        rarityStyle?.accent ?? accent ?? StrideColors.borderDefault;
    final Color titleInk = rarityStyle?.accent ?? StrideColors.textPrimary;
    final Color eyebrowInk = switch (tier) {
      RewardTier.minor => StrideColors.textSecondary,
      _ => rarityStyle?.accent ?? accent ?? StrideColors.textSecondary,
    };
    final bool inLayer = RewardLayerScope.isInside(context);
    // In the layer the headline steps up a weight: the frame it no longer
    // carries is replaced by size, which is the hierarchy the layer wants.
    final TextStyle titleStyle = switch (tier) {
      RewardTier.minor => StrideType.sub,
      RewardTier.medium =>
        inLayer ? StrideType.cardTitle : StrideType.sectionHeading,
      RewardTier.major => StrideType.cardTitle,
    };

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                eyebrow,
                style: StrideType.microLabel.copyWith(color: eyebrowInk),
                maxLines: 1,
              ),
            ),
            if (rarity != null) RarityBadge(rarity: rarity),
          ],
        ),
        const SizedBox(height: StrideSpace.s2),
        if (icon case final Widget leading)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              leading,
              const SizedBox(width: StrideSpace.s10),
              Expanded(
                child: AdaptiveText(title, style: titleStyle, color: titleInk),
              ),
            ],
          )
        else
          AdaptiveText(title, style: titleStyle, color: titleInk),
        // Prose wraps; it is never shrunk to fit. A fact line can be a
        // sentence ("+2 Max HP · harder fights are within reach"), and the
        // narrowest phone at the largest text scale is the case that decides.
        for (final String line in lines) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            line,
            style:
                (tier == RewardTier.minor ? StrideType.micro : StrideType.sub)
                    .copyWith(color: StrideColors.textSecondary),
            maxLines: 3,
          ),
        ],
        if (child case final Widget c) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          c,
        ],
        if (onContinue case final VoidCallback go) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: StrideButton.secondary(label: continueLabel, onPressed: go),
          ),
        ],
      ],
    );

    // MINOR sits on the fill alone; MEDIUM and MAJOR take a frame in their
    // accent. The difference between the two upper tiers is weight and the
    // rule's thickness, never a different shape.
    // Inside the layer: no fill, no border — the layer is the frame, and
    // the beat is content. Outside: the nested block as before.
    if (inLayer) {
      return SizedBox(width: double.infinity, child: body);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StrideSpace.blockPadding),
      decoration: BoxDecoration(
        color: StrideColors.surfaceBlock,
        borderRadius: StrideRadius.inner,
        border: tier == RewardTier.minor
            ? null
            : Border.all(color: frame, width: tier == RewardTier.major ? 2 : 1),
      ),
      child: body,
    );
  }
}

/// The universal level-up (§29): LEVEL, WHAT UNLOCKED, WHY IT MATTERS.
///
/// One presentation shared by gathering, crafting and character level — it is
/// never appended to whatever surface triggered it, it is placed by that
/// surface as a beat of its own. Always MEDIUM: a level is the same size of
/// event wherever it lands.
class LevelUpCard extends StatelessWidget {
  const LevelUpCard({
    super.key,
    required this.name,
    required this.level,
    this.skill,
    this.unlocked = const <String>[],
    this.why,
  });

  /// `Smithing`, `Mining`, or `Traveler` for the character.
  final String name;
  final int level;

  /// The skill, for its hue; null colours the beat with the reward light ink
  /// (FMPO02 wave 3 — it took the step accent, and a character LEVEL UP is
  /// not a step figure; `ART_DIRECTION.md` L-16).
  final ContentId? skill;

  /// What this level opened, by display name.
  final List<String> unlocked;

  /// The one sentence that answers "so what" — given by the caller, who
  /// knows: `+2 Max HP`, `Higher seams can be worked`.
  final String? why;

  @override
  Widget build(BuildContext context) {
    final Color accent = skill == null
        ? StrideColors.rewardLightInk
        : StrideColors.forSkill(skill!);
    return RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'LEVEL UP',
      title: '${name.toUpperCase()} LEVEL $level',
      accent: accent,
      // The level-up plate, in the slot a crafted item's icon already uses.
      // Every level-up in the game routes through this beat, so the mark
      // lands here once rather than at each of the call sites that raise one
      // (VAWO01). Decorative: the eyebrow and title state the fact.
      icon: _LevelStamp(skill: skill),
      lines: <String>[?why],
      child: unlocked.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('UNLOCKED', style: StrideType.microLabel),
                const SizedBox(height: StrideSpace.s2),
                for (final String item in unlocked)
                  AdaptiveText(
                    item,
                    style: StrideType.sub,
                    color: StrideColors.textPrimary,
                  ),
              ],
            ),
    );
  }
}

/// The mark a level-up wears: the **skill's own glyph, stamped into a well**
/// (EPO03, DIR-13).
///
/// DIR-13's third finding was that the level-up reads as a settings dialog —
/// a 48² plate beside card-title type in a dark card with a 1 px rule and a
/// Continue button. The plate was the same bronze medal for Mining 4 and
/// Cooking 9, so the one beat the game keeps for its biggest ordinary moment
/// said nothing about *which* thing levelled.
///
/// The glyph is the skill icon the Character and Skills screens already use,
/// sunk into the kit's stamped well (`KitFrame.slotWell`) so it reads as
/// pressed into the page rather than pasted onto it. A character level — no
/// skill — keeps `plateLevelUp`, which is exactly what it is a mark for.
///
/// Decorative throughout: the eyebrow and the title state the fact in words.
class _LevelStamp extends StatelessWidget {
  const _LevelStamp({required this.skill});

  final ContentId? skill;

  /// The glyph's own footprint, and so the well's content box. The well is
  /// bigger than this by its own band, which `KitPlate.well` computes — the
  /// arithmetic that must not be done the other way round.
  static const double glyph = 48;

  @override
  Widget build(BuildContext context) {
    final String? mark = skill == null ? null : PixelIcons.skillFor(skill!);
    return ExcludeSemantics(
      child: KitPlate.well(
        frame: KitFrame.slotWell,
        contentWidth: glyph,
        contentHeight: glyph,
        // Two families, two honest declarations: a skill glyph is 24² UI art
        // magnified ×2, the level plate is 48² reward art drawn ×1. Both
        // occupy the same 48 dp box, which is what keeps the well one size.
        child: Center(
          child: mark == null
              ? const PixelAsset(
                  assetPath: RewardArt.plateLevelUp,
                  nativeWidth: 48,
                  nativeHeight: 48,
                  scale: 1,
                )
              : PixelAsset.skill(mark, scale: 2),
        ),
      ),
    );
  }
}

/// Resolves [children] top to bottom, once — the choreography every
/// multi-beat result shares (§16): each child fades and settles in after the
/// one above, on one clock, so the reveal is a function of index and a test
/// can settle it. Reduced motion arrives finished.
///
/// Fast by design: a beat takes [beat] and the next starts [stagger] later,
/// so five beats resolve in well under a second. Nothing is unskippable —
/// the children are the information and are laid out at full size from the
/// first frame; only opacity and a short rise animate.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.children,
    this.beat = const Duration(milliseconds: 260),
    this.stagger = const Duration(milliseconds: 110),
    this.gap = StrideSpace.s8,
  });

  final List<Widget> children;
  final Duration beat;
  final Duration stagger;
  final double gap;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _started = false;

  Duration get _total => Duration(
    milliseconds:
        widget.beat.inMilliseconds +
        widget.stagger.inMilliseconds *
            (widget.children.length > 1 ? widget.children.length - 1 : 0),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) || widget.children.isEmpty) {
      _clock.value = 1;
    } else {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Animation<double> _slice(int index) {
    final int total = _total.inMilliseconds;
    final double begin = (widget.stagger.inMilliseconds * index) / total;
    final double end = begin + widget.beat.inMilliseconds / total;
    return CurvedAnimation(
      parent: _clock,
      curve: Interval(begin, end > 1 ? 1 : end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < widget.children.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: widget.gap),
        FadeTransition(
          opacity: _slice(i),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(_slice(i)),
            child: widget.children[i],
          ),
        ),
      ],
    ],
  );
}

/// One item gained, as a row: the approved 48 px icon, the name in its
/// rarity ink, the count, and — when the item has a rarity — the word
/// beneath, because colour is never the only carrier.
///
/// Lifted from the combat panel (PLAYABLE_POLISH_01 §4) so a contract
/// reward, a finished gather queue and a victory drop are one row, not
/// three. The row's arrival is the panel's one staggered resolve; the icon
/// carries no motion of its own, so pixel art lands on whole pixels from its
/// first frame (`RULES.md` A-2).
class RewardItemRow extends StatelessWidget {
  const RewardItemRow({
    super.key,
    required this.id,
    required this.name,
    required this.quantity,
    this.rarity,
  });

  final ContentId id;
  final String name;
  final int quantity;
  final Rarity? rarity;

  /// The icon's edge plus its gap: what the badge is indented by, so the word
  /// starts under the name rather than under the picture.
  static const double _nameIndent = 48 + StrideSpace.s10;

  @override
  Widget build(BuildContext context) {
    // Common is low-key everywhere: a plain row. From Uncommon up the row
    // keeps its rarity frame — the ink and the word say the item is worth
    // looking at, and the frame is the only box the layer allows inside
    // itself (finding E).
    final bool plain = rarity == null || rarity == Rarity.common;
    final Widget row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // `itemFor` never returns null: an item the icon set does not
            // cover gets the deliberately non-representational slab, and the
            // name beside it carries the meaning (**L-17**).
            PixelAsset.item(PixelIcons.itemFor(id)),
            const SizedBox(width: StrideSpace.s10),
            Expanded(
              // Wrapping: this is the narrowest full-width name surface in
              // the app. A name is prose; it takes the second line rather
              // than the smaller type.
              child: RarityName.wrapping(
                name: name,
                rarity: rarity,
                style: StrideType.sub,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            AdaptiveText('×$quantity', style: StrideType.itemCount),
          ],
        ),
        if (rarity != null && !plain) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Padding(
            padding: const EdgeInsets.only(left: _nameIndent),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RarityBadge(rarity: rarity),
            ),
          ),
        ],
      ],
    );
    if (plain) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: StrideSpace.s4),
        child: row,
      );
    }
    return RarityFrame(
      rarity: rarity,
      padding: const EdgeInsets.all(StrideSpace.s8),
      child: row,
    );
  }
}

/// A labelled group of facts inside a beat or a layer: `EXPERIENCE` over
/// `+40 XP`, `LEARNED` over a recipe name. The micro-label is the grammar
/// every panel already speaks; this keeps the three reward surfaces from
/// each spelling it slightly differently.
class RewardFacts extends StatelessWidget {
  const RewardFacts({
    super.key,
    required this.label,
    required this.children,
    this.gap = StrideSpace.s4,
  });

  final String label;
  final List<Widget> children;
  final double gap;

  /// A group of plain lines.
  static Widget lines(
    String label,
    List<String> lines, {
    TextStyle style = StrideType.sub,
    Color color = StrideColors.textPrimary,
  }) => RewardFacts(
    label: label,
    children: <Widget>[
      for (final String line in lines)
        AdaptiveText(line, style: style, color: color),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: StrideType.microLabel, maxLines: 1),
      SizedBox(height: gap),
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}
