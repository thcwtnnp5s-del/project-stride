# Presentation & Combat Evolution 01

**Branch:** `presentation-combat-evolution-01` (from `fable-depth-offensive-01` @ `9b61964`)
**Date:** 2026-08-31
**Status:** 🧪 Awaiting the owner's device evaluation. Not merged.
**Decisions:** `DECISIONS/0029_UI_ART_DIRECTION_AMENDMENT.md` (owner ruling — L-18 amended)
**Budget:** **Zero** PixelLab generations (balance exactly 25, the atlas reserve, untouched).
**Zero** audio generated — `STABILITY_API_KEY` is unset, so generation was unavailable and the balance is unverifiable.

---

## 1. Why the UI reads as generic — and why the obvious answer was wrong

The owner's charge was that Stride "still looks too much like generic /
AI-authored Flutter UI" and feels like "an application displaying RPG data".

The charge is **accurate**. The usual explanation for it is **not**.

A forensic sweep found **no stock Material anywhere in this app**. Searched and
absent: `Card`, `Chip`, `ListTile`, `ElevatedButton`, `TextButton`,
`OutlinedButton`, `FloatingActionButton`, `LinearProgressIndicator`,
`CircularProgressIndicator`, `AlertDialog`, `showDialog`, `AppBar`, `TabBar`,
`BottomNavigationBar`, `Divider`, `InkWell`, `Icons.*`. `LinearProgressIndicator`
appears exactly once in the codebase — inside a comment refusing it. Only 7 of
~40 UI files even import `material.dart`. Splash, highlight and hover are all
explicitly disabled.

So the genericness is not boilerplate, and "it looks AI-generated" is the wrong
diagnosis of a real symptom. The actual causes, ranked:

1. **One rectangle, thirty-four times.** `SectionCard`
   (`lib/ui/components/surfaces.dart:25`) is the outermost container on every
   screen: radius 14, one 1 px border in one colour (`#372F27`), one fill
   (`#201C17`). **Thirty-one of thirty-four call sites do not even take the
   optional hue wash**, and the washes that exist are authored *within ~6 L\* of
   the card colour* — sub-perceptual by construction, so they cannot carry
   identity however they are applied. Character, Craft and Inventory differ from
   each other by **heading string alone**.
2. **The biggest word on every screen was the name of a menu.**
   `stride_shell.dart:80` set `title: _selected.label`, so "Adventure" /
   "Inventory" / "Craft" rendered at 19 px bold while the *place* sat above it
   as an 11 px eyebrow — and the tab bar reprinted the same word 4 dp below.
3. **Nine of twelve surfaces contain no image at all.** Every `PixelScene` call
   site lives on World, Travel, Adventure, or Craft-while-running. Skills, Skill
   Detail, Inventory, Character, Step Tracker, Goal Board, Field Notes and
   Craft-at-rest render zero pictorial content, ever — while ten location
   vignettes are packaged and only five are used.
4. **Nothing in the interface is made of a material.** `assets/ui/v1/` holds 21
   files, all 12–24 px nav and skill glyphs. Zero frames, zero borders, zero
   textures, zero ornaments. `lib/` contained no nine-patch renderer, no
   `DecorationImage`, no `centerSlice`, no `ImageRepeat`.
5. **The contrast budget for hierarchy is spent.** Four near-blacks spanning
   ~14 L\*, one accent reserved system-wide for walking (L-16), no
   warning/positive/error hue by decision. Hierarchy can therefore only come
   from **size, image and space** — and image was the one the rules forbade.
6. **One gap everywhere.** `cardGap = 10` between every pair of cards on every
   screen. A uniform gap over uniform cards is the definition of a table.

The seam underneath all of it: **896 files of hand-authored pixel art render
every creature, item, place and character in the game, and every container
around them was a rounded rectangle from a layout engine.** Hand-made sprites
inside machine-drawn boxes. That is what "authored RPG versus application" looks
like from the player's side.

### The primitives responsible

| Primitive | File:line | Sites | Verdict |
|---|---|---|---|
| `SectionCard` | `surfaces.dart:25` | **34** | **The primary cause.** Now takes a `PanelRole`. |
| `SectionHeading` | `surfaces.dart:120` | 28 | Uniform uppercase micro-label everywhere. |
| `ScreenHeader` | `screen_header.dart:17` | 6 | **Inverted** — the place is the title now. |
| `LabeledValueTile` | `data_display.dart:18` | 16 | The label-over-value pattern, self-described as "the system's dominant pattern". |
| Six hand-rolled progress bars | six files | — | All avoid Material's widget and land on Material's *form*. |
| Four pill/chip shapes | four files | — | One visual language, reimplemented four times. |
| `StrideSpace.cardGap` | `stride_metrics.dart:40` | 29 | One rhythm, no grouping information. |

