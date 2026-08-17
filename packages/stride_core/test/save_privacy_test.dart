// Privacy audit of what actually reaches disk.
//
// Every other save test asserts on decoded objects. This one asserts on the
// **raw durable bytes**, because that is the only artifact the owner's ruling
// in TECHNICAL/STEP_LEDGER_PRIVACY.md actually governs. A decoded object can
// be clean while the file that produced it carries a field nobody reads.
//
// The ruling, restated as testable propositions:
//
//   P-A  Per slice, only a pseudonymous origin key, a UTC bucket, the amount
//        already granted, and minimum schema metadata are persisted.
//   P-B  Never persisted: raw health records, sub-bucket timestamps, device
//        names, source display names, workout categories, location, heart data,
//        original native payloads.
//   P-C  Retention is bounded (7 days default, 48 hour floor) and enforced in
//        the bytes, not merely in memory.
//   P-D  The journal is a privacy artifact. Every reconciliation record carries
//        a full granted-slice map, so an uncompacted journal is a permanent
//        unbounded step history — the ruling reintroduced through the back door.
//   P-E  No player-visible or diagnostic string carries a health-derived value.
//
// Nothing here may be weakened to go green. A failure is a finding.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

// --- what a leak looks like ------------------------------------------------

/// Substrings that must never appear in a durable artifact.
///
/// Two kinds. The first are field names from the platform payloads the adapter
/// is supposed to have already discarded — one of these appearing means a raw
/// record reached the core. The second are device-name-shaped strings: the
/// original iOS implementation of the origin field was `HKSource.name`, which
/// is whatever the player called their phone.
const List<String> forbiddenTokens = <String>[
  // Platform record identity — an adapter-only concern.
  'sampleId',
  'recordUid',
  'HKSource',
  'sourceName',
  'deviceName',
  'uuid',
  // Health data categories that are not steps.
  'workout',
  'latitude',
  'longitude',
  'heartRate',
  // Device-name-shaped strings.
  'iPhone',
  'iPad',
  'Apple Watch',
  'Pixel',
  'Galaxy',
  "Rob's",
];

/// Everything F-05 can write.
const List<String> durablePaths = <String>[
  'save_slot_a',
  'save_slot_b',
  'journal',
  'journal.compacting',
];

typedef SavedFixture = ({FaultingDevice device, Driver driver});
typedef RetentionFixture = ({FaultingDevice device, Driver driver, int days});
typedef LateDiscardFixture = ({GameEngine engine, EngineResult rescanResult});

String? durableText(FaultingDevice device, String path) {
  final Uint8List? bytes = device.committedBytes(path);
  return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
}

void expectNoForbiddenTokens(FaultingDevice device) {
  for (final String path in durablePaths) {
    final String? text = durableText(device, path);
    if (text == null) continue;
    final String lower = text.toLowerCase();
    for (final String token in forbiddenTokens) {
      expect(
        lower.contains(token.toLowerCase()),
        isFalse,
        reason:
            'durable artifact "$path" contains "$token". Raw health data must '
            'never reach disk (TECHNICAL/STEP_LEDGER_PRIVACY.md §6).',
      );
    }
  }
}

// --- reading the bytes back ------------------------------------------------

Map<String, Object?> decodeSlotBytes(FaultingDevice device, String path) {
  final Uint8List? bytes = device.committedBytes(path);
  expect(bytes, isNotNull, reason: '$path should be durable');
  final FrameResult framed = unframe(bytes!);
  expect(framed.verified, isTrue, reason: '$path did not verify');
  return jsonDecode(utf8.decode(framed.payload!)) as Map<String, Object?>;
}

Map<String, Object?> stepsOf(Map<String, Object?> envelope) =>
    (envelope['state']! as Map<String, Object?>)['steps']!
        as Map<String, Object?>;

List<Map<String, Object?>> slicesOf(Map<String, Object?> envelope) =>
    (stepsOf(envelope)['grantedSlices']! as List<Object?>)
        .cast<Map<String, Object?>>();

int watermarkOf(Map<String, Object?> envelope) =>
    (stepsOf(envelope)['checkpoint']!
            as Map<String, Object?>)['watermarkMillis']!
        as int;

/// The snapshot paths that actually hold bytes right now.
List<String> presentSlots(FaultingDevice device) => <String>[
  for (final String path in <String>['save_slot_a', 'save_slot_b'])
    if (device.committedBytes(path) != null) path,
];

/// Every observation key named by the durable journal.
///
/// Parsed from the committed bytes, not obtained from a repository call — the
/// question is what is *on disk*, not what an API is willing to return.
List<ObservationKey> journalObservationKeys(FaultingDevice device) {
  final Uint8List? bytes = device.committedBytes('journal');
  if (bytes == null) return <ObservationKey>[];

  final List<ObservationKey> keys = <ObservationKey>[];
  int start = 0;
  for (int i = 0; i <= bytes.length; i++) {
    final bool atEnd = i == bytes.length;
    if (!atEnd && bytes[i] != 0x0A) continue;
    if (start >= i) {
      start = i + 1;
      continue;
    }
    final JournalLineResult parsed = decodeJournalLine(
      Uint8List.sublistView(bytes, start, atEnd ? i : i + 1),
    );
    start = i + 1;
    if (!parsed.ok) continue;
    for (final GameEvent event in parsed.record!.events) {
      if (event is StepObservationReconciled) {
        keys.addAll(event.grantedSlicesAfter.keys);
      }
    }
  }
  return keys;
}

