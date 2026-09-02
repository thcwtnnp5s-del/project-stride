# GOV-05 — UI Architecture Map for the EPO03 screen rebuild

Facts only, read from the tree at `59c4723` (FMPO02 closeout, v2.40) on
2026-09-02. Supersedes `MILESTONES/evidence/FMPO02/wave0/GOV-05_ui_architecture_map.md`
where the two disagree; that report's §2 (primitive layer), §11 (harnesses) and
§12 (Reduce Motion / Dynamic Type plumbing) are still true and are not repeated
except where a line number moved. Paths are repo-relative; `file:line` is the
line at this commit.

Eight producers work in parallel: **ADVENTURE, CRAFT, SKILLS, INVENTORY,
CHARACTER, COMBAT, WORLD, NAV(+kit)**. This map exists so they do not collide.

---

## 0. The shape of the runtime, in one paragraph

`lib/ui/shell/stride_shell.dart:41` builds one `StrideScaffold` (the **only**
`SafeArea` handler in the app — `lib/ui/components/stride_scaffold.dart:1-7`)
with a `ScreenHeader` (`:104`), an `IndexedStack` of the six tab screens
(`:155-186`, all six kept alive, non-const on purpose) and a `StrideTabBar`
(`:191`). Every panel on every screen is a `SectionCard`
(`lib/ui/components/surfaces.dart:49`) carrying two orthogonal identities: a
`PanelRole` (frame axis, `panel_skin.dart:63`) and a `PanelSurface` (interior
material, `panel_skin.dart:179`). Only `heroPlate` and `modalFrame` are framed
(`PanelSkins.authored`, `panel_skin.dart:341-344`); every other role is a bare
surface. A third axis, the **band** (`band_plate.dart:57`), is a 384×48 picture
drawn once at ×1 under a heading. Combat is **not a route**: `CombatScreen` is
mounted inside `AdventureScreen`'s own `ListView`. Skill detail, Field Notes
(Bestiary), Goal Board and Step Tracker are pushed `MaterialPageRoute`s that
build their own `StrideScaffold`/`ScreenHeader`.

---

## 1. Per screen

Notation: `A > B[ c, d ]` = A's child is B whose children are c, d. Only the
top two levels are listed; `SectionCard()` with no args is
`role: card, surface: none` (flat `surfaceCard` fill, radius 14, 1 px border).

### 1.1 Adventure — producer ADVENTURE

| | |
|---|---|
| Files | `lib/ui/screens/adventure/adventure_screen.dart` (841), `activity_panel.dart` (1055), `location_stage.dart` (320), `goal_summary_card.dart` (254), `goal_tracker_card.dart` (304), `board_card.dart` (1437), `goal_board_screen.dart` (140, pushed) |
| Tree (`adventure_screen.dart:236-300`) | `ActivityResultHost > ListView[ LocationStage (176 dp, `location_stage.dart:133`), _Gutter(_WalkingStrip), _Gutter(Column[ StaleBanner?, _OpportunityBanner?, ActivityPanel, EncounterPanel, GoalSummaryCard ]) ]` |
| In-fight branch (`adventure_screen.dart:124-136`) | `ListView[ StaleBanner?, CombatScreen() ]` — taken when `s.encounter != null \|\| c.lastCombat?.outcome != null \|\| c.combatBusy`. **COMBAT's screen lives here.** |
| Roles/surfaces | `ActivityPanel` → `SectionCard(surface: journalLeaf)` + `BandPlate(StrideBands.forPlace(identity))` (`activity_panel.dart:106-124`); `_OpportunityBanner` → `SectionCard()` (`:362`); `GoalSummaryCard` → `SectionCard(role: boardSlip, surface: cork)` (`goal_summary_card.dart:228-230`); `GoalTrackerCard` → `SectionCard()` (`:55`); `BoardCard` → `SectionCard(role: boardSlip)` (`board_card.dart:164`); `GoalBoardScreen` → `BandPlate(boardsBatten)` + `SectionCard(role: boardSlip)` (`goal_board_screen.dart:107-124`) |
| Shared deps | `LocationStage`→`AmbientStage/AmbientScene/AmbientPlayer`, `ActivityResultHost/ActivityResultCard`, `StaleBanner`, `RewardRaise/RewardBeat` (in `activity_panel.dart`, `board_card.dart`), `WalkingGlyph`, `BandPlate`, `StrideButton`, `RarityItemTitle` |
| Save-affecting call sites (preserve) | `c.syncSteps()` `adventure_screen.dart:581`; `c.reload` `:133, :292`; `controller.acknowledgeOpportunities` `:383`; `ActivityScope.read(context).start(node, reps)` `activity_panel.dart:657`, `.stop()` `:760`; `trackGoal` `goal_tracker_card.dart:139`; `acceptContract` `board_card.dart:89`, `completeContract` `:62`, `contributeToProject` `:98` |
| Golden | `test/phase1_golden_test.dart` → `test/goldens/phase1_adventure.png`, `phase1_adventure_large.png` |
| Evidence/behaviour tests | `screen_evidence_test.dart` (`adventure`, `v2_adventure_fresh/_sync_banner/_woods`, `v3_adventure`, `gfcp_gather_plate`, `gfcp_ambient_dwell`, `gfcp_*_result`), `stage_evidence_test.dart` (LocationStage work mode ×5), `board_reward_layer_test.dart`, `goal_board_test.dart`, `gather_prerequisite_gate_test.dart`, `gather_queue_ui_test.dart`, `activity_result_test.dart`, `ambient_*_test.dart` |

### 1.2 Craft — producer CRAFT

