# GOV-05 — Current UI Runtime / Panel Architecture Map

Facts only, gathered by direct code read. No redesign proposed. All paths
relative to repo root. All line counts via `wc -l` on 2026-09-01.

## 1. Screen inventory (`lib/ui/screens/**`)

| File | Lines | Tab / route | SectionCard | Hand BoxDecoration | List type |
|---|---|---|---|---|---|
| `adventure/adventure_screen.dart` | 810 | Adventure tab (root) | uses child cards below | 0 | `ListView` |
| `adventure/activity_panel.dart` | 917 | Adventure — gather list | via SectionCard elsewhere | 3 | `ListView`×2 (nested) |
| `adventure/board_card.dart` | 1435 | Adventure — Goal Board card | (compound) | 9 | `Column`×10 |
| `adventure/encounter_card.dart` | 605 | Adventure — encounter list | via SectionCard elsewhere | 2 | `Column`×3 |
| `adventure/location_stage.dart` | 292 | Adventure — gather stage art | 0 | 1 | n/a |
| `adventure/goal_board_screen.dart` | 130 | pushed route (Goal Board) | 1 | 0 | `ListView`×1 |
| `adventure/goal_summary_card.dart` | 171 | Adventure — tracked-goal summary | 0 | 0 | `Column` |
| `adventure/goal_tracker_card.dart` | 304 | Adventure — Pursuit tracker | 0 | 0 | `Column`×3 |
| `adventure/bestiary_screen.dart` | 251 | pushed route (Field Notes) | 2 (+1 per region) | 0 | `ListView` |
| `character/character_screen.dart` | 558 | Character tab | 4 | 0 | `ListView`, `Row`/`Column` |
| `character/steps_block.dart` | 88 | Character — steps sub-block | 0 | 0 | n/a |
| `character/step_tracker_screen.dart` | 615 | pushed route (step history) | 1 | 3 | `ListView` |
| `character/audio_block.dart` | 175 | Character — audio settings | 0 | 0 | n/a |
| `character/playtest_block.dart` | 223 | Character — owner playtest tools | 0 | 0 | n/a |
| `skills/skills_screen.dart` | 334 | Skills tab | 1/skill card | 1 | `ListView` |
| `skills/skill_detail_screen.dart` | 512 | pushed route (skill roadmap) | 1 | 2 | `ListView` |
| `inventory/inventory_screen.dart` | 932 | Inventory tab | 1 (kitTray) + nested | 1 | `ListView` + `GridView.builder` |
| `craft/craft_screen.dart` | 1432 | Craft tab | 1/recipe detail | 7 | `ListView` |
| `combat/combat_screen.dart` | 727 | Modal (in-place over Adventure) | 1 (combatFrame) | 0 | n/a (Column) |
| `combat/combat_stage.dart` | 1035 | Combat — animated stage widget | 0 | 3 | n/a |
| `combat/combat_choreography.dart` | 359 | Combat — beat→segment logic | 0 | 0 | n/a |
| `world/world_screen.dart` | 731 | World tab | 2 | 4 | `ListView`×2 |
| `world/atlas/atlas_layers.dart` | 1652 | World — map paint layers | 0 | 0 | n/a (CustomPaint-heavy) |
| `world/atlas/atlas_layout.dart` | 376 | World — map layout math | 0 | 0 | n/a |
| `world/atlas/atlas_viewport.dart` | 461 | World — pan/zoom viewport | 0 | 0 | n/a |
| `world/atlas/atlas_selection_panel.dart` | 826 | World — place detail sheet | 0 | 0 | `Column`×3 |
| `world/atlas/atlas_place_info.dart` | 238 | World — place info block | 0 | 0 | n/a |
| `world/travel_pacing.dart` | 134 | World — travel pacing calc | 0 | 0 | n/a |
| `world/travel_transition.dart` | 378 | World — travel transition anim | 0 | 1 | `Column`×2 |
| `system/blocked_screen.dart` | 71 | System (HealthKit blocked) | 0 | 0 | `Column` |
| `system/stale_banner.dart` | 62 | Shared — stale-save banner | 0 | 1 | `Column` |

