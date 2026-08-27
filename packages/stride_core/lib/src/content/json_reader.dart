import 'content_id.dart';
import 'validation.dart';

/// Reads fields out of decoded JSON, reporting problems instead of throwing.
///
/// Every accessor returns a usable fallback on failure and records an error, so
/// one malformed entry does not hide the twenty after it. That is what makes
/// "collect all practical errors in one pass" achievable rather than aspirational.
final class JsonReader {
  JsonReader({
    required this.map,
    required this.sourceFile,
    required this.collector,
    this.entryId,
  });

  final Map<String, Object?> map;
  final String sourceFile;
  final ErrorCollector collector;
  final String? entryId;

  /// True when every access so far succeeded. An entry that failed a required
  /// field is not added to the registry — a half-built definition would
  /// produce confusing downstream errors about fields the author never wrote.
  bool get isComplete => _complete;
  bool _complete = true;

  void _fail(String field, String explanation, String suggestion) {
    _complete = false;
    collector.add(
      sourceFile: sourceFile,
      entryId: entryId,
      field: field,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  String requireString(String field) {
    final Object? raw = map[field];
    if (raw == null) {
      _fail(
        field,
        'the required field "$field" is missing',
        'add `"$field": "…"`',
      );
      return '';
    }
    if (raw is! String) {
      _fail(
        field,
        'expected text, found ${raw.runtimeType}',
        'quote the value, e.g. `"$field": "example"`',
      );
      return '';
    }
    if (raw.trim().isEmpty) {
      _fail(field, '"$field" is empty', 'give it a value, or remove the field');
      return '';
    }
    return raw;
  }

  int requireInt(String field, {int? min, int? max}) {
    final Object? raw = map[field];
    if (raw == null) {
      _fail(
        field,
        'the required field "$field" is missing',
        'add `"$field": 0`',
      );
      return min ?? 0;
    }
    if (raw is! int) {
      _fail(
        field,
        'expected a whole number, found ${raw.runtimeType} ($raw)',
        'write it unquoted and without a decimal point, e.g. `"$field": 10`',
      );
      return min ?? 0;
    }
    if (min != null && raw < min) {
      _fail(
        field,
        '$raw is below the allowed minimum of $min',
        'use a value of at least $min',
      );
      return min;
    }
    if (max != null && raw > max) {
      _fail(
        field,
        '$raw is above the allowed maximum of $max',
        'use a value of at most $max',
      );
      return max;
    }
    return raw;
  }

  int optionalInt(String field, {int fallback = 0, int? min, int? max}) {
    if (!map.containsKey(field)) return fallback;
    return requireInt(field, min: min, max: max);
  }

  String optionalString(String field, {String fallback = ''}) {
    if (!map.containsKey(field)) return fallback;
    return requireString(field);
  }

  bool optionalBool(String field, {bool fallback = false}) {
    final Object? raw = map[field];
    if (raw == null) return fallback;
    if (raw is! bool) {
      _fail(
        field,
        'expected true or false, found ${raw.runtimeType} ($raw)',
        'write `"$field": true` or `"$field": false`',
      );
      return fallback;
    }
    return raw;
  }

  /// Reads a value constrained to a fixed set, e.g. an item category.
  T requireEnum<T>(String field, Map<String, T> allowed) {
    final String raw = requireString(field);
    if (raw.isEmpty) return allowed.values.first;
    final T? value = allowed[raw];
    if (value == null) {
      _fail(
        field,
        '"$raw" is not a recognised value',
        'use one of: ${allowed.keys.join(', ')}',
      );
      return allowed.values.first;
    }
    return value;
  }

  /// Reads an ID, checking syntax and namespace.
  ContentId requireId(String field, ContentNamespace expected) {
    final String raw = requireString(field);
    if (raw.isEmpty) return ContentId.unchecked('${expected.wire}.placeholder');

    final ContentIdParse parsed = ContentId.parse(raw);
    final ContentId? id = parsed.id;
    if (id == null) {
      _fail(field, parsed.explanation, parsed.suggestion);
      return ContentId.unchecked('${expected.wire}.placeholder');
    }
    if (id.namespace != expected) {
      _fail(
        field,
        'expected a ${expected.wire} identifier, found "${id.value}"',
        'use an ID in the ${expected.wire} namespace, '
            'e.g. `${expected.wire}.${id.slug}`',
      );
      return ContentId.unchecked('${expected.wire}.placeholder');
    }
    return id;
  }

  ContentId? optionalId(String field, ContentNamespace expected) {
    if (!map.containsKey(field) || map[field] == null) return null;
    return requireId(field, expected);
  }

  List<ContentId> idList(String field, ContentNamespace expected) {
    final Object? raw = map[field];
    if (raw == null) return const <ContentId>[];
    if (raw is! List) {
      _fail(
        field,
        'expected a list, found ${raw.runtimeType}',
        'write it as an array, e.g. `"$field": ["${expected.wire}.example"]`',
      );
      return const <ContentId>[];
    }

    final List<ContentId> result = <ContentId>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? element = raw[i];
      if (element is! String) {
        _fail(
          '$field[$i]',
          'expected an identifier, found ${element.runtimeType}',
          'write the ID as a quoted string',
        );
        continue;
      }
      final ContentIdParse parsed = ContentId.parse(element);
      final ContentId? id = parsed.id;
      if (id == null) {
        _fail('$field[$i]', parsed.explanation, parsed.suggestion);
        continue;
      }
      if (id.namespace != expected) {
        _fail(
          '$field[$i]',
          'expected a ${expected.wire} identifier, found "${id.value}"',
          'use an ID in the ${expected.wire} namespace',
        );
        continue;
      }
      result.add(id);
    }
    return result;
  }

  List<int> intList(String field, {int? min}) {
    final Object? raw = map[field];
    if (raw == null) {
      _fail(
        field,
        'the required field "$field" is missing',
        'add `"$field": [ … ]`',
      );
      return const <int>[];
    }
    if (raw is! List) {
      _fail(
        field,
        'expected a list of numbers, found ${raw.runtimeType}',
        'write it as an array, e.g. `"$field": [0, 100, 250]`',
      );
      return const <int>[];
    }

    final List<int> result = <int>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? element = raw[i];
      if (element is! int) {
        _fail(
          '$field[$i]',
          'expected a whole number, found ${element.runtimeType}',
          'write it unquoted and without a decimal point',
        );
        continue;
      }
      if (min != null && element < min) {
        _fail(
          '$field[$i]',
          '$element is below the allowed minimum of $min',
          'use a value of at least $min',
        );
        continue;
      }
      result.add(element);
    }
    return result;
  }

