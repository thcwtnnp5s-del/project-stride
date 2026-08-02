/// Encodes and decodes [GameEvent]s for the journal.
///
/// The switch is exhaustive over the sealed hierarchy, so **the compiler
/// rejects this file the moment an event is added without a case**. That is
/// deliberate: an event that silently failed to serialize would be a grant
/// that vanishes on replay, and it would be discovered by a player rather
/// than by a test.
library;

import 'dart:convert';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../engine/events.dart';
import '../steps/reconciliation.dart';
import '../steps/step_ledger.dart';
import '../steps/step_origin_key.dart';
import '../steps/sync_batch.dart';

/// Encodes one event. `t` is the type tag; the rest are its fields.
Map<String, Object?> encodeEvent(GameEvent event) => switch (event) {
  GameStarted() => <String, Object?>{
    't': 'GameStarted',
    'seq': event.sequence,
    'profileId': event.profileId.value,
    'startLocation': event.startLocation.value,
    'grantedItems': <Object?>[
      for (final ContentId id in event.grantedItems) id.value,
    ],
  },
  SyntheticStepsGranted() => <String, Object?>{
    't': 'SyntheticStepsGranted',
    'seq': event.sequence,
    'steps': event.steps,
    'reason': event.reason,
  },
  StepsAllocated() => <String, Object?>{
    't': 'StepsAllocated',
    'seq': event.sequence,
    'steps': event.steps,
  },
  ItemEquipped() => <String, Object?>{
    't': 'ItemEquipped',
    'seq': event.sequence,
    'item': event.item.value,
    'slot': event.slot.name,
  },
  ItemUnequipped() => <String, Object?>{
    't': 'ItemUnequipped',
    'seq': event.sequence,
    'item': event.item.value,
    'slot': event.slot.name,
  },
  LocationUnlocked() => <String, Object?>{
    't': 'LocationUnlocked',
    'seq': event.sequence,
    'location': event.location.value,
  },
  LocationEntered() => <String, Object?>{
    't': 'LocationEntered',
    'seq': event.sequence,
    'from': event.from.value,
    'location': event.location.value,
  },
  StepRecoveryStarted() => <String, Object?>{
    't': 'StepRecoveryStarted',
    'seq': event.sequence,
    'windowStartMillis': event.windowStartMillis,
    'windowEndMillis': event.windowEndMillis,
    'truncated': event.truncated,
  },
  StepObservationReconciled() => <String, Object?>{
    't': 'StepObservationReconciled',
    'seq': event.sequence,
    'observedAfter': event.observedAfter,
    'grantedCompactedAway': event.grantedCompactedAway,
    'lateDiscarded': event.lateDiscarded,
    'watermarkMillis': event.watermarkMillis,
    'originWatermarks': <Object?>[
      for (final MapEntry<StepOriginKey, int> e
          in (event.originWatermarks.entries.toList()..sort(
            (MapEntry<StepOriginKey, int> a, MapEntry<StepOriginKey, int> b) =>
                a.key.compareTo(b.key),
          )))
        <String, Object?>{'o': e.key.value, 'w': e.value},
    ],
    'correctionsSeen': event.correctionsSeen,
    'truncatedGap': event.truncatedGap,
    'wasRecovery': event.wasRecovery,
    // Structural, never a composite string — see save_codec.dart.
    'slices': <Object?>[
      for (final MapEntry<ObservationKey, int> e in _sortedSlices(
        event.grantedSlicesAfter,
      ))
        <String, Object?>{
          'o': e.key.origin.value,
          's': e.key.bucket.startMillis,
          'e': e.key.bucket.endMillis,
          'g': e.value,
        },
    ],
  },
  StepsGranted() => <String, Object?>{
    't': 'StepsGranted',
    'seq': event.sequence,
    'steps': event.steps,
    'grantedTotalAfter': event.grantedTotalAfter,
  },
  StepCheckpointAuthorized() => <String, Object?>{
    't': 'StepCheckpointAuthorized',
    'seq': event.sequence,
    'cursor': event.cursor == null ? null : base64Encode(event.cursor!.bytes),
    'syncCount': event.syncCount,
  },
  StepRecoveryCompleted() => <String, Object?>{
    't': 'StepRecoveryCompleted',
    'seq': event.sequence,
    'newlyGranted': event.newlyGranted,
    'truncated': event.truncated,
  },
  StepSourceStateChanged() => <String, Object?>{
    't': 'StepSourceStateChanged',
    'seq': event.sequence,
    'sourceState': event.sourceState.name,
    'code': event.code?.name,
  },
};

List<MapEntry<ObservationKey, int>> _sortedSlices(
  Map<ObservationKey, int> slices,
) => slices.entries.toList()
  ..sort((MapEntry<ObservationKey, int> a, MapEntry<ObservationKey, int> b) {
    final int byOrigin = a.key.origin.compareTo(b.key.origin);
    if (byOrigin != 0) return byOrigin;
    return a.key.bucket.startMillis.compareTo(b.key.bucket.startMillis);
  });

