/// The gameplay screen: what walking has bought, what one action costs, and the
/// action itself.
///
/// ## What this screen deliberately does not show
///
/// The approved Round 03 render carries a `PROGRESS TO NEXT GATHER · 54 / 90`
/// bar, a `Stop` button, a `Change activity` button, and a `RECENT GAINS` row.
/// **Every one of those depicts a system `stride_core` does not have**: there is
/// no persistent selected activity, no partial gather progress, and no retained
/// gains view. `GatherResource` is a discrete command.
///
/// So this screen shows the cost, the available balance, and whether the action
/// can execute — and nothing that would imply progress accruing while the player
/// is away. A screen missing a card is honest; a fabricated progress bar is a lie
/// the player can see, and it is the exact Round 02 defect where four of five
/// bars contradicted their captions.
///
/// The render's hero figure, `3,240 walked today`, is also absent. `TimeBucket`
/// is a UTC hour-granularity span, so "today" would require choosing a local-day
/// boundary and folding the granted-slice map — a timezone policy and a game rule
/// invented in a widget (`RULES.md` E-2). `TOTAL WALKED` is the honest
/// substitute and is the same class of fact.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition;
import 'package:stride_health/stride_health.dart'
    show HealthAuthorization, SyncFault;

import '../../../audio/audio_controller.dart';
import '../../../runtime/stride_session.dart';
import '../../components/activity_result.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/panel_skin.dart';
import '../../components/reward_beat.dart' show StaggeredReveal;
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
import '../../state/activity_controller.dart';
import '../../state/audio_scope.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../shell/shell_tabs.dart';
import '../../shell/stride_destination.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../combat/combat_screen.dart';
import '../system/stale_banner.dart';
import 'activity_panel.dart';
import 'encounter_card.dart';
import 'goal_board_screen.dart';
import 'goal_summary_card.dart';
import 'location_stage.dart';

class AdventureScreen extends StatefulWidget {
  const AdventureScreen({super.key});

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  /// The selected activity — ephemeral UI selection, never a game figure
  /// (`RULES.md` E-2). Null is the idle stage: ambient Traveler, no node
  /// scenery, nothing running. A running queue overrides it (the stage always
  /// shows the work actually happening).
  ContentId? _selected;

  /// The expanded encounter — the same ephemeral kind of selection, kept
  /// separate because the two lists answer different questions and a player
  /// reading an enemy's drops has not stopped considering a gather.
  ContentId? _selectedEnemy;

  /// The completed gather whose sound has already played, by the same token
  /// the card itself is keyed to.
  Object? _cuedGather;

