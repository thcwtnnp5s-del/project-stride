/// The encounter in progress: the animated stage with its narration strip, the
/// 2 × 2 command grid, and the outcome panel.
///
/// ## Shape
///
/// The Adventure tab renders this in place of the location's cards while
/// `session.encounter != null`, and keeps it up while an outcome report is
/// waiting to be acknowledged (`GAME_BIBLE/COMBAT/02` §10). The stage
/// (`combat_stage.dart`) sits above and now carries the round's one narration
/// line on its own bottom edge; the command grid, the Eat chooser and the
/// result panel are the boundary it sits on, and they read the same
/// projections it does.
///
/// ## The ratio this screen exists to invert (FMPO02)
///
/// The owner's device verdict on 4d9a81f was that "the giant lower command
/// frame dominates the fight": four full-width buttons, three sub-labels and a
/// log block under a heading, about 276 dp of an 852 dp screen against the
/// stage's 192. `ART-09_combat_brief.md` §1 and `ART-12_ux_brief.md` §6
/// answer that here — the log becomes one line **on** the picture, the
/// sub-labels collapse into one micro line, and the controls become a 2 × 2
/// grid of 56 dp cells with Retreat as a quiet link. The whole card is 219 dp
/// and every combat semantic, timing and outcome flow is untouched.
///
/// ## What it never does
///
/// It renders nothing optimistically: every HP figure the HUD settles on is
/// `EncounterView`, read live after the commit, and every log line and every
/// beat the stage replays is a `CombatBeat` the session built from an event
/// already on disk. It never diffs state to find out what happened, and it
/// never re-derives a figure a beat already carries. No wall-clock: nothing
/// here advances the fight; the replay is a `TickerMode`-gated presentation
/// of a round already resolved.
///
/// ## The one thing it remembers
///
/// The engine clears the encounter on the same commit that decides it, so
/// when a Won/Lost/Retreated report arrives `session.encounter` is already
/// null and the stage would have no enemy to fell. This widget keeps the
/// **last non-null `EncounterView`** it was built with — enemy id, names,
/// location, maxima — for exactly as long as the outcome stands unacknowledged.
/// It is presentation memory of a fact the engine committed, held for one
/// panel's lifetime, cleared with the report; it decides nothing and outlives
/// nothing (`RULES.md` E-2).
///
/// ## When it reads the live view, and when it deliberately does not
///
/// While a combat command is in flight (`controller.busy`) the remembered
/// view is **frozen**: the engine applies a round to in-memory state
/// synchronously and only the commit awaits, so a frame rendered mid-command
/// already carries the next round's committed figures with no report to
/// choreograph them. Presenting them then is how the device showed damage
/// before the animation and an apparent mid-round heal-back
/// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4d); new committed figures
/// reach the stage only together with the beats that present them.
library;

import 'package:flutter/widgets.dart';

import 'package:stride_core/stride_core.dart' show KnowledgeTier;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/surfaces.dart';
import '../../icons/combat_assets.dart';
import '../../icons/reward_art.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'combat_choreography.dart' show replays;
import 'combat_stage.dart';

