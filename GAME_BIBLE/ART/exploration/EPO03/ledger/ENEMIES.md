# ENEMIES ledger — EPO03 Wave 2 (`DIR-12`)

Cap **130**. Family total below is the sum of each job's own cost line, never a
balance delta (M-17). Candidate dumps `E/raw/enemies/`, accepted `E/out/enemies/`,
sheets and seated composites `E/review/enemies/`, device renders
`E/review/device/enemies/`.

**A first instance of this team was killed by the session-limit outage before
it wrote a ledger, and its fifteen paid rolls survived in `E/raw/enemies/`
(`fetch_r1.txt`, `fetch_r2.txt` name every job id).** Those rolls were
re-fetched, seated and judged here rather than re-commissioned — three of the
five shipped plates come from them, and the salamander ember reference is one
of them. They are counted in the family total.

## Habitat windows — ground plates (`create_image_pixen`, opaque)

| job id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| c1bf20ec-bff2-4be8-a0c0-b7fae53560b5 | pixen | 192×76 | 1 | REJECT | rocky: a large boulder mass at the left reads as a crouching creature; cobble wall, narrow floor |
| f9aa93ca-40b0-4ad7-833f-01a558bf5c5a | pixen | 192×76 | 1 | REJECT | rocky: rounded cobble wall over a thin flagstone strip — the "foot of a wall" defect this round exists to remove |
| **9adff355-5a0c-4e6a-a5c8-bb43efc6e4fc** | pixen | 192×76 | 1 | **ACCEPT** | rocky: a scree bank as midground, dark rock columns as the top band, a wide worked floor in the lower third. The goblin stands on a floor with the workings behind it → `habitat_rocky_ledge` |
| 6e035cff-b4a4-4156-8a86-4e9d7774a0cf | pixen | 192×76 | 1 | REJECT | rocky: masonry courses filling the upper two thirds; a wall, milder but the same |
| 779db11a-b985-4c33-adb6-51bc9034b16a | pixen | 192×76 | 1 | REJECT | rocky (this instance): near-black cobble edge to edge with a grey blob centre; no floor plane reads at all |
| 6e3f245d-9fc6-47b2-9f49-79585dbd3c17 | pixen | 192×76 | 1 | REJECT | cave: a lantern-carrying humanoid figure drawn at the left — no creatures on a plate |
| 74020355-eb1c-4615-a105-61da36778c93 | pixen | 192×76 | 1 | REJECT | cave: a lava lake with a glowing dome behind it; open fire, and the floor is molten rather than standable |
| **fb45a974-a46f-4bd9-9a40-861611dec484** | pixen | 192×76 | 1 | **ACCEPT** | cave: slate flagstone floor over the lower half, one thin ember fissure crossing it, basalt columns as the top band, no lantern and no flame → `habitat_cave_shadow`, **and this closes Q-23** |
| 0c3a295f-e98f-44da-9a5f-5abdc85a2abb | pixen | 192×76 | 1 | REJECT | cave (this instance): a tiled corridor in hard perspective with glowing grout everywhere; weaker than fb45a974 on the same intent |
| **28264a73-6d0e-4b12-9768-f9cf0face4b6** | pixen | 192×76 | 1 | **ACCEPT** | snow: rime conifers as the top band, wind-packed snow to the bottom row with grass tufts breaking it. The lynx stands *on* the drift, not on the gravel under it → `habitat_snowbank` |
| 3e50c882-28b9-4a4d-a4c8-5722ca169d2f | pixen | 192×76 | 1 | REJECT | snow: a flat grey sky band across the top — the horizon rule |
| 4cd401f1-3fd2-48d5-9f07-3a5b8cc3d9c2 | pixen | 192×76 | 1 | REJECT | snow: same sky band, more of it |
| fdf0c0f6-5f47-40f3-8295-cee194921a52 | pixen | 192×76 | 1 | REJECT | snow: a blue band below the drift reads as open water at the creature's feet |
| 59194ac9-dca5-4e21-b824-3ad5d69a259b | pixen | 192×76 | 1 | REJECT | snow (this instance): a smooth snow field in strong perspective with no midground; reads as a grey road |
| 8dd73ca3-ac84-4670-b180-372ec7dfbc13 | pixen | 192×96 | 1 | REJECT | chamber: bright radial roots, symmetric, and a pale trunk exactly where the boss stands |
| 77e2b988-e502-4b9e-b3b3-4c2373ce11d1 | pixen | 192×96 | 1 | REJECT | chamber: a stone golem figure drawn in the middle — no creatures |
| 58581399-0498-4276-a5bd-16987b571726 | pixen | 192×96 | 1 | REJECT (runner-up) | chamber: dark root arch, good enclosure, but the floor is a thin dark strip the Guardian's feet do not read against |
| 55826d07-21ff-482e-a50f-6566527c0b96 | pixen | 192×96 | 1 | REJECT | chamber (this instance): a warm loam floor and good fungus, but a heavy central trunk masks the Guardian's silhouette |
| 7e0b4ccf-c33d-4eb0-b529-32922a9164ff | pixen | 192×96 | 1 | REJECT (runner-up) | chamber, centre-clear re-roll A: a root tunnel receding to a dark opening; the boss reads, but there is no distinct floor under it |
| **321803af-0450-4236-b024-2ab441920fe1** | pixen | 192×96 | 1 | **ACCEPT** | chamber, centre-clear re-roll B: the same root tunnel with a bare earth floor across the lower third. The Guardian reads against the dark opening *and* stands on something → `habitat_hollow_chamber` |
| **ef987e69-a1d3-439c-8994-98167d4666c2** | `edit_image_pixen` | 192×96 | 1 | **ACCEPT** | the same chamber roused: deep shadow, every fungus turned to an amber rune glow, rune arcs on the roots → `habitat_hollow_chamber_awakened` |

