import 'dart:convert';

import 'package:meta/meta.dart';

import 'balance_profile.dart';
import 'content_id.dart';
import 'content_registry.dart';
import 'definitions.dart';
import 'json_reader.dart';
import 'reachability.dart';
import 'schema_version.dart';
import 'validation.dart';

/// The raw content the loader is given.
///
/// Deliberately a map of filename to text, not a directory.
///
/// `stride_core` must not touch the file system (`DECISIONS/0010`), so reading
/// files is the caller's job — `rootBundle` in the app, `dart:io` in tests. The
/// benefit is not only purity: it makes the loader trivially testable with
/// fabricated content, and it means loading cannot depend on file enumeration
/// order, because the loader never enumerates anything.
@immutable
final class ContentSource {
  const ContentSource(this.files);

  /// Filename to file contents.
  final Map<String, String> files;

  /// Filenames in a stable order.
  ///
  /// Sorting here is what makes error ordering and registry construction
  /// independent of however the caller's map happened to be built.
  List<String> get orderedFilenames => files.keys.toList()..sort();
}

/// The result of loading: either a registry, or everything wrong with it.
@immutable
final class ContentLoadResult {
  const ContentLoadResult._({this.registry, required this.report});

  final ContentRegistry? registry;
  final ValidationReport report;

  bool get isValid => registry != null;

  /// The registry, or a thrown [ContentException] carrying the full report.
  ContentRegistry get requireRegistry {
    final ContentRegistry? loaded = registry;
    if (loaded == null) throw ContentException(report);
    return loaded;
  }
}

/// Turns content files into a validated registry, deterministically.
///
/// ## Determinism
///
/// The same files and the same profile always produce the same registry. The
/// loader never enumerates a directory, never iterates an unordered map into
/// output, never consults the clock, the timezone, the locale, or a random
/// source. Filenames are sorted; entries keep their declared order within a
/// file; the registry stores everything in sorted maps.
///
/// ## One pass
///
/// Every practical error is collected before returning. Parsing and
/// cross-reference checking are separate phases so that a reference error can
/// report against the full set of known IDs rather than whatever had been read
/// so far — which is what lets "did you mean…?" suggest the right thing.
final class ContentLoader {
  const ContentLoader();

  /// Items expected in the starting loadout (`DECISIONS/0004`).
  static final List<ContentId> defaultStartingLoadout = <ContentId>[
    ContentId.unchecked('item.training_sword'),
    ContentId.unchecked('item.training_axe'),
    ContentId.unchecked('item.training_pickaxe'),
    ContentId.unchecked('item.traveler_tunic'),
  ];

  /// The tier the reachability test must prove is obtainable.
  static final List<ContentId> defaultReachabilityTargets = <ContentId>[
    ContentId.unchecked('item.bronze_sword'),
    ContentId.unchecked('item.bronze_axe'),
    ContentId.unchecked('item.bronze_pickaxe'),
  ];

  ContentLoadResult load(
    ContentSource source, {
    required ContentId profileId,
    List<ContentId>? startingLoadout,
    List<ContentId>? reachabilityTargets,
  }) {
    final ErrorCollector collector = ErrorCollector();

    final _ParsedContent parsed = _parse(source, collector);
    if (parsed.fatal) {
      return ContentLoadResult._(report: collector.toReport());
    }

    // Checked first, and short-circuits below: a bundle whose profile is
    // missing has one root cause, and stacking a reachability failure on top
    // would bury the thing the author actually needs to fix.
    final BalanceProfile? profile = _selectProfile(
      parsed,
      profileId,
      collector,
    );

    _validateCrossReferences(parsed, collector);
    _validateSkills(parsed, collector);
    _validateWorld(parsed, collector);
    _validateEntryKeySafety(parsed, collector);
    _validateContracts(parsed, collector);
    _validateProjects(parsed, collector);
    _validateProfiles(parsed, collector);

    final List<ContentId> loadout = startingLoadout ?? defaultStartingLoadout;
    _validateLoadout(parsed, loadout, collector);

    if (collector.errors.isNotEmpty || profile == null) {
      return ContentLoadResult._(report: collector.toReport());
    }

    ReleaseSafety.assertSelectable(profile);

    final ContentRegistry registry = ContentRegistry(
      items: parsed.items,
      skills: parsed.skills,
      locations: parsed.locations,
      resourceNodes: parsed.resourceNodes,
      recipes: parsed.recipes,
      enemies: parsed.enemies,
      contracts: parsed.contracts,
      projects: parsed.projects,
      rumors: parsed.rumors,
      profile: profile,
      startingLoadout: List<ContentId>.unmodifiable(loadout),
    );

    // Reachability runs last: it needs a complete, cross-checked registry, and
    // reporting a broken chain on top of unresolved references would be noise.
    final ValidationReport reachability = ReachabilityValidator(
      registry,
    ).validate(targets: reachabilityTargets ?? defaultReachabilityTargets);
    if (reachability.hasErrors) {
      return ContentLoadResult._(report: reachability);
    }

    return ContentLoadResult._(
      registry: registry,
      report: const ValidationReport.empty(),
    );
  }

