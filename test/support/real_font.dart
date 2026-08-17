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

/// Registers Roboto from the copy checked in beside this file.
///
/// **Fails rather than skips when the font is missing.** A skipped measurement
/// reports success having measured nothing, which is the failure mode the files
/// that call this exist to remove. That is unchanged; only where the bytes come
/// from has changed.
///
/// ## Why the font is vendored rather than read from the SDK
///
/// This used to derive the path from `Platform.resolvedExecutable` — three
/// parents up to `<flutter>/bin/cache`, then `artifacts/material_fonts`. That
/// works on the development machine and did not work on the Linux CI runner,
/// where the directory resolved and did not contain the fonts.
///
/// Two attempts were made before giving up on it. `flutter precache --universal`
/// fetched 2 of 11 artifacts and skipped Material Fonts, because
/// `flutter-action`'s `cache: true` restores each artifact's *stamp file* and
/// precache believes the stamp. Adding `--force` made the download happen —
/// the log shows `[1/11] Material Fonts` — and `loadRealFont` still could not
/// find the files at the derived path.
///
/// At that point the SDK cache had cost two CI cycles and remained an
/// unpredictable dependency: its layout is Flutter's private business, it
/// varies by platform and by how the SDK was installed, and it is restored by a
/// third-party action that prunes it. A test that measures type should not be
/// the thing that discovers a toolchain packaging change.
///
/// So the two faces live in `test/support/fonts/`, **copied byte-for-byte from
/// the SDK's own `material_fonts`**. Byte-identical matters: the goldens and
/// every width assertion were authored against exactly these files, so nothing
/// measured moves. Roboto is Apache-2.0 and its licence is checked in beside
/// them (`roboto_license.txt`).
///
/// This does not weaken `MISTAKES.md` M-06. The requirement is a *real* font
/// rather than `flutter_test`'s fallback, which draws every glyph as a filled
/// rectangle about 0.84 em wide against Roboto's 0.55. These are that real font.
/// What changed is that it can no longer go missing.
Future<void> loadRealFont() async {
  // Candidates relative to the working directory, matching the convention
  // `content_test_support.dart` already uses for `test/fixtures`. Forward
  // slashes are correct on Windows too — `dart:io` accepts them.
  Directory? found;
  for (final String candidate in <String>[
    'test/support/fonts',
    'support/fonts',
  ]) {
    final Directory directory = Directory(candidate);
    if (directory.existsSync()) {
      found = directory;
      break;
    }
  }

  final File? regular = found == null
      ? null
      : File('${found.path}/roboto-regular.ttf');
  final File? bold = found == null
      ? null
      : File('${found.path}/roboto-bold.ttf');

  if (regular == null ||
      bold == null ||
      !regular.existsSync() ||
      !bold.existsSync()) {
    fail(
      'No real font under test/support/fonts, from '
      '${Directory.current.path}. The tests that call loadRealFont() measure '
      'or render text, and the flutter_test fallback font is ~50% wider than '
      'any font this app ships against — evidence taken against it is evidence '
      'about the harness (MISTAKES.md M-06). These two files are checked into '
      'the repository; restore them from git rather than letting those '
      'assertions run on square glyphs.',
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
