/// World & Reward Depth 01, stream C — the rarity visual language.
///
/// Four properties, each named for the defect it catches:
///
/// 1. **The table is total and the palette is legal.** A rank with no style is
///    an invisible item; a rank painted in the walking teal breaks
///    `ART_DIRECTION.md` **L-16**, which reserves that hue for steps and
///    nothing else; a rank that does not clear 4.5:1 on the card is a name the
///    player cannot read. None of the three is visible in a screenshot review.
/// 2. **The word travels with the colour.** The owner's direction is that
///    *Rare*, *Epic* and *Legendary* must be readable as text. A regression
///    here — a badge quietly dropped to make a row fit — degrades to
///    colour-only and nobody notices until someone who does not separate five
///    hues uses it.
/// 3. **The victory panel itemises, and acknowledges exactly once.** The
///    reward is written to disk by the engine; this panel is the only place
///    the player is told what they won, and a double acknowledgement would
///    clear a report the player never read.
/// 4. **Nothing clips.** `MISTAKES.md` M-06 and D-01: the rarity pass adds
///    words to the densest surfaces in the app, and a word that does not fit
///    fails silently.
///
/// The victory panel is driven through a **stubbed controller** rather than a
/// real fight. The engine's drop roll is deterministic
/// (`CombatRules.percentRoll`), so a wolf always drops the same things — which
/// means the empty-drop branch and the Legendary rank are not reachable from
/// gameplay at all. The stub supplies the `CombatReport` the session would
/// have produced and changes nothing about how the panel reads it.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/components/rarity_badge.dart';
import 'package:stride/ui/components/rarity_item_title.dart';
import 'package:stride/ui/components/reward_beat.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/screens/combat/combat_screen.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/rarity_style.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride/ui/theme/stride_theme.dart';
import 'package:stride/ui/theme/stride_typography.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId kHerb = ContentId.unchecked('item.meadow_herb');
final ContentId kPelt = ContentId.unchecked('item.wolf_pelt');
final ContentId kSigil = ContentId.unchecked('item.hollow_sigil');

/// An item id no content pack and no icon table knows, for the "reserved rank,
/// missing art" row.
final ContentId kRelic = ContentId.unchecked('item.unshipped_relic');

// ---------------------------------------------------------------- contrast

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Whether a colour carries the walking accent's signature: green **and** blue
/// well above red, and the two of them close to each other.
///
/// A plain RGB distance is the wrong test — the moss green sits 0.24 from the
/// teal by that measure and reads nothing like it, while a desaturated
/// blue-green could sit further away and read exactly like it. This is the
/// shape of the hue L-16 reserves, stated directly.
bool _readsAsTeal(Color c) =>
    c.g - c.r > 0.2 && c.b - c.r > 0.2 && (c.g - c.b).abs() < 0.2;

/// The WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

// ------------------------------------------------------------------ harness

/// Every single-line paragraph whose text needs more width than it was given.
///
/// The same property `test/ui_responsive_test.dart` asserts, applied to the two
/// surfaces that file does not visit: the Craft screen and the victory panel.
/// Duplicated deliberately and narrowly — the alternative is exporting a test
/// helper between suites, and one small measurement is cheaper than a shared
/// harness nobody owns.
List<String> clippedLines(WidgetTester tester) {
  final List<String> bad = <String>[];
  for (final Element e in find.byType(RichText).evaluate()) {
    final RenderParagraph p = e.renderObject! as RenderParagraph;
    if (p.text.toPlainText().contains('\n')) continue;
    final double needed = p.getMaxIntrinsicWidth(double.infinity);
    if (needed > p.size.width + 0.5 && p.maxLines == 1) {
      bad.add(
        '"${p.text.toPlainText()}" needs '
        '${needed.toStringAsFixed(1)} dp and was given '
        '${p.size.width.toStringAsFixed(1)}',
      );
    }
  }
  return bad;
}

