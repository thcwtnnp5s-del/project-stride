// Startup on a real device, over a real application-support directory.
//
// ## What this adds over the pure suites
//
// `packages/stride_core/test/bootstrap_test.dart` proves the state machine and
// `packages/stride_storage/test/restart_integration_test.dart` proves the file
// adapters. Neither touches an asset bundle, `path_provider`, or Android's
// scoped storage. This does, and that is all it adds:
//
//   * the content pack is actually in the APK and actually parses
//   * `getApplicationSupportDirectory()` is writable and survives
//   * the whole wiring in `bootstrapStride` composes on device
//
// ## What this does NOT prove
//
// **Not process death.** These assertions run inside the app process. A restart
// here means every object is discarded and rebuilt over the same directory —
// the same technique the storage suite uses, on a phone. The process is never
// killed, because the driver would die with it.
//
// Real process-death evidence comes from `Scripts/android-process-death.sh`
// driving `integration_test/process_death_app.dart`, where the assertions live
// in the app and the verdict is read off the disk afterwards.

import 'dart:io';
import 'dart:math';

import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stride/runtime/runtime_bootstrap.dart';
import 'package:stride_core/stride_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    // Under application support, not a system temp directory: the point is to
    // exercise the path the app actually uses on this platform.
    final Directory support = await getApplicationSupportDirectory();
    root = Directory(
      '${support.path}/restart_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    await root.create(recursive: true);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// One launch. Nothing is shared between calls except the directory.
  Future<StrideRuntime> launch() =>
      bootstrapStride(overrideRoot: root, random: Random(1750000000));

  testWidgets('the content pack ships and validates on device', (_) async {
    final StrideRuntime runtime = await launch();

    expect(runtime.outcome, isA<BootstrapNewGame>());
    final BootstrapNewGame game = runtime.outcome as BootstrapNewGame;
    expect(game.registry.skills.length, greaterThanOrEqualTo(5));
    expect(game.registry.locations.length, greaterThanOrEqualTo(4));
    expect(game.registry.profile.id, BalanceProfile.productionId);
  });

  testWidgets('a new game is durable before startup reports success', (
    _,
  ) async {
    final StrideRuntime runtime = await launch();
    expect(runtime.outcome, isA<BootstrapNewGame>());

    // On disk, in the app's own storage, before anything else happened.
    expect(runtime.layout.slotA.existsSync(), isTrue);
    expect(runtime.layout.identity.existsSync(), isTrue);
    expect(runtime.layout.journal.existsSync(), isTrue);
  });

  testWidgets('a restart resumes with the exact same state', (_) async {
    final StrideRuntime first = await launch();
    final BootstrapNewGame started = first.outcome as BootstrapNewGame;
    final String signature = canonicalDurableGameState(started.engine.state);

    // Everything from the first launch is discarded here.
    final StrideRuntime second = await launch();

    expect(second.outcome, isA<BootstrapExistingGame>());
    final BootstrapExistingGame resumed =
        second.outcome as BootstrapExistingGame;
    expect(canonicalDurableGameState(resumed.engine.state), signature);
    expect(resumed.identity, started.identity);
    expect(resumed.load.repairs, isEmpty);
  });

  testWidgets('committed grants are exact across restarts', (_) async {
    final StrideRuntime first = await launch();
    final BootstrapNewGame started = first.outcome as BootstrapNewGame;
    final GameEngine engine = started.engine;

    SaveLoaded head =
        await first.repository.load(registry: started.registry) as SaveLoaded;

    // Distinct and non-summing, so a drop, a duplicate, and an off-by-one each
    // land on a different total.
    for (final int steps in <int>[613, 291, 137]) {
      final EngineResult result = engine.execute(
        GrantSyntheticSteps(steps: steps, reason: 'device restart test'),
      );
      final CommitOutcome outcome = await first.repository.commit(
        after: engine.state,
        events: result.events,
        saveId: started.identity.saveId,
        expectation: CommitExpectation(
          expectedSnapshotGeneration: head.generation,
          expectedLastAppliedTransaction: head.lastAppliedTransaction,
        ),
        originSaltFingerprint: started.identity.saltFingerprint,
      );
      expect(outcome, isA<CommitDurable>());
      head =
          await first.repository.load(registry: started.registry) as SaveLoaded;
    }

    final StrideRuntime second = await launch();
    final BootstrapExistingGame resumed =
        second.outcome as BootstrapExistingGame;

    expect(resumed.engine.state.steps.totalGranted, 1041);
    expect(
      canonicalDurableGameState(resumed.engine.state),
      canonicalDurableGameState(engine.state),
    );
  });

  testWidgets('an unreadable save is refused, never restarted', (_) async {
    final StrideRuntime first = await launch();
    expect(first.outcome, isA<BootstrapNewGame>());

    // Both slots damaged, everything else intact — a save that exists and
    // cannot be read.
    first.layout.slotA.writeAsBytesSync(<int>[0x6E, 0x6F, 0x70, 0x65]);
    first.layout.slotB.writeAsBytesSync(<int>[0, 1, 2, 3]);

    final int slotABefore = first.layout.slotA.lengthSync();
    final int journalBefore = first.layout.journal.lengthSync();

    final StrideRuntime second = await launch();

    expect(
      second.outcome,
      isA<BootstrapBlocked>(),
      reason:
          'a successful launch onto a wiped character is the worst failure '
          'available here',
    );
    expect(
      (second.outcome as BootstrapBlocked).reason,
      BootstrapBlockReason.bothSlotsInvalid,
    );
    expect(second.pseudonymizer, isNull);

    // Nothing repaired, nothing deleted. Refusing is recoverable; deleting is
    // not.
    expect(first.layout.slotA.lengthSync(), slotABefore);
    expect(first.layout.journal.lengthSync(), journalBefore);
    expect(first.layout.identity.existsSync(), isTrue);
  });

  testWidgets('the origin salt survives, so origins do not re-key', (_) async {
    final StrideRuntime first = await launch();
    final String fingerprint =
        (first.outcome as BootstrapNewGame).identity.saltFingerprint;

    final StrideRuntime second = await launch();

    expect(
      (second.outcome as BootstrapExistingGame).identity.saltFingerprint,
      fingerprint,
      reason:
          'a regenerated salt re-keys every origin and grants the whole live '
          'retention window a second time',
    );
  });
}
