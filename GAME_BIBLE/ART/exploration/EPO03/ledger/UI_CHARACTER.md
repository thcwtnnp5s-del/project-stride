# EPO03 — PROD-UI-CHARACTER ledger

**Cap: 50 generations. Spent: 0.**

## Jobs

| # | Asked for | Tool | Job id | Cost line | Verdict | Reason |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | **No job was submitted.** See below. |

**Family total: 0 generations.**

## Why nothing was generated

The brief said to read the kit before generating anything, and the kit already
held every mark this screen's design calls for. `KIT_CONTRACT` §8 has thirteen
landed rows; the folio needed six of them and one more as a declared fallback,
and none of them is a Character-specific asset:

| What the design asked for (`DIR-05`, Character row) | What it is drawn with | Landed? |
|---|---|---|
| the bust "in an inset window" | `KitFrame.insetWell` (61², band 15, inset **15 dp**) | yes, `5b92ef6` |
| "gear in margin wells" ×3 | `KitFrame.slotWell` (32², inset **8 dp**) | yes, `5b92ef6` |
| "name over an ornate rule" | `KitMark.ruleOrnateA` (192×16, drawn once, clipped) | yes, `3e1fa02` |
| "walking ledger as ruled vellum" | `KitTile.ruleJournal` (8×6 ×2, **12 dp** thick) between rows | yes, `5b92ef6` |
| the folio's page | `PageGround(surface: journalLeaf)` | ships |
| the folio's binding | `KitTile.edgeSpine` (**32 dp** wide) | yes, `80463ee` — **but see the defect below** |
| the Step Tracker "as a tab", Day / Week as index tabs | `KitFrame.tabPlate` (declared inset **6 dp**, fallback plate) | declared, empty — the fallback is finished work |
| the section openings | `KitRule(title:)` with `ruleCapLeft/Right` reserved | tile landed, caps reserved |

Every one of those returns its declared geometry whether or not its raster has
landed, so the screen is finished today and gains material without reflowing
(`KIT_CONTRACT` §0). A Character-only ornament would have been a fourteenth
name in a kit whose whole argument is that screens share their furniture.

The one thing the folio genuinely wants and does not have is the **bust
itself in more armour classes**, and that is `TravelerArt`'s table, owned by
PROD-EQUIPMENT, who shipped a fifth body this round. This screen calls
`TravelerArt.portraitFor(s.equipmentVisualState)` and narrows nothing: an
unresolved state falls through to the base portrait, which is the resolver's
own contract.

## Defect found and filed, not worked around blind

`KitTile.edgeSpine` is **vertical**, and `EdgeStrip` has no `axis` parameter
at all — `KitEdge` cannot pass one, so `PageGround(spine: true)` hands a
vertical strip an unbounded main axis and every test that mounts the app
collects `BoxConstraints forces an infinite width`. The request was already
filed by UI-INVENTORY and seconded by UI-ADVENTURE (`REQUESTS_NAV.md`,
2026-09-03). This team took Adventure's resolution rather than inventing a
third: `spine: false`, and the binding drawn at the **declared** 32 dp in the
kit's own fallback register (the page's darker ground, one `borderDefault`
rule at its inner edge). The swap back to `KitEdge` is one widget and reflows
nothing, because the width spent is the registry's figure either way.

## Renders read at phone scale

`GAME_BIBLE/ART/exploration/EPO03/review/device/character/`, 393 × 852 @ DPR 1:

| File | What it shows |
|---|---|
| `character_folio_tunic.png` | level 1, training sword and traveller tunic — bust in the window, three margin wells (tool empty, class shadow), the three worn lines, the name over the ornate rule, the vellum ledger, the ledger foot with the Step Tracker tab |
| `character_folio_plate.png` | a played save: bronze sword and bronze pickaxe in the wells with UNCOMMON ribbons, armour empty and showing its class shadow |
| `character_folio_foot.png` | the combat ledger, and the sound and playtest footnotes — no card on any of them |
| `character_playtest_confirm.png` | the destructive command's guard, unchanged |
| `character_step_tracker.png` | the tracker on the same folio: Day / Week as index tabs, ruled sections, the sync line |