  /// The sound a completed gather makes, fired as its result card arrives —
  /// beside the card's own light haptic, never instead of it.
  ///
  /// One id covers every profession here (`gather.complete.01`, "something
  /// dropped into a pack"): the *working* sound is already per-profession
  /// through `playSkillCue`, so a second per-profession family at the
  /// boundary would say the same thing twice. Silent-safe — no [AudioScope]
  /// above this screen is silence, and the id is unproduced today, which is
  /// silence too.
  void _cueGather(Object token) {
    if (token == _cuedGather) return;
    _cuedGather = token;
    AudioScope.maybeRead(context)?.playEvent('gather.complete');
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final ActivityController activity = ActivityScope.of(context);
    final StrideSession s = c.session;
    final List<ResourceNodeDefinition> nodes = s.nodesHere;

    // Null before the game starts, which this screen is never built for — the
    // bootstrap resolves before the first frame. Handled rather than asserted:
    // an absent vignette is already a supported state.
    final ContentId? here = s.currentLocation;
    final String? vignette = here == null ? null : PixelIcons.vignetteFor(here);

    // THE FIGHT — in place of the stage, the walking band and the cards.
    //
    // While an encounter is active the tab *is* the encounter (`DECISIONS/0020`
    // §Consequences): a cold relaunch mid-fight lands here from state alone,
    // with no navigation to persist. The stage also stays up while the last
    // round's outcome — a win, a loss, a retreat — has not been acknowledged,
    // because the engine clears the encounter on the same commit that decides
    // it, and the result would otherwise vanish before it was read. The stale
    // banner is kept: a refused commit mid-fight is exactly when it matters.
    // `combatBusy` covers the killing blow's mid-commit frame, where the
    // encounter is already cleared in memory and the report has not yet
    // returned — both other conditions are null for that one frame, and
    // without the flag the whole stage unmounted, flashed the location cards,
    // and skipped the victory replay.
    if (s.encounter != null || c.lastCombat?.outcome != null || c.combatBusy) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          StrideSpace.screenGutter,
          StrideSpace.s12,
          StrideSpace.screenGutter,
          StrideSpace.s16,
        ),
        children: <Widget>[
          if (s.isStale) ...<Widget>[
            StaleBanner(busy: c.busy, onReload: c.reload),
            const SizedBox(height: StrideSpace.cardGap),
          ],
          const CombatScreen(),
        ],
      );
    }

    final List<EncounterOption> encounters = s.encountersHere;

    // The stage follows the work: a running queue's node wins over the tap
    // selection, so the diorama never idles while the save is gathering.
    final ContentId? active = activity.active ? activity.activeNode : null;
    final ContentId? stagedId = active ?? _selected;
    final ResourceNodeDefinition? staged = stagedId == null
        ? null
        : nodes
              .where((ResourceNodeDefinition n) => n.id == stagedId)
              .firstOrNull;

    // The selection's gate, projected once from the same rules the engine
    // enforces, so the stage and the disabled control never disagree (§8).
    final GatherEligibility? gate = staged == null
        ? null
        : s.gatherEligibilityOf(staged.id);
    final bool locked = gate != null && !gate.eligible;
    final String? lockReason = staged == null || gate == null || !locked
        ? null
        : !gate.skillMet
        ? 'Requires ${s.displayNameOf(staged.skill)} ${gate.requiredLevel}'
        : 'Needs a ${staged.requiredToolKind.name}';

    // The identity of a *successful* gather at the staged node, and nothing
    // else — the one-shot plays on the shared stage now. Suppressed while a
    // queue runs: the working loop already has the stage.
    final ActionReport? report = staged != null && c.lastActionNode == staged.id
        ? c.lastAction
        : null;
    final Object? playToken =
        active == null && report != null && report.succeeded ? report : null;

    // The universal activity result (GFCP01 device correction): every
    // completed gather answers on this surface — a floating card at the
    // screen's foot, not a line inside whichever node card is expanded.
    // Two sources: a finished queue's summary (a **running** watched
    // queue's live feedback is the working panel's own counter and gains,
    // right under the bar — a card too would say everything twice; a
    // level-up instead takes the held reward layer, which composes the
    // same facts larger), and a single gather's report (incremental, so
    // rapid taps merge into one card).
    ActivityResult? activityResult;
    Object? activityToken;
    if (activity.summaryNode != null &&
        activity.completed > 0 &&
        !activity.levelledUp) {
      activityResult = ActivityResult(
        verb: 'GATHERING COMPLETE',
        itemId: activity.gainedItemId,
        itemName: activity.gainedItemName ?? 'Items',
        // The controller's accumulated totals already include what
        // reconciled while away — one figure, the committed one.
        quantity: activity.gainedQuantity,
        skill: activity.skill,
        skillName: activity.gainedSkillName,
        xp: activity.gainedXp,
      );
      activityToken =
          'qdone:${activity.summaryNode?.value}:${activity.completed}';
    } else if (c.lastAction case final ActionReport gathered
        when gathered.succeeded && !gathered.levelledUp) {
      // Deliberately NOT the staged-gated `report` above: the card answers
      // the completion wherever it happened, selected row or not — "did
      // anything happen?" must never depend on what is expanded.
      final ContentId? node = c.lastActionNode;
      final ContentId? skill = node == null
          ? null
          : s.nodeDefinitionOf(node)?.skill;
      activityResult = ActivityResult(
        verb: activityVerbFor(skill?.value),
        itemId: gathered.itemId,
        itemName: gathered.itemName ?? 'Items',
        quantity: gathered.quantity ?? 0,
        bonusQuantity: gathered.bonusYield,
        skill: skill,
        skillName: gathered.skillName,
        xp: gathered.experience ?? 0,
        // The gather path's rarity, at last (PRESENTATION_COMBAT_EVOLUTION_01).
        // `ActivityResult.notable` reads this, so an Uncommon-or-better find
        // now takes the accented 2 px frame, the reward glow and the longer
        // hold — the same escalation a craft has had since GFCP01. Before
        // this, pulling Rare Gloom Silk looked exactly like pulling Copper
        // Ore, which made the game's best gathering moment its quietest.
        rarity: gathered.rarity,
        incremental: true,
      );
      activityToken = gathered;
    }

    // The card's arrival is the gather's completion, so it is where the
    // completion sounds. Identity-guarded, so the rebuilds that follow — and
    // the merges a rapid tapper produces under one token — stay quiet.
    if (activityToken != null) _cueGather(activityToken);

    return ActivityResultHost(
      result: activityResult,
      resultToken: activityToken,
      // THE PAGE (`DIR-05`, Adventure row: "it is a book"). The tab is one
      // leaf of a field journal, full bleed, and everything below the picture
      // is written on it. There is no card on this screen any more: what were
      // four dark rectangles down the page — the walking band, the kit, the
      // encounters, the goals — are now a picture tipped into the page, a
      // ruled line, a ledger, and a cork board pinned to the leaf.
      child: PageGround(
        surface: PanelSurface.journalLeaf,
        child: ListView(
          // Zero horizontal padding: the stage is full-bleed, and the spread
          // below it applies the spine and the gutter itself.
          padding: const EdgeInsets.only(bottom: StrideSpace.s16),
          children: <Widget>[
            // WHERE I AM, ALIVE — one stage for the whole location
            // (PRESENTATION_WORLD_REWARD_FEEL_01 §4–§5): the arrival painting,
            // the Traveler and companions, the selected activity's node as far
            // scenery, and the profession loop while a queue runs. The
            // Traveler lives here and nowhere else on this screen. Full bleed,
            // above the page's binding: a plate tipped into the journal, which
            // is why the spine below starts under it and not beside it.
            LocationStage(
              locationName: s.locationName,
              vignette: vignette,
              selectedNode: staged,
              // The man on the stage wears what Inventory says he wears
              // (FMPO02): the same read-time projection Combat and Inventory
              // draw from, so three screens cannot disagree about his coat.
              equipment: s.equipmentVisualState,
              activityActive: active != null && staged != null,
              playToken: playToken,
              locked: locked,
              lockReason: lockReason,
              // The action beats (AUDIO_PRESENTATION_01): the profession's one
              // accepted cue, fired by the stage when the work is visibly
              // happening — the loop's strike frame, or the one-shot
              // beginning. `read`, not `of`: a beat must not subscribe this
              // screen.
              //
              // The watched single gather also lands one light tap under the
              // finger. The queue loop's beat (`onActivityBeat`) deliberately
              // does not: a haptic per loop strike is exactly the "loop beat"
              // the seam's contract forbids.
              onActivityBeat: staged == null
                  ? null
                  : () => AudioScope.read(
                      context,
                    ).playSkillCue(staged.skill.value),
              onGatherCue: staged == null
                  ? null
                  : () {
                      final AudioController audio = AudioScope.read(context);
                      audio.playSkillCue(staged.skill.value);
                      audio.hapticLight();
                    },
            ),

            // THE SPREAD — everything written on the leaf, bound at the left.
            _Spread(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // WHAT WALKING HAS BOUGHT — the ledger's first line, ruled.
                  _WalkingLedger(controller: c),
                  // The picture and the line under it are one hero block; 24
                  // is what separates a hero from the first group beneath it
                  // (`ART-12` §0).
                  const SizedBox(height: StrideSpace.rhythmHero),

                  if (s.isStale) ...<Widget>[
                    StaleBanner(busy: c.busy, onReload: c.reload),
                    const SizedBox(height: StrideSpace.rhythmGroup),
                  ],

                  // WHAT MY WALKING JUST MADE POSSIBLE — after a granting
                  // sync, held until dismissed (`DECISIONS/0023` §1). Above
                  // everything else because it is the moment the sync exists
                  // for.
                  if (c.lastOpportunities.isNotEmpty) ...<Widget>[
                    _OpportunityBanner(controller: c),
                    const SizedBox(height: StrideSpace.rhythmGroup),
                  ],

                  // WHAT I CAN DO HERE — the expedition kit, as ledger
                  // entries; only the selected activity expands (§6).
                  ActivityPanel(
                    nodes: nodes,
                    selected: stagedId,
                    onSelect: (ContentId? id) => setState(() => _selected = id),
                  ),
                  const SizedBox(height: StrideSpace.rhythmGroup),

                  // WHAT I CAN FIGHT HERE — compact rows, only the selected
                  // creature expanded (§15). Absent where the content has no
                  // enemy (Haven's Rest), rather than an empty-state card: a
                  // safe place does not need to announce it.
                  if (encounters.isNotEmpty) ...<Widget>[
                    EncounterPanel(
                      options: encounters,
                      selected: _selectedEnemy,
                      onSelect: (ContentId? id) =>
                          setState(() => _selectedEnemy = id),
                    ),
                    const SizedBox(height: StrideSpace.rhythmGroup),
                  ],

                  // WHAT I AM WORKING TOWARDS — the slips pinned to the cork;
                  // the full tracker and the board live on the Goal Board
                  // (§8–§9).
                  const GoalSummaryCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The journal spread: the page's binding down the left, and everything
/// written to the right of it.
///
/// The spine is the kit's `edgeSpine` tile run vertically at the page's left
/// edge (`KIT_CONTRACT` §2 — landed, 32 dp wide), and it is what makes the
/// screen read as one bound object rather than as a stack of blocks. It is
/// drawn as a `Stack` overlay rather than as a `Row` child on purpose: a
/// stretched `Row` needs a bounded height, and this spread lives inside a
/// `ListView` where the height is exactly what is not known.
///
/// The content's left inset is the spine plus 8 — a book's inner margin — and
/// its right inset is the ordinary screen gutter. The binding therefore
/// **replaces** the left gutter rather than being added to it, which is why
/// the page loses no reading width to being bound.
class _Spread extends StatelessWidget {
  const _Spread({required this.child});

  final Widget child;

  /// The declared spine width, whether or not the raster has landed — the
  /// registry returns the same figure either way, so the page does not reflow
  /// on the day the tile ships (`KIT_CONTRACT` §0).
  static double get spine => KitTiles.thicknessFor(KitTile.edgeSpine);

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(
          spine + StrideSpace.s8,
          StrideSpace.s10,
          StrideSpace.screenGutter,
          0,
        ),
        child: child,
      ),
      // The binding. The width is declared, never inferred: a vertical strip
      // fills the height it is given and asks for its own thickness, and a
      // Positioned with three edges and no width hands it an infinite one.
      //
      // **This should be `KitEdge(tile: KitTile.edgeSpine)` and will be.**
      // `EdgeStrip` does not yet take the axis its `KitStrip` declares, so the
      // landed `edge_spine` raster tiles *across* the 32 dp width and paints a
      // single row at the page's head instead of running down it — a visible
      // artifact on the device render, not a binding. The request is filed
      // (`REQUESTS_NAV.md`, 2026-09-03) and seconded; until it lands the
      // binding is drawn in the kit's own fallback register — the declared
      // width, the page's darker ground, one `borderDefault` rule at its inner
      // edge — so the swap back is one widget and reflows nothing.
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: spine,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: StrideColors.surfaceGround,
            border: Border(
              right: BorderSide(color: StrideColors.borderDefault),
            ),
          ),
        ),
      ),
    ],
  );
}

