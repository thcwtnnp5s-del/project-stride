# Game Feel & Character Presentation 01

**Branch:** `game-feel-character-presentation-01` (from `world-atlas-remaster-01` @
`5bc2c46`, which already contains all of `fable-v2-experiment` @ `3aabfae`)
**Status:** in progress
**Scope:** presentation / game feel / character visualization only. Health
accounting, economy epoch, save atomicity, atlas art and pipeline, map
geography, audio provider, combat architecture, craft costs and step economy
are untouched. **PixelLab generations this pass: ZERO** — the 25-generation
reserve stays protected for atlas correction.

Process: seven design agents (FEEL-A craft reward, FEEL-B travel pacing,
FEEL-C ambient pacing, FEEL-D buttons, FEEL-E equipment architecture,
FEEL-F asset librarian, FEEL-G accessibility) reported before implementation;
this thesis synthesizes their findings. Main session owns implementation.
FINAL-A skeptical review follows implementation.

---

## Design thesis — the thirteen questions

### 1. Why does crafting completion currently feel flat?

Because completion is presented as a *removal*. At the final commit the
richest thing on the screen — the 176 dp work stage, its backdrop, the
working figure and the strike-beat audio — unmounts
(`craft_screen.dart`), and what replaces it is a four-second MINOR text
block with no item icon, no haptic and no sound
(`craft_controller.dart` `_summaryLifetime`). Mid-queue boundaries have no
sensory event at all: the repetition bar snaps full→empty and a counter
increments. A ×10 batch ends exactly the size of a ×1. Equipment is the one
good case (a held MEDIUM reward layer with Equip and a haptic).

Found while diagnosing, a truth bug: **a level-up on repetition k < N of a
queue is silently lost** — `_dispatchOne` overwrites `_lastReport` on every
success and `summaryHeld` reads only the last report, so a Smithing level
gained mid-queue produces no LevelUpCard and its unlock names vanish. The
game under-reports real accomplishment.

### 2. What craft completion hierarchy should exist?

Significance is **derived from real content, never hardcoded per item** — a
pure function over facts the reports already carry:

| Tier | Derived from | Presentation |
|---|---|---|
| MAJOR | output rarity ≥ Epic | held reward layer, 2 px frame, heavy haptic |
| MEDIUM (held) | finished equipment/tool (`equipDelta`), any level-up anywhere in the queue, Rare output, or first-time craft of an Uncommon+ output | held reward layer, Equip where applicable, medium haptic |
| MINOR (transient) | everything else | inline beat, now with the item's 48 px icon, rarity ink, +XP — and a light haptic per committed repetition |

Batch behavior: per-boundary light beats while watching (haptic + bar
flash), **one** summary at the end sized by the maximum significance in the
run. A queue that finishes while the player is elsewhere keeps its summary
until first seen (the owner's brief: "if they come back after a finite
queue: summarize what completed"); the decay timer starts at first sight,
not at finish. Nothing loops, expires or pressures (P-5); presentation
alters no economy truth.

First-craft state is **not derivable** from durable state (no craft counts
in `ProgressState`; the journal compacts) and no save migration is allowed,
so first-craft elevation uses a small presentation-side memory file on the
same seam as the audio settings store (never inside the save directory).
Because that memory can be lost on reinstall, the beat never makes a
lifetime factual claim — it elevates presentation strength only.

### 3. Why does travel feel rushed?

The presentation is 1.32 s — six walk frames at 110 ms × 2 passes
(`travel_transition.dart`) — and the map's travel trace is a separate fixed
2.4 s spark (`atlas_layers.dart`) that starts at commit and therefore plays
mostly *behind the card's 70 %-dark barrier*. Two unrelated animations, no
shared clock, no route awareness. Latent defect found: a multi-leg
journey's trace calls `routeBetween(origin, destination)` — null for
non-adjacent places — and falls back to a straight line cut cross-country.

### 4. What exact duration model will ship?

Durations are quantized to whole walk passes (6 frames × 110 ms = 660 ms)
so the loop always completes cleanly, and scale with **hop count** — never
step cost, and never real-world time (P-4 is not even gestured at):

| Route | Passes | Total |
|---|---|---|
| 1 leg | 15 | 9.90 s |
| 2 legs | 18 | 11.88 s |
| 3 legs | 21 | 13.86 s |
| 4+ legs | 22 (cap) | 14.52 s |

Phases (pass-indexed, so they scale): departure over the **origin's**
vignette (3 passes, unskippable window ≈ 1.98 s) → travel loop over the
destination vignette with the journey's cost line (crossfade near the
midpoint) → arrival anticipation (2 passes; the arrival burst fires here
instead of being wasted behind the barrier) → arrival rest (1 pass, frame
0, "Arrived at …"), then auto-dismiss.

