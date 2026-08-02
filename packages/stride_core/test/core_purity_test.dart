// The architectural boundary, enforced.
//
// stride_core must not depend on Flutter, a plugin, the file system, or the
// clock. This is not purity for its own sake: it keeps the simulation testable
// in milliseconds on Windows with no emulator, keeps balance work independent
// of the UI, and means a future port re-implements a specified system rather
// than reverse-engineering one out of view code.
//
// The same rule is enforced by Scripts/check-core-purity.sh for pre-commit and
// CI. Both read StrideCore.forbiddenImports, so the rule and its guards cannot
// drift apart.
//
// See DECISIONS/0010_CROSS_PLATFORM_STACK.md.

import 'dart:io';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

/// Locates `lib/` relative to this test file, so the check works from any
/// working directory and on any machine.
Directory get _libDirectory {
  final Uri here = Platform.script.resolve('.');
  // Prefer the package root discovered from the current directory, which is
  // where `dart test` runs from.
  final Directory candidate = Directory('lib');
  if (candidate.existsSync()) return candidate;
  return Directory.fromUri(here.resolve('../lib'));
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

/// Matches real import and export directives, not the text appearing in a
/// comment or a string literal.
List<String> importedUris(String source) {
  final RegExp directive = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  return directive
      .allMatches(source)
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}

void main() {
  group('stride_core purity', () {
    test('lib directory is discoverable', () {
      final List<File> files = _dartFiles(_libDirectory);
      // A silently empty scan would let this suite pass while checking nothing.
      expect(
        files,
        isNotEmpty,
        reason: 'No Dart sources found under ${_libDirectory.path}',
      );
    });

    test('no source imports a forbidden library', () {
      final List<String> violations = <String>[];

      for (final File file in _dartFiles(_libDirectory)) {
        for (final String uri in importedUris(file.readAsStringSync())) {
          for (final String forbidden in StrideCore.forbiddenImports) {
            final bool hit = forbidden.endsWith('/')
                ? uri.startsWith(forbidden)
                : uri == forbidden;
            if (hit) violations.add('${file.path}: $uri');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'stride_core must not import Flutter, plugins, dart:ui, or '
            'dart:io.\n${violations.join('\n')}\n\n'
            'Fix by defining a port in lib/src/ports/ and implementing it in '
            'the app or in stride_health. Do not relax this rule.',
      );
    });

    test('the detector recognizes a violation', () {
      // Guards against the check silently breaking and passing forever.
      const String sample = '''
// A comment mentioning package:flutter/material.dart must not trigger this.
const name = 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
export 'package:stride_health/stride_health.dart';
''';
      final List<String> uris = importedUris(sample);

      expect(uris, contains('dart:async'));
      expect(uris, contains('package:flutter/material.dart'));
      expect(uris, contains('package:stride_health/stride_health.dart'));
      expect(
        uris.length,
        3,
        reason: 'A comment or string literal was read as a directive',
      );

      final List<String> caught = uris
          .where(
            (String u) => StrideCore.forbiddenImports.any(
              (String f) => f.endsWith('/') ? u.startsWith(f) : u == f,
            ),
          )
          .toList();
      expect(caught, hasLength(2));
    });

    test('forbidden list is populated', () {
      // An empty list would make the purity test pass vacuously.
      expect(StrideCore.forbiddenImports.length, greaterThanOrEqualTo(5));
      expect(StrideCore.forbiddenImports, contains('package:flutter/'));
      expect(StrideCore.forbiddenImports, contains('dart:io'));
    });
  });
}
