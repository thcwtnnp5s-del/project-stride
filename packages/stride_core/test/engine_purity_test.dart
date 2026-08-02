// Static guarantees about the engine's inputs.
//
// The behavioural determinism tests prove two runs agree. These prove *why*:
// the ambient sources that could make them disagree are not referenced at all.
//
// A behavioural test can pass by luck — a clock read that happens to fall in
// the same millisecond, a random draw that happens to repeat. A source scan
// cannot.

import 'dart:io';

import 'package:test/test.dart';

/// Dart sources under `lib/`, excluding generated files.
List<File> _libSources() {
  for (final String candidate in <String>['lib', '../lib']) {
    final Directory directory = Directory(candidate);
    if (!directory.existsSync()) continue;
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
  }
  throw StateError('Could not locate lib/ from ${Directory.current.path}');
}

/// Strips comments and string literals, so a rule discussed in prose is not
/// mistaken for a rule broken in code.
String _codeOnly(String source) => source
    .replaceAll(RegExp(r'///.*'), '')
    .replaceAll(RegExp(r'//.*'), '')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
    .replaceAll(RegExp(r'"""[\s\S]*?"""'), '""')
    .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
    .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""');

void main() {
  group('no ambient inputs', () {
    /// Anything that would make the same state and commands produce a
    /// different answer depending on when or where the code ran.
    const Map<String, String> forbidden = <String, String>{
      r'DateTime\.now': 'reads the wall clock',
      r'DateTime\.timestamp': 'reads the wall clock',
      r'Stopwatch\(': 'measures elapsed real time',
      r'\bRandom\(': 'draws ambient randomness',
      r'Zone\.current': 'reads ambient context',
      r'Platform\.': 'reads the platform',
      r'Intl\b': 'reads the locale',
      r'\.timeZoneName': 'reads the timezone',
      r'\.timeZoneOffset': 'reads the timezone',
      r'localeName': 'reads the locale',
    };

    test('the engine reads no clock, randomness, locale, or platform', () {
      final List<String> violations = <String>[];

      for (final File file in _libSources()) {
        final String code = _codeOnly(file.readAsStringSync());
        for (final MapEntry<String, String> rule in forbidden.entries) {
          if (!RegExp(rule.key).hasMatch(code)) continue;
          violations.add(
            '${file.uri.pathSegments.last}: matches /${rule.key}/ — '
            '${rule.value}',
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'stride_core must produce the same result from the same inputs, '
            'whenever and wherever it runs.\n${violations.join('\n')}\n\n'
            'If a future feature genuinely needs time or randomness, inject it '
            'explicitly so that "what happened" stays a function of state and '
            'commands. Wall-clock progression is forbidden outright — see '
            'DECISIONS/0001_PROGRESSION_CLOCK.md.',
      );
    });

    test('the detector recognises a violation', () {
      // Guards against the scan silently breaking and passing forever.
      const String sample = '''
// A comment mentioning DateTime.now must not trigger this.
const note = 'Random(';
final t = DateTime.now();
''';
      final String code = _codeOnly(sample);

      expect(RegExp(r'DateTime\.now').hasMatch(code), isTrue);
      expect(
        RegExp(r'\bRandom\(').hasMatch(code),
        isFalse,
        reason: 'a string literal was read as code',
      );
    });

    test('the scan actually covers the engine', () {
      // An empty or misdirected scan would pass vacuously.
      final List<String> names = _libSources()
          .map((File f) => f.uri.pathSegments.last)
          .toList();

      expect(names, contains('game_engine.dart'));
      expect(names, contains('event_reducer.dart'));
      expect(names, contains('game_state.dart'));
      expect(names.length, greaterThanOrEqualTo(12));
    });
  });
}