| | |
|---|---|
| Files | `lib/ui/screens/craft/craft_screen.dart` (2215) — the largest screen file; `lib/ui/components/station_strip.dart` (226, only consumer is Craft) |
| Tree (`craft_screen.dart:369-560`) | `RewardRaise > PopScope > Stack[ ListView[ SectionCard(surface: benchOak, child: StationStrip) + BandPlate(StrideBands.forStation), _CategoryChips, (empty → const SectionCard(AdaptiveText)) \| (_HeroFolio, _TileFolio ×band, _LockedLedger) ], StrideSheet(open: _sheetRecipe != null) > Column[ _ChainBackChip?, _RecipeDetail ] ]` |
| Roles/surfaces | `_HeroFolio` → `SectionCard(role: heroPlate, surface: journalLeaf)` (`:727-729`, the one framed element); `_TileFolio` → `SectionCard(surface: journalLeaf)` (`:1011`), 2-column `_RecipeTile` grid; `_LockedLedger` → `SectionCard(surface: journalLeaf)` (`:1186`) of `_GateLine` rows — **this is the "spreadsheet" the owner named**; station header → `SectionCard(surface: benchOak)` (`:438`); `_IngredientTray` → `SurfaceBlock` (`:868`); `_RecipeDetail` → inside `StrideSheet` (`:1435` SectionCard) |
| Shared deps | `StrideSheet` (`bottom_sheet.dart`, **Craft is its only consumer today**), `StationStrip`→`AmbientStage`, `BandPlate`, `GearStatsBlock`, `RarityItemTitle/RarityBadge`, `ActivityResultHost`, `RewardRaise/RewardBeat`, `StrideButton`, `AdaptiveText`, `CraftController` (`lib/ui/state/craft_controller.dart`), `craft_memory.dart`, `craft_significance.dart` |
| Save-affecting call sites | `CraftScope.read(context).start(recipe, count)` `craft_screen.dart:825`, `:1659`; `.stop()` `:1885`; `craft.dismissSummary()` `:243`; `controller.reload` `:423`; `.equip(` `:2201` (equip-from-result) |
| Golden | `phase1_golden_test.dart` → `phase2_craft.png`, `phase2_craft_large.png`, `craft_stage.png` ("the craft stage, mid-craft, with its station", `:321`) |
| Evidence/behaviour tests | `craft_planner_test.dart` (drives `CraftScreen` at 393×852 DPR 3), `craft_flow_test.dart`, `craft_stage_evidence_test.dart` (`CRAFT_STAGE_EVIDENCE_DIR`), `craft_significance_test.dart`, `screen_evidence_test.dart` (`craft_gear_open`, `v3_craft_overview/ready/sourcing/chain/prover/locked`, `gfcp_craft_minor_beat`, `gfcp_batch_craft_summary`, `gfcp_levelup_with_result`) |

### 1.3 Skills overview + 1.4 Skill detail — producer SKILLS (one producer, both screens)

| | |
|---|---|
| Files | `lib/ui/screens/skills/skills_screen.dart` (478), `skill_detail_screen.dart` (632, pushed via `SkillDetailScreen.open` `:71`) |
| Overview tree (`skills_screen.dart:64-160`) | `ListView[ SectionCard(surface: buckram) > ClipRRect > Column[ SkillSpine ×5 ] ]`; `SkillSpine` = `Semantics > GestureDetector > Column[ Row(SkillPlate icon, name, LV), Stack(SkillProgressBar), SkillProgressCaption, unlock lines ]`. One card, five spines (not five cards as in FMPO02 wave0). |
| Detail tree (`skill_detail_screen.dart:94-210`) | `StrideScaffold(header: ScreenHeader(trailing: back GestureDetector), body: ListView[ BandPlate(StrideBands.forSkill)?, SectionCard() > Column[SkillHeaderRow, SkillProgressBar, SkillProgressCaption], SectionCard() > Column[_NextBlock, _Ladder > _LevelBand / _UnlockRow …] ])` — the two stacked `SectionCard()` rectangles are the owner's "stacks rectangles". |
| Roles/surfaces | overview: `surface: buckram` (`skills_screen.dart:93`); detail: both cards `role: card, surface: none` (`skill_detail_screen.dart:143, :170`) |
| Shared deps | `SkillPlate`, `SkillHeaderRow`, `SkillProgressBar`, `SkillProgressCaption` are **defined in `skills_screen.dart`** and imported by the detail screen — rebuild both together; `BandPlate`, `PixelAsset` (skill icons `assets/ui/v1/skill_*.png` 24×24 ×1), `StrideColors.forSkill/forSkillDeep`, `StrideScaffold`, `ScreenHeader` |
| Save-affecting call sites | overview: `controller.reload` `skills_screen.dart:78` only (reads `session.unlocksFor`); detail: none (reads `session.skillRoadmapFor` `:100`-ish). Safe screens. |
| Golden | `phase1_golden_test.dart` → `phase2_skills.png`, `phase2_skills_large.png`. **No golden for skill detail.** |
| Evidence/behaviour tests | `skill_detail_test.dart` (both screens), `phase1_ui_test.dart`, `screen_evidence_test.dart` (`skills`, `v2_skills`, `v3_skills`, `v3_skill_foraging/mining/smithing_detail`) |

### 1.5 Inventory — producer INVENTORY

| | |
|---|---|
| Files | `lib/ui/screens/inventory/inventory_screen.dart` (1126); `lib/ui/components/loadout_readout.dart` (321, shared with Character) |
| Tree (`inventory_screen.dart:137-200`) | `ListView[ _EquipmentCase, (empty → const SectionCard(kitTray, oilcloth)) \| SectionCard(role: kitTray, surface: oilcloth) > Column[ SectionHeading 'Carried', for group: heading, _ItemGrid (GridView.builder, 4 cols at 393 dp, floor 72 dp → 3), detail block (GearStatsBlock / _ItemPurposeBlock / _FoodResult / _EquipResult) ] ]` |
| Roles/surfaces | `_EquipmentCase` → `SectionCard(role: heroPlate, surface: oilcloth)` (`:598-600`, the framed element); tray → `kitTray + oilcloth` (`:163-165`, `:179-181`) |
| Shared deps | `LoadoutReadout`, `GearStatsBlock`, `RarityItemTitle/RarityBadge`, `PixelAsset.item` (48×48 ×1), `TravelerArt.figureFor` (`lib/ui/icons/traveler_art.dart`), `SurfaceBlock`, `InsetWell`, `ValueTileRow` |
| Save-affecting call sites | `controller.eatFood(item)` `:1043`; `controller.unequip(slot)` `:1107`; `controller.equip(item)` `:1113`; `c.reload` `:154` |
| Golden | `phase1_golden_test.dart` → `phase1_inventory.png`, `phase1_inventory_large.png` |
| Evidence/behaviour tests | `inventory_equip_test.dart`, `equipment_visual_test.dart`, `visible_equipment_test.dart`, `equipment_projection_test.dart`, `screen_evidence_test.dart` (`inventory`, `v3_inventory_purpose`, `gfcp_equipped_icons`) |

### 1.6 Character — producer CHARACTER

