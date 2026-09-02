# ART-12 — FMPO02 structural UX brief

Structural IA, not decoration. All numbers are dp at 393x852, scale 1.0. Non-negotiable floors: hit regions >=44; no fixed box around scaling text (D-01); `AdaptiveText` shrinks, never clips; a `disableAnimationsOf` branch on every new motion; the primary action of any screen sits below y=520 (one-handed reach); integer sprite scales only.

## 0. Spacing tokens — three rhythms replace uniform 16

Add to `StrideSpace`, and use nothing else vertically:

| Token | dp | Means |
|---|---|---|
| `rhythmHero` | 24 | after a hero/folio block, before the next group |
| `rhythmGroup` | 16 | between named groups inside a screen |
| `rhythmRow` | 8 | between peers inside one group |

Rule: a vertical scan down any screen reads 24 -> 16 -> 8 and never repeats one value across two hierarchy levels. `screenGutter` stays 16 horizontal. `cardGap` (10) is retired in favour of `rhythmRow`. Grid gaps: 8 for <=4 columns, 6 for 5.

## 1. Craft — from database to workshop

**Station is free data.** `AmbientAssets.craftStationKind(recipe.station?.name, skill)` already resolves all 39 recipes to `forge` (23), `cookfire` (11), `woodbench` (5). No content change, no new save state.

**Station strip** — replaces the category chips as the primary axis; the 4 chips survive as a secondary filter *inside* a station.
- Three `Expanded` plates, gap 8 (~114 wide each), plate height **88**.
- Plate art is the existing 96x96 `station_forge/woodbench/cookfire.png` at x1, bottom-aligned by measured `bounds.bottom` exactly as `_EnemyStage.groundOffset` does, clipped to `StrideRadius.inner`.
- Label *below* the plate, outside it so type can grow: `microLabel` name + `micro` count ("23 recipes - 1 ready"). Selected plate takes `actionEdge` + `surfaceRaised`; unselected keeps `borderDefault`. Tap target is the 88dp plate. Selection is ephemeral UI state, like `_selected`.

**Inside a station, top to bottom:**

1. **Hero folio card** — the single best ready recipe (highest tier, then most craftable). Full width. Output icon **96dp (48 native at x2)** in `InsetWell.square(contentSize: 96)`, left; right column carries `RarityName` at `cardTitle`, the rarity badge, the skill/XP line. Beneath both, the **ingredient tray**: a `Wrap` of wells, each a 48dp icon with `held/required` in `micro` under it, spacing 8. Then the x1/x5/x10 queue chips and the 48dp `Craft` button. Card padding 12; `rhythmHero` below. The folio is **already expanded** — no tap, no sheet.
2. **Ready / One away / Missing** as **2-column tiles**: column (393-32-8)/2 = **176**, gap 8. Tile = 48dp icon (48 native x1) top-left, two-line `itemName`, one `micro` state line, and a 4dp readiness rule flush to the tile's bottom edge (moss when ready, muted otherwise). Height derived from the text scaler with a floor of **112** — never `mainAxisExtent` from a constant; repeat `inventory_screen._tileExtent`. Heading is `sectionHeading` + count; `rhythmGroup` between groups, `rhythmRow` between tile rows.
3. **Locked ledger** — one line per gate level, not one row per recipe: "4 more at Smithing 3", 40dp tall, hairline separated; tapping expands that level into the same 2-column tiles. "A disabled recipe must say why" still holds: the ledger line names the gate and the tile's sheet carries `_reason()` verbatim.

**Where detail opens.** Inline expansion survives **only** for the hero folio, because it is full width and single. The 2-column tiles open a **bottom sheet** (hand-rolled, no Material): inline expansion inside a 2-column grid displaces the tile's row partner and shoves half the list off-screen, and that scroll-hunt is precisely what makes the screen read as a database. Sheet rules: max height 70% of screen; 56dp grab area; content is today's `_RecipeDetail` unchanged; the Craft button pinned above the bottom inset; dismiss on scrim tap and on back; focus returns to the tile. A chain jump replaces sheet content in place and keeps `_ChainBackChip`.

## 2. Inventory — an equipment case, then a pack

