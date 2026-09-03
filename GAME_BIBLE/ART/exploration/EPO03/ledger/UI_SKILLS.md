# EPO03 — PROD-UI-SKILLS ledger (`assets/art/v1/track/`)

Cap **100 generations**. One row per job, with the tool's own cost line and a
verdict read at phone scale. Never a balance delta (M-17).

Family: the Skills journey — the road, its four joints, the folds, the badge
plates, the caps, the gate seal, the gauge frame and the five hero emblems
(`DIR-07` production table). The journey family was struck from the shared kit
(`KIT_CONTRACT` §8), so nothing here is NAV's.

## Structure first

The Dart half of `DIR-07` — `journey_model.dart`, `track_art.dart`, the rebuilt
`skill_detail_screen.dart` — shipped at **0 generations**, on the accepted
grains and painted marks alone. Every row below is material laid into a screen
that already lays out at its final geometry, and every row that never lands
leaves that geometry untouched.

## The rolls

| # | Asked for | Tool | Job id | Cost line | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | road tile, top-down dirt track, tiles vertically (32²) | pixen | `2c2607ad-c9bc-42fb-9f31-d64426d483db` | ~1 generation | REJECT | came back as **wood planks** — a vertical fence, not packed earth; bright mid-brown, and two hard border columns that would read as a ladder down the gutter |
| 2 | joint reached — squat notched waystone (24²) | pixen | `c17f290d-2222-45a4-b67c-617af2b4717a` | ~1 generation | ACCEPT (remapped) | a low flat-topped slab on a rubble base; the squattest silhouette of the four. Tone-remapped ×0.55 in linear light so the stone behind the walker sits under the stone ahead of them |
| 3 | joint here — cairn with a lit lantern (24²) | pixen | `f2f44d6f-c02f-4f15-a6f1-08cb9ae68c04` | ~1 generation | ACCEPT | the only lit shape and the only stacked one; reads as "here" in greyscale by height and by the lantern's mass alone |
| 4 | joint next — standing stone, bronze band (24²) | pixen | `443f0fe0-f5b7-49b8-9a51-30c598c2d3ab` | ~1 generation | ACCEPT | upright, unlit, one bronze band; the tallest single stone. No lock, no coin (L-16/17) |
| 5 | joint far — thin wooden stake (24²) | pixen | `81753292-4ad5-433a-af5a-857d65829505` | ~1 generation | REJECT | drew a twisted **tree stump on its own patch of soil** — a ground plate none of the other three have, so the four would not have shared a baseline |
| 6 | road tile re-roll — bare earth, no wood | pixen | `3c09d3dd-8da3-43e7-bdd9-44e4897166fc` | ~1 generation | REJECT | a two-colour orange / blue-grey **checkerboard dither** at 1:1 — static, not a track. Tiles seamlessly and is still wrong: `road_tile_proof.png` shows what five repeats of it look like. Ceiling-clamped first (5 colours moved) to be sure brightness was not the complaint; it was not |
| 7 | joint far re-roll — bare grey post, no ground | pixen | `671120bd-0108-422b-823d-e9c2bdf1c66c` | ~1 generation | ACCEPT (remapped) | a plain post, no soil plate. Came back near-white, which would have made the *furthest* joint the brightest thing on the road — remapped ×0.18 in linear light (A-2, precedent 49c91f9) so it recedes |
| 8 | emblem mining — pickaxe over ore rock (64²) | pixen | `61a0f16a-6f45-4a5d-9297-679e72ba96ce` | ~1 generation | ACCEPT | first roll; reads at 64 dp in the gauge's well |
| 9 | emblem foraging — herb bundle and mushroom (64²) | pixen | `930bb12c-026a-4161-aecb-868a660547b9` | ~1 generation | ACCEPT | first roll |
| 10 | emblem smithing — hammer on anvil (64²) | pixen | `d5b4d333-e4b6-4734-9709-09ac812b57fc` | ~1 generation | REJECT | good drawing, but the anvil carries a **bronze roundel that reads as a numeral** — L-18 says the raster carries no number, and "probably not a 1" is not a standard |
| 11 | emblem woodcutting — axe and cut log (64²) | pixen | `50c0bb95-9572-475a-b6fd-bfeceaa932b2` | ~1 generation | ACCEPT | first roll |
| 12 | emblem cooking — iron pot and spoon (64²) | pixen | `a1c9634f-41f7-4daa-a2e8-dcf4de2f2336` | ~1 generation | ACCEPT | first roll |
| 13 | emblem smithing re-roll — plain anvil, no marks | pixen | `649f348b-d808-4510-82fb-2e291660c1a5` | ~1 generation | ACCEPT | heavier anvil, hammer standing on it, no numeral anywhere |
| 14 | gate seal — wax disc, a leaf pressed into it (24²) | pixen | `260a82bf-f44a-4580-8ce3-07c45beca4d4` | ~1 generation | ACCEPT | first roll; a seal, not a padlock (L-17) and not a coin (L-16) |

**Total 14 generations** requested — 10 accepted (2 of them tone-remapped),
4 rejected. Cap 100; **86 unspent.**

## What was not asked for, and why

The **road strip, the fold, the end cap and the two badge plates** were in
`DIR-07`'s table and are not in this ledger past row 6. Two rolls established
the same boundary the kit owner measured across 31 (`ledger/UI_KIT.md`,
`KIT_CONTRACT` §8): `pixen` at 16–128 px does not draw flat tileable chrome —
it draws objects in perspective, decorates them with studs, or dithers a flat
texture into two-colour static. A third, fourth and fifth road roll would have
spent the cap re-measuring a tool limit.

Those four marks are **Flutter-painted instead**, at exactly the geometry
`TrackArt` declares — a sunk track with a broken centre line, a pleated fold, a
cap running out into two courses of loose stone, and a stone plate the level
numeral is set on. `TrackArt._landed` is the on-switch: the day a strip is
authored, its name goes in that set and the painter stops being used, with no
reflow, because the road's width, the joint box, the fold height and the badge
box were spent unconditionally from the first commit.

The **five region marks** and the **96² expanded-site vignette** were also
dropped, for a different reason: both needed `subject` / `wherePlace`
passthroughs on `SkillUnlock` in `lib/runtime/stride_session.dart`, which no
brief gave this team and which another producer may be holding. The entry well
shows the unlock's own **yielded item** instead — art the projection already
points at, and arguably the better answer to "what does this open".
