# FOUNDATION-H — Gather Scene Audit (VAWO01, wave 0)

**Auditor:** FOUNDATION-H, Gather Scene Auditor
**Date:** 2026-09-01
**Branch:** `presentation-combat-evolution-01` @ `6d41bce`
**Scope:** every screen that presents a profession activity — Mining,
Woodcutting, Foraging, Smithing, Cooking.
**Method:** read-only. Source read, content data enumerated, every packaged
plate measured (PNG IHDR) and hashed (md5), representative plates viewed at
native resolution, stage geometry computed by hand from the layout model.

**Owner complaint under audit (P0, the loudest):**

> "mining / woodcutting / foraging often show a weird isolated object floating
> in the centre of a scene"
> "gathering scenes still look weak and mismatched"
> "locations do not visually differentiate enough during gathering"

**Verdict: all three complaints are literally, mechanically true, and each has
an exact cause in code or in the asset routing table.** Nothing here is a
matter of taste. The centre position is arithmetic; the floating is a missing
widget; the sameness is a lookup keyed by the wrong thing.

---

## 1. The implementation — every screen, every file:line

### 1.1 The gathering scene: `LocationStage`

| Concern | File:line |
|---|---|
| The stage widget | `lib/ui/screens/adventure/location_stage.dart:67` |
| Mounted on Adventure | `lib/ui/screens/adventure/adventure_screen.dart:225` |
| Composition model | `lib/ui/components/ambient_stage.dart:96` (`AmbientStageLayout`) |
| Stage widget | `lib/ui/components/ambient_stage.dart:229` (`AmbientStage`) |
| Near-prop builder | `lib/ui/components/ambient_stage.dart:336` (`_prop`) |
| Working loop | `lib/ui/components/ambient_stage.dart:~540` (`_ActivityLoop`) |
| Contact shadow | `lib/ui/components/grounded_sprite.dart:79` (`GroundedSprite`) |
| Asset routing | `lib/ui/icons/ambient_assets.dart:458–712` |
| Node → plate map | `lib/ui/icons/pixel_icons.dart:299–332` (`_nodeArt` / `nodeFor`) |
| Controls / progress | `lib/ui/screens/adventure/activity_panel.dart:551` (`_ActiveQueuePanel`) |

There is **one** gathering scene in the product. It is not per-node and not
per-region; it is a single 176 dp band at the top of Adventure that changes
mode when a node is selected.

**LAYOUT, precisely** (`location_stage.dart:131–263`):

```
ClipRect > SizedBox(height: 176, width: infinity) > Stack(fit: expand)
  [0] BACKGROUND
      work mode : PixelScene.vignette(AmbientAssets.workBackdropFor(skill))
                  -> 384 x 176 native, drawn scale 1 (1 dp per pixel),
                     horizontally centre-clipped in the stage width
      idle mode : PixelScene.vignette(location vignette) + 0x8C scrim if working
      neither   : ColoredBox(StrideColors.surfaceBlock)
  [1] GROUND BAND
      Positioned(bottom:0, height:72) linear gradient 0x0014120F -> 0x8014120F
      Exists solely so the multiply contact shadow has something to darken.
  [2] THE STAGE  Positioned(left:0,right:0,bottom:6,height:140) > AmbientStage
        - prop (near, the subject)  : bare PixelAsset, scale 1, 96 x 96
        - figures (Traveler)        : GroundedSprite, scale 2, 64-row canvas
        - paint order: prop-behind -> figure -> prop-in-front
        - the far `scenery` slot is PASSED NULL and never renders (line 165-169)
  [3] LOCK SCRIM + RequirementGate, only when the selection is gated
  [4] no caption — removed by PLAYABLE_EXPERIENCE_REFINEMENT_01 §5
```

**Geometry, computed** (`AmbientStageLayout`, scale 2, stage height 140):

| Quantity | Formula | 393 dp screen | 440 dp screen |
|---|---|---|---|
| `groupWidth` | 64 × 2 | 128 dp | 128 dp |
| `groupLeft` | `round(w·0.6 − 62)` | 174 | 202 |
| `groundLine` | `groupTop + 64·2` | y = 132 | y = 132 |
| `feetCentre` | `groupLeft + 62` | 236 | 264 |
| prop left (west) | `feetCentre − 8 − 96` | 132 | 160 |
| prop **opaque centre** | — | **x ≈ 180 (45.8 % of width)** | **x ≈ 208 (47.3 % of width)** |

The subject's opaque centre lands at **45–47 % of the screen at every
supported width**. The owner's word "centre" is not an impression; it is what
the layout is defined to do.

**What animates:** exactly one thing — the profession loop
(`_ActivityLoop`, 110 ms/frame). 8 frames mining, 8 woodcutting, 9+8 foraging
ping-pong. One cycle ≈ 0.9–1.9 s. Nothing else on the stage moves. The prop is
a still image. The backdrop is a still image. The ground band is a static
gradient.

**Progress presentation:** none on the stage. It lives in the panel below
(`activity_panel.dart:566–626`): a text line `Gathering 2 / 5`, a
`_SecondsRemaining` countdown, and `RepetitionBar` — a flat fill bar.

### 1.2 The craft scene: Smithing / Cooking

