// Every command must be explicitly classified as player-facing or internal.
//
// The hazard this guards is not a wrong classification — it is an *absent* one.
// A new internal command that nobody remembered to mark would default to
// player-facing and could reach a UI, letting a player grant themselves steps
// or unlock the world. That failure is silent: nothing crashes, no test fails,
// and it is discovered by someone finding a button that should not exist.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

/// One instance of every command in the sealed hierarchy.
///
/// Hand-maintained on purpose. Dart cannot enumerate a sealed hierarchy's
/// subtypes at runtime, so the completeness check below compares this list
/// against the exhaustive switch — which the *compiler* enforces. Adding a
/// command without adding it here fails to compile, which is the point.
List<GameCommand> allCommands() => <GameCommand>[
  const AllocateSteps(steps: 1),
  const GrantSyntheticSteps(steps: 1, reason: 'test'),
  EquipItem(item: ContentId.unchecked('item.training_sword')),
  const UnequipItem(slot: EquipmentSlot.weapon),
  UnlockLocation(location: ContentId.unchecked('location.havens_rest')),
  EnterLocation(location: ContentId.unchecked('location.havens_rest')),
  ReconcileStepSync(response: const NoChangeSync()),
];

/// The classification each command must carry.
///
/// Deliberately a second, independent statement of intent. If a command's
/// `isPlayerFacing` is changed without changing this table, the test fails and
/// someone has to say why — which is exactly the conversation that should
/// happen before an internal command becomes reachable.
const Map<String, bool> expectedPlayerFacing = <String, bool>{
  'AllocateSteps': true,
  'EquipItem': true,
  'UnequipItem': true,
  'EnterLocation': true,
  'GrantSyntheticSteps': false,
  'UnlockLocation': false,
  'ReconcileStepSync': false,
};

/// Proves [allCommands] covers the sealed hierarchy.
///
/// The switch is exhaustive, so the compiler rejects this function the moment a
/// command is added without a case. Returning the name means a command added to
/// the hierarchy but omitted from [allCommands] is caught by the count check.
String classify(GameCommand command) => switch (command) {
  AllocateSteps() => 'AllocateSteps',
  GrantSyntheticSteps() => 'GrantSyntheticSteps',
  EquipItem() => 'EquipItem',
  UnequipItem() => 'UnequipItem',
  UnlockLocation() => 'UnlockLocation',
  EnterLocation() => 'EnterLocation',
  ReconcileStepSync() => 'ReconcileStepSync',
};

void main() {
  group('command classification completeness', () {
    test('every command in the hierarchy is represented', () {
      final List<GameCommand> commands = allCommands();
      final Set<String> names = commands.map(classify).toSet();

      expect(
        names.length,
        commands.length,
        reason: 'allCommands() contains a duplicate',
      );
      expect(
        names.length,
        expectedPlayerFacing.length,
        reason:
            'a command exists in the hierarchy that the classification '
            'table does not mention — add it, and decide deliberately whether '
            'a player may issue it',
      );
    });

    test('every command has an explicit classification', () {
      for (final GameCommand command in allCommands()) {
        final bool? expected = expectedPlayerFacing[command.name];
        expect(
          expected,
          isNotNull,
          reason:
              '${command.name} has no entry in the classification table. '
              'There is no ambiguous state: decide.',
        );
        expect(
          command.isPlayerFacing,
          expected,
          reason: '${command.name} classification disagrees with the table',
        );
      }
    });

    test('the name a command reports matches its type', () {
      // Guards against a copy-pasted `name` getter, which would make the
      // classification table silently apply to the wrong command.
      for (final GameCommand command in allCommands()) {
        expect(command.name, classify(command));
      }
    });

    test('playerFacing excludes every internal command', () {
      final List<GameCommand> surface = GameCommand.playerFacing(allCommands());
      final Set<String> exposed = surface
          .map((GameCommand c) => c.name)
          .toSet();

      for (final MapEntry<String, bool> entry in expectedPlayerFacing.entries) {
        if (entry.value) {
          expect(exposed, contains(entry.key));
        } else {
          expect(
            exposed,
            isNot(contains(entry.key)),
            reason:
                '${entry.key} is internal and must never reach a player '
                'command surface',
          );
        }
      }
    });

    test('the three internal commands are the expected ones', () {
      // Named explicitly so that widening the internal set is a deliberate,
      // reviewable edit rather than a quiet one.
      final List<String> internal =
          (expectedPlayerFacing.entries
              .where((MapEntry<String, bool> e) => !e.value)
              .map((MapEntry<String, bool> e) => e.key)
              .toList()
            ..sort());

      expect(internal, <String>[
        'GrantSyntheticSteps',
        'ReconcileStepSync',
        'UnlockLocation',
      ]);
    });

    test('internal commands still work when issued by the engine', () {
      // Excluded from the *surface*, not disabled. The engine, the debug
      // injector, and the platform adapter all still need them.
      final GameEngine engine = newEngine();

      expect(
        engine
            .execute(const GrantSyntheticSteps(steps: 100, reason: 'test'))
            .isAccepted,
        isTrue,
      );
      expect(
        engine
            .execute(
              UnlockLocation(
                location: ContentId.unchecked('location.whispering_woods'),
              ),
            )
            .isAccepted,
        isTrue,
      );
      expect(sync(engine, const NoChangeSync()).isAccepted, isTrue);
    });
  });
}
