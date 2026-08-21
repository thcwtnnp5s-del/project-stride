/// Renders each Phase 1 screen at the reference viewport and writes it as a
/// golden.
///
/// **These are regression goldens between Flutter revisions, not a comparison
/// against the HTML prototype.** A browser and Skia differ on font metrics,
/// hinting, subpixel placement and antialiasing; chasing that difference is the
/// unbounded pixel-hunt `MISTAKES.md` M-01 records. Perceptual parity is judged
/// by a human against these renders, once per screen.
///
/// ## What these images CANNOT show, and it is more than it looks
///
/// **This harness supplies zero safe-area insets.** Any defect that is a
/// function of real device padding measures as exactly 0 here and appears only
/// on hardware. That is how 57 dp of dead space landed above the inventory grid
/// on a phone and nowhere in this file.
///
/// **The harness had no real font either, and now it has one.** Every glyph used
/// to render as a filled rectangle, so a golden could not show an underline, a
/// wrong weight, or a clipped descender — which is how Phase 1 passed 93 widget
/// tests and four of these goldens while **every string in the application was
/// underlined** (`MISTAKES.md` M-06). `loadRealFont()` now registers Roboto, so
/// these images carry real letterforms.
///
/// That is a smaller claim than it sounds and is worth stating precisely.
/// Roboto is not SF Pro, so a glyph-level difference against an iPhone is
/// expected and is not a defect. What the real font buys is that anything
/// **typographic** — a decoration, a weight, a size, a line that does not fit —
/// is now visible in the image instead of merging into a box. It also makes
/// these goldens agree with the device about which layout branch is taken:
/// `ValueTileRow` stacks or rows by measuring text, and against the fat fallback
/// font it stacked here while a phone showed it in a row.
///
/// So: a green run of this file means the layout has not moved. It does not
/// mean the screen looks right, and it never can. **Look at a running build.**
///
/// One viewport deliberately. A golden per screen per width is four times the
/// maintenance for a fraction of the signal, and `phase1_ui_test.dart` already
/// covers 320 / 360 / 375 / 393 / 430 for overflow.
///
/// Regenerate with:
///   flutter test test/phase1_golden_test.dart --update-goldens
@Tags(<String>['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';
import 'support/real_font.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_golden'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  /// A new game funded with [banked] spendable steps.
  ///
  /// A brand-new game's first authorised sync is its baseline and retires
  /// whatever it read (DECISIONS/0019), so the store is empty at install, one
  /// sync retires that nothing, and only then is the fixture page synced — the
  /// figures the goldens render are unchanged.
  Future<StrideSession> bootBaselined(WidgetTester tester, int banked) async {
    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(banked)],
        ),
      ),
    ))!;
    await tester.runAsync(() => session.syncSteps());
    expect(session.baselinePending, isFalse);
    expect(session.usableEnergy, 0);
    await tester.runAsync(() => session.syncSteps());
    expect(session.usableEnergy, banked);
    return session;
  }

  testWidgets('the six screens at 393 x 852', (WidgetTester tester) async {
    // The reference viewport the approved renders were authored at. DPR 1 so
    // the golden's pixel dimensions equal its logical dimensions and a reviewer
    // comparing it to the 393x852 HTML render is comparing like with like.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StrideSession session = await bootBaselined(tester, 12480);
    await tester.runAsync(() => session.gather(kNode));
    await tester.runAsync(() => session.gather(kNode));

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    /// Decodes every `Image` currently in the tree, then settles.
    ///
    /// `pumpAndSettle` does not wait for asset decode — it drives the frame
    /// scheduler, and decoding happens off it. Without this, a golden captures
    /// whichever sprites happened to win the race, which looks exactly like a
    /// missing-asset bug and is not one.
    Future<void> settleImages() async {
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          final Image image = e.widget as Image;
          await precacheImage(image.image, e);
        }
      });
      await tester.pumpAndSettle();
    }

    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_adventure.png'),
    );

    // Tapped through the tab bar specifically. `Craft` is also a button label
    // on the Craft screen, so `find.text('Craft')` alone is ambiguous the
    // moment that screen is the one on show.
    Future<void> open(String tab) async {
      await tester.tap(
        find.descendant(
          of: find.byType(StrideTabBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      await settleImages();
    }

    await open('Inventory');
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_inventory.png'),
    );

    await open('Character');
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_character.png'),
    );

    await open('Skills');
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase2_skills.png'),
    );

    await open('Craft');
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase2_craft.png'),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(StrideTabBar),
        matching: find.text('World'),
      ),
    );
    await tester.pumpAndSettle();
    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_world.png'),
    );
  });

  /// The same screens against a **real save's figures**, not a demo's.
  ///
  /// The golden above banks `12,480`. That is six characters, it fits, and it
  /// is the reason four green goldens said nothing about D-01 — the owner's
  /// phone was showing `455,281`, which is seven, and the header drew six of
  /// them (`MISTAKES.md` M-06, `MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md`
  /// §5).
  ///
  /// The numbers here are the ones from that run, to the step: 455,371 banked
  /// after the backlog drained, then one gather taking it to **455,281**. A
  /// fixture that resembles the accepted save rather than a convenient one.
  ///
  /// It is a second image rather than a replacement, because the small-value
  /// case is also real — a new player has it — and a regression that only
  /// affects short figures would otherwise have no golden at all.
  ///
  /// **This still cannot judge insets**, and Roboto is not the iPhone's SF Pro. It is
  /// regression evidence that the layout has not moved at a realistic value.
  /// `ui_responsive_test.dart` is what actually asserts the figure is whole.
  testWidgets('the six screens at the accepted save, 455,281 banked', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 455,361 − one 80-step gather = the historical 455,281. The device run
    // banked 455,371 and gathered at the old 90-step cost; the figure the
    // defect was found at is the part that must survive the retune
    // (Exploration & Progression Loop 01 took the meadow to 80).
    final StrideSession session = await bootBaselined(tester, 455361);
    await tester.runAsync(() => session.gather(kNode));
    expect(
      session.usableEnergy,
      455281,
      reason: 'the fixture must reach the figure the defect was found at',
    );

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    Future<void> settleImages() async {
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
    }

    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_adventure_large.png'),
    );

    for (final (String tab, String file) in <(String, String)>[
      ('Inventory', 'phase1_inventory_large.png'),
      ('Character', 'phase1_character_large.png'),
      ('Skills', 'phase2_skills_large.png'),
      ('Craft', 'phase2_craft_large.png'),
      ('World', 'phase1_world_large.png'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(StrideTabBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      await settleImages();
      await expectLater(
        find.byType(StrideApp),
        matchesGoldenFile('goldens/$file'),
      );
    }
  });
  testWidgets('the craft stage, mid-craft, with its station', (
    WidgetTester tester,
  ) async {
    // PRESENTATION_WORLD_REWARD_FEEL_01 §17. This golden exists for one
    // property the widget tests cannot state: that the Traveler and the
    // station he is working at occupy the SAME PLACE. The first composite of
    // this stage put the anvil at the far-left scenery slot and the figure at
    // 0.6 of the width, so he swung a hammer at empty air — a defect that is
    // invisible to any assertion about widgets existing, and obvious in an
    // image.
    //
    // It is a layout witness, not a beauty contest (`MISTAKES.md` M-06):
    // green means the figure, the loop and the station have not drifted
    // apart. Whether it looks right is a question for a running build.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeTiming fake = FakeTiming();
    final StrideSession session = await bootBaselined(tester, 4000);
    session.activityWallClock = fake.wallClock;
    // Enough Meadow Herb for a Herb Broth, which is Cooking — the craft class
    // whose loop and station both ship.
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(() => session.gather(kNode));
    }

    await tester.pumpWidget(
      StrideApp(
        session: session,
        syncOnStart: false,
        activityTiming: fake.timing,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(StrideTabBar),
        matching: find.text('Craft'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Herb Broth').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(StrideButton, 'Craft'));
    // NOT pumpAndSettle: the working loop repeats forever by design, so
    // there is no quiescent frame to settle to. Fixed pumps land on a
    // deterministic frame of the loop instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Mid-repetition: the loop is running and nothing has committed yet.
    expect(find.text('Crafting 0 / 1'), findsOneWidget);

    await tester.runAsync(() async {
      for (final Element e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/craft_stage.png'),
    );
  });

}
