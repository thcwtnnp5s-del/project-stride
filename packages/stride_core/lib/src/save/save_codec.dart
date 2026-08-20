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
import '../engine/combat.dart';
import '../engine/combat_rules.dart';
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
    // State version 7 (`DECISIONS/0023`): persistent HP.
    'hp': state.player.hp,
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
    // State version 5 (`DECISIONS/0021`), replacing v4's `drivenOff` list.
    // Written unconditionally, empty or not, so a v5 save is never silent
    // about it. An object rather than a list of pairs: the counts are keyed by
    // enemy id, `canonicalJson` sorts object keys, and a map cannot carry the
    // same enemy twice the way a list could.
    'visitVictories': <String, Object?>{
      for (final MapEntry<ContentId, int> e
          in state.world.visitVictories.entries)
        e.key.value: e.value,
    },
  },
  'steps': encodeStepLedger(state.steps),
  // State version 4. Written as an explicit null when no fight is on: an
  // absent key would be indistinguishable from a pre-v4 save's shape, and the
  // v4 decoder should never have to guess which it is reading.
  'encounter': _encodeEncounter(state.encounter),
  // State version 6 (`DECISIONS/0022`). Explicit null when no queue runs, on
  // exactly the terms `encounter` set at v4: a v6 save is never silent about
  // it, and the v6 decoder never has to guess which shape it is reading.
  'activityQueue': _encodeActivityQueue(state.activityQueue),
  // State version 7 (`DECISIONS/0023`). Written unconditionally, empty or
  // not, so a v7 save is never silent about the progression loop's memory.
  'progress': _encodeProgress(state.progress),
};

Map<String, Object?> _encodeProgress(ProgressState progress) =>
    <String, Object?>{
      'enemyVictories': _encodeIdCounts(progress.enemyVictories),
      'acceptedContracts':
          progress.acceptedContracts.map((ContentId id) => id.value).toList()
            ..sort(),
      'bountyProgress': _encodeIdCounts(progress.bountyProgress),
      'contractCompletions': _encodeIdCounts(progress.contractCompletions),
      // Slot order inside a location is meaningful (it is the board's layout),
      // so slots are a list per location; locations sort for canonical bytes.
      'localSlots': <Object?>[
        for (final MapEntry<ContentId, List<ContentId>> e
            in (progress.localSlots.entries.toList()..sort(
              (
                MapEntry<ContentId, List<ContentId>> a,
                MapEntry<ContentId, List<ContentId>> b,
              ) => a.key.compareTo(b.key),
            )))
          <String, Object?>{
            'location': e.key.value,
            'slots': <Object?>[for (final ContentId id in e.value) id.value],
          },
      ],
      'localNext': _encodeIdCounts(progress.localNext),
      'projects': <Object?>[
        for (final MapEntry<ContentId, ProjectProgressState> e
            in (progress.projects.entries.toList()..sort(
              (
                MapEntry<ContentId, ProjectProgressState> a,
                MapEntry<ContentId, ProjectProgressState> b,
              ) => a.key.compareTo(b.key),
            )))
          <String, Object?>{
            'id': e.key.value,
            'stage': e.value.stage,
            'contributed': _encodeIdCounts(e.value.contributed),
          },
      ],
      'completedProjects':
          progress.completedProjects.map((ContentId id) => id.value).toList()
            ..sort(),
      'revealedRumors':
          progress.revealedRumors.map((ContentId id) => id.value).toList()
            ..sort(),
      'tracked': <String, Object?>{
        'journey': progress.tracked.journey?.value,
        'pursuit': progress.tracked.pursuit?.value,
        'contract': progress.tracked.contract?.value,
      },
    };

Map<String, Object?>? _encodeActivityQueue(ActivityQueueState? queue) =>
    queue == null
    ? null
    : <String, Object?>{
        'node': queue.node.value,
        'requested': queue.requested,
        'completed': queue.completed,
        'durationMillis': queue.durationMillis,
        'anchorEpochMillis': queue.anchorEpochMillis,
      };

