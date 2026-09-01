# FOUNDATION-C — UI Architecture Forensics

```
Milestone: VISUAL_AUDIO_WORLD_OVERHAUL_01 (VAWO01), Wave 0
Author:    FOUNDATION-C (UI architecture forensics)
Date:      2026-09-01
Branch:    presentation-combat-evolution-01
Scope:     READ-ONLY. No file outside this report was modified.
Method:    Static census of lib/ (86 Dart files, 40,783 lines) by grep and
           direct reading. Every number below is a real grep count taken on
           this working tree; none is an estimate. Commands are in §10.
```

## 0. The headline, before the tables

The owner's complaint — *"still looks too generated / generic", "too app-like",
"Flutter UI over sprites"* — is accurate, and this audit locates it in four
structural facts rather than in taste:

1. **There is no typeface.** `pubspec.yaml` has no `fonts:` section and the
   string `fontFamily` appears nowhere in `lib/` except in a comment
   (`lib/ui/components/adaptive_text.dart:117`). All **292 text sites**
   (225 raw `Text(`, 67 `AdaptiveText(`) render in the host platform's system
   face — San Francisco on iOS. Hand-authored pixel art sits beside the iOS
   system font on every screen. This is the largest unaddressed tell and it has
   a one-file fix.

2. **One rectangle draws the product.** `SectionCard`
   (`lib/ui/components/surfaces.dart:42`) is constructed at **33 sites**;
   **28 take the default `PanelRole.card`**, and `PanelSkins.authored`
   (`lib/ui/components/panel_skin.dart:183`) is empty, so all 33 paint the
   identical radius-14 / 1 px `borderDefault` / `surfaceCard` rectangle. Only
   **3 sites** pass a `wash`. The architecture to fix this exists and is unused.

3. **The type hierarchy has collapsed into one register.** Of 326 `StrideType`
   role references, **232 (71%) are `micro` (131), `microLabel` (56) and
   `sub` (45)** — all 11–13 px, all `textSecondary`/`textMuted`. `cardTitle` is
   used 7 times, `numericHero` twice, `screenTitle` once. Nearly every word in
   the game is small grey supporting text on a flat dark rectangle.

4. **The identity palette is authored and unused.** The region hues exist
   (`lib/ui/theme/stride_colors.dart:289-318`) and `forRegion`/`forRegionDeep`
   are each called **exactly once**, both in `lib/ui/shell/stride_shell.dart:93`
   and `:94`. `forSkillDeep` is called 4 times. `StrideColors.lockedScrim`
   (`stride_colors.dart:344`) has **zero** call sites — a duplicate local
   constant at `lib/ui/screens/adventure/location_stage.dart:97` is what
   actually paints. Ten authored biome colours touch one gradient in one header.

The good news, which shapes every recommendation: **there is essentially no
stock Material in the product.** Strict-boundary greps over `lib/` find
`ListTile` 0, `Chip` 0, `ElevatedButton` 0, `Divider` 0,
`LinearProgressIndicator` 0, `InkWell` 0, `Scaffold` 1, `AppBar` 1,
`AlertDialog` 1, `TextButton` 1, `OutlinedButton` 4 — and **every one of those
last five is inside `lib/debug/dev_harness.dart`**, which ships debug-only. The
one `Material(` is `lib/ui/stride_app.dart:221`, a deliberate
`MaterialType.transparency` wrapper documented at `:195-224`.

So the app-like feeling is **not** unremoved Material. It is a very disciplined
system with too few registers, no voice, and an unused identity layer. That is
good news: the leverage is in primitives, exactly as the brief supposed.

---

## 1. Screen inventory

### 1.1 Tab destinations (6, hosted by `IndexedStack` at `stride_shell.dart:136`)

| # | Screen | File:line | One line |
|---|---|---|---|
| 1 | `AdventureScreen` | `lib/ui/screens/adventure/adventure_screen.dart:58` | The gameplay screen: what walking bought, what an action costs, and the action |
| 2 | `CharacterScreen` | `lib/ui/screens/character/character_screen.dart:45` | What walking has built — portrait, equipment, skills, blocks |
| 3 | `SkillsScreen` | `lib/ui/screens/skills/skills_screen.dart:38` | Progression visibility, and nothing else |
| 4 | `InventoryScreen` | `lib/ui/screens/inventory/inventory_screen.dart:54` | Everything the player holds — filter pills + 3/4-column icon grid |
| 5 | `CraftScreen` | `lib/ui/screens/craft/craft_screen.dart:88` | Categories, recipe list, one recipe's working surface, timed craft flow |
| 6 | `WorldScreen` | `lib/ui/screens/world/world_screen.dart:123` | The World Atlas — pannable region window, places as markers, travel costs |

Destination set fixed at six by `DECISIONS/0004` §5; enum at
`lib/ui/shell/stride_destination.dart:37`.

### 1.2 Pushed full-screen routes (4, all `MaterialPageRoute`)

