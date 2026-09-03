# EPO03 — PROD-ITEMS report

Brief `MILESTONES/evidence/EPO03/wave1/DIR-09_item_art.md`. Ledger
`GAME_BIBLE/ART/exploration/EPO03/ledger/ITEMS.md`. Cap 200; **spent 52**.

The owner's standard governed every verdict: *"Human-eye uniqueness. Two assets
are not distinct merely because their files differ. Review at actual UI size."*
Every accepted icon was put on a contact sheet at x2 on the inventory tile
colour `#1e1e1e`, **beside its collision partners**, and read by eye before the
verdict. The IoU metric was used as triage only (M-04).

## What shipped

**20 icons re-authored**, all 48 x 48, palette guard green.

| Group (DIR-09 rank) | Assets | Route | Verdict |
|---|---|---|---|
| 1 — four brown vests | `wolfhide_jerkin`, `tuskbound_jerkin`, `frostlined_jerkin`, `bearhide_coat` | regenerate | **CLOSED** |
| 2 — five ivory curves | `great_tusk`, `pristine_wolf_fang`, `pristine_horn` | regenerate | **CLOSED** |
| 3 — two dark stews | `hearty_stew`, `expedition_stew` | regenerate + edit | **CLOSED** |
| 4 — three identical crates | `reclaim_axe`, `reclaim_pickaxe`, `reclaim_chestplate` | edit | **CLOSED** |
| 5 — the epic longsword | `bronze_longsword` | regenerate | **CLOSED** |
| 6 — two bronze pick heads | `hornpoint_pickaxe`, `reinforced_pickaxe` | regenerate + edit | **CLOSED** |
| 7 — two coats drawing a person | `clawguard_coat`, `frostwarden_coat` | regenerate | **CLOSED** |
| 8 — `tin_ore` vs `scrap_metal` | — | none | **CLOSED as KEEP** — see below |
| 9 — `oak_handle` vs `pine_plank` | `oak_handle` | edit | **CLOSED** |
| 10 — `frost_claw`, `hornbound_bronze_axe` | both | regenerate + edit | **CLOSED** |

All ten groups closed. 20 re-authored (13 regenerated, 7 edited), 1 examined and
deliberately kept, 41 untouched.

### The one group that closed without spending anything

DIR-09 ranked `tin_ore` against `scrap_metal` as collision #8. Read at x2 on the
tile they are an angular rock with pale crystal spikes and a pile of flat rusted
plates — IoU 0.673, and nothing a player would confuse. **The collision does not
survive the sheet read at the size the phone draws it**, so it got no roll. The
sheet is the verdict in both directions: it withholds rolls as well as accepting
them.

## What the phone will show that it could not before

1. **The armour pocket names itself.** Four vests were one brown colour mass
   whose only tells were under 6 px (pairwise IoU 0.85-0.88). They are now a
   grey shaggy fur ruff, a tan jerkin with two white tusks crossing the chest, a
   smooth blue-grey tank, and a near-black hooded coat whose hem falls below the
   vest line — 0.56-0.83, and separable in greyscale, not only by hue.
2. **No armour draws a person.** `clawguard_coat` rendered a hooded figure with
   a face and red emissive eyes. Both coats are now garments: no head, no hands,
   no legs.
3. **The fang stops being a tusk.** It was a fat ivory wedge beside `boar_tusk`
   and `great_tusk`; it is now a tooth in a braided cord with a loop — IoU 0.256
   against `boar_tusk`, and 31.1% fill against the shipped 12%.
4. **The cooking list has two vessels.** `hearty_stew` leaves the dark iron pot
   to `expedition_stew` and takes a pale wooden bowl with a ladle standing in
   it. Both now steam, which the family language requires of every hot dish.
5. **Three reclaim rows show three bronze heads.** Three identical boxes at
   0.90-0.93, told apart only by a stamp illegible at 48 dp, now open on an axe
   blade, a pick head and a breastplate, each breaking the crate outline.
