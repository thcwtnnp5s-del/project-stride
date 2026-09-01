# World life round 01 — record

```
STATUS: ACCEPTED · 21 files, 5 assets shipped · 11 generations spent
Date: 2026-09-01 · Authority: owner ruling, DECISIONS/0030
Direction: WORLD_LIFE_DIRECTION_01.md
```

## What shipped

| Asset | Channel | Native | Motion |
|---|---|---|---|
| `overlay_redwyrm` | overlay | 72 × 32, 9f | travel (+30, −13), 61 s gap |
| `overlay_stormdrake` | overlay | 72 × 32, 9f | travel (−30, +9), 67 s gap |
| `prop_rimespire` | **prop** | 48 × 72 | static |
| `prop_lanterngard` | **prop** | 72 × 56 | static |
| `prop_black_gable` | **prop** | 56 × 52 | static |

## The channel choice is a performance decision

A landmark **body** is a static prop: no ticker, no `Opacity`, and it does not
consume one of the ~40 overlay slots. Only motion costs a slot. So the dragons
are overlays and the buildings are props, and the `props` channel — which has
shipped with a full parser, layer and test path and an empty array since the
atlas landed — finally carries something.

Both dragons are **periodic**, never continuous. 19 of the 30 shipped overlays
are continuous and all 19 sit inside the busy central band, so the in-frame
count is already the binding figure; this round adds **zero** continuous
overlays. Final state: **32 overlays, 19 continuous, 3 props.**

Their intervals — 61 s and 67 s — share no small factor with each other or with
the shipped set, so the two dragons drift apart instead of locking into a beat.

## Originality, stated as design rather than asserted

The owner's references were mood shorthand. Each design records what it
deliberately is **not**:

- **Rimespire** — a Nordic stave tower that rime ice has grown over in heavy
  lobes, on a snow drift. *Not* a crystal palace, not a snowflake plan, not a
  spiral crystal stair, no ice-blue-and-magenta palette, no figure.
- **Lanterngard** — a ring of standing stones colonised by a trained
  blackthorn, low bark-and-thatch roofs slung between them, amber lanterns in
  the branches. Wide, low and horizontal, deliberately the opposite of a
  turret cluster. *Not* conical turrets, not a castle on a crag, no pastels,
  no winged figures, no glitter.
- **The Black Gable** — one tarred-board croft on a bare rock knoll with a
  steep gable, a cold crooked chimney, a broken drystone wall and three
  wind-bent thorns. *Not* a mansard tower, not a Victorian cupola, no skulls,
  no ghosts.

**And nothing here uses the teal-green family at all**, because L-16 reserves
it for walking — the palette guard measures that across all 924 shipped PNGs
and is green.

## The finding worth not re-learning

**The phrase "world map" makes the model paint map terrain.** Round 1 of both
dragons came back with tan and green landmass blobs baked into the transparent
background — the model read "world map creature" as an instruction to draw a
world map. Replacing the noun phrase with *"pixel art game sprite, isolated
creature only"* and banning `no landscape, no terrain, no islands, no map, no
ground, no clouds, no background of any kind` fixed both in one roll.

The Rimespire needed the same kind of correction for a different reason: "stave
tower … ice accretion" produced an iced **conifer**. Naming the structure
("a tall narrow wooden watchtower of dark upright spruce planks … clearly
readable as a built tower with straight walls and a doorway at its foot") and
banning `no tree, no branches, no foliage, no conifer` fixed it.

Rejected rolls are in `rejected/world/` with their round suffix.

## Verification

- 924 PNGs through the palette guard: no teal, zero semi-transparent pixels.
- `package-art.js --check` green at 903 files; the layout's declared frame
  counts and sizes are checked by `atlas_layout_test`, which passes.
- 982 tests pass, `flutter analyze` clean.
- Protected geography untouched: these are **drawn over** the base atlas, not
  composed into it, so `RULES.md` A-4's protected interior and the 15
  byte-enforced landmark goldens are not reached at all. The three prop
  placements were still checked clear of the golden rects and of the five
  settlement markers.

## Not done in this round

Fire breath and lightning breath (the dragons fly but do not breathe); fairies
as motes at Lanterngard; the storm-flash overlay at the Black Gable; wolves,
deer, yeti and caravans; and the atlas **seam** corrections, which are a
repaint round and a different kind of work from placing life on top.