**One clock.** The card's controller is the master; the map trace becomes a
listener positioned from the same eased progress over the **concatenated
per-leg course** (fixing the straight-line defect), and the barrier
lightens so the dot is visible as the journey's second view. Skip jumps the
clock to the arrival phase — dot snaps home, arrival line still shows — so
an accidental tap loses only the middle, never the information.

Skip affordance: "Tap to continue" micro-label fades in when the window
ends; the card carries a real semantic button node (labeled, enabled after
the window) so assistive tech is never trapped. **Reduced motion keeps the
existing behavior — no card at all** (the recorded FABLE_V2 checklist item
17 stays true; the result line is the beat).

### 5. Why do ambient scenes feel rushed?

A scene lasts exactly as long as its Traveler track
(`ambient_scene.dart` — `duration => traveler.duration`), and every
authored track is 2.0–6.7 s; the player rotates the instant the controller
completes, after a fixed 1.6 s rest. `sit_by_fire` literally plays
sit-down-and-stand-straight-back-up as the whole scene, and the cat and
fire layers are cut short by the Traveler track ending. It is a playback
model problem, not an art problem — no new frames are needed.

### 6. What intro/loop/outro model will ship?

`ScenePhasing` metadata per scene, authored in the one existing table
(`ambient_assets.dart`), consumed by `AmbientPlayer`:

- **INTRO** — the strip's entry arc, played once (e.g. sitting down,
  taking the book out).
- **HOLD** — the loopable middle frames, ping-ponged/wrapped for a
  duration drawn from `AmbientCadence` bounds (20–28 s), companion layers
  sustained (the cat keeps breathing, the fire keeps flickering — also
  fixing the layers-cut-short defect). `once` layers still clamp (the cat
  that sat down stays seated).
- **OUTRO** — explicit closing frames where the strip has them
  (`pet_cat` 9..10), reverse-intro where it does not (`sit_by_fire`).

Scene totals land in the owner's 20–30 s window. Holds apply only when the
scene plays as a **full scene** (visit or idle full-beat) and only under
the same lifecycle seam the idle cadence already uses; micro-idles keep
their short form (the cadence pins them ≤ 4 s), and the widget-test
harness (no lifecycle state) keeps today's fast-settling behavior — the
documented test seam, extended, not a second one. Neutral gaps between
scenes become drawn 3–6 s instead of a fixed 1.6 s; scene selection avoids
the last two ids so A-B-A ping-pong dies. Reduced motion is unchanged:
rest frame, held. No gameplay reward, no cat system.

Cut points (frame-inspected): `read` intro 0–4 / loop 5–8 / reverse-intro;
`sit_by_fire` intro 0–4 / loop 5–10 / reverse-intro; `pet_cat` intro 0–3 /
loop 4–8 / outro 9–10; `crouch_pet` intro 0–3 / loop 4–8 / outro 9–10;
cyclic strips (drink, eat, dangle_string, head_scratch, stretch, pushups,
pack_check, wipe_brow, stretch_with_cat) hold their whole pass.

### 7. What is wrong with current buttons?

The V2 ember is a shine, not construction: a ~6 L* gradient across 48 dp
and a 14 %-alpha blurred glow on near-black are both sub-perceptual at
phone brightness. Nothing on any button declares thickness — every surface
in the system wears the same 1 px uniform border — and the press response
(3 % scale, ~1.4 dp) is below perception. Worst, one material serves every
register: Attack, Brace, Craft, Set out, **Cancel** and **Stop** all wear
identical ember, so "important" stops meaning anything.

### 8. What button system will ship?

The pixel plate — drawn depth in the language the panels already speak,
every color an existing token:

- Flat `surfaceRaised` fill (gradient deleted); 2 px lit top edge in
  `actionSheen`; 1 px `actionEdge` outline; a **hard** 2 px under-ledge
  (blur 0) in `surfaceGround`; radius tightened to the gate radius.
