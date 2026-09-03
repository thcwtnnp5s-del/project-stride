# EPO03 — PROD-UI-CRAFT ledger

Cap **112** generations. **Spent 15.** One row per job, recorded **at
submission** (§9a): a submitted job survives an interruption and is
retrievable by `get_image(job_id)`, so the id is what makes a generation
recoverable rather than repeated.

Family total is the sum of the cost lines below, never a balance delta (M-17).

Contact sheets, at ×4 on the chassis ground:
`GAME_BIBLE/ART/exploration/EPO03/review/craft/marks_r1.png`,
`marks_r2.png`. Every verdict below was given after reading the sheet.

## Round 1 — the family as `DIR-06` planned it (10 rolls)

| # | Asked for | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | `craft_cat_all` — open ledger book glyph, 24² | pixen | `e9353d7d-661e-43e3-8ea8-c7e5c478f28e` | 1 | **ACCEPT** | reads as a book at 48 dp; ships |
| 2 | `craft_cat_materials` — two ingot bars, 24² | pixen | `25cb0188-fc98-4dfc-8c86-a0e08b3fcf2f` | 1 | **ACCEPT** | unmistakable stack of bars |
| 3 | `craft_cat_food` — lidded pot, 24² | pixen | `2653e9f6-30ca-40a5-9775-c2769ad407be` | 1 | **ACCEPT** | the clearest of the five |
| 4 | `craft_cat_gear` — breastplate, 24² | pixen | `b231ee5b-c21c-439b-b3ff-37700acfb645` | 1 | **ACCEPT** | busy at 24 native, but reads as worn plate at 48 dp and beats the shield re-roll (#15) |
| 5 | `craft_cat_tools` — crossed hammer and chisel, 24² | pixen | `db8ee204-d99d-4a15-ba48-634957dfd43e` | 1 | **ACCEPT** | the crossed-tools read is instant |
| 6 | `craft_seal_smithing` — wax seal, anvil impression, 32² | pixen | `7bd76d7d-7f9c-4e60-a3db-4399451e1714` | 1 | REJECT | drawing is good; **the impression fights the numeral**. The seal is displayed at 64 dp with the required level set over it (L-18), and an anvil under a `2` makes both unreadable. |
| 7 | `craft_seal_cooking` — wax seal, pot impression, 32² | pixen | `be7d4e06-86e5-450e-aba5-e35bf91ea9b9` | 1 | REJECT | same defect as #6 |
| 8 | `craft_seal_woodcutting` — wax seal, axe impression, 32² | pixen | `49dad3bc-589f-43cf-8c1c-42d8c4bfd154` | 1 | REJECT | same defect as #6 |
| 9 | `craft_seal_taught` — wax seal, quill impression, 32² | pixen | `5e65e550-22de-419d-bbae-b6259e2e7d62` | 1 | REJECT | same defect as #6, and the wax came back cold grey rather than wax |
| 10 | `craft_stamp_made` — maker's mark impression, 48² | pixen | `ae6753fd-f3dc-4b45-9a65-8f4d19ee9ce7` | 1 | REJECT | drew a **stack of paper cards** with a mark on the top one, on a bright cream ground — an object, not an impression, and it would sit as a card over the output well |

**The lesson from #6–#9, which is a design finding and not a tool limit.**
Four per-trade seals were the brief's own plan and all four are good pictures.
They are still wrong: the chapter's tier header already says `SMITHING`, so a
per-trade impression states the trade twice and spends the seal's centre — the
one place the level numeral can go — doing it. One **blank** seal is both
cheaper and more legible, and it is what L-18 asks for anyway: the raster
carries no numeral, the type does.

## Round 2 — the correction (5 rolls)

| # | Asked for | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 11 | blank scalloped wax seal, smooth empty centre, 32² | pixen | `15507e4a-933a-4ac8-aa59-fc9dedecaaa1` | 1 | **ACCEPT** → `craft_seal_blank` | exactly the ask: scalloped rim, flat empty middle, warm wax. Ships as the seal for **every** trade and every level |
| 12 | empty wax annulus, hollow middle, 32² | pixen | `b5582335-0068-41bd-8f9e-3ab17fb81ea3` | 1 | REJECT | filled the "hollow" middle with a pale blue gem — a jewel, and a cold hue this palette does not hold |
| 13 | plain unmarked wax blob, 32² | pixen | `fd04363e-f0ff-4a2f-99f8-68d84061c738` | 1 | REJECT | drew the seal **on a square of paper**: a plate with a background, which the packaging guard rejects by name |
| 14 | worn circular ink stamp, hollow middle, 48² | pixen | `6f90584c-acb5-4846-a82d-125baff41d1f` | 1 | **ACCEPT** → `craft_stamp_made` | a broken ring of dry ink with an empty centre — an impression that presses **around** the output rather than over it |
| 15 | `craft_cat_gear` alternative — round shield, 24² | pixen | `12a6b65d-7d19-4dbb-97a8-8d94588b6ea3` | 1 | REJECT | clean, and less specific than the breastplate it was meant to replace: a round shield reads as one item, a breastplate reads as *worn gear* |

## Total

| | |
|---|---|
| Requested | **15** generations (cap 112) |
| Accepted | **7** assets — `craft_cat_all`, `craft_cat_materials`, `craft_cat_food`, `craft_cat_gear`, `craft_cat_tools`, `craft_seal_blank`, `craft_stamp_made` |
| Rejected | **8** rolls, each with the reason above |
| Not attempted | the dog-ear and the pursuit ribbon — their painted fallbacks read correctly at 393 dp (`v3_craft_book.png`, `v3_craft_overview.png`) and no roll was going to beat a 24 dp folded corner or a 24 × 40 swallowtail. `rail_plate_raised/recessed`, `tier_header`, `page_sealed`, `tray_well`, `stepper_plate`, `binding_gutter` were **not generated at all**: the shared kit already ships `slotWell`, `railShelf`, `pageSealed`, `ruleOrnateA` and `btnPlateV2`, and the brief's own §8 rule is to use them before generating anything of your own. That is roughly 60 planned rolls the kit paid for once. |

Every accepted asset is `--alpha`-snapped and carries a sidecar recording its
job id (`GAME_BIBLE/ART/exploration/EPO03/out/ui/*.json`). None is clamped to
the L\* ceiling and none should be: `check-art-palette.js` binds that ceiling
to `assets/ui/v1/frame|surface|ornament` only, and this family ships to
`assets/art/v1/ui/` — content art, like the item icons it sits beside. The
prep tool gained a `--content` flag that records the brightest ink as a
measurement rather than a violation; it stops applying a guard the product
does not apply to this path, and relaxes none that it does (G-4).
