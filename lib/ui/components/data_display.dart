/// The small data-display primitives: the label/value tile, the skill chip, the
/// requirement gate, and the primary button.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../icons/pixel_icons.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'surfaces.dart';

/// The system's dominant pattern: a micro-label above a value, with an optional
/// unit line beneath.
class LabeledValueTile extends StatelessWidget {
  const LabeledValueTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.leading,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;

  /// A glyph marking what kind of quantity this is — the walking mark, usually.
  ///
  /// **On the label line, not the value line.** It used to sit immediately
  /// before the numeral, where it took 30 dp of a two-across tile's 106 dp of
  /// content at 320 dp — so `9,999,999` was measured needing 77.3 dp in the 75
  /// it was left. The glyph marks the *category*, which is what the label does,
  /// so putting the two together costs nothing and gives the figure the tile's
  /// whole width.
  final Widget? leading;

  final Color? valueColor;

  /// The floor [AdaptiveText] uses for a tile's value and label.
  ///
  /// Public because [ValueTileRow] measures against them to decide whether a
  /// row of tiles still fits side by side. Two places must agree on this number
  /// and there is one of it.
  static const double floorScale = 0.8;

  /// The horizontal cost of [leading] — a 12 px glyph at ×2, plus its gap.
  static const double leadingExtent = 24 + StrideSpace.iconLabelGap;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: StrideSpace.iconLabelGap),
            ],
            // The label shrinks too, and this is not belt-and-braces.
            //
            // `EXPERIENCE` needs 73.4 dp at 11 px and was given 46 in a
            // three-across tile at 320 dp, so the shipped build drew
            // `EXPERIENC` on the Adventure screen — a clipped word, on a
            // device, that no test in the repository could see, because
            // `TextOverflow.clip` raises nothing. Same defect as D-01, one
            // card down.
            Flexible(
              child: AdaptiveText(
                label.toUpperCase(),
                style: StrideType.microLabel,
                minScale: floorScale,
              ),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.s4),
        // Shrink-to-fit rather than clip or overflow.
        //
        // These tiles sit two- and three-across inside cards, so their width
        // falls as the phone narrows while the numeral inside them grows with
        // the player's progress. At 320 dp a two-across tile gives a 22 px
        // figure about 106 logical px, which nine characters do not fit in —
        // and the failure mode without this is a RenderFlex overflow, which is
        // a yellow stripe on a shipping screen.
        //
        // **Was an unbounded `FittedBox(scaleDown)`.** That never clipped, and
        // it also never stopped: `9,999,999` in a narrow tile came out around
        // 9 px, which is legally present and practically unreadable. An
        // unbounded shrink trades a visible defect for an invisible one, which
        // is the D-01 trade in reverse. [AdaptiveText] shrinks the same way and
        // stops at [floorScale] — 17.6 px, still above the supporting-text
        // floor — and [ValueTileRow] stacks the tiles rather than asking for
        // more than that.
        //
        // This is chrome, not pixel content — L-18's integer-scale rule governs
        // sprites, and no sprite goes through here.
        AdaptiveText(
          value,
          style: StrideType.numericValue,
          color: valueColor,
          minScale: floorScale,
        ),
        if (unit case final String u) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(u, style: StrideType.micro, maxLines: 2),
        ],
      ],
    ),
  );
}

/// Two or three [LabeledValueTile]s that sit side by side while they fit, and
/// stack when they do not.
///
/// ## Why this is a widget rather than a `Row` at each call site
///
/// A row of value tiles is the app's densest arrangement and the one whose
/// content the player grows: `9,999,999` in a two-across tile at 320 dp needs
/// 109 dp at text scale 1.4 and has 106. There is no font size inside
/// [LabeledValueTile.floorScale] that fixes that, and lowering the floor to
/// reach it would answer an accessibility request by making the type smaller —
/// which is the wrong direction, and the trade this system already refuses.
///
/// The right yield is the layout's, not the type's. Below the width the tiles
/// actually need, they stop competing for one line.
///
/// The decision is **measured, not thresholded**. A breakpoint on width or on
/// scale factor is another constant standing in for a measurement, and it is
/// wrong for exactly the strings nobody tested with — which is D-01's whole
/// story. This asks [AdaptiveText.fitsWithin] the same question the tile itself
/// will ask, at the same floor, with the same scaler.
class ValueTileRow extends StatelessWidget {
  const ValueTileRow({super.key, required this.tiles});