  // -- Phase 1: parse -------------------------------------------------------

  _ParsedContent _parse(ContentSource source, ErrorCollector collector) {
    final _ParsedContent parsed = _ParsedContent();
    final Map<ContentId, String> firstSeenIn = <ContentId, String>{};

    for (final String filename in source.orderedFilenames) {
      final String text = source.files[filename]!;

      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException catch (error) {
        collector.add(
          sourceFile: filename,
          explanation: 'the file is not valid JSON: ${error.message}',
          suggestion:
              'check for a trailing comma, an unquoted key, or a '
              'missing bracket near offset ${error.offset ?? 0}',
        );
        parsed.fatal = true;
        continue;
      }

      if (decoded is! Map) {
        collector.add(
          sourceFile: filename,
          explanation:
              'the file must contain a JSON object, found '
              '${decoded.runtimeType}',
          suggestion:
              'wrap the contents in `{ "schemaVersion": 1, "kind": …, '
              '"entries": [ … ] }`',
        );
        parsed.fatal = true;
        continue;
      }

      final Map<String, Object?> root = decoded.cast<String, Object?>();

      final SchemaVersionCheck version = SchemaVersionCheck.read(
        root['schemaVersion'],
      );
      if (!version.isValid) {
        collector.add(
          sourceFile: filename,
          field: 'schemaVersion',
          explanation: version.explanation,
          suggestion: version.suggestion,
        );
        // Refuse to read entries against an unknown schema. Guessing is the one
        // thing the versioning rule exists to prevent.
        continue;
      }

      final Object? kindRaw = root['kind'];
      if (kindRaw is! String) {
        collector.add(
          sourceFile: filename,
          field: 'kind',
          explanation: 'the required field "kind" is missing or not text',
          suggestion:
              'add `"kind": "<one of: '
              '${_entryKinds.keys.join(', ')}>"`',
        );
        continue;
      }
      final _EntryKind? kind = _entryKinds[kindRaw];
      if (kind == null) {
        collector.add(
          sourceFile: filename,
          field: 'kind',
          explanation: '"$kindRaw" is not a recognised content kind',
          suggestion: 'use one of: ${_entryKinds.keys.join(', ')}',
        );
        continue;
      }

      final Object? entriesRaw = root['entries'];
      if (entriesRaw is! List) {
        collector.add(
          sourceFile: filename,
          field: 'entries',
          explanation: 'the required field "entries" is missing or not a list',
          suggestion: 'add `"entries": [ … ]`',
        );
        continue;
      }

      for (int index = 0; index < entriesRaw.length; index++) {
        final Object? entry = entriesRaw[index];
        if (entry is! Map) {
          collector.add(
            sourceFile: filename,
            field: 'entries[$index]',
            explanation: 'expected an object, found ${entry.runtimeType}',
            suggestion: 'write each entry as `{ "id": …, … }`',
          );
          continue;
        }

        final Map<String, Object?> entryMap = entry.cast<String, Object?>();
        final Object? rawId = entryMap['id'];
        final JsonReader reader = JsonReader(
          map: entryMap,
          sourceFile: filename,
          collector: collector,
          entryId: rawId is String ? rawId : 'entries[$index]',
        );

        final ContentId? id = kind.read(reader, parsed);
        if (id == null) continue;

        final String? previous = firstSeenIn[id];
        if (previous != null) {
          collector.add(
            sourceFile: filename,
            entryId: id.value,
            field: 'id',
            explanation:
                'duplicate identifier — "$id" is already defined in '
                '$previous',
            suggestion:
                'identifiers must be globally unique. Rename one of '
                'them, or delete the duplicate entry.',
          );
          continue;
        }
        firstSeenIn[id] = filename;
        parsed.sourceOf[id] = filename;
      }
    }

    return parsed;
  }

  BalanceProfile? _selectProfile(
    _ParsedContent parsed,
    ContentId profileId,
    ErrorCollector collector,
  ) {
    final BalanceProfile? profile = parsed.profiles[profileId];
    if (profile == null) {
      collector.add(
        sourceFile: 'balance profile selection',
        entryId: profileId.value,
        explanation:
            'the requested balance profile "$profileId" is not defined',
        suggestion: parsed.profiles.isEmpty
            ? 'add a profile file with kind "profiles"'
            : 'available profiles: '
                  '${(parsed.profiles.keys.map((ContentId i) => i.value).toList()..sort()).join(', ')}',
      );
    }
    return profile;
  }

  // -- Phase 2: cross references -------------------------------------------