`lib/ui/screens/craft/craft_screen.dart:1003–1075`. Structurally identical —
same `AmbientStage`, same ground gradient, same 384 × 176 backdrop family,
same 96² station prop at scale 1, same figure at scale 2. Differences: it is
inside a bordered card (`_craftStageHeight`), it mounts **only while a craft
is running** (`if (loop != null)`), the station is chosen by
`RecipeDefinition.station` rather than by node, and the companion scenes are
NOT filtered out (it passes `AmbientAssets.scenes`, not `soloScenes`) — so a
cat can appear at the forge, which the gathering stage deliberately forbids.

Craft is **less** affected by the P0: three stations (forge / woodbench /
cookfire) against three matching backdrops, all authored as a set. The
gathering side is where the routing broke.

### 1.3 Everywhere else

`skill_detail_screen.dart` and `skills_screen.dart` show only 24² skill icons.
`board_card.dart` and `activity_result.dart` show only 48² item icons. There is
no second gathering scene anywhere in the product.

---

## 2. The data that drives the scene — quoted

Three lookups, in this order, all in
`lib/ui/screens/adventure/location_stage.dart:136–149`:

```dart
final String? nodeArt = node == null ? null : PixelIcons.nodeFor(node.id);

// The resource, near, at the point the tool reaches. Falls back to the
// node's far vignette where no work prop is authored — worse, and never
// blank; `node_art_resolution_test` holds every node to having one or the
// other.
final StageScenery? prop = !working
    ? null
    : AmbientAssets.workPropFor(nodeArt ?? '') ??
          AmbientAssets.sceneryFor(nodeArt);

final String? workBackdrop = skill == null
    ? null
    : AmbientAssets.workBackdropFor(skill);
```

**The background is keyed by SKILL. Nothing else.**

```dart
// lib/ui/icons/ambient_assets.dart:497
static const Map<String, String> _workBackdrops = <String, String>{
  'skill.mining': '$_art/work/bg_mining.png',
  'skill.woodcutting': '$_art/work/bg_woodcutting.png',
  'skill.foraging': '$_art/work/bg_foraging.png',
};
```

Three entries. Twenty-two nodes. Five regions. There is no region term in the
expression at all — `LocationStage` receives `vignette` (the regional
painting) and **discards it whenever a work backdrop exists**, which for the
three gathering professions is always.

**The subject is keyed by NODE, via the node's vignette path**, with a
fallback that is the whole defect:

```dart
// lib/ui/icons/ambient_assets.dart:471
static StageScenery? workPropFor(String nodeArt) => _workProps[nodeArt];
```

`_workProps` (`ambient_assets.dart:512–570`) has **10 keys**. `_nodeArt`
(`pixel_icons.dart:299`) has **22**. The 12 nodes with no entry fall through
`??` to `sceneryFor(nodeArt)` — which returns the node's **96 × 96
transparent inventory-family vignette**, packaged from the same PixelLab
stream and the same source directory as the 48 × 48 item icons:

```js
// Scripts/art/package-art.js:636  (Transformation Build 01, stream F)
const ITEMS_SRC = path.join(TRANSFORM, 'items');
...
// "The node art is a new family: 96 x 96, transparent, no figures,
//  drawn on the Adventure gather card."
const NODE_ART = [
  'meadow_patch', 'oak_stand', 'duskcap_grove', 'copper_seam', 'tin_seam',
  'rimefrost_hollow', 'frostpine_stand', 'hollow_thicket',
];
```

**This fallback is the "isolated object". It is an inventory icon, by
provenance, by canvas convention, and by drawing style, being used as scene
furniture.**

The gap is on record in the round that created it — and it has since **grown
from 3 nodes to 12** as four content packs added nodes without adding props:

> "Frostpine, Rimefrost Hollow and Hollow Thicket have **no work prop**. They
> fall back to their existing node vignettes… A gap, on record, not an
> oversight."
> — `GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/stage/README.md`

---

## 3. Every gatherable node in the content data

Source: `assets/content/v1/resource_nodes.json` (22 entries) joined to
`assets/content/v1/locations.json` (5 locations). Region names as they exist
in the data are **Haven's Rest, Whispering Woods, Stonefall Mine, Frostmere,
Forgotten Hollow** — there is no "Haven", "Woods", "Stonefall" or "Hollow"
region id; those are shorthands.