---

## 2. Target visual language

Shared DNA, all screens: the page is a dark journal leaf and a panel is an
**object placed on it**; key light upper-left everywhere, chrome included; every
screen shows at least one picture, and if it has no subject it shows the place
it is happening in; **type is ink and images are artifacts** — no word is ever
raster and no picture ever carries a readable word; two levels of space and only
two; **one frame family app-wide**, with per-system identity coming from band,
surface and picture rather than from eleven different borders.

The last clause is the one most likely to be violated later, and it is the
reason `PanelRole` is a closed set of six *kinds of surface* rather than a role
per screen.

---

## 3. What PixelLab should author, and what Flutter keeps

`DECISIONS/0029` records the owner's amendment of L-18 and states the boundary.
In short:

**Raster owns** content (already true) and *material*: a panel's outer edge, its
interior as a low-variation tiled surface, and discrete ornaments Flutter
positions.

**Flutter keeps, permanently:** all text; all layout, sizing and hit targets;
every dynamic value; every state (pressed, disabled, selected, locked — a frame
has one state); accessibility; responsiveness.

**The enforcing test, which CI runs:** with every frame asset removed from the
build, the app must still lay out, read, navigate and pass its accessibility
assertions. Art may change how Stride *feels*; it may never change what Stride
*does*. That is `test/panel_skin_test.dart`, and it is why the registry ships
empty.

Full per-asset production plan: `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md`.

---

## 4. Combat diagnosis

**Mechanically the fight is sound. It has no voice.**

- **Zero sound of any kind.** No swing, impact, bite, death, heal, brace,
  victory or defeat. `AudioCues` had no combat entries at all, and `setRegion`
  has one call site (on location change), so region music plays unchanged
  through every fight.
- **`EncounterStartedBeat` emitted zero segments.** Nothing marked the start of
  a fight.
- **Brace — the one tactical action the game added — had no presentation.** 350
  ms of the *idle* track: no pose, no sound, no haptic. It read as a hang.
- **One haptic in an entire fight**, and it fired at the wrong time (below).
- **Seven of nine enemies have no flinch track**; they get a flat 6 dp recoil.
- **The Scree Crawler could not be seen to die** — neither a defeat nor a hit
  track, so the victory segment was a bare 400 ms while the stage kept drawing
  its idle until the reward panel covered it.
- **Combat ignored Reduce Motion entirely** — no `disableAnimationsOf` read
  anywhere under `lib/ui/screens/combat/`.
- **The scene freezes on frame 0 after an 8 s idle visit** — exactly while the
  player is deciding whether to brace.

### The finding that reframed the work

Equipment **already decides every fight in this game, completely**, and the game
never says so. Worked against the shipped roster:

| Fight | With | Result |
|---|---|---|
| Oakback Bear (55/11/3 guarded), lvl 10 | Bearhide Coat, def 9 | heavy 13, ordinary 1–3 → **win at ~64% HP** |
| same | Traveler Tunic, def 2 | heavy 20, ordinary 8–10 → **dead on turn 5** |
| Old Grey (48/13/4 flurry) | Clawguard, def 9 | **win at ~10 HP** |
| same | Bronze Chestplate, def 7 | **loss on turn 5** — two points of armour |
| Scree Crawler (34/6/6) | Training Sword (3) | 1 damage, floored, for **34 rounds** |
| same | Bronze Longsword (12) | 6 rounds |

None of this is broken. All of it is silent. **Combat's problem was never a
missing mechanic; it was a working tactical system with nothing to say.**

---

## 5. Audio diagnosis

`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md` requires three beats per major action —
**initiation, material response, reward confirmation**. Only the middle one
ships. That single sentence explains the owner's "effectively silent" report
better than any quality judgement.

Six defects, all fixed here, none requiring generation:

