# World atlas — independent blind Visual QA, round 1 (2026-08-19)

Recorded verbatim by the lead from the Visual QA agent's report on `qa/blind/`
(14 files, opaque codes). The reviewer read no README, PACKAGING or key.

**Staging note (reviewer):** the task prompt itself named the categories
(forest, meadow, moor, mountain, snow, river, coast, fields, settlements; the
glyph nouns; "slab/diorama"; "joystick/coin"). Region and glyph names below
were primed; "absent" findings are absent-when-prompted. Discount
accordingly. No native (×1) world crop was provided.

## Per file

- **xo0** (meadow, road, palisade, tree cluster): a dead-straight pale
  vertical band (~15 px) of constant width runs from under the tree cluster
  to the bottom edge, with a darker hairline on its left; a second pale band
  hugs the left edge; neither connects to the winding road — reads as a ruled
  line / tile edge with trees parked on it. Faint horizontal value step
  (mottled above, flatter below). **PASS-WITH-NOTE.**
- **qk7** (hamlet, river, bridge): same straight band at x≈35–60; a small
  white house shape inside the hamlet pops as a white-filled marker finished
  differently from the brown huts; faint texture change y≈440–460 and in the
  bottom ~30 px. **PASS-WITH-NOTE.**
- **df3** (scree with orange/dark bushes above, moor with Y-branching streams
  below, standing-stone pillars and boulders on the boundary): **a hard
  horizontal line across the full width at y≈175; grey→brown with no
  transition; both streams stop dead at it.** The pillars/boulders read as
  things placed to hide a join. Two pictures butted together. **FAIL.**
- **gu1** (mine portal, rails, tailings, conifer column, snowfields right):
  the centre column reads as a vertical strip of stamped objects (the same
  pillar+ledge twice) standing where brown mountain meets white snow mountain;
  terrain does not continue across. **PASS-WITH-NOTE bordering FAIL.**
- **b2m** (moor: ruined round tower on a crag, tarns, bog, ring of standing
  stones, path, scree with conifers): no seam visible, tones consistent; the
  small dark three-tier objects at the tower foot and circle centre read as
  "a dark pot / cauldron / small chest". **PASS** (note on the dark objects).
- **vd4** (coast: headland with field boundaries, breakwater enclosing dots,
  shallows, sandbar, sea stacks, estuary channels, reed marsh): reed-marsh
  block top-left has a straight horizontal bottom edge (y≈88) and near-vertical
  right edge — a rectangle of different texture; dots inside the breakwater
  and the object at its end unidentifiable at ×2. **PASS-WITH-NOTE.**
- **hs9** (zoomed-out composite): four regions meeting in a cross at x≈195 /
  y≈350. Lower vertical: hard hue step olive-khaki → yellow-green with a hedge
  along it. Right horizontal: hard grey→brown line with boulders on it. Upper
  vertical: the conifer/pillar column. Left horizontal: a hedge row and a
  faint value step — **the river crosses it continuously; the one good join.**
  Four quadrants carry four palettes and four object densities; reads as four
  tiles, not one country. **FAIL as a continuous world; PASS for region
  legibility** (settlements, mine, river, fields, snow, moor all distinct).
- **n3r** (glyphs in context on grass / snow / moor): hut, leafy tree, pick
  (white head, dark haft), bare branched tree, dark three-tier stack. On grass
  all distinguishable; the stack reads "dark pile / beehive / cauldron" not
  stones. On snow the hut's white body and the pick's white head survive on
  outline only. On moor the dark stack on dark brown is the weakest pairing.
  No text, compass, figures. **PASS-WITH-NOTE.**
- **j8k / twp / zc5** (glyph strips ×1/×2/×8): five glyphs distinguishable
  from each other at ×2 on neutral ground; at ×8 the pick is stuck in a brown
  dirt pad with ore chunks — **a small ground slab under the glyph**, a dark
  bar at ×2; the stack is ambiguous at ×2; the dead tree could also read
  scarecrow/antlers. **PASS-WITH-NOTE.**