| # | Node id | Skill | Region | Yields | Lvl | Tool tier | Gate |
|---|---|---|---|---|---|---|---|
| 1 | `meadow_patch` | Foraging | Haven's Rest | Meadow Herb ×1 | 1 | — | — |
| 2 | `mill_garden` | Foraging | Haven's Rest | Meadow Herb ×2 | 7 | — | `havens_rest_mill` |
| 3 | `oak_stand` | Woodcutting | Whispering Woods | Oak Log ×1 | 1 | axe t0 | — |
| 4 | `heartwood_oak` | Woodcutting | Whispering Woods | Oak Log ×2 | 4 | axe t1 | — |
| 5 | `warded_grove` | Woodcutting | Whispering Woods | Oak Log ×2 | 6 | axe t1 | `ranger_watchtower` |
| 6 | `duskcap_grove` | Foraging | Whispering Woods | Duskcap ×1 | 3 | — | — |
| 7 | `copper_seam` | Mining | Stonefall Mine | Copper Ore ×1 | 1 | pick t0 | — |
| 8 | `old_workings` | Mining | Stonefall Mine | Scrap Metal ×1 | 8 | pick t2 | `stonefall_lift` |
| 9 | `tin_seam` | Mining | Stonefall Mine | Tin Ore ×1 | 3 | pick t0 | — |
| 10 | `deep_tin_seam` | Mining | Stonefall Mine | Tin Ore ×2 | 4 | pick t1 | — |
| 11 | `hardened_copper_seam` | Mining | Stonefall Mine | Copper Ore ×2 | 5 | pick t2 | `stonefall_lift` |
| 12 | `gallery_tin_lode` | Mining | Stonefall Mine | Tin Ore ×2 | 6 | pick t2 | `lower_gallery_works` |
| 13 | `collapsed_span` | Mining | Stonefall Mine | Scrap Metal ×2 | 7 | pick t2 | `lower_gallery_works` |
| 14 | `rimefrost_hollow` | Foraging | Frostmere | Rime Blossom ×1 | 4 | — | — |
| 15 | `sheltered_frost_meadow` | Foraging | Frostmere | Rime Blossom ×2 | 7 | — | `frostmere_shelter` |
| 16 | `frostpine_stand` | Woodcutting | Frostmere | Pine Log ×1 | 5 | axe t1 | — |
| 17 | `oldgrowth_frostpine` | Woodcutting | Frostmere | Pine Log ×2 | 7 | axe t2 | — |
| 18 | `silkstrand_thicket` | Foraging | Forgotten Hollow | Gloom Silk ×1 | 6 | — | — |
| 19 | `hollow_thicket` | Foraging | Forgotten Hollow | Hollow Root ×1 | 9 | — | — |
| 20 | `veiled_silkstrand` | Foraging | Forgotten Hollow | Gloom Silk ×2 | 8 | — | `hollow_field_camp` |
| 21 | `undercroft_silkfall` | Foraging | Forgotten Hollow | Gloom Silk ×2 | 9 | — | `hollow_undercroft` |
| 22 | `deep_hollow_thicket` | Foraging | Forgotten Hollow | Hollow Root ×2 | 10 | — | `hollow_undercroft` |

Skill split: Mining 7, Foraging 10, Woodcutting 5.

---

## 4. The complete node → background / subject table, with pixel dimensions

All dimensions read from PNG IHDR. `md5` is the first 8 hex of the packaged
plate — **identical md5 means byte-identical image**.

| # | Node | Background (dims) | Subject asset (dims) | Subject md5 | Kind |
|---|---|---|---|---|---|
| 1 | meadow_patch | `work/bg_foraging.png` 384×176 | `work/prop_meadow_patch.png` 96×96 | `da52b40b` | PROP |
| 2 | mill_garden | `work/bg_foraging.png` 384×176 | `work/prop_meadow_patch.png` 96×96 | `da52b40b` | PROP — dup of #1 |
| 6 | duskcap_grove | `work/bg_foraging.png` 384×176 | `work/prop_duskcap_grove.png` 96×96 | `6b0dcb4d` | PROP |
| 14 | rimefrost_hollow | `work/bg_foraging.png` 384×176 | `node/rimefrost_hollow.png` 96×96 | `12fa6ffa` | **ICON** |
| 15 | sheltered_frost_meadow | `work/bg_foraging.png` 384×176 | `node/sheltered_frost_meadow.png` 96×96 | `12fa6ffa` | **ICON — dup of #14** |
| 18 | silkstrand_thicket | `work/bg_foraging.png` 384×176 | `node/silkstrand_thicket.png` 96×96 | `51162422` | **ICON** |
| 19 | hollow_thicket | `work/bg_foraging.png` 384×176 | `node/hollow_thicket.png` 96×96 | `51162422` | **ICON — dup** |
| 20 | veiled_silkstrand | `work/bg_foraging.png` 384×176 | `node/veiled_silkstrand.png` 96×96 | `51162422` | **ICON — dup** |
| 21 | undercroft_silkfall | `work/bg_foraging.png` 384×176 | `node/undercroft_silkfall.png` 96×96 | `51162422` | **ICON — dup** |
| 22 | deep_hollow_thicket | `work/bg_foraging.png` 384×176 | `node/deep_hollow_thicket.png` 96×96 | `51162422` | **ICON — dup** |
| 3 | oak_stand | `work/bg_woodcutting.png` 384×176 | `work/prop_oak_stand.png` 96×96 | `b9d97082` | PROP |
| 4 | heartwood_oak | `work/bg_woodcutting.png` 384×176 | `work/prop_oak_stand.png` 96×96 | `b9d97082` | PROP — dup of #3 |
| 5 | warded_grove | `work/bg_woodcutting.png` 384×176 | `node/warded_grove.png` 96×96 | `8f4e9cb3` | **ICON** |
| 16 | frostpine_stand | `work/bg_woodcutting.png` 384×176 | `node/frostpine_stand.png` 96×96 | `bc7832b7` | **ICON** |
| 17 | oldgrowth_frostpine | `work/bg_woodcutting.png` 384×176 | `node/oldgrowth_frostpine.png` 96×96 | `bc7832b7` | **ICON — dup of #16** |
| 7 | copper_seam | `work/bg_mining.png` 384×176 | `work/prop_copper_seam.png` 96×96 | `8bf88e17` | PROP |
| 8 | old_workings | `work/bg_mining.png` 384×176 | `work/prop_copper_seam.png` 96×96 | `8bf88e17` | PROP — dup of #7 |
| 9 | tin_seam | `work/bg_mining.png` 384×176 | `work/prop_tin_seam.png` 96×96 | `ba26c936` | PROP |
| 10 | deep_tin_seam | `work/bg_mining.png` 384×176 | `work/prop_tin_seam.png` 96×96 | `ba26c936` | PROP — dup of #9 |
| 11 | hardened_copper_seam | `work/bg_mining.png` 384×176 | `work/prop_hardened_copper_seam.png` 96×96 | `f23222e9` | PROP |
| 12 | gallery_tin_lode | `work/bg_mining.png` 384×176 | `node/gallery_tin_lode.png` 96×96 | `7841a1f4` | **ICON** |
| 13 | collapsed_span | `work/bg_mining.png` 384×176 | `node/collapsed_span.png` 96×96 | `4894ea61` | **ICON** |

