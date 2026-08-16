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
          if (bottomBar != null)
            // The bar's own ground extends into the bottom inset rather than
            // sitting above it. A tab bar that stops short of the home
            // indicator reads as a floating panel, not as chrome.
            ColoredBox(
              color: StrideColors.surfaceCard,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  bottomBar!,
                  SizedBox(height: inset.bottom),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