| # | Defect | Evidence |
|---|---|---|
| 1 | **Reduce Motion was a total SFX blackout** | `ambient_stage.dart:582` stopped the controller → `_onTick` never ran → `onBeat` never fired. Every cue, silently, forever. Recorded as **M-16**. |
| 2 | **The mix was never level-matched** | SFX mastered to peak, music to loudness. Measured LUFS-M max on the shipped files: smithing **−10.0**, foraging −17.2, woodcutting −18.4, cooking −18.9, mining **−20.4** — a **10.4 dB spread**. |
| 3 | **Cooking fired every other stir** | 1,500 ms floor over a 1,320 ms cycle, defended against a "1,430 ms" figure the frame list never matched. |
| 4 | **Three `!` crash sites** | `AudioCues.files[id]!` threw from inside a `setState` frame; the asset test iterated `files` and so could not see a dangling reference. |
| 5 | **The heavy haptic fired up to 625 ms early** | at segment start, under a comment claiming it landed "as it lands on screen". |
| 6 | **No haptic rate limit anywhere** | the scarcity rule was prose the code could contradict. |

Coverage was the real story: **three** `playSkillCue` call sites, all animation
callbacks, against **twelve** haptic sites marking commits and payoffs. Eleven of
twelve had a haptic and no sound.

---

## 6. Craft and profession reward diagnosis

The universal `ActivityResult` covers **2 of 11** completion types. The craft
path already distinguished a Bronze Sword from Herb Broth on real data
(`equipDelta`, `outputRarity`, 120 s vs 60 s bench time, `craftSignificanceOf`).

**The gather path was blind to rarity.** `ActionReport` dropped the `Rarity`
that `InventoryEntry` and `DropPreview` both already carried, so Rare Gloom
Silk — a genuine node yield — rendered exactly like Common Copper Ore. The best
moment a gathering session can produce was also its quietest. Fixed.

---

## 7. Rulings

### 7.1 Slash / Crush / Pierce — **NO**

Reopened as instructed, and refused on the evidence.

There are exactly **four weapon-slot items and all four are swords** — training
(3), bronze (9), fanghilt (10), bronze longsword (12). The split would be
**4 Slash / 0 Crush / 0 Pierce**: a three-way system whose every member is in
one category is not a system, it is a field.

