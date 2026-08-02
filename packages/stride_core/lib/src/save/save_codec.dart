/// Canonical encoding of a [GameState] and its save envelope.
///
/// Two rules govern everything here.
///
/// **Canonical.** Keys sorted, no insignificant whitespace, integers emitted as
/// integers, enums as stable wire strings rather than `index`. The same state
/// must produce the same bytes on every platform and every Dart version, or
/// the digest is meaningless and `encode(decode(x)) == x` cannot be asserted.
///
/// **Structural.** An [ObservationKey] is encoded as three separate fields, not
/// as `toString()`. An origin key concatenated with a bucket can split on a
/// separator or merge after normalization; a split key re-grants a whole
/// window, a merged one silently under-grants a real second device.
/// `StepOriginKey` already forbids the characters that would do it — this is
/// the second lock on the same door.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../content/schema_version.dart';
import '../engine/game_state.dart';
import '../engine/state_version.dart';
import '../steps/step_ledger.dart';
import '../steps/step_origin_key.dart';
import '../steps/sync_batch.dart';
import 'crc32c.dart';

/// The framing and envelope shape. Independent of [StateVersion].
final class SaveFormatVersion {
  const SaveFormatVersion._();

  static const int current = 1;
  static const int minimumSupported = 1;
}

/// Thrown only for a programming error, never for a corrupt save.
///
/// A corrupt save is an outcome, not an exception. This fires when the *code*
/// is wrong — an unencodable value, a decoder handed a shape it declared it
/// could read.
final class SaveCodecException implements Exception {
  const SaveCodecException(this.message);
  final String message;

  @override
  String toString() => 'SaveCodecException: $message';
}

/// A decoded save envelope, before content validation.
final class SaveEnvelope {
  const SaveEnvelope({
    required this.saveFormatVersion,
    required this.gameStateVersion,
    required this.contentSchemaVersion,
    required this.balanceProfileId,
    required this.saveId,
    required this.snapshotGeneration,
    required this.lastAppliedTransaction,
    required this.eventSequence,
    required this.commitComplete,
    required this.state,
    this.originSaltFingerprint,
  });

  final int saveFormatVersion;
  final int gameStateVersion;
  final int contentSchemaVersion;

  /// **Authoritative.** The save's profile governs how it loads, regardless of
  /// the app's current default. Silently reinterpreting a save under another
  /// profile is how compressed QA pacing reaches a production character.
  final String balanceProfileId;

  /// Opaque lineage identifier, minted by the app at new-game time.
  ///
  /// The core cannot generate one — no clock, no randomness. It only compares.
  final String saveId;

  /// Monotonic, +1 per snapshot write. Selects the live slot.
  final int snapshotGeneration;

  /// The journal transaction this snapshot has absorbed. 0 at genesis.
  final int lastAppliedTransaction;

  /// Mirrors `state.eventSequence`, at envelope level, so lineage continuity
  /// is checkable before the full state is constructed.
  final int eventSequence;

  /// The internally-validated commit-complete marker.
  ///
  /// Written last within the payload. A slot whose payload parses but whose
  /// marker is absent was interrupted mid-encode and is not a candidate,
  /// even if its digest happens to verify.
  final bool commitComplete;

  /// Fingerprint of the salt that produced this save's origin keys, or null if
  /// no health source has been read yet.
  ///
  /// A changed salt re-keys every origin, so every device looks new and the
  /// whole live retention window would be granted a second time. Comparing
  /// this is what turns that into a refusal rather than a silent double-grant.
  final String? originSaltFingerprint;

  final GameState state;
}

// --- canonical JSON -------------------------------------------------------

/// Encodes [value] with object keys in sorted order and no whitespace.
String canonicalJson(Object? value) {
  final StringBuffer out = StringBuffer();
  _writeCanonical(out, value);
  return out.toString();
}