  void _validateCrossReferences(
    _ParsedContent parsed,
    ErrorCollector collector,
  ) {
    final Set<ContentId> known = parsed.allIds;

    void checkItem(ContentId owner, String field, ContentId reference) {
      if (parsed.items.containsKey(reference)) return;
      collector.unknownReference(
        sourceFile: parsed.sourceOf[owner] ?? 'unknown',
        entryId: owner.value,
        field: field,
        reference: reference.value,
        expected: ContentNamespace.item,
        known: known,
      );
    }

    for (final ResourceNodeDefinition node in parsed.resourceNodes.values) {
      if (!parsed.skills.containsKey(node.skill)) {
        collector.unknownReference(
          sourceFile: parsed.sourceOf[node.id] ?? 'unknown',
          entryId: node.id.value,
          field: 'skill',
          reference: node.skill.value,
          expected: ContentNamespace.skill,
          known: known,
        );
      }
      checkItem(node.id, 'yieldsItem', node.yieldsItem);
    }

    for (final RecipeDefinition recipe in parsed.recipes.values) {
      if (!parsed.skills.containsKey(recipe.skill)) {
        collector.unknownReference(
          sourceFile: parsed.sourceOf[recipe.id] ?? 'unknown',
          entryId: recipe.id.value,
          field: 'skill',
          reference: recipe.skill.value,
          expected: ContentNamespace.skill,
          known: known,
        );
      }
      checkItem(recipe.id, 'outputItem', recipe.outputItem);

      for (int i = 0; i < recipe.ingredients.length; i++) {
        final RecipeIngredient ingredient = recipe.ingredients[i];
        checkItem(recipe.id, 'ingredients[$i].item', ingredient.item);

        // A recipe consuming its own output can never be started.
        if (ingredient.item == recipe.outputItem) {
          collector.add(
            sourceFile: parsed.sourceOf[recipe.id] ?? 'unknown',
            entryId: recipe.id.value,
            field: 'ingredients[$i].item',
            explanation:
                'the recipe consumes its own output '
                '"${recipe.outputItem}"',
            suggestion:
                'a recipe cannot require what it produces — remove the '
                'ingredient, or change the output',
          );
        }
      }
    }

    for (final LocationDefinition location in parsed.locations.values) {
      for (int i = 0; i < location.connections.length; i++) {
        final LocationConnection connection = location.connections[i];
        if (!parsed.locations.containsKey(connection.to)) {
          collector.unknownReference(
            sourceFile: parsed.sourceOf[location.id] ?? 'unknown',
            entryId: location.id.value,
            field: 'connections[$i].to',
            reference: connection.to.value,
            expected: ContentNamespace.location,
            known: known,
          );
        }
        if (connection.to == location.id) {
          collector.add(
            sourceFile: parsed.sourceOf[location.id] ?? 'unknown',
            entryId: location.id.value,
            field: 'connections[$i].to',
            explanation: 'the location connects to itself',
            suggestion:
                'remove the self-connection — travel to where you '
                'already are is not a journey',
          );
        }
      }
      for (int i = 0; i < location.entryRequirements.length; i++) {
        checkItem(
          location.id,
          'entryRequirements[$i]',
          location.entryRequirements[i],
        );
      }
      for (int i = 0; i < location.resourceNodes.length; i++) {
        final ContentId nodeId = location.resourceNodes[i];
        if (parsed.resourceNodes.containsKey(nodeId)) continue;
        collector.unknownReference(
          sourceFile: parsed.sourceOf[location.id] ?? 'unknown',
          entryId: location.id.value,
          field: 'resourceNodes[$i]',
          reference: nodeId.value,
          expected: ContentNamespace.resourceNode,
          known: known,
        );
      }
    }

    for (final EnemyDefinition enemy in parsed.enemies.values) {
      if (!parsed.locations.containsKey(enemy.location)) {
        collector.unknownReference(
          sourceFile: parsed.sourceOf[enemy.id] ?? 'unknown',
          entryId: enemy.id.value,
          field: 'location',
          reference: enemy.location.value,
          expected: ContentNamespace.location,
          known: known,
        );
      }
      for (int i = 0; i < enemy.drops.length; i++) {
        checkItem(enemy.id, 'drops[$i].item', enemy.drops[i].item);
      }
    }

    void checkRef(
      ContentId owner,
      String field,
      ContentId? reference,
      ContentNamespace expected,
      bool Function(ContentId) exists,
    ) {
      if (reference == null || exists(reference)) return;
      collector.unknownReference(
        sourceFile: parsed.sourceOf[owner] ?? 'unknown',
        entryId: owner.value,
        field: field,
        reference: reference.value,
        expected: expected,
        known: known,
      );
    }

    for (final RecipeDefinition recipe in parsed.recipes.values) {
      checkRef(
        recipe.id,
        'unlockedByProject',
        recipe.unlockedByProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
      checkRef(
        recipe.id,
        'retiredByProject',
        recipe.retiredByProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
      checkRef(
        recipe.id,
        'unlockedByContract',
        recipe.unlockedByContract,
        ContentNamespace.contract,
        parsed.contracts.containsKey,
      );
    }

    for (final ResourceNodeDefinition node in parsed.resourceNodes.values) {
      checkRef(
        node.id,
        'unlockedByProject',
        node.unlockedByProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
    }

    for (final LocationDefinition location in parsed.locations.values) {
      checkRef(
        location.id,
        'safeAfterProject',
        location.safeAfterProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
    }

    for (final ContractDefinition contract in parsed.contracts.values) {
      checkRef(
        contract.id,
        'location',
        contract.location,
        ContentNamespace.location,
        parsed.locations.containsKey,
      );
      for (int i = 0; i < contract.requires.length; i++) {
        checkItem(
          contract.id,
          'requires[$i].item',
          contract.requires[i].item,
        );
      }
      for (int i = 0; i < contract.requiresOwned.length; i++) {
        checkItem(contract.id, 'requiresOwned[$i]', contract.requiresOwned[i]);
      }
      checkRef(
        contract.id,
        'bountyEnemy',
        contract.bountyEnemy,
        ContentNamespace.enemy,
        parsed.enemies.containsKey,
      );
      checkRef(
        contract.id,
        'requiresContract',
        contract.requiresContract,
        ContentNamespace.contract,
        parsed.contracts.containsKey,
      );
      checkRef(
        contract.id,
        'requiresCompletedNeedAt',
        contract.requiresCompletedNeedAt,
        ContentNamespace.location,
        parsed.locations.containsKey,
      );
      checkRef(
        contract.id,
        'requiresProject',
        contract.requiresProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
      for (int i = 0; i < contract.rewardItems.length; i++) {
        checkItem(
          contract.id,
          'rewardItems[$i].item',
          contract.rewardItems[i].item,
        );
      }
      for (int i = 0; i < contract.rewardSkillXp.length; i++) {
        if (parsed.skills.containsKey(contract.rewardSkillXp[i].skill)) {
          continue;
        }
        collector.unknownReference(
          sourceFile: parsed.sourceOf[contract.id] ?? 'unknown',
          entryId: contract.id.value,
          field: 'rewardSkillXp[$i].skill',
          reference: contract.rewardSkillXp[i].skill.value,
          expected: ContentNamespace.skill,
          known: known,
        );
      }
      for (int i = 0; i < contract.revealRumors.length; i++) {
        checkRef(
          contract.id,
          'revealRumors[$i]',
          contract.revealRumors[i],
          ContentNamespace.rumor,
          parsed.rumors.containsKey,
        );
      }
    }

    // Veteran Hunts gate (`DECISIONS/0028`): the referenced base enemy must
    // exist, and no enemy may require itself — an enemy that must be Known
    // before it can be fought could then never be fought at all.
    for (final EnemyDefinition enemy in parsed.enemies.values) {
      final ContentId? mustKnow = enemy.requiresKnownEnemy;
      if (mustKnow == null) continue;
      if (mustKnow == enemy.id) {
        collector.add(
          sourceFile: parsed.sourceOf[enemy.id] ?? 'unknown',
          entryId: enemy.id.value,
          field: 'requiresKnownEnemy',
          explanation:
              'the enemy requires itself to be Known, which can never happen',
          suggestion: 'reference the base species the veteran is a variant of',
        );
        continue;
      }
      checkRef(
        enemy.id,
        'requiresKnownEnemy',
        mustKnow,
        ContentNamespace.enemy,
        parsed.enemies.containsKey,
      );
    }

    for (final ProjectDefinition project in parsed.projects.values) {
      checkRef(
        project.id,
        'location',
        project.location,
        ContentNamespace.location,
        parsed.locations.containsKey,
      );
      checkRef(
        project.id,
        'requiresProject',
        project.requiresProject,
        ContentNamespace.project,
        parsed.projects.containsKey,
      );
      for (int s = 0; s < project.stages.length; s++) {
        final ProjectStage stage = project.stages[s];
        for (int i = 0; i < stage.requires.length; i++) {
          checkItem(
            project.id,
            'stages[$s].requires[$i].item',
            stage.requires[i].item,
          );
        }
      }
      for (int i = 0; i < project.revealRumors.length; i++) {
        checkRef(
          project.id,
          'revealRumors[$i]',
          project.revealRumors[i],
          ContentNamespace.rumor,
          parsed.rumors.containsKey,
        );
      }
    }
  }

  /// Contract-class shape rules the type system cannot express.
  void _validateContracts(_ParsedContent parsed, ErrorCollector collector) {
    for (final ContractDefinition contract in parsed.contracts.values) {
      final String file = parsed.sourceOf[contract.id] ?? 'unknown';

      if (contract.contractClass == ContractClass.localNeed &&
          contract.deckOrder < 1) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'deckOrder',
          explanation:
              'a local need lives in its location\'s rotation deck and must '
              'declare a deckOrder',
          suggestion: 'add `"deckOrder": 1` (unique per location)',
        );
      }
      if (contract.contractClass != ContractClass.localNeed &&
          contract.deckOrder != 0) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'deckOrder',
          explanation:
              'only local needs rotate through a deck; this contract is '
              '${contract.contractClass.name}',
          suggestion: 'remove deckOrder',
        );
      }
      if (contract.contractClass == ContractClass.bounty &&
          (contract.bountyEnemy == null || contract.bountyCount < 1)) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'bountyEnemy',
          explanation: 'a bounty contract must name an enemy and a count',
          suggestion:
              'add `"bountyEnemy": "enemy.forest_wolf", "bountyCount": 3`',
        );
      }
      if (contract.contractClass == ContractClass.localNeed &&
          contract.bountyEnemy != null) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'bountyEnemy',
          explanation:
              'a rotating local need cannot carry a bounty — bounties must '
              'stay acceptable while the player hunts, and a deck slot '
              'rotates away',
          suggestion: 'use `"class": "bounty"` for combat orders',
        );
      }
      if (contract.bountyEnemy != null && contract.bountyCount < 1) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'bountyCount',
          explanation: 'a bounty enemy without a count can never be met',
          suggestion: 'add `"bountyCount": 1` or more',
        );
      }
      if (contract.requires.isEmpty &&
          contract.requiresOwned.isEmpty &&
          contract.bountyEnemy == null) {
        collector.add(
          sourceFile: file,
          entryId: contract.id.value,
          field: 'requires',
          explanation:
              'the contract asks for nothing — completing it would be a '
              'free reward button',
          suggestion: 'add item requirements or a bounty',
        );
      }
      final ContentId? prerequisite = contract.requiresContract;
      if (prerequisite != null) {
        final ContractDefinition? other = parsed.contracts[prerequisite];
        if (other != null && other.isRepeatable) {
          collector.add(
            sourceFile: file,
            entryId: contract.id.value,
            field: 'requiresContract',
            explanation:
                '"${prerequisite.value}" is repeatable; a prerequisite must '
                'be a one-time regional contract so "completed" is a fact, '
                'not a count',
            suggestion: 'reference a regional contract',
          );
        }
      }
    }

    // Deck order must be unique within a location, or rotation is ambiguous.
    final Map<ContentId, Map<int, ContentId>> decks =
        <ContentId, Map<int, ContentId>>{};
    for (final ContractDefinition contract in parsed.contracts.values) {
      if (contract.contractClass != ContractClass.localNeed) continue;
      final Map<int, ContentId> deck = decks.putIfAbsent(
        contract.location,
        () => <int, ContentId>{},
      );
      final ContentId? existing = deck[contract.deckOrder];
      if (existing != null) {
        collector.add(
          sourceFile: parsed.sourceOf[contract.id] ?? 'unknown',
          entryId: contract.id.value,
          field: 'deckOrder',
          explanation:
              'deckOrder ${contract.deckOrder} at ${contract.location.value} '
              'is already taken by ${existing.value}',
          suggestion: 'give each local need at a location a distinct order',
        );
      } else {
        deck[contract.deckOrder] = contract.id;
      }
    }
  }

  void _validateProjects(_ParsedContent parsed, ErrorCollector collector) {
    for (final ProjectDefinition project in parsed.projects.values) {
      final String file = parsed.sourceOf[project.id] ?? 'unknown';
      if (project.stages.isEmpty) {
        collector.add(
          sourceFile: file,
          entryId: project.id.value,
          field: 'stages',
          explanation: 'a project with no stages can never begin',
          suggestion: 'author at least one stage with requirements',
        );
      }

      // `requiresProject` chains must bottom out at an ungated project
      // (`DECISIONS/0028`): a self-reference or cycle would make every
      // project in the loop permanently unopenable. Dangling referents are
      // already refused by the cross-reference pass, so this walk stops
      // quietly at an unknown id rather than double-reporting.
      final ContentId? gate = project.requiresProject;
      if (gate != null) {
        final List<ContentId> path = <ContentId>[project.id];
        final Set<ContentId> visited = <ContentId>{project.id};
        ContentId? cursor = gate;
        while (cursor != null) {
          if (visited.contains(cursor)) {
            collector.add(
              sourceFile: file,
              entryId: project.id.value,
              field: 'requiresProject',
              explanation: cursor == project.id
                  ? 'the project requires itself'
                        '${path.length > 1 ? ' through ${path.skip(1).map((ContentId id) => id.value).join(' -> ')}' : ''}, '
                        'so it could never open'
                  : 'the requirement chain loops at "${cursor.value}" '
                        '(${path.map((ContentId id) => id.value).join(' -> ')} -> ${cursor.value})',
              suggestion:
                  'a project chain must bottom out at an ungated project',
            );
            break;
          }
          visited.add(cursor);
          path.add(cursor);
          cursor = parsed.projects[cursor]?.requiresProject;
        }
      }
    }
  }

  /// `RULES` L-1 (`DECISIONS/0028` §4): an item that opens a location may
  /// never be consumed. `entryRequirements` are checked against live
  /// inventory on every travel, so a recipe, contract delivery, or project
  /// stage that eats an entry key could lock the player out of somewhere
  /// they have already been. `requiresOwned` is deliberately exempt —
  /// show-don't-consume is the safe pattern.
  void _validateEntryKeySafety(
    _ParsedContent parsed,
    ErrorCollector collector,
  ) {
    final Set<ContentId> entryKeys = <ContentId>{
      for (final LocationDefinition location in parsed.locations.values)
        ...location.entryRequirements,
    };
    if (entryKeys.isEmpty) return;

    void refuse(ContentId owner, String field, ContentId item) {
      collector.add(
        sourceFile: parsed.sourceOf[owner] ?? 'unknown',
        entryId: owner.value,
        field: field,
        explanation:
            '"${item.value}" opens a location; consuming it could lock the '
            'player out of somewhere they have been',
        suggestion:
            'entry keys are shown, never spent - use requiresOwned on a '
            'contract, or a different material',
      );
    }

    for (final RecipeDefinition recipe in parsed.recipes.values) {
      for (int i = 0; i < recipe.ingredients.length; i++) {
        if (entryKeys.contains(recipe.ingredients[i].item)) {
          refuse(recipe.id, 'ingredients[$i].item', recipe.ingredients[i].item);
        }
      }
    }
    for (final ContractDefinition contract in parsed.contracts.values) {
      for (int i = 0; i < contract.requires.length; i++) {
        if (entryKeys.contains(contract.requires[i].item)) {
          refuse(contract.id, 'requires[$i].item', contract.requires[i].item);
        }
      }
    }
    for (final ProjectDefinition project in parsed.projects.values) {
      for (int s = 0; s < project.stages.length; s++) {
        final ProjectStage stage = project.stages[s];
        for (int i = 0; i < stage.requires.length; i++) {
          if (entryKeys.contains(stage.requires[i].item)) {
            refuse(
              project.id,
              'stages[$s].requires[$i].item',
              stage.requires[i].item,
            );
          }
        }
      }
    }
  }

  void _validateSkills(_ParsedContent parsed, ErrorCollector collector) {
    for (final SkillDefinition skill in parsed.skills.values) {
      final String file = parsed.sourceOf[skill.id] ?? 'unknown';

      if (skill.xpThresholds.length != skill.maxLevel) {
        collector.add(
          sourceFile: file,
          entryId: skill.id.value,
          field: 'xpThresholds',
          explanation:
              'expected ${skill.maxLevel} thresholds to match maxLevel, '
              'found ${skill.xpThresholds.length}',
          suggestion:
              'provide one cumulative XP value per level, from 1 to '
              '${skill.maxLevel}',
        );
        continue;
      }
      if (skill.xpThresholds.isEmpty) continue;

      if (skill.xpThresholds.first != 0) {
        collector.add(
          sourceFile: file,
          entryId: skill.id.value,
          field: 'xpThresholds[0]',
          explanation:
              'level 1 must require 0 XP, found '
              '${skill.xpThresholds.first}',
          suggestion:
              'set the first threshold to 0 — the player starts at '
              'level 1',
        );
      }
      for (int i = 1; i < skill.xpThresholds.length; i++) {
        if (skill.xpThresholds[i] > skill.xpThresholds[i - 1]) continue;
        collector.add(
          sourceFile: file,
          entryId: skill.id.value,
          field: 'xpThresholds[$i]',
          explanation:
              'thresholds must strictly increase: level ${i + 1} '
              'requires ${skill.xpThresholds[i]}, which is not more than '
              'level $i\'s ${skill.xpThresholds[i - 1]}',
          suggestion:
              'raise it above ${skill.xpThresholds[i - 1]} — a gap or '
              'a plateau would make a level unreachable or instant',
        );
      }
    }
  }

  void _validateWorld(_ParsedContent parsed, ErrorCollector collector) {
    final List<LocationDefinition> starts = parsed.locations.values
        .where((LocationDefinition l) => l.isStart)
        .toList();

    if (starts.isEmpty && parsed.locations.isNotEmpty) {
      collector.add(
        sourceFile: 'world',
        explanation: 'no location is marked as the start',
        suggestion:
            'set `"isStart": true` on exactly one location — normally '
            'location.havens_rest',
      );
    } else if (starts.length > 1) {
      final List<String> names =
          (starts.map((LocationDefinition l) => l.id.value).toList()..sort());
      collector.add(
        sourceFile: 'world',
        explanation:
            'more than one location is marked as the start: '
            '${names.join(', ')}',
        suggestion: 'exactly one location may set isStart',
      );
    }

    // Every gatherable should have a consumer. An item nothing uses is either a
    // dead end for the player or a recipe someone forgot to write. Contracts
    // and project stages are consumers too — a herb the notice board buys has
    // a purpose whether or not a recipe wants it.
    final Set<ContentId> consumed = <ContentId>{
      for (final RecipeDefinition r in parsed.recipes.values)
        ...r.ingredients.map((RecipeIngredient i) => i.item),
      for (final ContractDefinition c in parsed.contracts.values)
        ...c.requires.map((ItemQuantity q) => q.item),
      for (final ProjectDefinition p in parsed.projects.values)
        for (final ProjectStage s in p.stages)
          ...s.requires.map((ItemQuantity q) => q.item),
    };
    for (final ResourceNodeDefinition node in parsed.resourceNodes.values) {
      final ItemDefinition? item = parsed.items[node.yieldsItem];
      if (item == null) continue;
      if (item.category != ItemCategory.material) continue;
      if (consumed.contains(node.yieldsItem)) continue;
      collector.add(
        sourceFile: parsed.sourceOf[node.id] ?? 'unknown',
        entryId: node.id.value,
        field: 'yieldsItem',
        explanation:
            '"${node.yieldsItem}" is gathered but no recipe consumes it',
        suggestion:
            'add a recipe that uses it, or remove the node — a material '
            'with no purpose is busywork',
      );
    }
  }

  void _validateProfiles(_ParsedContent parsed, ErrorCollector collector) {
    for (final BalanceProfile profile in parsed.profiles.values) {
      final String file = parsed.sourceOf[profile.id] ?? 'unknown';
      final bool isProduction = profile.id == BalanceProfile.productionId;

      if (isProduction && !profile.releaseSafe) {
        collector.add(
          sourceFile: file,
          entryId: profile.id.value,
          field: 'releaseSafe',
          explanation: 'the production profile must be marked releaseSafe',
          suggestion:
              'set `"releaseSafe": true` — without it, release builds '
              'have no loadable profile at all',
        );
      }
      if (!isProduction && profile.releaseSafe) {
        collector.add(
          sourceFile: file,
          entryId: profile.id.value,
          field: 'releaseSafe',
          explanation: 'only the production profile may be releaseSafe',
          suggestion:
              'set `"releaseSafe": false` — a QA profile that can ship '
              'is the exact accident the safeguard exists to prevent',
        );
      }
      if (isProduction &&
          (profile.stepCostPercent != 100 ||
              profile.xpPercent != 100 ||
              profile.yieldPercent != 100 ||
              profile.enemyHealthPercent != 100)) {
        collector.add(
          sourceFile: file,
          entryId: profile.id.value,
          explanation:
              'the production profile must leave base content '
              'unscaled — all percentages must be 100',
          suggestion:
              'set every percentage to 100 and tune the base content '
              'files instead. Production is the reference point; a scaled '
              'production profile means the real numbers live in two places.',
        );
      }
    }

    if (!parsed.profiles.containsKey(BalanceProfile.productionId)) {
      collector.add(
        sourceFile: 'balance profiles',
        explanation: 'no production profile is defined',
        suggestion:
            'define "${BalanceProfile.productionId}" with all '
            'percentages at 100 and releaseSafe true',
      );
    }
  }

  void _validateLoadout(
    _ParsedContent parsed,
    List<ContentId> loadout,
    ErrorCollector collector,
  ) {
    for (final ContentId id in loadout) {
      if (parsed.items.containsKey(id)) continue;
      collector.unknownReference(
        sourceFile: 'starting loadout',
        entryId: id.value,
        field: 'startingLoadout',
        reference: id.value,
        expected: ContentNamespace.item,
        known: parsed.allIds,
      );
    }

    // Production content may not depend on QA-only items.
    for (final ItemDefinition item in parsed.items.values) {
      if (!item.qaOnly) continue;
      final List<String> referencedBy = <String>[
        for (final RecipeDefinition r in parsed.recipes.values)
          if (r.outputItem == item.id ||
              r.ingredients.any((RecipeIngredient i) => i.item == item.id))
            r.id.value,
        for (final ResourceNodeDefinition n in parsed.resourceNodes.values)
          if (n.yieldsItem == item.id) n.id.value,
        for (final LocationDefinition l in parsed.locations.values)
          if (l.entryRequirements.contains(item.id)) l.id.value,
      ]..sort();

      if (referencedBy.isEmpty) continue;
      collector.add(
        sourceFile: parsed.sourceOf[item.id] ?? 'unknown',
        entryId: item.id.value,
        field: 'qaOnly',
        explanation:
            'production content references the QA-only item '
            '"${item.id}" (from ${referencedBy.join(', ')})',
        suggestion:
            'remove the reference, or drop the qaOnly flag. QA-only '
            'content must never be reachable in a production bundle.',
      );
    }
  }
}

