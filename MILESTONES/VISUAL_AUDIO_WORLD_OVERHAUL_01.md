# Visual / Audio / World Overhaul 01 — the thesis

```
STATUS: IN PROGRESS · branch visual-audio-world-overhaul-01 · from 6d41bce
Opened: 2026-09-01 · Authority: DECISIONS/0030 (owner ruling, 2026-09-01)
Evidence: MILESTONES/evidence/VAWO01/wave0/ (twelve audits)
Directions: GAME_BIBLE/ART/exploration/VAWO01/{GATHER_SCENE,WORLD_LIFE}_DIRECTION_01.md
```

**What this document is.** The diagnosis, the budget, the chosen order, and the
explicit rejections, written before the large production rounds rather than
after them. It is the record `DECISIONS/0030` requires and the thing a later
session reads instead of re-deriving twelve audits.

**One thing to read first.** The owner's complaints were all accurate, and
**four of them had a cause other than the obvious one.** The floating gather
object was not a placement bug. The generic UI was not leftover Material. The
"AI-generated" look is largely one missing typeface. And the bear looking small
was not an art problem at all. Each is set out below with its measurement.

---

## 1. Current presentation diagnosis

The product is **896 files of hand-authored pixel art rendered inside machine-drawn
rectangles**, and the seam between those two facts is what the owner keeps
naming. There is essentially **no stock Material anywhere** — `ListTile` 0,
`Chip` 0, `ElevatedButton` 0, `Divider` 0, `LinearProgressIndicator` 0,
`InkWell` 0 — so "looks generated" was never leftover framework defaults. It is
a design system that is too narrow, in four measurable ways:

1. **There is no typeface.** `pubspec.yaml` has no `fonts:` block and
   `fontFamily` appears nowhere in `lib/`. All **292 text sites** render in the
   iOS system font. Pixel art beside San Francisco is the literal signature of
   "Flutter UI over sprites", and it is the single largest remaining tell.
2. **One rectangle drew the product.** `SectionCard` at 33 sites, 28 taking the
   default role, 30 taking no wash — radius 14, one 1 px border, one fill.
3. **Type collapsed to one register.** 232 of 326 `StrideType` references (71%)
   are 11–13 px grey micro/sub styles. `screenTitle` is used **once**.
4. **Identity tokens exist and are unused.** `forRegion` and `forRegionDeep` are
   called exactly once each; `lockedScrim` has zero call sites.

Beyond the card, the shared layer stops: **96 one-off private widget classes**
in `lib/ui/screens`, **12 separate chip implementations** against a shared
`SkillChip` with **0** call sites, **6 progress-bar implementations** with no
primitive, and 4 divider implementations for a 1 px line.

## 2. Current gathering diagnosis

The owner's loudest complaint, and the audit confirms every part of it.

| Measure | Value |
|---|---|
| Gatherable nodes | **22** across 5 regions |
| Distinct backgrounds during a gather | **3** — keyed by *skill*, never by region |
| Distinct subject plates | **12** |
| Nodes sharing a subject plate with another | **17 of 22** |
| Nodes showing an **inventory icon** as the subject | **12 of 22** |
| Forgotten Hollow | **all five nodes are one image** |

**The floating object, mechanically.** The geometry was always right — the
subject's base already sat on the stage's ground line. The *light* was wrong.
`GroundedSprite` composites a footprint-derived contact shadow and its own
documentation says a bare `PixelAsset` on a background **is** the floating
defect; the Traveler has gone through it since Playable Polish 01; and
`AmbientStage._prop` — the thing he is hitting — built a bare `PixelAsset`. Every
gather scene grounded the man and floated the ore.

Compounding it: 12 subjects are 96² inventory-icon plates from the same PixelLab
stream as the 48² item icons, several carrying their *own* ground (a snow patch,
a separate soil line) pasted onto an unrelated backdrop.

Also found: the completion one-shot was the foraging pluck for **every** skill,
so a finished mining queue ended with the miner kneeling to pick a herb.

