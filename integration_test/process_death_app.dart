// The Android process-death harness: an app, not a test.
//
// ## Why this is not an integration test
//
// `flutter test integration_test/...` runs the assertions **inside the app
// process**. `adb shell am force-stop` kills that process, which kills the test
// driver with it, and the run reports a lost connection rather than a result.
// A test framework cannot witness its own death.
//
// So the harness is an ordinary app that decides what to do from what it finds
// on disk, and writes its verdict back to disk. `Scripts/android-process-death.sh`
// launches it, kills it, launches it again, and reads the verdict. The evidence
// is the verdict file — written by a process that started after the previous
// one was killed by the operating system.
//
// ## The two phases
//
// | Launch | Marker found | What it does |
// |---|---|---|
// | 1 | none | bootstrap a new game, commit three grants, record what the next launch must see |
// | 2 | `seeded` | bootstrap again, compare against the recording, write PASS or FAIL |
//
// Nothing is passed between the phases in memory, by intent extra, or by
// argument. The only channel is the filesystem, which is the only channel a
// killed process leaves behind.
//
// Quantities are distinct and non-summing — 613, 291, 137 — so a lost batch, a
// duplicated one, and an off-by-one each produce a different total.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stride/runtime/runtime_bootstrap.dart';
import 'package:stride_core/stride_core.dart';

/// The grants phase 1 commits. Their sum is the number phase 2 must find.
const List<int> harnessGrants = <int>[613, 291, 137];
const int harnessExpectedTotal = 1041;

/// Prefixed so `adb logcat` can be filtered without a custom tag, and so a
/// build where the verdict file cannot be read still reports something.
const String logPrefix = 'STRIDE_HARNESS';

/// A fixed seed. The identity must be reproducible across launches only in the
/// sense that it is *persisted*; seeding here removes `Random.secure` from a
/// harness that should fail for one reason only.
final Random harnessRandom = Random(20260802);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String verdict;
  try {
    verdict = await _runPhase();
  } on Object catch (e, st) {
    verdict = jsonEncode(<String, Object?>{
      'phase': 'error',
      'result': 'FAIL',
      'detail': '$e',
      'stack': '$st',
    });
  }

  // Both channels, because each fails in a different situation: the file is
  // unreadable on a non-debuggable build, and logcat is lossy under pressure.
  debugPrint('$logPrefix $verdict');
  runApp(_HarnessApp(verdict: verdict));
}

Future<File> _markerFile() async {
  final Directory support = await getApplicationSupportDirectory();
  return File('${support.path}/harness_marker.json');
}

Future<String> _runPhase() async {
  final File marker = await _markerFile();
  final Map<String, Object?> found = marker.existsSync()
      ? jsonDecode(marker.readAsStringSync()) as Map<String, Object?>
      : <String, Object?>{};

  if (found['phase'] != 'seeded') return _seed(marker);

  final String verdict = await _verify(found);
  // The verdict has to reach the disk, not just logcat. logcat is lossy and
  // is cleared by anything; the file is what the driving script reads, and it
  // is written by the process that started after the kill.
  marker.writeAsStringSync(verdict, flush: true);
  return verdict;
}

/// Launch 1: create a save, commit three transactions, record the expectation.
Future<String> _seed(File marker) async {
  final StrideRuntime runtime = await bootstrapStride(random: harnessRandom);
  final BootstrapOutcome outcome = runtime.outcome;

  if (outcome is! BootstrapNewGame) {
    return jsonEncode(<String, Object?>{
      'phase': 'seed',
      'result': 'FAIL',
      'detail':
          'expected a new game on a cleared installation, got '
          '${outcome.runtimeType} (${outcome.phase.name})',
    });
  }

  final GameEngine engine = outcome.engine;
  SaveLoaded head =
      await runtime.repository.load(registry: outcome.registry) as SaveLoaded;

  for (final int steps in harnessGrants) {
    final EngineResult result = engine.execute(
      GrantSyntheticSteps(steps: steps, reason: 'harness'),
    );
    final CommitOutcome committed = await runtime.repository.commit(
      after: engine.state,
      events: result.events,
      saveId: outcome.identity.saveId,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: head.generation,
        expectedLastAppliedTransaction: head.lastAppliedTransaction,
      ),
      // Recorded in the snapshot, so the next launch can refuse a re-keyed
      // origin instead of granting the retention window a second time.
      originSaltFingerprint: outcome.identity.saltFingerprint,
    );
    if (committed is! CommitDurable) {
      return jsonEncode(<String, Object?>{
        'phase': 'seed',
        'result': 'FAIL',
        'detail': 'commit refused: $committed',
      });
    }
    head =
        await runtime.repository.load(registry: outcome.registry) as SaveLoaded;
  }

  // Written last. If the process dies before this line the script times out
  // waiting for it, which is a failure that names itself — far better than a
  // marker that claims a seed which did not finish.
  marker.writeAsStringSync(
    jsonEncode(<String, Object?>{
      'phase': 'seeded',
      'expectedTotal': engine.state.steps.totalGranted,
      'expectedSignature': canonicalDurableGameState(engine.state),
      'saveId': outcome.identity.saveId,
      'saltFingerprint': outcome.identity.saltFingerprint,
      'storageRoot': runtime.layout.root.path,
    }),
    flush: true,
  );

  return jsonEncode(<String, Object?>{
    'phase': 'seeded',
    'result': 'READY',
    'total': engine.state.steps.totalGranted,
  });
}

/// Launch 2, after the operating system killed launch 1.
Future<String> _verify(Map<String, Object?> expected) async {
  final StrideRuntime runtime = await bootstrapStride(random: harnessRandom);
  final BootstrapOutcome outcome = runtime.outcome;

  final List<String> failures = <String>[];

  if (outcome is! BootstrapExistingGame) {
    // The failure the whole design exists to prevent, caught on real hardware.
    return jsonEncode(<String, Object?>{
      'phase': 'verified',
      'result': 'FAIL',
      'detail':
          'a save existed and startup returned ${outcome.runtimeType} '
          '(${outcome.phase.name}) instead of resuming it',
    });
  }

  final int total = outcome.engine.state.steps.totalGranted;
  if (total != expected['expectedTotal']) {
    failures.add(
      'total granted is $total, expected ${expected['expectedTotal']}',
    );
  }
  if (total != harnessExpectedTotal) {
    failures.add('total granted is $total, expected $harnessExpectedTotal');
  }
  if (canonicalDurableGameState(outcome.engine.state) !=
      expected['expectedSignature']) {
    failures.add('state signature changed across the kill');
  }
  if (outcome.identity.saveId != expected['saveId']) {
    failures.add('the save lineage id was re-minted');
  }
  if (outcome.identity.saltFingerprint != expected['saltFingerprint']) {
    failures.add('the origin salt changed, which would re-key every origin');
  }
  if (runtime.pseudonymizer == null) {
    failures.add('no pseudonymizer after a successful resume');
  }

  return jsonEncode(<String, Object?>{
    'phase': 'verified',
    'result': failures.isEmpty ? 'PASS' : 'FAIL',
    'total': total,
    'replayed': outcome.load.replayedTransactions,
    'fromSlot': outcome.load.fromSlot.name,
    'generation': outcome.load.generation,
    'repairs': outcome.load.repairs
        .map((SaveRepair r) => r.toString())
        .toList(),
    'detail': failures,
  });
}

/// Something for the launcher to show. The harness is a command-line tool that
/// happens to need an Activity.
class _HarnessApp extends StatelessWidget {
  const _HarnessApp({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            verdict,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
        ),
      ),
    ),
  );
}
