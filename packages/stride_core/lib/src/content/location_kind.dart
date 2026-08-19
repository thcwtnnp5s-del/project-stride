import 'content_id.dart';
import 'content_registry.dart';
import 'definitions.dart';

/// What a place *is*, in one word, for a surface that needs to draw it
/// differently. **`DECISIONS/0021` §5.**
///
/// ## Why this is derived and not authored
///
/// Every one of these words is already a fact the content pack states: safety
/// is `LocationDefinition.isSafe`, a boss is `EnemyDefinition.isBoss`, a mine
/// is a resource node asking for a pickaxe. An authored `kind` field would be
/// a second place the same truth lives, free to disagree with the first the
/// day someone adds a boss to a location whose label still says `wilds`
/// (`RULES.md` G-7).
///
/// So it is a pure function over the registry, and the atlas can give Haven's
/// Rest a different marker from Forgotten Hollow without the content files
/// gaining a field that has to be kept honest by hand.
enum LocationKind {
  /// Safe ground: defeat returns the player here, and nothing fights.
  haven('Haven'),

  /// Open country. Enemies may roam it; none of them guards it.
  wilds('Wilds'),

  /// Somewhere the work needs a pickaxe — a mine, a quarry, a cutting.
  worksite('Worksite'),

  /// A boss lives here.
  perilous('Perilous');

  const LocationKind(this.label);

  /// Shown to the player, as the place's one-word identity line.
  final String label;
}

/// Derives [LocationKind] from what a content pack already says.
final class LocationKinds {
  const LocationKinds._();

  /// The kind of [location], read from [registry].
  ///
  /// The order of the tests is the whole rule and it is deliberately
  /// **safety first, danger next, work last**:
  ///
  /// 1. `isSafe` → [LocationKind.haven]. Safety is the strongest claim a place
  ///    can make and the one the defeat rule turns on (`DECISIONS/0003`); a
  ///    safe location cannot also be perilous, and if content ever made one
  ///    both, the honest word for the player is still *haven*.
  /// 2. any enemy here with `isBoss` → [LocationKind.perilous]. A boss
  ///    outranks a pickaxe: Stonefall Mine with a guardian in it is somewhere
  ///    you go armed, and the marker should say so before it says *worksite*.
  /// 3. any resource node here with `requiredToolKind == pickaxe` →
  ///    [LocationKind.worksite].
  /// 4. otherwise [LocationKind.wilds].
  ///
  /// An unknown [location] answers [LocationKind.wilds] rather than throwing.
  /// The registry's own reference validation has already refused a pack with a
  /// dangling location id, so this branch is unreachable through a validated
  /// pack — and taking the game down over a label would be the wrong trade for
  /// the one caller that could ever reach it.
  static LocationKind kindFor(ContentRegistry registry, ContentId location) {
    final LocationDefinition? place = registry.locations[location];
    if (place == null) return LocationKind.wilds;
    if (place.isSafe) return LocationKind.haven;

    for (final EnemyDefinition enemy in registry.enemies.values) {
      if (enemy.location == location && enemy.isBoss) {
        return LocationKind.perilous;
      }
    }
    for (final ContentId nodeId in place.resourceNodes) {
      final ResourceNodeDefinition? node = registry.resourceNodes[nodeId];
      if (node != null && node.requiredToolKind == ToolKind.pickaxe) {
        return LocationKind.worksite;
      }
    }
    return LocationKind.wilds;
  }
}
