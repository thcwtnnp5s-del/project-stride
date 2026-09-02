# DIR-05 — UI Creative Director: the page model (EPO03 Wave 1)

**A screen is a page of one material; content sits on the ground under rules, in wells, on slips — never in a card.** `SectionCard` leaves every tab root; `chassis_64` survives on modals only. Every screen wires the shipped-but-unused `header_shelf`, `nav_welt` and grain tiles; stages and the atlas bleed under the shelf.

## TOP FAILURES (phone-visible, ranked; → replacement)

1. **One rhythm, one weight, centred stacks, a button in every tile** — radius-14 rectangles at 34 call sites. → One ground per screen, square corners, content-driven rules, ledger entries (picture, name + one fact, numeral right); one primary plate per screen, quiet underlined actions.
2. **Locked = dim** — opacity 0.55 and "2 more at Smithing 2" rows. → A-2 pencil remap plus a margin note; sealed pages.
3. **Chips carry the meaning** — one grey pill for six meanings. → Index tabs, ribbons (level, rarity, boss), plain ink for counts.
4. **The stage is not the hero** — Combat's stage is ~23% of the screen; World's sheet buries the atlas. → Stage frame, one command rail, a peek strip.
5. **Four boot glyphs on Adventure.** → One, in the header.

## WHAT TO REPLACE (the page model)

| Screen | Ground | Dies → replaced by (*locked/empty*) | Authored thing |
|---|---|---|---|
| Adventure | `journalLeaf`, spine at left | cards → stage full-bleed; ruled walked/spent line; gather sites as ledger entries, cost on a ribbon; goals as pinned slips. *Locked: pencil + margin note.* | it is a book |
| Craft | `benchOak` | station cards, chips, recipe cards → shelf rail with plinth wells; a `journalLeaf` folio, index tabs on its edge; open row's output at 96dp over an `oilcloth` tray. *Recipe book: trade band + level ribbon per tier, sealed pages; never a "n more at" row.* | the folio on the bench |
| Skills overview | `buckram` | outer card → five chapter openings (band, title, rule, ruled XP line) | chapters |
| Skill detail | `buckram` | header card + stack → **vertical journey line**: road down a left rail, waystone per level with LV ribbon, illustrated unlock plates right, a lit lantern "you are here". *Ahead: pencil, unlit.* | the lantern on the road |
| Inventory | `leather` case, `oilcloth` pack | cards, tile buttons → figure in an inset window beside three slot wells; pockets ruled on canvas, items in wells, count ribbons; Equip only under the tapped item. *Empty well: class shadow.* | wells cut into leather |
| Character | `journalLeaf` folio | four cards → bust in an inset window, gear in margin wells, name over an ornate rule; walking ledger as ruled vellum | ruled ledger, no box |
| Combat | `steel` | card + stacked buttons → stage in a heavy frame (≥45% of height); one rail of four icon plates ≤56dp. *Disabled Eat: no plate.* | gauges hung from the frame's lower band |
| Encounter | `journalLeaf` | rows-in-cards → species plates: ground strip, name over an ornate rule, habitat ruled beneath, boss ribbon | field-guide plate |
| World | atlas to the nav, `chartVellum` strip | tall sheet → ≤72dp peek strip with a leather tab; selected = chart brackets + tinted strip; viewed = ring | the map is the page |
| Nav | `grain_leather` + `nav_welt` | void → a well per tab cut into the strap; active tab a raised bookmark plate breaking the bar's top edge | the plate rises |

## WHAT TO KEEP

Fonts and type roles; the colour ladder, `#7C6A4A` ceiling, reserved teal (`glyph_steps` only); all grain tiles and bands; `btn_plate`/`btn_compact`; combat `plate_*`, `hp_gauge_frame`, `narration_strip`; `PixelFrame`; nav glyphs; Skills overview grouping. State stays Flutter's (0029).

## PRODUCTION FAMILY

All `create_image_pixen`, key light upper-left, no text in any raster. Source px; wells, frames, plates are nine-patches cut *in*; rules, edges, rails tile.

| Asset | N | Rolls |
|---|---|---|
| `rule_journal/bench/chart` 96×8 (+caps), `rule_ornate` 192×16 ×2 | 5 | 30 |
| `ribbon_label` 96×24, `slip_pinned` 128×48, `tab_plate` 48×24, `page_sealed` 128×64 | 4 | 34 |
| `rail_shelf` 384×72, `rail_strap` 384×40 | 2 | 16 |
| `inset_well` 64², `slot_well` 48², `inset_stage` 96², `stage_frame` 128² | 4 | 40 |
| `edge_spine` 16×64, `edge_torn` 64×12, `case_strap` 64×16, `pocket_rule` 96×12 | 4 | 36 |
| `journey_road` 16×32, `journey_waystone` 24×32, `journey_lantern` 32², `journey_plate` 64² | 4 | 30 |
| `nav_well` 32², `nav_active_plate` 32² | 2 | 18 |
| `btn_plate_v2` 96×48, `btn_quiet_caps` 16×24 | 2 | 18 |
| `gauge_bracket` 48×16, `peek_tab` 48×12 | 2 | 12 |
| Per-screen: encounter strips 384×96 ×5 (recrop first), journey marks 24² ×12, nav glyphs 14² ×12 (if the plate alone fails) | 29 | 100 |

`stage_frame`/`inset_stage` frame pictures, not panels; if L-18 reads them as a third family, the owner's EPO03 authorisation is the amendment (GOV-01's ADR).

## PIXELLAB BUDGET

**Cap 480**: kit **260**, per-screen **100**, reserve **120**. Unit costs (GOV-04): `create_image_pixen` **1**/roll; `edit_image_pixen` **1**; `create_image_pro` (**40**) and `inpaint_image` (**20–40**) refused for chrome; `create_ui_asset` has no measured cost line — ledger its first job before a second.

## PHONE-SCALE SUCCESS CRITERIA

- **Every tab root:** zero rounded dark rectangles above the fold; chrome L\* unchanged; teal only on the steps glyph.
- **Adventure:** spine visible; entries share no box; locked entry reads pencil + note; one boot.
- **Craft:** stations in wells on a shelf; index tabs on the folio edge; sealed pages under a tier band; no "n more at" line.
- **Skill detail:** one continuous road LV1→last unlock; lantern at the current level; nothing rounded.
- **Inventory:** three wells beside the figure; empty well shows a shadow; no Equip until a tap; pockets ruled.
- **Character:** bust in a window, gear in wells; ledger ruled.
- **Combat:** stage ≥45% under the header; gauges hang from the frame; four commands in one row ≤56dp; disabled Eat has no plate.
- **Encounter:** creature on a ground strip under a titled rule; boss ribbon.
- **World:** map reaches the nav with the strip collapsed (≤72dp); selected = brackets, viewed = ring.
- **Nav:** active plate breaks the bar's top edge; wells legible.
