// Regenerates test/origin_key_vectors.dart. Not shipped; not analyzed as
// production code.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';
import 'package:stride_health/src/origin_pseudonymizer.dart';

Uint8List unhex(String h) => Uint8List.fromList(<int>[
  for (int i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

void main() {
  final List<List<String>> cases = <List<String>>[
    <String>[
      '7374726964652d6465766963652d73616c742d30303031',
      'com.apple.health',
    ],
    <String>[
      '7374726964652d6465766963652d73616c742d30303031',
      'com.apple.health.watch',
    ],
    <String>[
      '7374726964652d6465766963652d73616c742d30303031',
      'com.google.android.apps.fitness',
    ],
    <String>['7374726964652d6465766963652d73616c742d30303031', "Rob's iPhone"],
    <String>['7374726964652d6465766963652d73616c742d30303031', ''],
    <String>[
      '612d7365636f6e642d6465766963652d73616c742d3032',
      'com.apple.health',
    ],
    <String>['0001fe7f80ff', 'com.projectstride.app'],
    <String>['00', 'com.apple.health'],
  ];
  for (final List<String> c in cases) {
    final Uint8List key = OriginPseudonymizer(unhex(c[0])).keyBytes(c[1]);
    print(
      "  OriginKeyVector(saltHex: '${c[0]}', identifier: '''${c[1]}''', expectedKeyHex: '${key.map((int b) => b.toRadixString(16).padLeft(2, '0')).join()}'),",
    );
  }
  // sanity: utf8 of the ascii salts
  assert(utf8.encode('x').isNotEmpty);
}
