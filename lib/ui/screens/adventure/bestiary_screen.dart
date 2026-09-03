/// Field Notes — the Bestiary route (`DECISIONS/0028` §6).
///
/// ## Why a pushed full-screen route
///
/// Enemy knowledge was location-locked: the signature hunts and Known gates
/// that shape a 3,000–6,000-step trip could only be inspected by standing
/// where the enemy lives, so every hunt was planned blind. This route lists
/// every enemy whose existence the player can currently see, grouped by
/// region with the journey cost to reach it — the planning surface, not a
/// second combat UI. Starting a fight still happens on location, through the
/// encounter card, exactly as before.
///
/// ## What it deliberately is not
///
/// Not an encyclopedia (resources and recipes already answer "what am I
/// for" at their own decision points), not a completion meter (one fact
/// line, no percentages — P-5), and not animated: rows are static so
/// thirteen entries cost no tickers (the hidden-tab lesson).
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, KnowledgeTier;

import '../../../runtime/stride_session.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart';
import '../../components/surfaces.dart';
import '../../icons/combat_assets.dart';
import '../../icons/encounter_habitat.dart';
import '../../icons/reward_art.dart';
import 'encounter_card.dart';
import '../../state/activity_controller.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class BestiaryScreen extends StatelessWidget {
  const BestiaryScreen({super.key});

  /// Pushes the notes, re-wrapped in the pushing context's controllers —
  /// the Goal Board's own pattern.
  static Future<void> open(BuildContext context) {
    final SessionController session = SessionScope.read(context);
    final ActivityController activity = ActivityScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScope(
          controller: session,
          child: ActivityScope(
            controller: activity,
            child: const BestiaryScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final BestiaryView notes = c.session.bestiary;
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);

    return ColoredBox(
      color: StrideColors.surfaceGround,
      child: Column(
        children: <Widget>[
          SizedBox(height: inset.top),
          ScreenHeader(
            eyebrow: 'THE TRAVELER\'S JOURNAL',
            title: 'Field Notes',
            trailing: Semantics(
              button: true,
              label: 'Close the field notes',
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                StrideSpace.screenGutter,
                StrideSpace.s12,
                StrideSpace.screenGutter,
                StrideSpace.s16 + inset.bottom,
              ),
              children: <Widget>[
                // The one fact line — a statement, never a meter (P-5).
                SectionCard(
                  child: Text(
                    notes.complete
                        ? 'Field Guide — complete edition. Every creature '
                              'you have heard of is Known.'
                        : '${notes.knownCount} of ${notes.visibleCount} '
                              'creatures Known.',
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ),
                for (final BestiaryRegionView region in notes.regions) ...[
                  const SizedBox(height: StrideSpace.cardGap),
                  SectionHeading(
                    label: region.isHere
                        ? '${region.locationName} — HERE'
                        : region.distanceSteps == null
                        ? region.locationName
                        : '${region.locationName} — '
                              '${formatSteps(region.distanceSteps!)} steps',
                  ),
                  const SizedBox(height: StrideSpace.s8),
                  SectionCard(
                    // Slate — the bestiary board (FMPO02 wave 3, FINAL-11 #7).
                    // The tile was authored for exactly this list and shipped
                    // registered and painted nowhere; a registry entry nothing
                    // paints is the next integrator's trap. It resolves to
                    // null if the PNG ever goes missing and the card then
                    // paints the flat fill it painted before.
                    surface: PanelSurface.slate,
                    padding: const EdgeInsets.all(
                      StrideSpace.cardPaddingCompact,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (
                          int i = 0;
                          i < region.entries.length;
                          i++
                        ) ...<Widget>[
                          if (i > 0)
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                vertical: StrideSpace.s4,
                              ),
                              color: StrideColors.separator,
                            ),
                          _BestiaryRow(
                            entry: region.entries[i],
                            location: region.locationId,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One creature's notes: name and tier word, the study progress in plain
/// words, and — as knowledge buys it — the drops. Static by design.
class _BestiaryRow extends StatelessWidget {
  const _BestiaryRow({required this.entry, required this.location});

  final EncounterOption entry;

  /// The region this row is filed under — the habitat its vignette draws.
  /// Passed rather than read from the session, because the guide lists
  /// creatures the player is not standing beside.
  final ContentId location;

  @override
  Widget build(BuildContext context) {
    final String tierWord = switch (entry.knowledge) {
      KnowledgeTier.unseen => 'Unseen',
      KnowledgeTier.seen => 'Seen',
      KnowledgeTier.studied => 'Studied',
      KnowledgeTier.known => 'Known',
    };
    // The next study milestone, in the card's own grammar; nothing when
    // Known — the ladder deliberately stops (`DECISIONS/0023` §5).
    final String? progress = switch (entry.knowledge) {
      KnowledgeTier.known => null,
      KnowledgeTier.studied =>
        'Known after ${entry.knownAt - entry.victories} more '
            '${entry.knownAt - entry.victories == 1 ? 'victory' : 'victories'}',
      _ when entry.victories > 0 =>
        'Studied after ${entry.studiedAt - entry.victories} more '
            '${entry.studiedAt - entry.victories == 1 ? 'victory' : 'victories'}',
      _ => null,
    };
    // Only what knowledge has revealed: unrevealed signatures stay the
    // mystery the encounter card keeps them (`DECISIONS/0023` §5).
    final List<String> drops = <String>[
      for (final DropPreview drop in entry.drops)
        if (drop.revealed) drop.name,
    ];
    final String? gate = entry.reason == 'enemy_not_known'
        ? (entry.requiresKnownEnemyName == null
              ? 'Will not show itself yet'
              : 'Know the ${entry.requiresKnownEnemyName} to draw it out')
        : null;

    // The row's illustration: this creature standing in its own habitat, at
    // ×1, from rasters the encounter card already ships — no generations, no
    // ticker. An unsighted creature is drawn as ink, which is what "Unseen"
    // looks like in a field guide.
    final CombatantArt? art = CombatAssets.enemyFor(entry.enemyId);
    final HabitatPlate? habitat = EncounterHabitat.plateFor(
      location,
      enemy: entry.enemyId,
    );

    final Widget lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                entry.name,
                style: StrideType.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            Text(
              tierWord.toUpperCase(),
              style: StrideType.microLabel.copyWith(
                color: entry.knowledge == KnowledgeTier.known
                    ? StrideColors.positiveReady
                    : StrideColors.textSecondary,
              ),
            ),
          ],
        ),
        if (habitat != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            habitat.caption,
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 1,
          ),
        ],
        if (gate != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            gate,
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            maxLines: 1,
          ),
        ] else if (progress != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Row(
            children: <Widget>[
              // Enemy knowledge advancing, the same 24² mark as any other
              // in-line progress fact (`RewardArt.markKnowledge`, ART-10
              // §1). Decorative: the line beside it already says the fact.
              const ExcludeSemantics(
                child: PixelAsset(
                  assetPath: RewardArt.markKnowledge,
                  nativeWidth: 24,
                  nativeHeight: 24,
                  scale: 1,
                ),
              ),
              const SizedBox(width: StrideSpace.s6),
              Flexible(
                child: Text(
                  progress,
                  style: StrideType.micro.copyWith(
                    color: StrideColors.textMuted,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
        if (drops.isNotEmpty) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            'Drops: ${drops.join(', ')}',
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StrideSpace.s4),
      child: art == null
          ? lines
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: HabitatVignette(
                    art: art,
                    plate: habitat,
                    silhouette: entry.knowledge == KnowledgeTier.unseen,
                  ),
                ),
                const SizedBox(width: StrideSpace.s10),
                Expanded(child: lines),
              ],
            ),
    );
  }
}
