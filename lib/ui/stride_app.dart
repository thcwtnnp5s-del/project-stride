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
import 'state/activity_controller.dart';
import 'state/craft_controller.dart';
import 'state/session_controller.dart';
import 'state/session_scope.dart';
import 'theme/stride_theme.dart';

class StrideApp extends StatefulWidget {
  const StrideApp({
    super.key,
    required this.session,
    this.syncOnStart = true,
    this.activityTiming,
  });

  final StrideSession session;

  /// The activity queue's timing seams. Null in the app — real one-shot
  /// timers and the real clock. Tests substitute a fake pair so a queued
  /// gather completes on a manually advanced clock instead of a ten-second
  /// wait; the same shape as [syncOnStart], and like it, deliberately not a
  /// general switch — it changes when the presentation timer fires and
  /// nothing else.
  final ActivityTiming? activityTiming;

  /// Whether to reconcile new foreground health data once, after the first
  /// frame. True in the app; `main.dart` never passes it.
  ///
  /// ## Why this seam exists, and why it is not the feature being weakened
  ///
  /// A widget test runs under `FakeAsync`. A post-frame callback that starts
  /// real file and platform I/O produces a future `pumpAndSettle` cannot
  /// advance, so the controller stays `busy` for the rest of the test and every
  /// control in the tree is disabled — a hang wearing the costume of a layout
  /// bug. The sync is fine; the harness cannot finish it.
  ///
  /// So tests that drive their own sync compose it away, and the startup path
  /// gets its own test that runs inside `runAsync` and can actually await it
  /// (`test/startup_sync_test.dart`). The behaviour is still covered — it is
  /// covered by the test that is able to observe it, rather than half-started by
  /// every test that is not.
  ///
  /// It is deliberately **not** a general "disable health" switch. It gates one
  /// call, at one moment, and `syncSteps` remains reachable either way.
  final bool syncOnStart;

  @override
  State<StrideApp> createState() => _StrideAppState();
}

class _StrideAppState extends State<StrideApp> {
  // Synchronous. There is no async gap between the session existing and the
  // controller existing.
  late final SessionController _controller = SessionController(widget.session);

  /// App-scoped, beside the session controller, so the queue continues while
  /// the player browses other tabs — and never while the app is not resumed,
  /// which the controller enforces itself as a `WidgetsBindingObserver`.
  late final ActivityController _activity = ActivityController(
    _controller,
    timing: widget.activityTiming,
  );

  /// App-scoped like the gather queue, so a craft queue survives a tab
  /// switch. Purely presentational over the instant `CraftItem` command —
  /// see `craft_controller.dart` for the §55 background fast-forward.
  late final CraftController _craft = CraftController(
    _controller,
    timing: widget.activityTiming,
  );

  @override
  void initState() {
    super.initState();
    // The exclusive-command seam: travel or combat cancels the in-progress
    // repetition before it executes. See `SessionController.onExclusiveCommand`.
    _controller.onExclusiveCommand = _activity.cancelForExclusiveCommand;
    // Foreground startup sync, once, after the first frame.
    //
    // `addPostFrameCallback` rather than an `await` in `main`: startup already
    // awaits the session above `runApp`, so every figure on the first frame is
    // the real loaded save. Holding that frame for a HealthKit round trip as
    // well would trade a truthful immediate paint for a blank one.
    //
    // The two operations therefore stay visibly distinguishable — the save is
    // on screen, and the sync then adds to it or says why it could not. There
    // is no flash of zero, because zero is never what gets painted.
    //
    // One shot. H-5 permits foreground sync only, and `startupSync` is
    // idempotent, so neither a rebuild nor a hot reload can produce a second.
    if (!widget.syncOnStart) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.startupSync();
    });
  }

  @override
  void dispose() {
    _craft.dispose();
    _activity.dispose();
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
          child: ActivityScope(
            controller: _activity,
            child: CraftScope(
              controller: _craft,
              // The blocked branch is taken before the shell is built, not
              // inside it. A blocked bootstrap has no engine, so a shell that
              // rendered anyway would be reading the null-fallback zeros out
              // of every getter and presenting them as the player's save.
              child: blocked != null
                  ? BlockedScreen(blocked: blocked)
                  : const StrideShell(),
            ),
          ),
        ),
      ),
    );
  }
}
