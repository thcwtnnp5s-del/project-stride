# EPO03 — shared context for the Wave 1 directors and the Wave 2 producers

Branch `fable5-executive-production-overhaul-03`, from `59c4723`; workspace
commit `6a9a2d9`. Repo root: `C:\Users\jwspa\Downloads\ProjectStride_ClaudeCode_Handoff_COMPLETE\ProjectStride`.
Record: `MILESTONES/FABLE5_EXECUTIVE_PRODUCTION_OVERHAUL_03.md`. Ledger:
`GAME_BIBLE/ART/exploration/EPO03/GENERATION_LEDGER.md` (opened at **7,989**).
Guardian facts: `MILESTONES/evidence/EPO03/wave0/GOV-0[1-6]_*.md`. The previous
round's briefs are prior art, not scripture: `MILESTONES/evidence/FMPO02/wave1/`.

## 1. The owner's verdict on 59c4723 (physical iPhone)

**Better:** typography; Character; Inventory; gathering architecture; equipment
projection; encounter staging; Craft structure; some world regions; world life
more visible; UI more game-like than before.

**Not good enough:**

- **World / map** — inconsistent; visibly stitched in places; biome
  transitions vary in quality; some areas authored, others patched; fantasy
  landmarks not strong enough; world life not convincing; *some zones can and
  should be completely replaced; older terrain is not protected merely
  because it exists.*
- **UI** — too systematised; too many repeated dark cards; some surfaces
  feel "Claude generated"; Skills detail stacks rounded rectangles; Craft is
  improved but not premium; bottom nav plain; panels feel like styled app UI
  rather than authored RPG surfaces; hierarchy and material language can go
  much further.
- **Character / equipment** — must become fully convincing: no fallback to
  wrong clothing; no contradiction between equipped state and activity; more
  gear classes visibly meaningful.
- **World fantasy** — not enough spectacle; fairy presence too weak; dragons
  need more presence; the storm landmark needs stronger atmosphere; map life
  should feel inhabited, not decorated.
- **Audio** — still incomplete.

Acceptance target: *"This feels like a much more finished game."* Not "looks
a little cleaner".

## 2. Executive direction (the producer's own read of the atlas and the nine device screens)

### World atlas (1024², displayed at scale 6; the frozen core is (256..768)²)

The core master (Haven's Rest, the wheat, the delta marsh, Frostmere, the
Worldspine, the volcano) is the best painting on the map and stays as the
identity anchor. Around and inside it, the producer's zone verdicts — the
World Atlas Creative Director may overrule with reasons:

| Zone (atlas px) | Reference crop (`EPO03/src/atlas/ref/`) | Verdict | Why |
|---|---|---|---|
| South band 0–800 × 780–1024 | `zone_south_w_*`, `zone_south_e_*` | **FULL REPLACEMENT** | the pale strand at y 810–870 is a ruler-straight latitude stripe: the "layer cake" P0. It is held by two landmark goldens; the owner's directive authorises re-extracting them. Draw a *coast*, not a band: the delta's channels braid into tidal flats and a curved shore that runs diagonally, dune ridges at an angle, machair, creeks; the SW wood grades into it. |
| SW corner 0–260 × 760–1024 | `zone_sw_corner_*` | **FULL REPLACEMENT** with the south | lime sand slab, blue-blob flowers, a beach that meets a straight edge. |
| NE ice shelf 480–800 × 0–300 | `zone_ne_shelf_*` | **RECOMPOSE** the edge | the shelf meets the sea on a hard white diagonal. Author a calving front: bergs, brash ice, leads, a graded shelf edge; keep the pack-ice interior. |
| West road loop 0–260 × 460–630 | `zone_west_road_*` | **RECOMPOSE** | the caravan road S-bends across the meadow for no geographic reason; make it a pass road that reads — hugging a beck, a ford, a switchback into the Worldspine — while the caravan corridor stays where the atlas layout expects it. Four goldens overlap; re-extract in the same commit. |
| Far-west wall 0–70 × 540–780 | `zone_west_wall_*` | **RECOMPOSE** | a slab of grey with a pale column: make it the Worldspine's foothills — scree fans, a snow-line, a col. |
| Core forest west face 236–320 × 380–580 | `zone_core_forest_w_*` | **RECOMPOSE (core re-base)** | the canopy stops on a vertical wall at x≈256 (inside the A-4 rim — the reason FMPO02 could not fix it). Break it into bays and stepping copses that meet W1's edge. |
| Core canopy/snow treeline 256–400 × 230–290 | `zone_core_treeline_*` | **RECOMPOSE (core re-base)** | the snow meets the forest on a near-straight run; author altitude — pines thinning up into drifts. |
| East sea 770–1024 × 300–1024 | `zone_east_sea_*` | **KEEP terrain; POPULATE** | a quarter of the canvas is empty water. Do not add acreage. Add authored sea life and traffic (a ship on a route, a whale surfacing, gulls, a reef shoal) — world-life work, not terrain. |
| N1/N2/N3, W1/W2/W3, the volcano, Frostmere, the mountains | `grid_*` | **KEEP / RETOUCH** | accepted last round in the master's own hand; touch only where a transition to a replaced zone demands it. |

