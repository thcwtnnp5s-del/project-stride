/// No two items share a picture.
///
/// ## What this adds to `item_icon_resolution_test`
///
/// That file asserts every item *has* an icon: a 48 × 48 asset with more than
/// 200 visible pixels. It cannot see the defect the owner actually named —
/// **"no two items should feel like lazy variants"** — because a byte-identical
/// copy passes every one of its checks.
///
/// Eleven pairs shipped byte-identical for months underneath it. The
/// justification recorded in `package-art.js` was that a Masterwork piece
/// consumes its donor, so "the copy and its donor almost never share a bag".
/// That is true of the bag and false of the screen: the Craft screen shows 39
/// rows drawn from 21 distinct pictures, donor and copy side by side, and three
/// donors are starter gear worn from minute one.
///
/// So this file asserts the thing a resolution test structurally cannot: that
/// the pictures differ.
library;

import 'dart:convert' show jsonDecode;
import 'dart:ui' as ui;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

/// FNV-1a over the bytes. Grouping identical files, not defending against
/// anything — a dependency taken on for convenience is the incidental drift
/// `RULES.md` G-2 exists to prevent.
String _fnv1a(Uint8List bytes) {
  int hash = 0xcbf29ce484222325;
  for (final int b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no two items resolve a byte-identical icon', (
    WidgetTester tester,
  ) async {
    final List<String> ids = (await tester.runAsync(() async {
      final Map<String, Object?> doc =
          jsonDecode(await rootBundle.loadString('assets/content/v1/items.json'))
              as Map<String, Object?>;
      return <String>[
        for (final Object? raw in doc['entries']! as List<Object?>)
          (raw! as Map<String, Object?>)['id']! as String,
      ];
    }))!;
    expect(ids, isNotEmpty);

    final Map<String, List<String>> byDigest = <String, List<String>>{};
    for (final String id in ids) {
      final ContentId item = ContentId.unchecked(id);
      if (!PixelIcons.hasItemIcon(item)) continue; // the other file's assertion
      final String path = PixelIcons.itemFor(item);
      final String digest = (await tester.runAsync(() async {
        return _fnv1a((await rootBundle.load(path)).buffer.asUint8List());
      }))!;
      (byDigest[digest] ??= <String>[]).add(id);
    }

    final Iterable<List<String>> shared = byDigest.values.where(
      (List<String> g) => g.length > 1,
    );
    expect(
      shared,
      isEmpty,
      reason:
          'These items draw the same picture, so the player cannot tell them '
          'apart in the bag or side by side on the Craft screen: $shared',
    );
  });

  testWidgets('the ores the owner named are not one drawing in two colours', (
    WidgetTester tester,
  ) async {
    // Drift D-5 by name: Copper Ore and Tin Ore shipped as the same round
    // boulder at 90.5% silhouette overlap, differing only by inclusion colour
    // — a defect this project's own style spec bans and shipped anyway.
    //
    // Asserted on the SILHOUETTE rather than on the bytes, because a recolour
    // passes a byte comparison while being exactly the thing that was wrong.
    Future<List<bool>> mask(String path) async =>
        (await tester.runAsync(() async {
          final Uint8List b = (await rootBundle.load(path)).buffer.asUint8List();
          // The PNG is decoded by the framework elsewhere; here the alpha
          // channel is read through the same codec the app uses.
          final ui.Codec codec = await ui.instantiateImageCodec(b);
          final ui.FrameInfo frame = await codec.getNextFrame();
          final data = await frame.image.toByteData();
          return <bool>[
            for (int i = 3; i < data!.lengthInBytes; i += 4)
              data.getUint8(i) >= 8,
          ];
        }))!;

    final List<bool> copper = await mask('assets/art/v1/item/copper_ore.png');
    final List<bool> tin = await mask('assets/art/v1/item/tin_ore.png');
    expect(copper, hasLength(tin.length));

    int both = 0;
    int either = 0;
    for (int i = 0; i < copper.length; i += 1) {
      if (copper[i] || tin[i]) either += 1;
      if (copper[i] && tin[i]) both += 1;
    }
    final double iou = either == 0 ? 0 : both / either;

    expect(
      iou,
      lessThan(0.75),
      reason:
          'Copper Ore and Tin Ore overlap ${(iou * 100).toStringAsFixed(1)}% by '
          'silhouette. They were 90.5% — the same boulder in two colours. '
          'Different materials must differ in SHAPE, not only in hue.',
    );
  });
  // ---------------------------------------------------------------- EPO03

  /// The EPO03 collision round (`MILESTONES/evidence/EPO03/wave2/
  /// ITEMS_report.md`, brief `wave1/DIR-09_item_art.md`).
  ///
  /// **These are named-pair ceilings, not a global threshold, and the reason
  /// matters.** Distinct, unconfusable pairs in this set measure 0.85-0.90
  /// unaligned — `ram_wool` against `ember_core` is 0.90 and nobody has ever
  /// mistaken wool for a core. A global IoU threshold would therefore either
  /// pass everything or condemn the whole set. So a ceiling is written here
  /// only where the FIX WAS ITSELF A SILHOUETTE CHANGE, and it records what
  /// that change achieved so it cannot silently regress.
  ///
  /// The metric is triage. The verdict was the x2 sheet read on `#1e1e1e`
  /// (M-04) — every one of these pairs was looked at by eye at the size the
  /// phone draws it before it was accepted.
  Future<List<bool>> mask(WidgetTester tester, String id) async =>
      (await tester.runAsync(() async {
        final Uint8List b =
            (await rootBundle.load(
              'assets/art/v1/item/$id.png',
            )).buffer.asUint8List();
        final ui.Codec codec = await ui.instantiateImageCodec(b);
        final ui.FrameInfo frame = await codec.getNextFrame();
        final data = await frame.image.toByteData();
        return <bool>[
          for (int i = 3; i < data!.lengthInBytes; i += 4) data.getUint8(i) >= 8,
        ];
      }))!;

  double iouOf(List<bool> a, List<bool> b) {
    int both = 0;
    int either = 0;
    for (int i = 0; i < a.length; i += 1) {
      if (a[i] || b[i]) either += 1;
      if (a[i] && b[i]) both += 1;
    }
    return either == 0 ? 0 : both / either;
  }

  testWidgets('the four hide vests are four silhouettes, not one', (
    WidgetTester tester,
  ) async {
    // They shipped as one brown colour mass whose only tells were under 6 px:
    // 0.85-0.88 pairwise. The replacements differ by fur outline, tusks across
    // the chest, a smooth sleeveless tank, and a hooded coat with a longer hem.
    const List<String> vests = <String>[
      'wolfhide_jerkin',
      'tuskbound_jerkin',
      'frostlined_jerkin',
      'bearhide_coat',
    ];
    final Map<String, List<bool>> masks = <String, List<bool>>{
      for (final String id in vests) id: await mask(tester, id),
    };
    for (int i = 0; i < vests.length; i += 1) {
      for (int j = i + 1; j < vests.length; j += 1) {
        final double iou = iouOf(masks[vests[i]]!, masks[vests[j]]!);
        expect(
          iou,
          lessThan(0.83),
          reason:
              '${vests[i]} and ${vests[j]} overlap '
              '${(iou * 100).toStringAsFixed(1)}% by silhouette. The armour '
              'pocket shows all four at once; they were 85-88% and one brown '
              'mass. A vest may not be told from another by hue alone.',
        );
      }
    }
  });

  testWidgets('the two stews are two vessels', (WidgetTester tester) async {
    // Two dark iron pots that went dark-on-dark against each other and against
    // the green broth bowl (0.896). `hearty_stew` now takes a pale wooden bowl
    // with a ladle standing in it and leaves the cauldron to `expedition_stew`.
    for (final String other in <String>['expedition_stew', 'herb_broth']) {
      final double iou = iouOf(
        await mask(tester, 'hearty_stew'),
        await mask(tester, other),
      );
      expect(
        iou,
        lessThan(0.80),
        reason:
            'hearty_stew and $other overlap '
            '${(iou * 100).toStringAsFixed(1)}% by silhouette. The cooking '
            'list draws them on adjacent rows.',
      );
    }
  });

  testWidgets('no icon is too thin to read at 48 dp', (
    WidgetTester tester,
  ) async {
    // `bronze_longsword` was the thinnest icon in the game at 12% fill and
    // SHORTER than the uncommon sword it outranks; `pristine_horn` was a 12%
    // sliver. An epic is never the smallest thing on the screen.
    for (final String id in <String>[
      'bronze_longsword',
      'pristine_horn',
      'pristine_wolf_fang',
      'hornpoint_pickaxe',
      'frost_claw',
    ]) {
      final List<bool> m = await mask(tester, id);
      final int on = m.where((bool v) => v).length;
      final double fill = on / m.length;
      expect(
        fill,
        greaterThanOrEqualTo(0.20),
        reason:
            '$id fills only ${(fill * 100).toStringAsFixed(1)}% of its 48x48 '
            'frame. Under a fifth, an icon reads as a scratch on the tile.',
      );
    }
  });

  testWidgets('the longsword out-reaches the swords it outranks', (
    WidgetTester tester,
  ) async {
    // Family language, binding: "epic is never the smallest".
    //
    // Measured as REACH — the diagonal of the ink's bounding box — and not as
    // a pixel count, because a pixel count answers a different question. The
    // uncommon `bronze_sword` carries MORE ink than the epic (585 px against
    // 549) purely because its blade is broader; the epic is the longer weapon,
    // which is what the eye reads and what DIR-09 asked for. Counting area
    // would have condemned a correct icon and rewarded a fatter one.
    Future<int> reach(String id) async {
      final List<bool> m = await mask(tester, id);
      int x0 = 48, y0 = 48, x1 = -1, y1 = -1;
      for (int y = 0; y < 48; y += 1) {
        for (int x = 0; x < 48; x += 1) {
          if (!m[y * 48 + x]) continue;
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
      final int w = x1 - x0 + 1;
      final int h = y1 - y0 + 1;
      return w * w + h * h; // squared diagonal; ordering is all that is used
    }

    final int epic = await reach('bronze_longsword');
    for (final String lesser in <String>[
      'training_sword',
      'bronze_sword',
      'fanghilt_sword',
    ]) {
      expect(
        epic,
        greaterThan(await reach(lesser)),
        reason:
            'bronze_longsword does not out-reach $lesser. It shipped at 12% '
            'fill and SHORTER than the uncommon sword it outranks; the epic '
            'must be the longest blade in the case.',
      );
    }
  });

  testWidgets('the three reclaim crates show three different heads', (
    WidgetTester tester,
  ) async {
    // They shipped as three identical crates at 0.90-0.93, told apart only by
    // an illegible ghost stamp on the lid. The crate BODY is deliberately
    // shared — one crate motif is the recipe-art language recorded in
    // `package-art.js` — so this ceiling is set from what opening the lid and
    // standing a different bronze head in it actually achieved, and is a
    // tightening of a previously unbounded case, not a relaxation of an
    // existing one. The verdict remains the x2 sheet: axe blade, pick head,
    // breastplate.
    const List<String> crates = <String>[
      'reclaim_axe',
      'reclaim_pickaxe',
      'reclaim_chestplate',
    ];
    final Map<String, List<bool>> masks = <String, List<bool>>{
      for (final String id in crates) id: await mask(tester, id),
    };
    for (int i = 0; i < crates.length; i += 1) {
      for (int j = i + 1; j < crates.length; j += 1) {
        final double iou = iouOf(masks[crates[i]]!, masks[crates[j]]!);
        expect(
          iou,
          lessThan(0.89),
          reason:
              '${crates[i]} and ${crates[j]} overlap '
              '${(iou * 100).toStringAsFixed(1)}%. They were 90-93%: three '
              'identical boxes on three adjacent Craft rows. A head must '
              'break the crate outline.',
        );
      }
    }
  });
}
