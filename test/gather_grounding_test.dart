/// Every gather-scene subject is grounded, and the scene inventory is honest
/// about how much of itself repeats.
///
/// ## The defect this closes
///
/// The owner's loudest presentation complaint has been that mining, woodcutting
/// and foraging "show a weird isolated object floating in the centre of a
/// scene". `FOUNDATION_H_GATHER.md` found the mechanism, and it was not the one
/// the phrasing suggests. The *geometry* was always right — the subject's base
/// already sat on the stage's ground line. What was missing was light:
///
/// - `GroundedSprite` composites a footprint-derived contact shadow and its own
///   documentation says a bare `PixelAsset` on a background **is** the floating
///   defect;
/// - the Traveler has gone through it since Playable Polish 01;
/// - `AmbientStage._prop` — the thing he is hitting — built a bare
///   `PixelAsset`.
///
/// So every gather scene in the product grounded the man and floated the ore.
///
/// ## What is asserted, and what is deliberately not
///
/// This file asserts **grounding**, which is now true, and **records the
/// duplication**, which is not yet fixed. The second is a ratchet, not an
/// endorsement: 22 nodes currently draw on 12 distinct scenes because 12 of
/// them fall through to an inventory-icon plate and 10 are pixel-identical to
/// another node. That is `GH-01` and `GH-04`, both P0, and both need art that
/// this workstream has not generated yet.
///
/// The ratchet is here because the alternative is worse. `node_art_resolution_test`
/// asserts only that *a* 96² plate with ≥800 opaque pixels exists, which is why
/// twelve icon fallbacks and ten duplicate scenes have shipped CI-green for
/// months. A number that must not grow is how that stops being invisible.
library;

import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_stage.dart' show StageScenery;
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

/// How many nodes currently share their subject plate with another node.
///
/// **This number may fall. It may never rise.** Every reduction is a plate the
/// gather-scene rounds authored; every increase is a new node shipped without
/// one, which is the defect that produced the current figure.
/// Measured, not quoted: **17 of the 22 nodes** share their subject plate with
/// at least one other node, and the 22 nodes draw on **12 distinct plates**.
///
/// `FOUNDATION_H_GATHER.md` reports "10 duplicates" for the same tree. Both are
/// right and they count different things — that audit counted *scenes* whose
/// (backdrop, subject) pair repeats, this counts *nodes* whose subject plate is
/// byte-identical to another's. The distinct-plate figure agrees exactly: 12.
///
/// The worst group is Forgotten Hollow, where **all five nodes are one image**
/// despite yielding two different resources.
const int _knownDuplicateSubjectNodes = 17;

/// The floor on variety. Rises as plates are authored; must never fall.
const int _knownDistinctSubjectPlates = 12;

/// FNV-1a over the asset's bytes, 64-bit, as a grouping key.
///
/// Written out rather than pulling in `package:crypto` for one test: this is
/// grouping identical files, not defending against anything, and a new
/// dependency taken on for a convenience is exactly the incidental drift
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

  Future<List<String>> nodeIds(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final Map<String, Object?> doc =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/content/v1/resource_nodes.json',
                  ),
                )
                as Map<String, Object?>;
        return <String>[
          for (final Object? raw in doc['entries']! as List<Object?>)
            (raw! as Map<String, Object?>)['id']! as String,
        ];
      }))!;

  /// The plate a node actually shows during a gather — the work prop where one
  /// exists, otherwise the vignette. Mirrors `LocationStage`'s own resolution
  /// order exactly; if that changes, this must change with it.
  StageScenery? subjectFor(String id) {
    final String? art = PixelIcons.nodeFor(ContentId.unchecked(id));
    if (art == null) return null;
    return AmbientAssets.workPropFor(art) ?? AmbientAssets.sceneryFor(art);
  }

  testWidgets('every gather subject has a measured footprint', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await nodeIds(tester);
    expect(ids, isNotEmpty);

    final List<String> ungrounded = <String>[];
    for (final String id in ids) {
      final StageScenery? subject = subjectFor(id);
      expect(subject, isNotNull, reason: '$id resolves no gather subject');
      if (SpriteFootprints.byNodeAsset[subject!.assetPath] == null) {
        ungrounded.add('$id -> ${subject.assetPath}');
      }
    }

    expect(
      ungrounded,
      isEmpty,
      reason:
          'These gather subjects have no measured footprint, so '
          'AmbientStage._prop falls back to a bare PixelAsset and they float. '
          'The footprint is emitted by Scripts/art/package-art.js for every '
          'assets/art/v1/node/*.png — a subject missing from it means the '
          'plate is not in that family, or packaging has not been re-run: '
          '$ungrounded',
    );
  });

  testWidgets('the footprint describes the plate it claims to measure', (
    WidgetTester tester,
  ) async {
    // A footprint that disagrees with its plate puts the shadow somewhere the
    // subject is not, which looks like a bad asset rather than a bad number.
    final List<String> ids = await nodeIds(tester);
    for (final String id in ids) {
      final StageScenery subject = subjectFor(id)!;
      final SpriteFootprint f =
          SpriteFootprints.byNodeAsset[subject.assetPath]!;

      expect(
        f.left,
        inInclusiveRange(0, subject.native - 1),
        reason: '$id: contact starts outside the plate',
      );
      expect(
        f.right,
        inInclusiveRange(f.left, subject.native - 1),
        reason: '$id: contact ends outside the plate',
      );
      expect(
        f.bottom,
        inInclusiveRange(0, subject.native - 1),
        reason: '$id: contact row outside the plate',
      );
      expect(
        f.width,
        greaterThan(1),
        reason:
            '$id: a one-pixel contact span means the plate touches the ground '
            'at a point, which no resource face or plant bed does',
      );
    }
  });

  testWidgets('scene duplication does not grow', (WidgetTester tester) async {
    final List<String> ids = await nodeIds(tester);

    // Group by the bytes actually shipped, not by asset path: two paths can be
    // recorded byte-copies of one another, and the player sees the bytes.
    final Map<String, List<String>> byDigest = <String, List<String>>{};
    for (final String id in ids) {
      final StageScenery subject = subjectFor(id)!;
      final String digest = (await tester.runAsync(() async {
        final Uint8List bytes = (await rootBundle.load(
          subject.assetPath,
        )).buffer.asUint8List();
        return _fnv1a(bytes);
      }))!;
      (byDigest[digest] ??= <String>[]).add(id);
    }

    final int duplicated = byDigest.values
        .where((List<String> group) => group.length > 1)
        .fold(0, (int n, List<String> group) => n + group.length);

    expect(
      duplicated,
      lessThanOrEqualTo(_knownDuplicateSubjectNodes),
      reason:
          'A node now shares its subject plate with another that did not '
          'before. ${byDigest.values.where((List<String> g) => g.length > 1)}',
    );

    // The same debt from the other side: variety may only increase. Without
    // this, merging two plates would satisfy the ratchet above while making the
    // product worse.
    expect(
      byDigest.length,
      greaterThanOrEqualTo(_knownDistinctSubjectPlates),
      reason:
          '${byDigest.length} distinct subject plates across ${ids.length} '
          'nodes, down from $_knownDistinctSubjectPlates. Variety went '
          'backwards. Target is ${ids.length}; GATHER_SCENE_DIRECTION_01 lists '
          'the plates that close the gap.',
    );
  });
}