/// Content parsed but not yet cross-checked.
final class _ParsedContent {
  final Map<ContentId, ItemDefinition> items = <ContentId, ItemDefinition>{};
  final Map<ContentId, SkillDefinition> skills = <ContentId, SkillDefinition>{};
  final Map<ContentId, LocationDefinition> locations =
      <ContentId, LocationDefinition>{};
  final Map<ContentId, ResourceNodeDefinition> resourceNodes =
      <ContentId, ResourceNodeDefinition>{};
  final Map<ContentId, RecipeDefinition> recipes =
      <ContentId, RecipeDefinition>{};
  final Map<ContentId, EnemyDefinition> enemies =
      <ContentId, EnemyDefinition>{};
  final Map<ContentId, ContractDefinition> contracts =
      <ContentId, ContractDefinition>{};
  final Map<ContentId, ProjectDefinition> projects =
      <ContentId, ProjectDefinition>{};
  final Map<ContentId, RumorDefinition> rumors = <ContentId, RumorDefinition>{};
  final Map<ContentId, BalanceProfile> profiles = <ContentId, BalanceProfile>{};

  /// Which file each ID came from, for error reporting.
  final Map<ContentId, String> sourceOf = <ContentId, String>{};

  /// True when the content could not be read at all.
  bool fatal = false;

