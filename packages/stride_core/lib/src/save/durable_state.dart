/// Whole-durable-state comparison, for save integrity and for tests.
///
/// ===========================================================================
/// Why this is a function beside the codec and not a getter on `GameState`
/// ===========================================================================
///
/// It replaces `GameState.signature`, which was a hand-written summary string.
/// A summary is exactly the wrong shape for this job: it has to be *maintained*
/// to stay complete, nothing makes it fail when it stops being, and every
/// caller reads the name "signature" as "the whole state" regardless.
///
/// It had stopped being complete. It carried level, xp, inventory, equipment,
/// skills, world, event sequence and a ledger summary — but **not
/// `checkpoint.cursor` and not `checkpoint.originWatermarks`**, and it carried
/// granted slices only as a COUNT, so a slice revised in place was invisible.
/// Two states differing in the durable sync position produced identical
/// signatures.
///
/// That was not merely weak test evidence. `SaveRepository` used it to decide
/// whether two save slots at the SAME snapshot generation had diverged — a
/// fail-closed corruption check. Slots differing only in the durable cursor
/// compared equal, the refusal did not fire, and an arbitrary slot was chosen.
/// Choose the one whose cursor is further along and the next sync resumes past
/// steps the chosen ledger never granted: silent, permanent, and uncounted,
/// because no completeness assertion was violated and nothing was discarded as
/// late. See `DECISIONS/0014` and the F-06 post-closure addendum.
///
/// The fix is to stop summarising. [canonicalDurableGameState] is the exact
/// byte sequence the save file itself would carry, so:
///
///   * it is complete by construction — the codec must already encode every
///     durable field or saves would not round-trip, and the round-trip tests
///     enforce that independently
///   * a newly added `GameState` field joins the comparison the moment it is
///     persisted, with no second list to remember
///   * a field that is added to `GameState` and NOT persisted fails the codec's
///     own coverage guard rather than silently escaping this comparison
///
/// It is deliberately **not** put back on `GameState` as a convenience getter.
/// The previous defect was possible precisely because a convenience summary sat
/// where a complete comparison was assumed, and a name on the state object is
/// what invited callers to assume it.
library;

import '../engine/game_state.dart';
import 'save_codec.dart';

/// The canonical durable encoding of [state] — byte-for-byte what a save file
/// would carry for it.
///
/// Stable across map insertion order: the codec sorts object keys and sorts the
/// id-keyed collections, so two states built by different paths that mean the
/// same thing encode identically. Nothing here depends on `hashCode` ordering.
///
/// **Durable state only.** Anything `GameState` holds that the codec does not
/// persist is, by definition, not part of what a save slot preserves and must
/// not make two slots look divergent.
String canonicalDurableGameState(GameState state) =>
    canonicalJson(encodeGameState(state));

/// Whether [a] and [b] preserve exactly the same durable state.
///
/// Used by `SaveRepository` for the equal-generation divergence check and by
/// tests that need to claim a whole state is unchanged.
///
/// Symmetric, reflexive, and total — there is no field it declines to look at,
/// which is the entire difference between this and what it replaced.
bool durableGameStatesEqual(GameState a, GameState b) =>
    canonicalDurableGameState(a) == canonicalDurableGameState(b);