**Total screen-layer code: 16,834 lines across 30 files.** `SectionCard(` appears 33 times across the whole `screens/` tree (one primitive, thirty-three call sites, confirming `panel_skin.dart`'s own doc comment).

No screen file for Boards or Projects exists as a distinct destination — Goal Board (`goal_board_screen.dart`, pushed) and per-contract cards (`board_card.dart`) live under `adventure/`; there is no `projects/` directory at all — "Projects" content is folded into recipes/unlocks, not a separate screen family.

## 2. The primitive layer

**`SectionCard`** — `lib/ui/components/surfaces.dart:49`. Single universal container: one `BoxDecoration` (radius 14, 1px `borderDefault`, `surfaceCard` fill, optional top-down `wash` gradient) OR, if `PanelSkins.of(role)` resolves, a `PixelFrame` nine-patch. Doc comment states the exact debt: *"SectionCard draws one rectangle... at thirty-four call sites, and thirty-one... do not take even the optional hue wash."*

**`PanelRole`** enum (`panel_skin.dart:63`) — six values: `card`, `heroPlate`, `modalFrame`, `kitTray`, `combatFrame`, `boardSlip`. Deliberately screen-agnostic ("name kinds of surface, not screens").

**`PanelSkins`** (`panel_skin.dart:172`) — `static const Map<PanelRole, PanelSkin> authored`. **Every one of the six roles currently maps to the same single asset**, `_chassis` (`assets/ui/v1/frame/chassis_64.png`, 64×64 native, corner=16, band=8, scale=2 → one leather-welt/stitch chassis app-wide). The per-role differentiation the production plan originally reserved (heavier modal band, combat's own scarred edge) is explicitly deferred — doc: *"one family everywhere rather than a family and a gap."* `PanelSkins.of(role)` returns this same `PanelSkin` for all six; only an *empty* map would fall back to the painted rectangle, and the map is not empty.

**`PixelFrame`** (`pixel_asset.dart:315`) — nine-patch renderer. Draws 4 corners at 1:1 integer scale + 4 **tiled** (never stretched, `centerSlice` explicitly refused) edge strips via `_FramePainter` (`pixel_asset.dart:419`). Interior is **never drawn** by the frame — the panel's own fill or an optional `surfacePath` owns it.

**The `surfacePath` lever** — declared on `PanelSkin` (`panel_skin.dart:106-107, 155-156`) as `this.surfacePath, this.surfaceNative = 32` / `final String? surfacePath; final int surfaceNative;` with the doc: *"An optional seamless interior tile. Low tonal variation only: this sits behind body text, so it is grain, not pattern."* **It is declared but never read anywhere in the paint path** — `_FramePainter.paint()` (`pixel_asset.dart:426-508`) never references `skin.surfacePath`, and `_chassis` (the only `PanelSkin` instance in the registry) does not set it, leaving it `null`. The interior of every framed panel today is `DecoratedBox(color: StrideColors.surfaceCard)` set directly in `SectionCard.build()` (`surfaces.dart:133-135`), not a rendered surface tile. This is the exact seam the panel-family overhaul needs to light up per-family interior texture.

**`StrideType`** (`stride_typography.dart`) — 17 named `TextStyle` roles: `screenEyebrow, screenTitle, headerValue, numericHero, numericValue, cardTitle, sectionHeading, microLabel, body, sub, micro, compactLabel, tabLabel, tabLabelActive, itemName, itemCount, buttonLabel, buttonLabelSecondary, gateLabel`. Two font families only: `Cinzel` (display, `_wght700` variable-font axis) and `AlegreyaSans` (text/numerals, lining + optional `tabularFigures`).

**`StrideColors`** (`stride_colors.dart`) — 4-level surface ladder (`surfaceGround/Card/Block/Raised`), one border weight/colour, `accentSteps` (L-16 walking-only teal), 5 skill hues + 5 skill deeps, 5 rarity inks + 5 dims, action/danger/defense/reward-light/goal token families, and **5 region hues + 5 region deeps** via `forRegion(ContentId)` / `forRegionDeep(ContentId)` (`stride_colors.dart:301-318`, keyed by place id: `havens_rest→regionHaven`, `whispering_woods→regionWoods`, `stonefall_mine→regionStonefall`, `frostmere→regionFrostmere`, `forgotten_hollow→regionHollow`; unknown place falls back to `textSecondary`/`surfaceCard`). Also `forSkill(ContentId)` / `forSkillDeep(ContentId)` with the same fallback discipline.

**Button primitive — `StrideButton`** (`data_display.dart:363`), the *only* button widget in the app (grep for `StrideButton|PrimaryButton|ActionButton` finds nothing else named that way). Two constructors:
- `StrideButton(...)` — primary, full-width, `StrideButtonVariant {commit, attack, defense, ready}` register, optional `glow` (reserved for "Set out" only). **15 call sites** (excl. its own constructor).
- `StrideButton.secondary(...)` — quiet utility/exit register, shrink-wrapped, 34dp visual height inside a 44dp hit region. **28 call sites**.

Built on a bare `GestureDetector` (`HitTestBehavior.opaque`) + `Semantics(button: true)`; no Material `InkWell`/`ElevatedButton` anywhere. Standalone `GestureDetector(` (not via `StrideButton`) appears in 21 files for chips, tabs, rows and tappable cards (e.g. `_Chip` in `craft_screen.dart:481`, `_ChainBackChip`, filter chips, `_Tab` in `stride_tab_bar.dart:119`, skill card taps, item tiles).

**Progress bar implementations — no shared primitive; each screen hand-rolls one:**
- `SkillProgressBar` (`skills_screen.dart:187`) — `Stack` of two `ColoredBox`/`FractionallySizedBox`, 8dp tall, `TweenAnimationBuilder<double>` 600ms easing, reduced-motion branch.
- `CraftRepetitionBar` / `CraftRepetitionBar` (`craft_screen.dart:1224`, called `CraftRepetitionBar`) — same `AnimatedBuilder`+`FractionallySizedBox` pattern, 10dp tall, driven by a real `AnimationController` synced to `CraftController`.
- Combat HP bars are drawn inline inside `combat_stage.dart` (not extracted).
No `LinearProgressIndicator` anywhere (confirmed by `panel_skin.dart`'s own doc: "no Material anywhere").

**Chip implementations** — also no shared primitive:
- `SkillChip` (`data_display.dart:230`) — icon + uppercase label on `surfaceRaised`, `StrideRadius.chip`.
- `RequirementGate` (`data_display.dart:272`) — outlined-only capsule, never filled (states a fact, is not a control).
- `_Chip` (private, `craft_screen.dart:481`) — category/quantity filter chip, selected/unselected border+fill states.
- `_ProgressChip` (`board_card.dart:1317`), `RarityBadge` (`rarity_badge.dart:31`, has a `.compact` variant).

**Divider/rule implementations** — `StrideColors.separator` is the one within-card-rule colour (never used as an outline):
- `_Rule` (`character_screen.dart:550`) — 1px `ColoredBox`.
- `_Ruled` (`reward_layer.dart:139`), `RarityRule` (`rarity_item_title.dart:156`) — a rarity-rank thickness mark, not a hairline.
- Inline `Container(height: 1, color: StrideColors.separator)` between bestiary rows (`bestiary_screen.dart:134-140`).

## 3. Bottom navigation

File: `lib/ui/components/stride_tab_bar.dart` (`StrideTabBar`, 126 lines). Six fixed `Expanded` columns, one per `StrideDestination` (`shell/stride_destination.dart`) — **Adventure, Character, Skills, Inventory, Craft, World**, all `enabled: true` since Playable Phase 2 (no 7th tab, no Combat tab — combat is a modal per the enum's own doc). Bar height is `StrideGeometry.tabBarHeight = 64` (fixed; rationale doc: glyph 28 + gap 6 + label 11 = 45dp content). Each `_Tab` composes `PixelAsset.nav(glyph)` (14×14 native, drawn ×2 = 28dp) over `StrideType.tabLabel`/`tabLabelActive` (9.5px, under `MediaQuery.withNoTextScaling` — the tab bar is the one place text scaling is deliberately disabled). Active tab gets `surfaceBlock` fill + `StrideRadius.tabActive` (bottom corners only). Icons are `PixelIcons.navX` / `navXActive` pairs; the "active" variants are **not independently authored art** for most tabs — `Scripts/art/nav-active-variant.js` derives the brighter `_hi` variant by remapping a shared PLTE's colour indices, measured off the 3 tabs that originally shipped a hand `_hi` (`adventure/character/inventory`) and applied to the newer tabs (e.g. `world`) that didn't get one manually.

## 4. Header

File: `lib/ui/components/screen_header.dart` (`ScreenHeader`, 112 lines total with `BankedStepsReadout`). Shows: an `eyebrow` (uppercase micro-label, e.g. place name context) and a `title` (e.g. "Adventure"/a place name), left-aligned in a shrink-adaptive column, plus an optional `trailing` slot capped at `StrideGeometry.bankedFigureMaxFraction = 0.62` of header width. `regionInk`/`regionDeep` optionally tint the title and wash the header background per-place (via `StrideColors.forRegion`/`forRegionDeep`). Height is a **minimum** (`StrideGeometry.headerMinHeight = 61`), not fixed, so Dynamic Type does not clip it.

**Banked steps** — `BankedStepsReadout` (`screen_header.dart:119`), a `WalkingGlyph(role: .stock)` + tabular numeral (`formatSteps`, comma-grouped, no locale lib) + `BANKED STEPS` caption, right-aligned, minimum-width box (`bankedFigureMinWidth = 72`), animated via `TweenAnimationBuilder<int>` (~400ms) unless `disableAnimationsOf`. Sourced from `StrideSession`/`SessionController` (the caller passes `bankedSteps: int` in; the readout itself does no reading of session state — it is presentational only).

## 5. Craft screen (`lib/ui/screens/craft/craft_screen.dart`, 1432 lines)

- **Categories**: `enum CraftCategory {materials, food, gear, tools}`, derived from the output item's `RecipeOption.outputCategory`/`outputIsTool` (not authored per-recipe). Filter row is `_CategoryChips` (All + 4).
- **List grouping**: NOT by station or skill — by **readiness band**, via `_bands()` (`craft_screen.dart:386-411`): `Ready → One away → Missing → Locked` (locked + gated recipes share one "Locked" section). Each band a `SectionHeading` + rows.
- **Row widget**: `_RecipeRow` (`craft_screen.dart:533`) — 48px item icon in an `InsetWell`, `RarityName`, skill/XP or "one away" shortfall line, and a state chip (`LOCKED` / `LV n` / `×count` / `—`).
- **Detail/confirm flow**: tapping a row opens `_RecipeDetail` (`craft_screen.dart:651`) inline beneath it (not a separate screen/modal) inside a `SectionCard`: rarity badge, output line, `GearStatsBlock` or purpose text, per-ingredient held/required lines (with a "chain jump" to the ingredient's own recipe when it's itself crafted), consumed-prover/worn-gear warnings, then either `_ActiveCraftPanel` (if running) or `_QueueChips` (×1/×5/×10) + `StrideButton` (`variant: .ready`, label `Craft`/`Craft ×n`) + `StrideButton.secondary('Track as Pursuit')`.
- **Locked state**: row dims (`Opacity 0.55` on the icon when `!canCraft && !selected`), state chip reads `LOCKED`/`LV n`, detail shows `_reason()` (`craft_screen.dart:913-924`) as the button's `subLabel` — lock reason → skill gate → missing ingredients, in that priority order (mirrors engine refusal order).
- **"Ready" state**: `positiveReadyDim` border on the row, `positiveReady` state-chip ink, button `StrideButtonVariant.ready` (moss).
- **Completion feedback**: universal `ActivityResultCard` via `ActivityResultHost` (screen-level, not per-row) for MINOR results (auto-timed), and `RewardRaise`/`RewardLayer` (scrim overlay) for MEDIUM/MAJOR (finished equipment or level-up), holding until `Continue`/dismiss. `_ActiveCraftPanel` also runs a per-repetition `_CompletionPulse` (haptic + colour flash over `CraftRepetitionBar`).
- **Content count**: `assets/content/v1/recipes.json` has **39 recipe entries** (`"id"` occurrences).

## 6. Inventory screen (`lib/ui/screens/inventory/inventory_screen.dart`, 932 lines)

Single `SectionCard(role: PanelRole.kitTray)` holding everything: a `Carried` heading with total-item-count trailing, then per-`ItemCategory` groups (`material→equipment→consumable→quest`, plus an "Other" trailing group for uncategorised items) in that enum order. Equipment group opens with `_EquippedSummary` (three-slot readout) and a running `_EquipResult` line; consumable group shows `HP x / y` and `_FoodResult`. Each group renders `_ItemGrid` → `GridView.builder` (`SliverGridDelegateWithFixedCrossAxisCount`), then an optional detail block (`GearStatsBlock` for equipment / `_ItemPurposeBlock` for materials) beneath the grid for the tapped tile.

**Equipment figure**: `_EquippedSummary` (`inventory_screen.dart:428`) renders `PixelAsset(assetPath: TravelerArt.figureFor(session.equipmentVisualState), nativeWidth: 64, nativeHeight: 64, scale: 1)` — a **64×64 native, ×1 scale (64dp on screen)** standing Traveler figure, centred above the three equipment-slot columns. `TravelerArt.armorFigures` (`traveler_art.dart:103`) maps **3 authored armour classes** — `armor.plate`, `armor.jerkin`, `armor.coat` — to 3 south-facing PNGs (`traveler_south_plate.png`, `_jerkin.png`, `_coat.png`), each a single `create_character_state` PixelLab render on the canonical Traveler. `TravelerArt.variantOfItem` maps **8 chest items** onto those 3 classes (2 plate, 3 jerkin, 3 coat); an unmapped/empty slot falls back to the base `traveler_south.png`. No per-item unique figure exists — items collapse into 3 silhouettes.

**Item grid cell size**: `_ItemGrid._tileExtent()` derives extent from content; icon is `PixelAsset.item` = **48×48 native at scale 1 → 48dp rendered icon**, in every tile. Column count: `wanted = 4`, computed width `raw = (screenWidth - gap*(4-1))/4`, floored to even; if the resulting column width < `StrideGeometry.gridColumnFloor` (72dp) the grid drops to 3 columns. **On a 393dp-wide device** (the reference viewport used throughout the test suite): gutters 16dp each side + 3 inter-column gaps of 8dp → `raw = (393 - 32 - 24)/4 = 84.25` → floored even → **84dp column width**, well above the 72dp floor, so **4 columns** at ~84dp each, each holding a 48dp icon centred (icon is 57% of tile width). Tile height (`itemTileMinHeight` floor = 119dp, or content-derived if larger under Dynamic Type).

## 7. Character screen (`lib/ui/screens/character/character_screen.dart`, 558 lines)

Structure (top→bottom, all in one `ListView`): (1) identity `SectionCard` — 128dp portrait (`InsetWell.square(contentSize: portraitContent=128)` wrapping `PixelAsset.portrait`, 64×64 native ×2) beside name/level/skill-level-sum text column with a `_Rule` divider; (2) `StepsBlock`; (3) "What walking has built" card (`ValueTileRow` of total-walked/total-XP tiles); (4) "Skills" card (`_SkillRow` per skill: 24×24 icon well, name in skill hue, XP, `LEVEL n / max`); (5) `_CombatBlock` (Level/Experience/HP tiles, Attack/Defence tiles, then one `_EquippedLine` per occupied fighting slot with the item's own icon + rarity name + badge); (6) `AudioBlock`; (7) `PlaytestBlock` (owner-only tools, last).

**Portrait**: the *bust*, not the full figure — deliberately, per the file's own doc comment recording that VAWO01 tried the standing figure here and reverted it (a 64² body in a 128dp well leaves the face a handful of pixels; the figure lives in Inventory's `_EquippedSummary` instead). Uses `PixelIcons.portraitTraveler`.

**Equipment slots**: not a slot grid on this screen — combat-relevant slots (`weapon`, `armor`) are named lines (`_EquippedLine`) inside the Combat card, each with the item's 48px icon, rarity-inked name and `RarityBadge`. The full three-slot (`weapon/armor/tool`) summary with Equip/Unequip controls lives on the **Inventory** screen (`_EquippedSummary`), not here.

## 8. Combat screen

**Battlefield widget**: `CombatStage` (`combat/combat_stage.dart`, 1035 lines) — backdrop `192×96` native drawn at ×2 = **384×192dp**, clipped/centred (not resampled) on narrower phones; two `GroundedSprite`/animated-track figures at fixed backdrop columns (`travelerColumn`/`enemyColumn`, 116dp/276dp from backdrop left); a HUD strip **beneath** the backdrop (not an overlay) for HP bars, because the tallest enemy's head reaches within 32dp of the backdrop top.

**Command container** (`_CombatControls`, `combat_screen.dart:352-534`): a plain `Column` inside the `SectionCard(role: .combatFrame)` — **no fixed height in code**; it sizes to its content. Measured from `StrideGeometry`/button constants (default state, no Eat-chooser open):
  - intent line (micro, ~13dp) + 4dp gap
  - guard-reading line (micro, ~13dp) + 8dp gap (or a bare 4dp gap if absent)
  - `Attack` button: `minHeight 48` (`StrideGeometry.buttonHeight`)
  - 8dp gap
  - `Brace` button: `minHeight 48 + 12 = 60` (has a `subLabel`, so `buttonHeight + 12`)
  - 8dp gap
  - `Eat` button: `minHeight 48` (no sublabel in the common case)
  - 8dp gap
  - `Retreat` button (secondary): visual `minHeight 34` (`buttonHeightSecondary`), inside a 44dp hit region
  ≈ **17 + 21 + 48 + 8 + 60 + 8 + 48 + 8 + 34 ≈ 252dp** of controls, plus the `SectionCard`'s own `cardPaddingCompact` (12dp) top/bottom = 24dp, plus the `_CombatLog` block above it (`SectionHeading` + 1-4 lines, ~40-100dp) + a 12dp gap between log and controls.
  On an 852dp-tall device, the controls column alone is **≈30%** of total screen height; the whole `SectionCard` (log + controls + padding) is **≈35-40%**, and the stage above it adds another 192dp (+HUD) — so stage + card together typically exceed half the 852dp screen, leaving header (min 61dp) + tab bar (64dp) + insets to share the remainder. There is no single "command container height" constant to cite — it is arithmetic over button minimums, not a literal.

**Narration**: `_CombatLog` (`combat_screen.dart:235`) — most-recent-round-only text lines via `describeBeat()`, replaced by "Tap the stage to skip" while the stage replays.

**Result/loot**: `_ResultPanel` (`combat_screen.dart:561`) — not a screen widget but a set of `RewardBeat`/`RewardFacts`/`RewardItemRow`/`LevelUpCard` beats fed into the shared `RewardRaise` scrim-overlay component (`reward_layer.dart`), same mechanism Craft uses.

## 9. Encounter / creature preview

Widget: `_EnemyStage` (`adventure/encounter_card.dart:398-465`). A `Container` band, **`width: double.infinity`, fixed `height: 152`** (`_EnemyStage.height`), `surfaceBlock` fill + `borderDefault` + `StrideRadius.inner`, `ClipRRect`'d. Filled by the enemy's `CombatTrack` idle animation (`_EnemyIdle`) drawn at the **same ×2 scale as the combat stage itself** (`_EnemyStage.scale = 2`), bottom-aligned via a per-creature `groundOffset()` computed from each `CombatTrack`'s measured footprint (so wolf/crawler/salamander/bear/guardian all stand on one visual ground line despite differing canvas sizes). 152dp was chosen specifically so the tallest roster member (guardian, 71 content rows × 2 + 4dp bleed = 150dp) fits with nothing clipped — the file's doc records that the prior rule (drop to ×1 above a size threshold) inverted the roster's size ordering (bear/guardian ended up smaller on-card than the wolf/salamander). No backdrop/scene art in this band — "a strip, not a scene."

The Bestiary/Field Notes route (`adventure/bestiary_screen.dart`, 251 lines) is text-only by contrast — no creature art, static rows, one fact line per creature (tier, study-progress sentence, revealed drops), explicitly "not animated... not a completion meter."

## 10. Skills screen + skill detail

**`skills_screen.dart`** (334 lines): one `SectionCard` per skill (`wash: forSkillDeep(skill)`), tappable → pushes `SkillDetailScreen`. Card = `SkillHeaderRow` (32×32 icon plate + name in skill hue + `LV n`/`MAX`) → `SkillProgressBar` (hand-rolled two-layer `Stack`, 8dp tall, eased fill) → `SkillProgressCaption` → `_UnlockLines` (next **3** upcoming unlocks, capped) → right-aligned `ROADMAP` hint text (no icon/chevron widget, just text).

**`skill_detail_screen.dart`** (512 lines, pushed `MaterialPageRoute` via `SkillDetailScreen.open`): reuses `SkillHeaderRow`/`SkillProgressBar`/`SkillProgressCaption` from the card, then a full level-by-level roadmap from `StrideSession.skillRoadmapFor` — every level 1..max, unlock rows capped at 2 lines collapsed / +2 expanded, runs of "dead" (no-unlock) levels collapsed to one muted line, an "earned" band folded by default.

## 11. Evidence harnesses

Flutter is not on PATH; every command below needs:
```
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
```

| File | Renders | Env var (output dir) | Silent without var? |
|---|---|---|---|
| `test/screen_evidence_test.dart` | Real app, phone width, driven into specific states across 6 `testWidgets` groups: "polished surfaces" (gear recipe open on Craft, Inventory w/ equipment, Character), "Iteration 02 freshness pass", "Iteration 03 depth pass", "Hollow Field Ledger on the inspector", "World inspector, reached destination selected", "Game Feel & Character Presentation 01 moments" | `SCREEN_EVIDENCE_DIR` | Yes — becomes a mount-and-drive smoke test |
| `test/stage_evidence_test.dart` | Real `LocationStage` in **work mode** (gather backdrop + prop + profession loop) at 393×852, 5 compositions: `mine_copper`, `mine_tin`, `mine_hardened_locked`, `woods_oak`, `haven_meadow` | `STAGE_EVIDENCE_DIR` | Yes |
| `test/combat_golden_test.dart` | 3 `testWidgets`: golden "the wolf, turn 1, idle" at 393×852 (`combat_stage.png`); "the victory panel at 393×852" (`combat_victory.png`); an "evidence" group (guardian in the Hollow, idle + heavy-blow landing) writing extra PNGs when `COMBAT_EVIDENCE_DIR` is set | Golden files fixed; extra evidence via `COMBAT_EVIDENCE_DIR` | Golden always runs; evidence extras need the var |
| `test/board_reward_layer_test.dart` | Real app: hand in a Goal Board contract, expect the `RewardLayer` (eyebrow/item row/XP/Continue) over the board | `BOARD_EVIDENCE_DIR` (writes before/open-job/layer PNGs) | Yes |

Run one, e.g.:
```
SCREEN_EVIDENCE_DIR=/tmp/screens flutter test test/screen_evidence_test.dart
```

**Screens/states already renderable at 393×852** (confirmed by `phase1_golden_test.dart`'s `'the six screens at 393 x 852'` test): **Adventure, Character, Inventory, World, Craft, Skills** — plus a second pass at "the accepted save, 455,281 banked" (large-text/high-value variant), plus "the craft stage, mid-craft, with its station". Combat is covered separately by `combat_golden_test.dart` (stage + victory panel). Field Notes/Bestiary, Skill Detail, Goal Board, Step Tracker and the World atlas selection panel are exercised inside `screen_evidence_test.dart`'s driven-state groups (not as reference goldens).

**Not currently rendered by any harness**: the bottom nav bar and header in isolation (only ever seen as part of a full-screen capture), the Craft screen's *empty*/zero-recipe state, and any screen under **Reduce Motion** or non-1.0 Dynamic Type as a *golden* (the large-text state is exercised once, generically, not per-screen).

## 12. Reduce Motion / Dynamic Type / settings plumbing

**No dedicated app settings screen and no in-app "Reduce Motion" toggle.** Both read the **platform** (OS-level) accessibility signal ambiently, at each call site:
- Reduce Motion: `MediaQuery.disableAnimationsOf(context)` — **20 call sites** across `lib/ui` (e.g. `craft_screen.dart` completion pulse/repetition bar, `skills_screen.dart` progress-bar tween, `inventory_screen.dart` equip-result animation, `combat_stage.dart`, `stride_tab_bar.dart` is unaffected — it has no motion). No central `ReduceMotionScope`; each animated widget branches individually (`reduced ? Duration.zero : ...`).
- Dynamic Type: `MediaQuery.textScalerOf(context)` — **5 direct call sites** (`data_display.dart` `ValueTileRow`, `inventory_screen.dart` tile-extent math, `adaptive_text.dart` itself, `skills_screen.dart`/others), plus every `AdaptiveText` (`lib/ui/components/adaptive_text.dart`, 163 lines) instance implicitly shrinks-to-fit rather than clipping (`minScale` floor, default 0.85). `MediaQuery.withNoTextScaling` is used exactly once, deliberately, to **freeze** scaling inside the tab bar (`stride_tab_bar.dart:35`).

**Audio settings** (the one real player-facing settings surface) live in `character/audio_block.dart` (175 lines) — sound on/off + two bus volumes — reachable only via the Character tab, not a dedicated Settings destination. `character/playtest_block.dart` (223 lines) holds the owner-only debug/reset tools, also inline on the Character tab, last in the list.

There is no `Settings`-named class anywhere in `lib/ui` (`grep -rln "class.*Settings"` returns nothing).

## 13. Golden tests

**2 golden test files, 15 golden PNGs** in `test/goldens/`:
- `phase1_golden_test.dart` → `phase1_adventure(.png/_large.png)`, `phase1_character(_large)`, `phase1_inventory(_large)`, `phase1_world(_large)` (4 screens × 2 text scales = 8), `phase2_craft(_large)`, `phase2_skills(_large)` (2 screens × 2 = 4) — **12 files**, all at 393×852, Roboto (real font, not SF Pro), zero safe-area insets by design (documented limitation — device-only defects like the 57dp inventory-grid gap cannot be caught here).
- `combat_golden_test.dart` → `combat_stage.png`, `combat_victory.png`, `craft_stage.png` — **3 files**.

Update command (either file):
```
flutter test test/phase1_golden_test.dart --update-goldens
flutter test test/combat_golden_test.dart --update-goldens
```
`combat_golden_test.dart` is tagged `@Tags(<String>['golden'])`; both files' own doc comments state the limit explicitly: *"a regression golden between Flutter revisions... it does not mean the screen looks right... Look at a running build / Look at the image."*