## 3. Current UI diagnosis

See § 1. The structural conclusion is that this is fixable at the **primitive**
level and not by editing screens: a single `PanelSkins` row changes ~28 panels
with no call-site edits, and a `fonts:` block changes 292 text sites.

The counter-fact that bounds the ambition: **Inventory, Craft and World are
dominated by hand-rolled surfaces** (15 and 14 ad-hoc `BoxDecoration`s
respectively against 2 and 3 `SectionCard`s), so the chassis does not reach
them. That is a refactor, not an art round.

## 4. Current equipment-visibility diagnosis

23 equippable items across 3 slots (4 weapons, 10 armour, 9 tools). **No on-body
gear art exists.** The base combat art has a generic pale-steel sword baked into
all four tracks — including when nothing is equipped.

The projection seam already ships, inert: `StrideSession.equipmentVisualState`
reads `equipment.bySlot` on demand and holds nothing; `TravelerArt` is the
resolver with **three empty tables**. Landing gear art is table rows plus
packaged strips, with **zero** new persisted state.

**Layering is not viable, and the reason is not cost.** Four measurements:
per-frame bbox centre travels **13.0 px** in `traveler_attack` and **23.5 px** in
`activity_woodcut` (the feared "2–3 px drift" is off by an order of magnitude);
no anchor data exists and 219 frames × 3 slots ≈ 660 grip records would be
per-frame anatomical judgement, which `A-1` gives to PixelLab; the baked blade
shares **all 7** of its colours with the body, so an overlay double-draws and the
steel→bronze remap floated in Q-14 is **not deterministic**; and occlusion is one
z-bit while the blade passes in front at attack f2 and behind at idle f0.

Also found: **Brace has no art** — `combat_choreography` holds `traveler.idle`
for 350 ms with the comment "no authored stance pose exists".

## 5. Current combat presentation diagnosis

13 enemies drawn by 9 sprite families. **4 of 13 fall through to another
enemy's complete art set** — the Veteran tier is literally the same files as its
base. Flinch art exists for **2 of 9** families; a heavy strike for **1 of 9**,
yet five enemies throw a doubled-damage heavy every third turn and play their
*ordinary* attack for it.

Silhouettes collide inside the quadruped group: **Wolf↔Lynx 69.5%** aligned-mask
IoU, **Boar↔Ram 68.8%**, Wolf↔Ram 59.8%.

Timing is nominally per-enemy and factually near-global: the player-strike beat
is **617 ms for 7 of 9 families, identical to the millisecond**.

And the encounter card **inverted the size ordering** — see § 17, fixed.

## 6. Current audio diagnosis

The architecture is sound; the content is almost entirely absent.

| Category | Declared | Sounding |
|---|---:|---:|
| Combat | 11 | **0** |
| Reward / outcome | 5 | **0** |
| Gathering | 4 | 3 |
| Crafting | 5 | 2 |
| Region music | 5 | 5 |
| **Total** | **26** | **10** |

Combat and reward together are **0 of 16**. There is no `playCue`, no
`setCombat`, no duck, no voice cap, no priority band. Eleven of twelve
player-facing moments have a haptic and no sound.

Two content defects in what does sound: **cooking has no transient at all**
(a steady sizzle plateau, so it punctuates nothing), and **mining is the
loudness floor** at −20.4 LUFS-M with a cue table that can only attenuate — so
the cue the owner said "should ring" cannot be raised (Q-17, open).

## 7. Current world / atlas diagnosis

The atlas is one 1024² image, **4.000 MiB decoded**, world scale 6. It cannot
get bigger: 2048² would be 16.78 MiB for a 2× linear gain.

**An overlay animation layer already exists and is fully data-driven** — 30
overlays on one shared Ticker, supporting drift, one-way travel, interval gaps
and per-overlay opacity. A green dragon already flies (28 frames, 68×31, 40 s
cycle). **Adding a creature touches no Dart**: frames → `emit()` lines → a
layout JSON entry.