- Pressed: the plate translates down 2 px, the ledge collapses, the top
  light goes off. Reduced motion keeps the state swap, skips the ease.
- Disabled: flat `surfaceBlock`, no line, no ledge, no border, muted ink —
  an unpressable thing has no thickness.

Variants (an enum on the existing widget): **COMMIT** (warm plate;
`Set out` is the sole `actionGlow` bearer — the game's weightiest commit),
**ATTACK** (commit plate, `danger`/`dangerDim` accent — the token's scope
is amended by this brief's explicit owner direction, recorded in
`stride_colors.dart`), **DEFENSIVE** (temperature flipped: cool steel
`defenseSheen`/`defenseEdge`, aliases of the existing cobalt-dim hex — the
`positiveReady` precedent), **READY** (`positiveReady` outline — Craft
when craftable joins the moss "you can do this now" language the recipe
rows already speak), **NEUTRAL** (the existing secondary). Demotions are
half the design: Cancel, Stop gathering and Goal Board drop to NEUTRAL.

Haptics stay at call sites through the one audited `AudioController` seam:
exactly two additions (Gather start, Craft start — one pulse per
commitment, never per loop beat), none on Attack/Brace (the heavy-blow
haptic already lands the payoff). No new SFX (audio generation is closed).
A Brace shield glyph would need PixelLab and is deferred; the temperature
flip and labels carry the distinction this pass.

### 9. What equipment art already exists?

FEEL-F's audit (sources: `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md`, the
packaged tree, the exploration rounds): **on-body variants: none.** Every
Traveler strip is a flattened single-body PNG with one baked outfit
(tunic/scarf/backpack), one generic pale-steel sword across all combat
frames, one generic axe/pick/hammer in the work loops — regardless of what
is equipped, including nothing. No standalone weapon/tool/armor sprite
separate from the body exists. What is complete: **48 px item icons for
every equipment item in the game** — all 4 weapons, 8 armors, 8 tools.
The paused code-rendered character workstream is not canon and is not
equipment art.

### 10. What visible-equipment architecture is correct?

**(B) Precomposed equipment-state sprite sets behind a single resolver**,
per FEEL-E. Runtime overlays are rejected on the actual asset structure:
overlay art would need per-frame hand anchors and occlusion order on 100+
frames of flattened strips that already contain a baked generic tool —
the exact "forced layering" failure the brief warns against.

Two stages, both derived, no save change:

1. **`EquipmentVisualState`** — a pure fact projection on `StrideSession`
   beside `gearStatsOf`, read straight off `Equipment.bySlot` (the same
   map the engine consults): per slot, the item id, tier and tool kind.
   Nothing stored, nothing persisted (E-2); not in `stride_core` — variant
   vocabulary is art-coupled packaging fact, not engine content.
2. **`TravelerArt` resolver** (presentation layer) — string-keyed,
   data-driven tables mapping item ids to **coarse variant classes** and
   (sequence, variant) to strips. Absent entry → the base strip, exact
   current paths and footprints. **Never null, never faked.** A future
   PixelLab variant lands by packaging a strip and adding table rows —
   zero rendering-surface code changes.

### 11. What can be integrated now?

With zero generations: the projection, the resolver with total fallback,
the wiring of fetch sites through it (behaviorally inert — byte-identical
output today, pinned by a regression test), equipped-gear **icons** on the
Character screen's equipment block (the full ladder is representable as
icons today), and the tests. The foundation lands with zero visual change
to any animation surface.

### 12. What must wait for PixelLab production?

Every on-body variant. Production matrix (post-reserve, post-reset,
priority order an owner decision — logged in `JOURNAL/OPEN_QUESTIONS.md`):

| Set | Sequences to cover | Est. scale |
|---|---|---|
| Weapon variants (Training/Bronze/Longsword/Fang-Hilted, + an unarmed set — the baked sword currently contradicts an empty slot) | combat idle 9f + attack 4f + hit 6f (+ stagger 9f) | ~28 frames per weapon class |
| Armor classes (coarse: base tunic / hide / bronze / frost) | everywhere the body shows: combat, 16 ambient scenes, 5 work loops, walk, sprite, portrait | the largest set by far — batch by sequence family so partial delivery degrades to base per-sequence |
| Tool tiers (axe/pick classes) | woodcut 8f, mine 8f (+ inspect scenes if revived) | ~15 frames per tool class |

