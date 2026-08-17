import 'package:meta/meta.dart';

/// The version of the [GameState] shape.
///
/// Distinct from `SchemaVersion`, which governs authored content. Content and
/// state evolve for different reasons and at different rates: a new item is a
/// content change, a new field on the player is a state change. Sharing one
/// number would force a content edit to look like a save-breaking change.
///
/// **This is still not a migration framework**, and deliberately so. There is no
/// registry of migration steps and no chain of transformations. What exists is a
/// table of *direct decoders per historical version* (`StateCodecs`), plus one
/// place — `BootstrapCoordinator` — that asks [migrationRequired] and applies the
/// single upgrade this project has needed. A framework would be built for
/// migrations nobody has written; two decoders and one branch are built for the
/// one that exists.
///
/// ## Version history
///
/// | Version | Introduced | What changed |
/// |---:|---|---|
/// | 1 | F-03 | The original state shape |
/// | 2 | Playable Phase 2 | `steps.epoch` — the playable-economy cutover (`DECISIONS/0016`) |
@immutable
final class StateVersion implements Comparable<StateVersion> {
  const StateVersion(this.value);

  final int value;

  /// The version new games are created at.
  static const StateVersion current = StateVersion(2);

  /// The oldest version this build can read.
  ///
  /// **Version 1 must stay readable.** The owner's device holds a v1 save
  /// carrying the whole Phase 1 acceptance run, and that save is the input the
  /// Phase 2 cutover exists to migrate. Raising this floor would not "drop
  /// legacy support" — it would refuse to load the one save the migration is
  /// for.
  static const StateVersion minimumSupported = StateVersion(1);

  static bool supports(int version) =>
      version >= minimumSupported.value && version <= current.value;

  /// Whether a state at [version] must be migrated before it is played.
  ///
  /// The single durable signal that the Phase 2 cutover has not yet run on this
  /// save. It is deliberately the *only* such signal — see
  /// `EstablishEconomyEpoch` for why a boolean beside it would be a second
  /// mechanism recording one fact.
  static bool migrationRequired(int version) =>
      supports(version) && version < current.value;

  static String get supportedRange => minimumSupported.value == current.value
      ? '${current.value}'
      : '${minimumSupported.value}–${current.value}';

  @override
  int compareTo(StateVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is StateVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'state v$value';
}

/// Thrown when a state declares a version this build cannot use.
///
/// A throw rather than a rejection, deliberately. Rejections are for *gameplay*
/// the player attempted and cannot have; an unreadable state version is a
/// programming or deployment fault, and continuing would mean operating on a
/// structure whose meaning is unknown.
final class UnsupportedStateVersionException implements Exception {
  const UnsupportedStateVersionException(this.found);

  final int found;

  String get message =>
      'Unsupported game state version $found. This build supports '
      '${StateVersion.supportedRange}.\n'
      '${found > StateVersion.current.value ? 'The state was written by a newer build. Update the application; reading it here would mean guessing at fields this build has never seen.' : 'The state predates this build\'s minimum. A migration would be needed, and none is implemented.'}';

  @override
  String toString() => 'UnsupportedStateVersionException: $message';
}
