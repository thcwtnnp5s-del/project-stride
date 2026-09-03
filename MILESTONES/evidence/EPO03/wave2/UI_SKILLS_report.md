# EPO03 wave 2 — PROD-UI-SKILLS report

**Brief:** `wave1/DIR-07_skills_progression.md`. **Cap:** 100 generations,
**14 spent.** Branch `fable5-executive-production-overhaul-03`.

The owner named this screen by hand — "the Skills detail screen still stacks
rounded rectangles". It does not any more, and the overview it is reached from
was not touched.

## What shipped

**Dart (the bigger half, 0 generations).**

- `lib/ui/screens/skills/journey_model.dart` — **new.** `JourneyModel.from`
  turns `SkillRoadmap` into a list of stops (milestone | fold | end) as a pure,
  tested function: which levels stand, which sink into a fold, and where the
  road ends. That grouping used to be three loops tangled through
  `_Ladder.build`, untestable without pumping a screen. Nothing is derived —
  every level, state, distance and horizon is the projection's own (E-2, F-07).
- `lib/ui/screens/skills/track_art.dart` — **new.** The journey's own art
  registry, in `assets/art/v1/track/`, because the journey family was struck
  from the shared kit (`KIT_CONTRACT` §8). Kit doctrine exactly: a row that has
  not landed is `null`, the widget paints its own fallback, and the layout
  figure is spent either way. `_landed` is the on-switch.
- `lib/ui/screens/skills/skill_detail_screen.dart` — **rebuilt.** Dead:
  `_NextBlock`, `_Ladder`, `_LevelBand`, `_UnlockRow`, **both `SectionCard`s**,
  `SkillHeaderRow` / `SkillProgressBar` on this route. New: `PageGround`
  (`buckram`) full bleed, the trade band, `TradeGauge` — a 64² hero emblem in a
  well, the name in the trade's ink, a gauge frame whose window the existing
  `ProgressRule` fills, with the XP caption and the census line on the ground
  beneath — and `JourneyTrack`: an inked road painted **behind** the column of
  stops so it is continuous, with a Flutter-placed joint per level in a
  reserved 48 dp rail. Four joints told apart by shape; unlocks hang off the
  road on 16 dp spurs, unboxed, as a 48 dp well + name + the projection's first
  detail line + a wax seal carrying `Also needs …`; empty runs and the road
  already walked sink into painted folds; an end cap closes the road at
  `contentHorizon` with the projection's own sentence.
- **L-18:** a badge is a blank stone and `LV n` is set in `StrideType` over it;
  state is redundant in shape, ink and Semantics. **No padlock, no coin, no
  timer, no teal, nothing that counts up** (L-15/16/17/19).
- **No new data and no new content.** The entry well shows the unlock's own
  yielded item — art the projection already points at.

**Art (10 marks, `assets/art/v1/track/`).** Four joints — `joint_reached`,
`joint_here` (the lit lantern cairn), `joint_next` (a bronze-banded standing
stone), `joint_far` (a bare post) — `gate_seal`, and five 64² hero emblems
(`emblem_mining|foraging|smithing|woodcutting|cooking`). Packaged by this
team's own block in `Scripts/art/package-art.js` (header `EPO03 UI-SKILLS`,
run under the build lock), which enforces the declared canvas and refuses a
mark whose top and bottom rows are fully opaque. `package-art.js --check`
clean at 1,981 files; `check-art-palette.js` clean at 2,047 PNGs.

## What was rejected, and why

Four rolls, with sheets: the road tile twice (`review/skills/batch01.png`,
`review/skills/road_tile_proof.png`) — `pixen` returned wood planks, then a
two-colour checkerboard dither; the far stake once (a tree stump on its own
soil plate, a baseline the other three joints do not have); the first smithing
emblem once (a bronze roundel on the anvil that reads as a numeral — L-18).

Two accepted marks were **tone-remapped rather than re-rolled** (A-2,
precedent 49c91f9): the reached slab ×0.55 and the near-white far post ×0.18
in linear light, by `EPO03/tools/dim.js`. A near-white *far* joint would have
made the furthest thing on the road the brightest. Per-roll verdicts:
`GAME_BIBLE/ART/exploration/EPO03/ledger/UI_SKILLS.md`.