**No footprint expansion.** The map already carries 25% open sea; expansion
would add acreage, not a stronger world. Recomposition is the whole budget.

**Method is fixed:** `inpaint_image` over a wide crop (≤512²) of the *current*
composite with frozen margins, graded jittered mask by `tools/atlas-mask.js`,
dither-SELECT composite (A-2), the single-defect loop per region
(composite → guards → full atlas + ×2 perimeter + 197×426 phone FOV →
verdict), and no straight lattice line anywhere. Core re-base and golden
re-extraction go through the ADR the producer records (GOV-01) and the
insertion point GOV-03 names — protection stays in tooling.

### Hero landmarks (each must read as a *destination* at phone scale)

Current assets are tiny props on top of terrain: fairy castle 31×39, storm
house 25×21, ice tower 48×80, fairy motes 32×32 discs. Replace the approach:

- **Fairy Castle** — an in-terrain glade inpainted into the woods (≈96–128
  atlas px across): luminous woodland architecture grown from trees, a
  bridge, pools with crystal/flower light, fairy paths, warm windows. Fairies
  as 6–10 px winged silhouettes with warm light and a readable arc; gathering
  around the castle; occasional trails. No cyan squares, no glitter spam.
- **Storm House** — a dark cloud pocket painted into the terrain (local
  darkness ≈64–96 px), the house silhouette with lit windows, bent/scorched
  trees, rain sheets, lightning on a cadence with a flash on the ground.
- **Ice-Mage Tower** — rebuilt on a glacial foundation: crystalline ice
  architecture, drift integration, a frozen causeway approach, a beacon that
  sweeps, glacial terrain that changes around it.

### Dragons (hero world life)

Red fire dragon: ≥96 px wingspan, strong 8-frame wingbeat, a separate breath
loop with a large plume, a patrol path (waypoints) over the volcano so it
never disappears, recurring. Blue storm dragon: distinct serpentine
morphology, ≥112 px, visible charge, lightning breath, cloud association over
Frostmere and the cape. Silhouettes must not be shared. The overlay schema
grows a `path` (waypoints, speed, loop) in `atlas_layers.dart` — PROD-WORLD-
LIFE owns that Dart change.

### World life hierarchy

HERO (dragons, castle fairies, storm) · MID (caravans, boats, a ship on the
east route, whale, yeti, bears, wolves, deer herds, travellers on the roads)
· SUBTLE (birds, smoke, mist, ripples). Inhabited, not decorated: creatures
have a place and a behaviour, not a random scatter.

### UI — the page model replaces the card model

Every screen still reduces to dark ground → dark card → dark card → button.
Direction: each screen is a *page of a material* designed around its
content, with content sitting directly on the ground under rules, inset
frames, illustrated dividers and category rails — not nested dark cards.

- **Adventure** — field journal / expedition ledger: the stage full-bleed,
  the kit as a journal spread, goals as pinned slips.
- **Craft** — workshop: station rail, recipe table, ingredient tray, and the
  locked half as a *recipe book* — tiers as illustrated section headers with
  sealed/folded pages, never "1 more at Cooking 5" rows.
- **Skills** — overview stays (it works); the detail becomes a **vertical
  journey line**: milestone nodes with level badges, illustrated unlock
  nodes, regional icons, a lit "you are here", the rest of the road ahead.
- **Inventory** — equipment case / pack organisation: a real case with slot
  wells, the pack as pockets and rows on canvas/leather.
- **Character** — traveller folio / dressing space: the bust with the gear
  laid out around it, the ledger as ruled vellum.