A deterministic palette-remap of the blade/tool-head pixels (steel→bronze)
is *marginal* under A-2 (it communicates material tier only, needs
per-frame masks, and is a creative call) — **not built**, recorded as an
owner question.

### 13. What is deliberately deferred?

The Brace shield glyph (PixelLab), a craft completion chime (audio
generation closed), camera route-framing during the travel presentation
(its own small review), the palette-remap tint (owner question), the
variant coverage priority (owner question), and any wall-clock, FOMO or
pet-system adjacency — rejected on the Kernel, not deferred.

---

## Implementation record

**Tier 1 — Travel** (`lib/ui/screens/world/travel_pacing.dart` new;
`travel_transition.dart` reworked; `atlas_layers.dart`,
`atlas_viewport.dart`, `world_screen.dart`, `atlas_selection_panel.dart`,
`session_controller.dart`): the pacing spec (15/18/21/22 walk passes =
9.90/11.88/13.86/14.52 s by hop count, all whole 660 ms passes); the
phased card (departure over the origin's vignette → travel loop over the
destination's with the committed cost line and a one-pass crossfade →
anticipation → one rest pass on frame 0, auto-dismiss); the
**one shared clock** (`TravelPresentationLink`: the card's controller is
the master, the map trace mirrors it and falls back to its own
identically-paced clock; skip snaps both); the trace's **multi-leg course
fix** (`JourneySummary.legPlaces` — the old single from→to pair drew a
straight line cross-country the moment a journey had a middle); the
arrival burst deferred to the anticipation phase behind a short adoption
grace (it used to spend itself entirely behind the barrier); the barrier
lightened 0xB3→0x66 so the map is the journey's visible second view;
skip-to-arrival after the 1.98 s window with a "Tap to continue" caption
and an honestly-stated semantics escape (disabled during the window);
one polite announcement on open. Reduced motion: no card at all —
FABLE_V2 checklist item 17 stays true.

**Tier 2 — Ambient** (`ambient_scene.dart`, `ambient_player.dart`,
`ambient_assets.dart`): `ScenePhasing` (intro/loop/outro over the
existing strips, `quantizedHold` landing the hold's final frame adjacent
to what follows, `frameAtSustained` so `once` layers still clamp — the
seated cat stays seated — while loops wrap); the player's dwell
(hold 20–28 s drawn per scene from `AmbientCadence`, applied only to
full scenes under the same resumed-lifecycle seam the idle cadence runs
under — the harness settles exactly as before, the seam extended not
doubled); drawn 3–6 s neutral gaps after held scenes; avoid-last-two
rotation. The phasing table is authored per scene in the one existing
table — cut points frame-inspected (crouch_pet re-verified 2026-08-28).
Scene totals: 2.0–6.7 s before, 20–30 s held now (pinned by
`ambient_dwell_test` against the shipped table). Micro-idles unchanged.

**Tier 3 — Craft** (`craft_significance.dart` new, `craft_memory.dart`
new, `craft_controller.dart`, `craft_screen.dart`, `reward_beat.dart`,
`reward_layer.dart`, `main.dart`, `stride_app.dart`): derived
significance (minor/medium/major — pure function, no per-item branch
possible); **queue-level fact accumulation fixing a truth bug** — a
level-up on repetition k<N was overwritten by later reports and its
LevelUpCard vanished (regression pinned in `craft_flow_test`); the beat
gains the item's 48 px icon and rarity ink (a `RewardBeat.icon` slot);
a per-boundary light haptic + skill-hue bar flash while watching (one
pulse per increment observed — a reconciled batch is one pulse); MAJOR
frame + heavy haptic for Epic+; the held layer announces itself once;
MINOR decay is **seen-gated** (the owner's brief: a finished queue's
summary waits for the player; PLAYABLE_POLISH_01 §C carries the
amendment note); first-craft elevation via a monotonic presentation-side
JSON memory on the audio-settings seam — never a lifetime factual claim,
never in the save.

