# ART-11 — Audio Brief (FMPO02 Wave 1)

**Verdict up front: most of the requested list already exists.** Cross-checking
the owner's list against `AUDIO_PRODUCTION_QUEUE_02.md`, `audio_cues.dart` and
the actual haptic call sites found only **one genuinely new sound id** and
**one real haptic gap**. Everything else below is either already queued,
already wired, or deliberately ruled out — stated so QUEUE_03 doesn't
reintroduce something the owner already closed.

## 1. Blocker (unchanged from GOV-06)

`STABILITY_API_KEY` is unset; no `.env`/key file exists anywhere in the repo
or `~/.claude`; `gen2.mjs` exits 2 without it. No local ffmpeg/sox to
substitute. **No file work is possible this session.** Unblock: export
`STABILITY_API_KEY` before the next session; then run `node gen2.mjs` once to
read live balance (`/v1/user/balance`) before spending — last recorded 61
credits, 2026-08-24, unverifiable now.

## 2. What's already covered (do not re-queue)

| Requested | Status |
|---|---|
| Ore fracture, wood crack, forage rustle/collect split | **Ruled out.** Owner's one-cue-per-activity ruling (2026-08-24) stands until device play proves it distracting. Id shape reserved, not queued. |
| Smith finish, cook finish | **Already queued** — `craft.complete.gear.01`, `craft.complete.food.01`, QUEUE_02 §4/§5.3. |
| Rare reward, signature drop | **Already queued** — `reward.discovery.01`, QUEUE_02 §4/§5.2 (fires nested inside the victory layer, no separate haptic by design). |
| Level up | **Already queued** — `reward.levelup.01`. Haptic already correct: `WonBeat` is always `RewardTier.major` → `reward_layer.dart:79` fires `hapticHeavy(payoff:true)`; a level-up is a fact inside that same layer, not a second event. |
| Project/contract complete | **Already queued** — `reward.milestone.01` folds both (GAME_BIBLE §2.6 ruling, unchanged). |
| Equip haptic | **Already wired** — `inventory_screen.dart:924`, `hapticSelection()`, gated on `lastEquip.succeeded`. |
| Craft-begin haptic | **Already wired** — `craft_screen.dart:885`, `hapticLight()`, comment: "one light pulse per commitment, as Gather and Set out." |
| Travel-start haptic | **Already wired** — `atlas_selection_panel.dart:689`, `hapticLight()`, fired on the "Set out" commit itself. |

None of the above need code changes. What they lack is **sound only** (see §3), and for equip/craft-begin/travel-start the haptic is already correct.

## 3. The QUEUE_03 delta — genuinely new, not in QUEUE_02

Only two real additions, both already named in `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md` (draft) but absent from the shipped `AUDIO_PRODUCTION_QUEUE_02.md`:

| Event | Asset ID | Pri | Trim dB | Duck dB | Gap ms |
|---|---|---:|---:|---:|---:|
| `ui.commit` (confirm/equip/craft-begin/travel-start — one shared id) | `ui.commit.01` | 10 | 0 | 0 | 120 |

`ui.commit.01` is the one truly missing sound: Confirm, Equip, Craft-begin and
Travel-start all already fire a haptic at commit; none plays a sound. One id
covers all four (GAME_BIBLE §2.5 ruling — a UI click family is upkeep, not a
taxonomy). Wiring: add to `EventCues` (a new small `ui` map, or fold into
`reward`), call `AudioScope.read(context).playEvent('ui.commit')` (or
equivalent) at the four existing commit sites listed in §2, **beside** the
existing haptic call, not replacing it.

Second item is an `ActionCue`, not an `EventCue` (no priority/duck — it
replaces a working-loop cue, same shape as `skillCues['skill.cooking']`):

| Asset ID | Replaces | cooldownMillis | trimDb |
|---|---|---:|---:|
| `craft.cooking.stir.01` | `craft.cooking.01` in `skillCues['skill.cooking']` | 1100 (unchanged) | measure post-generation against the −17.0 LUFS-M ceiling |

Why: `craft.cooking.01`'s source is a steady sizzle plateau with **no
transient anywhere in its profile** (GAME_BIBLE §3.3) — it cannot punctuate a
strike frame at any cooldown. This is a one-row swap in `audio_cues.dart:166`
once the file lands; no other code changes.

