# World & Reward Depth 01 — milestone contract and record

**Opened:** 2026-08-19 · **Branch:** `playable-phase-2-multiregion` ·
**Starting HEAD:** `e962420` (Playable Expansion 01, device-validated: install
in place, health path, save, equip, combat, victory reward once, driven-off).
**Owner direction:** the "World & Reward Depth Pass" master prompt.
**Status:** implementation complete, awaiting the owner's physical-device test (§16). Results §13–§17.

## 1. Objective

Make the next iPhone build substantially richer as an RPG, in five
directions, without touching the proven health / economy / install paths:

1. **World / atlas depth** — a larger continuous atlas with real geography,
   embedded labels, visible routes, a route preview, a location inspector
   that exposes real gathering and combat, and a stronger travel moment.
2. **Repeatable combat** — `DECISIONS/0021`: authored encounters per visit,
   reset by travel, rewards exactly once; one new regional enemy where a
   region had none.
3. **Loot rarity and reward presentation** — one canonical `Rarity`, every
   item authored, one UI style, a victory panel that feels like winning.
4. **Ambient animation continuity** — the stage must not commonly end on a
   frozen pose; a tasteful idle cadence; the reading book corrected.
5. **Device-scale visual corrections** — judged at ×2 on a phone.

Not in scope (prompt §47): dungeons, merchants, gold, quests, NPC dialogue,
multiplayer, procedural gear, wall-clock anything, background HealthKit,
free-roam movement, a sixth skill, audio sourcing.

## 2. Frozen (P0) — must not change

`packages/stride_core/lib/src/steps/`, `packages/stride_health/`, the
session's sync section, `DECISIONS/0016/0018/0019`, single-writer
persistence, atomic commits, `Scripts/ios/` install defaults (`devicectl`
in place; `flutter install` only behind `--wipe-reinstall WIPE`). The only
change near them is one `StateMigrations` row (v4→v5, `rebasesEconomy:
false`).

## 3. Bootstrap findings that shape the work

- The 0020 driven-off rule is *already* "cleared by any move". What the
  owner felt is one fight per enemy per visit → `DECISIONS/0021` adds an
  authored per-visit count (normal enemies 2, boss 1) and a Frostmere enemy.
- `AmbientPlayer.scenesPerVisit = 4` → `_Phase.spent` holds the rest frame
  until the app resumes or a gather ends. That *is* the device "freeze" —
  intentional settling, now contrary to product intent (prompt §15–16).
- `traveler_read` frames carry a book wider than the Traveler's head at
  64 px — a frame problem → PixelLab, not code.
- `create_image_pro` caps at 384×688 portrait; `inpaint_image` cannot
  outpaint at ≥384×512 on this tier. The atlas grows by **tiles** (the
  layout already supports a tile grid) with seams hidden by authored
  geography (ridges, treelines, hedgerows, rivers) and seam-cover props.
- The content loader rejects unknown fields (`unknown_field.json` fixture),
  so `rarity` / `encountersPerVisit` land in the schema before the JSON.
- `AtlasLayout` is world-pixel based with explicit scale; routes are
  polylines; overlays are one ticker. Keep that model; extend, don't replace.

## 4. Workstreams, ownership, merge order