  /// Reads a list of nested objects, e.g. ingredients or drops.
  List<T> objectList<T>(
    String field,
    T? Function(JsonReader reader, int index) build,
  ) {
    final Object? raw = map[field];
    if (raw == null) return <T>[];
    if (raw is! List) {
      _fail(
        field,
        'expected a list, found ${raw.runtimeType}',
        'write it as an array of objects',
      );
      return <T>[];
    }

    final List<T> result = <T>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? element = raw[i];
      if (element is! Map) {
        _fail(
          '$field[$i]',
          'expected an object, found ${element.runtimeType}',
          'write it as `{ … }`',
        );
        continue;
      }
      final JsonReader nested = JsonReader(
        map: element.cast<String, Object?>(),
        sourceFile: sourceFile,
        collector: collector,
        entryId: entryId,
      );
      final T? built = build(nested, i);
      if (!nested.isComplete) _complete = false;
      if (built != null) result.add(built);
    }
    return result;
  }

  /// Flags fields the schema does not define.
  ///
  /// A typo'd optional field would otherwise be silently ignored — the author
  /// writes `"stackable"` as `"stackible"` and the game quietly disagrees with
  /// them forever.
  void rejectUnknownFields(Set<String> known) {
    final List<String> unknown =
        map.keys.where((String k) => !known.contains(k)).toList()..sort();
    for (final String key in unknown) {
      _fail(
        key,
        'unknown field "$key"',
        'remove it, or check the spelling. Known fields: '
            '${(known.toList()..sort()).join(', ')}',
      );
    }
  }
}