  final List<LabeledValueTile> tiles;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    // The ambient style carries the font family; see `AdaptiveText.build`.
    // Measuring the bare role here would ask the wrong font whether the tiles
    // fit, and the answer decides the layout branch.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    TextStyle atFloor(TextStyle style) => inherited.merge(
      style.copyWith(fontSize: style.fontSize! * LabeledValueTile.floorScale),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double each =
            (constraints.maxWidth - StrideSpace.s8 * (tiles.length - 1)) /
            tiles.length;
        // SurfaceBlock's padding on both sides.
        final double content = each - StrideSpace.blockPadding * 2;

        bool fits = content > 0;
        for (final LabeledValueTile tile in tiles) {
          if (!fits) break;
          final double labelRoom = tile.leading == null
              ? content
              : content - LabeledValueTile.leadingExtent;
          fits =
              AdaptiveText.fitsWithin(
                tile.value,
                atFloor(StrideType.numericValue),
                scaler,
                content,
              ) &&
              AdaptiveText.fitsWithin(
                tile.label.toUpperCase(),
                atFloor(StrideType.microLabel),
                scaler,
                labelRoom,
              );
        }

        if (fits) {
          // One height across the row: a tile with a unit line (`/ 100`,
          // `unarmed`) used to stand taller than its neighbours and the row
          // read as three different boxes (PLAYABLE_POLISH_01 §5). The
          // tiles without a unit reserve the line — an empty one — rather
          // than the row measuring intrinsics, which the tile's adaptive
          // text cannot supply.
          final bool anyUnit = tiles.any(
            (LabeledValueTile t) => t.unit != null,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < tiles.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: StrideSpace.s8),
                Expanded(
                  child: anyUnit && tiles[i].unit == null
                      ? LabeledValueTile(
                          label: tiles[i].label,
                          value: tiles[i].value,
                          unit: '',
                          leading: tiles[i].leading,
                          valueColor: tiles[i].valueColor,
                        )
                      : tiles[i],
                ),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: StrideSpace.s8),
              tiles[i],
            ],
          ],
        );
      },
    );
  }
}

/// Skill icon plus uppercase skill name, on a raised chip.
class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.skill, required this.label});

  final ContentId skill;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(skill);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: const BoxDecoration(
        color: StrideColors.surfaceRaised,
        borderRadius: StrideRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            PixelAsset.skill(icon),
            const SizedBox(width: StrideSpace.iconLabelGap),
          ],
          Text(
            label.toUpperCase(),
            style: StrideType.compactLabel.copyWith(
              color: StrideColors.forSkill(skill),
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}

/// An outlined uppercase capsule stating a condition — `REQUIRES FORAGING 1`,
/// `NO TOOL NEEDED`.
///
/// **Outlined, never filled.** It states a fact; it is not a control, and a
/// filled capsule beside a real button would read as a second one.
class RequirementGate extends StatelessWidget {
  const RequirementGate({super.key, required this.label, this.unmet = false});

  final String label;

  /// True when the stated condition is currently FAILING — the skill level the
  /// player does not have, the tool that is not equipped.
  ///
  /// The treatment is primary-ink type in the same outlined capsule, and that
  /// is deliberate restraint, not timidity. The palette has **no** warning or
  /// error colour, by written decision (`StrideColors` — a warning hue is how
  /// an unrequested pressure system acquires a colour), and this capsule may
  /// not fill (a filled capsule beside a real button reads as a second one, per
  /// the class doc above). Within those two rules the available emphasis is
  /// ink: a failing gate is the brightest text in its row while its met peers
  /// stay quiet, and the label itself states the concrete failure.
  final bool unmet;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.gate,
    ),
    // Padding rather than a fixed 22 dp box with `Container(alignment:)`.
    //
    // Two things were wrong with that. `Container`'s alignment expands to the
    // incoming constraints, and inside a `Wrap` those are the full line width —
    // so each gate was silently a full-width capsule and the `Wrap`'s `spacing`
    // had nothing to space. And the 22 was a fixed height around type that
    // grows with the text scaler. Padding shrink-wraps on both axes and derives
    // the height from the line box, which is the same result at scale 1.0 and a
    // correct one above it.
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StrideSpace.s8,
        vertical: 5,
      ),
      child: Text(
        label.toUpperCase(),
        style: unmet
            ? StrideType.gateLabel.copyWith(color: StrideColors.textPrimary)
            : StrideType.gateLabel,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    ),
  );
}

