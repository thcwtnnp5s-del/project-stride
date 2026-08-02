/// A pseudonymous, validated identifier for whatever wrote a step sample.
///
/// This type exists to make a privacy rule *structural* rather than a
/// convention. The owner's ruling forbids persisting device names, source
/// display names, `HKSource.name`, or any raw platform identifier. A free-form
/// `String` cannot enforce that — and the obvious iOS implementation of the
/// field it replaced was `HKSource.name`, which is a device name, which a
/// player may have called anything at all.
///
/// So the accepted shape is deliberately narrow: sixteen lowercase hex
/// characters, or the reserved literal `unknown`. "Rob's iPhone" is not a
/// representable value. Neither is a bundle identifier, a UUID with dashes, or
/// anything a human would recognise.
///
/// The mapping from a platform identifier to a key belongs to the adapter, in
/// `stride_health`, behind `OriginPseudonymizer`. **No raw platform identifier
/// crosses into `stride_core`.**
///
/// The narrow alphabet also removes a serialization hazard: no separator
/// character, no non-ASCII, nothing that could split or merge a key on
/// round-trip and silently re-grant or under-grant a device's window.
library;

import 'package:meta/meta.dart';

/// Why a candidate origin key was refused.
enum OriginKeyRefusal {
  /// Empty string.
  empty,

  /// Not the required length.
  wrongLength,

  /// Contains something outside `[0-9a-f]`.
  ///
  /// This is the one that fires for a device name, and it must never be
  /// "handled" by sanitizing the input — a sanitized device name is still
  /// derived from a device name.
  notLowercaseHex,
}

/// Thrown when a raw string cannot become a [StepOriginKey].
final class InvalidOriginKeyException implements Exception {
  const InvalidOriginKeyException(this.refusal, this.length);

  final OriginKeyRefusal refusal;

  /// The rejected value's *length* only. The value itself is never retained,
  /// because it may be exactly the display name this type exists to keep out,
  /// and an exception message is a diagnostic surface.
  final int length;

  @override
  String toString() =>
      'InvalidOriginKeyException: ${refusal.name} (length $length). '
      'Origin keys are 16 lowercase hex characters, produced by the adapter '
      'pseudonymizer. A raw platform identifier must never reach the core.';
}

/// A pseudonymous origin identifier.
@immutable
final class StepOriginKey implements Comparable<StepOriginKey> {
  /// Validates [value] and throws [InvalidOriginKeyException] if it is not a
  /// well-formed key.
  factory StepOriginKey(String value) {
    final OriginKeyRefusal? refusal = validate(value);
    if (refusal != null) {
      throw InvalidOriginKeyException(refusal, value.length);
    }
    return StepOriginKey._(value);
  }

  const StepOriginKey._(this.value);

  /// The number of hex characters in a key.
  ///
  /// 16 hex characters is 64 bits. Wide enough that two origins on one device
  /// will not collide; narrow enough that the save stays small. There is no
  /// need for collision resistance against an adversary — the only reader is
  /// this device.
  static const int length = 16;

  /// Used when a platform reports no origin at all.
  ///
  /// Reserved, and deliberately not hex, so it can never be produced by the
  /// pseudonymizer and confused with a real source.
  static const StepOriginKey unknown = StepOriginKey._('unknown');

  /// The pseudonymous key. Never a name, never a raw platform identifier.
  final String value;

  /// Returns null when [value] is acceptable, or the reason it is not.
  ///
  /// Exposed so an adapter can check without building an exception, and so the
  /// privacy tests can assert the rule directly.
  static OriginKeyRefusal? validate(String value) {
    if (value == unknown.value) return null;
    if (value.isEmpty) return OriginKeyRefusal.empty;
    if (value.length != length) return OriginKeyRefusal.wrongLength;
    for (int i = 0; i < value.length; i++) {
      final int c = value.codeUnitAt(i);
      final bool isDigit = c >= 0x30 && c <= 0x39;
      final bool isLowerHex = c >= 0x61 && c <= 0x66;
      if (!isDigit && !isLowerHex) return OriginKeyRefusal.notLowercaseHex;
    }
    return null;
  }

  /// Parses without throwing. Null when [value] is not a valid key.
  static StepOriginKey? tryParse(String value) =>
      validate(value) == null ? StepOriginKey._(value) : null;

  @override
  int compareTo(StepOriginKey other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is StepOriginKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
