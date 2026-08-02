// M-2 scope: prove the app links stride_core and renders. Simulation tests live
// in packages/stride_core/test, where they run with no Flutter and no emulator.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/main.dart';
import 'package:stride_core/stride_core.dart';

void main() {
  testWidgets('app renders the placeholder and links stride_core', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StrideApp());

    expect(find.text('Project Stride'), findsOneWidget);
    expect(find.text('stride_core ${StrideCore.version}'), findsOneWidget);
  });

  testWidgets('placeholder carries no gameplay affordances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StrideApp());

    // M-2 is a skeleton. A button appearing here would mean gameplay crept in
    // ahead of the reviews that own it.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
