// The origin-privacy rule, asserted as behaviour rather than trusted as a
// convention.
//
// Keying happens in Swift and Kotlin now, so the Dart side's job is narrower
// and sharper than it was: **validate, decode, and refuse.** These tests cover
// that job, plus the reference implementation the two native ones must match.
//
// `Scripts/check-origin-privacy.sh` enforces the static half — that no raw
// identifier can be named anywhere in Dart, that no display-name API appears in
// native source, and that no platform value reaches a diagnostic. Both halves
// are needed: a static guard cannot prove the hash is keyed, and a behavioural
// test cannot prove nobody added a second call site.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'origin_key_vectors.dart';

const OriginGateway gateway = OriginGateway();
const int hour = 60 * 60 * 1000;
const int t0 = 1753401600000;

/// The values the owner's ruling names outright, plus the ones an obvious
/// implementation would reach for first.
const List<String> forbiddenShapes = <String>[
  "Rob's iPhone",
  'iPhone 15 Pro',
  'Apple Watch Series 9',
  'Pixel 8',
  'Google',
  'Samsung Health',
  'My Watch',
];

Uint8List unhex(String h) => Uint8List.fromList(<int>[
  for (int i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

String hex(Uint8List bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

PlatformStepObservation observation(Uint8List originKey) =>
    PlatformStepObservation(
      originKey: originKey,
      bucket: PlatformTimeBucket(startMillis: t0, endMillis: t0 + hour),
      steps: 1000,
    );

void main() {
  group('a display name cannot survive the boundary', () {
    test('no forbidden shape is a representable origin key', () {
      // The rule is structural, not a filter. `StepOriginKey` accepts sixteen
      // lowercase hex characters or the literal `unknown`, so "Rob's iPhone" is
      // not a value the type can hold — and sanitizing one into shape would
      // still be a key derived from a device name.
      for (final String name in forbiddenShapes) {
        expect(
          StepOriginKey.tryParse(name),
          isNull,
          reason: '$name must not be representable as an origin key',
        );
      }
    });

    test('a name that is not exactly eight bytes cannot reach the core', () {
      // The second control, and the one that is new: the platform contract has
      // no String origin field at all. A name would have to arrive as bytes,
      // and only two lengths are legal — eight, or zero.
      for (final String name in forbiddenShapes) {
        final Uint8List asBytes = Uint8List.fromList(utf8.encode(name));
        if (asBytes.length == OriginGateway.keyByteLength) continue;
        expect(
          gateway.decodeOrigin(asBytes),
          isNull,
          reason: '"$name" is ${asBytes.length} bytes and must be refused',
        );
      }
    });

    test('an eight-byte name DOES pass — the named limit of this control', () {
      // Honesty about what the width does not buy, kept as an executable fact
      // rather than a caveat in a comment.
      //
      // "My Watch" is exactly eight bytes. So are the first eight bytes of
      // "Rob's iPhone". The wire cannot tell eight bytes of digest from eight
      // bytes of anything else, so the length check stops a WHOLE identifier
      // travelling and cannot stop a short one or a prefix.
      //
      // What closes this gap is not on the Dart side at all: it is native
      // review, and `origin_key_vectors.dart`, which an adapter sending raw
      // bytes would fail. If this test ever starts failing, someone has made
      // the control stronger and should say how.
      for (final String eightByteName in <String>['My Watch']) {
        final Uint8List asBytes = Uint8List.fromList(
          utf8.encode(eightByteName),
        );
        expect(asBytes, hasLength(OriginGateway.keyByteLength));
        expect(gateway.decodeOrigin(asBytes), isNotNull);
      }

      final Uint8List truncated = Uint8List.fromList(
        utf8.encode("Rob's iPhone").take(8).toList(),
      );
      expect(gateway.decodeOrigin(truncated), isNotNull);
      expect(gateway.decodeOrigin(truncated)!.value, hasLength(16));
    });
  });

  group('the gateway validates and refuses', () {
    test('eight bytes become sixteen lowercase hex characters', () {
      final StepOriginKey origin = gateway.decodeOrigin(
        unhex('41091b752209a534'),
      )!;

      expect(origin.value, '41091b752209a534');
      expect(origin.value, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('zero bytes is the reserved unknown origin', () {
      expect(gateway.decodeOrigin(Uint8List(0)), StepOriginKey.unknown);
      // Reserved and deliberately not hex, so the keying function can never
      // produce it and confuse it with a real source.
      expect(
        StepOriginKey.unknown.value,
        isNot(matches(RegExp(r'^[0-9a-f]+$'))),
      );
    });

    test('any other length is refused', () {
      for (final int length in <int>[1, 2, 3, 4, 5, 6, 7, 9, 12, 16, 64]) {
        expect(
          gateway.decodeOrigin(Uint8List(length)),
          isNull,
          reason: '$length bytes is not an origin key',
        );
      }
    });

    test('a malformed observation is null, never a throw', () {
      // An adapter fault is a condition the game survives. The caller refuses
      // the whole page rather than partially accepting it, so nothing can be
      // settled over a dropped slice.
      expect(gateway.toObservation(observation(Uint8List(5))), isNull);
    });

    test('a scope naming an undecodable origin is refused whole', () {
      expect(
        gateway.toScope(
          PlatformOriginScope(
            kind: PlatformOriginScopeKind.someOrigins,
            originKeys: <Uint8List>[unhex('41091b752209a534'), Uint8List(3)],
          ),
        ),
        isNull,
      );
    });
  });

  group('the reference implementation the native ones must match', () {
    test('every cross-platform vector reproduces exactly', () {
      // A divergence between Dart, Swift, and Kotlin is silent and unbounded:
      // a re-keyed origin looks exactly like a new device, its recent buckets
      // look ungranted, and the retention window is granted a second time.
      // These vectors are the closest thing to a proof that is available, and
      // both native suites must assert the same numbers.
      for (final OriginKeyVector vector in originKeyVectors) {
        final Uint8List actual = OriginPseudonymizer(
          unhex(vector.saltHex),
        ).keyBytes(vector.identifier);

        expect(
          hex(actual),
          vector.expectedKeyHex,
          reason:
              'salt ${vector.saltHex} + "${vector.identifier}" must key to '
              '${vector.expectedKeyHex}. A change here re-keys every origin on '
              'every installed device.',
        );
      }
    });

    test('the empty identifier is zero bytes, not eight zero bytes', () {
      final Uint8List key = OriginPseudonymizer(
        Uint8List.fromList(<int>[1, 2, 3]),
      ).keyBytes('');

      expect(key, isEmpty);
      // Eight zero bytes would be an ordinary key the hash could produce, and
      // conflating the two would make "no source" collide with a real one.
      expect(gateway.decodeOrigin(Uint8List(8)), isNot(StepOriginKey.unknown));
    });

    test('a high-bit hash renders unsigned', () {
      // Half of all 64-bit hashes have the top bit set. Dart's int is signed,
      // Swift's Int64 is signed, Kotlin's Long is signed, and an arithmetic
      // shift in any of the three produces a stable, self-consistent, and
      // completely different key. At least one vector exercises this; assert
      // the property directly too.
      for (final OriginKeyVector vector in originKeyVectors) {
        if (vector.expectedKeyHex.isEmpty) continue;
        final Uint8List key = OriginPseudonymizer(
          unhex(vector.saltHex),
        ).keyBytes(vector.identifier);
        expect(key, hasLength(8));
        for (final int byte in key) {
          expect(byte, inInclusiveRange(0, 255));
        }
      }
    });

    test('a different salt gives a different key', () {
      // What makes the mapping meaningless outside this installation. An
      // unkeyed digest of a package name is trivially reversible by anyone with
      // a list of package names, which is everyone.
      final Uint8List a = OriginPseudonymizer(
        unhex(originKeyVectors[0].saltHex),
      ).keyBytes('com.apple.health');
      final Uint8List b = OriginPseudonymizer(
        unhex(originKeyVectors[5].saltHex),
      ).keyBytes('com.apple.health');

      expect(hex(a), isNot(hex(b)));
    });

    test('the algorithm version is pinned to the vectors', () {
      // A silent version drift would produce keys nothing else on the device
      // agrees with — indistinguishable from a new device.
      expect(originKeyingAlgorithmVersion, originKeyVectorAlgorithmVersion);
    });
  });

  group('nothing retains a raw value', () {
    test('an origin key stringifies to the pseudonym', () {
      final StepObservation converted = gateway.toObservation(
        observation(unhex('dd8b33f7cf0c5a07')),
      )!;

      // `toString` is a diagnostic surface. Everything reachable from an
      // observation must be safe to print.
      expect(converted.toString(), contains('dd8b33f7cf0c5a07'));
      expect(converted.key.origin.toString(), converted.key.origin.value);
    });

    test('a refused key reports its length, not its value', () {
      // An exception message is a diagnostic surface, and the rejected value
      // may be exactly the display name this type exists to keep out.
      try {
        StepOriginKey("Rob's iPhone");
        fail('a device name must not be accepted as an origin key');
      } on InvalidOriginKeyException catch (e) {
        expect(e.toString(), isNot(contains('Rob')));
        expect(e.length, "Rob's iPhone".length);
        expect(e.refusal, OriginKeyRefusal.wrongLength);
      }

      // And a name that happens to be the right LENGTH is refused on its
      // alphabet, with the same silence about its content. This is the refusal
      // that fires for a device name, and it must never be "handled" by
      // sanitizing the input — a sanitized device name is still derived from a
      // device name.
      try {
        StepOriginKey('MyPhoneIsCalled!');
        fail('a sixteen-character name must not be accepted either');
      } on InvalidOriginKeyException catch (e) {
        expect(e.toString(), isNot(contains('Phone')));
        expect(e.refusal, OriginKeyRefusal.notLowercaseHex);
      }
    });

    test('a sync fault is a category and carries no payload', () {
      // Faults are the bridge's diagnostic channel. If one could carry the
      // offending value, the diagnostic channel would be the leak.
      for (final SyncFault fault in SyncFault.values) {
        expect(fault.toString(), startsWith('SyncFault.'));
      }
    });
  });

  group('fail-closed', () {
    test('an empty salt is refused before the channel is touched', () {
      // A launch that could not resolve the identity has already been blocked
      // by BootstrapCoordinator with originIdentityMissing. This is the same
      // refusal made unavoidable at the only entry point that exists.
      expect(
        PlatformStepSource.open(salt: Uint8List(0)),
        completion(
          isA<OriginKeyingInstall>()
              .having(
                (OriginKeyingInstall i) => i.isInstalled,
                'isInstalled',
                isFalse,
              )
              .having(
                (OriginKeyingInstall i) => i.refusal,
                'refusal',
                OriginKeyingRefusal.emptySalt,
              ),
        ),
      );
    });

    test('the salt fingerprint is not the salt', () {
      // The fingerprint reaches the save envelope; the salt does not, because a
      // reader holding the salt could re-derive every origin mapping the save
      // contains.
      final Uint8List salt = unhex(originKeyVectors[0].saltHex);
      final String fingerprint = OriginSaltPolicy.fingerprint(salt);

      expect(fingerprint, hasLength(16));
      expect(fingerprint, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(fingerprint, isNot(base64Encode(salt)));
      expect(
        OriginSaltPolicy.fingerprint(unhex(originKeyVectors[5].saltHex)),
        isNot(fingerprint),
      );
    });
  });
}
