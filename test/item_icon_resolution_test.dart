/// Every shipped item resolves to real, visible icon art.
///
/// ## The device finding this exists for
///
/// Activity Feel & Presentation 01's acceptance pass found Wolf Pelt blank on
/// the victory panel and in Inventory, and both jerkins blank in Craft — an
/// empty dark rectangle where the reward should be. The art was fine: all
/// four icons were generated, blind-QA'd and packaged to
/// `assets/art/v1/item/`. What was missing was four lines in
/// `PixelIcons._itemIcons`, so `itemFor` fell back to the deliberately blank
/// `unknown` slab. Packaging, the lookup table and the content pack are three
/// lists that must agree, and nothing asserted that they did.
///
/// So this test walks the REAL content pack and holds, for every item id:
/// the lookup table has an entry (not the slab), the asset it names loads
/// from the bundle, and the decoded image actually shows something — a
/// mostly-transparent PNG would be the same defect with extra steps.
library;

import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every item in the content pack has visible icon art', (
    WidgetTester tester,
  ) async {
    final List<String> ids = (await tester.runAsync(() async {
      final String text = await rootBundle.loadString(
        'assets/content/v1/items.json',
      );
      final Map<String, Object?> doc = jsonDecode(text) as Map<String, Object?>;
      return <String>[
        for (final Object? raw in doc['entries']! as List<Object?>)
          (raw! as Map<String, Object?>)['id']! as String,
      ];
    }))!;

    expect(ids, isNotEmpty);

    final List<String> missing = <String>[];
    for (final String id in ids) {
      final ContentId item = ContentId.unchecked(id);
      if (!PixelIcons.hasItemIcon(item)) {
        missing.add(id);
        continue;
      }
      final String path = PixelIcons.itemFor(item);
      final int visible = (await tester.runAsync(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(
          (await rootBundle.load(path)).buffer.asUint8List(),
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        expect(image.width, 48, reason: path);
        expect(image.height, 48, reason: path);
        final ByteData pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int count = 0;
        for (int i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) >= 8) count += 1;
        }
        return count;
      }))!;
      // A 48 × 48 icon with fewer than 200 visible pixels is a sliver or a
      // bad export, not an icon; the smallest shipped icon carries ~900.
      expect(visible, greaterThan(200), reason: '$id ($path) is nearly empty');
    }

    expect(
      missing,
      isEmpty,
      reason:
          'these items render the blank `unknown` slab on every surface — '
          'add their packaged icons to PixelIcons._itemIcons',
    );
  });
}
