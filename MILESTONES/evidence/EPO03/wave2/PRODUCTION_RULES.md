# EPO03 — production rules for every Wave 2 team (binding)

Repo root `C:\Users\jwspa\Downloads\ProjectStride_ClaudeCode_Handoff_COMPLETE\ProjectStride`,
branch `fable5-executive-production-overhaul-03`. Round dir
`GAME_BIBLE/ART/exploration/EPO03/` ("`E/`"). Toolchain for any `flutter`/`dart`
command, every time (nothing is on PATH):

```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"; export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
```

Read before starting: `MILESTONES/evidence/EPO03/wave1/BRIEF_CONTEXT.md` (§1
verdict, §4 rules), `wave0/GOV-04_pipeline_cheatsheet.md` (tool costs, hosting,
packaging, guards), `wave0/GOV-02_save_health_boundary.md` if present (the
do-not-touch list and the session call sites), your director's brief, and the
FMPO02 report + ledger for your family (`MILESTONES/evidence/FMPO02/wave2/`,
`GAME_BIBLE/ART/exploration/FMPO02/ledger/`). World teams also read
`wave2/ATLAS_PRODUCTION_RULES.md`. You are a producer: generate, review,
integrate, prove. Recommendations alone are a failed deliverable.

## 1. Cap and ledger

- Your **cap** is in your brief. Stop at the cap and report. Rejected rolls
  with written reasons are output, not waste.
- **Ledger** `E/ledger/<FAMILY>.md`: one row per job — what was asked, tool,
  job id, the tool's own cost line (`cost: ~20 generations`), verdict
  (ACCEPT / REJECT / RE-ROLL / REPLACE SECTION), reason. Family total = the
  sum of cost lines. **Never a balance delta** (M-17); do not call
  `get_balance` to measure your family — the producer takes checkpoints.
- Cheapest correct tool first: `create_image_pixen` = 1, `edit_image_pixen`
  = 1, `animate_image` = 1–2, `create_image_pro` / `edit_image` / `inpaint_image`
  = 20–40, `create_character_state` ≈ 44, `create_map_object` ≈ 32.

## 2. Look before you accept

Every candidate is **downloaded** (`node E/tools/fetch.js <url> <file>`), put
on a **contact sheet** at the scale the phone shows it (`node E/tools/sheet.js
<out.png> <scale> <cols> "#1e1e1e" <files…>`), and **Read** (the image, with
your eyes) before a verdict. A metric, a pixel count, a seam distance or a
"looks plausible at x1" is triage, never a verdict (M-04, M-05, M-14).
Candidate dumps go to `E/raw/<family>/` (local, untracked); accepted assets
to `E/out/<family>/`; sheets and renders to `E/review/<family>/`; rejected
rolls with a one-line verdict file to `E/rejected/<family>/`.

## 3. Hosting

Inline base64 truncates above ≈5 KB. Commit sources under `E/src/<family>/`,
push, and reference
`https://raw.githubusercontent.com/thcwtnnp5s-del/project-stride/<commit-sha>/<path>`
(the SHA form propagates immediately; the branch form can 404). PixelLab's
own result URLs chain into `image_url` / `first_frame_url` /
`reference_image_url` directly.

## 4. Git discipline (several agents share this working tree)

- Stage and commit **only your paths, in one command**:
  `git add <paths> && git commit -q -m "EPO03 <family>: <what>" -- <paths>`.
  Never `git add -A`, `git add .`, `git commit -a`, `git stash`, `git reset`,
  `git checkout -- <file>` on a file you do not own, or any rebase.
- Push whenever you need a URL: `git push -q`. If push is rejected, re-run
  `git push -q` once; if it fails again, stop and say so in your report.
- Commit often and coherently (one family, one intent per commit). Do not
  wait for the end.

## 5. Ownership — files you may edit