class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key});

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  /// The last live view — see the library doc.
  EncounterView? _lastView;

  /// True while the stage replays a round; the controls are disabled and the
  /// outcome panel waits.
  bool _playing = false;

  /// The report the last build saw, by identity — how a new one is spotted
  /// on the frame it arrives.
  CombatReport? _seenReport;

  /// Counts fights beginning on screen; keys the entrance reveal so it
  /// plays once per fight. Presentation memory only.
  int _fightArrival = 0;

  /// Whether the narration strip is showing the whole round rather than its
  /// last line. Ephemeral, like the Eat chooser's own flag.
  bool _logOpen = false;

  void _onPlayingChanged(bool playing) {
    if (playing == _playing) return;
    setState(() => _playing = playing);
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final EncounterView? live = s.encounter;
    final CombatReport? report = c.lastCombat;
    final CombatBeat? outcome = report?.outcome;

    // Whether the stage was already in the tree when this build began — only
    // then can a report arriving now reach its `didUpdateWidget` and replay.
    final bool stageWasUp = _lastView != null;

    // The view is adopted only while no command is in flight. The engine
    // applies a round to in-memory state synchronously and only the commit
    // awaits, so a frame rendered mid-command already reads next round's
    // committed figures — with the report that would choreograph them still
    // null. Adopting `live` on that frame snapped every HP bar to its final
    // value; the replay then tweened *from* those values, which showed the
    // wolf's damage before its animation and healed the player back up to
    // "after hit 1" mid-round (the device-observed defect). Freezing the view
    // until the report arrives means new committed figures only ever reach
    // the stage together with the beats that present them. On a killing blow
    // the same mid-command frame has `live == null` with no outcome yet;
    // freezing also keeps the remembered view — and the stage — up through it.
    if (!c.busy) {
      if (live != null) {
        _lastView = live;
      } else if (outcome == null) {
        // Nothing to stage and nothing to acknowledge.
        _lastView = null;
      }
    } else if (live != null && _lastView == null) {
      // First sight of an encounter (a remount mid-command): nothing is
      // shown yet, so nothing can snap.
      _lastView = live;
    }
    final EncounterView? view = _lastView;
    // A null→non-null adoption is a fight beginning on screen — the token
    // that keys the entrance reveal below, so the stage steps in once per
    // fight and never on a mid-fight rebuild.
    if (!stageWasUp && view != null) _fightArrival++;

    // A report that will be replayed locks the controls and holds the outcome
    // panel back on the frame it arrives. The stage confirms through
    // [_onPlayingChanged] — but only post-frame, which is one frame too late
    // for the panel not to flash and the controls not to open. Mirrors the
    // stage's own condition exactly: a fresh mount does not replay a report
    // it mounted with, hence [stageWasUp].
    if (!identical(report, _seenReport)) {
      _seenReport = report;
      if (stageWasUp &&
          view != null &&
          report != null &&
          report.succeeded &&
          replays(report.events)) {
        _playing = true;
      }
    }

    // The fight has ended and its result has not been acknowledged. With no
    // remembered view — a relaunch cannot have one, and a report cannot
    // outlive one — the panel stands alone; otherwise the stage plays the
    // outcome first and the panel follows.
    // The result rises over the stage in the reward layer
    // (PLAYABLE_POLISH_01 §4) once the stage has finished playing the
    // outcome; the card beneath the scrim keeps the log and the locked
    // controls, so the fight is still there behind its own ending. Continue
    // is `acknowledgeCombat`, as before.
    if (view == null) {
      if (outcome == null || report == null) return const SizedBox.shrink();
      final bool signature = _ResultPanel.signatureAwarded(outcome);
      return RewardRaise(
        token: outcome,
        // A signature drop is major (ART-10 §3: "masterwork/signature drop
        // classify as RewardTier.major for hapticHeavy"); an ordinary
        // victory keeps the medium frame and haptic it always had.
        tier: signature ? RewardTier.major : RewardTier.medium,
        accent: _ResultPanel.accentOf(outcome),
        beats: _ResultPanel.beatsOf(report, outcome),
        emblem: signature ? RewardArt.sealSignature : null,
        emblemSize: const Size(96, 48),
        onDismiss: c.acknowledgeCombat,
        child: const SizedBox.shrink(),
      );
    }

    final bool ended = live == null;
    final bool resolved =
        ended && outcome != null && report != null && !_playing;
    final bool signature =
        resolved && _ResultPanel.signatureAwarded(outcome);
    return RewardRaise(
      token: resolved ? outcome : null,
      tier: signature ? RewardTier.major : RewardTier.medium,
      accent: resolved ? _ResultPanel.accentOf(outcome) : null,
      beats: resolved
          ? _ResultPanel.beatsOf(report, outcome)
          : const <Widget>[],
      emblem: signature ? RewardArt.sealSignature : null,
      emblemSize: const Size(96, 48),
      onDismiss: c.acknowledgeCombat,
      // The fight's entrance (Fable V2 Iteration 02): the stage resolves
      // first, the controls follow a beat later — the same reveal grammar
      // as a reward layer, played once per fight (see `_fightArrival`).
      // `StaggeredReveal` renders everything at full value under Reduce
      // Motion, and a mid-fight rebuild keeps the element, so nothing
      // re-plays.
      child: StaggeredReveal(
        key: ValueKey<int>(_fightArrival),
        gap: StrideSpace.cardGap,
        children: <Widget>[
          CombatStage(
            view: view,
            report: report,
            ended: ended,
            onPlayingChanged: _onPlayingChanged,
            // The loadout's visual facts, snapshotted by the stage at its
            // first bell (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5).
            equipment: c.session.equipmentVisualState,
            // The round's narration, on the picture's own bottom edge rather
            // than as a block on the card below it (`ART-09` §4). The stage
            // places it; this screen still decides every word.
            narration: _CombatLog(
              report: report,
              enemyName: view.enemyName,
              intent: view.intentLine,
              playing: _playing,
              open: _logOpen,
              onToggle: () => setState(() => _logOpen = !_logOpen),
            ),
          ),
          // The command kit: an oiled-leather surface, no frame. `combatFrame`
          // is a surface role now (`panel_skin.dart` — the frame belongs to
          // the one thing a screen is about, and here that is the stage), so
          // this differs from its neighbours by material and never by a
          // second border.
          SectionCard(
            role: PanelRole.combatFrame,
            surface: PanelSurface.leather,
            padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
            child: _CombatControls(
              view: view,
              controller: c,
              locked: _playing || ended,
            ),
          ),
        ],
      ),
    );
  }
}

