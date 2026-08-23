// Generates `test/fixtures/save/v9_baseline.save`, once.
//
// ## Run this exactly once, and never again
//
// ```text
// dart run tool/generate_v9_baseline.dart
// ```
//
// The output is a **frozen fixture** on the same terms as `v1_baseline.save`
// through `v8_baseline.save`, and for the same reason: a fixture regenerated
// against a later build stops being evidence about what a player's phone
// holds and becomes a restatement of whatever the code did that day.
//
// ## What it produces
//
// The v8 baseline fixture, put through the real v8→v9 step of the migration
// table — the playtest reset's format bump (`DECISIONS/0025`). The step
// re-bases nothing and repairs nothing; the one field that enters the save is
// `steps.epoch.walkedAtStart`, written as `0`, which is what every v8 save
// meant. So the fixture must grow by exactly `,"walkedAtStart":0` — 18 bytes —
// and that is checked below rather than assumed.
//
// The reset itself is a player command, not a migration, and is deliberately
// **not** in this fixture: a frozen save that had been through one would be
// evidence about the command, and the command has its own tests.
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
  final File source = File('${fixtures.path}/v8_baseline.save');
  final File target = File('${fixtures.path}/v9_baseline.save');

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
    stderr.writeln('The v8 fixture does not verify: ${framed.fault}');
    exitCode = 1;
    return;
  }
  final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

  if (envelope.state.stateVersion != 8) {
    stderr.writeln(
      'The v8 fixture reports state version ${envelope.state.stateVersion}. '
      'This script generates the v9 fixture from a v8 save and nothing else.',
    );
    exitCode = 1;
    return;
  }
  if (StateVersion.current.value != 9) {
    stderr.writeln(
      'This build is at ${StateVersion.current}. This script produces a v9 '
      'fixture and must not run against any other current version.',
    );
    exitCode = 1;
    return;
  }

  final StateMigrationApplication applied = applyStateMigrationPath(
    registry: saveRegistry,
    state: envelope.state,
    path: StateMigrations.pathFrom(8),
  );
  if (applied is! StateMigrationApplied) {
    stderr.writeln('The v8→v9 path was refused: $applied');
    exitCode = 1;
    return;
  }
  if (applied.events.isNotEmpty) {
    stderr.writeln(
      'The v8→v9 path produced ${applied.events.length} event(s). A format-'
      'only bump issues none. Refusing to write a fixture.',
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
  if (grew != 18) {
    stderr.writeln(
      'The v9 fixture differs from the v8 fixture by $grew bytes; the one '
      'added field is `,"walkedAtStart":0`, 18 bytes. Refusing to write a '
      'fixture.',
    );
    exitCode = 1;
    return;
  }

  target.writeAsBytesSync(bytes, flush: true);

  stdout
    ..writeln('Wrote ${target.path} (${bytes.length} bytes, v8 + 18)')
    ..writeln('  version  ${applied.engine.state.stateVersion}')
    ..writeln('  epoch    ${applied.engine.state.steps.epoch}')
    ..writeln('  banked   ${applied.engine.state.steps.banked}')
    ..writeln('  walked   ${applied.engine.state.steps.walkedSinceBaseline}')
    ..writeln('')
    ..writeln('Check this file in. Do not run this script again.');
}
