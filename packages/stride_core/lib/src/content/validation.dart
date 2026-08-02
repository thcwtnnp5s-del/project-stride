import 'package:meta/meta.dart';

import 'content_id.dart';

/// A single problem found in content, with enough detail to fix it.
///
/// Every field exists because a content author needs it. An error that says
/// only "invalid reference" has told them nothing; one that names the file, the
/// entry, the field, what is wrong, and what would fix it can be acted on
/// without opening the loader.
@immutable
final class ValidationError implements Comparable<ValidationError> {
  const ValidationError({
    required this.sourceFile,
    required this.explanation,
    required this.suggestion,
    this.entryId,
    this.field,
  });

  /// The file the problem was found in.
  final String sourceFile;

  /// The entry's ID, where one could be read. Absent when the ID itself is the
  /// problem, or when the entry has no usable ID at all.
  final String? entryId;

  /// The field or reference at fault, e.g. `ingredients[1].item`.
  final String? field;

  /// What is wrong, in a sentence.
  final String explanation;

  /// What would fix it.
  final String suggestion;

  /// A stable sort key, so two runs over the same content report errors in the
  /// same order. Determinism applies to failure as well as success — a
  /// reordering diff in CI output is noise nobody should have to read past.
  String get _sortKey =>
      '$sourceFile|${entryId ?? ''}|${field ?? ''}|$explanation';

  @override
  int compareTo(ValidationError other) => _sortKey.compareTo(other._sortKey);

  /// A single human-readable line.
  String format() {
    final StringBuffer buffer = StringBuffer(sourceFile);
    if (entryId != null) buffer.write(' [$entryId]');
    if (field != null) buffer.write(' .$field');
    buffer.write(': $explanation');
    buffer.write('\n    fix: $suggestion');
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Everything wrong with a content bundle, collected in one pass.
///
/// Stopping at the first error would make fixing a bundle a sequence of
/// one-error rebuilds. Content is authored data; an author wants the whole list.
@immutable
final class ValidationReport {
  ValidationReport(List<ValidationError> errors)
    : errors = List<ValidationError>.unmodifiable(
        <ValidationError>[...errors]..sort(),
      );

  const ValidationReport.empty() : errors = const <ValidationError>[];

  final List<ValidationError> errors;

  bool get isValid => errors.isEmpty;
  bool get hasErrors => errors.isNotEmpty;

  ValidationReport merge(ValidationReport other) =>
      ValidationReport(<ValidationError>[...errors, ...other.errors]);

  /// The whole report, ready to print.
  String format() {
    if (isValid) return 'Content is valid.';
    final StringBuffer buffer = StringBuffer(
      '${errors.length} content validation '
      '${errors.length == 1 ? 'error' : 'errors'}:\n',
    );
    for (final ValidationError error in errors) {
      buffer.writeln('  - ${error.format()}');
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Thrown when content cannot be loaded at all.
///
/// Validation failures are a [ValidationReport], not an exception — the loader
/// returns them so a test can assert on the list. This is reserved for the case
/// where a caller demands a registry and the content cannot produce one.
final class ContentException implements Exception {
  ContentException(this.report);

  final ValidationReport report;

  @override
  String toString() => 'ContentException:\n${report.format()}';
}

/// Collects errors while validating, so a rule can report and continue.
final class ErrorCollector {
  final List<ValidationError> _errors = <ValidationError>[];

  List<ValidationError> get errors =>
      List<ValidationError>.unmodifiable(_errors);

  void add({
    required String sourceFile,
    required String explanation,
    required String suggestion,
    String? entryId,
    String? field,
  }) {
    _errors.add(
      ValidationError(
        sourceFile: sourceFile,
        entryId: entryId,
        field: field,
        explanation: explanation,
        suggestion: suggestion,
      ),
    );
  }

  /// Reports a reference to something that does not exist.
  void unknownReference({
    required String sourceFile,
    required String entryId,
    required String field,
    required String reference,
    required ContentNamespace expected,
    required Iterable<ContentId> known,
  }) {
    add(
      sourceFile: sourceFile,
      entryId: entryId,
      field: field,
      explanation: 'references "$reference", which is not defined',
      suggestion: _didYouMean(reference, known, expected),
    );
  }

  /// Offers the closest known ID, which is usually the typo the author made.
  static String _didYouMean(
    String reference,
    Iterable<ContentId> known,
    ContentNamespace expected,
  ) {
    final List<ContentId> candidates = known
        .where((ContentId id) => id.namespace == expected)
        .toList();
    if (candidates.isEmpty) {
      return 'define a ${expected.wire} with that ID, or correct the reference';
    }

    ContentId? best;
    int bestDistance = 1 << 30;
    for (final ContentId candidate in candidates) {
      final int distance = _editDistance(reference, candidate.value);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    // Only suggest a correction when it is close enough to be plausible.
    if (best != null && bestDistance <= 4) {
      return 'did you mean "${best.value}"? Otherwise define it, or correct '
          'the reference';
    }
    return 'define a ${expected.wire} with that ID, or correct the reference';
  }

  static int _editDistance(String a, String b) {
    final List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
    final List<int> current = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      current[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final int substitution =
            previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        final int deletion = previous[j] + 1;
        final int insertion = current[j - 1] + 1;
        current[j] = substitution < deletion
            ? (substitution < insertion ? substitution : insertion)
            : (deletion < insertion ? deletion : insertion);
      }
      previous.setAll(0, current);
    }
    return previous[b.length];
  }

  ValidationReport toReport() => ValidationReport(_errors);
}