/// The round's narration: **one line**, on the fight's own bottom edge.
///
/// ## What changed, and what did not
///
/// This used to be a heading and up to four lines on the command card — 40 to
/// 100 dp of the 252 dp column the owner's device read as "a giant lower
/// command frame dominating the fight" (`ART-09` §4, §1). The words are
/// unchanged and every one of them is still reachable: the strip shows the
/// most recent line, and a tap opens the whole round. Position replaces the
/// heading — a line along the picture's base says "now" without spending a
/// row on the word.
///
/// Held back while the stage replays the round, exactly as before: the lines
/// would otherwise tell the ending before the blows land. They appear,
/// complete, when the replay ends or is skipped.
///
/// Between rounds, with nothing to narrate, the strip carries the creature's
/// **intent** — the prose the knowledge tiers earn (`DECISIONS/0027`). That
/// is where a tell as long as "Scarred and patient, it feints where the young
/// ones snapped — two strikes, always." belongs: it is a sentence, and the
/// command card's one micro line is for the figures it implies, which is the
/// only reading of "collapse the sub-labels" that does not clip prose.
///
/// ## Why the authored parchment strip is not behind this line
///
/// FMPO02 wave 2 produced `narration_strip.png` for exactly this ground, and
/// it is packaged and unused. Measured (`test/combat_ui_test.dart`, the
/// contrast guard), composited over the stage:
///
/// | rows | mean relative luminance | contrast vs `textPrimary` |
/// |---|---|---|
/// | 0–15, the whole canvas | 0.111 | **5.32 : 1** |
/// | 4–10, the drawn body | 0.246 | **2.90 : 1** |
/// | 6–9, the bright core | 0.414 | **1.85 : 1** |
///
/// The canvas figure passes AA and is the wrong figure: nine of the sixteen
/// rows are fully transparent, and averaging them in measures the stage
/// showing through rather than the parchment a line of type would sit on. The
/// rows the text actually crosses are 3.22 : 1, and its brightest pixels reach
/// #EBE9CB — 1.00 : 1 against `textPrimary`, which is to say invisible.
///
/// So the strip keeps the translucent `surfaceGround` fill it shipped with.
/// Never `textMuted` and never a pale ground: this is the fight's own
/// narration and it sits on a picture, which is the hardest ground the palette
/// has. The guard holds the measured figures so a darker re-authored strip
/// swaps in on a measurement rather than on a redesign.
class _CombatLog extends StatelessWidget {
  const _CombatLog({
    required this.report,
    required this.enemyName,
    required this.intent,
    required this.playing,
    required this.open,
    required this.onToggle,
  });

  final CombatReport? report;
  final String enemyName;

  /// What the creature will do this round, when knowledge has earned it.
  final String? intent;

  final bool playing;

  /// Whether the strip is showing the whole round.
  final bool open;
  final VoidCallback onToggle;

  /// The round as lines, in order, plus the one the strip shows closed.
  ///
  /// The list is unchanged from the block this replaces, so nothing about
  /// *what is said* moved with the layout. The headline is the last line that
  /// earns the strip: a plain `Turn 3.` does not, because the stage's own TURN
  /// chip is already saying it two hundred pixels above and the strip would
  /// then narrate nothing at all. A telegraph turn — "Turn 3. The Forest Wolf
  /// gathers itself…" — is the opposite case and keeps its place.
  ({List<String> lines, String headline}) _content() {
    final CombatReport? r = report;
    ({List<String> lines, String headline}) one(String line) =>
        (lines: <String>[line], headline: line);
    if (playing) return one('Tap the stage to skip.');
    if (r == null) return one(intent ?? 'Choose your action.');
    if (!r.succeeded) return one(_refusalText(r));
    final List<String> lines = <String>[];
    String? headline;
    for (final CombatBeat b in r.events) {
      // The outcome itself is the layer's; the log beneath it keeps the
      // round's blows and never narrates the ending twice.
      if (b is WonBeat || b is LostBeat || b is RetreatedBeat) continue;
      final String line = describeBeat(b, enemyName);
      lines.add(line);
      if (b is RoundEndedBeat && !b.telegraph) continue;
      headline = line;
    }
    if (lines.isEmpty) return one(intent ?? 'Choose your action.');
    return (lines: lines, headline: headline ?? lines.last);
  }