| | |
|---|---|
| Files | `lib/ui/screens/character/character_screen.dart` (675), `steps_block.dart` (74), `audio_block.dart` (175), `playtest_block.dart` (223), `step_tracker_screen.dart` (615, pushed) |
| Tree (`character_screen.dart:52-330`) | `ListView[ SectionCard(role: heroPlate, surface: journalLeaf) > Column[ Row(InsetWell.square(PixelAsset.portrait 64² ×2), Column(name, _Rule, _IdentityFact ×2)), _DressingStrip ], SectionCard() 'What walking has built' (ValueTileRow), StepsBlock (SectionCard), SectionCard() 'Skills' > _SkillSpine ×5, _CombatBlock (SectionCard, `:358`), AudioBlock (SectionCard, `audio_block.dart:44`), PlaytestBlock (SectionCard, `playtest_block.dart:104`) ]` — one framed hero, then six flat `SectionCard()`s: the owner's "dark card / dark card / button". |
| Shared deps | `LoadoutReadout`, `WalkingGlyph`, `ValueTileRow` (`data_display.dart`), `PixelAsset.portrait` (`PixelIcons.portraitTraveler`), `InsetWell`, `RarityItemTitle`, `AudioScope` (`lib/ui/state/audio_scope.dart`) |
| Save-affecting call sites | `c.reload` `character_screen.dart:67`; `AudioScope.read(context).setEnabled` `audio_block.dart:66`, `.setMusicVolume` `:76`, `.setSfxVolume` `:83`; `resetPlaytest(freshStart:)` `playtest_block.dart:55` (**destructive — keep its confirm step**); `syncSteps` `step_tracker_screen.dart:186`; reads `session.stepHistory`, `session.syncDiagnostics` |
| Golden | `phase1_golden_test.dart` → `phase1_character.png`, `phase1_character_large.png` |
| Evidence/behaviour tests | `screen_evidence_test.dart` (`character`, `character_playtest_confirm`, `v2_step_tracker_sync_details`), `step_tracker_test.dart`, `playtest_reset_session_test.dart`, `activity_beat_audio_test.dart` |

### 1.7 Combat — producer COMBAT

| | |
|---|---|
| Files | `lib/ui/screens/combat/combat_screen.dart` (1026), `combat_stage.dart` (1233), `combat_choreography.dart` (464); `lib/ui/icons/combat_assets.dart` (`CombatAssets`, `CombatHudAssets :1329`) |
| Mount point | **inside `adventure_screen.dart:124-136`** (see 1.1). No `Navigator`, no route; a cold relaunch mid-fight lands here from state. |
| Tree (`combat_screen.dart:157-362`) | `RewardRaise(beats: _ResultPanel) > StaggeredReveal[ CombatStage(narration: _CombatLog), SectionCard(role: combatFrame, surface: leather) > _CombatControls Column[ intent micro line, Row(Attack \| Brace) 56 dp cells, Row(Eat \| empty), Retreat as StrideButton.secondary link ] ]`. Card budget documented at `:22, :532-551` (219 dp). |
| Stage | backdrop **192 × 128 native drawn ×2 = 384 × 256 dp** (`combat_stage.dart:39`), clipped/centred; HUD strip beneath, HP gauge `hp_gauge_frame.png` rows 4–11 only. Command plates `plate_attack/brace/eat.png` are **ornaments, not nine-patches** (centred blobs on transparent 64×32; `assets/ui/v1/README.md` "What the integrator found"), drawn 128×64 dp (`_plateWidth/_plateHeight` `combat_screen.dart:817-818`) behind the label; cell height `_cellHeight = 56` (`:811`). `narration_strip.png` and `turn_marker.png` are packaged and deliberately **not drawn** (contrast 2.90:1; coin read). |
| Roles/surfaces | `combatFrame + leather` (`combat_screen.dart:301-303`); `combatFrame` is **unframed** (not in `PanelSkins.authored`) so it reserves 0 |
| Shared deps | `GroundedSprite`, `SpriteAnimation`, `RewardRaise/RewardBeat/LevelUpCard/RewardItemRow`, `StrideButton`, `StaggeredReveal`, `SessionController.lastCombat/combatBusy` |
| Save-affecting call sites | `c.combatAttack` `:719`, `c.combatBrace` `:745`, `c.combatEat` `:788`, `c.combatRetreat` `:801`, `c.acknowledgeCombat` `:240`, `:265` (clears the held outcome — the Continue gate) |
| Golden | `test/combat_golden_test.dart` (`@Tags(['golden'])`) → `test/goldens/combat_stage.png` ("the wolf, turn 1, idle"), `combat_victory.png`; extra PNGs to `COMBAT_EVIDENCE_DIR` (guardian idle + heavy blow) |
| Evidence/behaviour tests | `combat_ui_test.dart` (holds the narration-strip contrast figures), `combat_presentation_order_test.dart`, `combat_stage_test.dart`, `combat_gear_evidence_test.dart` (`COMBAT_GEAR_EVIDENCE_DIR`), `combat_busy_test.dart`, `combat_visible_death_test.dart`, `combat_guard_reading_test.dart`, `combat_guard_reading_live_test.dart`, `combat_session_test.dart`, `step_regrant_after_defeat_test.dart` |

### 1.8 Encounter panel / Bestiary — producer COMBAT (contents), slot owned by ADVENTURE

| | |
|---|---|
| Files | `lib/ui/screens/adventure/encounter_card.dart` (737), `bestiary_screen.dart` (281, pushed via `BestiaryScreen.open` `:46`) |
| Encounter tree | `EncounterPanel = SectionCard() > Column[ SectionHeading 'Encounters', BandPlate(encounterGround), _EncounterRow … / EncounterCard ]` (`encounter_card.dart:85-93`); `EncounterCard = Column[ _EnemyStage (Container band, height clamped `:480`, fill `surfaceBlock`) > Stack > _EnemyIdle (GroundedSprite at stage scale ×2), StrideButton 'Fight' ]` (`:233-327`) |
| Bestiary tree | `ColoredBox > Column[ ScreenHeader(back), Expanded(ListView[ SectionCard(), per-region SectionCard(surface: slate) > Column[_BestiaryRow …] ]) ]` (`bestiary_screen.dart:65-135`). Text-only; `slate` surface at `:131`. |
| Shared deps | `CombatTrack`/`CombatAssets` (`combat_assets.dart`), `GroundedSprite`, `RarityItemTitle`, `BandPlate`, `ScreenHeader` |
| Save-affecting call sites | `startEncounter(enemy)` `encounter_card.dart:336` — the only one; Bestiary has none |
| Tests | `encounter_card_test.dart`, `combat_ui_test.dart` (EncounterCard). **No test references `BestiaryScreen` or `EncounterPanel` by type; no golden.** |

### 1.9 World + atlas panel — producer WORLD

