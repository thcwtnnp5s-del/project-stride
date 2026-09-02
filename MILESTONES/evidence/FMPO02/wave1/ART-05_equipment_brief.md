# ART-05 — Universal Visible Equipment: production architecture

Owner P0: gear visible in Character, Inventory figure, Combat (idle/attack/hit/
stagger/brace), Adventure idle, Mining, Woodcutting, Foraging. P1: travel walk,
craft loops. **No ghost gear** — no frame may drop the held item or revert the
garment.

## 1. Architecture: precomposed state families, coarse on both axes

Runtime overlays stay rejected (`traveler_art.dart` header): per-frame hand
anchors and occlusion order do not exist and cannot be measured. Every visual is
a **PixelLab character state** (garment + held item baked together) on the
canonical Traveler `c82b7da5-cda0-44eb-ae4e-30d73689e115`, animated per context.
The resolver picks a precomposed strip; it never composites.

**Body classes (4 authored + 2 aliases).** `base` · `armor.plate` ·
`armor.jerkin` · `armor.coat`; `armor.tunic` (waywarden) aliases to `base`,
`armor.plate.scaled` (scalewarmed) aliases to `armor.plate` until wave C buys
them their own states. Aliases are rows in `variantOfItem`, not fallthrough.

**Held-item classes (coarse by tier, never per item).** `weapon.unarmed` ·
`weapon.steel` (training) · `weapon.bronze` (sword / longsword / fanghilt) ·
`tool.axe.steel` · `tool.axe.bronze` (bronze / hornbound / goblin-toothed) ·
`tool.pick.steel` · `tool.pick.bronze` (bronze / reinforced / hornpoint /
tinbraced).

**`item.training_sword` must stop being unmapped.** Its absence is honest only
for the base body, whose baked blade *is* a plain steel sword. On a plated body
that fallthrough is exactly the banned "revert to base clothes".

## 2. The matrix — body × context × held item

| Family | Bodies | Held | States | Serves |
|---|---:|---:|---:|---|
| **F1 bare** | 4 | 1 | 4 — **all exist** | figure, inventory, adventure idle, foraging, travel walk |
| **F2 combat** (east 80×64) | 4 | 3 | 12 — 3 exist | idle/attack/hit/stagger/brace |
| **F3 woodcut** (west) | 4 | 2 axe | 8 — 1 exists | woodcutting loop |
| **F4 mine** (west) | 4 | 2 pick | 8 — 1 exists | mining loop |

**Existing states to reuse, not re-order:** Bronze Plate `bdb2773b`, Fur Jerkin
`7de7cfcb`, Heavy Coat `a3db12d1` are F1 in full — their south renders already
ship as `armorFigures` and their west/east rotations are free. Guard Unarmed
`bc5f632b` and Guard Bronze Sword `2108c61a` are F2 base+unarmed / base+bronze;
the shipped base combat set is base+steel (baked pale-steel blade, honest), and
shipped `activity_woodcut` / `activity_mine` are base+steel tools. These five
are also the **labelled reference images** attached to every new state order, so
garment and grip match rather than drift.

**New: 23 states** (9 combat, 7 axe, 7 pick) at ~30 gens ⇒ 690; **~74
animations**, v3 only, ~1 gen/direction ≤96px ⇒ 74. **Nominal 764; ≈880 with a
15% re-roll allowance.** Larger than the ~600 line — §6 says where 600 stops.

**Wave-A gen-0 probe (30 gens, run first):** order ONE armored *bronze* axe
state, then animate it with an action naming a *steel* axe. If v3 re-renders the
tool head, F3+F4 collapse from 14 new states to 7 and the matrix lands under
600. Prior evidence shows only that v3 *preserves* a held prop; it has never
been asked to change one. Cheap to learn, large if true.

## 3. Canvas, facing, anchor

| Context | Canvas | Facing | Anchor |
|---|---|---|---|
| Character / Inventory figure | 64×64, 1 frame | south | n/a (rest) |
| Combat, all 5 tracks | 80×64 | **east** | row 62 |
| Woodcut / Mine / Forage loop | 64 rows × 76 / 60 / 44 | **west** | row 62 |
| Adventure idle | 64×64 | ¾ south-west, as `traveler_idle_breathe` | row 62 |
| Travel walk (P1) | 64×64 × 6 | west | row 62 |

One asset serves Character and Inventory. v3 returns 88×88 → crop `(4,12,80,64)`.
Keep the shipped gather widths so stage layout is unchanged; if a union opaque
box exceeds one, widen the **declared** width and record it — never re-crop a
frame alone. **Anchor standard:** lowest opaque foot pixel on **row 62** of a
64-row canvas, every strip, every context. `traveler_unarmed_idle` at row 63 is
the sole legacy exception and declares its own row via `CombatTrack.anchorRow`;
any new deviation goes in `manifest.json` with a reason, or packaging lies.

## 4. Animation action descriptions (v3 only — templates discard props)