**Equipment case** (top; replaces `_EquippedSummary`'s stacked layout):
- Left: the standing Traveler at **128dp** (64 native **x2**, up from x1/64dp) in `InsetWell.square(contentSize: 128)`.
- Right: three slot plates stacked, gap 8, each **56dp tall** across the remaining ~195 width — 48dp item icon, `microLabel` slot name, `itemName` in rarity ink, `micro` stat. An empty slot draws a muted silhouette well and the word "Empty"; never a lock glyph.
- Plates are a **readout**; Equip/Unequip stays on the pack tile. Tapping a plate scrolls to and selects that item's tile. `rhythmHero` below the case.

**Pack sections** (Materials / Equipment / Consumables / Quest; `sectionHeading`, `rhythmGroup` between):
- **Materials: 5 columns.** Width (361-24)/5 = **66**, gap 6. Tile = 48dp icon + `itemCount` "x3" only; the name is the Semantics label and appears in the detail block under the grid. Height floor 84, scaler-derived. Column rule: largest n in [5,4,3] whose column width >= 56, **and** drop 5 whenever `textScalerOf(context).scale(11) > 13` — a 66dp tile cannot hold enlarged type, so enlarged type gets 4 or 3 columns and its names back.
- **Equipment / Consumables: 3 columns.** Width (361-16)/3 = **114**, gap 8; tile keeps today's full content (two-line name, count, stat, Equip control), height floor 132, scaler-derived. 114dp is what the Equip control needs.
- Quest/Other: 3 columns, same as gear.

## 3. Character — portrait folio, dressing, steps ledger

- **Folio:** keep the 128dp bust (`portraitContent`; the reverted-figure decision stands) left; the right column gets name/level/skill-sum **plus** a three-chip dressing strip (weapon/armour/tool, 32dp icon + rarity name, 44dp hit region), so equipment reads universal here too. `rhythmHero` below.
- **Steps ledger** replaces the two `ValueTileRow` tiles: a ruled list — TODAY / THIS WEEK / TOTAL WALKED / TOTAL SKILL XP, one row each, label left in `microLabel`, tabular value right in `numericValue`, 1px `separator` between rows, 36dp row height. Teal stays reserved for walking figures.
- The Skills block collapses to the §4 spine list and defers to the Skills tab; the Combat block keeps its `_EquippedLine`s.

## 4. Skills — a handbook, not five posters

- One **spine** per skill, 64dp tall, hairline separated inside a *single* `SectionCard` (five cards become one): 32dp skill plate, name in skill hue at `cardTitle`, `LV n` right, and a **4dp progress rule flush to the spine's bottom edge**, full bleed, in `forSkill` ink.
- The three unlock lines move off the spine into `SkillDetailScreen` (already a push route). The spine answers "where am I"; the roadmap answers "what next". Tapping anywhere on the spine pushes detail, and the `ROADMAP` text hint is deleted — the whole spine is the control.
- Result: 5 skills in ~340dp instead of ~1000dp of near-identical cards.

## 5. Adventure — a field journal

- **Location hero:** keep `LocationStage` at 384x176, unchanged, at the top.
- **Expedition kit strip** replaces `activity_panel`'s nested lists: activities become journal entries, full width, **112dp tall** — node vignette at **96dp (96 native x1)** left, bottom-aligned by its measured bounds, then name at `cardTitle`, requirement/yield at `micro`, step cost right in teal. Entries separate with 1px `separator` rules inside one card, not eleven borders. A locked entry keeps full contrast on its reason line and dims only the vignette to 0.55.
- **Goals as pinned notes:** a 2-up row of note plates (176 wide, 88 tall), `boardSlip` role, each naming one tracked goal and its progress line; the empty state is one plate reading "Nothing pinned" beside the Goal Board plate. `Goal Board` and `Field Notes` stay as two secondary controls beneath.

## 6. Combat — the stage wins

Today: stage 192 + HUD ~56 + log/controls card ~276 = bottom-heavy.
- **2x2 command grid.** Cell (393-32-8)/2 = **176** wide x **56** tall, gap 8, so the grid is 120dp. Order: Attack (top-left, thumb-nearest), Brace (top-right), Eat (bottom-left), Item/Skip (bottom-right). Sub-labels collapse into one `micro` intent line above the grid.
- Budget: intent 16 + 8 + grid 120 + 8 + Retreat secondary 34 (44 hit) + card padding 24 = **210dp**, down from ~276. Every cell is 176x56, far above the 44 floor, and all four sit below y=600.
- Spend the ~66dp reclaimed on the stage first: keep the 192x96 native backdrop at x2 and let the HUD strip breathe, or (a PixelLab job) re-author backdrops at 192x112 native -> 384x224 on screen. Never exceed x2.
- `_CombatLog` drops to the single most recent line (20dp); tapping it reveals the rest.

## 7. Encounter card — the empty box

Replace the fixed `_EnemyStage.height = 152` with a **derived** height: `clamp(contentRows * 2 + 12, 76, 152)`, where `contentRows` comes from the same `idle.footprint` the ground offset already reads. Result: wolf **70** (from 152), crawler 78, salamander 104, bear 112, guardian 152. Scale stays x2, the roster's size ordering is preserved, nothing clips, and the common case loses 82dp of blank rectangle. Tint the band `forRegionDeep(place)` rather than flat `surfaceBlock` so it reads as habitat — still a strip, not a scene.

## 8. Bottom nav and header

**Nav** (`stride_tab_bar.dart`; height 64 and `withNoTextScaling` unchanged):
- The active tab gets a **plate**: 4dp inset from the bar's edges, `surfaceRaised` fill, `StrideRadius.tabActive`, plus a **2dp top rule** in `actionEdge`. That rule is the "you are here" mark; the fill alone is what currently reads as plain.
- Labels: active `tabLabelActive` at `textPrimary`; inactive `tabLabel` at `textSecondary`, not `textMuted` — six 9.5px labels need the contrast. Disabled tabs keep 0.28.

**Header** (`screen_header.dart`; `headerMinHeight` 61 stays a *minimum*):
- **Place first, tab name gone.** Title = the place name in `regionInk`. The eyebrow becomes the place's own descriptor ("SETTLEMENT - GRASSLAND"), not "CRAFT"/"WORLD" — the lit nav plate already says which tab this is, and saying it twice is the utility-app tell.
- Banked readout unchanged and always visible (0.62 cap, 72 min width, tabular, teal). Add a 1px bottom rule in `regionInk` at 24% beneath the wash so the header terminates without a second frame.