/// Decodes one event, or null if [json] is not a well-formed event.
///
/// Returns null rather than throwing: a malformed journal line is an expected
/// condition with a typed outcome, not an exception.
GameEvent? decodeEvent(Map<String, Object?> json) {
  final Object? tag = json['t'];
  final Object? seq = json['seq'];
  if (tag is! String || seq is! int) return null;

  int? i(String k) => json[k] is int ? json[k]! as int : null;
  bool b(String k) => json[k] == true;
  String? s(String k) => json[k] is String ? json[k]! as String : null;

  ContentId? id(String k) {
    final String? raw = s(k);
    if (raw == null) return null;
    return ContentId.parse(raw).id;
  }

  switch (tag) {
    case 'GameStarted':
      final ContentId? profile = id('profileId');
      final ContentId? start = id('startLocation');
      final Object? items = json['grantedItems'];
      if (profile == null || start == null || items is! List<Object?>) {
        return null;
      }
      final List<ContentId> granted = <ContentId>[];
      for (final Object? raw in items) {
        if (raw is! String) return null;
        final ContentId? parsed = ContentId.parse(raw).id;
        if (parsed == null) return null;
        granted.add(parsed);
      }
      return GameStarted(
        sequence: seq,
        profileId: profile,
        startLocation: start,
        grantedItems: granted,
      );

    case 'SyntheticStepsGranted':
      final int? steps = i('steps');
      final String? reason = s('reason');
      if (steps == null || reason == null) return null;
      return SyntheticStepsGranted(sequence: seq, steps: steps, reason: reason);

    case 'StepsAllocated':
      final int? steps = i('steps');
      return steps == null ? null : StepsAllocated(sequence: seq, steps: steps);

    case 'ItemEquipped':
    case 'ItemUnequipped':
      final ContentId? item = id('item');
      final EquipmentSlot? slot = _enumOrNull(EquipmentSlot.values, s('slot'));
      if (item == null || slot == null) return null;
      return tag == 'ItemEquipped'
          ? ItemEquipped(sequence: seq, item: item, slot: slot)
          : ItemUnequipped(sequence: seq, item: item, slot: slot);

    case 'LocationUnlocked':
      final ContentId? location = id('location');
      return location == null
          ? null
          : LocationUnlocked(sequence: seq, location: location);

    case 'LocationEntered':
      final ContentId? from = id('from');
      final ContentId? location = id('location');
      if (from == null || location == null) return null;
      return LocationEntered(sequence: seq, from: from, location: location);

    case 'StepRecoveryStarted':
      final int? start = i('windowStartMillis');
      final int? end = i('windowEndMillis');
      if (start == null || end == null) return null;
      return StepRecoveryStarted(
        sequence: seq,
        windowStartMillis: start,
        windowEndMillis: end,
        truncated: b('truncated'),
      );

    case 'StepObservationReconciled':
      final int? observed = i('observedAfter');
      final int? compacted = i('grantedCompactedAway');
      final int? late = i('lateDiscarded');
      final int? corrections = i('correctionsSeen');
      final Object? slices = json['slices'];
      if (observed == null ||
          compacted == null ||
          late == null ||
          corrections == null ||
          slices is! List<Object?>) {
        return null;
      }
      final Map<ObservationKey, int> parsed = <ObservationKey, int>{};
      for (final Object? raw in slices) {
        if (raw is! Map<String, Object?>) return null;
        final Object? o = raw['o'];
        final Object? start = raw['s'];
        final Object? end = raw['e'];
        final Object? granted = raw['g'];
        if (o is! String || start is! int || end is! int || granted is! int) {
          return null;
        }
        final StepOriginKey? origin = StepOriginKey.tryParse(o);
        if (origin == null) return null;
        parsed[ObservationKey(
              origin: origin,
              bucket: TimeBucket(startMillis: start, endMillis: end),
            )] =
            granted;
      }
      final Map<StepOriginKey, int> marks = <StepOriginKey, int>{};
      final Object? rawMarks = json['originWatermarks'];
      if (rawMarks is List<Object?>) {
        for (final Object? raw in rawMarks) {
          if (raw is! Map<String, Object?>) return null;
          final Object? o = raw['o'];
          final Object? w = raw['w'];
          if (o is! String || w is! int) return null;
          final StepOriginKey? key = StepOriginKey.tryParse(o);
          if (key == null) return null;
          marks[key] = w;
        }
      }
      return StepObservationReconciled(
        sequence: seq,
        observedAfter: observed,
        grantedSlicesAfter: parsed,
        grantedCompactedAway: compacted,
        lateDiscarded: late,
        watermarkMillis: i('watermarkMillis'),
        originWatermarks: marks,
        correctionsSeen: corrections,
        truncatedGap: b('truncatedGap'),
        wasRecovery: b('wasRecovery'),
      );

    case 'StepsGranted':
      final int? steps = i('steps');
      final int? total = i('grantedTotalAfter');
      if (steps == null || total == null) return null;
      return StepsGranted(
        sequence: seq,
        steps: steps,
        grantedTotalAfter: total,
      );

    case 'StepCheckpointAuthorized':
      final int? count = i('syncCount');
      if (count == null) return null;
      final String? raw = s('cursor');
      return StepCheckpointAuthorized(
        sequence: seq,
        cursor: raw == null ? null : SyncCursor(base64Decode(raw)),
        syncCount: count,
      );

    case 'StepRecoveryCompleted':
      final int? granted = i('newlyGranted');
      return granted == null
          ? null
          : StepRecoveryCompleted(
              sequence: seq,
              newlyGranted: granted,
              truncated: b('truncated'),
            );

    case 'StepSourceStateChanged':
      final SourceState? state = _enumOrNull(
        SourceState.values,
        s('sourceState'),
      );
      if (state == null) return null;
      return StepSourceStateChanged(
        sequence: seq,
        sourceState: state,
        code: _enumOrNull(ReconciliationCode.values, s('code')),
      );

    default:
      return null;
  }
}

T? _enumOrNull<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final T v in values) {
    if (v.name == name) return v;
  }
  return null;
}
