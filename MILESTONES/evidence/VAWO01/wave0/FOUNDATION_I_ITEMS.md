# FOUNDATION-I — Item Visual Uniqueness audit for VAWO01

```
STATUS: read-and-report only. No file outside this one was modified.
Agent:  FOUNDATION-I (Item Visual Uniqueness Auditor), Visual / Audio / World Overhaul 01
Date:   2026-09-01
Branch: presentation-combat-evolution-01 (repo HEAD 6d41bce, PROJECT_STATE v2.35)
Scope:  every item in the shipped content pack, the icon each one resolves to,
        and how distinguishable those icons actually are.
```

**Method.** Every number here comes from a command run against the working tree,
not from a document. `assets/content/v1/items.json` was parsed for the item list;
`lib/ui/icons/pixel_icons.dart` was parsed line-by-line for the icon lookup;
every PNG in `assets/art/v1/item/` was decoded (a zlib inflate plus PNG unfilter
written for this audit) so that **pixel content**, not just file bytes, could be
compared; and every 48 × 48 PNG under `GAME_BIBLE/ART/exploration/**` was decoded
and matched against the shipped set by pixel hash. Contact sheets of the whole
set were rendered at ×4 and at ×2 (the play-scale verdict rung the style spec
requires) and read directly.

---

## 0. The finding, in one paragraph

There are **58 items and 58 icon-map entries — nothing falls through to the
`unknown` placeholder.** But those 58 entries point at only **47 distinct
pictures**. Eleven items wear a **byte-for-byte copy** of another item's icon,
deliberately, recorded in `Scripts/art/package-art.js` as A-2 placeholder work
awaiting "the recorded future PixelLab round". That round is this milestone. On
top of the eleven exact copies sit roughly nine more pairs that are the same
object in two tints — including **Copper Ore vs Tin Ore, which the project's own
style spec already names as prohibited drift D-5 and which shipped anyway.** The
Craft screen is the worst surface: **39 rows drawn from 21 distinct pictures.**

---

## 1. The complete item table

**Total item count: 58.** Source: `assets/content/v1/items.json` (`schemaVersion` 1,
`kind: items`). No item id is referenced by `recipes.json`, `projects.json`,
`contracts.json`, `resource_nodes.json` or `enemies.json` that is absent from
`items.json`, and no icon-map entry names an item that does not exist — the three
lists agree.

`items.json` carries only three category values (`material`, `equipment`,
`consumable`, plus one `quest`). The finer categories the brief asks for are
derived: an `equipment` entry's `slot` (`weapon` / `armor` / `tool`) and its
`toolKind` (`axe` / `pickaxe`); "signature drop" is the `signature: true` flag on
an enemy drop; "project material" is membership in a `projects.json` stage
requirement. Those derivations are folded into the Category column below.

**Exposure** is a content-graph score computed for this audit:
`4×node yields + 3×enemy drops + 2×recipe outputs + 3×recipe ingredients +
3×project stage requirements + 3×contract requirements + 2×contract rewards`.
It measures how many places in the content graph put the icon in front of a
player. It **under-counts equipment**, which is additionally on the Character
screen permanently while worn and in the Craft list permanently once unlocked;
§9 corrects for that.

**Dup group** marks items whose icon file is byte-identical to another item's.

