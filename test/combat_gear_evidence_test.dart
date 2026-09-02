/// Device-size evidence for the VAWO01 weapon round: the same fight, three
/// loadouts, side by side.
///
/// The assertions in `combat_gear_variant_test.dart` prove the *wiring* — that
/// a variant never reaches into the base's sword frames. They cannot prove the
/// thing that actually decides this round, which is whether an empty-handed
/// Traveler reads as empty-handed on a phone (`RULES.md` A-3: the blind device
/// read decides, metrics only triage). So this writes what the stage paints at
/// 393 × 852 for an unarmed, a training-sword and a bronze-sword loadout, at
/// rest and mid-swing, and a human looks at it.
///
/// Gated on `COMBAT_EVIDENCE_DIR`, like `combat_golden_test.dart`. Silent in
/// CI; it asserts nothing a golden would.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/icons/traveler_art.dart';
import 'package:stride/ui/screens/combat/combat_stage.dart';
import 'package:stride_core/stride_core.dart';

import 'support/real_font.dart';

EncounterView _view({int turn = 1, int playerHp = 40, int enemyHp = 20}) =>
    EncounterView(
      enemyId: ContentId.unchecked('enemy.forest_wolf'),
      enemyName: 'Forest Wolf',
      location: ContentId.unchecked('location.whispering_woods'),
      locationName: 'Whispering Woods',
      turn: turn,
      playerHp: playerHp,
      playerMaxHp: 40,
      playerAttack: 3,
      playerDefence: 1,
      enemyHp: enemyHp,
      enemyMaxHp: 20,
      telegraph: false,
      behavior: EnemyBehavior.flurry,
      isBoss: false,
    );

const CombatReport _round = CombatReport(
  succeeded: true,
  enemyName: 'Forest Wolf',
  events: <CombatBeat>[
    PlayerStruckBeat(damage: 7, enemyHpAfter: 13),
    EnemyStruckBeat(damage: 4, playerHpAfter: 36, heavy: false, strikeIndex: 0),
    RoundEndedBeat(turn: 2, telegraph: false),
  ],
);

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(393, 852)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 361, child: RepaintBoundary(child: child)),
    ),
  ),
);

EquipmentVisualState _holding(String? itemId) => itemId == null
    ? EquipmentVisualState.none
    : EquipmentVisualState(
        weapon: EquippedVisualFact(itemId: itemId, tier: 1, toolKind: 'none'),
      );

void main() {
  setUpAll(loadRealFont);
  final String? dir = Platform.environment['COMBAT_EVIDENCE_DIR'];

  Future<void> shot(WidgetTester tester, String name) async {
    if (dir == null || dir.isEmpty) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(CombatStage).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final (String label, String? item) in <(String, String?)>[
    ('unarmed', null),
    ('training', 'item.training_sword'),
    ('bronze', 'item.bronze_sword'),
  ]) {
    testWidgets('$label: the stage at 393 x 852, at rest and mid-swing', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      final EquipmentVisualState eq = _holding(item);
      await tester.pumpWidget(
        _host(CombatStage(view: _view(), report: null, equipment: eq)),
      );
      await tester.pumpAndSettle();

      // The stage decodes on mount; a capture taken before that paints holes.
      await tester.runAsync(() async {
        final BuildContext ctx = tester.element(find.byType(CombatStage));
        for (final String f in CombatAssets.framesFor(
          ContentId.unchecked('enemy.forest_wolf'),
          ContentId.unchecked('location.whispering_woods'),
          traveler: TravelerArt.combatantFor(eq),
        )) {
          await precacheImage(AssetImage(f), ctx);
        }
      });
      await tester.pumpAndSettle();

      final String idleSprite = tester
          .widgetList<GroundedSprite>(find.byType(GroundedSprite))
          .first
          .assetPath;
      expect(
        idleSprite,
        contains(switch (label) {
          'unarmed' => 'traveler_unarmed_idle',
          'bronze' => 'traveler_bronze_idle',
          _ => 'traveler_combat_idle',
        }),
        reason: '$label drew $idleSprite at rest',
      );
      await shot(tester, 'gear_${label}_idle');

      await tester.pumpWidget(
        _host(
          CombatStage(
            view: _view(turn: 2, playerHp: 36, enemyHp: 13),
            report: _round,
            equipment: eq,
          ),
        ),
      );
      await tester.pump();
      // Far enough in for the blade to be out, short of the impact segment.
      await tester.pump(const Duration(milliseconds: 210));
      await shot(tester, 'gear_${label}_swing');
      await tester.pumpAndSettle();
    });
  }
}