// The step-sync motivation moment: what was banked, and the few true
/// sentences about what it makes possible (brief §5). Dismissed by the
/// player, displaced by the next command — never swept away by a timer.
///
/// Iteration 02 makes the moment feel like one: the card wears the warm
/// reward wash, the beats resolve top-to-bottom once, the banked figure
/// counts up to its committed value, and each opportunity row is the door
/// to the thing it names — a journey line fronts the World tab, a pursuit
/// or contract line opens the Goal Board. The figures themselves are
/// untouched: the count-up ends at the committed number and the reduced-
/// motion branch renders it directly.
class _OpportunityBanner extends StatelessWidget {
  const _OpportunityBanner({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    // The banner's own copy — `lastSync` is cleared by the result timer
    // while this banner waits for a tap, and reading it here is what put
    // "+0 STEPS BANKED" on the owner's device.
    final int banked = controller.lastOpportunityBanked;
    final List<SyncOpportunity> opportunities = controller.lastOpportunities;
    // No card, and no wash behind one: on a journal page the moment is a
    // **notice written into the page**, crowned by the ornate rule and closed
    // by the plain one. The reward wash was a dark rectangle whose warmth only
    // read because everything around it was a dark rectangle too; on the leaf,
    // a flourish and a rule say "this is the entry that matters today" without
    // putting a box back on the screen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Center(child: KitOrnament(mark: KitMark.ruleOrnateA)),
        const SizedBox(height: StrideSpace.s6),
        StaggeredReveal(
          // Keyed by the list identity so the next granting sync replays the
          // reveal; rebuilds while this banner waits do not.
          key: ObjectKey(opportunities),
          gap: StrideSpace.s6,
          children: <Widget>[
            Row(
              children: <Widget>[
                const WalkingGlyph(role: WalkingRole.stock),
                const SizedBox(width: StrideSpace.iconLabelGap),
                Expanded(child: _BankedCountUp(banked: banked)),
              ],
            ),
            for (final SyncOpportunity o in opportunities)
              _OpportunityRow(opportunity: o),
            // Acknowledgement, at the width of the word. Full-bleed it read
            // as the screen's primary action, which on a page with a gather
            // control below it is exactly backwards.
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 96,
                child: StrideButton.secondary(
                  label: 'OK',
                  onPressed: controller.acknowledgeOpportunities,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.s8),
        const KitEdge(
          tile: KitTile.ruleJournal,
          fallbackColor: StrideColors.separator,
        ),
      ],
    );
  }
}

// The banked headline, counting up to the committed figure.
///
/// Presentation only: the tween ends at the exact committed value, restarts
/// only when that value changes, and the reduced-motion branch prints the
/// figure with no intermediate frames. `RepaintBoundary` + tabular figures
/// keep the per-frame repaint to this one line (Iteration 02, PERF-A).
class _BankedCountUp extends StatelessWidget {
  const _BankedCountUp({required this.banked});

