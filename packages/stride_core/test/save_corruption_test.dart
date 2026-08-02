// One deliberately damaged save per failure mode.
//
// Two rules govern this file.
//
// **Nothing throws.** `load()` is the boundary between "the disk lied" and
// "the player is playing". Every case here asserts `returnsNormally` *and* a
// typed outcome *and* a value, because an outcome type with no value assertion
// would pass just as happily against a load that returned a wiped character.
//
// **Damage that still parses is the interesting damage.** A slot corrupted into
// garbage tests the JSON parser. A slot where one digit of `totalGranted`
// changed from 1000 to 4000 tests the digest — and that is the failure a player
// would actually experience, because flash does not usually fail by writing
// something unparseable.
//
// Quantities are distinct and non-summing — 137, 291, 613, 1000, 1041 — so a
// drop, a duplicate, and an off-by-one each move a *different* number.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

// --- helpers --------------------------------------------------------------

const String slotA = 'save_slot_a';
const String slotB = 'save_slot_b';
const String journalPath = 'journal';

/// A state carrying [steps] granted, and nothing else unusual.
GameState grantedState(int steps) {
  final GameEngine engine = newEngine();
  engine.execute(
    GrantSyntheticSteps(steps: steps, reason: 'corruption fixture'),
  );
  return engine.state;
}

Uint8List snapshotOf(
  GameState state, {
  int generation = 0,
  int lastTransaction = 0,
  String saveId = testSaveId,
}) => encodeSnapshot(
  state: state,
  saveId: saveId,
  generation: generation,
  lastAppliedTransaction: lastTransaction,
);

/// Frames [payload] with a correct header, then applies [overrides].
///
/// Separate from `frame()` so a header field can be made wrong *without* also
/// making the digest wrong — otherwise every header test would be an integrity
/// test wearing a disguise.
Uint8List framedWith(
  Uint8List payload, [
  Map<String, Object?> overrides = const <String, Object?>{},
]) {
  final Map<String, Object?> header = <String, Object?>{
    'm': saveMagic,
    'f': SaveFormatVersion.current,
    'len': payload.length,
    'crc': crc32cHex(payload),
    ...overrides,
  };
  return Uint8List.fromList(<int>[
    ...utf8.encode(canonicalJson(header)),
    0x0A,
    ...payload,
  ]);
}

/// Decodes the envelope of [framed], applies [mutate], and re-frames it with a
/// **correct** digest.
///
/// The digest is recomputed on purpose: these cases test the envelope
/// validators, and a stale checksum would short-circuit every one of them at
/// the frame layer and prove nothing.
Uint8List remake(
  Uint8List framed,
  void Function(Map<String, Object?> envelope, Map<String, Object?> state)
  mutate,
) {
  final FrameResult result = unframe(framed);
  expect(result.verified, isTrue, reason: 'the base fixture must be healthy');
  final Map<String, Object?> envelope =
      jsonDecode(utf8.decode(result.payload!)) as Map<String, Object?>;
  mutate(envelope, envelope['state']! as Map<String, Object?>);
  return frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));
}

void seedJournal(FaultingDevice device, List<Uint8List> lines) {
  final List<int> joined = <int>[];
  for (final Uint8List line in lines) {
    joined.addAll(line);
  }
  device.seed(journalPath, Uint8List.fromList(joined));
}

/// One well-formed journal line, so "the journal is not empty" is expressible
/// without also being "the journal is corrupt".
Uint8List someJournalLine({String saveId = testSaveId}) {
  final GameEngine engine = newEngine();
  final GameState before = engine.state;
  final EngineResult result = engine.execute(
    const GrantSyntheticSteps(steps: 291, reason: 'journal line'),
  );
  return encodeJournalLine(
    JournalRecord(
      formatVersion: SaveFormatVersion.current,
      saveId: saveId,
      transactionId: 1,
      eventSequenceBefore: before.eventSequence,
      eventSequenceAfter: engine.state.eventSequence,
      events: result.events,
    ),
  );
}

