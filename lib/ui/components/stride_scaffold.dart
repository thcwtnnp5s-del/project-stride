/// The page shell, and **the only place in the app that handles safe areas**.
///
/// No descendant calls `SafeArea`. A second one inside the first silently
/// double-insets, which is the classic way a tab bar acquires a 34 px float
/// under it on exactly one device family — and it is invisible on every other
/// device, including the one the developer is holding.
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';

class StrideScaffold extends StatelessWidget {
  const StrideScaffold({
    super.key,
    required this.header,
    required this.body,
    this.bottomBar,
  });

  final Widget header;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);
    return ColoredBox(
      color: StrideColors.surfaceGround,
      child: Column(
        children: <Widget>[
          // The status bar / Dynamic Island region. Painted in the page ground
          // rather than left transparent, so the header does not appear to
          // float on whatever the platform draws behind it.
          SizedBox(height: inset.top),
          header,
          Expanded(child: body),
          // The bar's own ground extends into the bottom inset rather than
          // sitting above it. A tab bar that stops short of the home indicator
          // reads as a floating panel, not as chrome.
          //
          // **The inset is now the bar's to paint, not the scaffold's**
          // (EPO03, `DIR-15_mobile_ux.md` §2 item 4). This used to be a
          // `ColoredBox(surfaceCard)` wrapped around the bar, which was right
          // while the bar was a flat fill and became a defect the moment it
          // became leather: under a leather strap it put a flat `#201C17`
          // rectangle across the bottom 34 pt of a notched device — a seam on
          // every screen, invisible on every phone without an inset, including
          // the developer's simulator.
          //
          // Passing the figure down instead of painting it means the material
          // runs to the bottom of the glass whatever the material is, and this
          // file keeps being the only place in the app that reads a safe area.
          if (bottomBar != null)
            _BottomInset(inset: inset.bottom, child: bottomBar!),
        ],
      ),
    );
  }
}

/// The bottom safe-area figure, published downward so the bar can paint it in
/// its own material.
///
/// An inherited widget rather than a constructor argument because
/// [StrideScaffold] is handed a **built** `bottomBar` and must not know what
/// kind of bar it is. This keeps the file's one invariant intact — no
/// descendant calls `SafeArea`, and exactly one place in the app reads a view
/// padding — while letting the bar decide what the inset is made of.
///
/// Absent, it is zero: a bar built directly in a test paints no inset and is
/// exactly 64 dp, which is what `band_plate_test.dart` measures.
class StrideBottomInset extends InheritedWidget {
  const StrideBottomInset({
    super.key,
    required this.inset,
    required super.child,
  });

  final double inset;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StrideBottomInset>()
          ?.inset ??
      0;

  @override
  bool updateShouldNotify(StrideBottomInset old) => old.inset != inset;
}

class _BottomInset extends StatelessWidget {
  const _BottomInset({required this.inset, required this.child});

  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      StrideBottomInset(inset: inset, child: child);
}
