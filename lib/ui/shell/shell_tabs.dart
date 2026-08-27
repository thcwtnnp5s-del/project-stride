/// A handle for switching the shell's tab from inside a screen.
///
/// The shell owns the selected destination as plain widget state — that is
/// correct and stays. But a moment on one tab can point at another: the
/// opportunity banner's "journey now affordable" line is answered on the
/// World tab, and making the player find it by hand is friction exactly
/// where the game wants momentum (Fable V2 Iteration 02, feel-audit item 3).
///
/// This is deliberately a callback carrier, not state: nothing here is
/// durable, nothing notifies, and a screen hosted outside the shell (a
/// pushed route, a component test) simply gets null from [maybeOf] and
/// renders its content untappable rather than crashing.
library;

import 'package:flutter/widgets.dart';

import 'stride_destination.dart';

class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.select, required super.child});

  /// Switches the shell to [destination], as if the tab bar were tapped.
  final ValueChanged<StrideDestination> select;

  static ShellTabs? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTabs>();

  @override
  bool updateShouldNotify(ShellTabs oldWidget) => select != oldWidget.select;
}
