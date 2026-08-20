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

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../combat/combat_screen.dart';
import '../system/stale_banner.dart';
import 'board_card.dart';
import 'encounter_card.dart';
import 'gather_node_card.dart';
import 'goal_tracker_card.dart';

class AdventureScreen extends StatelessWidget {
  const AdventureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<ResourceNodeDefinition> nodes = s.nodesHere;

    // Null before the game starts, which this screen is never built for — the
    // bootstrap resolves before the first frame. Handled rather than asserted:
    // an absent vignette is already a supported state, so there is nothing to
    // gain from crashing over it.
    final ContentId? here = s.currentLocation;
    final String? vignette = here == null ? null : PixelIcons.vignetteFor(here);

    // THE FIGHT — in place of the vignette, the walking band and the cards.
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

    return ListView(
      // Zero horizontal padding: the vignette is full-bleed, and every other
      // child re-applies the gutter itself. A ListView-level gutter would inset
      // the scene band and leave two strips of app ground beside a picture that
      // is meant to be a window.
      padding: const EdgeInsets.only(bottom: StrideSpace.s16),
      children: <Widget>[
        // WHERE I AM — the picture, and the walking that funds what is below it.
        //
        // The strip is attached to the vignette rather than floated as its own
        // card. The owner's device review found the screen reading as "location
        // image, then a large walking card, then a large activity card" —
        // three independent objects — and the walking card was the one with the
        // least to say and the second-most visual mass on the screen.
        if (vignette != null) ...<Widget>[
          _LocationVignette(assetPath: vignette, name: s.locationName),
        ] else
          const SizedBox(height: StrideSpace.s12),

        _Gutter(child: _WalkingStrip(controller: c)),
        const SizedBox(height: StrideSpace.cardGap),

        _Gutter(
          child: Column(
            children: <Widget>[
              if (s.isStale) ...<Widget>[
                StaleBanner(busy: c.busy, onReload: c.reload),
                const SizedBox(height: StrideSpace.cardGap),
              ],

              // WHAT MY WALKING JUST MADE POSSIBLE — after a granting sync,
              // held until dismissed (`DECISIONS/0023` §1; brief §5). Above
              // everything else because it is the moment the sync exists for.
              if (c.lastOpportunities.isNotEmpty) ...<Widget>[
                _OpportunityBanner(controller: c),
                const SizedBox(height: StrideSpace.cardGap),
              ],

              // WHAT I CAN DO HERE — immediately, not after a second card.
              // The gather control is the screen's primary action and must
              // stay above the fold on ≥390 dp phones
              // (`test/fold_clearance_test.dart`); the goal tracker and the
              // board are planning surfaces and sit below the action.
              if (nodes.isEmpty)
                const SectionCard(
                  child: Text(
                    'There is nothing to gather here.',
                    style: StrideType.body,
                  ),
                )
              else
                for (final ResourceNodeDefinition node in nodes) ...<Widget>[
                  GatherNodeCard(node: node),
                  const SizedBox(height: StrideSpace.cardGap),
                ],

              // WHAT I CAN FIGHT HERE — one card per enemy at this location,
              // below the gather cards. Absent where the content has no enemy
              // (Haven's Rest), rather than an empty-state card: a safe place
              // does not need to announce it.
              for (final EncounterOption option in encounters) ...<Widget>[
                EncounterCard(option: option),
                const SizedBox(height: StrideSpace.cardGap),
              ],

              // WHAT I AM WORKING TOWARDS — the three tracked slots.
              const GoalTrackerCard(),
              const SizedBox(height: StrideSpace.cardGap),

              // WHAT THIS PLACE ASKS FOR — the contract board, in this
              // location's own fiction (`DECISIONS/0023` §2). Absent where
              // the place keeps no board (the Hollow).
              const LocationBoardCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The step-sync motivation moment: what was banked, and the few true
/// sentences about what it makes possible (brief §5). Dismissed by the
/// player, displaced by the next command — never swept away by a timer.
class _OpportunityBanner extends StatelessWidget {
  const _OpportunityBanner({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final int banked = controller.lastSync?.newlyGranted ?? 0;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const WalkingGlyph(role: WalkingRole.stock),
              const SizedBox(width: StrideSpace.iconLabelGap),
              Expanded(
                child: Text(
                  '+${formatSteps(banked)} STEPS BANKED',
                  style: StrideType.sectionHeading.copyWith(
                    color: StrideColors.accentSteps,
                  ),
                ),
              ),
            ],
          ),
          for (final SyncOpportunity o in controller.lastOpportunities) ...<
              Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(o.headline, style: StrideType.itemName),
            Text(o.detail, style: StrideType.micro),
          ],
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(
            label: 'OK',
            onPressed: controller.acknowledgeOpportunities,
          ),
        ],
      ),
    );
  }
}

/// The screen gutter, applied per child rather than to the list, so a full-bleed
/// scene can sit beside gutter-inset cards in one scroll view.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: StrideSpace.screenGutter),
    child: child,
  );
}

