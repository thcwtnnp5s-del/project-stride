// Generates `test/fixtures/save/v5_baseline.save`, once.
//
// ## Run this exactly once, and never again
//
// ```text
// dart run tool/generate_v5_baseline.dart
// ```
//
// The output is a **frozen fixture** on the same terms as `v1_baseline.save`
// through `v4_baseline.save`: it represents a save written by a build that
// will eventually no longer exist, which is the only thing a player's phone
// actually contains. Regenerating it against a later build deletes that
// evidence and replaces it with a restatement of whatever the code does that
// day — after which the round-trip test in `save_migration_test.dart` is a
// tautology.
//
// If a future change makes this generator's output differ from the checked-in
// file, **that is the test doing its job.** The fix is a state version 6, a new
// decoder, a new `StateMigrations` step, and a new fixture — never a re-run of
// this script.
//
// ## What it produces
//
// The v4 baseline fixture, put through the real v4→v5 step of the migration
// table (`DECISIONS/0021`, repeatable encounters):
//
// ```text
// decode v4_baseline.save              → granted 1041, spent 400,
//                                        epoch (1041, 400) @v3, banked 0,
//                                        encounter null, drivenOff []
// migratedToCurrentVersion()           → same figures, stateVersion 5,
//                                        visitVictories {}
// (no re-basing step on the path)      → zero events
// encodeSnapshot(same id/gen/lastTx)   → v5_baseline.save
// ```
//
// The v4→v5 step declares `rebasesEconomy: false`, so the engine issues no
// command and the epoch does not move. What the fixture proves is exactly and
// only the *format* change: `world.drivenOff` (a sorted list) becomes
// `world.visitVictories` (an object of enemy id → count), and the version.
//
// The v4 baseline's `drivenOff` is empty, so the migrated map is empty and the
// fixture cannot demonstrate the count-of-one decode on its own. That is
// deliberate — the baseline stays the migrated lineage of the older fixtures,
// and the `drivenOff → 1` rule is proved in `save_migration_test.dart` against
// a v4 envelope carrying an actual driven-off enemy, which is a stronger test
// than a fixture with a hand-placed value.
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
  final File source = File('${fixtures.path}/v4_baseline.save');
  final File target = File('${fixtures.path}/v5_baseline.save');

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
    stderr.writeln('The v4 fixture does not verify: ${framed.fault}');
    exitCode = 1;
    return;
  }
  final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

  if (envelope.state.stateVersion != 4) {
    stderr.writeln(
      'The v4 fixture reports state version ${envelope.state.stateVersion}. '
      'This script generates the v5 fixture from a v4 save and nothing else.',
    );
    exitCode = 1;
    return;
  }
  if (StateVersion.current.value != 5) {
    stderr.writeln(
      'This build is at ${StateVersion.current}. This script produces a v5 '
      'fixture and must not run against any other current version.',
    );
    exitCode = 1;
    return;
  }

  // The same thing `BootstrapCoordinator._migrate` does, through the one shared
  // implementation, so a fixture that disagrees with the shipped migration
  // cannot be produced here.
  final StateMigrationApplication applied = applyStateMigrationPath(
    registry: saveRegistry,
    state: envelope.state,
    path: StateMigrations.pathFrom(4),
  );
  if (applied is! StateMigrationApplied) {
    stderr.writeln('The v4→v5 path was refused: $applied');
    exitCode = 1;
    return;
  }
  if (applied.events.isNotEmpty) {
    stderr.writeln(
      'The v4→v5 path produced ${applied.events.length} event(s); a reshape-'
      'only step must produce none. Refusing to write a fixture.',
    );
    exitCode = 1;
    return;
  }

  final Uint8List bytes = encodeSnapshot(
    state: applied.engine.state,
    saveId: envelope.saveId,
    generation: envelope.snapshotGeneration,
    lastAppliedTransaction: envelope.lastAppliedTransaction,
    originSaltFingerprint: envelope.originSaltFingerprint,
  );

  target.writeAsBytesSync(bytes, flush: true);

  stdout
    ..writeln('Wrote ${target.path} (${bytes.length} bytes)')
    ..writeln('  version        ${applied.engine.state.stateVersion}')
    ..writeln('  epoch          ${applied.engine.state.steps.epoch}')
    ..writeln('  banked         ${applied.engine.state.steps.banked}')
    ..writeln('  encounter      ${applied.engine.state.encounter}')
    ..writeln('  visitVictories ${applied.engine.state.world.visitVictories}')
    ..writeln('')
    ..writeln('Check this file in. Do not run this script again.');
}