**The centre-clear re-roll is the one lesson worth carrying.** Four independent
chamber rolls all put a vertical trunk dead centre — where the boss stands. The
fix was not a seed but a prompt that says the centre is empty and the roots are
at the edges (two rolls, both usable). "Two failed rolls on one intent means
change the intent" applies to *composition* as much as to subject.

`habitat_forest_floor` is **KEPT unchanged** — the one plate a creature already
stood on. `habitat_hollow_rootbed` is **retired**: no floor, no headroom, and
nothing references it any more.

## Foreground strips (`create_image_pixen`, `no_background`, 192×32)

Authored at 32 rows, not DIR-12's costed 28 and 20: PixelLab forces a square
canvas on any side under 32.

| job id | cost | verdict | reason |
|---|---|---|---|
| 279bc958-92e8-4c2c-ad0b-d9a3e5358747 | 1 | **ACCEPT** | forest: grass tufts, dry leaves, a fern and one root end, alpha bottom-anchored at row 31 → `habitat_fg_forest_floor` |
| 94223a01-a4ea-44a1-aab4-86b141bd2779 | 1 | **ACCEPT** | ledge: loose grey rock chips and a scree lip → `habitat_fg_rocky_ledge` |
| 28b13d78-d467-4888-838c-bb638a557aa2 | 1 | **ACCEPT** | cave: angular basalt shards with ember rimlight on their upper edges → `habitat_fg_cave_shadow` |
| 342fd0a2-1b52-4271-a981-289beec651b1 | 1 | **ACCEPT** | snow: a wind-carved drift lip with blown spray → `habitat_fg_snowbank` |
| 9ca72bf6-e114-4fdd-b32d-638ec0341ad7 | 1 | **ACCEPT** | hollow: pale root loops crossing low with one glowing fungus cluster → `habitat_fg_hollow_chamber`, shared by both bosses |
| a769e89a-3a11-40dd-ba76-fc31e5eedd95 | 1 | **ACCEPT** | cave canopy: a stalactite fringe, alpha top-anchored → `habitat_top_cave_shadow`, the one canopy in the family |