  @override
  Widget build(BuildContext context) {
    final (:List<String> lines, :String headline) = _content();
    final bool expandable = lines.length > 1 && !playing;
    final TextStyle style = StrideType.micro.copyWith(
      // Never `textMuted`: this is the fight's own narration and it sits on
      // a picture, which is the hardest ground the palette has.
      color: StrideColors.textPrimary,
    );
    final Widget text = open
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: StrideSpace.s2),
                  child: Text(line, style: style),
                ),
            ],
          )
        : Text(
            headline,
            style: style,
            maxLines: 1,
            // The one place in the product where a line may be shortened on
            // screen, and it is allowed here only because the full text is
            // one tap away — `AdaptiveText`'s rule is that no character may
            // be *lost*, and none is (D-01).
            overflow: TextOverflow.ellipsis,
          );

    return Semantics(
      button: expandable,
      label: expandable
          ? '$headline. Tap to read the whole round.'
          : headline,
      excludeSemantics: true,
      child: GestureDetector(
        // Null while the replay runs, so the stage's own tap-to-skip keeps
        // the whole picture, this strip included.
        onTap: expandable ? onToggle : null,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StrideColors.surfaceGround.withValues(alpha: 0.72),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StrideSpace.s8,
              vertical: 3,
            ),
            child: text,
          ),
        ),
      ),
    );
  }

  static String _refusalText(CombatReport r) => switch (r.rejection) {
    'session_busy' => 'Still finishing the last action',
    'session_not_ready' => 'Reload before fighting on',
    'commit_refused' => 'That could not be saved — reload before continuing',
    'no_encounter' => 'There is no fight to act in',
    'health_full' => 'Your health is already full',
    'not_edible' => 'That cannot be eaten',
    'item_not_owned' => 'You have none of that left',
    _ => r.detail ?? 'That action was refused',
  };
}

/// One beat as one line. Public within the file's library so the result panel
/// and the log agree on the wording; presentation only.
String describeBeat(CombatBeat b, String enemy) => switch (b) {
  EncounterStartedBeat() =>
    'The fight begins. ${b.enemyName} ${b.enemyHp} / ${b.enemyMaxHp}, '
        'you ${b.playerHp} / ${b.playerMaxHp}.',
  PlayerStruckBeat() =>
    '${switch (b.quality) {
      StrikeQuality.strong => 'A strong hit',
      StrikeQuality.weak => 'A glancing blow',
      StrikeQuality.even => 'You strike',
    }} for ${b.damage}. $enemy is at ${b.enemyHpAfter}.',
  ConsumableUsedBeat() =>
    'You eat ${b.itemName} and recover ${b.healed}. '
        'You are at ${b.playerHpAfter}.',
  BracedBeat() => 'You set your feet and brace behind your guard.',
  EnemyStruckBeat() =>
    '$enemy ${b.heavy ? 'lands a heavy blow' : switch (b.quality) {
                StrikeQuality.strong => 'hits hard',
                StrikeQuality.weak => 'grazes you',
                StrikeQuality.even => 'strikes',
              }} for ${b.damage}. '
        'You are at ${b.playerHpAfter}.',
  RoundEndedBeat() =>
    b.telegraph
        ? 'Turn ${b.turn}. The $enemy gathers itself…'
        : 'Turn ${b.turn}.',
  WonBeat() =>
    '$enemy falls. +${b.xp} XP'
        '${b.levelledUp ? ' — level ${b.levelAfter}!' : ''}'
        '${b.drops.isEmpty ? '' : ' Drops: ${dropsText(b.drops)}.'}',
  LostBeat() => 'You retreat to ${b.retreatToName}. Nothing was lost.',
  RetreatedBeat() => 'You retreat to ${b.retreatToName}. Nothing was lost.',
};

/// `Meadow Herb, Wolf Pelt ×2`.
///
/// Names and quantities only. Rarity now rides along on each [RewardLine] and
/// is deliberately *not* folded into this string — a colour is not a word, and
/// the victory panel that shows it is stream C's redesign.
String dropsText(List<RewardLine> drops) => drops
    .map(
      (RewardLine d) => d.quantity == 1 ? d.name : '${d.name} ×${d.quantity}',
    )
    .join(', ');

