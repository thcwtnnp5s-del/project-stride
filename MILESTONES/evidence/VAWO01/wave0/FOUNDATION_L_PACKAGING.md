# FOUNDATION-L — Asset Packaging / Provenance Audit

```
Role:    FOUNDATION-L (Asset Packaging / Provenance Auditor)
Wave:    VAWO01 Wave 0
Date:    2026-09-01
Branch:  visual-audio-world-overhaul-01 (HEAD 6d41bce, master is 34ae263)
Mode:    read-and-report only. No repository file was modified by this audit
         except this report. No packaging script was run in write mode.
```

**Working-tree caveat.** Wave 0 is running in parallel. Between the first and
last command of this audit the untracked-file count moved from 239 to 246, and
`DECISIONS/0030_VISUAL_AUDIO_WORLD_OVERHAUL_SCOPE.md` appeared mid-audit. Every
count below is a snapshot; re-run the commands in §8 before acting on them.

---

## 0. Headline findings

| # | Finding | Severity |
|---|---|---|
| **L-1** | `AUDIO/evaluation/` — **652 MB, 200+ files, never committed, NOT in `.gitignore`.** A `git add -A` today stages 652 MB of raw WAVs and listening ZIPs into a public repo. This is M-08's exact shape with a bigger payload. | **CRITICAL** |
| **L-2** | The third-party imagery in `WALKSCAPE_REFERENCE_SET/` **is** correctly ignored (`*.jpg`/`*.jpeg`/`*.png` rules at `.gitignore:208-212`). But `README.md` and `OBSERVATION_05.md` in that directory are **not** ignored — the blanket `!**/*.md` exception reaches inside it. They are text, so the exposure is descriptive, not the imagery itself. | MEDIUM |
| **L-3** | CI is genuinely RED, and the cause is `lib/ui/state/craft_memory.dart` failing `check-ui-boundary.sh` (exit 1). Introduced by `830f1a1` (2026-08-28, GFCP01), **three milestones before VAWO01**. Not on `master`. Genuinely pre-existing; does not block this workstream but will make every PR red until fixed. | HIGH (not blocking) |
| **L-4** | Everything else is green: `package-art.js --check` (851 files), `nav-active-variant.js --check`, `check-art-palette.js` (871 PNGs), `check-tile-seam.js` (vacuous), `item_icon_resolution_test`, `node_art_resolution_test`, `audio_assets_test` (10/10). | — |
| **L-5** | The uncommitted `.gitignore` edit adds exceptions for `GAME_BIBLE/ART/exploration/VAWO01/**`, but production-plan precondition **P-5 names `UI_MATERIAL_01/out/**`**. Two different round-directory names. Pick one before the first generation, or `--check` fails on a clean checkout. | HIGH |
| **L-6** | `DECISIONS/0030` says `0005_AUDIO_SOURCING.md` § Permitted sources is amended to cover Stability AI, and that `AUDIO_ASSET_MANIFEST.md` gains a provider entry. **Neither file is modified in the working tree.** The already-shipped audio still has no ADR-sanctioned provider. | MEDIUM |
| **L-7** | Audio has **no packaging script in the repository.** The `.mjs` generation/mastering tools live under the untracked `AUDIO/evaluation/*/tools/`. Audio packaging is documented but not reproducible from a clean checkout — the opposite of the art pipeline. | MEDIUM |

---

## 1. Every script in `Scripts/` that touches assets

`Scripts/` holds 4 asset scripts (all Node, all under `Scripts/art/`) plus one
shared library and the verification driver. Everything else in `Scripts/` is a
platform/persistence guard that never reads an asset.

### 1.1 `Scripts/art/package-art.js` — the packaging pipeline

| | |
|---|---|
| **Language** | Node (CommonJS, no dependencies beyond `./png.js` and Node builtins) |
| **Invocation** | `node Scripts/art/package-art.js` (write) · `node Scripts/art/package-art.js --check` (verify, writes nothing) |
| **Reads** | `GAME_BIBLE/ART/exploration/**` only — 30+ round directories, enumerated in §2.2 |
| **Writes** | `assets/art/v1/**` (851 files) and `lib/ui/icons/sprite_footprints.dart` |
| **Idempotent** | **Yes, by construction.** Re-running produces byte-identical output; `--check` is exactly "would a re-run change anything". |
| **Current state** | **PASS** — `art packaging: 851 files up to date`, exit 0 |

`--check` semantics, from the tail of the file:

- `missing:` — an emitted path absent from `assets/art/v1/`
- `stale:` — present but different bytes
- `unexpected:` — a file in `assets/art/v1/` the script does not emit
  (`.md` excluded). This is the **orphaned-asset check**.
- `stale: lib/ui/icons/sprite_footprints.dart` — the generated Dart drifted

Any problem → prints the list, `Run: node Scripts/art/package-art.js`, exit 1.

**Its stated non-goals (header comment, lines 19-25):** "No generation, no
scaling, no palette change, no sharpening, no recolouring." Permitted operations
are a copy, an alpha key on a flood-filled border region, a rectangular crop, and
a measurement — i.e. `RULES.md` **A-2** deterministic transformation only. It
must never become a second place art is changed.

### 1.2 `Scripts/art/nav-active-variant.js` — the `_hi` derivation

| | |
|---|---|
| **Language** | Node |
| **Invocation** | `node Scripts/art/nav-active-variant.js` · `--check` |
| **Reads** | `assets/ui/v1/nav_{adventure,character,inventory}{,_hi}.png` (the three human-authored reference pairs) |
| **Writes** | `assets/ui/v1/nav_{world,skills,craft}_hi.png` |
| **Transformation** | Palette **index → index remap**, recovered by measurement from the three reference pairs. Indices the three pairs disagree about are reported and left alone. |
| **Idempotent** | Yes |
| **Current state** | **PASS** — all three `up to date`, exit 0 |

Deliberately does **not** widen its reference set to include its own output —
"deriving the mapping from its own output would let a single wrong index
entrench itself as evidence".

### 1.3 `Scripts/art/check-art-palette.js` — the palette guard (NEW, uncommitted)

| | |
|---|---|
| **Language** | Node |
| **Invocation** | `node Scripts/art/check-art-palette.js` · `node Scripts/art/check-art-palette.js --self-test` · `--measure` variants |
| **Reads** | `assets/art/v1`, `assets/ui/v1` (all), plus `assets/ui/v1/{frame,surface,ornament}` for the chrome rules |
| **Writes** | Nothing |
| **Idempotent** | Yes (pure read) |
| **Current state** | **PASS** — `871 PNGs, no teal collision, no semi-transparent pixel, chrome under the textMuted ceiling`, exit 0 |

Four named rules, exit-coded `STRIDE_GUARD[art-palette.<rule>]` (exit 1) vs
`STRIDE_INFRA[<reason>]` (exit 2):

