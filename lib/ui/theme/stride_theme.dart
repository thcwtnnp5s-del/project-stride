/// The `ThemeData` the app runs under.
///
/// Deliberately thin. It exists so `MaterialApp` has something coherent
/// underneath, not as the token store — the tokens are const classes in the
/// files beside this one, and widgets name those directly.
library;

import 'package:flutter/material.dart';

import 'stride_colors.dart';
import 'stride_typography.dart';

ThemeData strideTheme() {
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: StrideColors.surfaceGround,
    canvasColor: StrideColors.surfaceGround,

    // No shine, no gradient, no glow, no shadow, anywhere in the system.
    // Construction and value separation do the work. Material's default ink
    // ripple would be the first motion in an app that specifies none, so it is
    // removed at the root rather than suppressed per-widget.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,

    textTheme: const TextTheme(
      bodyMedium: StrideType.body,
      bodyLarge: StrideType.body,
      titleMedium: StrideType.sectionHeading,
    ),

    colorScheme: const ColorScheme.dark(
      surface: StrideColors.surfaceCard,
      primary: StrideColors.accentSteps,
      onPrimary: StrideColors.surfaceGround,
      onSurface: StrideColors.textPrimary,
    ),
  );
}
