# GOV-01 — Canon / Rules Guardian report for FMPO02

**Scope of this report:** what must not be broken. No new scope invented, no
UI-quality audit performed. Sources: `RULES.md` (full), `MISTAKES.md`
(headers + M-12/M-14/M-15/M-16 bodies), `PROJECT_KERNEL/` (skim),
`DECISIONS/0029-0032` (full) + `0005` (grep), `STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`.

---

## 1. LOCKED rules/invariants relevant to art, UI, world, audio, equipment, persistence

- **P-4** — No wall-clock progression; step-clocked only, except the named
  finite background-activity exception (`0022`). A new activity/queue feature
  in FMPO02 may not invent a second time-based exception.
- **P-5** — Absence is never punished: no decay, expiry, streaks, FOMO, upkeep.
- **P-6** — No monetization systems: no premium currency, coins, price tags,
  loot boxes, gacha, battle passes. Directly binds reward art and any UI meter.
- **P-7** — Defeat costs progress, never possessions/equipment/inventory/XP.
- **P-9 / P-10** — Goal tracking never reserves/escrows/auto-spends steps;
  repeatable RNG is never load-bearing; permanent effects apply exactly once.
- **E-1** — `stride_core` is pure Dart (no Flutter/plugins/dart:io/clock/RNG).
  Enforced by `Scripts/check-core-purity.sh`.
- **E-2** — UI must never become an alternate source of durable game state;
  widgets read state and dispatch commands only.
- **E-3** — Single-writer persistence: no background isolate/callback may touch
  `SaveRepository` or the save directory. `Scripts/check-single-writer.sh`.
- **E-5** — Content is data, not code; no hardcoded game content.
- **G-3** — Unresolved design choices stay `UNRESOLVED` in
  `JOURNAL/OPEN_QUESTIONS.md`; an agent may not silently decide one.
- **G-4** — Never weaken an invariant/guard to make a test pass.
- **G-7** — One canonical home per concept; no duplicate authority.
- **G-8** — Stage explicit paths; never `git add -A`/`git add .` (see M-08, trap
  below — this repo currently has ~25 untracked exploration dirs on disk).
- **A-1** — PixelLab is the production-art/animation engine. Claude art-directs,
  prompts, selects, edits/inpaints, integrates — **never hand-draws production
  art or animation frames in code.** If PixelLab fails: keep the temp asset,
  record failure, escalate — never silently substitute code-drawn art.
- **A-2** — Deterministic transformation (crop, nearest-neighbour scale,
  sheet assembly, keying, palette/index remap, state derivation, format
  conversion) is permitted in code **only if it invents no new object,
  silhouette, frame, or illustrated content.**
- **A-3** — Atlas expansions must be transition-authored across every boundary;
  a generated boundary never ships until a blind read at iPhone-viewport scale
  confirms biome/coastline/detail-scale/palette continuity with no visible
  generated rectangle.
- **A-4** — Approved atlas interiors are protected in tooling; a repair may
  write only its transition band. Repainting approved geography to solve a
  seam is a defect. Enforced in `Scripts/art/package-art.js`.
- **L-15/L-16/L-17** (`GAME_BIBLE/ART/ART_DIRECTION.md`) — icon semantics and
  reserved teal (detail in §2/§3). Explicitly reaffirmed unchanged by both
  `0029` and `0031`.
- **L-19** — Bronze reads as bronze/reddish-copper, never bright gold bullion.
- **H-1 through H-7** — step/health accounting is completely out of scope for
  this workstream per `0030`; FMPO02 must not touch anything under
  `packages/stride_health` or step/economy/save semantics.

---

## 2. Palette / density / pixel-scale numeric constraints

- **L-18 (as amended by `0029`)**: every pixel asset at an exact **integer**
  multiple of native size, nearest-neighbour filtering, no sub-pixel
  positioning, container that layout cannot compress. Interface chrome **may**
  now be authored pixel art (panel outer edge tiled — never `centerSlice`
  stretch — interior as low-variation tiled surface, or a discrete
  Flutter-positioned ornament). Text/layout/measurement/state/interaction are
  **never raster**; no pixelated text anywhere; no full-screen raster; one
  chassis family app-wide (no per-screen frame family).
- **L-18a (`0031`)**: **density is a property of a plane, not a frame.**
  Anything sharing the figure's ground line, overlapping it, or crossed by its
  tool arc must be drawn at the **figure's density**. Only the single backdrop
  plate behind may sit at a lower density. Current concrete mapping: backdrop
  **384×176 native, ×1**; gather subject **48×48 native, ×2** (screen
  footprint 96 dp, unchanged); traveler **64×64 native, ×2**. No third density
  permitted without amending this decision; no resampling an asset to comply
  (must be re-authored, per A-2 — resampling invents pixels).