// --- driving a realistic save ----------------------------------------------

/// Runs commands through the engine and commits each one, tracking the
/// compare-and-swap expectation the way the app layer will have to.
final class Driver {
  Driver(this.repo, this.engine);

  final SaveRepository repo;
  final GameEngine engine;

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
    expect(durable.snapshotDurable, isTrue);
    generation = durable.generation;
    transaction = durable.transactionId;
  }
}

/// Several syncs across two origins, a spend, and an equip.
Future<SavedFixture> realisticSave() async {
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final Driver driver = Driver(repo, newEngine());

  await driver.run(
    ReconcileStepSync(
      response: incremental(<StepObservation>[obs(phone, 0, 613)], next: 'c1'),
    ),
  );
  await driver.run(
    ReconcileStepSync(
      response: incremental(<StepObservation>[
        obs(watch, 1, 291),
        obs(phone, 1, 877),
      ], next: 'c2'),
    ),
  );
  await driver.run(
    ReconcileStepSync(
      response: incremental(
        <StepObservation>[obs(phone, 2, 409)],
        next: 'c3',
        completeThroughIndex: 1,
      ),
    ),
  );
  await driver.run(const AllocateSteps(steps: 137));
  await driver.run(EquipItem(item: ContentId.unchecked('item.training_sword')));

  return (device: device, driver: driver);
}

/// Fourteen days of complete-asserted syncs, one commit per day.
Future<RetentionFixture> fourteenDaysCommitted() async {
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final Driver driver = Driver(repo, newEngine());

  const int days = 14;
  for (int day = 0; day < days; day++) {
    await driver.run(
      ReconcileStepSync(
        response: incremental(
          <StepObservation>[obs(phone, day * 24, 1000)],
          next: 'd$day',
          completeThroughIndex: day * 24 + 1,
        ),
      ),
    );
  }
  return (device: device, driver: driver, days: days);
}

int dayStart(int day) => t0 + day * 24 * hour;
int dayEnd(int day) => t0 + (day * 24 + 1) * hour;

// --- refusal fixtures ------------------------------------------------------

Map<String, Object?> envelopeJsonOf(
  GameState state, {
  int generation = 0,
  int transaction = 0,
  String saveId = testSaveId,
}) =>
    jsonDecode(
          utf8.decode(
            unframe(
              encodeSnapshot(
                state: state,
                saveId: saveId,
                generation: generation,
                lastAppliedTransaction: transaction,
                originSaltFingerprint: null,
              ),
            ).payload!,
          ),
        )
        as Map<String, Object?>;

Uint8List framedFrom(Map<String, Object?> envelope) =>
    frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));

Uint8List reframedWithFormat(Map<String, Object?> envelope, int format) {
  final Uint8List payload = Uint8List.fromList(
    utf8.encode(canonicalJson(envelope)),
  );
  final Map<String, Object?> header = <String, Object?>{
    'm': saveMagic,
    'f': format,
    'len': payload.length,
    'crc': crc32cHex(payload),
  };
  return Uint8List.fromList(<int>[
    ...utf8.encode(canonicalJson(header)),
    0x0A,
    ...payload,
  ]);
}

/// A state with real slices in it, so a refusal has something to leak.
GameState populatedState() {
  final GameEngine engine = newEngine();
  sync(
    engine,
    incremental(<StepObservation>[
      obs(phone, 0, 613),
      obs(watch, 1, 291),
    ], next: 'c1'),
  );
  return engine.state;
}

/// The list of persisted slices inside a decoded envelope, for mutation.
List<Object?> rawSlicesIn(Map<String, Object?> envelope) =>
    ((envelope['state']! as Map<String, Object?>)['steps']!
            as Map<String, Object?>)['grantedSlices']!
        as List<Object?>;

/// A lock that is never available — the other-process-holds-it case.
///
/// Needed here because `storageBusy` is a refusal whose explanation reaches the
/// player, and a refusal that is not in the audit below is a string nobody
/// privacy-reviewed.
final class NeverAvailableLock implements TransactionLock {
  const NeverAvailableLock();

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async => null;
}

Future<LoadRefused> refusalFrom(
  FaultingDevice device, {
  bool treatAsRelease = false,
  TransactionLock lock = const UncontendedLock(),
}) async {
  final SaveRepository repo = SaveRepository(
    snapshots: FaultingSnapshotStore(device),
    journal: FaultingJournal(device),
    lock: lock,
    lockTimeout: const Duration(milliseconds: 1),
  );
  final LoadOutcome outcome = await repo.load(
    registry: saveRegistry,
    treatAsRelease: treatAsRelease,
  );
  expect(outcome, isA<LoadRefused>(), reason: 'expected a refusal');
  return outcome as LoadRefused;
}