Prefix every combat and gather track with the garment ("wearing the bronze
breastplate, …"). That clause is the anti-revert clause: the hit/stagger
washouts in `EQUIPMENT_ROUND_RECORD_01.md` are what it exists to stop.

| Track | f | Action text following the garment prefix |
|---|---:|---|
| idle (loop) | 8–9 | standing in a fighting stance, breathing, holding the bronze sword low in the right hand |
| attack | 7 | swinging the bronze sword downward in an overhead cut and returning to stance |
| hit | 5–7 | flinching backward from a blow, the bronze sword still gripped in the right hand |
| stagger | 9 | stumbling backward and dropping to one knee, the bronze sword held clear of the ground |
| brace | 6 | raising the bronze sword across the body, feet set to absorb a blow |
| woodcut | 8 | swinging the bronze axe overhead into a tree trunk and pulling it back, both hands on the haft |
| mine | 8 | driving the bronze pickaxe into a rock face at chest height and pulling it back |
| forage | 9 | kneeling to pick a plant with both hands, no tool held |
| idle breathe / look around | 7 | standing at rest, breathing / turning the head left then right |
| walk west | 6 | walking west at a steady pace with the pack on |

**Brace has no track on this branch** (only on `fable-v2-experiment`). Author
it; if the mechanic is absent, package `status: withheld`. Never register a half
set — `CombatantArt` needs all four existing tracks or the loadout flickers
armed/unarmed inside one round.

## 5. Automated checks

1. **Single-component guard (exists).** `attachedPixelCount()`,
   `package-art.js:1528` — a frame's opaque pixels must form one 8-connected
   component reachable from the lowest foot pixel. Extend coverage from combat
   variants to **every** new strip (gather, idle, walk).
2. **NEW per-frame gear-colour-presence check.** Each set declares in
   `manifest.json` a `gearSignature: { ramp: [<hex>…], minPixels: n }` per gear
   element (blade, axe head, breastplate). Packaging counts exact-ramp matches
   per frame and throws if any falls below `minPixels`, set at 0.6 × the
   *minimum* of the accepted census (recorded, never guessed). It would have
   caught `bronze_hit` f6 (sword gone) and the template's washed-out vest before
   a human laid frames side by side, and catches a vanishing pickaxe directly.
3. **NEW completeness test** (Dart). Over every equippable armor × weapon and
   armor × tool pair, `combatantFor` / `gatherLoopFor` / `figureFor` /
   `idleScenesFor` must return a set whose **armor class equals the equipped
   armor's class**. "No revert to base clothes", as code.
4. **Extend `combat_gear_variant_test.dart`** (no variant shares a frame with
   the base set; each owns its defeat; the blow lands inside the attack; the
   stage precaches the *resolved* set) to gather and idle variants.
5. Regenerate `sprite_footprints.dart` — one row per new strip.

## 6. Production order — where 600 lands

**Wave A — armor everywhere + correct weapon in combat (~330).** A0 probe (30).
A1: 12 anims off the three existing armour states (idle breathe, look-around,
forage loop, walk west per body) ⇒ armor visible in Character, Inventory,
Adventure idle, Foraging and Travel for **12 gens**. A2: 9 combat states (270) +
36 tracks; brace deferred. *Exit test:* all 7 P0 contexts show the worn garment,
combat shows the owned weapon, §5.2 green on every frame.

**Wave B — bronze tool column (~190).** 6 states (3 armored bodies × axe/pick
bronze) + 6 loop tracks. Mining and woodcutting show armor *and* the bronze tool
family. **Cumulative ≈520 — where 600 lands, leaving ~80 for re-rolls.**

**Wave C — closure (~250, beyond 600).** Steel tool column for the three armored
bodies (6 states + 6 tracks, 186); own states for `armor.tunic` and
`armor.plate.scaled`; 5 brace tracks; P1 craft loops. Until C lands, an armored
body holding a *training* tool has **no honest strip** — both fallbacks are
banned lies — so ship it as a named, time-boxed gap in `PROJECT_STATE.md`, never
a silent fallthrough. A successful A0 probe deletes C's steel column and drops
the total to ≈580 nominal.

## 7. Resolver changes — `traveler_art.dart`, zero persisted state

All tables are static `const`/`final`, keyed by strings derived at read time from
`Equipment.bySlot` via `StrideSession.equipmentVisualState` (built fresh on every
read, `stride_session.dart:4258`). No `GameState` field, no `save_codec` change,
no `StateVersion` bump (stays **v9**), no fixture regeneration — GOV-02 §4 holds.

- **`variantOfItem`** — add `item.training_sword → weapon.steel`,
  `item.waywarden_tunic → armor.tunic`, all 6 tools to their four classes. A new
  `aliasOfClass` folds `armor.tunic` / `armor.plate.scaled` until wave C.
- **`armorFigures`** — shape unchanged; +1 row in wave C.
- **`combatVariants`** — becomes **two-axis**: `Map<String, CombatantArt>` keyed
  by `_gearKey(armorClass, weaponClass)` (`'armor.plate|weapon.bronze'`), with
  `combatantFor` composing the key from the *pair*. An empty weapon slot stays a
  **value** (`weapon.unarmed`) resolved before the table, as today. A missing
  pair must fail §5.3 rather than degrade — the degradations are the defects.
- **NEW `gatherVariants`** — `Map<String, GatherStrip>` keyed
  `'<skill>|<armorClass>|<toolClass>'` (foraging omits the tool segment).
  `GatherStrip` carries frames **plus** canvas width, footprint and strike frame,
  since a new strip owns its geometry. `AmbientAssets.activityLoopFor` /
  `activityCanvasFor` / `activityFootprintFor` / `strikeFrameFor` take an
  optional `EquipmentVisualState`, consult `TravelerArt` first, else base tables.
- **NEW `idleScenesFor(EquipmentVisualState)`** — for a non-base armor class, an
  `AmbientSceneSet` of that class's authored idles unioned with the scenes that
  draw **no** Traveler (cat set, `prop_fire`, `prop_yarn`), filtered by
  frame-path prefix exactly as `soloScenes` filters the cat by layer — derived
  from the one list, never a second hand-kept list that can drift.
- **`walkWestVariants`** — filled in wave A1 (armor class → 6 frames).