- **rl2 / am6 / e4y** (object cutouts): jetty with rowing boat on a small
  water patch (mild slab); ruined tower on crag (fine); **ring of standing
  stones on an oval green grass disc — a clear diorama slab**; stone arch
  bridge (fine); **mine portal on a flat green pad — slab**; reed tussock on
  pale sand (faint slab); tussock row, rubble line, hedge row (fine); two
  dark-blue tapering spires read "crystals/obelisks" alone, sea stacks in
  context; a vertical column of round bushes reads as a poplar / stacked
  hedge. **PASS-WITH-NOTE** (stone circle and mine pads are real slabs,
  Category A, MINOR-to-MAJOR depending on placement).

## Findings

| Sev | Cat | Finding |
|---|---|---|
| MAJOR | A/B | df3 / hs9 right horizontal: hard straight grey→brown line across the full width; both streams terminate on it. |
| MAJOR | A/B | hs9 lower vertical: hard hue step olive-khaki → yellow-green; the two lower quadrants read as different paintings. |
| MAJOR | B | hs9 overall: four quadrants with four palettes/densities; reads as tiles, not one world. |
| MINOR | A | gu1 / hs9 upper vertical: join hidden by a vertical column of props with the same pillar+ledge stamped twice. |
| MINOR | A | xo0 / qk7: dead-straight pale vertical band of constant width from the tree clump to the frame edge. |
| MINOR | A | vd4: reed-marsh block has a straight rectangular bottom edge. |
| MINOR | A | Cutouts: stone circle on an oval grass disc; mine portal on a flat green pad; pick glyph on its own dirt pad. |
| MINOR | B | Dark three-tier glyph reads as "pot / cauldron / small chest" at ×2; weakest on moor. |
| MINOR | B | Hut and pick glyphs lose their white fill on snow. |
| NOTE | C | qk7: white hut marker inside the hamlet finished differently from the village huts; pops as UI. |
| NOTE | B | vd4: dots inside the breakwater and the object at its end unidentifiable at ×2. |

**Per-item:** xo0 PASS-WITH-NOTE · qk7 PASS-WITH-NOTE · df3 FAIL · gu1
PASS-WITH-NOTE · b2m PASS · vd4 PASS-WITH-NOTE · hs9 FAIL (continuity) /
PASS (legibility) · n3r PASS-WITH-NOTE · j8k/twp/zc5 PASS-WITH-NOTE ·
rl2/am6/e4y PASS-WITH-NOTE.

**Overall — "the 2×2 world as composed": FAIL.** Region readability is good
and most single-tile viewports hold, but the composite shows a visible cross —
one hard ruled seam with rivers dying on it, one hard hue step, and one
prop-column mask — so a player would read four pictures, not one country.

**QA VERDICT: FAIL**

## Lead's disposition (2026-08-19)

One focused fix round commissioned (≤ 100 generations): palette-conform
and/or re-roll the south-east tile against measured neighbour edges; vary the
base↔east stamp column; break the straight band; re-roll the cairn glyph;
key the pick pad. Re-staged blind for a second verdict. **Fallback if the
south-east seam cannot be made to join: ship base + south only (768 × 2752),
withhold east and south-east.**

---

# Round 2 (2026-08-19) — verbatim from the second, independent blind reviewer on `qa/blind_r2/`

Staging note (reviewer): codes opaque; the directory path leaks "world"; the
task prompt listed the defect classes (checklist tilt — absent-when-prompted);
no whole-world overview staged (judged on crops; `wq4` the nearest).

- **ta7** (×2, east↔south-east join): smooth grey-green ground with outlined
  boulders above; coarse speckled scree below; **hard line** at mid-height,
  nothing continues; a standing rock on a bright green oval patch reads as a
  slab. **FAIL.**
- **ju3** (×2, south↔south-east join): warm saturated farmland left; pale
  washed-out flat field patches right; **hard line** — value, saturation and
  texture step at once; a light vertical strip with tree blobs on it reads as a
  decorated stitch. **FAIL.**
