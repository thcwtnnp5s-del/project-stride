# FOUNDATION J — Enemy Visual Uniqueness Audit

**Milestone:** Visual / Audio / World Overhaul 01 (VAWO01), Wave 0
**Agent:** FOUNDATION-J
**Date:** 2026-09-01
**Branch at audit:** `presentation-combat-evolution-01` @ `6d41bce`
**Mode:** read-and-report. No file in the repository was modified except this one.

---

## 0. Headline

The roster is **13 enemies**. It is drawn by **9 sprite families**. Four enemies
— every Veteran and the awakened boss — are served the *pixel-identical* art of
another enemy: `enemy.old_grey` is the Forest Wolf, frame for frame, at the same
size, at the same speed, in the same palette. That is **31 % of the roster with
zero visual identity of its own**.

Of the nine families that do have art:

- **7 of 9 have no flinch (hit) track at all.** Only the Cave Goblin and the
  Hollow Guardian visibly react to being struck. The other seven jerk 6 dp
  sideways over 150 ms.
- **8 of 9 have no heavy-strike track.** Five enemies deliver a doubled-damage
  telegraphed heavy blow every third turn; only the Guardian family plays a
  different animation for it. The Foreman's tell line says *"It hefts a broken
  drill-arm overhead"* while the sprite plays an ordinary goblin jab.
- **Timing is very nearly global.** Seven of nine attack tracks are 9 frames at
  10 fps. Six of nine produce an *identical* 900 ms strike segment. Six of nine
  idles are 7 frames at 6 fps ping-pong. Six of nine defeats are 7 frames at
  8 fps.
- **Scale is authored, not data-driven, and it inverts on the encounter card.**
  In the fight the Bear is genuinely 98 dp against the Wolf's 56 dp. On the
  Adventure encounter card the Oakback Bear renders at **50 dp — the *smallest*
  creature in the game**, smaller than the wolf it is supposed to dwarf — because
  a fixed 120 dp band demotes its 76-px canvas to x1 while the wolf keeps x2.
- **The two closest silhouettes are 69.5 % and 68.8 % identical** by aligned mask
  IoU (Wolf-Lynx, Boar-Ram).

Palettes are *not* recolours — cross-family palette overlap never exceeds the
0.30 Jaccard threshold. The uniqueness problem here is **silhouette, state
coverage, motion amplitude and timing**, not colour.

PixelLab balance at audit: **10,000 generations remaining this cycle**
(Tier 3, resets 2026-10-01, 0 used). Budget is not the constraint on this plan.

---

## 1. The enemy roster — every entry

Source: `assets/content/v1/enemies.json` (schemaVersion 1, 13 entries).
Schema: `packages/stride_core/lib/src/content/definitions.dart:916`.

`Enc/visit` = `encountersPerVisit`. `Tier` is derived: **Normal** = plain entry,
**Veteran** = carries `requiresKnownEnemy`, **Boss** = `isBoss: true`.