### The counts

| Measure | Value |
|---|---|
| Nodes | **22** |
| Distinct backgrounds in work mode | **3** |
| Distinct subject images (by md5) | **12** — 6 authored props + 6 icon plates |
| Nodes showing an authored work prop | **10** (45 %) |
| Nodes showing an inventory-family icon | **12** (55 %) |
| Distinct (background + subject) scenes | **12** |
| Nodes that are a pixel-identical duplicate of another node | **10** (45 %) |

### The worst repetitions, named

- **All 5 Forgotten Hollow nodes are one image.** `silkstrand_thicket`,
  `hollow_thicket`, `veiled_silkstrand`, `undercroft_silkfall`,
  `deep_hollow_thicket` → identical backdrop, identical `51162422` root-ball
  icon, identical forage loop. Two of them yield Hollow Root, three yield
  Gloom Silk; the picture is the same for both.
- **All 10 foraging nodes across 4 regions share `bg_foraging.png`** — a
  temperate olive scrub bank authored for Haven's Meadow Patch.
- **All 7 Stonefall nodes share `bg_mining.png`;** 5 of them show one of two
  boulder images.
- **Both Frostmere woodcutting nodes are one image;** both Frostmere foraging
  nodes are one image. Frostmere has 4 nodes and 2 pictures.
- **The two Haven foraging nodes are one image.**

### Semantic mismatches inside the table

- `old_workings` and `collapsed_span` yield **Scrap Metal** and show a
  **copper seam**.
- `gallery_tin_lode` yields Tin Ore and shows the tin **icon**, not
  `prop_tin_seam.png`, which exists and is already routed for two other tin
  nodes.
- `warded_grove` shows the oak-stand **vignette** while `oak_stand` two rows
  above shows the oak **prop** — two nodes in the same region, same skill,
  same resource, drawn in two different pictorial languages.

---

## 5. The floating-object failure, mechanically

Five compounding causes. Each is independently sufficient to produce the
owner's read; together they guarantee it.

### 5.1 The subject has no contact shadow — and the codebase says so itself

```dart
// lib/ui/components/ambient_stage.dart:336
Widget _prop(AmbientStageLayout layout, StageScenery prop, bool east) =>
    Positioned(
  left: layout.propRect(prop, east: east).left,
  top: layout.propRect(prop, east: east).top,
  child: PixelAsset(
    assetPath: prop.assetPath,
    nativeWidth: prop.native,
    nativeHeight: prop.native,
    scale: 1,
  ),
);
```

A bare `PixelAsset`. Compare the doc on the widget that exists to solve
exactly this, `lib/ui/components/grounded_sprite.dart:75–78`:

> "A sprite composited onto a background, with its contact shadow. Use this
> for **every** standalone character placed on scenery. **A bare
> `PixelAsset.sprite` on a background is the floating defect.**"

The Traveler goes through `GroundedSprite` (multiply ellipse, strength 0.72,
squash 0.30, derived from his measured footprint). The subject does not. The
ground-band gradient at `location_stage.dart:213` was added specifically so
the contact shadow has something to darken — and the subject casts none into
it. **The figure is planted; the thing he is working on is pasted.**

Note the geometry is *correct*: `propRect` puts the prop's measured lowest
opaque row exactly on `groundLine` (y = 132), the same row as the Traveler's
feet. The object is not floating in coordinates. It is floating **in light**.
That distinction matters for the fix: this is not a placement bug, it is a
missing shading layer.

### 5.2 The subject is an inventory icon for 12 of 22 nodes

Viewed at native resolution during this audit:

- `node/hollow_thicket.png` — a dark tangled root ball with a heavy black
  keyline, isolated on transparency, no ground, its own internal lighting. It
  is drawn to the item-icon contract: read at a glance, in a grid cell,
  against a UI surface.
- `node/rimefrost_hollow.png` — white blossoms **standing on their own patch
  of snow**, on transparency.
- `node/frostpine_stand.png` — three complete snow-laden pines with their own
  snow ground line.

These are composited onto `bg_foraging.png` (a pale olive temperate scrub
bank) and `bg_woodcutting.png` (a green temperate forest clearing with
dappled daylight). The result is a hard-outlined object with a foreign
palette, a foreign light direction and **its own second ground plane** sitting
in the middle of a painting with a different one. A 96 dp snow patch on a
green forest floor is a cut-out, and the eye reads cut-outs as floating even
when the pixels touch the floor.

`prop_copper_seam.png` — viewed — is better but still a catalogue object: a
boulder with a hard black keyline and loose rubble, no cast shadow, no
bedding into anything.

### 5.3 The subject sits at the optical centre

Computed in §1. `propRect` places the subject's opaque centre at 45–47 % of
the screen width at every supported size, while the Traveler stands at 60 %.
The object is therefore in the **middle of the frame** and the figure is off
to its right. In a 384 × 176 letterbox with no other focal element, the eye
goes to the centre first, finds a keylined icon, and the man appears to be
standing beside it rather than working on it.

