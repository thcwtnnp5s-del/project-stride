# EPO03 wave 2 — EQUIPMENT (DIR-08) production report

**PROD-EQUIPMENT · 2026-09-02 · cap 500 · spent ~435 in cost lines.**

## Headline

**Four and a half of DIR-08's five top failures are closed in code and in art.** The
starting loadout can brace, the Plate Bronze Pick has stopped being the only
orange tool, the Bronze Longsword is a longsword rather than the Bronze Sword
in another key, and the Waywarden's Tunic has a body of its own instead of the
white shirt — a fifth body class authored in **every** context the resolver
answers for. The jerkin's fur ruff (failure 5, P6) is untouched and named
below.

The round's method finding is worth more than any one strip: **a new held item
costs one generation, not forty-four.** `edit_image_pixen` on an accepted,
shipped frame gives the new silhouette; `animate_character` v3 then takes that
loose PNG as `custom_start_frame_url`. A five-track weapon class on one body is
≈6 generations where FMPO02's `create_character_state` route was ≈49. The whole
longsword class — four bodies, twenty tracks — cost **30**.

## What shipped

### P1 — the two one-call fixes (40)

| Asset | What the phone shows that it could not before |
|---|---|
| `combat/traveler_base_steel_brace_f0-5.png` | A Traveler holding the **Training Sword** — the loadout every new player starts in — now has a braced figure when Brace is pressed. It had **no brace track at all** (0 files): FMPO02 authored brace for the two VAWO01 base sets and all nine armoured loadouts and missed the shipped base set. |
| `ambient/traveler_plate_bronzepick_mine_f0-7.png` | The Plate Bronze Pick's head is the muted copper the other four bronze tool strips use. It was the wave-A probe, ordered before the family's colour was set, and it snapped **0** pixels under `toneBronze` after the recolour where the old one needed the remap. Its f4 swing-streak is gone too. |

Both are one `edit_image` text call on an accepted strip, and both were
re-registered frame-for-frame onto their source's own bounding box by a new
`tools/register.js` — the model translates a frame by up to 7 px and the strips
are anchored per **strip**, so an un-registered re-dress pops.

### P2 — the longsword class (30)

`combat/traveler_{plate,jerkin,coat,base}_longsword_{idle,attack,hit,stagger,brace}`
— 20 strips, 144 frames. The blade is half again as long with a straight
cross-guard and a two-hand grip, and its tip passes the front foot in the idle
(the opaque box grows to the right by 11–27 px per body, measured). **The base
body's five tracks are declared 104 px wide**, not 80: its blade came back the
longest and its attack measures 98 px across, so the declared width grows and
is recorded rather than a frame being re-cropped (ART-05 §3). Anchor row 62
throughout.

`item.bronze_longsword` now maps to `weapon.longsword`;
`CombatAssets.longswordLoadouts` holds the four sets, spread into
`TravelerArt.combatVariants`.

### P3 — the warden body (~165)

One `create_character_state` (`76bf1ace`, 80 × 64, rotations already on row 62)
and **30 strips**: four held classes × five combat tracks, idle-breathe,
look-around, walk-west, forage, four gather loops, smith, cook, plus the 64²
standing figure (a centre-crop of the south rotation) and the bust. The
silhouette is a pointed hood up, a tiered cloth mantle wider than the
shoulders, a knee-length coat **split up the front so both legs show**, and
tall boots in moss green.

`item.waywarden_tunic` and `item.frostwarden_coat` both map to `armor.warden`.
The Frostwarden Coat's move out of `armor.coat` is the creative call DIR-08
flagged, carried out.

### P4 — the special heads (~200): the pick ships, the axe does not

`ambient/traveler_{plate,jerkin,coat,base,warden}_hornpick_mine_f0-7` — five
strips, 40 frames. The **Hornpoint Pickaxe** now carries a pale bone-white
curved horn tip on the same copper socket and haft: the opposite value to the
copper, so it reads at a glance, and it holds its shape in all forty frames
with every frame's foot row equal to its bronze source's.

