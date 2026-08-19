import 'package:collection/collection.dart';

import '../content/balance_profile.dart';
import '../content/content_id.dart';
import '../content/content_registry.dart';
import '../content/definitions.dart';
import '../steps/reconciliation.dart';

import '../steps/step_ledger.dart';
import '../steps/step_origin_key.dart';
import 'combat.dart';
import 'combat_rules.dart';
import 'commands.dart';
import 'event_reducer.dart';
import 'events.dart';
import 'game_state.dart';
import 'rejection.dart';
import 'state_version.dart';

/// The simulation.
///
/// ## Flow
///
/// ```text
/// command → validate against state + content
///         → typed events, or a typed rejection
///         → canonical reducer
///         → new immutable state
/// ```
///
/// Validation reads; only the reducer writes. There is no path where a command
/// handler changes something itself.
///
/// ## Determinism
///
/// Same state, same registry, same profile, same commands ⇒ same events, same
/// rejections, same resulting state. The engine reads no clock, draws no
/// randomness, consults no locale or timezone, and touches no platform.
///
/// Time and randomness are not forbidden forever — they are forbidden *as
/// ambient inputs*. When a future task needs either, it will be injected, so
/// that "what happened" remains a function of state and commands rather than of
/// when the code ran.
///
/// **No wall-clock progression, ever.** Steps advance the game
/// (`DECISIONS/0001`); elapsed time does not.
final class GameEngine {
  GameEngine({required this.registry, required GameState state})
    : _state = state {
    if (state.profileId != registry.profile.id) {
      throw ArgumentError(
        'State was created under profile ${state.profileId} but the registry '
        'provides ${registry.profile.id}. Loading a state under a different '
        'balance profile would silently change pacing.',
      );
    }
  }

  /// Starts a new game deterministically.
  ///
  /// The only inputs are the registry and its profile, so two calls with the
  /// same content produce byte-identical states. No timestamp, no generated
  /// identifier, nothing that would make one new game differ from another.
  factory GameEngine.newGame({required ContentRegistry registry}) {
    final GameState empty = GameState(
      stateVersion: StateVersion.current.value,
      profileId: registry.profile.id,
      contentPackVersion: 1,
      player: const PlayerState.initial(),
      inventory: Inventory.empty(),
      equipment: Equipment.empty(),
      skills: SkillProgress(<ContentId, int>{
        for (final ContentId skill in registry.skills.keys) skill: 0,
      }),
      world: WorldState(
        currentLocation: registry.startLocation.id,
        unlockedLocations: <ContentId>{registry.startLocation.id},
      ),
      steps: StepLedger.initial(),
      eventSequence: 0,
    );

    final GameEngine engine = GameEngine(registry: registry, state: empty);
    engine._commit(<GameEvent>[
      GameStarted(
        sequence: 0,
        profileId: registry.profile.id,
        startLocation: registry.startLocation.id,
        grantedItems: registry.startingLoadout,
      ),
    ]);
    return engine;
  }

  final ContentRegistry registry;
  static const EventReducer _reducer = EventReducer();
  static final StepReconciler _reconciler = StepReconciler();

  GameState _state;

  /// The current state.
  ///
  /// Safe to keep. It is deeply immutable, so a caller holding one is holding a
  /// snapshot that nothing here will change.
  GameState get state => _state;

  /// The active balance profile.
  BalanceProfile get profile => registry.profile;

  /// Validates [command], applies any events, and returns the outcome.
  EngineResult execute(GameCommand command) {
    final GameState before = _state;
    final _Decision decision = _validate(command, before);

    final CommandRejection? rejection = decision.rejection;
    if (rejection != null) {
      // Returns the *same object*, not a copy, and deliberately so: a test can
      // then assert `identical(engine.state, before)`, which proves nothing was
      // rebuilt and therefore nothing could have been partially applied.
      // Replacing this with `before.copyWith()` would weaken that guarantee to
      // value equality and break those tests for a reason no diff would explain.
      return RejectedResult(state: before, rejection: rejection);
    }

    final List<GameEvent> events = decision.events;
    if (events.isEmpty) {
      // Accepted with nothing to record — re-equipping what is already worn,
      // for instance. Idempotent without inventing a fact: a fabricated
      // `ItemEquipped` for something that did not change would corrupt replay
      // and would fire audio for a non-event.
      return AcceptedResult(state: before, events: const <GameEvent>[]);
    }

    _commit(events);
    return AcceptedResult(state: _state, events: events);
  }

  /// Runs a sequence, stopping at the first rejection.
  ///
  /// Stopping rather than continuing is deliberate: a later command usually
  /// assumes the earlier one succeeded, and pushing on would produce a cascade
  /// of consequential rejections that bury the first real one.
  List<EngineResult> executeAll(Iterable<GameCommand> commands) {
    final List<EngineResult> results = <EngineResult>[];
    for (final GameCommand command in commands) {
      final EngineResult result = execute(command);
      results.add(result);
      if (result.isRejected) break;
    }
    return results;
  }

  void _commit(List<GameEvent> events) {
    _state = _reducer.applyAll(_state, events);
  }

