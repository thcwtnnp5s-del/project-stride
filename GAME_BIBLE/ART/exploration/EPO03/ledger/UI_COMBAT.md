# EPO03 — PROD-UI-COMBAT ledger

Cap **150**. Tranche 1 (UI marks) capped at 60; tranche 2 (the four backdrop
extensions) only if ≥ 80 remain when tranche 1 closes.

`DIR-11` commissioned nine marks. **Seven of them were already on disk**, and
finding that out cost nothing: the KIT_CONTRACT landed thirteen rows between
the brief being written and this team starting, and six of DIR-11's nine names
are the kit's names with a different label on them.

| DIR-11 asked for | What ships instead | Generations |
|---|---|---|
| `stage_frame` 48² nine-patch | `KitFrame.stageFrame` — landed, 114², 26 / 19 | 0 |
| `rail_plate` 32² nine-patch | `PageGround(leather)` + `KitTile.navWelt` — the nav strap's own stitch, one chassis | 0 |
| `gauge_well` 28² nine-patch | `CombatHudAssets.gaugeFrame` — the authored 96 × 16 gauge chassis already shipping, now set into the lintel | 0 |
| `chip_plate` 24² nine-patch | `_Chip`, dense — the FMPO02 verdict that a coin beside a numeral is the casino register (L-16/L-17) stands, and a plate behind TURN is the same mistake with square corners | 0 |
| `plate_attack/brace/eat` ×3 | `KitFrame.btnPlateV2` — a **real** nine-patch (56 × 24, 8 / 5), one raster, three inks from Flutter. **This is what closes Q-22.** | 0 |
| `icon_attack` (no ground) | the shipped file with its baked checker keyed out — see below | 0 |
| `icon_retreat` (new subject) | pixen, below | 3 |

---

## Rows

| # | Asked | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | `icon_attack` without its baked checker ground | `key-flat.js` (deterministic, no tool) | — | **0** | ACCEPT | The "checker" is one exact ink, `#0C0B0F`, on 91 of the 256 pixels, alternating with real transparency — a transparency checkerboard the original generator painted **opaque**. None of the sprite's own nine inks is within 1 of it, so keying it is lossless: 91 keyed, 82 kept, crossed swords intact. `DIR-11` budgeted 4 generations for a re-roll of this file; it cost none. Sheet: `review/combat/icon_attack_keyed_x8.png` |
| 2 | `icon_retreat` — an open gate with a road through it | `create_image_pixen` 16² | `1657f52b-6296-4592-8043-8820206df865` | 1 | see below | |
| 3 | `icon_retreat` — two posts and a lintel, road between | `create_image_pixen` 16² | `a059b653-b95e-4af8-9de7-2879cc88a8d7` | 1 | see below | |
| 4 | `icon_retreat` — one leaf swung open, track through | `create_image_pixen` 16² | `4ae2a5ba-97a1-4fba-b302-eddb675020f9` | 1 | see below | |

**Running total: 3 generations.**