| # | id | Display name | Location | Tier | HP | Atk | Def | Behaviour | XP | Enc/visit | Signature drop |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `enemy.forest_wolf` | Forest Wolf | Whispering Woods | Normal | 20 | 4 | 0 | flurry | 30 | 2 | `item.pristine_wolf_fang` @8 % |
| 2 | `enemy.wild_boar` | Wild Boar | Whispering Woods | Normal | 30 | 6 | 2 | steady | 45 | 2 | `item.great_tusk` @8 % |
| 3 | `enemy.oakback_bear` | Oakback Bear | Whispering Woods | Normal (high-danger mark) | 55 | 11 | 3 | guarded | 120 | 1 | none |
| 4 | `enemy.cave_goblin` | Cave Goblin | Stonefall Mine | Normal | 32 | 8 | 3 | steady | 60 | 2 | `item.goblin_toolhead` @8 % |
| 5 | `enemy.salamander` | Salamander | Stonefall Mine | Normal | 34 | 8 | 2 | guarded | 70 | 2 | `item.ember_core` @8 % |
| 6 | `enemy.scree_crawler` | Scree Crawler | Stonefall Mine | Normal | 34 | 6 | 6 | steady | 70 | 2 | none |
| 7 | `enemy.frost_lynx` | Frost Lynx | Frostmere | Normal | 30 | 9 | 2 | flurry | 80 | 2 | `item.frost_claw` @6 % |
| 8 | `enemy.mountain_ram` | Mountain Ram | Frostmere | Normal | 36 | 7 | 4 | steady | 70 | 2 | `item.pristine_horn` @8 % |
| 9 | `enemy.hollow_guardian` | Hollow Guardian | Forgotten Hollow | **Boss** | 60 | 11 | 4 | guarded | 150 | 1 | `item.hollow_sigil` @100 % |
| 10 | `enemy.old_grey` | Old Grey | Whispering Woods | **Veteran** (of #1) | 48 | 13 | 4 | flurry | 140 | 1 | `item.wolf_pelt` x2 @100 % |
| 11 | `enemy.gallery_foreman` | Foreman of the Broken Gallery | Stonefall Mine | **Veteran** (of #4) | 60 | 15 | 5 | guarded | 150 | 1 | `item.scrap_metal` x2 @100 % |
| 12 | `enemy.rimeclaw_matriarch` | Rimeclaw Matriarch | Frostmere | **Veteran** (of #7) | 52 | 14 | 5 | flurry | 150 | 1 | `item.lynx_pelt` x2 @100 % |
| 13 | `enemy.guardian_awakened` | The Guardian, Awakened | Forgotten Hollow | **Boss / Veteran** (of #9) | 72 | 14 | 5 | guarded | 150 | 1 | `item.hollow_root` x3 @100 % |

**Total: 13.** Normal 8 · Veteran 4 · Boss 2 (one of which, #13, is also a
Veteran).

Behaviour distribution — this is what the animation has to say out loud:

| Behaviour | Meaning in the engine | Enemies |
|---|---|---|
| `flurry` | **two** strikes per round | wolf, lynx, old_grey, matriarch (4) |
| `steady` | one strike per round | boar, goblin, crawler, ram (4) |
| `guarded` | one strike; **every third turn is a heavy**, `max(1, 2*atk - def)`, telegraphed a round ahead (`combat_rules.dart:233-240`) | bear, salamander, hollow_guardian, foreman, guardian_awakened (5) |

There is **no `region` and no `tier` field** on locations
(`assets/content/v1/locations.json` carries `terrain`, `isSafe`,
`developmentState`, `connections`). Region grouping below is by location.

**Encounter traffic** (encounters offered per visit, by location, with step
distance from the start town):

| Location | Terrain | Steps from Haven's Rest | Enemies | Encounters/visit |
|---|---|---|---|---|
| Whispering Woods | forest | 500 (nearest, hub-adjacent) | wolf, boar, bear, old_grey | **6** |
| Stonefall Mine | foothills | 1,400 direct / 1,000 via Woods | goblin, salamander, crawler, foreman | **7** |
| Frostmere | alpine | 3,000 from the Mine (deepest) | lynx, ram, matriarch | **5** |
| Forgotten Hollow | forest | 2,400 from the Woods | hollow_guardian, guardian_awakened | **2** |

The Whispering Woods is the cheapest location to reach and is where every player
begins; the Forest Wolf and the Wild Boar are, by a wide margin, the two
creatures a player sees most.

---

## 2. How an enemy id becomes sprites

**File:** `lib/ui/icons/combat_assets.dart` (751 lines).
There is **no runtime manifest**. The mapping is a hand-written Dart switch over
the content id, generated once from the PixelLab manifests and frozen.

Frame paths are built by convention, `combat_assets.dart:80-86`:

```dart
const String _art = 'assets/art/v1/combat';

/// `combat/<id>_f0.png … <id>_f{count-1}.png`.
List<String> _frames(String id, int count) => List<String>.generate(
  count,
  (int i) => '$_art/${id}_f$i.png',
  growable: false,
);
```

The id-to-art resolution, `combat_assets.dart:702-722`:

```dart
  /// The art for [enemy], or `null` for an enemy the table does not know —
  /// the stage then draws the Traveler alone against the backdrop, with the
  /// figures still exact, rather than crashing on a content pack's new enemy.
  static CombatantArt? enemyFor(ContentId enemy) => switch (enemy.value) {
    'enemy.forest_wolf' => wolf,
    'enemy.cave_goblin' => goblin,
    'enemy.hollow_guardian' => guardian,
    'enemy.frost_lynx' => lynx,
    'enemy.wild_boar' => boar,
    'enemy.mountain_ram' => ram,
    'enemy.salamander' => salamander,
    'enemy.oakback_bear' => bear,
    'enemy.scree_crawler' => crawler,
    // Veteran Hunts (`DECISIONS/0028`): named elites reuse their species'
    // full combat set — zero generations; the hold-hit-pose precedent covers
    // withheld frames.
    'enemy.old_grey' => wolf,
    'enemy.gallery_foreman' => goblin,
    'enemy.rimeclaw_matriarch' => lynx,
    'enemy.guardian_awakened' => guardian,
    _ => null,
  };
```

Backdrops resolve separately, and *do* have a true fallback
(`combat_assets.dart:238-243`): `location.stonefall_mine`, `forgotten_hollow`,
`frostmere` are named, `_ => backdropForest`.

**Fallback count.**

- Enemies that fall through to the `null` art fallback (Traveler swings at
  empty air): **0 of 13**. Every shipped enemy is named in the switch.
- Enemies that fall through to **another enemy's complete art set**: **4 of 13
  (31 %)** — `old_grey`->wolf, `gallery_foreman`->goblin,
  `rimeclaw_matriarch`->lynx, `guardian_awakened`->guardian.
- Locations that fall through to `backdropForest`: 1 of 5 (`havens_rest`, which
  is safe and never fights) — so effectively 0.

Only **two** call sites consume enemy art in the whole app:

| Call site | What it draws |
|---|---|
| `lib/ui/screens/combat/combat_stage.dart:259` | the fight |
| `lib/ui/screens/adventure/encounter_card.dart:222` | the pre-fight encounter card |

Geometry is not per-enemy data either — it is fields on each `CombatantArt`
literal: `canvasWidth/Height`, `anchorRow`, `footprint`, `impactRise`,
`strikeFrame`. Footprints are the one genuinely generated table
(`lib/ui/icons/sprite_footprints.dart`, header: *"GENERATED by
Scripts/art/package-art.js — do not edit by hand"*).

---

## 3. Sprite asset inventory and the missing-state table

**Directory:** `assets/art/v1/combat/` — 262 PNGs, declared in `pubspec.yaml:188`
as a whole directory (`- assets/art/v1/combat/`), so *every* file ships whether
referenced or not.

Composition: 4 backdrops (192x96) · 10 effect frames (fx_impact 5, fx_bite 5, 32²)
· 28 Traveler frames · **220 enemy frames**, of which **209 are referenced** and
**11 are dead weight in the bundle** (`wolf_hit_f0..3`, `guardian_defeat_f0..6`
— packaged, deliberately withheld, still shipped).

### 3.1 Every enemy track, measured

Dimensions and opaque extents measured with `Scripts/art/png.js` (`load`,
`bounds`), union across each sequence. "Body" is the union opaque box.

| Track | Frames | fps | Loop | Canvas | Opaque box (union) | Body w x h | Distinct opaque colours |
|---|---|---|---|---|---|---|---|
| `wolf_idle` | 8 | 6 | pingpong | 56x56 | 7,12 .. 51,40 | 45x29 | 16 |
| `wolf_attack` | 9 | 10 | once | 56x56 | 4,12 .. 51,40 | 48x29 | 16 |
| `wolf_hit` | 4 | — | *unreferenced* | 56x56 | 9,8 .. 51,41 | 43x34 | 15 |
| `wolf_defeat` | 7 | 8 | once | 56x56 | 5,12 .. 51,41 | 47x30 | 17 |
| `lynx_idle` | 7 | 6 | pingpong | 56x56 | 10,13 .. 51,39 | 42x27 | 22 |
| `lynx_attack` | 9 | 10 | once | 56x56 | 3,13 .. 52,39 | 50x27 | 31 |
| `lynx_defeat` | 7 | 8 | once | 56x56 | 5,13 .. 51,40 | 47x28 | 25 |
| `boar_idle` | 7 | 6 | pingpong | 56x56 | 4,8 .. 52,43 | 49x36 | 18 |
| `boar_attack` | 9 | 10 | once | 56x56 | 3,7 .. 53,43 | 51x37 | 19 |
| `boar_defeat` | 7 | 8 | once | 56x56 | 3,8 .. 53,44 | 51x37 | 18 |
| `ram_idle` | 7 | 6 | pingpong | 56x56 | 7,9 .. 50,42 | 44x34 | 23 |
| `ram_attack` | 9 | 10 | once | 56x56 | 5,9 .. 48,42 | 44x34 | 24 |
| `ram_defeat` | 7 | 8 | once | 56x56 | 4,9 .. 52,42 | 49x34 | 23 |
| `bear_idle` | 7 | **5** | pingpong | **76x76** | 2,12 .. 72,61 | 71x50 | 24 |
| `bear_attack2` | 9 | **8** | once | 76x76 | 4,6 .. 74,61 | 71x56 | 24 |
| `bear_defeat` | 7 | **6** | once | 76x76 | 2,12 .. 74,61 | 73x50 | 24 |
| `goblin_idle` | 7 | 6 | pingpong | 56x56 | 17,8 .. 38,46 | 22x39 | 40 |
| `goblin_attack` | 9 | 10 | once | 56x56 | 7,9 .. 49,46 | 43x38 | 40 |
| `goblin_hit` | 4 | 10 | pingpong | 56x56 | 10,10 .. 46,46 | 37x37 | 40 |
| `goblin_defeat` | 7 | 8 | once | 56x56 | 10,10 .. 45,46 | 36x37 | 40 |
| `crawler_idle` | 7 | 6 | pingpong | **48x48** | 1,6 .. 46,40 | 46x35 | 54 |
| `crawler_attack` | 9 | 10 | once | 48x48 | 1,6 .. 46,40 | 46x35 | 54 |
| `salamander_idle` | 7 | 6 | pingpong | 56x56 | 3,5 .. 52,50 | 50x46 | 50 |
| `salamander_attack` | 9 | 10 | once | 56x56 | 3,5 .. 52,50 | 50x46 | 50 |
| `salamander_defeat` | 7 | 8 | once | 56x56 | 3,5 .. 52,50 | 50x46 | 50 |
| `guardian_idle` | 7 | **4** | pingpong | **96x96** | 30,11 .. 69,83 | 40x73 | 40 |
| `guardian_swipe` (= normal attack) | 9 | 8 | once | 96x96 | 24,13 .. 74,83 | 51x71 | 40 |
| `guardian_attack` (= **heavy**) | 7 | 6 | once | 96x96 | 18,9 .. 63,83 | 46x75 | 40 |
| `guardian_hit` | 4 | 8 | once | 96x96 | 28,12 .. 77,83 | 50x72 | 40 |
| `guardian_defeat` | 7 | — | *unreferenced* | 96x96 | 19,13 .. 79,83 | 61x71 | 40 |

Traveler, for reference: `traveler_combat_idle` 9f@6 ping-pong 80x64 ·
`traveler_attack` 4f@10 80x64 · `traveler_hit` 6f@8 64x64 ·
`traveler_stagger` 9f@8 56x64.

### 3.2 The missing-animation-state table

**Legend:** YES = authored *and wired* · WITHHELD = art exists but is
deliberately withheld and not wired · NONE = never authored / no usable art.

| Enemy | idle | attack | **heavy** | **hit / flinch** | defeat | States wired |
|---|---|---|---|---|---|---|
| Forest Wolf | YES 8f | YES 9f | NONE | WITHHELD — 4f on disk, unreferenced | YES 7f | 3 / 5 |
| Frost Lynx | YES 7f | YES 9f | NONE | WITHHELD — candidate read as a prowl | YES 7f | 3 / 5 |
| Wild Boar | YES 7f | YES 9f | NONE | **NONE — never authored** | YES 7f | 3 / 5 |
| Mountain Ram | YES 7f | YES 9f | NONE | WITHHELD — 4f, head-turn only | YES 7f | 3 / 5 |
| Oakback Bear | YES 7f | YES 9f (`attack2`; round-1 `bear_attack` withheld) | **NONE — but it is `guarded`** | **NONE — never authored** | YES 7f | 3 / 5 |
| Salamander | YES 7f | YES 9f | **NONE — but it is `guarded`** | **NONE — never authored** | YES 7f | 3 / 5 |
| Cave Goblin | YES 7f | YES 9f | NONE | YES 4f | YES 7f | **4 / 5** |
| Scree Crawler | YES 7f | YES 9f | NONE | **NONE — never authored** | WITHHELD — candidate 7f, **fall-out stand-in** | **2 / 5** |
| Hollow Guardian | YES 7f | YES 9f | YES 7f | YES 4f | WITHHELD — 7f on disk, holds hit pose | **4 / 5** |
| *Old Grey* | *wolf* | *wolf* | NONE | WITHHELD | *wolf* | 3 / 5 (borrowed) |
| *Foreman of the Broken Gallery* | *goblin* | *goblin* | **NONE — but it is `guarded`** | *goblin* | *goblin* | 4 / 5 (borrowed) |
| *Rimeclaw Matriarch* | *lynx* | *lynx* | NONE | WITHHELD | *lynx* | 3 / 5 (borrowed) |
| *The Guardian, Awakened* | *guardian* | *guardian* | *guardian* | *guardian* | WITHHELD | 4 / 5 (borrowed) |

**Totals across the nine families:** flinch present **2/9** · heavy present
**1/9** · defeat present **7/9** · complete four-state set **0/9** (the Goblin
lacks a heavy it never needs; the Guardian lacks a defeat).

**The heavy-strike hole is the sharpest one.** Five enemies use `guarded`
behaviour and therefore land a doubled-damage heavy every third turn. Three of
them — **Oakback Bear, Salamander, Foreman of the Broken Gallery** — have no
heavy track, so `combat_choreography.dart:249` falls back:

```dart
        final CombatTrack? atk = b.heavy
            ? (enemy?.heavy ?? enemy?.attack)
            : enemy?.attack;
```

The blow that hits twice as hard is *the same animation*. The only difference on
screen is `heavyFlash`, which brightens the telegraph text line for 400 ms
(`combat_stage.dart`, `flash = s.heavyFlash && elapsed < 400ms`). The content
already writes the pose the art does not have — the Foreman's tell line is
*"It hefts a broken drill-arm overhead before the crushing blow falls."*

---

## 4. Duplicates, near-duplicates and provenance

MD5 over all 262 PNGs in `assets/art/v1/combat/`.

### 4.1 Exact duplicates — 9 groups, 26 files

| MD5 (first 10) | Files |
|---|---|
| `9a3f315e0b` | `bear_attack2_f0` `bear_defeat_f0` `bear_idle_f0` |
| `b74c7d4954` | `boar_attack_f0` `boar_defeat_f0` `boar_idle_f0` |
| `992e7150de` | `crawler_attack_f0` `crawler_idle_f0` |
| `add095fe1e` | `goblin_attack_f0` `goblin_defeat_f0` `goblin_hit_f0` `goblin_idle_f0` |
| `6c14ec33a4` | `guardian_attack_f0` `guardian_defeat_f0` `guardian_hit_f0` `guardian_idle_f0` `guardian_swipe_f0` |
| `51265ca67d` | `lynx_attack_f0` `lynx_defeat_f0` `lynx_idle_f0` |
| `2d092c7ba0` | `ram_attack_f0` `ram_defeat_f0` `ram_idle_f0` |
| `b91697d5a3` | `salamander_attack_f0` `salamander_defeat_f0` `salamander_idle_f0` |
| `28fdb56266` | `wolf_attack_f0` `wolf_defeat_f0` `wolf_hit_f0` `wolf_idle_f0` |

**Every group is intra-species.** This is the PixelLab `create_character` ->
`animate_character` provenance showing through: each track begins on the same
base pose, and the pack's packaging step palette-remaps each track to its own
f0. It is benign, and it is also why the first frame of a defeat looks exactly
like the first frame of an idle — the collapse has one fewer frame of runway
than the count suggests.

**There are zero exact duplicate frames between different species.** Nothing in
this repository is a byte-identical shared sprite.

### 4.2 Recolour check — negative

Palette Jaccard over the exact opaque RGB sets of all nine idle tracks: **no
pair exceeds 0.30**. Dominant colours are genuinely separate families:

| Family | Top 3 opaque colours by pixel count |
|---|---|
| wolf | `#040301` `#3a3534` `#3e3938` (near-black / charcoal) |
| lynx | `#534d48` `#4f4944` `#080605` (warm grey) |
| boar | `#5f3e4a` `#63404a` `#080606` (plum-brown) |
| ram | `#e6dcd3` `#cdb8a8` `#68444c` (bone white) |
| bear | `#784430` `#7e4530` `#511e24` (red-brown) |
| goblin | `#000000` `#301617` `#5a4745` |
| crawler | `#000000` `#6d7483` `#95a1a4` (cold slate) |
| salamander | `#000000` `#cfd5bb` `#66614d` (pale sage) |
| guardian | `#271826` `#010109` `#34222e` (violet-black) |

**The owner's "pointless recolours" objection does not apply to the base
species.** It applies squarely to the four Veterans, which are not even
recolours — they are the *same file*.

### 4.3 The real duplication: the Veteran tier

| Veteran | Serves | Differs from its base in the picture by |
|---|---|---|
| Old Grey (48 HP, 13 atk) | Forest Wolf (20 HP, 4 atk) | **nothing** — same frames, same 56² canvas, same 2333 ms idle, same 900 ms attack, same palette |
| Foreman of the Broken Gallery (60/15) | Cave Goblin (32/8) | **nothing** |
| Rimeclaw Matriarch (52/14) | Frost Lynx (30/9) | **nothing** |
| The Guardian, Awakened (72/14) | Hollow Guardian (60/11) | **nothing** |

`DECISIONS/0028` recorded this as a deliberate zero-generation trade. It was
sound at a balance of 25 generations. At **10,000** it is the single largest
uniqueness debt in the game.

---

## 5. Silhouette distinctness

Method: idle frame 0, alpha>8 mask, aligned on each sprite's own **footprint
centre and anchor row** — i.e. exactly where the stage stands them — then
intersection-over-union.

### 5.1 Body plans

| Body plan | Members | Verdict |
|---|---|---|
| **Quadruped, long-bodied, head-forward** | Forest Wolf, Frost Lynx, Wild Boar, Mountain Ram (+ Old Grey, Rimeclaw Matriarch as copies) | **COLLIDING.** 4 of 9 families, and the two worst pairs in the game are both inside it. |
| **Quadruped, heavy, rearing** | Oakback Bear | distinct (71x50 body, 2x the mass of any other quadruped) |
| **Biped, upright, humanoid** | Cave Goblin (+ Foreman) | distinct — the only tall-narrow 22x39 idle |
| **Biped, monolithic, stone** | Hollow Guardian (+ Awakened) | distinct — 40x73, twice anything else's height |
| **Low serpentine / amphibian** | Salamander | distinct *in outline* but see §5.3 |
| **Low insectoid / arthropod** | Scree Crawler | distinct in outline |

### 5.2 Every silhouette collision, named

Aligned-mask IoU, idle f0. Anything above ~55 % reads as "the same animal in a
different colour" at 56 px:

| Pair | IoU | Verdict |
|---|---|---|
| **Forest Wolf / Frost Lynx** | **69.5 %** | **COLLISION.** 45x29 vs 42x27 body, both head-forward four-legged profiles, both grey-family. Two different regions' signature predator. |
| **Wild Boar / Mountain Ram** | **68.8 %** | **COLLISION.** 49x36 vs 44x34. Both are the "steady, one solid blow" bulk quadruped of their region. The Ram's horns are the only differentiator and they are 3-4 px of the outline. |
| **Forest Wolf / Mountain Ram** | **59.8 %** | **COLLISION**, cross-region. |
| Oakback Bear / Salamander | 58.4 % | **BORDERLINE.** Both are wide low masses; the bear survives on scale (71x50 vs 50x46 — only 1.5x larger, not the 3x the fiction implies). |
| Frost Lynx / Mountain Ram | 49.2 % | acceptable at size |
| Scree Crawler / Salamander | 46.0 % | **WATCH.** Both are the Mine/Hollow's low armoured mass; RCP01's own blind QA flagged that "the armoured-bug families carry identity risks (gargoyle / rock-with-legs)". |
| Wild Boar / Scree Crawler | 42.7 % | acceptable |
| Cave Goblin / everything | <= 36.7 % | **clean** — the only reliably distinct mid-size family |
| Hollow Guardian / everything | below the top 15 | **clean** |

**Summary: 3 outright collisions and 2 borderline pairs, all of them inside the
quadruped group, which is 4 of 9 families and — counting the two Veterans that
copy it — 6 of 13 enemies.**

### 5.3 A second-order tell: the Salamander does not move

Per-track motion, measured as mean silhouette change between consecutive frames
as a fraction of union pixels, plus how far the opaque box travels across the
track:

| Track | Mean delta | Peak delta | Left travel | Top travel |
|---|---|---|---|---|
| `salamander_attack` | **4.7 %** | 9.2 % | **0 px** | **0 px** |
| `salamander_idle` | 4.0 % | 7.3 % | 1 px | 1 px |
| `crawler_attack` | **9.2 %** | 12.1 % | 1 px | 2 px |
| `crawler_idle` | 7.9 % | 11.9 % | 0 px | 2 px |
| `bear_idle` | 4.9 % | 7.8 % | 6 px | 1 px |
| `goblin_attack` | 29.8 % | 43.9 % | 11 px | 4 px |
| `wolf_attack` | 28.3 % | 38.1 % | 8 px | 7 px |
| `lynx_attack` | 31.3 % | 40.4 % | 11 px | 7 px |
| `boar_attack` | 19.9 % | 33.3 % | 3 px | 4 px |
| `ram_attack` | 20.7 % | 29.5 % | 6 px | 7 px |
| `bear_attack2` | 16.7 % | 23.8 % | 6 px | 8 px |
| `guardian_swipe` | 20.1 % | 29.4 % | 9 px | 9 px |
| `guardian_attack` (heavy) | 17.3 % | 21.3 % | 16 px | 10 px |

The Salamander's content says *"Heat gathers along its back before the scalding
lunge."* Its attack track moves **4.7 % of its own pixels and travels zero
pixels in any direction** — it is the least animated thing in the game, less than
most idles. The Scree Crawler's *"plates grind shut and it simply keeps
coming"* is nearly as static. Both are Stonefall Mine enemies, seen 2x per visit
in the busiest location by encounter count.

---

## 6. Scale

### 6.1 In the fight — authored, not data-driven, and actually correct

There is **no per-enemy display-scale field anywhere.** `CombatStage.scale`
defaults to `2` (`combat_stage.dart:85`) and is applied uniformly to the
backdrop, both figures, both effect canvases and the ground row
(`combat_stage.dart:706-757`). Every sprite is drawn at exactly x2, nearest
neighbour.

Apparent scale therefore comes entirely from the **authored canvas plus the
opaque extent above the anchor row**. That part is genuinely differentiated:

| Enemy | Canvas | Anchor row | Opaque top | Rows above ground | **On-screen height @x2** |
|---|---|---|---|---|---|
| Frost Lynx | 56² | 39 | 13 | 26 | **52 dp** |
| Forest Wolf | 56² | 40 | 12 | 28 | **56 dp** |
| Mountain Ram | 56² | 42 | 9 | 33 | **66 dp** |
| Scree Crawler | 48² | 40 | 6 | 34 | **68 dp** |
| Wild Boar | 56² | 43 | 8 | 35 | **70 dp** |
| Cave Goblin | 56² | 46 | 8 | 38 | **76 dp** |
| Salamander | 56² | 50 | 5 | 45 | **90 dp** |
| Oakback Bear | 76² | 61 | 12 | 49 | **98 dp** |
| Hollow Guardian | 96² | 83 | 11 | 72 | **144 dp** |

**In combat the Bear does render larger than the Lynx** — 98 dp against 52 dp,
a 1.9x ratio. The Guardian is 2.8x the Lynx. That reads.

Two problems remain even here:

1. **The Salamander is 90 dp — the third-largest creature in the game**, larger
   than the Goblin and 92 % of the Bear, for a 34 HP / 8 atk mid-tier fight. Its
   `anchorRow: 50` on a 56 canvas leaves almost no ground clearance, so its
   raised head fills the frame.
2. **Every Veteran renders at exactly its base species' size.** Old Grey, with
   2.4x the wolf's HP and 3.25x its attack, is 56 dp — identical.

### 6.2 On the encounter card — the scale ordering **inverts**

`lib/ui/screens/adventure/encounter_card.dart:405-414`:

```dart
  /// The band's interior height. 120 seats the x2 wolf-class figures exactly
  /// (56 canvas + 4 shadow bleed, x2) and keeps the card compact ...
  static const double height = 120;

  static int scaleFor(CombatTrack idle) =>
      (idle.canvasHeight + ContactShadowSpec.bleed) * 2 <= height ? 2 : 1;
```

With `ContactShadowSpec.bleed = 4` (`grounded_sprite.dart:72`), the 120 dp band
gives x2 to every 48- and 56-px canvas and demotes the 76- and 96-px canvases to
x1. Resulting body heights *on the card the player reads before choosing the
fight*:

| Enemy | Canvas | Card scale | Body rows | **Card height** |
|---|---|---|---|---|
| **Oakback Bear** | 76² | **x1** | 50 | **50 dp — smallest in the game** |
| Frost Lynx | 56² | x2 | 27 | 54 dp |
| Forest Wolf | 56² | x2 | 29 | 58 dp |
| Mountain Ram | 56² | x2 | 34 | 68 dp |
| Scree Crawler | 48² | x2 | 35 | 70 dp |
| Wild Boar | 56² | x2 | 36 | 72 dp |
| **Hollow Guardian** | 96² | **x1** | 73 | **73 dp** |
| Cave Goblin | 56² | x2 | 39 | 78 dp |
| **Salamander** | 56² | x2 | 46 | **92 dp — largest in the game** |

**This is a hard defect.** On the Adventure encounter card:

- the **Oakback Bear** (55 HP, the Woods' high-danger mark) is drawn **smaller
  than the Forest Wolf** it is meant to dwarf, and smaller than every other
  creature in the game;
- the **Hollow Guardian**, the boss, is drawn **smaller than the Salamander**;
- the **Salamander**, a mid-tier Mine fight, is the largest thing the player ever
  sees on a card.

The scale ordering the combat stage gets right, the card reverses. This is
fixable with zero generations (see §10, Batch 0).

---

## 7. Motion and timing

**Playback code:** `lib/ui/screens/combat/combat_choreography.dart` (359 lines),
frame selection in `AmbientTrack.frameAt` (`lib/ui/components/ambient_scene.dart:88`).

### 7.1 The timing constants — all global

```dart
/// How long a figure without a flinch track recoils.
const Duration recoilDuration = Duration(milliseconds: 150);

/// How long a figure with **no defeat and no flinch track** takes to sink and
/// fade on the killing blow. See the `WonBeat` case.
const Duration _fallOut = Duration(milliseconds: 500);

/// How far it sinks, in logical pixels, over that time.
const int fallOutDrop = 6;

/// The window over which an HP bar tweens after a blow lands.
const Duration _hpTween = Duration(milliseconds: 250);

/// The least a strike segment runs on after the blow lands.
const Duration _afterBlow = Duration(milliseconds: 400);

/// How long the fallen enemy's pose stands before the sequence ends ...
const Duration _wonHold = Duration(milliseconds: 700);

/// The beat after the Traveler's stagger has reached its kneel ...
const Duration _lostSettle = Duration(milliseconds: 500);

/// The planted beat a brace holds before the enemy's halved reply ...
const Duration _bracedHold = Duration(milliseconds: 350);
```

Plus, in `combat_stage.dart`: `idleVisit = Duration(seconds: 8)`,
`_fallOutWindow = 500 ms`, recoil amplitude `(6 * f).round()` — **6 dp, for every
figure, regardless of mass**. The Traveler recoils -6 dp from a bear's swipe and
-6 dp from a wolf's nip.

**Not one of these constants is per-enemy, and there is no per-enemy timing data
anywhere in `enemies.json`.**

### 7.2 What is per-enemy: the fps and strike frame on each track

The library doc is explicit and correct about the intent — *"Tracks play at the
manifest's own fps: the art was timed by its author."* So timing *is* nominally
per-enemy. In practice the authoring converged on one template:

| Attack track shape | Enemies |
|---|---|
| **9 frames @ 10 fps = 900 ms** | wolf, lynx, goblin, boar, ram, crawler, salamander — **7 of 9** |
| 9 frames @ 8 fps = 1125 ms | bear, guardian (swipe) |

| Idle track shape | Enemies |
|---|---|
| **7 frames @ 6 fps ping-pong = 2000 ms** | lynx, goblin, boar, ram, crawler, salamander — **6 of 9** |
| 8 @ 6 = 2333 ms | wolf |
| 7 @ 5 = 2400 ms | bear |
| 7 @ 4 = 3000 ms | guardian |

| Defeat track shape | Enemies |
|---|---|
| **7 frames @ 8 fps = 875 ms** | wolf, lynx, goblin, boar, ram, salamander — **6 of 9** |
| 7 @ 6 = 1167 ms | bear |
| (none) | crawler, guardian |

### 7.3 The segment durations the player actually experiences

Derived from the constants above and each track's fps/strike frame:

| Enemy | Idle loop | Attack | Blow lands at | **Player-strike segment** | **Enemy-strike segment** | **Heavy segment** | **Victory segment** |
|---|---|---|---|---|---|---|---|
| Forest Wolf | 2333 ms | 900 ms | 500 ms | **617 ms** | **900 ms** | (= normal) | 1575 ms |
| Frost Lynx | 2000 ms | 900 ms | 600 ms | **617 ms** | 1000 ms | (= normal) | 1575 ms |
| Wild Boar | 2000 ms | 900 ms | 400 ms | **617 ms** | **900 ms** | (= normal) | 1575 ms |
| Mountain Ram | 2000 ms | 900 ms | 500 ms | **617 ms** | **900 ms** | (= normal) | 1575 ms |
| Salamander | 2000 ms | 900 ms | 400 ms | **617 ms** | **900 ms** | **(= normal)** — guarded | 1575 ms |
| Scree Crawler | 2000 ms | 900 ms | 400 ms | **617 ms** | **900 ms** | (= normal) | 1200 ms (fall-out) |
| Cave Goblin | 2000 ms | 900 ms | 400 ms | 800 ms | **900 ms** | (= normal) | 1575 ms |
| Oakback Bear | 2400 ms | 1125 ms | 625 ms | **617 ms** | 1125 ms | **(= normal)** — guarded | 1867 ms |
| Hollow Guardian | 3000 ms | 1125 ms | 500 ms | 700 ms | 1125 ms | 1167 ms | 1200 ms (held hit pose) |

**Findings:**

- **The player-strike segment is 617 ms for 7 of 9 enemies** — identical to the
  millisecond. It is pinned by `lands (200 ms) + fx_impact (417 ms)`, because
  those seven enemies have no flinch track for the segment to accommodate. The
  player's own blow feels the same against every creature in the game bar two.
- **The enemy-strike segment is exactly 900 ms for 6 of 9.** Only the Lynx
  (1000 ms), Bear and Guardian (1125 ms) differ.
- **The victory beat is 1575 ms for 6 of 9** — six identical deaths.
- **The heavy blow has no timing of its own for 8 of 9**, including three enemies
  that actually throw one.
- Recoil is 150 ms / 6 dp for everyone. Fall-out is 500 ms / 6 dp for everyone.

**This is the defect the brief predicted.** Timing is nominally per-enemy and
factually near-uniform.

**Audio note (adjacent, for FOUNDATION-E):** `assets/audio/v1/sfx/` contains five
files — cooking, smithing, foraging, mining, woodcutting. **There is no combat
SFX at all**, so nothing differentiates the enemies by ear either.

---

## 8. The combat presentation state machine, phase by phase

Segments are built by `choreograph()` from committed `CombatBeat`s
(`combat_choreography.dart:180-357`) and played by one `AnimationController` in
`CombatStage` (`_Phase.idle` -> `_Phase.playing` -> `_Phase.spent`). Nothing reads
a clock; nothing decides a game fact.

| Phase | Beat / trigger | What is visible today | Duration |
|---|---|---|---|
| **ENGAGE** | `EncounterStartedBeat` | **Emits no segment at all** — *"The figures already stand where the view puts them."* The fight's entrance is a `StaggeredReveal` in `combat_screen.dart` (stage resolves, controls follow a beat later), keyed once per fight. Before that, the encounter card shows the enemy's idle for a 6 s bounded visit. | 0 ms of enemy-specific motion |
| **IDLE (between turns)** | no beat | Both figures loop their idle for `idleVisit = 8 s`, then hold frame 0 forever (`_Phase.spent`). | 8 s, then frozen |
| **PLAYER ATTACK** | `PlayerStruckBeat` | Traveler plays `traveler_attack` (4f@10). At f2 (200 ms): `fx_impact` bursts at the enemy's `impactRise`, the enemy plays its flinch **or**, for 7 of 9, jerks +6 dp for 150 ms, and the enemy HP bar tweens over 250 ms. | 617 ms (7/9), 800 ms goblin, 700 ms guardian |
| **BRACE** | `BracedBeat` | **No art exists.** A held, planted `traveler.idle` beat. The enemy does nothing. `DECISIONS/0027` and `RULES.md` A-1 forbid inventing a stance pose. | `_bracedHold` = 350 ms |
| **ENEMY ATTACK** | `EnemyStruckBeat` | Enemy plays `attack` (or `heavy ?? attack`). At its strike frame: the strike effect bursts on the Traveler — `fx_bite` for wolf / lynx / salamander / Old Grey / Matriarch, `fx_impact` for everyone else (`strikeEffectOf`) — the Traveler plays `traveler_hit` (6f@8, 750 ms, often cut short), and player HP tweens. `heavyFlash` brightens the telegraph text for 400 ms; the heavy haptic fires at `heavyImpactAt` (PCE01 fix). | 900 ms (6/9) · 1000 lynx · 1125 bear/guardian · 1167 guardian heavy |
| **HIT (target reaction)** | inside the two strike phases | Goblin and Guardian play a real flinch. Everyone else: a 6 dp translate decaying linearly over 150 ms. | 150 ms for 7/9 |
| **DEFEAT (enemy dies)** | `WonBeat` | Three different endings: (a) plays `defeat` and **holds the last frame** — 7 enemies; (b) no defeat but has a flinch, so it **holds the hit pose** — Guardian family; (c) neither, so **fall-out**: the last standing frame translates down 6 dp and fades to alpha 0, linearly, over 500 ms — Scree Crawler only. Then `_wonHold` = 700 ms before the panel is allowed. | 1575 ms (6/9) · 1867 bear · 1200 crawler · 1200 guardian |
| **VICTORY (panel)** | after the stage reports done | `RewardRaise` at `RewardTier.medium` rises over the stage; the log and locked controls stay visible beneath the scrim. | until dismissed |
| **RETREAT** | `RetreatedBeat` | **Nothing on screen.** A bare `_afterBlow` segment with `telegraph: false`. No enemy motion, no Traveler motion. | 400 ms |
| **LOST / driven back** | `LostBeat` | Two segments: Traveler plays `traveler_stagger` (9f@8, 1125 ms — stumble, drop, kneel) and **holds** the kneel; then the enemy idles, standing its ground over him, for `_lostSettle` = 500 ms. Defeat is retreat, never death (`RULES.md` P-7). | 1625 ms |
| **LOOT / heal** | `ConsumableUsedBeat` | A `+N` float rising 12 dp over the Traveler; HP tween over 300 ms. Drops themselves appear only in the result panel. | 600 ms |
| **ROUND END** | `RoundEndedBeat` | Turn chip and telegraph flag update. No motion. | 250 ms |

### What PCE01 added, and whether it generalises

Commit `fab04aa`, *"PCE01 combat: the armour finally speaks, and the crawler is
seen to die"*. The visual half added exactly one mechanism: **`enemyFallOut`**
(`combat_choreography.dart:305-330`, `combat_stage.dart:578-590`).

The defect it fixed: the Scree Crawler is the only enemy with **neither a defeat
track nor a flinch track**, so `held` was null, the victory segment collapsed to
a bare 400 ms, and the stage kept drawing its **idle** until the reward panel
covered it. The player struck the last blow and watched the thing keep breathing.

**Does it generalise?** Structurally yes, practically no.

- The *guard* generalises: `test/combat_visible_death_test.dart` iterates
  `CombatAssets.enemyFor` over all 13 enemy ids and asserts every one of them
  ends its own life with a track, a held pose, or a fall. A future content pack
  with partial art fails in CI rather than on a device. That is real and it holds.
- The *mechanism* fires for **exactly one enemy today** — the Scree Crawler is
  the only `fallOut == true` case. Withheld-defeat enemies (the Guardian family)
  were deliberately left holding their hit pose, because that is an authored
  decision the fallback must not override.
- It is explicitly **not an animation**: *"a translate and an alpha over an
  approved frame ... not a defeat animation and does not pretend to be one."* It
  raises the floor from "invisible" to "minimally legible". It does not make the
  Crawler's death *its own*.

So: PCE01 gave the roster a guaranteed floor and one deterministic stand-in. It
did not add per-enemy identity, and it was never meant to.

---

## 9. Unused creature art available for adoption

All paths under `GAME_BIBLE/ART/exploration/`. Motion figures measured the same
way as §5.3.

### 9.1 Two complete, unshipped enemy families

| Family | Frames on disk | Canvas | Motion (mean delta) | RCP01 disposition |
|---|---|---|---|---|
| **Adit Bat** — `REGIONAL_CONTENT_PACK_01/enemies/candidates/bat_{idle,attack,defeat}` | 7 + 9 + 7 = **23** | 40x40 | idle 6.4 %, attack 9.6 %, defeat 7.6 % | **CONCEPT-ONLY.** Blind QA: *"REJECT on identity (reads as gargoyle / small dragon; frontal head reads as an owl)"* then *"rebuild as a PixelLab character, wings open, before any further spend"* |
| **Hollow Weaver** (great spider) — `.../weaver_{idle,attack,attack2,defeat}` | 7 + 9 + 9 + 7 = **32** | 48x48 | idle 6.8 %, attack 12.4 %, attack2 15.5 %, defeat 11.1 % | **CONCEPT-ONLY.** Idle *"PASS WITH NOTE (dark on dark ground; spider/bug)"*; attack r1 indistinguishable from idle, r2 *"barely"* (Pass D), both **WITHHELD**; defeat withheld. Two attack rounds already spent. |

Both have full content proposals written (`CONTENT_PROPOSALS.md`):
`enemy.adit_bat` 18/5/0 · 35 xp · 2/visit · drops `item.copper_ore` @60 % (no new
material, "combat variety, not loot"); `enemy.hollow_weaver` 30/8/2 · 85 xp ·
2/visit · drops `item.gloom_silk` @45 % + `item.duskcap` @40 %, and Gloom Silk is
already specified as the grip wrap of a Bronze Longsword. **The Weaver would give
the Forgotten Hollow its only non-boss fight** — that location currently offers
2 encounters per visit and both are the same Guardian sprite.

Neither is adoptable as-is. Both need re-authoring, not integration.

### 9.2 Withheld tracks for enemies already shipped

| Track | Frames | Canvas | Motion | Why withheld | Adoptable? |
|---|---|---|---|---|---|
| `crawler_defeat` | 7 | 48² | mean **9.9 %**, top travels 3 px | *"legs curl slightly; no collapse read"* | **No** — the measurement confirms the verdict. Re-author. |
| `ram_hit` | 4 | 56² | mean **6.3 %**, top travels 1 px | *"the template flinch is a head turn only, the known quadruped-flinch failure"* | **No.** Confirms the quadruped-flinch problem is a template problem. |
| `bear_attack` (round 1) | 9 | 96² | mean 16.6 % | blind QA read it as a walk | **No** — superseded by `bear_attack2`. |
| `lynx_hit` (`WORLD_REWARD_DEPTH_01/combat/candidates/lynx_hit`) | 7 | 68² | mean **29.2 %**, peak 38.2 % | *"read as a prowl"* | **Marginal — worth a re-read.** It is the only withheld quadruped flinch with real amplitude, and it is on a 68² canvas that would need re-cropping to 56². |
| `wolf_hit` (**already packaged**, `assets/art/v1/combat/wolf_hit_f0..3`) | 4 | 56² | mean **46.7 %**, peak 67.9 % | *"three rounds of the wolf flinch never read"* | **Worth a fresh blind read.** It has by far the highest motion amplitude of any track in the game. It ships in the bundle today and is drawn by nothing. |
| `guardian_defeat` (**already packaged**, `guardian_defeat_f0..6`) | 7 | 96² | mean 22.9 %, top travels 25 px | *"the guardian's last defeat frames drifted into a quadruped"* | **No** — but re-authoring it is cheap and the boss currently dies by freezing. |

### 9.3 Other

`REGIONAL_CONTENT_PACK_01/fauna/candidates/` holds five ambient loops (bat, crow,
hare, songbird, butterfly) and 24/32-px stills, dispositioned **READY**. Not
enemies, but they are the region-flavour layer the combat backdrops lack.
`REGIONAL_CONTENT_PACK_01/enemies/candidates/_rot/` holds 5 rotation reference
stills (bear, boar x2, ram x2) usable as PixelLab reference inputs at no cost.

**Bottom line: there is no unused enemy art that can simply be adopted.** Every
withheld track was withheld for a reason the measurements confirm. The one real
exception worth a blind re-read is `wolf_hit`, which is already in the bundle.

---

## 10. Prioritised enemy art plan

**Ranking input:** encounter frequency (§1) x visual collision severity (§4, §5)
x missing states (§3.2).

### Batch 0 — Code and data only, **0 generations**

Do these first; they are free and one of them changes what the player sees more
than any single new sprite would.

| # | Fix | File | Why |
|---|---|---|---|
| 0.1 | **Fix the encounter-card scale inversion.** Raise `_EnemyStage.height` to ~160 dp, or scale by *body rows above the anchor* rather than by canvas height, so the Bear and Guardian are not demoted to x1. | `encounter_card.dart:405-414` | The Bear currently renders smaller than the Wolf and the boss smaller than the Salamander. Highest visible-impact fix in this report. |
| 0.2 | **Give the recoil per-enemy amplitude and duration.** 6 dp / 150 ms for a bear's swipe and a wolf's nip is the same lie in two directions. Derive from the enemy's `attack` stat or add explicit fields on `CombatantArt`. | `combat_choreography.dart:135`, `combat_stage.dart:509-513` | Costs nothing; differentiates 7 of 9 enemies at the moment of impact. |
| 0.3 | **Delete or wire the 11 unreferenced frames** (`wolf_hit`, `guardian_defeat`). Blind-re-read `wolf_hit` first (46.7 % mean motion, the liveliest track in the repo). | `pubspec.yaml:188`, `combat_assets.dart` | They ship in every build and draw nothing. |
| 0.4 | **Vary the per-track fps** on tracks that are already authored, where the manifest's figure was a template default rather than an authored choice. E.g. Boar attack at 9 fps, Ram at 8. Requires the manifest's author intent to be checked, not guessed. | `combat_assets.dart` | Breaks the 900 ms / 617 ms / 1575 ms uniformity for free. Flag as **UNRESOLVED** if the manifests do not record intent — this must not become a silent design decision (`RULES.md` G-3). |

### Batch 1 — **Veteran identity** (highest priority)

*The single largest uniqueness debt: 4 of 13 enemies with zero art of their own.*

| Enemy | New silhouette brief (the content already writes it) | Tracks |
|---|---|---|
| **Old Grey** | *"Scarred and patient, it feints where the young ones snapped"* — leaner, taller at the shoulder, one ear torn, ribs showing, tail low. Must not be the wolf shape at a different size. | idle, attack, hit, defeat |
| **Rimeclaw Matriarch** | *"She strikes twice from the flank, and the cold rides every blow"* — heavier ruff, longer ear tufts, rimed guard hairs, a wider stance than the Lynx. | idle, attack, hit, defeat |
| **Foreman of the Broken Gallery** | *"It hefts a broken drill-arm overhead"* — an asymmetric silhouette: one arm replaced by a drill, hunched, a head taller than the Goblin. **Needs a distinct heavy track** (it is `guarded`). | idle, attack, **heavy**, hit, defeat |
| **The Guardian, Awakened** | *"The whole chamber shakes as it draws both arms back"* — a wider, cracked, lit version on a **112² canvas** so it is visibly larger than the Hollow Guardian's 96². | idle, attack, heavy, hit, **defeat** |

**Constraints:** west-facing profile (the enemy stands at backdrop column 138 and
faces the Traveler at column 58). Canvases: 56² for Old Grey and Matriarch
(anchor 39-41), 64² for the Foreman (anchor ~50, taller than the goblin's 46),
112² for the Awakened (anchor ~97). Frame counts: idle 7, attack 9, heavy 7,
hit 4, defeat 7. **Deliberately break the template fps:** Old Grey idle @5 (older,
slower), Matriarch attack @12 (faster than the Lynx), Foreman attack @7 (heavier),
Awakened idle @3. Palette per family, remapped to that track's own f0.

**Generations:** 4 characters x (1 `create_character` + 4-5 `animate_character` +
2 re-rolls) = **28-40**.

### Batch 2 — **Quadruped silhouette break**

*Fixes the 69.5 % and 68.8 % collisions.*

| Enemy | What changes | Tracks |
|---|---|---|
| **Frost Lynx** | Re-author to a genuinely different body plan from the Wolf: shorter back, longer legs, upright cat carriage, pronounced ear tufts and cheek ruff, bobbed tail. Target < 45 % IoU against `wolf_idle`. | idle, attack, hit, defeat |
| **Mountain Ram** | Re-author for front-heavy mass: deep chest, low head carriage, **horns as 8-10 px of outline, not 3-4**. Target < 45 % IoU against `boar_idle`. | idle, attack, hit, defeat |

Leave the Wolf and Boar as the reference shapes — they are the ones the player
learns first, and they are cheaper to define *against* than to move.

**Constraints:** 56², anchor 39 (lynx) / 42 (ram), west profile, idle 7 / attack 9
/ hit 4 / defeat 7. Lynx attack @12 fps (flurry — it should feel faster than the
wolf's 10). Ram attack @8 with a longer wind-up (steady).

**Generations:** 2 x (1 create + 4 animate + 2-3 re-rolls) = **14-20**.

### Batch 3 — **The missing flinch and the missing deaths**

*7 of 9 enemies do not react to being hit; 2 of 9 do not die.*

| Track | Enemy | Note |
|---|---|---|
| hit x5 | Wolf, Boar, Bear, Salamander, Crawler | Lynx and Ram flinches are folded into Batch 2. **Do not use the animation template** — RCP01 recorded the failure mode explicitly: *"the template flinch is a head turn only, the known quadruped-flinch failure"*. Author key poses: weight thrown onto the hind legs, head snapped away, body compressed. |
| defeat x2 | Scree Crawler, Hollow Guardian | Crawler: legs must fold and the shell must drop to the ground line — the withheld candidate moves 9.9 % and travels 3 px. Guardian: it must topple; the round-1 candidate *"drifted into a quadruped"*. |

**Constraints:** hit 4f @10 ping-pong on the species' own canvas and anchor;
defeat 7f, fps varied by mass (crawler @9, guardian @5). Blind Visual QA at x2
per `NEUTRAL_STAGING_CHECKLIST.md` before any of these is wired.

**Generations:** 7 tracks, budget 2x for re-rolls given the recorded failure
rate = **20-30**.

### Batch 4 — **Heavy strikes for the `guarded` enemies that lack one**

Oakback Bear, Salamander, and (in Batch 1) the Foreman throw a doubled-damage
telegraphed blow every third turn that looks identical to their normal attack.

| Enemy | Heavy brief |
|---|---|
| **Oakback Bear** | *"It rises to its full height before the heavy swipe falls"* — a full rear-up that exceeds the 76² canvas's current 50-row body; may need an 88² canvas, anchor 71. |
| **Salamander** | *"Heat gathers along its back before the scalding lunge"* — and the lunge must **travel**; the current attack moves 0 px. |

**Also in this batch: re-author `salamander_attack` and `crawler_attack`
outright.** At 4.7 % and 9.2 % mean silhouette change with zero bbox travel they
are the two least animated attacks in the game, in the location with the most
encounters per visit.

**Constraints:** heavy 7f @6 (slower than the normal attack, so the telegraph
reads in the motion and not only in the text). Attack re-authors keep the
existing canvas and anchor so no geometry changes.

**Generations:** 2 heavy tracks + 2 attack re-authors + re-rolls = **12-18**.

### Batch 5 — **Two new enemies from the CONCEPT-ONLY families** *(needs an owner content decision)*

The Forgotten Hollow offers 2 encounters per visit and both are the same
Guardian. The Hollow Weaver fixes that. The Adit Bat gives the Mine a light
fight below the Goblin.

Both require a **rebuild, not adoption** (§9.1), and both require
`assets/content/v1/enemies.json` and `items.json` changes (`item.gloom_silk`).
**That is a content decision, not an art decision — flagging it rather than
assuming it.** Record as **UNRESOLVED** in `JOURNAL/OPEN_QUESTIONS.md` if taken up.

**Generations:** 2 families x (1 create + 4 animate + 3 re-rolls, higher because
both previously failed blind QA on identity) = **20-28**.

### Totals

| Batch | Scope | Generations |
|---|---|---|
| 0 | Code / data only | **0** |
| 1 | Veteran identity (4 elites, 17 tracks) | 28-40 |
| 2 | Quadruped silhouette break (Lynx, Ram, 8 tracks) | 14-20 |
| 3 | Missing flinches x5 + missing deaths x2 | 20-30 |
| 4 | Heavy strikes x2 + static-attack re-authors x2 | 12-18 |
| 5 | Adit Bat + Hollow Weaver (content decision first) | 20-28 |
| | **Total, batches 1-4 (no new content)** | **74-108** |
| | **Total including batch 5** | **94-136** |

**Calibration:** RCP01 delivered five enemy families with three tracks each for
roughly 27 enemy-specific generations (`create_character` 5, `animate_character`
12, enemy stills 10) out of a 98-generation pack. This plan is ~4x that spend for
~4x the tracks, with a heavier re-roll allowance because it is deliberately
attacking the cases that previously failed blind QA.

**Against a balance of 10,000 generations this cycle, the whole plan costs
roughly 1 % of the allowance.** The constraint is blind Visual QA throughput and
the owner's device acceptance, not credit.

### Recommended order

1. **Batch 0** — free, and 0.1 alone reverses a visible size inversion.
2. **Batch 1** — removes 31 % of the roster's zero-identity problem.
3. **Batch 3** — the flinch is what makes a hit land; it is missing on 7 of 9.
4. **Batch 2** — the two silhouette collisions.
5. **Batch 4** — the heavy blow and the two static attacks.
6. **Batch 5** — only after an owner content decision.

---

## Appendix — Method

- Roster, stats, drops: `assets/content/v1/enemies.json`, schema at
  `packages/stride_core/lib/src/content/definitions.dart:890-1060`.
- Resolution, geometry, tracks: `lib/ui/icons/combat_assets.dart`,
  `lib/ui/icons/sprite_footprints.dart`.
- Playback and phases: `lib/ui/screens/combat/combat_choreography.dart`,
  `combat_stage.dart`, `combat_screen.dart`;
  `lib/ui/components/ambient_scene.dart` (`AmbientTrack.duration`, `frameAt`).
- Card rendering: `lib/ui/screens/adventure/encounter_card.dart`;
  `lib/ui/components/grounded_sprite.dart` (`ContactShadowSpec.bleed`).
- Hashes: MD5 over all 262 PNGs in `assets/art/v1/combat/`.
- Dimensions, opaque bounds, palettes, motion: `Scripts/art/png.js` (`load`,
  `bounds`) driven from throwaway scripts in the session scratchpad. Motion =
  mean per-frame silhouette (alpha > 8) symmetric difference over union.
  Silhouette IoU = idle f0 masks translated so each sprite's footprint centre and
  anchor row coincide — the stage's own placement rule.
- Segment durations recomputed from the fps/frame/strike-frame constants and the
  global timings in `combat_choreography.dart`.
- PixelLab balance read live via `get_balance` on 2026-09-01.

**Nothing in this audit was measured by eye, and no file was modified.**