/// The command grid: Attack, Brace, Eat as 176 × 56 cells in a 2 × 2, one
/// micro intent line above them, and Retreat as a quiet link beneath. All
/// disabled while a command is in flight and while the stage replays the last
/// round ([locked]).
///
/// ## The budget this obeys
///
/// 12 + 13 (intent) + 8 + 56 + 8 + 56 + 8 + 44 (Retreat's 34 dp visual in its
/// 44 dp hit region) + 12 + 2 (the card's own border) = **219 dp** at scale
/// 1.0, against roughly 276 before. `ART-12_ux_brief.md` §6 says 210 because
/// it budgeted Retreat's visual rather than the hit region the accessibility
/// floor requires, and did not count the border; the structure it specifies
/// is implemented exactly. `combat_ui_test` holds the figure and writes the
/// sum out — it is the one number in this file a future addition must argue
/// with rather than quietly exceed.
///
/// ## The fourth cell is empty on purpose
///
/// The grid has four places and the fight has three actions: `combatAttack`,
/// `combatBrace`, `combatEat`, plus Retreat, which the brief puts *beneath*
/// the grid as a link rather than in it. There is no skip, wait or item
/// action in `SessionController`, so the bottom-right cell draws nothing. An
/// invented fourth action would be a design decision smuggled in as a layout
/// fix (`RULES.md` G-3), and a stretched Eat would say the grid is about
/// filling itself.
class _CombatControls extends StatefulWidget {
  const _CombatControls({
    required this.view,
    required this.controller,
    required this.locked,
  });

  final EncounterView view;
  final SessionController controller;

  /// True while a replay runs or the fight has ended: nothing may be tapped.
  final bool locked;

  @override
  State<_CombatControls> createState() => _CombatControlsState();
}

class _CombatControlsState extends State<_CombatControls> {
  /// Whether the Eat chooser is open. Presentational; nothing durable.
  bool _choosing = false;