- Enforcement scripts (`Scripts/art/`):
  - `check-art-palette.js` — palette guard, checks shipped PNGs for the
    reserved teal / palette-family compliance (built under `0030`; measured
    871 PNGs, found exactly one legitimate teal file).
  - `check-tile-seam.js` — mechanical seam/border artefact guard (built under
    `0030`).
  - `png.js` — PNG decode/encode helper (`loadAny` is read-only, added under
    `0030` for palette/greyscale files; no `save` counterpart, deliberately,
    so a palette PNG can't be silently laundered into RGBA).
  - `package-art.js` — the composition/packaging pipeline; owns the protected-
    interior guard (§4) and the `--check` reproducibility gate.
  - `Scripts/check-ui-boundary.sh` — confines raster image drawing to
    `pixel_asset.dart` only; also catches `DecorationImage`/`paintImage`
    used elsewhere (a hole `0029` closed — those render bilinear and would
    have silently passed CI).

---

## 3. Reserved teal

**L-16**: `#58D6C0` ("teal") is reserved **system-wide, exclusively, for
walking, steps, and banked-step quantity.** No character, environment, item,
or interface element may use it as an identity accent or for any other
meaning — deliberately not gold, because a gold numeral beside a glyph would
read as currency (P-6 forbids currency). This is unchanged and explicitly
reaffirmed by both `DECISIONS/0029` (new UI-art frames) and `DECISIONS/0031`
(new density plane) — **FMPO02's UI overhaul, equipment art, reward art, and
world/atlas work all bind to L-16 with no exception.** `check-art-palette.js`
is the live enforcement (added under `0030` specifically because "nothing
enforces it" was true before that).

---

## 4. Protected atlas rules (M-12/M-14/M-15, `RULES.md` A-3/A-4)

- **Frozen core rect** (in `Scripts/art/package-art.js`):
  `const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 }` — a 512×512
  interior with a 20 px rim band around it where feathered repairs are allowed.
- **Protected-zone / landmark registry file**:
  `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/landmark_registry.json`
  (referenced in code as `path.join(REM01, 'landmark_registry.json')`, where
  `REM01 = GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01`).
- **The guard in `package-art.js`**: after compositing, every pixel deeper than
  the rim band (`protDepth(x,y) > PROT.band`) is compared against the
  byte-preserved approved master; any non-water drift throws
  (`protected interior drift — N px`), failing `--check`/packaging outright
  rather than shipping silently (this is the direct fix for M-15). A second,
  separate guard walks the landmark registry and throws on drift inside any
  registered landmark rect even within the rim band.
- **Owner's mandated repair-loop semantics** (graduated into
  `STUDIO_OPERATIONS/WORKFLOW.md` "World-atlas repairs", commit `5ffba67`):
  a **strict single-defect loop** — (1) identify ONE device-visible defect,
  (2) map to exact atlas coordinates, (3) make ONE minimal correction,
  (4) recompose the actual production atlas via
  `node Scripts/art/package-art.js`, (5) render/review at full-atlas context,
  defect close-up, all affected repair-perimeter edges/corners, and a
  representative iPhone-scale viewport, (6) accept/reject that one repair
  before starting another, (7) if a repair introduces a new visible
  patch/perimeter, reject it immediately — never accumulate on top of it.
  **Never batch multiple unreviewed terrain corrections.** Physical iPhone
  review is the final visual authority, not a desktop composite. `0030`
  reaffirms none of this is relaxed by the larger art budget: "the owner's
  authorization to recompose weak, non-protected areas is an authorization
  about the ~70% that is fair game, not a licence to touch the core."

---

## 5. Change classes needing owner approval (producer cannot decide alone)

Per `STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md` + `RULES.md` G-3/G-4 + the
`0029`-`0032` pattern:

- **Kernel change** (solo-first, no-FOMO, mobile-only, walking-first identity)
  — explicit owner approval, always.
- **System change** (new skill, combat mechanic, progression resource, economy
  rule) — design review + technical review + a decision log entry. **FMPO02 is
  scoped as presentation-only** (`0030`): no gameplay-systems expansion, no
  talent trees, no combat redesign, no new economy architecture, no quest
  systems. Q-15 (Slash/Crush/Pierce) stays explicitly closed to this
  workstream.
- **Any amendment to a LOCKED document** (`ART_DIRECTION.md`, `RULES.md`
  A-rules, L-rules) — owner ruling required, recorded as a new/updated ADR
  (the `0029`→`0031` pattern is the template: cite what's amended, what stands,
  what's explicitly NOT authorized).
- **Any new persisted state or save-format change** — needs its own decision;
  `0030` §3 explicitly refused persisting an art key/variant id/cosmetic
  override for equipment visuals as "converts a free change into a schema-v10
  migration for no player-visible gain." Equipment visuals must stay a
  read-only projection off existing `equipment.bySlot` content lookups.
- **Any relaxation of atlas protection (A-3/A-4), the rim band, or the
  landmark goldens** — explicitly forbidden by `0030` regardless of budget.
- **Answering `Q-13`** (lime-band identity, gates southern atlas zone) — stays
  `UNRESOLVED`; owner's to settle, not the producer's.
- **New audio-source provider or licensing change** — `DECISIONS/0005` governs
  permitted sources (ElevenLabs, Stability AI as of `0030`, original/CC0);
  anything else needs a decision amendment.
- **Toolchain/CI version changes (G-2)** — own branch, own decision, never
  incidental to FMPO02.

---

## 6. Things FMPO02 is flatly forbidden from doing

- **Atlas expansion beyond 1024×1024 that repaints/replaces the protected
  512×512 core, or that ships an unauthored (non-transition) generated
  boundary** — forbidden by A-3/A-4 and the live guard in `package-art.js`
  regardless of the 10,000-generation budget (`0030` is explicit: "a larger
  art budget does not... licence to touch the core"; A-3's blind iPhone-scale
  read is still required per boundary).
- **New persisted state for cosmetic/equipment-visual purposes** — forbidden
  by `0030` §3 (must be a pure content-lookup projection, no schema migration
  for equipment art).
- **A new font, or any pixelated text** — forbidden absolutely by L-18 as
  amended ("Text is never pixelated... at any size, anywhere. Bitmap type is
  not in scope"). Layout/text/measurement/state/interaction stay native
  widgets.
- **Procedural / code-drawn production art in Dart, including placeholder art
  meant to ship** — forbidden by A-1/A-2. PixelLab authors; code may only
  deterministically transform already-approved PixelLab output. A temporary
  asset kept after a PixelLab failure must be flagged/escalated, not quietly
  finalized as shipped art.
- **Reserved-teal use outside walking/steps** — forbidden by L-16, unchanged.
- **Any icon/frame that implies a system Stride doesn't have** (timer/
  hourglass/cooldown/decay/durability/capacity meter/lock/coin/price
  tag/ledger/shop) — forbidden by L-15/L-17 and PIXELLAB_UI_PRODUCTION_PLAN
  §11 "DO NOT AUTHOR", regardless of craft quality.
- **A per-screen frame family / stretched (`centerSlice`) pixel frames** —
  forbidden by L-18's boundary clauses.
- **Silencing or degrading one feedback channel via another's accessibility
  toggle** (e.g., Reduce Motion touching audio) — forbidden by M-16 / `0032`;
  Reduce Motion may only ever affect visual motion, never audio, never
  haptics.

---

## 7. Traps — what a previous session violated, so FMPO02 doesn't repeat it

- **M-15**: seam/bridge repairs with no enforced boundary repainted 35.3% of
  the approved atlas master (erased the Frostmere frozen basin, deleted the
  volcano watchtowers) — three device passes reviewed only the seams, not the
  repair's own footprint against the pre-repair baseline. **Always diff a
  repair's full footprint against the approved baseline, not just its edges.**
- **M-14**: an atlas that passed `--check`, byte-preservation, seam-distance
  metrics, and desktop review still shipped visible rectangles on the actual
  iPhone. **A seam metric and desktop composite are triage, never the
  verdict — only a blind iPhone-viewport read clears a generated boundary.**
- **M-12**: tiles generated independently with matched palettes and low
  measured seam-distance still read as "four maps from different games
  pasted into a grid" in blind QA — texture/drawing-hand continuity is
  invisible to colour-distance metrics. **Grow by transition-authoring around
  natural boundaries (coast/ridge/river), never by butting separately-painted
  tiles edge to edge.**
- **M-16**: an accessibility toggle (Reduce Motion) silently disabled ALL game
  audio because sound was driven off the same animation ticker the toggle
  stopped — happened **twice** (also v2.28's `IndexedStack`/`TickerMode`
  incident). Test suites checked cue-table consistency but never asserted a
  cue actually fires. **A cue must never be emitted from a callback an
  accessibility setting can stop; test that cues fire, not just that the
  table is well-formed.**
- **M-13**: blind QA plates were staged inside a path that literally named the
  asset's intent (`.../step_icon/qa...`, filenames like `woodcut_f*`), leaking
  the answer before the perceptual read. **Stage blind plates in a neutrally
  named scratch path, never inside the round's own working tree.**
- **M-08**: `git add -A` published 929 untracked files (including third-party
  reference imagery marked DO NOT COMMIT) to the public repo, requiring a
  history rewrite. **This repo currently has ~25 untracked exploration
  directories on disk right now** (`GAME_BIBLE/ART/exploration/...`,
  `AUDIO/evaluation/`) — G-8 binds FMPO02 "with unusual force" per `0030`:
  stage explicit paths, every commit, no exceptions.
- **M-11**: two device milestones shipped with structurally-passing engine
  code but no actual UI affordance to equip anything — reachability/graph
  validators proved a chain was theoretically possible while nobody played
  the real UI end to end. Relevant to FMPO02's "visible equipment" work:
  prove it plays on device, not just that the projection compiles.