Protection is real and machine-enforced: a hard-frozen core of
`x ∈ [276,747] × y ∈ [276,747]` (21.25% of the atlas) plus **15 byte-enforced
landmark goldens**. Roughly **70%** is fair game, and the register names its
defects with coordinates — the west treeline wall (D-01), the SW dark slab
(D-12), the south layer-cake (D-02).

## 8. PixelLab inventory summary

896 shipped files (23 MB); 6,286 files across 41 exploration rounds. **235 of
242 asset keys are referenced.** The real finding is not unused art:

> The biggest item on the menu is **already-shipped art used on one surface when
> it could serve seven.**

Chief among them: **262 combat files exist and the creature screen shows zero**;
six work backdrops resolve for the gather stage but not Skill Detail; five `alt_`
vignettes are consumed only by the atlas inspector. Also genuinely orphaned: 6
`env/prop_*` and `overlay_forge_smoke` (6 frames), each one JSON entry from
being visible.

And a caution: **~30 assets are off the table by prior blind QA** — the whole
`SKILL_ICONS_OD04` round, the Adit Bat and Hollow Weaver families, the weaver
attacks. That pruning is part of the deliverable.

## 9. New PixelLab budget

Verified live at open, per precondition P-0 — a remembered figure has been wrong
three times in this project's history:

```
generations_remaining: 10000 · used: 0 · Tier 3 · resets 2026-10-01
```

**Spent so far: 18**, all on Batch A. Generations are not the constraint.
**Blind review verdicts and device acceptance are**, and every estimate below
should be read that way.

## 10. Selected production art families

| Family | Plates | Est. gens | Status |
|---|---:|---:|---|
| **A — UI chassis frame** | 1 | 18 | **SHIPPED** |
| C/B/D/E/F/G/H/I — rest of the UI kit | ~20 | 30–60 | queued, spec written |
| **Gather scenes R1** | 18 | 60–110 | spec written (§ 6 of the direction) |
| Gather scenes R2 (project-gated) | 10 | 30–60 | after R1 device read |
| Item icons | 22 | 55–80 | prioritised list written |
| Enemies (veteran identity, quadruped break, flinches, heavies) | 17 tracks | 74–108 | batches 1–4 |
| Equipment W1–W3 + brace | 49 tracks | 400–640 | precomposed, axis-dominant |
| World life — the ten | 141 files | 450–550 | placements written |

Full plan ≈ **1,100–1,600 generations**, roughly **11–16%** of one cycle.

## 11. Selected audio families

Combat (11 cues), reward (5), profession completion, level-up. **Blocked on
credentials**: `STABILITY_API_KEY` and `ELEVENLABS_API_KEY` are both unset and
no credential file exists in the repo, so **no new audio can be generated in
this workstream until the owner supplies a key**.

What is *not* blocked, and is the majority of the work: the cue tables, priority
bands, voice cap, music duck, `setCombat`, `fallbackTo` chains and trigger
wiring at ~20 named sites — none of which needs a file, because
`AudioController.fileFor()` already returns `String?` and an unresolved cue is
silent rather than fatal. Plus **40+ already-paid-for candidates** sitting
unshipped in `AUDIO/evaluation/`, never re-auditioned against the current mix.

**Q-16 is a prerequisite, not a note.** Combat reads `disableAnimationsOf`
nowhere; under Reduce Motion a 2.5 s round collapses to ~125 ms and
segment-placed cues would arrive nearly simultaneously with no voice cap to
absorb them. Landing combat audio before answering it repeats M-16.

## 12. Selected world additions

Ten overlay slots, because the performance budget allows ~40 declared and ~12
drawn and **30 are already declared**. Ranked: red fire-drake · Rimespire (ice
tower) · The Black Gable (storm house) · Lanterngard (fairy court) · blue
storm-drake · aurora · wolfpack · crows · fae motes · ox-cart. Three landmark
*bodies* are static named-landmark PNGs and cost no slot; only their magic does.

