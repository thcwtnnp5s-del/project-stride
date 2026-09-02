# Audio Production Queue 03 — the ART-11 delta

**Opened:** 2026-09-02 (FMPO02 wave 1, `ART-11_audio_brief.md`)
**Authority:** `DECISIONS/0005_AUDIO_SOURCING.md`, `DECISIONS/0030` (audio
reopened), `DECISIONS/0032` (Reduce Motion keeps audio continuity),
`GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md` §2.5–§2.6
**Enforced by:** `test/audio/event_cue_readiness_test.dart` — which fails if
this document and the `EventCues.ui` table ever disagree, and separately
checks this document names the cooking-transient swap below.

---

## 1. What this queue is for

ART-11 cross-checked the owner's requested sound list against
`AUDIO_PRODUCTION_QUEUE_02.md`, `audio_cues.dart` and the actual haptic call
sites, and found the list **almost entirely already covered** — either
already queued in QUEUE_02, already wired with a haptic waiting on sound only,
or already ruled out by a standing owner decision. Two things were genuinely
new. This document is those two things, and only those two things: **QUEUE_03
is two rows, not twenty.**

The one-row contract this queue follows is identical to QUEUE_02 §2, restated
here rather than assumed:

> *"produce a final exact generation queue, verify every event can accept its
> future file with no code change."*

## 2. The one-row contract, stated exactly

To land the sound below:

1. Produce the file.
2. Save it as `assets/audio/v1/sfx/<file>` using the name in the table.
3. Add one row to `AudioCues.files`:
   `'<asset ID>': 'audio/v1/sfx/<file>',`
4. Add one row to `AUDIO/AUDIO_ASSET_MANIFEST.md` with its provenance.

**Nothing else changes.** The `EventCues.ui` table already landed this
session (`lib/audio/audio_cues.dart`), ahead of the file, exactly as QUEUE_02
did for its twenty events — priority, gap floor, duck and trim are already
authored; the mixer is waiting for bytes.

The cooking-transient swap in §5.2 is a **different contract** — it is not a
new `EventCue`, it is a one-row replacement inside the existing
`skillCues['skill.cooking']` `ActionCue`, and it does not land until the file
exists (see §5.2).

## 3. Direction (unchanged from the bake-off, QUEUE_02 §3)

Acoustic fantasy lo-fi: real instruments and real materials, close-mic'd, a
little room, no synthesis. No EDM, no synthwave, no arcade blips. Every cue is
a **transient**, not a phrase — one gesture, no tail that outlives the beat it
answers.

## 4. The queue — 1 unproduced event

Priority bands: **30** the moment resolves · **20** something landed · **10**
ordinary action. Gap is the floor between two firings of the same cue. Duck is
how far the music bed moves under it.

| Event | Asset ID | Pri | Trim dB | Duck dB | Gap ms |
|---|---|---:|---:|---:|---:|
| `ui.commit` | `ui.commit.01` | 10 | 0 | 0 | 120 |

`ui.commit` is one shared id fired at four existing commit sites — confirm,
equip, craft-begin, travel-start — each of which already fires a haptic today
and plays no sound. Priority 10 (intent), not 30: it is the most frequent cue
in the whole game, never the moment a fight or a delivery resolves, and it
must never be allowed to duck the music bed at that frequency, which is why
duck is 0 and not the −3 a QUEUE_02 intent-tier cue carries.

## 5. Briefs and filenames

### 5.1 UI — 1 cue

| Asset ID | File | Brief |
|---|---|---|
| `ui.commit.01` | `sfx_ui_commit_01.wav` | Extremely close, extremely quiet single tap of a fingertip on dense leather-bound wood, like a hand settling a decision onto a table: one small dry contact, no ring, no click, no digital tone, no reverb, a natural room the size of a hand's reach, gone almost as soon as it starts. ~90 ms |

Full Stability prompt (`TrackType: SFX`):

> `Extremely close, extremely quiet single tap of a fingertip on dense leather-bound wood, like a hand settling a decision onto a table: one small dry contact, no ring, no click, no digital tone, no reverb, a natural room the size of a hand's reach, gone almost as soon as it starts.`

