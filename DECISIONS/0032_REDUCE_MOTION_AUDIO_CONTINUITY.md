# 0032 — Reduce Motion reduces motion: Q-16 resolved for audio continuity

**Status:** Approved — **owner ruling, 2026-09-01**
**Date:** 2026-09-01
**Owner:** Project owner (explicit, in writing, continuing
VISUAL_AUDIO_WORLD_OVERHAUL_01)
**Resolves:** `JOURNAL/OPEN_QUESTIONS.md` **Q-16**
**Related:** `MISTAKES.md` M-16 · `RULES.md` G-4 · `DECISIONS/0005`, `0030`

---

## Context

Combat reads `disableAnimationsOf` **nowhere**. Under Reduce Motion Flutter
collapses animation durations, so a round that takes ~2.5 s of choreography
runs in roughly **125 ms**. Every combat cue is placed against that
choreography, so wiring combat audio without answering this first would deliver
eleven transients inside an eighth of a second — indistinguishable noise, on
the accessibility setting.

The tempting fix is the one `MISTAKES.md` **M-16** already records as a defect:
letting an accessibility preference silence a channel it does not name. That
cost a device pass once, when the activity beat was driven off the drawn frame
and Reduce Motion stopped the sound along with the animation.

## Decision

**Reduce Motion reduces visual motion. It does not reduce audio.**

Combat audio stays intelligible under the setting, and the architecture that
makes that true is:

1. **Cue timing is independent of animation duration.** A cue is fired by the
   combat state machine reaching a state, never by a drawn frame arriving. The
   separation `M-16`'s fix established for the activity beat now governs the
   whole combat surface.
2. **A voice cap, which nothing overrides.** At most **2 cues start inside any
   200 ms window**. A phone speaker cannot resolve a third, and the
   performance budget allows four voices of which two are music. This is a
   property of the speaker, so priority does not buy an exemption from it.
3. **Priority bands, so the survivor is the informative one.** 30 outcome ·
   20 impact · 10 intent · 5 texture. When cues collide the higher band wins,
   and a blow landing therefore outranks the swing that threw it.
4. **A stream floor, `minGapMillis`, breakable only upward.** Each cue declares
   the minimum gap after the previous cue; a **strictly higher-priority** cue
   may break it. That is what turns a collapsed round from a pile-up into a
   short, legible sequence rather than into silence.
5. **Ducking, not shouting.** An impact pulls the music bed down 3–9 dB for
   260 ms rather than being mixed louder. The duck multiplies the player's own
   music setting and is floored at 0.35 of it, so it can neither silence music
   the player chose nor raise it above what they chose.
6. **Nothing outlives its encounter.** Cues are fired, never scheduled — there
   is no pending-cue queue that could fire after a fight has resolved. The duck
   recovery is the only timer, it is one-shot, and it is cancelled on dispose.

### What the setting *does* still change

Visual motion, exactly as before: collapsed durations, held frames, no travel
tween. And haptics remain on their own axis — `hapticsEnabled` is a separate
preference and Reduce Motion does not touch it, because a player who wants
fewer moving pixels has not asked for fewer taps on the wrist.

## Reasoning

- **The failure mode is asymmetric.** Audio that arrives too fast is unpleasant
  for one round; audio that a preference silently disables is a defect the
  owner has already paid for once (M-16) and is invisible to everyone who does
  not use the setting.
- **A voice cap is honest about the hardware.** The alternative — mixing
  everything and trusting the player to parse it — is not a mix decision, it is
  the absence of one.
- **Priority beats reordering.** The instinct is to *delay* colliding cues so
  they all play. That reintroduces the thing the owner explicitly forbade: a
  delayed cue continuing after the encounter has resolved. Dropping the less
  informative cue is bounded; queueing is not.
- **The bands are few and named.** A continuous priority number invites
  per-cue fiddling and drifts; four bands can be reasoned about in a sentence.

## What this decision does NOT authorize

- **No new audio generation.** Both provider keys remain unset
  (`DECISIONS/0030` § 4). This is architecture; every event id it wires is
  currently silent by design, and `AudioCues.fileFor` returning null is the
  contract that makes that safe rather than fatal.
- **No music genre change in combat.** The regional bed keeps playing and is
  ducked. A dedicated battle track is a separate decision.
- **No weakening of any accessibility guard.** Nothing here reads
  `disableAnimationsOf` to *suppress* sound; the setting is not consulted by
  the audio layer at all, which is the strongest available form of "it does not
  reduce audio".
- **No haptic on every cue.** Haptics keep their existing rate floors and their
  own preference.

## Consequences

- `lib/audio/audio_cues.dart` gains `EventCue` and the `EventCues` tables —
  **11 combat ids and 9 outcome/craft ids**, every one wired and currently
  silent.
- `lib/audio/audio_controller.dart` gains `playEvent`, the voice cap, the
  priority arbitration, the stream floor and the duck. `playEvent` **returns
  whether it voiced**, because arbitration that does not report its decision
  cannot be tested.
- Loot deliberately has **no id**: it resolves inside the victory layer, and a
  separate coin-or-bag flourish is the slot-machine register the locked
  creative direction forbids.
- `AUDIO/AUDIO_PRODUCTION_BRIEF_VAWO01.md` carries a generation-ready brief per
  id, so the round runs the moment a key exists.
- **Q-16 closes.** Q-17 (mining is the loudness floor and `trimDb` can only
  attenuate) stays open — it needs a limiter re-master, which is a change of
  packaging class.

## Invariant check

**P-4/P-5**: no clock, no schedule, no decay — cues fire from state, not time.
**P-6**: no jackpot register; loot has no cue. **E-2**: the audio layer reads
presentation state and mutates nothing. **G-4**: nothing is loosened; a cap and
a floor are added. **M-16**: directly addressed — cadence is separated from the
drawn frame, and no accessibility preference reaches the audio path.
**Health, steps, economy, save format:** untouched.