### 5.4 Two pixel densities in one picture

| Layer | Native | Drawn at | Effective density |
|---|---|---|---|
| Backdrop | 384 × 176 | `PixelScene.vignette` → `scale = 1` | **1 dp per pixel** |
| Subject prop | 96 × 96 | `PixelAsset(..., scale: 1)` | **1 dp per pixel** |
| Traveler / loop | 64-row canvas | `GroundedSprite(scale: 2)` | **2 dp per pixel** |

The character's pixels are **four times the area** of every other pixel in the
frame. This is deliberate — `ambient_stage.dart:26–31` argues the ×1/×2 split
reads as depth — but it is also, exactly, "mismatched". A chunky ×2 figure in
front of a finely rendered ×1 painting is two art styles in one 176 dp band,
and no rule in `GAME_BIBLE/ART/ART_DIRECTION.md` governs intra-scene density:
**L-18** requires an integer multiple per asset and says nothing about two
assets in one composition agreeing.

### 5.5 The backdrop is generic to the profession, not to the place

Because `_workBackdrops` is keyed by skill, the region-specific painting the
player arrived to is **replaced** the instant they select an activity
(`location_stage.dart:201–205`). The `else` branch that dims the location
vignette instead is dead code for all three gathering skills — a work backdrop
always exists.

So the scene the object floats in is not a scene of anywhere. It is
"foraging". This is why the object reads as *isolated*: there is nothing in
the frame that belongs with it, because the frame belongs to a different
resource in a different region.

---

## 6. Regional identity — quantified

Verified region names: **Haven's Rest, Whispering Woods, Stonefall Mine,
Frostmere, Forgotten Hollow.**

| Region | Nodes | Distinct gathering backgrounds | Distinct subjects | Distinct scenes |
|---|---|---|---|---|
| Haven's Rest | 2 | 1 (`bg_foraging`) | 1 | **1** |
| Whispering Woods | 4 | 2 (`bg_woodcutting`, `bg_foraging`) | 3 | **3** |
| Stonefall Mine | 7 | 1 (`bg_mining`) | 5 | **5** |
| Frostmere | 4 | 2 (`bg_woodcutting`, `bg_foraging`) | 2 | **2** |
| Forgotten Hollow | 5 | 1 (`bg_foraging`) | 1 | **1** |

**Region-specific gathering assets in the product: ZERO.**

Shared/generic gathering assets: 3 backdrops + 6 props + 12 icon fallbacks
(keyed by resource family, not region) + 3 activity loops + 1 shared one-shot.

The bitter part is that the three backdrops **were authored for specific
regions** and are then dispatched by skill:

> "Mining — Stonefall … `mine_rock_s7.png` **Accepted** — natural slate face
> with copper streaks, two timber props and a lintel…
> Woodcutting — Whispering Woods … `woods_open_s7.png` **Accepted** — open
> earthen clearing … the deeper wood in cool haze…
> Foraging — preserved. `work_foraging_0` … stays the packaged **Meadow
> Patch** backdrop"
> — `PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/README.md`

Consequences on the device today:

- Felling a **Frostpine in alpine Frostmere** shows the temperate green
  Whispering Woods clearing, with three snowy pines pasted in front of it.
- Foraging **Gloom Silk in the Forgotten Hollow** shows Haven's Rest's sunlit
  meadow scrub, with a near-black root ball pasted in front of it.
- Foraging **Rime Blossom at Frostmere** shows the same Haven scrub, with a
  snow patch pasted in front of it.

Mining is the only profession whose backdrop matches its region — because
mining exists in exactly one region.

Additionally, in work mode the stage drops the companion scenes
(`soloScenes`) and therefore also drops the region's fauna layer
(`_faunaByVignette` — hare / songbird / crow / ptarmigan, resolved by
*location vignette*, which work mode has already discarded). For the entire
duration of a gather there is **no signal on screen of where the player is**.

---

## 7. Action staging — what the player actually sees

**Does the Traveler appear?** Yes, always, and he is the only animated thing.

**Is there a swing/strike?** Yes. `_activityLoops` (`ambient_assets.dart:390`)
gives each profession a loop; `_strikeFrames` (`:372`) marks the contact
frame — mining 4, woodcutting 4, foraging 8, smithing 6, cooking 6.

**Is there impact feedback?** Audio and haptics only. A repo-wide search for
`particle`, `debris`, `spark`, `flash`, `shake` finds **nothing in the
gathering or craft presentation** — the only hits are the World atlas travel
spark. `onActivityBeat` fires on the strike frame and its sole consumer is
`AudioScope.playSkillCue`. There is no chip, no dust, no dislodged ore, no
falling leaf, no screen shake, no colour flash, no node depletion state.

**Timeline of one gather, exactly:**

1. Player taps a row in `ActivityPanel`. The stage swaps from the location
   painting to the profession backdrop, the cat/fauna vanish, and the subject
   appears at the centre. The Traveler stands in the ambient rest pose.
2. Player taps `Gather ×N — 1,200 steps`. One light haptic.
   `ActivityController.start(node, count)` — **even ×1 goes through the
   queue**.
3. `activityActive` becomes true. The ambient player and one-shot unmount;
   `_ActivityLoop` mounts and cycles at 110 ms/frame, forever, unchanged.
   One repetition is `stepCost × 600 ms` — **48 s for a Meadow Patch, 3 min
   for a Hollow Thicket** (`ActivityDurations.millisPerStep = 600`).