void _writeCanonical(StringBuffer out, Object? value) {
  switch (value) {
    case null:
      out.write('null');
    case final bool b:
      out.write(b ? 'true' : 'false');
    case final int i:
      out.write(i.toString());
    case double _:
      // A step count that round-trips as 1.0 becomes a type error on load.
      throw const SaveCodecException(
        'doubles are not encodable in a save; every quantity is an integer',
      );
    case final String s:
      out.write(jsonEncode(s));
    case final List<Object?> list:
      out.write('[');
      for (int i = 0; i < list.length; i++) {
        if (i > 0) out.write(',');
        _writeCanonical(out, list[i]);
      }
      out.write(']');
    case final Map<String, Object?> map:
      final List<String> keys = map.keys.toList()..sort();
      out.write('{');
      for (int i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _writeCanonical(out, map[keys[i]]);
      }
      out.write('}');
    default:
      throw SaveCodecException('unencodable type ${value.runtimeType}');
  }
}

// --- state <-> json -------------------------------------------------------

/// Encodes [state] to a canonical JSON tree.
Map<String, Object?> encodeGameState(GameState state) => <String, Object?>{
  'stateVersion': state.stateVersion,
  'profileId': state.profileId.value,
  'contentPackVersion': state.contentPackVersion,
  'eventSequence': state.eventSequence,
  'player': <String, Object?>{
    'level': state.player.level,
    'experience': state.player.experience,
  },
  'inventory': _encodeIdCounts(state.inventory.counts),
  'equipment': <String, Object?>{
    for (final MapEntry<EquipmentSlot, ContentId> e in _sortedByKeyName(
      state.equipment.bySlot,
    ))
      e.key.name: e.value.value,
  },
  'skills': _encodeIdCounts(state.skills.experienceBySkill),
  'world': <String, Object?>{
    'currentLocation': state.world.currentLocation.value,
    'unlockedLocations':
        state.world.unlockedLocations.map((ContentId id) => id.value).toList()
          ..sort(),
  },
  'steps': encodeStepLedger(state.steps),
};

List<Object?> _encodeIdCounts(Map<ContentId, int> counts) {
  final List<MapEntry<ContentId, int>> entries = counts.entries.toList()
    ..sort(
      (MapEntry<ContentId, int> a, MapEntry<ContentId, int> b) =>
          a.key.value.compareTo(b.key.value),
    );
  return <Object?>[
    for (final MapEntry<ContentId, int> e in entries)
      <String, Object?>{'id': e.key.value, 'n': e.value},
  ];
}

List<MapEntry<EquipmentSlot, ContentId>> _sortedByKeyName(
  Map<EquipmentSlot, ContentId> map,
) => map.entries.toList()
  ..sort(
    (
      MapEntry<EquipmentSlot, ContentId> a,
      MapEntry<EquipmentSlot, ContentId> b,
    ) => a.key.name.compareTo(b.key.name),
  );

/// Encodes the step ledger.
///
/// `grantedSlices` is a discrete sub-object on purpose: if the retention shape
/// is ever narrowed further, that is a change to one encoder and one decoder
/// rather than a change to the save's whole geometry.
Map<String, Object?> encodeStepLedger(StepLedger ledger) => <String, Object?>{
  'totalObserved': ledger.totalObserved,
  'totalGranted': ledger.totalGranted,
  'totalSpent': ledger.totalSpent,
  'grantedBeforeWatermark': ledger.grantedBeforeWatermark,
  'correctionsObserved': ledger.correctionsObserved,
  'unreachableGapEvents': ledger.unreachableGapEvents,
  'lateDiscardedSlices': ledger.lateDiscardedSlices,
  'sourceState': ledger.sourceState.name,
  'checkpoint': <String, Object?>{
    'cursor': ledger.checkpoint.cursor == null
        ? null
        : base64Encode(ledger.checkpoint.cursor!.bytes),
    'watermarkMillis': ledger.checkpoint.watermarkMillis,
    'syncCount': ledger.checkpoint.syncCount,
  },
  'recovery': <String, Object?>{
    'phase': ledger.recovery.phase.name,
    'windowStartMillis': ledger.recovery.windowStartMillis,
    'windowEndMillis': ledger.recovery.windowEndMillis,
    'truncated': ledger.recovery.truncated,
    'attempts': ledger.recovery.attempts,
  },
  'grantedSlices': _encodeSlices(ledger.grantedSlices),
};

