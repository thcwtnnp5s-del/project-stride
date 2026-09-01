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

import 'audio/audio_controller.dart';
import 'runtime/stride_session.dart';
import 'ui/state/craft_memory.dart';
import 'ui/stride_app.dart';

Future<void> main() async {
  // Required before `getApplicationSupportDirectory`, and required before
  // anything else touches a platform channel. Bootstrap does both.
  WidgetsFlutterBinding.ensureInitialized();

  // The image cache is sized for this bundle, not for Flutter's defaults.
  //
  // The default cap is **1,000 entries** and this app ships **872 PNGs** — the
  // count binds at 87% occupancy, and it binds roughly four times sooner than
  // the 100 MiB byte cap does, because the mean decoded PNG here is only ~23
  // KiB. Left alone, VAWO01's new art would push past the entry cap and start
  // evicting; the symptom is not a crash but a re-decode stutter when a screen
  // is revisited, which reads as "the new art made it slow".
  //
  // `maximumSizeBytes` is deliberately *lowered* from the 100 MiB default to
  // 48 MiB. Total decoded art is ~20 MiB today with a budget of 44 MiB
  // (`FOUNDATION_K_PERFORMANCE.md`), so 48 MiB is a ceiling the budget fits
  // inside — which makes overspending the memory budget show up as a visible
  // eviction stutter in QA rather than as invisible growth on the device.
  //
  // Note what is *not* done here: no `cacheWidth`/`cacheHeight`/`ResizeImage`
  // anywhere. Resampling at decode drops columns before `filterQuality` is ever
  // consulted, and this app magnifies pixel art at integer scale (L-18). The
  // usual "downscale large images" advice is actively wrong for this product.
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 48 << 20;

  // Awaited before the first frame rather than kicked off behind a splash.
  //
  // The app's whole claim is that what it shows is what is durable, and a screen
  // that renders before the save has loaded would show zeros that are not the
  // save's zeros. A blocked bootstrap is a value here, not an exception:
  // `StrideSession.start` returns a session whose `outcome` is
  // `BootstrapBlocked`, and `StrideApp` renders the refusal.
  //
  // **This await must stay above `runApp`.** Moving it below, or wrapping the
  // app in a `FutureBuilder`, reintroduces the zero-flash — and a `FutureBuilder`
  // whose future is built in `build` would additionally re-run
  // `StrideSession.start`, a second bootstrap over the same save directory in
  // the same isolate.
  final StrideSession session = await StrideSession.start();

  // The presentation audio layer (AUDIO_PRESENTATION_01): loads the volume
  // preferences (one tiny JSON read) and configures the platform session.
  // Awaited here for the same truthfulness reason as the session — the first
  // frame's settings block shows what is stored, not a default that then
  // jumps. Audio touches no game state and cannot block a launch: every
  // failure path inside degrades to defaults or silence.
  final AudioController audio = await AudioController.start();

  // The craft presentation memory (GAME_FEEL_CHARACTER_PRESENTATION_01):
  // one tiny JSON read on the audio-settings seam, so first-craft
  // significance is known before the first queue. Unreadable means empty;
  // it cannot block a launch and touches no game state.
  final CraftMemory craftMemory = await CraftMemory.open();

  runApp(StrideApp(session: session, audio: audio, craftMemory: craftMemory));
}