| # | Screen | File:line | Push site | One line |
|---|---|---|---|---|
| 7 | `SkillDetailScreen` | `lib/ui/screens/skills/skill_detail_screen.dart:58` | `:68` | One profession's whole plannable future |
| 8 | `GoalBoardScreen` | `lib/ui/screens/adventure/goal_board_screen.dart:39` | `:46` | The one-press planning surface (the location's own notice board) |
| 9 | `BestiaryScreen` (Field Notes) | `lib/ui/screens/adventure/bestiary_screen.dart:35` | `:43` | The Traveler's journal of creatures met |
| 10 | `StepTrackerScreen` | `lib/ui/screens/character/step_tracker_screen.dart:41` | `:47` | Day/week step history behind the Character tab's Steps card |

### 1.3 Surfaces the owner would call screens, that are not routes

| # | Surface | File:line | Hosted as |
|---|---|---|---|
| 11 | `CombatScreen` | `lib/ui/screens/combat/combat_screen.dart:65` | **Inline in the Adventure `ListView`** (`adventure_screen.dart:117`) — combat is a card in a scroll, not a place |
| 12 | `CombatStage` | `lib/ui/screens/combat/combat_stage.dart:77` | Inside `CombatScreen` — backdrop, two figures, effects, HUD |
| 13 | `ActivityPanel` (gathering) | `lib/ui/screens/adventure/activity_panel.dart:40` | A `SectionCard` on Adventure |
| 14 | `LocationStage` (the diorama) | `lib/ui/screens/adventure/location_stage.dart:67` | Full-bleed at the top of Adventure |
| 15 | `LocationBoardCard` (contracts/projects) | `lib/ui/screens/adventure/board_card.dart:40` | `SectionCard` on Adventure — 1,436 lines, the largest UI file |
| 16 | `EncounterPanel` / `EncounterCard` | `lib/ui/screens/adventure/encounter_card.dart:62`, `:213` | `SectionCard` on Adventure |
| 17 | `GoalTrackerCard` / `GoalSummaryCard` | `lib/ui/screens/adventure/goal_tracker_card.dart:23`, `goal_summary_card.dart:27` | `SectionCard`s on Adventure |
| 18 | `AtlasViewport` | `lib/ui/screens/world/atlas/atlas_viewport.dart:108` | The World screen's map window |
| 19 | `AtlasSelectionPanel` | `lib/ui/screens/world/atlas/atlas_selection_panel.dart:60` | The World screen's place inspector |
| 20 | Travel transition | `lib/ui/screens/world/travel_transition.dart:63` (`showTravelTransition`), card at `:128` | `showGeneralDialog`, 140 ms fade |
| 21 | `StepsBlock` | `lib/ui/screens/character/steps_block.dart:39` | `SectionCard` on Character |
| 22 | **Audio settings** (`AudioBlock`) | `lib/ui/screens/character/audio_block.dart:30` | `SectionCard` on Character — **there is no Settings screen**; this is it |
| 23 | `PlaytestBlock` | `lib/ui/screens/character/playtest_block.dart:37` | `SectionCard` on Character (owner playtest controls, `DECISIONS/0025`) |
| 24 | `RewardLayer` | `lib/ui/components/reward_layer.dart:154` | Full-screen scrim + panel — the game's biggest emotional moment |
| 25 | `RewardBeat` / `LevelUpCard` | `lib/ui/components/reward_beat.dart:69`, `:223` | Inside the reward layer |
| 26 | `ActivityResultHost` / `ActivityResultCard` | `lib/ui/components/activity_result.dart:219`, `:130` | Universal completion card (GFCP01 Correction 01) |
| 27 | `StaleBanner` | `lib/ui/screens/system/stale_banner.dart` | Inline banner on 6 screens |
| 28 | `BlockedScreen` | `lib/ui/screens/system/blocked_screen.dart:30` | Bootstrap refusal, before the shell (`stride_app.dart:238`) |
| 29 | `DevHarnessScreen` | `lib/debug/dev_harness.dart:119` | Debug-only long-press on the header (`stride_shell.dart:65`). **The only raw-Material surface in the codebase** |

**Not present anywhere:** a Settings screen, an onboarding / first-run screen, a
map legend, an About/credits screen, a save-management screen.

---

## 2. The existing UI primitive layer

### 2.1 Theme / token files (`lib/ui/theme/`, 4 files, 721 lines)

| File:line | Public API |
|---|---|
| `stride_colors.dart:28` | `abstract final class StrideColors`. 4 surface rungs (`surfaceGround` `#14120F`, `surfaceCard` `#201C17`, `surfaceBlock` `#2C2620`, `surfaceRaised` `#3A332B`); `borderDefault`, `separator`; `textPrimary/Secondary/Muted`; `accentSteps`/`accentStepsDim`; 5 skill hues + `forSkill(ContentId)`; 5 rarity inks + 5 dims; 4 category hues (declared, unused). V2 extension: `actionSheen/actionEdge/actionGlow`, `positiveReady(+Dim)`, `goalActive(+Dim)`, `danger(+Dim)`, `defenseSheen/defenseEdge`, `rewardLightInk/rewardGlow/rewardWashTop`, 5 region ink+deep pairs with `forRegion`/`forRegionDeep`, 5 skill deeps with `forSkillDeep`, `lockedScrim` |
| `stride_typography.dart:32` | `abstract final class StrideType`. 19 roles: `screenEyebrow`, `screenTitle`, `headerValue`, `numericHero`, `numericValue`, `cardTitle`, `sectionHeading`, `microLabel`, `body`, `sub`, `micro`, `compactLabel`, `tabLabel`, `tabLabelActive`, `itemName`, `itemCount`, `buttonLabel`, `buttonLabelSecondary`, `gateLabel`. **No role names a `fontFamily`.** |
| `stride_metrics.dart:13` | `StrideSpace`: `s2 s4 s6 s8 s10 s12 s14 s16`, `screenGutter`=16, `cardPadding`=14, `cardPaddingCompact`=12, `blockPadding`=10, `cardGap`=10, `gridGap`=8, `rowGap`=6, `iconLabelGap`=6 |
| `stride_metrics.dart:47` | `StrideRadius`: `card`=14, `inner`=10, `chip`=8, `gate`=6, `tabActive`=8 (bottom corners only) |
| `stride_metrics.dart:65` | `StrideGeometry`: `headerMinHeight`=61, `bankedFigureMinWidth`=72, `bankedFigureMaxFraction`=0.62, `tabBarHeight`=64, `activityStage`=180, `portraitContent`=128, `buttonHeight`=48, `buttonHeightSecondary`=34, `buttonHitFloor`=44, `itemTileMinHeight`=119, `gridColumnFloor`=72 |
| `stride_theme.dart:13` | `ThemeData strideTheme()`. `useMaterial3: false`, dark, `NoSplash.splashFactory`, transparent splash/highlight/hover. Sets only 3 `TextTheme` slots. **Deliberately not the token store** (`:3-5`) |
| `rarity_style.dart:38` | `final class RarityStyle` with `ink`, `accent`, `label`, `badgeLabel`; statics `of(Rarity)`, `maybe(Rarity?)`, `inkOr(Rarity?, Color)`. Exhaustive switch, no default arm |

### 2.2 The skin / nine-slice layer

| Symbol | File:line | API |
|---|---|---|
| `enum PanelRole` | `lib/ui/components/panel_skin.dart:63` | `card`, `heroPlate`, `modalFrame`, `kitTray`, `combatFrame`, `boardSlip` |
| `final class PanelSkin` | `panel_skin.dart:98` | `{assetPath, nativeWidth, nativeHeight, corner, band, scale, surfacePath?, surfaceNative}`; derived `inset` (= `band * scale`), `cornerExtent`. Four debug asserts on the geometry |
| `abstract final class PanelSkins` | `panel_skin.dart:172` | `static const Map<PanelRole, PanelSkin> authored` — **EMPTY** (`:183`); `of(PanelRole)` (`:186`); `insetFor(PanelRole)` (`:194`); `_reserve` (`:200`) = card 0, kitTray 0, heroPlate 12, boardSlip 12, combatFrame 12, modalFrame 16 |
| `class PixelFrame` | `lib/ui/components/pixel_asset.dart:315` | `{skin, child, fallback}`. Stateful; resolves `AssetImage` (`:352`), paints via `_FramePainter` (`:419`). **Tiles the edge strips, never stretches** — Flutter's `centerSlice` explicitly refused (`:292-302`). Draws no interior. Falls back to the painted decoration on load failure. `debugFramePainter` exposed `@visibleForTesting` (`:414`) |
| `class PixelAsset` | `pixel_asset.dart:45` | `{assetPath, nativeWidth, nativeHeight, scale}` + named ctors `.item`(48,x1) `.skill`(24,x1) `.nav`(14,x2) `.glyph`(12,x2) `.portrait`(64,x2) `.sprite`(64,x2) `.activity`(40,x2). Integer scale only; `FilterQuality.none`; `_ExactSizeBox` (`:517`) asserts against Flutter's silent rescale |
| `class PixelScene` | `pixel_asset.dart:186` | `.regionMap`, `.vignette`; `{viewportHeight, alignment, overlay}` — clips rather than rescales, and says so (`:185`) |

### 2.3 Container / layout primitives

| Symbol | File:line | API |
|---|---|---|
| `SectionCard` | `lib/ui/components/surfaces.dart:42` | `{child, padding?, wash?, role = PanelRole.card}`. `_painted()` at `:58` |
| `SurfaceBlock` | `surfaces.dart:114` | `{child, padding?}` — fill only, `StrideRadius.inner`, no border |
| `InsetWell` / `.square` | `surfaces.dart:141`, `:150` | `{contentWidth, contentHeight, child}` — adds its own 1 px border so the rendered box is content+2. No `ClipRRect`, deliberately (`:172`) |
| `SectionHeading` | `surfaces.dart:180` | `{label, trailing?}` — uppercased `microLabel` + optional trailing |
| `StrideScaffold` | `lib/ui/components/stride_scaffold.dart:13` | `{header, body, bottomBar?}` — **the only `SafeArea` handler in the app** (`:1-6`) |
| `StrideTabBar` | `lib/ui/components/stride_tab_bar.dart:12` | `{selected, onSelect}` |
| `ScreenHeader` | `lib/ui/components/screen_header.dart:17` | `{eyebrow, title, trailing?, regionInk?, regionDeep?}` |
| `BankedStepsReadout` | `screen_header.dart:119` | `{bankedSteps}` |
| `ShellTabs` (InheritedWidget) | `lib/ui/shell/shell_tabs.dart:19` | `{select, child}` — lets any screen route to another tab |

### 2.4 Data-display primitives (`lib/ui/components/data_display.dart`)

| Symbol | Line | API |
|---|---|---|
| `LabeledValueTile` | `:18` | `{label, value, unit?, leading?, valueColor?}` |
| `ValueTileRow` | `:140` | `{tiles}` |
| `SkillChip` | `:230` | `{skill, label}` — **0 call sites (dead)** |
| `RequirementGate` | `:272` | `{label, unmet}` — outlined capsule, never filled |
| `enum StrideButtonVariant` | `:326` | `commit`, `attack`, `defense`, `ready` |
| `StrideButton` / `.secondary` | `:363`, `:385` | `{label, onPressed, subLabel?, variant, glow, secondary}` — raised plate, 2 px lit top edge, hard under-ledge, 2 px press travel, `Semantics(button:)` because there is no Material widget to supply the role |

### 2.5 Content / art primitives

| Symbol | File:line |
|---|---|
| `AdaptiveText` | `lib/ui/components/adaptive_text.dart:46` — shrink-within-bounds text; the app's real text primitive |
| `RarityBadge` / `.compact` | `lib/ui/components/rarity_badge.dart:31`, `:40` |
| `RarityName` / `.wrapping`, `RarityFrame`, `RarityRule` | `lib/ui/components/rarity_item_title.dart:33`, `:58`, `:107`, `:156` |
| `GroundedSprite`, `ContactShadowSpec` | `lib/ui/components/grounded_sprite.dart:79`, `:47` |
| `SpriteAnimation` | `lib/ui/components/sprite_animation.dart:34` |
| `WalkingGlyph`, `enum WalkingRole` | `lib/ui/components/walking_glyph.dart:38`, `:30` |
| `GearStatsBlock`, `GearStatLine` | `lib/ui/components/gear_stats.dart:31`, `:169` |
| `RewardLayer`, `RewardRaise`, `_Ruled` | `lib/ui/components/reward_layer.dart:154`, `:295`, `:136` |
| `RewardBeat`, `LevelUpCard`, `StaggeredReveal`, `RewardItemRow`, `RewardFacts`, `enum RewardTier`, `RewardLayerScope` | `lib/ui/components/reward_beat.dart:69`, `:223`, `:286`, `:377`, `:458`, `:49`, `:58` |
| `ActivityResult`, `ActivityResultCard`, `ActivityResultHost` | `lib/ui/components/activity_result.dart:67`, `:130`, `:219` |
| `AmbientStage`, `AmbientStageLayout`, `StageScenery` | `lib/ui/components/ambient_stage.dart:231`, `:98`, `:58` |
| `AmbientPlayer`, `AmbientScene`, `AmbientLayer`, `AmbientCadence`, `ScenePhasing`, `SpriteBounds` | `lib/ui/components/ambient_player.dart:101`; `ambient_scene.dart:360`, `:316`, `:597`, `:136`, `:258` |

### 2.6 The asset-key indirection layer — it exists, and it is good

| Registry | File:line | Contents |
|---|---|---|
| `PixelIcons` | `lib/ui/icons/pixel_icons.dart:11` | Two roots: `_base = 'assets/ui/v1'` (`:16`), `_art = 'assets/art/v1'` (`:24`). Maps: `_vignetteByLocation` (`:112`), `_altVignetteByLocation` (`:133`), `_skillIcons` (`:165`), `_itemIcons` (`:195`), `_nodeArt` (`:299`). Lookups `vignetteFor` (`:125`), `altVignetteFor` (`:142`), `skillFor` (`:179`), `itemFor` (`:345`, falls back to `itemUnknown`), `nodeFor` (`:332`), `hasItemIcon` (`:350`). Nav glyph constants `:354-374` |
| `AtlasAssets` | `lib/ui/icons/atlas_assets.dart:39` | Atlas base, landmarks, overlay frame sequences |
| `CombatAssets`, `CombatantArt`, `EffectArt`, `CombatTrack` | `lib/ui/icons/combat_assets.dart:200`, `:116`, `:164`, `:83` | |
| `AmbientAssets` | `lib/ui/icons/ambient_assets.dart:303` | 185 ambient frames |
| `TravelerArt` | `lib/ui/icons/traveler_art.dart:45` | `walkWestFor(EquipmentVisualState)` — the visible-equipment seam |
| `SpriteFootprints`, `SpriteFootprint` | `lib/ui/icons/sprite_footprints.dart:38`, `:15` | Measured opaque boxes per sprite |

`pixel_icons.dart:1` states the invariant: *"The only place an asset path string
appears."* **It holds.** 871 PNGs ship under `assets/`, declared file-by-file in
`pubspec.yaml` with four whole-directory exceptions guarded by
`Scripts/art/package-art.js --check`.

---

## 3. Call-site census — the leverage ranking

Counts are constructor invocations across all of `lib/`, with constructor
*declarations* excluded (see §10 for the exact command).

| Rank | Primitive | Sites | Notes |
|---:|---|---:|---|
| 1 | `AdaptiveText` | **67** | 48 outside `components/`. The real text primitive |
| 2 | `SectionCard` | **33** | 28 default `PanelRole.card`; 3 pass `wash`; 5 name a role |
| 3 | `PixelAsset` (all ctors) | **33** | `.item` 9, `.skill` 4, `.sprite` 2, `.portrait` 2, `.nav` 2, `.glyph` 2, `.activity` 1 |
| 4 | `SectionHeading` | **27** | |
| 5 | `RewardBeat` | **19** | |
| 6 | `StrideButton` (+ `.secondary`) | **15** | |
| 7 | `LabeledValueTile` | **15** | |
| 8 | `SurfaceBlock` | **14** | |
| 9 | `WalkingGlyph` | **11** | |
| 10 | `PixelScene` | **10** | 8 `.vignette`, 1 `.regionMap` |
| 11 | `GroundedSprite` | **8** | |
| 12 | `RarityName` | **7** | |
| 13 | `ValueTileRow` | **6** | |
| 14 | `LevelUpCard` | **6** | |
| 15 | `InsetWell` (+ `.square`) | **5** | |
| 16 | `ScreenHeader` | **5** | |
| 17 | `RarityBadge` | **5** | |
| 18 | `StaggeredReveal` | **5** | |
| 19 | `RewardRaise` | **4** | |
| 20 | `RequirementGate` | **4** | |
| 21 | `RewardFacts` | **3** | |
| 22 | `StrideScaffold` | **2** | **Only 2** — see §5 T-13 |
| 23 | `RewardItemRow`, `GearStatsBlock`, `AmbientStage`, `ActivityResultHost` | 2 each | |
| 24 | `StrideTabBar`, `SpriteAnimation`, `RarityRule`, `RarityFrame`, `PixelFrame`, `GearStatLine` | 1 each | |
| 25 | **`SkillChip`** | **0** | **Dead primitive.** A shared chip exists and nobody uses it |

### 3.1 `SectionCard` distribution (33 sites, 20 files)

```
4  character/step_tracker_screen.dart    2  adventure/bestiary_screen.dart
4  character/character_screen.dart       2  adventure/activity_panel.dart
2  world/world_screen.dart               1  world/atlas/atlas_selection_panel.dart
2  skills/skill_detail_screen.dart       1  skills/skills_screen.dart
2  inventory/inventory_screen.dart       1  combat/combat_screen.dart
2  craft/craft_screen.dart               1  character/steps_block.dart
2  adventure/goal_tracker_card.dart      1  character/playtest_block.dart
                                         1  character/audio_block.dart
                                         1  adventure/goal_summary_card.dart
                                         1  adventure/goal_board_screen.dart
                                         1  adventure/encounter_card.dart
                                         1  adventure/board_card.dart
                                         1  adventure/adventure_screen.dart
```

The five sites that name a role:
`adventure/board_card.dart:160` (`boardSlip`),
`adventure/goal_board_screen.dart:114` (`boardSlip`),
`combat/combat_screen.dart:204` (`combatFrame`),
`inventory/inventory_screen.dart:116` and `:131` (`kitTray`).

### 3.2 Token reference distribution

`StrideType` — 326 references:

| Role | Refs | | Role | Refs |
|---|---:|---|---|---:|
| `micro` | 131 | | `sectionHeading` | 6 |
| `microLabel` | 56 | | `headerValue` | 3 |
| `sub` | 45 | | `gateLabel` | 3 |
| `itemName` | 17 | | `screenEyebrow` | 2 |
| `compactLabel` | 16 | | `numericHero` | 2 |
| `body` | 10 | | `buttonLabelSecondary` | 2 |
| `numericValue` | 9 | | `tabLabel` / `tabLabelActive` | 1 / 1 |
| `itemCount` | 9 | | `screenTitle` | 1 |
| `cardTitle` | 7 | | `buttonLabel` | 1 |

`StrideColors` — ~480 references, top and bottom:

| Token | Refs | | Token | Refs |
|---|---:|---|---|---:|
| `textSecondary` | 107 | | `forRegion` | **1** |
| `textMuted` | 87 | | `forRegionDeep` | **1** |
| `textPrimary` | 72 | | `goalActive` | 1 |
| `borderDefault` | 29 | | `defenseSheen` / `defenseEdge` | 1 / 1 |
| `accentSteps` | 29 | | each rarity ink and dim | 1 each |
| `surfaceBlock` | 22 | | `rewardGlow` / `rewardWashTop` | 1 / 1 |
| `surfaceGround` | 18 | | **`lockedScrim`** | **0** |
| `forSkill` | 17 | | `categoryMaterial/Equipment/Consumable` | 0 |
| `surfaceRaised` | 13 | | `forSkillDeep` | 4 |
| `surfaceCard` | 12 | | `separator` | 6 |

`StrideRadius` — 55 references: `inner` 21, `gate` 15, `chip` 11, `card` 7,
`tabActive` 1. `StrideSpace` — **508 references**, of which `cardGap` alone is 29.

---

## 4. Skinned vs. raw — the screen table

"Skinned" means the surface is drawn by `SectionCard` and would therefore change
the day a `PanelSkin` row lands. "Ad-hoc surfaces" counts
`Container(` + `BoxDecoration(` + `DecoratedBox(` — hand-rolled boxes a frame
family would **not** reach. "Art" counts `PixelAsset` / `PixelScene` /
`GroundedSprite` / `SpriteAnimation` / `AmbientStage` / `AtlasViewport` uses.

| Screen | Skinned? | `SectionCard` | Explicit role | Ad-hoc surfaces | Art |
|---|---|---:|---:|---:|---:|
| Adventure (7 files) | Partly | 8 | 1 `boardSlip` | **31** | 6 |
| Character (4 files) | **Fully** | 7 | 0 | **0** | 3 |
| Skills | Mostly | 1 | 0 | 2 | 1 |
| Skill Detail | Mostly | 2 | 0 | 5 | 0 |
| Inventory | Yes | 2 | 2 `kitTray` | 2 | 2 |
| Craft | Partly | 2 | 0 | **15** | 4 |
| World + Atlas (5 files) | Partly | 3 | 0 | **14** | 11 |
| Travel transition | **No** | 0 | 0 | 2 | 3 |
| Combat (2 files) | Partly | 1 | 1 `combatFrame` | **6** | 3 |
| Field Notes | Yes | 2 | 0 | 1 | 0 |
| Goal Board | Yes | 1 | 1 `boardSlip` | 0 | 0 |
| Step Tracker | Yes | 4 | 0 | 6 | 0 |
| Reward / result layers | **No** | 0 | 0 | **7** | 2 |
| Blocked | **No** | 0 | 0 | 0 | 0 |
| Stale banner | **No** | 0 | 0 | 2 | 0 |
| Dev harness (debug) | **No — raw Material** | 0 | 0 | 0 | 0 |

**Role coverage of `PanelSkins`:** `card` 28 (implicit), `kitTray` 2,
`boardSlip` 2, `combatFrame` 1, **`heroPlate` 0, `modalFrame` 0**.

The two roles designed to carry the most *authored* weight have no call sites.
The most emotionally loaded surface in the game — `RewardLayer`
(`reward_layer.dart:154`) — bypasses `SectionCard` entirely and hand-rolls, at
`reward_layer.dart:62-66`:

```dart
child: Container(
  decoration: BoxDecoration(
    color: StrideColors.surfaceCard,
    borderRadius: StrideRadius.card,
    border: Border.all(color: frame, width: major ? 2 : 1),
```

That is literally the same rectangle as every ordinary card, plus one pixel of
border. **The day a `modalFrame` frame lands, nothing happens**, because nothing
asks for it.

---

## 5. The "AI-generated look" tells, structurally

### T-1 — One rectangle, 33 times

| | |
|---|---|
| Responsible | `lib/ui/components/surfaces.dart:42`; `_painted()` at `:58` |
| Constants | `StrideRadius.card` (14), `StrideColors.borderDefault`, `StrideColors.surfaceCard` |
| Affected | **33** sites; **28** take no role, **30** take no `wash` |
| Why it reads generated | Radius 14, one 1 px border in one colour, one fill, no material, no corner treatment, no ornament, no variation by subject. Two screens showing entirely different fictions show the same box |

### T-2 — No typeface at all

| | |
|---|---|
| Responsible | `pubspec.yaml` (no `fonts:` block); `stride_typography.dart:32` (no role sets `fontFamily`); `stride_theme.dart:29` (`TextTheme` fills 3 slots, no family) |
| Affected | **292 sites** — 225 raw `Text(`, 67 `AdaptiveText(`. Every word in the product |
| Why it reads generated | Pixel art beside San Francisco is the exact visual signature of "Flutter UI over sprites". No other single fact in this codebase does as much work |

### T-3 — Uniform vertical rhythm: every screen is the same list

Every tab screen and every pushed route is
`ListView(padding: EdgeInsets.fromLTRB(screenGutter, _, screenGutter, _),
children: [Card, SizedBox(cardGap), Card, SizedBox(cardGap), ...])`. Verified at
`adventure_screen.dart:105`, `character_screen.dart:54`, `skills_screen.dart:47`,
`inventory_screen.dart:100`, `craft_screen.dart:266`, `world_screen.dart:452`,
`bestiary_screen.dart:87`, `goal_board_screen.dart`, `step_tracker_screen.dart`.

| | |
|---|---|
| Responsible | `StrideSpace.screenGutter` (`stride_metrics.dart:27`), `StrideSpace.cardGap` (`:40`) |
| Affected | `cardGap` **29** sites across 11 files; `screenGutter` on every screen; **272** `SizedBox(height:` in `lib/` |
| Why it reads generated | Identical gutter, identical inter-card gap, identical scroll, on 12 surfaces with 12 different jobs. No screen has a composition; each has a stack |

### T-4 — The type register has collapsed to "small grey"

| | |
|---|---|
| Responsible | `StrideType.micro` (`stride_typography.dart:130`), `microLabel` (`:106`), `sub` (`:122`) |
| Affected | **232 of 326** role references (71%) |
| Counter-evidence | `cardTitle` 7, `numericHero` 2, `screenTitle` 1, `buttonLabel` 1 |
| Why it reads generated | An authored game varies scale hard — a place name at 32, a body line at 12. Stride varies scale by about two points across almost everything, so nothing announces itself and every card scans as a data readout |

### T-5 — Twelve chip implementations, and the shared one is dead

| Class | File:line |
|---|---|
| `SkillChip` — **shared, 0 sites** | `lib/ui/components/data_display.dart:230` |
| `_QuantityChip` | `adventure/activity_panel.dart:364` |
| `_TypeChip` | `adventure/board_card.dart:701` |
| `_StagePill` | `adventure/board_card.dart:1174` |
| `_RequirementChip` | `adventure/board_card.dart:1303` |
| `_ProgressChip` | `adventure/board_card.dart:1318` |
| `_SpanChip` | `character/step_tracker_screen.dart:569` |
| `_Chip` | `combat/combat_stage.dart:835` |
| `_ChainBackChip` | `craft/craft_screen.dart:416` |
| `_CategoryChips` | `craft/craft_screen.dart:455` |
| `_Chip` | `craft/craft_screen.dart:481` |
| `_QueueChips` | `craft/craft_screen.dart:928` |
| `_BossBadge` | `world/atlas/atlas_selection_panel.dart:732` |

Each is `Container + BoxDecoration(surfaceRaised or surfaceBlock,
StrideRadius.chip or .gate) + uppercase compactLabel`. They look identical
because they were each independently written to the same tokens — which is
precisely what "AI-authored" looks like from the outside. 12 `Wrap(` sites in
`lib/` lay them out.

### T-6 — Six progress-bar implementations, no primitive

| Class | File:line |
|---|---|
| `SkillProgressBar` | `skills/skills_screen.dart:187` |
| `_HpBar` | `combat/combat_stage.dart:985` |
| `_BarRow` | `character/step_tracker_screen.dart:496` |
| `_MaterialProgressRow` | `adventure/board_card.dart:1213` |
| `RepetitionBar` | `adventure/activity_panel.dart:659` |
| `CraftRepetitionBar` | `craft/craft_screen.dart:1224` |

All six are `FractionallySizedBox(widthFactor:)` inside a rounded track
(`activity_panel.dart:733`, `board_card.dart:1284`,
`step_tracker_screen.dart:534`, `craft_screen.dart:1289`,
`skills_screen.dart:229`). Every fill in the game — XP, HP, craft timer, gather
timer, material delivery, step history — is a separately authored rounded
rectangle.

### T-7 — Four divider implementations for a 1 px line

`_Rule` (`character/character_screen.dart:541`), `_SlotRule`
(`adventure/goal_tracker_card.dart:98`), `_Ruled`
(`components/reward_layer.dart:136`), `RarityRule`
(`components/rarity_item_title.dart:156`), plus inline
`Container(height: 1, color: StrideColors.separator)` at
`adventure/bestiary_screen.dart:139` and `skills/skill_detail_screen.dart:268`.
`StrideColors.separator` has 6 references and no primitive.

### T-8 — Uniform border radius, everywhere

| Radius | Value | Refs |
|---|---:|---:|
| `StrideRadius.inner` | 10 | 21 |
| `StrideRadius.gate` | 6 | 15 |
| `StrideRadius.chip` | 8 | 11 |
| `StrideRadius.card` | 14 | 7 |
| `StrideRadius.tabActive` | 8 (bottom) | 1 |
| hardcoded `Radius.circular` | 1, 2, 3, 3, 9 | 5 |

**60 rounded surfaces and zero square, bevelled, notched or frame-cornered
ones.** Rounded-everything is the visual default of every app framework; it is
the shape that says "template". The only non-uniform corner in the product is
`BorderRadius.vertical(top: Radius.circular(9))` at `board_card.dart:479`.

### T-9 — 96 one-off private widget classes inside screens

`grep -rn "^class _[A-Za-z]* extends \(Stateless\|Stateful\)Widget" lib/ui/screens`
returns **96**, of which 16 are named `_...Row`. Worst files:
`board_card.dart` 13, `craft_screen.dart` 10, `inventory_screen.dart` 8,
`adventure_screen.dart` 8, `activity_panel.dart` 8, `world_screen.dart` 6,
`goal_tracker_card.dart` 6.

This is the mechanical cause of T-5, T-6 and T-7: **the shared layer stops at
the card**, so everything below the card is re-authored per screen and converges
on the same tokens.

### T-10 — Screens have no identity because the identity tokens are unused

Ten region colours, five skill deeps and a `wash` parameter exist. Actual use:
`forRegion` **1**, `forRegionDeep` **1** (both `stride_shell.dart:93-94`),
`forSkillDeep` **4**, `SectionCard(wash:)` **3**. Whispering Woods and Frostmere
render the same greys everywhere except a ~6 L\* header gradient which
`panel_skin.dart:17` itself concedes is "sub-perceptual by construction".

### T-11 — Combat is a card in a scroll

`CombatScreen` (`combat/combat_screen.dart:65`) is instantiated at
`adventure_screen.dart:117` as a child of the Adventure `ListView`, and its body
is `SectionCard(role: PanelRole.combatFrame)` at `combat_screen.dart:203-204`.
The fight happens in the same box as the inventory summary, one `cardGap` below
a banner. `panel_skin.dart:83` states that combat "is not an interruption, it is
a place" — the widget tree does not yet agree.

### T-12 — Default platform route transitions

All four pushed screens use `MaterialPageRoute` (`bestiary_screen.dart:44`,
`goal_board_screen.dart:47`, `step_tracker_screen.dart:48`,
`skill_detail_screen.dart:69`) plus the debug harness
(`stride_shell.dart:66`). That is the OS's own page push — the most recognisably
"app" motion available. The travel transition
(`travel_transition.dart:101-124`) is the one authored route in the product, and
it is a 140 ms fade.

### T-13 — The page shell is bypassed by three of four pushed screens

`StrideScaffold` has **2** call sites (`stride_shell.dart:39`,
`skill_detail_screen.dart:97`). The other three pushed screens hand-roll the
identical `ColoredBox + Column + SizedBox(inset.top) + ScreenHeader + CLOSE
GestureDetector` stack: `bestiary_screen.dart:61-86`,
`goal_board_screen.dart:66-92`, `step_tracker_screen.dart:70-95`. Three copies
of the same page chrome, each with its own `MediaQuery.viewPaddingOf` handling
— which is exactly the double-inset hazard `stride_scaffold.dart:1-6` was
written to make impossible.

---

## 6. Values that bypass the theme

**Hardcoded colours: 92 total `Color(0x` in `lib/`, 60 inside `lib/ui/theme/`
(legitimate token definitions). 32 outside.**

| File | Count | Lines | Character |
|---|---:|---|---|
| `world/atlas/atlas_layers.dart` | **12** | `:168, 169, 170, 171, 819, 823, 824, 969, 1135, 1325, 1639, 1644` | Painter alphas over `14120F` / `F0E7D8` |
| `world/world_screen.dart` | **5** | `:322, 334, 578, 579, 580` | Gradient scrims over `14120F` |
| `components/grounded_sprite.dart` | 4 | `:175-178` | Contact-shadow black ramp |
| `adventure/location_stage.dart` | 3 | `:97, 129, 223` | Scrims |
| `craft/craft_screen.dart` | 2 | `:1036, 1037` | Vignette scrim |
| `components/reward_layer.dart` | 1 | `:186` | `scrim = 0xB30E0C0A` |
| `components/activity_result.dart` | 1 | `:156` | `0x8014120F` |
| `combat/combat_stage.dart` | 1 | `:843` | `0xCC14120F` |
| `world/travel_transition.dart` | 1 | `:106` | Barrier `0x6614120F` |
| `components/stride_tab_bar.dart` | 1 | `:98` | `0x00000000` |
| `debug/dev_harness.dart` | 1 | `:102` | Debug seed colour |

**The important pattern: 20 of the 32 are alpha variants of exactly two palette
hexes** — `14120F` (`surfaceGround`) at twelve distinct alpha levels
(`00, 5A, 66, 80, 8C, B3, B4, C4, CC, D9, E6, F2`) and `F0E7D8`
(`textPrimary`) at two. This is not palette drift; it is **a missing scrim/veil
token family**, invented independently eleven times.

**Confirmed duplication defect.** `StrideColors.lockedScrim`
(`stride_colors.dart:344`) documents itself as *"promoted from `LocationStage`'s
local constant so 'locked looks like this' has one home"* — but it has **zero**
call sites, and `location_stage.dart:97` still declares
`static const Color _lockedScrim = Color(0x5A14120F);`, used at `:251`. The
promotion landed; the call site was never repointed.

**Hardcoded radii: 5 outside the theme.** `rarity_item_title.dart:173` (1),
`world_screen.dart:361` (2), `combat_stage.dart:1009` and `:1023` (3),
`board_card.dart:479` (9).

**`EdgeInsets` not derived from `StrideSpace`: 58 of 109.** Worst files:
`board_card.dart` 6, `dev_harness.dart` 6, `skill_detail_screen.dart` 5,
`craft_screen.dart` 5, `world_screen.dart` 3, `bestiary_screen.dart` 3,
`activity_panel.dart` 3, `data_display.dart` 3. Most are small odd numbers
(`vertical: 5`, `horizontal: 9`, `top: 3`) — hand-tuning inside components, the
exact drift `stride_metrics.dart:8-12` says the scale exists to stop.

---

## 7. How images and sprites reach the screen

```
PixelIcons / AtlasAssets / CombatAssets / AmbientAssets / TravelerArt / SpriteFootprints
        (asset-key registries — the only place a path string is written)
                              |  String assetPath
                              v
   PixelAsset      PixelScene      PixelFrame       SpriteAnimation
   (integer        (clips, never   (nine-slice,     AmbientPlayer / AmbientStage
    scale,          rescales)       tiled edges)    (frame lists)
    asserts)
        \_______________|_______________|________________/
                        v                        v
             Image.asset (x2)            AssetImage -> CustomPaint
             pixel_asset.dart:125,260    pixel_asset.dart:352
                                         + 9 precacheImage sites
```

Findings:

- `Image.asset` appears at exactly **two** places, both in `pixel_asset.dart`
  (`:125`, `:260`): `FilterQuality.none`, `isAntiAlias: false`, `BoxFit.fill`,
  no `cacheWidth`/`cacheHeight`, no `2.0x/` variant directories. The reasoning
  is written out at `:130-152`.
- `AssetImage` appears **once** outside `precacheImage` — `PixelFrame`'s
  resolver at `:352`. `precacheImage` sites: `ambient_player.dart:261,263`,
  `ambient_stage.dart:602`, `sprite_animation.dart:91`,
  `encounter_card.dart:489`, `combat_stage.dart:280`, `atlas_layers.dart:382`,
  `travel_transition.dart:84,85,87`.
- `rootBundle` is confined to `lib/runtime/asset_content.dart:15` and
  `lib/runtime/atlas_layout.dart:32`.
- Six `CustomPainter`s: `_FramePainter` (`pixel_asset.dart:419`),
  `_ContactShadowPainter` (`grounded_sprite.dart:141`), and four atlas painters
  (`atlas_layers.dart:135, 792, 944, 1297`).
- **The asset-key indirection layer exists, is complete, and is the healthiest
  part of the UI stack.** Six registries, all `abstract final class`, keyed by
  `ContentId` where content drives them, with honest fallbacks (`itemFor` ->
  `itemUnknown`; `vignetteFor` -> null).
- `Scripts/check-ui-boundary.sh` does **not** yet guard `DecorationImage`,
  `paintImage` or `AssetImage` outside `pixel_asset.dart`.
  `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` P-3 names this as a live hole.

---

## 8. The eight highest-leverage primitive changes

Ordered by (perceived-authorship change) per (call sites touched). Every one is
a change to a *primitive or token*, not to screens.

### R-1. Ship a typeface — **292 text sites, 2 files**

Add a `fonts:` block to `pubspec.yaml` and one `fontFamily` (or two — a display
face and a text face) to the `StrideType` roles at `stride_typography.dart:32`.
Every word in the product changes at once.

- *Leverage:* 292 sites (225 `Text(` + 67 `AdaptiveText(`) for one edit.
- *Risk:* metrics shift — every `height:` ratio in `stride_typography.dart` is
  calibrated against the system face, and `test/ui/typography_test.dart`
  measures rendered line boxes, so the guard will catch it. Budget one device
  pass.
- *Note:* PixelLab's `create_font` can author a display face. The body face
  should stay a legible non-pixel face; `pixel_icons.dart:41` already warns
  against improvising a substitute medium, and the reverse caution applies —
  do not set body copy in a pixel face.

**This is the single highest-leverage change available.**

### R-2. Land one `PanelSkin` row for `PanelRole.card` — **28 panels, 1 map entry**

`PanelSkins.authored` (`panel_skin.dart:183`) is empty by design and
`PixelFrame` (`pixel_asset.dart:315`) is built, tested and asserted. One row —
`PanelRole.card` -> a frame family — repaints 28 of 33 panels with no call-site
change; emptying the map reverts it in one commit.

- *Leverage:* 28 sites, zero call-site edits.
- *Blocker:* the asset. `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` §9.2 has
  the queue; the recorded balance was 25 generations reserved for the atlas
  emergency, cycle reset 2026-09-16. Call `get_balance` live before planning.
- *Caveat:* `_reserve[PanelRole.card]` is **0** (`panel_skin.dart:201`), so a
  card frame with a non-zero `band` **will** reflow all 28 panels. Set the
  reserve before the art lands, not with it — otherwise the art takes the blame
  for a text-wrap regression it did not cause, which is the exact failure
  `panel_skin.dart:188-193` predicts.

### R-3. Introduce a scrim/veil token family — **32 literals to 0; 20 collapse to one ladder**

Twenty of the 32 non-theme `Color(0x...)` literals are alpha variants of
`surfaceGround`. Add a named ladder to `stride_colors.dart` and repoint the
eleven files. Fix the `lockedScrim` duplication
(`location_stage.dart:97` -> `StrideColors.lockedScrim`) in the same pass.

- *Leverage:* 32 literal sites across 11 files — and, more importantly, it makes
  "how dark is a scrim in this game" a decision that can be retuned once. Every
  diorama, vignette, atlas plate, travel barrier and reward scrim currently
  answers that question independently.

### R-4. Add a `ProgressTrack` primitive; retire six bar implementations — **6 classes, ~10 render sites**

One primitive in `components/` taking `{fraction, ink, track, height, role}`,
replacing `SkillProgressBar` (`skills_screen.dart:187`), `_HpBar`
(`combat_stage.dart:985`), `_BarRow` (`step_tracker_screen.dart:496`),
`_MaterialProgressRow` (`board_card.dart:1213`), `RepetitionBar`
(`activity_panel.dart:659`) and `CraftRepetitionBar` (`craft_screen.dart:1224`).

- *Leverage:* it is the **only** place authored material can enter a filling
  element. A pixel-authored track cap, a hand-drawn fill texture, a notched
  segment count — each lands once and appears on XP, HP, craft, gather, delivery
  and step history simultaneously. Today that would be six edits and would not
  happen.

### R-5. Promote `SkillChip` into one `StrideChip`; delete twelve private ones — **~25 render sites**

`SkillChip` (`data_display.dart:230`) has **0** call sites while twelve private
chips exist (T-5). Generalise it — `{label, ink?, icon?, variant}` — and
repoint. Chips are the most-repeated *small* shape in the product and the one
most legible as generic UI.

- *Leverage:* ~25 render sites and -12 classes; then one authored chip plate
  reaches every one of them, by the R-2 mechanism.

### R-6. Break the uniform rhythm at the primitive level — **33 + 29 + 6 sites**

Two moves, both inside existing API:

1. `PanelRole.heroPlate` has **0** call sites. Each tab screen has an obvious
   hero — the location diorama, the portrait, the atlas, the selected recipe,
   the tracked goal, the item detail. Naming one hero per screen is six
   one-word edits and is what stops six screens being six identical lists.
   `_reserve[heroPlate]` is already 12 (`panel_skin.dart:203`), so adopting the
   role today reserves the room and reflows those six panels **once**, before
   art — which is the right time.
2. Replace the flat `SizedBox(height: StrideSpace.cardGap)` (29 sites,
   `stride_metrics.dart:40`) with a rhythm that varies by adjacency
   (e.g. `beatTight` / `beatSection`). A constant 10 dp between every pair of
   cards is the metronome that makes the whole app read as a generated list.

### R-7. Route `RewardLayer` and the pushed pages through the primitives they bypass — **7 ad-hoc surfaces, 4 routes**

- `RewardLayer` (`reward_layer.dart:62-66`) hand-rolls the card rectangle; make
  it `SectionCard(role: PanelRole.modalFrame)`. That role has **0** call sites
  and a 16 dp reserve waiting (`panel_skin.dart:206`).
- Fold the three hand-rolled page shells (T-13) into `StrideScaffold` or a new
  `StridePage`, and give it **one authored route transition** to replace four
  `MaterialPageRoute`s (T-12). `travel_transition.dart:101-124` is the working
  precedent for a custom route in this codebase.
- *Leverage:* the two most-authored-feeling moments in the game — a reward, a
  journal opening — currently look exactly like the inventory list. This is
  where "authored" is cheapest to buy.

### R-8. Widen the type scale in `StrideType` before any screen is touched — **326 references, 1 file**

The collapse in T-4 is a *token* problem: `micro`/`microLabel`/`sub` carry 71%
of all type. Two edits in `stride_typography.dart`:

1. Raise `cardTitle` (21 px, 7 uses) and `screenTitle` (19 px, 1 use) into a
   genuine display register, and give the header's place name the larger of
   them — the header inversion at `stride_shell.dart:76-84` already made the
   place the title; the type has not caught up.
2. Add one larger body role so prose can leave the 11-13 px band.

- *Leverage:* 326 references respond to the token file alone; no screen edits.
- *Guard:* `test/ui/typography_test.dart` measures rendered line boxes, and
  `AdaptiveText` (67 sites) is what keeps larger type from clipping. The D-01
  family of defects (`stride_metrics.dart:83-97`) is the thing to re-check.

### Ranking by sites improved per edit

| Rec | Sites automatically improved | Files edited | Needs art? |
|---|---:|---:|---|
| R-1 typeface | **292** | 2 | a face, not a generation |
| R-8 type scale | **326 refs** (visible on ~50) | 1 | no |
| R-2 card frame | **28** | 1 + asset family | **yes** |
| R-3 veil tokens | **32** | 12 | no |
| R-6 rhythm + heroPlate | **29 + 6** | ~8 | no |
| R-5 chip primitive | ~25 sites, -12 classes | ~7 | no |
| R-4 progress track | ~10 sites, -6 classes | ~7 | no |
| R-7 modal/page routing | 7 surfaces, 4 routes | ~6 | no |

**R-1 and R-8 are one file each, need no PixelLab budget, and change every word
on every screen.** They are the Wave 1 candidates. R-2 is gated on the
generation reset but needs no call-site work at all, so it can be queued in
parallel. R-3 through R-7 are refactors that make the *next* art drop reach
further than the panel edge.

---

## 9. What this audit deliberately does not decide

Per `CLAUDE.md` ("do not infer unresolved design decisions") and `RULES.md` G-3,
the following are named and left open for the owner:

- **Q-C1.** Whether combat becomes a place — a route or full-screen surface —
  rather than a card in the Adventure scroll (T-11). This is a design decision
  with flow consequences, not a widget one.
- **Q-C2.** Which typeface(s). R-1 states the leverage; it does not pick a face.
  A pixel display face, a warm humanist serif and a condensed sans are three
  different products, and `GAME_BIBLE/ART/ART_DIRECTION.md` does not choose.
- **Q-C3.** Whether the uniform 14 dp radius is retired for a frame-cornered or
  square register (T-8). This is `DECISIONS/0029` territory and belongs with the
  frame family, not ahead of it.
- **Q-C4.** Whether region identity may exceed the ~6 L\* wash ceiling that
  `panel_skin.dart:17` records as sub-perceptual. Ten authored biome colours
  currently touch one header gradient (T-10); making them visible is a change to
  a stated composition rule.

---

## 10. Reproduction

```sh
# §3 call-site census
for w in AdaptiveText SectionCard SectionHeading RewardBeat StrideButton \
         LabeledValueTile SurfaceBlock WalkingGlyph GroundedSprite \
         PixelAsset PixelScene SkillChip StrideScaffold; do
  n=$(grep -rnE "(^|[^A-Za-z_])$w[.(]" lib --include="*.dart" \
      | grep -vE "const +$w(\.[a-z]+)?\(\{|class +$w |// |/// " | wc -l)
  printf "%-20s %s\n" "$w" "$n"
done

# §3.2 token distribution
grep -rhno "StrideType\.[a-zA-Z]*"   lib -r --include="*.dart" | sed 's/.*://' | sort | uniq -c | sort -rn
grep -rhno "StrideColors\.[a-zA-Z]*" lib -r --include="*.dart" | sed 's/.*://' | sort | uniq -c | sort -rn
grep -rhno "StrideRadius\.[a-zA-Z]*" lib -r --include="*.dart" | sed 's/.*://' | sort | uniq -c | sort -rn

# §5 tells
grep -rn "^class _[A-Za-z]* extends \(Stateless\|Stateful\)Widget" lib/ui/screens --include="*.dart" | wc -l   # 96
grep -rn "StrideSpace.cardGap" lib --include="*.dart" | wc -l                                                  # 29
grep -rnE "(^|[^A-Za-z_.])Text\(" lib/ui --include="*.dart" | wc -l                                            # 225
grep -rn "AdaptiveText(" lib/ui --include="*.dart" | wc -l                                                     # 67
grep -rn "fontFamily" lib --include="*.dart"                                                                   # 1, a comment
grep -rn "role: PanelRole" lib --include="*.dart"                                                              # 5
grep -rn "wash:" lib --include="*.dart" | wc -l                                                                # 3

# §6 bypass counts
grep -rn "Color(0x" lib --include="*.dart" | grep -v "^lib/ui/theme/" | wc -l                                  # 32
grep -rn "Radius.circular" lib --include="*.dart" | grep -v "^lib/ui/theme/" | wc -l                           # 5
grep -rnE "EdgeInsets\.(all|symmetric|only|fromLTRB)\(" lib --include="*.dart" | grep -v StrideSpace | wc -l    # 58

# §0 Material absence, strict word boundaries
for w in Card Chip ListTile AppBar Scaffold Divider ElevatedButton InkWell \
         LinearProgressIndicator AlertDialog TextButton OutlinedButton; do
  printf "%-26s %s\n" "$w" "$(grep -rnE "(^|[^A-Za-z_.])$w\(" lib --include='*.dart' | wc -l)"
done
```
