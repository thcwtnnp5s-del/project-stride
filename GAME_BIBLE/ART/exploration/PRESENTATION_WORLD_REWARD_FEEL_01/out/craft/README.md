# PWRF01 — craft activity loops and stations

The Traveler working at a craft, one loop per craft profession, plus the two
stations they work at. Same family, canvas and ground convention as the
gathering loops (`ACTIVITY_FEEL_01/README.md` §2): PixelLab
`animate_character` v3 on the canonical Traveler (`c82b7da5…`), west-facing,
cropped to a 64-row box with the feet on **row 62**.

## Accepted

| Ship id | Source | Frames kept | Crop |
|---|---|---|---|
| `activity_smith` | `smith4` | 2–8 (7) | x 6, w 74 |
| `activity_cook` | `cook` | 2–8 (7) | x 15, w 46 |
| `node/station_forge` | `station_forge_64x48` | — | padded to 64² |
| `node/station_cookfire` | `station_cookfire_64x48` | — | padded to 64² |

Both loops drop their leading reference frames, where the Traveler is empty
handed: a working loop that starts without its tool and pops one into frame
reads as a glitch, and the loop only ever plays while a craft is running.

## Generations (2026-08-21) — 8 total

| # | Job | What | Outcome |
|---|---|---|---|
| 1 | `57376f27` | `craft_smith_loop` — hammering at a workbench | **REJECTED.** Two frames suffer palette collapse (the figure bleaches to bone-grey); blind QA read the bleached frame as *"a ghost, a statue, or a different character"* and the held block as *"a tankard"* |
| 2 | `94cd55d9` | `craft_cook_loop` — stirring a pot | **ACCEPTED** (as `cook`). Blind QA in context: *"a man crouched over a cooking pot, stirring"*, label **Cooking**; the bowl enters the pot's mouth in five of seven frames |
| 3 | `e7c6153d` | forge/anvil station prop | **ACCEPTED** |
| 4 | `1eccc354` | cookfire station prop | **ACCEPTED** |
| 5 | `e07fa456` | `craft_smith_loop2` — colour-stable retry | **REJECTED.** Colour-clean, good arc, but the tool reads as a **pickaxe** — blind QA labelled it **Mining**, which collides with the gathering loop |
| 6 | `6e2d3581` | `craft_smith_loop3` — explicit blunt hammer | **REJECTED.** Right tool, but blind QA in context: *"a man standing with his back to a forge while a mallet hovers behind him"* — figure faces away, tool changes identity across frames, spark fires in empty air |
| 7 | `5a6a4fe4` | `craft_smith_loop4` — big arc, spark at the low point | **ACCEPTED** (as `smith4`). Blind QA: *"a blacksmith swinging a hammer down onto hot metal on an anvil"*, label **Smithing**; the only smith candidate with *contact and consequence* |
| 8 | `e7fa80d3` | `craft_cook_loop2` — shape-stable spoon retry | **REJECTED.** More stable than `cook` frame-to-frame, but blind QA read the implement as *"a pole planted in the ground"*, never entering the pot, and the loop as *functionally static* — **worse in context than the loop it was meant to replace** |

**Six accepted of eight, and the two rejections that matter were both my own
preferred candidate before review.** That is the process working: `cook2` was
generated to fix a fault the author saw in `cook`, and blind QA in context
picked `cook`.

## QA

Two blind rounds, M-13 staging (neutral scratchpad paths, non-ordinal names,
first-impression questions before any reveal), ×2 verdict scale (M-05).

**Round 1 — figure-only strips — FAIL.** Four candidates, all read without
their stations. Useful, and *insufficient*: the reviewer could not tell what
any tool was acting on, because nothing was in the frame to act on.

**Round 2 — in-context strips — the deciding round.** Composited exactly as
the app draws the stage (station on the same floor, figure at the layout's
own anchor). This is the round that found the placement defect below, and it
is the one whose verdicts shipped. `loop_h` (smith4) and `loop_w` (cook)
passed with minors; the other two took four blockers between them.

### The finding worth carrying

The first in-context composite put the station in `AmbientStage`'s **scenery
slot** — far-left and raised, which is correct for a gather node ("this
figure, at this place") and **wrong for a craft station** ("this figure,
working on this thing"). Composited that way the Traveler swung a hammer at
empty air with the anvil a screen away. Nothing in the widget tree was wrong;
no assertion about widgets could have seen it. The craft screen now places
the station itself, on the figure's own ground line and immediately in front
of him, using the same `AmbientStageLayout` the figure is placed by — and
`test/goldens/craft_stage.png` is the witness that they stay together.

### Minors on record (non-blocking)

- `smith4`: posture pops slightly on the 7→1 wrap; frame 1's grip is not
  legible at ×2; the spark lands a touch left of the billet.
- `cook`: the bowl leaves the pot in two of seven frames; the saturated red
  bowl supports a competing "glowing poker tip" read, resolved by the pot
  beside it; handle length varies beyond foreshortening.
- Both stations are drawn in ¾ isometric cool grey against a flat warm
  side-view figure, and read faintly as a separate plane. A future round
  should generate the props in true side view.
- Escalated, no opinion: whether all stage activity loops must share one
  canonical facing (all shipped loops face west, so nothing acts on this
  today).

**Packaging:** `Scripts/art/package-art.js` § PWRF01 craft loops →
`assets/art/v1/ambient/activity_{smith,cook}_f*.png` and
`assets/art/v1/node/station_{forge,cookfire}.png`. Footprints measured on
frame 0 into `SpriteFootprints`; wiring in `AmbientAssets`.
