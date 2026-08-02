/// One journal record: the durable intent for a single transaction.
///
/// A record is **all-or-nothing**. The batch's events go in one framed line
/// with one digest, so no crash can commit "the slice was granted" without
/// "the player was credited" — those are two different events, and F-05 is
/// precisely what puts a disk between them.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../engine/events.dart';
import 'crc32c.dart';
import 'event_codec.dart';
import 'save_codec.dart';

/// A durable transaction record.
final class JournalRecord {
  const JournalRecord({
    required this.formatVersion,
    required this.saveId,
    required this.transactionId,
    required this.eventSequenceBefore,
    required this.eventSequenceAfter,
    required this.events,
  });

  final int formatVersion;

  /// Lineage. A record from a different save is never applied.
  final String saveId;

  /// Monotonic and gap-free from 1. Counts durable commits, **not** events —
  /// one commit carries several events, and conflating the two makes that
  /// inexpressible.
  final int transactionId;

  final int eventSequenceBefore;
  final int eventSequenceAfter;
  final List<GameEvent> events;
}

/// Why a journal line could not be read.
enum JournalLineFault {
  malformedEncoding,
  integrityMismatch,
  unsupportedFormat,
}

/// A parsed line, or the fault that rejected it.
final class JournalLineResult {
  const JournalLineResult.ok(this.record) : fault = null;
  const JournalLineResult.failed(this.fault) : record = null;

  final JournalRecord? record;
  final JournalLineFault? fault;

  bool get ok => fault == null;
}

/// Encodes a record as `<crc32c-hex-8> <canonical-json>\n`.
///
/// Space-delimited with the digest **outside** the object it covers — a digest
/// field inside the object would be self-referential. Canonical JSON escapes
/// `\n` inside strings, so a raw newline can never appear in the payload and
/// line splitting is unambiguous.
Uint8List encodeJournalLine(JournalRecord record) {
  final Map<String, Object?> body = <String, Object?>{
    'f': record.formatVersion,
    'saveId': record.saveId,
    'tx': record.transactionId,
    'eventSeqBefore': record.eventSequenceBefore,
    'eventSeqAfter': record.eventSequenceAfter,
    'events': <Object?>[
      for (final GameEvent e in record.events) encodeEvent(e),
    ],
  };
  final List<int> json = utf8.encode(canonicalJson(body));
  return Uint8List.fromList(<int>[
    ...utf8.encode('${crc32cHex(json)} '),
    ...json,
    0x0A,
  ]);
}

/// Parses one line. Never throws for a corrupt line.
JournalLineResult decodeJournalLine(Uint8List line) {
  // A line without its terminator is a torn tail. The caller decides whether
  // that is benign (trailing) or a storage failure (interior); this only
  // reports that it did not parse.
  List<int> body = line;
  if (body.isNotEmpty && body.last == 0x0A) {
    body = body.sublist(0, body.length - 1);
  }

  final int space = body.indexOf(0x20);
  if (space != 8) {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }

  final String digest;
  try {
    digest = utf8.decode(body.sublist(0, space));
  } on FormatException {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }

  final List<int> json = body.sublist(space + 1);
  if (crc32cHex(json) != digest) {
    return const JournalLineResult.failed(JournalLineFault.integrityMismatch);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(json));
  } on FormatException {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }
  if (decoded is! Map<String, Object?>) {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }

  final Object? format = decoded['f'];
  if (format is! int) {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }
  if (format > SaveFormatVersion.current) {
    return const JournalLineResult.failed(JournalLineFault.unsupportedFormat);
  }

  final Object? saveId = decoded['saveId'];
  final Object? tx = decoded['tx'];
  final Object? before = decoded['eventSeqBefore'];
  final Object? after = decoded['eventSeqAfter'];
  final Object? events = decoded['events'];
  if (saveId is! String ||
      tx is! int ||
      before is! int ||
      after is! int ||
      events is! List<Object?>) {
    return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
  }

  final List<GameEvent> parsed = <GameEvent>[];
  for (final Object? raw in events) {
    if (raw is! Map<String, Object?>) {
      return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
    }
    final GameEvent? event = decodeEvent(raw);
    if (event == null) {
      return const JournalLineResult.failed(JournalLineFault.malformedEncoding);
    }
    parsed.add(event);
  }

  return JournalLineResult.ok(
    JournalRecord(
      formatVersion: format,
      saveId: saveId,
      transactionId: tx,
      eventSequenceBefore: before,
      eventSequenceAfter: after,
      events: parsed,
    ),
  );
}
