# DIR-08 — Character / Equipment Director: silhouette matrix and strip bill

Looked at: the seven device captures, the FMPO02 equipment report and ledger,
`traveler_art.dart`, `equipment_projection_test.dart`, and a ×3 contact sheet of
every body's figure / bust / idle f0 / walk f0 / combat idle f0 (24 cells).
Spent 0 generations.

## TOP FAILURES

1. **Weapons differ by hue only.** Training, Bronze Sword, Bronze Longsword and
   Fanghilt are one blade shape in two colours; the epic longsword *is* the
   bronze sword. Phone-visible in every fight.
2. **Tools differ by hue only.** Five T2 heads (goblin-toothed, hornbound,
   reinforced, hornpoint, tinbraced) all draw the plain bronze head; the
   Plate Bronze Pick is a saturated orange the other four are not.
3. **`waywarden_tunic` draws the shirt** in all ten contexts — the last true
   "wrong clothing" item.
4. **`base|weapon.steel` has no brace track** (0 files); a training-sword
   player pressing Brace gets no braced figure.
5. **Light vs base share an outline** at 2×: the jerkin reads as the shirt in
   tan; only the fur collar and the ginger hair (a known debt) separate them.

## WHAT TO REPLACE

### The silhouette matrix (23 items → 5 bodies, 4 weapons + unarmed, 6 tool classes)

| Family (class) | Items | Silhouette at 2× — what differs by outline, not hue | Today |
|---|---|---|---|
| BASE `base` | traveler_tunic | slim torso, short open vest, sleeves, pack | exists |
| LIGHT `armor.jerkin` | wolfhide, tuskbound, frostlined jerkins | fur ruff wider than the head, hem cropped at the belt, wrapped forearms | exists — ruff reads as collar only (P6 debt) |
| BRONZE `armor.plate` | bronze_chestplate, scalewarmed_chestplate | pauldrons double the shoulder line, rigid block torso, straight waist | exists |
| HEAVY COAT `armor.coat` | bearhide_coat, clawguard_coat | knee hem that swings, hood up, belt | exists |
| **SPECIAL / WARDEN `armor.warden`** | **waywarden_tunic, frostwarden_coat** | tiered shoulder mantle (soft, wider than pauldrons), hood point, knee-length **split** skirt showing the legs, tall boots, cloak tail on the walk | **new** |
| `weapon.unarmed` | — | empty hands | exists |
| TRAINING `weapon.steel` | training_sword | short pale blade, small guard | exists |
| BRONZE `weapon.bronze` | bronze_sword, (fanghilt until P5) | leaf blade, copper | exists |
| **LONGSWORD `weapon.longsword`** | **bronze_longsword** | blade ≈1.5×, tip passes the front foot in idle, straight cross-guard, two-hand grip, carried low | **new** |
| **FANG `weapon.fang`** | **fanghilt_sword** | bronze-sword length, pale ivory tusk-hook guard and hilt | new (P5) |
| `tool.axe.steel` / `tool.pick.steel` | training_axe / training_pickaxe | pale plain heads | exists |
| `tool.axe.bronze` / `tool.pick.bronze` | bronze_axe / bronze_pickaxe, **reinforced, tinbraced** | copper heads (a band is sub-pixel at 2× — stays bronze) | exists |
| **`tool.axe.special`** | **goblin_toothed_axe, hornbound_bronze_axe** | wider hooked head with a serrated bit and a horn spike | new (P4) |
| **`tool.pick.special`** | **hornpoint_pickaxe** | bronze head with a long curved pale horn tip | new (P4) |

`frostwarden_coat` moves from coat to warden (a creative call — flag to the
owner; cost 0, one row). `scalewarmed_chestplate` stays plate: it is a
chestplate, and a scale skirt is sub-pixel.

### Resolver (`traveler_art.dart`, owner per GOV-05) and test

- `variantOfItem`: add `item.waywarden_tunic` **now** as `armor.jerkin` (nearest
  correct family; never absent), flipping to `armor.warden` with
  `frostwarden_coat` when the warden rows are all registered. `bronze_longsword`
  → `weapon.longsword`, `fanghilt_sword` → `weapon.fang`, the three special
  heads → `tool.*.special`, each **only when its family is complete in every
  context** — the test forbids half families, and G-4 forbids relaxing it.