Map<String, Object?>? _encodeEncounter(EncounterState? encounter) =>
    encounter == null
    ? null
    : <String, Object?>{
        'enemy': encounter.enemy.value,
        'location': encounter.location.value,
        'seed': encounter.seed,
        'turn': encounter.turn,
        'playerHp': encounter.playerHp,
        'playerMaxHp': encounter.playerMaxHp,
        'playerAttack': encounter.playerAttack,
        'playerDefence': encounter.playerDefence,
        'enemyHp': encounter.enemyHp,
        'enemyMaxHp': encounter.enemyMaxHp,
        'telegraph': encounter.telegraph,
        // State version 7 (`DECISIONS/0023`).
        'playerFrostGuard': encounter.playerFrostGuard,
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
  // State version 2. Absent in a v1 save, where its absence means the origin
  // epoch — every granted step is playable, which is exactly what a v1 save
  // meant. Written unconditionally rather than omitted at the origin: this is
  // the field the whole cutover turns on, and a save that is silent about it is
  // a save that has to be interpreted.
  //
  // `establishedAtStateVersion` is state version 3 (`DECISIONS/0018`). Absent
  // in a v2 save, where a non-origin epoch can only have been set by the
  // Phase 2 cutover and so reads as 2 — see `V2StateDecoder`.
  'epoch': <String, Object?>{
    'establishedAtStateVersion': ledger.epoch.establishedAtStateVersion,
    'grantedAtStart': ledger.epoch.grantedAtStart,
    'spentAtStart': ledger.epoch.spentAtStart,
  },
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
    // Omitted when empty so saves written before per-origin watermarks existed
    // stay byte-identical -- the frozen v1 fixture depends on that.
    //
    // Persisting these is not optional: without them a reload unsettles every
    // origin, and the whole live retention window is granted a second time.
    if (ledger.checkpoint.originWatermarks.isNotEmpty)
      'originWatermarks': <Object?>[
        for (final MapEntry<StepOriginKey, int> e
            in ledger.checkpoint.originWatermarks.entries)
          <String, Object?>{'o': e.key.value, 'w': e.value},
      ],
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
  // **Required, though nullable.** It was optional, and every call site simply
  // omitted it -- so no snapshot ever carried a fingerprint, and the salt
  // fail-closed check in SaveRepository could never fire. An optional
  // parameter carrying a safety-critical value is a defect waiting to be
  // written; required makes forgetting it a compile error.
  required String? originSaltFingerprint,
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

  static const List<StateDecoder> _decoders = <StateDecoder>[
    V1StateDecoder(),
    V2StateDecoder(),
    V3StateDecoder(),
    V4StateDecoder(),
    V5StateDecoder(),
    V6StateDecoder(),
    V7StateDecoder(),
  ];

  static StateDecoder? decoderFor(int version) {
    for (final StateDecoder d in _decoders) {
      if (d.version == version) return d;
    }
    return null;
  }
}

/// Decoder for state version 1.
///
/// **Frozen.** A v1 save is read by this and by nothing else, and the frozen
/// fixture in `test/save_migration_test.dart` is the proof that it still reads
/// one. It is never edited to accommodate a new field — that is what a new
/// decoder is for.
///
/// A v1 state has no `steps.epoch`, so it decodes to [EconomyEpoch.origin]:
/// every granted step is playable. That is not a fallback, it is what a v1 save
/// meant. The state comes back declaring `stateVersion: 1`, which is the signal
/// `BootstrapCoordinator` uses to run the migration table from there.
final class V1StateDecoder implements StateDecoder {
  const V1StateDecoder();

  @override
  int get version => 1;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.absent,
    combatShape: _CombatShape.absent,
  );
}

