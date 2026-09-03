# EPO03 — PROD-UI-COMBAT ledger

Cap **150**. Tranche 1 (the nine UI marks) capped at 60; tranche 2 (the four
backdrop extensions) permitted only if ≥ 80 remained when tranche 1 closed.

**Spent: 3 of 150.** Tranche 1 came in at 3 against a budget of 48; tranche 2
was **declined on the evidence**, not on the budget — 147 were free for it.

## Why tranche 1 cost 3 and not 48

`DIR-11` commissioned nine marks. **Seven of them were already on disk**, and
finding that out cost nothing: `KIT_CONTRACT.md` §8 landed thirteen shared
rows between the brief being written and this team starting, and six of
DIR-11's nine names are the kit's names with a different label on them. The
Craft team reported the same thing on the same day. Read §8 before generating.

| DIR-11 asked for | What ships instead | Gens |
|---|---|---|
| `stage_frame` 48² nine-patch | `KitFrame.stageFrame` — landed, 114², corner 26 / band 19, drawn **over** the picture | 0 |
| `rail_plate` 32² nine-patch | `PageGround(leather)` + `KitTile.navWelt` — the nav strap's own saddle stitch, so the rail is the phone's furniture and not a fourth panel | 0 |
| `gauge_well` 28² nine-patch | `CombatHudAssets.gaugeFrame` — the 96 × 16 authored gauge chassis already shipping, now set into the lintel instead of hanging under a type band | 0 |
| `chip_plate` 24² nine-patch | `_Chip`, dense — FMPO02's verdict that a coin beside a numeral is the casino register (L-16 / L-17) stands, and a plate behind TURN is that mistake with square corners | 0 |
| `plate_attack` / `_brace` / `_eat`, 3 × 32² nine-patch | `KitFrame.btnPlateV2` — a **real** nine-patch (56 × 24, corner 8 / band 5, ×2), one raster, three inks from Flutter's fill. **This is what closes Q-22**, and since EPO03 it is also the raster `StrideButton` draws, so a command plate and a product button are one construction | 0 |
| `icon_attack` redrawn without its baked ground | the shipped file with the ground keyed out — row 1 below | 0 |
| `icon_retreat`, new subject | `create_image_pixen` — rows 2–4 below | 3 |

## Rows

| # | Asked | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | `icon_attack` without its baked checker ground | `E/tools/key-flat.js` (deterministic; no tool call) | — | **0** | **ACCEPT** | The "checker" is one exact ink, `#0C0B0F`, on 91 of the 256 pixels, alternating with real transparency — a transparency checkerboard the original generator painted **opaque**, which is why the file measured as art. None of the sprite's own nine inks is within 1 of it, so the key is lossless: 91 keyed, 82 kept, crossed swords untouched. DIR-11 budgeted 4 generations to re-roll this file. It cost none. Sheet `review/combat/icon_attack_keyed_x8.png` |
| 2 | `icon_retreat` — an open wooden gate in a stone wall, road through | `create_image_pixen` 16² | `1657f52b-6296-4592-8043-8820206df865` | 1 | **REJECT** | A good drawing of the wrong thing: the wall fills all 256 pixels, so it is a tiny picture rather than a mark, and it does not sit in the register `icon_brace` and `icon_eat` set (a subject on transparent ground). Its own baked checkerboard keys out cleanly in three inks — the recovery was tried, and it is the drawing that fails, not the file. `rejected/combat/` |
| 3 | `icon_retreat` — two posts under a lintel, a road between them | `create_image_pixen` 16² | `a059b653-b95e-4af8-9de7-2879cc88a8d7` | 1 | **ACCEPT** | Clean transparency, no baked ground, axis-aligned, symmetrical: two dark posts, a lintel, and a pale road widening out through the opening. It reads as a way out at 16 dp and it is a *mark*, which is what the other three combat glyphs are. `out/combat/icon_retreat.png`; sheet `review/combat/icon_retreat_accepted_x8.png` shows it beside brace, eat and the keyed attack |
| 4 | `icon_retreat` — one leaf swung open, track through | `create_image_pixen` 16² | `4ae2a5ba-97a1-4fba-b302-eddb675020f9` | 1 | **REJECT** | Off palette — moss green and lantern yellow, two hues combat does not own — and the shape reads as a lit shrine rather than a way out. `rejected/combat/` |

**Tranche 1 total: 3 generations** (1 accepted, 2 rejected with reasons, 1
recovered for free).

## Tranche 2 — declined, with the render as the reason

`DIR-11` tranche 2: inpaint the four 192 × 128 backdrops to 192 × 160 (+32
native rows of sky), making the picture 320 dp and shrinking the leather page
to about 143. Four `inpaint_image` calls at the 20 tier = **80 generations**,
and **147 were free**, so the budget gate opened.

**Not spent.** The device render is the argument
(`review/device/combat/page_wolf_turn.png`): the 256 dp picture already
carries roughly 100 dp of sky and canopy above the Traveler's head. Another
64 dp of sky trades empty leather *below* the fight for empty air *above* it
and sinks both figures lower in a taller frame — the picture gets bigger and
emptier, which is not what "make the battlefield visually dominant" asked
for. Tranche 2 was specified before the chassis existed, when the picture was
the entire fight surface and headroom was the guardian's problem; the chassis
answered the guardian's crown with a 64 dp lintel instead, and the render
confirms the crown is clear (`review/device/combat/chassis_guardian.png`).

If the picture is ever to grow, the rows want to be **ground**, not sky — a
different brief with a different mask, and a decision rather than a spend.
Recorded as `JOURNAL/OPEN_QUESTIONS.md` **Q-30**.

## Filed, not spent

- `REQUESTS_NAV.md`, 2026-09-03 — one `pubspec.yaml` row for
  `assets/ui/v1/combat/icon_retreat.png` plus its provenance line in
  `assets/ui/v1/README.md`. The `assets/ui/v1/` tree is declared file by file
  and NAV owns the manifest, so COMBAT cannot land the row itself. Until it
  does, Retreat ships as the micro link with no glyph — a finished state, not
  a hole.
