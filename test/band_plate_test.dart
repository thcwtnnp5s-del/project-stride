/// The FMPO02 wave 2 raster integration, measured rather than asserted in prose.
///
/// Three claims, all of them the kind that fail silently:
///
/// 1. **Every registered surface resolves.** `PanelSurfaces` names ten tiles by
///    path. A path that is right in the registry and wrong in `pubspec.yaml`
///    produces no error anywhere — `PixelFrame` and `SurfaceFill` swallow decode
///    failures on purpose, because a missing raster is a material change and
///    never a crash. So the *only* place a typo can be caught is a test that
///    actually loads all ten.
///
/// 2. **Every band clears 4.5:1 under body type.** A band is the one piece of
///    authored chrome that sits *under* words, and PROD-UI bought that by
///    applying a per-band linear-light gain at packaging time. A re-roll that
///    skipped `--textsafe` would put the title on a 4.26:1 ground and nothing
///    else in the build would notice. The margin is thin by construction —
///    `band_forge` measures 4.519:1 — which is exactly why it is measured from
///    the shipped PNG and not taken from the report.
///
/// 3. **The band registry is complete and the mappings are the ones reviewed.**
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/band_plate.dart';
import 'package:stride_core/stride_core.dart' show LocationKind, Terrain;
import 'package:stride/ui/components/screen_header.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/shell/stride_destination.dart';
import 'package:stride/ui/components/panel_skin.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride/ui/theme/stride_metrics.dart';