  @override
  Widget build(BuildContext context) {
    final SessionController c = widget.controller;
    final EncounterView view = widget.view;
    final List<EdibleOption> edibles = c.session.edibles;
    // Busy is the command in flight; locked is the replay of the one that
    // returned. Either way the player waits, and neither reads as a refusal.
    final bool held = c.busy || widget.locked;
    final bool full = view.playerHp >= view.playerMaxHp;
    final String? eatReason = edibles.isEmpty
        ? 'Nothing to eat'
        : full
        ? 'Health is full'
        : null;

    // The armour is the subject of the sentence, deliberately.
    //
    // It states the design thesis inside the line — *this* is what your coat
    // is doing — rather than beside it, and it avoids putting a number in the
    // creature's voice one line under its authored tell. It also avoids the
    // word "guard", which in this game already means an enemy's `guarded`
    // behaviour and the `frostGuard` stat, neither of which is "the armour
    // you are wearing".
    //
    // It says "your armour" and never names the piece: `playerDefence` is
    // snapshotted at the first bell, so if the player swaps a coat mid-fight
    // the figure still describes the coat they *started* in. A generic noun
    // is the honest one; naming an item would state something false.
    String guardSentence(CombatGuardReading g) => g.heavy
        ? 'Your armour takes the heavy blow to ${g.takenLabel}.'
        : 'Your armour takes it to ${g.takenLabel}.';

    // The one micro line, and the whole of what used to be three rows of
    // sub-label (`ART-12` §6: "sub-labels collapse into one micro intent
    // line above the grid").
    //
    // What it says, in priority order:
    //
    // * **Held** — the round is playing out. It says so here, once, instead
    //   of four cells all relabelling themselves "Fighting…" and the grid
    //   losing the three words that tell the player what it does.
    // * **Brace is the suggested action** — the Brace sub-label's figure
    //   moves here verbatim ("Take 6 instead of 13", or the lethal warning).
    //   `worthwhile` is the engine's own judgement and is deliberately not
    //   re-derived; it already refuses to recommend a brace that costs more
    //   than it saves.
    // * **Otherwise, with a reading** — the armour sentence, unchanged, word
    //   for word, including its heavy variant.
    // * **Otherwise** — the creature's intent, which below Studied is the one
    //   short sentence ("It will strike twice.") this line was written for.
    //
    // The *prose* tell at Studied and above stays on the stage's narration
    // strip. Concatenating a 90-character tellLine onto the armour figures
    // would need a second line at scale 1.0 — over the §6 budget — or an
    // `AdaptiveText` shrunk past legibility, and the strip already carries it
    // one row above, unclipped.
    final CombatGuardReading? reading = view.guardReading;
    final String? intentLine = held
        ? 'Fighting…'
        : reading != null && reading.worthwhile
        ? reading.braceLabel
        : reading != null
        ? guardSentence(reading)
        : view.intentLine;

    // One cell: 56 dp tall, half the card wide — 163.5 dp at 393, which is
    // §6's 176 minus the card padding the brief's arithmetic did not
    // subtract. `StrideButton` renders at the cell's height because its own
    // box is a *minimum* (48), so there is no new control type, no edit to
    // `data_display.dart`, and the press, disable, variant and semantics
    // behaviour is the product's one button verbatim.
    Widget cell(Widget child) => SizedBox(height: _cellHeight, child: child);

    // The command ornament, drawn at ×2 behind the label and never stretched.
    //
    // `plate_attack/brace/eat.png` are **not** the nine-patches `ART-09` §5
    // commissioned — measured, each is a centred blob on a transparent 64 × 32
    // field whose corner blocks and edge strips are entirely empty, so a
    // nine-patch would tile the blob's arc across the cell and draw nothing in
    // the middle. `CombatHudAssets` carries the measurement. They are
    // integrated as ornaments instead, which is the third thing
    // `DECISIONS/0029` allows a raster to be, and the 56 dp cell clips 4 dp of
    // each plate's own transparent margin top and bottom and none of its drawn
    // pixels.
    Widget plate(String path) => OverflowBox(
      minWidth: _plateWidth,
      maxWidth: _plateWidth,
      minHeight: _plateHeight,
      maxHeight: _plateHeight,
      child: PixelAsset(
        assetPath: path,
        nativeWidth: CombatHudAssets.plateNativeWidth,
        nativeHeight: CombatHudAssets.plateNativeHeight,
      ),
    );

    // The 16 × 16 glyph at ×2, before the label. Decoration: the word still
    // says what the control does, and Retreat has no glyph at all.
    Widget glyph(String path) => PixelAsset(
      assetPath: path,
      nativeWidth: CombatHudAssets.iconNative,
      nativeHeight: CombatHudAssets.iconNative,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (intentLine case final String line) ...<Widget>[
          // A telegraph turn speaks in the danger rust (Fable V2 Iteration
          // 02) — the one hue combat threat owns — so the round to brace
          // against is unmissable without reading a word.
          //
          // `AdaptiveText`, not `Text`: this is the one line, so it shrinks
          // within its bounded range rather than taking a second row out of
          // the budget, and it never loses a character (D-01).
          AdaptiveText(
            line,
            style: StrideType.micro,
            color: view.telegraph && !held
                ? StrideColors.danger
                // Never `textMuted`: it fails WCAG AA on all four surfaces,
                // and this is the one number the game volunteers.
                : StrideColors.textSecondary,
          ),
          const SizedBox(height: StrideSpace.rhythmRow),
        ],
        // Row one: Attack, then Brace. Attack sits top-left — thumb-nearest
        // on the reach the brief measures from — and both cells are 176 × 56,
        // far above the 44 dp floor.
        Row(
          children: <Widget>[
            Expanded(
              child: cell(
                StrideButton(
                  label: 'Attack',
                  emblem: plate(CombatHudAssets.plateAttack),
                  leading: glyph(CombatHudAssets.iconAttack),
                  // Offense wears the danger accent inside the encounter —
                  // scope-amended on the token by the owner's brief
                  // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
                  variant: StrideButtonVariant.attack,
                  onPressed: held ? null : c.combatAttack,
                ),
              ),
            ),
            const SizedBox(width: StrideSpace.rhythmRow),
            // Brace (`DECISIONS/0027`, experimental — Q-06's candidate): deal
            // nothing, take the reply at half. Always offered; reading the
            // telegraph and spending the round well is the player's craft.
            //
            // Its figures — "Take 6 instead of 13", computed from the armour
            // actually worn — moved to the intent line above when bracing is
            // the suggested play. That is the same one-fact-said-once rule
            // that put the *taken* figure in the armour sentence and the
            // *braced* figure on the button: there is still exactly one
            // statement of each, and now there is one row of them instead of
            // three.
            Expanded(
              child: cell(
                StrideButton(
                  label: 'Brace',
                  emblem: plate(CombatHudAssets.plateBrace),
                  leading: glyph(CombatHudAssets.iconBrace),
                  // Defense at the opposite temperature — cool steel line and
                  // edge, so offense and defense read apart at a glance
                  // without a rainbow.
                  variant: StrideButtonVariant.defense,
                  onPressed: held ? null : c.combatBrace,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.rhythmRow),
        // Row two: Eat, and the empty fourth place. Eat keeps its reason —
        // "a disabled control must say why" is not a sub-label the intent
        // line may absorb, because it belongs to one control and not to the
        // round.
        Row(
          children: <Widget>[
            Expanded(
              child: cell(
                StrideButton(
                  label: _choosing ? 'Eat — choose' : 'Eat',
                  emblem: plate(CombatHudAssets.plateEat),
                  leading: glyph(CombatHudAssets.iconEat),
                  subLabel: held ? null : eatReason,
                  onPressed: held || eatReason != null
                      ? null
                      : () => setState(() => _choosing = !_choosing),
                ),
              ),
            ),
            const SizedBox(width: StrideSpace.rhythmRow),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        if (_choosing && eatReason == null) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              for (final EdibleOption e in edibles)
                StrideButton.secondary(
                  label: '${e.name} +${e.healing} (×${e.count})',
                  onPressed: held
                      ? null
                      : () {
                          setState(() => _choosing = false);
                          c.combatEat(e.itemId);
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: StrideSpace.rhythmRow),
        // Beneath the grid, quiet, and not a plate: leaving is not one of the
        // four things you do in a fight. No confirm step either — retreating
        // loses nothing, and the label says so, so a second tap would guard
        // against nothing.
        StrideButton.secondary(
          label: 'Retreat — nothing is lost',
          onPressed: held ? null : c.combatRetreat,
        ),
      ],
    );
  }
}

/// One command cell's height (`ART-12` §6). The width is whatever half the
/// card is — 176 dp at 393 — because a cell that fixed its width would be the
/// one thing on this screen that could not follow the phone.
const double _cellHeight = 56;

/// The command ornament's drawn size: `CombatHudAssets.plateNativeWidth` ×
/// `plateNativeHeight` (64 × 32) at ×2. Written out rather than computed so
/// they are `const` doubles the `OverflowBox` can take directly; the assets'
/// own figures are the constants beside them and a test holds the two equal.
const double _plateWidth = 128;
const double _plateHeight = 64;

/// Victory, defeat or retreat, once, with a Continue that acknowledges it.
///
/// ## The victory choreography (PLAYABLE_EXPERIENCE_REFINEMENT_01 §16–§18)
///
/// The stage has already played the enemy's fall and its settle before this
/// panel mounts (`combat_presentation_order_test`). From here the result
/// resolves top to bottom on one clock, fast, never unskippable:
///
/// `VICTORY` · *the enemy falls* → the **experience** → the **drops**, one
/// framed row each → the **knowledge** advance, if this victory crossed one
/// → the **level-up**, if one landed → bounty progress, if any → `Continue`.
///
/// ## The hierarchy (§17)
///
/// Not every reward at equal weight. An ordinary win is XP and materials on
/// the quiet ground; a knowledge stage (Seen → Studied, Studied → Known) is a
/// MEDIUM beat naming what is now understood; a rare drop's row carries its
/// rarity frame and nothing else is louder; a character level is the
/// universal [LevelUpCard]; bounty progress is one small line.
///
/// ## What it deliberately is not
///
/// No chest, no reveal, no "tap to open", no burst, no currency, nothing
/// stacked or sequenced to be opened (`RULES.md` P-6). The motion is one
/// staggered resolve of facts already committed, once.
class _ResultPanel {
  const _ResultPanel._(this.report);

  final CombatReport report;

  /// The beats the layer resolves for [outcome], top to bottom.
  static List<Widget> beatsOf(CombatReport report, CombatBeat outcome) {
    final _ResultPanel p = _ResultPanel._(report);
    return switch (outcome) {
      final WonBeat w => p._victory(w),
      final LostBeat l => p._drivenBack(l),
      final RetreatedBeat r => p._retreated(r),
      _ => <Widget>[
        Text(
          describeBeat(outcome, report.enemyName),
          style: StrideType.body,
          maxLines: 4,
        ),
      ],
    };
  }

  /// A win takes the **reward light** — the warm ink every payoff wears
  /// (Fable V2 Iteration 02, an L-16 repair: this used to be the step
  /// accent, and teal belongs to walking alone). Being driven back or
  /// retreating takes the plain frame, because losing nothing is not an
  /// event to celebrate and not one to punish.
  static Color? accentOf(CombatBeat outcome) =>
      outcome is WonBeat ? StrideColors.rewardLightInk : null;

  /// Whether this victory actually put a signature item in the player's
  /// hand — not merely that the enemy has one, which `signatureDrops`
  /// carries whether or not the roll landed this fight. Cross-referencing
  /// the round's own awarded [WonBeat.drops] against the names
  /// [WonBeat.signatureDrops] reveals is a read of two facts the report
  /// already states, never a third source of truth (`RULES.md` E-2). Only
  /// true once the enemy is Known — the same gate that lets the names be
  /// shown at all rather than `???` (`DECISIONS/0023` §5).
  static bool signatureAwarded(CombatBeat? outcome) =>
      outcome is WonBeat &&
      outcome.knowledgeAfter == KnowledgeTier.known &&
      outcome.drops.any(
        (RewardLine d) => outcome.signatureDrops.contains(d.name),
      );

  List<Widget> _victory(WonBeat o) => <Widget>[
    // The headline, with the fall beneath it — the card title weight a win
    // deserves.
    RewardBeat(
      tier: RewardTier.major,
      eyebrow: 'VICTORY',
      title: '${report.enemyName} falls',
      accent: StrideColors.rewardLightInk,
    ),
    // The experience, on its own ground: MINOR unless a level landed, which
    // the LevelUpCard below says.
    // No block of its own: the layer is the frame (finding E).
    RewardFacts(
      label: 'EXPERIENCE',
      children: <Widget>[
        AdaptiveText('+${o.xp} XP', style: StrideType.numericValue),
        if (o.knowledgeXp > 0)
          AdaptiveText(
            'including +${o.knowledgeXp} for knowing the ${o.enemyName}',
            style: StrideType.micro,
            color: StrideColors.textSecondary,
          ),
      ],
    ),
    // The drops. Each row carries its rarity's frame; a rare or better row
    // is therefore the loudest thing in the list without a second treatment.
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('REWARDS', style: StrideType.microLabel, maxLines: 1),
        const SizedBox(height: StrideSpace.s6),
        if (o.drops.isEmpty)
          // Quiet, and never an apology. Nothing was lost and nothing is
          // owed; the drop tables are chances, and a chance that did not land
          // is a fact rather than a failure (`RULES.md` P-5, P-7).
          const Text(
            'No drops this time.',
            style: StrideType.micro,
            maxLines: 2,
          )
        else
          for (int i = 0; i < o.drops.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: StrideSpace.s6),
            RewardItemRow(
              id: o.drops[i].id,
              name: o.drops[i].name,
              quantity: o.drops[i].quantity,
              rarity: o.drops[i].rarity,
            ),
          ],
      ],
    ),
    // The knowledge stage, when this victory crossed one (§18): Studied names
    // what is now understood and keeps the signature concealed; Known reveals
    // the signature.
    if (o.knowledgeAdvanced)
      RewardBeat(
        tier: RewardTier.medium,
        eyebrow: o.enemyName.toUpperCase(),
        title: switch (o.knowledgeAfter) {
          KnowledgeTier.known => 'KNOWN',
          KnowledgeTier.studied => 'STUDIED',
          _ => 'SEEN',
        },
        // Reward light, not teal (L-16 repair): understanding earned is a
        // payoff, not a walking quantity.
        accent: StrideColors.rewardLightInk,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (o.knowledgeAfter == KnowledgeTier.studied &&
                o.understoodDrops.isNotEmpty) ...<Widget>[
              const Text('NEWLY UNDERSTOOD', style: StrideType.microLabel),
              for (final String name in o.understoodDrops)
                AdaptiveText(
                  name,
                  style: StrideType.sub,
                  color: StrideColors.textPrimary,
                ),
            ],
            if (o.signatureDrops.isNotEmpty) ...<Widget>[
              if (o.knowledgeAfter == KnowledgeTier.studied)
                const SizedBox(height: StrideSpace.s4),
              const Text('SIGNATURE', style: StrideType.microLabel),
              for (final String name in o.signatureDrops)
                AdaptiveText(
                  o.knowledgeAfter == KnowledgeTier.known ? name : '???',
                  style: StrideType.sub,
                  color: o.knowledgeAfter == KnowledgeTier.known
                      ? StrideColors.textPrimary
                      : StrideColors.textMuted,
                ),
            ],
          ],
        ),
      ),
    // The character level: the universal beat (§29).
    if (o.levelledUp)
      LevelUpCard(
        name: 'Traveler',
        level: o.levelAfter,
        why: '+2 Max HP · harder fights are within reach',
      ),
    // Bounty progress: one small line each, never a card (§17).
    for (final BountyProgressLine b in o.bountyProgress)
      AdaptiveText(
        '${b.contractName} · ${b.progress} / ${b.required}',
        style: StrideType.micro,
        color: StrideColors.textSecondary,
      ),
  ];

  /// Retreat-not-death (§19): where the player now is, that nothing was
  /// lost, and — when the safe destination healed them — that too, without
  /// ever implying a death. Quieter heading than a win: losing nothing is
  /// not an event to celebrate, and not one to punish.
  List<Widget> _drivenBack(LostBeat l) => <Widget>[
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'DRIVEN BACK',
      title: 'Retreated to ${l.retreatToName}',
      lines: <String>[
        'Nothing was lost.',
        if (l.healed) 'Rested and recovered at ${l.retreatToName}.',
      ],
    ),
  ];

  List<Widget> _retreated(RetreatedBeat r) => <Widget>[
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'RETREATED',
      title: 'Retreated to ${r.retreatToName}',
      lines: const <String>['Nothing was lost.'],
    ),
  ];
}
