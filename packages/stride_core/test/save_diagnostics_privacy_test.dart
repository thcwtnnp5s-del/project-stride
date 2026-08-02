// What a diagnostic is allowed to say.
//
// `save_privacy_test.dart` audits the bytes that reach disk. This file audits
// the other surface the privacy ruling governs: the strings a human or a log
// can see. TECHNICAL/STEP_LEDGER_PRIVACY.md §5 forbids plaintext diagnostic
// logging of slice detail outright, and §4.1 permits `lateDiscardedSlices` in
// "opt-in redacted diagnostics only". DECISIONS/0012 §3 enumerates what may
// survive compaction as metadata.
//
// The propositions under test:
//
//   D-A  A diagnostic built from a realistic two-origin save renders none of
//        the forbidden values: origin keys, bucket boundaries, bucket amounts,
//        cursor bytes, a salt or its fingerprint, save payload, device names.
//   D-B  A diagnostic built from a refusal forwards neither the refusal's
//        player-legible explanation nor a repair's free-form detail — both are
//        strings, and one of them already carries raw exception text upstream.
//   D-C  The permitted fields are actually present. A diagnostic that leaks
//        nothing because it says nothing is not a control, it is an omission.
//   D-D  The field set is frozen, so a new field is a privacy review rather
//        than a commit.
//
// Nothing here may be weakened to go green. A failure is a finding.

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

// --- values that must never be rendered -------------------------------------

/// A cursor value chosen to be unmistakable in a haystack.
///
/// A real HealthKit anchor is opaque bytes; a literal like `'c1'` would be too
/// short to distinguish a leak from a coincidence.
const String distinctiveCursor = 'zzanchortokenzz';

/// Bucket amounts, four digits so they cannot collide with a generation, a
/// journal record count, or a format version.
const int phoneStepsHour0 = 6131;
const int watchStepsHour1 = 2917;
const int phoneStepsHour1 = 8779;

/// A salt fingerprint is never handed to `SaveDiagnostics` — there is no
/// parameter that would accept one. This literal exists so the assertion is
/// written down rather than assumed; the real guard is the frozen key set.
const String saltFingerprintShaped = 'deadbeefcafe1234';

const List<String> deviceNameTokens = <String>[
  'iPhone',
  'iPad',
  'Apple Watch',
  'Pixel',
  'Galaxy',
  "Rob's",
  'HKSource',
  'sourceName',
  'deviceName',
];

// --- the fixture ------------------------------------------------------------

typedef DiagnosticFixture = ({
  FaultingDevice device,
  GameEngine engine,
  SaveLoaded load,
  int journalRecords,
});

/// Several syncs across two origins, a spend, and an equip — then a real load
/// back off the device, so the diagnostic describes something that happened
/// rather than something constructed for the assertion.
Future<DiagnosticFixture> realisticLoad() async {
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final GameEngine engine = newEngine();

  int generation = -1;
  int transaction = 0;

  Future<void> run(GameCommand command) async {
    final EngineResult result = engine.execute(command);
    expect(
      result.isAccepted,
      isTrue,
      reason: '${command.name} was rejected; the fixture is wrong',
    );
    if (result.events.isEmpty) return;
    final CommitOutcome outcome = await commit(
      repo,
      after: engine.state,
      events: result.events,
      generation: generation,
      lastTransaction: transaction,
    );
    expect(outcome, isA<CommitDurable>());
    final CommitDurable durable = outcome as CommitDurable;
    generation = durable.generation;
    transaction = durable.transactionId;
  }

  await run(
    ReconcileStepSync(
      response: incremental(<StepObservation>[
        obs(phone, 0, phoneStepsHour0),
      ], next: distinctiveCursor),
    ),
  );
  await run(
    ReconcileStepSync(
      response: incremental(<StepObservation>[
        obs(watch, 1, watchStepsHour1),
        obs(phone, 1, phoneStepsHour1),
      ], next: distinctiveCursor),
    ),
  );
  await run(const AllocateSteps(steps: 137));
  await run(EquipItem(item: ContentId.unchecked('item.training_sword')));

  final SaveRepository reader = SaveRepository(
    snapshots: FaultingSnapshotStore(device),
    journal: FaultingJournal(device),
  );
  final LoadOutcome outcome = await reader.load(registry: saveRegistry);
  expect(
    outcome,
    isA<SaveLoaded>(),
    reason: 'the fixture must produce a real load to diagnose',
  );

  final List<Uint8List> lines = await FaultingJournal(device).readLines();

  return (
    device: device,
    engine: engine,
    load: outcome as SaveLoaded,
    journalRecords: lines.length,
  );
}