/// Loads, and fails the test if anything escaped rather than returning.
///
/// This is the `returnsNormally` assertion for every case in the file. A
/// `FormatException` or a `TypeError` reaching a caller is the same defect as
/// losing the save, because the app has no typed outcome to render.
Future<LoadOutcome> loadWithoutThrowing(
  FaultingDevice device, {
  bool treatAsRelease = false,
}) async {
  final SaveRepository repo = newRepo(device).repo;
  Object? thrown;
  StackTrace? trace;
  LoadOutcome? outcome;
  try {
    outcome = await repo.load(
      registry: saveRegistry,
      treatAsRelease: treatAsRelease,
    );
  } on Object catch (e, st) {
    thrown = e;
    trace = st;
  }
  expect(
    thrown,
    isNull,
    reason:
        'load() must never throw for a damaged save; it threw '
        '${thrown.runtimeType}: $thrown\n$trace',
  );
  return outcome!;
}

bool hasDiagnosis(List<SaveRepair> repairs, SaveDiagnosis diagnosis) =>
    repairs.any((SaveRepair r) => r.diagnosis == diagnosis);

/// Everything a refusal shows to a human, concatenated. Used to assert that a
/// value which must never be surfaced is not surfaced.
String refusalText(LoadRefused refused) =>
    '${refused.reason.name}|${refused.explanation}|'
    '${refused.repairs.map((SaveRepair r) => r.toString()).join('|')}';

// --- cases ----------------------------------------------------------------

/// One malformed artifact and the per-slot diagnosis it must produce.
final class MalformedCase {
  const MalformedCase(this.name, this.bytes);
  final String name;
  final Uint8List Function() bytes;
}

