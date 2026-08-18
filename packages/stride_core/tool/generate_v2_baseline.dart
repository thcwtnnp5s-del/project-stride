// Generates `test/fixtures/save/v2_baseline.save`, once.
//
// ## Run this exactly once, and never again
//
// ```text
// dart run tool/generate_v2_baseline.dart
// ```
//
// The output is a **frozen fixture** on the same terms as `v1_baseline.save`:
// it represents a save written by a build that will eventually no longer exist,
// which is the only thing a player's phone actually contains. Regenerating it
// against a later build deletes that evidence and replaces it with a
// restatement of whatever the code does that day — after which the round-trip
// test in `save_migration_test.dart` is a tautology.
//
// If a future change makes this generator's output differ from the checked-in
// file, **that is the test doing its job.** The fix is a new state version, a
// new decoder, and a new fixture — never a re-run of this script. (That is
// exactly what happened for state version 3: see `generate_v3_baseline.dart`.
// This script is kept for provenance and would now refuse to run, since its
// target exists; it also could no longer produce the same bytes, because the
// current encoder writes v3.)
//
// ## What it produces
//
// The v1 baseline fixture, put through the real Phase 2 cutover:
//
// ```text
// decode v1_baseline.save              → granted 1041, spent 400, banked 641
// migratedToCurrentVersion()           → same figures, stateVersion 2
// EstablishEconomyEpoch(from: 1)       → epoch (1041, 400), banked 0
// encodeSnapshot(same id/gen/lastTx)   → v2_baseline.save
// ```
//
// The envelope's `saveId`, `snapshotGeneration` and `lastAppliedTransaction`
// are carried across unchanged, so the two fixtures differ **only** in the ways
// the migration is supposed to change a save. A diff between them is readable
// as the migration itself.

import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import '../test/content_test_support.dart';
import '../test/save_support.dart';

void main() {
  final Directory fixtures = Directory('${fixtureDirectory.path}/save');
  final File source = File('${fixtures.path}/v1_baseline.save');
  final File target = File('${fixtures.path}/v2_baseline.save');

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
    stderr.writeln('The v1 fixture does not verify: ${framed.fault}');
    exitCode = 1;
    return;
  }
  final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

  if (!StateVersion.migrationRequired(envelope.state.stateVersion)) {
    stderr.writeln(
      'The v1 fixture reports state version ${envelope.state.stateVersion}, '
      'which this build does not consider in need of migration. Nothing to do.',
    );
    exitCode = 1;
    return;
  }

  // The same two steps `BootstrapCoordinator._migrate` performs, in the same
  // order: reshape, then apply the meaning. Deliberately not a copy of the
  // arithmetic — it runs the real command through the real engine, so a fixture
  // that disagrees with the shipped migration cannot be produced here.
  final GameEngine engine = GameEngine(
    registry: saveRegistry,
    state: envelope.state.migratedToCurrentVersion(),
  );
  final EngineResult result = engine.execute(
    EstablishEconomyEpoch(
      fromStateVersion: envelope.state.stateVersion,
      toStateVersion: 2,
    ),
  );
  if (result.isRejected) {
    stderr.writeln('The migration was refused: ${result.rejection}');
    exitCode = 1;
    return;
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