/// Every string a `SaveDiagnostics` can put in front of a human or a log.
List<String> surfacesOf(SaveDiagnostics diagnostics) => <String>[
  diagnostics.render(),
  diagnostics.toString(),
  canonicalJson(diagnostics.toMap()),
];

void main() {
  // ---------------------------------------------------------------- test 1
  group('a diagnostic from a realistic two-origin save leaks nothing', () {
    late DiagnosticFixture fixture;
    late SaveDiagnostics diagnostics;

    setUp(() async {
      fixture = await realisticLoad();
      diagnostics = SaveDiagnostics.fromLoaded(
        fixture.load,
        fixture.engine.state.steps,
        journalRecordCount: fixture.journalRecords,
      );
    });

    test('the fixture is actually worth auditing', () {
      // A test over an empty ledger proves nothing. Two origins, real grants,
      // a real cursor, and a real journal, or the assertions below are theatre.
      expect(fixture.engine.state.steps.grantedSlices.length, greaterThan(1));
      expect(
        fixture.engine.state.steps.grantedSlices.keys
            .map((ObservationKey k) => k.origin)
            .toSet()
            .length,
        2,
        reason: 'the fixture must span two origins',
      );
      expect(
        fixture.engine.state.steps.totalGranted,
        phoneStepsHour0 + watchStepsHour1 + phoneStepsHour1,
      );
      expect(fixture.engine.state.steps.checkpoint.cursor, isNotNull);
      expect(fixture.journalRecords, greaterThan(0));
      expect(
        fixture.load.repairs,
        isEmpty,
        reason:
            'a healthy fixture must load without repairs; a repair here means '
            'the commit protocol changed and the outcome assertions below are '
            'judging something else',
      );
    });

    test('no origin key appears in any rendered surface', () {
      final RegExp originShaped = RegExp('[0-9a-f]{16}');
      for (final String surface in surfacesOf(diagnostics)) {
        expect(
          surface.contains(phone.value),
          isFalse,
          reason: 'a diagnostic names an origin key: $surface',
        );
        expect(
          surface.contains(watch.value),
          isFalse,
          reason: 'a diagnostic names an origin key: $surface',
        );
        expect(
          originShaped.hasMatch(surface),
          isFalse,
          reason: 'a diagnostic contains an origin-key-shaped run: $surface',
        );
      }
    });

    test('no bucket timestamp appears', () {
      // Every boundary the fixture supplied, plus the shape of any epoch
      // millisecond value at all — the second assertion is the one that
      // survives a change of fixture.
      final RegExp epochShaped = RegExp(r'\d{10,}');
      for (final String surface in surfacesOf(diagnostics)) {
        for (int index = 0; index <= 2; index++) {
          expect(
            surface.contains('${t0 + index * hour}'),
            isFalse,
            reason: 'a diagnostic names bucket boundary $index: $surface',
          );
        }
        expect(
          epochShaped.hasMatch(surface),
          isFalse,
          reason: 'a diagnostic contains an epoch-shaped value: $surface',
        );
      }
    });

    test('no bucket amount appears', () {
      for (final String surface in surfacesOf(diagnostics)) {
        for (final int amount in <int>[
          phoneStepsHour0,
          watchStepsHour1,
          phoneStepsHour1,
          fixture.engine.state.steps.totalGranted,
          fixture.engine.state.steps.totalSpent,
        ]) {
          expect(
            surface.contains('$amount'),
            isFalse,
            reason: 'a diagnostic names a step amount ($amount): $surface',
          );
        }
      }
    });

    test('no cursor bytes appear', () {
      for (final String surface in surfacesOf(diagnostics)) {
        expect(
          surface.contains(distinctiveCursor),
          isFalse,
          reason: 'a diagnostic carries the provider cursor: $surface',
        );
        expect(
          surface.toLowerCase().contains('cursor'),
          isFalse,
          reason: 'a diagnostic mentions a cursor at all: $surface',
        );
      }
    });

    test('no salt or salt fingerprint appears', () {
      // There is no parameter that would accept one, which is the real control;
      // this asserts the consequence so a future parameter fails here too.
      for (final String surface in surfacesOf(diagnostics)) {
        expect(surface.contains(saltFingerprintShaped), isFalse);
        expect(surface.toLowerCase().contains('salt'), isFalse);
        expect(surface.toLowerCase().contains('fingerprint'), isFalse);
      }
    });

    test('no save payload appears', () {
      for (final String surface in surfacesOf(diagnostics)) {
        for (final String token in <String>[
          'grantedSlices',
          'inventory',
          'item.training_sword',
          'checkpoint',
          'watermark',
          'totalGranted',
        ]) {
          expect(
            surface.contains(token),
            isFalse,
            reason: 'a diagnostic carries save payload ("$token"): $surface',
          );
        }
      }
    });

    test('no device or source name appears', () {
      for (final String surface in surfacesOf(diagnostics)) {
        for (final String token in deviceNameTokens) {
          expect(
            surface.toLowerCase().contains(token.toLowerCase()),
            isFalse,
            reason: 'a diagnostic contains "$token": $surface',
          );
        }
      }
    });

    // ------------------------------------------------------------ D-C
    test('the permitted fields are actually reported', () {
      final String rendered = diagnostics.render();

      expect(diagnostics.outcome, DiagnosticOutcome.loaded);
      expect(diagnostics.saveFormatVersion, SaveFormatVersion.current);
      expect(diagnostics.snapshotGeneration, fixture.load.generation);
      expect(diagnostics.selectedSlot, fixture.load.fromSlot);
      expect(diagnostics.integrity, DiagnosticIntegrity.verified);
      expect(diagnostics.journalRecordCount, fixture.journalRecords);
      expect(diagnostics.lateDiscardedSlices, 0);

      expect(rendered, contains('outcome=loaded'));
      expect(rendered, contains('integrity=verified'));
      expect(
        rendered,
        contains('lateDiscarded=0'),
        reason:
            'the count must stay legible — a loss you cannot count is a '
            'haunting (STEP_LEDGER_PRIVACY.md §4.1)',
      );
    });
  });

  // ---------------------------------------------------------------- test 2
  group('a diagnostic from a refusal forwards no free text', () {
    // Both of these are strings the production code really can produce:
    // `LoadRefused.explanation` is player-legible prose, and
    // `BootstrapBlocked.detail` is built from an interpolated exception, which
    // on a real device carries a filesystem path.
    const String explanationMarker =
        'MARKER_EXPLANATION /data/user/0/com.projectstride/files/project_stride '
        "on Rob's iPhone at 1750000000000";
    const String detailMarker =
        'MARKER_DETAIL a1b2c3d4e5f60718 1750000003600000 FileSystemException';

    late SaveDiagnostics diagnostics;

    setUp(() {
      diagnostics = SaveDiagnostics.fromRefused(
        LoadRefused(
          reason: LoadRefusal.allSlotsUnreadable,
          explanation: explanationMarker,
          repairs: <SaveRepair>[
            const SaveRepair(
              SaveDiagnosis.slotIntegrityMismatch,
              detail: detailMarker,
            ),
            const SaveRepair(SaveDiagnosis.slotTruncated),
          ],
        ),
        journalRecordCount: 0,
      );
    });

    test('the explanation is not forwarded', () {
      for (final String surface in surfacesOf(diagnostics)) {
        expect(surface.contains('MARKER_EXPLANATION'), isFalse);
        expect(surface.contains('project_stride'), isFalse);
        expect(surface.toLowerCase().contains('iphone'), isFalse);
      }
    });

    test('a repair detail is not forwarded', () {
      for (final String surface in surfacesOf(diagnostics)) {
        expect(
          surface.contains('MARKER_DETAIL'),
          isFalse,
          reason:
              'SaveRepair.detail is free-form text and must never reach a '
              'diagnostic surface',
        );
        expect(surface.contains('a1b2c3d4e5f60718'), isFalse);
        expect(surface.contains('1750000003600000'), isFalse);
        expect(
          surface.toLowerCase().contains('exception'),
          isFalse,
          reason: 'raw exception text reached a diagnostic',
        );
      }
    });

    test('the codes themselves survive, because they are the diagnostic', () {
      expect(diagnostics.outcome, DiagnosticOutcome.refused);
      expect(diagnostics.refusalCode, LoadRefusal.allSlotsUnreadable);
      expect(diagnostics.integrity, DiagnosticIntegrity.mismatch);
      expect(diagnostics.recoveryCodes, <String>[
        'slotIntegrityMismatch',
        'slotTruncated',
      ]);
      expect(diagnostics.snapshotGeneration, isNull);
      expect(diagnostics.selectedSlot, isNull);
      expect(
        diagnostics.lateDiscardedSlices,
        isNull,
        reason:
            'no ledger was available, and reporting 0 would be a claim rather '
            'than an absence',
      );
    });
  });

  // ---------------------------------------------------------------- test 3
  group('the field set is frozen', () {
    test('a new field needs a privacy review', () async {
      final DiagnosticFixture fixture = await realisticLoad();
      final SaveDiagnostics diagnostics = SaveDiagnostics.fromLoaded(
        fixture.load,
        fixture.engine.state.steps,
        journalRecordCount: fixture.journalRecords,
      );

      expect(
        diagnostics.toMap().keys.toSet(),
        <String>{
          'outcome',
          'saveFormatVersion',
          'snapshotGeneration',
          'selectedSlot',
          'integrity',
          'journalRecordCount',
          'lateDiscardedSlices',
          'recoveryCodes',
          'refusalCode',
        },
        reason:
            'a new diagnostic field needs a privacy review before it can '
            'reach a log — see DECISIONS/0012 §3',
      );
    });

    test('every value is an int, an enum name, or a list of enum names', () {
      // The structural claim the whole design rests on: there is no free-form
      // String field, so a leak cannot be introduced by a caller — only by
      // editing this type, which fails the frozen key set above.
      final SaveDiagnostics diagnostics = SaveDiagnostics.fromRefused(
        LoadRefused(
          reason: LoadRefusal.originKeyReset,
          explanation: 'anything at all',
        ),
        journalRecordCount: 3,
      );

      final Set<String> enumNames = <String>{
        ...DiagnosticOutcome.values.map((DiagnosticOutcome e) => e.name),
        ...DiagnosticIntegrity.values.map((DiagnosticIntegrity e) => e.name),
        ...LoadRefusal.values.map((LoadRefusal e) => e.name),
        ...SnapshotSlot.values.map((SnapshotSlot e) => e.name),
        ...SaveDiagnosis.values.map((SaveDiagnosis e) => e.name),
      };

      for (final MapEntry<String, Object?> entry
          in diagnostics.toMap().entries) {
        final Object? value = entry.value;
        if (value == null || value is int) continue;
        if (value is String) {
          expect(
            enumNames.contains(value),
            isTrue,
            reason:
                '"${entry.key}" carries the free-form string "$value". Every '
                'string in a diagnostic must come from a closed enum.',
          );
          continue;
        }
        if (value is List<String>) {
          for (final String element in value) {
            expect(
              enumNames.contains(element),
              isTrue,
              reason: '"${entry.key}" carries free-form string "$element"',
            );
          }
          continue;
        }
        fail('"${entry.key}" is neither an int, an enum name, nor a list');
      }
    });
  });
}
