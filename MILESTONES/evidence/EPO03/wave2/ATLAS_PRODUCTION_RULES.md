# EPO03 — atlas production rules (binding for PROD-WORLD-NORTH / SOUTH / WEST / EAST / LANDMARKS)

Authority: the owner's EPO03 directive · `DECISIONS/0033` · `RULES.md` A-2, A-3,
A-4, G-4, G-8 · `STUDIO_OPERATIONS/WORKFLOW.md` "World-atlas repairs" ·
`MISTAKES.md` M-12, M-14, M-15, M-17. Mechanics: `MILESTONES/evidence/EPO03/wave0/GOV-03_atlas_guardian.md`.
Direction: `wave1/DIR-01_world_atlas.md` (territories, verdicts),
`wave1/DIR-02_regional_environment.md` (style lock, transition prompts),
`wave1/DIR-03_fantasy_landmarks.md`, `wave1/DIR-04_world_life.md`.

Repo root `C:\Users\jwspa\Downloads\ProjectStride_ClaudeCode_Handoff_COMPLETE\ProjectStride`;
round dir `GAME_BIBLE/ART/exploration/EPO03/` (call it `E/`). All commands run
from the repo root.

## 1. What a team owns

- **A territory** — the disjoint atlas rect DIR-01 assigned. Nothing outside it
  is painted by this team. A shared edge belongs to the team DIR-01 names.
- **Its regions file** `E/src/atlas/regions_<team>.json` (pending work, never
  a manifest) and **its manifest** `E/out/atlas/manifest_<team>.json`
  (accepted regions only; it already exists with `"regions": []`).
- **Its ledger** `E/ledger/WORLD_<TEAM>.md` — one row per job: tool, job id,
  the tool's own cost line, verdict, reason. Never a balance delta (M-17).
- **Its review dir** `E/review/atlas/` (shared dir, file names prefixed by
  region id — ids are unique per team: `N1…`, `S1…`, `W1…`, `E1…`, `L1…`).
- **Its cap.** Stop at the cap and report. A REJECT with a reason is output.

Teams do not edit `Scripts/art/package-art.js`, `atlas_layout.json`,
`landmark_registry.json` rects (except as §5 says), or another team's files.

## 2. Region spec (in `regions_<team>.json`)

```json
{ "id": "S1", "x": 0, "y": 700, "w": 512, "h": 324,
  "rect": { "x0": 24, "y0": 40, "x1": 488, "y1": 324 },
  "ramps": { "left": 24, "right": 32, "top": 32, "bottom": 0 },
  "inpaint": { "x": 24, "y": 40, "w": 464, "h": 284 },
  "salt": 41, "seed": 0, "status": "pending",
  "coreAuthor": true, "reauthorizes": ["south_strand_w"],
  "intent": "one sentence: what the terrain becomes and which transition it authors" }
```

- `x,y,w,h`: crop origin and size on the 1024² atlas; the crop, the
  generation and the mask are exactly `w×h`; `w,h ≤ 512`.
- `rect`: the authored rect in **crop** coords, half-open; a coordinate
  outside `[0,w)`/`[0,h)` means "canvas edge, no ramp". **The rect edge equals
  the inpaint rect edge** — the boundary contour then always lies inside
  authored terrain, never on the inpaint cut.
- `ramps`: 24 px on a free edge, 32 px where the boundary crosses a texture
  change (canopy/meadow, snow/rock, sand/sward). A one-sided ramp, width
  jittered ±60 % by the tool — never straight.
- `salt`: **≥ 40 and unique across all five teams.** Allocation: NORTH 40–59,
  SOUTH 60–79, WEST 80–99, EAST 100–119, LANDMARKS 120–139.
- `coreAuthor: true` whenever the rect reaches inside (256..768)² or its rim
  (D0033). `reauthorizes`: every landmark golden the mask will touch; each is
  re-extracted in the same commit (§5). The packager throws on an undeclared
  touch.
- Frozen margins: the crop carries **≥ 40 px of untouched terrain** on every
  side that is not a canvas edge, so PixelLab re-seats the painting against
  real neighbours.

## 3. The loop — one region at a time, no batching