/// Slices as a sorted list of structural records.
///
/// `{"o": key, "s": start, "e": end, "g": granted}` — never a composite string.
List<Object?> _encodeSlices(Map<ObservationKey, int> slices) {
  final List<MapEntry<ObservationKey, int>> entries = slices.entries.toList()
    ..sort((MapEntry<ObservationKey, int> a, MapEntry<ObservationKey, int> b) {
      final int byOrigin = a.key.origin.compareTo(b.key.origin);
      if (byOrigin != 0) return byOrigin;
      final int byStart = a.key.bucket.startMillis.compareTo(
        b.key.bucket.startMillis,
      );
      if (byStart != 0) return byStart;
      return a.key.bucket.endMillis.compareTo(b.key.bucket.endMillis);
    });
  return <Object?>[
    for (final MapEntry<ObservationKey, int> e in entries)
      <String, Object?>{
        'o': e.key.origin.value,
        's': e.key.bucket.startMillis,
        'e': e.key.bucket.endMillis,
        'g': e.value,
      },
  ];
}

// --- framing --------------------------------------------------------------

/// The framing line prefix, so a save file is identifiable without parsing.
const String saveMagic = 'stride.save';

/// Frames [payload] with its magic, format version, length, and digest.
///
/// The length lives in the frame so **truncation is distinguishable from
/// corruption without parsing anything**. Corruption that still parses is the
/// case a naive integrity test misses entirely.
Uint8List frame(Uint8List payload) {
  final Map<String, Object?> header = <String, Object?>{
    'm': saveMagic,
    'f': SaveFormatVersion.current,
    'len': payload.length,
    'crc': crc32cHex(payload),
  };
  final List<int> headerBytes = utf8.encode(canonicalJson(header));
  return Uint8List.fromList(<int>[...headerBytes, 0x0A, ...payload]);
}

/// What was wrong with a framed artifact, or null if it verified.
enum FrameFault {
  malformedEncoding,
  futureFormat,
  truncated,
  integrityMismatch,
}

/// The verified payload of a framed artifact, or the fault that rejected it.
final class FrameResult {
  const FrameResult.ok(this.payload) : fault = null;
  const FrameResult.failed(this.fault) : payload = null;

  final Uint8List? payload;
  final FrameFault? fault;

  bool get verified => fault == null;
}

/// Verifies framing, length, and digest — in that order.
///
/// The order is what produces distinct diagnoses. Checking the digest first
/// would report every truncation as corruption, and the two call for different
/// recovery.
FrameResult unframe(Uint8List bytes) {
  final int newline = bytes.indexOf(0x0A);
  if (newline <= 0) {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }

  final Object? header;
  try {
    header = jsonDecode(utf8.decode(bytes.sublist(0, newline)));
  } on FormatException {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }
  if (header is! Map<String, Object?> || header['m'] != saveMagic) {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }

  final Object? format = header['f'];
  if (format is! int) {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }
  // Refused before decoding anything: a newer build's payload is not ours to
  // interpret, and a partial interpretation is worse than a clean refusal.
  if (format > SaveFormatVersion.current) {
    return const FrameResult.failed(FrameFault.futureFormat);
  }

  final Object? length = header['len'];
  final Object? digest = header['crc'];
  if (length is! int || digest is! String) {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }

  final int available = bytes.length - newline - 1;
  if (available < length) return const FrameResult.failed(FrameFault.truncated);
  if (available > length) {
    return const FrameResult.failed(FrameFault.malformedEncoding);
  }

  final Uint8List payload = Uint8List.sublistView(bytes, newline + 1);
  if (crc32cHex(payload) != digest) {
    return const FrameResult.failed(FrameFault.integrityMismatch);
  }
  return FrameResult.ok(payload);
}