6. **The epic is the largest blade.** `bronze_longsword` shipped at 12% fill,
   the thinnest icon in the game and *shorter* than the uncommon sword it
   outranks. It now out-reaches every sword in the case.
7. **Nothing reads emissive.** `frost_claw` was a glowing cyan shard; it is a
   matte pale blue-grey talon with a dark root.

## Cost

**52 of 200 generations**, all `create_image_pixen` or `edit_image_pixen` at 1
each. 39 requested in batch 1 (13 assets x 3 rolls, submitted by the instance a
session-limit outage killed — **recovered from `E/raw/items/fetch_*.txt` and
re-fetched by job id, not re-rolled**), 13 in batch 2. Accepted 21 rolls,
rejected 29, held 2. No `edit_image` / `create_image_pro` fallback was needed:
DIR-09 budgeted up to 80 generations for it and none was spent.

Two pieces of the round's shared production intelligence paid off directly:
- `edit_image_pixen` at cost 1 did the whole crate group, the handle, the axe,
  the pick strap and both steams — 9 assets for 9 generations. DIR-09 had
  budgeted 24 for these plus an 80-generation `edit_image` fallback.
- Before rejecting `hornbound_bronze_axe` for reading gold, it was put through
  the shipped `toneBronze` remap (`E/tools/tone-bronze.js`). Only 40 px moved,
  so the brightness was never the defect and the roll shipped untouched.

## What did not close

- **`reinforced_pickaxe` could not be replaced, only amended.** All three
  regeneration rolls drew a hammer, a mace, and an off-palette horned collar —
  each lost the tool's identity to gain the steel. The shipped icon is the
  better *pickaxe*, so the grey strap and rivets were added to it by edit
  instead. It is distinct from `bronze_pickaxe` on the sheet read, but by the
  tell at the head-to-haft joint rather than by outline: it is the weakest
  separation in the set and the first thing to revisit if the owner disagrees.
- **The reclaim trio measures 0.82-0.88, not the < 0.85 DIR-09 proposed.** The
  crate body is deliberately shared — one crate motif is the recipe-art language
  recorded in `package-art.js` — so most of the mass is common by design and the
  differentiator is the protruding head. The ceiling in the test is set at 0.89,
  which is a tightening of a previously unbounded case and not a relaxation of
  any existing assertion. Abandoning the one-crate motif to reach 0.85 would be
  a content decision, not an art one (G-3).
- **`bronze_longsword` and `bronze_sword` remain the same weapon in two tiers.**
  The defect DIR-09 named (the epic shorter and thinner than the uncommon) is
  fixed; the family resemblance is intended and was left alone.
- **No Inventory render exists for the armour or crate groups.** The evidence
  harness starts every run at level 1, and there is no item-granting API on
  `StrideSession`; the vests and crates are locked behind skill levels and craft
  chains. Building a granting path for a screenshot would be verification
  machinery built without a named uncovered risk (G-1, M-01). The ivory group
  was reachable, because it drops from wolves and boars, so that is the group
  the Inventory render shows.

## Evidence

Sheets, all on `#1e1e1e`, in `GAME_BIBLE/ART/exploration/EPO03/review/items/`:

| Sheet | Shows |
|---|---|
| `before_vests_x2.png` / `after_vests_x2.png` | group 1 and 7, before and after, beside the other six torso icons |
| `before_ivory_x2.png` / `after_ivory_final_x2.png` | group 2 beside `boar_tusk` and `ram_horn` |
| `before_stews_x2.png` / `after_food_x2.png` | group 3 across the whole cooking list |
| `before_crates_x2.png` / `after_reclaim_x2.png` | group 4 |
| `before_swords_x2.png` / `swords_x2.png` | group 5 against all three lesser blades |
| `before_picks_x2.png` / `after_tools_x2.png` | groups 6, 9, 10 across every tool and haft |
| `before_edits_x2.png`, `batch2_beforeafter_x4.png` | every edited asset, before and after |
| `frost_claw_x4.png`, `claw_vs_ivory_x2.png` | the claw's two rejected routes and the accepted roll in the ivory row |
| `hornbound_tone_x4.png` | the axe as generated and as the shipped bronze remap would ship it |
| `pick_*_x4.png` (13) | every regeneration's three candidates beside the icon it replaces |

