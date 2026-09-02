/// A one-call convenience for the shared `ui.commit` cue (ART-11, FMPO02
/// wave 1): every primary-commit press — Confirm, Equip, Craft-begin,
/// Travel-start — plays the same id, `ui.commit.01` (`EventCues.ui`), so a
/// call site needs one line rather than a `playEvent` string it has to spell
/// correctly.
///
/// Kept inside `lib/audio/` rather than the UI layer so it stays a plain
/// function of [AudioController] — no `BuildContext`, no import of
/// `ui/state/audio_scope.dart`, so this file does not cross the boundary
/// `audio_controller.dart` documents ("reachable from nothing in
/// `stride_core`", and reachable *by* nothing above it either). Call sites
/// resolve their own [AudioController] with `AudioScope.read`/`maybeRead` as
/// they already do for haptics, and pass it in:
///
/// ```dart
/// AudioScope.maybeRead(context)?.hapticSelection();
/// AudioEvents.commit(AudioScope.maybeRead(context));
/// ```
///
/// Always call this **beside** the existing haptic call, never in place of
/// it — the haptic and the sound are two separate feedback channels with
/// independent settings toggles.
library;

import 'audio_controller.dart';

abstract final class AudioEvents {
  const AudioEvents._();

  /// Fires `ui.commit`. Silent until `ui.commit.01` lands as a bundled file —
  /// the same fallback contract as every other unproduced [EventCue] — and a
  /// no-op when [audio] is null (no [AudioScope] above the call site).
  static void commit(AudioController? audio) {
    audio?.playEvent('ui.commit');
  }
}