| # | id | Display name | Category | Tier | Rarity | Icon asset | sha256[0:8] | Dup group | Exposure |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `item.training_sword` | Training Sword | weapon | 0 | common | `item/training_sword.png` | `16b117a5` | D2 | 3 |
| 2 | `item.training_axe` | Training Axe | tool/axe | 0 | common | `item/training_axe.png` | `cbdb8cb4` | D3 | 3 |
| 3 | `item.training_pickaxe` | Training Pickaxe | tool/pickaxe | 0 | common | `item/training_pickaxe.png` | `4917e90f` | — | 3 |
| 4 | `item.traveler_tunic` | Traveler Tunic | armor | 0 | common | `item/traveler_tunic.png` | `bfdeb825` | D4 | 3 |
| 5 | `item.oak_log` | Oak Log | material | 0 | common | `item/oak_log.png` | `ca9ab2c9` | — | 42 |
| 6 | `item.pine_log` | Pine Log | material | 1 | common | `item/pine_log.png` | `503b261c` | — | 17 |
| 7 | `item.copper_ore` | Copper Ore | material | 0 | common | `item/copper_ore.png` | `76ad76b3` | — | 27 |
| 8 | `item.tin_ore` | Tin Ore | material | 0 | common | `item/tin_ore.png` | `fe9a39f7` | — | 35 |
| 9 | `item.meadow_herb` | Meadow Herb | material | 0 | common | `item/meadow_herb.png` | `a6a171b4` | — | 42 |
| 10 | `item.duskcap` | Duskcap | material | 0 | common | `item/duskcap.png` | `6286c86e` | — | 37 |
| 11 | `item.rime_blossom` | Rime Blossom | material | 1 | common | `item/rime_blossom.png` | `65607a78` | — | 46 |
| 12 | `item.hollow_root` | Hollow Root | material | 1 | common | `item/hollow_root.png` | `968b1d2e` | — | 27 |
| 13 | `item.wolf_pelt` | Wolf Pelt | material | 0 | common | `item/wolf_pelt.png` | `05fdb566` | — | 16 |
| 14 | `item.lynx_pelt` | Frost Lynx Pelt | material | 1 | uncommon | `item/lynx_pelt.png` | `6f972cb9` | — | 19 |
| 15 | `item.boar_hide` | Boar Hide | material | 0 | common | `item/boar_hide.png` | `6c1c4ea3` | — | 21 |
| 16 | `item.boar_tusk` | Boar Tusk | material | 0 | common | `item/boar_tusk.png` | `0276ae5a` | — | 11 |
| 17 | `item.scrap_metal` | Scrap Metal | material | 0 | common | `item/scrap_metal.png` | `b81f0da6` | — | 51 |
| 18 | `item.heat_scale` | Heat Scale | material | 1 | common | `item/heat_scale.png` | `af4b0415` | — | 17 |
| 19 | `item.ram_wool` | Ram Wool | material | 1 | common | `item/ram_wool.png` | `1c41bcf5` | — | 26 |
| 20 | `item.ram_horn` | Ram Horn | material | 1 | common | `item/ram_horn.png` | `39f50c1b` | — | 11 |
| 21 | `item.bear_pelt` | Bear Pelt | material | 1 | rare | `item/bear_pelt.png` | `ecc69059` | — | 17 |
| 22 | `item.pristine_wolf_fang` | Pristine Wolf Fang | material | 0 | rare | `item/pristine_wolf_fang.png` | `66a685f0` | — | 6 |
| 23 | `item.great_tusk` | Great Tusk | material | 0 | rare | `item/great_tusk.png` | `f6a745e3` | — | 6 |
| 24 | `item.goblin_toolhead` | Goblin Toolhead | material | 0 | rare | `item/goblin_toolhead.png` | `6fa6d089` | — | 6 |
| 25 | `item.ember_core` | Ember Core | material | 1 | rare | `item/ember_core.png` | `b52a91b4` | — | 6 |
| 26 | `item.frost_claw` | Frost Claw | material | 1 | epic | `item/frost_claw.png` | `bb4075ba` | — | 6 |
| 27 | `item.pristine_horn` | Pristine Horn | material | 1 | rare | `item/pristine_horn.png` | `57d485c0` | — | 6 |
| 28 | `item.gloom_silk` | Gloom Silk | material | 1 | rare | `item/gloom_silk.png` | `fdc79804` | — | 46 |
| 29 | `item.oak_handle` | Oak Handle | material | 0 | common | `item/oak_handle.png` | `af7f19bb` | — | 27 |
| 30 | `item.oak_plank` | Oak Plank | material | 0 | common | `item/oak_plank.png` | `ae144fa4` | — | 52 |
| 31 | `item.bronze_ingot` | Bronze Ingot | material | 1 | common | `item/bronze_ingot.png` | `841baec2` | — | 71 |
| 32 | `item.pine_plank` | Pine Plank | material | 1 | common | `item/pine_plank.png` | `757dbf53` | — | 38 |
| 33 | `item.bronze_sword` | Bronze Sword | weapon | 1 | uncommon | `item/bronze_sword.png` | `1de64dc8` | — | 2 |
| 34 | `item.bronze_longsword` | Bronze Longsword | weapon | 1 | epic | `item/bronze_longsword.png` | `0bac81cf` | — | 2 |
| 35 | `item.bronze_axe` | Bronze Axe | tool/axe | 1 | uncommon | `item/bronze_axe.png` | `f91a0999` | — | 8 |
| 36 | `item.bronze_pickaxe` | Bronze Pickaxe | tool/pickaxe | 1 | uncommon | `item/bronze_pickaxe.png` | `b519f6c2` | D5 | 8 |
| 37 | `item.hornbound_bronze_axe` | Hornbound Bronze Axe | tool/axe | 2 | epic | `item/hornbound_bronze_axe.png` | `61ec32fd` | — | 2 |
| 38 | `item.reinforced_pickaxe` | Reinforced Pickaxe | tool/pickaxe | 2 | rare | `item/reinforced_pickaxe.png` | `b6700f7e` | D6 | 5 |
| 39 | `item.bronze_chestplate` | Bronze Chestplate | armor | 1 | uncommon | `item/bronze_chestplate.png` | `59020065` | D1 | 8 |
| 40 | `item.wolfhide_jerkin` | Wolfhide Jerkin | armor | 1 | rare | `item/wolfhide_jerkin.png` | `0201bb77` | D7 | 8 |
| 41 | `item.frostlined_jerkin` | Frost-lined Jerkin | armor | 2 | epic | `item/frostlined_jerkin.png` | `d3fabf9f` | D8 | 5 |
| 42 | `item.bearhide_coat` | Bearhide Coat | armor | 2 | epic | `item/bearhide_coat.png` | `79ffb1ed` | D9 | 5 |
| 43 | `item.fanghilt_sword` | Fang-Hilted Sword | weapon | 1 | rare | `item/fanghilt_sword.png` | `16b117a5` | D2 | 2 |
| 44 | `item.tuskbound_jerkin` | Tuskbound Jerkin | armor | 1 | rare | `item/tuskbound_jerkin.png` | `0201bb77` | D7 | 2 |
| 45 | `item.goblin_toothed_axe` | Goblin-Toothed Axe | tool/axe | 2 | rare | `item/goblin_toothed_axe.png` | `cbdb8cb4` | D3 | 2 |
| 46 | `item.scalewarmed_chestplate` | Scale-Warmed Chestplate | armor | 2 | epic | `item/scalewarmed_chestplate.png` | `59020065` | D1 | 2 |
| 47 | `item.clawguard_coat` | Clawguard Coat | armor | 2 | epic | `item/clawguard_coat.png` | `79ffb1ed` | D9 | 2 |
| 48 | `item.hornpoint_pickaxe` | Hornpoint Pickaxe | tool/pickaxe | 2 | rare | `item/hornpoint_pickaxe.png` | `b519f6c2` | D5 | 2 |
| 49 | `item.waywarden_tunic` | Waywarden's Tunic | armor | 1 | rare | `item/waywarden_tunic.png` | `bfdeb825` | D4 | 2 |
| 50 | `item.tinbraced_pickaxe` | Tin-Braced Pickaxe | tool/pickaxe | 2 | rare | `item/tinbraced_pickaxe.png` | `b6700f7e` | D6 | 2 |
| 51 | `item.frostwarden_coat` | Frostwarden Coat | armor | 2 | epic | `item/frostwarden_coat.png` | `d3fabf9f` | D8 | 2 |
| 52 | `item.herb_broth` | Herb Broth | consumable | 0 | common | `item/herb_broth.png` | `61936e59` | D10 | 53 |
| 53 | `item.traveler_ration` | Traveler's Ration | consumable | 0 | common | `item/traveler_ration.png` | `61936e59` | D10 | 16 |
| 54 | `item.expedition_stew` | Expedition Stew | consumable | 1 | rare | `item/expedition_stew.png` | `e780fe22` | D11 | 13 |
| 55 | `item.duskcap_skewer` | Duskcap Skewer | consumable | 0 | common | `item/duskcap_skewer.png` | `d1420aad` | — | 17 |
| 56 | `item.frostbloom_tea` | Frostbloom Tea | consumable | 1 | uncommon | `item/frostbloom_tea.png` | `eb41d765` | — | 14 |
| 57 | `item.hearty_stew` | Hearty Stew | consumable | 1 | uncommon | `item/hearty_stew.png` | `e780fe22` | D11 | 25 |
| 58 | `item.hollow_sigil` | Hollow Sigil | quest | 1 | epic | `item/hollow_sigil.png` | `b4981d06` | — | 3 |

### Category totals

| Category | Items | Distinct icons | Collapse |
|---|---|---|---|
| material | 27 | 27 | none |
| equipment — weapon | 4 | 3 | 1 lost |
| equipment — tool (axe) | 4 | 3 | 1 lost |
| equipment — tool (pickaxe) | 5 | 3 | 2 lost |
| equipment — armour | 11 | 6 | 5 lost |
| consumable | 6 | 4 | 2 lost |
| quest | 1 | 1 | none |
| **Total** | **58** | **47** | **11 lost** |

---

## 2. How an item id becomes an image

One lookup table, one fallback, no naming convention and no runtime manifest.
`lib/ui/icons/pixel_icons.dart` is documented as "The only place an asset path
string appears", and a `Scripts/check-ui-boundary.sh` guard confines
`Image.asset` to `lib/ui/components/pixel_asset.dart`.

```dart
static const Map<String, String> _itemIcons = <String, String>{
  'item.bronze_ingot': '$_art/item/bronze_ingot.png',
  ...
};

/// A deliberately non-representational slab, for an item with no icon.
static const String itemUnknown = '$_art/item/unknown.png';

/// Never null. An item the icon set does not cover still gets a tile, a label
/// and a count — icon + label + count is the semantic unit (**L-17**), and the
/// label carries the meaning while the icon is honest about being absent.
static String itemFor(ContentId item) =>
    _itemIcons[item.value] ?? itemUnknown;

/// Whether [item] has a real icon.
static bool hasItemIcon(ContentId item) => _itemIcons.containsKey(item.value);
```