Everything else the owner's list named is either §2 (already done) or §2.6 of
the event matrix (deliberately not created). **QUEUE_03 is two rows, not
twenty.**

## 4. Haptic map — what fires today, and the one real gap

**Already correct (no change):** heavy combat impact → `hapticHeavy`,
`combat_stage.dart:472` (fires at `_heavyHapticPending`, set from
`s.heavyImpactAt` at `:363` — already at *lands*, not segment start).
Victory/level-up (major) → `hapticHeavy`, retreat/discovery/milestone-tier
(medium) → `hapticMedium`, both `reward_layer.dart:79/81`, scaled by
`RewardTier` at the single `showRewardLayer` seam. Gather/craft/minor
completion → `hapticLight`, `activity_result.dart:394`. Equip →
`hapticSelection`, `inventory_screen.dart:924`. Craft-begin/loop-boundary →
`hapticLight`, `craft_screen.dart:885,1181`. Travel-start → `hapticLight`,
`atlas_selection_panel.dart:689`. Encounter-begin → `hapticMedium`,
`encounter_card.dart:319`. Gather strikes → `hapticLight`,
`adventure_screen.dart:250,552`, `activity_panel.dart:518`.

**Real gap — Brace has zero haptic today.** `combat_choreography.dart:231-238`
builds a `BracedBeat` segment (a held idle pose) but no haptic fires at its
start anywhere in `combat_stage.dart` — the file's only combat haptic call is
the heavy-impact one at `:472`. Per GAME_BIBLE §2.1's own table, brace is the
one cue in the whole combat section marked **"new `hapticLight`"** (everything
else is "none" or "existing"). Fix: in `combat_stage.dart`, alongside the
`_heavyHapticPending` segment-start dispatch (`:363` region), add a case for a
`BracedBeat` segment that calls `AudioScope.maybeRead(context)?.hapticLight()`
once at segment start. Pairs with the already-queued `combat.brace.01` sound
(QUEUE_02 §5.1) — landing the haptic now means Brace is *felt* before it can
be *heard*.

**Secondary finding (flagged only, not acted on):** non-heavy combat impacts
(`combat.player.impact`, `combat.enemy.impact`, `combat.brace.absorb`) have
**no haptic at all** — only the heavy path calls `hapticHeavy`. GAME_BIBLE
§2.1 marks these "none" deliberately (heavy stays the one interrupt-worthy
tier), so this is an existing design choice, not an oversight — recorded so a
future haptic-density pass doesn't rediscover it as new.

## 5. Stability prompts — the two new cues (acoustic fantasy lo-fi, real materials, transient, no EDM/arcade)

**`ui.commit.01`** (~90 ms):
> `TrackType: SFX. Extremely close, extremely quiet single tap of a fingertip on dense leather-bound wood, like a hand settling a decision onto a table: one small dry contact, no ring, no click, no digital tone, no reverb, a natural room the size of a hand's reach, gone almost as soon as it starts.`
Acceptance: must not read as a UI "blip" — no pitch, no synth tone. Must sit
under every other cue in the mix without competing (Pri 10, no duck).

**`craft.cooking.stir.01`** (~1 s, seed continues the 46xx block, e.g. 4601):
> `TrackType: SFX. Close-mic field recording of one single stir in a cast iron cookpot over a fire: a wooden spoon makes a clear firm contact with the pot's inner wall, a short thick liquid drag through stew, one small fat pop, a faint fire crackle far under, one clean discrete cooking gesture, extremely short decay, dry close recording space.`
Acceptance: must have a contact transient at its front (the entire failure
of the current file); must survive firing every 1.32 s without smearing.

## 6. Landing contract (unchanged)

Both cues follow the existing one-row rule: file →
`assets/audio/v1/sfx/<name>` → one row in `AudioCues.files` (+ `skillCues` for
the cooking swap) → one manifest row. `ui.commit.01`'s four call sites also
need one `playEvent`/`playCue` line added beside each existing haptic call —
that is the only non-file code change QUEUE_03 requires, and it can land
**today**, independent of the key, since it plays silence until the file
exists (same fallback contract as the 20 QUEUE_02 events).