  final int banked;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final TextStyle style = StrideType.sectionHeading.copyWith(
      color: StrideColors.accentSteps,
      fontFeatures: StrideType.tabularFigures,
    );
    if (reduced) {
      return Text('+${formatSteps(banked)} STEPS BANKED', style: style);
    }
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<int>(banked),
        tween: Tween<double>(begin: 0, end: banked.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) =>
            Text('+${formatSteps(value.round())} STEPS BANKED', style: style),
      ),
    );
  }
}

/// One opportunity, as the door to the thing it announces.
class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({required this.opportunity});

  final SyncOpportunity opportunity;

  @override
  Widget build(BuildContext context) {
    // A journey is answered on the World tab; a pursuit or contract on the
    // Goal Board. Outside the shell (component tests) there is no tab bar
    // to front, so the journey row degrades to plain text.
    final ShellTabs? tabs = ShellTabs.maybeOf(context);
    final VoidCallback? go = switch (opportunity.kind) {
      SyncOpportunityKind.journeyReady =>
        tabs == null ? null : () => tabs.select(StrideDestination.world),
      SyncOpportunityKind.pursuit ||
      SyncOpportunityKind.contract => () => GoalBoardScreen.open(context),
    };
    final Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(opportunity.headline, style: StrideType.itemName),
              Text(opportunity.detail, style: StrideType.micro),
            ],
          ),
        ),
        if (go != null) ...<Widget>[
          const SizedBox(width: StrideSpace.s6),
          Text(
            '›',
            style: StrideType.sub.copyWith(color: StrideColors.textMuted),
          ),
        ],
      ],
    );
    if (go == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: go,
      child: body,
    );
  }
}