/// The arrival vignette: where the player is, as a picture.
///
/// **Presentation only, and shaped so it cannot be mistaken for anything else.**
/// There is no character in it, nothing in it is tappable, and no control sits
/// on top of it. The player is not steering anyone around this place; they are
/// looking at it, the way an illustration at the head of a chapter shows the
/// room the chapter happens in.
///
/// The name is written over the image's lower edge rather than beside it,
/// because the band is full-bleed and a caption in the gutter would re-introduce
/// the inset the full-bleed layout exists to remove.
class _LocationVignette extends StatelessWidget {
  const _LocationVignette({required this.assetPath, required this.name});

  final String assetPath;
  final String name;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.bottomLeft,
    children: <Widget>[
      PixelScene.vignette(assetPath),
      // A gradient, not a solid plate: the vignette's lower edge is grass and
      // trail, so a plate would cut the picture with a hard line while a
      // gradient lets the ground run out under the text.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          StrideSpace.screenGutter,
          StrideSpace.s16,
          StrideSpace.screenGutter,
          // 12, not 8. The walking band now sits directly under the vignette
          // with no card gap between them, so the caption was riding about
          // 5 dp off the image's crop with the darkest part of its own gradient
          // below it rather than behind it.
          StrideSpace.s12,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x00000000), Color(0xCC14120F)],
          ),
        ),
        child: Text(name, style: StrideType.cardTitle, maxLines: 1),
      ),
    ],
  );
}

/// WHAT WALKING LETS ME DO — one band, not a card.
///
/// ## What this replaced, and why the mass came out
///
/// This was a full `SectionCard`: a section heading, two 22 px value tiles in
/// filled blocks, the affordance sentence, and a full-width filled `Sync steps`
/// button — roughly 215 dp, second only to the gather card, sitting between the
/// player and the only action on the screen.
///
/// **Every figure it carried is still here and still exact.** `TOTAL WALKED`,
/// `SPENT` and the affordance sentence read the same projections they always
/// did. What changed is their weight: they are supporting facts about a stock
/// the header already shows in 19 px teal, and they were being drawn at the
/// size of a headline. The band is about 70 dp.
///
/// It is attached to the vignette's lower edge — no gap, no card, a rule under
/// the picture — so "where I am" and "what my walking has bought me here" read
/// as one object rather than two.
class _WalkingStrip extends StatelessWidget {
  const _WalkingStrip({required this.controller});

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
        value: formatSteps(s.totalGranted),
        leading: const WalkingGlyph(role: WalkingRole.stock),
        valueColor: StrideColors.accentSteps,
      ),
      _WalkingFact(label: 'Spent', value: formatSteps(s.totalSpent)),
      // Persistent HP (`DECISIONS/0023` §4): carried between fights, restored
      // by food and by safe arrivals — a fact a player checks before choosing
      // to fight. Shown only while it is information: at full health it is
      // noise, and the extra wrap row it costs is what pushes the gather
      // control below the fold on a fresh save
      // (`test/fold_clearance_test.dart`).
      if (s.playerHp < s.playerMaxHp)
        _WalkingFact(label: 'HP', value: '${s.playerHp} / ${s.playerMaxHp}'),
    ];

    // Demoted to a utility control beside the facts it refreshes, rather than a
    // full-width filled button under them. It is the only thing on this screen
    // that is not the game action, and it was reading as the game action.
    final Widget sync = StrideButton.secondary(
      label: controller.busy ? 'Checking…' : 'Sync steps',
      onPressed: controller.busy || !controller.session.isReady
          ? null
          : controller.syncSteps,
    );

    final Widget factRow = Wrap(
      spacing: StrideSpace.s12,
      runSpacing: StrideSpace.s4,
      children: facts,
    );

    return Padding(
      padding: const EdgeInsets.only(top: StrideSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FactsAndSync(facts: facts, factRow: factRow, sync: sync),
          if (affordance case final String a) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(a, style: StrideType.micro),
          ],
          _SyncResult(controller: controller),
        ],
      ),
    );
  }
}

/// The walking facts and the sync control on one line, or on two where the line
/// is not wide enough for both.
///
/// The band's whole point is low mass, so the first instinct is to keep it on
/// one line and let the facts compress. That is wrong for the same reason D-01
/// was wrong: at 320 dp and text scale 1.4 the label `TOTAL WALKED` needs
/// 99.8 dp beside the button and has 66, and compressing it means clipping a
/// word. The band growing by one line is cheaper than a figure the player
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
        // The button shrink-wraps, so its width is its label plus its padding.
        final double syncWidth =
            widthOf('Sync steps', StrideType.buttonLabelSecondary) +
            StrideSpace.s10 * 2;

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

/// A label and a figure on one line — the walking band's unit.
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
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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
          // weakened, suppressed in UI, or accommodated". A product UI naturally
          // maps a sync onto a friendly line, and faults are the field with no
          // friendly rendering — so they are the field that gets dropped.
          if (r.faults.isNotEmpty)
            Text(
              'faults: ${r.faults.map((SyncFault f) => f.name).join(', ')}',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
        ],
      ],
    );
  }

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
