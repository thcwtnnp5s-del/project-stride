// The boundary where a device name stops existing.
//
// These tests are the enforcement of a privacy rule that is otherwise a
// convention. The strongest one is the last: a device name is not a
// representable StepOriginKey, so the rule cannot be forgotten — it can only
// be deliberately worked around, which is a reviewable act.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  final Uint8List salt = Uint8List.fromList(<int>[
    0x9a,
    0x41,
    0x0c,
    0xf7,
    0x22,
    0xbd,
    0x53,
    0x68,
  ]);
  final OriginPseudonymizer pseudonymizer = OriginPseudonymizer(salt);

  group('OriginPseudonymizer', () {
    test('a device name never survives the boundary', () {
      // This is the actual HKSource.name a player might have.
      const String deviceName = "Rob's iPhone";
      final StepOriginKey key = pseudonymizer.pseudonymize(deviceName);

      expect(key.value, isNot(contains('Rob')));
      expect(key.value, isNot(contains('iPhone')));
      expect(key.value.length, StepOriginKey.length);
      expect(
        RegExp(r'^[0-9a-f]{16}$').hasMatch(key.value),
        isTrue,
        reason: 'the key must be opaque hex, not a transformed name',
      );
    });

    test('a raw identifier cannot become an origin key by any other route', () {
      // The rule made structural. If this ever compiles, the privacy boundary
      // has become a convention again.
      expect(
        () => StepOriginKey("Rob's iPhone"),
        throwsA(isA<InvalidOriginKeyException>()),
      );
      expect(
        () => StepOriginKey('com.apple.health'),
        throwsA(isA<InvalidOriginKeyException>()),
      );
      expect(
        () => StepOriginKey('A1B2C3D4E5F60718'),
        throwsA(isA<InvalidOriginKeyException>()),
        reason: 'uppercase would give two keys for one device',
      );
    });

    test('the rejection carries a length, never the value', () {
      // An exception message is a diagnostic surface, and the rejected value
      // may be exactly the display name this type exists to keep out.
      try {
        StepOriginKey("Rob's iPhone");
        fail('expected a refusal');
      } on InvalidOriginKeyException catch (e) {
        expect(e.toString(), isNot(contains('Rob')));
        expect(e.toString(), isNot(contains('iPhone')));
        expect(e.length, "Rob's iPhone".length);
      }
    });

    test('the same identifier always gives the same key', () {
      // If it did not, a device would look new on every sync and its whole
      // retention window would be granted again.
      final StepOriginKey a = pseudonymizer.pseudonymize('com.apple.health');
      final StepOriginKey b = pseudonymizer.pseudonymize('com.apple.health');
      expect(a, b);
    });

    test('different identifiers give different keys', () {
      // A collision merges two devices into one bucket, which reads a genuine
      // second device as a correction and silently under-grants it.
      final Set<StepOriginKey> keys = <String>[
        'com.apple.health',
        'com.apple.watch',
        'com.google.android.apps.fitness',
        'Pixel 9',
        'Pixel 8',
      ].map(pseudonymizer.pseudonymize).toSet();

      expect(keys.length, 5);
    });

    test('a different salt gives a different key for the same device', () {
      // The mapping is meaningless outside this installation, which is the
      // whole point of keying it.
      final OriginPseudonymizer other = OriginPseudonymizer(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
      expect(
        pseudonymizer.pseudonymize('com.apple.health'),
        isNot(other.pseudonymize('com.apple.health')),
      );
    });

    test('an absent source becomes the reserved unknown key', () {
      expect(pseudonymizer.pseudonymize(''), StepOriginKey.unknown);
      expect(
        StepOriginKey.unknown.value,
        isNot(matches(RegExp(r'^[0-9a-f]{16}$'))),
        reason:
            'unknown must not be producible by the pseudonymizer, or a real '
            'source could collide with it',
      );
    });

    test('a salt round-trips through base64', () {
      final OriginPseudonymizer restored = OriginPseudonymizer.fromSalt(
        base64Encode(salt),
      );
      expect(
        restored.pseudonymize('com.apple.health'),
        pseudonymizer.pseudonymize('com.apple.health'),
      );
    });
  });

  group('salt loss', () {
    test('a changed salt is detectable before it is acted on', () {
      // A lost salt re-keys every origin, so recent buckets look ungranted and
      // would be granted a second time. Bounded by retention, but a real
      // double-grant — which is why a save records a fingerprint and a load
      // that cannot reproduce it fails closed.
      final String before = OriginSaltPolicy.fingerprint(salt);
      final String after = OriginSaltPolicy.fingerprint(
        Uint8List.fromList(<int>[...salt, 0x00]),
      );

      expect(before, isNot(after));
      expect(before.length, 16);
    });

    test('the fingerprint does not carry the salt', () {
      final String print = OriginSaltPolicy.fingerprint(salt);
      expect(print, isNot(contains(base64Encode(salt))));
      expect(
        print,
        matches(RegExp(r'^[0-9a-f]{16}$')),
        reason: 'a fingerprint that revealed the salt would let any reader '
            're-derive every origin mapping',
      );
    });
  });
}
