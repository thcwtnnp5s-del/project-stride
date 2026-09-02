# GATHER family — FMPO02 Wave 2 report

Brief: `MILESTONES/evidence/FMPO02/wave1/ART-06_gather_brief.md`. Scope: re-author
3 subject plates and 4 backdrops named in that brief's "Re-author list". Cap
220 generations; this family's own tracked spend was **180** (see
`GAME_BIBLE/ART/exploration/FMPO02/ledger/GATHER.md` for every job).

Balance: **9,459 → 8,565** remaining (541 → 1,434 used) per `get_balance` at
open and close. The account-wide delta (893) exceeds this family's own spend
(180) because other FMPO02 wave-2 leads share the same PixelLab balance
concurrently (BRIEF_CONTEXT.md: 2,000–3,000 gens across ten families this
workstream) — tracked spend, not the balance delta, is this family's number.

## Accepted → `out/gather/` → shipped path

| File in `out/gather/` | Ships to | Canvas | Notes |
|---|---|---|---|
| `bg_stonefall_mining.png` | `assets/art/v1/work/bg_stonefall_mining.png` | 384×176 opaque | fractured natural rock above working height, timber/rail/lantern/cart kept, floor luminance 84–86 |
| `bg_stonefall_lift.png` | `assets/art/v1/work/bg_stonefall_lift.png` | 384×176 opaque | fractured rock with a shallow bowl recess ≈ native columns 87–207, headframe/cage/drum kept |
| `bg_stonefall_gallery.png` | `assets/art/v1/work/bg_stonefall_gallery.png` | 384×176 opaque | fractured rock, 3 depth planes read distinct, floor luminance 67–75 (was near-black) |
| `bg_hollow_foraging.png` | `assets/art/v1/work/bg_hollow_foraging.png` | 384×176 opaque | open mossy vale floor, natural root framing L/R, no tunnel-mouth; floor band (rows150–176, cols122–230) luminance 57.4 |
| `prop_meadow_bed.png` | `assets/art/v1/work/prop_meadow_bed.png` | 48×48 transparent | grass+cream-umbel clump on an irregular green turf patch, no basket |
| `prop_rime_cushion.png` | `assets/art/v1/work/prop_rime_cushion.png` | 48×48 transparent | wiry blue-stemmed flowers growing from a scatter of broken rock, no dome/plinth |
| `prop_hollow_root.png` | `assets/art/v1/work/prop_hollow_root.png` | 48×48 transparent | bone-pale root fan breaking from a dark peat smudge, no diamond base |

Composited review renders (backdrop ×1 + accepted/kept-shipped subject ×2 +
shipped Traveler frame ×2, built with the new
`GAME_BIBLE/ART/exploration/FMPO02/tools/gather-composite.js`) are in
`GAME_BIBLE/ART/exploration/FMPO02/review/gather/after/` — one per affected
node (`copper_seam`, `old_workings`, `gallery_tin_lode` use the **kept**
shipped ore-face subjects; `hollow_thicket`, `meadow_patch`,
`rimefrost_hollow` use the new subjects above). All six read as an
improvement over `review/gather/before/` (same tool, unmodified inputs).

## Rejected, and why (full detail in the ledger)

- **Stonefall family, ~30 cheap-tier (`pixen`/`pixflux`, 1 gen) attempts
  across 3 rounds**: every one defaulted to either dressed/coursed masonry
  (brick, cobblestone, honeycomb) or a symmetric black doorway/arch/forge-pit
  where a shallow ore recess was asked for, regardless of explicit negative
  prompting ("not bricks", "not a doorway"). img2img on the shipped file at
  two strengths (150, 60) barely moved the wall material at all. This is
  recorded, not chased further at the cheap tier (`PRODUCTION_RULES.md`
  "a batch that fails twice is recorded and left").
- **`create_image_pro` (40 gens each, 1 candidate per backdrop, style-anchored
  to the shipped file's palette)** broke the pattern on the first try for all
  three — genuine fractured rock, correct props, no doorway. Only **one**
  pro-tier candidate per backdrop was generated (not three) once the cheap
  tier had burned ~2/3 of a reasonable per-backdrop budget; see UNRESOLVED.
- **`prop_rime_cushion`, 3 rounds (10 candidates)** kept rendering as a round
  crystal/gem ball or a mossy boulder dome — never the requested "crevice"
  framing — until the prompt abandoned "mound/cushion" language for
  "wiry stems + flowers growing from a gap between rock chunks" (round 4,
  matching the construction language that worked for `prop_meadow_bed`).
- **`prop_meadow_bed`/`prop_hollow_root`, round 1**: every candidate had a
  distinct isometric ground tile or soil-ring plinth — the exact defect being
  fixed. Switching `view` from unset to `side` and stating "the foliage/peat
  IS the bottom edge, no isometric tile" resolved it for both.
- One `edit_image_pixen` call (surgical brightness fix on a cropped centre
  strip of an earlier `bg_hollow_foraging` candidate) errored on image decode
  — inline base64 truncated in transit — before any generation ran; cost
  nothing. The fix that worked was a fresh full-scene re-roll with explicit
  centre-band brightness language.

## Integrator action

No Dart or `package-art.js` changes made (per instruction). To ship:
`cp GAME_BIBLE/ART/exploration/FMPO02/out/gather/<file> assets/art/v1/work/<file>`
for all 7 files above (same names, same canvases — drop-in replacement, no
resolver/table changes needed since these are existing keyed filenames).

## UNRESOLVED

1. Only **one** `create_image_pro` candidate was generated per Stonefall
   backdrop (cost 40 gens each), not three, because ~60 cheap-tier attempts
   had already been spent diagnosing the doorway/masonry failure mode first.
   All three passed on the first pro-tier try, so no second/third candidate
   exists to compare against. If the owner wants true 3-candidate coverage at
   the tier that actually works, that's 2 more pro calls per backdrop (~240
   gens) — a separate follow-on spend decision, not made here.
2. `bg_stonefall_lift`'s recess sits at native columns ≈87–207, short of the
   122–230 target band by about 35px on the right side; visually the whole
   wall is uniform natural rock so the subject still reads as sitting into
   rock, but it is not exactly centred on the keep-clear band as specified.
3. `prop_rime_cushion`'s accepted plate is a rock-and-flower cluster rather
   than the brief's literal "tight cushion mound growing from a crack that
   cuts into the frame edge" — the model would not produce that specific
   crevice-in-edge framing without collapsing to a sphere. The accepted
   version satisfies "grows from broken rock, not a potted disc" but is a
   deliberate compromise on the exact construction clause; flagging for
   owner sign-off rather than deciding it silently.