Acceptance: must not read as a UI "blip" — no pitch, no synth tone. Must sit
under every other cue in the mix without competing (Pri 10, no duck).

### 5.2 Not a queue row — the cooking-transient swap

`craft.cooking.01`'s source is a steady sizzle plateau with **no transient
anywhere in its profile** — it cannot punctuate a strike frame at any
cooldown. The fix is not a new event, it is a replacement source for the
existing `skillCues['skill.cooking']` `ActionCue` in `audio_cues.dart:166`.

| Asset ID | Replaces | cooldownMillis | trimDb |
|---|---|---:|---:|
| `craft.cooking.stir.01` | `craft.cooking.01` in `skillCues['skill.cooking']` | 1100 (unchanged) | measure post-generation against the −17.0 LUFS-M ceiling (`AudioCues.skillCues` doc) |

File name: `sfx_craft_cooking_stir_01.wav` (seed continues the 46xx block,
e.g. 4601).

Full Stability prompt (`TrackType: SFX`):

> `Close-mic field recording of one single stir in a cast iron cookpot over a fire: a wooden spoon makes a clear firm contact with the pot's inner wall, a short thick liquid drag through stew, one small fat pop, a faint fire crackle far under, one clean discrete cooking gesture, extremely short decay, dry close recording space.`

Acceptance: must have a contact transient at its front (the entire failure of
the current file); must survive firing every 1.1 s without smearing.

**This is a one-row swap once the file lands — no other code changes.** Until
then, `skillCues['skill.cooking']` keeps pointing at `craft.cooking.01`
exactly as shipped; nothing in this session changes that table entry.

## 6. Blocker (unchanged from GOV-06)

`STABILITY_API_KEY` is unset; no `.env`/key file exists anywhere in the repo
or `~/.claude`; `gen2.mjs` exits 2 without it. No local ffmpeg/sox to
substitute. **No file work is possible this session.**

Unblock: export `STABILITY_API_KEY` before the next session; then run
`node gen2.mjs` once — the script at
`AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs` (or the bakeoff copy)
— to read live balance (`/v1/user/balance`) before spending. Last recorded
balance: 61 credits, 2026-08-24, unverifiable now. Generation cost:
stable-audio-2.5 (SFX) = 20 credits flat; both cues in this queue are SFX, so
both rows cost 20 credits each if generated singly.

## 7. Why nothing was generated this session

The workstream's instruction was explicit that design and wiring must not
block on missing credentials. So the `EventCues.ui` table, the `ui.commit`
call sites (§8) and this queue all landed, and **zero sounds were produced.**
The gap is honest, and it is visible in exactly one place: the table in §4
plus the swap in §5.2.

## 8. Call-site wiring landed this session

`AudioEvents.commit(AudioController?)` (`lib/audio/audio_events.dart`) is the
one-line helper every commit site calls beside its existing haptic. Wired
directly this session:

- `lib/ui/screens/world/atlas/atlas_selection_panel.dart` — the "Set out"
  travel-start commit, beside the existing `hapticLight()`.

Recorded for the integrator to add once `craft_screen.dart` and
`inventory_screen.dart` are no longer being rewritten concurrently by other
agents this round (exact lines, both already importing `AudioScope`):

- `lib/ui/screens/craft/craft_screen.dart:885`, beside
  `AudioScope.read(context).hapticLight();` (the Craft-begin commit) — add
  `AudioEvents.commit(AudioScope.read(context));` and import
  `../../../audio/audio_events.dart`.
- `lib/ui/screens/inventory/inventory_screen.dart:924`, beside
  `AudioScope.maybeRead(context)?.hapticSelection();` (the Equip commit) — add
  `AudioEvents.commit(AudioScope.maybeRead(context));` and import
  `../../../audio/audio_events.dart`.

No fourth "confirm" call site distinct from equip/craft-begin/travel-start
was found in code — `GOV-06_audio_capability.md` §3 independently confirms
`ui.confirm` "does not exist as a runtime asset ID anywhere," and this
session's own grep of every haptic call site in `lib/` turned up no separate
confirm commit outside the three above. If the owner has a specific fourth
site in mind, it is `UNRESOLVED` and belongs in
`JOURNAL/OPEN_QUESTIONS.md` rather than guessed at here.
