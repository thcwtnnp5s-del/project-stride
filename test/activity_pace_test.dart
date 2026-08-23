// The pace of work (PLAYABLE_POLISH_01 correction pass, findings H and I).
//
// Gathering: 100 spendable steps = 60 seconds, so ×N scales with the site's
// cost by construction, with one authored seam (`workSpeedPercent`) for a
// future special site. Crafting: zero steps, so its pace is authored per
// recipe — a component a small job, gear a real one — never the step rule.
// Both are presentation pacing: the engine commits each repetition exactly
// as before (`activity_controller_test`, `craft_flow_test` prove that).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/activity_controller.dart';
import 'package:stride/ui/state/craft_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

ResourceNodeDefinition node(int stepCost, {int speed = 100}) =>
    ResourceNodeDefinition(
      id: ContentId.unchecked('resource_node.test'),
      displayName: 'Test',
      skill: ContentId.unchecked('skill.foraging'),
      requiredLevel: 1,
      requiredToolKind: ToolKind.none,
      minimumToolTier: 0,
      yieldsItem: ContentId.unchecked('item.meadow_herb'),
      yieldsQuantity: 1,
      stepCost: stepCost,
      xp: 10,
      workSpeedPercent: speed,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gathering paces at 100 steps a minute', () {
    test('the brief\'s table, exactly', () {
      const Map<int, int> table = <int, int>{
        80: 48,
        100: 60,
        120: 72,
        140: 84,
        160: 96,
        200: 120,
        500: 300,
        1000: 600,
      };
      table.forEach((int steps, int seconds) {
        expect(
          ActivityDurations.forNode(node(steps), steps),
          Duration(seconds: seconds),
          reason: '$steps steps',
        );
      });
    });

    test('a site may author its own speed; the default is the formula', () {
      expect(ActivityDurations.forNode(node(100), 100), const Duration(seconds: 60));
      expect(
        ActivityDurations.forNode(node(100, speed: 200), 100),
        const Duration(seconds: 30),
      );
      expect(
        ActivityDurations.forNode(node(100, speed: 50), 100),
        const Duration(seconds: 120),
      );
    });

    test('the pace follows the profile-scaled cost the engine charges', () {
      // The controller reads `StrideSession.costOf`, not the raw content
      // figure; here the production profile scales nothing, so the two
      // agree, and the assertion is that they are the same call.
      expect(ActivityDurations.forNode(node(80), 80), const Duration(seconds: 48));
      expect(ActivityDurations.forNode(node(80), 160), const Duration(seconds: 96));
    });
  });

  group('crafting is paced by authored seconds, and costs no steps', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('stride_pace'));
    tearDown(() {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows handle lag.
      }
    });

    test('every shipped recipe authors a deliberate bench time', () async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: <SyncFetch>[SyncFetch(const NoChangeSync())]),
      );
      final Map<String, int> expected = <String, int>{
        'recipe.bronze_ingot': 45,
        'recipe.oak_handle': 40,
        'recipe.oak_plank': 30,
        'recipe.herb_broth': 45,
        'recipe.bronze_sword': 150,
        'recipe.bronze_axe': 120,
        'recipe.bronze_pickaxe': 120,
        'recipe.bronze_chestplate': 180,
      };
      for (final RecipeOption r in s.recipeOptions) {
        expect(r.craftSeconds, isNotNull, reason: '${r.id} authored none');
        final Duration d = CraftDurations.of(r);
        // Components 30–60 s, food 45–90 s, gear 120–180 s.
        final (int lo, int hi) = switch (r.outputCategory) {
          ItemCategory.consumable => (45, 90),
          ItemCategory.equipment => (120, 180),
          _ => (30, 60),
        };
        expect(d.inSeconds, inInclusiveRange(lo, hi), reason: r.id.value);
        if (expected[r.id.value] case final int secs) {
          expect(d, Duration(seconds: secs), reason: r.id.value);
        }
      }
      // No recipe is paced by the gathering rule: none finishes in the
      // 3–6 s the card used to, and none costs a step.
      expect(
        s.recipeOptions.every((RecipeOption r) => CraftDurations.of(r).inSeconds >= 30),
        isTrue,
      );
    });
  });
}