Device renders in `review/items/device/`:

- `epo_items_inventory_ivory.png` — **the Inventory at 393 x 852**, carrying the
  regenerated `pristine_wolf_fang` in the Materials grid, won in sixty real
  trips to Whispering Woods rather than granted. `inventory_materials_x3.png`
  is that grid enlarged for reading: at the size the phone draws it the fang is
  a tooth hanging in a braided cord, which is exactly the read the shipped fat
  ivory wedge did not have. It sits beside `wolf_pelt` and `meadow_herb`.
  `boar_tusk` and `great_tusk` are not in this render: `encountersPerVisit` is
  2, so a visit that opens on the wolf spends both slots there and never
  reaches the boar table. The alternating drive that would fix it was written
  but could not be compiled — the kit owner was mid-refactor on
  `inventory_screen.dart`, `pixel_asset.dart` and `surfaces.dart` — and an
  unverified drive is not evidence, so the verified wolf-first form was kept.
  The full ivory group is read side by side on `after_ivory_final_x2.png`.
- `epo_items_reclaim_rows.png` — the three reclaim rows on Craft. They are
  skill-locked, so the screen draws each recipe's icon as a bare silhouette:
  the purest possible form of the owner's test, and the three formerly identical
  crates now cast three different shapes.

## Tests

`flutter test test/item_icon_distinctness_test.dart
test/item_icon_resolution_test.dart test/rarity_ui_test.dart` — **30 passed.**
`flutter analyze` — the only issue is an unused import in
`test/combat_presentation_order_test.dart`, which belongs to another team and
predates this work.

Five assertions added to `item_icon_distinctness_test.dart`. They are
**named-pair ceilings, never a global threshold**: unconfusable pairs in this
set measure 0.85-0.90 unaligned (`ram_wool` against `ember_core` is 0.90), so a
global threshold would pass everything or condemn everything. A ceiling is
written only where the fix *was itself a silhouette change*, and it records what
that change achieved. No existing assertion was loosened (G-4); the byte-identity
test and the copper/tin silhouette assertion are untouched.

- the four hide vests are four silhouettes, not one — pairwise < 0.83
- the two stews are two vessels — `hearty_stew` vs `expedition_stew` and
  `herb_broth` < 0.80
- no icon is too thin to read at 48 dp — five named icons >= 20% fill
- the longsword out-reaches the swords it outranks
- the three reclaim crates show three different heads — pairwise < 0.89

**One of these caught a mistake of my own making rather than a defect in the
art.** The longsword assertion was first written as a pixel count and failed:
`bronze_sword` carries 585 px against the epic's 549, purely because its blade
is *broader*. Counting area would have condemned a correct icon and rewarded a
fatter one, so the assertion was rewritten to measure **reach** — the diagonal
of the ink's bounding box — which is what the eye reads and what DIR-09 asked
for. The art was not changed to satisfy the metric; the metric was corrected to
measure the stated property.

## Files

- `GAME_BIBLE/ART/exploration/EPO03/out/items/*.png` — the 20 accepted icons
- `GAME_BIBLE/ART/exploration/EPO03/src/items/*.png` — the 9 hosted edit sources
- `Scripts/art/package-art.js` — the `EPO03 ITEMS (PROD-ITEMS)` block. It refuses
  any file in `out/items` that does not already name a shipped icon, so this
  round cannot author a new item by accident (G-3)
- `test/item_icon_distinctness_test.dart` — the five ceilings above
- `test/screen_evidence_test.dart` — two capture blocks, `epo_items_reclaim_rows`
  and `EPO03 items: the ivory drops, side by side in the bag`

## Locks honoured

No new items, no content change. Nothing outside the item family was touched: no
kit file, no `atlas_layout.json`, no Dart outside the two test files. No
REQUESTS were filed and no Q- was raised — nothing in this family needed a
decision that was not already made.