/// Decoder for state version 2.
///
/// **Frozen**, on the same terms as [V1StateDecoder]; `v2_baseline.save` is the
/// proof it still reads one.
///
/// Differs from v1 in exactly one place: `steps.epoch` is present and is read
/// (`DECISIONS/0016`). Everything else is byte-for-byte the same geometry, which
/// is why the versions share one implementation rather than being copied — a
/// copy would let the shapes drift in the fields that are supposed to be
/// identical.
///
/// A v2 epoch has no `establishedAtStateVersion`. It decodes as **2** for any
/// non-origin mark and **0** for the origin, and that is what a v2 save meant:
/// the only re-basing migration that existed when v2 was current was the Phase
/// 2 cutover, so a mark that is not the origin was set by it.
final class V2StateDecoder implements StateDecoder {
  const V2StateDecoder();

  @override
  int get version => 2;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.marksOnly,
    combatShape: _CombatShape.absent,
  );
}

/// Decoder for state version 3.
///
/// **Frozen**, on the same terms as [V1StateDecoder]; `v3_baseline.save` is the
/// proof it still reads one.
///
/// Differs from v2 in exactly one place: `steps.epoch.establishedAtStateVersion`
/// is present and is read (`DECISIONS/0018`). A v3 save has no `encounter` and
/// no `world.drivenOff`; it decodes with no fight on and nothing driven off,
/// which is what a v3 save meant — combat did not exist.
final class V3StateDecoder implements StateDecoder {
  const V3StateDecoder();

  @override
  int get version => 3;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.withEstablishedVersion,
    combatShape: _CombatShape.absent,
  );
}

/// Decoder for state version 4.
///
/// **Frozen**, on the same terms as [V1StateDecoder]; `v4_baseline.save` is the
/// proof it still reads one.
///
/// Differs from v3 in exactly two places: `encounter` (null or an object) and
/// `world.drivenOff` are present and are read (`DECISIONS/0020`).
///
/// The `drivenOff` **list** decodes into the current `visitVictories` **map**
/// with every listed enemy at a count of `1`. That is not a default standing
/// in for missing data — it is what a v4 save said: at v4 one victory was the
/// entire allowance, so an enemy in the set had been beaten exactly once since
/// the player last moved (`DECISIONS/0021` §3).
final class V4StateDecoder implements StateDecoder {
  const V4StateDecoder();

  @override
  int get version => 4;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.withEstablishedVersion,
    combatShape: _CombatShape.drivenOffSet,
  );
}

/// Decoder for state version 5.
///
/// **Frozen**, on the same terms as [V1StateDecoder]; `v5_baseline.save` is
/// the proof it still reads one.
///
/// Differs from v4 in exactly one place: `world.drivenOff` (a sorted list of
/// enemy ids) is gone and `world.visitVictories` (an object of enemy id →
/// count) is present and is read (`DECISIONS/0021`). A v5 save has no
/// `activityQueue`; it decodes with none, which is what a v5 save meant — no
/// queue could outlive the process.
final class V5StateDecoder implements StateDecoder {
  const V5StateDecoder();

  @override
  int get version => 5;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.withEstablishedVersion,
    combatShape: _CombatShape.visitVictories,
  );
}

/// Decoder for state version 6.
///
/// **Frozen**, on the same terms as [V1StateDecoder]; `v6_baseline.save` is
/// the proof it still reads one.
///
/// Differs from v5 in exactly one place: `activityQueue` (null or an object)
/// is present and is read (`DECISIONS/0022`). A v6 save has no `player.hp`
/// and no `progress`; it decodes with full HP at the level's maximum —
/// what a v6 save meant, where every fight began full — and an empty
/// progress block.
final class V6StateDecoder implements StateDecoder {
  const V6StateDecoder();

  @override
  int get version => 6;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.withEstablishedVersion,
    combatShape: _CombatShape.visitVictories,
    queueShape: _QueueShape.present,
  );
}

