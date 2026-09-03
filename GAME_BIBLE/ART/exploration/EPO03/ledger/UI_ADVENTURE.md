# EPO03 — PROD-UI-ADVENTURE ledger

Team `adventure`. Cap **60 generations**. **Requested 0, accepted 0, rejected 0.
Family total: 0 generations.**

## The zero, argued

There is no row below because no job was submitted, and that is the deliverable
rather than an omission. `PRODUCTION_RULES.md` §2a ends with the instruction
this round has now proved twice — **build the Dart structure first, because
every screen's page model is mostly layout on materials that already ship** —
and the World team spent 0 of 60 on the same reasoning one commit earlier.

Adventure is the screen that argument fits best, because everything `DIR-05`
asks of it is a *shape*, and the kit contract has already landed the material
for every one of those shapes:

| What the brief asks Adventure for | What it costs | Where it came from |
|---|---|---|
| the page is a leaf of a field journal | 0 | `PanelSurface.journalLeaf`, shipped since FMPO02 |
| the leaf is bound — a spine at the left | 0 | `KitTile.edgeSpine`, landed `80463ee` (§8) |
| ruled lines, and a heading on a rule | 0 | `KitTile.ruleJournal` landed `5b92ef6`; `KitRule` is the kit's widget |
| gather sites as ledger entries with the cost in a margin | 0 | Flutter layout on the node plates the pack already ships |
| locked sites as pencil sketches with a margin note | 0 | a deterministic colour matrix — `RULES.md` A-2's tone remap, the recovery §2a names |
| goals as pinned slips on cork | 0 | `PanelSurface.cork` shipped; `KitFrame.slipPinned` declared, painting its fallback |
| the sync control as a stamped plate | 0 | `KitFrame.btnPlateV2`, landed `80463ee` |
| the moment a granting sync makes, crowned | 0 | `KitMark.ruleOrnateA`, landed `3e1fa02` |
| the stage tipped into the page | 0 | `KitTile.ruleJournal` again, run across the picture's foot |

Nine of nine. **The one thing on this screen that would have wanted a
generation is the pencil**, and it did not: a locked site's sketch is the same
node plate the unlocked one draws, put through a luminance matrix that
flattens it to graphite and lifts it off black. That is the tone remap A-2
permits and this repo has precedent for at `49c91f9`; it is exact, it is free,
and — read on the device at 393 dp — it is a better answer than a new asset
would have been, because a *pencilled* version of the same drawing is what a
field journal actually contains, and a separately authored "locked" plate
would have been a second drawing of the same place.

## Rejections

None to record: nothing was rolled. The verdicts that matter this round were
made against the **device render**, not against candidates, and they are in the
report.

## Assets shipped

None. No file under `assets/` was added, changed or removed by this team, so
`package-art.js` was never run, the build lock was never taken, and the block
`Scripts/art/package-art.js` reserves for a family was never opened.

## Checkpoint

The producer takes balance checkpoints (M-17). This team called `get_balance`
zero times and reports no balance figure.