`_art` is `'assets/art/v1'`; `_base` is `'assets/ui/v1'`. The split is deliberate
and documented: game art is PixelLab-authored and packaged by
`Scripts/art/package-art.js`; UI chrome is authored as UI.

### The fallback count — the key number

**Zero.** All 58 items have an explicit `_itemIcons` entry. `unknown.png` is
reachable only by a content pack naming an item this build does not know about,
and `unknown.png` is the single icon file on disk that no item points at.

This is *enforced*, not merely true today. `test/item_icon_resolution_test.dart`
walks the real content pack and, for every id, asserts (a) `hasItemIcon` is true,
(b) the named asset loads from the bundle, (c) it decodes to exactly 48 × 48, and
(d) it has more than 200 pixels with alpha ≥ 8. It exists because Activity Feel &
Presentation 01 shipped four packaged icons whose map entries were forgotten, and
Wolf Pelt rendered as a blank slab on a physical phone.

**The gap:** that test asserts *presence and non-emptiness*. Nothing anywhere
asserts *distinctness*. Eleven byte-identical pairs pass it cleanly. There is no
guard in `Scripts/` and no test in `test/` that would notice if every item in the
game shared one picture.

---

## 3. Icon assets on disk, and the exact duplicates

**59 PNGs in `assets/art/v1/item/`.** Every one is **48 × 48, 8-bit,
colour-type 6 (RGBA)**. File sizes run 136 B (`unknown.png`, two colours) to
1,920 B (`ram_horn.png`). Palette sizes among opaque pixels run 21
(`wolf_pelt.png`) to 87 (`bronze_chestplate.png`); `unknown.png` has 2.

58 files are referenced; `unknown.png` is referenced only as the fallback.
**47 distinct sha256 digests among the 58 referenced files.**

### Exact-duplicate groups — 11 groups, 22 files, 11 pictures lost

Each group is one picture serving two different game concepts. sha256 truncated
to 12 hex digits; "shape" and "colour" distances are exactly 0 by construction.

| Group | sha256[0:12] | Bytes | Items sharing the picture | Donor recorded in `package-art.js` |
|---|---|---|---|---|
| D1 | `16b117a5ef2f` | 670 | **Training Sword** · **Fang-Hilted Sword** | `fanghilt_sword ← training_sword` |
| D2 | `cbdb8cb4ba42` | 672 | **Training Axe** · **Goblin-Toothed Axe** | `goblin_toothed_axe ← training_axe` |
| D3 | `b519f6c26958` | 792 | **Bronze Pickaxe** · **Hornpoint Pickaxe** | `hornpoint_pickaxe ← bronze_pickaxe` |
| D4 | `b6700f7e9494` | 1060 | **Reinforced Pickaxe** · **Tin-Braced Pickaxe** | `tinbraced_pickaxe ← reinforced_pickaxe` |
| D5 | `0201bb775cde` | 1021 | **Wolfhide Jerkin** · **Tuskbound Jerkin** | `tuskbound_jerkin ← wolfhide_jerkin` |
| D6 | `59020065e619` | 1697 | **Bronze Chestplate** · **Scale-Warmed Chestplate** | `scalewarmed_chestplate ← bronze_chestplate` |
| D7 | `79ffb1edf392` | 1067 | **Bearhide Coat** · **Clawguard Coat** | `clawguard_coat ← bearhide_coat` |
| D8 | `d3fabf9fcaab` | 1260 | **Frost-lined Jerkin** · **Frostwarden Coat** | `frostwarden_coat ← frostlined_jerkin` |
| D9 | `bfdeb8254ebe` | 1396 | **Traveler Tunic** · **Waywarden's Tunic** | `waywarden_tunic ← traveler_tunic` |
| D10 | `61936e59418e` | 1374 | **Herb Broth** · **Traveler's Ration** | `traveler_ration ← herb_broth` |
| D11 | `e780fe22bc9b` | 1153 | **Hearty Stew** · **Expedition Stew** | `expedition_stew ← hearty_stew` |

These are not an accident. `Scripts/art/package-art.js` emits them from the
already-emitted donor bytes and throws if the donor is missing:

```js
for (const [id, donor] of Object.entries({
  fanghilt_sword: 'training_sword',
  tuskbound_jerkin: 'wolfhide_jerkin',
  goblin_toothed_axe: 'training_axe',
  scalewarmed_chestplate: 'bronze_chestplate',
  clawguard_coat: 'bearhide_coat',
  hornpoint_pickaxe: 'bronze_pickaxe',
  traveler_ration: 'herb_broth',
  expedition_stew: 'hearty_stew',
})) {
  const bytes = emitted.get(`item/${donor}.png`);
  if (!bytes) throw new Error(`iteration 03 icon donor missing: item/${donor}.png`);
  emit(`item/${id}.png`, bytes);
}
```

The justification recorded in both `package-art.js` and `pixel_icons.dart` is
that each Masterwork **consumes** its donor, "so the copy and its donor almost
never share a bag". **That claim is true of the bag and false of the screen.**
Every one of the eleven recipes does consume its donor (verified against
`recipes.json` — e.g. `fanghilt_sword` requires `item.training_sword ×1`,
`item.pristine_wolf_fang ×1`, `item.bronze_ingot ×2`). But the Craft screen lists
*every unlocked recipe's output icon in one scrolling column*, so donor and copy
sit in the same list regardless of what the player holds. §5 quantifies that.

### No hue-swap-only pairs among the byte-identical set

The audit separately hashed the **alpha silhouette** of every icon and compared it
against the full-colour hash. Every group with an identical silhouette also has
identical pixels. **There is no case in the shipped set of one drawing recoloured
and re-exported** — the placeholder mechanism is copy, not tint. The hue-swap
failure the brief hunts is real here, but it lives one level out: in *pairs of
separately authored icons that resolved to the same shape* (§4).

---

## 4. Near-duplicates — same base idea, different tint

Two measures were computed over all 1,596 pairs of shipped icons:

- **Silhouette IoU** — intersection over union of the alpha ≥ 128 masks.
- **Confusability** — RMS distance between 12 × 12 downsamples of the
  alpha-weighted coverage map (`shape`) and of the alpha-weighted RGB
  (`colour`), combined as `sqrt(shape² + colour²)`. Lower is more alike.
  Byte-identical pairs score 0.0; the next-closest non-identical pair scores 40.2.

### The collision families, read at ×2 on the contact sheet

**F1 — The round mineral blob. `copper_ore` / `tin_ore`, and by extension
`ember_core`, `ram_wool`.**
Copper Ore and Tin Ore are silhouette IoU **90.5 %**, confusability **50.6**
(shape 40.5, colour 30.3). At play scale they are the same lumpy round rock:
copper carries orange nodules, tin carries pale specks. Nothing else differs.

