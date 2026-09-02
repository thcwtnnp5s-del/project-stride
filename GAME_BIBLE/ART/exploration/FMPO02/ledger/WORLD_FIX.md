# FMPO02 — WORLD_FIX generation ledger (answering FINAL-04 / FINAL-12)

Balance at start: **8,173** generations (credits $0.00, Tier 3, resets
2026-10-01). Cap for this task: **160**. Balance at close: **8,013**.
**Spent: 160 — the cap exactly, and it bound.** Two authorised items were
never rolled; they are named at the bottom and in `ATLAS_REGION_LOG.md`.

## What each call cost

`create_map_object` is the expensive tool in this list. It is billed like an
inpaint rather than like a `pixen` still — the four calls below account for
**127 of the 160** on their own. Recorded here because nothing in the tool's
description says so, and it is what stopped items 7 and 10.

| job / object id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| `10666417` | `inpaint_image` | 140x150 | 20 | **ACCEPT** | NB3 north bridge — the razor at atlas x≈513 becomes a winding lead; column L1 81.0 → 59.7 |
| `26c21de5` | pixen | 64x48 | 1 | REJECT | castle: isometric diorama on an oval plate — FINAL-04 #3 again |
| `d3b8a638` | pixen | 64x48 | 1 | REJECT | castle: same, with a heavier plinth |
| `41925bb0` | pixen | 64x48 | 1 | REJECT | castle: rectangular ground tile with side wall |
| `b278de84` | pixen | 40x36 | 1 | REJECT | storm house on an extruded soil block |
| `3580f7c9` | pixen | 40x36 | 1 | REJECT | storm house, taller plinth |
| `11b89c41` | pixen | 40x36 | 1 | REJECT | storm house, isometric box |
| `eea60631` | pixen | 24x24 | 1 | **ACCEPT** | deer + fawn at map scale → `overlay_deer2` 16x16 |
| `4877f831` | pixen | 28x28 | 1 | REJECT | wolves on a hard isometric snow diamond |
| `ff746f33` | pixen | 24x24 | 1 | **ACCEPT** | snow ape at map scale → `overlay_yeti3` 16x17 |
| `e4206e85` | pixen | 16x16 | 1 | **ACCEPT** | ox wagon at map scale → `overlay_wagon` 14x13 |
| `2a692c50` | pixen | 32x32 | 1 | REJECT | motes: came back an opaque forest scene, `no_background` ignored |
| `c38334f3` | pixen | 28x28 | 1 | REJECT | wolves: unreadable grey blob (second failure — stop, ART-03 §7) |
| `eb98d92a` | pixen | 32x32 | 1 | REJECT | motes: six 8x5 orange insects, 3x the specified 2–3 px body |
| `368d16a2` | `create_map_object` | 64x48 | ~32 | REJECT | castle: flat and plinth-free, but two thin towers reading as rockets |
| `696b6047` | `create_map_object` | 40x36 | ~32 | **ACCEPT** | storm house — one dark roof, one lit window, no plate, no side wall |
| `99296d24` | `create_map_object` | 64x48 | ~32 | REJECT | castle: reads as three green potion bottles |
| `8ee310c5` | `create_map_object` | 64x48 | ~32 | **ACCEPT** | fairy castle — spires, lit windows, no plinth, 31x39 tight |

Accepted: 6. Rejected: 12. Rolls that shipped: **6 of 18**.

## Zero-generation work in the same pass

Everything below is deterministic (A-2 — no pixel invented, nothing averaged)
and cost nothing:

- **N1 + N2 + NB1 palette remap** (`tools/atlas-quantise.js`) — the answer to
  FINAL-04 #1 / FINAL-12 #9 without a re-roll. Saved the 40–80 generations a
  re-roll would have cost, which is the only reason items 3–6 fitted at all.
- **Sea-ice sage cleanup** (`package-art.js`, after the ocean conform) — 342 px.
- **Fairy-mote honey-green tone** (`tools/worldfix-prep.js`) — 1,121 px over
  4 frames.
- **Every crop, every placement move, every manifest and layout row.**

## Not rolled — the cap bound first