/// Decoder for state version 7 — the current shape.
///
/// Differs from v6 in three places, all `DECISIONS/0023`: `player.hp`,
/// `progress`, and `encounter.playerFrostGuard` are present and are read.
final class V7StateDecoder implements StateDecoder {
  const V7StateDecoder();

  @override
  int get version => 7;

  @override
  GameState decode(Map<String, Object?> json) => _decodeStateShape(
    json,
    epochShape: _EpochShape.withEstablishedVersion,
    combatShape: _CombatShape.visitVictories,
    queueShape: _QueueShape.present,
    loopShape: _LoopShape.present,
  );
}

/// Whether — and how — the shape carries the combat fields.
enum _CombatShape {
  /// State versions 1–3: no `encounter`, no per-visit combat record at all.
  /// Their absence means no fight on and nothing beaten this visit.
  absent,

  /// State version 4: `encounter`, and `world.drivenOff` as a list of enemy
  /// ids. Each listed enemy decodes to a visit count of 1.
  drivenOffSet,

  /// State version 5: `encounter`, and `world.visitVictories` as an object of
  /// enemy id → count.
  visitVictories,
}

/// Whether the shape carries the activity queue (`DECISIONS/0022`).
enum _QueueShape {
  /// State versions 1–5: no `activityQueue` at all. Its absence means no
  /// queue was running — what those saves meant, not a default.
  absent,

  /// State version 6: `activityQueue`, as null or an object.
  present,
}

/// Whether the shape carries the progression loop's fields
/// (`DECISIONS/0023`).
enum _LoopShape {
  /// State versions 1–6: no `player.hp`, no `progress`, no
  /// `encounter.playerFrostGuard`. Their absence means full HP at the
  /// level's maximum, an empty progress block, and no frost guard — what
  /// those saves meant.
  absent,

  /// State version 7: all three, required.
  present,
}

/// The one field that differs between the shared shapes.
enum _EpochShape {
  /// State version 1: no `steps.epoch`. Its absence is the origin.
  absent,

  /// State version 2: `grantedAtStart` and `spentAtStart` only.
  marksOnly,

  /// State version 3: the marks and `establishedAtStateVersion`.
  withEstablishedVersion,
}