This is **exactly the drift the project already wrote down and banned**.
`GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md` §9:

> **D-5 — Two silhouettes in one family separated only by hue.** Copper and tin
> ore are the same lumpy round rock in two tints. *(Observed in both rounds.)*

The spec named it, the round shipped anyway, and it is still on the phone. If
VAWO01 fixes one thing in the item set, it is this pair — it is the owner's
complaint stated verbatim in the project's own words.

`ember_core` (IoU 92.1 % against tin ore) and `ram_wool` (90.9 %) widen the family
to four round blobs; both are at least differently *textured* (cracked shell with
a hot core; clustered fleece lobes), so they rank below the ore pair.

**F2 — The diagonal wooden bar. `oak_plank` / `pine_plank` / `oak_handle`,
adjacent to `pine_log`.**
Three tan-to-brown rectangles at the same 45°, differing in length, width and
value. `pine_log`/`pine_plank` is the tightest measured pair in the whole
non-identical set: IoU 81.8 %, confusability **48.5**. `oak_handle` is
`oak_plank` narrowed. All three are high-exposure crafting staples (Oak Plank
exposure 52, Oak Handle 27, Pine Plank 38) and they appear *together* in Craft
ingredient lists.

**F3 — The splayed hide. `wolf_pelt` / `bear_pelt` / `boar_hide` / `lynx_pelt`.**
Four flat pelts pinned open, head-up. `bear_pelt`/`wolf_pelt` IoU 81.5 %; both
are brown-on-tan and separate at ×2 mainly by value, not shape. `lynx_pelt`
escapes on colour (blue-white, patterned) and `boar_hide` on construction (a
stretched hide with no head), so the live defect is wolf-vs-bear.

**F4 — The spiral horn. `ram_horn` / `pristine_horn`.**
The same coiled spiral: grey-white for Ram Horn, orange-bronze on a plinth for
Pristine Horn. A hue swap with a mount added. Pristine Horn is a *signature
trophy* (8 % drop) and reads as a recolour of a 35 %-drop common.

**F5 — The cream curved point. `boar_tusk` / `pristine_wolf_fang`.**
One banded curved tusk versus one smooth curved fang. Same colour, same arc, same
size class. Again a common and its signature trophy collide.

**F6 — The diagonal sword. `training_sword` / `bronze_sword` / `bronze_longsword`.**
`bronze_sword` vs `training_sword` is confusability **40.2** — the closest
non-identical pair in the set — and it is a straight hue swap: identical pose,
identical crossguard-and-pommel construction, grey blade versus gold blade. Since
`fanghilt_sword` is a byte copy of `training_sword`, **three of the four weapons
in the game are the same drawing in two colours.** `bronze_longsword` genuinely
differs (longer, cord grip, disc pommel — the RCP01 manifest says so explicitly)
and is the one weapon that survives.

**F7 — The torso garment. All eleven armour pieces.**
Every armour icon is a front-facing sleeveless or short-sleeved torso, centred,
same height, same framing. `frostlined_jerkin` vs `wolfhide_jerkin` IoU 87.5 %;
`bronze_chestplate` vs `wolfhide_jerkin` 86.6 %; `traveler_tunic` vs
`wolfhide_jerkin` 83.2 %. The category identity is excellent and the intra-category
identity is nil. With five of eleven being byte copies, **eleven armour items
present as six torsos, four of them brown.**

**F8 — The bowl. `herb_broth` / `frostbloom_tea`, `hearty_stew` / `bronze_ingot`.**
`frostbloom_tea` vs `herb_broth` confusability 63.5 — a mug and a bowl, separable.
Weaker: `bronze_ingot` vs `hearty_stew` at 63.3, both squat rounded masses.

### Naming stems that share art

`oak_*` (log / plank / handle) share wood language; `bronze_*` (ingot / sword /
longsword / axe / pickaxe / chestplate) share the bronze palette by design and
under **L-19** must read as bronze rather than gold. The bronze family is
*supposed* to cohere; the failure is that within it, tier and rarity are invisible
— an uncommon Bronze Pickaxe and a rare tier-2 Hornpoint Pickaxe are the same
picture.

---

## 5. Category identity

Judged from ×4 and ×2 contact sheets of the whole set, rendered for this audit.

| Category | Items | Distinct icons | Does the category read? | Verdict |
|---|---|---|---|---|
| **Ore / mineral** (copper, tin, scrap, ingot, heat scale, ember core) | 6 | 6 | Yes — round or angular mineral masses, rock-grey with an inclusion colour | **PASS on category, FAIL on member** — copper/tin is D-5 |
| **Log / plank / wood** (oak log, pine log, oak plank, pine plank, oak handle) | 5 | 5 | Yes — cut timber, visible end grain | **WEAK** — one bar silhouette serving three of five |
| **Plant / fungus** (meadow herb, duskcap, rime blossom, hollow root, gloom silk) | 5 | 5 | Yes — bundled sprig, mushroom cluster, five-petal bloom, gnarled root, thread spool. Five different silhouette families | **PASS** — the best-differentiated group in the game |
| **Hide / pelt / wool** (wolf, lynx, bear, boar, ram wool) | 5 | 5 | Yes — flat pinned skins | **WEAK** — wolf/bear separate on value only |
| **Trophy** (pristine wolf fang, great tusk, goblin toolhead, ember core, frost claw, pristine horn) | 6 | 6 | Partly — a keratin-and-bone family, plus one metal head and one ice claw | **WEAK** — the trophies collide with the commons they sit beside (F4, F5), which is backwards: a signature drop should be the most distinct thing in the bag |
| **Food** (6 consumables) | 6 | 4 | Yes — bowls, a skewer, a mug | **FAIL** — two of six pairs are byte copies; Traveler's Ration is a bowl of green soup |
| **Weapon** (4) | 4 | 3 | Yes — every weapon is unmistakably a sword | **FAIL** — one drawing in two colours plus one byte copy |
| **Tool — axe** (4) | 4 | 3 | Yes at ×2, and this was *earned*: three rounds of code-rendered training axe read as "hammer" before the PixelLab edit | **FAIL** — 1 byte copy |
| **Tool — pickaxe** (5) | 5 | 3 | **Marginally.** `training_pickaxe` reads as a pickaxe (symmetric curved head). `bronze_pickaxe` reads closer to a mallet — the D-4 "unaccountable attached masses" failure. `reinforced_pickaxe` reads as a winged mattock | **FAIL** — 2 byte copies and a soft noun |
| **Armour** (11) | 11 | 6 | Yes, emphatically — every one is a torso | **FAIL on member** — see F7 |
| **Quest** (hollow sigil) | 1 | 1 | Reads as a carved stone tablet | **PASS** |

### The silhouette families exist, and there are too few of them

Across 47 distinct pictures the set uses roughly **twelve** silhouette archetypes:
round blob · diagonal bar · diagonal sword · hafted tool · torso · bowl · mug ·
splayed hide · spiral horn · curved point · sprig/cluster · slab. Armour spends
eleven items on one archetype; tools spend nine on two. That, more than any
individual icon, is why the set feels repetitive: the *category* language is
strong and the *member* language inside each category is missing.