- **Combat** — battlefield first: the stage dominates; gauges framed into
  the stage; a compact command rail (attack / brace / eat / retreat) that
  never outweighs the fight; narration on the stage.
- **Encounter** — field guide / habitat dossier plates.
- **World** — atlas first: the sheet collapses to a peek strip; the map is
  the hero; viewed vs selected location made unambiguous.
- **Bottom nav** — authored: material backing, icon wells, an active state
  that reads as a physical change (raised plate / lit lantern), a silhouette
  that relates to the top frame. Usable, not ornate.

### Equipment

Every existing armour, weapon and tool *item* gets its own silhouette (see
GOV-01's item list): base / light / bronze / heavy coat / special-masterwork
for armour; training / bronze sword / bronze longsword / special for weapons;
training / bronze / special for tools. Correct in Character, Inventory,
Adventure, Combat, Mining, Woodcutting, Foraging, Smithing, Cooking, Travel.
No shirt fallback, no wrong weapon, no generic tool. **No new items** — that
is a systems decision (G-3).

### Items, gathering, encounters, rewards, audio

Items: human-eye uniqueness at UI size across food, pots/broth/stews/rations,
tools, weapons, armour, ores, logs, herbs, drops, project items, masterworks.
Gathering: keep the working system; fix weak scenes (natural integration,
believable geology, living trees, regional identity, less staging).
Encounters: push the habitat plates — scale, framing, foreground, species
identity, atmosphere, boss presence. Rewards: presentation of the moment.
Audio: GOV-06 rules go/no-go; if no-go, record once and move on.

## 3. What every director returns

Write `MILESTONES/evidence/EPO03/wave1/DIR-NN_<name>.md`, ≤700 words, with
exactly these headings: **TOP FAILURES** (phone-visible, ranked) · **WHAT TO
REPLACE** · **WHAT TO KEEP** · **PRODUCTION FAMILY** (each asset or region:
name, canvas size, frames, count, PixelLab tool, reference/style source) ·
**PIXELLAB BUDGET** (cap, with the per-item unit cost from GOV-04's table) ·
**PHONE-SCALE SUCCESS CRITERIA** (what the iPhone must show, checkable).
Return to the producer ≤150 words: the top three failures and the budget.
No essays. No re-auditing of what this file already states.

## 4. Production rules for Wave 2 (binding)

1. **Hard cap** per team, named in its brief; stop at the cap and report.
2. **Ledger** `GAME_BIBLE/ART/exploration/EPO03/ledger/<FAMILY>.md`: one row
   per job — tool, job id, the tool's own cost line, verdict, reason. Never a
   balance delta (M-17).
3. **Download, sheet, Read, then accept.** Every accepted asset is fetched
   (`tools/fetch.js`), put on a contact sheet (`tools/sheet.js`) at the scale
   the phone shows it, and *looked at* before the verdict. A pixel-count or a
   metric is triage, not a verdict (M-04, M-14).
4. **Hosting**: commit sources under `EPO03/src/<family>/`, push, and use
   `https://raw.githubusercontent.com/thcwtnnp5s-del/project-stride/<commit-sha>/<path>`.
   Inline base64 truncates above ≈5 KB. PixelLab's own result URLs chain into
   other tools directly. Stage explicit paths only (G-8); never `git add -A`.
5. **Atlas**: regions are disjoint per team; each team writes its own
   `EPO03/out/atlas/manifest_<team>.json`; only the packager reads them. The
   single-defect loop is mandatory. Preview composites go to the team's own
   `review/atlas/` — `package-art.js` may be run, but on EBUSY wait and rerun;
   never edit `package-art.js` outside the block your brief names.
6. **Shared Dart files have one owner** (GOV-05's assignment). Others request
   changes in `MILESTONES/evidence/EPO03/wave2/REQUESTS_<owner>.md`.
7. **No save impact, no health impact, no new items, no systems changes.**
   Preserve every session command call site GOV-02 lists.
8. **Goldens are regenerated only after the diff of each screen is
   inspected** and the new render is judged at phone scale.
9. **Reject weak rolls.** A REJECT with a written reason is a valid, useful
   result; "REPLACE SECTION" is a valid QA verdict.
10. **Report** to `MILESTONES/evidence/EPO03/wave2/<TEAM>_report.md`: what
    shipped (paths), what was rejected and why, cost-line total, what the
    phone will show, what did not close. Return ≤200 words to the producer.
