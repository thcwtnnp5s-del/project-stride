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
    // The loadout is granted to the bag, unworn — the shape every engine
    // fixture and the frozen conformance transcript are built on. A fresh
    // *playtest* wears it (`PlaytestReset.equippedItems`); changing a brand
    // new game's first transcript is a separate, deliberate edit.
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
        StartActivityQueue() => _startActivityQueue(command, state),
        ReconcileActivityQueue() => _reconcileActivityQueue(command, state),
        StopActivityQueue() => _stopActivityQueue(command, state),
        ReconcileStepSync() => _reconcile(command, state),
        EstablishEconomyEpoch() => _establishEpoch(command, state),
        EstablishNewGameBaseline() => _establishBaseline(command, state),
        ResetPlaytest() => _resetPlaytest(command, state),
        StartEncounter() => _startEncounter(command, state),
        CombatAttack() => _combatAttack(command, state),
        CombatEat() => _combatEat(command, state),
        CombatBrace() => _combatBrace(command, state),
        CombatRetreat() => _combatRetreat(command, state),
        EatFood() => _eatFood(command, state),
        TrackGoal() => _trackGoal(command, state),
        AcceptContract() => _acceptContract(command, state),
        CompleteContract() => _completeContract(command, state),
        ContributeToProject() => _contributeToProject(command, state),
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
  /// Does this enemy exist → is it here → am I already fighting → has this
  /// visit's authored encounter count been spent. Costs no steps
  /// (`DECISIONS/0020` §3, `DECISIONS/0021` §1). The player's figures
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
    // Spent for this visit: the authored `encountersPerVisit` has been met
    // (`DECISIONS/0021` §1). The wire code is unchanged — from the player's
    // side the enemy is still driven off and still returns when they move on;
    // only how many wins it took to get there is now content.
    if (!state.world.isAvailable(command.enemy, enemy.encountersPerVisit)) {
      return _Decision.reject(
        RejectionCode.enemyDrivenOff,
        command,
        '"${enemy.displayName}" has been driven off here '
        '(${enemy.encountersPerVisit} '
        '${enemy.encountersPerVisit == 1 ? 'encounter' : 'encounters'} a '
        'visit); it returns once the player moves on',
        subject: command.enemy.value,
      );
    }

    final PlayerCombatLoadout loadout = CombatRules.loadoutFor(state, registry);
    final int enemyHp = profile.applyEnemyHealth(enemy.health);
    // Persistent HP (`DECISIONS/0023` §4): the fight begins at the player's
    // carried HP, clamped to the loadout's maximum in case a level change
    // moved the ceiling under a stored value.
    final int startingHp = state.player.hp > loadout.maxHp
        ? loadout.maxHp
        : state.player.hp;
    return _Decision.accept(<GameEvent>[
      EncounterStarted(
        sequence: state.eventSequence,
        enemy: command.enemy,
        location: state.world.currentLocation,
        seed: CombatRules.seedFor(state.eventSequence, command.enemy),
        playerHp: startingHp,
        playerMaxHp: loadout.maxHp,
        playerAttack: loadout.attack,
        playerDefence: loadout.defence,
        enemyHp: enemyHp,
        enemyMaxHp: enemyHp,
        playerFrostGuard: loadout.frostGuard,
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

    final int roll = CombatRules.roll(
      encounter.seed,
      turn,
      CombatRules.playerStrikeSalt,
    );
    final int damage = CombatRules.strike(
      encounter.playerAttack,
      enemy.defence,
      roll,
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
        roll: roll,
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

  /// One round: the player braces — deals nothing — and the enemy's reply
  /// lands at half damage (`DECISIONS/0027`, experimental; Q-06's candidate).
  ///
  /// No encounter → enemy loaded. Bracing is never refused for being
  /// pointless: reading the telegraph is the player's job, and a wasted
  /// brace against a light round is the cost of misreading it.
  _Decision _combatBrace(CombatBrace command, GameState state) {
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
      return _Decision.reject(
        RejectionCode.contentNotLoaded,
        command,
        'the enemy in the active encounter is not loaded',
        subject: encounter.enemy.value,
      );
    }

    final List<GameEvent> events = <GameEvent>[
      CombatBraced(sequence: state.eventSequence, turn: encounter.turn),
    ];
    _enemyReply(
      events,
      state.eventSequence + 1,
      state,
      encounter,
      enemy,
      encounter.playerHp,
      braced: true,
    );
    return _Decision.accept(events);
  }

  /// Leaves the fight. Nothing is lost; the safe destination restores HP.
  _Decision _combatRetreat(CombatRetreat command, GameState state) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) {
      return _Decision.reject(
        RejectionCode.noEncounter,
        command,
        'no encounter is active',
      );
    }
    final ContentId retreatTo = CombatRules.retreatDestination(state, registry);
    return _Decision.accept(<GameEvent>[
      EncounterRetreated(
        sequence: state.eventSequence,
        enemy: encounter.enemy,
        location: encounter.location,
        retreatTo: retreatTo,
        restoredHp: _restoredHpAt(retreatTo, state),
      ),
    ]);
  }

  /// The HP an arrival at [destination] restores, or null when it is not a
  /// safe place for this state (`DECISIONS/0023` §4). Full, instant, free.
  int? _restoredHpAt(ContentId destination, GameState state) {
    final LocationDefinition? location = registry.locations[destination];
    if (location == null || !CombatRules.isSafeNow(location, state)) {
      return null;
    }
    return CombatRules.maxHpFor(state.player.level);
  }

  /// The one `EncounterWon`, with every figure of the reward on it.
  ///
  /// XP is profile-scaled here, once; the level after is recomputed from the
  /// total here, once, and written on the event so the reducer never consults
  /// the curve. Drops roll from the seed with the drop index and the victory
  /// turn — one independent draw per drop — and are recorded as literal
  /// amounts, unscaled: drops are not gather yields.
  ///
  /// Since state v7 the event also carries: the player's HP as the fight
  /// ended (persistent HP, `DECISIONS/0023` §4); the lifetime victory count
  /// after this one, with the one-time Known award when this victory crosses
  /// the enemy's `knownAt` threshold (§5); and the accepted bounty contracts
  /// this victory advanced (§2 — only qualifying victories after acceptance
  /// count, and the counting is recorded here so replay reproduces it).
  EncounterWon _victory(
    int sequence,
    GameState state,
    EncounterState encounter,
    EnemyDefinition enemy,
  ) {
    final int victoriesAfter = state.progress.victoriesOf(encounter.enemy) + 1;
    final int knowledgeXp = victoriesAfter == enemy.knownAt
        ? profile.applyXp(enemy.knownXp)
        : 0;
    final int xp = profile.applyXp(enemy.xp) + knowledgeXp;
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

    // Accepted, uncompleted bounty contracts naming this enemy advance by
    // one, capped at their required count — a count past the requirement
    // would be a figure with no meaning.
    final Map<ContentId, int> bountyProgress = <ContentId, int>{};
    for (final ContentId contractId in state.progress.acceptedContracts) {
      final ContractDefinition? contract = registry.contracts[contractId];
      if (contract == null) continue;
      if (contract.bountyEnemy != encounter.enemy) continue;
      final int current = state.progress.bountyProgress[contractId] ?? 0;
      if (current >= contract.bountyCount) continue;
      bountyProgress[contractId] = current + 1;
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
      playerHpAfter: encounter.playerHp,
      victoriesAfter: victoriesAfter,
      knowledgeXp: knowledgeXp,
      bountyProgress: bountyProgress,
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
    int playerHp, {
    bool braced = false,
  }) {
    final int turn = encounter.turn;
    final bool heavy =
        enemy.behavior == EnemyBehavior.guarded &&
        CombatRules.isHeavyTurn(turn);
    final int strikes = enemy.behavior == EnemyBehavior.flurry ? 2 : 1;

    // Cold Weather (`DECISIONS/0023` §4): frost-guard armour reduces every
    // incoming strike in an alpine-terrain fight, floored at 1 — the strike
    // still lands. A narrow tagged modifier, applied here and nowhere else.
    final bool alpineFight =
        registry.locations[encounter.location]?.terrain == Terrain.alpine;
    final int frostGuard = alpineFight ? encounter.playerFrostGuard : 0;

    int hp = playerHp;
    for (int i = 0; i < strikes; i++) {
      final int roll = heavy
          ? 0
          : CombatRules.roll(
              encounter.seed,
              turn,
              CombatRules.enemyStrikeSalt + i,
            );
      int damage = heavy
          ? CombatRules.heavyStrike(enemy.attack, encounter.playerDefence)
          : CombatRules.strike(enemy.attack, encounter.playerDefence, roll);
      // Braced (`DECISIONS/0027`): every strike of the reply is halved,
      // floored at 1, before frost guard — the stance and the coat stack,
      // because both were choices.
      if (braced) {
        damage = damage ~/ 2 < 1 ? 1 : damage ~/ 2;
      }
      if (frostGuard > 0) {
        damage = damage - frostGuard < 1 ? 1 : damage - frostGuard;
      }
      hp = hp - damage < 0 ? 0 : hp - damage;
      events.add(
        CombatEnemyStruck(
          sequence: sequence++,
          damage: damage,
          playerHpAfter: hp,
          turn: turn,
          heavy: heavy,
          strikeIndex: i,
          roll: roll,
        ),
      );
      if (hp == 0) {
        final ContentId retreatTo = CombatRules.retreatDestination(
          state,
          registry,
        );
        events.add(
          EncounterLost(
            sequence: sequence,
            enemy: encounter.enemy,
            location: encounter.location,
            retreatTo: retreatTo,
            restoredHp: _restoredHpAt(retreatTo, state),
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

  /// Begins a fresh playtest. See [ResetPlaytest] and `DECISIONS/0025`.
  ///
  /// Pure over the ledger it is handed: the new mark is what the counters
  /// read now. No guard against running twice — a second reset is a second
  /// deliberate act — but a fight or a queue in flight is refused unless the
  /// reset is a fresh start, which discards them.
  _Decision _resetPlaytest(ResetPlaytest command, GameState state) {
    if (!command.freshStart) {
      if (state.encounter != null) {
        return _Decision.reject(
          RejectionCode.encounterInProgress,
          command,
          'finish or retreat from the fight before resetting the baseline',
        );
      }
      if (state.activityQueue != null) {
        return _Decision.reject(
          RejectionCode.activityQueueActive,
          command,
          'stop the running activity before resetting the baseline',
        );
      }
    }
    final EconomyEpoch epoch = state.steps.epoch;
    return _Decision.accept(<GameEvent>[
      PlaytestReset(
        sequence: state.eventSequence,
        grantedAtStart: state.steps.totalGranted,
        spentAtStart: state.steps.totalSpent,
        previousGrantedAtStart: epoch.grantedAtStart,
        previousSpentAtStart: epoch.spentAtStart,
        previousWalkedAtStart: epoch.walkedAtStart,
        stateVersion: command.stateVersion,
        freshStart: command.freshStart,
        startLocation: registry.startLocation.id,
        grantedItems: command.freshStart
            ? registry.startingLoadout
            : const <ContentId>[],
        equippedItems: command.freshStart
            ? registry.startingEquipment
            : const <EquipmentSlot, ContentId>{},
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
        // Safe arrivals heal fully, instantly, freely (`DECISIONS/0023` §4).
        restoredHp: _restoredHpAt(command.destination, state),
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

    // Project/contract gating (`DECISIONS/0023` §3): a recipe not yet
    // unlocked, or retired by a completed project, is refused before any
    // other question — the player's real answer is progression, not
    // materials.
    final String? lockReason = recipeLockReason(recipe, state);
    if (lockReason != null) {
      return _Decision.reject(
        RejectionCode.recipeLocked,
        command,
        lockReason,
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
    final _GatherResolution resolved = _resolveGather(
      command,
      command.node,
      state,
    );
    final CommandRejection? rejection = resolved.rejection;
    if (rejection != null) return _Decision.rejectWith(rejection);
    final _GatherFigures figures = resolved.figures!;

    return _Decision.accept(<GameEvent>[
      ResourceGathered(
        sequence: state.eventSequence,
        node: command.node,
        stepsSpent: figures.stepsSpent,
        item: figures.item,
        quantity: figures.quantity,
        skill: figures.skill,
        experience: figures.experience,
      ),
    ]);
  }

  /// **The one validation of working a node once**, shared by [GatherResource]
  /// and every activity-queue completion, so the two cannot diverge
  /// (`DECISIONS/0022` §6). Returns the freshly profile-scaled figures, or the
  /// refusal.
  ///
  /// [checkCost] false skips only the banked-steps check — the one question
  /// [StartActivityQueue] does not ask, because starting spends nothing and
  /// every completion re-asks it against the balance of its own moment.
  _GatherResolution _resolveGather(
    GameCommand command,
    ContentId nodeId,
    GameState state, {
    bool checkCost = true,
    int completionIndex = 0,
  }) {
    final ResourceNodeDefinition? node = registry.resourceNodes[nodeId];
    if (node == null) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.unknownResourceNode,
          command: command.name,
          explanation: 'no resource node is defined with that ID',
          subject: nodeId.value,
        ),
      );
    }

    // Same placement as in [_travel]: after existence, before everything else.
    final CommandRejection? fighting = _refuseDuringEncounter(command, state);
    if (fighting != null) return _GatherResolution.refused(fighting);

    final LocationDefinition? here =
        registry.locations[state.world.currentLocation];
    if (here == null || !here.resourceNodes.contains(nodeId)) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.resourceNodeNotHere,
          command: command.name,
          explanation:
              '"${node.displayName}" is not at '
              '${here?.displayName ?? state.world.currentLocation.value}',
          subject: nodeId.value,
        ),
      );
    }

    // Project gating (`DECISIONS/0023` §3): the Lift's hardened seam does
    // not exist as a workable thing until the Lift is complete.
    final ContentId? gate = node.unlockedByProject;
    if (gate != null && !state.progress.isProjectComplete(gate)) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.nodeLocked,
          command: command.name,
          explanation:
              '"${node.displayName}" is behind '
              '"${registry.projects[gate]?.displayName ?? gate.value}", '
              'which has not been completed',
          subject: nodeId.value,
        ),
      );
    }

    final SkillDefinition? skill = registry.skills[node.skill];
    if (skill == null) {
      // Unreachable through a validated registry -- the content loader's
      // reference check rejects a node naming a skill that does not exist.
      // Answered rather than thrown anyway: an engine that crashes on a content
      // defect takes the game down over a file someone edited.
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.contentNotLoaded,
          command: command.name,
          explanation:
              'the skill "${node.skill.value}" this node trains is not loaded',
          subject: node.skill.value,
        ),
      );
    }

    final int level = skill.levelAt(state.skills.experienceIn(node.skill));
    if (level < node.requiredLevel) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.skillLevelTooLow,
          command: command.name,
          explanation:
              '"${node.displayName}" needs ${skill.displayName} '
              '${node.requiredLevel}; the player is level $level',
          subject: nodeId.value,
        ),
      );
    }

    if (node.requiredToolKind != ToolKind.none && !_hasTool(node, state)) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.toolRequired,
          command: command.name,
          explanation:
              '"${node.displayName}" needs a ${node.requiredToolKind.name} of '
              'tier ${node.minimumToolTier} or better equipped',
          subject: nodeId.value,
        ),
      );
    }

    final int cost = profile.applyStepCost(node.stepCost);
    if (checkCost && cost > state.steps.banked) {
      return _GatherResolution.refused(
        CommandRejection(
          code: RejectionCode.insufficientSteps,
          command: command.name,
          explanation:
              '"${node.displayName}" costs $cost steps but only '
              '${state.steps.banked} are banked',
          subject: nodeId.value,
        ),
      );
    }

    return _GatherResolution.resolved(
      _GatherFigures(
        stepsSpent: cost,
        item: node.yieldsItem,
        quantity:
            profile.applyYield(node.yieldsQuantity) +
            _bonusYield(node, level, state, completionIndex),
        skill: node.skill,
        experience: profile.applyXp(node.xp),
      ),
    );
  }

  /// The deterministic bonus yield of one gather (`DECISIONS/0023` §9):
  /// the node's own skill bonus, equipped wilderness gear on Woodcutting/
  /// Foraging nodes, and an equipped bonus tool on nodes its kind serves —
  /// each an independent roll from the event sequence, the completion index
  /// and its own salt, so replay reproduces it and two completions of one
  /// reconciliation roll differently.
  int _bonusYield(
    ResourceNodeDefinition node,
    int skillLevel,
    GameState state,
    int completionIndex,
  ) {
    final int seed = CombatRules.gatherSeed(state.eventSequence, node.id);
    int bonus = 0;

    if (node.bonusYieldPercent > 0 &&
        node.bonusYieldLevel > 0 &&
        skillLevel >= node.bonusYieldLevel) {
      if (CombatRules.percentRoll(
            seed,
            completionIndex,
            CombatRules.nodeBonusSalt,
          ) <
          node.bonusYieldPercent) {
        bonus += 1;
      }
    }

    // Wilderness gear (the Wolfhide Jerkin): qualifying nodes are the
    // wilderness professions — Woodcutting and Foraging, per the owner brief
    // (§46) — never Mining. The best equipped figure rolls once.
    final bool wildernessNode =
        node.skill.slug == 'woodcutting' || node.skill.slug == 'foraging';
    if (wildernessNode) {
      int best = 0;
      for (final ContentId equipped in state.equipment.bySlot.values) {
        final ItemDefinition? item = registry.items[equipped];
        if (item == null) continue;
        if (item.wildernessYieldPercent > best) {
          best = item.wildernessYieldPercent;
        }
      }
      if (best > 0 &&
          CombatRules.percentRoll(
                seed,
                completionIndex,
                CombatRules.wildernessBonusSalt,
              ) <
              best) {
        bonus += 1;
      }
    }

    // A bonus tool (the Reinforced Pickaxe): counts only on nodes that ask
    // for its kind, and only when the equipped tool actually satisfies the
    // node — the same equipped-not-owned rule as [_hasTool].
    if (node.requiredToolKind != ToolKind.none) {
      int best = 0;
      for (final ContentId equipped in state.equipment.bySlot.values) {
        final ItemDefinition? item = registry.items[equipped];
        if (item == null) continue;
        if (item.toolKind != node.requiredToolKind) continue;
        if (item.tier < node.minimumToolTier) continue;
        if (item.toolBonusYieldPercent > best) {
          best = item.toolBonusYieldPercent;
        }
      }
      if (best > 0 &&
          CombatRules.percentRoll(
                seed,
                completionIndex,
                CombatRules.toolBonusSalt,
              ) <
              best) {
        bonus += 1;
      }
    }

    return bonus;
  }

  /// Why [recipe] is not currently craftable, or null when it is
  /// (`DECISIONS/0023` §3). Public so projections disable and explain with
  /// the engine's own words rather than re-deriving the rule.
  String? recipeLockReason(RecipeDefinition recipe, GameState state) {
    final ContentId? projectGate = recipe.unlockedByProject;
    if (projectGate != null && !state.progress.isProjectComplete(projectGate)) {
      return '"${recipe.displayName}" is unlocked by completing '
          '"${registry.projects[projectGate]?.displayName ?? projectGate.value}"';
    }
    final ContentId? retiredBy = recipe.retiredByProject;
    if (retiredBy != null && state.progress.isProjectComplete(retiredBy)) {
      return '"${recipe.displayName}" was retired by '
          '"${registry.projects[retiredBy]?.displayName ?? retiredBy.value}" '
          '— an improved method replaced it';
    }
    final ContentId? contractGate = recipe.unlockedByContract;
    if (contractGate != null &&
        state.progress.completionsOf(contractGate) == 0) {
      return '"${recipe.displayName}" is taught by completing '
          '"${registry.contracts[contractGate]?.displayName ?? contractGate.value}"';
    }
    return null;
  }

  // -- The activity queue (`DECISIONS/0022`) ---------------------------------

  /// Begins a finite queue. Spends nothing; every completion pays at its own
  /// reconciliation through [_resolveGather].
  ///
  /// The refusal order is the player's question order, exactly as [_gather]'s
  /// is — with the queue-already-active check taking the place cost holds
  /// there, because cost is not asked at start.
  _Decision _startActivityQueue(StartActivityQueue command, GameState state) {
    if (command.requested < 1) {
      return _Decision.reject(
        RejectionCode.invalidAmount,
        command,
        'a queue of ${command.requested} repetitions is not a queue; '
        'at least one is required',
        subject: command.node.value,
      );
    }
    if (command.durationMillis < 1) {
      return _Decision.reject(
        RejectionCode.invalidAmount,
        command,
        'a repetition duration of ${command.durationMillis} ms is not a '
        'duration',
        subject: command.node.value,
      );
    }
    if (state.activityQueue != null) {
      return _Decision.reject(
        RejectionCode.activityQueueActive,
        command,
        'an activity queue is already running at '
        '${state.activityQueue!.node.value}; stop it or let it finish first',
        subject: command.node.value,
      );
    }

    // The same existence / encounter / location / skill / tool validation a
    // gather gets — without the cost check, because nothing is pre-spent.
    final _GatherResolution resolved = _resolveGather(
      command,
      command.node,
      state,
      checkCost: false,
    );
    final CommandRejection? rejection = resolved.rejection;
    if (rejection != null) return _Decision.rejectWith(rejection);

    return _Decision.accept(<GameEvent>[
      ActivityQueueStarted(
        sequence: state.eventSequence,
        node: command.node,
        requested: command.requested,
        durationMillis: command.durationMillis,
        anchorEpochMillis: command.nowEpochMillis,
      ),
    ]);
  }

  /// Resolves every repetition the elapsed time completed
  /// (`DECISIONS/0022` §6).
  ///
  /// Accepted with **no events** — and therefore no commit — when there is no
  /// queue, no whole repetition has elapsed, or the clock ran backwards
  /// (elapsed clamps at zero and the anchor never moves on a clock reading
  /// alone). That is what makes a reconcile safe to dispatch at any moment,
  /// and a second reconcile after a commit a no-op.
  _Decision _reconcileActivityQueue(
    ReconcileActivityQueue command,
    GameState state,
  ) {
    final ActivityQueueState? queue = state.activityQueue;
    if (queue == null) return const _Decision.accept(<GameEvent>[]);

    final _ElapsedCompletions run = _elapsedCompletions(
      command,
      queue,
      state,
      command.nowEpochMillis,
    );
    if (run.completions.isEmpty && run.stopReason == null) {
      // Nothing elapsed, or the clock went backwards: nothing changed, so
      // nothing is committed and the anchor stays exactly where it was.
      return const _Decision.accept(<GameEvent>[]);
    }

    final int completedAfter = queue.completed + run.completions.length;
    final bool cleared =
        run.stopReason != null || completedAfter >= queue.requested;
    return _Decision.accept(<GameEvent>[
      ActivityQueueReconciled(
        sequence: state.eventSequence,
        node: queue.node,
        completions: run.completions,
        completedAfter: completedAfter,
        anchorAfter:
            queue.anchorEpochMillis +
            run.completions.length * queue.durationMillis,
        cleared: cleared,
        stopReason: run.stopReason,
      ),
    ]);
  }

  /// Stops the queue: the closing reconciliation commits, the partial
  /// repetition does not, and the queue clears regardless
  /// (`DECISIONS/0022` §7). With no queue, accepted with no events, so the
  /// app's exclusive-command seam may issue it unconditionally.
  _Decision _stopActivityQueue(StopActivityQueue command, GameState state) {
    final ActivityQueueState? queue = state.activityQueue;
    if (queue == null) return const _Decision.accept(<GameEvent>[]);

    final _ElapsedCompletions run = _elapsedCompletions(
      command,
      queue,
      state,
      command.nowEpochMillis,
    );
    return _Decision.accept(<GameEvent>[
      ActivityQueueStopped(
        sequence: state.eventSequence,
        node: queue.node,
        completions: run.completions,
        completedAfter: queue.completed + run.completions.length,
        stopReason: run.stopReason,
      ),
    ]);
  }

  /// The closing arithmetic both queue commands share: how many whole
  /// repetitions elapsed, and which of them can legally complete.
  ///
  /// `k = floor(max(0, now − anchor) / duration)`, clamped to the repetitions
  /// the queue still owes. Each of the k candidates is validated by
  /// [_resolveGather] against the state **as the previous completions left
  /// it** — advanced through the reducer's own [applyGatherEffects], so the
  /// walk and the eventual commit apply identical arithmetic. The first
  /// refusal stops the walk with its wire code; every prior completion is
  /// kept (`DECISIONS/0022` §6).
  _ElapsedCompletions _elapsedCompletions(
    GameCommand command,
    ActivityQueueState queue,
    GameState state,
    int nowEpochMillis,
  ) {
    final int elapsed = nowEpochMillis - queue.anchorEpochMillis;
    final int wholeRepetitions = elapsed <= 0
        ? 0
        : elapsed ~/ queue.durationMillis;
    final int owed = queue.requested - queue.completed;
    final int k = wholeRepetitions > owed ? owed : wholeRepetitions;

    final List<ActivityCompletion> completions = <ActivityCompletion>[];
    String? stopReason;
    GameState working = state;
    for (int j = 0; j < k; j++) {
      final _GatherResolution resolved = _resolveGather(
        command,
        queue.node,
        working,
        completionIndex: j,
      );
      final CommandRejection? rejection = resolved.rejection;
      if (rejection != null) {
        stopReason = rejection.code.wire;
        break;
      }
      final _GatherFigures figures = resolved.figures!;
      completions.add(
        ActivityCompletion(
          stepsSpent: figures.stepsSpent,
          item: figures.item,
          quantity: figures.quantity,
          skill: figures.skill,
          experience: figures.experience,
        ),
      );
      working = applyGatherEffects(
        working,
        stepsSpent: figures.stepsSpent,
        item: figures.item,
        quantity: figures.quantity,
        skill: figures.skill,
        experience: figures.experience,
      );
    }
    return (completions: completions, stopReason: stopReason);
  }

  // -- Exploration & Progression Loop 01 (`DECISIONS/0023`) -------------------

  /// Eats outside combat (`DECISIONS/0023` §4).
  ///
  /// Item exists → not fighting → owned → edible → HP missing. The in-fight
  /// path is [CombatEat] and spends the turn; this one spends only the food.
  _Decision _eatFood(EatFood command, GameState state) {
    final ItemDefinition? item = registry.items[command.item];
    if (item == null) {
      return _Decision.reject(
        RejectionCode.unknownItem,
        command,
        'no item is defined with that ID',
        subject: command.item.value,
      );
    }
    final CommandRejection? fighting = _refuseDuringEncounter(command, state);
    if (fighting != null) return _Decision.rejectWith(fighting);
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
    final int maxHp = CombatRules.maxHpFor(state.player.level);
    final int missing = maxHp - state.player.hp;
    if (missing <= 0) {
      return _Decision.reject(
        RejectionCode.healthFull,
        command,
        'the player is already at full health',
        subject: command.item.value,
      );
    }
    final int healed = item.healing < missing ? item.healing : missing;
    return _Decision.accept(<GameEvent>[
      FoodEaten(
        sequence: state.eventSequence,
        item: command.item,
        healed: healed,
        hpAfter: state.player.hp + healed,
      ),
    ]);
  }

  /// Sets or clears a tracked-objective slot (`DECISIONS/0023` §1). The
  /// target must fit the slot and exist in content; clearing always works.
  /// No economy figure moves either way.
  _Decision _trackGoal(TrackGoal command, GameState state) {
    final ContentId? target = command.target;
    if (target != null) {
      final bool fits = switch (command.slot) {
        GoalSlot.journey => registry.locations.containsKey(target),
        GoalSlot.pursuit => registry.items.containsKey(target),
        GoalSlot.contract =>
          registry.contracts.containsKey(target) ||
              registry.projects.containsKey(target),
      };
      if (!fits) {
        return _Decision.reject(
          RejectionCode.invalidGoal,
          command,
          'a ${command.slot.name} slot cannot track "${target.value}"',
          subject: target.value,
        );
      }
    }
    if (state.progress.tracked.inSlot(command.slot) == target) {
      // Tracking what is already tracked: accepted, nothing happened.
      return const _Decision.accept(<GameEvent>[]);
    }
    return _Decision.accept(<GameEvent>[
      GoalTracked(
        sequence: state.eventSequence,
        slot: command.slot,
        target: target,
      ),
    ]);
  }

  /// The availability questions every contract action shares
  /// (`DECISIONS/0023` §2): exists → offered at this board right now.
  /// Returns the refusal, or null when the contract is available where the
  /// player stands.
  CommandRejection? _contractUnavailable(
    GameCommand command,
    ContractDefinition contract,
    GameState state,
  ) {
    if (contract.location != state.world.currentLocation) {
      return CommandRejection(
        code: RejectionCode.contractNotHere,
        command: command.name,
        explanation:
            '"${contract.displayName}" is posted at '
            '${registry.locations[contract.location]?.displayName ?? contract.location.value}',
        subject: contract.id.value,
      );
    }
    if (!contract.isRepeatable &&
        state.progress.completionsOf(contract.id) > 0) {
      return CommandRejection(
        code: RejectionCode.contractNotAvailable,
        command: command.name,
        explanation: '"${contract.displayName}" has already been completed',
        subject: contract.id.value,
      );
    }
    if (contract.contractClass == ContractClass.localNeed &&
        !localNeedSlots(state, contract.location).contains(contract.id)) {
      return CommandRejection(
        code: RejectionCode.contractNotAvailable,
        command: command.name,
        explanation:
            '"${contract.displayName}" is not on the board right now; '
            'complete a posted order and it will rotate back around',
        subject: contract.id.value,
      );
    }
    final ContentId? prerequisite = contract.requiresContract;
    if (prerequisite != null &&
        state.progress.completionsOf(prerequisite) == 0) {
      return CommandRejection(
        code: RejectionCode.contractNotAvailable,
        command: command.name,
        explanation:
            '"${contract.displayName}" is offered after '
            '"${registry.contracts[prerequisite]?.displayName ?? prerequisite.value}"',
        subject: contract.id.value,
      );
    }
    final ContentId? needsNeedAt = contract.requiresCompletedNeedAt;
    if (needsNeedAt != null && !_hasCompletedNeedAt(state, needsNeedAt)) {
      return CommandRejection(
        code: RejectionCode.contractNotAvailable,
        command: command.name,
        explanation:
            '"${contract.displayName}" is offered after helping at '
            '${registry.locations[needsNeedAt]?.displayName ?? needsNeedAt.value}',
        subject: contract.id.value,
      );
    }
    final ContentId? projectGate = contract.requiresProject;
    if (projectGate != null && !state.progress.isProjectComplete(projectGate)) {
      return CommandRejection(
        code: RejectionCode.contractNotAvailable,
        command: command.name,
        explanation:
            '"${contract.displayName}" is offered once '
            '"${registry.projects[projectGate]?.displayName ?? projectGate.value}" '
            'is complete',
        subject: contract.id.value,
      );
    }
    return null;
  }

  /// Why [contract] is not currently offered where the player stands, in the
  /// engine's own words, or null when it is available. Public so board
  /// projections disable and explain without re-deriving the rule
  /// (`RULES.md` E-2); [CompleteContract] and [AcceptContract] still
  /// re-check on execute.
  String? contractUnavailableReason(
    ContractDefinition contract,
    GameState state,
  ) => _contractUnavailable(
    CompleteContract(contract: contract.id),
    contract,
    state,
  )?.explanation;

  /// Whether any local need at [location] has ever been completed.
  bool _hasCompletedNeedAt(GameState state, ContentId location) {
    for (final MapEntry<ContentId, int> e
        in state.progress.contractCompletions.entries) {
      if (e.value <= 0) continue;
      final ContractDefinition? contract = registry.contracts[e.key];
      if (contract == null) continue;
      if (contract.location != location) continue;
      if (contract.contractClass == ContractClass.localNeed ||
          contract.contractClass == ContractClass.bounty) {
        return true;
      }
    }
    return false;
  }

  /// The local needs currently visible on [location]'s board: the recorded
  /// slots once a rotation has happened, else the first window of the
  /// authored deck. Public so projections read the same window the engine
  /// validates against.
  List<ContentId> localNeedSlots(GameState state, ContentId location) {
    final List<ContentId>? recorded = state.progress.localSlots[location];
    if (recorded != null) return recorded;
    final List<ContentId> deck = registry.localNeedDeck(location);
    final int window = _boardWindow(location, deck.length);
    return deck.sublist(0, window);
  }

  /// How many local needs a board shows at once: the location's authored
  /// `boardSlots`, clamped to the deck.
  int _boardWindow(ContentId location, int deckLength) {
    final int authored = registry.locations[location]?.boardSlots ?? 3;
    return authored < deckLength ? authored : deckLength;
  }

  /// Accepts a bounty (`DECISIONS/0023` §2): victories count from here.
  _Decision _acceptContract(AcceptContract command, GameState state) {
    final ContractDefinition? contract = registry.contracts[command.contract];
    if (contract == null) {
      return _Decision.reject(
        RejectionCode.unknownContract,
        command,
        'no contract is defined with that ID',
        subject: command.contract.value,
      );
    }
    if (contract.bountyEnemy == null) {
      return _Decision.reject(
        RejectionCode.contractNotAcceptable,
        command,
        '"${contract.displayName}" is a delivery order — hand the goods over '
        'when you have them; nothing needs accepting',
        subject: command.contract.value,
      );
    }
    final CommandRejection? unavailable = _contractUnavailable(
      command,
      contract,
      state,
    );
    if (unavailable != null) return _Decision.rejectWith(unavailable);
    if (state.progress.acceptedContracts.contains(command.contract)) {
      return _Decision.reject(
        RejectionCode.contractAlreadyAccepted,
        command,
        '"${contract.displayName}" is already accepted; victories are '
        'already counting',
        subject: command.contract.value,
      );
    }
    return _Decision.accept(<GameEvent>[
      ContractAccepted(
        sequence: state.eventSequence,
        contract: command.contract,
      ),
    ]);
  }

  /// Completes a contract (`DECISIONS/0023` §2): one event, exactly once,
  /// zero mutation on any shortfall.
  ///
  /// Exists → offered here now → bounty met → held-but-kept items present →
  /// consumed items present. Cost-last ordering for the player's questions,
  /// exactly as [_gather] orders its own.
  _Decision _completeContract(CompleteContract command, GameState state) {
    final ContractDefinition? contract = registry.contracts[command.contract];
    if (contract == null) {
      return _Decision.reject(
        RejectionCode.unknownContract,
        command,
        'no contract is defined with that ID',
        subject: command.contract.value,
      );
    }
    final CommandRejection? unavailable = _contractUnavailable(
      command,
      contract,
      state,
    );
    if (unavailable != null) return _Decision.rejectWith(unavailable);

    final ContentId? bountyEnemy = contract.bountyEnemy;
    if (bountyEnemy != null) {
      if (!state.progress.acceptedContracts.contains(command.contract)) {
        return _Decision.reject(
          RejectionCode.bountyUnmet,
          command,
          '"${contract.displayName}" has not been accepted; only victories '
          'after acceptance count',
          subject: command.contract.value,
        );
      }
      final int counted = state.progress.bountyProgress[command.contract] ?? 0;
      if (counted < contract.bountyCount) {
        return _Decision.reject(
          RejectionCode.bountyUnmet,
          command,
          '"${contract.displayName}" needs ${contract.bountyCount} '
          '${registry.enemies[bountyEnemy]?.displayName ?? bountyEnemy.value} '
          'victories; $counted counted since acceptance',
          subject: command.contract.value,
        );
      }
    }

    final List<String> notOwned = <String>[
      for (final ContentId item in contract.requiresOwned)
        if (!state.inventory.has(item))
          registry.items[item]?.displayName ?? item.value,
    ];
    if (notOwned.isNotEmpty) {
      return _Decision.reject(
        RejectionCode.requirementNotOwned,
        command,
        '"${contract.displayName}" asks to see ${notOwned.join(', ')}',
        subject: command.contract.value,
      );
    }

    // Folded first, exactly as [_craft] folds, and for the same reason.
    final Map<ContentId, int> required = <ContentId, int>{};
    for (final ItemQuantity need in contract.requires) {
      required[need.item] = (required[need.item] ?? 0) + need.quantity;
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
        '"${contract.displayName}" cannot be completed: '
        '${shortfalls.join(', ')}',
        subject: command.contract.value,
      );
    }

    // Rewards, profile-scaled once, here.
    final Map<ContentId, int> rewardItems = <ContentId, int>{};
    for (final ItemQuantity given in contract.rewardItems) {
      rewardItems[given.item] =
          (rewardItems[given.item] ?? 0) + profile.applyYield(given.quantity);
    }
    final Map<ContentId, int> rewardSkillXp = <ContentId, int>{};
    for (final SkillXpAward award in contract.rewardSkillXp) {
      rewardSkillXp[award.skill] =
          (rewardSkillXp[award.skill] ?? 0) + profile.applyXp(award.xp);
    }
    final int characterXp = profile.applyXp(contract.rewardCharacterXp);
    final int experienceAfter = state.player.experience + characterXp;

    // Rotation, for a local need: the completed order leaves the board and
    // the next authored order not already showing takes its slot. Rotation
    // is caused by completion, never by time.
    List<ContentId>? rotatedSlots;
    int? rotatedNext;
    if (contract.contractClass == ContractClass.localNeed) {
      final List<ContentId> deck = registry.localNeedDeck(contract.location);
      final List<ContentId> slots = List<ContentId>.of(
        localNeedSlots(state, contract.location),
      );
      final int window = _boardWindow(contract.location, deck.length);
      // The first undealt deck index — `window` on a virgin board, wrapped
      // when the whole deck is already showing.
      int next =
          state.progress.localNext[contract.location] ?? (window % deck.length);
      final Set<ContentId> staying = slots.toSet()..remove(contract.id);
      ContentId? replacement;
      for (int i = 0; i < deck.length; i++) {
        final ContentId candidate = deck[(next + i) % deck.length];
        if (staying.contains(candidate)) continue;
        replacement = candidate;
        next = (next + i + 1) % deck.length;
        break;
      }
      final int completedAt = slots.indexOf(contract.id);
      if (replacement != null && completedAt >= 0) {
        slots[completedAt] = replacement;
      }
      rotatedSlots = slots;
      rotatedNext = next;
    }

    // Rumors not yet revealed. An already-known rumor is not re-announced.
    final List<ContentId> revealed = <ContentId>[
      for (final ContentId rumor in contract.revealRumors)
        if (!state.progress.revealedRumors.contains(rumor)) rumor,
    ];

    return _Decision.accept(<GameEvent>[
      ContractCompleted(
        sequence: state.eventSequence,
        contract: command.contract,
        location: contract.location,
        consumed: required,
        rewardItems: rewardItems,
        rewardSkillXp: rewardSkillXp,
        characterXp: characterXp,
        experienceAfter: experienceAfter,
        levelBefore: state.player.level,
        levelAfter: CombatRules.levelFor(experienceAfter),
        completionsAfter: state.progress.completionsOf(command.contract) + 1,
        revealedRumors: revealed,
        rotatedSlots: rotatedSlots,
        rotatedNext: rotatedNext,
      ),
    ]);
  }

  /// Contributes to a community project (`DECISIONS/0023` §3): explicit
  /// amounts, validated against holdings and the stage's remaining need,
  /// removed permanently, one atomic event. Stage and project completion
  /// ride the same event when the contribution fills the stage.
  _Decision _contributeToProject(ContributeToProject command, GameState state) {
    final ProjectDefinition? project = registry.projects[command.project];
    if (project == null) {
      return _Decision.reject(
        RejectionCode.unknownProject,
        command,
        'no community project is defined with that ID',
        subject: command.project.value,
      );
    }
    if (project.location != state.world.currentLocation) {
      return _Decision.reject(
        RejectionCode.projectNotHere,
        command,
        '"${project.displayName}" is at '
        '${registry.locations[project.location]?.displayName ?? project.location.value}; '
        'contributions are made in person',
        subject: command.project.value,
      );
    }
    if (state.progress.isProjectComplete(command.project)) {
      return _Decision.reject(
        RejectionCode.projectComplete,
        command,
        '"${project.displayName}" is already complete',
        subject: command.project.value,
      );
    }
    if (command.contributions.isEmpty) {
      return _Decision.reject(
        RejectionCode.invalidContribution,
        command,
        'nothing was offered',
        subject: command.project.value,
      );
    }

    final ProjectProgressState progress =
        state.progress.projects[command.project] ??
        ProjectProgressState(stage: 0);
    final ProjectStage stage = project.stages[progress.stage];

    // The stage's remaining need per item. Requirements are folded first, so
    // an item listed twice is one total rather than two checks against the
    // same receipt.
    final Map<ContentId, int> requiredTotal = <ContentId, int>{};
    for (final ItemQuantity need in stage.requires) {
      requiredTotal[need.item] =
          (requiredTotal[need.item] ?? 0) + need.quantity;
    }
    final Map<ContentId, int> remaining = <ContentId, int>{
      for (final MapEntry<ContentId, int> need in requiredTotal.entries)
        need.key: (need.value - progress.contributedOf(need.key)) < 0
            ? 0
            : need.value - progress.contributedOf(need.key),
    };

    // Every offered line must be positive, needed, and held — or nothing
    // moves.
    for (final MapEntry<ContentId, int> offer
        in command.contributions.entries) {
      final String name =
          registry.items[offer.key]?.displayName ?? offer.key.value;
      if (offer.value <= 0) {
        return _Decision.reject(
          RejectionCode.invalidContribution,
          command,
          'an offer of ${offer.value} $name is not a contribution',
          subject: command.project.value,
        );
      }
      final int needed = remaining[offer.key] ?? 0;
      if (needed == 0) {
        return _Decision.reject(
          RejectionCode.invalidContribution,
          command,
          '"${stage.name}" does not need $name'
          '${stage.requires.any((ItemQuantity q) => q.item == offer.key) ? ' any more' : ''}',
          subject: command.project.value,
        );
      }
      if (offer.value > needed) {
        return _Decision.reject(
          RejectionCode.invalidContribution,
          command,
          '"${stage.name}" needs only $needed more $name',
          subject: command.project.value,
        );
      }
      if (!state.inventory.has(offer.key, offer.value)) {
        return _Decision.reject(
          RejectionCode.invalidContribution,
          command,
          'the player holds ${state.inventory.quantityOf(offer.key)} $name, '
          'not ${offer.value}',
          subject: command.project.value,
        );
      }
    }

    // The stage's receipt after this contribution, and whether it fills.
    final Map<ContentId, int> after = <ContentId, int>{...progress.contributed};
    for (final MapEntry<ContentId, int> offer
        in command.contributions.entries) {
      after[offer.key] = (after[offer.key] ?? 0) + offer.value;
    }
    bool stageCompleted = true;
    for (final MapEntry<ContentId, int> need in requiredTotal.entries) {
      if ((after[need.key] ?? 0) < need.value) {
        stageCompleted = false;
        break;
      }
    }
    final bool projectCompleted =
        stageCompleted && progress.stage == project.stages.length - 1;

    int characterXp = 0;
    if (stageCompleted) characterXp += profile.applyXp(stage.characterXp);
    if (projectCompleted) {
      characterXp += profile.applyXp(project.completionCharacterXp);
    }
    final int experienceAfter = state.player.experience + characterXp;

    final List<ContentId> revealed = <ContentId>[
      if (projectCompleted)
        for (final ContentId rumor in project.revealRumors)
          if (!state.progress.revealedRumors.contains(rumor)) rumor,
    ];

    return _Decision.accept(<GameEvent>[
      ProjectContributed(
        sequence: state.eventSequence,
        project: command.project,
        stage: progress.stage,
        contributed: command.contributions,
        stageContributedAfter: after,
        stageCompleted: stageCompleted,
        projectCompleted: projectCompleted,
        characterXp: characterXp,
        experienceAfter: experienceAfter,
        levelBefore: state.player.level,
        levelAfter: CombatRules.levelFor(experienceAfter),
        revealedRumors: revealed,
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

/// The engine's walk of one reconciliation: the completions that can legally
/// commit, and the wire code of the refusal that stopped the walk, if one did.
typedef _ElapsedCompletions = ({
  List<ActivityCompletion> completions,
  String? stopReason,
});

/// One gather's freshly profile-scaled figures, as [GameEngine._resolveGather]
/// produced them — the same five figures `ResourceGathered` and
/// [ActivityCompletion] carry.
final class _GatherFigures {
  const _GatherFigures({
    required this.stepsSpent,
    required this.item,
    required this.quantity,
    required this.skill,
    required this.experience,
  });

  final int stepsSpent;
  final ContentId item;
  final int quantity;
  final ContentId skill;
  final int experience;
}

/// Either the figures of a legal gather, or the refusal.
final class _GatherResolution {
  const _GatherResolution.resolved(_GatherFigures this.figures)
    : rejection = null;

  const _GatherResolution.refused(CommandRejection this.rejection)
    : figures = null;

  final _GatherFigures? figures;
  final CommandRejection? rejection;
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
