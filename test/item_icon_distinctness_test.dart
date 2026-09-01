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
}