**The special axe head was rejected as a class**, and `goblin_toothed_axe` and
`hornbound_bronze_axe` stay `tool.axe.bronze`. The head that came back is
genuinely different — wider, hooked, serrated, bone-spiked — but it *morphs
between frames*: on the warden strip it is pale in f1, small and dark in f2
and a forked orange hook in f3 and f5; the plate strip leaves a stray chip in
f5. A tool whose head changes shape mid-swing is a worse defect than the
hue-only difference it was meant to fix, and there were 65 generations left —
not enough to re-roll five strips. The candidates and their sheets are kept.

`gatherStripFor` learns one rule for it: a **special** head is a tier above
bronze, not a material of its own, so it degrades to bronze rather than to
steel. Every authored body has the row today, so that line is a guarantee for
the next content pack rather than a path taken now.

### The resolver and the tests

- `variantOfItem` now answers for **every** `category: equipment` id in
  `items.json`, including `item.traveler_tunic` → `base`. "Unmapped" and
  "deliberately the base body" used to look identical from outside, which is
  how the Waywarden hole survived a whole round.
- **New assertion**: every equippable id in `items.json` is a key of
  `variantOfItem`. An item that arrives without a decision now fails a test
  instead of quietly wearing the shirt.
- **New assertion**: `combatantFor(...).brace` is non-null for every armour ×
  weapon pair, including no-armour.
- `_token` gains `traveler_warden`; `equipment_visual_test.dart`'s "every
  bronze blade shares one set" is now the truth it should be — the longsword
  asserts a *different* strip and no shared frames with the bronze set.

`flutter test test/equipment_projection_test.dart test/equipment_visual_test.dart
test/combat_gear_variant_test.dart test/combat_gear_evidence_test.dart
test/craft_stage_evidence_test.dart` — **34 passing.** `flutter analyze` clean on
every file touched. `node Scripts/art/package-art.js --check` — **2,243 files up
to date**.

## Device-size proof (`EPO03/review/device/equip/`, 393 × 852 @ DPR 1)

| Render | What it settles |
|---|---|
| `gear_bronze_idle.png` beside `gear_longsword_idle.png` | The short leaf blade against a blade roughly twice as long reaching past the front foot — the owner's "must visibly differ, not just colour", at the size he will see it. |
| `gear_warden_longsword_{idle,swing}.png`, `gear_warden_unarmed_*` | The warden fights in what he is wearing, with the weapon he owns. |
| `stage_warden_{mine_bronze,mine_steel,woodcut_bronze,woodcut_steel,forage}_{f0,mid}.png` | The hooded body at all three gather stations with the right tool head. |
| `stage_craft_{smith,cook}_warden_{f0,mid}.png` | The warden at the anvil and the pot. |
| `review/equip/device_warden_figure_x2.png` | **The five south figures side by side**, and the five busts under them — DIR-08's success criterion 1. No pair is separable only by hue. |
| `review/equip/device_warden_work_x1.png` | The six work stages on one sheet. |
| `review/equip/p4_heads_x4.png`, `stage_warden_mine_horn_mid.png` | The bone tip against the copper head on all five bodies, and the horn pick at the seam at phone size. |

Every strip also has a ×2 or ×3 contact sheet under `EPO03/review/equip/`, feet
bottom-aligned, and every one was read before its verdict.

## Rejected, with reasons

25 v3 rolls bought 20 longsword tracks; 5 were rejected on the reading — four
staggers that walked backwards instead of going down on a knee, and a base
flinch that lost the blade entirely at f3. In the warden set, the unarmed punch
came back with a **black-and-white checkerboard** for a fist, and the steel and
longsword overhead cuts swung the blade 19 and 38 px out of the 64-row window.
The warden smith was rejected **twice**: reference mode turned him to face the
viewer and then to show his back, and the first text-mode retry invented an
anvil the stage already draws itself. Sheets and job ids are all in
`GAME_BIBLE/ART/exploration/EPO03/ledger/EQUIPMENT.md`.

## What did not close

1. **The jerkin's fur ruff (DIR-08 failure 5, P6, ≈340).** Light and base still
   share an outline at 2×; the jerkin reads as the shirt in tan. Untouched.
2. **The special axe head (`tool.axe.special`).** Ordered, judged and
   rejected; the two items resolve to bronze, which is what they are made
   of. A re-roll needs the head described as one fixed shape rather than a
   list of features, and about 100 generations.