The nine axes and pickaxes are **tool-slot and contribute exactly zero to
combat**, by a guard written specifically against this
(`combat_rules.dart:128`: *"a content pack that puts a hatchet in the weapon
slot cannot make it a sword by accident"*). Reversing it would put a hatchet in
the weapon slot and still have the Traveler swing a **pale-steel sword**,
because `TravelerArt.combatVariants` is an empty map and every combat frame has
that sword baked in — including when nothing is equipped. That is the same
invisible lie the brief forbids, inverted.

The item art is a documented three-family silhouette system — blade, lopsided
wedge, symmetric two spikes. **There is no hammer, mace, spear, bow or staff
anywhere in the item set.**

**Prerequisite to reopen** (a self-contained art milestone, not an increment):
4 new weapon items · 4 new icons · **2 new icon silhouette families** · 3 on-body
combat sets (including a mandatory *unarmed* set) · 84 frames · 12 animation
jobs · one optional enemy-side field · ~4 recipes touching the frozen Bronze
Lineage. Estimated **300–700 generations** against a balance of 25.

### 7.2 Iron vertical slice — **NO, this round**

There is **not one unused item icon on disk**. Every grey metal image is a live
item, and `scrap_metal`'s own authored prompt is literally *"dull grey iron"* —
it already occupies the exact ramp position iron must use. The byte-copy
precedent requires the copy's recipe to **consume** its donor; iron is a
*parallel* tier, so it does not qualify, and applying it anyway would put
identical pixels on two items that live in the bag together permanently.
Code-tinting is forbidden by A-1 in the codebase's own words.

**Minimum honest cost: 8 generations** (iron_ore, iron_ingot, iron_sword,
iron_axe, iron_pickaxe, iron_chestplate, node plate, work prop), **12 with a new
location** — plus blind QA against `tin_ore`, `scrap_metal` and `bronze_ingot`
as confusion partners. Queued for after the reset.

### 7.3 Provisioning — **NOT SHIPPED**

Deliberately not taken. The workstream's own combat finding is that the existing
preparation layer — armour, brace, food timing — is *already decisive and
already invisible*. Making that legible is strictly higher value than adding a
fourth preparation axis on top of it, and doing both at once would make the
device verdict unreadable. Reopen after the guard reading has been played.

### 7.4 What replaces them

**THE READ.** Knowledge buys **foresight, not power**. At Studied the fight
states what the creature's blow costs *against the armour actually worn*, and
the Brace button states what bracing would save — `Take 9 instead of 19`,
computed from the coat. Swap the coat and the number moves.

Zero engine change, zero content change, **state stays v9**, no new stat, no
resistance table, no roll altered, nothing mandatory. Every figure is a pure
projection of facts the resolver already guarantees, pinned to it by a 546-case
parity test.

---

## 8. Shipped this round

**Audio integrity** (`4c1d822`) — the six defects in §5, plus a general
`fileFor` resolution that lets an event be wired before its sound exists.

**Surfaces** (`9d4bfd4`) — `DECISIONS/0029` and the L-18 amendment at its
source; `PanelRole` + `PanelSkins` registry (empty) + `PixelFrame`, a **tiled**
nine-patch that refuses `centerSlice` because it stretches; the boundary guard
extended to `DecorationImage`/`paintImage`; the header inversion; gather rarity.

**Combat** — the guard reading and its parity test; the Scree Crawler's
fall-out and a no-invisible-death guard over every enemy; the heavy haptic moved
to the frame the blow lands.

### Caught in review, before it cost anything

`PanelSkin.inset` used the **corner block** rather than the band, which would
have inset every panel by ~32 logical px a side — a fifth of a 320 dp screen —
and the resulting text-wrap regression would have been blamed on the art. A
separate measured `band` field now carries the layout figure.

---

## 9. Waiting on production capacity

- `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` — per-asset dimensions,
  tiling strategy, prompts, destinations, priorities, batches. First
  post-refresh window buys **Batch A (the chassis frame) alone**, because every
  later batch is authored inside it.
- `AUDIO/AUDIO_PRODUCTION_QUEUE_01.md` — 23 cues with verbatim prompts, seeds,
  costs and written rejection criteria. **The recorded 61 credits cannot buy
  P0** (200 at one roll, ~520 at this project's measured reroll rate).
- Free actions worth taking first, at zero credits: re-measure the unshipped
  mining candidates (`4101` is 1.3 LU hotter than the shipped anchor with a
  tighter transient — an anchor swap may beat the queued limiter re-master),
  and four listening passes that could retire two P2 cues.

---

## 10. Deferrals, explicit

| Item | Why |
|---|---|
| Slash/Crush/Pierce | §7.1 — needs its own art milestone |
| Iron tier | §7.2 — 8–12 generations minimum |
| Provisioning | §7.3 — measure the existing preparation layer first |
| The combat **engage** beat | `replays()` returns `beats.any((b) => b is! EncounterStartedBeat)`; emitting a segment there changes control-locking semantics that `combat_busy_test` and `combat_presentation_order_test` both assert. Real regression risk, and its payload is mostly a sound that cannot be produced yet. |
| The 8 s idle freeze | Bounded-breath design specified; not implemented this round. |
| Brace's held pose | Specified (hold `traveler_hit` f5, guard band). Deferred with the engage beat as one presentation pass. |
| Combat music duck | Architecture ruled (Option B: duck the regional bed, no new track); not implemented. |
| Talent tree, daily systems, elite tiers, guard-stat proliferation, tunic branches | Owner-prohibited. Untouched. |
| Atlas | Out of scope by instruction. Untouched. |
| Health, steps, economy, save format | Untouched. No state version change. |

---

## 11. Known issues

- **CI IS RED ON THIS BRANCH, and it was red before it.**
  `lib/ui/state/craft_memory.dart` violates two UI-boundary rules
  (`path_provider` import at :29, `File()` at :47 and :81) — **pre-existing**,
  introduced by GFCP01 `830f1a1`, not by this workstream.

  An earlier draft of this section said the failure "strongly suggests that
  guard is not currently being run." **That was wrong, and the truth is
  worse.** `.github/workflows/ci.yml:125` runs `check-ui-boundary.sh`
  unconditionally, with no `continue-on-error`, *before* the analyzer and the
  test suites. So CI fails at that step and **never reaches** the 966 app
  tests reported here — every suite figure in this document and in
  `PROJECT_STATE.md` is from a **local** run.

  Two consequences worth stating plainly. The `DecorationImage`/`paintImage`
  rule this workstream added to that same guard — the one protecting L-18's
  surviving paragraph from the moment authored frames land — is correct in
  source and **unreachable in practice** while the gate is red. And a guard
  that always fails is a guard people learn to skip, which makes the next
  person to skip it the person shipping the first frame asset.

  Still flagged rather than fixed here: it is durable-state plumbing, out of
  this pass's scope, and the right fix (move it behind `StrideSession`, or
  open a named ADR-backed exemption — never a loosened pattern, `RULES.md`
  G-4) deserves its own change. **It must close before this branch merges.**
- Combat still has **no sound**, by necessity. The wiring is ready; the assets
  are not producible. Device review should judge the *picture* and not report
  the silence as a new defect.
- `textMuted` (`#7C7263`) fails WCAG AA on all four surfaces (3.58 / 3.16 /
  2.63 / 3.96). Pre-existing, palette-wide, not addressed here.

---

## 12. iPhone acceptance checklist

Install with `Scripts/ios/build-release-device.sh` — **not** Xcode's Run
button, which installs a Debug build (M-09).

**Read this first: combat is silent, by necessity.** `STABILITY_API_KEY` is
unset, so no audio could be produced this round. The combat cue architecture is
wired and resolves to silence. Judge the *picture* and the *figures*; the
silence is a known, queued gap, not a new defect.

### A — The header inversion (all six tabs)

1. Walk each tab. The **place** should be the large word, in the region's own
   colour; the tab name is the small uppercase line above it.
2. **Travel somewhere and re-check all six.** The title should change on every
   tab. If it does not, the inversion is not doing its job.
3. The honest risk, and the thing to judge hardest: with the region constant,
   five list screens now have near-identical headers, and the only thing
   distinguishing them is 11 px. **Is the place worth that?** A reviewer
   already argued no. If you agree, say so — the change is six lines and
   reverts cleanly.

### B — The guard reading (the round's headline)

4. Fight something until it reaches **Studied** (3 wins for most, 2 for the
   bear and the Guardian). Below that there is deliberately no reading.
5. The line above the controls should read *"Your armour takes it to …"*, and
   the **Brace button should state its own worth in figures**.
6. **The point of the whole feature:** change armour and fight the same
   creature again. **The number must move.** If it does not, the feature has
   failed regardless of how it looks.
7. Find a case where Brace says *"gives up your strike"* rather than
   recommending — an ordinary turn in good armour. It should refuse to
   recommend itself when bracing is a bad play. A button that always argues
   for itself is the defect this was rebuilt to avoid.
8. On a **flurry** enemy, check the round total reads clearly ("3–5 each, 6–10
   this round") rather than making you add.
9. Is this legible, or is it a spreadsheet? Two reviewers split on this. Your
   call decides whether the line stays or only the button keeps the figures.

### C — Combat presentation

10. Kill a **Scree Crawler** (Stonefall). It should now visibly sink and fade.
    Before this round it kept idling until the reward panel covered it.
11. Take a **heavy blow** from a guarded enemy (bear, salamander, Guardian).
    The haptic should land *with* the blow, not before it. It used to fire up
    to 625 ms early.
12. Win a fight and confirm the victory tap still fires right after a heavy
    blow — a rate limit was added, and payoffs are exempt from it.

### D — Audio (the six defect fixes)

13. **Turn Reduce Motion ON** (Settings → Accessibility → Motion). Gather
    something. **You must still hear the profession cue** while the picture
    holds still. This was a total, silent, product-wide SFX blackout — M-16.
14. Compare **smithing** against **mining** and **cooking** at equal volume.
    Smithing was 10.4 dB hotter and is now attenuated 7 dB. Ratify or ask for
    a retune.
15. **Mining is the floor and I could not raise it** — a trim can only
    attenuate. Q-17 offers three zero-credit routes (limiter re-master, anchor
    swap to an unshipped candidate, lower music default). Say which you want.
16. Cook something and confirm the sizzle now lands on **every** stir rather
    than every other one.
17. Check the ring/silent switch — `respectSilence: true` means the hardware
    switch mutes everything. If the game seems silent, check this first.

### E — Everything that should be unchanged

18. Travel presentation, ambient scenes, buttons, craft completion cards — all
    device-PASSED previously and deliberately untouched.
19. Gather something **Rare** (Gloom Silk, from a silkstrand thicket). It
    should now take the accented frame and longer hold that a rare craft
    already got. It used to look exactly like Copper Ore.
20. Panels look **exactly as before**. That is correct: the frame architecture
    shipped with an empty registry and no art. Nothing should have moved.

### F — Decisions this checklist is asking for

- **B-3**: keep or revert the header inversion.
- **B-9**: keep the guard-reading line, or let the Brace button carry the
  figures alone.
- **D-15**: which route for mining.
- **Q-15**: buy the Slash/Crush/Pierce art milestone (~300–700 generations), or
  close the question.
- **Q-12 / Q-06**: unchanged, still open. Note that a verdict on Brace taken
  *with* the reading enabled is a verdict on Brace **plus** the reading.