//// WHAT WALKING HAS BOUGHT — the page's first ruled line.
///
/// ## What this replaced, and why the mass came out
///
/// This was a full `SectionCard`: a section heading, two 22 px value tiles in
/// filled blocks, the affordance sentence, and a full-width filled `Sync steps`
/// button — roughly 215 dp, second only to the gather card, sitting between the
/// player and the only action on the screen. FMPO02 took the card away and left
/// a band; EPO03 puts the band **on the page**, under the journal's own ruled
/// line, with the sync control stamped rather than filled.
///
/// **Every figure it carried is still here and still exact.** `TOTAL WALKED`,
/// `SPENT`, `HP` and the affordance sentence read the same projections they
/// always did, and `syncSteps` is dispatched from the same call site with the
/// same guard and the same one haptic.
class _WalkingLedger extends StatelessWidget {
  const _WalkingLedger({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final StrideSession s = controller.session;
    final List<ResourceNodeDefinition> nodes = s.nodesHere;

    // The sentence that relates the header's banked figure to the cost of an
    // action. Visual QA's M-4 was that the approved render states this
    // relationship nowhere: banked and today sit 60 pt apart, both large, both
    // teal, with nothing saying how a stock relates to a flow.
    //
    // The division is arithmetic on two numbers already on screen, not a game
    // rule — the cost comes from `costOf`, which applies the same balance
    // profile the engine charges with.
    String? affordance;
    if (nodes.isNotEmpty) {
      final int? cost = s.costOf(nodes.first.id);
      if (cost != null && cost > 0) {
        final int count = s.usableEnergy ~/ cost;
        // Thousands-separated like every other figure in the app. It was the
        // one bare integer on a screen carrying `455,281` and `455,371`
        // twenty pixels away, and at a real save it reaches four digits.
        affordance = count == 1
            ? 'Enough banked for 1 more gather'
            : 'Enough banked for ${formatSteps(count)} more gathers';
      }
    }

    final List<_WalkingFact> facts = <_WalkingFact>[
      _WalkingFact(
        label: 'Total walked',
        // Since the last playtest reset, or lifetime when there has been
        // none (`DECISIONS/0025`); the Character tab names the lifetime
        // figure beside it.
        value: formatSteps(s.walkedSinceBaseline),
        leading: const WalkingGlyph(role: WalkingRole.stock),
        valueColor: StrideColors.accentSteps,
      ),
      // Spent in this economy — since the epoch a playtest reset moves —
      // so a fresh playtest reads Spent 0 beside Total walked 0; the
      // lifetime figure is the Character tab's (`DECISIONS/0025`).
      _WalkingFact(label: 'Spent', value: formatSteps(s.spentThisEpoch)),
      // Persistent HP (`DECISIONS/0023` §4): carried between fights, restored
      // by food and by safe arrivals — a fact a player checks before choosing
      // to fight. Shown only while it is information: at full health in a safe
      // place it says nothing, and the extra wrap row it costs is what pushes
      // the gather control below the fold on a fresh save
      // (`test/fold_clearance_test.dart`).
      if (s.playerHp < s.playerMaxHp || s.encountersHere.isNotEmpty)
        _WalkingFact(label: 'HP', value: '${s.playerHp} / ${s.playerMaxHp}'),
    ];

    final Widget factRow = Wrap(
      spacing: StrideSpace.s12,
      runSpacing: StrideSpace.s4,
      children: facts,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FactsAndSync(
          facts: facts,
          factRow: factRow,
          sync: _SyncStamp(controller: controller),
        ),
        const SizedBox(height: StrideSpace.s6),
        // The line the facts are written on. It is the journal's own rule,
        // full width of the spread — the first of the page's ruled lines, and
        // the thing that says these figures are an entry rather than a card.
        const KitEdge(
          tile: KitTile.ruleJournal,
          fallbackColor: StrideColors.separator,
        ),
        if (affordance case final String a) ...<Widget>[
          const SizedBox(height: StrideSpace.s4),
          Text(a, style: StrideType.micro),
        ],
        _SyncResult(controller: controller),
      ],
    );
  }
}

