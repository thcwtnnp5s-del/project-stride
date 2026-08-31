// F-07 — skill level derivation, owned by the domain.
//
// A level is one number and would not need a type. What a progression screen
// shows is a *position between two thresholds* — 340 into level 4, 220 to go —
// and computing that means indexing the curve, handling its top, and knowing
// that index 0 is level 1.
//
// That is rule math. Done in a widget it becomes a second implementation of the
// curve sitting beside the one the engine gates on, free to disagree the first
// time a content pack retunes a skill (`RULES.md` E-2). These tests exist to
// make the domain's version the only one worth having.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId foraging = ContentId.unchecked('skill.foraging');
final ContentId woodcutting = ContentId.unchecked('skill.woodcutting');

SkillDefinition skill(ContentId id) => stepRegistry.skills[id]!;

void main() {
  // Foraging: [0, 100, 250, 470, 770, 1160, 1650, 2250, 2970, 3820, …]
  // Quoted from `skills.json` rather than read from it, so a retune that
  // changes the curve fails here loudly instead of silently re-deriving.
  group('1 — level derivation', () {
    test('a fresh skill is level 1 with nothing earned', () {
      final SkillStanding s = skill(foraging).standingAt(0);

      expect(s.level, 1);
      expect(s.totalExperience, 0);
      expect(s.experienceIntoLevel, 0);
      expect(s.experienceForLevel, 100);
      expect(s.experienceToNextLevel, 100);
      expect(s.isMaxLevel, isFalse);
      expect(s.progress, 0);
    });

    test('one XP short of a threshold is still the level below', () {
      expect(skill(foraging).standingAt(99).level, 1);
      expect(skill(foraging).standingAt(100).level, 2);
      expect(skill(foraging).standingAt(249).level, 2);
      expect(skill(foraging).standingAt(250).level, 3);
    });

    test('it agrees with levelAt, which is what the engine gates on', () {
      // Two derivations of one fact is the defect this whole type exists to
      // prevent, so the two that do exist are checked against each other across
      // the entire curve rather than at a sample point.
      final SkillDefinition definition = skill(foraging);
      for (int xp = 0; xp <= 25000; xp += 37) {
        expect(
          definition.standingAt(xp).level,
          definition.levelAt(xp),
          reason: 'standingAt and levelAt disagree at $xp XP',
        );
      }
    });
  });

  group('2 — position within a level', () {
    test('XP into the level is measured from the level’s own floor', () {
      // Level 4 starts at 470 and level 5 at 770, so the span is 300.
      final SkillStanding s = skill(foraging).standingAt(600);

      expect(s.level, 4);
      expect(s.experienceIntoLevel, 130, reason: '600 − 470');
      expect(s.experienceForLevel, 300, reason: '770 − 470');
      expect(s.experienceToNextLevel, 170, reason: '300 − 130');
      expect(s.progress, closeTo(130 / 300, 1e-9));
    });

    test('a fresh level-up sits at zero into the level, not at full', () {
      final SkillStanding s = skill(foraging).standingAt(470);

      expect(s.level, 4);
      expect(s.experienceIntoLevel, 0);
      expect(s.progress, 0);
    });

    test('into-level plus to-next always equals the span', () {
      final SkillDefinition definition = skill(woodcutting);
      for (int xp = 0; xp <= 31919; xp += 53) {
        final SkillStanding s = definition.standingAt(xp);
        if (s.isMaxLevel) continue;
        expect(
          s.experienceIntoLevel + s.experienceToNextLevel!,
          s.experienceForLevel,
          reason: 'the level span does not add up at $xp XP',
        );
      }
    });

    test('progress is always within 0 and 1', () {
      final SkillDefinition definition = skill(woodcutting);
      for (int xp = 0; xp <= 60000; xp += 97) {
        final double p = definition.standingAt(xp).progress;
        expect(p, greaterThanOrEqualTo(0.0), reason: 'at $xp XP');
        expect(p, lessThanOrEqualTo(1.0), reason: 'at $xp XP');
      }
    });
  });

  group('3 — the top of the curve', () {
    test('the cap is 20, as DECISIONS/0004 and 0017 freeze it', () {
      for (final SkillDefinition definition in stepRegistry.skills.values) {
        expect(
          definition.maxLevel,
          20,
          reason: '${definition.id} broke the level cap freeze',
        );
      }
    });

    test('reaching the last threshold is max level', () {
      // Woodcutting's twentieth threshold is 31,920.
      final SkillStanding s = skill(woodcutting).standingAt(31920);

      expect(s.level, 20);
      expect(s.isMaxLevel, isTrue);
    });

    test('at max level there is no next level, expressed as null', () {
      // Null rather than zero: zero is a legitimate span nowhere on this curve,
      // and a caller dividing by it would get infinity rather than a caught
      // case. Null makes "there is no next level" impossible to read past.
      final SkillStanding s = skill(woodcutting).standingAt(31920);

      expect(s.experienceForLevel, isNull);
      expect(s.experienceToNextLevel, isNull);
    });

    test('progress reads full at max level, not empty', () {
      // A full bar is the honest reading of a finished curve. An empty one
      // would say "no progress" about the player who has made all of it.
      expect(skill(woodcutting).standingAt(31920).progress, 1.0);
      expect(skill(woodcutting).standingAt(999999).progress, 1.0);
    });

    test('experience keeps accruing past the cap', () {
      // The player is still earning; there is simply nothing left to buy. A
      // figure frozen at the cap would under-report what they have done.
      final SkillStanding s = skill(woodcutting).standingAt(50000);

      expect(s.level, 20);
      expect(s.totalExperience, 50000);
      expect(
        s.experienceIntoLevel,
        18080,
        reason: '50,000 − 31,920 — counted, not clamped',
      );
    });
  });

  group('4 — the gates the content actually uses', () {
    test('every node and recipe level requirement is inside the cap', () {
      // A requirement above maxLevel is content the player can never satisfy —
      // a wall with nothing behind it. Cheap to check, invisible to notice.
      for (final ResourceNodeDefinition node
          in stepRegistry.resourceNodes.values) {
        final SkillDefinition definition = stepRegistry.skills[node.skill]!;
        expect(
          node.requiredLevel,
          lessThanOrEqualTo(definition.maxLevel),
          reason: '${node.id} needs a level ${definition.id} cannot reach',
        );
      }
      for (final RecipeDefinition recipe in stepRegistry.recipes.values) {
        final SkillDefinition definition = stepRegistry.skills[recipe.skill]!;
        expect(
          recipe.requiredLevel,
          lessThanOrEqualTo(definition.maxLevel),
          reason: '${recipe.id} needs a level ${definition.id} cannot reach',
        );
      }
    });

    test('a recipe never needs an ingredient gated above itself', () {
      // The Phase 1 wart this rule was written for: Bronze Chestplate needed
      // Smithing 6 and its Pine Plank needed Smithing 9, so the recipe could
      // never be made at the level it advertised. Not a hard block — the
      // reachability validator ignores levels by design — and invisible until
      // someone plays for an hour.
      // The gate is the CHEAPEST same-skill source: a deliberate high-level
      // alternate source — the `DECISIONS/0028` reclaim trio returns Bronze
      // Ingots at Smithing 8 while the ingot recipe itself needs 1 — does not
      // raise the level at which the ingredient can actually be made.
      for (final RecipeDefinition recipe in stepRegistry.recipes.values) {
        for (final RecipeIngredient ingredient in recipe.ingredients) {
          RecipeDefinition? cheapest;
          for (final RecipeDefinition source in stepRegistry.recipes.values) {
            if (source.outputItem != ingredient.item) continue;
            if (source.skill != recipe.skill) continue;
            if (cheapest == null ||
                source.requiredLevel < cheapest.requiredLevel) {
              cheapest = source;
            }
          }
          if (cheapest == null) continue;
          expect(
            cheapest.requiredLevel,
            lessThanOrEqualTo(recipe.requiredLevel),
            reason:
                '${recipe.id} claims level ${recipe.requiredLevel} but its '
                'ingredient "${ingredient.item}" comes from ${cheapest.id}, '
                'which needs ${cheapest.requiredLevel} in the same skill',
          );
        }
      }
    });

    test('every skill has something to do at level 1', () {
      // A skill whose first action is gated above level 1 cannot be started at
      // all, because the only source of its XP is behind its own gate.
      for (final ContentId id in stepRegistry.skills.keys) {
        final bool hasEntryPoint =
            stepRegistry.resourceNodes.values.any(
              (ResourceNodeDefinition n) =>
                  n.skill == id && n.requiredLevel <= 1,
            ) ||
            stepRegistry.recipes.values.any(
              (RecipeDefinition r) => r.skill == id && r.requiredLevel <= 1,
            );
        expect(
          hasEntryPoint,
          isTrue,
          reason:
              '$id has no level-1 action, so its own XP is behind its own gate',
        );
      }
    });
  });

  group('5 — every skill is genuinely part of the loop', () {
    test('each of the five has at least two rungs', () {
      // DECISIONS/0017: the five existing skills become useful rather than
      // decorative. Two rungs is the minimum at which levelling makes a visible
      // difference, which is what the milestone has to demonstrate.
      for (final ContentId id in stepRegistry.skills.keys) {
        final int actions =
            stepRegistry.resourceNodes.values
                .where((ResourceNodeDefinition n) => n.skill == id)
                .length +
            stepRegistry.recipes.values
                .where((RecipeDefinition r) => r.skill == id)
                .length;
        expect(
          actions,
          greaterThanOrEqualTo(2),
          reason: '$id has $actions action(s); levelling it changes nothing',
        );
      }
    });

    test('the five are exactly the frozen set', () {
      expect(
        stepRegistry.skills.keys.map((ContentId i) => i.value).toList(),
        <String>[
          'skill.cooking',
          'skill.foraging',
          'skill.mining',
          'skill.smithing',
          'skill.woodcutting',
        ],
      );
    });
  });
}