---

## 6. Small-size readability

**Authored at 48 × 48. Displayed at 48 logical px. Scale ×1. Nearest neighbour.
No downscale anywhere, no upscale beyond the device pixel ratio.** This is the
one part of the item pipeline that is in good shape, and it is defended by
construction rather than by convention.

`lib/ui/components/pixel_asset.dart` takes **a native size and an integer scale,
never a width** — "A fractional displayed size is therefore *unrepresentable*
rather than merely discouraged." The item constructor is:

```dart
/// Item icons — **48 × 48**, the PixelLab family, 48 logical at ×1.
const PixelAsset.item(this.assetPath, {super.key, this.scale = 1})
  : nativeWidth = 48,
    nativeHeight = 48;
```

and the draw is `fit: BoxFit.fill`, `filterQuality: FilterQuality.none`,
`isAntiAlias: false`, with `cacheWidth`/`cacheHeight` **deliberately unset**
(they resample at decode time, before `filterQuality` is consulted). A debug
assert in `_ExactSizeBox` fires if a parent hands down a constraint smaller than
the declared size, because Flutter shrinks silently rather than overflowing.
`Scripts/check-ui-boundary.sh` confines `Image.asset` to this file. `L-18` in
`GAME_BIBLE/ART/ART_DIRECTION.md` is the rule being enforced.

### Every call site, and the size it draws at

| Surface | File : line | Scale | Displayed |
|---|---|---|---|
| Inventory grid tile | `lib/ui/screens/inventory/inventory_screen.dart:764` | ×1 | 48 dp |
| Craft recipe row | `lib/ui/screens/craft/craft_screen.dart:593` (in `InsetWell.square(contentSize: 48)`) | ×1 | 48 dp |
| Craft selected-recipe header | `lib/ui/screens/craft/craft_screen.dart:1362` | ×1 | 48 dp |
| Contract / job card face | `lib/ui/screens/adventure/board_card.dart:492` (`InsetWell.square(contentSize: 48)`) | ×1 | 48 dp |
| Contract reward row | `lib/ui/screens/adventure/board_card.dart:853` | ×1 | 48 dp |
| Equipped-gear row, Character screen | `lib/ui/screens/character/character_screen.dart:381` | ×1 | 48 dp |
| Activity result card | `lib/ui/components/activity_result.dart:168` | ×1 | 48 dp |
| Victory / reward beat | `lib/ui/components/reward_beat.dart:412` | ×1 | 48 dp |

The inventory grid reserves the icon explicitly — `const double iconEdge = 48;
// PixelAsset.item at x1.` inside `_tileExtent`, which computes cell height from
icon + rarity rule + two reserved name lines + count + padding under the ambient
`TextScaler` so a 1.4 scaler grows the cell instead of clipping it.

**Findings:**

1. **No destructive downscaling exists.** Every item icon is drawn at exactly its
   native 48 px, then magnified by the device pixel ratio (2× or 3× on every
   supported phone) with nearest-neighbour. Nothing is resampled.
2. **48 dp at ×1 is small for 48 px of art.** On a 3× phone the icon occupies
   ~4.3 mm. The style spec's QA rule ("**Native, ×2 and ×8 must all be supplied.**
   ×2 is the verdict rung") exists precisely because round 2 of PROOF_02 "failed
   in different cells" at native and at ×2. Any VAWO01 replacement must be judged
   on the ×2 sheet in the four-wide grid, not at ×8.
3. **The comment on `PixelAsset.item` records the constraint that forced ×1:**
   "A 96 logical px icon does not fit a four-column grid at 320 dp." So a bigger
   icon is not available as a fix. Differentiation must come from silhouette and
   value, not from more room.
4. **Detail budget is being spent on interior texture that dies at 48 dp.**
   `bronze_chestplate` carries 87 distinct colours; `wolf_pelt` carries 21 and
   reads better. The high-colour icons are not more legible, they are busier.

---

## 7. Items with no icon, and icons that are wrong for the item

**Items with no icon: none.** All 58 resolve, and a test enforces it (§2).

**Icons that are wrong for the item.** Ranked by how confidently a player would
name the wrong thing. The first eight are wrong *because* of the byte-copy
mechanism — the picture is a correct drawing of a different item.

| Item | What the icon actually shows | Severity |
|---|---|---|
| **Fang-Hilted Sword** (rare, T1) | The plain grey **Training Sword**. No fang anywhere. A rare crafted reward is pictured as the starter weapon | **Critical** |
| **Traveler's Ration** (T0 consumable) | A bowl of green **Herb Broth**. A ration is dry portable food; this is soup in a bowl, and the same bowl the broth uses | **Critical** |
| **Goblin-Toothed Axe** (rare, T2) | The plain **Training Axe**. No teeth | **Critical** |
| **Waywarden's Tunic** (rare, T1) | The **Traveler Tunic**, the level-0 starter armour | **Critical** |
| **Scale-Warmed Chestplate** (epic, T2, `frostGuard: 3`) | The **Bronze Chestplate**. No scales, no frost language | High |
| **Clawguard Coat** (epic, T2) | The **Bearhide Coat**. No claws | High |
| **Frostwarden Coat** (epic, T2, `frostGuard: 3`) | The **Frost-lined Jerkin** | High |
| **Tuskbound Jerkin** / **Hornpoint Pickaxe** / **Tin-Braced Pickaxe** / **Expedition Stew** | Their donors, unmodified | High |
| **Bronze Pickaxe** | Reads closer to a **mallet or war-hammer** than a pickaxe at ×2 — the head is a compact mass rather than two opposed points. This is the D-4 drift ("unaccountable attached masses… flips the noun") that the same family already failed twice on | Medium — and it propagates to Hornpoint Pickaxe |
| **Heat Scale** | A nut-brown teardrop. The item's own accepted manifest records the defect: *"MAJOR note: palette carries no heat language (nut-brown), the name carries it."* It reads as a seed or a leaf | Medium — shipped with a recorded MAJOR |
| **Reinforced Pickaxe** | A winged mattock / war pick. The RCP01 attempt at this item was **WITHHELD after three rounds** — *"c1 jumble, c2 read as a polearm, c3 read as a hammer"* — and the shipped icon came from a later round | Medium |
| **Ram Wool** | A cluster of pale lobes; the manifest records *"MINOR: bottom wisps read as strays"* and it sits in the round-blob family with the ores | Low |

**Orphan art with no item:** `granite_chitin` has five authored 48 × 48 images
under `REGIONAL_CONTENT_PACK_01` and **no entry in `items.json`**. Its manifest
records `status: "withheld"` after four rounds — helmet, seashell, pauldrons,
barrel — so its item was struck rather than shipped blank. `icon_canvas_backpack_48`
is in the same position; `package-art.js` notes it directly: *"`items.json` has no
`item.canvas_backpack`"*.

---

## 8. Unused item art already on disk

