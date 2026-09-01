# FOUNDATION-A — Canon Guardian report for VAWO01

```
STATUS: read-and-report only. No file outside this one was modified.
Agent:  FOUNDATION-A (Canon Guardian), Visual / Audio / World Overhaul 01
Date:   2026-09-01
Branch: presentation-combat-evolution-01 (repo HEAD 6d41bce, PROJECT_STATE v2.35)
Scope:  the enforceable rule surface a presentation / art / audio / world
        overhaul must not violate.
```

**Sources read in full:** `RULES.md`, `MISTAKES.md`, all fourteen
`PROJECT_KERNEL/` files, `STUDIO_OPERATIONS/WORKFLOW.md`,
`STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`, `JOURNAL/OPEN_QUESTIONS.md`,
`DECISIONS/0003`, `0005`, `0012` (§1–4), `0013` (§decision), `0016` (§decision),
`0020`, `0022`, `0026`, `0029`; `PROJECT_STATE.md` (v2.33–2.35 status blocks,
gaps, risks). Supporting reads: `GAME_BIBLE/ART/ART_DIRECTION.md` L-1…L-19,
`GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md`, `AUDIO/AUDIO_ASSET_MANIFEST.md`,
`AUDIO/AUDIO_PRODUCTION_QUEUE_01.md`, `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md`,
`Scripts/check-ui-boundary.sh`, `Scripts/art/package-art.js`, `.gitignore`.

Where the repository does not contain something, this report says so rather than
filling it in.

---

## 1. Every `RULES.md` rule, one line each, flagged for VAWO01

Flags: **[BLOCKING]** = this workstream can plausibly violate it and a violation
stops the work; **[RELEVANT]** = it constrains a decision here but is unlikely to
be tripped by ordinary art/audio work; **[NOT RELEVANT]** = outside this
workstream's reach.

### Product

