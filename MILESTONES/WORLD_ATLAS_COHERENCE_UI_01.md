# World Atlas Coherence UI 01

**Branch:** `playable-phase-2-multiregion` · **Start HEAD:** `559669e` ·
**State:** v2.23 · **Status:** built, awaiting the owner's physical-device
acceptance.

A presentation-only pass with two goals from the device review: make the shipped
1024² atlas read as **one coherent authored painting** (no visible generated
rectangles on the phone), and make the World tab **map-first**. No canvas growth,
no ring 3, no new regions, no new easter eggs. Nothing in health, economy, saves,
combat, audio or navigation semantics changed.

## 1 · The recurring seam failure, and the method change

Four consecutive world passes narrowed each generation seam to a deterministic
dither band and still shipped rectangles to the iPhone, because a straight dither
band at the layout's ×6 display scale is a straight line the eye reads as a pasted
tile. The lesson — **pixel-edge continuity is not geographic continuity** — is on
the record as `MISTAKES.md` **M-14**, and the corrective invariant as `RULES.md`
**A-3**: production atlas expansions are transition-authored across every
boundary; tile-local generation plus seam blending is triage, not evidence of
continuity.

The fix generalises what `corridor_edit`/`southjoin_edit` did once into the rule
for every join: **cross-boundary transition authoring**. For each seam a wide
crop of the shipped composite (real terrain from both sides) was cut and its
central strip repainted with `inpaint_image`, the crop's outer margins frozen so
it re-seats with no new edge and the terrain — coastline, ridge, road, biome —
is carried *through* the boundary. Twelve bridges cover the north (ice wall,
combs, master-top, corners, junction), the west (Worldspine, master-west),
the east (volcanic coast), the south (delta) and the SE corner. The open ocean's
several teal dialects are unified deterministically to one accepted swatch
(`ocean_unify.js`, A-2 palette remap). Full provenance, the twelve prompts/masks
and the spend:
`GAME_BIBLE/ART/exploration/WORLD_ATLAS_COHERENCE_UI_01/README.md`.

The bridges and the ocean conform run in `Scripts/art/package-art.js` after the
existing dither, so `atlas_base.png` is reproducible from tracked sources and
`--check` stays green. The regenerated atlas byte-matches the reviewed composite.

## 2 · World UI — map-first, translucent panel

The World screen was a non-overlapping `Column` (map a fixed top half, opaque
card beneath). It is now a `Stack`: the atlas fills the whole content area with
`Positioned.fill` and **continues behind** a translucent warm-brown "smoked
parchment" panel over the lower third. The panel is a responsive fraction
(`_panelFraction 0.34`, clamped 220–360), its top edge an `IgnorePointer` fade
so pans and pinches at the seam reach the atlas, its body a semi-transparent
dark fill (`0xF014120F`) that keeps text at full contrast — **no blur** (it would
mush the nearest-neighbour pixel art and cost a raster every frame). The
inspector renders `bare` (no `SectionCard`) so the translucency is real. A new
`bottomInset` on `AtlasViewport` centres the current and each arrived location in
the **visible** map area above the panel, so the you-are-here marker never opens
behind the glass; panning and clamping still use the full window. Default zoom is
unchanged (native ×2). The caption was tightened to one line.

Files: `lib/ui/screens/world/world_screen.dart`,
`lib/ui/screens/world/atlas/atlas_viewport.dart`,
`lib/ui/screens/world/atlas/atlas_selection_panel.dart`.

## 3 · Prevention

- `MISTAKES.md` **M-14** — the recurring seam failure and its prevention checklist.
- `RULES.md` **A-3** — transition-authored boundaries, indexed to M-12/M-14.
- `tools/seam_review.js` — a preflight safeguard that emits one iPhone-scale crop
  per boundary plus a contact sheet; human visual review remains the authority
  (no automated scoring). The documented iPhone-scale review procedure is in §4.

## 4 · iPhone acceptance checklist (owner)

Run `node GAME_BIBLE/ART/exploration/WORLD_ATLAS_COHERENCE_UI_01/tools/seam_review.js`
and view `out/review/seams/contact_sheet.png` at phone scale; then on the device:

1. No cell / no place on the map shows a straight generated rectangle.
2. No coastline changes drawing style where it crosses a former boundary.
3. Water colour/detail does not jump across a former boundary — the sea reads as
   one body.
4. Forest / mountain / snow density changes by geography, not by panel.
5. The atlas reads as one authored painting.
6. The map clearly dominates (~2/3 height); the panel is ~1/3.
7. The panel is readable with the atlas visible behind it (warm dark glass, not
   an opaque card).
8. Pan, pinch and place taps feel natural; the current location opens centred in
   the visible map area, not behind the panel.

## 5 · Verification

- `flutter analyze`: clean.
- App suite: **658** pass (world/atlas layout, camera-inset centring, bare panel,
  travel-under-scroll updated to the new structure — no assertion weakened).
- `package-art.js --check`: clean, **792** files reproducible from tracked sources.
- Goldens: only `phase1_world.png` and `phase1_world_large.png` changed,
  regenerated and reviewed (they show the map-first layout).
- Guards: source-safety, ui-boundary, dependency-policy, core-purity — all OK.
- Seam contact sheet: all sixteen boundaries read as continuous geography.
- PixelLab: 12 inpaint bridges, **335** generations, balance 815 → **480**
  (ceiling ~400, reset 2026-09-16); ocean conform deterministic.

## 6 · Deferred

- **Label density.** The device brief reports future-landmark labels reading as
  noisy. Judging which to move/fade/remove needs the rendered map with labels at
  phone scale (the owner's device view), not the source PNG; changing them blind
  risks removing a wanted name. Deferred to the device review with the owner's
  call on specific labels. No labels were added or removed this round.
- One cosmetic whitecap fleck near the south coast (reads as spray, not a seam).
- The 1px-border packaging guard (M-14 prevention) is recommended but not yet
  wired into `--check`; `seam_review.js` surfaces borders visually in the interim.