- **ae0** (×2, base↔east join at the mine): grey mountain / mine left; tan
  ridged rock with white streaks right; **hard line** — hue step, shading
  style change, streaks end at the seam; a rock pile on a small green pad at the
  join (slab). **FAIL.**
- **wq4** (×1 four-way cross): vertical seam a **hard line** full height;
  right horizontal **hard line**; left horizontal (base↔south) **faint-to-
  visible** — green slightly darker below, a hedge/tree row sits on the line
  and draws the eye; **the river on the left continues across** (credit); the
  thin stream bottom-right is orphaned. "Four maps from different games pasted
  into a grid." **FAIL.**
- **fz9** (×1, Haven's Rest / south): the hamlet, river and bridge read as one
  picture; lower half: a row of conifers plus a white-blossom tree across the
  width on one horizontal; a tan vertical strip up the left edge (a track or a
  tile edge — connects to nothing); two dark hedge bars on one horizontal.
  No colour/value seam. **PASS-WITH-NOTE** (grid/band cues; left strip).
- **km2** (×1, east moor): one continuous picture, no seam; tower and stone
  circle are clusters a player would try to tap. **PASS.**
- **no1** (×1, estuary): continuous; a stray partial outlined object cut at the
  right frame edge; lagoon strokes ambiguous. **PASS-WITH-NOTE.**
- Glyphs (`mr4/cd5/bk9/px6`): house · three rounded rocks · dark forked dead
  tree · round mottled disc with stem (tree at ×8, ring/wheel at ×2) · pale
  pickaxe. All five distinguishable on grass; house and pick weak-but-findable
  on snow; **dead tree near-invisible on dark moor**; dead tree vs pick share a
  forked-stick silhouette at native, separated by value only; no pads.
  **PASS-WITH-NOTE** (MAJOR if dark moor is a real placement).
- Cutouts (`sv2/yb8/hg7`): jetty-and-basin unidentifiable; rock pinnacle;
  standing stones; arched bridge; **boulder on a bright green oval slab — a
  visible slab, carried into `ta7`/`ae0`**; sand-pad tuft; strips; ice spires;
  poplar. **FAIL for the slab boulder, PASS-WITH-NOTE for the rest.**

Findings: BLOCKER B — joins read as hard lines ("four different maps in a
grid"); MAJOR A — boulder-on-slab cutout placed on non-green ground; MAJOR B —
dead-tree glyph on dark moor; MINOR — fz9 alignment cues / left strip; no1
partial object; dead tree vs pick silhouette; NOTE — table+basin, lagoon,
disc glyph; no overview staged.

**QA VERDICT (round 2): FAIL** — the tile joins present as hard hue / value /
texture lines, so the composed map reads as separate pictures butted
together rather than one continuous world.

## Lead's final disposition (2026-08-19)

Two independent blind passes failed the 2 × 2 composite on continuity, and
the second judged the fix round no better at the east and south-east joins.
**Shipped: base + south (384 × 1376 native, 768 × 2752 world px)** — the one
join both reviewers called faint / the good one (the river continues across
it). **Withheld: east and south-east tiles, the four landmark cutouts, the
crag / dune / sea-stack / reed / strip props** (packaged under `out/`, not in
`assets/`). Of the seam props only the base↔south copse and the south-tile
field props are placed; the straight treeline strip at (296, 684) is dropped
(strips read as ruled lines — E's own finding). Glyphs ship (the perilous
glyph sits inside a ring on a plate, which is not dark moor). Landmark names
on the shipped column — *Millbridge*, *Ferry Crossing*, *Far Town* (future
tier) — are the art stream's proposals, recorded UNRESOLVED in
`JOURNAL/OPEN_QUESTIONS.md` for the World Designer / owner. A third round, if
opened, should re-roll the **east** tile's western third from the base's
measured east edge (the east tile alone was the only unqualified PASS) before
touching the south-east again.