/// The semantic register a primary action speaks in
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4). A small family, not a
/// rainbow: every colour is an existing token, and the differences are
/// construction and temperature, never a new hue per action.
enum StrideButtonVariant {
  /// The screen's meaningful commit — Gather, Set out, Deliver, Continue.
  commit,

  /// The player's offense inside an encounter — the [StrideColors.danger]
  /// accent (its scope amendment is recorded on the token).
  attack,

  /// The guarded action — Brace. The same plate at the opposite
  /// temperature: cool steel line and edge, so offense and defense read
  /// apart at a glance.
  defense,

  /// "You can do this now" — Craft with the materials in the bag, an Equip
  /// that upgrades. Joins the moss language the recipe rows already speak.
  ready,
}

/// The primary action control.
///
/// Disabled rather than hidden when the action cannot run: the cost stays
/// visible, so the player can see what they are walking toward.
///
/// ## The pixel plate (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4)
///
/// The Fable V2 ember was a shine — a ~6 L* gradient and a 14 %-alpha glow,
/// both sub-perceptual at phone brightness — and every register wore it,
/// Cancel included. The plate replaces shine with **construction**, in the
/// language the panels already speak: a flat raised fill, a 2 px lit top
/// edge, a 1 px outline, and a hard 2 px under-ledge — drawn thickness,
/// like a key. A press translates the plate down onto its ledge and puts
/// the top light out: mechanical acknowledgment under the finger, state
/// not motion, so reduced motion loses nothing. Disabled is flat,
/// line-less and ledge-less — an unpressable thing has no thickness.
///
/// One warm glow remains in the system and exactly one control carries it:
/// `Set out`, the game's weightiest commit ([glow]).
class StrideButton extends StatefulWidget {
  const StrideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subLabel,
    this.variant = StrideButtonVariant.commit,
    this.glow = false,
    this.leading,
    this.emblem,
  }) : secondary = false;

  /// A **utility** control, not the screen's game action.
  ///
  /// Shorter, quieter, and shrink-wrapped rather than stretched. `Sync steps`
  /// is the case this exists for: the owner's device review found it reading as
  /// more important than `Gather`, which is the actual game action — a
  /// full-width filled control at the same height and fill as the one that
  /// spends steps and yields loot.
  ///
  /// Demotion is by **size, weight and width**, not by hue: the palette has one
  /// accent and `ART_DIRECTION.md` L-16 reserves it for walking and steps, so
  /// there is no "secondary colour" available and inventing one would be a
  /// palette change smuggled in as a layout fix.
  const StrideButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : subLabel = null,
       secondary = true,
       variant = StrideButtonVariant.commit,
       glow = false,
       leading = null,
       emblem = null;

  final String label;

  /// Null disables the control.
  final VoidCallback? onPressed;

  /// A `micro` line beneath the label — the shortfall, usually.
  final String? subLabel;

  final bool secondary;

  /// The action's register — see [StrideButtonVariant]. Presentation only;
  /// nothing announced changes with it.
  final StrideButtonVariant variant;

  /// The one warm glow. Reserved for the screen-level commit that spends
  /// the game's central currency — `Set out` — and nothing else.
  final bool glow;

  /// A glyph drawn immediately before the label, inside the same centred line
  /// (FMPO02 wave 2, the combat command cluster).
  ///
  /// It is decoration and never information: [label] still says the whole
  /// thing, semantics still announce only [label], and a glyph that fails to
  /// decode leaves a control that reads exactly as it did before. The label is
  /// `Flexible` beside it, so an enlarged text scale wraps the words rather
  /// than pushing the glyph out of the control (D-01).
  ///
  /// **Dimmed, not dropped, when the control is disabled** (FMPO02 wave 3):
  /// the combat cluster is held between turns, and four cells that lost their
  /// icons on every held frame read as four different controls twice a round.
  ///
  /// It does still stand down for a disabled control that grew a [subLabel]
  /// saying why: a 32 dp glyph beside a two-line stack does not fit the combat
  /// cluster's 56 dp cell, and the line that says why a thing cannot be
  /// pressed is never the one squeezed out.
  final Widget? leading;

  /// An **ornament drawn behind the whole face**, clipped to the control, for
  /// a raster that is a picture rather than a nine-patch — the three combat
  /// command plates are centred blobs on a transparent field and cannot be a
  /// [PanelSkin] (`combat_assets.dart`, `CombatHudAssets`).
  ///
  /// Behind the plate and inside the press transform, so it travels with the
  /// control — and **above the control's own face**, which FMPO02 wave 3 put
  /// back underneath it, so the ornament reads as drawn on the button rather
  /// than as the page showing through a hole in it.
  ///
  /// Drawn at 60 % under the label and at 45 % when the control is disabled;
  /// see [leading] for why disablement dims the dressing rather than deleting
  /// it. Null at every call site outside combat and the reward seals.
  final Widget? emblem;

  /// The volume the authored dressing keeps on a control that cannot be
  /// pressed.
  ///
  /// Low enough that the cell is plainly out of reach, high enough that its
  /// identity — which of the four commands this is — survives the held frame.
  static const double disabledDressing = 0.45;

  /// The volume of an [emblem] drawn behind a label.
  ///
  /// The plate is the one raster in the app that sits under type. At full
  /// strength its bright arc crossed the letterforms and both lost — the
  /// review's words were "raster emblems sitting behind and colliding with
  /// their own labels". Dimmed, it reads as material under the word instead of
  /// a second thing competing with it.
  ///
  /// **0.35 is measured, not chosen.** Composited over the `surfaceRaised`
  /// face the control now paints, `plate_attack` and `plate_eat` clear WCAG AA
  /// against the label ink at 7.8 : 1 and 8.5 : 1 even at 0.6 — but
  /// `plate_brace`'s lit steel core is far brighter and sits at 3.02 : 1
  /// there, and 0.4 is still short. 0.35 puts the worst of the three at
  /// 4.90 : 1. One value for all three, because three opacities on three
  /// members of one cluster is the inconsistency this round is closing.
  ///
  /// Public because `test/combat_ui_test.dart` composites the shipped plates
  /// at exactly this value: the guard has to use the number the widget uses,
  /// not a copy of it.
  static const double emblemBehindText = 0.35;

  @override
  State<StrideButton> createState() => _StrideButtonState();
}