/// WCAG relative luminance, linearised — the same arithmetic
/// `Scripts/art/check-art-palette.js` uses, deliberately, so the guard and this
/// test cannot disagree about what "brighter" means. A naive weighted mean of
/// the gamma-encoded values answers the perceptual question wrong, which is the
/// whole reason the ceiling and this floor are both expressed in it.
double _luminance(int r, int g, int b) {
  double channel(int c) {
    final double s = c / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return (0.2126 * channel(r)) + (0.7152 * channel(g)) + (0.0722 * channel(b));
}

void main() {
  group('the surface registry resolves', () {
    testWidgets('every authored tile decodes at the path the registry names', (
      WidgetTester tester,
    ) async {
      // A `SectionCard` is pumped per surface so the failure, if there is one,
      // points at the call site shape the product actually uses — and so the
      // precache runs against a real element with a real image configuration.
      for (final MapEntry<PanelSurface, SurfaceTile> entry
          in PanelSurfaces.authored.entries) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 300,
                child: SectionCard(
                  surface: entry.key,
                  child: const SizedBox(height: 40),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(SurfaceFill), findsOneWidget, reason: entry.key.name);

        final BuildContext context = tester.element(find.byType(SectionCard));
        await tester.runAsync(() async {
          await precacheImage(
            AssetImage(entry.value.assetPath),
            context,
            onError: (Object e, StackTrace? _) => fail(
              '${entry.key.name}: ${entry.value.assetPath} did not decode. '
              'Check the pubspec row and the file name — a surface that fails '
              'to load degrades silently to the flat card, so nothing else in '
              'the build will tell you. ($e)',
            ),
          );
        });
      }
    });

    test('every surface but none has a tile, and this round shipped ten', () {
      // `none` is the flat fill by construction; every other member is a
      // screen family, and one without a tile is a family that quietly lost
      // its material.
      expect(PanelSurfaces.of(PanelSurface.none), isNull);
      for (final PanelSurface s in PanelSurface.values) {
        if (s == PanelSurface.none) continue;
        expect(PanelSurfaces.of(s), isNotNull, reason: '${s.name} has no tile');
      }

      // The ten this integration landed, named rather than counted: the
      // registry is shared, and asserting a total would make this test fail
      // the next time a different round adds an eleventh material — which is
      // a false alarm, not a regression.
      const List<PanelSurface> fmpo02 = <PanelSurface>[
        PanelSurface.journalLeaf,
        PanelSurface.oilcloth,
        PanelSurface.buckram,
        PanelSurface.leather,
        PanelSurface.benchOak,
        PanelSurface.steel,
        PanelSurface.slate,
        PanelSurface.chartVellum,
        PanelSurface.cork,
        PanelSurface.planLinen,
      ];
      for (final PanelSurface s in fmpo02) {
        final SurfaceTile tile = PanelSurfaces.of(s)!;
        expect(tile.native, 32, reason: s.name);
        expect(tile.scale, 2, reason: s.name);
        expect(tile.assetPath, startsWith('assets/ui/v1/surface/grain_'));
      }
    });
  });

  group('the button plates declare what their PNGs actually are', () {
    test('measured geometry, not the brief\'s', () {
      // `ART-02` asked for corner 8 / band 4 and corner 6 / band 3. PixelLab
      // drew a thinner rim than that on every candidate, and declaring the
      // brief over the asset is the defect production plan § 3.2.1 exists to
      // prevent. These are the sidecars' figures.
      expect(ButtonPlates.primary.nativeWidth, 58);
      expect(ButtonPlates.primary.nativeHeight, 26);
      expect(ButtonPlates.primary.corner, 4);
      expect(ButtonPlates.compact.nativeWidth, 46);
      expect(ButtonPlates.compact.nativeHeight, 22);
      expect(ButtonPlates.compact.corner, 5);
      expect(ButtonPlates.compact.band, 2);

      // The one deliberate divergence, and the reason for it: `btn_plate`
      // measures band 0, which `PanelSkin` refuses because a frame with no
      // material depth is a surface. Declaring 1 costs two logical px of inset
      // the label had to spare; weakening the assert would cost every panel
      // that comes after.
      expect(ButtonPlates.primary.band, 1);
      expect(ButtonPlates.primary.inset, 2);
    });
  });

  group('the band registry', () {
    test('every band names a file under assets/ui/v1/band', () {
      for (final StrideBand b in StrideBand.values) {
        expect(
          StrideBands.pathOf(b),
          startsWith('assets/ui/v1/band/band_'),
          reason: b.name,
        );
      }
      expect(StrideBands.authored, hasLength(StrideBand.values.length));
    });

    test('the station and trade mappings are the ones reviewed', () {
      // Smithing and Woodcutting deliberately share their band with the Craft
      // station they work at: a player who learns the forge on one screen
      // meets the same forge at the head of the other.
      expect(StrideBands.forStation('forge'), StrideBand.forge);
      expect(StrideBands.forStation('woodbench'), StrideBand.bench);
      expect(StrideBands.forStation('cookfire'), StrideBand.cookfire);
      expect(StrideBands.forStation('nowhere'), isNull);

      expect(StrideBands.forSkill('mining'), StrideBand.mining);
      expect(StrideBands.forSkill('foraging'), StrideBand.foraging);
      expect(StrideBands.forSkill('woodcutting'), StrideBand.bench);
      expect(StrideBands.forSkill('smithing'), StrideBand.forge);
      expect(StrideBands.forSkill('cooking'), StrideBand.cookfire);
      expect(StrideBands.forSkill('alchemy'), isNull);
    });

    test('the expedition kit takes the band of the place it is packed for', () {
      // FMPO02 wave 3, FINAL-10 #2. The strip above `Expedition kit` was
      // `adventureTrail` everywhere, and the review's diff found it
      // **100.0 % pixel-identical** between a grassland settlement, a deep
      // forest and the inside of a mine — a split-rail fence nailed above the
      // ore seams. These five outcomes are the routing that ended that, and
      // they are the whole function: `PlaceIdentity` has four terrains and
      // four kinds, and every combination lands on a row below.
      StrideBand? at(LocationKind kind, Terrain terrain) =>
          StrideBands.forPlace((kind: kind, terrain: terrain));

      // Haven's Rest: a settlement on open ground keeps the road out.
      expect(at(LocationKind.haven, Terrain.grassland),
          StrideBand.adventureTrail);
      // The Whispering Woods: hedgerow and herb, not a fence.
      expect(at(LocationKind.wilds, Terrain.forest), StrideBand.foraging);
      // Stonefall: the cut face, whichever way it is asked.
      expect(at(LocationKind.worksite, Terrain.foothills), StrideBand.mining);
      expect(at(LocationKind.wilds, Terrain.foothills), StrideBand.mining);
      // A quarry laid on grass is still a cutting: kind beats terrain.
      expect(at(LocationKind.worksite, Terrain.grassland), StrideBand.mining);
      // Frostmere: gathering under snow, on the closest authored ground.
      expect(at(LocationKind.wilds, Terrain.alpine), StrideBand.foraging);
      // The Forgotten Hollow: the boss's ground gets nothing. A cheerful
      // strip of trail over the one location with a boss in it would be the
      // same mistake at a different address.
      for (final Terrain t in Terrain.values) {
        expect(at(LocationKind.perilous, t), isNull, reason: t.name);
      }
      // Exhaustive: no pair falls through to a null the caller did not mean.
      for (final LocationKind k in LocationKind.values) {
        for (final Terrain t in Terrain.values) {
          expect(
            at(k, t),
            k == LocationKind.perilous ? isNull : isNotNull,
            reason: '${k.name} · ${t.name}',
          );
        }
      }
    });

    testWidgets('a band is drawn ×1 as a picture, never scaled to fit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              // Narrower than the 384 the band is authored at: it must clip,
              // not shrink. There is no integer scale at which 384 fits 320.
              width: 320,
              child: BandPlate(band: StrideBand.forge, title: 'Forge'),
            ),
          ),
        ),
      );
      final PixelScene scene = tester.widget<PixelScene>(
        find.byType(PixelScene),
      );
      expect(scene.scale, 1);
      expect(scene.nativeWidth, 384);
      expect(scene.nativeHeight, 48);
      expect(scene.displayWidth, 384);
      expect(tester.getSize(find.byType(BandPlate)).height, 48);
    });
  });

  group('the chrome edges cost no layout', () {
    // The welt and the shelf replace painted lines, and both reserve their
    // room out of space their container already had: the tab bar's six tabs
    // give up 8 of their 64 dp, and the header spends 12 of the 14 dp of slack
    // between its 47 dp content box and its 61 dp minimum. If either grows the
    // bar it terminates, every screen in the product loses that much body
    // height at once — and on Adventure, where a one-press entry already sits
    // near the fold, that is measured in controls the thumb can no longer
    // reach.
    testWidgets('the header is still 61 dp at scale 1, shelf and all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(393, 852)),
            // A Column, because that is what `StrideScaffold` gives the
            // header: unbounded height, so the bar shrink-wraps its own
            // content instead of filling whatever it is handed.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ScreenHeader(
                  eyebrow: 'SETTLEMENT',
                  title: "Haven's Rest",
                  rule: StrideColors.actionEdge,
                  trailing: BankedStepsReadout(bankedSteps: 455281),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ScreenHeader)).height,
        StrideGeometry.headerMinHeight,
      );
      expect(find.byType(EdgeStrip), findsOneWidget);
    });

    testWidgets('a header with no rule has no shelf and no bottom room', (
      WidgetTester tester,
    ) async {
      // A pushed route is already a modal layer: `rule` said it needs no end
      // before FMPO02 and still says so. The shelf must not arrive uninvited.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(393, 852)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ScreenHeader(eyebrow: 'SKILLS', title: 'Smithing'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(EdgeStrip), findsNothing);
      expect(
        tester.getSize(find.byType(ScreenHeader)).height,
        StrideGeometry.headerMinHeight,
      );
    });

    testWidgets('the tab bar is still 64 dp, welt and all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(393, 852)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: StrideTabBar(
                selected: StrideDestination.values.first,
                onSelect: (StrideDestination _) {},
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(StrideTabBar)).height,
        StrideGeometry.tabBarHeight,
      );
      expect(find.byType(EdgeStrip), findsOneWidget);
      expect(
        tester.getSize(find.byType(EdgeStrip)).height,
        StrideTabBar.weltHeight,
      );
    });
  });

  group('bands are text-safe', () {
    testWidgets('every shipped band clears 4.5:1 against textPrimary', (
      WidgetTester tester,
    ) async {
      // Measured off the shipped PNG, not read out of the round report. The
      // margin is roughly 0.02 of a ratio point — `band_forge` lands at
      // 4.519:1 — so a re-roll that forgot the packaging gain would fail here
      // and nowhere else.
      const double textPrimaryL = 0.80635; // #F0E7D8, computed below and pinned
      final int r = (StrideColors.textPrimary.r * 255).round();
      final int g = (StrideColors.textPrimary.g * 255).round();
      final int b = (StrideColors.textPrimary.b * 255).round();
      expect(
        _luminance(r, g, b),
        closeTo(textPrimaryL, 0.0005),
        reason: 'textPrimary moved; the whole band exposure is calibrated to it',
      );

      for (final StrideBand band in StrideBand.values) {
        final String path = StrideBands.pathOf(band);
        late double brightest;
        await tester.runAsync(() async {
          final Uint8List bytes = await File(path).readAsBytes();
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frame = await codec.getNextFrame();
          final ByteData? raw = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(raw, isNotNull, reason: path);
          final Uint8List px = raw!.buffer.asUint8List();
          double max = 0;
          for (int i = 0; i < px.length; i += 4) {
            if (px[i + 3] == 0) continue;
            final double l = _luminance(px[i], px[i + 1], px[i + 2]);
            if (l > max) max = l;
          }
          brightest = max;
        });

        final double ratio = (textPrimaryL + 0.05) / (brightest + 0.05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${band.name}: brightest pixel L=$brightest gives $ratio:1 under '
              'body type. Re-run tools/band-batch.js WITH --textsafe.',
        );
      }
    });
  });
}
