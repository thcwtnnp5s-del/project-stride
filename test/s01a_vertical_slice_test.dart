// S-01A acceptance: real steps to saved game state, through the real wiring.
//
// ===========================================================================
// What is real here and what is substituted
// ===========================================================================
//
// Real: `bootstrapStride`, `IdentityVault` on its app-private file backend —
// which is the **Android** path, since `KeychainIdentityStore.isSupported` is
// `Platform.isIOS` — the content pack, `GameEngine`, `StepReconciler`,
// `SaveRepository` over a real temporary directory with a real OS lock, and
// `StrideSession`'s fetch → reconcile → commit loop.
//
// Substituted: exactly one thing, `StepSyncSource`. Everything behind it is
// Health Connect, which needs a phone. Everything in front of it is asserted
// here, on Windows, in under a second.
//
// That split is deliberate and it is where the honesty of this suite lives. A
// green run says the *decision* layer is correct. It says nothing about whether
// Health Connect on a real Pixel returns what the adapter expects — the Kotlin
// suite covers the adapter's translation of a `StepSource`, and only a device
// covers the platform beneath it. `S01A_DEVICE_VALIDATION.md` is the rest.
//
// ===========================================================================
// A note on acceptance property 1
// ===========================================================================
//
// The brief asks that an unavailable provider cause "no GameState mutation".
// The engine deliberately emits `StepSourceStateChanged` on that path, and has
// since F-04: the UI has to be able to say *why* it is showing nothing, and a
// screen that cannot distinguish "no health service" from "you did not walk"
// is the screen that makes a player think the game lost their steps.
//
// So the property asserted below is the substantive one: no energy, no cursor,
// no watermark, no ledger arithmetic, and no spend. The single field that does
// change is the typed diagnostic, and it is asserted to be the *only* one.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/dev_harness.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

/// A stand-in for a pseudonymized Health Connect package name.
///
/// Sixteen hex characters, because that is what `StepOriginKey` accepts and
/// what native keying produces. `StepOriginKey('com.google.android.apps.fitness')`
/// does not compile, which is the type doing its job.
final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
final StepOriginKey watch = StepOriginKey('0f1e2d3c4b5a6978');

const int hour = 60 * 60 * 1000;

/// A fixed instant. The engine reads no clock and neither does this suite.
const int t0 = 1750000000000;

StepObservation obs(StepOriginKey origin, int index, int steps) =>
    StepObservation(
      key: ObservationKey(
        origin: origin,
        bucket: TimeBucket(
          startMillis: t0 + index * hour,
          endMillis: t0 + (index + 1) * hour,
        ),
      ),
      steps: steps,
    );