class _StrideButtonState extends State<StrideButton> {
  bool _pressed = false;

  String get label => widget.label;
  VoidCallback? get onPressed => widget.onPressed;
  String? get subLabel => widget.subLabel;
  bool get secondary => widget.secondary;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final bool plate = enabled && !secondary;
    final bool down = plate && _pressed;

    // The authored plate (FMPO02). Primary takes `btn_plate`, the utility
    // control takes `btn_compact`, and a **disabled** control takes neither:
    // "an unpressable thing has no thickness" was true of the painted
    // construction and is true of the raster one for the same reason.
    // **The primary takes the EPO03 plate when the kit has one** (`KitFrame.btnPlateV2`).
    //
    // One lookup rather than 43 edits: every call site already reaches this
    // line, so the whole product inherits the new plate the moment the registry
    // row lands, and reverts the moment it is removed. That is the same
    // property `PanelSkins` has, and it is why the plate was authored against a
    // registry instead of dropped into a widget.
    //
    // `btn_compact` still dresses the utility control: the v2 plate is a
    // primary's rim — brass, lit along its top — and putting it on `Cancel`
    // and `Retreat* would undo the register demotion GFCP01 spent a device
    // review earning.
    final PanelSkin? plateSkin = enabled
        ? (secondary
              ? ButtonPlates.compact
              : (KitFrames.of(KitFrame.btnPlateV2) ?? ButtonPlates.primary))
        : null;