Your brief names your files. Shared kit files (`lib/ui/components/panel_skin.dart`,
`surfaces.dart`, `band_plate.dart`, `screen_header.dart`, `bottom_sheet.dart`,
`stride_tab_bar.dart`, `lib/ui/shell/*`, `lib/ui/theme/*`, `pixel_asset.dart`,
`data_display.dart`, `rules.dart`, `adaptive_text.dart`, `pubspec.yaml`,
`assets/ui/v1/README.md`, `Scripts/art/check-art-palette.js`) belong to
**PROD-UI-NAV (the kit owner)**. Anyone else writes the request to
`MILESTONES/evidence/EPO03/wave2/REQUESTS_NAV.md` (append a dated block:
what, why, the exact rows/lines) and continues with what does not depend on
it. `Scripts/art/package-art.js`: edit **only inside your family's block**,
with a comment header naming EPO03 and your team; on `EBUSY` wait 5 s and
retry. `assets/content/v1/atlas/atlas_layout.json`: PROD-WORLD-LIFE owns
`overlays`; PROD-WORLD-LANDMARKS owns `props` and `landmarks`; nobody else.
`lib/ui/icons/traveler_art.dart` and `test/equipment_projection_test.dart`:
PROD-EQUIPMENT. `activity_result.dart`, `reward_beat.dart`,
`reward_layer.dart`, `rarity_*`: PROD-REWARDS. `encounter_card.dart`,
`bestiary_screen.dart`: PROD-ENEMIES. `combat_screen.dart`,
`combat_stage.dart`, `combat_choreography.dart`: PROD-UI-COMBAT.
`adventure_screen.dart` lines 124–136 (the branch that hosts combat): frozen.

## 6. Builds and the lock

`node Scripts/art/package-art.js` writes 1,779 files; two concurrent builds
corrupt each other's reads. **Before any build, take the lock; release after
`--check`:**

```bash
node E/tools/atlas-lock.js acquire <team>
node Scripts/art/package-art.js && node Scripts/art/package-art.js --check
node E/tools/atlas-lock.js release <team>
```

`node Scripts/art/check-art-palette.js` and `check-tile-seam.js` run
without the lock. A guard that fails is evidence about the asset, never a
reason to edit the guard (G-4).

## 7. Proof at phone scale

- Screens: `SCREEN_EVIDENCE_DIR=<abs dir> flutter test test/screen_evidence_test.dart`
  renders 393×852 @ DPR 1 (iPhone 15 Pro logical). Read the PNGs. Golden
  files (`test/goldens/`) are regenerated **only by the producer** at
  integration; do not run `--update-goldens`. Your proof is the evidence
  render, judged, saved under `E/review/device/<family>/`.
- Stages: `STAGE_EVIDENCE_DIR`, `COMBAT_EVIDENCE_DIR`, `BOARD_EVIDENCE_DIR`
  harnesses (see GOV-04 §5).
- Every accepted asset that reaches the app is shown in at least one such
  render before your report says "shipped".

## 8. Tests

Run the focused tests for what you touched (`flutter test test/<file>`), then
`flutter analyze` on your files. Do not weaken an assertion; a failing guard
is evidence about the code (G-4). Do not add verification frameworks (G-1).
Goldens that legitimately change because a screen was rebuilt: note the
test file in your report; the producer regenerates after inspection.

## 9. Locks you must not cross

No save or health change; no new items, recipes, nodes, enemies or systems
(G-3 — write it to `JOURNAL/OPEN_QUESTIONS.md` as the next free Q- number
and move on); no economy or step-cost change; no FOMO, streaks, decay,
monetization; no background Health; no reserved teal outside step figures;
the L* ceiling on chrome; every session command call site preserved.

## 2a. Chrome art: what the tool can and cannot do (measured, 2026-09-02)

The kit owner spent 32 rolls on flat tileable interface chrome and shipped
one. Do not re-learn this at your own cap’s expense.

**`create_image_pixen` reliably fails on flat chrome at 32–128 px.** Its four
failure modes are tool limits, not prompt faults, and a re-roll does not fix
any of them:

- it draws the piece in **perspective** — a foreshortened box whose four
  sides differ, so no nine-patch can be cut from it;
- it puts a **screw head or bolt at each corner** (the stud register the
  material brief forbids by name);