**The road strip, the folds, the caps and the two badge plates were not
pursued past two rolls.** They are the flat-tileable-chrome boundary the kit
owner measured across 31 rejected rolls; a third road roll would have spent the
cap re-measuring a tool limit. All four are Flutter-painted at exactly the
geometry `TrackArt` declares, so a strip authored later swaps in with no
reflow.

## Proof

`GAME_BIBLE/ART/exploration/EPO03/review/device/skills/`, 393 × 852 @ DPR 1,
read at phone scale:

- `v3_skill_mining_detail.png`, `v3_skill_foraging_detail.png`,
  `v3_skill_smithing_detail.png` — the three trades at level 1.
- `epo_skill_foraging_midroad.png` — **the seeded mid-road state** (Foraging at
  LV 3): two reached slabs behind the walker, the lit cairn and its backplate
  at LV 3, the bronze stone at LV 4 carrying `70 XP away`, faded stakes above
  it. No such state had a render in the repo before — every other run in the
  harness starts every trade at level 1 — so one additive block was added at
  the end of `test/screen_evidence_test.dart`, touching no other team's block.
- `epo_skills_overview.png`, `v3_skills.png` — the overview, **untouched**.

Judged: the roadmap now reads as position rather than as a list. The first
screen answers *where am I* without scrolling (band, emblem, gauge, the lit
joint, the next joint with its distance); there is not one rounded dark card on
the route; the four joint states separate by silhouette alone.

## Tests

- `flutter test test/skill_detail_test.dart` — **3/3 pass**, rewritten for the
  new grammar: the projection assertions kept verbatim, a new pure test of
  `JourneyModel` (no level number invented or skipped, exactly one lit joint,
  the distance on the next joint alone, the end cap), and a widget test that
  now asserts `SectionCard` **findsNothing** on the route.
- `flutter test test/ui_responsive_test.dart` — 64/64 pass (320 dp, ×1.4).
- `flutter test test/screen_evidence_test.dart` — 7/7 pass.
- `flutter analyze lib/ui/screens/skills/` — clean.

**Stale goldens, not regenerated** (`--update-goldens` not run, per the rules):
`test/phase1_golden_test.dart` fails three cases — the six tab roots at both
sizes (`phase2_skills.png`, `phase2_skills_large.png` among them) and
`craft_stage.png`. None of them is this route, which has no golden; they cover
the Skills *overview*, which this team did not edit, and they are failing under
the round's kit changes (square radii, the rebuilt tab bar, the new welt). The
producer regenerates after inspection.

## What did not close

1. **The road is painted, not authored.** Two rolls, both refused. The screen
   is finished without it and reserves its geometry, but the gutter is a
   painted track and not material.
2. **The badge plates, the fold, the end cap and the "here" backplate** are the
   same story — painted, with their `TrackArt` rows declared and `null`.
3. **The gauge frame** was never rolled: it is a nine-patch, the exact shape
   the tool has failed on 33 times across two teams. The gauge is a painted
   recess of the same band thickness.
4. **The five region marks and the 96² expanded-site vignette** in `DIR-07` are
   not built. Both need the `subject` / `wherePlace` passthroughs on
   `SkillUnlock` in `lib/runtime/stride_session.dart` — a file no brief gave
   this team, and a projection change another producer may be holding. The
   entry well shows the yielded item instead. If the producer wants the region
   marks, that passthrough is the prerequisite.
5. **No device verdict.** Every judgement here is this team's, on the evidence
   renders. The iPhone is the final authority and has not seen it.

## Requests and questions

None filed against `REQUESTS_NAV.md` — the journey family is this team's own
and needed nothing from the kit owner. No `Q-` raised, and nothing in this work
touches a save, a health call, an item, a recipe or a step cost.

## Note for whoever runs next

While this team was rendering, the shared tree did not compile for a stretch:
`lib/ui/icons/traveler_art.dart` (PROD-EQUIPMENT) referenced `SpriteFootprints`
members that no `package-art.js` block generates yet, which fails every widget
test in the repo rather than only that team's. It cleared on its own.