    // The variant's construction tokens: the lit top edge, the outline,
    // and the under-ledge. Attack warms the ledge with the danger dim;
    // defense flips the temperature; ready wears the moss the recipe rows
    // already mean "can do" with.
    final (
      Color topLight,
      Color outline,
      Color ledge,
    ) = switch (widget.variant) {
      StrideButtonVariant.commit => (
        StrideColors.actionSheen,
        StrideColors.actionEdge,
        StrideColors.surfaceGround,
      ),
      StrideButtonVariant.attack => (
        StrideColors.actionSheen,
        StrideColors.dangerDim,
        StrideColors.dangerDim,
      ),
      StrideButtonVariant.defense => (
        StrideColors.defenseSheen,
        StrideColors.defenseEdge,
        StrideColors.surfaceGround,
      ),
      StrideButtonVariant.ready => (
        StrideColors.actionSheen,
        StrideColors.positiveReady,
        StrideColors.positiveReadyDim,
      ),
    };

    // **The interior, under the plate** (FMPO02 wave 3, FINAL-10 #1).
    //
    // `btn_plate` and `btn_compact` are nine-patches: an authored rim with a
    // *transparent* middle. Drawn alone over the page they turned the screen's
    // commit action into a window cut through the card to `surfaceGround`
    // (#14120F) — the darkest value in the app, and the same one the page
    // ground 165 px below already wears. The secondary beneath it, still on
    // its painted `surfaceBlock`, then read as the *lighter* of the two and
    // the hierarchy inverted.
    //
    // So the raster keeps the rim and Flutter supplies the face beneath it.
    // The registers stay tokens as `DECISIONS/0029` requires — no tint is
    // applied to the plate itself — and `ready` keeps the moss the recipe rows
    // already mean "can do" with, which is the one register that was already
    // reading as a lit face rather than a hole.
    //
    // Null when disabled: the disabled path draws its own opaque Container
    // (`painted`, `surfaceBlock`) and has never had a hole to fill.
    final Color? interiorFill = !enabled
        ? null
        : secondary
        ? StrideColors.surfaceBlock
        : widget.variant == StrideButtonVariant.ready
        ? StrideColors.positiveReadyDim
        : StrideColors.surfaceRaised;

    // **The dressing survives disablement** (FMPO02 wave 3, FINAL-01 #1).
    //
    // The combat command cluster is four cells that are held between turns.
    // Dropping the plate and the glyph on every held frame made the same four
    // controls change shape twice a round — "flat/unframed on turn 1, framed
    // with rivets on turn 2" — so the cell's identity was never constant long
    // enough to learn. It is kept and *dimmed* instead: an `Opacity`, never a
    // colour remap, so the art is the same art at a quieter volume and the
    // label carries the state in words (`textMuted`) as it always did.
    //
    // The glyph still stands down for a control that grew a [subLabel]: a
    // 32 dp icon row plus two lines of type does not fit the cluster's 56 dp
    // cell, and the line that says *why* a thing cannot be pressed is never
    // the one squeezed out.
    final Widget? leadingGlyph = widget.leading == null
        ? null
        : enabled
        ? widget.leading
        : subLabel == null
        ? Opacity(opacity: StrideButton.disabledDressing, child: widget.leading)
        : null;

