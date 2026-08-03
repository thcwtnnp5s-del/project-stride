/// Loader for the CANONICAL cross-platform origin-key fixture.
///
/// ===========================================================================
/// This file holds no expected values
/// ===========================================================================
///
/// It parses `test_fixtures/origin_key_vectors.json`, which Swift and Kotlin
/// read as well. That is the whole design: **one fixture, three readers.**
///
/// It used to hold the vectors as Dart literals, which meant Swift and Kotlin
/// would each need a transcribed copy. Three hand-maintained copies is three
/// chances to drift, and a drift here is silent and unbounded — origin keying
/// happens natively now, once in Swift and once in Kotlin, against a Dart
/// reference implementation. A re-keyed origin has no `grantedSlices`, so its
/// recent buckets look ungranted and the entire retention window is granted a
/// second time. Nothing downstream detects it, and it reaches the player as
/// "the game gave me my steps twice", which nobody reports as a bug.
///
/// So: if you find yourself typing an expected hex value into a test in any
/// language, stop. Read the JSON.
///
/// Regenerate with `dart run tool/genvec.dart` from `packages/stride_health`,
/// and only when the algorithm version changes — an unexplained change to
/// these numbers is a migration, not an edit.
library;

import 'dart:convert';
import 'dart:io';

/// One `(salt, identifier) -> key` case.
final class OriginKeyVector {
  const OriginKeyVector({
    required this.saltHex,
    required this.identifier,
    required this.expectedKeyHex,
    required this.why,
    this.rawUtf8Hex,
    this.rawUtf8PrefixHex,
    this.rawUtf8ZeroPaddedHex,
  });

  /// The salt, hex-encoded. Hex rather than a string literal so a case can
  /// carry bytes no source encoding would survive.
  final String saltHex;

  /// The raw platform identifier the adapter would have read.
  final String identifier;

  /// The expected eight bytes, hex-encoded. Empty for the empty identifier,
  /// which is zero bytes on the wire.
  final String expectedKeyHex;

  /// What this case would catch.
  final String why;

  /// Negative fixtures only — the raw UTF-8 of [identifier], and the two
  /// obvious wrong answers.
  ///
  /// Present so a test can assert the key is **none of them**. Eight bytes of
  /// output is not evidence of hashing: `My Watch` is exactly eight bytes of
  /// UTF-8, so an implementation that returned the raw bytes would pass a
  /// width check.
  final String? rawUtf8Hex;
  final String? rawUtf8PrefixHex;
  final String? rawUtf8ZeroPaddedHex;
}

Map<String, Object?> _load() {
  // Resolved relative to the package root, which is the working directory for
  // both `dart test` and `flutter test` here.
  for (final String candidate in <String>[
    'test_fixtures/origin_key_vectors.json',
    '../test_fixtures/origin_key_vectors.json',
  ]) {
    final File f = File(candidate);
    if (f.existsSync()) {
      return jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    }
  }
  throw StateError(
    'canonical origin-key fixture not found. Run '
    '`dart run tool/genvec.dart` from packages/stride_health. It must not be '
    'reconstructed by hand — Swift and Kotlin read the same file.',
  );
}

final Map<String, Object?> _doc = _load();

OriginKeyVector _vector(Map<String, Object?> j) => OriginKeyVector(
  saltHex: j['saltHex']! as String,
  identifier: j['identifier']! as String,
  expectedKeyHex: j['expectedKeyHex']! as String,
  why: j['why']! as String,
  rawUtf8Hex: j['rawUtf8Hex'] as String?,
  rawUtf8PrefixHex: j['rawUtf8PrefixHex'] as String?,
  rawUtf8ZeroPaddedHex: j['rawUtf8ZeroPaddedHex'] as String?,
);

/// The algorithm the fixture describes.
///
/// Sent to native as `installOriginKeying(salt, algorithmVersion)`. If this
/// changes, so does every key on every device.
final int originKeyVectorAlgorithmVersion = _doc['algorithmVersion']! as int;

/// FNV-1a, 64-bit, over `salt || 0x1F || utf8(identifier)`, big-endian.
final List<OriginKeyVector> originKeyVectors =
    List<OriginKeyVector>.unmodifiable(
      (_doc['vectors']! as List<Object?>).cast<Map<String, Object?>>().map(
        _vector,
      ),
    );

/// Identifiers at or below the key width.
///
/// These are the ones that prove the output is a hash rather than the bytes:
/// each carries [OriginKeyVector.rawUtf8Hex] plus the prefix and zero-padded
/// forms, so a test can assert the key equals none of them.
final List<OriginKeyVector> originKeyNegativeVectors =
    List<OriginKeyVector>.unmodifiable(
      (_doc['negativePrivacyVectors']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(_vector),
    );