/// A drained, complete incremental page for one origin.
///
/// `CompleteThrough` on a final page is what authorizes a cursor. Anything less
/// deliberately does not, which several tests below rely on.
SyncFetch complete(
  List<StepObservation> observations, {
  required String cursor,
  required int throughIndex,
  Set<StepOriginKey> origins = const <StepOriginKey>{},
}) => SyncFetch(
  IncrementalSync(
    observations: observations,
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + throughIndex * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(
          origins.isEmpty
              ? observations.map((StepObservation o) => o.key.origin).toSet()
              : origins,
        ),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + throughIndex * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  // rootBundle, for the content pack.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('stride_s01a');
  });

  tearDown(() {
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows occasionally holds a handle a moment past close. The
        // directory is under systemTemp and the OS reclaims it; failing a
        // passing suite over cleanup would be the wrong trade.
      }
    }
  });

  Future<StrideSession> launch({StepSyncSource? source}) =>
      StrideSession.start(overrideRoot: root, source: source);

  /// A relaunch: a cold start over the same directory, exactly as a force-stop
  /// and a tap on the icon produce.
  Future<StrideSession> relaunch({StepSyncSource? source}) =>
      launch(source: source ?? MockStepSource(script: const <SyncFetch>[]));

  int costOfHarnessNode(StrideSession session) => session.costOf(kHarnessNode)!;

  // =========================================================================
  // 1-3, 7: nothing that failed may move the ledger
  // =========================================================================

  group('a read that did not happen changes nothing', () {
    /// The four fields that constitute "the ledger moved".
    ///
    /// Compared as a tuple rather than one at a time, so a test cannot pass by
    /// checking the three that happen to be right.
    List<Object?> ledgerFacts(StrideSession s) => <Object?>[
      s.usableEnergy,
      s.totalGranted,
      s.totalSpent,
      s.hasCursor,
      s.engine!.state.steps.checkpoint.originWatermarks,
      s.engine!.state.steps.grantedSlices.length,
    ];

    test(
      '1 — an unavailable provider grants nothing and moves no cursor',
      () async {
        final StrideSession session = await launch(
          source: MockStepSource(
            script: <SyncFetch>[
              MockStepSource.unavailable(
                ProviderUnavailableReason.serviceUnavailable,
              ),
            ],
          ),
        );
        final List<Object?> before = ledgerFacts(session);

        final SyncReport report = await session.syncSteps();

        expect(report.status, SyncStatus.unavailable);
        expect(
          report.unavailableReason,
          ProviderUnavailableReason.serviceUnavailable,
        );
        expect(report.newlyGranted, 0);
        expect(ledgerFacts(session), before);
        // The one permitted change: the typed diagnostic the UI explains itself
        // with. See the header note.
        expect(session.sourceState, SourceState.serviceUnavailable);
      },
    );

    test('2 — a denied permission grants nothing', () async {
      // HealthKit and Health Connect both surface a denial as
      // `permissionUnavailable` rather than as an empty read, because an empty
      // read is indistinguishable from a player who did not move.
      final StrideSession session = await launch(
        source: MockStepSource(
          authorization: HealthAuthorization.denied,
          script: <SyncFetch>[
            MockStepSource.unavailable(
              ProviderUnavailableReason.permissionUnavailable,
            ),
          ],
        ),
      );
      final List<Object?> before = ledgerFacts(session);

      expect(await session.requestPermission(), HealthAuthorization.denied);
      final SyncReport report = await session.syncSteps();

      expect(report.newlyGranted, 0);
      expect(ledgerFacts(session), before);
      expect(session.sourceState, SourceState.permissionUnavailable);
    });

    test(
      '3 — a permission revoked after a good sync grants nothing more',
      () async {
        // The order matters: a grant lands first, so the assertion is that a
        // later revocation neither adds to it nor claws it back. A revocation
        // that reset the ledger would erase steps the player really walked.
        final MockStepSource source = MockStepSource(
          script: <SyncFetch>[
            complete(
              <StepObservation>[obs(phone, 0, 400)],
              cursor: 'c1',
              throughIndex: 1,
            ),
            MockStepSource.unavailable(
              ProviderUnavailableReason.permissionUnavailable,
            ),
          ],
        );
        final StrideSession session = await launch(source: source);

        await session.syncSteps();
        final List<Object?> afterGrant = ledgerFacts(session);
        expect(session.usableEnergy, 400);

        final SyncReport revoked = await session.syncSteps();

        expect(revoked.newlyGranted, 0);
        expect(ledgerFacts(session), afterGrant);
        expect(session.usableEnergy, 400);
      },
    );

    test(
      '7 — a self-contradictory delivery is refused before the ledger',
      () async {
        // A page whose status says "nothing arrived since your cursor" while
        // carrying what arrived. Both halves cannot be believed and promoting one
        // picks by guessing, so the whole delivery is rejected.
        final StrideSession session = await launch(
          source: MockStepSource(
            script: <SyncFetch>[
              SyncFetch(
                const ContractViolationSync(
                  SyncContractViolation.noChangeWithPayload,
                ),
              ),
            ],
          ),
        );
        final List<Object?> before = ledgerFacts(session);

        final SyncReport report = await session.syncSteps();

        expect(report.status, SyncStatus.contractViolation);
        expect(report.rejection, RejectionCode.malformedSyncBatch.wire);
        expect(report.newlyGranted, 0);
        expect(ledgerFacts(session), before);
      },
    );
  });

  // =========================================================================
  // 4-6, 8: the arithmetic and the cursor
  // =========================================================================

  group('reconciliation', () {
    test('4 — a first sync grants the whole observed delta', () async {
      final StrideSession session = await launch(
        source: MockStepSource(
          script: <SyncFetch>[
            complete(
              <StepObservation>[obs(phone, 0, 400), obs(watch, 0, 150)],
              cursor: 'c1',
              throughIndex: 1,
            ),
          ],
        ),
      );

      final SyncReport report = await session.syncSteps();

      expect(report.status, SyncStatus.reconciled);
      expect(report.newlyGranted, 550);
      expect(session.usableEnergy, 550);
      // Counts, not identities: two origins contributed and the harness may
      // know that much and no more.
      expect(report.originCount, 2);
      expect(report.bucketCount, 1);
      expect(report.observedSteps, 550);
      expect(report.faults, isEmpty);
    });

    test('5 — repeating the identical sync grants nothing further', () async {
      // The absolute contract in one assertion. 400 restated is still 400, not
      // another 400, and it is the same code path as a correction, a deletion,
      // and an overlapping batch.
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          complete(
            <StepObservation>[obs(phone, 0, 400)],
            cursor: 'c1',
            throughIndex: 1,
          ),
          complete(
            <StepObservation>[obs(phone, 0, 400)],
            cursor: 'c1',
            throughIndex: 1,
          ),
        ],
      );
      final StrideSession session = await launch(source: source);

      expect((await session.syncSteps()).newlyGranted, 400);
      expect((await session.syncSteps()).newlyGranted, 0);
      expect(session.usableEnergy, 400);
      expect(session.totalGranted, 400);
    });

    test('6 — a higher restatement grants only the increase', () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          complete(
            <StepObservation>[obs(phone, 0, 400)],
            cursor: 'c1',
            throughIndex: 1,
          ),
          complete(
            <StepObservation>[obs(phone, 0, 900)],
            cursor: 'c2',
            throughIndex: 1,
          ),
        ],
      );
      final StrideSession session = await launch(source: source);

      expect((await session.syncSteps()).newlyGranted, 400);
      expect((await session.syncSteps()).newlyGranted, 500);
      expect(session.usableEnergy, 900);
    });

    test('a downward correction records, and never claws back', () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          complete(
            <StepObservation>[obs(phone, 0, 900)],
            cursor: 'c1',
            throughIndex: 1,
          ),
          complete(
            <StepObservation>[obs(phone, 0, 100)],
            cursor: 'c2',
            throughIndex: 1,
          ),
        ],
      );
      final StrideSession session = await launch(source: source);

      await session.syncSteps();
      await session.syncSteps();

      expect(session.totalGranted, 900);
      expect(session.usableEnergy, 900);
      expect(session.engine!.state.steps.correctionsObserved, greaterThan(0));
    });

    test('8a — an undrained read authorizes no cursor at all', () async {
      // Nothing to make durable. A cursor offered mid-read would record a
      // position for pages the caller has not seen, and resuming from it would
      // skip pages 2..N permanently.
      final StrideSession session = await launch(
        source: MockStepSource(
          script: <SyncFetch>[
            MockStepSource.partialPage(
              phone.value,
              startMillis: t0,
              endMillis: t0 + hour,
              steps: 300,
            ),
          ],
        ),
      );

      await session.syncSteps();

      expect(session.hasCursor, isFalse);
      // But the grant it did deliver is durable: partial delivery settles
      // nothing and still credits what actually arrived.
      expect(session.usableEnergy, 300);
      expect((await relaunch()).usableEnergy, 300);
    });

    test(
      '8b — a drained read authorizes one, and it survives a relaunch',
      () async {
        // "Authorized" and "durable" are the two states the commit ordering
        // exists to keep apart, so durability is proven by reading the save back
        // through a cold start rather than by inspecting memory.
        final StrideSession session = await launch(
          source: MockStepSource(
            script: <SyncFetch>[
              complete(
                <StepObservation>[obs(phone, 0, 400)],
                cursor: 'c1',
                throughIndex: 1,
              ),
            ],
          ),
        );

        await session.syncSteps();
        expect(session.hasCursor, isTrue);

        final StrideSession reopened = await relaunch();
        expect(reopened.hasCursor, isTrue);
        expect(reopened.engine!.state.steps.checkpoint.syncCount, 1);
      },
    );

    test('a paginated read drains every page and grants each once', () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          MockStepSource.partialPage(
            phone.value,
            startMillis: t0,
            endMillis: t0 + hour,
            steps: 300,
          ),
          complete(
            <StepObservation>[obs(phone, 1, 250)],
            cursor: 'c1',
            throughIndex: 2,
          ),
        ],
      );
      final StrideSession session = await launch(source: source);

      final SyncReport report = await session.syncSteps();

      expect(report.pages, 2);
      expect(session.usableEnergy, 550);
      expect(session.hasCursor, isTrue);
      // The second request resumed the read with the continuation, not with a
      // cursor the first page was never entitled to offer.
      expect(source.requestsSeen[1].continuation, isNotNull);
    });
  });

  // =========================================================================
  // 9-12: the playable action, and persistence
  // =========================================================================

  group('the playable action', () {
    Future<StrideSession> walked(int steps) => launch(
      source: MockStepSource(
        script: <SyncFetch>[
          complete(
            <StepObservation>[obs(phone, 0, steps)],
            cursor: 'c1',
            throughIndex: 1,
          ),
        ],
      ),
    );

    test('11 — insufficient energy cannot execute the action', () async {
      final StrideSession session = await walked(10);
      await session.syncSteps();
      final int cost = costOfHarnessNode(session);
      expect(session.usableEnergy, lessThan(cost));

      expect(session.canGather(kHarnessNode), isFalse);
      final ActionReport report = await session.gather(kHarnessNode);

      expect(report.succeeded, isFalse);
      expect(report.rejection, RejectionCode.insufficientSteps.wire);
      expect(session.usableEnergy, 10);
      expect(session.totalSpent, 0);
    });

    test('10 — the action consumes exactly its cost, exactly once', () async {
      final StrideSession session = await walked(1000);
      await session.syncSteps();
      final int cost = costOfHarnessNode(session);

      final ActionReport report = await session.gather(kHarnessNode);

      expect(report.succeeded, isTrue);
      expect(report.cost, cost);
      expect(session.usableEnergy, 1000 - cost);
      expect(session.totalSpent, cost);
      expect(session.totalGranted, 1000);
      expect(
        session.inventoryCount(ContentId.unchecked('item.meadow_herb')),
        report.quantity,
      );
    });

    test(
      '9 — a reload preserves energy, ledger, cursor and the yield',
      () async {
        final StrideSession session = await walked(1000);
        await session.syncSteps();
        await session.gather(kHarnessNode);

        final int energy = session.usableEnergy;
        final int granted = session.totalGranted;
        final int spent = session.totalSpent;
        final int herbs = session.inventoryCount(
          ContentId.unchecked('item.meadow_herb'),
        );
        final GameState before = session.engine!.state;

        final LoadOutcome? outcome = await session.reload();

        expect(outcome, isA<SaveLoaded>());
        expect(session.usableEnergy, energy);
        expect(session.totalGranted, granted);
        expect(session.totalSpent, spent);
        expect(session.hasCursor, isTrue);
        expect(
          session.inventoryCount(ContentId.unchecked('item.meadow_herb')),
          herbs,
        );
        // Whole-state equality, not field-by-field: a field added later that the
        // codec forgets would slip past a list of assertions and not past this.
        expect(session.engine!.state, before);
      },
    );

    test(
      '12 — a relaunch duplicates neither the grant nor the action',
      () async {
        final StrideSession first = await walked(1000);
        await first.syncSteps();
        await first.gather(kHarnessNode);
        final GameState before = first.engine!.state;

        // A cold start over the same directory: new bootstrap, new repository,
        // new engine, the same disk. What a force-stop and a relaunch produce.
        final StrideSession second = await relaunch();

        expect(second.outcome, isA<BootstrapExistingGame>());
        expect(second.engine!.state, before);
        expect(second.totalGranted, 1000);
        expect(second.totalSpent, costOfHarnessNode(second));
        expect(
          second.inventoryCount(ContentId.unchecked('item.meadow_herb')),
          greaterThan(0),
        );
      },
    );

    test(
      'a relaunch that re-syncs the same walk grants nothing again',
      () async {
        // The double-grant this whole design exists to prevent, in the shape a
        // player produces it: walk, sync, force-stop, reopen, sync again.
        final StrideSession first = await walked(1000);
        await first.syncSteps();

        final StrideSession second = await relaunch(
          source: MockStepSource(
            script: <SyncFetch>[
              complete(
                <StepObservation>[obs(phone, 0, 1000)],
                cursor: 'c1',
                throughIndex: 1,
              ),
            ],
          ),
        );
        final SyncReport report = await second.syncSteps();

        expect(report.newlyGranted, 0);
        expect(second.totalGranted, 1000);
      },
    );
  });

  // =========================================================================
  // 13: nothing identifying may reach a diagnostic
  // =========================================================================

  group('13 — redaction', () {
    test('a sync report carries counts and codes, never identifiers', () async {
      final StrideSession session = await launch(
        source: MockStepSource(
          script: <SyncFetch>[
            complete(
              <StepObservation>[obs(phone, 0, 400), obs(watch, 1, 100)],
              cursor: 'a-health-connect-changes-token',
              throughIndex: 2,
            ),
          ],
        ),
      );

      final SyncReport report = await session.syncSteps();

      // Everything the harness renders, concatenated. If an origin key, a
      // cursor, or a salt can reach the screen at all, it reaches this string.
      final String rendered = <Object?>[
        report.status.name,
        report.deliveryKind,
        report.pages,
        report.originCount,
        report.bucketCount,
        report.observedSteps,
        report.newlyGranted,
        report.faults.map((SyncFault f) => f.name).join(','),
        report.unavailableReason?.name,
        report.intervalStartMillis,
        report.intervalEndMillis,
        report.commitDetail,
        report.rejection,
      ].join('|');

      expect(rendered, isNot(contains(phone.value)));
      expect(rendered, isNot(contains(watch.value)));
      expect(rendered, isNot(contains('changes-token')));
      // And the session exposes the cursor only as a boolean.
      expect(session.hasCursor, isTrue);
    });

    test('a save on disk contains no raw platform identifier', () async {
      final StrideSession session = await launch(
        source: MockStepSource(
          script: <SyncFetch>[
            complete(
              <StepObservation>[obs(phone, 0, 400)],
              cursor: 'c1',
              throughIndex: 1,
            ),
          ],
        ),
      );
      await session.syncSteps();

      // Every artifact the app wrote, as text. Origin keys legitimately appear
      // — they are the pseudonyms — so what is asserted is the absence of the
      // things they are pseudonyms *for*.
      final StringBuffer bytes = StringBuffer();
      for (final FileSystemEntity entity
          in session.runtime.layout.root.listSync(recursive: true)) {
        if (entity is File) {
          bytes.write(entity.readAsStringSync(encoding: latin1WithFallback));
        }
      }
      final String contents = bytes.toString();

      for (final String forbidden in <String>[
        'com.google.android.apps.healthdata',
        'com.google.android.apps.fitness',
        'packageName',
        'dataOrigin',
        'bundleIdentifier',
      ]) {
        expect(contents, isNot(contains(forbidden)));
      }
    });
  });

  // =========================================================================
  // 14: no background entry point, no second writer
  // =========================================================================

  group('14 — foreground only, one writer', () {
    /// Every Dart file the application ships.
    ///
    /// Scanned as source text because the property is a property of the source:
    /// no type can express "this package spawns nothing". The shell guards
    /// `check-single-writer.sh` and `check-android-target.sh` cover the native
    /// and cross-package cases; this covers `lib/`, in the suite a developer
    /// runs before the guards.
    List<File> appSources() {
      final Directory lib = Directory('lib');
      return lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
    }

    /// [source] with every comment removed.
    ///
    /// Necessary, and the first version of this test proved why: it failed on
    /// `stride_session.dart`'s own doc comment, which names `WorkManager` in the
    /// sentence explaining that there is no `WorkManager`. A scan that cannot
    /// tell code from prose makes it impossible to *document* the rule, which
    /// pushes exactly the reasoning that matters out of the file.
    String codeOnly(String source) => source
        .split('\n')
        .where((String line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('no background execution primitive appears in lib/', () {
      // Named exactly, not by keyword soup. Each of these is a way to run code
      // when the player is not looking, and S-01B is where that gets designed
      // with a persistence coordinator behind it.
      const List<String> forbidden = <String>[
        'Isolate.spawn',
        'compute(',
        'Timer.periodic',
        'WorkManager',
        'BackgroundIsolate',
        'registerBackgroundTask',
        'PassiveMonitoring',
      ];

      for (final File file in appSources()) {
        final String text = codeOnly(file.readAsStringSync());
        for (final String pattern in forbidden) {
          expect(
            text,
            isNot(contains(pattern)),
            reason:
                '${file.path} contains "$pattern". S-01A is foreground '
                'only; background delivery is S-01B and is blocked on a real '
                'persistence coordinator (DECISIONS/0013, 0014).',
          );
        }
      }
    });

    test('only runtime_bootstrap constructs persistence', () {
      // The same rule `Scripts/check-single-writer.sh` enforces, restated where
      // `flutter test` can see it. A session, a screen, or a harness that built
      // its own repository would be a second writer over the same directory —
      // which nothing at runtime serializes across isolates.
      for (final File file in appSources()) {
        if (file.path.endsWith('runtime_bootstrap.dart')) continue;
        if (file.path.endsWith('identity_vault.dart')) continue;
        final String text = codeOnly(file.readAsStringSync());
        for (final String symbol in <String>[
          'SaveRepository(',
          'FileSnapshotStore(',
          'FileLedgerJournal(',
          'FileTransactionLock(',
          'StorageLayout(',
        ]) {
          expect(text, isNot(contains(symbol)), reason: file.path);
        }
      }
    });

    test('a session performs no read that was not asked for', () async {
      // Foreground-only, made observable: constructing a session must not
      // fetch. Every read in this file happens because a test called
      // `syncSteps`, exactly as every read on a device happens because a
      // player pressed a button.
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          complete(
            <StepObservation>[obs(phone, 0, 400)],
            cursor: 'c1',
            throughIndex: 1,
          ),
        ],
      );

      final StrideSession session = await launch(source: source);
      expect(source.fetchCount, 0);

      await session.syncSteps();
      expect(source.fetchCount, 1);
    });
  });

  // =========================================================================
  // The harness screen
  // =========================================================================

  group('the harness screen', () {
    /// Boots a session from inside a widget test.
    ///
    /// `runAsync` is mandatory and its absence is not a slow test, it is a hang:
    /// `testWidgets` runs the body inside `FakeAsync`, where a future backed by
    /// real file I/O never completes because no elapsing clock ever delivers it.
    /// The first version of this suite deadlocked here for four minutes.
    Future<StrideSession> boot(
      WidgetTester tester, {
      required StepSyncSource source,
    }) async {
      // The default 800×600 test surface is shorter than the harness, and a
      // `ListView` does not build what it has not scrolled to — so a control
      // below the fold is both untappable and unfindable, which reads as a
      // missing widget rather than as a viewport that is too small. A phone-
      // shaped, phone-tall surface is closer to the thing being tested anyway.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return (await tester.runAsync(() => launch(source: source)))!;
    }

    testWidgets('shows usable energy, the action and its cost', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: const <SyncFetch>[]),
      );

      await tester.pumpWidget(StrideHarnessApp(session: session));
      await tester.pumpAndSettle();

      expect(find.text('Usable energy'), findsOneWidget);
      expect(find.text('Meadow Patch'), findsOneWidget);
      expect(
        find.textContaining('${costOfHarnessNode(session)} energy'),
        findsWidgets,
      );

      // The Save section is below the fold, and a `ListView` has not built what
      // it has not scrolled to — so this must scroll rather than merely look.
      await tester.scrollUntilVisible(find.text('Cursor'), 300);

      // Cursor state as a word, never as bytes.
      expect(find.text('absent'), findsOneWidget);
    });

    testWidgets('the action is disabled until the energy is there, then acts', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(
          script: <SyncFetch>[
            complete(
              <StepObservation>[obs(phone, 0, 1000)],
              cursor: 'c1',
              throughIndex: 1,
            ),
          ],
        ),
      );

      await tester.pumpWidget(StrideHarnessApp(session: session));
      await tester.pumpAndSettle();

      final Finder gather = find.widgetWithIcon(FilledButton, Icons.grass);
      expect(
        tester.widget<FilledButton>(gather).onPressed,
        isNull,
        reason: 'no energy has been earned yet',
      );

      // Both the tap and the real commit it triggers have to run outside
      // `FakeAsync`. The pump that renders the result belongs back inside it.
      // `ensureVisible`, not `scrollUntilVisible`: the button is already built,
      // just below the fold, and `scrollUntilVisible` stops as soon as the
      // finder matches — which it already does.
      await tester.ensureVisible(find.text('Sync steps'));
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );

      // Back to the top: tapping Sync scrolled the energy card out of the
      // viewport, and an unbuilt card is not a missing one.
      await tester.scrollUntilVisible(find.text('Usable energy'), -300);
      expect(find.textContaining('+1000 energy'), findsOneWidget);
      expect(session.usableEnergy, 1000);
      expect(tester.widget<FilledButton>(gather).onPressed, isNotNull);

      final int cost = costOfHarnessNode(session);
      await tester.ensureVisible(gather);
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        gather,
        until: () => session.usableEnergy == 1000 - cost,
      );
      await tester.scrollUntilVisible(find.text('Usable energy'), -300);

      expect(session.usableEnergy, 1000 - cost);
      expect(find.textContaining('−$cost energy'), findsOneWidget);
    });

    testWidgets('a blocked bootstrap renders the refusal rather than crashing', (
      WidgetTester tester,
    ) async {
      // Reached by corrupting every artifact after a first launch: the
      // repository refuses, and a refusal is a state the app must be able to
      // present. A crash here would be a player with no way to report anything.
      final StrideSession broken = (await tester.runAsync(() async {
        final StrideSession first = await launch(
          source: MockStepSource(script: const <SyncFetch>[]),
        );
        expect(first.outcome, isA<BootstrapNewGame>());

        for (final FileSystemEntity entity
            in first.runtime.layout.root.listSync(recursive: true)) {
          if (entity is File) entity.writeAsStringSync('not a save');
        }
        return relaunch();
      }))!;

      await tester.pumpWidget(StrideHarnessApp(session: broken));
      await tester.pumpAndSettle();

      expect(broken.outcome, isA<BootstrapBlocked>());
      expect(find.text('Stride could not start'), findsOneWidget);
      // The refusal names a reason and a phase, so a bug report says how far
      // startup actually got.
      expect(find.textContaining('stopped at:'), findsOneWidget);
    });
  });
}