/// The sync control, as a **stamped plate** rather than a filled button.
///
/// It is the one thing on this screen that is not the game action, and as a
/// filled secondary button it kept reading as one. `KitFrame.btnPlateV2` is the
/// kit's landed plate (`KIT_CONTRACT` §8); raised, it takes the lit upper edge
/// every other plate in the product takes, so a stamp on the page and a button
/// elsewhere agree about where the light comes from.
///
/// **The call site is unchanged**: `controller.syncSteps()` behind the same
/// busy/ready guard, and the one light haptic only when the sync actually
/// banked — the walk paying off is the punctuation moment; a no-change check
/// stays silent.
class _SyncStamp extends StatelessWidget {
  const _SyncStamp({required this.controller});

  final SessionController controller;

  /// The words, unchanged: every harness that funds a save taps this text.
  static const String label = 'Sync steps';

  @override
  Widget build(BuildContext context) {
    final bool enabled = !controller.busy && controller.session.isReady;
    final String text = controller.busy ? 'Checking…' : label;
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () async {
                final AudioController audio = AudioScope.read(context);
                await controller.syncSteps();
                if ((controller.lastSync?.newlyGranted ?? 0) > 0) {
                  audio.hapticLight();
                }
              }
            : null,
        child: KitPlate(
          frame: KitFrame.btnPlateV2,
          raised: enabled,
          fill: StrideColors.surfaceBlock,
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s6,
          ),
          child: Text(
            text,
            style: StrideType.buttonLabelSecondary.copyWith(
              color: enabled
                  ? StrideColors.textPrimary
                  : StrideColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The walking facts and the sync stamp on one line, or on two where the line
/// is not wide enough for both.
///
/// The line's whole point is low mass, so the first instinct is to keep it on
/// one line and let the facts compress. That is wrong for the same reason D-01
/// was wrong: at 320 dp and text scale 1.4 the label `TOTAL WALKED` needs
/// 99.8 dp beside the stamp and has 66, and compressing it means clipping a
/// word. The line growing by one row is cheaper than a figure the player
/// cannot read, and it only happens where the width genuinely is not there.
class _FactsAndSync extends StatelessWidget {
  const _FactsAndSync({
    required this.facts,
    required this.factRow,
    required this.sync,
  });

  final List<_WalkingFact> facts;
  final Widget factRow;
  final Widget sync;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    double widthOf(String data, TextStyle style) {
      final TextPainter p = TextPainter(
        text: TextSpan(text: data, style: inherited.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double w = p.width;
      p.dispose();
      return w;
    }

    // The widest single fact, at full size. The `Wrap` can run the facts onto
    // separate lines on its own; what it cannot do is make one of them narrower
    // than its own content.
    double widest = 0;
    for (final _WalkingFact f in facts) {
      final double needs =
          (f.leading == null ? 0 : 24 + StrideSpace.iconLabelGap) +
          widthOf(f.label.toUpperCase(), StrideType.microLabel) +
          StrideSpace.s6 +
          widthOf(f.value, StrideType.sub);
      if (needs > widest) widest = needs;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The stamp shrink-wraps, so its width is its label plus its own
        // padding and the frame's declared inset on both sides — the same
        // figure before and after the raster lands (`KIT_CONTRACT` §0).
        final double syncWidth =
            widthOf(_SyncStamp.label, StrideType.buttonLabelSecondary) +
            StrideSpace.s10 * 2 +
            KitFrames.insetFor(KitFrame.btnPlateV2) * 2;

        final bool sideBySide =
            widest + StrideSpace.s8 + syncWidth <= constraints.maxWidth;

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: factRow),
              const SizedBox(width: StrideSpace.s8),
              sync,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            factRow,
            const SizedBox(height: StrideSpace.s8),
            sync,
          ],
        );
      },
    );
  }
}

// A label and a figure on one line — the walking band's unit.
///
/// Deliberately **not** a [LabeledValueTile]: a tile is a filled block with a
/// 22 px numeral, and two of them are what gave this section the mass the owner
/// asked to remove. The value keeps its accent and its tabular figures, at the
/// weight of a supporting fact rather than of a headline.
class _WalkingFact extends StatelessWidget {
  const _WalkingFact({
    required this.label,
    required this.value,
    this.leading,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? leading;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      if (leading case final Widget g) ...<Widget>[
        g,
        const SizedBox(width: StrideSpace.iconLabelGap),
      ],
      // Flexible, and adaptive, because these sit in a `Wrap` that hands each
      // child the full line width — a `Row(mainAxisSize.min)` of plain `Text`
      // inside one overflows rather than wrapping, which is a yellow stripe
      // and not a layout.
      Flexible(
        child: AdaptiveText(
          label.toUpperCase(),
          style: StrideType.microLabel,
          minScale: 0.8,
        ),
      ),
      const SizedBox(width: StrideSpace.s6),
      Flexible(
        child: AdaptiveText(
          value,
          style: StrideType.sub.copyWith(
            fontFeatures: StrideType.tabularFigures,
          ),
          color: valueColor ?? StrideColors.textPrimary,
          minScale: 0.8,
        ),
      ),
    ],
  );
}

/// What the last foreground sync did.
///
/// Split out of the old `_SyncRow`, which owned both the button and this line.
/// The button now lives beside the walking facts it refreshes; the result is
/// still reported underneath them, unchanged.
class _SyncResult extends StatelessWidget {
  const _SyncResult({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final SyncReport? r = controller.lastSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (r != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Text(_describe(r), style: StrideType.micro),
          // Faults are rendered, never filtered. `RULES.md` H-4 names
          // `cursorOfferedWhenProhibited` specifically: it "must never be
          // weakened, suppressed in UI, or accommodated". Every fault still
          // renders — as a player sentence now, not a wire enum name; H-4
          // mandates the fault's presence, not its format (Fable V2 UX
          // audit S7 — the one genuinely debug-looking line a player could
          // meet).
          if (r.faults.isNotEmpty)
            Text(
              'Step data issues: '
              '${r.faults.map(_faultWord).toSet().join('; ')} — '
              'nothing was double-counted',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
        ],
      ],
    );
  }