- asked for a **well**, it draws an object sitting inside the well; a well is
  empty by definition;
- asked for a **sheet to cut tiles from**, it returns the tiles rotated a few
  degrees off axis, so no axis-aligned window contains one.

Reject those and change strategy — do not spend a second roll on them.

**Brightness over the L\* ceiling is NOT a rejection.** If the drawing is
right and only the palette is too light, it is a **deterministic tone remap**,
permitted by `RULES.md` A-2 and with precedent in this repo at commit
`49c91f9` ("bronze is not gold"). Remap it down and ship it. Marking such a
roll REJECT throws away a good asset and spends the cap again on its
replacement.

**A painted-white face is a key, not a rejection.** Asked for a frame, the
model often returns the same frame with its centre filled solid, and it
measures as "solid plate, not a frame". Key everything above L 0.5 to
alpha 0 and the frame is there underneath. This turned six rejects into
shipped frames for zero generations on 2026-09-02. Together with the tone
remap above, the two recoveries account for ten of the kit’s thirteen
landed assets — **measure before you reject, and try the cheap recovery
before you spend the cap again.**
**For flat, hollow or nine-patchable chrome, `create_image_pro` is the
default — not the expensive fallback.** Measured on 2026-09-02: the three
frame families that 32 pixen rolls refused (`inset_well`, `slot_well`,
`stage_frame`) were each accepted on the **first pro call**, 60 generations
for all three, returning 36 candidates. Pass an accepted grain
(`assets/ui/v1/surface/grain_*.png`) as the labelled style reference,
generate larger, downscale. Keep pixen for small opaque marks, where it
already succeeds at cost 1.

**Set a nine-patch band from what the painter does, not from the measured
rim.** `stage_frame`’s iron corner cap is 26 px against a band of 19, and at
19 the painter tiles the cap along every beam. No measurement shows this;
render the patch as the painter will (`ninepatch-proof.js`) and look at it.

**A new held item on an existing frame costs 1 generation, not 44.**
Measured by PROD-EQUIPMENT on 2026-09-02: `edit_image_pixen` on an already
shipped frame, fed back as a `custom_start_frame_url`, puts a different tool
or weapon in the figure’s hand for **one** generation — against ≈44 for a
fresh `create_character_state`. The whole hornpoint-pick column across five
bodies was produced this way. Before costing any variant of something that
already ships, ask whether it is an edit of a shipped frame rather than a
new authoring job; FMPO02 cut a whole tool column as unaffordable on a unit
cost that was wrong by more than an order of magnitude (M-17).
**Build the Dart structure first.** Every screen’s page model is mostly
layout on materials that already ship. A screen rebuilt on existing grains
and painted rules is transformed even if none of its new marks ever land;
a screen waiting on art is not transformed at all.

## 9a. Batching, and surviving an interruption

Nineteen concurrent producers exhausted the session usage limit twice on
2026-09-02, killing every team mid-flight. The round therefore runs **four
teams at a time**, and every team works as if it will be cut off without
warning:

- **Commit after every accepted item**, not at the end. An uncommitted
  candidate is lost work; a committed one is the next session’s starting
  point.
- **A submitted PixelLab job survives the interruption.** Its result stays
  retrievable by `get_image(job_id)`, so record every job id in the ledger
  the moment you submit it — the id is what makes a generation recoverable
  rather than repeated, and re-rolling a lost job spends the cap twice.
- **Re-read your ledger and `git log -5` on resume** before doing anything
  else: another team, or the producer, may have landed work in your area
  while you were stopped, and the atlas may have been rebuilt under you, so
  re-cut any crop from the current composite.
- **Never end a turn to wait** for a job or a neighbouring team; poll.

## 10. Report

`MILESTONES/evidence/EPO03/wave2/<TEAM>_report.md`: what shipped (asset
paths, Dart files, tests), what was rejected and why (with sheet paths),
cost-line total (requested / accepted / rejected), what the phone will show
that it could not before, what did not close (named, not softened), any
REQUESTS you filed, any Q- you raised. Return ≤200 words to the producer
with the same headings. Then stop.
