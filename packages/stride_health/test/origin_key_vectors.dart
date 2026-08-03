/// Cross-platform origin-keying test vectors.
///
/// ===========================================================================
/// Why these exist
/// ===========================================================================
///
/// Origin keying happens in Swift and Kotlin now, before the value crosses
/// Pigeon. That keeps every raw platform identifier inside its own process —
/// and it means the mapping is implemented **three times**: once in Dart as the
/// reference (`lib/src/origin_pseudonymizer.dart`), once in Swift, once in
/// Kotlin.
///
/// A divergence between any two of them is **silent and unbounded**. A re-keyed
/// origin has no `grantedSlices`, so its recent buckets look ungranted and the
/// whole retention window is granted a second time. Nothing detects that. It is
/// the one way this design can double-count, and it would present as "the game
/// gave me my steps twice", which nobody reports as a bug.
///
/// These vectors are the closest thing to a proof that is available.
/// **Every adapter must assert them**, and an adapter that cannot reproduce
/// them fails its own suite instead of a player's ledger.
///
/// ## What each case is for
///
/// | case | what it would catch |
/// |---|---|
/// | two Apple sources under one salt | the ordinary path, and that two sources on one device do not collide |
/// | an Android package name | UTF-8 handling of a longer identifier |
/// | a device display name | that a name keys like anything else — it must never be *sent*, but if one is, it must not survive recognisably |
/// | the empty identifier | zero bytes, not eight zero bytes: the wire's "no source reported" |
/// | the same source under a second salt | that the salt is actually mixed in, rather than a bare digest |
/// | a binary salt with high bytes | sign extension. Swift's `Int64` and Kotlin's `Long` are signed, and an arithmetic shift where an unsigned one belongs is the single likeliest native defect here |
/// | a one-byte salt | that the separator is present, so `salt‖id` cannot collide with `salt'‖id'` |
///
/// ## Regenerating
///
/// `dart run tool/genvec.dart` from `packages/stride_health`. Regenerate only
/// when the algorithm version changes — an unexplained change to these numbers
/// means the mapping moved, which means every origin on every installed device
/// re-keyed.
library;

/// One `(salt, identifier) -> key` case.
final class OriginKeyVector {
  const OriginKeyVector({
    required this.saltHex,
    required this.identifier,
    required this.expectedKeyHex,
  });

  /// The salt, hex-encoded. Hex rather than a string literal so a case can
  /// carry bytes no source encoding would survive.
  final String saltHex;

  /// The raw platform identifier the adapter would have read.
  final String identifier;

  /// The expected eight bytes, hex-encoded. Empty for the empty identifier,
  /// which is zero bytes on the wire.
  final String expectedKeyHex;
}

/// The algorithm these vectors describe.
///
/// Sent to native as `installOriginKeying(salt, algorithmVersion)`. If this
/// changes, so does every key on every device, and the change is a migration
/// rather than an edit.
const int originKeyVectorAlgorithmVersion = 1;

/// FNV-1a, 64-bit, over `salt || 0x1F || utf8(identifier)`, big-endian.
const List<OriginKeyVector> originKeyVectors = <OriginKeyVector>[
  OriginKeyVector(
    saltHex: '7374726964652d6465766963652d73616c742d30303031',
    identifier: 'com.apple.health',
    expectedKeyHex: '41091b752209a534',
  ),
  OriginKeyVector(
    saltHex: '7374726964652d6465766963652d73616c742d30303031',
    identifier: 'com.apple.health.watch',
    expectedKeyHex: 'f92ff88d6a645c0d',
  ),
  OriginKeyVector(
    saltHex: '7374726964652d6465766963652d73616c742d30303031',
    identifier: 'com.google.android.apps.fitness',
    expectedKeyHex: 'fb3c0df653b0346e',
  ),
  OriginKeyVector(
    saltHex: '7374726964652d6465766963652d73616c742d30303031',
    identifier: "Rob's iPhone",
    expectedKeyHex: 'dd8b33f7cf0c5a07',
  ),
  OriginKeyVector(
    saltHex: '7374726964652d6465766963652d73616c742d30303031',
    identifier: '',
    expectedKeyHex: '',
  ),
  OriginKeyVector(
    saltHex: '612d7365636f6e642d6465766963652d73616c742d3032',
    identifier: 'com.apple.health',
    expectedKeyHex: 'e902253f065cbd74',
  ),
  OriginKeyVector(
    saltHex: '0001fe7f80ff',
    identifier: 'com.projectstride.app',
    expectedKeyHex: 'd0253a7c10ac984d',
  ),
  OriginKeyVector(
    saltHex: '00',
    identifier: 'com.apple.health',
    expectedKeyHex: 'b203667f1b3d1569',
  ),
];
