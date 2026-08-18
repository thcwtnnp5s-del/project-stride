/// What the atlas says about the place the player tapped, and the one control
/// that may follow from it.
///
/// This is `_DestinationRow` moved under the map. The rules are unchanged: the
/// row is the control; every reason it might be disabled is stated on it, in
/// the order the engine refuses (requirement, then price); the button exists
/// only because `TravelTo` exists and dispatches only `SessionController.travel`.
/// A place with no road from here is described and is **not** offered — the
/// panel says which way it is reached and stops there, because the engine would
/// refuse the journey and a disabled button with no sentence is a broken one.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Terrain;

import '../../../../runtime/stride_session.dart';
import '../../../components/adaptive_text.dart';
import '../../../components/data_display.dart';
import '../../../components/screen_header.dart' show formatSteps;
import '../../../components/surfaces.dart';
import '../../../components/walking_glyph.dart';
import '../../../state/session_controller.dart';
import '../../../state/session_scope.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_metrics.dart';
import '../../../theme/stride_typography.dart';
import 'atlas_layout.dart';

class AtlasSelectionPanel extends StatelessWidget {
  const AtlasSelectionPanel({
    super.key,
    required this.scene,
    required this.selected,
    required this.onTravelled,
  });

  final AtlasScene scene;

  /// The place under discussion. The screen defaults it to the current
  /// location, so the panel is never empty.
  final AtlasNode selected;

  /// Called after a travel is dispatched, so the screen can let the selection
  /// follow the player. Not a result callback — the result is the session's.
  final VoidCallback onTravelled;

  @override
  Widget build(BuildContext context) {
    final SessionController watched = SessionScope.of(context);
    final SessionController controller = SessionScope.read(context);
    final RegionPlace place = selected.place;
    final TravelOption? option = scene.optionFor(place.id);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  place.displayName,
                  style: StrideType.cardTitle,
                ),
              ),
              if (option != null) ...<Widget>[
                const SizedBox(width: StrideSpace.s8),
                // The step figure keeps the muted "steps as a unit" glyph. It
                // is a price, still a quantity of steps rather than the
                // player's own balance, and L-16's two-tone rule turns on
                // exactly that distinction.
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.s4),
                AdaptiveText(
                  formatSteps(option.stepCost),
                  style: StrideType.itemCount,
                  color: option.affordable
                      ? StrideColors.textPrimary
                      : StrideColors.textMuted,
                ),
              ],
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          AdaptiveText(
            _identityLine(place),
            style: StrideType.micro,
            color: StrideColors.textSecondary,
          ),
          const SizedBox(height: StrideSpace.s4),
          if (option != null) ...<Widget>[
            if (subtitleFor(option, watched.session.usableEnergy)
                case final String reason) ...<Widget>[
              AdaptiveText(
                reason,
                style: StrideType.micro,
                color: StrideColors.textMuted,
              ),
              const SizedBox(height: StrideSpace.s8),
            ],
            StrideButton.secondary(
              label: watched.busy ? 'Travelling…' : 'Travel',
              onPressed:
                  option.canTravel && !watched.busy && watched.session.isReady
                  ? () {
                      controller.travel(option.id);
                      onTravelled();
                    }
                  : null,
            ),
          ] else
            Text(
              _reachLine(place),
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          if (watched.lastTravel != null) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            TravelResultLine(report: watched.lastTravel!),
          ],
        ],
      ),
    );
  }

  /// `You are here · Grassland · Safe · 1 resource`.
  static String _identityLine(RegionPlace place) => <String>[
    if (place.isCurrent)
      'You are here'
    else if (!place.isUnlocked)
      'Not yet reached',
    terrainWord(place.terrain),
    if (place.isSafe) 'Safe',
    if (place.resourceCount == 1)
      '1 resource'
    else if (place.resourceCount > 1)
      '${place.resourceCount} resources',
  ].join(' · ');

  /// For a place with no direct road: which way it lies. Truthful about the
  /// one thing a player would otherwise try — there is no button because the
  /// engine has no route, not because the screen is hiding one.
  String _reachLine(RegionPlace place) {
    if (place.isCurrent) {
      return 'Tap a place on the map to see the way there.';
    }
    final List<ContentId>? way = scene.wayTo(place.id);
    if (way == null || way.isEmpty) {
      return 'No route runs there from here.';
    }
    final String via = way
        .map((ContentId id) => scene.nodeFor(id)?.place.displayName ?? id.value)
        .join(', then ');
    return 'Not reachable from here directly · reached by way of $via';
  }

  /// The one line that explains why a journey is refused, or null when it is
  /// open — an open road needs no sentence beside its button.
  ///
  /// Ordered the way the engine refuses: the requirement first, then the price.
  /// Telling a player they are 400 steps short of Forgotten Hollow, when the
  /// real answer is that it needs a Bronze Sword, sends them walking toward a
  /// wall they will still hit.
  static String? subtitleFor(TravelOption option, int banked) {
    if (option.isBlocked) {
      return 'Needs ${option.missingRequirements.join(', ')}';
    }
    if (!option.affordable) {
      return 'Walk ${formatSteps(option.shortfallFrom(banked))} more steps';
    }
    return null;
  }

  /// The terrain, as a word a player would use rather than an enum name.
  static String terrainWord(Terrain terrain) => switch (terrain) {
    Terrain.grassland => 'Grassland',
    Terrain.forest => 'Forest',
    Terrain.foothills => 'Foothills',
    Terrain.alpine => 'Alpine',
  };
}

/// What the last journey did, while the line is still on screen.
class TravelResultLine extends StatelessWidget {
  const TravelResultLine({super.key, required this.report});

  final TravelReport report;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: AdaptiveText(
      report.succeeded
          ? report.firstVisit
                ? 'Arrived at ${report.destinationName} for the first time · '
                      '${formatSteps(report.cost)} steps'
                : 'Arrived at ${report.destinationName} · '
                      '${formatSteps(report.cost)} steps'
          : refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  /// Keyed on the stable wire code, never on the explanation sentence.
  static String refusalText(TravelReport report) => switch (report.rejection) {
    'insufficient_steps' => 'Not enough banked steps for that journey.',
    'entry_requirement_unmet' =>
      'You are not carrying what that place requires.',
    'route_not_found' => 'No route runs there from here.',
    'already_at_location' => 'You are already there.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before travelling again.',
    _ => 'You could not travel there.',
  };
}
