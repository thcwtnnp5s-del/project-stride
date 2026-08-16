/// The app root.
///
/// ## Why there is no loading state
///
/// `SessionController`'s constructor requires an **already-started**
/// `StrideSession`, which `main.dart` awaits before `runApp`. So there is no
/// state in which the UI exists and the session does not: no `isLoading` field
/// to forget to check, no null session, no default-constructed `GameState`.
///
/// A flash of zeros is not "avoided" here. It is **unrepresentable**.
///
/// That is why this file contains no `FutureBuilder`. A `FutureBuilder` renders
/// before its future resolves — which would paint the `?? 0` fallbacks on
/// `usableEnergy` and friends, zeros that are not the save's zeros, followed by
/// a jump. And a future constructed inside `build` is recreated on every
/// rebuild, so it would re-run `StrideSession.start` — a second bootstrap over
/// the same save directory in the same isolate.
///
/// A Flutter splash route has the same defect wearing different clothes: it
/// requires `runApp` first. A *native* launch screen is safe, because the OS
/// draws it before `main` runs at all.
library;

import 'package:flutter/material.dart';
import 'package:stride_core/stride_core.dart' show BootstrapBlocked;

import '../runtime/stride_session.dart';
import 'screens/system/blocked_screen.dart';
import 'shell/stride_shell.dart';
import 'state/session_controller.dart';
import 'state/session_scope.dart';
import 'theme/stride_theme.dart';

class StrideApp extends StatefulWidget {
  const StrideApp({super.key, required this.session});

  final StrideSession session;

  @override
  State<StrideApp> createState() => _StrideAppState();
}

class _StrideAppState extends State<StrideApp> {
  // Synchronous. There is no async gap between the session existing and the
  // controller existing.
  late final SessionController _controller = SessionController(widget.session);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapBlocked? blocked = widget.session.blocked;
    return MaterialApp(
      title: 'Project Stride',
      debugShowCheckedModeBanner: false,
      theme: strideTheme(),
      // Every screen sits under one Material, and this is not decoration.
      //
      // `MaterialApp` supplies the theme but NOT a `Material`; `home` is
      // whatever you put there. With no `Material` ancestor, `DefaultTextStyle`
      // resolves to Flutter's fallback — whose own debug label reads "consider
      // putting your text in a Material" — and that style carries
      // `TextDecoration.underline` in double yellow.
      //
      // The result is that **every string in the product is underlined**. Each
      // `StrideType` role sets a colour, a size and a weight but not a
      // `decoration`, so the fallback's decoration is inherited by all of them
      // and the app renders exactly as designed except for a yellow rule under
      // every word.
      //
      // Nothing caught it before a device: widget tests read strings rather than
      // their decoration, and the golden harness has no real font, so it draws
      // every glyph as a filled rectangle and the underline merges into the box.
      // The first honest look was a screenshot from a running device.
      //
      // `type: transparency` because `StrideScaffold` paints the page ground
      // itself — a Material with a colour here would put a second opaque layer
      // under every screen for nothing.
      home: Material(
        type: MaterialType.transparency,
        child: SessionScope(
          controller: _controller,
          // The blocked branch is taken before the shell is built, not inside
          // it. A blocked bootstrap has no engine, so a shell that rendered
          // anyway would be reading the null-fallback zeros out of every getter
          // and presenting them as the player's save.
          child: blocked != null
              ? BlockedScreen(blocked: blocked)
              : const StrideShell(),
        ),
      ),
    );
  }
}
