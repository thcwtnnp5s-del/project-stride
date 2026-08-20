// Test-only helpers for loading content from disk.
//
// `dart:io` lives here, in test/, and never in lib/ — the core itself must not
// touch the file system (DECISIONS/0010). That is why ContentSource takes a map
// of already-read text rather than a directory.

import 'dart:io';

import 'package:stride_core/stride_core.dart';

/// The production content directory, resolved relative to this package.
Directory get productionContentDirectory {
  for (final String candidate in <String>[
    '../../assets/content/v1',
    'assets/content/v1',
  ]) {
    final Directory directory = Directory(candidate);
    if (directory.existsSync()) return directory;
  }
  throw StateError(
    'Could not locate assets/content/v1 from ${Directory.current.path}. '
    'Run tests from packages/stride_core or the repository root.',
  );
}

Directory get fixtureDirectory {
  for (final String candidate in <String>['test/fixtures', 'fixtures']) {
    final Directory directory = Directory(candidate);
    if (directory.existsSync()) return directory;
  }
  throw StateError(
    'Could not locate test/fixtures from ${Directory.current.path}.',
  );
}

/// Reads every `.json` file in [directory] into a source.
///
/// Filenames only — no paths — so a fixture and a production file are
/// interchangeable, and so error messages name something an author recognises.
ContentSource readDirectory(Directory directory) {
  final Map<String, String> files = <String, String>{};
  for (final FileSystemEntity entity in directory.listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    files[entity.uri.pathSegments.last] = entity.readAsStringSync();
  }
  if (files.isEmpty) {
    throw StateError('No JSON content found in ${directory.path}');
  }
  return ContentSource(files);
}

/// The production bundle.
ContentSource get productionSource => readDirectory(productionContentDirectory);

/// The production bundle with one file replaced by a broken fixture.
///
/// A fixture breaks exactly one file and inherits every other, so a test
/// exercises one rule against otherwise-real content.
///
/// Fixtures are generated from production by `Scripts/generate-fixtures.js`,
/// which applies a single mutation. Hand-written stubs were tried first and
/// were a mistake: a stub silently deletes every entry it omits, so one broken
/// field cascaded into a page of unrelated reference errors and the test
/// stopped demonstrating the rule it was named for.
ContentSource productionWithOverride(String fixtureFilename) {
  final File fixture = File('${fixtureDirectory.path}/$fixtureFilename');
  if (!fixture.existsSync()) {
    throw StateError('Missing fixture: ${fixture.path}');
  }

  final Map<String, String> files = Map<String, String>.of(
    productionSource.files,
  );
  final String text = fixture.readAsStringSync();

  // A fixture normally replaces the production file of its kind, so it must
  // restate that file completely — otherwise every entry it omits vanishes and
  // one broken field cascades into a page of unrelated reference errors.
  //
  // A fixture marked `"standalone": true` is added as an extra file instead.
  // That is for failures which reject the whole file, such as an unsupported
  // schema version: replacing production content with one of those would
  // delete the file rather than break one thing in it.
  final bool standalone = text.contains('"standalone": true');
  final String target = standalone
      ? fixtureFilename
      : (_targetFileFor(text) ?? fixtureFilename);
  files[target] = text;
  return ContentSource(files);
}

String? _targetFileFor(String json) {
  const Map<String, String> kindToFile = <String, String>{
    'items': 'items.json',
    'skills': 'skills.json',
    'locations': 'locations.json',
    'resource_nodes': 'resource_nodes.json',
    'recipes': 'recipes.json',
    'enemies': 'enemies.json',
    'contracts': 'contracts.json',
    'projects': 'projects.json',
    'rumors': 'rumors.json',
    'profiles': 'profiles.json',
  };
  for (final MapEntry<String, String> entry in kindToFile.entries) {
    if (json.contains('"kind": "${entry.key}"')) return entry.value;
  }
  return null;
}

/// Loads content under the production profile.
ContentLoadResult loadProduction(ContentSource source) =>
    const ContentLoader().load(source, profileId: BalanceProfile.productionId);

/// True when any error mentions [needle], searching every field.
bool reports(ValidationReport report, String needle) => report.errors.any(
  (ValidationError e) =>
      e.explanation.contains(needle) ||
      e.suggestion.contains(needle) ||
      (e.field?.contains(needle) ?? false) ||
      (e.entryId?.contains(needle) ?? false),
);