Every 48 × 48 PNG under `GAME_BIBLE/ART/exploration/**` was decoded and matched
by **pixel hash** against the shipped set (byte hashes would miss re-encoding by
`package-art.js`). Results:

### Directly reusable, style-conformant, currently unused

| Candidate | Round & recorded reason it lost | Plausible use in VAWO01 |
|---|---|---|
| `TRANSFORMATION_01/items/candidates/bronze_axe_c1…c4, c6` (**5 axe heads**) | c5 was chosen; the others are alternate takes, not defects | Break D2 — a genuinely different axe for **Goblin-Toothed Axe** |
| `TRANSFORMATION_01/items/candidates/bronze_pickaxe_c1, c2` | c-selection | Break D3 — a different head for **Hornpoint Pickaxe**; c1/c2 may also read as a better *pickaxe* than the shipped one |
| `TRANSFORMATION_01/items/candidates/bronze_sword_c1` | c2 chosen | Break D1 — a distinct blade for **Fang-Hilted Sword** |
| `REGIONAL_CONTENT_PACK_01/gear/candidates/bearhide_coat_c1` | *"c1 came out olive"* — a colour note, not a construction failure. It is also a **longer, shaggier coat with a different silhouette** than the shipped c2 | Break D7 — **Clawguard Coat**, or better, promote it to the true "coat" silhouette so coats stop being jerkins |
| `REGIONAL_CONTENT_PACK_01/gear/candidates/hornbound_axe_c1` | c2 chosen | Spare axe silhouette |
| `REGIONAL_CONTENT_PACK_01/gear/candidates/reinforced_pickaxe_c1, c2, c3` (+ packaged `icon_reinforced_bronze_pickaxe_48`) | **All three failed blind QA** (jumble / polearm / hammer) | **Do not reuse.** Recorded as read-failures |
| `TRANSFORMATION_01/items/candidates/herb_broth_c1` | c2 chosen | Would break D10 only cosmetically — still a bowl of green soup, still the wrong noun for a *ration*. Author instead |
| `TRANSFORMATION_01/items/candidates/pine_plank_c1…c3`, `PLAYABLE_EXPANSION_01/items/candidates/pine_plank_c1, c2`, `…/withheld/icon_pine_plank_48` | The withheld one is recorded as *"a hue-twin of the oak log at play scale"* | Useful as **negative evidence** for F2 — the failure mode is documented |
| `TRANSFORMATION_01/items/candidates/hollow_root_c1…c4`, `hollow_sigil_c1…c3` | c-selection | Spares; both items already read fine |
| `WORLD_REWARD_DEPTH_01/items/candidates/lynx_pelt_c2` | *"drew a whole spread-out cat with a long tail, not a cut pelt"* | Do not reuse as a pelt |
| `WORLD_REWARD_DEPTH_01/items/candidates/wolf_pelt_c1` | Rejected: emissive-looking cream stripe, against the no-glow style clause | Do not reuse |
| `REGIONAL_CONTENT_PACK_01/materials/candidates/bear_pelt_c1, c2` | c1 *"read as a teddy bear"* | Do not reuse c1 |
| `REGIONAL_CONTENT_PACK_01/materials/candidates/boar_tusk_c1` | *"read as a drinking horn"* | Do not reuse as a tusk — **but it is a usable drinking-horn silhouette** if a future item wants one |
| `REGIONAL_CONTENT_PACK_01/materials/candidates/gloom_silk_c1, c2` | c1 yarn ball, c2 unidentifiable | Do not reuse |
| `granite_chitin_c1…c4` + `icon_granite_chitin_48` (**5 images**) | Withheld after four rounds; **no item exists** | A finished helmet, a seashell, a pauldron pair and a barrel, all in-style. Genuinely usable art looking for a noun |
| `icon_canvas_backpack_48` (in both PROOF_03 and STABILIZATION_01) | No `item.canvas_backpack` exists | Same |
| `…_round1_withheld` / `_round2_withheld` for goblin toolhead ×2, heat scale ×1, ram wool ×1 | Explicit blind-QA failures | Do not reuse |

**Net honest count: about 10 unused images are safely reusable** (5 bronze axes,
2 bronze pickaxes, 1 bronze sword, 1 olive coat, 1 hornbound axe), plus 6 orphan
images with no item (granite chitin ×5, canvas backpack ×1). The rest carry a
recorded read-failure and reusing them would re-ship a known defect.

**What reuse buys, and what it does not.** Swapping in `bronze_axe_c2` for the
Goblin-Toothed Axe makes it *a different axe* at zero generation cost, which
breaks the byte collision immediately. It does not make it a *goblin-toothed*
axe. Reuse is the right same-day de-collision for a subset; it is not the
deliverable.

---

## 9. Prioritised replacement list

Ranked by **(a) how often the player sees the icon** × **(b) how badly it
collides**. Content-graph exposure (§1) is corrected here for surface presence:
a crafted tool has low graph exposure but permanent presence, because the Craft
screen lists every unlocked recipe's output icon in one column and the Character
screen shows every worn piece.

### The single most damaging surface

**The Craft screen shows 39 recipe rows drawn from 21 distinct pictures.** Eight
of those collisions are between *different game concepts* sitting in one scrolling
list:

```
Bronze Pickaxe        ==  Hornpoint Pickaxe
Reinforced Pickaxe    ==  Tin-Braced Pickaxe
Bronze Chestplate     ==  Scale-Warmed Chestplate
Wolfhide Jerkin       ==  Tuskbound Jerkin
Bearhide Coat         ==  Clawguard Coat
Frost-lined Jerkin    ==  Frostwarden Coat
Herb Broth            ==  Traveler's Ration
Hearty Stew           ==  Expedition Stew
```

The remaining three copies (Fang-Hilted Sword, Goblin-Toothed Axe, Waywarden's
Tunic) collide against **starter equipment the player is wearing on the Character
screen from the first minute**, which is worse in a different way: the reward for
a rare craft is a picture of the thing it replaced.

### P1 — Break the eleven byte-identical pairs (11 icons)

| Rank | Item to re-author | Collides with | Why here |
|---|---|---|---|
| 1 | **Traveler's Ration** | Herb Broth | Herb Broth has the second-highest exposure in the game (53): 6 contract requirements, 4 contract rewards, 5 project stages. Five of the Craft screen's food rows share this one bowl. Also the worst *noun* error in the set |
| 2 | **Fang-Hilted Sword** | Training Sword | Only 4 weapons exist; the rare one is pictured as the starter, which is worn on the Character screen from minute one |
| 3 | **Waywarden's Tunic** | Traveler Tunic | Same, for the starter armour |
| 4 | **Goblin-Toothed Axe** | Training Axe | Same, for the starter axe |
| 5 | **Hornpoint Pickaxe** | Bronze Pickaxe | 5 pickaxes present as 3 pictures; both rows are in the Craft list |
| 6 | **Tin-Braced Pickaxe** | Reinforced Pickaxe | As above |
| 7 | **Scale-Warmed Chestplate** | Bronze Chestplate | Epic T2 pictured as uncommon T1 |
| 8 | **Tuskbound Jerkin** | Wolfhide Jerkin | Rare T1 pictured as rare T1 — the trophy adds nothing visible |
| 9 | **Clawguard Coat** | Bearhide Coat | Epic T2 pictured as epic T2 |
| 10 | **Frostwarden Coat** | Frost-lined Jerkin | Two `frostGuard` pieces, one picture |
| 11 | **Expedition Stew** | Hearty Stew | Rare pictured as uncommon; three Craft rows |