Six for six on the first roll. The instruction that did it, in every case, was
"only the bottom half of the canvas is drawn and the top half is empty" —
`dims.js` confirmed the alpha bounds before any of them was accepted, and every
one is anchored to the edge it is drawn against.

## Salamander — species identity (`edit_image` pro, reference mode)

| job id | tool | frames | cost | verdict | reason |
|---|---|---|---|---|---|
| 53df8642-5235-4ab5-adbf-a70509d3e1a3 | `edit_image_pixen` | 1 | 1 | **ACCEPT (reference)** | the first instance's ember pass on `salamander_idle_f0`: a molten stripe along spine and tail with ember spots. Not shipped as a frame — hosted at `E/src/enemies/salamander_ember_ref.png` and used as the **reference** so every frame of every track is restyled to one appearance |
| e90218dc-54c8-4883-aae2-dc58505de15d | `edit_image` (pro, reference) | 14 | ~20 | see below | idle ×7 + defeat ×7 |
| — | `edit_image` (pro, reference) | 15 | ~20 | see below | attack ×9 + hit ×6 |

**Why pro and not 29 pixen edits at cost 1.** The motion is accepted work: the
attack's cock-back on f4 and its landed blow on f5, the defeat's collapse, the
hit's flinch. Re-animating from an edited first frame (DIR-12's costed plan,
~10) replaces that motion with `animate_image`'s in-place-only output, which
FMPO02 already measured as too weak for a collapse (`crawler_defeat`, two
rolls, shipped as a partial). Editing frame by frame with pixen preserves the
motion but gives each frame its own independent recolour — the flicker trap.
Pro's reference mode is the only route that keeps the pose and guarantees one
appearance across the set, and it prices at **20 generations for fourteen
frames**, not per frame.

## Ram — the re-horn, at zero generations

FMPO02 packaged `ram2_idle` and wired it to nothing, leaving adoption to an
integrator on one stated condition: re-measure the boar↔ram silhouette IoU.
Measured (`tools/iou.js`, unaligned 56² alpha ≥ 8, the same computation
`item_icon_distinctness_test.dart` uses):

* `ram_idle_f0` ↔ `boar_idle_f0` — **0.702**
* `ram2_idle_f0` ↔ `boar_idle_f0` — **0.727**

The re-horn is fractionally *closer* to the boar by that number and clearly
further from it on the ×4 sheet (`review/enemies/ram_swap_x4.png`): the horn
gains internal ridging that reads as a curl where the shipped one is a dark
blob. M-04 is explicit that the sheet read is the verdict and the number is
triage, and the two animals differ by palette as well as shape — cream against
dark purple-brown. **Adopted**, idle only; the attack and defeat tracks keep the
original horn, which is a texture difference at the same silhouette. 0 generations.

## Family total

| Group | Generations |
|---|---|
| Ground plates (21 rolls, 6 accepted) | 21 |
| Foreground strips and canopy (6 rolls, 6 accepted) | 6 |
| Salamander reference edit | 1 |
| Salamander pro restyle, idle + defeat | 20 |
| Salamander pro restyle, attack + hit | 20 |
| Ram swap, bestiary vignette, dossier chrome, boss frame | 0 |
| **Total** | **68** of a **130** cap |

Nothing in the dossier's own chrome cost a generation: the tier stamp is the
kit's landed `ribbonLabel`, the entry rule is its landed `ruleOrnateA`, the
boss's heavy frame is its landed `stageFrame` and the common window is
`insetStage`'s honest fallback. The Bestiary's habitat vignettes redraw plates
and sprites the encounter card already ships. DIR-12 costed 71 planned plus a
15-roll buffer and a 40-generation Q-23 inpaint reserve; the reserve was never
needed, because the cave was fixed by re-authoring the floor rather than
repainting the wall.
