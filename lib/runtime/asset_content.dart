/// Reads the content pack out of the Flutter asset bundle.
///
/// This is the *only* place `rootBundle` is mentioned. `stride_core` takes a
/// `ContentSource` — a map of filename to text — so the loader never learns
/// what an asset is, never enumerates a directory, and stays testable with
/// fabricated content.
///
/// The manifest below is hand-written and must match `pubspec.yaml`. That
/// duplication is deliberate: a directory glob would silently ship whatever
/// someone dropped in, and an asset the loader is not handed is content that
/// does not exist. A mismatch fails loudly at startup rather than producing a
/// registry that is quietly missing a file.
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:stride_core/stride_core.dart';

/// The versioned content pack this build ships.
///
/// The version lives in the path so a v2 pack can ship beside v1 rather than
/// replacing it — which is what makes a content migration reviewable.
const String contentPackDirectory = 'assets/content/v1';

/// Every file in the pack, in the order they are declared in `pubspec.yaml`.
const List<String> contentPackFiles = <String>[
  'enemies.json',
  'items.json',
  'locations.json',
  'profiles.json',
  'recipes.json',
  'resource_nodes.json',
  'skills.json',
];

/// Thrown when an asset cannot be read.
///
/// Named separately from a content *validation* failure: a missing asset is a
/// packaging fault, and the fix is in `pubspec.yaml` rather than in the JSON.
final class ContentAssetException implements Exception {
  const ContentAssetException(this.filename, this.cause);

  final String filename;
  final Object cause;

  @override
  String toString() =>
      'ContentAssetException: could not read $filename from the asset bundle. '
      'Is it declared under `flutter: assets:` in pubspec.yaml? ($cause)';
}

/// Loads the content pack into a platform-neutral [ContentSource].
Future<ContentSource> loadContentFromAssets({AssetBundle? bundle}) async {
  final AssetBundle assets = bundle ?? rootBundle;
  final Map<String, String> files = <String, String>{};

  for (final String filename in contentPackFiles) {
    try {
      files[filename] = await assets.loadString(
        '$contentPackDirectory/$filename',
      );
    } on Object catch (e) {
      // Rethrown as a typed error rather than allowed to surface as a raw
      // asset exception, so the bootstrap can report "content is invalid"
      // rather than something about a bundle the player has never heard of.
      throw ContentAssetException(filename, e);
    }
  }

  return ContentSource(files);
}