3. **The Fanghilt Sword (`weapon.fang`, P5, ≈245).** `item.fanghilt_sword`
   stays on `weapon.bronze`, which is honest — it is a bronze blade — but it
   does not yet have the ivory tusk-hook guard the matrix describes.
4. **The warden carries no backpack.** Every other body does. The cloak covers
   the back, so it is defensible, but it is a difference from the other four
   and the owner should rule on it; re-authoring the state is ≈44.
5. **The longsword's blade midtone runs lighter than the bronze sword's.** The
   census is clean — 0 gold-leaning pixels by ART-01's own predicate, and the
   bronze count per frame matches the shipped bronze idle — but at ×3 on a dark
   sheet it reads paler than the short blade. A device read should decide it.
6. **The warden's contact footprints are 40–41 px wide** on the longsword
   tracks (the blade tip is inside the lowest four rows), against 10–13 px for
   every other Traveler strip. The shadow under a longsword figure is
   correspondingly wide. Measured, not tuned — but the device read should say
   whether it looks like a shadow or a smear.
7. **The base body's `weapon.steel` gather column and the base brace's own
   pose.** The re-dressed `base|steel` brace inherits its source's weakness:
   the blade reads in f0–f2 and is hidden behind the forearms in f3–f5, which
   the armoured brace strips do not do. It is the source's pose, not the edit's.

## Files written

- `assets/art/v1/combat/traveler_base_steel_brace_f*`, `traveler_*_longsword_*`,
  `traveler_warden_*` (20 + 20 combat strips)
- `assets/art/v1/ambient/traveler_plate_bronzepick_mine_f*` (replaced),
  `traveler_warden_*` (10 ambient strips)
- `assets/art/v1/sprite/traveler_south_warden.png`,
  `assets/art/v1/portrait/traveler_warden.png`
- `lib/ui/icons/traveler_art.dart`, `lib/ui/icons/combat_assets.dart`,
  `lib/ui/icons/sprite_footprints.dart` (generated)
- `Scripts/art/package-art.js` — one new block, `EPO03 EQUIPMENT
  (PROD-EQUIPMENT)`, after the FMPO02 matrix. The one edit outside it moves the
  `traveler_plate_bronzepick_mine` row out of `FMPO_AMBIENT_STRIPS`, with the
  reason in place: emitting a path from two blocks makes `--check` compare the
  old bytes against the new file forever.
- `test/equipment_projection_test.dart`, `test/equipment_visual_test.dart`,
  `test/combat_gear_evidence_test.dart`, `test/craft_stage_evidence_test.dart`
- `GAME_BIBLE/ART/exploration/EPO03/{src,out,raw,review}/equip*`,
  `tools/{register,tone-bronze,pad,pull-epo-tracks}.js`,
  `ledger/EQUIPMENT.md`

## Requests filed

None. No shared kit file was touched, and no `Q-` was raised: every decision
this round was either DIR-08's or a production one inside it.

## The final matrix

| Family (class) | Items | Bodies authored | Strips |
|---|---|---|---|
| `base` | traveler_tunic (explicit row now) | — | shipped + longsword |
| `armor.plate` | bronze_chestplate, scalewarmed_chestplate | yes | + longsword |
| `armor.jerkin` | wolfhide, tuskbound, frostlined jerkins | yes | + longsword |
| `armor.coat` | bearhide_coat, clawguard_coat | yes | + longsword |
| **`armor.warden`** | **waywarden_tunic, frostwarden_coat** | **new** | **30 strips: 4 weapon classes × 5 tracks, 4 gather, forage, idle-breathe, look-around, walk-west, smith, cook, figure, bust** |
| `weapon.unarmed` / `weapon.steel` / `weapon.bronze` | as before | all five | base+steel brace new |
| **`weapon.longsword`** | **bronze_longsword** | **plate, jerkin, coat, base, warden** | **25 strips** |
| `weapon.fang` | fanghilt_sword | — (stays bronze) | not authored |
| `tool.{axe,pick}.{steel,bronze}` | as before | all five (warden new) | 4 warden loops new |
| **`tool.pick.special`** | **hornpoint_pickaxe** | **all five** | **5 strips** |
| `tool.axe.special` | goblin_toothed, hornbound | rejected — stay `tool.axe.bronze` | 5 candidates kept, none shipped |
