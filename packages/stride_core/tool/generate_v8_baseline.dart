// Generates `test/fixtures/save/v8_baseline.save`, once.
//
// ## Run this exactly once, and never again
//
// ```text
// dart run tool/generate_v8_baseline.dart
// ```
//
// The output is a **frozen fixture** on the same terms as `v1_baseline.save`
// through `v7_baseline.save`, and for the same reason: a fixture regenerated
// against a later build stops being evidence about what a player's phone
// holds and becomes a restatement of whatever the code did that day.
//
// ## What it produces, and what makes this one different
//
// The v7 baseline fixture, put through the real v7→v8 step of the migration
// table — PRESENTATION_WORLD_REWARD_FEEL_01's stale-tracker repair.
//
// Every earlier generator in this family carried a *format* change across.
// This one carries none: v8's geometry is v7's geometry, and the only byte
// that moves is the version digit. That is deliberately checked below — the
// two fixtures must differ in length by exactly zero.
//
// The v7 baseline tracks no contract (its `progress` block is empty), so the
// repair finds nothing to clear and issues no command. That is the case worth
// freezing: **a save with no residue must come through the repair untouched.**
// The repair's other half — a save that *does* carry residue — cannot be a
// frozen fixture, because the v7 baseline never had a tracker to spoil; it is
// covered in `save_migration_test.dart` by building the stale state directly
// and running the same shared path.
//
// The envelope's `saveId`, `snapshotGeneration` and `lastAppliedTransaction`
// are carried across unchanged.

import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import '../test/content_test_support.dart';
import '../test/save_support.dart';

void main() {
  final Directory fixtures = Directory('${fixtureDirectory.path}/save');
  final File source = File('${fixtures.path}/v7_baseline.save');
  final File target = File('${fixtures.path}/v8_baseline.save');

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
    stderr.writeln('The v7 fixture does not verify: ${framed.fault}');
    exitCode = 1;
    return;
  }
  final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

  if (envelope.state.stateVersion != 7) {
    stderr.writeln(
      'The v7 fixture reports state version ${envelope.state.stateVersion}. '
      'This script generates the v8 fixture from a v7 save and nothing else.',
    );
    exitCode = 1;
    return;
  }
  if (StateVersion.current.value != 8) {
    stderr.writeln(
      'This build is at ${StateVersion.current}. This script produces a v8 '
      'fixture and must not run against any other current version.',
    );
    exitCode = 1;
    return;
  }

  final StateMigrationApplication applied = applyStateMigrationPath(
    registry: saveRegistry,
    state: envelope.state,
    path: StateMigrations.pathFrom(7),
  );
  if (applied is! StateMigrationApplied) {
    stderr.writeln('The v7→v8 path was refused: $applied');
    exitCode = 1;
    return;
  }
  if (applied.events.isNotEmpty) {
    stderr.writeln(
      'The v7→v8 path produced ${applied.events.length} event(s) on a save '
      'that tracks no contract. The repair must be silent where there is no '
      'residue. Refusing to write a fixture.',
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

  final int grew = bytes.length - source.lengthSync();
  if (grew != 0) {
    stderr.writeln(
      'The v8 fixture differs from the v7 fixture by $grew bytes. A repair-'
      'only version bump replaces one digit with one digit and must differ by '
      'none. Refusing to write a fixture.',
    );
    exitCode = 1;
    return;
  }

  target.writeAsBytesSync(bytes, flush: true);

  stdout
    ..writeln('Wrote ${target.path} (${bytes.length} bytes, same as v7)')
    ..writeln('  version  ${applied.engine.state.stateVersion}')
    ..writeln('  epoch    ${applied.engine.state.steps.epoch}')
    ..writeln('  banked   ${applied.engine.state.steps.banked}')
    ..writeln('  tracked  ${applied.engine.state.progress.tracked.contract}')
    ..writeln('')
    ..writeln('Check this file in. Do not run this script again.');
}