| Stream | Owner (agent) | Files owned | Depends on |
|---|---|---|---|
| A lead | this session | docs, integration, `pubspec.yaml`, `atlas_layout.json` final, goldens, packaging | — |
| B combat/rarity domain | Technical (worktree) | `packages/stride_core/**`, `assets/content/v1/*.json` (not `atlas/`), `lib/runtime/stride_session.dart`, session tests, `lib/ui/screens/adventure/encounter_card.dart`, minimal compile fixes elsewhere | — |
| C reward / inventory presentation | UI | `lib/ui/theme/rarity_style.dart` (new), `lib/ui/components/rarity_*.dart` (new), `lib/ui/screens/combat/combat_screen.dart`, `inventory_screen.dart`, `craft_screen.dart`, `character_screen.dart` (equipped rarity only), their tests | B merged |
| D atlas architecture / inspector | UI | `lib/runtime/atlas_layout.dart`, `lib/ui/screens/world/**`, `lib/ui/icons/atlas_assets.dart`, `assets/content/v1/atlas/atlas_layout.json` (schema + geometry for existing tile; lead merges E's coordinates), `test/atlas*` | B's `placeDetailsFor` (interface fixed in §6; compile after merge) |
| E PixelLab world art director | art | `GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/world/**` only | art brief §8 |
| F ambient runtime | UI | `lib/ui/components/ambient_player.dart`, `ambient_scene.dart` (additive), `lib/ui/icons/ambient_assets.dart` (cadence table entries), `test/ambient*` | — |
| G PixelLab ambient + combat corrections | art | `GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/{ambient,combat}/**` only | — |
| H device visual QA | Visual QA | read-only, writes its verdict under `.../WORLD_REWARD_DEPTH_01/qa/` | after integration |
| I QA regression | QA Director | focused tests only | after integration |

Merge order: B → (C, D, F in the main tree, file-disjoint) → art packaging
(E, G) → lead integration → H/I → strict verify → commit with explicit paths.

## 5. Combat and content (B) — the contract

- `enemies.json`: `encountersPerVisit` (≥ 1, default 1): wolf 2, goblin 2,
  guardian 1 (boss), **Frost Lynx 2**.
- New enemy `enemy.frost_lynx` at `location.frostmere` — the one region
  with no combat: health 30, attack 9, defence 2, `flurry`, xp 80, drops
  `item.rime_blossom` ×1 @50 %, `item.lynx_pelt` ×1 @35 %. Needs bronze.
  (Provisional test balance, like everything in COMBAT/02.)
- Wolf drops gain `item.wolf_pelt` ×1 @45 % (herb @60 % kept).
- New materials (2): `item.wolf_pelt` (tier 0, **common**), `item.lynx_pelt`
  "Frost Lynx Pelt" (tier 1, **rare**). New recipes (2, smithing — the
  production skill that exists): `recipe.wolfhide_jerkin` L2 = 3 wolf_pelt +
  1 oak_handle → `item.wolfhide_jerkin` (armor, power 4, **rare**, xp 60);
  `recipe.frostlined_jerkin` L4 = 1 wolfhide_jerkin + 2 lynx_pelt →
  `item.frostlined_jerkin` "Frost-lined Jerkin" (armor, power 6, **epic**,
  xp 120). Nothing else. No gold, merchants, vendor trash.
- `WorldState.visitVictories`, state **v5**, migration, `v5_baseline.save`,
  v1–v4 fixtures untouched (`DECISIONS/0021`).
- `Rarity` enum in core; `ItemDefinition.rarity` required in JSON.
- `LocationKind` derived (`haven` · `perilous` · `worksite` · `wilds`).
- Q-06 stays open: encounters start at full HP (unchanged).

### Rarity table (authored; rationale: tier of effort to obtain)

| Rarity | Colour | Items |
|---|---|---|
| Uncommon | gray | oak_log, copper_ore, tin_ore, meadow_herb, duskcap (tier-0 gathered) |
| Common | green | pine_log, rime_blossom, hollow_root, oak_handle, bronze_ingot, pine_plank, training_sword/axe/pickaxe, traveler_tunic, herb_broth, duskcap_skewer, wolf_pelt |
| Rare | blue | bronze_sword, bronze_axe, bronze_pickaxe, bronze_chestplate, hearty_stew, frostbloom_tea, lynx_pelt, wolfhide_jerkin |
| Epic | purple | hollow_sigil, frostlined_jerkin |
| Legendary | orange | *none yet — reserved; the enum, style and tests cover it* |

**Note for the owner:** the prompt lists Uncommon (gray) *below* Common
(green). Implemented exactly as written. ✅ **Owner-resolved, 2026-08-19:
intentional and canonical** — recorded in `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`
and closed in `JOURNAL/OPEN_QUESTIONS.md` Q-07 (that bullet only; the other
Q-07 items stay open for the device review).

## 6. Session projections (B provides, C and D consume)

```dart
// stride_core
enum Rarity { uncommon, common, rare, epic, legendary }   // .label, .rank, .wireName
enum LocationKind { haven, wilds, worksite, perilous }

// stride_session.dart (additions)
InventoryEntry.rarity        : Rarity
RecipeOption.outputRarity    : Rarity      (+ outputItemId if absent)
EncounterOption.drops        : List<DropPreview{ItemId id, String name, Rarity rarity}>  (replaces dropNames)
EncounterOption.remainingThisVisit, .encountersPerVisit : int
WonBeat.drops                : List<RewardLine{ContentId id, String name, int quantity, Rarity rarity}>
RegionPlace.kind             : LocationKind
PlaceDetails placeDetailsFor(ContentId location):
  kind, isSafe, terrain,
  gatherSites: List<GatherSiteLine{ContentId id, String name, String skillName, int requiredLevel, String? toolWord}>,
  encounters : List<PlaceEncounterLine{ContentId enemyId, String name, bool isBoss, EnemyBehavior behavior,
                                       int encountersPerVisit, int remainingThisVisit /* = perVisit when not current */}>
EquippedSummary lines carry rarity (for Character / Inventory).
```

## 7. Atlas architecture (D) — the contract

- `atlas_layout.json` **schemaVersion 2**: keeps `world`, `scale`, `base.tiles`
  (grid), `locations`, `routes`, `props`, `overlays`; adds
  `landmarks: [{id, name, x, y, tier: "minor"|"future", marker?: {asset,w,h,anchorX,anchorY}}]`
  — named, non-interactive geography (a ruin, a ferry, a far town). Minor
  labels, no hit target, no panel: "clearly non-interactive" (prompt §9).
- Markers get a **kind glyph** (PixelLab, from E: `world/marker_<kind>` —
  haven · wilds · worksite · perilous · landmark) drawn under the ring; the
  ring chrome stays as the fallback until art lands.
- Labels: two tiers (place / landmark), embedded plates as today but smaller
  for landmarks; legible at every zoom; no overlap test extended.
- **Route preview**: current → selected via `AtlasScene.wayTo`; the edges on
  that path are highlighted (heavier dots), the rest muted; the inspector
  shows the hop list and the **total** step cost (sum of the edges) and the
  first-leg cost the Travel button charges. Steps are a price, never dots.
- **Inspector** (replaces `AtlasSelectionPanel` content): name · kind word ·
  terrain · here/reached/unreached · safe; *Gathering* rows (node, skill,
  level, tool); *Encounters* rows (enemy, boss badge, "2 of 2 this visit" when
  current, "returns after you travel" when spent); route/hops line; step cost;
  Travel button (engine refusal order unchanged). Only real systems.
- **Travel feedback**: camera recentres to the destination (exists) plus a
  short one-shot arrival pulse burst and the panel's arrival line — no avatar
  walking, no real-time traversal.
- Zoom range widened for the larger world (min so ~half the world width fits;
  max 2×), pixel-snapped; pan clamped; the world size comes from the layout.
- World coordinates stay authoritative; no magic screen offsets.

## 8. PixelLab world production (E) — the brief in one paragraph

One atlas visual language (the accepted TRANSFORMATION_01 base C: muted
olive/khaki/grey, flat matte, light upper-left, Traveler palette via
`style_image_url`, no text/figures/grid). Grow the world to a **2 × 2 tile
grid** (native 768 × 1376; world 1536 × 2752 at ×2) — current base at (0,0);
**east** tile beyond the ridge (moor, tarns, a ruined watchtower, a far
coast), **south** tile (river lowlands, farmsteads, a ferry crossing, the
road south toward a distant walled town at the edge), **south-east** tile
(estuary, salt marsh, headland, old harbour ruins). Every seam lands in
geography that hides it (the base's east edge is ridge; its south edge is
meadow — a hedgerow/treeline strip; the west/north are not extended). Plus
seam-cover prop strips, ~6 landmark objects for the new territory, 5 marker
glyphs (16–20 px), extra props, one water-shimmer retry (one attempt only).
Produce **one representative tile first**, judge at ×2 on a 390-wide
composite, then fan out. Deliver a `PACKAGING.md` with every coordinate in
native pixels. Budget ≤ 260 generations. Nothing written outside the
exploration directory.

## 9. Ambient cadence (F) — the contract

- Production default: **no permanent `spent` hold.** A *visit* (4 authored
  scenes with short rests) is followed by an **idle cadence**: rest frame for
  a few seconds → a micro-idle (a short subtle scene from a `microIdles`
  pool; until G's `traveler_idle_breathe` lands the pool is the existing
  shortest subtle scenes at low weight) → longer rest → occasionally a full
  scene again, forever while visible. Presentation timers only; nothing
  granted.
- Lifecycle: pauses on inactive/paused, resumes on resumed; `TickerMode`;
  reduced-motion respected as today.
- A documented test seam so the widget suite can still settle (bounded
  visits in tests, endless in the app); a test that proves the production
  default does **not** end on a held frame after a visit; a test for the
  lifecycle pause/resume; the composition test still runs over every scene.

## 10. Tests to add (focused)

Combat: victory → reward once; second fight same visit (count 2) → reward
once more; third refused `enemy_driven_off`; travel away/back → available;
relaunch mid-visit keeps the count; boss stays 1; v4 save migrates
`drivenOff` → count 1; reward reload/re-ack no duplication.
Rarity: enum complete; loader refuses missing/unknown; every shipped item has
a rarity; save compatibility (rarity is content, not save); inventory and
victory show label + colour.
Ambient: no permanent hold; pause/resume; sequencing.
Atlas: schema v2 parse; landmarks non-tappable; route preview highlights the
BFS path; inspector shows real nodes/enemies; hit targets; zoom/pan bounds.

## 11. Definition of done

Prompt §46, verbatim in spirit: repeatable combat with no wall-clock;
exactly-once rewards proven; every item with authored rarity shown
consistently; a victory panel that reads as winning; a materially larger,
richer atlas with readable routes, embedded places and a real inspector;
ambient that does not run once and freeze; the book corrected; health and
install paths untouched; saves migrate; strict verify passes; docs current.

## 12. Progress log

- 2026-08-19 — bootstrap read; `DECISIONS/0021` and this contract written;
  fan-out launched (B in a worktree; D, F in the tree; E, G PixelLab).
- 2026-08-19 — F, D, G, E, B returned; B merged (`dc8f6f6`); G's art
  blind-QA'd and packaged; E's world blind-QA'd — FAIL on continuity; one
  fix round; second blind FAIL; base + south shipped, east / south-east
  withheld; C returned; integration, goldens, strict verify, docs.

## 13. What shipped

### Combat

- **Per-visit encounters** (`DECISIONS/0021`): `encountersPerVisit` — wolf 2,
  goblin 2, Frost Lynx 2, Hollow Guardian 1; the card says *"2 of 2 this
  visit"* → *"1 of 2 this visit"* → *"Driven off — returns after you travel"*;
  any location change resets the visit; reload / tab change / relaunch do
  not. State **v5** (`WorldState.visitVictories`), v4 `drivenOff` → count 1,
  `v5_baseline.save` frozen, v1–v4 fixtures untouched.
- **Exactly-once** unchanged by construction (one `EncounterWon` event);
  proven again across reload-before-acknowledge and re-acknowledge.
- **Frost Lynx** at Frostmere (30 / 9 / 2, flurry, xp 80; drops Rime Blossom
  @50 %, Frost Lynx Pelt @35 %), PixelLab idle / attack / defeat on a new
  alpine backdrop (blind QA PASS; `lynx_hit` withheld — recoil + fx instead).
- Wolf also drops **Wolf Pelt** @45 %. Two materials, two smithing recipes:
  Wolfhide Jerkin (armor 4, L2) and Frost-lined Jerkin (armor 6, L4).
- Q-06 persistent HP / rest: **still open, untouched** — encounters start at
  full HP.

### Loot

- `Rarity` enum in `stride_core`, required on every item, loader-enforced;
  the authored table in §5 / `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`
  (Legendary reserved, none authored). One style table
  (`lib/ui/theme/rarity_style.dart`): gray `#A8A093` · moss `#86B06A` · cobalt
  `#7D91DE` (hue-tested off the teal accent) · dusk purple `#A987D8` · amber
  `#E0A63F`, each with a dim accent; the label is always present beside the
  colour except inside the inventory grid (Q-07).
- **Victory panel**: VICTORY headline · "<Enemy> falls." · EXPERIENCE block
  (+XP, level-up line) · REWARDS — one framed row per drop: 48 px icon, name
  in rarity ink, rarity badge, ×count · Continue (primary). Icons scale-and-
  fade in once (A-2 presentation; reduced motion jumps to finished). Empty
  drops → "No drops this time." Golden `goldens/combat_victory.png`.
- Inventory tiles: rarity rule + name in rarity ink; Equipped summary carries
  the rank word. Craft: output name ink + badge, result line framed. Character:
  weapon / armour rows with ink + badge. Four new item icons (blind QA PASS).

### World

- Atlas layout **schema v2**: `landmarks` (named, non-interactive, minor /
  future tiers), `kindMarkers` (PixelLab glyphs per location kind under the
  ring — hut, tree, pick, dead tree, boulders). Location kind derived from
  content (`LocationKinds.kindFor`).
- **World doubled**: base + a new south tile (river lowlands, farmsteads,
  Millbridge, Ferry Crossing, the road to the Far Town) — 768 × 2752 world px;
  seam props by the road jog; overlays unchanged. The east and south-east
  tiles, four landmark cutouts and their props are **withheld** after two
  blind QA FAILs on seam continuity (§14, `MISTAKES.md` M-12).
- **Route preview**: the BFS way from here to the selected place is drawn
  heavier; the inspector says "Road from here · 600 steps" or "By way of
  Stonefall Mine · 2,300 steps in all, 800 for the first leg".
- **Inspector**: name · kind · terrain · here / reached / unreached · Safe ·
  Gathering rows (node · skill Lv · tool) · Encounters rows (enemy · BOSS ·
  behaviour · "2 per visit" / "2 of 2 this visit" / driven off) · route line ·
  refusal sentence (engine order) · primary Travel. Labels counter-scale with
  zoom; zoom floor = max(0.5, viewport / world); hit targets grow as the map
  shrinks; landmarks have no hit target; a one-shot arrival burst on travel.

### Ambient

- **Root cause of the "freeze"**: `AmbientPlayer.scenesPerVisit = 4` → the
  `spent` phase held the rest frame until resume / gather — design, not a
  ticker or TickerMode fault. Two real lifecycle defects found and fixed on
  the way (a ticker started while backgrounded; a lazy controller built from
  `dispose`).
- **Idle cadence**: visit (4 scenes) → idle: rest 2–4 s → micro-idle → rest →
  … every 3rd beat a full scene, forever while resumed; one controller; the
  micro-idle pool is derived from the scene table (`idleWeight` / `idleOnly`).
  New PixelLab micro-idles `idle_breathe` and `look_around` (blind QA PASS).
  Test seam: the cadence runs only once `resumed` has been reported, which the
  widget harness never reports, so the suite still settles.
- **Reading book** re-rolled at book scale (blind QA: shipped frames FAIL
  "unfolding a giant map"; replacement PASS-WITH-NOTE "reading a small book").
  `pick_inspect` taken out of rotation (blind FAIL: "pick pops in, no action").

### PixelLab ledger

| Stream | Generations | Accepted | Withheld / rejected |
|---|---:|---|---|
| E world | 253 + 82 = **335** | south tile, 5 glyphs | east, south-east tiles; 4 landmark cutouts; strips / crag / dune / sea stack / reed; water shimmer (5th failure) |
| G ambient / combat / items | **29** | read, idle_breathe, look_around; lynx idle / attack / defeat, backdrop_frostmere; 4 icons | read_alt, shift_weight, lynx_hit, fx_reward_burst |

Balance 700 → **335**. Records and verdicts: `GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/`.

## 14. Known issues

- **BLOCKER:** none known.
- **GAMEPLAY / DESIGN:** balance provisional (lynx untested on a phone); Q-06
  open; Q-07 (the Uncommon/Common order is **owner-resolved as intentional**,
  2026-08-19 — the rest stay open: kind words, landmark names, multi-leg
  total, grid colour-only, future-tier dash); pelts drop only from victories,
  so the jerkin chain starts at the wolf.
- **COSMETIC:** the world is 1 × 2, not 2 × 2 — the east country (watchtower,
  stones, coast) is withheld; the base↔south join shows a faint value step
  and a copse on the line; the south tile's own farm road runs straight at
  the west edge; kind glyphs sit under the ring chrome (device judgement
  pending); wolf-on-forest contrast (pre-existing, blind MAJOR-leaning);
  dead-tree glyph weak on very dark ground; wipe_brow frame 7 arm; the lynx
  attack travels ~10 px; no water shimmer / coastal overlays.

## 15. Verification

`Scripts/verify.sh --strict` result recorded in §15a.

### 15a. Result

`Scripts/verify.sh --strict` on the committed tree (2026-08-19): **All checks
passed** — every guard and self-test green, `dart format` clean,
`stride_core` **613**, `stride_storage` **108**, app **497** (incl. combat
recurrence / session / UI / stage, victory golden, rarity UI 22, atlas schema
v2 / scene / inspector / screen, ambient cadence 185), `stride_health` **143**,
`stride_secure_store` **31**; art packaging `--check` **434** files up to
date; 7 goldens regenerated (Inventory ×2, Craft ×2, World ×2, the new
`combat_victory`) and reviewed by eye. Two earlier strict runs failed
honestly on the way — once because a concurrently running owner session
created a new untracked exploration directory mid-run (the self-test compares
tree snapshots), once on one unformatted test file — both are the guards
working, not defects shipped.

## 16. Physical-device test script (owner)

1. **Mac:** pull the branch; `bash Scripts/ios/build-release-device.sh` —
   in place (`devicectl`); note TOTAL WALKED before / after. Unplug.
2. Launch from the Home Screen: banked, TOTAL WALKED, location, inventory,
   skill XP, character XP as before (a v4 save migrates to v5 silently).
3. **Sync steps** twice: the second grants nothing.
4. **World:** pan — the map continues south past Haven's Rest into farmland,
   Millbridge, Ferry Crossing, the Far Town at the edge (faint names, no
   panel). Pinch to the floor and back. Each place has a glyph under its ring.
5. Tap Stonefall Mine: Worksite · Foothills, Copper Seam / Tin Seam rows,
   Cave Goblin "2 per visit", "Road from here · 800 steps". Tap Frostmere:
   "By way of Stonefall Mine · 2,300 steps in all, 800 for the first leg",
   Frost Lynx listed, no Travel. Tap Whispering Woods → Travel (600): the
   camera recentres, an arrival burst plays once.
6. **Adventure at the Woods:** watch the ambient stage for several minutes —
   after the first scenes it keeps breathing / looking around / occasionally
   doing something; it never holds one pose for long. The reading scene: a
   small book.
7. **Forest Wolf card → Start Combat**; win. VICTORY: +30 XP, reward rows with
   icon / name / rarity / count; Continue. Inventory: the drop once, rarity
   rule and colour; Equipped summary shows rank words.
8. The card now says "1 of 2 this visit": fight again, win — reward once more;
   then "Driven off — returns after you travel".
9. Travel Woods → Haven → Woods: "2 of 2 this visit" again.
10. Win a third fight; **force-quit on the VICTORY panel before Continue**;
    relaunch: the panel stands, the drop is in inventory **once**; Continue;
    no duplicate.
11. Craft: the recipe list shows rarity badges; Wolfhide Jerkin needs 3 pelts.
12. (Optional, needs bronze) Travel to Frostmere, fight the Frost Lynx on the
    alpine backdrop; Frost Lynx Pelt (RARE) on victory.
13. Force-quit and relaunch: everything intact.

## 17. Recommendation

Play it. The next art round should regenerate the **east** tile from the
base's measured edge (M-12) before any other world growth; the next design
conversation is Q-07 and Q-06.