| Rule | What it catches |
|---|---|
| `art-palette.teal` | Any opaque pixel within Chebyshev 10 of `#58D6C0` (L-16's reserved walking teal). One allowlisted file: `assets/ui/v1/glyph_steps.png`. |
| `art-palette.alpha` | Any pixel with `0 < a < 255`. Zero semi-transparent pixels is what makes integer scaling exact (L-18). |
| `art-palette.ceiling` | Any opaque pixel in the interface-art dirs brighter than `textMuted #7C7263` in WCAG relative luminance. |
| `art-palette.substrate` | Any frame pixel drawn in `surfaceCard #201C17` or `surfaceGround #14120F` — a frame in its own background's ink. |

**Status: untracked.** Precondition P-1 of `PIXELLAB_UI_PRODUCTION_PLAN.md`.

### 1.4 `Scripts/art/check-tile-seam.js` — the tiling gate (NEW, uncommitted)

| | |
|---|---|
| **Language** | Node |
| **Invocation** | `node Scripts/art/check-tile-seam.js` · `--self-test` · `node Scripts/art/check-tile-seam.js --measure <png> --period <n> [--axis h\|v]` |
| **Reads** | `assets/ui/v1/frame`, `assets/ui/v1/surface` (both empty today) |
| **Writes** | Nothing |
| **Idempotent** | Yes |
| **Current state** | **PASS (vacuous)** — `no frame or surface assets yet, vacuously satisfied`, exit 0 |

| Rule | What it catches |
|---|---|
| `tile-seam.wrap` | Last column vs first column of a tile, scored as mean absolute channel difference, compared against the tile's own internal column-to-column variation (`WRAP_TOLERANCE = 2.5`; flat strips fall back to `FLAT_ABSOLUTE = 6`). |
| `tile-seam.period` | Whether a strip is honestly periodic at its declared period (`DEFAULT_PERIOD = 8`). A 16-px run carrying a 24-px motif reads as a repeating motif, not a material. |

**A pass here is explicitly not acceptance.** `RULES.md` A-3's logic transfers:
a numeric seam score is a pre-filter; acceptance is a blind read at device scale
at the four widths in production-plan §3.3.

**Status: untracked.** Precondition P-4.

### 1.5 `Scripts/art/measure-ambient-extents.js` — the measuring instrument

| | |
|---|---|
| **Invocation** | `node Scripts/art/measure-ambient-extents.js` |
| **Reads** | `assets/art/v1/{anim,ambient,node}` — the **packaged** art, never the exploration sources, "so what is measured is exactly what ships" |
| **Writes** | Nothing (prints) |
| **Purpose** | Produces the union opaque bounding box per animated sequence and the single-frame box per node vignette. These numbers are hand-transcribed into the composition tables in `lib/ui/icons/ambient_assets.dart`. |

**This is the tool to run whenever a new ambient/node/combat sequence is
packaged.** The bounds it prints are the `StageScenery` values a human must
paste into the Dart table — that hand-off is unguarded and is the most likely
place a big art wave silently regresses composition.

### 1.6 `Scripts/art/png.js` — the shared codec (modified, uncommitted)

Pure-Node PNG reader/writer, no `pngjs`. Exports:

```
Raster, blit, bounds, crop, fill, footprint, load, loadAny, save, scale
```

- `load` — strict RGBA8 decoder. What `package-art.js` depends on. Unchanged.
- `loadAny` — **new, +152 lines, uncommitted.** Read-only decoder for palette
  and greyscale PNGs. Without it the palette guard could not read 13 of 871
  shipped files (the hand-maintained nav icons). **Deliberately has no `save`
  counterpart** — round-tripping a palette PNG would launder it into RGBA
  without anyone deciding to.

### 1.7 `Scripts/verify.sh` — the local driver (modified, uncommitted)

```bash
bash Scripts/verify.sh            # skips steps whose toolchain is absent
bash Scripts/verify.sh --strict   # fails if any toolchain is absent (CI shape)
```

Art-relevant steps, in order:

```bash
node ./Scripts/art/package-art.js --check
node ./Scripts/art/nav-active-variant.js --check
node ./Scripts/art/check-art-palette.js --self-test >/dev/null   # uncommitted
node ./Scripts/art/check-art-palette.js                          # uncommitted
node ./Scripts/art/check-tile-seam.js --self-test >/dev/null     # uncommitted
node ./Scripts/art/check-tile-seam.js                            # uncommitted
```

Prerequisite, once per checkout: `bash Scripts/bootstrap-tooling.sh`
(runs `npm ci --prefix Scripts/tooling --ignore-scripts --no-audit --no-fund`).
`verify.sh` **checks and stops** rather than installing.

### 1.8 Non-asset scripts (for completeness)

`check-{core-purity,ui-boundary,dependency-policy,backup-exclusions,ios-target,android-target,single-writer,step-model,origin-privacy,rulekit,guard-parsers,source-safety,causality-framework,supervisor}.sh`,
`registry-report.sh`, `smoke-round.sh`, `causality-run.sh`,
`android-process-death.sh`, `generate-fixtures.js`, `ios/build-release-device.sh`,
`ios/install-device.sh`, and the `Scripts/lib/` support library. **None reads an
asset file.** `check-ui-boundary.sh` matters to this workstream only because it
is the guard currently red (§6).

---

## 2. The canonical pipeline

### 2.1 The journey, end to end

```
  PixelLab MCP (mcp__pixellab__*)
        │  create_image_pro / inpaint_image / animate_character / edit_image …
        ▼
  GAME_BIBLE/ART/exploration/<ROUND>/            ← the exploration workspace
        ├── tools/args_<name>.json               ← the request, verbatim (provenance)
        ├── raw/  or  candidates/                ← unselected rolls  [NEVER TRACKED]
        ├── out/<name>_job.json                  ← the MCP response: job id, seed, cost
        ├── out/<name>_f<N>.png                  ← the SELECTED frames  [TRACKED by exception]
        ├── out/manifest.json                    ← per-sequence metadata + verdict
        ├── rejected/                            ← rejected rolls with written verdicts
        ├── review/  goldens/                    ← blind-QA plates, byte goldens
        └── README.md                            ← the round record and verdicts
        │
        │  .gitignore exception must exist for out/ BEFORE the commit
        ▼
  Scripts/art/package-art.js                     ← the ONLY writer of assets/art/v1
        │  copy · border-flood alpha key · rectangular crop · frame selection
        │  · byte-copy donor · stamp belts · water join · protected-interior restore
        │  · footprint measurement
        ▼
  assets/art/v1/**                (851 files)    ← "Generated. Do not edit a file here."
  lib/ui/icons/sprite_footprints.dart            ← generated Dart table
        │
        ▼
  pubspec.yaml  flutter: assets:                 ← declaration; undeclared = does not exist
        │
        ▼
  lib/ui/icons/{pixel_icons,ambient_assets,combat_assets,atlas_assets,traveler_art}.dart
        │   hand-maintained lookup tables — the step nothing generates
        ▼
  lib/ui/components/pixel_asset.dart (PixelAsset / PixelScene / PixelFrame)
        │   integer scale, nearest-neighbour, no smoothing (L-18)
        ▼
  iPhone — the only surface that accepts or rejects
```

### 2.2 Every exploration directory `package-art.js` currently reads

```
ACTIVITY_FEEL_01/out/{ambient,combat,env,world}
EXPLORATION_PROGRESSION_LOOP_01/out/items
PHASE1_CARRIED_CORRECTIONS/out/gather_f5_repaired.png
PIXELLAB_PROOF_02/out/character
PIXELLAB_STABILIZATION_01/out
PLAYABLE_EXPANSION_01/out/{ambient,combat,items}
PLAYABLE_EXPANSION_01/combat/candidates/trav_zip/…/traveler_walk/west
PLAYABLE_POLISH_01/out/{ambient,props}
PLAYABLE_POLISH_02/out
PRESENTATION_WORLD_REWARD_FEEL_01/out
REGIONAL_CONTENT_PACK_01/out/{enemies,fauna,gear,materials,vignettes}
TRANSFORMATION_01/out
WORLD_ATLAS_COHERENCE_UI_01
WORLD_ATLAS_REMASTER_01 (+ iteration_02/tools/stamp_belts.js, tools/water_join.js)
WORLD_ATLAS_RESTORE_01
WORLD_MAP_EXPANSION_REFINEMENT_02/out
WORLD_MAP_POLISH_01/out/env
WORLD_MAP_POLISH_03/out
WORLD_REWARD_DEPTH_01/{ambient,combat,items,world}/out
```

Every one of these has a matching `!` exception in `.gitignore`. **Adding a new
round means adding a new exception in the same commit** — precondition P-5, and
the defect `PIXELLAB_ASSET_INVENTORY.md` §2 records shipping once already (the
untracked RCP01 boar/ram/salamander/bear sources made `--check` fail from a
clean checkout for several milestones without anyone noticing locally).

### 2.3 Every transformation the script performs

| Transformation | Where | Example |
|---|---|---|
| **Straight byte copy + re-encode** | most families | item icons, portrait, sprite, combat frames |
| **Dimension assertion** | item icons | `expected 48x48, got WxH` → throw |
| **Border flood-fill alpha key** | `location/havens_rest.png` | PixelLab returned an opaque white ground (34% of file). Flood-fill from the border, **not** a global colour replace, so white *inside* the art survives. |
| **Rectangular crop** | vignettes, ambient, overlays | 512×384 → 384×176; the 80×80 ambient sources cropped to rows 8..71 so feet stay on row 62; `overlay_smoke` cropped `(2,0,16,14)` |
| **Frame selection / drop** | ambient + combat | `manifest.json` declares `frames`, and notes which source frames were dropped and why ("source frames 6-10 dropped: the pack turned into a slatted crate") |
| **`status: withheld` honoured** | combat | withheld sequences are packaged but must not be drawn |
| **Recorded byte-copy donor** | items | FDO01/Fable V2 gear icons are explicit byte copies of the item each consumes; donor table lives in the script |
| **Atlas composition** | `world/atlas_base.png` | stamp belts (`iteration_02/tools/stamp_belts.js`), water join (`tools/water_join.js`), region masks, landmark placement |
| **Protected-interior restore + drift check** | atlas | see §5.1 |
| **Footprint measurement** | `sprite_footprints.dart` | lowest four opaque rows of the rest frame; every frame of a sequence shares the rest frame's footprint |
| **Palette index remap** | nav `_hi` | `nav-active-variant.js`, §1.2 |

There is **no scaling in the pipeline.** Scaling is a runtime concern: `PixelAsset`
draws at an exact integer multiple of the native size with nearest-neighbour
filtering. There are deliberately no `2.0x/`/`3.0x/` directories, because
`AssetImage` would resolve those by `devicePixelRatio` and change the intrinsic
size out from under the explicit width.

### 2.4 Manifests that must be updated

| Manifest | Kind | Who maintains it |
|---|---|---|
| `GAME_BIBLE/ART/exploration/<ROUND>/out/manifest.json` | round metadata (`id`, `frames`, `fps`, `loop`, `canvas`, `baseline`, `anchor`, `groundRow`, `facing`, `kind`, `status`, `note`) | the round author |
| `Scripts/art/package-art.js` source tables | the emit map | packaging author |
| `.gitignore` `!` exception for the round's `out/` | tracking | packaging author, **same commit** |
| `pubspec.yaml` `flutter: assets:` | bundle declaration | see §4 |
| `lib/ui/icons/pixel_icons.dart` — `_itemIcons`, `_nodeArt`, `_skillIcons`, `_vignetteByLocation`, `_altVignetteByLocation` | runtime lookup | integration author |
| `lib/ui/icons/ambient_assets.dart` — `_scenery`, `_workBackdrops`, `_workProps`, `_craftBackdrops`, `_stations`, `_strikeFrames`, `_activityFootprints`, `_activityCanvases` | runtime composition (bounds from §1.5) | integration author |
| `lib/ui/icons/combat_assets.dart`, `atlas_assets.dart`, `traveler_art.dart` | runtime tables | integration author |
| `lib/ui/icons/sprite_footprints.dart` | **generated** — never hand-edit | `package-art.js` |
| `assets/art/v1/README.md`, `assets/ui/v1/README.md` | provenance narrative | integration author |
| `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` | cross-round index (A–I classification) | producer, on every ship/adopt/reject |
| `AUDIO/AUDIO_ASSET_MANIFEST.md` | audio provenance (§9) | audio author |

---

## 3. The provenance system

There are **two provenance systems, of very different maturity.**

### 3.1 Image provenance — convention, not schema; **not enforced by any check**

Recorded in three places per round, all under `GAME_BIBLE/ART/exploration/<ROUND>/`:

1. **`tools/args_<name>.json`** — the request, verbatim. Example
   (`WORLD_ATLAS_REMASTER_01/tools/args_r1_ice.json`, abridged):

```json
{
  "image_base64": "@file:GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/src/r1_ice_src_464x320.png",
  "mask_image_base64": "@file:GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/src/r1_ice_mask_464x320.png",
  "description": "Aerial fantasy world-map pixel art of an arctic sea, top-down. …",
  "crop_to_mask": true,
  "seed": 601
}
```

2. **`out/<name>_job.json`** — the raw MCP response, which carries the **job id,
   size, mask geometry, the prompt as echoed, seed, and cost**. Example
   (`WORLD_ATLAS_COHERENCE_UI_01/out/north_west_job.json`):

```json
{ "content": [ { "type": "text", "text":
  "id: 4e2d2f8a-44ac-4f72-86d5-ffedf8bd53d0\nsize: 288x288px\nmask: box 208x208 at (24,24)\nfill: Repaint this north-western corner as one continuous frozen frontier …\ntransparent: False — auto (input is opaque)\nseed: 103\ncost: ~25 generations\nstatus: processing (~30-90s)\n\nhint: get_image(job_id=\"4e2d2f8a-44ac-4f72-86d5-ffedf8bd53d0\")" } ],
  "isError": false }
```

3. **The verdict** — prose in `README.md` / `INTEGRATION_MANIFEST.md`, plus the
   `status` and `note` fields in `out/manifest.json`
   (`accepted` / `withheld` / `READY WITH NOTE`, and rejection reasons).

**Nothing validates that any of this exists.** `package-art.js --check` proves
the *pixels* are reproducible; it does not ask where they came from. The
enforcement is `assets/art/v1/README.md`'s source table, `PIXELLAB_ASSET_INVENTORY.md`,
and human review. For a wave of hundreds of generations this is the weakest link
in the whole system — see the operating procedure in §10, step 3.

### 3.2 Audio provenance — a real schema, one JSON per candidate

`AUDIO/evaluation/<workstream>/provenance/<CANDIDATE_ID>.json`. This is
materially better than the image side: every field a reproduction needs, plus
the owner's ruling in the same file. Verbatim example
(`audio_presentation_01/provenance/COOK_AP1_SA25_4501.json`):

```json
{
  "candidate_id": "COOK_AP1_SA25_4501",
  "status": "REJECTED_REFERENCE",
  "provider": "Stability AI (Stable Audio)",
  "endpoint": "/v2beta/audio/stable-audio-2/text-to-audio",
  "model": "stable-audio-2.5",
  "mode": "text-to-audio",
  "source_file": null,
  "strength": null,
  "prompt": "TrackType: SFX. Close-mic home hearth cooking recording of one small gesture: …",
  "seed_requested": 4501,
  "steps": "default",
  "cfg_scale": "default",
  "duration_requested_s": 2,
  "output_format": "wav",
  "credits_before": 199,
  "generated_at": "2026-08-24T01:29:57.286Z",
  "request_id": "5707578e0f03d20cd93c021f4deb9def",
  "post_status": 200,
  "seed_returned": "4501",
  "finish_reason": "SUCCESS",
  "completed_at": "2026-08-24T01:30:02.354Z",
  "file": "cooking/raw/COOK_AP1_SA25_4501.wav",
  "bytes": 368940,
  "credit_cost_settled": 20,
  "sha256": "53176b93bab098b9d121af2a8c82c28468873c2fd966b1a88a70a922a4d4eb45",
  "measured": {
    "duration_s": 2,
    "codec": "pcm_s16le 44100 Hz stereo",
    "true_peak_dbtp": 1.4,
    "integrated_lufs": -14.2,
    "decay": "single stir gesture: strong 0.4-0.6 s, …"
  },
  "listening_copy": "cooking/listening/COOK_AP1_SA25_4501_LISTENING.wav (gain -2.4 dB to -1.0 dBTP, no other processing)",
  "ruling": "Rejected by owner 2026-08-24: does not read as actual cooking … Do not derive from this file or reuse its seed. Retained as reference; raw, listening copy and provenance preserved."
}
```

**The enforcement gap:** the shipped `assets/audio/v1/README.md` and
`AUDIO/AUDIO_ASSET_MANIFEST.md` both say this provenance is "preserved untouched
under `AUDIO/evaluation/`". **`AUDIO/evaluation/` has never been committed** —
`git log --all -- AUDIO/evaluation` is empty, and only two files under `AUDIO/`
are tracked. So the canonical documents point at a path that does not exist for
anyone else. See §8 for the disposition question this forces.

**What IS enforced:** `AUDIO/AUDIO_ASSET_MANIFEST.md` states the rule — "A
shipped asset with no manifest row is a **QA defect**, not a paperwork
oversight" — and `test/audio/audio_assets_test.dart` mechanically checks the
table/file/pubspec triangle (§5.4).

**The image side has no equivalent of either.** VAWO01 should consider adopting
the audio schema shape for PixelLab rounds; it is the one artefact that survives
a session ending.

---

## 4. The asset manifests, and which is authoritative

There are **four** lists, and they must all agree.

| # | Manifest | Authority over | What breaks if it disagrees |
|---|---|---|---|
| 1 | `Scripts/art/package-art.js` | **What exists.** The only writer of `assets/art/v1/`. | If it stops emitting a file, `--check` reports `unexpected:` for the orphan still on disk and CI goes red. |
| 2 | `pubspec.yaml` `flutter: assets:` | **What is in the bundle.** | An undeclared file is an asset that does not exist **on the device**, while every desktop test that reads from disk still passes. This is the nastiest disagreement: green locally, blank rectangle on the phone. |
| 3 | `lib/ui/icons/*.dart` lookup tables | **What the game can name.** | A packaged, declared asset with no table entry renders the deliberately-blank `unknown` slab. This is the M-family defect the resolution tests exist for (Wolf Pelt, both jerkins — art generated, QA'd, packaged, declared, and invisible because four lines were missing from `PixelIcons._itemIcons`). |
| 4 | `assets/content/v1/*.json` | **What the game contains.** | An item/node in the content pack with no icon is caught by the resolution tests. |

**Authoritative: `package-art.js`.** `assets/art/v1/README.md` states it flatly —
"Generated. Do not edit a file in this directory." The other three are
declarations *about* what it produces.

**Two declaration styles in `pubspec.yaml`, and the difference matters:**

- **File by file** — `assets/content/v1/*`, all of `assets/ui/v1/`,
  `assets/art/v1/item/*`, `location/*`, `anim/*`, `portrait/*`, `sprite/*`,
  and **all of `assets/audio/v1/`**. Rationale in the file: "an undeclared file
  is an asset that does not exist, and a stray one is an asset nobody reviewed."
  → **A new item icon needs a new `pubspec.yaml` line.**
- **Whole directory** — `assets/art/v1/{ambient,combat,world,env,node,work}/`.
  Rationale: these are generated in bulk and `package-art.js --check` already
  guards their contents; listing each file "would be a second copy of that
  manifest that drifts."
  → **A new ambient/combat/env/node/work/world frame needs no pubspec change.**

Get this backwards in either direction and the failure is silent on desktop.

---

## 5. Every validation and guard over assets

### 5.1 Atlas protected-interior + landmark-golden guard

- **Lives in:** `Scripts/art/package-art.js`, ~lines 1590-2110 (inside the atlas
  composition, not a separate script).
- **Run with:** `node Scripts/art/package-art.js --check` (or the write run —
  it throws either way).
- **Catches:**
  - *Protected interior drift* — the approved atlas core is snapshotted before
    any repair layer; every repair pixel deeper than the narrow rim band is
    restored; any surviving non-water drift throws
    `world/atlas_base: protected interior drift — N px`.
  - *Landmark golden drift* — 15 byte-enforced golden crops under
    `WORLD_ATLAS_REMASTER_01/goldens/`, checked against a `landmark_registry.json`
    rect. Any change throws `world/atlas_base: protected landmark '<id>' drifted
    (N px vs its golden) — a layer repainted a registry feature`.
  - Deep-teal water is exempt in both, deliberately and symmetrically.
- **Re-authorization protocol:** you do not weaken the guard. You re-extract the
  golden **in the same commit as the change**, and *the golden's git diff is the
  authorization*. `RULES.md` A-4, `MISTAKES.md` M-15.
- **Current state: PASS.**

### 5.2 Packaging equivalence + orphan check

`node Scripts/art/package-art.js --check` — §1.1. **PASS (851 files).**
This is simultaneously the asset-existence check, the byte-equivalence check,
the dimension check (item icons assert 48×48; goldens assert their registry
size), and the **orphaned-asset check** (`unexpected:`).

### 5.3 Palette and tile-seam guards

`node Scripts/art/check-art-palette.js` — **PASS, 871 PNGs.**
`node Scripts/art/check-tile-seam.js` — **PASS (vacuous, no frame art yet).**
Both uncommitted. §1.3, §1.4.

### 5.4 Runtime resolution tests

```bash
flutter test test/item_icon_resolution_test.dart \
             test/node_art_resolution_test.dart \
             test/audio/audio_assets_test.dart
```

**Current state: PASS, 10/10** (measured this session).

| Test | Holds |
|---|---|
| `item_icon_resolution_test.dart` | For every id in the **real** `assets/content/v1/items.json`: `PixelIcons` has an entry (not the slab), the named asset loads **from the bundle**, and the decoded image is not mostly transparent. |
| `node_art_resolution_test.dart` | Same for `resource_nodes.json`: art table entry, `StageScenery` bounds entry, asset loads, image visible. |
| `audio/audio_assets_test.dart` | Every `AudioCues.files` entry exists on disk **and** is declared in `pubspec.yaml`; every region-music key is a real location; every action-cue key is a real skill; the five accepted region tracks are present by name. |

These are the guards against manifest disagreement #3 in §4. **Any VAWO01 asset
family that gets a new lookup table should get a sibling of these tests** —
there is currently no equivalent for enemies, locations, work stations, or
equipment overlays.

### 5.5 Product-UI boundary guard

`bash Scripts/check-ui-boundary.sh` — **FAIL, exit 1.** See §6. Relevant to art
because it is the guard enforcing that all image drawing goes through
`lib/ui/components/pixel_asset.dart`: it matches
`Image.(asset|file|network|memory)`, `DecorationImage` and `paintImage` outside
that file (`AssetImage` alone is deliberately unmatched, for
`precacheImage`). That is production-plan precondition **P-3**, and it is
satisfied.

### 5.6 Golden image tests

`test/goldens/` — 15 PNGs (`combat_stage`, `combat_victory`, `craft_stage`,
`phase1_*`, `atlas_*`). **Excluded from CI deliberately** (`dart_test.yaml`):
Flutter's text rasterization differs across platforms, so a Windows-captured
golden cannot match on the Linux runner. They are a local instrument, regenerated
with `flutter test --update-goldens` and diffed by a person. **They are not a gate
for this workstream** — but a large visual pass will change them, and
regenerating them without looking at the diff wastes their only value.

### 5.7 What has NO guard

- **Image provenance.** Nothing checks that a packaged frame has a
  `job.json`/`args.json`/verdict.
- **`ambient_assets.dart` composition bounds.** `measure-ambient-extents.js`
  prints them; a human transcribes them; nothing compares the two.
- **Asset count / budget drift.** Nothing notices the tree growing by 400 files.
- **Enemy, location, work-station, equipment-overlay resolution.** No sibling of
  §5.4 exists for those families.

---

## 6. CI, and the `craft_memory` failure

### 6.1 Configuration

`.github/workflows/ci.yml`:

```yaml
on:
  push:
    branches: [master]
  pull_request:
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

**Pushing a feature branch does not run CI.** Only `master` pushes, pull
requests, and manual dispatch do. Four jobs: `core` (ubuntu, the guards + Dart +
Flutter tests), `pigeon` (ubuntu, binding drift), `android` (ubuntu, APK +
minSdk 26 proof), `ios` (macos, compile + simulator Keychain).

Flutter channel is **pinned, not floating** — a reproducibility fix after a
stable-channel move changed `dart format` output and reddened three untouched
files.

Art steps live in `core`, in this order:

```yaml
- name: Core purity guard
  run: bash ./Scripts/check-core-purity.sh
- name: Product UI boundary guard          # ← THE RED ONE
  run: bash ./Scripts/check-ui-boundary.sh
- name: Dependency policy guard
  run: bash ./Scripts/check-dependency-policy.sh
- name: Shipped art matches the packaging step
  run: |
    node ./Scripts/art/package-art.js --check
    node ./Scripts/art/nav-active-variant.js --check
```

Note the ordering: **the UI-boundary guard runs before the art step.** A red
boundary guard means the art check never executes in CI. Until §6.2 is fixed,
`package-art.js --check` in CI is unproven for this branch — verify locally.

### 6.2 The `craft_memory` failure, precisely

```
$ bash Scripts/check-ui-boundary.sh ; echo $?
error: lib/ui must not import storage internals (package:path_provider/)
lib/ui/state/craft_memory.dart: 29:import 'package:path_provider/path_provider.dart';
error: lib/ui must not touch the filesystem
lib/ui/state/craft_memory.dart: 47:      file = File('${support.path}/craft_memory.json');
81:      final File tmp = File('${file.path}.tmp');
1
```

Two violations of `RULES.md` **E-2** in one file: `lib/ui/state/craft_memory.dart`
imports `path_provider` and constructs `File` handles directly, giving the
product UI its own durable write path around `StrideSession`.

**Is it pre-existing?**

```
$ git log --diff-filter=A --format='%H %ad %an %s' --date=short -- lib/ui/state/craft_memory.dart
830f1a1aed90d1d96fec5b348acc63a2737990bb 2026-08-28 Studio Stride
  GFCP01 craft: completion becomes an arrival, and a lost level-up is found
```

**Yes — genuinely and unambiguously.** Introduced 2026-08-28 by Game Feel &
Character Presentation 01, four days and three milestones before VAWO01 opened.
It is the file's *only* commit. `git merge-base --is-ancestor 830f1a1 master`
returns false, so **`master` is clean** and the failure exists only on the
GFCP01 → FDO01 → PCE01 → VAWO01 branch lineage.

**Does it block this workstream?**

- **It does not block the work.** VAWO01 touches presentation art, audio and the
  world atlas. Nothing in this workstream causes, worsens, or depends on it.
- **It does distort the evidence.** Any PR from this branch is red before it
  starts, and the art steps never run in CI because they are sequenced after the
  boundary guard. **All CI-equivalent evidence for VAWO01 must be produced
  locally** via `bash Scripts/verify.sh`, and the report must say so.
- **It is not this workstream's to fix silently.** Fixing it means moving craft
  memory behind `StrideSession` — a real architecture change in a workstream
  whose own ADR says "no gameplay-systems expansion". Options, in order of
  preference: (a) a separate one-commit fix on its own branch, merged to master
  first; (b) an explicit owner-authorized carve-out; (c) proceed with local
  evidence and state the condition. **Do not weaken `check-ui-boundary.sh`** —
  that is `RULES.md` G-4 verbatim.

### 6.3 Everything else, measured this session

| Guard | Command | Result |
|---|---|---|
| Core purity | `bash Scripts/check-core-purity.sh` | PASS (41 Dart files, 7 forbidden imports) |
| Product UI boundary | `bash Scripts/check-ui-boundary.sh` | **FAIL (exit 1)** — §6.2 |
| Single-writer | `bash Scripts/check-single-writer.sh` | PASS (145 Dart, 13 native) |
| Dependency policy | `bash Scripts/check-dependency-policy.sh` | PASS (7 pubspecs) |
| Art packaging | `node Scripts/art/package-art.js --check` | PASS (851 files) |
| Nav variant | `node Scripts/art/nav-active-variant.js --check` | PASS (3 files) |
| Art palette | `node Scripts/art/check-art-palette.js` | PASS (871 PNGs) |
| Tile seam | `node Scripts/art/check-tile-seam.js` | PASS (vacuous) |
| Asset resolution | `flutter test test/item_icon_resolution_test.dart test/node_art_resolution_test.dart test/audio/audio_assets_test.dart` | PASS (10/10) |

---

## 7. Git hygiene

### 7.1 The rule

`RULES.md` **G-8** — *Stage explicit paths. Never `git add -A` or `git add .`*

> Name the paths a commit is for, or read `git status --short` before
> committing. A blind stage published 929 untracked files — including
> third-party reference imagery marked `DO NOT COMMIT` — to a public repository,
> and required a history rewrite to undo. A commit that adds far more files than
> its message describes is a defect signal, not a tidy-up.

`MISTAKES.md` **M-08** records the incident: four Playable Phase 2 commits staged
with `git add -A` swept 929 untracked files across nineteen directories; twelve
were in `WALKSCAPE_REFERENCE_SET/`, nine of them third-party imagery. The
repository is public and deliberately so. The commits were pushed. Untracking at
the tip did nothing; it needed a history rewrite.

`DECISIONS/0030` restates it for this workstream: *"No blind staging. G-8 binds
this workstream with unusual force … Paths are named, every time."*

### 7.2 The `.gitignore` architecture for art

The default is **inverted** for the exploration tree (`.gitignore:171-173`):

```gitignore
GAME_BIBLE/ART/exploration/**
!GAME_BIBLE/ART/exploration/**/          # directories, so exceptions can descend
!GAME_BIBLE/ART/exploration/**/*.md      # round records and specs, everywhere
```

Nothing under `exploration/` is tracked unless it is named. ~30 `!` exceptions
follow, one per round's packaging sources (§2.2). The file's own comment explains
why: *"A rule beats a README, because the README was already right and was still
not read by the command that mattered."*

Then the absolute floor (`.gitignore:208-212`):

```gitignore
# Never, under any exception: third-party reference imagery.
GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/*.jpg
GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/*.jpeg
GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/*.png
```

Verified working:

```
$ git check-ignore -v GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/*
.gitignore:210:…/*.jpg   01_walkscape_ui_stats_inventory.jpg
… (all nine images ignored) …
.gitignore:173:!…/**/*.md   OBSERVATION_05.md      ← NOT ignored
.gitignore:173:!…/**/*.md   README.md              ← NOT ignored
.gitignore:171:…/**         README.txt
```

**The nine images are safe. The two `.md` files are not** — the blanket `*.md`
exception reaches into the reference-set directory. They are prose about the
reference study rather than the imagery, so the risk is descriptive rather than
a licence problem, but `README.md` is the file whose header says `DO NOT COMMIT`.
**Never stage `GAME_BIBLE/ART/exploration/` as a directory.**

### 7.3 The specific dangerous paths

**Never stage, under any circumstances:**

```
GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/     (any part of it)
```

**Never stage as a directory — always name individual files:**

```
GAME_BIBLE/ART/exploration/          (reaches the reference set's .md files)
AUDIO/                               (reaches 652 MB of untracked evaluation data)
AUDIO/evaluation/                    (652 MB, not ignored, never committed)
.                                    (everything above)
```

**Forbidden commands, verbatim:**

```
git add -A          git add .          git add -u .
git commit -a       git commit -am     git add GAME_BIBLE/
git add AUDIO/      git stash -u  (then popping into a staged tree)
```

**Also never stage:** `Scripts/tooling/node_modules/`, `build/`, `.dart_tool/`,
`test/failures/`, `ios/Flutter/Local.xcconfig`, anything matching the secrets
block at the top of `.gitignore` (`*.jks`, `*.p12`, `*.mobileprovision`, `.env*`,
`service-account*.json`, `GoogleService-Info.plist`).

### 7.4 The safe staging pattern

```bash
# 1. Look at everything, including files inside untracked directories.
git status --short --untracked-files=all

# 2. Stage by explicit path. One path per argument. No globs that can widen.
git add assets/art/v1/item/new_icon.png
git add "GAME_BIBLE/ART/exploration/VAWO01/out/frame_f0.png"
git add pubspec.yaml lib/ui/icons/pixel_icons.dart .gitignore

# 3. Read back exactly what is staged, and count it.
git diff --cached --name-only
git diff --cached --name-only | wc -l

# 4. Sanity gate: does the count match the message? Does anything under
#    WALKSCAPE_REFERENCE_SET or AUDIO/evaluation appear?
git diff --cached --name-only | grep -E 'WALKSCAPE_REFERENCE_SET|AUDIO/evaluation' \
  && echo "STOP — dangerous path staged" || echo "clear"

# 5. Only then:
git commit -m "…"
```

A glob is acceptable **only** when it cannot widen — `git add
'GAME_BIBLE/ART/exploration/VAWO01/out/*.png'` is fine because the directory is
this round's own and the extension is fixed. `git add
'GAME_BIBLE/ART/exploration/VAWO01/**'` is not.

---

## 8. Untracked-directory classification

Snapshot: `git status --short --untracked-files=all` → 239 entries at audit
start (246 by the end; Wave 0 is writing). Total on-disk size of untracked
material: **653 MB**, of which `AUDIO/evaluation/` is 652 MB.

Extension histogram: 76 `.json`, 57 `.md`, 52 `.wav`, 18 `.mp3`, 13 `.mjs`,
9 `.zip`, 9 `.png`, 2 `.js`, 1 `.txt`.

| Path | Files | Classification | Reasoning |
|---|---|---|---|
| `AUDIO/evaluation/stable_audio_bakeoff_00/**` | ~110 | **UNCLEAR — owner decision required; DO NOT stage blind** | 400+ MB. `assets/audio/v1/README.md` and `AUDIO_ASSET_MANIFEST.md` both cite this path as where provenance "is preserved", but it has never been committed and is not ignored. Three options: (a) commit only `provenance/*.json` + `INDEX*.md` + `tools/*.mjs` and add an ignore rule for `raw/`, `listening/` and `*.zip`; (b) commit nothing and amend the READMEs to say the evaluation corpus is local-only; (c) LFS. **(a) is the recommendation** — it makes the cited provenance real at a few hundred KB. |
| `AUDIO/evaluation/audio_presentation_01/**` | ~90 | **UNCLEAR — same decision** | ~250 MB. Same shape. Its `provenance/*.json` are the best provenance artefacts in the repository (§3.2) and are the part worth tracking. |
| ↳ `…/provenance/*.json` (35 files) | 35 | **SHOULD BE COMMITTED** (under option (a)) | Tiny, textual, and the thing the shipped READMEs promise exists. |
| ↳ `…/tools/*.mjs`, `…/tools/job_*.json` (49) | 49 | **SHOULD BE COMMITTED** (under option (a)) | The generation and mastering tooling. Without it, audio packaging is not reproducible from a clean checkout (finding L-7). |
| ↳ `…/raw/*.wav` (52), `…/listening/*` (mp3/wav), `*.zip` (9) | ~80 | **SHOULD REMAIN UNTRACKED** | 26 MB per music WAV; a 56 MB ZIP. Regenerable-in-principle audition material. Needs an explicit `.gitignore` rule so `git add -A` cannot reach it. |
| `GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/README.md` | 1 | **THIRD-PARTY-NEVER-COMMIT** | Its own header reads `REFERENCE EVIDENCE ONLY — NOT CANON — NOT A PROJECT STRIDE ASSET / DO NOT COMMIT`. The `.md` exception un-ignores it. Never stage. |
| `GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/OBSERVATION_05.md` | 1 | **THIRD-PARTY-NEVER-COMMIT** | Same directory, same instruction. |
| `GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/*.jpg|*.png` (9) | 9 | **THIRD-PARTY-NEVER-COMMIT** *(already `.gitignore`-blocked; does not appear in `git status`)* | The M-08 payload. Verified ignored by `git check-ignore`. |
| `GAME_BIBLE/ART/exploration/WALKSCAPE_PIVOT_01/**` (`.md`) | 9 | **SHOULD REMAIN UNTRACKED** (as-is), or commit deliberately | Round records for a superseded direction. The `.md` exception makes them addable. Harmless but out of VAWO01's scope — do not sweep them in. |
| `GAME_BIBLE/ART/exploration/PORTRAIT_SYSTEM_03/*.md` | 6 | **SHOULD REMAIN UNTRACKED** (out of scope) | Paused portrait workstream records. |
| `GAME_BIBLE/ART/exploration/PIXELLAB_STABILIZATION_01/out/{boards,icons}/**`, `icons_full/icon_canvas_backpack_48.png`, `location/tavern_interior_GROUNDING_TEST.png` | 9 | **UNCLEAR — leaning SHOULD BE COMMITTED** | These are inside a **tracked-by-exception** `out/` tree (`!…/PIXELLAB_STABILIZATION_01/out/**`), so they are stageable and their siblings are tracked. `icon_canvas_backpack_48.png` is explicitly *not* packaged (no `item.canvas_backpack`); the tavern PNG is a failed grounding test. Committing them completes the round's evidence at ~9 files; leaving them makes the tracked `out/` tree partial. **Decide once, record the decision.** |
| `GAME_BIBLE/ART/exploration/REGIONAL_CONTENT_PACK_01/{enemies,materials,qa,world}/*.md` | 7 | **SHOULD REMAIN UNTRACKED** (out of scope) | Round records; RCP01's packaging sources under `out/` are already tracked. |
| `GAME_BIBLE/ART/exploration/{CHARACTER_REBUILD_01,CHARACTER_REBUILD_02,DIRECTION_A_ROUND_01,FAR_ARM_FEASIBILITY_01,HAVENS_REST_BASE_02,HAVENS_REST_HOLLOW_02A,HAVENS_REST_HOLLOW_03A,PIXELLAB_PROOF_01,PIXELLAB_PROOF_03,WALKSCAPE_CHARACTER_EXPLORATION_01,WALKSCAPE_CHARACTER_EXPLORATION_02,WALKSCAPE_ENVIRONMENT_EXPLORATION_01}/*.md` | 12 | **SHOULD REMAIN UNTRACKED** (out of scope) | One `.md` each: historical round records from superseded explorations. |
| `GAME_BIBLE/ART/exploration/{CHARACTER_PORTRAIT_CLOSEOUT,NEUTRAL_STAGING_CHECKLIST,ROUND_03_PACKAGE}.md` | 3 | **UNCLEAR** | Top-level exploration documents. `CHARACTER_PORTRAIT_CLOSEOUT.md` is **cited by `assets/art/v1/README.md`** as the record of what the portrait workstream never solved — a cited document that is not in the repository. Worth committing on that ground alone. |
| `GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/{README.md,PIXELLAB_STYLE_SPEC_01.md,tools/}` | 3 | **SHOULD BE COMMITTED** | `PIXELLAB_STYLE_SPEC_01.md` §4.1 and §12 are cited by `check-art-palette.js` and `PIXELLAB_UI_PRODUCTION_PLAN.md` as load-bearing. A guard citing an untracked document is a dangling reference. |
| `DECISIONS/0030_VISUAL_AUDIO_WORLD_OVERHAUL_SCOPE.md` | 1 | **SHOULD BE COMMITTED** | The ADR authorizing this entire workstream. Appeared mid-audit. |
| `Scripts/art/check-art-palette.js` | 1 | **SHOULD BE COMMITTED** | Production-plan P-1. Passes. Wired into `verify.sh`. |
| `Scripts/art/check-tile-seam.js` | 1 | **SHOULD BE COMMITTED** | Production-plan P-4. Passes. Wired into `verify.sh`. |
| `MILESTONES/evidence/VAWO01/wave0/*.md` | 4+ | **SHOULD BE COMMITTED** | Wave 0 audit reports, this file included. |
| *(modified, not untracked)* `.gitignore`, `Scripts/art/png.js`, `Scripts/verify.sh` | 3 | **SHOULD BE COMMITTED** | The P-1/P-4/P-5 wiring. **But resolve L-5 first** — the `.gitignore` block names `VAWO01/`, the production plan names `UI_MATERIAL_01/`. |

**The single most important line in this section:** `AUDIO/evaluation/` is
652 MB, not ignored, and never committed. Until an ignore rule or a tracking
decision lands, one `git add -A` reproduces M-08 at 700× the byte count. Fixing
this is cheap and should happen in VAWO01's first commit regardless of which
disposition the owner chooses.

---

## 9. How audio is packaged, and how it differs

### 9.1 The chain

```
Stability AI Stable Audio (stable-audio-3 music / stable-audio-2.5 SFX)
    ↓  AUDIO/evaluation/<workstream>/tools/gen*.mjs        [UNTRACKED]
AUDIO/evaluation/<workstream>/<family>/raw/<CANDIDATE>.wav [UNTRACKED, 26 MB each]
    ↓  gain to -1.0 dBTP, no other processing
…/<family>/listening/<CANDIDATE>_LISTENING.wav             [UNTRACKED]
    ↓  zipped, sent to owner, ruled on
…/provenance/<CANDIDATE>.json  ("status", "ruling")        [UNTRACKED]
    ↓  MANUAL: gain / trim+fade / format conversion
assets/audio/v1/{music/*.m4a, sfx/*.wav}                   [TRACKED, 10 files]
    ↓
pubspec.yaml  (file by file — no directory declarations)
    ↓
lib/audio/audio_cues.dart  (AudioCues.files, regionMusic, actionCues, trimDb)
    ↓
test/audio/audio_assets_test.dart
```

### 9.2 How it differs from images

| | Images | Audio |
|---|---|---|
| Packaging step | **`Scripts/art/package-art.js`**, in-repo, reproducible, `--check`-verified | **No script in the repository.** Mastering is described in `assets/audio/v1/README.md` (per-file dB figures) but performed by hand/by untracked `.mjs` tools. |
| Byte equivalence proof | `--check` reproduces every file from source | **None.** Nobody can re-derive `music_haven_01.m4a` from a clean checkout. |
| Provenance | ad-hoc `job.json` / `args.json` / prose | **Structured JSON schema per candidate** (§3.2) — better than the image side |
| Manifest | four lists (§4) | `AUDIO/AUDIO_ASSET_MANIFEST.md` (canonical: asset ID → file → source → licence → model → prompt → date → consumer), `assets/audio/v1/README.md` (mastering), `pubspec.yaml`, `lib/audio/audio_cues.dart` |
| pubspec declaration | mixed file-by-file and directory | **file by file, always** — "an undeclared file is audio that does not exist" |
| Test | `item_icon_resolution_test`, `node_art_resolution_test` | `test/audio/audio_assets_test.dart` — file exists **and** is pubspec-declared **and** its key is a real location/skill |
| Formats | PNG only | **music: AAC 192 kbps `.m4a`, 150 s** (decode cost amortised over a long loop) · **SFX: WAV 44.1 kHz 16-bit stereo** (transient clarity, zero decode cost) |
| Mastering targets | n/a | **music: uniform −1.5 dB → −15.5 LUFS-I, true peak ≤ −1.0 dBTP after AAC** · **SFX: per-file gain to exactly −1.0 dBTP** |
| Runtime correction | none | `ActionCue.trimDb` in `lib/audio/audio_cues.dart` — a **runtime attenuation**, not a re-master, added by PCE01 to close a 10.4 dB LUFS-M spread between cues without touching a byte |

### 9.3 The two audio-specific rules

- **Nothing in the game ever references an audio filename.** `GameEvent →
  asset ID → manifest → file`. Replacing a placeholder with a better recording
  is a one-row change in `AUDIO_ASSET_MANIFEST.md`.
- **Forbidden sources, absolute** (`AUDIO_ASSET_MANIFEST.md`): "Any asset
  extracted from WalkScape, Melvor Idle, Old School RuneScape, or New World.
  These are references for identity, never sources for files."

### 9.4 Open audio debt for VAWO01

- **L-6:** `DECISIONS/0005` § Permitted sources lists only ElevenLabs / original
  recordings / CC0. **Stability AI is not listed**, in either the ADR or the
  manifest's Sourcing rules block, despite ten shipped assets from it.
  `DECISIONS/0030` says it amends this. **The amendment has not been written** —
  neither file is modified in the working tree. Do it before shipping new audio.
- **L-7:** the packaging tooling is untracked (§8).
- **`Q-16` is a hard prerequisite** for combat audio, per 0030: combat reads
  `disableAnimationsOf` nowhere, so under Reduce Motion a 2.5 s round collapses
  to ~125 ms and segment-placed cues would arrive nearly simultaneously with no
  voice cap. **Combat audio must not land before that is answered, or `M-16`
  repeats with more voices.**

---

## 10. The operating procedure

Run this for **every** new asset. Steps 0, 3, 9 and 11 are the ones a big wave
skips and regrets.

### Step 0 — Before any generation

```bash
# Live budget. A remembered figure has been wrong three times in this project.
#   mcp__pixellab__get_balance
```

- [ ] `get_balance` called live this session (P-0). Never trust a remembered figure.
- [ ] Round directory name **decided and consistent** — resolve finding L-5:
      the uncommitted `.gitignore` says `VAWO01/`, production-plan P-5 says
      `UI_MATERIAL_01/`. One name, everywhere.
- [ ] `.gitignore` exception for the round's `out/` (and `src/`, `tools/`,
      `review/`, `rejected/` as needed) **already present**, with `raw/`
      explicitly excluded. An untracked packaging source is a latent
      clean-checkout `--check` failure (P-5, `PIXELLAB_ASSET_INVENTORY.md` §2).
- [ ] Preconditions green:
      `node Scripts/art/check-art-palette.js && node Scripts/art/check-tile-seam.js`

### Step 1 — Generate

- [ ] Write the request to `GAME_BIBLE/ART/exploration/<ROUND>/tools/args_<name>.json`
      **before** the call, and keep it. It is the reproduction record.
- [ ] Call the PixelLab MCP tool. PixelLab authors; Claude does not draw
      production art in code (`RULES.md` A-1). If PixelLab fails, keep the
      temporary asset, record the failure, escalate.

### Step 2 — Land raw output

- [ ] Unselected rolls → `<ROUND>/raw/` (**never tracked**).
- [ ] Save the MCP response to `<ROUND>/out/<name>_job.json` — job id, seed,
      size, mask geometry, cost.

### Step 3 — Record provenance (the step that gets skipped)

- [ ] `args_<name>.json` (request) and `<name>_job.json` (response) both on disk.
- [ ] A written verdict: `accepted` / `withheld` / `rejected`, with the reason,
      in `<ROUND>/README.md` **and** in `out/manifest.json`'s `status`/`note`.
- [ ] Rejected rolls kept under `<ROUND>/rejected/` with their verdict —
      re-learning a rejection costs generations (`MISTAKES.md` M-05).
- [ ] Consider adopting the audio provenance schema (§3.2) for image rounds.
      Nothing enforces image provenance; a hundreds-generation wave is exactly
      where the informal convention breaks.

### Step 4 — Select and land packaging sources

- [ ] Accepted frames → `<ROUND>/out/`, named to the sequence convention
      (`<id>_f<N>.png`).
- [ ] `<ROUND>/out/manifest.json` written: `id`, `frames`, `fps`, `loop`,
      `canvas`, `baseline`, `anchor`/`groundRow`, `facing`, `kind`, `status`, `note`.

### Step 5 — Teach the packaging script

- [ ] Edit `Scripts/art/package-art.js`: add the source path, the emit path, and
      any crop/key/frame-selection, **with the reasoning in a comment**. That
      comment is the only place the framing decision will ever be readable.
- [ ] Only A-2 operations. No generation, no scaling, no palette change, no
      sharpening, no recolouring. Invent no new object, silhouette, animation
      frame or illustrated content.
- [ ] Atlas work only: masks authored in or outside the 20 px rim band; if a
      protected landmark legitimately changes, **re-extract its golden in the
      same commit** — the golden's diff is the authorization (A-4, M-15).

### Step 6 — Package

```bash
node Scripts/art/package-art.js
node Scripts/art/nav-active-variant.js      # only if a nav glyph changed
```

- [ ] Read the emitted count and the footprint lines. A count that moved by more
      than you expected is a defect signal.

### Step 7 — Measure, if the asset is composed on a stage

```bash
node Scripts/art/measure-ambient-extents.js
```

- [ ] Transcribe the printed bounds into `lib/ui/icons/ambient_assets.dart`
      (`StageScenery`). **Nothing guards this transcription.** Read it twice.

### Step 8 — Declare

- [ ] `pubspec.yaml`: add a line **if and only if** the asset is in a
      file-by-file family — `item/`, `location/`, `anim/`, `portrait/`,
      `sprite/`, all of `assets/ui/v1/`, all of `assets/audio/v1/`.
      `ambient/`, `combat/`, `world/`, `env/`, `node/`, `work/` are
      whole-directory and need nothing.

### Step 9 — Name it in the runtime

- [ ] Add the lookup entry: `PixelIcons._itemIcons` / `_nodeArt` /
      `_skillIcons` / `_vignetteByLocation` / `_altVignetteByLocation`, or the
      relevant `AmbientAssets` / `CombatAssets` / `AtlasAssets` / `TravelerArt`
      table.
- [ ] **This is the step that has failed most often.** Packaged, QA'd, declared
      art with no table entry renders the deliberately blank `unknown` slab and
      passes every check except a human looking at a phone.

### Step 10 — Update the written record

- [ ] `assets/art/v1/README.md` (or `assets/ui/v1/README.md`) — a row: path,
      native size, displayed size, source, verdict.
- [ ] `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` — the cross-round index.
      Update it "whenever a round ships, adopts, or rejects assets".
- [ ] Audio only: a row in `AUDIO/AUDIO_ASSET_MANIFEST.md` — asset ID, file,
      source, licence, model/version, verbatim prompt, date, consumer.
      A shipped asset with no manifest row is a QA defect.

### Step 11 — Re-run every guard

```bash
node Scripts/art/package-art.js --check          # must say "up to date"
node Scripts/art/nav-active-variant.js --check
node Scripts/art/check-art-palette.js --self-test >/dev/null
node Scripts/art/check-art-palette.js
node Scripts/art/check-tile-seam.js --self-test >/dev/null
node Scripts/art/check-tile-seam.js
flutter test test/item_icon_resolution_test.dart \
             test/node_art_resolution_test.dart \
             test/audio/audio_assets_test.dart
bash Scripts/verify.sh          # the full local pass, before committing
```

- [ ] `verify.sh` will still fail at "Product UI boundary" on the pre-existing
      `craft_memory` violation (§6.2). **Record that as a known pre-existing
      condition; never weaken the guard to get past it** (`RULES.md` G-4).
- [ ] Golden tests are local-only; if a visual change moves them, regenerate
      with `flutter test --update-goldens` **and look at the diff**.

### Step 12 — Stage explicitly, and verify what you staged

```bash
git status --short --untracked-files=all

git add assets/art/v1/<family>/<file>.png            # each new/changed asset
git add GAME_BIBLE/ART/exploration/<ROUND>/out/<file>.png
git add GAME_BIBLE/ART/exploration/<ROUND>/out/manifest.json
git add GAME_BIBLE/ART/exploration/<ROUND>/tools/args_<name>.json
git add GAME_BIBLE/ART/exploration/<ROUND>/out/<name>_job.json
git add GAME_BIBLE/ART/exploration/<ROUND>/README.md
git add Scripts/art/package-art.js .gitignore pubspec.yaml
git add lib/ui/icons/pixel_icons.dart lib/ui/icons/sprite_footprints.dart
git add assets/art/v1/README.md GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md

git diff --cached --name-only
git diff --cached --name-only | wc -l
git diff --cached --name-only | grep -E 'WALKSCAPE_REFERENCE_SET|AUDIO/evaluation' \
  && echo "STOP — dangerous path staged" || echo "clear"
```

- [ ] The staged count matches what the commit message describes. "A commit that
      adds far more files than its message describes is a defect signal, not a
      tidy-up" (G-8).
- [ ] **Never** `git add -A`, `git add .`, `git add GAME_BIBLE/`, `git add AUDIO/`,
      `git commit -a`, `git commit -am`.

### Step 13 — Device

- [ ] The iPhone is the verdict surface. `Scripts/ios/build-release-device.sh`
      (Xcode Run installs Debug — M-09). A guard pass is a pre-filter; a blind
      read at device scale is acceptance (A-3).

---

## 11. What this workstream should fix before it generates anything

1. **`AUDIO/evaluation/` disposition** (L-1). An ignore rule at minimum;
   preferably commit `provenance/` + `tools/` + `INDEX*.md` and ignore `raw/`,
   `listening/`, `*.zip`. This is the largest live G-8 hazard in the tree.
2. **Round-directory name** (L-5). `VAWO01/` vs `UI_MATERIAL_01/`. One name in
   `.gitignore`, `package-art.js`, and the production plan.
3. **`DECISIONS/0005` + `AUDIO_ASSET_MANIFEST.md` provider amendment** (L-6).
   `DECISIONS/0030` promises it; it is unwritten.
4. **A decision on the `craft_memory` boundary violation** (L-3): fix on its own
   branch to master, get an owner carve-out, or proceed on local evidence and
   say so in the report. Not: weaken the guard.
5. **Commit the two new guards** (`check-art-palette.js`, `check-tile-seam.js`),
   `png.js`'s `loadAny`, the `verify.sh` wiring, and `DECISIONS/0030` — they are
   this workstream's preconditions and they are currently untracked.
6. **Consider a provenance schema for image rounds** (§3.1). The audio side
   already has one. A wave of hundreds of generations is where an informal
   convention stops working.
7. **Consider resolution tests for the families that lack them** (§5.7): enemies,
   locations, work stations, equipment overlays. Each missing one is the M-family
   defect waiting to happen again.

---

*End of FOUNDATION-L report.*