- `_nearestArmed` gains `weaponLongsword` / `weaponFang` in its order after
  bronze; `gatherStripFor` treats `special` as a tier that degrades to bronze
  (the body never degrades). New rows in `armorFigures`, `portraitFigures`,
  `idleVariants`, `walkWestVariants`, `craftVariants`, `gatherVariants`,
  `CombatAssets.armouredLoadouts`.
- `equipment_projection_test.dart`: (a) every `kind: equipment` id in
  `items.json` is a key of `variantOfItem` — the unmapped-item hole closes as
  code; (b) every `combatantFor` result has a non-null `brace`; (c) `_token`
  gains `traveler_warden`; the existing `_${held}_` check covers `longsword`.
- No new guard framework: the FMPO02 `tools/measure.js` census (blade / head
  colour per frame, single component, foot row) runs on every accepted strip.

## WHAT TO KEEP

All 52 accepted FMPO02 tracks, the six craft re-dresses, the three busts, the
brace sets, the two-axis resolver and its fallthrough order, the 67-row combat
canvas rule, anchor row 62. Nothing shipped is re-ordered.

## PRODUCTION FAMILY — the strip bill, in priority order

Canonical Traveler `c82b7da5…`; combat east 80×67; gather/craft west; bare ¾/south.
Unit costs (GOV-04): `create_character_state` 80×64 ≈44 (call `get_balance`
after the first); `animate_character` v3 1/track; `edit_image` reference or
text ≈20 per ≤8-frame call, first-roll accept high.

| Pri | Block (atomic — registers whole or not at all) | Strips · frames | Method | Cost |
|---|---|---|---|---:|
| **P1** | `base\|steel` brace 6f (re-dress `base_bronze_brace`, steel blade); Plate Bronze Pick mine 8f recoloured to the muted copper of the other four | 2 · 14 | edit_image ×2 | **40** |
| **P2** | **Warden body**: 3 combat states (the unarmed one at 80×64 doubles as the bare body — its south rotation is the figure) + 15 tracks (idle 8, attack 8, hit 6, stagger 8, brace 6 × unarmed / steel / bronze); bare 4 tracks (breathe 8, look 7, walk 6, forage 9); gather 4 loops (mine / woodcut × steel / bronze) re-dressed from the coat strips; smith 7 + cook 7 re-dressed; bust 1 | 25 · 184 (+ figure, bust) | 3×44 + 19×1 + 4×20 + 2×20 + 20 | **291** |
| **P3** | **Longsword class**: 5 bodies × 5 tracks | 25 · 180 | 5 states 220 + 25 anims | **245** (196 on 4 bodies) |
| P4 | Special tool heads: axe + pick × 5 bodies, head-swap text edits of the bronze loops | 10 · 80 | edit_image ×10 | 200 |
| P5 | Fang class: 5 bodies × 5 tracks | 25 · 180 | 5 states + 25 anims | 245 |
| P6 | Jerkin ruff widened across its 17 strips | 17 · ~130 | edit_image ×17 | 340 |

**Cut rule:** every item is mapped to an authored family at every cut line
(P1 alone already satisfies it, waywarden on the jerkin row). A family lands
whole; partial raw is kept under `EPO03/src/equipment/` and named in
`PROJECT_STATE.md`. Alternative order for the producer, same cap: P1 + P3 on
four bodies + P4 = 436 makes weapons *and* tools differ now and leaves the
fifth body for a second allotment.

## PIXELLAB BUDGET

**Cap 450.** P1 + P2 = 331 nominal, ≈380 with a 15 % re-roll reserve; P3 needs
a second allotment of ≈250 (or the cap at ≈620 for P1–P3). P4–P6 (≈785) are
named gaps. Ledger `EPO03/ledger/EQUIPMENT.md`, one row per job.

## PHONE-SCALE SUCCESS CRITERIA

Checked on the iPhone with each of the 23 items equipped in turn, across
Character, Inventory, Adventure idle, Combat (all five tracks), Mining,
Woodcutting, Foraging, Smithing, Cooking, Travel:

1. Five south figures side by side in Character are told apart by outline at
   arm's length; any pair separable only by hue FAILS.
2. Longsword tip passes the front foot in combat idle; the training blade does
   not reach the knee; Brace shows a braced figure on every loadout.
3. Never the shirt, never a blade the player does not own, never a plain head
   for a special tool once P4 lands; the hood, hair and ruff do not flicker
   when only the weapon changes.
4. Mine / woodcut strike frames land the head on the prop (measured, as FMPO02).
5. `flutter test` green with the three new assertions; goldens regenerated
   only after each screen's diff is inspected.