  Set<ContentId> get allIds => <ContentId>{
    ...items.keys,
    ...skills.keys,
    ...locations.keys,
    ...resourceNodes.keys,
    ...recipes.keys,
    ...enemies.keys,
    ...contracts.keys,
    ...projects.keys,
    ...rumors.keys,
    ...profiles.keys,
  };
}

/// How each `kind` of file is read.
final class _EntryKind {
  const _EntryKind(this.read);

  final ContentId? Function(JsonReader reader, _ParsedContent into) read;
}

final Map<String, _EntryKind> _entryKinds = <String, _EntryKind>{
  'items': _EntryKind((JsonReader r, _ParsedContent into) {
    final ItemDefinition? definition = ItemDefinition.read(r);
    if (definition == null) return null;
    return (into.items[definition.id] = definition).id;
  }),
  'skills': _EntryKind((JsonReader r, _ParsedContent into) {
    final SkillDefinition? definition = SkillDefinition.read(r);
    if (definition == null) return null;
    return (into.skills[definition.id] = definition).id;
  }),
  'locations': _EntryKind((JsonReader r, _ParsedContent into) {
    final LocationDefinition? definition = LocationDefinition.read(r);
    if (definition == null) return null;
    return (into.locations[definition.id] = definition).id;
  }),
  'resource_nodes': _EntryKind((JsonReader r, _ParsedContent into) {
    final ResourceNodeDefinition? definition = ResourceNodeDefinition.read(r);
    if (definition == null) return null;
    return (into.resourceNodes[definition.id] = definition).id;
  }),
  'recipes': _EntryKind((JsonReader r, _ParsedContent into) {
    final RecipeDefinition? definition = RecipeDefinition.read(r);
    if (definition == null) return null;
    return (into.recipes[definition.id] = definition).id;
  }),
  'enemies': _EntryKind((JsonReader r, _ParsedContent into) {
    final EnemyDefinition? definition = EnemyDefinition.read(r);
    if (definition == null) return null;
    return (into.enemies[definition.id] = definition).id;
  }),
  'contracts': _EntryKind((JsonReader r, _ParsedContent into) {
    final ContractDefinition? definition = ContractDefinition.read(r);
    if (definition == null) return null;
    return (into.contracts[definition.id] = definition).id;
  }),
  'projects': _EntryKind((JsonReader r, _ParsedContent into) {
    final ProjectDefinition? definition = ProjectDefinition.read(r);
    if (definition == null) return null;
    return (into.projects[definition.id] = definition).id;
  }),
  'rumors': _EntryKind((JsonReader r, _ParsedContent into) {
    final RumorDefinition? definition = RumorDefinition.read(r);
    if (definition == null) return null;
    return (into.rumors[definition.id] = definition).id;
  }),
  'profiles': _EntryKind((JsonReader r, _ParsedContent into) {
    final BalanceProfile? definition = BalanceProfile.read(r);
    if (definition == null) return null;
    return (into.profiles[definition.id] = definition).id;
  }),
};