  /// Each fault as a short player phrase. One mapping per enum value so a
  /// new fault fails compilation here rather than shipping as its raw name;
  /// the phrases stay deliberately dull — a fault channel is a diagnostic,
  /// not drama.
  static String _faultWord(SyncFault f) => switch (f) {
    SyncFault.malformedObservation => 'an unreadable step record was set aside',
    SyncFault.malformedOriginKey => 'an unreadable source tag was set aside',
    SyncFault.originKeyingUnconfigured =>
      'the device key is not ready — reading was refused',
    SyncFault.completenessOnNonFinalPage =>
      'a partial answer overclaimed and was checked',
    SyncFault.contradictoryOriginScope =>
      'a contradictory answer was read cautiously',
    SyncFault.invalidatedWithoutRescan => 'a revision arrived without detail',
    SyncFault.unavailableWithoutReason => 'the source went quiet mid-read',
    SyncFault.cursorOfferedWhenProhibited =>
      'an early bookmark was refused, correctly',
    SyncFault.observationsOnNoChange => 'an unexpected payload was set aside',
    SyncFault.noChangeWithPayload => 'an unexpected payload was set aside',
    SyncFault.mismatchedCompleteness => 'an inconsistent claim was checked',
  };

  static String _describe(SyncReport r) => switch (r.status) {
    // Access first. On iOS a read the player has not allowed comes back
    // empty, which the sync truthfully reports as "no change" — but the fact
    // that matters to the player is that nobody was allowed to look. Denied
    // and unavailable are separated because they have different remedies.
    SyncStatus.noChange || SyncStatus.reconciled
        when r.authorization == HealthAuthorization.denied =>
      'Health access not granted — allow Steps in Settings › Health',
    SyncStatus.noChange || SyncStatus.reconciled
        when r.authorization == HealthAuthorization.unavailable =>
      'Health is not available on this device',
    // The source count is not on the play surface (PLAYABLE_POLISH_01 §7):
    // two sources reporting the same hours are both credited (`RULES.md`
    // H-1 keeps origins distinct) and that fact matters, but it is a
    // diagnostic, and its home is the Character tab's Total walked line —
    // the persisted count, never an identity (H-7).
    SyncStatus.reconciled when r.newlyGranted > 0 =>
      '+${formatSteps(r.newlyGranted)} steps banked',
    // Observed is shown beside newlyGranted, never instead of it. A restated
    // bucket counts in `observedSteps` every time it is restated, so rendering
    // it as "steps earned" would tell a returning player they earned the same
    // walk twice (`RULES.md` H-1).
    SyncStatus.reconciled =>
      'No new steps to bank (${formatSteps(r.observedSteps)} already counted)',
    SyncStatus.noChange => 'No new steps since the last check',
    SyncStatus.unavailable => 'Step data is not available right now',
    SyncStatus.keyingUnconfigured => 'Health is not connected on this device',
    SyncStatus.contractViolation =>
      'That step reading was refused before it could count',
    SyncStatus.commitRefused =>
      'Those steps could not be saved — reload before continuing',
  };
}