4. For that entire duration the picture is: a still backdrop, a still subject,
   a ~0.9 s figure loop, and a per-strike sound. The bar and `Gathering 2 / 5`
   are in the panel below, outside the picture.
5. On each completion: the counter and the bar reset; the universal
   `ActivityResult` card updates at the screen's foot. Nothing happens on the
   stage.
6. When the queue ends, `activityActive` goes false and — because
   `playToken` is only non-null when no queue is running
   (`adventure_screen.dart:150`) — the one-shot fires. That one-shot is
   `PixelIcons.gatherFrames`, passed unconditionally at
   `location_stage.dart:152` **regardless of skill**. It is the foraging
   animation: the Traveler crouches and plucks a plant. **A finished mining
   queue ends with the miner kneeling to pick a herb next to a boulder.**
7. Deselect, and the location painting, the cat and the fauna return.

Under Reduce Motion the loop is pinned to frame 0 and the scene is entirely
still for the full 48 s–3 min, with only the audio beat continuing
(deliberate — `_ActivityLoop` doc).

---

## 8. Unused gathering-scene art already in the repository

Cross-referenced against `Scripts/art/package-art.js` (which names every
shipped source). "Unused" below means generated, kept, and **not** referenced
by the packager.

### Backdrops, 384 × 176 — 7 unused plates

| File | Note |
|---|---|
| `PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/mine_masonry_s41.png` | rejected: "reads as a cellar" |
| `…/mine_masonry_s97.png` | rejected: timber walkway at the ground line |
| `…/woods_stump_s41.png` | rejected: stump collides with the oak prop |
| `…/woods_stump_s97.png` | rejected: same collision |
| `PRESENTATION_WORLD_REWARD_FEEL_01/out/stage/work_mining_0.png` | superseded |
| `…/work_mining_b_0.png` | superseded by PER01 `mine_rock_s7` |
| `…/work_woodcutting_0.png` | superseded by PER01 `woods_open_s7` |

None of these is a *region* plate for Frostmere or the Hollow. **There is no
existing art that would fix the regional gap** — that requires new PixelLab
rounds.

### Props, 96 × 96 — 18 unused plates

| Family | Files | Note |
|---|---|---|
| Mining base | `prop_mine_a_0/1/2/3` | the accepted family base, ×4 candidates |
| Ore variants | `prop_copper_b_0`, `prop_tin_0`, `prop_tin_b_0`, `prop_hardened_0`, `prop_hardened_b_0` | earlier inpaints; `_b_` variants shipped then superseded by PLAYABLE_POLISH_01 |
| Woodcutting | `prop_wood_a_0/1/3` | `a_2` shipped; `a_1` was withdrawn for a hard-edged grass slab |
| Foraging | `prop_forage_a_1/2/3` | `a_0` shipped (low candidate, clears the head) |
| **Frostpine** | *(none survives)* | **`8711bacf` frostpine inpaint was REJECTED** — "read as an ice column / frozen waterfall, not a frosted pine" |
| Seam seeds | `PLAYABLE_POLISH_01/out/props/seam_{copper,tin,tin3,hardened,hardened2}_s*` (15) | rejected seeds from the re-author round |

**The Frostpine work prop was attempted and failed QA.** Rimefrost Hollow and
Hollow Thicket were never attempted. Nothing in the archive can be promoted to
close the 12-node gap; all five missing props need generating.

### Craft, already shipped

`PLAYABLE_POLISH_02/out/stage/` — `bg_{cooking,smithing,woodworking}_384` and
`station_{forge,woodbench,cookfire}_96` are all packaged and in use. The
superseded 64² `node/station_forge.png` / `node/station_cookfire.png` remain
packaged and unreferenced (dead bytes in the bundle).

---

## 9. DEFECT REGISTER

