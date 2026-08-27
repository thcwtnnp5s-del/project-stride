# PixelLab Asset Inventory

**Established:** 2026-08-27, by Fable V2 Experiment 01
(`MILESTONES/FABLE_V2_EXPERIMENT_01.md`), from a full sweep of
`GAME_BIBLE/ART/exploration/`, `Scripts/art/package-art.js` and the runtime
asset tables. **Purpose:** no good production art rots unused because nobody
audited it. Update this file whenever a round ships, adopts, or rejects
assets; the per-round READMEs and manifests stay the authority on verdicts —
this is the index across them.

Classifications: **A** currently used · **B** approved but unused ·
**C** usable with light packaging · **D** usable as ambient/presentation ·
**E** usable for gameplay/content · **F** duplicate/superseded ·
**G** failed/rejected · **H** boss/major content deferred · **I** unclear.

## 1. Shipped and referenced (A)

`assets/art/v1/` — **820 files**, all emitted by `package-art.js` from
tracked exploration sources and declared in `pubspec.yaml`; runtime
references live in `lib/ui/icons/*.dart`. Families: item icons (48²),
ambient Traveler+cat set, combat sets (Traveler, wolf, goblin, guardian,
lynx, boar, ram, salamander, bear, **scree crawler** since Fable V2),
env/atlas overlays, world atlas + markers, location vignettes (+ five
`alt_*` variants since Fable V2), node vignettes, work backdrops/props,
gather anim, portrait, sprite. Plus `assets/ui/v1/` (boot glyph, five skill
icons, chrome).

Packaged but deliberately never drawn (manifest `withheld`, the stage
respects it): `combat/wolf_hit_f0-3`, `combat/guardian_defeat_f0-6`.

## 2. Integrated by Fable V2 Experiment 01 (was B → now A)

All from `REGIONAL_CONTENT_PACK_01` (RCP01), whose packaging sources are now
**tracked** (`.gitignore` exceptions; this also fixed the latent
clean-checkout `--check` failure the untracked boar/ram/salamander/bear
sources had been causing since Exploration & Progression Loop 01):

| Asset | Source | New home |
|---|---|---|
| Scree Crawler idle (7f) + attack (9f), 48² | `out/enemies/crawler_*` (accepted; defeat withheld — "no collapse read") | `enemy.scree_crawler`, Stonefall's armoured fight; stage holds the hit pose on victory (guardian precedent) |
| Bronze Longsword icon | `out/gear/icon_bronze_longsword_48` (accepted) | `item.bronze_longsword` (Epic weapon, Smithing 6) |
| Bearhide Coat icon | `out/gear/icon_bearhide_coat_48` (accepted, "cloak" note) | `item.bearhide_coat` (Epic armor, Smithing 6) |
| Hornbound Bronze Axe icon | `out/gear/icon_hornbound_bronze_axe_48` (accepted) | `item.hornbound_bronze_axe` (Epic tier-2 tool) |
| Gloom Silk icon | `out/materials/icon_gloom_silk_48` (accepted) | `item.gloom_silk` (Rare, gathered at the Silkstrand Thicket) |
| Five vignette variants, 384×176 | `out/vignettes/vignette_*` (all accepted) | `location/alt_<id>.png` — the World inspector's destination preview and the DISCOVERED reward layer |

Derived (A-2 byte copies, no authoring): `node/deep_tin_seam.png` ←
tin seam plate, `node/oldgrowth_frostpine.png` ← frostpine plate,
`node/silkstrand_thicket.png` ← hollow thicket plate. **Distinct authored
node scenery for the three Verge nodes is a recorded future PixelLab
round.**

## 3. Viable but deliberately unused (B/C/D), with reasons

