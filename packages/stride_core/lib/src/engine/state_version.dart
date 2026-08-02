import 'package:meta/meta.dart';

/// The version of the [GameState] shape.
///
/// Distinct from `SchemaVersion`, which governs authored content. Content and
/// state evolve for different reasons and at different rates: a new item is a
/// content change, a new field on the player is a state change. Sharing one
/// number would force a content edit to look like a save-breaking change.
///
/// **This is not a migration framework.** F-03 establishes the version and the
/// place migration will go; F-05 owns saves and will build the rest. What
/// exists here is the guarantee that an unsupported version fails loudly rather
/// than being read as though it were current.
@immutable
final class StateVersion implements Comparable<StateVersion> {
  const StateVersion(this.value);

  final int value;

  /// The version new games are created at.
  static const StateVersion current = StateVersion(1);

  /// The oldest version this build can read.
  ///
  /// Equal to [current] today because nothing older exists. When it diverges,
  /// [migrationRequired] becomes the extension point.
  static const StateVersion minimumSupported = StateVersion(1);

  static bool supports(int version) =>
      version >= minimumSupported.value && version <= current.value;

  /// Whether a state at [version] would need migrating before use.
  ///
  /// The future extension point. It returns false for everything today, which
  /// is honest: no migration exists because no older state exists.
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