/// The shared state shape, parameterised by the one field that differs.
GameState _decodeStateShape(
  Map<String, Object?> json, {
  required _EpochShape epochShape,
  required _CombatShape combatShape,
  _QueueShape queueShape = _QueueShape.absent,
  _LoopShape loopShape = _LoopShape.absent,
}) {
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

  Set<ContentId> idSet(Map<String, Object?> from, String key) => <ContentId>{
    for (final Object? raw in listAt(from, key))
      if (raw is String)
        idOf(raw, key)
      else
        throw SaveCodecException('$key entry is not a string'),
  };

  // The combat fields. Absent in v1–v3, where absence means no fight on and
  // nothing beaten this visit — what those saves meant, not a default for
  // missing data. From v4 the `encounter` key must be present, as null or an
  // object; the per-visit record changes shape at v5.
  final Map<ContentId, int> visitVictories;
  final EncounterState? encounter;
  switch (combatShape) {
    case _CombatShape.absent:
      visitVictories = const <ContentId, int>{};
      encounter = null;
    case _CombatShape.drivenOffSet:
    case _CombatShape.visitVictories:
      visitVictories = combatShape == _CombatShape.drivenOffSet
          // A v4 save listed the enemies beaten once each; the count is 1 by
          // what that version meant, not by assumption (`DECISIONS/0021` §3).
          ? <ContentId, int>{
              for (final ContentId id in idSet(worldJson, 'drivenOff')) id: 1,
            }
          : <ContentId, int>{
              for (final MapEntry<String, Object?> e in objectAt(
                worldJson,
                'visitVictories',
              ).entries)
                idOf(e.key, 'world.visitVictories'): e.value is int
                    ? e.value! as int
                    : throw SaveCodecException(
                        'world.visitVictories.${e.key} is not an integer',
                      ),
            };
      if (!json.containsKey('encounter')) {
        throw const SaveCodecException('encounter is missing');
      }
      final Object? raw = json['encounter'];
      if (raw == null) {
        encounter = null;
      } else if (raw is Map<String, Object?>) {
        encounter = EncounterState(
          enemy: idOf(stringAt(raw, 'enemy'), 'encounter.enemy'),
          location: idOf(stringAt(raw, 'location'), 'encounter.location'),
          seed: intAt(raw, 'seed'),
          turn: intAt(raw, 'turn'),
          playerHp: intAt(raw, 'playerHp'),
          playerMaxHp: intAt(raw, 'playerMaxHp'),
          playerAttack: intAt(raw, 'playerAttack'),
          playerDefence: intAt(raw, 'playerDefence'),
          enemyHp: intAt(raw, 'enemyHp'),
          enemyMaxHp: intAt(raw, 'enemyMaxHp'),
          telegraph: raw['telegraph'] == true,
          // Required from v7; zero before, where no armour carried one.
          playerFrostGuard: loopShape == _LoopShape.present
              ? intAt(raw, 'playerFrostGuard')
              : 0,
        );
      } else {
        throw const SaveCodecException('encounter is not an object or null');
      }
  }

  // The activity queue (`DECISIONS/0022`). Absent in v1–v5, where absence
  // means no queue was running. From v6 the key must be present, as null or an
  // object — the same discipline `encounter` established at v4.
  final ActivityQueueState? activityQueue;
  switch (queueShape) {
    case _QueueShape.absent:
      activityQueue = null;
    case _QueueShape.present:
      if (!json.containsKey('activityQueue')) {
        throw const SaveCodecException('activityQueue is missing');
      }
      final Object? raw = json['activityQueue'];
      if (raw == null) {
        activityQueue = null;
      } else if (raw is Map<String, Object?>) {
        activityQueue = ActivityQueueState(
          node: idOf(stringAt(raw, 'node'), 'activityQueue.node'),
          requested: intAt(raw, 'requested'),
          completed: intAt(raw, 'completed'),
          durationMillis: intAt(raw, 'durationMillis'),
          anchorEpochMillis: intAt(raw, 'anchorEpochMillis'),
        );
      } else {
        throw const SaveCodecException(
          'activityQueue is not an object or null',
        );
      }
  }

  final Map<EquipmentSlot, ContentId> equipment = <EquipmentSlot, ContentId>{};
  for (final MapEntry<String, Object?> e in equipmentJson.entries) {
    final EquipmentSlot slot = EquipmentSlot.values.firstWhere(
      (EquipmentSlot s) => s.name == e.key,
      orElse: () => throw SaveCodecException('unknown equipment slot ${e.key}'),
    );
    final Object? raw = e.value;
    if (raw is! String) {
      throw SaveCodecException('equipment.${e.key} is not a string');
    }
    equipment[slot] = idOf(raw, 'equipment.${e.key}');
  }

  // The progression loop (`DECISIONS/0023`). Absent before v7, where absence
  // means full HP at the level's maximum and an empty progress block — what
  // those saves meant. From v7 both fields must be present.
  final int level = intAt(playerJson, 'level');
  final int hp;
  final ProgressState progress;
  switch (loopShape) {
    case _LoopShape.absent:
      hp = CombatRules.maxHpFor(level);
      progress = ProgressState.initial();
    case _LoopShape.present:
      hp = intAt(playerJson, 'hp');
      progress = _decodeProgress(
        objectAt(json, 'progress'),
        idOf: idOf,
        intAt: intAt,
        stringAt: stringAt,
        listAt: listAt,
        objectAt: objectAt,
      );
  }

  return GameState(
    stateVersion: intAt(json, 'stateVersion'),
    profileId: idOf(stringAt(json, 'profileId'), 'profileId'),
    contentPackVersion: intAt(json, 'contentPackVersion'),
    eventSequence: intAt(json, 'eventSequence'),
    player: PlayerState(
      level: level,
      experience: intAt(playerJson, 'experience'),
      hp: hp,
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
      visitVictories: visitVictories,
    ),
    encounter: encounter,
    activityQueue: activityQueue,
    progress: progress,
    steps: _decodeLedger(
      objectAt(json, 'steps'),
      epochShape: epochShape,
      intAt: intAt,
      nullableIntAt: nullableIntAt,
      stringAt: stringAt,
      listAt: listAt,
      objectAt: objectAt,
    ),
  );
}

