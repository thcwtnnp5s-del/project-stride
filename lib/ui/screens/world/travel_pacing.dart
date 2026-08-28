/// The travel presentation's one pacing spec, and the one clock both of its
/// views share (GAME_FEEL_CHARACTER_PRESENTATION_01, item 2).
///
/// ## Why this file exists
///
/// The owner's device verdict on the ~1.3 s travel card was "much too fast":
/// the game's biggest spend resolved in a flash, and the map's travel trace
/// ran a *separate* fixed 2.4 s clock that played mostly behind the card's
/// barrier. Two views of one journey, disagreeing.
///
/// Everything that decides how long the journey presentation lasts now lives
/// here, once:
///
/// - **Durations are whole walk passes.** The Traveler's west cycle is six
///   frames at 110 ms — 660 ms a pass — and every total below is an exact
///   multiple, so the loop always completes cleanly instead of freezing
///   mid-stride. The frame pace is never slowed: a stretched six-frame walk
///   reads as broken, so the longer hold is more passes, not slower ones.
/// - **Length scales with the route's hop count**, never its step cost and
///   never real-world time. Scaling by steps would visually assert that
///   steps are time, the exact implication `DECISIONS/0001` forbids this
///   presentation to even gesture at. A one-road walk is ~10 s; the longest
///   journeys cap at ~14.5 s — the owner's 10–15 s window.
/// - **Phases are pass-indexed** so they scale with the total: a short
///   departure beat (also the unskippable window — it absorbs the reflex
///   tap that follows Set out), the travel loop, an arrival anticipation,
///   and one closing rest pass on the standing frame.
///
/// ## The shared clock
///
/// [TravelPresentationLink] is how the map trace rides the card's own
/// controller instead of keeping a twin constant that would desynchronize
/// the moment skip exists. The card registers its animation while it plays
/// and clears it when it leaves; the trace mirrors whatever is registered
/// and falls back to its own identically-paced clock when no card runs
/// (reduced motion never gets here — both views skip themselves first).
/// Ephemeral presentation wiring only: nothing here is durable state, nothing
/// reads a wall clock, and a relaunch finds it empty (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';

/// The pacing table. Pure arithmetic — a test needs no widgets to pin it.
abstract final class TravelPacing {
  const TravelPacing._();

  /// One pass of the six-frame walk cycle at the repo-wide 110 ms cadence.
  static const int walkFrameCount = 6;
  static const Duration framePace = Duration(milliseconds: 110);
  static Duration get walkPass => framePace * walkFrameCount;

  /// Departure holds this many passes and is the unskippable window
  /// (3 × 660 ms = 1.98 s — inside the owner's 1.5–2 s ask).
  static const int departurePasses = 3;

  /// The last passes before the rest: the dot eases home, the burst fires.
  static const int anticipationPasses = 2;

  /// The closing pass: walk stops on frame 0, "Arrived at …" stands.
  static const int restPasses = 1;

  /// Total passes for a journey of [legs] adjacent hops. One road is ~10 s;
  /// the cap keeps the longest journey inside the owner's window.
  static int passesForLegs(int legs) => switch (legs) {
    <= 1 => 15, // 9.90 s
    2 => 18, // 11.88 s
    3 => 21, // 13.86 s
    _ => 22, // 14.52 s
  };

  /// The whole presentation's length for [legs] hops.
  static Duration durationForLegs(int legs) =>
      walkPass * passesForLegs(legs);

  /// Where skip becomes available, as a fraction of the whole.
  static double skipFractionForLegs(int legs) =>
      departurePasses / passesForLegs(legs);

  /// Where the arrival-rest phase begins, as a fraction of the whole — what
  /// a skip jumps to, so an accidental tap loses the journey's middle and
  /// never the arrival information.
  static double restFractionForLegs(int legs) {
    final int passes = passesForLegs(legs);
    return (passes - restPasses) / passes;
  }

  /// Where anticipation begins (the burst's cue), as a fraction.
  static double anticipationFractionForLegs(int legs) {
    final int passes = passesForLegs(legs);
    return (passes - restPasses - anticipationPasses) / passes;
  }

  /// The point where the backdrop has crossed from origin to destination —
  /// the midpoint of the travel loop.
  static double crossfadeFractionForLegs(int legs) {
    final double a = departurePasses / passesForLegs(legs);
    final double b = anticipationFractionForLegs(legs);
    return a + (b - a) / 2;
  }

  /// The eased course position the map trace draws at raw clock value [t] —
  /// departure and rest hold the ends, the middle eases along the road, so
  /// the dot leaves and arrives rather than teleporting.
  static double courseProgress(double t, int legs) {
    final double start = skipFractionForLegs(legs);
    final double end = restFractionForLegs(legs);
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeInOut.transform((t - start) / (end - start));
  }
}

/// The clock a playing travel card publishes, so the map trace can mirror it.
final class TravelPresentationHandle {
  const TravelPresentationHandle({required this.clock, required this.legs});

  /// The card's own animation, 0..1 over the whole presentation.
  final Animation<double> clock;

  /// The journey's hop count — the pacing key both views share.
  final int legs;
}

/// The registration point. A module-level notifier, deliberately: it carries
/// no durable state (E-2 — a relaunch finds it null), exactly one card can
/// play at a time (the dialog is modal), and threading a handle through five
/// widget layers to connect two leaves of different routes would be plumbing
/// in costume.
abstract final class TravelPresentationLink {
  const TravelPresentationLink._();

  static final ValueNotifier<TravelPresentationHandle?> active =
      ValueNotifier<TravelPresentationHandle?>(null);
}
