import 'package:meta/meta.dart';

/// The schema version a content bundle declares.
///
/// Every content file carries one. The loader accepts what it supports, rejects
/// what it does not, and **never guesses**: content written against a schema the
/// running build does not understand is a hard failure, not something to coerce.
///
/// A newer bundle on an older build is the dangerous direction. Silently
/// ignoring a field the build has never heard of would produce a registry that
/// looks fine and is quietly wrong — precisely the failure mode the whole
/// project's validation posture exists to prevent.
///
/// Save migration is a different problem and is **not** part of this. Saves are
/// F-05; this governs only the shape of authored content.
@immutable
final class SchemaVersion implements Comparable<SchemaVersion> {
  const SchemaVersion(this.value);

  final int value;

  /// The oldest schema this build can read.
  static const SchemaVersion minimumSupported = SchemaVersion(1);

  /// The newest schema this build understands.
  static const SchemaVersion current = SchemaVersion(1);

  static bool supports(int version) =>
      version >= minimumSupported.value && version <= current.value;

  static String get supportedRange => minimumSupported.value == current.value
      ? '${current.value}'
      : '${minimumSupported.value}–${current.value}';

  @override
  int compareTo(SchemaVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is SchemaVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'v$value';
}

/// The outcome of reading a `schemaVersion` field.
@immutable
final class SchemaVersionCheck {
  const SchemaVersionCheck._({
    this.version,
    this.explanation = '',
    this.suggestion = '',
  });

  final SchemaVersion? version;
  final String explanation;
  final String suggestion;

  bool get isValid => version != null;

  /// Reads and validates a raw `schemaVersion` value.
  ///
  /// Returns a reason rather than throwing, so a bundle with several bad files
  /// reports all of them at once.
  static SchemaVersionCheck read(Object? raw) {
    if (raw == null) {
      return const SchemaVersionCheck._(
        explanation: 'the required field "schemaVersion" is missing',
        suggestion:
            'add `"schemaVersion": ${1}` as the first field of the file',
      );
    }
    if (raw is! int) {
      return SchemaVersionCheck._(
        explanation:
            '"schemaVersion" must be a whole number, found ${raw.runtimeType} '
            '($raw)',
        suggestion: 'write it unquoted, e.g. `"schemaVersion": 1`',
      );
    }
    if (raw < SchemaVersion.minimumSupported.value) {
      return SchemaVersionCheck._(
        explanation:
            'schema version $raw is older than this build supports '
            '(${SchemaVersion.supportedRange})',
        suggestion:
            'migrate the file to schema ${SchemaVersion.current.value}. This '
            'build will not guess at an older layout.',
      );
    }
    if (raw > SchemaVersion.current.value) {
      return SchemaVersionCheck._(
        explanation:
            'schema version $raw is newer than this build understands '
            '(${SchemaVersion.supportedRange})',
        suggestion:
            'update the application, or author the file against schema '
            '${SchemaVersion.current.value}. Loading it anyway would silently '
            'drop fields this build has never heard of.',
      );
    }
    return SchemaVersionCheck._(version: SchemaVersion(raw));
  }
}