| | |
|---|---|
| Files | `lib/ui/screens/world/world_screen.dart` (731), `atlas/atlas_selection_panel.dart` (860), `atlas/atlas_place_info.dart` (253), `atlas/atlas_viewport.dart` (461), `atlas/atlas_layers.dart` (1652, paint — **do not touch: GOV-04 atlas guardian territory**), `atlas/atlas_layout.dart` (376), `travel_transition.dart` (378), `travel_pacing.dart` (134); `lib/ui/icons/atlas_assets.dart` |
| Tree (`world_screen.dart:146-290`) | `LayoutBuilder > Stack[ Positioned.fill(AtlasViewport), AnimatedPositioned(bottom, height: panelHeight) > _WorldInfoPanel(collapsedChild: _PanelPeekRow, child: ListView[ _CurrentPlaceBar?, AtlasSelectionPanel(bare: true) → AtlasInspector, … ]) ]`; `_ListFallback` (`:440`, two `SectionCard()`s) when `atlasLayoutProblems` is non-empty |
| The sheet that "covers too much map" | `_panelFraction = 0.34`, `_panelMinHeight = 220`, `_panelMaxHeight = 360`, `_panelPeekHeight = 76`, `_panelHandleHeight = 20`, `_panelFadeHeight = 40` (`world_screen.dart:100-121`); height = `(maxHeight × 0.34).clamp(220, 360)` → **290 dp on 852** plus the fade. Not a `StrideSheet` and not a `BackdropFilter` — a gradient `DecoratedBox` `0x00→0xB4→0xE6 14120F` (`:287-380`), vertical-drag to fold (`onVerticalDragEnd :349`). |
| Roles/surfaces | `AtlasInspector` bare on World (no card); framed only when `bare == false` → `SectionCard(surface: chartVellum) > Column[ BandPlate(worldChart), … ]` (`atlas_selection_panel.dart:456-471`); `_TravelControls` → `SurfaceBlock + StrideButton` (`:683-707`) |
| Shared deps | `AtlasViewport`, `AtlasLayers`, `AtlasLayout` (runtime `lib/runtime/atlas_layout.dart`), `WalkingGlyph`, `RewardRaise/RewardBeat` (discovery layer), `StrideButton`, `TravelTransition`, `AmbientPlayer` |
| Save-affecting call sites | `controller.travel(destination)` `world_screen.dart:662` (list fallback); `controller.travelJourney(legs)` `atlas_selection_panel.dart:133`; `trackGoal` `:182`; `trackGoalJourney` `:183`; `c.reload` `world_screen.dart:242, :465` |
| Golden | `phase1_golden_test.dart` → `phase1_world.png`, `phase1_world_large.png` |
| Evidence/behaviour tests | `atlas_screen_test.dart` (393×852 DPR 3), `atlas_inspector_test.dart`, `atlas_scene_test.dart` (390×844 DPR 3), `atlas_layout_test.dart`, `travel_transition_test.dart`, `travel_pacing_test.dart`, `ambient_cadence_test.dart`, `screen_evidence_test.dart` (`v2_world`, `v2_world_arrived`, `v2_world_journey_ring`, `v2_travel_card(_departure)`, `v2_discovery_layer`, `v3_world_hollow_inspector`, `world_inspector_destination`) |

### 1.10 Shell / header / nav — producer NAV(+kit)

| | |
|---|---|
| Files | `lib/ui/shell/stride_shell.dart` (197), `stride_destination.dart` (87), `shell_tabs.dart` (30); `lib/ui/components/stride_scaffold.dart` (56), `screen_header.dart` (275), `stride_tab_bar.dart` (200) |
| Shell tree (`stride_shell.dart:37-197`) | `StrideScaffold(header: ScreenHeader(eyebrow/title/regionInk from `session.placeIdentityOf`, trailing: BankedStepsReadout), body: IndexedStack[ AdventureScreen, CharacterScreen, SkillsScreen, InventoryScreen, CraftScreen, WorldScreen ] (`:155-186`), bottomBar: StrideTabBar(`:191`))`. `StrideScaffold` = `ColoredBox(surfaceGround) > Column[ SizedBox(inset.top), header, Expanded(body), ColoredBox(surfaceCard) > Column[bar, SizedBox(inset.bottom)] ]` |
| Header (`screen_header.dart:67-178`) | `Stack[ Padding(Row[ Column(eyebrow Cinzel 11, title Cinzel 18), trailing ≤ 62 % ]), bottom: EdgeStrip.headerShelf (`:168`, `header_shelf.png` 8×6 ×2 → `shelfHeight = 12`, tiled horizontally, only when `rule != null`) ]`; `headerMinHeight = 61` (`stride_metrics.dart:94`) is a minimum, not a fixed height |
| Tab bar (`stride_tab_bar.dart:33-95`) | `_Leather(SurfaceFill grain_leather) > SizedBox(h: tabBarHeight 64) > MediaQuery.withNoTextScaling > Column[ EdgeStrip.navWelt (`weltHeight = 8`, `nav_welt.png` 8×4 ×2), Expanded(Row[ 6 × Expanded(_Tab: PixelAsset.nav 14² ×2 + tabLabel 9.5) ]) ]`. Active = `surfaceBlock` fill + `StrideRadius.tabActive`; `_hi` glyphs are palette-index remaps (`Scripts/art/nav-active-variant.js`). |
| Save-affecting call sites | none in the shell beyond tab selection (`setState`); `DevHarnessScreen` push at `stride_shell.dart:67` |
| Tests | `band_plate_test.dart` group 'the chrome edges cost no layout' (`:253-349`: header still 61 dp, header without rule has no shelf, tab bar still 64 dp), `fold_clearance_test.dart` (four phone sizes, DPR 3), `phase1_ui_test.dart`, `phase1_golden_test.dart` (all six goldens include header + bar), `ui_responsive_test.dart` |

---

## 2. Shared files — single owner this round

Recommendation: **NAV(+kit) owns every file in this table unless a row says
otherwise.** Other producers file a one-line request (what token/row/parameter,
why) and NAV lands it; producers never edit these files on their own branch.
The reason is mechanical, not political: `PanelSkins.authored` and
`PanelSurfaces.authored` are global registries — a row changes every panel of
that role at once — and `phase1_golden_test.dart` renders all six tabs in one
test, so any change here reflows and re-goldens every producer's screen.