| ID | Sev | Defect | Affected | Proposed fix (one line) |
|---|---|---|---|---|
| **GH-01** | **P0** | The work subject is an **inventory-family 96² icon** — same PixelLab stream and source folder as the 48² item icons — composited into a painted scene. | 12 nodes: `rimefrost_hollow`, `sheltered_frost_meadow`, `frostpine_stand`, `oldgrowth_frostpine`, `silkstrand_thicket`, `hollow_thicket`, `veiled_silkstrand`, `undercroft_silkfall`, `deep_hollow_thicket`, `warded_grove`, `gallery_tin_lode`, `collapsed_span` | Author 5 new work props (frostpine, rime blossom, gloom-silk thicket, hollow-root thicket, ruin/scrap face) and route the 7 depth nodes to their donors' existing props. |
| **GH-02** | **P0** | The subject carries **no contact shadow**; `_prop` builds a bare `PixelAsset` — the exact construction `grounded_sprite.dart` names as "the floating defect". | all 22 nodes + 3 craft stations | Give `StageScenery` a measured bottom footprint and render props through a prop-shaped `GroundedSprite`. |
| **GH-03** | **P0** | The backdrop is keyed by **skill**, so 22 nodes in 5 regions share 3 plates, and the arrival painting is discarded on selection. | all 22 nodes; worst at Frostmere and Forgotten Hollow | Key `_workBackdrops` by `(region, skill)`; author 4 new plates. |
| **GH-04** | **P0** | **10 of 22 nodes render a pixel-identical scene** to another node. The 5 Forgotten Hollow nodes are one picture. | `mill_garden`, `heartwood_oak`, `old_workings`, `deep_tin_seam`, `sheltered_frost_meadow`, `oldgrowth_frostpine`, `hollow_thicket`, `veiled_silkstrand`, `undercroft_silkfall`, `deep_hollow_thicket` | GH-01 + GH-03 together take 12 distinct scenes to 22; add a tier treatment (richer vein / older growth) for same-resource pairs. |
| **GH-05** | **P1** | **Two pixel densities in one frame**: backdrop and prop at 1 dp/px, figure at 2 dp/px. The character's pixels are 4× the area of the scenery's. | every gather and craft scene | Owner/art-direction ruling, then one density per stage — either ×2 props at 48² native, or a ×2 backdrop family. Record as an amendment to L-18. |
| **GH-06** | **P1** | **Subject scale is wrong against the figure**: a 96 dp prop beside a 128 dp Traveler makes an ore boulder chest-high and a "Frostpine Stand" (three mature pines) shorter than the man felling it. | `frostpine_stand`, `oldgrowth_frostpine`, `oak_stand`, `heartwood_oak`, `warded_grove` | Author tree props as **one trunk section at the cut**, not a whole stand; set per-family native size in `StageScenery`. |
| **GH-07** | **P1** | The closing one-shot is the **foraging** animation for every profession — `location_stage.dart:152` passes `PixelIcons.gatherFrames` unconditionally. | all mining and woodcutting nodes | Key the one-shot by skill, or suppress it outside Foraging until per-skill one-shots exist. |
| **GH-08** | **P1** | **No impact feedback of any kind**: no debris, dust, chips, flash, shake or node depletion. Over a 48 s–3 min repetition the only motion is a ~0.9 s loop. | every gather and craft | Hang a short debris/dust burst on the existing `onActivityBeat` strike hook; add a subtle stage-level progress cue. |
| **GH-09** | **P1** | The backdrop is a fixed **384 dp** plate centre-placed in the stage width; on any screen wider than 384 dp it leaves empty gutters (≈23 dp each side at 440 dp) at a half-dp offset. | every location vignette and work backdrop, on iPhone Pro Max class devices | Author the backdrop family at 440 wide, or extend/tile the flanks in `package-art.js`. |
| **GH-10** | **P2** | **Resource/subject semantic mismatch.** | `old_workings` (Scrap Metal → copper seam), `collapsed_span` (Scrap Metal → copper vignette), `gallery_tin_lode` (Tin → tin *icon* while `prop_tin_seam` exists) | Author a ruin/scrap work face; route `gallery_tin_lode` to `prop_tin_seam`. |
| **GH-11** | **P2** | The far **`scenery` slot is never populated** by `LocationStage` (`:165–169`); `_scenery` (22 entries, measured bounds) exists only as the prop fallback, and `ambient_composition_test` guards geometry that never renders on this screen. | architecture | Either use the slot for a mid-ground element in the new spec, or delete it and retarget the test at `propRect`. |
| **GH-12** | **P2** | **The guard cannot see any of this.** `test/node_art_resolution_test.dart` asserts only that each node has a 96² vignette with ≥800 opaque pixels. It does not assert a work prop, distinctness, or regional match — so 12 icon fallbacks and 10 duplicate scenes ship CI-green. | CI | Add assertions: every node resolves a `_workProps` entry; no two nodes resolve the same (backdrop, subject) pair. |
| **GH-13** | **P2** | **Stale provenance.** `PWRF01/out/stage/README.md` still lists `work_mining_b_0` as `bg_mining`'s source and states mining ships mirrored because "the mining loop works east"; the shipped source is PER01 `mine_rock_s7` with `flip: false`, and `AmbientAssets.worksEast()` returns false unconditionally. | documentation | Correct the README to the shipped routing. |
| **GH-14** | **P2** | **Work mode erases every regional cue**: the location painting is replaced, the companion scenes are filtered out, and with them the region's fauna layer (which resolves by location vignette). Nothing on screen says where the player is for the whole gather. | all 22 nodes | Carried by GH-03; additionally keep a regional silhouette band or the fauna layer in work mode. |
| **GH-15** | **P2** | Superseded 64² `node/station_forge.png` and `node/station_cookfire.png` remain packaged and unreferenced. | bundle size | Drop from `package-art.js`. |

---

## 10. Proposed SCENE COMPOSITION SPEC

### 10.1 What a correct gathering scene contains, structurally

Six layers, back to front. The rule is that **every layer belongs to the same
place, the same light and the same pixel density.**

1. **Sky / far band** — the top ~35 % of the plate. Regional: alpine haze,
   forest canopy, mine ceiling, hollow gloom. Establishes palette and time of
   day for everything in front of it.
2. **Mid-ground context** — the middle ~30 %. Regional and *readable as the
   region without the subject*: frostpines receding, gallery timbering,
   webbed boles. This is the layer that currently does not vary and is the
   single largest cause of "locations do not visually differentiate".
3. **Ground plane** — an explicit horizon/floor junction inside the painted
   plate, at the row the figure's `groundLine` lands on (y = 162 of 176
   today). Currently faked by a code gradient because two of three plates do
   not draw one.
4. **Mid-ground subject with contact shadow** — the resource. Authored *for
   the scene*, not for a grid cell: no keyline, no self-contained base, no
   internal ground, palette drawn from the region's, lit from the plate's
   light direction. Must be sized against the 128 dp figure — an ore face is
   waist-to-shoulder, a fellable trunk exceeds the frame and is cropped by it.
   Contact shadow derived from its own measured footprint, not authored.