// --- envelope -------------------------------------------------------------

/// Encodes a complete, framed snapshot.
Uint8List encodeSnapshot({
  required GameState state,
  required String saveId,
  required int generation,
  required int lastAppliedTransaction,
  String? originSaltFingerprint,
}) {
  final Map<String, Object?> envelope = <String, Object?>{
    'saveFormatVersion': SaveFormatVersion.current,
    'gameStateVersion': state.stateVersion,
    'contentSchemaVersion': state.contentPackVersion,
    'balanceProfileId': state.profileId.value,
    'saveId': saveId,
    'snapshotGeneration': generation,
    'lastAppliedTransaction': lastAppliedTransaction,
    'eventSequence': state.eventSequence,
    // Omitted entirely when absent rather than written as null. A save with no
    // health source has no salt, and an explicit null would be a field whose
    // meaning is "this was deliberately nothing" — which is not what it means.
    // It also keeps saves written before this field existed byte-identical.
    'originSaltFingerprint': ?originSaltFingerprint,
    'state': encodeGameState(state),
    // Last field written, and validated on load. A payload that parses without
    // it was interrupted mid-encode.
    'commitComplete': true,
  };
  return frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));
}

/// Decodes a verified payload into an envelope, or throws [SaveCodecException]
/// with the offending field path.
///
/// Callers convert that into a typed refusal; it is an exception here only
/// because a field path is far easier to produce at the point of failure than
/// to thread back up through twenty return values.
SaveEnvelope decodeEnvelope(Uint8List payload) {
  final Object? root;
  try {
    root = jsonDecode(utf8.decode(payload));
  } on FormatException catch (e) {
    throw SaveCodecException('payload is not JSON: $e');
  }
  if (root is! Map<String, Object?>) {
    throw const SaveCodecException('payload root is not an object');
  }

  int intAt(String key) {
    final Object? v = root is Map<String, Object?> ? root[key] : null;
    if (v is! int) throw SaveCodecException('$key is not an integer');
    return v;
  }

  String stringAt(String key) {
    final Object? v = root is Map<String, Object?> ? root[key] : null;
    if (v is! String) throw SaveCodecException('$key is not a string');
    return v;
  }

  final Object? stateJson = root['state'];
  if (stateJson is! Map<String, Object?>) {
    throw const SaveCodecException('state is not an object');
  }

  final int stateVersion = intAt('gameStateVersion');
  final StateDecoder? decoder = StateCodecs.decoderFor(stateVersion);
  if (decoder == null) {
    throw SaveCodecException('no decoder for gameStateVersion $stateVersion');
  }

  return SaveEnvelope(
    saveFormatVersion: intAt('saveFormatVersion'),
    gameStateVersion: stateVersion,
    contentSchemaVersion: intAt('contentSchemaVersion'),
    balanceProfileId: stringAt('balanceProfileId'),
    saveId: stringAt('saveId'),
    snapshotGeneration: intAt('snapshotGeneration'),
    lastAppliedTransaction: intAt('lastAppliedTransaction'),
    eventSequence: intAt('eventSequence'),
    commitComplete: root['commitComplete'] == true,
    originSaltFingerprint: root['originSaltFingerprint'] is String
        ? root['originSaltFingerprint']! as String
        : null,
    state: decoder.decode(stateJson),
  );
}

// --- migration boundary ---------------------------------------------------

/// Decodes one historical state shape into the *current* [GameState].
///
/// A direct decoder per version, not a v0→v1→v2 chain. With a handful of
/// versions a chain means every old shape stays materialisable forever and
/// each hop is somewhere a defect compounds quietly. A direct decoder is
/// written once against a frozen fixture and never touched again.
///
/// Chaining wins only at dozens of versions. Revisit then, behind this same
/// interface.
abstract interface class StateDecoder {
  int get version;
  GameState decode(Map<String, Object?> json);
}