**Tier 4 — Buttons** (`data_display.dart`, `stride_colors.dart`, ten
call sites): the pixel plate — flat `surfaceRaised` fill, 2 px lit top
edge, 1 px outline, hard 2 px under-ledge, 2 px press travel onto the
ledge with the light out (a state swap; reduced motion loses nothing);
disabled flat and ledge-less. Variants: COMMIT (warm), ATTACK
(danger-dim accent — the token's scope amended by this brief, recorded
on the token), DEFENSE (cool steel aliases of the cobalt-dim hex, the
`positiveReady` precedent), READY (moss). `Set out` is the sole glow
bearer. Demotions: Cancel, Stop gathering, Goal Board → secondary;
world-screen Travel promoted to commit. Two new commit haptics (Gather,
Craft start) through the audited `AudioController` seam. Every
secondary control's hit region now meets a 44 dp floor
(`StrideGeometry.buttonHitFloor`, FINAL-A M-1) while its visual stays
the quiet 34.

**Tier 5 — Equipment foundation** (`stride_session.dart`,
`traveler_art.dart` new, `combat_stage.dart`, `combat_screen.dart`,
`travel_transition.dart`, `character_screen.dart`):
`EquipmentVisualState` (facts: item id, tier, tool kind per slot;
value-equal; derived on read from `Equipment.bySlot`); the `TravelerArt`
resolver (coarse variant classes, string-keyed tables, **empty this
pass**, total fallback to the base strips — behaviorally inert, pinned
by `equipment_visual_test`); wired at the combat stage (snapshot at the
first bell) and the travel card; the Character sheet's combat block now
shows each worn piece's 48 px icon — equipment visibly real with
existing art. No save change of any kind. The production matrix and the
priority question are Q-14.

**Review:** FINAL-A ruled **INSTALL**; its M-1 (44 dp hit floor), N-1
(skip semantics honesty) and N-2 (PLAYABLE_POLISH_01 cross-reference)
are landed. **PixelLab generations this pass: 0** (balance verified
25 → 25, reserve intact, reset 2026-09-16).

**Suites:** app 836 (was 802; +34 across `travel_pacing_test`,
`travel_transition_test`, `ambient_dwell_test`, `craft_significance_test`,
`stride_button_test`, `equipment_visual_test`, and the craft
regression), `stride_core` 712, analyze clean, `package-art.js --check`
clean, goldens regenerated and reviewed (nine — the restyle's subjects).
Evidence: `GAME_BIBLE/ART/exploration/GAME_FEEL_CHARACTER_PRESENTATION_01/
evidence/` (travel departure + road, craft beat, gather plate, ambient
dwell, equipped icons, plus the refreshed v2/v3 sets).

## iPhone acceptance checklist

1. **Travel:** Set out on a one-road walk — does ~10 s read as a journey
   (departure beat, walk loop, arrival) rather than a delay? Watch the
   map dot behind the card: does it ride the road in step with the card?
2. **Travel, long:** a 2–3 leg journey (~12–14 s) — does the dot follow
   the actual roads through the middle place (not a straight line)?
3. **Travel skip:** tap immediately (nothing should happen), tap after
   ~2 s (should jump to "Arrived at …", never vanish the information).
4. **Travel, repeat:** after five journeys, is the pacing still welcome
   or does it want to be shorter? (The owner's call; the spec is one
   table.)
5. **Ambient:** open Adventure and put the phone down. Does the Traveler
   sit by the fire / read / pet the cat for a real 20–30 s each, with
   several seconds of standing between scenes? Does the cat keep moving
   through the whole scene?
6. **Craft, common:** queue ×5 planks — a light tap + bar flash per
   completion, one quiet summary with the item's icon at the end, gone
   ~4 s after you look at it. Does it stay out of the way?
7. **Craft, meaningful:** craft a piece of gear — the held layer with
   icon, stat story, Equip. Craft something that levels a skill mid-queue
   — the LevelUpCard must appear (this was silently lost before).
8. **Buttons:** do Gather / Craft / Set out feel pressable (the plate
   sits down under the finger)? Is Set out's glow right as the one
   weighty commit? Attack vs Brace — tell them apart without reading?
9. **Buttons, demoted:** Cancel / Stop gathering — quiet but still easy
   to hit?
10. **Character:** equip a different weapon — the icon on the combat
    block should swap with it.
11. **Reduce Motion (Settings → Accessibility):** travel resolves
    instantly with no card; the stage holds its standing figure.