5. **The Traveler** — at 60 % width, tool arc crossing the subject's near
   face, at the same density as everything else.
6. **Near foreground** — a low occluding element at the frame's bottom edge
   (grass tufts, spoil, snow drift). Cheap depth, and it is what stops a
   subject reading as pasted even before the shadow lands.

Plus, per strike: a short regional debris burst at the contact point (rock
chips, chips of pale wood, disturbed pollen) — 3–4 frames on the existing
`onActivityBeat` hook.

### 10.2 What is authored per what

| Layer | Varies by | Why |
|---|---|---|
| Sky, mid-ground, ground plane, near foreground | **region × skill** | The place and the kind of work together decide the setting; a Frostmere logging site and a Frostmere herb slope are not one picture. |
| Subject / work face | **resource family**, with a tier treatment | The owner's own brief: "reusable compositions with an interchangeable resource object". Copper, tin and hardened copper are one outcrop with different metal in it. |
| Traveler loop, strike frame, debris kind | **skill** | Already correct today. |
| Closing one-shot | **skill** | Currently shared — GH-07. |
| Contact shadow, ground band, scale, placement | **nothing** — code | Derived, so it cannot drift. |

### 10.3 Asset count

**Naive, per node:** 22 backdrops + 22 subjects = **44 plates**.

**Smart reuse — region × skill for the backdrop, resource family for the
subject:**

*Backdrops.* Only 7 (region, skill) pairs actually exist in the content:

| Pair | Nodes | Status |
|---|---|---|
| Stonefall × Mining | 7 | **have** (`mine_rock_s7`) |
| Whispering Woods × Woodcutting | 3 | **have** (`woods_open_s7`) |
| Haven's Rest × Foraging | 2 | **have** (`work_foraging_0`) |
| Whispering Woods × Foraging | 1 | **NEW** |
| Frostmere × Woodcutting | 2 | **NEW** |
| Frostmere × Foraging | 2 | **NEW** |
| Forgotten Hollow × Foraging | 5 | **NEW** |

→ **7 backdrops, 4 new.**

*Subjects.* 11 resource families across the 22 nodes:

| Family | Nodes | Status |
|---|---|---|
| Copper face | copper_seam | have |
| Hardened copper face | hardened_copper_seam | have |
| Tin face | tin_seam, deep_tin_seam, gallery_tin_lode | have (route the third) |
| Ruin / scrap face | old_workings, collapsed_span | **NEW** |
| Oak trunk | oak_stand, heartwood_oak, warded_grove | have |
| Frostpine trunk | frostpine_stand, oldgrowth_frostpine | **NEW** (previous attempt rejected) |
| Meadow herb bed | meadow_patch, mill_garden | have |
| Duskcap cluster | duskcap_grove | have |
| Rime blossom bed | rimefrost_hollow, sheltered_frost_meadow | **NEW** |
| Gloom-silk thicket | silkstrand_thicket, veiled_silkstrand, undercroft_silkfall | **NEW** |
| Hollow-root thicket | hollow_thicket, deep_hollow_thicket | **NEW** |

→ **11 subjects, 5 new.**

**Minimum to close the P0s: 9 new PixelLab plates** (4 backdrops + 5 props),
against 44 for the naive route. That takes the product from 3 backgrounds /
12 subjects / **12 distinct scenes** to 7 backgrounds / 11 subjects /
**up to 22 distinct scenes** — every node visually its own place and its own
resource.

**Optional second tier, +7 plates:** a "deeper/older" treatment per
same-resource pair so `deep_tin_seam` ≠ `tin_seam`, `oldgrowth_frostpine` ≠
`frostpine_stand`, `heartwood_oak` ≠ `oak_stand`, `mill_garden` ≠
`meadow_patch`, `sheltered_frost_meadow` ≠ `rimefrost_hollow`,
`deep_hollow_thicket` ≠ `hollow_thicket`, `veiled_silkstrand` ≠
`silkstrand_thicket`. **Total 16 plates for full per-node distinctness.**

**Code-only, zero generations:** GH-02 (contact shadow), GH-04 routing,
GH-07 (skill-keyed one-shot), GH-10 (route `gallery_tin_lode`), GH-11,
GH-12 (guards), GH-13, GH-15. GH-08's debris needs 3–4 tiny frames per
profession (≈9–12 small plates) or can be code-rendered as a deliberate
temporary.

### 10.4 Ordering recommendation

1. **GH-02** — one widget change, applies to all 22 nodes and all 3 craft
   stations, and is the single highest ratio of perceived fix to work.
2. **GH-12** — put the guard in *before* the art, so the new routing cannot
   regress and the 12/22 gap can never silently regrow.
3. **GH-01 + GH-04** — 5 props, closes the icon-in-a-scene P0.
4. **GH-03** — 4 backdrops, closes the regional P0.
5. **GH-05 / GH-06** — needs an owner ruling on density before any plate is
   generated at a new scale; **decide before step 3**, or the 9 new plates
   are authored at a density that may then change.
6. **GH-07, GH-08** — the action beat.

**One decision blocks the art work:** GH-05, the pixel-density question. It is
not currently governed by any rule in `ART_DIRECTION.md`, and it determines
the native size of all 9 new plates. It should be raised as an
`OPEN_QUESTIONS` entry and answered by the owner before generation starts.

---

*Read-and-report only. No file in the product was modified by this audit.*