**IP safety is designed in, not asserted**: an ice-accreted Nordic stave tower
rather than a crystal palace; a ring of standing stones colonised by blackthorn
rather than turrets; a tarred-board Hebridean croft rather than a Victorian
mansion. Fairies are motes of light, never humanoid figures. And nothing here
uses the teal-green family at all, because L-16 reserves it for walking.

## 13. Equipment architecture

**Precomposed variants with per-surface axis dominance** — not layering (§ 4),
and not the full cross product. Vary weapon × armour in combat, tool at work,
armour on walk/gather-rest/portrait, and leave the 14 solo ambient scenes at
base permanently. W1–W3 plus the missing brace stance is ~49 tracks and 51 blind
verdicts.

**Save impact: zero, and already met.** Equipment persists as
`Map<EquipmentSlot, ContentId>`; the visual state is a getter that writes
nothing, pinned by `equipment_visual_test.dart`. Variant classes are
presentation-layer const maps. State stays **v9**, and revert is emptying a map.

**Risk to put to the owner before W1:** under axis dominance a bronze-armoured
player still fights in a tunic. Either that is accepted, or W4 (weapon × armour
in combat, +510–830 gens) is funded.

## 14. UI architecture

One frame family app-wide through `PanelSkins`, per L-18 as amended. Flutter
keeps layout, text, measurement, state and interaction; raster occupies only a
panel's outer edge, a low-variation interior surface, or a discrete ornament.
The enforcing property — **empty the registry and the product returns to the
painted rectangle in one commit** — is preserved and tested.

The highest-leverage remaining items are not art: a **typeface** (292 sites, 2
files, 0 generations), a **wider type scale**, a **scrim token family**, one
`StrideChip` replacing 12, and one `ProgressTrack` replacing 6.

## 15. Save impact

**None.** All six planned change families were audited against the persistence
layer and are migration-free; state version stays **9**. Audio settings live in
an unversioned sidecar whose decoder is tolerant, so new keys are additive by
construction. Explicitly refused under `DECISIONS/0030`: persisting an art key,
an equipment variant id, a cosmetic override, or per-creature world state —
each converts a free change into a schema-v10 migration for no player-visible
gain.

## 16. Performance risks

Budget: **+24 MiB decoded** (total ≤ 44), ≤ 12 animated world elements in frame,
≤ 2 tickers, ≤ 4 audio voices, ≤ 3 sprite layers per character, +2.5 MB PNG.

Four named exposures, one already closed:

- **K-1, closed.** The image cache defaulted to **1,000 entries** against a
  bundle of **872 PNGs**, binding on count ~4× sooner than on bytes; the world
  plan alone would take it to 1,012. `maximumSize` is now 2000 and
  `maximumSizeBytes` deliberately *lowered* to 48 MiB so overspending shows up
  as a QA stutter rather than invisible growth.
- **K-2.** Hidden tabs stop ticking but not rebuilding — one `notifyListeners`
  re-lays-out a 6144² offstage Stack.
- **K-3.** `Opacity` over a multi-child world creature forces a real `saveLayer`
  at 2.73 MB per creature per frame. Every world overlay must wrap exactly one
  image.
- **K-4.** No performance test or profiling harness exists anywhere.

Confirmed good: **no animation runs while hidden** — all 16 tickers pause and all
16 are disposed. And `cacheWidth`/`ResizeImage` stay **forbidden**: resampling at
decode drops columns before `filterQuality` is consulted, so the usual
"downscale large images" advice is actively wrong here.

## 17. Chosen implementation order

Ordered by visible payoff per unit of risk, not by the phase list.