/// The refusals the fixtures below can actually reach.
///
/// `originKeyReset` is absent because nothing in `stride_core` constructs it —
/// there is no origin-key-reset detection yet. See the coverage test.
const Set<LoadRefusal> reachableRefusals = <LoadRefusal>{
  LoadRefusal.allSlotsUnreadable,
  LoadRefusal.futureSaveFormat,
  LoadRefusal.unsupportedStateVersion,
  LoadRefusal.divergentSlotsAtSameGeneration,
  LoadRefusal.qaProfileForbiddenInRelease,
  LoadRefusal.profileMigrationRequired,
  LoadRefusal.unknownProfile,
  LoadRefusal.unsupportedContentSchema,
  LoadRefusal.unknownContent,
  LoadRefusal.lineageMismatch,
  LoadRefusal.journalForked,
  LoadRefusal.storageBusy,
  LoadRefusal.resetIncomplete,
};

void main() {
  // ---------------------------------------------------------------- test 1
  group('raw durable bytes carry nothing health-derived', () {
    test('a realistic save contains none of the forbidden tokens', () async {
      final SavedFixture saved = await realisticSave();

      // Sanity: the fixture actually wrote something worth auditing.
      expect(saved.driver.engine.state.steps.totalGranted, 2190);
      expect(saved.driver.engine.state.steps.totalSpent, 137);
      expect(saved.device.committedBytes('save_slot_a'), isNotNull);
      expect(saved.device.committedBytes('save_slot_b'), isNotNull);
      expect(saved.device.committedBytes('journal'), isNotNull);
      expect(
        durableText(saved.device, 'save_slot_a'),
        contains('grantedSlices'),
      );

      expectNoForbiddenTokens(saved.device);
    });

    test('a device name cannot be constructed, so it cannot be stored', () {
      // Wrong length is the first gate. "Rob's iPhone" is 12 characters.
      expect(
        StepOriginKey.validate("Rob's iPhone"),
        OriginKeyRefusal.wrongLength,
      );
      expect(
        () => StepOriginKey("Rob's iPhone"),
        throwsA(isA<InvalidOriginKeyException>()),
      );

      // Exactly 16 characters, so only the alphabet can refuse it. This is the
      // gate that matters: a name padded to the right length is still a name.
      expect(
        StepOriginKey.validate('Robs-iPhone-15pr'),
        OriginKeyRefusal.notLowercaseHex,
      );
      expect(
        () => StepOriginKey('Robs-iPhone-15pr'),
        throwsA(isA<InvalidOriginKeyException>()),
      );

      // Nor a bundle id, a dashed UUID, uppercase hex, or a near miss.
      for (final String candidate in <String>[
        'com.apple.health',
        '3F2504E0-4F89-11D3',
        'A1B2C3D4E5F60718',
        '',
        'a1b2c3d4e5f6071',
        'a1b2c3d4e5f607189',
      ]) {
        expect(
          StepOriginKey.tryParse(candidate),
          isNull,
          reason: '"$candidate" must not be representable as an origin key',
        );
      }

      // The only two shapes that are representable.
      expect(StepOriginKey.tryParse('a1b2c3d4e5f60718'), isNotNull);
      expect(StepOriginKey.tryParse('unknown'), StepOriginKey.unknown);
    });

    test('a slice keyed by an unrepresentable origin cannot be built', () {
      // The negative assertion over bytes proves no name is there today. This
      // proves none can be put there tomorrow without changing the type.
      expect(
        () => ObservationKey(
          origin: StepOriginKey('My iPhone 15 Pro'),
          bucket: const TimeBucket(startMillis: 0, endMillis: 1),
        ),
        throwsA(isA<InvalidOriginKeyException>()),
      );
    });
  });

  // ---------------------------------------------------------------- test 2
  group('every persisted origin is a valid pseudonymous key', () {
    test('structurally, over the decoded slice list', () async {
      final SavedFixture saved = await realisticSave();

      final RegExp shape = RegExp(r'^([0-9a-f]{16}|unknown)$');
      int checked = 0;

      for (final String path in presentSlots(saved.device)) {
        final List<Map<String, Object?>> slices = slicesOf(
          decodeSlotBytes(saved.device, path),
        );
        expect(slices, isNotEmpty, reason: '$path has no slices to audit');
        for (final Map<String, Object?> slice in slices) {
          final Object? origin = slice['o'];
          expect(
            origin,
            isA<String>(),
            reason: '$path: origin is not a string',
          );
          final String value = origin! as String;
          expect(
            shape.hasMatch(value),
            isTrue,
            reason:
                '$path: "$value" is not 16 lowercase hex or "unknown". A '
                'free-form origin is where a device name gets in.',
          );
          // The type agrees with the shape — belt and braces, because the type
          // is what production code actually enforces.
          expect(StepOriginKey.validate(value), isNull);
          checked++;
        }
      }
      expect(checked, greaterThan(0), reason: 'nothing was actually audited');
    });

    test('the journal holds origins to the same standard', () async {
      final SavedFixture saved = await realisticSave();

      // `realisticSave` ends on a spend and an equip, and compaction retains
      // only the newest record — which therefore carries no slices at all.
      // One more reconciliation puts a slice-bearing record back in the
      // journal, so the assertion below has something to judge.
      //
      // This is a fixture correction, not a softened assertion: the test
      // failed with its own "proved nothing" reason string, which is exactly
      // the diagnosis it was written to produce.
      await saved.driver.run(
        ReconcileStepSync(
          response: incremental(<StepObservation>[
            obs(phone, 3, 251),
          ], next: 'c4'),
        ),
      );

      int checked = 0;

      for (final ObservationKey key in journalObservationKeys(saved.device)) {
        expect(StepOriginKey.validate(key.origin.value), isNull);
        checked++;
      }
      expect(
        checked,
        greaterThan(0),
        reason:
            'the journal carried no slices at all, so this test proved '
            'nothing; the fixture must reach a reconciliation record',
      );
    });
  });

  // ---------------------------------------------------------------- test 3
  group('a slice carries exactly four fields', () {
    test('no sub-bucket timestamp, no extra field, anywhere', () async {
      final SavedFixture saved = await realisticSave();

      // The bucket bounds the fixture actually supplied. Anything else under a
      // slice is a timestamp we did not intend to keep.
      final Set<String> supplied = <String>{
        for (int index = 0; index <= 2; index++)
          '${t0 + index * hour}:${t0 + (index + 1) * hour}',
      };

      for (final String path in presentSlots(saved.device)) {
        for (final Map<String, Object?> slice in slicesOf(
          decodeSlotBytes(saved.device, path),
        )) {
          expect(
            slice.keys.toSet(),
            <String>{'o', 's', 'e', 'g'},
            reason:
                '$path: a slice grew a field. The ruling permits origin, '
                'bucket start, bucket end, and granted amount — nothing else.',
          );
          expect(slice['s'], isA<int>());
          expect(slice['e'], isA<int>());
          expect(slice['g'], isA<int>());
          expect(
            supplied,
            contains('${slice['s']}:${slice['e']}'),
            reason:
                '$path: a persisted bucket does not match any bucket the '
                'adapter supplied — a sub-bucket timestamp leaked in',
          );
        }
      }
    });

    test('the ledger object itself carries only the permitted fields', () {
      // The ruling enumerates what may persist. This is that list, in code.
      expect(
        encodeStepLedger(StepLedger.initial()).keys.toSet(),
        <String>{
          'totalObserved',
          'totalGranted',
          'totalSpent',
          'grantedBeforeWatermark',
          'correctionsObserved',
          'unreachableGapEvents',
          'lateDiscardedSlices',
          'sourceState',
          'checkpoint',
          'recovery',
          'grantedSlices',
          // Reviewed for Phase 2 (`DECISIONS/0016`). Two integers: what
          // `totalGranted` and `totalSpent` read at the cutover. Both are
          // aggregates of figures the ledger already persists in the clear, so
          // the epoch discloses nothing `totalGranted` does not — no bucket, no
          // timestamp, no origin, no cursor content, and nothing from which a
          // step history could be reconstructed.
          'epoch',
        },
        reason: 'a new persisted ledger field needs a privacy review',
      );

      // Named separately so that the *shape* of the epoch is also reviewed. A
      // future field added inside it would otherwise pass the check above,
      // because the check above only sees the key it hangs from.
      expect(
        (encodeStepLedger(StepLedger.initial())['epoch']!
                as Map<String, Object?>)
            .keys
            .toSet(),
        <String>{'grantedAtStart', 'spentAtStart'},
        reason: 'a new field inside the epoch needs a privacy review too',
      );
    });
  });

  // ---------------------------------------------------------------- test 4
  group('retention is enforced end to end, in the bytes', () {
    test('fourteen days leave a bounded, in-window slice set', () async {
      final RetentionFixture run = await fourteenDaysCommitted();

      expect(
        run.driver.engine.state.steps.totalGranted,
        14000,
        reason: 'compaction must not lose a granted step',
      );

      for (final String path in presentSlots(run.device)) {
        final Map<String, Object?> envelope = decodeSlotBytes(run.device, path);
        final List<Map<String, Object?>> slices = slicesOf(envelope);

        expect(
          slices.length,
          lessThan(run.days),
          reason:
              '$path retained one slice per day. That is a step history, '
              'which is exactly what the retention window exists to prevent.',
        );

        final int watermark = watermarkOf(envelope);
        for (final Map<String, Object?> slice in slices) {
          expect(
            slice['e']! as int,
            greaterThan(watermark),
            reason: '$path retained a slice at or behind the settled floor',
          );
        }
      }
    });

    test('an out-of-window bucket boundary is absent from the bytes', () async {
      final RetentionFixture run = await fourteenDaysCommitted();
      int suppressed = 0;

      /// Every bucket boundary at or behind [watermark] must be gone from the
      /// artifact's bytes.
      ///
      /// The horizon is itself a bucket boundary, and `watermarkMillis` is an
      /// explicitly permitted persisted field, so that single value is expected
      /// to appear and is not a leak.
      void expectHorizonHolds(String label, String text, int watermark) {
        for (int day = 0; day < run.days; day++) {
          if (dayEnd(day) > watermark) continue;
          expect(
            text.contains('${dayStart(day)}'),
            isFalse,
            reason:
                '$label still contains the start of day $day, which is behind '
                'the retention horizon',
          );
          if (dayEnd(day) != watermark) {
            expect(
              text.contains('${dayEnd(day)}'),
              isFalse,
              reason:
                  '$label still contains the end of day $day, which is behind '
                  'the retention horizon',
            );
          }
          suppressed++;
        }
      }

      // Each snapshot slot is judged against **its own** watermark. The stale
      // slot is one commit behind by design; what matters is that it is bounded
      // by the horizon it was written with, not by a newer one.
      for (final String path in presentSlots(run.device)) {
        expectHorizonHolds(
          path,
          durableText(run.device, path)!,
          watermarkOf(decodeSlotBytes(run.device, path)),
        );
      }

      // The journal is judged against the live horizon: compaction retains only
      // records already absorbed by both snapshots, so nothing older survives.
      expectHorizonHolds(
        'journal',
        durableText(run.device, 'journal')!,
        run.driver.engine.state.steps.checkpoint.watermarkMillis!,
      );

      expect(
        suppressed,
        greaterThan(0),
        reason: 'nothing aged out, so retention was never exercised',
      );
    });

    test('the retention floor cannot be configured away', () {
      // 48 hours is a hard floor. A shorter window is a privacy gain nobody
      // asked for against a correctness loss nobody can see.
      expect(StepReconciler.minimumRetentionMillis, 48 * 60 * 60 * 1000);
      expect(StepReconciler.defaultRetentionMillis, 7 * 24 * 60 * 60 * 1000);
      expect(
        () => StepReconciler(
          retentionWindowMillis: StepReconciler.minimumRetentionMillis - 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        StepReconciler(
          retentionWindowMillis: StepReconciler.minimumRetentionMillis,
        ).retentionWindowMillis,
        StepReconciler.minimumRetentionMillis,
      );
    });
  });

  // ---------------------------------------------------------------- test 5
  group('the journal is a privacy artifact', () {
    test('compaction keeps it inside the live retention window', () async {
      final RetentionFixture run = await fourteenDaysCommitted();

      await run.driver.repo.compact();

      final int watermark =
          run.driver.engine.state.steps.checkpoint.watermarkMillis!;
      final List<ObservationKey> keys = journalObservationKeys(run.device);

      expect(
        keys,
        isNotEmpty,
        reason:
            'the journal carried no reconciliation record, so this test '
            'proved nothing about the journal',
      );
      for (final ObservationKey key in keys) {
        expect(
          key.bucket.endMillis,
          greaterThan(watermark),
          reason:
              'the durable journal still names bucket ${key.bucket} from '
              'behind the retention horizon. Every reconciliation record '
              'carries a full slice map, so an uncompacted journal is a '
              'permanent unbounded step history.',
        );
      }
    });

    test('the journal stays bounded across many commits', () async {
      final RetentionFixture run = await fourteenDaysCommitted();

      final List<Uint8List> lines = await FaultingJournal(
        run.device,
      ).readLines();
      expect(
        lines.length,
        lessThanOrEqualTo(2),
        reason:
            'compaction is floored at the older of two verified snapshots, so '
            'a healthy device should retain one or two records. More means '
            'the journal is accumulating slice maps.',
      );
    });

    test('no compaction sidecar survives a commit', () async {
      final RetentionFixture run = await fourteenDaysCommitted();
      expect(
        run.device.committedBytes('journal.compacting'),
        isNull,
        reason: 'a leftover sidecar is a second, uncompacted step history',
      );
    });
  });

  // ---------------------------------------------------------------- test 6
  group('refusal explanations leak nothing', () {
    test('every reachable refusal path is clean', () async {
      final Map<LoadRefusal, String> surfaces = <LoadRefusal, String>{};

      Future<void> record(
        FaultingDevice device, {
        bool release = false,
        TransactionLock lock = const UncontendedLock(),
      }) async {
        final LoadRefused refused = await refusalFrom(
          device,
          treatAsRelease: release,
          lock: lock,
        );
        // A refusal carries repairs, and those are reachable strings too, so
        // they are audited alongside the explanation.
        surfaces[refused.reason] = <String>[
          refused.explanation,
          ...refused.repairs.map((SaveRepair r) => r.toString()),
        ].join(' | ');
      }

      // allSlotsUnreadable — both slots present and unreadable.
      await record(
        FaultingDevice()
          ..seed('save_slot_a', Uint8List.fromList(utf8.encode('not a save')))
          ..seed('save_slot_b', Uint8List.fromList(utf8.encode('also not'))),
      );

      // futureSaveFormat.
      await record(
        FaultingDevice()..seed(
          'save_slot_a',
          reframedWithFormat(envelopeJsonOf(populatedState()), 99),
        ),
      );

      // unsupportedStateVersion.
      final Map<String, Object?> futureState = envelopeJsonOf(populatedState());
      futureState['gameStateVersion'] = 99;
      (futureState['state']! as Map<String, Object?>)['stateVersion'] = 99;
      await record(
        FaultingDevice()..seed('save_slot_a', framedFrom(futureState)),
      );

      // divergentSlotsAtSameGeneration.
      final GameEngine one = newEngine();
      sync(one, incremental(<StepObservation>[obs(phone, 0, 613)], next: 'c1'));
      final GameEngine two = newEngine();
      sync(two, incremental(<StepObservation>[obs(watch, 3, 877)], next: 'c1'));
      await record(
        FaultingDevice()
          ..seed(
            'save_slot_a',
            framedFrom(
              envelopeJsonOf(one.state, generation: 5, transaction: 3),
            ),
          )
          ..seed(
            'save_slot_b',
            framedFrom(
              envelopeJsonOf(two.state, generation: 5, transaction: 3),
            ),
          ),
      );

      // qaProfileForbiddenInRelease, profileMigrationRequired, unknownProfile.
      Map<String, Object?> withProfile(String id) {
        final Map<String, Object?> json = envelopeJsonOf(populatedState());
        json['balanceProfileId'] = id;
        (json['state']! as Map<String, Object?>)['profileId'] = id;
        return json;
      }

      await record(
        FaultingDevice()..seed(
          'save_slot_a',
          framedFrom(withProfile('profile.accelerated_qa')),
        ),
        release: true,
      );
      await record(
        FaultingDevice()..seed(
          'save_slot_a',
          framedFrom(withProfile('profile.accelerated_qa')),
        ),
      );
      await record(
        FaultingDevice()
          ..seed('save_slot_a', framedFrom(withProfile('profile.bogus'))),
      );

      // unsupportedContentSchema.
      final Map<String, Object?> futureSchema = envelopeJsonOf(
        populatedState(),
      );
      futureSchema['contentSchemaVersion'] = 999;
      (futureSchema['state']! as Map<String, Object?>)['contentPackVersion'] =
          999;
      await record(
        FaultingDevice()..seed('save_slot_a', framedFrom(futureSchema)),
      );

      // unknownContent.
      final Map<String, Object?> ghostItem = envelopeJsonOf(populatedState());
      ((ghostItem['state']! as Map<String, Object?>)['inventory']!
              as List<Object?>)
          .add(<String, Object?>{'id': 'item.no_such_thing', 'n': 1});
      await record(
        FaultingDevice()..seed('save_slot_a', framedFrom(ghostItem)),
      );

      // lineageMismatch.
      await record(
        FaultingDevice()
          ..seed('save_slot_a', framedFrom(envelopeJsonOf(populatedState())))
          ..seed(
            'journal',
            encodeJournalLine(
              const JournalRecord(
                formatVersion: 1,
                saveId: 'a-different-save',
                transactionId: 1,
                eventSequenceBefore: 0,
                eventSequenceAfter: 1,
                events: <GameEvent>[
                  StepsGranted(sequence: 1, steps: 5, grantedTotalAfter: 5),
                ],
              ),
            ),
          ),
      );

      // journalForked — two records claiming one transaction.
      JournalRecord forkAt(int after) => JournalRecord(
        formatVersion: 1,
        saveId: testSaveId,
        transactionId: 1,
        eventSequenceBefore: 0,
        eventSequenceAfter: after,
        events: <GameEvent>[
          StepsGranted(sequence: after, steps: after, grantedTotalAfter: after),
        ],
      );
      await record(
        FaultingDevice()
          ..seed('save_slot_a', framedFrom(envelopeJsonOf(populatedState())))
          ..seed(
            'journal',
            Uint8List.fromList(<int>[
              ...encodeJournalLine(forkAt(1)),
              ...encodeJournalLine(forkAt(2)),
            ]),
          ),
      );

      // storageBusy — the lock is held elsewhere. Nothing on the device is
      // read, so the fixture is a healthy save and the refusal must still say
      // nothing derived from it.
      await record(
        FaultingDevice()
          ..seed('save_slot_a', framedFrom(envelopeJsonOf(populatedState()))),
        lock: const NeverAvailableLock(),
      );

      // resetIncomplete — a reset intent that survived a death mid-erase.
      await record(FaultingDevice()..seed('journal', encodeResetMarkerLine()));

      // --- the actual assertions -----------------------------------------

      expect(
        surfaces.keys.toSet(),
        reachableRefusals,
        reason: 'the fixtures no longer reach the paths they claim to',
      );

      final RegExp originShaped = RegExp('[0-9a-f]{16}');
      final RegExp epochShaped = RegExp(r'\d{10,}');

      for (final MapEntry<LoadRefusal, String> entry in surfaces.entries) {
        final String text = entry.value;
        expect(
          text.contains(phone.value),
          isFalse,
          reason: '${entry.key.name} names an origin key',
        );
        expect(
          text.contains(watch.value),
          isFalse,
          reason: '${entry.key.name} names an origin key',
        );
        expect(
          originShaped.hasMatch(text),
          isFalse,
          reason: '${entry.key.name} contains an origin-key-shaped run: $text',
        );
        expect(
          epochShaped.hasMatch(text),
          isFalse,
          reason: '${entry.key.name} contains a bucket-shaped timestamp: $text',
        );
        for (final String token in forbiddenTokens) {
          expect(
            text.toLowerCase().contains(token.toLowerCase()),
            isFalse,
            reason: '${entry.key.name} contains "$token"',
          );
        }
      }
    });

    test('an unreviewed refusal cannot be added silently', () {
      // The one refusal the fixtures cannot reach, because nothing in
      // stride_core constructs it: there is no origin-key-reset detection.
      // If that changes, or a new refusal appears, this fails and someone has
      // to privacy-review the new explanation string.
      expect(
        LoadRefusal.values.toSet().difference(reachableRefusals),
        <LoadRefusal>{LoadRefusal.originKeyReset},
      );
    });
  });

  // ---------------------------------------------------------------- test 7
  group('a rejected origin key is never retained', () {
    test('the exception carries a length and nothing else', () {
      const String name = "Rob's iPhone";
      try {
        StepOriginKey(name);
        fail('a device name must not be constructible');
      } on InvalidOriginKeyException catch (e) {
        expect(e.length, name.length);
        expect(e.refusal, OriginKeyRefusal.wrongLength);

        final String rendered = e.toString();
        expect(rendered, contains('length ${name.length}'));
        expect(
          rendered.contains(name),
          isFalse,
          reason:
              'the rejected value may be exactly the display name this type '
              'exists to exclude, and an exception message is a diagnostic '
              'surface',
        );
        expect(rendered.toLowerCase().contains('iphone'), isFalse);
        expect(rendered.toLowerCase().contains('rob'), isFalse);
      }
    });

    test('the same holds for a full-length name', () {
      const String name = 'Robs-iPhone-15pr';
      try {
        StepOriginKey(name);
        fail('a device name must not be constructible');
      } on InvalidOriginKeyException catch (e) {
        expect(e.refusal, OriginKeyRefusal.notLowercaseHex);
        expect(e.length, 16);
        expect(e.toString().contains(name), isFalse);
        expect(e.toString().toLowerCase().contains('iphone'), isFalse);
      }
    });

    test('the decoder refuses a named origin without echoing it', () {
      const String name = 'My iPhone 15 Pro';
      final Map<String, Object?> json = envelopeJsonOf(populatedState());
      final List<Object?> slices = rawSlicesIn(json);
      expect(slices, isNotEmpty);
      (slices.first! as Map<String, Object?>)['o'] = name;

      try {
        decodeEnvelope(unframe(framedFrom(json)).payload!);
        fail('a named origin must not decode');
      } on SaveCodecException catch (e) {
        expect(e.message, contains('length ${name.length}'));
        expect(
          e.message.contains(name),
          isFalse,
          reason: 'the codec echoed the rejected value into a diagnostic',
        );
        expect(e.toString().toLowerCase().contains('iphone'), isFalse);
      }
    });

    test('and the load that follows says nothing about it either', () async {
      const String name = 'My iPhone 15 Pro';
      final Map<String, Object?> json = envelopeJsonOf(populatedState());
      (rawSlicesIn(json).first! as Map<String, Object?>)['o'] = name;

      final LoadRefused refused = await refusalFrom(
        FaultingDevice()..seed('save_slot_a', framedFrom(json)),
      );
      expect(refused.reason, LoadRefusal.allSlotsUnreadable);
      final String surface = <String>[
        refused.explanation,
        ...refused.repairs.map((SaveRepair r) => r.toString()),
      ].join(' ');
      expect(surface.toLowerCase().contains('iphone'), isFalse);
      expect(surface.contains(name), isFalse);
    });
  });

  // ---------------------------------------------------------------- test 8
  group('lateDiscardedSlices is a count and only a count', () {
    /// Settles hour 0, then restates it — the one lossy path in the design.
    LateDiscardFixture lateDiscardScenario() {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 800)], next: 'c1'),
      );
      for (int day = 1; day <= 12; day++) {
        sync(
          engine,
          incremental(
            <StepObservation>[obs(phone, day * 24, 100)],
            next: 'd$day',
            completeThroughIndex: day * 24 + 1,
          ),
        );
      }
      final EngineResult rescanResult = sync(
        engine,
        rescan(
          <StepObservation>[obs(phone, 0, 5000)],
          fromIndex: 0,
          toIndex: 1,
          next: 'late',
        ),
      );
      return (engine: engine, rescanResult: rescanResult);
    }

    test('it increments, and grants nothing', () {
      final LateDiscardFixture run = lateDiscardScenario();
      expect(grantedBy(run.rescanResult), 0);
      expect(run.engine.state.steps.lateDiscardedSlices, isA<int>());
      expect(
        run.engine.state.steps.lateDiscardedSlices,
        greaterThan(0),
        reason: 'the scenario must actually exercise the lossy path',
      );
    });

    test('no signature or toString says which slice was discarded', () {
      final LateDiscardFixture run = lateDiscardScenario();
      final StepLedger ledger = run.engine.state.steps;

      // DIAGNOSTIC surfaces only.
      //
      // `canonicalDurableGameState` is deliberately not in this list, and the
      // S-01A migration briefly put it there by substituting it for the removed
      // `GameState.signature`. That was a category error: it is the save
      // format, and the save format MUST carry every granted slice with its
      // origin key, because that is the state the game reloads. A durable
      // record of what was granted is not a diagnostic that leaks it.
      //
      // The rule this test protects is narrower and still holds: a string a
      // human or a log might see must not say WHICH slice was dropped.
      for (final String surface in <String>[
        ledger.signature,
        ledger.toString(),
        run.engine.state.toString(),
      ]) {
        expect(
          surface.contains(phone.value),
          isFalse,
          reason: 'a diagnostic surface names the origin: $surface',
        );
        expect(
          surface.contains('${dayStart(0)}'),
          isFalse,
          reason: 'a diagnostic surface names the discarded bucket: $surface',
        );
      }

      // What it *does* say: counts.
      expect(
        ledger.signature,
        contains('late=${ledger.lateDiscardedSlices}'),
        reason:
            'the count must stay legible, because a loss you cannot count is '
            'a haunting',
      );
      expect(
        ledger.signature,
        contains('slices=${ledger.grantedSlices.length}'),
        reason: 'slice detail is reduced to a cardinality, not enumerated',
      );
    });

    test('no event carries which slice was discarded', () {
      final LateDiscardFixture run = lateDiscardScenario();
      final StepObservationReconciled event = run.rescanResult.events
          .whereType<StepObservationReconciled>()
          .single;

      expect(event.lateDiscarded, isA<int>());
      expect(event.lateDiscarded, greaterThan(0));

      final Map<String, Object?> encoded = encodeEvent(event);
      expect(encoded['lateDiscarded'], isA<int>());
      expect(
        encoded.keys.toSet(),
        <String>{
          't',
          'seq',
          'observedAfter',
          'grantedCompactedAway',
          'lateDiscarded',
          'watermarkMillis',
          'correctionsSeen',
          'truncatedGap',
          'wasRecovery',
          'slices',
          // Added 2026-08-02 with the per-origin watermark fix, and reviewed
          // rather than waved through — which is what this frozen key set is
          // for.
          //
          // Carries a pseudonymous origin key and one UTC millisecond value per
          // origin. Both categories are already permitted by the ruling, and
          // this is strictly *coarser* than the slice map beside it: one
          // instant per source rather than one entry per bucket. It replaces a
          // scalar that could not express "settled for the phone, still open
          // for the watch" — and using a scalar for that silently discarded a
          // returning player's backlog.
          'originWatermarks',
        },
        reason: 'a new reconciliation event field needs a privacy review',
      );

      // The discarded slice is settled and compacted, so it must not reappear
      // in the slice map the event carries.
      expect(
        canonicalJson(encoded).contains('${dayStart(0)}'),
        isFalse,
        reason: 'the event re-materialised the discarded bucket',
      );

      // And no event type anywhere carries a per-slice discard record.
      for (final GameEvent e in run.rescanResult.events) {
        final String json = canonicalJson(encodeEvent(e));
        expect(json.contains('discardedSlices'), isFalse);
        expect(json.contains('lateSlices'), isFalse);
        expect(json.contains('discardedOrigin'), isFalse);
      }
    });

    test('it survives a round trip as a bare integer', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final Driver driver = Driver(repo, newEngine());

      await driver.run(
        ReconcileStepSync(
          response: incremental(<StepObservation>[
            obs(phone, 0, 800),
          ], next: 'c1'),
        ),
      );
      for (int day = 1; day <= 12; day++) {
        await driver.run(
          ReconcileStepSync(
            response: incremental(
              <StepObservation>[obs(phone, day * 24, 100)],
              next: 'd$day',
              completeThroughIndex: day * 24 + 1,
            ),
          ),
        );
      }
      await driver.run(
        ReconcileStepSync(
          response: rescan(
            <StepObservation>[obs(phone, 0, 5000)],
            fromIndex: 0,
            toIndex: 1,
            next: 'late',
          ),
        ),
      );

      expect(driver.engine.state.steps.lateDiscardedSlices, greaterThan(0));
      for (final String path in presentSlots(device)) {
        final Object? value = stepsOf(
          decodeSlotBytes(device, path),
        )['lateDiscardedSlices'];
        expect(value, isA<int>(), reason: '$path: not a bare integer');
      }
      expectNoForbiddenTokens(device);
    });
  });
}
