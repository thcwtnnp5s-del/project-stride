/// The origin boundary: opaque bytes in, a validated [StepOriginKey] out.
///
/// ===========================================================================
/// Where pseudonymization happens, and why it is not here
/// ===========================================================================
///
/// **In native code, before the value crosses Pigeon.** Owner ruling. The raw
/// `HKSource.bundleIdentifier` or `dataOrigin.packageName` exists inside one
/// Swift or Kotlin function call and never reaches Dart at all — there is no
/// field on the platform contract that could carry one.
///
/// An earlier draft of this file did the keying itself, on the argument that
/// one Dart implementation cannot diverge from itself while two native ones
/// can. That argument is still true and is now a **named residual risk** rather
/// than a design: Swift and Kotlin must each implement FNV-1a over
/// `salt || 0x1F || utf8(identifier)` identically, and a divergence is silent
/// because a re-keyed origin looks exactly like a new device. Two things bound
/// it — `algorithmVersion` on `HealthHostApi.installOriginKeying`, which turns a
/// version mismatch into a typed refusal, and `test/origin_key_vectors.dart`,
/// which both native suites must reproduce byte for byte.
///
/// What the ruling buys in exchange is larger: a raw identifier crosses the
/// boundary once per observation — thousands of times a day — while the salt
/// crosses once per engine attachment. Fewer crossings of the more sensitive
/// value. And a leaked salt costs a fail-closed refusal, which is recoverable;
/// a leaked device name is not.
///
/// ===========================================================================
/// What this class does instead
/// ===========================================================================
///
/// It validates. Eight bytes become sixteen lowercase hex characters and then a
/// `StepOriginKey`; zero bytes become `StepOriginKey.unknown`; **anything else
/// refuses the whole page.**
///
/// That length check is the only thing standing between a truncated raw string
/// and the ledger. A native adapter that put the first eight characters of
/// "Rob's iPhone" in the field would pass it — the wire cannot tell eight bytes
/// of digest from eight bytes of anything — which is exactly why the check is
/// strict about the two legal lengths and why native origin derivation stays a
/// standing review obligation rather than a solved problem.
library;

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import 'messages.g.dart';

/// Converts the platform's opaque origin bytes into core origin keys.
///
/// Stateless. It holds no salt, because it does no keying: the salt lives in
/// `IdentityVault` and is handed to native once, through
/// `PlatformStepSource.open`.
final class OriginGateway {
  const OriginGateway();

  /// The number of bytes in a keyed origin. 64 bits.
  ///
  /// Wide enough that two origins on one device will not collide; narrow
  /// enough that the save stays small. There is no need for collision
  /// resistance against an adversary — the only reader is this device.
  static const int keyByteLength = 8;

  /// Decodes one origin, or null when the bytes are not a legal key.
  ///
  /// Zero bytes is the platform reporting no source at all, which becomes the
  /// reserved [StepOriginKey.unknown] — deliberately not hex, so the keying
  /// function can never produce it and confuse it with a real source.
  StepOriginKey? decodeOrigin(Uint8List bytes) {
    if (bytes.isEmpty) return StepOriginKey.unknown;
    if (bytes.length != keyByteLength) return null;

    final StringBuffer hex = StringBuffer();
    for (final int byte in bytes) {
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    // tryParse rather than the throwing constructor: a malformed key is an
    // adapter fault the game must survive, and the caller refuses the page.
    return StepOriginKey.tryParse(hex.toString());
  }

  /// Converts one platform observation into a core observation.
  ///
  /// Returns null when the observation is malformed — an illegal origin key, a
  /// non-positive bucket, a bucket narrower than
  /// [TimeBucket.minimumWidthMillis], or a negative count. Null rather than a
  /// throw because an adapter fault is a condition the game must survive; the
  /// caller refuses the whole page rather than partially accepting it, so
  /// nothing can be settled over a dropped slice.
  StepObservation? toObservation(PlatformStepObservation platform) {
    final StepOriginKey? origin = decodeOrigin(platform.originKey);
    if (origin == null) return null;

    final int start = platform.bucket.startMillis;
    final int end = platform.bucket.endMillis;
    if (end <= start) return null;
    if (end - start < TimeBucket.minimumWidthMillis) return null;
    if (platform.steps < 0) return null;

    return StepObservation(
      key: ObservationKey(
        origin: origin,
        bucket: TimeBucket(startMillis: start, endMillis: end),
      ),
      steps: platform.steps,
    );
  }

  /// Converts a completeness scope's origin list.
  ///
  /// Returns null when any named origin is malformed. A scope that vouches for
  /// a source nobody can identify is not a narrower assertion, it is an
  /// unusable one, and settling against it would settle the wrong buckets.
  ///
  /// A scope that claims [PlatformOriginScopeKind.allOrigins] while naming
  /// sources is contradictory and is narrowed to the named set rather than
  /// widened: a narrower scope settles fewer buckets, and under-settling costs
  /// a little ledger growth while over-settling costs a grant permanently.
  OriginScope? toScope(PlatformOriginScope platform) {
    final Set<StepOriginKey> named = <StepOriginKey>{};
    for (final Uint8List bytes in platform.originKeys) {
      final StepOriginKey? origin = decodeOrigin(bytes);
      if (origin == null) return null;
      named.add(origin);
    }
    if (platform.kind == PlatformOriginScopeKind.allOrigins && named.isEmpty) {
      return const AllOrigins();
    }
    return SomeOrigins(named);
  }

  /// True when [platform] claims to speak for every source but names some.
  ///
  /// Reported as a fault by the bridge so an adapter bug is visible rather than
  /// merely absorbed by [toScope]'s narrowing.
  static bool scopeIsContradictory(PlatformOriginScope platform) =>
      platform.kind == PlatformOriginScopeKind.allOrigins &&
      platform.originKeys.isNotEmpty;
}
