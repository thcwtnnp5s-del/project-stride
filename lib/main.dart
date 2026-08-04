// Project Stride — app entry point.
//
// S-01A scope: the real bootstrap and the developer harness. The app opens
// storage, runs `BootstrapCoordinator`, installs the device-bound identity into
// the native health adapter, and shows the harness.
//
// There is deliberately no background entry point here and no second `main`.
// Everything runs on the root isolate, in the foreground, because a second
// isolate pointed at the save directory is covered by nothing — see
// `runtime_bootstrap.dart`'s "Who may touch this directory" and
// `DECISIONS/0013`.

import 'package:flutter/material.dart';

import 'runtime/stride_session.dart';
import 'ui/dev_harness.dart';

Future<void> main() async {
  // Required before `getApplicationSupportDirectory`, and required before
  // anything else touches a platform channel. Bootstrap does both.
  WidgetsFlutterBinding.ensureInitialized();

  // Awaited before the first frame rather than kicked off behind a splash.
  //
  // The harness's whole claim is that what it shows is what is durable, and a
  // screen that renders before the save has loaded would show zeros that are
  // not the save's zeros. A blocked bootstrap is a value here, not an
  // exception: `StrideSession.start` returns a session whose `outcome` is
  // `BootstrapBlocked`, and the harness renders the refusal.
  final StrideSession session = await StrideSession.start();

  runApp(StrideHarnessApp(session: session));
}