| # | Step | Gens | State |
|---|---|---:|---|
| 1 | Guards (palette, tile-seam), budget decision, G-8 hazards | 0 | **DONE** |
| 2 | UI chassis frame + image-cache sizing | 18 | **DONE** |
| 3 | Gather grounding + per-skill one-shot + ratchet test | 0 | **DONE** |
| 4 | Encounter-card scale inversion + golden race | 0 | **DONE** |
| 5 | Typeface + type scale | 0 | next, highest leverage |
| 6 | Free asset utilisation (combat idles → Field Notes, work backdrops → Skill Detail, orphan props → atlas) | 0 | next |
| 7 | Enemy batch 0 (per-enemy timing, wire `wolf_hit`) | 0 | next |
| 8 | Audio architecture: cues, duck, voice cap, Q-16 | 0 | next |
| 9 | Gather scenes R1 | 60–110 | needs the § 3 density ruling |
| 10 | Item icons, enemy batches 1–4 | 130–190 | |
| 11 | Equipment W1–W3 + brace | 400–640 | needs the § 13 owner ruling |
| 12 | World life — the ten | 450–550 | |

Steps 1–4 are landed and are the reason this document can be specific.

## 18. Explicitly rejected

- **Layered equipment compositing.** Measured, not assumed — § 4. It also
  reverses a recorded architectural decision in `traveler_art.dart`.
- **The audit's "9 plates close every gather P0".** On enumeration it yields 11
  distinct scenes against today's 12 — it would have made the product *worse*.
  The real number is 18.
- **A full palette conform of generated UI art.** Tried; it passed the guard and
  produced an olive frame that had stopped being leather. Only the ceiling
  breach is corrected — 5 colours, 208 pixels.
- **Thinning a border by asking for it.** Three rolls at "four pixels thick"
  fragmented into 57–68 components. To change a border's weight, change the
  canvas.
- **A 2048² atlas.** 4× the memory for 2× the linear detail.
- **Walking humanoids at settlements**, and any composition implying free-roam —
  `ART_DIRECTION` forbids art that introduces mechanics.
- **A second teal.** `#58D6C0` appears in exactly one file and this workstream
  does not add a second; a guard now measures it.
- **New gameplay systems.** The owner's instruction is explicit: Depth Offensive
  added the gameplay; this makes it feel better.
- **Bitmap type.** Not in scope and not a future option under `0029`.

## 19. Acceptance criteria

**Landed and verifiable now**

1. `flutter analyze` clean; **976 tests pass**.
2. `check-art-palette` green across 872 PNGs; `check-tile-seam` green on all
   four chassis runs; `package-art --check` green at 851 files.
3. Goldens are **deterministic** — the suite re-run twice produces no diff.
4. Every gather node resolves a subject with a **measured** footprint.
5. Emptying `PanelSkins.authored` returns the product to the painted rectangle.
6. Large-text support is not reduced: `ui_responsive_test` green at ×1.4 / 320 dp.

**Requires the iPhone, and is not claimed until then**

7. The chassis reads as authored leather at device scale and does not crowd
   text on the smallest supported width.
8. Mining, woodcutting and foraging subjects read as resting on the ground.
9. The Oakback Bear reads as larger than the Grey Wolf on the encounter card.
10. No frame rate or battery regression on the Adventure and World tabs.

**Not yet begun** — 5 through 12 of § 17, and every acceptance criterion that
depends on them.

---

## Open questions this workstream must not answer silently

- **Q-13** — the atlas lime band. Gates the southern zone. Owner's.
- **Q-16** — the accessibility channel rule for combat. **Blocks combat audio.**
- **Q-17** — mining's loudness floor.
- **L-18a (proposed)** — the gather-scene density ruling, which fixes the native
  size of all 18 new plates. `GATHER_SCENE_DIRECTION_01` § 3 makes the case;
  it is an amendment to a LOCKED document and is the owner's to ratify.
- **Equipment axis dominance** — § 13's bronze-armour-in-a-tunic consequence.
- **`AUDIO/evaluation/`** — 652 MB now safely ignored down to 0.12 MB of
  provenance. Whether the provenance and tooling should be committed is open.
