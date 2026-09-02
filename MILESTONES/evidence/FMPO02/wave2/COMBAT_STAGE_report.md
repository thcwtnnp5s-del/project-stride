# COMBAT_STAGE report — FMPO02 Wave 2

Balance: start generations_remaining 9229 (used 771/10000) → end generations_remaining 8630
(used 1369/10000). That delta is the whole shared account across every concurrent PROD-* lead
this wave; this family's own tracked spend is ~130.3 of its 160 cap (100 backdrop + 30.3 HUD).
Full job-by-job ledger: `GAME_BIBLE/ART/exploration/FMPO02/ledger/COMBAT_STAGE.md`.

## Accepted — backdrops (`out/combat/backdrop_<biome>_128.png`, all exactly 192x128)

forest, hollow, frostmere accepted on the first inpaint. **mine used its one re-roll**: the first
pass drew an exterior sunburst medallion and open barn rafters above the doorway (wrong — it is an
enclosed mine), the re-roll (seed 7712) produced a continuing rock ceiling arch with a timber
cross-beam and one hanging lantern. All four seams (mask row 0-39 over original rows 32-127) are
invisible at the row-32 join and the new top 40 rows read as atmosphere, not competing detail.

**Integrator facts**: ground row moves from 88 to **120** in all four (128 - 8, unchanged offset
from canvas bottom). Columns 58/138 (traveler/enemy) and canvas width 192 are unchanged — only
vertical canvas grew, per the brief's own instruction. `combat_assets.dart` and `package-art.js`
were **not** touched, per instruction; the integrator still has to wire the new files and ground row.

## Accepted — HUD (`out/combat/ui/`, `pixen`, 1 gen/candidate, 3 candidates/item)

| File | Canvas | Material | Nine-patch |
|---|---|---|---|
| `hp_gauge_frame.png` | 96x16 | chassis leather ramp | corner 6 / band 3 — see `.json`: visible pill content is only rows 4-11 (8px) of the 16px canvas; **the Flutter fill must inset into rows 5-10, not the full height** |
| `turn_marker.png` | 24x24 | chassis leather ramp | fixed, not stretched |
| `narration_strip.png` | 64x16 | parchment (candidate `narr_b`) | tiles at a 14px rhythm by design (torn-segment look), not sub-pixel seamless |
| `plate_attack.png` | 64x32 | oxblood_danger (ART-13 §2) | corner 10 / band 12 |
| `plate_brace.png` | 64x32 | bluesteel_brace (ART-13 §2) | corner 10 / band 12 — **not** reduce_colors-snapped (inline-base64 truncated twice; accepted after a manual palette check found no violations) |
| `plate_eat.png` | 64x32 | wood_eat (ART-13 §2) | corner 10 / band 12 |
| `icon_attack.png`, `icon_brace.png`, `icon_eat.png` | 16x16 each | glyph, unforced palette (ART-13 §5) | n/a |

`hp_gauge_frame`, `narration_strip` needed a compose step: PixelLab's `pixen` tool refuses a
non-square canvas when either side is under 32px, so both were built from a 16x16 candidate plus
two new deterministic crop-only tools, `tools/flipx.js` (mirror) and `tools/hstitch.js` (horizontal
concat/tile) — same "invents nothing" discipline as the existing `crop.js`/`pad-top.js`.

**Dropped**: `icon_retreat` — 3 initial candidates plus one re-roll (4 of the HUD budget) never
produced a readable footprint glyph (static noise, unclear blobs, one with a stray magenta pixel —
palette violation). Per the two-strikes rule it ships with no icon, which matches ART-09 §5 anyway:
Retreat was already specified as a plain text link, no plate, no icon.

## Discrepancies vs `ART-09_combat_brief.md` §3 — flagged, not resolved

This session's direct task instructions gave different sizes than the brief; I followed the direct
instructions and am flagging the mismatch for the owner/integrator to reconcile:
- `hp_gauge_frame`: brief says 96x16 corner **8/band 4**; built to corner **6/band 3** per this task.
- `turn_marker`: brief says a 32x16 **bar**, corner 6/band 3; built as a 24x24 **tab** per this task.
- `narration_strip`: brief says 96x20, corner 6/band 4; built as 64x16 tile per this task.
- Command plates: brief says 64x64 native, corner 14/band 6; built at 64x32 per this task.

UNRESOLVED: which spec is authoritative for engine wiring — record in `JOURNAL/OPEN_QUESTIONS.md`
if the owner hasn't already reconciled ART-09 §3 against this wave's dispatch instructions.