/// The progression loop's block, state version 7 (`DECISIONS/0023`).
ProgressState _decodeProgress(
  Map<String, Object?> json, {
  required ContentId Function(String raw, String path) idOf,
  required int Function(Map<String, Object?>, String) intAt,
  required String Function(Map<String, Object?>, String) stringAt,
  required List<Object?> Function(Map<String, Object?>, String) listAt,
  required Map<String, Object?> Function(Map<String, Object?>, String) objectAt,
}) {
  Map<ContentId, int> idCountsIn(String key) {
    final Map<ContentId, int> out = <ContentId, int>{};
    for (final Object? entry in listAt(json, key)) {
      if (entry is! Map<String, Object?>) {
        throw SaveCodecException('progress.$key entry is not an object');
      }
      out[idOf(stringAt(entry, 'id'), 'progress.$key.id')] = intAt(entry, 'n');
    }
    return out;
  }

  Set<ContentId> idSetIn(String key) => <ContentId>{
    for (final Object? raw in listAt(json, key))
      if (raw is String)
        idOf(raw, 'progress.$key')
      else
        throw SaveCodecException('progress.$key entry is not a string'),
  };

  final Map<ContentId, List<ContentId>> localSlots =
      <ContentId, List<ContentId>>{};
  for (final Object? entry in listAt(json, 'localSlots')) {
    if (entry is! Map<String, Object?>) {
      throw const SaveCodecException(
        'progress.localSlots entry is not an object',
      );
    }
    localSlots[idOf(
      stringAt(entry, 'location'),
      'progress.localSlots.location',
    )] = <ContentId>[
      for (final Object? raw in listAt(entry, 'slots'))
        if (raw is String)
          idOf(raw, 'progress.localSlots.slots')
        else
          throw const SaveCodecException(
            'progress.localSlots.slots entry is not a string',
          ),
    ];
  }

  final Map<ContentId, ProjectProgressState> projects =
      <ContentId, ProjectProgressState>{};
  for (final Object? entry in listAt(json, 'projects')) {
    if (entry is! Map<String, Object?>) {
      throw const SaveCodecException(
        'progress.projects entry is not an object',
      );
    }
    final Map<ContentId, int> contributed = <ContentId, int>{};
    for (final Object? raw in listAt(entry, 'contributed')) {
      if (raw is! Map<String, Object?>) {
        throw const SaveCodecException(
          'progress.projects.contributed entry is not an object',
        );
      }
      contributed[idOf(
        stringAt(raw, 'id'),
        'progress.projects.contributed.id',
      )] = intAt(raw, 'n');
    }
    projects[idOf(stringAt(entry, 'id'), 'progress.projects.id')] =
        ProjectProgressState(
          stage: intAt(entry, 'stage'),
          contributed: contributed,
        );
  }

  final Map<String, Object?> trackedJson = objectAt(json, 'tracked');
  ContentId? trackedAt(String key) {
    final Object? raw = trackedJson[key];
    if (raw == null) return null;
    if (raw is! String) {
      throw SaveCodecException('progress.tracked.$key is not a string or null');
    }
    return idOf(raw, 'progress.tracked.$key');
  }

  return ProgressState(
    enemyVictories: idCountsIn('enemyVictories'),
    acceptedContracts: idSetIn('acceptedContracts'),
    bountyProgress: idCountsIn('bountyProgress'),
    contractCompletions: idCountsIn('contractCompletions'),
    localSlots: localSlots,
    localNext: idCountsIn('localNext'),
    projects: projects,
    completedProjects: idSetIn('completedProjects'),
    revealedRumors: idSetIn('revealedRumors'),
    tracked: TrackedGoals(
      journey: trackedAt('journey'),
      pursuit: trackedAt('pursuit'),
      contract: trackedAt('contract'),
    ),
  );
}