### P2 — Break the named silhouette collisions (5 icons)

| Rank | Item | Collides with | Why here |
|---|---|---|---|
| 12 | **Tin Ore** | Copper Ore | **This is D-5, written down as prohibited drift in the project's own style spec and shipped anyway.** Both are node yields *and* enemy drops; combined exposure 62. Fixing this is the owner's complaint answered in the project's own words |
| 13 | **Oak Handle** | Oak Plank / Pine Plank | Three diagonal wooden bars; combined exposure 117 and they appear together in ingredient lists |
| 14 | **Pine Plank** | Oak Plank | As above. The withheld PLAYABLE_EXPANSION_01 attempt is recorded as *"a hue-twin of the oak log at play scale"* — the failure mode is already documented |
| 15 | **Bronze Sword** | Training Sword | Closest non-identical pair in the whole set (confusability 40.2) and a pure hue swap of one pose |
| 16 | **Bronze Pickaxe** | — (noun repair) | Reads as a mallet at ×2; D-4. Must be fixed *with* rank 5 or the whole pickaxe family inherits the wrong noun |

### P3 — Trophy dignity and recorded weak reads (6 icons)

| Rank | Item | Issue |
|---|---|---|
| 17 | **Pristine Horn** | Same spiral as the common Ram Horn, in orange. A signature 8 % trophy should be the most distinct object in the bag, not a recolour |
| 18 | **Pristine Wolf Fang** | Same cream curved point as the common Boar Tusk |
| 19 | **Bear Pelt** | Same splayed hide as Wolf Pelt, separated by value only |
| 20 | **Heat Scale** | Shipped with a recorded MAJOR: *"palette carries no heat language (nut-brown), the name carries it"* |
| 21 | **Ember Core** | Round-blob family with the ores (IoU 92.1 % vs Tin Ore); lowest-urgency member of that family |
| 22 | **Reinforced Pickaxe** | Mattock read; three prior rounds withheld for jumble / polearm / hammer |

**Explicitly not on this list:** the plant/fungus group (meadow herb, duskcap,
rime blossom, hollow root, gloom silk), the Hollow Sigil, Bronze Longsword,
Hornbound Bronze Axe, Bronze Ingot, Scrap Metal, Great Tusk, Goblin Toolhead,
Frost Claw, Lynx Pelt, Boar Hide, Ram Wool, Duskcap Skewer, Frostbloom Tea, Oak
Log, Pine Log, Oak Plank, Wolf Pelt, Training Sword/Axe/Pickaxe, Traveler Tunic.
**26 of 58 items are fine and must not be touched.** "No two items feel
identical" is a differentiation problem, not a redraw-everything problem, and
re-rolling a passing icon risks losing a blind-QA PASS for nothing.

---

## 10. Production batches, and the generation estimate

### Batch by collision family, not by category

The reason the shipped set collides is that colliding items were authored in
*different milestones months apart* and never seen side by side. Batching by
category would repeat that mistake. **Every batch below puts the colliding items
in the same round so the blind set-coherence reviewer sees the contest.** Where a
batch contains an item that already passes (marked *anchor*), it is included in
the review sheet as a fixed reference and **not** regenerated.

Batch size is **5-6**. The style spec's QA regime (§10) demands three separate
reviews per round — blind naming per asset, set coherence as a different
reviewer, and an in-context screen read — and a 16-icon round mixing unrelated
subjects makes the coherence verdict meaningless.

### Shared constraints for every batch

- **Canvas: 48 x 48.** Non-negotiable — `PixelAsset.item` hard-codes
  `nativeWidth = 48`, `test/item_icon_resolution_test.dart` asserts 48 x 48, and
  L-18 forbids any non-integer display scale.
- **Tool: `create_image_pixen`** (icons), per the style spec's three-scales table.
- **Style clause, appended verbatim and unchanged** (`PIXELLAB_STYLE_SPEC_01.md`
  §7.2 — the clause that moved set coherence from FAIL to PASS):

  > — pixel art game item icon, single dark outline all the way around the
  > object, flat matte shading in a few clear steps, light from the upper left,
  > warm earthy limited palette, no glow, no emissive light, no bright white
  > specular, no cast shadow, no ground, no text, object centred and filling most
  > of the frame

- **Lighting: upper left, every asset.** Already carried by the clause; the set
  is consistent on this today and must stay so.
- **Palette: warm earthy limited.** No palette words in the prompt (the spec's
  §3.2 rule). **L-19**: bronze reads as bronze, never as gold bullion.
  **L-16**: teal `#58d6c0` is reserved for walking and may not appear on an item.
- **Prompt shape** (§7): `<noun> <presentation clause>: <construction clause> —
  <style clause>`, with the construction clause enumerating parts and how they
  attach. Positive construction, never a prohibition.
- **Colour ceiling ~48.** Measured: the icons that read best carry 21-48 colours;
  the busiest (87, the Bronze Chestplate) reads worst at 48 dp.
- **QA: blind naming per asset, set coherence separately, in-context screen read
  third — supplied at native, x2 and x8, with x2 as the verdict rung**, staged
  outside the repository per `NEUTRAL_STAGING_CHECKLIST.md`.

### The batches

