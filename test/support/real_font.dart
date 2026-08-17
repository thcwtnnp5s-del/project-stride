/// Installs a **real font** as the test harness's default.
///
/// ## Why any test that measures or renders type needs this
///
/// `flutter test` ships no font. Its fallback draws every glyph as a filled
/// rectangle roughly 0.84 em wide, where Roboto and SF Pro average nearer 0.55.
/// That has two consequences, and both of them have already cost this project a
/// device pass:
///
/// - **A width measurement taken against it measures the harness.** Strings come
///   out about half again too wide, so an assertion tuned to satisfy it would
///   condemn labels that fit comfortably on a phone — and the natural response,
///   shrinking real type until the fake font is happy, makes the shipped UI
///   worse.
/// - **A golden rendered against it cannot show type at all.** Underlines,
///   weights and clipped descenders all merge into the filled boxes. That is
///   exactly how every string in the product shipped underlined through 93
///   widget tests and four goldens (`MISTAKES.md` M-06).
///
/// Roboto is the right stand-in. The app declares no font family, so it renders
/// in the platform default: Roboto on Android, SF Pro on iOS. The two are close
/// enough in advance width for a layout bound; the square fallback is not close
/// to either.
///
/// **This does not make a golden a judge of type.** Roboto is not SF Pro, and
/// the harness still supplies zero safe-area insets. It moves the goldens from
/// "cannot show type" to "shows a plausible type", which is worth having and is
/// not a substitute for looking at a device.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Registers Roboto from the Flutter SDK's own font cache.
///
/// **Fails rather than skips when the font is missing.** A skipped measurement
/// reports success having measured nothing, which is the failure mode the files
/// that call this exist to remove.
Future<void> loadRealFont() async {
  // `<flutter>/bin/cache/dart-sdk/bin/dart` is what runs a `flutter test`, so
  // the SDK's font cache is three directories up from the executable's own.
  // Derived rather than hardcoded, because this must hold on the Linux and
  // macOS CI runners as well as on Windows.
  Directory dir = File(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 3; i++) {
    dir = dir.parent;
  }
  final Directory fonts = Directory('${dir.path}/artifacts/material_fonts');

  final File regular = File('${fonts.path}/roboto-regular.ttf');
  final File bold = File('${fonts.path}/roboto-bold.ttf');
  if (!regular.existsSync() || !bold.existsSync()) {
    fail(
      'No real font at ${fonts.path}. The tests that call loadRealFont() '
      'measure or render text, and the flutter_test fallback font is ~50% '
      'wider than any font this app ships against — evidence taken against it '
      'is evidence about the harness (MISTAKES.md M-06). Point loadRealFont() '
      'at a real TTF rather than letting those assertions run on square '
      'glyphs.',
    );
  }

  // `Roboto` is the family `ThemeData`'s typography names on the test target
  // platform, and no `StrideType` role sets a family of its own — so
  // registering it here makes it the resolved font for the whole tree rather
  // than something each style has to opt into.
  final FontLoader loader = FontLoader('Roboto')
    ..addFont(regular.readAsBytes().then(ByteData.sublistView))
    ..addFont(bold.readAsBytes().then(ByteData.sublistView));
  await loader.load();
}