/// The decoder table.
///
/// **Encoding is single-version.** There is one encoder, for the current
/// state version; a build never writes an old format. That asymmetry is the
/// point: `decode` fans in, `encode` does not fan out.
final class StateCodecs {
  const StateCodecs._();

  static const List<StateDecoder> _decoders = <StateDecoder>[V1StateDecoder()];

  static StateDecoder? decoderFor(int version) {
    for (final StateDecoder d in _decoders) {
      if (d.version == version) return d;
    }
    return null;
  }
}

/// Decoder for state version 1.
final class V1StateDecoder implements StateDecoder {
  const V1StateDecoder();

  @override
  int get version => 1;

  @override
  GameState decode(Map<String, Object?> json) {
    Map<String, Object?> objectAt(Map<String, Object?> from, String key) {
      final Object? v = from[key];
      if (v is! Map<String, Object?>) {
        throw SaveCodecException('$key is not an object');
      }
      return v;
    }

    int intAt(Map<String, Object?> from, String key) {
      final Object? v = from[key];
      if (v is! int) throw SaveCodecException('$key is not an integer');
      return v;
    }

    int? nullableIntAt(Map<String, Object?> from, String key) {
      final Object? v = from[key];
      if (v == null) return null;
      if (v is! int) throw SaveCodecException('$key is not an integer or null');
      return v;
    }

    String stringAt(Map<String, Object?> from, String key) {
      final Object? v = from[key];
      if (v is! String) throw SaveCodecException('$key is not a string');
      return v;
    }

    List<Object?> listAt(Map<String, Object?> from, String key) {
      final Object? v = from[key];
      if (v is! List<Object?>) throw SaveCodecException('$key is not a list');
      return v;
    }

    ContentId idOf(String raw, String path) {
      final ContentIdParse parsed = ContentId.parse(raw);
      final ContentId? id = parsed.id;
      if (id == null) {
        throw SaveCodecException(
          '$path is not a valid content id: ${parsed.explanation}',
        );
      }
      return id;
    }

    Map<ContentId, int> idCounts(String key) {
      final Map<ContentId, int> out = <ContentId, int>{};
      for (final Object? entry in listAt(json, key)) {
        if (entry is! Map<String, Object?>) {
          throw SaveCodecException('$key entry is not an object');
        }
        out[idOf(stringAt(entry, 'id'), '$key.id')] = intAt(entry, 'n');
      }
      return out;
    }

    final Map<String, Object?> playerJson = objectAt(json, 'player');
    final Map<String, Object?> worldJson = objectAt(json, 'world');
    final Map<String, Object?> equipmentJson = objectAt(json, 'equipment');

    final Map<EquipmentSlot, ContentId> equipment =
        <EquipmentSlot, ContentId>{};
    for (final MapEntry<String, Object?> e in equipmentJson.entries) {
      final EquipmentSlot slot = EquipmentSlot.values.firstWhere(
        (EquipmentSlot s) => s.name == e.key,
        orElse: () =>
            throw SaveCodecException('unknown equipment slot ${e.key}'),
      );
      final Object? raw = e.value;
      if (raw is! String) {
        throw SaveCodecException('equipment.${e.key} is not a string');
      }
      equipment[slot] = idOf(raw, 'equipment.${e.key}');
    }

    return GameState(
      stateVersion: intAt(json, 'stateVersion'),
      profileId: idOf(stringAt(json, 'profileId'), 'profileId'),
      contentPackVersion: intAt(json, 'contentPackVersion'),
      eventSequence: intAt(json, 'eventSequence'),
      player: PlayerState(
        level: intAt(playerJson, 'level'),
        experience: intAt(playerJson, 'experience'),
      ),
      inventory: Inventory(idCounts('inventory')),
      equipment: Equipment(equipment),
      skills: SkillProgress(idCounts('skills')),
      world: WorldState(
        currentLocation: idOf(
          stringAt(worldJson, 'currentLocation'),
          'world.currentLocation',
        ),
        unlockedLocations: <ContentId>{
          for (final Object? raw in listAt(worldJson, 'unlockedLocations'))
            if (raw is String)
              idOf(raw, 'world.unlockedLocations')
            else
              throw const SaveCodecException(
                'world.unlockedLocations entry is not a string',
              ),
        },
      ),
      steps: _decodeLedger(
        objectAt(json, 'steps'),
        intAt: intAt,
        nullableIntAt: nullableIntAt,
        stringAt: stringAt,
        listAt: listAt,
        objectAt: objectAt,
      ),
    );
  }

