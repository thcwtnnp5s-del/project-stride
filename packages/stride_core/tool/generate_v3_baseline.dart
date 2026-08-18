// Generates `test/fixtures/save/v3_baseline.save`, once.
//
// ## Run this exactly once, and never again
//
// ```text
// dart run tool/generate_v3_baseline.dart
// ```
//
// The output is a **frozen fixture** on the same terms as `v1_baseline.save`
// and `v2_baseline.save`: it represents a save written by a build that will
// eventually no longer exist, which is the only thing a player's phone actually
// contains. Regenerating it against a later build deletes that evidence and
// replaces it with a restatement of whatever the code does that day — after
// which the round-trip test in `save_migration_test.dart` is a tautology.
//
// If a future change makes this generator's output differ from the checked-in
// file, **that is the test doing its job.** The fix is a state version 4, a new
// decoder, a new `StateMigrations` step, and a new fixture — never a re-run of
// this script.
//
// ## What it produces
//
// The v2 baseline fixture, put through the real Transformation playtest epoch
// (`DECISIONS/0018`) — the v2→v3 step of the migration table:
//
// ```text
// decode v2_baseline.save              → granted 1041, spent 400,
//                                        epoch (1041, 400) @v2, banked 0
// migratedToCurrentVersion()           → same figures, stateVersion 3
// EstablishEconomyEpoch(2 → 3)         → epoch (1041, 400) @v3, banked 0
// encodeSnapshot(same id/gen/lastTx)   → v3_baseline.save
// ```
//
// The v2 fixture was already at banked 0, so the marks do not move; what the
// step adds is `establishedAtStateVersion: 3`. That is deliberate — the fixture
// then proves the *format* change and the exactly-once record on their own,
// while the re-basing arithmetic on a live balance is proved by
// `transformation_epoch_test.dart` against device-shaped figures.
//
// The envelope's `saveId`, `snapshotGeneration` and `lastAppliedTransaction`
// are carried across unchanged, so the two fixtures differ **only** in the ways
// the migration is supposed to change a save.

import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import '../test/content_test_support.dart';
import '../test/save_support.dart';

void main() {
  final Directory fixtures = Directory('${fixtureDirectory.path}/save');
  final File source = File('${fixtures.path}/v2_baseline.save');
  final File target = File('${fixtures.path}/v3_baseline.save');

  if (!source.existsSync()) {
    stderr.writeln('Missing ${source.path}. Restore it from git.');
    exitCode = 1;
    return;
  }
  if (target.existsSync()) {
    stderr.writeln(
      'Refusing to overwrite ${target.path}.\n'
      'It is a frozen fixture. If it disagrees with this build, the answer is '
      'a new state version and a new fixture — see the header of this file and '
      'the regeneration policy in test/save_migration_test.dart.',
    );
    exitCode = 1;
    return;
  }

  final FrameResult framed = unframe(source.readAsBytesSync());
  if (!framed.verified) {
    stderr.writeln('The v2 fixture does not verify: ${framed.fault}');
    exitCode = 1;
    return;
  }
  final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

  if (envelope.state.stateVersion != 2) {
    stderr.writeln(
      'The v2 fixture reports state version ${envelope.state.stateVersion}. '
      'This script generates the v3 fixture from a v2 save and nothing else.',
    );
    exitCode = 1;
    return;
  }
  if (StateVersion.current.value != 3) {
    stderr.writeln(
      'This build is at ${StateVersion.current}. This script produces a v3 '
      'fixture and must not run against any other current version.',
    );
    exitCode = 1;
    return;
  }

  // The same steps `BootstrapCoordinator._migrate` performs, in the same
  // order: reshape, then apply the meaning of every table step from v2.
  // Deliberately not a copy of the arithmetic — it runs the real table through
  // the real engine, so a fixture that disagrees with the shipped migration
  // cannot be produced here.
  final GameEngine engine = GameEngine(
    registry: saveRegistry,
    state: envelope.state.migratedToCurrentVersion(),
  );
  for (final StateMigrationStep step in StateMigrations.pathFrom(2)) {
    if (!step.rebasesEconomy) continue;
    final EngineResult result = engine.execute(
      EstablishEconomyEpoch(
        fromStateVersion: step.from,
        toStateVersion: step.to,
      ),
    );
    if (result.isRejected) {
      stderr.writeln('$step was refused: ${result.rejection}');
      exitCode = 1;
      return;
    }
  }

  final Uint8List bytes = encodeSnapshot(
    state: engine.state,
    saveId: envelope.saveId,
    generation: envelope.snapshotGeneration,
    lastAppliedTransaction: envelope.lastAppliedTransaction,
    originSaltFingerprint: envelope.originSaltFingerprint,
  );

  target.writeAsBytesSync(bytes, flush: true);

  stdout
    ..writeln('Wrote ${target.path} (${bytes.length} bytes)')
    ..writeln('  granted ${engine.state.steps.totalGranted}')
    ..writeln('  spent   ${engine.state.steps.totalSpent}')
    ..writeln('  epoch   ${engine.state.steps.epoch}')
    ..writeln('  banked  ${engine.state.steps.banked}')
    ..writeln('  retired ${engine.state.steps.epoch.retiredSteps}')
    ..writeln('')
    ..writeln('Check this file in. Do not run this script again.');
}
