/// The Craft planner (Fable V2 Iteration 03): readiness bands, the
/// one-away row's named material, missing-ingredient sourcing, the chain
/// jump with its way back, and the consumed-prover warning.
///
/// The band lives on the PROJECTION (`RecipeOption.band`) so the section
/// headers, the census line, and the engine can never tell three stories;
/// this file holds both the classification and the presentation to it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/screens/craft/craft_screen.dart';
import 'package:stride/ui/state/craft_controller.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart' show MockStepSource;

import 'support/real_font.dart';

final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId copperOre = ContentId.unchecked('item.copper_ore');
final ContentId tinOre = ContentId.unchecked('item.tin_ore');
final ContentId fang = ContentId.unchecked('item.pristine_wolf_fang');
final ContentId ingotRecipe = ContentId.unchecked('recipe.bronze_ingot');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_planner'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> boot() =>
      StrideSession.start(overrideRoot: root, source: MockStepSource());

  test('the readiness band is the projection\'s own classification', () async {
    final StrideSession s = await boot();
    RecipeOption of(String id) => s.recipeOptions.firstWhere(
      (RecipeOption r) => r.id == ContentId.unchecked(id),
    );

    // Fresh save (empty bags): broth and the handle each want one
    // material kind (ONE AWAY); the ingot wants two ores (MISSING); the
    // sword is skill-locked; the wolfhide jerkin is contract-gated.
    expect(of('recipe.herb_broth').band, ReadinessBand.oneAway);
    expect(of('recipe.oak_handle').band, ReadinessBand.oneAway);
    expect(of('recipe.bronze_ingot').band, ReadinessBand.missing);
    expect(of('recipe.bronze_sword').band, ReadinessBand.skillLocked);
    expect(of('recipe.wolfhide_jerkin').band, ReadinessBand.gated);
  });

  test('sourcing and the prover warning are projection-derived', () async {
    final StrideSession s = await boot();

    // A missing ore names the seam that yields it — the same purpose join
    // the bag reads.
    expect(s.ingredientSourceLine(copperOre), contains('Copper Seam'));

    // The fanghilt recipe consumes the fang A Hunter's Token asks to SEE;
    // the warning names the contract and its place while it is
    // uncompleted.
    final RecipeOption fanghilt = s.recipeOptions.firstWhere(
      (RecipeOption r) => r.id == ContentId.unchecked('recipe.fanghilt_sword'),
    );
    final String warning = s.consumesProverWarning(fanghilt)!;
    expect(warning, contains('A Hunter\'s Token'));
    expect(warning, contains('Whispering Woods'));
    expect(warning, contains('consumes it'));

    // A recipe touching no prover warns about nothing.
    final RecipeOption broth = s.recipeOptions.firstWhere(
      (RecipeOption r) => r.id == ContentId.unchecked('recipe.herb_broth'),
    );
    expect(s.consumesProverWarning(broth), isNull);
  });

  test(
    'the worn-gear warning fires only while the donor is worn spare-less',
    () async {
      // The Iteration 03 review's must-fix, seen from the bench: a reforge
      // that consumes what the player is wearing announces the unequip
      // before the tap. The fresh Traveler's only Training Sword is the
      // fanghilt's donor.
      final StrideSession s = await boot();
      RecipeOption fanghilt() => s.recipeOptions.firstWhere(
        (RecipeOption r) =>
            r.id == ContentId.unchecked('recipe.fanghilt_sword'),
      );

      expect(s.consumesWornGearWarning(fanghilt()), isNull);

      expect(
        (await s.equip(ContentId.unchecked('item.training_sword'))).succeeded,
        isTrue,
      );
      final String warning = s.consumesWornGearWarning(fanghilt())!;
      expect(warning, contains('Training Sword'));
      expect(warning, contains('takes it off'));

      expect((await s.unequip(EquipmentSlot.weapon)).succeeded, isTrue);
      expect(s.consumesWornGearWarning(fanghilt()), isNull);
    },
  );

  testWidgets('bands render as sections and the chain jump goes and comes '
      'back', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession s = (await tester.runAsync(boot))!;
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(
          controller: c,
          child: CraftScope(
            controller: CraftController(c),
            child: const Scaffold(body: CraftScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The section headers, in planning order (SectionHeading renders
    // uppercase) — and the empty READY band is skipped entirely on an
    // empty-bagged fresh save, exactly the rule.
    expect(find.text('READY'), findsNothing);
    expect(find.text('ONE INGREDIENT AWAY'), findsOneWidget);
    expect(find.text('MISSING MATERIALS'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    // The one-away row names its single missing material on the row.
    expect(find.textContaining('needs 2 more Oak Log'), findsOneWidget);

    // Open the ingot: its short ores carry sourcing lines (gathered
    // materials, so no chain link on them).
    await tester.tap(find.text('Bronze Ingot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copper Seam'), findsWidgets);

    // The chain: Bronze Sword's short Bronze Ingot line is a door to the
    // ingot recipe, and the back chip is the way home. Reach the sword
    // through the Gear filter — the shorter list keeps it and its detail
    // on screen the way a player would find it — and the jump itself must
    // clear the filter (an ingot is Materials, not Gear).
    await tester.tap(find.text('Gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Sword'));
    await tester.pumpAndSettle();
    expect(find.text('CRAFT ›'), findsWidgets);
    await tester.tap(find.text('CRAFT ›').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to Bronze Sword'), findsOneWidget);
    // The jumped-to detail is the ingot's (its ores and their sources).
    expect(find.textContaining('Copper Seam'), findsWidgets);
    await tester.tap(find.textContaining('Back to Bronze Sword'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to Bronze Sword'), findsNothing);
    // Back on the sword's detail: its skill sentence is on the button.
    expect(find.textContaining('Needs Smithing 3'), findsOneWidget);
  });
}
