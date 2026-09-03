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

  testWidgets('the workshop: stations, folio, tiles, ledger, and the chain '
      'jump inside the sheet', (WidgetTester tester) async {
    // FMPO02 (`ART-12_ux_brief.md` §1). The bands survive as headings over
    // 2-column tiles, but the screen's PRIMARY axis is the station, so a
    // band is now a band *within a station*: the same 39 recipes, sorted by
    // the place they are made rather than by nothing at all.
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

    // Three stations, always, whatever the bag holds — the strip is the
    // screen's map of the workshop and never hides a bench.
    expect(find.text('Forge'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Cookfire'), findsOneWidget);
    // The census on each plinth is over the whole station, and since EPO03
    // it is one line rather than two (`DIR-06` §2).
    expect(find.text('23 · 0 ready'), findsOneWidget);
    expect(find.text('3 · 0 ready'), findsOneWidget);
    expect(find.text('10 · 0 ready'), findsOneWidget);

    // A fresh save can make nothing, so the strip defaults to the forge and
    // the forge's own bands are what shows: no READY, the ingot MISSING,
    // and everything gated behind a level in the ledger.
    expect(find.text('READY'), findsNothing);
    expect(find.text('MISSING MATERIALS'), findsOneWidget);
    expect(find.text('THE RECIPE BOOK'), findsOneWidget);

    // A tile opens the sheet rather than expanding in place: the list does
    // not move, and the short ores carry their sourcing lines.
    await tester.tap(find.text('Bronze Ingot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copper Seam'), findsWidgets);

    // The scrim dismisses it.
    await tester.tapAt(const Offset(196, 30));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copper Seam'), findsNothing);

    // The recipe book (EPO03, `DIR-06` §6). The locked half is chapters of
    // sealed pages, not a ledger: every locked recipe is visible by name
    // without opening anything, the gate is said ONCE in the chapter's tier
    // header, and **no row states a gate at all** — which is the owner's
    // verdict, in an assertion.
    expect(find.text('Bronze Sword'), findsOneWidget);
    // The chapter opening names its trade and its range. Both are asserted,
    // as separate runs: the header is a `Wrap` of word-level runs rather than
    // one string, so that it **breaks** instead of shrinking at accessibility
    // text scales — at ×1.4 on a 320 dp screen the single string wanted 264 dp
    // of a 156 dp row, which no honest shrink ladder can buy
    // (`ui_responsive_test.dart`). The presentation moved, so the assertion
    // moves with it; what it checks is unchanged.
    expect(find.text('SMITHING ·'), findsNWidgets(4));
    expect(find.text('LEVELS'), findsNWidgets(4));
    expect(find.text('1–3'), findsOneWidget);
    expect(find.text('Opens at Smithing 2'), findsOneWidget);
    expect(find.textContaining('Opens at Smithing'), findsNWidgets(4));
    expect(find.textContaining('more at Smithing'), findsNothing);

    // The chain: the sword's short Bronze Ingot line is a door to the
    // ingot's recipe, and it replaces the sheet's content in place.
    await tester.ensureVisible(find.text('Bronze Sword'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Sword'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Needs Smithing 3'), findsOneWidget);
    expect(find.text('CRAFT ›'), findsWidgets);
    await tester.tap(find.text('CRAFT ›').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to Bronze Sword'), findsOneWidget);
    expect(find.textContaining('Copper Seam'), findsWidgets);
    await tester.tap(find.textContaining('Back to Bronze Sword'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to Bronze Sword'), findsNothing);
    expect(find.textContaining('Needs Smithing 3'), findsOneWidget);
    await tester.tapAt(const Offset(196, 30));
    await tester.pumpAndSettle();

    // Walk to the cookfire: a different station, a different census, and a
    // folio open at the nearest thing to a meal — with its shortfall on the
    // button, which is the whole point of showing a one-away recipe big.
    // The book was scrolled to, so the strip is above the viewport and its
    // elements are gone: drag back rather than ensureVisible.
    await tester.dragUntilVisible(
      find.text('Cookfire'),
      find.byType(ListView).first,
      const Offset(0, 250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cookfire'));
    await tester.pumpAndSettle();
    expect(find.text('0 craftable · 10 known'), findsOneWidget);
    expect(find.text('Herb Broth'), findsOneWidget);
    // The folio's tray states held over required, and its button states the
    // shortfall — the one sentence that says why, unchanged.
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Needs 2 more Meadow Herb'), findsOneWidget);
    // And the folio's own recipe is not repeated as a tile beneath itself.
    expect(find.text('ONE INGREDIENT AWAY'), findsNothing);
  });
}