void main() {
  group('a damaged slot with a healthy sibling', () {
    test('a truncated slot falls back and the totals survive', () async {
      final Uint8List newer = snapshotOf(
        grantedState(1041),
        generation: 1,
        lastTransaction: 2,
      );
      final Uint8List older = snapshotOf(grantedState(613));

      final FaultingDevice device = FaultingDevice()
        // The live, higher-generation slot lost its tail mid-write.
        ..seed(slotA, Uint8List.sublistView(newer, 0, newer.length - 20))
        ..seed(slotB, older);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.b);
      expect(
        loaded.state.steps.totalGranted,
        613,
        reason: 'the surviving slot must load intact, not empty',
      );
      expect(loaded.state.steps.totalGranted, isNot(0));
      expect(loaded.degraded, isTrue);
      expect(hasDiagnosis(loaded.repairs, SaveDiagnosis.slotTruncated), isTrue);
    });
  });

  group('nothing readable', () {
    test(
      'both slots unreadable with a journal refuses and touches nothing',
      () async {
        final Uint8List healthy = snapshotOf(grantedState(613));
        final FaultingDevice device = FaultingDevice()
          ..seed(slotA, Uint8List.sublistView(healthy, 0, healthy.length - 30))
          ..seed(
            slotB,
            Uint8List.fromList(utf8.encode('garbage\nnot a payload')),
          );
        seedJournal(device, <Uint8List>[someJournalLine()]);

        final String before = device.image();
        expect(
          before,
          isNotEmpty,
          reason: 'the fixture must actually be on disk',
        );

        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.allSlotsUnreadable);
        expect(
          refused.explanation,
          contains('have not been modified'),
          reason: 'the player must be told the files are still there',
        );
        expect(
          device.image(),
          before,
          reason:
              'a refusal must leave every byte in place, or the human recovery '
              'path (pull the files off the device) is gone',
        );
      },
    );

    test(
      'an empty slot file refuses rather than reporting a new game',
      () async {
        // A zero-length file is what a truncate-to-zero leaves behind. With a
        // journal present it must never be read as "this player is new".
        final FaultingDevice device = FaultingDevice()
          ..seed(slotA, Uint8List(0));
        seedJournal(device, <Uint8List>[someJournalLine()]);

        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isNot(isA<NoSaveFound>()));
        expect(outcome, isA<LoadRefused>());
        expect((outcome as LoadRefused).reason, LoadRefusal.allSlotsUnreadable);
      },
    );
  });

  group('malformed encoding', () {
    final List<MalformedCase> cases = <MalformedCase>[
      MalformedCase(
        'valid UTF-8 that is not JSON',
        () => Uint8List.fromList(
          utf8.encode('this is not a save at all\n{"state":{}}'),
        ),
      ),
      MalformedCase(
        'valid JSON of the wrong shape',
        () => framedWith(Uint8List.fromList(utf8.encode('[1,2,3]'))),
      ),
      MalformedCase(
        'a string where an int belongs',
        () => remake(
          snapshotOf(grantedState(613)),
          (Map<String, Object?> envelope, Map<String, Object?> _) =>
              envelope['eventSequence'] = '2',
        ),
      ),
      MalformedCase(
        'a frame line with no newline',
        () => Uint8List.fromList(
          utf8.encode('{"crc":"00000000","f":1,"len":0,"m":"stride.save"}'),
        ),
      ),
      MalformedCase('payload longer than the declared len', () {
        final Uint8List healthy = snapshotOf(grantedState(613));
        return Uint8List.fromList(<int>[...healthy, 0x20, 0x78]);
      }),
      MalformedCase(
        'the declared len is a string',
        () => framedWith(
          Uint8List.fromList(utf8.encode('{}')),
          <String, Object?>{'len': '2'},
        ),
      ),
      MalformedCase(
        'the magic is absent',
        () => framedWith(
          Uint8List.fromList(utf8.encode('{}')),
          <String, Object?>{'m': 'some.other.file'},
        ),
      ),
    ];

    for (final MalformedCase fixture in cases) {
      test(fixture.name, () async {
        final FaultingDevice device = FaultingDevice()
          ..seed(slotA, fixture.bytes());

        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.allSlotsUnreadable);
        expect(
          hasDiagnosis(refused.repairs, SaveDiagnosis.slotMalformedEncoding),
          isTrue,
          reason:
              'the slot must be diagnosed as malformed, not merely skipped: '
              '${refusalText(refused)}',
        );
      });
    }
  });

  group('integrity', () {
    test('a flipped digit that still parses is caught by the digest', () async {
      // The whole point. `totalGranted` goes from 1000 to 4000: same length,
      // still valid JSON, still a valid envelope, still a plausible number.
      // Only the checksum knows.
      final Uint8List healthy = snapshotOf(grantedState(1000));
      final String text = utf8.decode(healthy);
      expect(text, contains('"totalGranted":1000'));

      final String tampered = text.replaceFirst(
        '"totalGranted":1000',
        '"totalGranted":4000',
      );
      final Uint8List bytes = Uint8List.fromList(utf8.encode(tampered));
      expect(
        bytes.length,
        healthy.length,
        reason:
            'the tamper must not change the length, or this is a '
            'truncation test rather than an integrity test',
      );

      // Proof the payload really does still parse — otherwise the parser, not
      // the digest, is what rejected it.
      final Map<String, Object?> stillParses =
          jsonDecode(tampered.substring(tampered.indexOf('\n') + 1))
              as Map<String, Object?>;
      expect(
        ((stillParses['state']! as Map<String, Object?>)['steps']!
            as Map<String, Object?>)['totalGranted'],
        4000,
      );

      expect(unframe(bytes).fault, FrameFault.integrityMismatch);

      final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(
        outcome,
        isNot(isA<SaveLoaded>()),
        reason: 'a silently accepted 4000 is 3000 fabricated steps',
      );
      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.allSlotsUnreadable);
      expect(
        hasDiagnosis(refused.repairs, SaveDiagnosis.slotIntegrityMismatch),
        isTrue,
        reason: refusalText(refused),
      );
    });
  });

  group('version skew', () {
    test('a future save format is refused and nothing is deleted', () async {
      final FrameResult healthy = unframe(snapshotOf(grantedState(613)));
      final Uint8List bytes = framedWith(
        healthy.payload!,
        const <String, Object?>{'f': 99},
      );

      final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
      final String before = device.image();

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.futureSaveFormat);
      expect(refused.explanation, contains('Update the app'));
      expect(refused.explanation, contains('Nothing has been changed'));
      expect(
        device.image(),
        before,
        reason:
            'a version skew that deletes the save turns a recoverable '
            'situation into permanent loss',
      );
    });

    test('an unsupported state version is refused', () async {
      final Uint8List bytes = remake(snapshotOf(grantedState(613)), (
        Map<String, Object?> envelope,
        Map<String, Object?> state,
      ) {
        envelope['gameStateVersion'] = 7;
        state['stateVersion'] = 7;
      });

      final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.unsupportedStateVersion);
      expect(
        hasDiagnosis(
          refused.repairs,
          SaveDiagnosis.slotUnsupportedStateVersion,
        ),
        isTrue,
        reason: refusalText(refused),
      );
    });
  });

  group('envelope self-consistency', () {
    test(
      'a missing commitComplete marker rejects a slot whose digest verifies',
      () async {
        final Uint8List bytes = remake(
          snapshotOf(grantedState(613)),
          (Map<String, Object?> envelope, Map<String, Object?> _) =>
              envelope.remove('commitComplete'),
        );

        // The digest is correct. Only the marker is gone — the signature of a
        // process that died part-way through writing the payload.
        expect(unframe(bytes).verified, isTrue);

        final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.allSlotsUnreadable);
        expect(
          hasDiagnosis(refused.repairs, SaveDiagnosis.slotIncompleteCommit),
          isTrue,
          reason:
              'a verified digest is not enough; the marker is what says the '
              'encode finished: ${refusalText(refused)}',
        );
      },
    );

    test('a header that disagrees with its payload rejects the slot', () async {
      final Uint8List bytes = remake(
        snapshotOf(grantedState(613)),
        (Map<String, Object?> envelope, Map<String, Object?> state) =>
            envelope['eventSequence'] = (state['eventSequence']! as int) + 1,
      );

      expect(unframe(bytes).verified, isTrue);

      final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.allSlotsUnreadable);
      expect(
        hasDiagnosis(
          refused.repairs,
          SaveDiagnosis.slotHeaderDisagreesWithPayload,
        ),
        isTrue,
        reason: refusalText(refused),
      );
    });
  });

  group('content references', () {
    test(
      'an unknown item refuses the load rather than dropping the item',
      () async {
        final Uint8List bytes = remake(snapshotOf(grantedState(613)), (
          Map<String, Object?> _,
          Map<String, Object?> state,
        ) {
          final List<Object?> inventory = state['inventory']! as List<Object?>;
          inventory.add(<String, Object?>{'id': 'item.phantom_relic', 'n': 3});
        });

        final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
        final String before = device.image();

        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(
          outcome,
          isNot(isA<SaveLoaded>()),
          reason:
              'dropping the entry would silently delete the possessions of '
              'a player who did nothing wrong',
        );
        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.unknownContent);
        expect(
          refused.explanation,
          contains('item.phantom_relic'),
          reason: 'the build that broke ID permanence must be named',
        );
        expect(device.image(), before);
      },
    );
  });

  group('balance profile authority', () {
    Uint8List withProfile(String profileId) => remake(
      snapshotOf(grantedState(613)),
      (Map<String, Object?> envelope, Map<String, Object?> state) {
        envelope['balanceProfileId'] = profileId;
        state['profileId'] = profileId;
      },
    );

    test('an unknown profile is refused', () async {
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, withProfile('profile.homebrew'));

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.unknownProfile);
      expect(refused.explanation, contains('profile.homebrew'));
    });

    test('an accelerated QA save is refused by a release build', () async {
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, withProfile('profile.accelerated_qa'));

      final LoadOutcome outcome = await loadWithoutThrowing(
        device,
        treatAsRelease: true,
      );

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.qaProfileForbiddenInRelease);
      expect(refused.explanation, contains('accelerated QA pacing'));
    });

    test(
      'a profile the app is not running requires a deliberate migration',
      () async {
        // Same save, non-release build. The refusal changes, and it must still
        // be a refusal: reinterpreting QA pacing as production pacing silently
        // changes what every number in the save means.
        final FaultingDevice device = FaultingDevice()
          ..seed(slotA, withProfile('profile.accelerated_qa'));

        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.profileMigrationRequired);
        expect(refused.explanation, contains('profile.accelerated_qa'));
        expect(refused.explanation, contains('profile.production'));
      },
    );
  });

  group('journal', () {
    /// A snapshot at genesis plus two transactions that were never folded in.
    ({
      Uint8List snapshot,
      JournalRecord tx1,
      JournalRecord tx2,
      GameState afterTx1,
      GameState afterTx2,
    })
    journalScenario() {
      final GameEngine engine = newEngine();
      final GameState genesis = engine.state;

      final EngineResult first = engine.execute(
        const GrantSyntheticSteps(steps: 291, reason: 'tx1'),
      );
      final GameState afterFirst = engine.state;
      final EngineResult second = engine.execute(
        const GrantSyntheticSteps(steps: 137, reason: 'tx2'),
      );
      final GameState afterSecond = engine.state;

      return (
        snapshot: snapshotOf(genesis),
        tx1: JournalRecord(
          formatVersion: SaveFormatVersion.current,
          saveId: testSaveId,
          transactionId: 1,
          eventSequenceBefore: genesis.eventSequence,
          eventSequenceAfter: afterFirst.eventSequence,
          events: first.events,
        ),
        tx2: JournalRecord(
          formatVersion: SaveFormatVersion.current,
          saveId: testSaveId,
          transactionId: 2,
          eventSequenceBefore: afterFirst.eventSequence,
          eventSequenceAfter: afterSecond.eventSequence,
          events: second.events,
        ),
        afterTx1: afterFirst,
        afterTx2: afterSecond,
      );
    }

    JournalRecord relabel(JournalRecord record, int transactionId) =>
        JournalRecord(
          formatVersion: record.formatVersion,
          saveId: record.saveId,
          transactionId: transactionId,
          eventSequenceBefore: record.eventSequenceBefore,
          eventSequenceAfter: record.eventSequenceAfter,
          events: record.events,
        );

    JournalRecord relineage(JournalRecord record, String saveId) =>
        JournalRecord(
          formatVersion: record.formatVersion,
          saveId: saveId,
          transactionId: record.transactionId,
          eventSequenceBefore: record.eventSequenceBefore,
          eventSequenceAfter: record.eventSequenceAfter,
          events: record.events,
        );

    test('an intact journal replays and the totals are exact', () async {
      final scenario = journalScenario();
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, scenario.snapshot);
      seedJournal(device, <Uint8List>[
        encodeJournalLine(scenario.tx1),
        encodeJournalLine(scenario.tx2),
      ]);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(loaded.state.steps.totalGranted, 428);
      expect(loaded.replayedTransactions, 2);
      expect(loaded.lastAppliedTransaction, 2);
    });

    test('a sequence gap stops the replay at the hole', () async {
      final scenario = journalScenario();
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, scenario.snapshot);
      seedJournal(device, <Uint8List>[
        encodeJournalLine(scenario.tx1),
        encodeJournalLine(relabel(scenario.tx2, 3)),
      ]);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(
        loaded.state.steps.totalGranted,
        291,
        reason: 'everything after the hole must be discarded, not applied',
      );
      expect(loaded.replayedTransactions, 1);
      expect(
        hasDiagnosis(loaded.repairs, SaveDiagnosis.journalSequenceGap),
        isTrue,
        reason: '${loaded.repairs}',
      );
    });

    test('a duplicate with an identical payload is absorbed', () async {
      // An append whose acknowledgement was lost. At-least-once flushing
      // produces exactly this, and it is benign.
      final scenario = journalScenario();
      final Uint8List line = encodeJournalLine(scenario.tx1);
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, scenario.snapshot);
      seedJournal(device, <Uint8List>[
        line,
        Uint8List.fromList(line),
        encodeJournalLine(scenario.tx2),
      ]);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(
        loaded.state.steps.totalGranted,
        428,
        reason: 'absorbing the duplicate must not credit 291 twice',
      );
      expect(loaded.replayedTransactions, 2);
      expect(
        hasDiagnosis(loaded.repairs, SaveDiagnosis.journalDuplicateTransaction),
        isTrue,
        reason: '${loaded.repairs}',
      );
    });

    test('a duplicate with a different payload forks and is refused', () async {
      final scenario = journalScenario();
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, scenario.snapshot);
      seedJournal(device, <Uint8List>[
        encodeJournalLine(scenario.tx1),
        // Same transaction id, different history. Identity is not a function
        // of content, so nothing after this is trustworthy.
        encodeJournalLine(relabel(scenario.tx2, 1)),
      ]);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.journalForked);
      expect(refused.explanation, contains('same transaction'));
    });

    test('a record from another lineage refuses the load', () async {
      final scenario = journalScenario();
      final FaultingDevice device = FaultingDevice()
        ..seed(slotA, scenario.snapshot);
      seedJournal(device, <Uint8List>[
        encodeJournalLine(relineage(scenario.tx1, 'save-9999')),
      ]);

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.lineageMismatch);
      expect(refused.explanation, contains('different save'));
    });
  });

  group('the damage helpers do not fire spuriously', () {
    // Every case above proves a validator fires. These prove the *fixtures* are
    // not themselves the failure: a `remake` or `framedWith` that broke the
    // payload on its own would make the whole file pass while checking nothing.
    test('remake with no mutation still loads cleanly', () async {
      final FaultingDevice device = FaultingDevice()
        ..seed(
          slotA,
          remake(
            snapshotOf(grantedState(613)),
            (Map<String, Object?> _, Map<String, Object?> _) {},
          ),
        );

      final LoadOutcome outcome = await loadWithoutThrowing(device);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(loaded.state.steps.totalGranted, 613);
      expect(loaded.repairs, isEmpty);
    });

    test('framedWith with no overrides produces a verifiable frame', () {
      final FrameResult healthy = unframe(snapshotOf(grantedState(613)));
      expect(unframe(framedWith(healthy.payload!)).verified, isTrue);
    });
  });

  group('privacy', () {
    test(
      'a device name in an origin key rejects the slot without echoing it',
      () async {
        // "Robs iPhone" is the exact thing StepOriginKey exists to keep out. It
        // must be refused *and* must not reappear in a diagnostic, because a
        // diagnostic is a surface a log or a bug report will carry.
        const String deviceName = 'Robs iPhone';

        final Uint8List bytes = remake(snapshotOf(grantedState(613)), (
          Map<String, Object?> _,
          Map<String, Object?> state,
        ) {
          final Map<String, Object?> steps =
              state['steps']! as Map<String, Object?>;
          steps['grantedSlices'] = <Object?>[
            <String, Object?>{
              'o': deviceName,
              's': t0,
              'e': t0 + hour,
              'g': 613,
            },
          ];
        });

        // The codec-level assertion: the message names a length, never a value.
        expect(
          () => decodeEnvelope(unframe(bytes).payload!),
          throwsA(
            isA<SaveCodecException>()
                .having(
                  (SaveCodecException e) => e.message,
                  'message',
                  isNot(contains('Robs')),
                )
                .having(
                  (SaveCodecException e) => e.message,
                  'message',
                  contains('length ${deviceName.length}'),
                ),
          ),
        );

        final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
        final LoadOutcome outcome = await loadWithoutThrowing(device);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.allSlotsUnreadable);
        expect(
          // Specifically `originKeyRejected`, not generic malformed encoding.
          // The distinction is the point: this one means an adapter wrote a
          // raw platform identifier past the pseudonymization boundary, and
          // the fix is in the adapter rather than in the save format.
          hasDiagnosis(refused.repairs, SaveDiagnosis.originKeyRejected),
          isTrue,
          reason: refusalText(refused),
        );
        expect(
          refusalText(refused),
          isNot(contains('Robs')),
          reason:
              'the rejected value must never reach a player-facing or '
              'diagnostic surface',
        );
      },
    );
  });
}
