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

import '../../../audio/audio_controller.dart';
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
import '../../state/audio_scope.dart';
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

  /// The outcome whose sound has already been fired, by identity — the
  /// report's own beat object, so a rebuild cannot play a victory twice and
  /// a new fight's outcome is a different object.
  CombatBeat? _cuedOutcome;

  void _onPlayingChanged(bool playing) {
    if (playing == _playing) return;
    setState(() => _playing = playing);
  }

  /// The one sound the end of a fight makes, fired as the result panel is
  /// raised — beside the tier haptic `showRewardLayer` already fires, never
  /// instead of it.
  ///
  /// **One cue, not four.** All five reward ids share priority 30 and a
  /// 400 ms gap floor, so a victory that also levelled would voice the first
  /// and silently drop the rest (`AudioController.playEvent`); stacking them
  /// would only make the arbitration decide what the panel means. The
  /// precedence below is the panel's own reading, largest first: a character
  /// level is the biggest thing that can happen in a fight, then a signature
  /// item finally revealed, then a contract closing, then the win itself.
  ///
  /// Being driven back and retreating share `reward.retreat` by design — the
  /// queue's brief calls it "a *result*, not a punishment", and the two are
  /// the same result reached two ways.
  void _cueOutcome(CombatBeat outcome) {
    if (identical(outcome, _cuedOutcome)) return;
    _cuedOutcome = outcome;
    final AudioController? audio = AudioScope.maybeRead(context);
    if (audio == null) return;
    if (outcome is WonBeat) {
      if (outcome.levelledUp) {
        audio.playEvent('reward.levelup');
      } else if (_ResultPanel.signatureAwarded(outcome)) {
        audio.playEvent('reward.discovery');
      } else if (outcome.bountyProgress.any(
        (BountyProgressLine b) => b.progress >= b.required,
      )) {
        audio.playEvent('reward.milestone');
      } else {
        audio.playEvent('reward.victory');
      }
    } else if (outcome is LostBeat || outcome is RetreatedBeat) {
      audio.playEvent('reward.retreat');
    }
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
      // The panel stands alone (a relaunch holding an unacknowledged
      // result): it is raised on this build, so this is its raise.
      _cueOutcome(outcome);
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
    final bool signature = resolved && _ResultPanel.signatureAwarded(outcome);
    // `resolved` is exactly the condition `RewardRaise` raises on, and it
    // becomes true on the build after the stage stops playing — so the sound
    // and the panel answer the same frame. Identity-guarded inside, so the
    // rebuilds that follow are silent.
    // (`resolved` carries `outcome != null`, which flow analysis propagates.)
    if (resolved) _cueOutcome(outcome);
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
      // The battle page (`DIR-11`): one column sized to the viewport, in
      // which the fight is 55 % and the commands are 16 %. There is no card
      // on it anywhere — the fight has a chassis, the commands have a rail,
      // and the ground between them is leather.
      child: _BattlePage(
        key: ValueKey<int>(_fightArrival),
        view: view,
        controller: c,
        locked: _playing || ended,
        stage: CombatStage(
          view: view,
          report: report,
          ended: ended,
          onPlayingChanged: _onPlayingChanged,
          // The loadout's visual facts, snapshotted by the stage at its
          // first bell (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5).
          equipment: c.session.equipmentVisualState,
          // The round's narration, now on the chassis's own sill rather than
          // as a translucent strip over the picture's contact shadows
          // (`DIR-11`). The stage places it; this screen still decides every
          // word.
          narration: _CombatLog(
            report: report,
            enemyName: view.enemyName,
            intent: view.intentLine,
            playing: _playing,
            // The sill is one line tall by construction (40 dp), so it never
            // opens: the tap is answered on the leather page below, which is
            // the surface the whole round resolves on. Before the chassis the
            // strip grew in place, over the picture, which is why it could.
            open: false,
            onToggle: () => setState(() => _logOpen = !_logOpen),
          ),
        ),
        // The whole round, when the player has asked for it — on the page,
        // under the fight, in the room that used to be bare ground.
        roundLog: _logOpen
            ? _CombatLog(
                report: report,
                enemyName: view.enemyName,
                intent: view.intentLine,
                playing: _playing,
                open: true,
                onToggle: () => setState(() => _logOpen = !_logOpen),
              )
            : null,
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
      label: expandable ? '$headline. Tap to read the whole round.' : headline,
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

/// The battle page: the whole fight as one column sized to the viewport.
///
/// ## The ratio, and what bought it
///
/// The owner's verdict on this screen was "fight first, UI second — make the
/// battlefield visually dominant; buttons should not outweigh the fight." It
/// arrived at a 384 dp picture with two rod gauges under it, a 219 dp grey
/// card holding a 2 × 2 command block, and roughly 200 dp of bare dark ground
/// under that. A third of the screen was the fight; two thirds was chrome and
/// void.
///
/// The page is now, at 393 × 852 (727 dp of content under a 61 dp header and
/// a 64 dp tab bar, less the host list's 28 dp of padding):
///
/// | band | dp | what |
/// |---|---|---|
/// | chassis | 398 | frame · lintel 64 · picture 256 · sill 40 · frame |
/// | intent | 18 | the one line the round is about |
/// | page | flexible | leather, **no card** — the Eat chooser resolves here |
/// | rail | 120 | welt 12 · three 64 dp plates · Retreat's 44 dp hit |
///
/// **398 : 120 is 3.3 : 1** where it was about 1.2 : 1, and the rail's top
/// edge is 648 dp down an 852 dp screen with the tab bar directly beneath it —
/// no bare ground under the controls at all, because the page above them is
/// where the room went.
///
/// ## Why it is a fixed height rather than an `Expanded`
///
/// The host is a `ListView` (`adventure_screen.dart`, frozen), so the
/// incoming height is unbounded and `Expanded` would assert. The page
/// therefore measures the viewport itself from [StrideGeometry] and takes
/// that height, with a floor: on a phone too short to hold the layout the
/// column keeps its minimum and the host list scrolls, which is the ordinary
/// behaviour of everything else in that list.
class _BattlePage extends StatefulWidget {
  const _BattlePage({
    super.key,
    required this.stage,
    required this.view,
    required this.controller,
    required this.locked,
    this.roundLog,
  });

  final Widget stage;

  /// The whole round's lines, when the player has opened the narration. It
  /// resolves on the page rather than on the 40 dp sill, which holds exactly
  /// one line and is the reason the strip stopped growing over the picture.
  final Widget? roundLog;
  final EncounterView view;
  final SessionController controller;

  /// True while a replay runs or the fight has ended: nothing may be tapped.
  final bool locked;

  @override
  State<_BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<_BattlePage> {
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

    // The one line, unchanged in every word from the micro line that used to
    // sit inside the command card, and moved out onto the page between the
    // sill and the rail — where it belongs to the *fight* rather than to the
    // buttons. Priority order:
    //
    // * **Held** — the round is playing out. It says so here, once, instead
    //   of three plates all relabelling themselves "Fighting…".
    // * **Brace is the suggested action** — the Brace sub-label's figure
    //   verbatim ("Take 6 instead of 13", or the lethal warning).
    //   `worthwhile` is the engine's own judgement and is deliberately not
    //   re-derived.
    // * **Otherwise, with a reading** — the armour sentence, word for word.
    // * **Otherwise** — the creature's intent, which below Studied is the one
    //   short sentence ("It will strike twice.") this line was written for.
    //
    // The *prose* tell at Studied and above stays on the narration sill.
    final CombatGuardReading? reading = view.guardReading;
    final String? intentLine = held
        ? 'Fighting…'
        : reading != null && reading.worthwhile
        ? reading.braceLabel
        : reading != null
        ? guardSentence(reading)
        : view.intentLine;

    final double viewport =
        MediaQuery.sizeOf(context).height -
        StrideGeometry.headerMinHeight -
        StrideGeometry.tabBarHeight -
        _hostListPadding;
    final double floor =
        CombatStage.chassisHeight() + _intentHeight + _pageFloor + _railHeight;

    return SizedBox(
      height: viewport > floor ? viewport : floor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          widget.stage,
          SizedBox(
            height: _intentHeight,
            child: intentLine == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveText(
                      intentLine,
                      style: StrideType.micro,
                      // A telegraph turn speaks in the danger rust (Fable V2
                      // Iteration 02) — the one hue combat threat owns — so
                      // the round to brace against is unmissable without
                      // reading a word. Never `textMuted`: it fails WCAG AA
                      // on all four surfaces, and this is the one number the
                      // game volunteers.
                      color: view.telegraph && !held
                          ? StrideColors.danger
                          : StrideColors.textSecondary,
                    ),
                  ),
          ),
          // The page: leather, no card, no border, no radius. What resolves
          // on it is what the round asks for and nothing else — today that is
          // the Eat chooser. Empty ground between a fight and its commands is
          // not a hole to fill; it is the room that stops the two touching,
          // and it is made of something.
          Expanded(
            child: PageGround(
              surface: PanelSurface.leather,
              fill: StrideColors.surfaceGround,
              child: widget.roundLog != null && !_choosing
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        StrideSpace.s8,
                        StrideSpace.s10,
                        StrideSpace.s8,
                        StrideSpace.s8,
                      ),
                      child: widget.roundLog!,
                    )
                  : _choosing && eatReason == null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        StrideSpace.s8,
                        StrideSpace.s10,
                        StrideSpace.s8,
                        StrideSpace.s8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text('EAT WHAT?', style: StrideType.microLabel),
                          const SizedBox(height: StrideSpace.s6),
                          Wrap(
                            spacing: StrideSpace.s6,
                            runSpacing: StrideSpace.s6,
                            children: <Widget>[
                              for (final EdibleOption e in edibles)
                                StrideButton.secondary(
                                  label:
                                      '${e.name} +${e.healing} (×${e.count})',
                                  onPressed: held
                                      ? null
                                      : () {
                                          AudioScope.maybeRead(
                                            context,
                                          )?.hapticLight();
                                          setState(() => _choosing = false);
                                          c.combatEat(e.itemId);
                                        },
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
          // The fight's entrance (Fable V2 Iteration 02) survives the
          // rebuild, one element lighter: the stage resolves with the frame
          // and the rail follows a beat later. The first child is the beat
          // the stage used to occupy — the stage is above the `Expanded` now
          // and cannot be inside the same reveal, so its slot is spent here
          // as nothing. Reduce Motion renders both at full value, and a
          // mid-fight rebuild keeps the element, so nothing re-plays.
          StaggeredReveal(
            gap: 0,
            children: <Widget>[
              const SizedBox.shrink(),
              _CommandRail(
                held: held,
                eatReason: eatReason,
                choosing: _choosing,
                onAttack: () {
                  AudioScope.maybeRead(context)?.hapticLight();
                  c.combatAttack();
                },
                onBrace: c.combatBrace,
                onEat: () => setState(() => _choosing = !_choosing),
                onRetreat: () {
                  AudioScope.maybeRead(context)?.hapticLight();
                  c.combatRetreat();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The host list's own vertical padding (`adventure_screen.dart`, frozen):
/// `StrideSpace.s12` above the first child and `s16` below the last.
const double _hostListPadding = StrideSpace.s12 + StrideSpace.s16;

/// The intent line's band on the page, under the sill.
const double _intentHeight = 18;

/// The least leather the page may show before the host list starts scrolling
/// instead. Enough to hold the Eat chooser's first row.
const double _pageFloor = 96;

/// The command rail: welt 12 · plates 64 · Retreat's 44 dp hit region.
const double _railHeight = 12 + _plateHeight + _retreatHit;

/// One command plate. Three of them, 64 dp tall, side by side.
const double _plateHeight = 64;

/// Retreat's hit region. 44 is the accessibility floor and is not negotiable;
/// the *visual* inside it is one micro line, which is the whole point.
const double _retreatHit = 44;

/// A held plate's opacity — a round playing out, or a command in flight.
const double _heldPlate = 0.40;

/// A plate that cannot run for a reason of its own (nothing edible, health
/// full). Lighter than held, because "not now" and "not here, ever" are
/// different states and the player learns them apart (`DIR-11`).
const double _refusedPlate = 0.55;

/// The commands: three plates on a leather rail pinned above the tab bar, and
/// Retreat as a micro link beneath them.
///
/// ## What changed, and why it is not `StrideButton`
///
/// The three commands used to be `StrideButton`s in a 2 × 2 grid — the
/// product's general-purpose control, with an authored plate laid behind the
/// label as a **centred ornament**, because `plate_attack/brace/eat.png` are
/// blobs on a transparent field whose corner blocks and edge runs are empty,
/// from which no nine-patch can be cut. Three ornaments in three perspectives
/// (cushion, diamond, bowl), one with a checker ground baked in, sat behind
/// three labels in a grey card. That is Q-22, and this closes it: the plate is
/// `KitFrame.btnPlateV2`, a **real nine-patch** measured at 8 / 5 on a 56 × 24
/// canvas, cut in at its own band and tinted by the command's own ink. It is a
/// whole plate at any size, it has one light direction because it has one
/// authored corner, and there is no edge inside the cell.
///
/// A local widget rather than `StrideButton` because `StrideButton` is
/// NAV-owned, has 43 call sites, and its box is a 48 dp minimum around a
/// horizontal label — none of which is a 64 dp stacked command plate.
/// Everything a button owes the player is here: a target well over the 44 dp
/// floor, a semantics label carrying the reason a disabled control gives, and
/// a disabled state that recedes rather than disappears.
class _CommandRail extends StatelessWidget {
  const _CommandRail({
    required this.held,
    required this.eatReason,
    required this.choosing,
    required this.onAttack,
    required this.onBrace,
    required this.onEat,
    required this.onRetreat,
  });

  final bool held;

  /// Why Eat cannot run, or null. A disabled control must say why, and this
  /// is the one sub-label the intent line may not absorb: it belongs to one
  /// control and not to the round.
  final String? eatReason;
  final bool choosing;
  final VoidCallback onAttack;
  final VoidCallback onBrace;
  final VoidCallback onEat;
  final VoidCallback onRetreat;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _railHeight,
    child: PageGround(
      surface: PanelSurface.leather,
      fill: StrideColors.surfaceBlock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The same stitched welt the nav strap and the header shelf wear
          // (KIT_CONTRACT §2, `nav_welt_v2`) — one chassis, one stitch. It is
          // what makes the rail read as part of the phone's furniture rather
          // than as a fourth panel.
          const KitEdge(
            tile: KitTile.navWelt,
            fallbackColor: StrideColors.separator,
          ),
          SizedBox(
            height: _plateHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _CommandPlate(
                      label: 'Attack',
                      glyph: CombatHudAssets.iconAttack,
                      // Offense wears the danger accent inside the encounter —
                      // scope-amended on the token by the owner's brief
                      // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4). The dim
                      // register, because this is a *face* under type and not
                      // an accent line.
                      ink: StrideColors.dangerDim,
                      onTap: held ? null : onAttack,
                      held: held,
                    ),
                  ),
                  const SizedBox(width: StrideSpace.s8),
                  // Brace (`DECISIONS/0027`, experimental — Q-06's candidate):
                  // deal nothing, take the reply at half. Always offered;
                  // reading the telegraph and spending the round well is the
                  // player's craft. Its figures — "Take 6 instead of 13" — are
                  // on the intent line above when bracing is the suggested
                  // play, which is the same one-fact-said-once rule that put
                  // the *taken* figure in the armour sentence.
                  Expanded(
                    child: _CommandPlate(
                      label: 'Brace',
                      glyph: CombatHudAssets.iconBrace,
                      // Defense at the opposite temperature — cool steel, so
                      // offense and defense read apart at a glance without a
                      // rainbow.
                      ink: StrideColors.defenseSheen,
                      onTap: held ? null : onBrace,
                      held: held,
                    ),
                  ),
                  const SizedBox(width: StrideSpace.s8),
                  Expanded(
                    child: _CommandPlate(
                      label: choosing ? 'Choose' : 'Eat',
                      glyph: CombatHudAssets.iconEat,
                      ink: StrideColors.surfaceRaised,
                      reason: held ? null : eatReason,
                      onTap: held || eatReason != null ? null : onEat,
                      held: held,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Beneath the plates, quiet, and **never a plate**: leaving is not
          // one of the three things you do in a fight. No confirm step either
          // — retreating loses nothing, and the label says so, so a second tap
          // would guard against nothing.
          Expanded(child: _RetreatLink(onTap: held ? null : onRetreat)),
        ],
      ),
    ),
  );
}

/// One command: a nine-patch plate, a 32 dp glyph, a micro label.
class _CommandPlate extends StatelessWidget {
  const _CommandPlate({
    required this.label,
    required this.glyph,
    required this.ink,
    required this.onTap,
    required this.held,
    this.reason,
  });

  final String label;
  final String glyph;

  /// The plate's face. The nine-patch supplies the construction — rim, ledge,
  /// light — and Flutter supplies the temperature, so three commands read
  /// apart without three rasters.
  final Color ink;
  final VoidCallback? onTap;
  final bool held;

  /// Why this command cannot run. Shown in place of the glyph: the words that
  /// say why outrank the icon, and 32 dp of glyph over two lines of type does
  /// not fit a 64 dp plate.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    // The plate stays, dimmed (FMPO02 wave 3, FINAL-01 #1). It used to vanish
    // when disabled, and the result was cells that changed shape twice a
    // round: flat on turn 1, plated on turn 2, for the same three commands. A
    // cell whose identity depends on whether it is your turn cannot be
    // learned.
    final double opacity = enabled
        ? 1
        : held
        ? _heldPlate
        : _refusedPlate;
    return Semantics(
      button: true,
      enabled: enabled,
      label: reason == null ? label : '$label. $reason',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: opacity,
          child: KitPlate(
            frame: KitFrame.btnPlateV2,
            fill: ink,
            raised: enabled,
            // Stated, because `KitPlate` shrink-wraps its child when it is
            // not: the 32 dp glyph row inside a 10 dp band made a 52 dp plate
            // floating in a 64 dp slot, and three plates that are not the
            // height of the row they sit in is the "floating ornament"
            // failure `DIR-11` is here to end.
            height: _plateHeight,
            // Zero, not a figure of its own: `KitPlate` already insets by the
            // nine-patch's own band (10 dp at `btnPlateV2`'s 5 × 2), and a
            // second padding on top of it is subtracted from the same 64 dp.
            // The interior is 44, and what goes in it is sized to 44.
            padding: EdgeInsets.zero,
            // The glyph beside the word rather than over it. Stacked, a 32 dp
            // icon and a 13 dp label are 45 dp of content in a 44 dp
            // interior — one dp over, which is a plate that overflows on
            // every phone rather than an arrangement that nearly works. Side
            // by side they are 32 dp tall in 44 and about 72 dp wide in 89,
            // and the label keeps [AdaptiveText]'s room to shrink under
            // Dynamic Type instead of pushing the icon out of the plate.
            child: reason == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PixelAsset(
                        assetPath: glyph,
                        nativeWidth: CombatHudAssets.iconNative,
                        nativeHeight: CombatHudAssets.iconNative,
                      ),
                      const SizedBox(width: StrideSpace.s4),
                      Flexible(
                        child: AdaptiveText(
                          label,
                          style: StrideType.microLabel,
                          color: StrideColors.textPrimary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AdaptiveText(
                        label,
                        style: StrideType.microLabel,
                        color: StrideColors.textPrimary,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: StrideSpace.s2),
                      AdaptiveText(
                        reason!,
                        style: StrideType.micro,
                        color: StrideColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Retreat: a micro link, right-aligned, in a full-width 44 dp hit region.
///
/// It was the **widest control on the screen** — a full-bleed secondary button
/// reading "Retreat — nothing is lost", heavier than any command it sat under.
/// The words are unchanged and the hit region is unchanged; what went is the
/// plate, because the plates are what the fight is fought with and this is the
/// way out of it.
class _RetreatLink extends StatelessWidget {
  const _RetreatLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: 'Retreat — nothing is lost',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _retreatHit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s10),
          child: Align(
            alignment: Alignment.centerRight,
            child: Opacity(
              opacity: onTap == null ? _heldPlate : 1,
              child: const Text(
                'Retreat — nothing is lost',
                style: StrideType.micro,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

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
