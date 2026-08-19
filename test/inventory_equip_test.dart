/// The Inventory screen's Equip / Unequip control.
///
/// A new game grants the starting loadout to inventory only; nothing is
/// equipped, and gathering nodes require an *equipped* tool. These cases prove
/// the product UI can put a tool in the slot the engine reads, swap it, and
/// take it off again — through `SessionController`, with the tile marker and
/// the slot summary reading from the session's projections.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/stride_typography.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId kAxe = ContentId.unchecked('item.training_axe');
final ContentId kPickaxe = ContentId.unchecked('item.training_pickaxe');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('stride_equip'));

  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close. The directory is under
      // systemTemp and the OS reclaims it.
    }
  });

  /// A cold launch, booted inside `runAsync` (real file I/O never completes
  /// under `FakeAsync`), sized to the phone reference, and torn down before
  /// the framework checks for the controller's live result timer.
  Future<StrideSession> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: const <SyncFetch>[]),
      ),
    ))!;
    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    return session;
  }

  SessionController controllerInTree() =>
      (find.byType(SessionScope).evaluate().first.widget as SessionScope)
          .notifier!;

  /// Taps the control inside the tile whose name is [item], and waits for the
  /// session to reach [until] and the controller to leave `busy`.
  Future<void> tapOnTile(
    WidgetTester tester,
    String item,
    String control, {
    required bool Function() until,
  }) async {
    // The tile's name label specifically — once equipped, the slot summary
    // shows the same string in a different style.
    final Finder name = find.byWidgetPredicate(
      (Widget w) =>
          w is Text && w.data == item && w.style == StrideType.itemName,
    );
    final Finder tile = find.ancestor(
      of: name,
      matching: find.byType(Container),
    );
    final Finder button = find.descendant(
      of: tile.first,
      matching: find.widgetWithText(StrideButton, control),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(button);
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!until() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(until(), isTrue, reason: 'the tapped action did not complete');
    for (int i = 0; i < 250 && controllerInTree().busy; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    expect(controllerInTree().busy, isFalse);
  }

  testWidgets('a new game shows the loadout with Equip and empty slots', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);

    for (final String name in <String>[
      'Training Sword',
      'Training Axe',
      'Training Pickaxe',
      'Traveler Tunic',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.widgetWithText(StrideButton, 'Equip'), findsNWidgets(4));
    expect(find.widgetWithText(StrideButton, 'Unequip'), findsNothing);
    expect(find.text('EQUIPPED'), findsNothing);

    // The three slot labels, each over an em dash.
    for (final String slot in <String>['WEAPON', 'ARMOUR', 'TOOL']) {
      expect(find.text(slot), findsOneWidget);
    }
    expect(find.text('—'), findsNWidgets(3));
    for (final EquipmentSlot slot in EquipmentSlot.values) {
      expect(session.equippedIn(slot), isNull);
    }
  });

  testWidgets('Equip on the Training Axe marks it and fills the Tool slot', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);

    await tapOnTile(
      tester,
      'Training Axe',
      'Equip',
      until: () => session.equippedIn(EquipmentSlot.tool) == kAxe,
    );

    expect(find.text('EQUIPPED'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Unequip'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Equip'), findsNWidgets(3));
    // The tile name and the slot summary both say Training Axe now.
    expect(find.text('Training Axe'), findsNWidgets(2));
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Equipped Training Axe.'), findsOneWidget);
    expect(session.isEquipped(kAxe), isTrue);
  });

  testWidgets('equipping the Pickaxe swaps the tool slot; Unequip clears it', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);

    await tapOnTile(
      tester,
      'Training Axe',
      'Equip',
      until: () => session.equippedIn(EquipmentSlot.tool) == kAxe,
    );
    await tapOnTile(
      tester,
      'Training Pickaxe',
      'Equip',
      until: () => session.equippedIn(EquipmentSlot.tool) == kPickaxe,
    );

    // One slot, one occupant: the axe came off when the pickaxe went on.
    expect(session.isEquipped(kAxe), isFalse);
    expect(find.text('EQUIPPED'), findsOneWidget);
    expect(find.text('Training Pickaxe'), findsNWidgets(2));
    expect(find.text('Training Axe'), findsOneWidget);

    await tapOnTile(
      tester,
      'Training Pickaxe',
      'Unequip',
      until: () => session.equippedIn(EquipmentSlot.tool) == null,
    );

    expect(find.text('EQUIPPED'), findsNothing);
    expect(find.widgetWithText(StrideButton, 'Unequip'), findsNothing);
    expect(find.widgetWithText(StrideButton, 'Equip'), findsNWidgets(4));
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('Set Training Pickaxe aside.'), findsOneWidget);
  });
}