| File | Who will want to touch it | Owner |
|---|---|---|
| `lib/ui/components/panel_skin.dart` (`PanelRole`, `PanelSurface`, `PanelSkins`, `PanelSurfaces`, `ButtonPlates`) | **all eight** — every new material, frame or role is a row here | NAV |
| `lib/ui/components/surfaces.dart` (`SectionCard`, `SurfaceBlock`, `InsetWell`, `SectionHeading`) | all eight (new container kinds, clip behaviour, padding) | NAV |
| `lib/ui/components/band_plate.dart` (`StrideBand`, `StrideBands.forPlace/forStation/forSkill`, `BandPlate`) | ADVENTURE (`forPlace`), CRAFT (`forStation`), SKILLS (`forSkill`), WORLD (`worldChart`), COMBAT (`encounterGround`, `combatKit`) | NAV |
| `lib/ui/components/bottom_sheet.dart` (`StrideSheet`, `maxFraction = 0.7`) | CRAFT (sole consumer today), WORLD (if the map panel becomes a sheet), INVENTORY (item detail) | NAV — CRAFT may propose, WORLD must not fork a second sheet |
| `lib/ui/components/screen_header.dart` | NAV; WORLD (full-bleed map under the header), SKILLS/COMBAT (back affordance) | NAV |
| `lib/ui/components/stride_tab_bar.dart`, `lib/ui/shell/*.dart`, `stride_scaffold.dart` | NAV only (the owner's "bottom nav is plain" verdict) | NAV |
| `lib/ui/theme/stride_colors.dart` | all (new tokens); COMBAT (button registers), WORLD (region deeps) | NAV |
| `lib/ui/theme/stride_typography.dart` | all; SKILLS/CRAFT (ledger numerals), NAV (tab labels) | NAV |
| `lib/ui/theme/stride_metrics.dart` (`StrideSpace`, `StrideRadius`, `StrideGeometry`) | all; COMBAT (`buttonHeight`), INVENTORY (`itemTileMinHeight`, `gridColumnFloor`), NAV (`tabBarHeight`, `headerMinHeight`) | NAV |
| `lib/ui/components/pixel_asset.dart` (`PixelAsset`, `PixelScene`, `PixelFrame`, `SurfaceFill`, `EdgeStrip`, `paintSurfaceTile`) | NAV; COMBAT (ornament placement), CRAFT (sheet grain) | NAV |
| `lib/ui/components/data_display.dart` (`StrideButton`, `SkillChip`, `RequirementGate`, `ValueTileRow`) | all (`StrideButton` has 15 primary + 28 secondary call sites); COMBAT wants button weight down | NAV |
| `lib/ui/components/rules.dart` (`HairlineRule`, `ProgressRule`) | SKILLS, CHARACTER, CRAFT | NAV |
| `lib/ui/components/adaptive_text.dart` | all | NAV (freeze) |
| `lib/ui/components/activity_result.dart`, `reward_layer.dart`, `reward_beat.dart` | ADVENTURE, CRAFT, COMBAT, WORLD (six consumer files) | NAV (**freeze this round** — these are the accepted GFCP01/FMPO02 feedback surfaces) |
| `lib/ui/components/loadout_readout.dart`, `gear_stats.dart`, `rarity_item_title.dart`, `rarity_badge.dart`, `lib/ui/theme/rarity_style.dart` | INVENTORY, CHARACTER, CRAFT, COMBAT | INVENTORY (CHARACTER/CRAFT request) |
| `lib/ui/components/ambient_stage.dart`, `ambient_scene.dart`, `ambient_player.dart`, `grounded_sprite.dart`, `sprite_animation.dart`, `screens/adventure/location_stage.dart` | ADVENTURE, CRAFT (`StationStrip`), COMBAT (`GroundedSprite`), WORLD (`TravelTransition`) | ADVENTURE (freeze the sprite/animation files; only `location_stage.dart` layout is in scope) |
| `lib/ui/components/station_strip.dart` | CRAFT only | CRAFT |
| `lib/ui/screens/skills/skills_screen.dart` exports (`SkillPlate`, `SkillHeaderRow`, `SkillProgressBar`, `SkillProgressCaption`) | SKILLS (both screens), CHARACTER (`_SkillSpine` is a private copy, not an import) | SKILLS |
| `lib/ui/screens/adventure/adventure_screen.dart:124-136` (the in-fight branch) | ADVENTURE, COMBAT | ADVENTURE owns the file; **the branch is frozen** — COMBAT changes only `combat/*` |
| `lib/ui/screens/adventure/encounter_card.dart`, `bestiary_screen.dart` | COMBAT (creature stage, Fight), ADVENTURE (slot in the ListView) | COMBAT owns the files; ADVENTURE owns the call at `adventure_screen.dart:83` |
| `lib/ui/icons/pixel_icons.dart`, `combat_assets.dart`, `traveler_art.dart`, `atlas_assets.dart`, `reward_art.dart`, `ambient_assets.dart`, `encounter_habitat.dart`, `sprite_footprints.dart` | per family | NAV (`pixel_icons`), COMBAT (`combat_assets`, `encounter_habitat`, `sprite_footprints`), INVENTORY (`traveler_art`), WORLD (`atlas_assets`), ADVENTURE (`ambient_assets`, `reward_art`) |
| `pubspec.yaml` asset block (`:79-167`), `assets/ui/v1/README.md`, `Scripts/art/check-art-palette.js` (`CHROME` `:110`), `Scripts/art/check-tile-seam.js` | anyone adding art | NAV |
| `test/phase1_golden_test.dart`, `test/goldens/*.png`, `test/combat_golden_test.dart` | all | **integrator only** — see §5 |
| `test/panel_skin_test.dart`, `test/band_plate_test.dart`, `test/stride_button_test.dart`, `test/fold_clearance_test.dart` | NAV | NAV |

---

## 3. The material kit as it exists

All under `assets/ui/v1/`; every PNG declared file-by-file in `pubspec.yaml:79-167`;
every `.json` sidecar is **build-time only and deliberately not in `pubspec.yaml`**.
Provenance rows: `assets/ui/v1/README.md`.

### 3.1 Frame (`PanelSkins`, `panel_skin.dart:341-380`)

| Asset | Native | corner / band / period / scale | Registered to |
|---|---|---|---|
| `frame/chassis_64.png` + `.json` | 64×64 | 16 / 8 / 8 / 2 → inset 16 dp, corner block 32 dp | `PanelRole.heroPlate`, `PanelRole.modalFrame` **only**. `card`, `kitTray`, `combatFrame`, `boardSlip` are unframed and reserve 0 (`_reserve` `:381`). |

### 3.2 Surfaces (`PanelSurfaces.authored`, `panel_skin.dart:256-311`) — 32×32 native, ×2, tiled both axes from the interior top-left, last row/column clipped

| `PanelSurface` | File | Ramp (shadow→highlight) | Consumers today |
|---|---|---|---|
| `journalLeaf` | `surface/grain_journal_leaf.png` | `#1C1811 #241F17 #332B1F #463A28 #5C4C34` | Adventure `ActivityPanel`, Craft hero/tiles/ledger, Character hero |
| `oilcloth` | `grain_oilcloth.png` | `#1A1C15 #23261B #333524 #464A31 #5B5E3F` | Inventory case + tray |
| `buckram` | `grain_buckram.png` | `#1D1912 #26211A #362E22 #4B4030 #61533E` | Skills overview |
| `leather` | `grain_leather.png` | `#1B1310 #241914 #3A2620 #54372C #6C4736` | Combat card, **nav bar ground** (`stride_tab_bar.dart:38`); ships on a `CHECK` (ΔL* 7.45) |
| `benchOak` | `grain_bench_oak.png` | `#160F0A #1E140E #2E2015 #43301F #5A4229` | Craft station header |
| `steel` | `grain_steel.png` | `#14161A #1C1F24 #2B2F36 #3E434C #535A63` | **nobody** (intended: combat command surfaces) |
| `slate` | `grain_slate.png` | `#15161A #1E2024 #2C2F34 #3F444A #565B60` | Bestiary region cards |
| `chartVellum` | `grain_chart_vellum.png` | `#1A1712 #23201A #332E25 #463F32 #5A5142` | Atlas inspector (framed mode only). **Ships without grain** (99.4 % one ink) |
| `cork` | `grain_cork.png` | `#1C170F #26201A #372E22 #4C4130 #63533D` | `GoalSummaryCard` |
| `planLinen` | `grain_plan_linen.png` | `#12161C #1A2028 #28323E #3B4A58 #4E6072` | **nobody** (intended: construction ledger / Projects) |
| `notable` | `grain_notable_plate.png` (**no sidecar**) | warm dark parchment, mirror-folded | `ActivityResultCard` via `SurfaceFill` (`activity_result.dart:230`) |
| `none` | — | flat `surfaceCard #201C17` | Skill detail ×2, Bestiary top card, Character ×6, Adventure encounter/opportunity/tracker, Craft `_RecipeDetail`, World fallback, Goal Board slips |

Sidecar `recipe` for every grain: `flattenRadius 4, grainDepthRungs 2, rampTarget 1 (cork 0.9), window 32, method "cut, no mirror"`.

### 3.3 Bands (`StrideBands.authored`, `band_plate.dart:103-117`) — 384×48, ×1, centred and clipped, never tiled/stretched; each carries a ×0.87–0.93 linear-light gain so its brightest pixel is ≤ L 0.1400 (4.5:1 under `textPrimary`)

`band_forge`, `band_cookfire`, `band_bench`, `band_foraging`, `band_mining`, `band_world_chart`, `band_encounter_ground`, `band_adventure_trail`, `band_boards_batten`, `band_combat_kit` (**registered, deliberately unused** — combat's picture is its stage). Mappings: `forStation` (`forge/woodbench/cookfire`, `:120`), `forSkill` (`:133`), `forPlace(PlaceIdentity)` by `(LocationKind, Terrain)` (`:161`; perilous → none).

### 3.4 Button plates (`ButtonPlates`, `panel_skin.dart:407-443`) — drawn through `PixelFrame` by `StrideButton` (`data_display.dart:504`)

| Asset | Native | Measured corner / band | Declared | Note |
|---|---|---|---|---|
| `button/btn_plate.png` | 58×26 | 4 / **0** | corner 4, band **1** | `PanelSkin` asserts `band > 0`; do not carry a 0 band to a panel and do not weaken the assert |
| `button/btn_compact.png` | 46×22 | 5 / 2 | 5 / 2 | secondary/utility |

One leather ramp `#241F18 #3A332B #4A4034 #6B5A3E`; **no register or state art** — `commit/attack/defense/ready` differ by the `outline`/`ledge` tokens in `StrideButton` (DECISIONS/0029 forbids raster state variants).

### 3.5 Chrome edges (`EdgeStrip`, `pixel_asset.dart:842-880`) — tiled horizontally at period 8, ×2, last tile clipped

| Asset | Native | Widget | Replaces |
|---|---|---|---|
| `header/header_shelf.png` | 8×6 | `EdgeStrip.headerShelf` (`screen_header.dart:168`) | the 24 %-alpha header hairline; adds `shelfHeight = 12` only when `rule != null` |
| `nav/nav_welt.png` | 8×4 | `EdgeStrip.navWelt` (`stride_tab_bar.dart:67`) | the bar's 1 px `borderDefault` top rule; `weltHeight = 8` inside the unchanged 64 dp |

### 3.6 Combat HUD (`CombatHudAssets`, `combat_assets.dart:1329-1406`) — no sidecars

`combat/hp_gauge_frame.png` 96×16 (pill rows 4–11), `turn_marker.png` 24×24 (not drawn), `narration_strip.png` 64×16 (not drawn), `plate_attack/brace/eat.png` 64×32 (ornaments), `icon_attack/brace/eat.png` 16×16.

### 3.7 Glyphs and icons at the root of `assets/ui/v1/`

`nav_{adventure,character,skills,inventory,craft,world}.png` + `_hi` (14×14 ×2), `glyph_steps.png` (12×12, **the one teal file**), `glyph_steps_muted.png`, `glyph_arrow.png`, `skill_{foraging,woodcutting,mining,smithing,cooking}.png` (24×24 ×1).

### 3.8 The two colour rules and their guards

**L\* ceiling (`art-palette.ceiling`).** No opaque pixel in the chrome directories may exceed `textMuted #7C7263` in WCAG relative luminance (L = 0.1722). Enforced by `Scripts/art/check-art-palette.js:98,110,248` — but `CHROME` is only `assets/ui/v1/{frame,surface,ornament}`; `band/`, `button/`, `nav/`, `header/`, `combat/` are **not** in that list and are covered only by the `guards.over = 0` figure `ui-package.js` writes into each sidecar. Bands additionally must clear **4.5:1 against `textPrimary`** (L ≤ 0.1403) because type sits on them: `test/band_plate_test.dart:350-351` 'bands are text-safe' › 'every shipped band clears 4.5:1 against textPrimary' measures the shipped PNGs. Frames may not use the substrate inks `#201C17`/`#14120F` (`art-palette.substrate`, `FRAMES` `:113`). No pixel anywhere in `assets/art/v1` or `assets/ui/v1` may have `0 < a < 255` (`art-palette.alpha`).

**Reserved teal (`art-palette.teal`, L-16).** No opaque pixel within Chebyshev 10 of `#58D6C0` (`StrideColors.accentSteps`, `stride_colors.dart:79`) in any shipped PNG except `assets/ui/v1/glyph_steps.png` (`TEAL_ALLOWLIST` `check-art-palette.js:95`). Dart-side: `test/rarity_ui_test.dart:265-289` (no rarity ink/accent is `accentSteps`/`accentStepsDim`; teal reads as teal), `test/board_reward_layer_test.dart:217-234`, `test/phase1_ui_test.dart:1377`. Both scripts run in `Scripts/verify.sh:158-169` (self-test then real).

### 3.9 Typography ladder (`lib/ui/theme/stride_typography.dart`; fonts `pubspec.yaml:349-357`)

Two families only. **Cinzel** (variable TTF, `_wght` axis, display): `screenEyebrow 11`, `sectionHeading 16`, `screenTitle 18`, `cardTitle 19`. **Alegreya Sans** (Regular 400 + Medium, lining figures forced, optional `tabularFigures`): `compactLabel 9.5`, `tabLabel / tabLabelActive 9.5`, `gateLabel 10`, `itemName 10.5`, `microLabel 11`, `micro 11`, `body 12.5`, `sub 13`, `buttonLabelSecondary 13`, `itemCount 14.5`, `buttonLabel 15`, `headerValue 19`, `numericValue 22`, `numericHero 28`. Tab labels are the one place text scaling is frozen (`MediaQuery.withNoTextScaling`, `stride_tab_bar.dart:47`). Goldens render in Roboto (`test/support/real_font.dart:74`), not these fonts.

---

## 4. Adding a nine-patch / tile / band end to end

`Scripts/art/package-art.js` **does not write `assets/ui/v1/`** — it writes `assets/art/v1/` only (`package-art.js:3252-3253`; `assets/ui/v1/README.md` "packaged by hand"). The UI pipeline is the FMPO02 tool set, then hand-copy, then a registry row.

| Step | Where | file:line |
|---|---|---|
| 1. Generate in PixelLab; save the master | `GAME_BIBLE/ART/exploration/<ROUND>/raw/ui/<kind>/<name>.png` | — |
| 2. Deterministic post-work (A-2): snap to an ART-13 ramp, measure seam, cut/fold | `GAME_BIBLE/ART/exploration/FMPO02/tools/surface.js` (`--ramp <name> --out … [--align] [--fold]`), `tile-cut.js`, `band.js`/`band-batch.js` (`--textsafe` gain), `btn-prep.js`, `ramps.js` (the ramp table), `colour.js` | `surface.js:1-27` |
| 3. Emit shipped PNG **+ sidecar** with measured geometry and guards | `FMPO02/tools/ui-package.js` → `out/ui/<kind>/<name>.png` + `.json` (`emit()` `:37-45`, `guards()` `:15-34`) | `ui-package.js:37` |
| 4. Copy both files by hand | `assets/ui/v1/<frame\|surface\|band\|button\|nav\|header\|ornament>/<name>.{png,json}` | — |
| 5. Declare the PNG (never the JSON) | `pubspec.yaml:79-167` asset block | — |
| 6. Provenance row | `assets/ui/v1/README.md` | — |
| 7a. Surface → enum member + registry row | `PanelSurface` `panel_skin.dart:179-222`; `PanelSurfaces.authored` `:256-311` | — |
| 7b. Frame → `PanelSkin` const + role row + reserve | `panel_skin.dart:354-362` (`_chassis` pattern); `PanelSkins.authored` `:341`; `_reserve` `:381` | — |
| 7c. Band → enum + path + mapping | `StrideBand` `band_plate.dart:57`; `StrideBands.authored` `:103`; `forStation :120` / `forSkill :133` / `forPlace :161` | — |
| 7d. Button plate | `ButtonPlates` `panel_skin.dart:407-443` | — |
| 7e. Edge strip → named constructor | `EdgeStrip.navWelt/.headerShelf` `pixel_asset.dart:855-870` | — |
| 8. Paint path (no code needed, for reference) | `SectionCard.build` `surfaces.dart:88-165` → framed: `PixelFrame` `pixel_asset.dart:315` → `_FramePainter.paint` `:616` (surface tile first, inset by `skin.inset` `:624-631`; corners `:640-655`; edges **tiled** `:657-700`); unframed: `SurfaceFill` `:495` → `_SurfacePainter.paint` `:567`; both via `paintSurfaceTile` `:468` (`FilterQuality.none`, integer scale) | — |
| 9. Guards | `node Scripts/art/check-art-palette.js` (add any **new directory** to `CHROME` `:110`); `node Scripts/art/check-tile-seam.js` (walks only `FRAME_DIR`/`SURFACE_DIR` `:75-76, :251`; reads `corner` (required for frames) and `period` (default 8) from the sidecar `:261-274, :297`); `flutter test test/panel_skin_test.dart test/band_plate_test.dart` | — |
| 10. Device look | §5 harness, then the iPhone | — |

**Sidecar schema** (one line): `{asset, destination, canvas:[w,h], kind, corner:int|null, band:int|null, period:int|null, scale:int, tiles?, alpha?, ramp:string|string[], master, crop?|recipe:{flattenRadius,grainDepthRungs,rampTarget,window,method}, textSafe?, ceiling?, guards:{teal,semi,over,colours,maxHex,maxL,verdict}|string, note}` — `chassis_64.json` is the minimal older form `{corner, band, period, scale, note}`; `corner` and `band` are **measured off the PNG**, never copied from the brief (`btn_plate` corner 4 / band 0 vs the brief's 8 / 4 is the recorded example).

Tests that will notice a new row: `panel_skin_test.dart:43` 'only the picture and the interruption are framed' (fails if a third role is framed), `:82` 'every authored surface names a tile at integer scale', `:95` 'the chassis geometry matches the asset it declares'; `band_plate_test.dart:57` 'every authored tile decodes at the path the registry names', `:97` 'every surface but none has a tile' (**an enum member without a registry row fails**), `:157` 'every band names a file under assets/ui/v1/band', `:168` 'the station and trade mappings are the ones reviewed', `:133` 'measured geometry, not the brief's'.

---

## 5. Rendering screens at phone size

There is **no DPR-3 capture and no simulator render**. What FMPO02 called the
"device renders" (`GAME_BIBLE/ART/exploration/FMPO02/review/device/*.png`, 41
screens + `board/`, `combat/`, `stage/`) are the widget-test harnesses driving
the real app at **393 × 852 logical, `devicePixelRatio = 1.0`, zero
safe-area insets, Roboto**, captured with
`captureImage(find.byType(StrideApp))` (`test/screen_evidence_test.dart:160-175`)
after `settleImages` precaches every `Image`, `PixelFrame` (frame + surface) and
`SurfaceFill` (`:118-152`) — a producer who adds a new raster-bearing widget
type must add it to that loop or the capture races the decode. The real iPhone
(DPR 3) remains the final authority; several tests use `physicalSize = 393×3,
DPR 3` (`atlas_screen_test`, `combat_ui_test`, `craft_planner_test`,
`fold_clearance_test`) for layout, not for pictures.

Flutter is not on PATH. Every command needs, in Git Bash:

```
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
```

| Harness | Command (Git Bash, repo root) | Writes |
|---|---|---|
| Six tabs + driven states | `SCREEN_EVIDENCE_DIR=/abs/out flutter test test/screen_evidence_test.dart` | `adventure, inventory, craft_gear_open, character, character_playtest_confirm, skills, v2_*, v3_*, gfcp_*` |
| Gather stage (work mode) | `STAGE_EVIDENCE_DIR=/abs/out flutter test test/stage_evidence_test.dart` | `mine_copper, mine_tin, mine_hardened_locked, woods_oak, haven_meadow` |
| Combat stage + victory + guardian extras | `COMBAT_EVIDENCE_DIR=/abs/out flutter test test/combat_golden_test.dart` | goldens compared **and** extra PNGs |
| Combat with gear variants | `COMBAT_GEAR_EVIDENCE_DIR=/abs/out flutter test test/combat_gear_evidence_test.dart` | `gear_*` |
| Goal Board + reward layer | `BOARD_EVIDENCE_DIR=/abs/out flutter test test/board_reward_layer_test.dart` | `board_closed, board_open, board_layer` |
| Craft stage mid-craft | `CRAFT_STAGE_EVIDENCE_DIR=/abs/out flutter test test/craft_stage_evidence_test.dart` | craft stage |
| Reward art in context | `REWARD_ART_EVIDENCE_DIR=/abs/out flutter test test/reward_art_evidence_test.dart` | reward marks |

Without the variable every harness silently degrades to a mount-and-drive smoke test.

**Goldens.** Two files, both `@Tags(['golden'])` (`phase1_golden_test.dart:42`,
`combat_golden_test.dart:20`) and therefore **excluded from CI**
(`.github/workflows/ci.yml:307, :538` run `flutter test --exclude-tags golden`);
they are local proof only. Regenerate with:

```
flutter test --update-goldens test/phase1_golden_test.dart
flutter test --update-goldens test/combat_golden_test.dart
```

`phase1_golden_test.dart` writes 12 PNGs (six tabs × normal / "455,281 banked"
large) plus `craft_stage.png` from **one test each** — there is no per-screen
golden to regenerate in isolation.

---

## 6. Structural traps for a screen rebuilder (ranked)

1. **Combat is a child of Adventure, not a route** (`adventure_screen.dart:124-136`). ADVENTURE and COMBAT both have a reason to edit that file. Freeze the branch: ADVENTURE may restructure lines 236-300 only; COMBAT edits `combat/*` only. The same file also hosts `EncounterPanel` (`:83`) whose contents belong to COMBAT.
2. **One golden test renders all six tabs, and goldens are binary.** Eight branches each running `--update-goldens` produce eight conflicting `test/goldens/phase1_*.png`. Producers prove their screen with their evidence-harness PNG (§5) and do **not** commit goldens; the integrator regenerates once after all eight land. CI will not catch a stale golden (tagged out), so a wrong regeneration survives until someone runs it locally.
3. **The registries are global and guarded by name.** A `PanelSurface` member without an `authored` row fails `band_plate_test.dart:97`; a third framed role fails `panel_skin_test.dart:43`; a `PanelSkin` with `band == 0` fails the constructor assert; a new asset directory is invisible to `check-art-palette.js` until it is added to `CHROME`. Every row changes every panel of that role/surface on every screen at once — which is why NAV owns `panel_skin.dart` and lands rows for everyone.
4. `SectionCard` **does not clip its surface** to its radius (`skills_screen.dart:86` wraps in `ClipRRect` for this reason); a producer who draws rules or bands inside a card must clip or they bleed past the corner.
5. **Framed roles reserve 16 dp whether or not the PNG decodes** (`PanelSkins.insetFor`, `_reserve` `:381-393`); surface roles reserve 0. Moving a panel between `heroPlate` and a surface role reflows its content by 32 dp of width.
6. `StrideScaffold` is the only `SafeArea`. A pushed route that adds its own `SafeArea` double-insets on notched devices and looks right on the developer's device.
7. `StrideSheet` must be the **last child of a full-screen `Stack`** (`bottom_sheet.dart:33-37`) and caps at `maxFraction = 0.7`; the World panel is not a `StrideSheet` and has its own `_panelFraction = 0.34` clamp (220–360 dp). Two sheet systems already exist; do not add a third.
8. **Combat command plates are ornaments, not nine-patches** — their corner blocks are transparent; feeding them to `PixelFrame` tiles the blob's arc across the cell.
9. Bands are `384 × 48` at ×1 and **clip** at 320/360 dp; nothing load-bearing may sit in a band's outer 32 px. Any re-authored band must go through the `--textsafe` gain or `band_plate_test.dart:351` fails.
10. Tab labels are under `withNoTextScaling`; everything else scales. A header is a **minimum** 61 dp, not a fixed height; the shelf adds 12 dp only when `rule != null`.

---

## 7. Deltas from the FMPO02 wave0 map worth knowing

- `PanelSkins.authored` shrank from six rows to two (`heroPlate`, `modalFrame`); `surfacePath` on `PanelSkin` is dead — the live lever is `SectionCard.surface` → `PanelSurface` → `PixelFrame.surface` / `SurfaceFill`.
- Craft moved from inline `_RecipeDetail` under the row to `StrideSheet`; the list is now a 2-column `_TileFolio` grid plus a `_LockedLedger`.
- Skills overview is one buckram card holding five `SkillSpine`s, not five washed cards.
- Combat backdrop is 192×128 (was 192×96); command grid is 2×2 of 56 dp cells with plate ornaments, Retreat a secondary link.
- Header and tab bar gained `EdgeStrip` chrome; the tab bar sits on `grain_leather`.
- `combat_golden_test.dart` and `phase1_golden_test.dart` are both tagged `golden` and excluded from CI.