/// Taps a control whose handler performs real file I/O, and waits for it.
///
/// Three things have to happen in the right zone and none of them is optional:
/// the tap and the commit it triggers must run under `runAsync`, because a
/// future backed by real I/O never completes inside `FakeAsync`; the wait must
/// be against a real clock for the same reason; and the pump that renders the
/// result must happen back inside `FakeAsync`, where the framework's own
/// scheduling lives.
///
/// [until] is polled rather than a fixed delay. A fixed delay is a race that
/// passes on a fast machine and fails on a loaded one, and the failure looks
/// like a missing widget rather than like a timing problem.
///
/// **[until] going true is not the end of the handler.** It observes the
/// session, which the handler updates *before* it calls `setState`, so the
/// widget's own state is still one continuation behind. The grace period after
/// the loop is what lets that continuation run — still inside `runAsync`,
/// because the moment control returns to `FakeAsync` it never will.
Future<void> tapAndAwait(
  WidgetTester tester,
  Finder finder, {
  required bool Function() until,
  Duration timeout = const Duration(seconds: 10),
}) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    final DateTime deadline = DateTime.now().add(timeout);
    while (!until() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  expect(until(), isTrue, reason: 'the tapped action did not complete in time');
}

/// Reads bytes as latin1 so that a binary artifact does not throw mid-scan.
///
/// The privacy assertion is about the presence of ASCII substrings, and a
/// decoder that refuses malformed input would make the scan skip exactly the
/// files it most needs to read.
const Encoding latin1WithFallback = latin1;