| ID | One line | Flag |
|---|---|---|
| **P-1** | Mobile-first and mobile-only; iOS first, Android via Health Connect later, desktop is not a target. | **[BLOCKING]** — the iPhone viewport is the verdict surface (M-14); a desktop-scale review is not evidence. |
| **P-2** | Solo PvE — no multiplayer, trading, guilds, or PvP. | [NOT RELEVANT] |
| **P-3** | Real-world steps are the progression input; walking is the engine, not a bonus. | [RELEVANT] — presentation may never imply a second input. |
| **P-4** | No wall-clock progression masquerading as walking, with exactly one named exception (`0022`'s finite, player-initiated activity queue). | **[BLOCKING]** — a juice/ambient/audio pass is the most likely place a second clock appears. |
| **P-5** | Absence is never punished — no FOMO, login streaks, expiring rewards, decay, spoilage or upkeep; nothing stored decays or expires, ever. | **[BLOCKING]** — the classic failure mode of a "reward feel" pass. |
| **P-6** | No monetization systems — no premium currency, ads, loot boxes, gacha or battle passes without explicit owner reconsideration. | **[BLOCKING]** — reaches art and audio semantics (coin/bullion frames, jackpot stingers). |
| **P-7** | Defeat costs progress, never possessions — no death, no item loss, no rollback. | [RELEVANT] — combat presentation must not depict or imply loss of goods. |
| **P-8** | Offline-first — core gameplay never requires connectivity. | **[BLOCKING]** — every art/audio asset must be bundled; no remote fetch, no CDN, no streaming. |
| **P-9** | Goal tracking never reserves, escrows or auto-spends steps; a tracked goal is information and a live projection. | [RELEVANT] — any new goal/progress visual is a projection only. |
| **P-10** | Repeatable RNG is never load-bearing; permanent effects apply exactly once; signature rares are trophies, not ingredients. | [RELEVANT] — bears on Q-12 and on any reward-presentation change. |

### Health and step accounting

| ID | One line | Flag |
|---|---|---|
| **H-1** | Observed, granted, spent and banked are four distinct concepts and may never be collapsed. | [RELEVANT] — any step readout must render the projection, never re-derive it. |
| **H-2** | Granted is monotonic; there is no clawback (epochs move a mark, not a counter). | [NOT RELEVANT] |
| **H-3** | A candidate cursor becomes durable only after safe reconciliation and save commit. | [NOT RELEVANT] |
| **H-4** | A cursor may be offered only where the delivery contract permits; `cursorOfferedWhenProhibited` must never be weakened or suppressed in UI. | [RELEVANT] — a presentation pass must not hide a fault signal. |
| **H-5** | Foreground health sync only — no observer queries, background delivery or background modes. | [RELEVANT] — no ambient/audio feature may request a background mode (`0022` §4 repeats this). |
| **H-6** | First-party native health adapters only. | [NOT RELEVANT] |
| **H-7** | Health-data privacy is structural — no bundle id, device name, source name, salt, origin-key byte or cursor content is ever logged, displayed or persisted; origins are a count. | **[BLOCKING]** — a "richer step dashboard" is exactly where a source name gets displayed. |

### Engineering

| ID | One line | Flag |
|---|---|---|
| **E-1** | `stride_core` is pure Dart — no Flutter, plugins, `dart:io`, clock, randomness, locale or platform reads. | [RELEVANT] — no audio, art or animation may reach into core. |
| **E-2** | Player-facing UI must not become an alternate source of durable game state; widgets read state and dispatch commands, never compute or hold durable state. | **[BLOCKING]** — enforced in part by `Scripts/check-ui-boundary.sh`. |
| **E-3** | Single-writer persistence — no background isolate, callback, worker or platform entry point may instantiate `SaveRepository` or touch the save directory. | [RELEVANT] — an audio/settings persistence shortcut is the plausible violation. |
| **E-4** | Under-settle rather than over-settle where the platform contradicts itself. | [NOT RELEVANT] |
| **E-5** | Content is data, not code — no hardcoded game content. | [RELEVANT] — cue tables, skin registries and ambient definitions stay data-driven. |
| **E-6** | A content set is not proven until something plays it; graph checks answer *is this possible*, not *would anyone find it*. | [RELEVANT] — its art analogue is "a plate is not proven until someone reads it blind at ×2 / phone scale". |

### Governance

| ID | One line | Flag |
|---|---|---|
| **G-1** | Verification must stay proportional to the risk being changed; a new framework or repeated-validation campaign needs a concrete uncovered risk named before the work starts. | **[BLOCKING]** |
| **G-2** | Toolchain and CI upgrades are explicit work on their own branch, never incidental drift. | [RELEVANT] — do not bump Flutter/ffmpeg/node to make an asset pipeline work. |
| **G-3** | Unresolved design choices stay visibly `UNRESOLVED` and are recorded in `JOURNAL/OPEN_QUESTIONS.md`; an implementation detail must never quietly become a design decision. | **[BLOCKING]** — this workstream inherits ~15 open questions it must not silently answer. |
| **G-4** | Never weaken an invariant to make a test pass; a failing guard is evidence about the code. | **[BLOCKING]** |
| **G-5** | Durable knowledge belongs in repository documents; chat memory is not project memory. | **[BLOCKING]** |
| **G-6** | Documentation is part of done — a milestone is not closed until `PROJECT_STATE.md` and the affected canonical documents reflect reality. | **[BLOCKING]** |
| **G-7** | One canonical home per concept; no document duplicates another's authority. | [RELEVANT] |
| **G-8** | Stage explicit paths — never `git add -A` or `git add .`; a commit that adds far more files than its message describes is a defect signal. | **[BLOCKING]** — an art/audio workstream generates hundreds of untracked bytes; this is the single highest-probability violation. |

### Production art

| ID | One line | Flag |
|---|---|---|
| **A-1** | PixelLab is the production-art and production-animation engine; Claude may art-direct, prompt, select, edit, inpaint and integrate, but may not manufacture new production artwork or animation frames in code — on PixelLab failure, preserve the temporary asset, record the failure, escalate. | **[BLOCKING]** |
| **A-2** | Deterministic transformation of approved art is not authoring — crop, nearest-neighbour scale, sheet assembly, keying, palette/index remap, state derivation and format conversion are permitted **provided they invent no new object, silhouette, animation frame or illustrated content**. | **[BLOCKING]** |
| **A-3** | Production atlas expansions are transition-authored across every boundary; no generated boundary ships until a blind read at iPhone-viewport scale confirms biome, coastline, detail-scale and palette continuity and no visible generated rectangle remains. | **[BLOCKING]** |
| **A-4** | Approved atlas interiors are protected in tooling and a repair may write only its transition band; the pipeline snapshots the interior, restores every repair pixel deeper than the rim band, and fails packaging on core drift. | **[BLOCKING]** |

---

## 2. The rules governing the surfaces this workstream touches — exact text and intent

### 2.1 Art production — who may draw (`RULES.md` A-1)

> **A-1 — PixelLab is the production-art and production-animation engine.**
> Claude may art-direct, prompt, select outputs, edit and inpaint through
> PixelLab, and integrate the results. Claude may **not** manufacture new
> production artwork or animation frames in code when PixelLab can do the creative
> task. Where PixelLab fails: preserve the temporary asset, record the failure,
> escalate — never silently substitute code-drawn art.
> → owner direction, 2026-08-17

**Intent.** The creative act belongs to PixelLab. A code-drawn substitute is not
a stopgap, it is a rule violation, *and the escalation path is mandatory* — the
temporary asset stays, the failure is recorded, the owner hears about it.
`DECISIONS/0029` re-affirms A-1 in its invariant check: the painted
`BoxDecoration` fallback is permitted only because it is *chrome, not art*.

### 2.2 PixelLab usage (`RULES.md` A-2, and `DECISIONS/0029`)

> **A-2 — Deterministic transformation of approved art is not authoring.**
> Crop, nearest-neighbour scale, sprite-sheet assembly, keying, palette or index
> remap, selected/disabled-state derivation, and format conversion are permitted
> in code, **provided they invent no new object, silhouette, animation frame, or
> illustrated content.** The nav `_hi` variants are a derivation of this kind and
> stand.

**Intent.** A bright line between *transforming* an approved plate and *making*
something. Q-14 records a live case sitting right on the line — a deterministic
steel→bronze palette remap of baked blade pixels is judged "marginal under A-2"
and is **UNRESOLVED until the owner rules**.

**Budget, which is a hard operational constraint and not a rule:**
`DECISIONS/0029` states, in the owner's own words, *"The remaining 25 PixelLab
generations are STILL RESERVED for the atlas and are NOT authorized for this
workstream"*, with cycle reset **2026-09-16**. `PIXELLAB_UI_PRODUCTION_PLAN.md`
repeats it: *"Zero generations were spent writing this document. Zero may be
spent executing it before 2026-09-16."* Today is 2026-09-01, so **the reserve is
still in force**. The plan also requires `get_balance` to be called at the start
of every production session because *"a remembered figure has been wrong three
times in this project's history"*.

### 2.3 Asset provenance and packaging

- **Audio (`DECISIONS/0005`).** `AUDIO/AUDIO_ASSET_MANIFEST.md` records, for
  every shipped asset: asset ID, source, licence, generation prompt, model and
  version, generation/acquisition date, and usage. *"A missing manifest entry for
  a shipped asset is a **QA defect**, not a paperwork issue."* Audio is
  referenced **by asset ID only, never by filename or path** (`audio_cues.json`
  → asset ID → manifest → file).
- **Art (`Scripts/art/package-art.js`).** Every shipped asset is derived
  deterministically from a tracked source and reproduced under `--check`; frame
  counts, canvases and baselines are read from the round's own `manifest.json`,
  and entries marked `withheld` cannot ship (`throw new Error('… not in the
  manifest')`). M-14 is explicit that `--check` is a **reproducibility gate and
  cannot see a seam** — it is not visual evidence.
- **Repository hygiene (`.gitignore` lines 171–228).** `GAME_BIBLE/ART/exploration/**`
  is ignored by default with named re-includes for round records (`*.md`) and
  specific `out/` trees. This inversion exists because of M-08.

### 2.4 Atlas protected regions (`RULES.md` A-3, A-4)

> **A-3 — Production atlas expansions are transition-authored across every
> boundary.** Tile-local generation plus seam blending, palette conform, or a seam
> metric is triage, not evidence of visual continuity: no generated boundary ships
> until a blind read at iPhone-viewport scale confirms biome, coastline,
> detail-scale and palette continuity, and no visible generated rectangle remains.

> **A-4 — Approved atlas interiors are protected in tooling, and a repair may
> write only its transition band.** The composition pipeline snapshots the
> approved interior before any repair layer, restores every repair pixel deeper
> than the narrow rim band, and fails packaging on any core drift. Repainting
> approved geography to solve a seam is a defect, not a technique; masks are
> authored in or outside the band.

**Enforcement is real code**, not intention: `Scripts/art/package-art.js`
(~lines 1592–2072) snapshots the protected core, clips every repair to the rim
band, and throws `world/atlas_base: protected interior drift — N px` on any
non-water core pixel change. The single-defect loop that governs any atlas repair
is canonical in `STUDIO_OPERATIONS/WORKFLOW.md` — *author → validate → render →
inspect → adjust*, one defect at a time, **"Never batch unreviewed terrain
corrections. The physical iPhone is the final visual authority."**

### 2.5 Git staging (`RULES.md` G-8)

> **G-8 — Stage explicit paths. Never `git add -A` or `git add .`**
> Name the paths a commit is for, or read `git status --short` before committing.
> A blind stage published 929 untracked files — including third-party reference
> imagery marked `DO NOT COMMIT` — to a public repository, and required a history
> rewrite to undo. A commit that adds far more files than its message describes is
> a defect signal, not a tidy-up.

The working tree **right now** carries ~25 untracked exploration directories
(see `git status`), including `WALKSCAPE_REFERENCE_SET/` — the directory whose
third-party imagery caused M-08.

### 2.6 Verification proportionality (`RULES.md` G-1)

> **G-1 — Verification must stay proportional to the risk being changed.**
> The smallest focused regression proof plus existing CI and guards is the
> default. A new verification framework or a repeated-validation campaign
> requires a **concrete uncovered risk**, named before the work starts.

Both M-06 and M-07 close with an explicit disclaimer — *"This does not license a
verification campaign (`RULES.md` G-1)"* — so the tension between "look harder"
and G-1 is already adjudicated: **change the instrument, do not multiply the
runs.**

### 2.7 Invariant weakening (`RULES.md` G-4)

> **G-4 — Never weaken an invariant to make a test pass.**
> A failing guard is evidence about the code, not about the guard. Suppressing a
> fault, loosening an assertion, or accommodating a violation upstream is a
> change to the rule and requires the rule's owner.

`DECISIONS/0029` demonstrates the correct pattern: `check-ui-boundary.sh` was
**strengthened** (adding `DecorationImage` and `paintImage` to the one-image-site
rule) as a *prerequisite* of the new permission, not relaxed to admit it.

### 2.8 Documentation on close (`RULES.md` G-6, G-5, G-7)

> **G-6 — Documentation is part of done.** A milestone is not closed until
> `PROJECT_STATE.md` and the affected canonical documents reflect reality.

Paired with **G-5** (durable knowledge goes in the repo, chat memory is not
project memory) and **G-7** (one canonical home per concept — extend the existing
document, never open a second one).

---

## 3. Every `MISTAKES.md` entry, and this workstream's recurrence risk

| ID | One line | VAWO01 recurrence risk |
|---|---|---|
| **M-16** (2026-08-31) | A cue driven by an animation ticker is a cue an accessibility toggle can delete — Reduce Motion silenced every SFX in the product. | **VERY HIGH.** Any new juice couples audio/haptics to animation. The durable rule: *an accessibility preference must degrade the one channel it names and no other*, and *a cue must never be emitted from a callback an accessibility setting can stop*. Note this was the **second** such incident (the first was `TickerMode` on hidden `IndexedStack` tabs, v2.28). |
| **M-15** (2026-08-27) | Seam repair with no enforced boundary repainted 35.3% of the approved atlas interior it was protecting. | **VERY HIGH** if the world half touches the atlas. Protection is now code (A-4), but the lesson — *audit a repair's footprint against the approved baseline, not only its seams* — is a review habit, not a guard. |
| **M-14** (2026-08-26) | A composed atlas measured as joined, blended and border-clean still shipped rectangles to the phone. | **VERY HIGH.** Pixel-edge continuity is not geographic continuity. Four consecutive world passes were declared clean by `--check` and a desktop review before the phone found them. |
| **M-13** (2026-08-20) | Blind QA was staged inside a directory whose path named the intent, leaking semantics to reviewers. | **HIGH.** Any blind visual round in this workstream must stage plates in a neutral scratch directory, and ask the first-impression question before revealing purpose. |
| **M-12** (2026-08-19) | A tiled AI-generated world measured as joined and read as four paintings; 335 generations spent, one join shipped. | **HIGH** for any world expansion. Grow by natural boundaries or regenerate whole; never butt paintings edge to edge. |
| **M-11** (2026-08-19) | Two device milestones shipped with no way to equip anything, because no surface offered the control the acceptance script named. | **MEDIUM.** An acceptance-script step must name a control that exists in the build it tests — directly relevant if the overhaul reworks equipment surfaces. |
| **M-10** (2026-08-18) | The product never asked HealthKit for read access; only the dev harness had. | **LOW** — but the general lesson (a device finding from a fresh container is a different test from a reinstall) applies to any presentation acceptance run. |
| **M-09** (2026-08-17) | `flutter build ios --profile` then Xcode's Run button installed a Debug build; the record described the command, not what landed. | **MEDIUM.** Every device pass in this workstream must use `Scripts/ios/build-release-device.sh` and record the configuration read from the bundle. |
| **M-08** (2026-08-17) | `git add -A` published 929 files, including third-party imagery, to a public repository. | **VERY HIGH.** The tree currently holds ~25 untracked exploration directories, `WALKSCAPE_REFERENCE_SET/` among them. |
| **M-07** (2026-08-17) | Every structural validator passed and the loop was unplayable — bronze required ten oak handles first. | **MEDIUM.** Its art analogue is the whole M-04/M-05/M-06 family: a graph check and a play check are different instruments. |
| **M-06** (2026-08-16) | A UI was declared done on evidence structurally blind to how it looked — 93 widget tests and 4 goldens, three visible defects on first device run. | **VERY HIGH.** `flutter test` has no real font and zero safe-area insets. *"A UI is not done until it has been looked at, running, on a device."* The update adds: assert the property (needed width vs given width), not the absence of an exception. |
| **M-05** (2026-08-14) | Visual decisions were made without a play-scale verdict view — no ×2 render existed anywhere in the repository. | **VERY HIGH.** ×2 is the verdict view; ×8 is inspection only; a visual pass without the required verdict view is **returned unreviewed**. |
| **M-04** (2026-08-14) | A technically correct pixel change was reported as a fix without perceptual verification; the author was the only judge. | **VERY HIGH.** The perceptual law: source intent gets no credit. Blind semantic read, perceptual delta test, and **separate AUTHOR ASSESSMENT and QA VERDICT lines — the author never writes the second**. |
| **M-03** (2026-08-13) | A HealthKit candidate cursor was offered on non-final pages; the fault channel fired on every normal read. | **LOW.** |
| **M-02** (2026-08-13) | CI floated on Flutter `stable` and moved 3.44.8 → 3.47.0 unannounced, breaking format checks on untouched files. | **LOW–MEDIUM.** Do not bump any toolchain to make an asset or audio pipeline work (G-2). |
| **M-01** (2026-08) | Verification depth expanded beyond the risk being covered, generating verification work of its own. | **HIGH.** A big overhaul invites a big validation campaign; G-1 forbids one without a named uncovered risk. |

**The four highest-probability repeats for VAWO01, in order:**
M-08 (blind staging), M-04/M-05/M-06 (author-judged, wrong-scale, harness-blind
visual verdicts), M-16 (a feedback channel made a passenger of the animation
system), M-14/M-15 (atlas seams and protected interiors).

---

## 4. `DECISIONS/0029` — UI art direction amendment: exact wording, permits and forbids

**Status:** Approved — owner ruling, 2026-08-31, explicit and in writing during
PRESENTATION_COMBAT_EVOLUTION_01. **Amends** `GAME_BIBLE/ART/ART_DIRECTION.md`
L-18 and the UI Baseline Closeout status block.

### The decision, verbatim

> **The owner amends L-18. PixelLab may author production interface art.**
>
> The owner's ruling, recorded in their own terms:
>
> > Flutter remains responsible for layout, text, dynamic data, accessibility,
> > interaction, responsiveness and hit targets.
> >
> > PixelLab may author production UI art where it materially improves the game:
> > panel/frame art, headers, material surfaces, borders, dividers, reward
> > frames, combat frames, craft/workbench presentation, inventory/equipment
> > treatments, board/ledger treatments and restrained screen backplates.
> >
> > Do NOT turn whole screens into raster screenshots. Do NOT pixelate text. Do
> > NOT sacrifice readability or mobile responsiveness. Prefer
> > scalable/segmented/9-slice integration for authored frame assets. Maintain
> > one coherent Stride visual language rather than making every screen
> > stylistically unrelated.
> >
> > The goal is specifically to eliminate the generic rounded-card /
> > LLM-generated application appearance and make Stride feel like an authored
> > RPG.

### L-18 as amended

The **first** paragraph is untouched — *"Every pixel asset is displayed at an
exact integer multiple of its native size, with nearest-neighbour filtering and
no sub-pixel positioning, in a container that layout cannot compress"* — and now
governs **more** assets, not fewer. The second paragraph is replaced by:

> Interface chrome may be authored pixel art. Text, layout, measurement, state
> and interaction are never raster.

### The enforceable boundary

A raster asset in the interface may occupy **only**:

1. the **outer edge** of a panel — a frame, drawn as corners at 1:1 integer scale
   with tiled (never stretched) edge strips;
2. a panel's **interior as a tiled surface** of low tonal variation; or
3. a **discrete ornament** positioned by Flutter.

> It may never carry a word, a number, a state, or a boundary that Flutter needs
> to measure.

> **The test that keeps this honest, and that CI runs:** with every frame asset
> removed from the build, the app must still lay out, still read, still be
> navigable and still pass its accessibility assertions. A raster asset may
> change how Stride *feels*; it may never change what Stride *does*.

### What 0029 explicitly does NOT authorize (verbatim headings)

- **No PixelLab generation in this workstream.** *"The remaining 25 PixelLab
  generations are STILL RESERVED for the atlas and are NOT authorized for this
  workstream"*; reset **2026-09-16**; a single inpaint bills 20–40.
- **No pixelated text**, at any size, anywhere. Bitmap type *"is not in scope and
  is not a future option under this decision."*
- **No full-screen raster.** A backplate is restrained, scrimmed, and behind
  everything.
- **No per-screen frame family.** One chassis, app-wide — *"the failure mode this
  decision is most likely to produce if unwatched."*
- **No stretched pixel art.** `centerSlice` stretches its edge bands and is
  therefore **forbidden** for pixel frames; tiling is the only permitted edge
  behaviour, which forbids a once-only ornament inside a repeating strip.
- **No change to L-16** (teal is walking, exclusively), **L-15/L-17** (an icon may
  not change referent; a wrong semantic is a blocker), or **A-1/A-2**. *"A frame
  that reads as an equipment slot, a lock, a coin or a capacity meter is a blocker
  on semantics regardless of craft."*

### Architectural consequences that bind this workstream

- `SectionCard` gains a **`PanelRole`**; a **`PanelSkins` registry (ships empty)**
  decides whether a role has art; all 34 call sites render byte-identical until a
  registry entry exists.
- A **tiled nine-patch renderer joins `pixel_asset.dart`** — not a new file,
  because `Scripts/check-ui-boundary.sh` confines image drawing to that one file.
- `check-ui-boundary.sh` was **strengthened**: `DecorationImage` and `paintImage`
  are now caught outside `pixel_asset.dart`.
- **A palette guard is a prerequisite of production**: L-16 reserves `#58D6C0`
  system-wide and *nothing enforces it* today; a UI-art family is the first art
  authored near interface colour.
- **Reversible by construction**: empty the registry and every screen returns to
  the painted fallback in one commit. *"That property is deliberate and must be
  preserved as the architecture grows."*

---

## 5. `DECISIONS/0005` — audio sourcing: sanctioned providers, direction, prohibitions

**Status:** Approved, 2026-08-01, owner. Closes gap G-05.

### Permitted sources (verbatim)

- **ElevenLabs**, free or the lowest practical tier
- **Original or generated assets**
- **CC0 or properly licensed royalty-free** placeholders

### Forbidden (verbatim)

- **Any asset extracted from the inspiration games.** WalkScape, Melvor Idle, Old
  School RuneScape, and New World are references for *identity*, never sources for
  files. **This is absolute.**
- **Paid libraries**, without explicit owner approval

### Required record-keeping and indirection

Every asset carries a `AUDIO/AUDIO_ASSET_MANIFEST.md` row: asset ID, source,
licence, generation prompt, model and version, date, usage. Audio is referenced
**by asset ID only, never by filename or path**. *"A missing manifest entry for a
shipped asset is a **QA defect**, not a paperwork issue."* Memory budget is 30 MB
(`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4).

### Accepted creative direction (not in 0005 — it is downstream canon)

0005 governs **sourcing**, not taste. The creative direction lives in
`AUDIO/AUDIO_PRODUCTION_QUEUE_01.md` §0 and the bake-off record:

> **Fantasy first, lo-fi second, retro third.** Acoustic fantasy lo-fi, nostalgic
> adventure warmth. Guitar/lute plucks, felt piano, celesta, flute, warm strings,
> soft hand percussion, warm pads, tape/vinyl texture. **Forbidden:** techno,
> synthwave, EDM, harsh square-wave arcade, bombast, slot-machine/jackpot audio.
>
> **Provider discipline: do not provider-hop.** Do not casually replace the five
> accepted region tracks or the five accepted action cues.

### Two facts the repository states plainly and that must not be papered over

1. **The shipped assets are Stability AI Stable Audio on a paid tier**, not
   ElevenLabs. `AUDIO_ASSET_MANIFEST.md` records every row as *"a Stability AI
   Stable Audio generation under Stability's licence for the account's paid credit
   tier, owner-accepted in AUDIO_PRESENTATION_01"*. **I found no ADR amending
   0005 to name Stability** — `grep -rn "Stability" DECISIONS/ RULES.md` returns
   nothing. The provider change rests on the owner's acceptance recorded in
   `MILESTONES/AUDIO_PRESENTATION_01.md`, not on an amended decision. This is a
   **G-7 / G-3 gap worth surfacing to the owner**, not something to resolve here.
2. **Generation is closed.** `AUDIO_PRODUCTION_QUEUE_01.md` opens: *"No audio was
   generated to write this document, and none may be generated by running it until
   the owner explicitly reopens generation"* (`AUDIO_PRESENTATION_01.md` §1: *"No
   further Stability spend without the owner explicitly reopening generation"*).
   `STABILITY_API_KEY` is **not set in this environment**; last *recorded* balance
   is **61 credits, 2026-08-24** — a record, not a reading.
3. **The owner's GitHub audio sources are not recoverable from the repository.**
   Searched 2026-08-19, 2026-08-20, 2026-08-31. OD-06: *"Do not guess or invent
   those repositories… a plausible-looking URL recorded here would be worse than
   an acknowledged gap."*

---

## 6. Rules a "juice / reward" pass could accidentally violate

| Source | The constraint | The plausible accidental violation |
|---|---|---|
| `RULES.md` **P-4** | No wall-clock progression; **one** named exception, the finite player-initiated activity queue (`0022`). *"Nothing else may cite this exception; a second one needs its own decision."* | An ambient loop, a "come back in N minutes" beat, a timed reward window, an idle animation that accrues anything. |
| `DECISIONS/0022` §2 | Explicitly not licensed: *"no passive world progression, no infinite jobs, no automatic or background health sync, no background HealthKit delivery, no time-based enemy respawns or combat, no energy recharge, no streaks, no decay, no daily systems, no unbounded idle progression."* | Any of the above dressed as presentation. |
| `DECISIONS/0022` §4 | **No process-keep-alive** — no iOS background modes, audio or location keep-alives. | Requesting the background-audio mode so ambience continues when the app is backgrounded. |
| `RULES.md` **P-5** | Absence never punished — no FOMO, login streaks, expiring rewards, decay, spoilage, upkeep; *"Nothing stored decays or expires — ever."* | A "welcome back, you missed…" panel; a fading/expiring reward card; anything that makes a quiet day look like a fault. |
| `PROJECT_KERNEL/06_ANTI_FEATURES.md` | Do not introduce without explicit owner approval: premium currencies, advertisements, loot boxes or gacha, battle passes, **daily-login streaks**, **expiring rewards that punish absence**, energy systems designed to restrict play, punishing idle decay, live-service pressure, **grind whose only purpose is larger numbers**, **generic mobile-game engagement mechanics**. | A reward pass that reaches for a mobile-game vocabulary (chests, streak counters, daily bonuses, celebratory "jackpot" moments). |
| `RULES.md` **P-6** | No monetization systems. | Art or audio that *asserts* a system: a coin, a price, a premium frame. |
| `ART_DIRECTION.md` **L-16** | Teal `#58d6c0` is reserved system-wide for walking, steps and banked-step quantity — *"No character, environment, item, or interface element may use it as an identity accent or for any other meaning."* It is *"deliberately not gold: a gold numeral beside a glyph reads as currency, and Stride has none."* **Nothing enforces this today** (0029 § Consequences). | Any new palette, frame or reward glow that lands on the teal, or a gold reward numeral. |
| `ART_DIRECTION.md` **L-15 / L-17** | No UI icon may imply a semantic the game does not have; *"an icon that reads as a timer or hourglass is objectively unacceptable"*; an icon that confidently implies **currency, rarity, a timer, capacity, or a lock** is *"a defect regardless of craft quality"*; an icon may not change referent across treatments. | A progress ring, hourglass, chest, padlock or capacity meter in a reward frame. |
| `ART_DIRECTION.md` **L-19** | Bronze reads as bronze, not gold bullion — *"A banded gold trapezoid is the universal bullion glyph and asserts a currency Stride does not have."* | Reward-frame metal treatments drifting to gold. |
| `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md` | Reward audio must be *"Earned, satisfied, human warmth; a small triumph among friends, **never a fanfare, never brass, never a jackpot or arcade flourish**."* One resolve per layer, never two. | A celebratory stinger with slot-machine DNA. |
| `DECISIONS/0026` § *What this deliberately is not* | The step tracker is *"Not a health app. No goals, streaks, rings, reminders, or any surface that makes a quiet day look like a fault (`RULES.md` P-5)."* And *"Not a second accounting"* — nothing in the engine reads its figures back. | Adding a daily goal ring or a streak line to a "richer" steps dashboard. |
| `RULES.md` **P-9** | Goal tracking never reserves, escrows or auto-spends steps; every figure is a live projection; nothing tracked expires. | A progress visual that implies steps are already committed to a goal. |
| `RULES.md` **P-10** | Nothing required is a low-chance drop; signature rares are trophies, not ingredients. | A reward pass that makes a rare drop feel *needed*. |
| `RULES.md` **P-7** / `0003` | Defeat retreats; it never removes equipment, inventory, XP or progression. | Combat presentation that dramatizes loss ("you dropped…"). |

---

## 7. Open questions currently unresolved that touch presentation, audio, world or equipment

Read from `JOURNAL/OPEN_QUESTIONS.md` at HEAD. **G-3 forbids answering any of
these silently.**

### Owner directions — settled in intent, implementation deferred

| ID | State | Bearing on VAWO01 |
|---|---|---|
| **OD-03** — the steps glyph | 🔶 One round attempted 2026-08-17, **not shipped**. The turquoise boot stays. | The most-repeated mark in the app. Retry brief: **one connected mass at 12 × 12**. *"Do not improvise a vector, icon-font or SVG substitute."* |
| **OD-04** — the five skill icons | 🔶 **STILL OPEN.** Spec frozen (`SKILL_ICON_SPEC_01.md`), one round generated, **blind QA FAIL** — axe and pickaxe read as the same object at ×2. Three spec amendments recorded and deliberately **not applied**. | *"Do not generate replacement assets during a UI or correction pass."* The set is generated in one round against the spec, never one at a time. Next round must separate Woodcutting/Mining by silhouette **family**, not head geometry. |
| **OD-05** — interactive animated world atlas | Settled, **implementation deferred**; not to start before the owner's device pass. | Pan/zoom atlas with subtle ambient motion, bounded by four rules: remain subtle, never cover a destination for long, never reduce readability, **never imply free-roam character control**. PixelLab makes the art (A-1); Claude builds viewport/compositing/hit targets (A-2). |
| **OD-06** — audio and environmental sound | Settled, **implementation deferred**. | Order is fixed: recover the owner's exact GitHub source *or ask* → licence audit → Flutter/mobile compatibility → formats/looping/memory → decide source vs custom → integrate through **one coherent audio layer**, not per-screen playback. **Invent no URL.** |

### Q-entries

| ID | State | Domain |
|---|---|---|
| **Q-01** | OPEN, target M02 — what Stride offers a player who cannot walk this week. | presentation/balance |
| **Q-02** | OPEN — what makes the Traveler recognisable. A decorative signature is **deliberately withheld** until proportion/gesture/silhouette have had a fair attempt (L-5). | character art |
| **Q-03** | **Answered (A)** — 24 × 34 canvas is not widened. Reopens **only** on one of three demonstrated conditions in a compliant render. *"'More pixels would be easier' is not a reopening condition."* | character art |
| **Q-04** | OPEN — does the current location get to be teal? A live L-16 tension that has shipped and been accepted. Identity call, owner's. | UI colour |
| **Q-06** | Partly open — persistent HP / rest, and whether a guard/brace action earns its place (engine evidence gathered, verdict outstanding); enemy variants per region. | combat |
| **Q-07** | Open bullets: location kind words ("Perilous" among nouns), landmark names, the multi-leg total cost figure, rarity being colour-only in the grid, the "future" landmark em-dash treatment. Rarity **order and colours are RESOLVED and not open to "conventional" correction**. | world / UI wording |
| **Q-09** | UNRESOLVED — combat variability: keep the roll and the words (done), widen to −2..+2, or a visible d20 check. Option 3 changes the combat model and needs its own decision. | combat presentation |
| **Q-10** | UNRESOLVED — banked-steps cap (5,000) and combat energy. Owner direction exists; implementation deferred. Would need an ADR and state v10. | economy + UI |
| **Q-11** | UNRESOLVED — random encounters on travel; design note only, no scaffolding. | world |
| **Q-12** | UNRESOLVED — what signature drops are *for*. Four candidate shapes; the owner's rule to change. | equipment / rewards |
| **Q-13** | UNRESOLVED — the south coast's two greens: keep the lime coastal band with a terrain-following transition, or conform one green. **The post-reset atlas plan's Z1 item is blocked on this.** Riding along: A-4 core exceptions for owner-marked in-core defects, and strand-golden re-extractions. | world atlas |
| **Q-14** | UNRESOLVED — visible-equipment art priority: weapon-in-combat, tool-in-work, or armor everywhere. **Blocks any equipment art round.** Sub-question, deliberately not built: a deterministic steel→bronze palette remap is *marginal under A-2* and needs an owner ruling. | equipment art |
| **Q-15** | UNRESOLVED — is Slash/Crush/Pierce worth an art milestone? Bill: ~84 frames, ~12 animation jobs, **300–700 generations**. **Downstream of Q-14, which must be answered first.** | combat / equipment |
| **Q-16** | **Partially answered in code; the general rule is UNRESOLVED.** (a) Should "an accessibility preference degrades only the channel it names" be promoted to `RULES.md`? (b) Combat's segment timing collapses under Reduce Motion and **the voice cap and priority rule that would make outcome cues survivable do not exist yet**. (c) Haptic rate floor *drops* rather than queues — nobody has ruled whether that is right for two payoffs landing together. **Combat has no Reduce Motion path at all.** | audio / accessibility |
| **Q-17** | UNRESOLVED — mining is the loudness floor (−20.4 LUFS-M vs smithing −10.0, a 10.4 dB spread) and `trimDb` is attenuation-only, so **mining cannot be raised from the cue table at all**. Three zero-credit options, each a creative re-acceptance the owner must make. | audio |
| **Q-08** | UNRESOLVED (health, not presentation) — two step sources, one walk. Touches any steps display. | health |

**Closed, for completeness:** OD-01, OD-02, Q-05, Q-UI-9 (answered by `0026`),
and Q-07's rarity bullet.

---

## 8. DO NOT DO — concrete prohibitions for VAWO01

1. **Do not run `git add -A` or `git add .`** — name paths, or read
   `git status --short` first. The tree currently holds ~25 untracked exploration
   directories including `WALKSCAPE_REFERENCE_SET/`, the third-party imagery from
   the original incident. *(`RULES.md` G-8; `MISTAKES.md` M-08)*
2. **Do not spend a single PixelLab generation before 2026-09-16**, and do not
   touch the 25-generation atlas emergency reserve at any time without an explicit
   owner authorization. Call `get_balance` before any production session; never
   trust a remembered figure. *(`DECISIONS/0029` § What this does NOT authorize;
   `PIXELLAB_UI_PRODUCTION_PLAN.md` § Budget position)*
3. **Do not draw production artwork or animation frames in code** — not a sprite,
   not a frame, not a "temporary" hand-painted panel treatment. If PixelLab fails:
   preserve the temporary asset, record the failure, escalate.
   *(`RULES.md` A-1)*
4. **Do not invent a new object, silhouette, animation frame or illustrated
   content under the banner of a "deterministic transform."** Crop, integer scale,
   sheet assembly, keying, palette remap and format conversion are the whole list.
   The steel→bronze weapon remap specifically is **UNRESOLVED** (Q-14).
   *(`RULES.md` A-2)*
5. **Do not write a single pixel of the atlas's approved interior**, deeper than
   the rim band, for any reason including fixing a seam. Do not disable, widen or
   route around `package-art.js`'s protected-interior guard.
   *(`RULES.md` A-4; `MISTAKES.md` M-15)*
6. **Do not batch atlas/terrain corrections.** One defect, one masked correction,
   one recompose, one full review (context + close-up + all repair-perimeter edges
   and corners + iPhone-scale viewport), accept or reject before the next.
   *(`STUDIO_OPERATIONS/WORKFLOW.md` § World-atlas repairs)*
7. **Do not ship a generated boundary on the strength of a seam metric, a
   crossfade, a palette conform, or `--check`.** Those are triage. A generated
   rectangle is a defect until a blind read at iPhone-viewport scale says
   otherwise. *(`RULES.md` A-3; `MISTAKES.md` M-14, M-12)*
8. **Do not let the asset author write the QA verdict.** Separate AUTHOR
   ASSESSMENT and QA VERDICT lines; blind semantic read before any intent, name,
   source or version label; perceptual delta test for corrections.
   *(`MISTAKES.md` M-04)*
9. **Do not judge any visual at ×8, or ship a review set without ×2.** ×2 is
   verdict scale; ×8 is inspection only; a pass without the verdict view is
   returned unreviewed. *(`MISTAKES.md` M-05)*
10. **Do not stage blind QA plates inside the round's working directory or any
    path that names the intent**, and do not disclose purpose before the
    first-impression question. *(`MISTAKES.md` M-13)*
11. **Do not declare any UI or art change done on test evidence alone.**
    `flutter test` has no real font and zero safe-area insets. It must be looked
    at, running, on the device — and the device record names the build
    configuration read from the bundle, installed via
    `Scripts/ios/build-release-device.sh`, never Xcode's Run button.
    *(`MISTAKES.md` M-06, M-09)*
12. **Do not emit any audio or haptic cue from a callback an accessibility
    setting can stop** (an `AnimationController` listener, a ticker, a frame
    callback). Reduce Motion may not remove audio; a sound toggle may not remove
    haptics; a haptic toggle may not remove sound. *(`MISTAKES.md` M-16; Q-16)*
13. **Do not introduce a second wall-clock read.** `0022` §8's injectable
    `activityWallClock` seam plus `0026`'s read-only second caller are the entire
    permitted set; `DateTime.now` and `Timer.periodic` stay forbidden in `lib/ui`.
    *(`RULES.md` P-4, E-2; `DECISIONS/0022` §8, `0026` §4;
    `Scripts/check-ui-boundary.sh` rule 5)*
14. **Do not add anything that punishes absence or manufactures urgency** — no
    streaks, daily bonuses, expiring or decaying rewards, goal rings, "you missed"
    panels, energy gates, or any generic mobile-game engagement mechanic.
    *(`RULES.md` P-5; `PROJECT_KERNEL/06_ANTI_FEATURES.md`; `DECISIONS/0022` §2;
    `DECISIONS/0026` § What this deliberately is not)*
15. **Do not let art or audio assert a system Stride does not have** — no coin,
    price, bullion, timer/hourglass, capacity meter, padlock, rarity badge or slot
    machine/jackpot flourish, however well drawn or mixed. A wrong semantic is a
    blocker regardless of craft. *(`RULES.md` P-6; `ART_DIRECTION.md` L-15, L-17,
    L-19; `AUDIO_EVENT_MATRIX` reward prompt)*
16. **Do not use teal `#58D6C0` for anything but walking, steps and banked-step
    quantity**, and do not ship a UI-art family before the palette guard 0029
    names as a production prerequisite exists. *(`ART_DIRECTION.md` L-16;
    `DECISIONS/0029` § Consequences)*
17. **Do not pixelate text, at any size, anywhere**, and do not raster a whole
    screen. Bitmap type is not in scope and is not a future option.
    *(`DECISIONS/0029`; `ART_DIRECTION.md` L-18 as amended)*
18. **Do not use `centerSlice`, or stretch a pixel frame's edge bands.** Corners
    at 1:1 integer scale, edges **tiled**; a once-only ornament may not live inside
    a repeating strip. *(`DECISIONS/0029`; `ART_DIRECTION.md` L-18)*
19. **Do not build a per-screen frame family.** One chassis, app-wide — 0029 names
    this as the failure mode it is most likely to produce if unwatched.
    *(`DECISIONS/0029`)*
20. **Do not let a raster asset carry a word, a number, a state, or a boundary
    Flutter must measure**, and do not break the enforcing test: with the skin
    registry empty the app must lay out, read, navigate and pass its accessibility
    assertions identically, and every screen must revert in one commit.
    *(`DECISIONS/0029`; `ART_DIRECTION.md` L-18)*
21. **Do not paint an image outside `lib/ui/components/pixel_asset.dart`** —
    `Image.asset/file/network/memory`, `DecorationImage` and `paintImage` are all
    caught by the guard, which was strengthened, not relaxed, to admit 0029.
    *(`Scripts/check-ui-boundary.sh` rule 6; `RULES.md` G-4)*
22. **Do not compute or hold durable game state in a widget**, derive a local-day
    figure in `lib/ui`, name a command or the engine there, or touch the
    filesystem or save directory from any presentation or audio code.
    *(`RULES.md` E-2, E-3; `Scripts/check-ui-boundary.sh` rules 1–5, 7;
    `DECISIONS/0013`)*
23. **Do not display or persist any health-source identity** — a source name, a
    bundle id, a device name, a salt or cursor content. Origins are a count; the
    Step Tracker's pseudonymous `Source A / Source B` is the pattern.
    *(`RULES.md` H-7; `DECISIONS/0026` §2)*
24. **Do not source audio from WalkScape, Melvor Idle, Old School RuneScape or
    New World** — absolute. Do not buy a paid library without explicit owner
    approval, do not provider-hop, do not replace an accepted region track or
    action cue casually, and do not generate any audio until the owner explicitly
    reopens generation. *(`DECISIONS/0005`; `AUDIO_PRODUCTION_QUEUE_01.md` §0)*
25. **Do not ship an audio asset without its manifest row**, and do not reference
    audio by filename or path anywhere in game code or content — asset IDs only.
    *(`DECISIONS/0005`; `AUDIO/AUDIO_ASSET_MANIFEST.md`)*
26. **Do not invent a URL for the owner's GitHub audio sources.** They are not in
    the repository; they have been searched for three times. Ask.
    *(`JOURNAL/OPEN_QUESTIONS.md` OD-06; `AUDIO_PRODUCTION_QUEUE_01.md` §0)*
27. **Do not silently answer an open question.** Q-04, Q-06, Q-07, Q-09–Q-17,
    OD-03, OD-04, OD-05, OD-06 are the owner's; label anything undecided
    `UNRESOLVED` and record it. An implementation detail must never become a design
    decision. *(`RULES.md` G-3)*
28. **Do not weaken a guard, loosen an assertion or suppress a fault to make this
    workstream pass.** *(`RULES.md` G-4)*
29. **Do not build a new verification framework or run a repeated-validation
    campaign** without a concrete uncovered risk named before the work starts.
    Change the instrument; do not multiply the runs. *(`RULES.md` G-1;
    `MISTAKES.md` M-01, and the disclaimers closing M-06 and M-07)*
30. **Do not bump a toolchain version to make an asset or audio pipeline work.**
    That is its own branch, its own reformatting, its own run, its own decision.
    *(`RULES.md` G-2; `MISTAKES.md` M-02)*
31. **Do not request an iOS background mode, background delivery or an
    audio/location keep-alive** so ambience or a timer survives backgrounding.
    *(`RULES.md` H-5; `DECISIONS/0022` §4)*
32. **Do not close this workstream without updating `PROJECT_STATE.md` and every
    affected canonical document**, and do not open a second home for a concept that
    already has one. *(`RULES.md` G-5, G-6, G-7)*

---

## 9. Two things the repository does not contain, stated rather than guessed

- **No ADR sanctions Stability AI as an audio provider.** `DECISIONS/0005` names
  ElevenLabs, original/generated assets, and CC0/royalty-free, and forbids paid
  libraries without explicit owner approval. Every shipped audio asset is a
  Stability paid-tier generation accepted by the owner in AUDIO_PRESENTATION_01.
  The acceptance is recorded; the sourcing decision was never amended. Flag to the
  owner; do not resolve it inside this workstream (G-3).
- **Nothing enforces L-16 (`#58D6C0` reserved for walking).** `DECISIONS/0029`
  states the style spec's clearance is *"an impression, not a measurement"*, and
  names a palette guard as a prerequisite of the first UI-art round.

---

## 10. Standing operational facts for VAWO01

| Fact | Value | Source |
|---|---|---|
| PixelLab balance of record | **exactly 25**, atlas emergency reserve, **not authorized for this workstream**; cycle reset **2026-09-16** | `DECISIONS/0029`, `PIXELLAB_UI_PRODUCTION_PLAN.md` |
| PixelLab tier | Tier 2 (Pixel Artisan) — `inpaint_image` at 512×384 available | `PIXELLAB_UI_PRODUCTION_PLAN.md` |
| Stability audio balance | **Unverifiable** — `STABILITY_API_KEY` unset. Last *recorded*: 61 credits, 2026-08-24 | `AUDIO_PRODUCTION_QUEUE_01.md` §0 |
| Save state version | **v9**, unchanged through FDO01 and PCE01 | `PROJECT_STATE.md` v2.34, v2.35 |
| Suites at HEAD | core **738**, app **966**, analyze clean | `PROJECT_STATE.md` v2.35 |
| Known pre-existing defect | `lib/ui/state/craft_memory.dart` violates two UI-boundary rules (from GFCP01 `830f1a1`); flagged not fixed. Memory records CI as RED on it. | `PROJECT_STATE.md` v2.35 |
| Active risks naming this workstream | *"Generic or menu-heavy presentation"*, *"Audio being deferred until the end"*, *"Feature creep"*, *"Overengineering before validating the loop"* | `PROJECT_STATE.md` § Active risks |
| Change class | Content changes need specialist review; **system** changes need design review, technical review and a decision log entry; **Kernel** changes need explicit owner approval | `STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md` |

---

*End of FOUNDATION-A canon report. Read-and-report only; no repository file other
than this one was created or modified.*