| item | what it needed | why it did not happen |
|---|---|---|
| GAP snowline (FINAL-04 #9) | one inpaint ≤25 gens over atlas 0–220 x 230–310 | cap reached. The deterministic alternative was tried and **failed**: widening N1's bottom ramp 32 → 56 moved row 270's score by 0.0, because the run is base-composite terrain below N1's authorization, not a join. It needs authored fraying. |
| S1 wood edge (FINAL-12 #10) | one inpaint ≤30 gens over atlas 60–200 x 850–990 | cap reached. Measured first: the west edge's longest straight column run is **10 px**, not a ruler; the north edge's longest row run is 31 px at y=893 and most of that band is inside the `south_strand_w` keepout (y ≤ 890) and unwritable without the owner's golden authorization. Lower priority than the review implies. |
| 4 creature loops | 4 `animate_image` calls, ~8 gens | cap reached. The three halved creatures ship as **1-frame static markers** — the fallback the brief authorised, and FINAL-04 #5's own second option ("declare them markers"). |
| 1 mote re-author | one pixen roll at 16x16 | cap reached after two failures. 16x16 is the diagnosis: at 32x32 the model draws an 8 px body whatever the prompt says. |

---

## Cap-raise pass (+120 for four named items)

Balance at open **8,013**, at close **8,009** — **spent 4 of the 120**. The
budget was not the constraint this time; transport and the goldens were.

| job / id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| `d41aef2d` | `animate_image` | 16x16 x5 | 1 | **ACCEPT** | `overlay_deer2` loop — doe's head lifts, fawn shifts |
| `5afb2ef9` | `animate_image` | 16x17 x5 | 1 | **ACCEPT** | `overlay_yeti3` loop — slow shoulder sway |
| `017b3d4a` | `animate_image` | 14x13 x5 | 1 | **ACCEPT** | `overlay_wagon` loop — oxen plod, wagon rocks |
| `801ecb92` | pixen | 16x16 | 1 | REJECT | motes at 16x16 came back as ONE fairy character with a face — the brief forbids figures |

### Item 1 — the grey-green rectangle: 0 generations, blocked on transport

Not a budget failure. `inpaint_image` needs the crop by URL; the standing
method (and NB3 earlier in this pass) publishes it as a one-file commit, and
this pass was instructed to make no commits. Inline base64 is 38,024
characters, which PixelLab's own note says MCP clients routinely truncate, and
four re-encodings could not shrink it (RGB+Sub 43.6k, RGB+Up 47.6k, RGB+None
37.6k, max deflate no change). The crop is cut and waiting at
`src/atlas/GAP_crop.png`; one line of permission to push it unblocks a ~20–25
generation roll. Before/after measurements are prepared and recorded in
`ATLAS_REGION_LOG.md`.

### Item 4 — S1 north edge: 0 generations, skipped by the brief's own rule

The writable band inside the defect is **10 px** (y 890–899) against the 20 px
floor the brief set, and even those rows carry only 0.04–0.42 authorization;
the first fully-writable row is y=913, fourteen rows below the defect. Measured
against `atlas-mask.js`'s own `protectFactor`, not estimated.

---

## Second cap-raise pass — item 1 rolled

Balance at open **8,009**, at close **7,989**. **Spent 20 of the 50 allowed**;
the re-roll was not needed.

| job / id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| `bb3ad9bf` | `inpaint_image` | 138x202 | 20 | **ACCEPT** | GAP — the grey-green slab becomes a drifted snowfield breaking into a ragged treeline; every straight run collapsed (35→5, 27→4, 19→4, 17→6) |

Transport was the blocker last pass and the coordinator cleared it: the crop
went up as `c79e197` and was verified byte-identical to the local file and to
the live atlas at origin (134,124) before the roll.

**Zero-generation work in the same item.** Roll 1 left a 7 x 28 grey rectangle
at atlas 239-246 x 227-255 where the conventional 32 px right ramp did not
reach full alpha over the old slab's last columns. That is mask coverage, not
generation, so it was fixed by a seven-point ramp sweep (8/12/16/20/24/28/32)
rather than by spending the re-roll: at 20 the surviving sliver falls 94% and
the worst straight run in columns 230-256 hits its minimum of 10.