```bash
# 0. BEFORE evidence (once per region)
node E/tools/atlas-review.js S1 before south

# 1. Cut and publish the crop (needs a push — PixelLab reads by commit SHA)
node E/tools/crop.js assets/art/v1/world/atlas_base.png 0 700 512 324 E/src/atlas/S1_crop.png
git add E/src/atlas/S1_crop.png E/src/atlas/regions_south.json && git commit -q -m "EPO03 south: publish the S1 crop" && git push -q
#    URL: https://raw.githubusercontent.com/thcwtnnp5s-del/project-stride/<sha>/GAME_BIBLE/ART/exploration/EPO03/src/atlas/S1_crop.png

# 2. Generate — inpaint_image(image_url=<crop url>, mask_x/y/width/height = the inpaint rect,
#    description = the DIR-02 prompt template for this transition, in the style lock; seed recorded)
#    Cost by crop size: ≤192×128 → 20, ~200–300 sides → 25, ≥348×346 → 40.

# 3. Fetch, then LOOK (contact sheet at x2) before anything else
node E/tools/fetch.js <result url> E/raw/atlas/S1_r1.png
node E/tools/sheet.js E/review/atlas/S1_r1_x2.png 2 1 "#000000" E/raw/atlas/S1_r1.png   # then Read it

# 4. Accept the roll as the candidate, build the graded mask, verify containment
cp E/raw/atlas/S1_r1.png E/out/atlas/S1.png
node E/tools/atlas-mask.js S1 south
node E/tools/atlas-verify.js S1 E/out/atlas/S1.png south      # changed-outside-mask should be ~0

# 5. Preview WITHOUT touching assets/ (safe in parallel with other teams)
node E/tools/compose-preview.js S1 south
#    Read: E/review/atlas/S1_preview_full.png, S1_preview_x2.png, S1_preview_fov_x2.png
#    Judge all four continuities at every boundary: biome, coastline/waterline,
#    detail-scale (drawing hand), palette. Any straight lattice line, patch
#    rectangle, dither column, treeline wall, snow cut-line, surf/shore mismatch,
#    density shift, layer-cake band, slab, dead zone, strange road bend, river
#    that does not read, landmark sitting ON terrain, or style mismatch = REJECT
#    or RE-ROLL. Write the verdict in the ledger BEFORE the next step.

# 6. ACCEPT → move the entry to the manifest (status "accepted", job, seed) and
#    build the real composite. package-art.js runs are SERIALIZED across teams:
#    take the lock, build, check, release.
node E/tools/atlas-lock.js acquire south      # waits if another team holds it
node Scripts/art/package-art.js && node Scripts/art/package-art.js --check
node E/tools/atlas-qa.js S1 south             # repeated sprite pairs 0; orphan flecks near 0
node E/tools/atlas-review.js S1 after south   # the AFTER evidence from the SHIPPED composite
node E/tools/atlas-lock.js release south

# 7. Commit explicitly (G-8): the region PNG + mask, the manifest, the regions
#    file, the review renders, the ledger, assets/art/v1/world/atlas_base.png,
#    and any re-extracted golden (§5). Push.
```

Rules inside the loop:

- **One region open at a time per team.** The next region's crop is cut from
  the composite the previous region shipped into, so bridges see both sides.
- **Two failed rolls on the same intent → stop and change the intent**
  (crop, prompt, rect), not the seed. Three → REPLACE SECTION or escalate to
  the producer with the sheets.
- **Never re-touch a region to fix its neighbour.** Author a bridge region
  (a crop centred on the join, both sides frozen ≥ 48 px) as its own entry.
- **Never widen the guard, the rim, or a keepout to make a mask pass** (G-4).
  If the tool blocks a pixel you need, the region is declared wrongly
  (`coreAuthor`, `reauthorizes`) — fix the declaration, which is the recorded
  authorization, not the tool.

## 4. The build lock

`E/tools/atlas-lock.js acquire <team>` creates `E/.atlas.lock` with the team
name and time, polling every 2 s up to 5 minutes; `release <team>` removes
it (only the holder may release; a lock older than 10 minutes is stale and
may be broken with `break`). Only `package-art.js` builds and golden
re-extraction need the lock. `compose-preview.js` never does.

## 5. Re-authoring a landmark golden (D0033)

Declare the golden in `reauthorizes`. After ACCEPT, under the lock:

```bash
ATLAS_DUMP=E/raw/atlas/S1_pre_guard.png node Scripts/art/package-art.js   # throws on the golden — expected
node E/tools/extract-golden.js E/raw/atlas/S1_pre_guard.png south_strand_w
node Scripts/art/package-art.js && node Scripts/art/package-art.js --check   # green
```

Stage the golden(s) under
`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/goldens/` in the same
commit. A registry rect may be **edited** (moved or resized to follow the
re-authored feature) before extraction — never emptied or deleted; say so in
the ledger. `Sunward Strand` (atlas 511,860) must still have a beach under
its marker.

## 6. Identity anchors — verify after every composite

Every `locations`, `landmarks`, `routes` and `props` coordinate in
`assets/content/v1/atlas/atlas_layout.json` (world px ÷ 6 = atlas px; the
gazetteer is in GOV-03 §3) stays where it is and the biome under it still
matches its name. Millbridge and Ferry Crossing keep water; the road routes
keep road under them where they cross your territory (a route through a
replaced region must be *painted* into the generation — say so in the
prompt: "a dirt road enters at (…) and leaves at (…)").

## 7. Acceptance bar (what QA-ATLAS / QA-SEAMS will check)

At 197×426 phone FOV ×2, blind: one painting, one hand; the transition
reads as geography (the DIR-02 criteria for that transition type); no
generated rectangle; no straight line longer than ~12 px that is not a
road, wall or field edge; no dither column; no orphan flecks; no repeated
sprite pairs; the identity anchors in place; guards green; `--check` green;
the ledger reconciles to cost lines. **"REPLACE SECTION" is a valid verdict**
— it sends the region back to step 0 with a new intent.

## 8. Reporting

`MILESTONES/evidence/EPO03/wave2/WORLD_<TEAM>_report.md`: per region —
BEFORE problem, intent, job/seed/cost, verdict and why, evidence paths;
territory total cost (sum of cost lines), accepted / rejected counts; what
the phone will show; what did not close, named. Return ≤200 words to the
producer.
