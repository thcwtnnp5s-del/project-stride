// The runtime spine: state, commands, events, reducer, engine.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

ContentRegistry get production =>
    loadProduction(productionSource).requireRegistry;

ContentRegistry get acceleratedQa => const ContentLoader()
    .load(productionSource, profileId: BalanceProfile.acceleratedQaId)
    .requireRegistry;

final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId trainingAxe = ContentId.unchecked('item.training_axe');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');
final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId havensRest = ContentId.unchecked('location.havens_rest');
final ContentId whisperingWoods = ContentId.unchecked(
  'location.whispering_woods',
);

void main() {
  group('new game', () {
    test('is deterministic', () {
      final GameState first = GameEngine.newGame(registry: production).state;
      final GameState second = GameEngine.newGame(registry: production).state;

      // Nothing in creation reads a clock or generates an identifier, so two
      // new games are indistinguishable.
      expect(
        canonicalDurableGameState(first),
        canonicalDurableGameState(second),
      );
      expect(first, second);
    });

    test('grants the approved starting equipment and location', () {
      final GameState state = GameEngine.newGame(registry: production).state;

      for (final ContentId item in production.startingLoadout) {
        expect(state.inventory.has(item), isTrue, reason: '$item not granted');
      }
      expect(state.world.currentLocation, havensRest);
      expect(state.world.unlockedLocations, <ContentId>{havensRest});

      // Granted, not worn. Equipping is a player decision, and onboarding
      // teaching it is part of P-05.
      expect(state.equipment.bySlot, isEmpty);
    });

    test('every starting ID resolves in the registry', () {
      final ContentRegistry registry = production;
      final GameState state = GameEngine.newGame(registry: registry).state;

      for (final ContentId item in state.inventory.counts.keys) {
        expect(registry.items, contains(item));
      }
      for (final ContentId skill in state.skills.experienceBySkill.keys) {
        expect(registry.skills, contains(skill));
      }
      for (final ContentId location in state.world.unlockedLocations) {
        expect(registry.locations, contains(location));
      }
      expect(registry.locations, contains(state.world.currentLocation));
    });

    test('starts at the current state version with an empty ledger', () {
      final GameState state = GameEngine.newGame(registry: production).state;

      expect(state.stateVersion, StateVersion.current.value);
      expect(state.steps.totalGranted, 0);
      expect(state.steps.totalSpent, 0);
      expect(state.steps.banked, 0);
      expect(state.player.level, 1);
    });

    test('emits GameStarted as the first event', () {
      final GameEngine engine = GameEngine.newGame(registry: production);

      // The very first thing in a game's history is a fact in the same stream
      // as everything after it.
      expect(engine.state.eventSequence, 1);
    });
  });

  group('state stores IDs, not definitions', () {
    test('inventory, equipment, skills, and world hold content IDs', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(EquipItem(item: trainingSword));
      final GameState state = engine.state;

      expect(state.inventory.counts.keys, everyElement(isA<ContentId>()));
      expect(state.equipment.bySlot.values, everyElement(isA<ContentId>()));
      expect(
        state.skills.experienceBySkill.keys,
        everyElement(isA<ContentId>()),
      );
      expect(state.world.currentLocation, isA<ContentId>());

      // The signature is the whole state as text. A definition leaking in would
      // show up as a display name or a stat.
      expect(canonicalDurableGameState(state), contains('item.training_sword'));
      expect(
        canonicalDurableGameState(state),
        isNot(contains('Training Sword')),
      );
      expect(canonicalDurableGameState(state), isNot(contains('power')));
    });
  });

  group('deep immutability', () {
    test('mutating a returned collection throws', () {
      final GameState state = GameEngine.newGame(registry: production).state;

      expect(() => state.inventory.counts[oakLog] = 99, throwsUnsupportedError);
      expect(
        () => state.inventory.counts.remove(trainingSword),
        throwsUnsupportedError,
      );
      expect(
        () => state.world.unlockedLocations.add(whisperingWoods),
        throwsUnsupportedError,
      );
      expect(
        () => state.skills.experienceBySkill.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => state.equipment.bySlot[EquipmentSlot.weapon] = bronzeSword,
        throwsUnsupportedError,
      );
    });

    test('a snapshot cannot be mutated to change the engine', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final GameState snapshot = engine.state;
      final String before = canonicalDurableGameState(engine.state);

      // Every route a caller could take to reach in and edit.
      for (final void Function() attempt in <void Function()>[
        () => snapshot.inventory.counts[oakLog] = 99,
        () => snapshot.world.unlockedLocations.add(whisperingWoods),
        () => snapshot.skills.experienceBySkill[trainingSword] = 5000,
        () => snapshot.equipment.bySlot[EquipmentSlot.tool] = trainingAxe,
      ]) {
        expect(attempt, throwsUnsupportedError);
      }

      expect(canonicalDurableGameState(engine.state), before);
    });

    test('an earlier snapshot is unchanged by later commands', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final GameState earlier = engine.state;
      final String earlierSignature = canonicalDurableGameState(earlier);

      engine.execute(EquipItem(item: trainingSword));
      engine.execute(const GrantSyntheticSteps(steps: 5000, reason: 'test'));

      expect(canonicalDurableGameState(earlier), earlierSignature);
      expect(earlier.equipment.bySlot, isEmpty);
      expect(earlier.steps.totalGranted, 0);
      expect(canonicalDurableGameState(engine.state), isNot(earlierSignature));
    });

    test('a later snapshot is unaffected by mutating an earlier one', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final GameState earlier = engine.state;

      engine.execute(EquipItem(item: trainingSword));
      final GameState later = engine.state;
      final String laterSignature = canonicalDurableGameState(later);

      expect(
        () => earlier.inventory.counts[oakLog] = 1,
        throwsUnsupportedError,
      );

      expect(canonicalDurableGameState(later), laterSignature);
      expect(later.inventory.has(oakLog), isFalse);
    });

    test(
      'mutating the map a state was built from does not change the state',
      () {
        // The constructor copies. Without that, a caller who kept their map
        // could edit the state from outside, and `final` would not have stopped
        // them — it prevents reassignment, not mutation.
        final Map<ContentId, int> source = <ContentId, int>{oakLog: 1};
        final Inventory inventory = Inventory(source);

        source[trainingSword] = 99;
        source[oakLog] = 42;

        expect(inventory.counts, hasLength(1));
        expect(inventory.quantityOf(oakLog), 1);
        expect(inventory.has(trainingSword), isFalse);
      },
    );
  });

  group('state version', () {
    test('an unsupported version fails clearly', () {
      GameState build(int version) => GameState(
        stateVersion: version,
        profileId: BalanceProfile.productionId,
        contentPackVersion: 1,
        player: const PlayerState.initial(),
        inventory: Inventory.empty(),
        equipment: Equipment.empty(),
        skills: SkillProgress.empty(),
        world: WorldState(
          currentLocation: havensRest,
          unlockedLocations: <ContentId>{havensRest},
        ),
        steps: StepLedger.initial(),
        eventSequence: 0,
      );

      expect(() => build(0), throwsA(isA<UnsupportedStateVersionException>()));
      expect(
        () => build(99),
        throwsA(
          isA<UnsupportedStateVersionException>().having(
            (UnsupportedStateVersionException e) => e.message,
            'message',
            allOf(contains('99'), contains('newer build')),
          ),
        ),
      );
      expect(build(StateVersion.current.value).stateVersion, 1);
    });

    test(
      'migration has an extension point that is honest about being empty',
      () {
        // Nothing needs migrating because nothing older exists. Saying so is
        // better than implying coverage.
        expect(
          StateVersion.migrationRequired(StateVersion.current.value),
          isFalse,
        );
        expect(StateVersion.supports(StateVersion.current.value), isTrue);
        expect(StateVersion.supports(StateVersion.current.value + 1), isFalse);
      },
    );
  });

  group('commands and rejections', () {
    test('equipping an owned item is accepted', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final EngineResult result = engine.execute(
        EquipItem(item: trainingSword),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events.single, isA<ItemEquipped>());
      expect(
        engine.state.equipment.inSlot(EquipmentSlot.weapon),
        trainingSword,
      );
    });

    test('unequipping empties the slot', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(EquipItem(item: trainingSword));

      final EngineResult result = engine.execute(
        const UnequipItem(slot: EquipmentSlot.weapon),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events.single, isA<ItemUnequipped>());
      expect(engine.state.equipment.inSlot(EquipmentSlot.weapon), isNull);
    });

    test('equipping an unowned item is rejected as item_not_owned', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final EngineResult result = engine.execute(EquipItem(item: bronzeSword));

      expect(result.isRejected, isTrue);
      expect(result.rejection!.code, RejectionCode.itemNotOwned);
      expect(result.rejection!.code.wire, 'item_not_owned');
      expect(result.rejection!.subject, 'item.bronze_sword');
    });

    test('an invalid ID is rejected, not thrown', () {
      final GameEngine engine = GameEngine.newGame(registry: production);

      final EngineResult item = engine.execute(
        EquipItem(item: ContentId.unchecked('item.does_not_exist')),
      );
      expect(item.rejection!.code, RejectionCode.unknownItem);

      final EngineResult location = engine.execute(
        EnterLocation(location: ContentId.unchecked('location.nowhere')),
      );
      expect(location.rejection!.code, RejectionCode.unknownLocation);
    });

    test(
      'an owned item with no slot is rejected as invalid_equipment_slot',
      () {
        final ContentRegistry registry = production;
        final GameState withLog = GameEngine.newGame(registry: registry).state
            .copyWith(
              inventory: GameEngine.newGame(
                registry: registry,
              ).state.inventory.adding(oakLog, 5),
            );
        final GameEngine engine = GameEngine(
          registry: registry,
          state: withLog,
        );

        // Owned, so it gets past the ownership check — a raw material simply
        // occupies no slot. Checking ownership first would have hidden this.
        final EngineResult result = engine.execute(EquipItem(item: oakLog));

        expect(result.rejection!.code, RejectionCode.invalidEquipmentSlot);
        expect(result.rejection!.code.wire, 'invalid_equipment_slot');
        expect(result.rejection!.explanation, contains('material'));
      },
    );

    test('entering a locked location is rejected as location_locked', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final EngineResult result = engine.execute(
        EnterLocation(location: whisperingWoods),
      );

      expect(result.rejection!.code, RejectionCode.locationLocked);
      expect(result.rejection!.code.wire, 'location_locked');
    });

    test('allocating more steps than banked is rejected', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(const GrantSyntheticSteps(steps: 100, reason: 'test'));

      final EngineResult result = engine.execute(
        const AllocateSteps(steps: 101),
      );

      expect(result.rejection!.code, RejectionCode.insufficientSteps);
      expect(result.rejection!.explanation, contains('100'));
    });

    test('a rejected command leaves the state completely unchanged', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(const GrantSyntheticSteps(steps: 500, reason: 'test'));
      final GameState before = engine.state;

      for (final GameCommand command in <GameCommand>[
        EquipItem(item: bronzeSword),
        EnterLocation(location: whisperingWoods),
        const AllocateSteps(steps: 99999),
        const AllocateSteps(steps: 0),
        const UnequipItem(slot: EquipmentSlot.armor),
      ]) {
        final EngineResult result = engine.execute(command);
        expect(result.isRejected, isTrue, reason: command.name);
        expect(result.events, isEmpty);
        // Identity, not just equality — nothing was rebuilt, so nothing could
        // have been partially applied.
        expect(identical(engine.state, before), isTrue, reason: command.name);
        expect(identical(result.state, before), isTrue, reason: command.name);
      }

      expect(
        canonicalDurableGameState(engine.state),
        canonicalDurableGameState(before),
      );
    });

    test('every rejection carries a stable wire code and an explanation', () {
      final GameEngine engine = GameEngine.newGame(registry: production);

      for (final GameCommand command in <GameCommand>[
        EquipItem(item: bronzeSword),
        EnterLocation(location: whisperingWoods),
        const AllocateSteps(steps: 1),
        const UnequipItem(slot: EquipmentSlot.tool),
        UnlockLocation(location: havensRest),
      ]) {
        final CommandRejection? rejection = engine.execute(command).rejection;
        expect(rejection, isNotNull, reason: command.name);
        expect(rejection!.code.wire, isNotEmpty);
        expect(rejection.code.wire, matches(RegExp(r'^[a-z][a-z_]*$')));
        expect(rejection.explanation, isNotEmpty);
        expect(rejection.command, command.name);
      }
    });
  });

  group('unlock and enter', () {
    test('a location can be unlocked then entered', () {
      final GameEngine engine = GameEngine.newGame(registry: production);

      final EngineResult unlock = engine.execute(
        UnlockLocation(location: whisperingWoods),
      );
      expect(unlock.isAccepted, isTrue);
      expect(unlock.events.single, isA<LocationUnlocked>());

      final EngineResult enter = engine.execute(
        EnterLocation(location: whisperingWoods),
      );
      expect(enter.isAccepted, isTrue);
      final LocationEntered entered = enter.events.single as LocationEntered;
      expect(entered.from, havensRest);
      expect(entered.location, whisperingWoods);
      expect(engine.state.world.currentLocation, whisperingWoods);
    });

    test('unlocking twice is rejected', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(UnlockLocation(location: whisperingWoods));

      final EngineResult second = engine.execute(
        UnlockLocation(location: whisperingWoods),
      );
      expect(second.rejection!.code, RejectionCode.locationAlreadyUnlocked);
    });
  });

  group('equipment swap', () {
    test('replacing a slot emits both the removal and the addition', () {
      final ContentRegistry registry = production;
      final GameEngine engine = GameEngine.newGame(registry: registry);
      engine.execute(EquipItem(item: trainingSword));

      // Grant a second weapon through the ledger-free path a real reward would
      // eventually use.
      final GameState granted = engine.state.copyWith(
        inventory: engine.state.inventory.adding(bronzeSword, 1),
      );
      final GameEngine swapped = GameEngine(registry: registry, state: granted);

      final EngineResult result = swapped.execute(EquipItem(item: bronzeSword));

      expect(result.events, hasLength(2));
      expect(result.events.first, isA<ItemUnequipped>());
      expect(result.events.last, isA<ItemEquipped>());
      expect(swapped.state.equipment.inSlot(EquipmentSlot.weapon), bronzeSword);
    });

    test('re-equipping what is already worn changes nothing', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      engine.execute(EquipItem(item: trainingSword));
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        EquipItem(item: trainingSword),
      );

      // Accepted but eventless: idempotent, without inventing a fact.
      expect(result.isAccepted, isTrue);
      expect(result.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
    });
  });

  group('event sequence', () {
    test('is monotonic and gap-free across a session', () {
      final ContentRegistry registry = production;
      final GameEngine engine = GameEngine.newGame(registry: registry);

      final List<GameEvent> collected = <GameEvent>[];
      for (final GameCommand command in <GameCommand>[
        const GrantSyntheticSteps(steps: 3000, reason: 'test'),
        const AllocateSteps(steps: 1200),
        EquipItem(item: trainingSword),
        EquipItem(item: trainingAxe),
        UnlockLocation(location: whisperingWoods),
        EnterLocation(location: whisperingWoods),
        const UnequipItem(slot: EquipmentSlot.weapon),
      ]) {
        collected.addAll(engine.execute(command).events);
      }

      // GameStarted is sequence 0, so the session's events continue from 1.
      for (int i = 0; i < collected.length; i++) {
        expect(collected[i].sequence, i + 1);
      }
      expect(engine.state.eventSequence, collected.length + 1);
    });

    test('a rejected command does not consume a sequence number', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final int before = engine.state.eventSequence;

      engine.execute(EquipItem(item: bronzeSword));

      expect(engine.state.eventSequence, before);
    });
  });

  group('determinism', () {
    List<GameCommand> script() => <GameCommand>[
      const GrantSyntheticSteps(steps: 7500, reason: 'reference day'),
      const AllocateSteps(steps: 2500),
      EquipItem(item: trainingSword),
      EquipItem(item: bronzeSword), // rejected
      UnlockLocation(location: whisperingWoods),
      EnterLocation(location: whisperingWoods),
      const AllocateSteps(steps: 99999), // rejected
      const UnequipItem(slot: EquipmentSlot.weapon),
    ];

    test('the same script produces the same events, rejections, and state', () {
      String run() {
        final GameEngine engine = GameEngine.newGame(registry: production);
        final StringBuffer log = StringBuffer();
        for (final GameCommand command in script()) {
          final EngineResult result = engine.execute(command);
          log.write('${command.name}:');
          log.write(
            result.isRejected
                ? 'R=${result.rejection!.code.wire};'
                : 'A=${result.events.map((GameEvent e) => '${e.name}@${e.sequence}').join(',')};',
          );
        }
        return '${log.toString()}|${canonicalDurableGameState(engine.state)}';
      }

      expect(run(), run());
      expect(run(), run());
    });

    test('the engine reads no clock and no ambient randomness', () {
      // Two runs separated by real elapsed time must be identical. Wall-clock
      // progression is forbidden outright (DECISIONS/0001), and this is the
      // cheapest standing check that none crept in.
      final GameEngine first = GameEngine.newGame(registry: production);
      for (final GameCommand c in script()) {
        first.execute(c);
      }

      var spin = 0;
      for (int i = 0; i < 2000000; i++) {
        spin += i;
      }
      expect(spin, greaterThan(0));

      final GameEngine second = GameEngine.newGame(registry: production);
      for (final GameCommand c in script()) {
        second.execute(c);
      }

      expect(
        canonicalDurableGameState(first.state),
        canonicalDurableGameState(second.state),
      );
    });

    test('executeAll stops at the first rejection', () {
      final GameEngine engine = GameEngine.newGame(registry: production);
      final List<EngineResult> results = engine.executeAll(<GameCommand>[
        const GrantSyntheticSteps(steps: 100, reason: 'test'),
        const AllocateSteps(steps: 500), // rejected
        EquipItem(item: trainingSword), // never runs
      ]);

      expect(results, hasLength(2));
      expect(results.last.isRejected, isTrue);
      expect(engine.state.equipment.bySlot, isEmpty);
    });
  });

  group('canonical reducer', () {
    test('replaying the same events produces the same final state', () {
      final ContentRegistry registry = production;
      final GameEngine engine = GameEngine.newGame(registry: registry);

      final List<GameEvent> history = <GameEvent>[
        GameStarted(
          sequence: 0,
          profileId: registry.profile.id,
          startLocation: registry.startLocation.id,
          grantedItems: registry.startingLoadout,
        ),
      ];
      for (final GameCommand command in <GameCommand>[
        const GrantSyntheticSteps(steps: 4000, reason: 'test'),
        const AllocateSteps(steps: 1500),
        EquipItem(item: trainingSword),
        UnlockLocation(location: whisperingWoods),
        EnterLocation(location: whisperingWoods),
      ]) {
        history.addAll(engine.execute(command).events);
      }

      // Rebuild from scratch by replaying only the events. If the engine ever
      // changed state outside the reducer, this would diverge.
      final GameState blank = GameEngine.newGame(registry: registry).state
          .copyWith(
            inventory: Inventory.empty(),
            world: WorldState(
              currentLocation: registry.startLocation.id,
              unlockedLocations: <ContentId>{},
            ),
            eventSequence: 0,
          );
      final GameState replayed = const EventReducer().applyAll(blank, history);

      expect(
        canonicalDurableGameState(replayed),
        canonicalDurableGameState(engine.state),
      );
    });

    test('replay is repeatable', () {
      final ContentRegistry registry = production;
      final List<GameEvent> history = <GameEvent>[
        SyntheticStepsGranted(sequence: 0, steps: 900, reason: 'test'),
        const StepsAllocated(sequence: 1, steps: 400),
        LocationUnlocked(sequence: 2, location: whisperingWoods),
        LocationEntered(
          sequence: 3,
          from: havensRest,
          location: whisperingWoods,
        ),
      ];

      GameState base() => GameEngine.newGame(
        registry: registry,
      ).state.copyWith(eventSequence: 0);

      final GameState a = const EventReducer().applyAll(base(), history);
      final GameState b = const EventReducer().applyAll(base(), history);

      expect(canonicalDurableGameState(a), canonicalDurableGameState(b));
      expect(a, b);
    });

    test('an out-of-order event is a programming fault, not a rejection', () {
      final GameState state = GameEngine.newGame(registry: production).state;

      // Assertions are enabled in tests, disabled in release — an invariant,
      // not a gameplay outcome.
      expect(
        () => const EventReducer().apply(
          state,
          const SyntheticStepsGranted(sequence: 999, steps: 1, reason: 'x'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('balance profiles preserve structure and identity', () {
    test('a new game under either profile has identical shape', () {
      final GameState prod = GameEngine.newGame(registry: production).state;
      final GameState qa = GameEngine.newGame(registry: acceleratedQa).state;

      // The profile scales pacing. It must not change what exists, what is
      // granted, where the player starts, or how state is shaped.
      expect(qa.inventory.counts.keys, prod.inventory.counts.keys);
      expect(
        qa.skills.experienceBySkill.keys,
        prod.skills.experienceBySkill.keys,
      );
      expect(qa.world.currentLocation, prod.world.currentLocation);
      expect(qa.world.unlockedLocations, prod.world.unlockedLocations);
      expect(qa.stateVersion, prod.stateVersion);
      expect(qa.eventSequence, prod.eventSequence);

      // Only the recorded profile differs.
      expect(qa.profileId, isNot(prod.profileId));
    });

    test('the same command sequence behaves identically under both', () {
      String run(ContentRegistry registry) {
        final GameEngine engine = GameEngine.newGame(registry: registry);
        for (final GameCommand command in <GameCommand>[
          const GrantSyntheticSteps(steps: 5000, reason: 'test'),
          const AllocateSteps(steps: 2000),
          EquipItem(item: trainingSword),
          UnlockLocation(location: whisperingWoods),
          EnterLocation(location: whisperingWoods),
        ]) {
          engine.execute(command);
        }
        // Strip the profile ID; everything else must match.
        //
        // The pattern follows the canonical durable encoding, not the removed
        // signature string — `"profileId":"profile.x"` rather than
        // `profile=profile.x`. The comparison is strictly stronger than it was:
        // it now also covers the durable cursor and the per-origin watermarks,
        // which the signature never carried.
        return canonicalDurableGameState(
          engine.state,
        ).replaceAll(RegExp(r'"profileId":"profile\.\w+"'), '"profileId":"X"');
      }

      expect(run(acceleratedQa), run(production));
    });

    test('a state cannot be loaded under a different profile', () {
      final GameState prodState = GameEngine.newGame(
        registry: production,
      ).state;

      // Silently swapping profiles would change pacing without changing
      // anything visible in the state.
      expect(
        () => GameEngine(registry: acceleratedQa, state: prodState),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
