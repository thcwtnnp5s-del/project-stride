/// CRC-32C (Castagnoli) over save bytes.
///
/// **The threat is corruption, not tampering.** The save lives in app-private
/// storage on the player's own device, there is no server, and any digest we
/// compute a save editor can recompute. Paying a `package:crypto` dependency —
/// in a package whose whole value proposition is having two — plus fifty times
/// the CPU, to buy tamper-evidence we cannot actually enforce, is the wrong
/// trade.
///
/// What this does buy: all single-bit errors, all burst errors up to 32 bits,
/// and — combined with the explicit length in the frame — every truncation.
/// That is the real failure set: interrupted writes, flash bit-rot, and bugs in
/// our own encoder.
///
/// **Never use `Object.hashAll` or `String.hashCode` for this.** Dart's hash
/// codes are not stable across VM versions or between JIT and AOT, so a save
/// written by a debug build would fail to verify in release.
///
/// Revisit if informal comparison between players ever becomes a feature; at
/// that point a save whose only guard is a CRC is trivially editable, and
/// retrofitting means a format bump.
library;

import 'dart:typed_data';

const int _polynomial = 0x82F63B78;

final Uint32List _table = _buildTable();

Uint32List _buildTable() {
  final Uint32List table = Uint32List(256);
  for (int i = 0; i < 256; i++) {
    int crc = i;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ _polynomial : crc >> 1;
    }
    table[i] = crc;
  }
  return table;
}

/// The CRC-32C of [bytes], optionally over the range \[start, end).
int crc32c(List<int> bytes, {int start = 0, int? end}) {
  final int stop = end ?? bytes.length;
  int crc = 0xFFFFFFFF;
  for (int i = start; i < stop; i++) {
    crc = _table[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// The CRC-32C of [bytes] as eight lowercase hex characters.
///
/// Fixed width, so a digest never changes length between saves and a
/// truncated frame line cannot be mistaken for a short digest.
String crc32cHex(List<int> bytes, {int start = 0, int? end}) =>
    crc32c(bytes, start: start, end: end).toRadixString(16).padLeft(8, '0');