  // -- Validation ------------------------------------------------------------

  _Decision _validate(GameCommand command, GameState state) =>
      switch (command) {
        GrantSyntheticSteps() => _grantSteps(command, state),
        AllocateSteps() => _allocateSteps(command, state),
        EquipItem() => _equip(command, state),
        UnequipItem() => _unequip(command, state),
        UnlockLocation() => _unlock(command, state),
        EnterLocation() => _enter(command, state),
        TravelTo() => _travel(command, state),
        CraftItem() => _craft(command, state),
        GatherResource() => _gather(command, state),
        ReconcileStepSync() => _reconcile(command, state),
        EstablishEconomyEpoch() => _establishEpoch(command, state),
        EstablishNewGameBaseline() => _establishBaseline(command, state),
        StartEncounter() => _startEncounter(command, state),
        CombatAttack() => _combatAttack(command, state),
        CombatEat() => _combatEat(command, state),
        CombatRetreat() => _combatRetreat(command, state),
      };

  // -- Combat (Combat Slice 01) ---------------------------------------------

  /// The refusal gathering and travel share while a fight is on. Null when no
  /// encounter is active. Crafting and equipping are deliberately not gated:
  /// they cannot change a fight already snapshotted (`GAME_BIBLE/COMBAT/02` §8).
  CommandRejection? _refuseDuringEncounter(
    GameCommand command,
    GameState state,
  ) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) return null;
    return CommandRejection(
      code: RejectionCode.encounterInProgress,
      command: command.name,
      explanation:
          'an encounter with ${encounter.enemy.value} is active; attack, eat '
          'or retreat first',
      subject: encounter.enemy.value,
    );
  }

  /// Begins a fight.
  ///
  /// Does this enemy exist → is it here → am I already fighting → has it been
  /// driven off. Costs no steps (`DECISIONS/0020` §3). The player's figures
  /// are derived once, here, and snapshotted onto the event; the enemy's
  /// health is profile-scaled once, here. The seed is a pure function of the
  /// event sequence and the enemy id.
  _Decision _startEncounter(StartEncounter command, GameState state) {
    final EnemyDefinition? enemy = registry.enemies[command.enemy];
    if (enemy == null) {
      return _Decision.reject(
        RejectionCode.unknownEnemy,
        command,
        'no enemy is defined with that ID',
        subject: command.enemy.value,
      );
    }
    if (enemy.location != state.world.currentLocation) {
      return _Decision.reject(
        RejectionCode.enemyNotHere,
        command,
        '"${enemy.displayName}" is at '
        '${registry.locations[enemy.location]?.displayName ?? enemy.location.value}, '
        'not where the player is standing',
        subject: command.enemy.value,
      );
    }
    final EncounterState? active = state.encounter;
    if (active != null) {
      return _Decision.reject(
        RejectionCode.encounterInProgress,
        command,
        'an encounter with ${active.enemy.value} is already active',
        subject: command.enemy.value,
      );
    }
    if (state.world.isDrivenOff(command.enemy)) {
      return _Decision.reject(
        RejectionCode.enemyDrivenOff,
        command,
        '"${enemy.displayName}" has been driven off here; it returns once the '
        'player moves on',
        subject: command.enemy.value,
      );
    }

    final PlayerCombatLoadout loadout = CombatRules.loadoutFor(state, registry);
    final int enemyHp = profile.applyEnemyHealth(enemy.health);
    return _Decision.accept(<GameEvent>[
      EncounterStarted(
        sequence: state.eventSequence,
        enemy: command.enemy,
        location: state.world.currentLocation,
        seed: CombatRules.seedFor(state.eventSequence, command.enemy),
        playerHp: loadout.maxHp,
        playerMaxHp: loadout.maxHp,
        playerAttack: loadout.attack,
        playerDefence: loadout.defence,
        enemyHp: enemyHp,
        enemyMaxHp: enemyHp,
      ),
    ]);
  }

  /// One round: the player strikes, then the enemy replies unless it fell.
  _Decision _combatAttack(CombatAttack command, GameState state) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) {
      return _Decision.reject(
        RejectionCode.noEncounter,
        command,
        'no encounter is active',
      );
    }
    final EnemyDefinition? enemy = registry.enemies[encounter.enemy];
    if (enemy == null) {
      // Unreachable through a validated registry and a save whose references
      // were checked at load. Answered rather than thrown.
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the enemy in the active encounter is not loaded',
        subject: encounter.enemy.value,
      );
    }

    final List<GameEvent> events = <GameEvent>[];
    int sequence = state.eventSequence;
    final int turn = encounter.turn;

    final int damage = CombatRules.strike(
      encounter.playerAttack,
      enemy.defence,
      CombatRules.roll(encounter.seed, turn, CombatRules.playerStrikeSalt),
    );
    final int enemyHpAfter = encounter.enemyHp - damage < 0
        ? 0
        : encounter.enemyHp - damage;
    events.add(
      CombatPlayerStruck(
        sequence: sequence++,
        damage: damage,
        enemyHpAfter: enemyHpAfter,
        turn: turn,
      ),
    );

    if (enemyHpAfter == 0) {
      events.add(_victory(sequence, state, encounter, enemy));
      return _Decision.accept(events);
    }

    _enemyReply(events, sequence, state, encounter, enemy, encounter.playerHp);
    return _Decision.accept(events);
  }

  /// One round: the player eats, then the enemy replies. A turn spent.
  ///
  /// No encounter → item unknown → not owned → not edible → HP full.
  _Decision _combatEat(CombatEat command, GameState state) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) {
      return _Decision.reject(
        RejectionCode.noEncounter,
        command,
        'no encounter is active',
      );
    }
    final ItemDefinition? item = registry.items[command.item];
    if (item == null) {
      return _Decision.reject(
        RejectionCode.unknownItem,
        command,
        'no item is defined with that ID',
        subject: command.item.value,
      );
    }
    if (!state.inventory.has(command.item)) {
      return _Decision.reject(
        RejectionCode.itemNotOwned,
        command,
        'the player does not have "${item.displayName}"',
        subject: command.item.value,
      );
    }
    if (item.category != ItemCategory.consumable || item.healing <= 0) {
      return _Decision.reject(
        RejectionCode.notEdible,
        command,
        '"${item.displayName}" is not a consumable that heals',
        subject: command.item.value,
      );
    }
    final int missing = encounter.playerMaxHp - encounter.playerHp;
    if (missing <= 0) {
      return _Decision.reject(
        RejectionCode.healthFull,
        command,
        'the player is already at full health',
        subject: command.item.value,
      );
    }
    final EnemyDefinition? enemy = registry.enemies[encounter.enemy];
    if (enemy == null) {
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the enemy in the active encounter is not loaded',
        subject: encounter.enemy.value,
      );
    }

    final int healed = item.healing < missing ? item.healing : missing;
    final int hpAfterEating = encounter.playerHp + healed;
    final List<GameEvent> events = <GameEvent>[
      CombatConsumableUsed(
        sequence: state.eventSequence,
        item: command.item,
        healed: healed,
        playerHpAfter: hpAfterEating,
        turn: encounter.turn,
      ),
    ];
    _enemyReply(
      events,
      state.eventSequence + 1,
      state,
      encounter,
      enemy,
      hpAfterEating,
    );
    return _Decision.accept(events);
  }

  /// Leaves the fight. Nothing else changes.
  _Decision _combatRetreat(CombatRetreat command, GameState state) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) {
      return _Decision.reject(
        RejectionCode.noEncounter,
        command,
        'no encounter is active',
      );
    }
    return _Decision.accept(<GameEvent>[
      EncounterRetreated(
        sequence: state.eventSequence,
        enemy: encounter.enemy,
        location: encounter.location,
        retreatTo: CombatRules.retreatDestination(state, registry),
      ),
    ]);
  }

  /// The one `EncounterWon`, with every figure of the reward on it.
  ///
  /// XP is profile-scaled here, once; the level after is recomputed from the
  /// total here, once, and written on the event so the reducer never consults
  /// the curve. Drops roll from the seed with the drop index and the victory
  /// turn — one independent draw per drop — and are recorded as literal
  /// amounts, unscaled: drops are not gather yields.
  EncounterWon _victory(
    int sequence,
    GameState state,
    EncounterState encounter,
    EnemyDefinition enemy,
  ) {
    final int xp = profile.applyXp(enemy.xp);
    final int experienceAfter = state.player.experience + xp;
    final Map<ContentId, int> drops = <ContentId, int>{};
    for (int i = 0; i < enemy.drops.length; i++) {
      final EnemyDrop drop = enemy.drops[i];
      final int rolled = CombatRules.percentRoll(
        encounter.seed,
        i,
        encounter.turn,
      );
      if (rolled < drop.chancePercent) {
        drops[drop.item] = (drops[drop.item] ?? 0) + drop.quantity;
      }
    }
    return EncounterWon(
      sequence: sequence,
      enemy: encounter.enemy,
      location: encounter.location,
      characterXp: xp,
      experienceAfter: experienceAfter,
      levelBefore: state.player.level,
      levelAfter: CombatRules.levelFor(experienceAfter),
      drops: drops,
    );
  }

  /// The enemy's reply for this round, appended to [events] from [sequence].
  ///
  /// Per behaviour (`GAME_BIBLE/COMBAT/02` §6): steady one strike, flurry two,
  /// guarded one strike that is heavy every third turn. After each strike, if
  /// the player falls the round ends in `EncounterLost` and nothing further is
  /// emitted; otherwise the round closes with `CombatRoundEnded` carrying the
  /// new turn number and, for a guarded enemy, whether the *next* reply will be
  /// heavy — the telegraph, set at the end of the round before.
  void _enemyReply(
    List<GameEvent> events,
    int sequence,
    GameState state,
    EncounterState encounter,
    EnemyDefinition enemy,
    int playerHp,
  ) {
    final int turn = encounter.turn;
    final bool heavy =
        enemy.behavior == EnemyBehavior.guarded &&
        CombatRules.isHeavyTurn(turn);
    final int strikes = enemy.behavior == EnemyBehavior.flurry ? 2 : 1;

    int hp = playerHp;
    for (int i = 0; i < strikes; i++) {
      final int damage = heavy
          ? CombatRules.heavyStrike(enemy.attack, encounter.playerDefence)
          : CombatRules.strike(
              enemy.attack,
              encounter.playerDefence,
              CombatRules.roll(
                encounter.seed,
                turn,
                CombatRules.enemyStrikeSalt + i,
              ),
            );
      hp = hp - damage < 0 ? 0 : hp - damage;
      events.add(
        CombatEnemyStruck(
          sequence: sequence++,
          damage: damage,
          playerHpAfter: hp,
          turn: turn,
          heavy: heavy,
          strikeIndex: i,
        ),
      );
      if (hp == 0) {
        events.add(
          EncounterLost(
            sequence: sequence,
            enemy: encounter.enemy,
            location: encounter.location,
            retreatTo: CombatRules.retreatDestination(state, registry),
          ),
        );
        return;
      }
    }

    final int nextTurn = turn + 1;
    events.add(
      CombatRoundEnded(
        sequence: sequence,
        turn: nextTurn,
        telegraph:
            enemy.behavior == EnemyBehavior.guarded &&
            CombatRules.isHeavyTurn(nextTurn),
      ),
    );
  }

  /// Retires a new game's first observed history. See
  /// [EstablishNewGameBaseline]; refused by the state once the mark has left
  /// the origin.
  _Decision _establishBaseline(
    EstablishNewGameBaseline command,
    GameState state,
  ) {
    final EconomyEpoch epoch = state.steps.epoch;
    if (!epoch.isOrigin) {
      return _Decision.reject(
        RejectionCode.economyEpochAlreadySet,
        command,
        'this game already has an economy mark at '
        '${epoch.grantedAtStart} granted / ${epoch.spentAtStart} spent '
        '(state v${epoch.establishedAtStateVersion}); a baseline is set once',
      );
    }
    return _Decision.accept(<GameEvent>[
      EconomyEpochEstablished(
        sequence: state.eventSequence,
        grantedAtStart: state.steps.totalGranted,
        spentAtStart: state.steps.totalSpent,
        fromStateVersion: command.stateVersion,
        toStateVersion: command.stateVersion,
      ),
    ]);
  }

  /// Re-bases the playable economy. See [EstablishEconomyEpoch].
  ///
  /// A pure function of the ledger it is handed: the marks are simply what the
  /// two counters currently read. That is what makes the migration idempotent
  /// under retry — a crashed commit is followed by a launch that reads the same
  /// unchanged save and computes the same two numbers.
  ///
  /// The guard is on the epoch's own record of which step established it, not
  /// on "is it the origin". An epoch established at or after
  /// [EstablishEconomyEpoch.toStateVersion] has already been through this step
  /// (or a later one) and is refused; an earlier one is re-based exactly once.
  _Decision _establishEpoch(EstablishEconomyEpoch command, GameState state) {
    final EconomyEpoch epoch = state.steps.epoch;
    if (epoch.establishedAtStateVersion >= command.toStateVersion) {
      return _Decision.reject(
        RejectionCode.economyEpochAlreadySet,
        command,
        'the playable economy was already re-based for state '
        'v${epoch.establishedAtStateVersion} at '
        '${epoch.grantedAtStart} granted / ${epoch.spentAtStart} spent; '
        'v${command.toStateVersion} may not re-base it again',
      );
    }
    return _Decision.accept(<GameEvent>[
      EconomyEpochEstablished(
        sequence: state.eventSequence,
        grantedAtStart: state.steps.totalGranted,
        spentAtStart: state.steps.totalSpent,
        previousGrantedAtStart: epoch.grantedAtStart,
        previousSpentAtStart: epoch.spentAtStart,
        fromStateVersion: command.fromStateVersion,
        toStateVersion: command.toStateVersion,
      ),
    ]);
  }

  /// Walks a route.
  ///
  /// ## The order of the refusals is the order of the player's questions
  ///
  /// Does this place exist → am I already there → can I get there from here →
  /// do I hold what it takes to enter → can I afford the walk. Cost is checked
  /// **last**, for the same reason it is last in [_gather]: telling a player
  /// they cannot afford Forgotten Hollow, when the real answer is that it needs
  /// a Bronze Sword, sends them walking toward a wall they will still hit.
  _Decision _travel(TravelTo command, GameState state) {
    final LocationDefinition? destination =
        registry.locations[command.destination];
    if (destination == null) {
      return _Decision.reject(
        RejectionCode.unknownLocation,
        command,
        'no location is defined with that ID',
        subject: command.destination.value,
      );
    }

    // Right after existence, so "no such place" still reads as such, and
    // before every other question, because none of them matters until the
    // fight is resolved (`GAME_BIBLE/COMBAT/02` §8).
    final CommandRejection? fighting = _refuseDuringEncounter(command, state);
    if (fighting != null) return _Decision.rejectWith(fighting);

    if (state.world.currentLocation == command.destination) {
      return _Decision.reject(
        RejectionCode.alreadyAtLocation,
        command,
        'the player is already there',
        subject: command.destination.value,
      );
    }

    final LocationDefinition? here =
        registry.locations[state.world.currentLocation];
    if (here == null) {
      // Unreachable through a validated registry. Answered rather than thrown:
      // an engine that crashes on a content defect takes the game down over a
      // file someone edited.
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the location the player is standing in is not loaded',
        subject: state.world.currentLocation.value,
      );
    }

    // Adjacency is the content graph's answer, not the caller's. A route the
    // world does not declare cannot be manufactured by naming two places.
    final LocationConnection? route = here.connections
        .where((LocationConnection c) => c.to == command.destination)
        .firstOrNull;
    if (route == null) {
      return _Decision.reject(
        RejectionCode.routeNotFound,
        command,
        'no route runs from "${here.displayName}" to '
        '"${destination.displayName}"',
        subject: command.destination.value,
      );
    }

    final List<ContentId> missing = destination.entryRequirements
        .where((ContentId item) => !state.inventory.has(item))
        .toList();
    if (missing.isNotEmpty) {
      final String names = missing
          .map(
            (ContentId id) =>
                '"${registry.items[id]?.displayName ?? id.value}"',
          )
          .join(', ');
      return _Decision.reject(
        RejectionCode.entryRequirementUnmet,
        command,
        '"${destination.displayName}" cannot be entered without $names',
        subject: command.destination.value,
      );
    }

    final int cost = profile.applyStepCost(route.stepCost);
    if (cost > state.steps.banked) {
      return _Decision.reject(
        RejectionCode.insufficientSteps,
        command,
        'travelling to "${destination.displayName}" costs $cost steps but only '
        '${state.steps.banked} are banked',
        subject: command.destination.value,
      );
    }

    return _Decision.accept(<GameEvent>[
      LocationTravelled(
        sequence: state.eventSequence,
        from: state.world.currentLocation,
        location: command.destination,
        stepsSpent: cost,
        firstVisit: !state.world.isUnlocked(command.destination),
      ),
    ]);
  }

  /// Turns held materials into an item.
  ///
  /// Does this recipe exist → am I skilled enough → do I hold the materials.
  /// There is no step check and no location check: crafting costs no steps, and
  /// nothing in the design ties a recipe to a workshop.
  ///
  /// The ingredient check reports **every** shortfall rather than the first.
  /// A player two ingots and one handle short should learn both in one refusal;
  /// discovering a second requirement only after satisfying the first is the
  /// kind of drip-feed that makes a crafting screen feel like it is hiding
  /// things.
  _Decision _craft(CraftItem command, GameState state) {
    final RecipeDefinition? recipe = registry.recipes[command.recipe];
    if (recipe == null) {
      return _Decision.reject(
        RejectionCode.unknownRecipe,
        command,
        'no recipe is defined with that ID',
        subject: command.recipe.value,
      );
    }

    final SkillDefinition? skill = registry.skills[recipe.skill];
    if (skill == null) {
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the skill "${recipe.skill.value}" this recipe trains is not loaded',
        subject: recipe.skill.value,
      );
    }

    final int level = skill.levelAt(state.skills.experienceIn(recipe.skill));
    if (level < recipe.requiredLevel) {
      return _Decision.reject(
        RejectionCode.skillLevelTooLow,
        command,
        '"${recipe.displayName}" needs ${skill.displayName} '
        '${recipe.requiredLevel}; the player is level $level',
        subject: command.recipe.value,
      );
    }

    // Folded first, so a recipe naming the same ingredient twice is charged
    // once for the sum rather than checked twice against the same holding —
    // which would pass with half the materials and then remove more than the
    // player had.
    final Map<ContentId, int> required = <ContentId, int>{};
    for (final RecipeIngredient ingredient in recipe.ingredients) {
      required[ingredient.item] =
          (required[ingredient.item] ?? 0) + ingredient.quantity;
    }

    final List<String> shortfalls = <String>[];
    for (final MapEntry<ContentId, int> need in required.entries) {
      final int held = state.inventory.quantityOf(need.key);
      if (held >= need.value) continue;
      final String name =
          registry.items[need.key]?.displayName ?? need.key.value;
      shortfalls.add('$name ${need.value - held} short');
    }
    if (shortfalls.isNotEmpty) {
      return _Decision.reject(
        RejectionCode.insufficientIngredients,
        command,
        '"${recipe.displayName}" cannot be made: ${shortfalls.join(', ')}',
        subject: command.recipe.value,
      );
    }

    return _Decision.accept(<GameEvent>[
      ItemCrafted(
        sequence: state.eventSequence,
        recipe: command.recipe,
        consumed: required,
        item: recipe.outputItem,
        quantity: profile.applyYield(recipe.outputQuantity),
        skill: recipe.skill,
        experience: profile.applyXp(recipe.xp),
      ),
    ]);
  }

  /// Reconciles a normalized provider response.
  ///
  /// ## Event order is the crash-safety contract
  ///
  /// The events are emitted in commit order, and the reducer applies them in
  /// that order:
  ///
  /// 1. `StepRecoveryStarted` — only when recovering, so an interrupted
  ///    recovery is distinguishable from one that never began
  /// 2. `StepObservationReconciled` — observed totals and slice records
  /// 3. `StepsGranted` — the credit, if any
  /// 4. `StepRecoveryCompleted` — only when recovering
  /// 5. `StepCheckpointAuthorized` — **last**, so the cursor becomes
  ///    persistable strictly after the ledger has committed
  ///
  /// A process that dies at any point leaves the old cursor in place, and the
  /// retry recomputes the same answer. Authorizing the cursor first would let
  /// a crash resume past steps that were never credited — steps the player
  /// walked and would never see.
  _Decision _reconcile(ReconcileStepSync command, GameState state) {
    final ReconciliationOutcome outcome = _reconciler.reconcile(
      ledger: state.steps,
      response: command.response,
    );

    switch (outcome) {
      case ReconciliationRefused(
        :final ReconciliationCode code,
        :final String explanation,
      ):
        // The ledger is untouched, but the provider's availability is a fact
        // worth recording — the UI needs it to explain itself calmly.
        final SourceState sourceState = switch (code) {
          ReconciliationCode.serviceUnavailable =>
            SourceState.serviceUnavailable,
          ReconciliationCode.permissionUnavailable =>
            SourceState.permissionUnavailable,
          ReconciliationCode.transientFailure =>
            SourceState.transientlyUnavailable,
          // Distinct from serviceUnavailable on purpose: the service may be
          // present and authorized, and no amount of retrying fixes it. The
          // player-facing action is to reconnect the health source; the
          // developer harness shows it as configuration-blocked.
          ReconciliationCode.originKeyingUnconfigured =>
            SourceState.originKeyingUnconfigured,
          ReconciliationCode.malformedBatch => state.steps.sourceState,
        };

        if (code == ReconciliationCode.malformedBatch) {
          return _Decision.reject(
            RejectionCode.malformedSyncBatch,
            command,
            explanation,
          );
        }
        if (sourceState == state.steps.sourceState) {
          // Nothing new to say. Accepted with no events keeps a repeated
          // failure from filling the event stream with noise.
          return _Decision.accept(const <GameEvent>[]);
        }
        return _Decision.accept(<GameEvent>[
          StepSourceStateChanged(
            sequence: state.eventSequence,
            sourceState: sourceState,
            code: code,
          ),
        ]);

      case ReconciliationAccepted():
        final List<GameEvent> events = <GameEvent>[];
        int sequence = state.eventSequence;

        if (state.steps.sourceState != SourceState.available) {
          events.add(
            StepSourceStateChanged(
              sequence: sequence++,
              sourceState: SourceState.available,
            ),
          );
        }

        if (outcome.wasRecovery) {
          events.add(
            StepRecoveryStarted(
              sequence: sequence++,
              windowStartMillis: outcome.windowStartMillis ?? 0,
              windowEndMillis: outcome.windowEndMillis ?? 0,
              truncated: outcome.truncatedGap,
            ),
          );
        }

        // The watermarks are whatever compaction actually used, never figures
        // recomputed here. The two disagreeing is what silently discarded a
        // paginated backfill.
        //
        // Merged per origin, and monotonic per origin: an origin's watermark
        // never moves backwards, and an origin the batch said nothing about
        // keeps whatever it had.
        final Map<StepOriginKey, int> watermarks = <StepOriginKey, int>{
          ...state.steps.checkpoint.originWatermarks,
        };
        for (final MapEntry<StepOriginKey, int> e
            in outcome.watermarksAfter.entries) {
          final int? existing = watermarks[e.key];
          if (existing == null || e.value > existing) {
            watermarks[e.key] = e.value;
          }
        }
        // Diagnostic only: the lowest per-origin watermark. Never used to
        // decide whether a slice is settled.
        final int? watermark = watermarks.isEmpty
            ? null
            : watermarks.values.reduce((int a, int b) => a < b ? a : b);

        events.add(
          StepObservationReconciled(
            sequence: sequence++,
            observedAfter: outcome.observedAfter,
            grantedSlicesAfter: outcome.grantedSlicesAfter,
            grantedCompactedAway: outcome.compactedGranted,
            lateDiscarded: outcome.lateDiscardedSlices,
            watermarkMillis: watermark,
            originWatermarks: watermarks,
            correctionsSeen: outcome.correctionsSeen,
            truncatedGap: outcome.truncatedGap,
            wasRecovery: outcome.wasRecovery,
          ),
        );

        if (outcome.newlyGranted > 0) {
          events.add(
            StepsGranted(
              sequence: sequence++,
              steps: outcome.newlyGranted,
              grantedTotalAfter: outcome.grantedAfter,
            ),
          );
        }

        if (outcome.wasRecovery) {
          events.add(
            StepRecoveryCompleted(
              sequence: sequence++,
              newlyGranted: outcome.newlyGranted,
              truncated: outcome.truncatedGap,
            ),
          );
        }

        // Last. The cursor becomes persistable only now.
        events.add(
          StepCheckpointAuthorized(
            sequence: sequence,
            cursor: outcome.cursorToAuthorize ?? state.steps.checkpoint.cursor,
            syncCount: state.steps.checkpoint.syncCount + 1,
          ),
        );

        return _Decision.accept(events);
    }
  }

  _Decision _grantSteps(GrantSyntheticSteps command, GameState state) {
    if (command.steps <= 0) {
      return _Decision.reject(
        RejectionCode.invalidAmount,
        command,
        'cannot grant ${command.steps} steps; the amount must be positive',
      );
    }
    return _Decision.accept(<GameEvent>[
      SyntheticStepsGranted(
        sequence: state.eventSequence,
        steps: command.steps,
        reason: command.reason,
      ),
    ]);
  }

  _Decision _allocateSteps(AllocateSteps command, GameState state) {
    if (command.steps <= 0) {
      return _Decision.reject(
        RejectionCode.invalidAmount,
        command,
        'cannot allocate ${command.steps} steps; the amount must be positive',
      );
    }
    if (command.steps > state.steps.banked) {
      return _Decision.reject(
        RejectionCode.insufficientSteps,
        command,
        'tried to allocate ${command.steps} steps but only '
        '${state.steps.banked} are banked',
      );
    }
    return _Decision.accept(<GameEvent>[
      StepsAllocated(sequence: state.eventSequence, steps: command.steps),
    ]);
  }

  /// Works a resource node once.
  ///
  /// ## The order of the refusals is the order of the player's questions
  ///
  /// Does this exist → am I there → am I skilled enough → do I have the tool →
  /// can I afford it. Cost is checked **last** deliberately: telling a level-1
  /// player they cannot afford Pine Ridge, when the real answer is that it
  /// needs level 8, sends them walking for a wall they will still hit.
  ///
  /// ## Every figure is scaled here, once
  ///
  /// `stepCost`, `yieldsQuantity` and `xp` are base values; the active balance
  /// profile scales them at the point of use, which is this method. The scaled
  /// figures go onto the event, so the reducer performs no arithmetic against
  /// content and a replay under a retuned pack reproduces the original result.
  _Decision _gather(GatherResource command, GameState state) {
    final ResourceNodeDefinition? node = registry.resourceNodes[command.node];
    if (node == null) {
      return _Decision.reject(
        RejectionCode.unknownResourceNode,
        command,
        'no resource node is defined with that ID',
        subject: command.node.value,
      );
    }

    // Same placement as in [_travel]: after existence, before everything else.
    final CommandRejection? fighting = _refuseDuringEncounter(command, state);
    if (fighting != null) return _Decision.rejectWith(fighting);

    final LocationDefinition? here =
        registry.locations[state.world.currentLocation];
    if (here == null || !here.resourceNodes.contains(command.node)) {
      return _Decision.reject(
        RejectionCode.resourceNodeNotHere,
        command,
        '"${node.displayName}" is not at '
        '${here?.displayName ?? state.world.currentLocation.value}',
        subject: command.node.value,
      );
    }

    final SkillDefinition? skill = registry.skills[node.skill];
    if (skill == null) {
      // Unreachable through a validated registry -- the content loader's
      // reference check rejects a node naming a skill that does not exist.
      // Answered rather than thrown anyway: an engine that crashes on a content
      // defect takes the game down over a file someone edited.
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the skill "${node.skill.value}" this node trains is not loaded',
        subject: node.skill.value,
      );
    }

    final int level = skill.levelAt(state.skills.experienceIn(node.skill));
    if (level < node.requiredLevel) {
      return _Decision.reject(
        RejectionCode.skillLevelTooLow,
        command,
        '"${node.displayName}" needs ${skill.displayName} '
        '${node.requiredLevel}; the player is level $level',
        subject: command.node.value,
      );
    }

    if (node.requiredToolKind != ToolKind.none && !_hasTool(node, state)) {
      return _Decision.reject(
        RejectionCode.toolRequired,
        command,
        '"${node.displayName}" needs a ${node.requiredToolKind.name} of tier '
        '${node.minimumToolTier} or better equipped',
        subject: command.node.value,
      );
    }

    final int cost = profile.applyStepCost(node.stepCost);
    if (cost > state.steps.banked) {
      return _Decision.reject(
        RejectionCode.insufficientSteps,
        command,
        '"${node.displayName}" costs $cost steps but only '
        '${state.steps.banked} are banked',
        subject: command.node.value,
      );
    }

    return _Decision.accept(<GameEvent>[
      ResourceGathered(
        sequence: state.eventSequence,
        node: command.node,
        stepsSpent: cost,
        item: node.yieldsItem,
        quantity: profile.applyYield(node.yieldsQuantity),
        skill: node.skill,
        experience: profile.applyXp(node.xp),
      ),
    ]);
  }

  /// Whether an equipped item satisfies the node's tool requirement.
  ///
  /// Equipped, not merely owned: a pickaxe in the bag is not a pickaxe in hand.
  /// Matched on [ItemDefinition.toolKind] and [ItemDefinition.tier] rather than
  /// on a specific item id, so a better axe added later works everywhere an axe
  /// is asked for without editing a single node.
  ///
  /// Every slot is scanned rather than only [EquipmentSlot.tool]. The
  /// requirement is about capability, and a content pack that puts a hatchet in
  /// the weapon slot should not silently stop satisfying it.
  bool _hasTool(ResourceNodeDefinition node, GameState state) {
    for (final ContentId equipped in state.equipment.bySlot.values) {
      final ItemDefinition? item = registry.items[equipped];
      if (item == null) continue;
      if (item.toolKind != node.requiredToolKind) continue;
      if (item.tier >= node.minimumToolTier) return true;
    }
    return false;
  }

  _Decision _equip(EquipItem command, GameState state) {
    final ItemDefinition? item = registry.items[command.item];
    if (item == null) {
      return _Decision.reject(
        RejectionCode.unknownItem,
        command,
        'no item is defined with that ID',
        subject: command.item.value,
      );
    }
    if (!state.inventory.has(command.item)) {
      return _Decision.reject(
        RejectionCode.itemNotOwned,
        command,
        'the player does not have "${item.displayName}"',
        subject: command.item.value,
      );
    }
    final EquipmentSlot? slot = item.slot;
    if (slot == null) {
      return _Decision.reject(
        RejectionCode.invalidEquipmentSlot,
        command,
        '"${item.displayName}" is a ${item.category.name} and occupies no '
        'equipment slot',
        subject: command.item.value,
      );
    }
    if (state.equipment.inSlot(slot) == command.item) {
      // Already worn: accepted, but nothing happened. An empty event list is
      // how "no change was needed" is expressed, and it keeps the operation
      // idempotent without pretending a fact occurred.
      return _Decision.accept(const <GameEvent>[]);
    }

    final List<GameEvent> events = <GameEvent>[];
    int sequence = state.eventSequence;

    // Swapping is two facts, not one. A listener that only understood
    // "equipped" would otherwise never learn the old item came off.
    final ContentId? occupant = state.equipment.inSlot(slot);
    if (occupant != null) {
      events.add(
        ItemUnequipped(sequence: sequence++, item: occupant, slot: slot),
      );
    }
    events.add(
      ItemEquipped(sequence: sequence, item: command.item, slot: slot),
    );
    return _Decision.accept(events);
  }

  _Decision _unequip(UnequipItem command, GameState state) {
    final ContentId? occupant = state.equipment.inSlot(command.slot);
    if (occupant == null) {
      return _Decision.reject(
        RejectionCode.slotEmpty,
        command,
        'nothing is equipped in the ${command.slot.name} slot',
        subject: command.slot.name,
      );
    }
    return _Decision.accept(<GameEvent>[
      ItemUnequipped(
        sequence: state.eventSequence,
        item: occupant,
        slot: command.slot,
      ),
    ]);
  }

  _Decision _unlock(UnlockLocation command, GameState state) {
    if (!registry.locations.containsKey(command.location)) {
      return _Decision.reject(
        RejectionCode.unknownLocation,
        command,
        'no location is defined with that ID',
        subject: command.location.value,
      );
    }
    if (state.world.isUnlocked(command.location)) {
      return _Decision.reject(
        RejectionCode.locationAlreadyUnlocked,
        command,
        'the location is already unlocked',
        subject: command.location.value,
      );
    }
    return _Decision.accept(<GameEvent>[
      LocationUnlocked(
        sequence: state.eventSequence,
        location: command.location,
      ),
    ]);
  }

  _Decision _enter(EnterLocation command, GameState state) {
    if (!registry.locations.containsKey(command.location)) {
      return _Decision.reject(
        RejectionCode.unknownLocation,
        command,
        'no location is defined with that ID',
        subject: command.location.value,
      );
    }
    if (!state.world.isUnlocked(command.location)) {
      return _Decision.reject(
        RejectionCode.locationLocked,
        command,
        'the location has not been unlocked',
        subject: command.location.value,
      );
    }
    if (state.world.currentLocation == command.location) {
      return _Decision.reject(
        RejectionCode.alreadyAtLocation,
        command,
        'the player is already there',
        subject: command.location.value,
      );
    }
    return _Decision.accept(<GameEvent>[
      LocationEntered(
        sequence: state.eventSequence,
        from: state.world.currentLocation,
        location: command.location,
      ),
    ]);
  }
}

/// A validation outcome: events to apply, or a reason not to.
final class _Decision {
  const _Decision.accept(this.events) : rejection = null;

  _Decision.reject(
    RejectionCode code,
    GameCommand command,
    String explanation, {
    String? subject,
  }) : events = const <GameEvent>[],
       rejection = CommandRejection(
         code: code,
         command: command.name,
         explanation: explanation,
         subject: subject,
       );

  const _Decision.rejectWith(CommandRejection this.rejection)
    : events = const <GameEvent>[];

  final List<GameEvent> events;
  final CommandRejection? rejection;
}