| Asset | Where | Why not yet | Recommendation |
|---|---|---|---|
| Fauna pack — butterfly/songbird/crow/ptarmigan/hare stills (16/24/32 px) + 5 loops, all accepted (`fauna_bat_16` withheld) | `RCP01/out/fauna/` | The ambient runtime has no "fauna beat" slot (RCP handoff §6.6); building one mid-sprint was scope | High-charm, low-cost follow-up: one fauna beat per location stage, absence the default |
| Ten atlas props — plank bridge, waystone, mine headframe, elder oak, alpine hut, ruined tower, hamlet cluster, ruin corner, cold camp, ore cart (accepted; charcoal clamp & deer group withheld) | `RCP01/out/world/` | Palette-conformed against the **retired** 384×688 base; Reviewer C mandated an in-place ×2 contrast check against the current 1024 composite — atlas-adjacent work this sprint froze by owner order | Revisit only when atlas work reopens; layout-placed layers, never atlas-image edits |
| Traveler walk cycle, 7 directions × 6f, 64² | `PIXELLAB_PROOF_02/out/animation/` | QA-passed with a backpack-flicker defect and no NW direction; needs frame QA + a use design (travel-in-progress feedback) | The best candidate for a travel-feel round: animate the journey along the route line |
| Traveler 8-direction stills | `PIXELLAB_PROOF_02/out/character/traveler_*` | No direction-aware staging exists | With the walk cycle, same round |
| Canvas Backpack icon 48² | `PIXELLAB_STABILIZATION_01/out/icons_full/` | No `item.canvas_backpack` exists; a capacity item contradicts the no-capacity stance (Q-UI-1) unless designed deliberately | Hold until a capacity/storage design exists, if ever |
| Full 512×384 location scenes | `PIXELLAB_STABILIZATION_01/out/location/*_vignette_512x384` | The shipped 384×176 crops serve; alternative framings had no consumer this sprint | Recrop candidates (A-2) if a larger presentation surface appears |
| WRD01 landmark cutouts ×4 | `WORLD_REWARD_DEPTH_01/world/out/world/landmark_*` | Host tiles retired; need re-conform + placement — atlas-adjacent, frozen | With the props, if atlas work reopens |

## 4. Deferred as major content (H)

- **Hollow Weaver** — idle accepted, both attacks and defeat withheld after
  two rounds. Cannot fight without an attack that reads. Its silk role went
  to the Silkstrand Thicket (gathered) instead; the creature waits for a
  successful animation round.
- **Great Elk of the Tarn** — concept only, no art. Boss-tier Frostmere idea
  in RCP01 `CONTENT_PROPOSALS.md` §1.
- **Tavern interior** — right register, MAJOR lighting defect, and no tavern
  canon exists (`PIXELLAB_PROOF_03`). A rest/inn design question first.

## 5. Superseded / failed (F/G) — do not integrate

**F:** T01 world base tile + 5 landmark cutouts; WRD01 east/south/southeast
atlas tiles + 7 withheld strip props; AF01/PWRF alternate atlas masters;
WMP03 strip_east/corner_ne/corner_se; AF01 mine2 loop; PE01
traveler_combat_idle (replaced by PP02); PWRF 64×48 stations; RCP
reinforced-pickaxe icon (item superseded by shipped `reinforced_pickaxe`).

**G:** Adit Bat (identity failed — gargoyle/owl read); granite chitin icon
(withheld after four rounds — its material was struck with it); ram_hit,
bear_attack r1, crawler_defeat, weaver attacks/defeat, lynx prowl;
PROOF_02 picking-up gather and env tilesets; WMP01 v1 creatures + fire v1;
AF01 wave loop; the aurora and flying-dragon rejects; prop_deer_group and
prop_charcoal_clamp (L-17 implied-interaction rule); `fauna_bat_16`;
everything under any `rejected/`.

**I:** `second_*` character rotation+portrait (style transfer PASSED, the
asset FAILED — the proven `create_character` + `style_character_id` recipe
is the real asset for a future NPC cast); `fx_reward_burst` (never
packaged; the reward grammar deliberately has no burst).

## 6. Out of scope

`WALKSCAPE_*`, `PORTRAIT_SYSTEM_03`, `CHARACTER_REBUILD_01/02`,
`FAR_ARM_FEASIBILITY_01`, `DIRECTION_A_ROUND_01`, `HAVENS_REST_*`,
`CODE_RENDER_01`, `TRAVELER_REFINE_03` — code-rendered exploration
(not PixelLab), and the character workstream is PAUSED, NOT APPROVED
(`CHARACTER_PORTRAIT_CLOSEOUT.md`).