    // Over an emblem the label needs a floor under it. The plate is the one
    // ornament drawn *behind type* in the app, and a 1 px hard shadow in the
    // page ground is the cheapest way to keep the glyph edges from dissolving
    // into the blob's brightest arc (FINAL-10 #1, "the emblem goes beside the
    // word, never under it" — it now does both: beside as [leading], and the
    // plate that remains behind is dimmed and underpainted).
    final TextStyle labelStyle = () {
      final TextStyle base = secondary
          ? StrideType.buttonLabelSecondary
          : StrideType.buttonLabel;
      return widget.emblem == null
          ? base
          : base.copyWith(
              shadows: const <Shadow>[
                Shadow(color: StrideColors.surfaceGround, offset: Offset(0, 1)),
                Shadow(color: StrideColors.surfaceGround, offset: Offset(1, 0)),
              ],
            );
    }();

    final Widget body = Container(
      // Minimums. The label is composed — `Gather — 9,999,999 steps` at an
      // enlarged text scale is a real string — so a fixed box is the D-01
      // shape again, and the sub-label variant was a second magic number
      // (56) derived from the first.
      constraints: BoxConstraints(
        minHeight: secondary
            ? StrideGeometry.buttonHeightSecondary
            : subLabel == null
            ? StrideGeometry.buttonHeight
            : StrideGeometry.buttonHeight + 12,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: secondary ? StrideSpace.s10 : StrideSpace.s12,
        vertical: secondary ? StrideSpace.s4 : StrideSpace.s6,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The label, alone as it always was, or preceded by a glyph on the
          // same centred line. `Flexible` around the text and not around the
          // glyph: at an enlarged text scale the words wrap and the glyph
          // keeps its integer-scaled size, because a pixel asset that shrinks
          // to fit has stopped being pixel art (L-18).
          if (leadingGlyph case final Widget glyph)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                glyph,
                const SizedBox(width: StrideSpace.s8),
                Flexible(
                  child: AdaptiveText(
                    label,
                    style: labelStyle,
                    color: enabled ? null : StrideColors.textMuted,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          else
            AdaptiveText(
              label,
              style: labelStyle,
              color: enabled ? null : StrideColors.textMuted,
              textAlign: TextAlign.center,
            ),
          if (subLabel case final String s) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            AdaptiveText(
              s,
              style: StrideType.micro,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    // The plate: flat raised fill, outline, lit top edge, hard under-ledge.
    // Pressed, it sits down onto the ledge and the light goes out — a state
    // swap, not a motion, so reduced motion loses nothing. Disabled and
    // secondary keep their flat surfaces; an unpressable thing has no
    // thickness.
    // The painted construction, unchanged in every line — and now the
    // **fallback**. `PixelFrame` paints this until the plate's raster decodes
    // and forever if it never does, so a missing asset degrades to the control
    // that shipped before FMPO02 rather than to a bare label.
    final BoxDecoration painted = plate
        ? BoxDecoration(
            color: StrideColors.surfaceRaised,
            border: Border.all(color: outline),
            borderRadius: StrideRadius.gate,
          )
        : BoxDecoration(
            color: StrideColors.surfaceBlock,
            border: secondary && enabled
                ? Border.all(color: StrideColors.borderDefault)
                : null,
            borderRadius: secondary ? StrideRadius.inner : StrideRadius.gate,
          );

    // The face: the authored plate where there is one, the painted rectangle
    // where there is not.
    //
    // **The variant registers stay tokens, not raster.** `DECISIONS/0029` calls
    // every register and both states index remaps of the one plate, and PROD-UI
    // authored none of them: attack, defense and ready differ by the `outline`
    // and `ledge` tokens above. Tinting the raster with a `ColorFilter` was the
    // obvious alternative and is refused — a multiply over a four-ink plate
    // authored under the `#7C7263` ceiling has nowhere left to go but darker,
    // so the loud registers would read *quieter* than the neutral one. So the
    // plate stays neutral, the ledge below it carries the register, and the
    // outline carries it in the fallback.
    final Widget unadorned = plateSkin == null
        ? Container(decoration: painted, child: body)
        : PixelFrame(
            skin: plateSkin,
            fallback: painted,
            child: body,
            // The lit top edge belongs to the painted construction and to it
            // alone: over the authored plate's own rim it would be a second
            // highlight on the same edge, which is the doubling `fallback`
            // exists to prevent one layer out. Pressed, the light is out on
            // both paths.
            //
            // It draws inside the frame's reserved band — 2 logical px in —
            // because `PixelFrame` insets its child whether or not the raster
            // arrived, which is the `PanelSkins.insetFor` doctrine: art
            // landing later changes the material, never the layout.
            childBuilder: (BuildContext context, bool framed) =>
                framed || down || !plate
                ? body
                : ClipRRect(
                    borderRadius: StrideRadius.gate,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 2,
                          child: ColoredBox(color: topLight),
                        ),
                        body,
                      ],
                    ),
                  ),
          );

    // The ornament, behind the whole face and clipped to the control
    // (FMPO02 wave 2). It sits outside `PixelFrame`'s reserved band rather
    // than inside it, so a 64 dp-tall plate in a 56 dp cell loses 4 dp of its
    // own transparent margin top and bottom and none of its drawn pixels.
    // Disabled controls get none, for the reason the authored plate is also
    // absent then.
    //
    // Two changes in FMPO02 wave 3. It is **kept when disabled**, at
    // [StrideButton.disabledDressing], for the identity reason [leadingGlyph] carries; and
    // when enabled it is drawn at [StrideButton.emblemBehindText] rather than full, so the
    // blob's bright arc sits under the label as a texture and not as a
    // competing value. Both are `Opacity` over the same art.
    final Widget emblemed = widget.emblem == null
        ? unadorned
        : Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: ClipRect(
                  child: Opacity(
                    opacity: enabled ? StrideButton.emblemBehindText : StrideButton.disabledDressing,
                    child: widget.emblem!,
                  ),
                ),
              ),
              unadorned,
            ],
          );

    // The face beneath everything (FINAL-10 #1). Below the emblem, so the
    // ornament still reads as drawn *on* the control rather than punched
    // through it, and below the plate, whose rim covers the fill's edge.
    final Widget faced = interiorFill == null
        ? emblemed
        : DecoratedBox(
            decoration: BoxDecoration(
              color: interiorFill,
              borderRadius: secondary ? StrideRadius.inner : StrideRadius.gate,
            ),
            child: emblemed,
          );

    // The under-ledge and the one warm glow are Flutter's on both paths: the
    // ledge is drawn thickness *below* the plate, outside anything the raster
    // covers, and it is where the variant's temperature lives.
    final Widget surfaced = plate
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: StrideRadius.gate,
              boxShadow: <BoxShadow>[
                if (!down) BoxShadow(color: ledge, offset: const Offset(0, 2)),
                if (widget.glow && !down)
                  const BoxShadow(
                    color: StrideColors.actionGlow,
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: faced,
          )
        : faced;

    // The 2 px press travel — the plate onto its ledge.
    final Widget pressable = Transform.translate(
      offset: Offset(0, down ? 2 : 0),
      child: surfaced,
    );

    // Semantics carries the button role and its enabled state, because the
    // control is a plain GestureDetector — there is no Material widget here to
    // supply either, and a screen reader would otherwise announce a bare
    // label. The child text is excluded: the composed label already says it
    // once, and merging would announce every string twice.
    return Semantics(
      button: true,
      enabled: enabled,
      label: subLabel == null ? label : '$label. $subLabel',
      excludeSemantics: true,
      // Excluding the descendants also excludes the GestureDetector's tap,
      // so the action lives here, on the one announced node.
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        // A secondary control shrink-wraps; a primary one fills its column.
        // Width is half of what makes the primary action read as primary.
        //
        // The shrink-wrapped plate stays its quiet 34 dp, but the **hit
        // region** it sits in meets the 44 dp platform floor (FINAL-A M-1,
        // GAME_FEEL_CHARACTER_PRESENTATION_01): `Cancel`, `Stop gathering`
        // and `Retreat` are gameplay-path escapes, and an escape a thumb
        // can miss is not quieter, it is worse. The demotion is visual;
        // the target is not.
        child: secondary
            ? Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: StrideGeometry.buttonHitFloor,
                  ),
                  alignment: Alignment.centerLeft,
                  child: pressable,
                ),
              )
            : pressable,
      ),
    );
  }
}