  StepLedger _decodeLedger(
    Map<String, Object?> json, {
    required int Function(Map<String, Object?>, String) intAt,
    required int? Function(Map<String, Object?>, String) nullableIntAt,
    required String Function(Map<String, Object?>, String) stringAt,
    required List<Object?> Function(Map<String, Object?>, String) listAt,
    required Map<String, Object?> Function(Map<String, Object?>, String)
    objectAt,
  }) {
    final Map<String, Object?> checkpointJson = objectAt(json, 'checkpoint');
    final Map<String, Object?> recoveryJson = objectAt(json, 'recovery');

    final Object? cursorRaw = checkpointJson['cursor'];
    final SyncCursor? cursor;
    if (cursorRaw == null) {
      cursor = null;
    } else if (cursorRaw is String) {
      cursor = SyncCursor(base64Decode(cursorRaw));
    } else {
      throw const SaveCodecException('checkpoint.cursor is not a string');
    }

    final Map<ObservationKey, int> slices = <ObservationKey, int>{};
    for (final Object? entry in listAt(json, 'grantedSlices')) {
      if (entry is! Map<String, Object?>) {
        throw const SaveCodecException('grantedSlices entry is not an object');
      }
      final String rawOrigin = stringAt(entry, 'o');
      final StepOriginKey? origin = StepOriginKey.tryParse(rawOrigin);
      if (origin == null) {
        // Length only. The rejected value may be exactly the display name the
        // type exists to keep out, and this message reaches a diagnostic.
        throw SaveCodecException(
          'grantedSlices.o is not a valid origin key (length ${rawOrigin.length})',
        );
      }
      slices[ObservationKey(
        origin: origin,
        bucket: TimeBucket(
          startMillis: intAt(entry, 's'),
          endMillis: intAt(entry, 'e'),
        ),
      )] = intAt(
        entry,
        'g',
      );
    }

    return StepLedger(
      totalObserved: intAt(json, 'totalObserved'),
      totalGranted: intAt(json, 'totalGranted'),
      totalSpent: intAt(json, 'totalSpent'),
      grantedSlices: slices,
      grantedBeforeWatermark: intAt(json, 'grantedBeforeWatermark'),
      correctionsObserved: intAt(json, 'correctionsObserved'),
      unreachableGapEvents: intAt(json, 'unreachableGapEvents'),
      lateDiscardedSlices: intAt(json, 'lateDiscardedSlices'),
      sourceState: _enumByName(
        SourceState.values,
        stringAt(json, 'sourceState'),
        'sourceState',
      ),
      checkpoint: SyncCheckpoint(
        cursor: cursor,
        watermarkMillis: nullableIntAt(checkpointJson, 'watermarkMillis'),
        syncCount: intAt(checkpointJson, 'syncCount'),
      ),
      recovery: RecoveryState(
        phase: _enumByName(
          RecoveryPhase.values,
          stringAt(recoveryJson, 'phase'),
          'recovery.phase',
        ),
        windowStartMillis: nullableIntAt(recoveryJson, 'windowStartMillis'),
        windowEndMillis: nullableIntAt(recoveryJson, 'windowEndMillis'),
        truncated: recoveryJson['truncated'] == true,
        attempts: intAt(recoveryJson, 'attempts'),
      ),
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String name, String path) {
  for (final T v in values) {
    if (v.name == name) return v;
  }
  throw SaveCodecException('$path has unknown value "$name"');
}

/// Whether [version] is a content schema this build can read.
bool contentSchemaSupported(int version) => SchemaVersion.supports(version);