/// A controller that stands in for the outcome of a fight that already
/// happened. It holds a report and counts acknowledgements; it commands
/// nothing.
class _StubbedOutcome extends SessionController {
  _StubbedOutcome(super.session, this._report);

  CombatReport? _report;
  int acknowledgements = 0;

  @override
  CombatReport? get lastCombat => _report;

  @override
  void acknowledgeCombat() {
    acknowledgements++;
    if (_report == null) return;
    _report = null;
    notifyListeners();
  }
}

CombatReport won({
  required List<RewardLine> drops,
  int xp = 30,
  int levelBefore = 1,
  int levelAfter = 1,
}) => CombatReport(
  succeeded: true,
  enemyName: 'Forest Wolf',
  events: <CombatBeat>[
    WonBeat(
      xp: xp,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      drops: drops,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_rarity_ui'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    return (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync())],
        ),
      ),
    ))!;
  }

  /// The result panel, alone, under the app's real theme.
  ///
  /// `CombatScreen` with no live encounter and an unacknowledged report is
  /// exactly the panel and nothing else — its own library documents that path.
  Future<_StubbedOutcome> showPanel(
    WidgetTester tester,
    CombatReport report, {
    double width = 393,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    final StrideSession session = await boot(tester);
    final _StubbedOutcome controller = _StubbedOutcome(session, report);
    await tester.pumpWidget(
      MaterialApp(
        theme: strideTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 852),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: SessionScope(
            controller: controller,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width - 32),
                child: const CombatScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  // =========================================================================
  // The style table
  // =========================================================================

  group('the rarity style table', () {
    test('every rank has a style, and no two ranks share an ink', () {
      final Set<int> inks = <int>{};
      final Set<int> accents = <int>{};
      for (final Rarity r in Rarity.values) {
        final RarityStyle s = RarityStyle.of(r);
        expect(s.rarity, r);
        inks.add(s.ink.toARGB32());
        accents.add(s.accent.toARGB32());
      }
      // Five ranks in the enum, five inks, five accents. A rank added to
      // `stride_core` without a style here is a compile error in
      // `RarityStyle.of`; a rank added *with a duplicate colour* is not, and
      // that is what this counts.
      expect(Rarity.values.length, 5);
      expect(inks.length, Rarity.values.length);
      expect(accents.length, Rarity.values.length);
    });

    test('the label is the enum label, and the badge is it uppercased', () {
      for (final Rarity r in Rarity.values) {
        expect(RarityStyle.of(r).label, r.label);
        expect(RarityStyle.of(r).badgeLabel, r.label.toUpperCase());
      }
      // Named, so a rename in content is visible here as a failure rather than
      // as a silently different word on the phone.
      expect(RarityStyle.of(Rarity.rare).badgeLabel, 'RARE');
      expect(RarityStyle.of(Rarity.legendary).badgeLabel, 'LEGENDARY');
    });

    test('no rank uses the walking accent — ART_DIRECTION L-16', () {
      for (final Rarity r in Rarity.values) {
        final RarityStyle s = RarityStyle.of(r);
        expect(s.ink, isNot(StrideColors.accentSteps));
        expect(s.ink, isNot(StrideColors.accentStepsDim));
        expect(s.accent, isNot(StrideColors.accentSteps));
        expect(s.accent, isNot(StrideColors.accentStepsDim));
        // Not merely "a different constant": teal is a *region* of the wheel,
        // and a rarity that landed inside it would read as walking.
        expect(
          _readsAsTeal(s.ink),
          isFalse,
          reason: '${r.label} reads as the walking accent',
        );
        expect(_readsAsTeal(s.accent), isFalse, reason: '${r.label} accent');
      }
      // The predicate is not vacuous: it catches the colour it is about.
      expect(_readsAsTeal(StrideColors.accentSteps), isTrue);
      // The blue rank is the one actually at risk, and the property that keeps
      // it a cobalt rather than a teal is that it is bluer than it is green.
      // `MILESTONES/WORLD_REWARD_DEPTH_01.md` §5 and L-16 both turn on this.
      final Color rare = RarityStyle.of(Rarity.rare).ink;
      expect(rare.b, greaterThan(rare.g));
      expect(rare.g, greaterThan(rare.r));
      // …and the walking accent is the other way round.
      expect(
        StrideColors.accentSteps.g,
        greaterThan(StrideColors.accentSteps.b),
      );
    });

    test('every ink is legible on every surface it is drawn on', () {
      const List<Color> grounds = <Color>[
        StrideColors.surfaceGround,
        StrideColors.surfaceCard,
        StrideColors.surfaceBlock,
      ];
      for (final Rarity r in Rarity.values) {
        for (final Color ground in grounds) {
          expect(
            contrast(RarityStyle.of(r).ink, ground),
            greaterThanOrEqualTo(4.5),
            reason: '${r.label} on $ground',
          );
        }
      }
    });

    test('a missing rarity resolves to nothing, never to a rank', () {
      expect(RarityStyle.maybe(null), isNull);
      expect(
        RarityStyle.inkOr(null, StrideColors.textSecondary),
        StrideColors.textSecondary,
      );
      expect(
        RarityStyle.inkOr(Rarity.epic, StrideColors.textSecondary),
        StrideColors.rarityEpic,
      );
    });
  });

  // =========================================================================
  // The badge
  // =========================================================================

  group('the badge', () {
    Future<void> pumpBadges(WidgetTester tester, Widget child) =>
        tester.pumpWidget(
          MaterialApp(
            theme: strideTheme(),
            home: Align(alignment: Alignment.topLeft, child: child),
          ),
        );

    testWidgets('renders the rank as a word, in the rank ink', (
      WidgetTester tester,
    ) async {
      await pumpBadges(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final Rarity r in Rarity.values) RarityBadge(rarity: r),
          ],
        ),
      );
      for (final Rarity r in Rarity.values) {
        final Finder label = find.text(r.label.toUpperCase());
        expect(label, findsOneWidget, reason: r.label);
        expect(
          (tester.widget(label) as Text).style!.color,
          RarityStyle.of(r).ink,
        );
      }
    });

    testWidgets('a null rank renders nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpBadges(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RarityBadge(rarity: null),
            RarityBadge.compact(rarity: null),
          ],
        ),
      );
      expect(find.byType(Text), findsNothing);
      // Zero-size, not merely empty: an invisible box that still occupied a
      // line would push a grid cell's contents and clip the row below it.
      for (final Element e in find.byType(RarityBadge).evaluate()) {
        expect((e.renderObject! as RenderBox).size, Size.zero);
      }
    });

    testWidgets('the compact form is the same word without the plate', (
      WidgetTester tester,
    ) async {
      await pumpBadges(
        tester,
        const SizedBox(
          width: 90,
          child: RarityBadge.compact(rarity: Rarity.uncommon),
        ),
      );
      expect(find.text('UNCOMMON'), findsOneWidget);
      // No filled plate: the compact form exists for surfaces with no room for
      // one, and a plate that shrank with the word would be the thing clipping.
      expect(
        find.descendant(
          of: find.byType(RarityBadge),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  // =========================================================================
  // The victory panel
  // =========================================================================

  group('the victory panel', () {
    testWidgets('itemises one framed row per drop: icon, name, rank, count', (
      WidgetTester tester,
    ) async {
      await showPanel(
        tester,
        won(
          drops: <RewardLine>[
            RewardLine(
              id: kHerb,
              name: 'Meadow Herb',
              quantity: 1,
              rarity: Rarity.uncommon,
            ),
            RewardLine(
              id: kPelt,
              name: 'Wolf Pelt',
              quantity: 2,
              rarity: Rarity.common,
            ),
            RewardLine(
              id: kSigil,
              name: 'Hollow Sigil',
              quantity: 3,
              rarity: Rarity.epic,
            ),
            // Reserved rank, and an item no icon table covers: the row must
            // still be complete, with the fallback slab carrying the picture.
            RewardLine(
              id: kRelic,
              name: 'Unshipped Relic',
              quantity: 12,
              rarity: Rarity.legendary,
            ),
          ],
        ),
      );

      expect(find.text('VICTORY'), findsOneWidget);
      expect(find.text('Forest Wolf falls'), findsOneWidget);
      // The experience is separated from the rewards, under its own label.
      expect(find.text('EXPERIENCE'), findsOneWidget);
      expect(find.text('+30 XP'), findsOneWidget);
      expect(find.text('REWARDS'), findsOneWidget);

      // One icon per drop; a frame only from Uncommon up — the Common row
      // is plain (the correction pass, finding E), so three of four.
      expect(find.byType(RarityFrame), findsNWidgets(3));
      expect(find.byType(PixelAsset), findsNWidgets(4));
      expect(find.text('No drops this time.'), findsNothing);

      const Map<String, (Rarity, String)> rows = <String, (Rarity, String)>{
        'Meadow Herb': (Rarity.uncommon, '×1'),
        'Wolf Pelt': (Rarity.common, '×2'),
        'Hollow Sigil': (Rarity.epic, '×3'),
        'Unshipped Relic': (Rarity.legendary, '×12'),
      };
      rows.forEach((String name, (Rarity, String) row) {
        final Finder title = find.text(name);
        expect(title, findsOneWidget, reason: name);
        // The name carries the rank's ink…
        expect(
          (tester.widget(title) as Text).style!.color,
          RarityStyle.of(row.$1).ink,
          reason: name,
        );
        // …and the rank's word rides beside it, because colour is never the
        // only carrier — except Common, which is the floor and says
        // nothing (finding E: a Common row is plain).
        if (row.$1 != Rarity.common) {
          expect(
            find.text(row.$1.label.toUpperCase()),
            findsWidgets,
            reason: name,
          );
        }
        expect(find.text(row.$2), findsOneWidget, reason: '$name quantity');
      });

      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('an empty drop list says so, quietly, and frames nothing', (
      WidgetTester tester,
    ) async {
      await showPanel(tester, won(drops: const <RewardLine>[]));
      expect(find.text('VICTORY'), findsOneWidget);
      expect(find.text('+30 XP'), findsOneWidget);
      expect(find.text('REWARDS'), findsOneWidget);
      expect(find.text('No drops this time.'), findsOneWidget);
      expect(find.byType(RarityFrame), findsNothing);
      expect(find.byType(RarityBadge), findsNothing);
      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('a level-up is the universal level-up beat, beneath the '
        'experience block', (WidgetTester tester) async {
      // PLAYABLE_EXPERIENCE_REFINEMENT_01 §29: one level-up presentation
      // shared by gathering, crafting and combat — never a line appended
      // inside whichever block happened to trigger it.
      await showPanel(
        tester,
        won(drops: const <RewardLine>[], xp: 120, levelAfter: 3),
      );
      expect(find.text('+120 XP'), findsOneWidget);
      expect(find.text('Level 3!'), findsNothing);
      expect(find.byType(LevelUpCard), findsOneWidget);
      expect(find.text('LEVEL UP'), findsOneWidget);
      expect(find.text('TRAVELER LEVEL 3'), findsOneWidget);
      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('Continue acknowledges exactly once and cannot be tapped '
        'again', (WidgetTester tester) async {
      final _StubbedOutcome c = await showPanel(
        tester,
        won(
          drops: <RewardLine>[
            RewardLine(
              id: kHerb,
              name: 'Meadow Herb',
              quantity: 1,
              rarity: Rarity.uncommon,
            ),
          ],
        ),
      );
      final Finder go = find.widgetWithText(StrideButton, 'Continue');
      expect(go, findsOneWidget);
      await tester.tap(go);
      await tester.pumpAndSettle();

      expect(c.acknowledgements, 1);
      // The panel goes with the report, so there is no second control to tap:
      // the "acknowledged twice" defect is unreachable rather than guarded.
      expect(find.widgetWithText(StrideButton, 'Continue'), findsNothing);
      expect(find.text('VICTORY'), findsNothing);
      expect(find.text('Meadow Herb'), findsNothing);
    });

    testWidgets('the real controller acknowledges idempotently', (
      WidgetTester tester,
    ) async {
      // The stub above counts taps; this is the property the *shipping*
      // controller has, and it is what makes a duplicate acknowledgement a
      // no-op rather than a cleared-but-unread report.
      final StrideSession session = await boot(tester);
      final SessionController real = SessionController(session);
      int notifications = 0;
      real.addListener(() => notifications++);
      expect(real.lastCombat, isNull);
      real
        ..acknowledgeCombat()
        ..acknowledgeCombat();
      expect(notifications, 0);
      real.dispose();
    });

    testWidgets('the reward reveal is one-shot, and off under reduced motion', (
      WidgetTester tester,
    ) async {
      final CombatReport report = won(
        drops: <RewardLine>[
          RewardLine(
            id: kHerb,
            name: 'Meadow Herb',
            quantity: 1,
            rarity: Rarity.uncommon,
          ),
          RewardLine(
            id: kPelt,
            name: 'Wolf Pelt',
            quantity: 2,
            rarity: Rarity.common,
          ),
        ],
      );

      // Reduced motion: the rows arrive finished on the first frame. Nothing
      // is animated away, and nothing has to be waited for.
      await showPanel(tester, report, reducedMotion: true);
      for (final Element e in find.byType(FadeTransition).evaluate()) {
        expect((e.widget as FadeTransition).opacity.value, 1.0);
      }
      await tester.pumpWidget(const SizedBox.shrink());

      // Ordinary motion: it settles, and once settled it stays settled — a
      // looping flourish would never let `pumpAndSettle` return, and a second
      // pump would find a different opacity.
      await showPanel(tester, report);
      for (final Element e in find.byType(FadeTransition).evaluate()) {
        expect((e.widget as FadeTransition).opacity.value, 1.0);
      }
      await tester.pump(const Duration(seconds: 2));
      for (final Element e in find.byType(FadeTransition).evaluate()) {
        expect((e.widget as FadeTransition).opacity.value, 1.0);
      }
    });

    for (final double width in <double>[320, 393]) {
      for (final double scale in <double>[1.0, 1.4]) {
        testWidgets('nothing clips at ${width.toInt()} dp x$scale', (
          WidgetTester tester,
        ) async {
          await showPanel(
            tester,
            won(
              drops: <RewardLine>[
                // The longest rank word against the longest shipped item
                // name and a three-digit count — the row's worst case.
                RewardLine(
                  id: kRelic,
                  name: 'Frost-lined Jerkin',
                  quantity: 999,
                  rarity: Rarity.legendary,
                ),
                RewardLine(
                  id: kHerb,
                  name: 'Meadow Herb',
                  quantity: 1,
                  rarity: Rarity.uncommon,
                ),
              ],
            ),
            width: width,
            textScale: scale,
          );
          expect(clippedLines(tester), isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // =========================================================================
  // Inventory and Craft, through the app
  // =========================================================================

  group('the screens', () {
    Future<StrideSession> app(WidgetTester tester) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      return session;
    }

    Future<void> tab(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(
          of: find.byType(StrideTabBar),
          matching: find.text(name),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an inventory tile carries the rank as ink and a rule', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await app(tester);
      await tab(tester, 'Inventory');

      final List<InventoryEntry> entries = session.inventoryEntries;
      expect(entries, isNotEmpty);
      // One rule per tile, always — reserved even for an item whose rarity the
      // pack does not supply, because a grid has one height for every cell.
      expect(find.byType(RarityRule), findsNWidgets(entries.length));

      for (final InventoryEntry e in entries) {
        final Finder name = find.byWidgetPredicate(
          (Widget w) =>
              w is Text &&
              w.data == e.displayName &&
              w.style?.fontSize == StrideType.itemName.fontSize,
        );
        expect(name, findsOneWidget, reason: e.displayName);
        expect(
          (tester.widget(name) as Text).style!.color,
          RarityStyle.inkOr(e.rarity, StrideColors.textSecondary),
          reason: e.displayName,
        );
      }
      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('the equipment case carries the rank as ink', (
      WidgetTester tester,
    ) async {
      // Equipped through the product's own control rather than a direct
      // session call: since the shell keeps screens alive (Fable V2), only
      // a controller-notified change rebuilds a mounted screen — which is
      // exactly the product path, so the test walks it.
      final StrideSession session = await app(tester);
      await tab(tester, 'Inventory');
      await tester.tap(find.text('Equip').first);
      await tester.pumpAndSettle();

      final EquippedSummary worn = session.equippedSummary.single;
      expect(worn.rarity, isNotNull);
      // **The ink, not the word, since FMPO02.** The stacked summary that
      // spelled the rank out is now the equipment case's slot plate, and a
      // plate says four things — icon, slot, name, stat (`ART-12` §2). The
      // word is still carried by every surface that gives a piece a full row:
      // the Character sheet's equipped line (tested below), the victory panel,
      // the craft card.
      final Finder name = find.byWidgetPredicate(
        (Widget w) =>
            w is Text &&
            w.data == worn.displayName &&
            w.style?.fontSize == StrideType.itemName.fontSize,
      );
      expect(name, findsWidgets);
      expect(
        (tester.widget(name.first) as Text).style!.color,
        RarityStyle.of(worn.rarity!).ink,
      );
      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('a recipe card names the rank of what it makes', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await app(tester);
      await tab(tester, 'Craft');

      final List<RecipeOption> recipes = session.recipeOptions;
      expect(recipes, isNotEmpty);

      // Every row's name is in the rank's ink — rarity is identity, shown
      // craftable or not (PRESENTATION_WORLD_REWARD_FEEL_01 §20).
      final RecipeOption first = recipes.first;
      expect(first.outputRarity, isNotNull);
      final Finder title = find.text(first.displayName);
      expect(title, findsWidgets);
      expect(
        (tester.widget(title.first) as Text).style!.color,
        RarityStyle.of(first.outputRarity!).ink,
      );

      // The badge word lives on the selected recipe's expanded detail since
      // the compact-row restructure.
      await tester.tap(title.first);
      await tester.pumpAndSettle();
      expect(find.byType(RarityBadge), findsWidgets);
      expect(clippedLines(tester), isEmpty);
    });

    testWidgets('the character sheet names the rank of what is worn', (
      WidgetTester tester,
    ) async {
      // Through the product's own Equip control (see the summary test above
      // for why a direct session call no longer repaints a kept-alive
      // screen). The tunic's tile is the last equipment tile.
      final StrideSession session = await app(tester);
      await tab(tester, 'Inventory');
      await tester.ensureVisible(find.text('Traveler Tunic'));
      await tester.pump();
      await tester.tap(find.text('Equip').last);
      await tester.pumpAndSettle();
      await tab(tester, 'Character');

      // The Combat card sits below the fold since the Steps card joined
      // the sheet (the physical-device polish pass); the list builds
      // lazily, so scroll it into being before asserting on it.
      await tester.scrollUntilVisible(
        find.text('ARMOUR'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ARMOUR'), findsOneWidget);
      expect(find.text('Traveler Tunic'), findsOneWidget);
      final EquippedSummary worn = session.equippedSummary.single;
      expect(find.text(worn.rarity!.label.toUpperCase()), findsWidgets);
      // The empty slot still explains its figure in the page's own words.
      // EPO03 turned this screen into a folio, so the combat ledger sits
      // below the bust and its margin wells rather than in a card near the
      // top — scroll to it. The note itself is unchanged and still worth
      // asserting: an Attack figure with no weapon must say why.
      await tester.scrollUntilVisible(
        find.text('unarmed'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('unarmed'), findsOneWidget);
      expect(clippedLines(tester), isEmpty);
    });
  });
}
