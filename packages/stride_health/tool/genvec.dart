// Regenerates the CANONICAL origin-key fixture:
//
//   test_fixtures/origin_key_vectors.json
//
// That JSON is the single source of truth for Dart, Swift and Kotlin. None of
// the three may transcribe the expected bytes into its own test: three
// hand-maintained copies is three chances to drift, and a drift here is silent
// and unbounded. A re-keyed origin has no `grantedSlices`, so its recent
// buckets look ungranted and the whole retention window is granted a second
// time — which presents as "the game gave me my steps twice", and nobody
// reports that as a bug.
//
// Regenerate ONLY when the algorithm version changes. An unexplained change to
// these numbers means the mapping moved, which means every origin on every
// installed device re-keyed: a migration, not an edit.
//
//   dart run tool/genvec.dart      (from packages/stride_health)
//
// Not shipped; not analyzed as production code.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_health/src/origin_pseudonymizer.dart';

Uint8List unhex(String h) => Uint8List.fromList(<int>[
  for (int i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

String hex(List<int> b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

const String saltA = '7374726964652d6465766963652d73616c742d30303031';
const String saltB = '612d7365636f6e642d6465766963652d73616c742d3032';

/// `(saltHex, identifier, why)`.
const List<List<String>> positive = <List<String>>[
  <String>[saltA, 'com.apple.health', 'the ordinary Apple source'],
  <String>[
    saltA,
    'com.apple.health.watch',
    'a second source on one device must not collide with the first',
  ],
  <String>[
    saltA,
    'com.google.android.apps.fitness',
    'UTF-8 handling of a longer identifier',
  ],
  <String>[
    saltA,
    "Rob's iPhone",
    'a display name keys like anything else. It must never be SENT, but if one '
        'ever is, it must not survive recognisably',
  ],
  <String>[
    saltA,
    '',
    'the empty identifier is ZERO bytes on the wire, not eight zero bytes',
  ],
  <String>[
    saltB,
    'com.apple.health',
    'the same source under a second salt must key differently, or the salt is '
        'not mixed in and this is a bare digest',
  ],
  <String>[
    '0001fe7f80ff',
    'com.projectstride.app',
    'a salt with high bytes. Swift Int64 and Kotlin Long are signed, and an '
        'arithmetic shift where a logical one belongs is the likeliest native '
        'defect here',
  ],
  <String>[
    '00',
    'com.apple.health',
    'a one-byte salt, so the separator must be present: salt||id must not be '
        'able to collide with salt2||id2',
  ],
];

/// Identifiers whose UTF-8 is at or below the key width.
///
/// `My Watch` and `iPhone12` are EXACTLY eight bytes, which is the point:
/// eight bytes of output is not evidence of hashing. These carry the raw UTF-8
/// and its 8-byte prefix so a test can assert the key is **none of them** —
/// not the raw bytes, not a prefix, not a truncation, not a padding.
const List<List<String>> negative = <List<String>>[
  <String>[saltA, 'My Watch', 'exactly 8 bytes of UTF-8'],
  <String>[saltA, 'iPhone12', 'exactly 8 bytes, alphanumeric'],
  <String>[saltA, 'phone', '5 bytes — shorter than the key width'],
  <String>[saltA, 'Watch', '5 bytes'],
];

Map<String, Object?> caseFor(List<String> c, {required bool isNegative}) {
  final Uint8List salt = unhex(c[0]);
  final String identifier = c[1];
  final Uint8List key = OriginPseudonymizer(salt).keyBytes(identifier);
  final List<int> raw = utf8.encode(identifier);

  final Map<String, Object?> out = <String, Object?>{
    'saltHex': c[0],
    'identifier': identifier,
    'expectedKeyHex': hex(key),
    'why': c[2],
  };

  if (isNegative) {
    out['rawUtf8Hex'] = hex(raw);
    // First min(8, len) bytes, so a prefix implementation is detectable
    // whether the identifier is longer or shorter than the key.
    out['rawUtf8PrefixHex'] = hex(raw.take(8).toList());
    // Right-padded to the key width, which is the other obvious wrong answer
    // for an identifier shorter than eight bytes.
    out['rawUtf8ZeroPaddedHex'] = hex(<int>[
      ...raw.take(8),
      ...List<int>.filled(raw.length >= 8 ? 0 : 8 - raw.length, 0),
    ]);
  }
  return out;
}

void main() {
  final Map<String, Object?> doc = <String, Object?>{
    'README':
        'CANONICAL origin-key vectors. Dart, Swift and Kotlin all read THIS '
        'file at test time. Do not transcribe these values into a test in any '
        'language: three copies is three chances to drift, and a drift '
        're-keys every origin and re-grants the retention window silently. '
        'Regenerate with `dart run tool/genvec.dart` from '
        'packages/stride_health.',
    'algorithm':
        'FNV-1a 64-bit over salt || 0x1F || utf8(identifier), big-endian, '
        '8 bytes. The empty identifier yields ZERO bytes, not eight zeroes.',
    'algorithmVersion': originKeyingAlgorithmVersion,
    'keyLengthBytes': 8,
    'coreKeyFormat': '16 lowercase hexadecimal characters',
    'vectors': <Map<String, Object?>>[
      for (final List<String> c in positive) caseFor(c, isNegative: false),
    ],
    'negativePrivacyVectors': <Map<String, Object?>>[
      for (final List<String> c in negative) caseFor(c, isNegative: true),
    ],
  };

  final File out = File('test_fixtures/origin_key_vectors.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(doc)}\n');
  print('wrote ${out.path}');
  print('  ${positive.length} vectors, ${negative.length} negative fixtures');
}