| # | Batch | New icons | Anchors (not regenerated) | The silhouette rule this batch must satisfy |
|---|---|---|---|---|
| **B1** | Pickaxe family | Bronze Pickaxe, Reinforced Pickaxe, Hornpoint Pickaxe, Tin-Braced Pickaxe (4) | Training Pickaxe | Four **distinguishable head geometries** on a shared haft language: symmetric twin-point, single-point-and-poll, twin-point-with-braces, and a broad splitting head. Head mass must resolve into named parts (D-4); a compact undifferentiated lump reads as a hammer and has already failed here twice |
| **B2** | Blade and axe | Bronze Sword, Fang-Hilted Sword, Goblin-Toothed Axe (3) | Training Sword, Bronze Longsword, Hornbound Bronze Axe | **No two blades may share a pose.** The set already has one 45-degree cruciform sword three times over; give the new blades different blade profiles, guards and grips, and make the Fang-Hilt's fang structural — in the grip, at the silhouette edge — rather than a painted detail. The Goblin-Toothed head must show teeth as silhouette notches on the cutting edge, not as interior colour |
| **B3** | Armour torso split | Waywarden's Tunic, Tuskbound Jerkin, Scale-Warmed Chestplate, Clawguard Coat, Frostwarden Coat (5) | Traveler Tunic, Bronze Chestplate, Wolfhide Jerkin, Bearhide Coat, Frost-lined Jerkin | **Break the one-torso monopoly.** Eleven items currently share a single front-facing torso outline. Give the category **three sub-silhouettes** — short jerkin (waist-cut, sleeveless), plate cuirass (shouldered, rigid), long coat (below-hip, collared, hem visible) — and put each new piece's trophy at the *outline*: tusks at the shoulder line, scale plating breaking the chest edge, claws at the collar, a fur storm-collar for the frost pieces |
| **B4** | Prepared food | Traveler's Ration, Expedition Stew (2) | Herb Broth, Hearty Stew, Duskcap Skewer, Frostbloom Tea | **A ration is not a bowl.** Wrapped and portable versus cooked and served: the Ration should be a bound bundle — cloth-wrapped block, cord, a dried strip — with no vessel at all. The Expedition Stew must differ from the Hearty Stew by vessel and contents, not by tint |
| **B5** | Mineral split (**D-5**) | Tin Ore, Heat Scale, Ember Core (3) | Copper Ore, Scrap Metal, Bronze Ingot | **The batch that answers the owner's complaint.** No two minerals may be the same round mass. Tin must differ from Copper by *form* — a bladed or prismatic cluster, or a fractured slab, against copper's nodular boulder — before any colour is chosen. Heat Scale must carry heat in its palette, not only in its name (the recorded MAJOR). Ember Core must not read as a fourth boulder |
| **B6** | Trophy dignity | Pristine Horn, Pristine Wolf Fang, Bear Pelt (3) | Ram Horn, Boar Tusk, Wolf Pelt, Lynx Pelt, Great Tusk | **A signature trophy must out-read the common it drops beside.** Each of these three currently mirrors a common item's silhouette. Change the object's *construction*, not its polish — a mounted or bound presentation, a different curvature class, a pelt with a distinct head shape and posture |
| **B7** | Wood bar split | Oak Handle, Pine Plank (2) | Oak Log, Pine Log, Oak Plank | **Three wooden bars is one bar too many.** The Handle should be a shaped haft — tapered, bound, clearly a *part* — not a shorter plank. The Pine Plank must differ from the Oak Plank in section and end grain, not only in value; the recorded prior failure here is "a hue-twin of the oak log at play scale" |

**22 new icons across 7 batches.**

### Generation estimate

Estimated from this project's own measured accept rate, not from an assumption.
Counting candidate files against accepted outputs in the exploration tree:

| Round | Candidates generated | Icons accepted | Generations per accept |
|---|---|---|---|
| `PIXELLAB_STABILIZATION_01` / `PROOF_03` | 12 + 5 `icons_full` | ~12 shipped | ~1.4 |
| `EXPLORATION_PROGRESSION_LOOP_01` | 16 (incl. 4 recorded withheld rounds) | 12 | **1.33** |
| `TRANSFORMATION_01` (items only) | 26 | 9 | **2.9** |
| `REGIONAL_CONTENT_PACK_01` gear | 9 | 3 (+1 withheld after 3 rounds) | **3.0** |
| `REGIONAL_CONTENT_PACK_01` materials | 12 | 4 (+1 withheld after 4 rounds) | **3.0** |

Hafted tools and gear cost about **3 generations per accepted icon**; materials
and foods about **2**. Applying those rates:

| Batch | Icons | Rate | Generations |
|---|---|---|---|
| B1 Pickaxes | 4 | 3.0 | 12 |
| B2 Blade and axe | 3 | 3.0 | 9 |
| B3 Armour | 5 | 2.5 | 13 |
| B4 Food | 2 | 2.0 | 4 |
| B5 Minerals | 3 | 2.5 | 8 |
| B6 Trophies | 3 | 2.5 | 8 |
| B7 Wood | 2 | 2.5 | 5 |
| **Total** | **22** | — | **~59** |

**Estimate: 55-70 generations, call it ~60, with a ceiling of ~80** if the
pickaxe family repeats its history (three withheld rounds on one subject). Add
~5 if the reviewer asks for targeted `edit_image` / `inpaint_image` passes rather
than re-rolls — which the style spec prefers: *"Once a good silhouette exists,
targeted inpaint/edit, never a full reroll."* Inpaints are cheaper per attempt
and should be the default once a batch's silhouettes land.

**Budget is not the constraint.** `get_balance` at the time of this audit:
**10,000 generations remaining** this cycle (Tier 3 Pixel Architect, active,
resets 2026-10-01), $0.00 credits used. Sixty generations is 0.6 % of the
allowance. The constraint is **blind-QA throughput** — three separate reviews per
batch, staged outside the repository — which is why the plan is 7 batches of
5-6 rather than 2 batches of 11.

### Reuse strategy, stated honestly

Roughly **10 unused in-style 48 x 48 images** already sit in the exploration tree
without a recorded read-failure (§8). Integrating four of them —
`bronze_axe_c2` to Goblin-Toothed Axe, `bronze_pickaxe_c1` to Hornpoint Pickaxe,
`bronze_sword_c1` to Fang-Hilted Sword, `bearhide_coat_c1` to Clawguard Coat —
would **break four byte-collisions the same day at zero generations**, and is
worth doing as an immediate mitigation.

It does **not** reduce the 22. A different bronze axe is not a goblin-toothed
axe, and shipping it as one preserves the wrong-noun defect while removing the
collision that made it visible. Recorded as a stopgap, not a substitute.

### One thing to add that is not art

Nothing in `test/` or `Scripts/` asserts that two items have different icons.
`item_icon_resolution_test.dart` checks presence, size and non-emptiness, and
eleven byte-identical pairs pass it cleanly. A test that hashes every mapped icon
and fails on a collision **not present in an explicit, commented allow-list**
would have made the eleven copies a deliberate, reviewed, expiring decision
instead of a comment in a packaging script. It is a small change, and it is the
only thing in this report that stops the defect recurring after VAWO01 closes.

---

## Appendix — commands and derived artefacts

All analysis scripts were written to the session scratchpad, outside the
repository, and are not committed:

- `png.js` — PNG decoder (zlib inflate plus unfilter, colour types 0/2/4/6) used
  to compare pixel content rather than file bytes.
- `analyze.js` — per-icon dimensions, opaque-pixel fill, bounding box, palette
  size, mean RGB, alpha-mask hash, pixel hash. Produced the exact-duplicate and
  identical-silhouette groupings.
- `pairs.js` / `perc.js` — all 1,596 pairwise silhouette IoU and confusability
  scores.
- `sheet.js` — PNG encoder producing x4 and x2 contact sheets over a checker
  ground, read directly for every perceptual judgement in §4, §5 and §7.
- `xcheck2.js` — `items.json` to `_itemIcons` to disk, three-way reconciliation.
- `expo2.js` — content-graph exposure across nodes, enemies, recipes, projects
  and contracts.
- `match.js` — pixel-hash match of every 48 x 48 exploration PNG against the
  shipped set, producing the unused-art inventory in §8.
- `craft.js` — Craft-screen collision count (39 rows, 21 pictures).

`mcp__pixellab__get_balance` was called once, read-only, for §10.

**No file in the repository was modified except this report.**
