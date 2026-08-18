import 'package:meta/meta.dart';

/// The version of the [GameState] shape.
///
/// Distinct from `SchemaVersion`, which governs authored content. Content and
/// state evolve for different reasons and at different rates: a new item is a
/// content change, a new field on the player is a state change. Sharing one
/// number would force a content edit to look like a save-breaking change.
///
/// **This is still not a migration framework.** *Decoding* is a table of direct
/// decoders per historical version (`StateCodecs`) — a v1 save is read by the
/// v1 decoder, never by v1→v2→v3 transformations of its JSON. What *is* a
/// chain is the **meaning** applied after decoding: `StateMigrations` is an
/// explicit table of one step per version bump, each declaring in code whether
/// it re-bases the economy and which decision authorised it, and
/// `BootstrapCoordinator` walks the steps from the save's version to [current]
/// inside one transaction. The table exists so that a re-basing can never
/// happen as a side effect of a format bump: a future v3→v4 that only adds a
/// field says `rebasesEconomy: false` and touches no balance.
///
/// ## Version history
///
/// | Version | Introduced | What changed |
/// |---:|---|---|
/// | 1 | F-03 | The original state shape |
/// | 2 | Playable Phase 2 | `steps.epoch` — the playable-economy cutover (`DECISIONS/0016`) |
/// | 3 | Transformation Build 01 | `steps.epoch.establishedAtStateVersion` — the Transformation playtest epoch (`DECISIONS/0018`) |
@immutable
final class StateVersion implements Comparable<StateVersion> {
  const StateVersion(this.value);

  final int value;

  /// The version new games are created at.
  static const StateVersion current = StateVersion(3);

  /// The oldest version this build can read.
  ///
  /// **Version 1 must stay readable.** The owner's device held a v1 save
  /// carrying the whole Phase 1 acceptance run, and a v1 save is still the
  /// input the Phase 2 cutover exists to migrate — through the v1→v2 step and
  /// then the v2→v3 one, in a single launch. Raising this floor would not
  /// "drop legacy support" — it would refuse to load the one save the
  /// migration is for.
  static const StateVersion minimumSupported = StateVersion(1);

  static bool supports(int version) =>
      version >= minimumSupported.value && version <= current.value;

  /// Whether a state at [version] must be migrated before it is played.
  ///
  /// The single durable signal that some `StateMigrations` step has not yet
  /// run on this save. It is deliberately the *only* such signal — see
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
