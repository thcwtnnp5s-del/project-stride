/// Every shipped resource node resolves to real, visible stage art.
///
/// ## The device finding this exists for
///
/// PRESENTATION_WORLD_REWARD_FEEL_01 B-3: the Hardened Copper Seam rendered a
/// large empty activity stage on the owner's phone. The node was added by
/// REGIONAL_CONTENT_PACK_01 (`resource_node.hardened_copper_seam`, behind the
/// Stonefall Lift), and no vignette was ever generated for it —
/// `PixelIcons._nodeArt` and `AmbientAssets._scenery` simply had no entry, so
/// the stage drew a figure mining nothing.
///
/// This is the same three-lists-must-agree defect class as
/// `item_icon_resolution_test` (M-family: the content pack, the lookup table
/// and the packaged asset), asserted for the node family: for every node the
/// content pack ships, the art table has an entry, the scenery table has its
/// measured bounds, the asset loads, and the decoded image shows something.
library;

import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_stage.dart' show StageScenery;
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every resource node in the content pack has stage art', (
    WidgetTester tester,
  ) async {
    final List<String> ids = (await tester.runAsync(() async {
      final String text = await rootBundle.loadString(
        'assets/content/v1/resource_nodes.json',
      );
      final Map<String, Object?> doc = jsonDecode(text) as Map<String, Object?>;
      return <String>[
        for (final Object? raw in doc['entries']! as List<Object?>)
          (raw! as Map<String, Object?>)['id']! as String,
      ];
    }))!;

    expect(ids, isNotEmpty);

    final List<String> missingArt = <String>[];
    final List<String> missingScenery = <String>[];
    for (final String id in ids) {
      final ContentId node = ContentId.unchecked(id);
      final String? path = PixelIcons.nodeFor(node);
      if (path == null) {
        missingArt.add(id);
        continue;
      }
      final StageScenery? scenery = AmbientAssets.sceneryFor(path);
      if (scenery == null) {
        missingScenery.add(id);
        continue;
      }

      final int visible = (await tester.runAsync(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(
          (await rootBundle.load(path)).buffer.asUint8List(),
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        expect(image.width, 96, reason: path);
        expect(image.height, 96, reason: path);
        final ByteData pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int count = 0;
        for (int i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) >= 8) count += 1;
        }
        return count;
      }))!;
      // A 96 × 96 vignette with fewer than 800 visible pixels is a sliver or
      // a bad export, not a place; the sparsest shipped vignette carries
      // thousands.
      expect(visible, greaterThan(800), reason: '$id ($path) is nearly empty');
    }

    expect(
      missingArt,
      isEmpty,
      reason:
          'These nodes have no entry in PixelIcons._nodeArt, so their '
          'activity stage renders empty — the exact B-3 defect: $missingArt',
    );
    expect(
      missingScenery,
      isEmpty,
      reason:
          'These node vignettes have no measured StageScenery bounds in '
          'AmbientAssets._scenery, so the stage cannot place them: '
          '$missingScenery',
    );
  });
}