/// The shared ledger shape.
///
/// [epochShape] says which of the epoch's fields this version wrote. What is
/// absent is never missing data: a v1 save has no epoch and meant the origin;
/// a v2 save has no `establishedAtStateVersion` and meant the Phase 2 cutover
/// for any non-origin mark, the origin otherwise.
StepLedger _decodeLedger(
  Map<String, Object?> json, {
  required _EpochShape epochShape,
  required int Function(Map<String, Object?>, String) intAt,
  required int? Function(Map<String, Object?>, String) nullableIntAt,
  required String Function(Map<String, Object?>, String) stringAt,
  required List<Object?> Function(Map<String, Object?>, String) listAt,
  required Map<String, Object?> Function(Map<String, Object?>, String) objectAt,
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

  final Map<StepOriginKey, int> originWatermarks = <StepOriginKey, int>{};
  final Object? rawMarks = checkpointJson['originWatermarks'];
  if (rawMarks is List<Object?>) {
    for (final Object? raw in rawMarks) {
      if (raw is! Map<String, Object?>) {
        throw const SaveCodecException(
          'originWatermarks entry is not an object',
        );
      }
      final StepOriginKey? key = StepOriginKey.tryParse(stringAt(raw, 'o'));
      if (key == null) {
        throw const SaveCodecException(
          'originWatermarks.o is not a valid origin key',
        );
      }
      originWatermarks[key] = intAt(raw, 'w');
    }
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

  final EconomyEpoch epoch;
  switch (epochShape) {
    case _EpochShape.absent:
      epoch = const EconomyEpoch.origin();
    case _EpochShape.marksOnly:
      final Map<String, Object?> epochJson = objectAt(json, 'epoch');
      final int grantedAtStart = intAt(epochJson, 'grantedAtStart');
      final int spentAtStart = intAt(epochJson, 'spentAtStart');
      // A v2 mark that is not the origin was set by the Phase 2 cutover: it
      // is the only re-basing step that existed while v2 was current. A v2
      // origin is a game that never migrated, and stays the origin. Either
      // way the mark reads as established *before* state version 3, which is
      // what lets the v3 step re-base it exactly once.
      epoch = EconomyEpoch(
        grantedAtStart: grantedAtStart,
        spentAtStart: spentAtStart,
        establishedAtStateVersion: grantedAtStart == 0 && spentAtStart == 0
            ? 0
            : 2,
      );
    case _EpochShape.withEstablishedVersion:
      final Map<String, Object?> epochJson = objectAt(json, 'epoch');
      epoch = EconomyEpoch(
        grantedAtStart: intAt(epochJson, 'grantedAtStart'),
        spentAtStart: intAt(epochJson, 'spentAtStart'),
        establishedAtStateVersion: intAt(
          epochJson,
          'establishedAtStateVersion',
        ),
      );
  }

  return StepLedger(
    totalObserved: intAt(json, 'totalObserved'),
    totalGranted: intAt(json, 'totalGranted'),
    totalSpent: intAt(json, 'totalSpent'),
    epoch: epoch,
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
      originWatermarks: originWatermarks,
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

T _enumByName<T extends Enum>(List<T> values, String name, String path) {
  for (final T v in values) {
    if (v.name == name) return v;
  }
  throw SaveCodecException('$path has unknown value "$name"');
}

/// Whether [version] is a content schema this build can read.
bool contentSchemaSupported(int version) => SchemaVersion.supports(version);
