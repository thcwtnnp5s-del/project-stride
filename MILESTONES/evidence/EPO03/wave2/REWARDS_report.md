# EPO03 — PROD-REWARDS report (team `rewards`, brief DIR-13)

**4 generations of a 90 cap.** Requested 4, accepted 1, rejected 3. Ten
further assets landed at **cost 0** by deterministic remap. DIR-13 budgeted 66
generations for nine new marks; the kit and the Craft workshop had already
authored five of the nine shapes, and three more were reachable by remap.

Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/REWARDS.md`. Rejections with
their reasons: `GAME_BIBLE/ART/exploration/EPO03/rejected/reward/VERDICTS.txt`.

---

## What shipped

### Art — 11 files, `assets/art/v1/reward/`

| file | how | cost |
|---|---|---|
| `stamp_verb_{mining,woodcutting,foraging,cooking,smithing,gathered}.png` | `KitMark.ribbonLabel` re-hued per skill | 0 |
| `seal_wax_{rare,epic,legendary}.png` | Craft's `craft_seal_blank` re-hued per rank | 0 |
| `seal_project_bronze.png` | `seal_project` re-hued off the reserved teal | 0 |
| `glyph_tally.png` | `create_image_pixen`, job `be4befb4`, cropped and lifted | 4 |

The remap tool is `GAME_BIBLE/ART/exploration/EPO03/tools/wax-tone.js`: every
opaque pixel keeps its position, its alpha and its **rank in the source's own
luminance order**, and only hue and chroma move onto a ramp derived from the
target hex. It invents no pixel, moves no pixel and draws nothing (`RULES.md`
A-2, precedent `49c91f9`). Run it twice, get the same bytes.

Packaged in `Scripts/art/package-art.js` under the header
`EPO03 REWARDS (PROD-REWARDS)`, inside the build lock (`atlas-lock.js acquire
rewards` … `release rewards`). `package-art.js --check` clean;
`check-art-palette.js` clean over 2,381 PNGs — no teal collision, no
semi-transparent pixel, chrome under the ceiling.

### Dart

- `lib/ui/components/activity_result.dart` — the result card is a **tally
  slip**: `KitFrame.pageSealed` (deckled paper nine-patch) replacing the
  `surfaceCard` box, the item hero at integer ×2 = 96 dp, the verb on its
  skill's ribbon, facts on `KitTile.ruleJournal` lines with the figures
  aligned down the right margin, and the batch tally.
- `lib/ui/components/reward_beat.dart` — `LevelUpCard`'s mark is the skill's
  own glyph stamped into `KitFrame.slotWell`. Mining 4 and Cooking 9 were the
  same bronze medal.
- `lib/ui/icons/reward_art.dart` — the three new families, `stampVerbFor`,
  and `sealProject` repointed off the teal.

### Rarity is material, never area-fill

| rank | material | mark |
|---|---|---|
| common / unknown | paper (`journalLeaf`) | — |
| uncommon | cloth (`buckram`) | — |
| rare / epic / legendary | warm parchment (`notable`) | the drop sack **and** a wax seal in the rank's own tone |
| a bonus proc at any rank | warm parchment | the bonus mark |
| notable, any cause | | the first ruled line is `KitMark.ruleOrnateA` |

### The producer's running note, answered

The recipe book's six identical saturated red seals were the warning. This
family's three seals are **three different waxes** — blue, violet, gold —
derived from the same drawing at zero cost, exactly the remedy that note named
as cheapest. `test/reward_art_test.dart` holds it: three ranks resolve to
three distinct seals, and Common and Uncommon resolve to none, because a seal
on every result is a seal on nothing. The verb ribbons carry the same
treatment across six skill tones.

---

## What was rejected, and why

Three of four `glyph_tally` rolls, on the sheet
`review/rewards/tally_sheet.png` (×6, on the card's own fill), Read:

- `5857a090` — six crossed strokes; does not read as a count of five.
- `95864968` — a wooden picket fence with a plank nailed across it. An
  illustration of a fence, not tally notation, and it out-shines the words.
- `4e458a22` — two crossed timbers with a cast shadow; three strokes visible.

The accepted roll measured max L\* 11.4 (`#32170D`) against a card fill at
L\* ~10 — invisible, measured rather than judged. Lifted onto the card's ink
ramp by `wax-tone.js --lift 0.55` (`review/rewards/tally_final.png`).

**The corner bracket was withdrawn**, per DIR-13 and confirmed on the render.
At ×2 the bronze corners land *outside* the deckled page, floating in the
void, reading as a stray ornament rather than as significance
(`review/rewards/bracket_before.png` against `bracket_after.png`). Its job —
make the ordinary-to-notable step visible — moved to the ornate rule, which is
visible at 393 dp where the grain difference alone was not.

---

## Proof at phone scale

`GAME_BIBLE/ART/exploration/EPO03/review/device/rewards/`, rendered by
`test/reward_art_evidence_test.dart` at 393 dp / DPR 1 and **Read**:

`result_common_gather`, `result_broth`, `result_bronze_sword`,
`result_rare_drop`, `result_legendary_drop`, `result_batch_craft`,
`layer_signature_drop`, `layer_masterwork_craft`,
`layer_level_up_with_result`. Contact sheets: `review/rewards/slips_x1.png`,
`layers_x1.png`.

What the phone shows that it could not before: the slip's fill is paper with a
torn edge instead of a rounded dark rectangle; the hero is 96 px; MINED,
COOKED, FORGED, FORAGED and CHOPPED wear five different-coloured ribbons; a
rare find carries a blue wax seal and a legendary a gold one; a batch of eight
shows a tally gate; a level-up shows the smith's anvil pressed into a well
rather than a generic medal; and there is no glow ring anywhere.

## Tests

`flutter analyze` clean on every file touched. No `--update-goldens` run.

| suite | result |
|---|---|
| `activity_result_test.dart` | 11/11 |
| `reward_art_test.dart` | 8/8 (3 assertions added) |
| `reward_art_evidence_test.dart` | 9/9 (6 cases added) |
| `board_reward_layer_test.dart` | pass |
| `rarity_ui_test.dart` | 1 pre-existing failure, not ours (below) |
| `gather_queue_ui_test.dart` | 27/27 |
| `phase1_ui_test.dart` | 27/27 |
| `craft_flow_test.dart` | pass |

Assertions that moved, and why each is not a weakening: the slip writes the
item name and its quantity as two widgets and the fact label and its figure as
two widgets, so `find.text('Meadow Herb ×2')` and `find.text('+10 Foraging
XP')` name a layout that no longer exists. Each was replaced by **both halves**
— the item is named, the quantity is 2 — scoped to the card where the name
also appears elsewhere on the screen. Nothing became `findsWidgets` or a
vaguer `textContaining`.

New assertions, each guarding something that would regress quietly: three
ranks resolve to three waxes and the lower two to none; two skills never
resolve to one ribbon; under Reduce Motion every transform on the card is the
identity **while the arrival haptic stays where no motion guard can reach it**
(M-16); exactly one ornate rule per slip, because it is picture class and
never tiles.

---

## What did not close

- **`mark_first_find`** (DIR-13's first-time discovery). `ActivityResult`
  carries no `firstCraft` field and adding one is useless without the call
  site, which is `lib/ui/screens/craft/craft_screen.dart` — PROD-UI-CRAFT's
  file, not ours (§5). Not generated, not wired. It needs one field on the
  snapshot and one line at the craft call site, and it should go to whoever
  owns that screen next round.
- **`badge_level_r1/r2/r3`** (the three-rank level badge). The badges step at
  "the milestone levels already in content", but `LevelUpCard` receives a name,
  a level and a list of unlocked display names — nothing that says which rank
  a level is. Deriving one here would be inventing a threshold, which is a
  design decision an implementation may not make (G-3). Not generated. The
  existing `badgeMilestone` is untouched and still available to a caller that
  knows.
- **`plate_level_stamp` 64²** was not generated: `KitFrame.slotWell` already
  is a stamped well and holds the 48 dp skill glyph, and pixen's measured
  failure mode is exactly "asked for a well, draws an object inside it"
  (PRODUCTION_RULES §2a). Saved 8 rolls and a likely reject.
- **`seal_project`, the teal master, still ships as an orphan.** Its emit is
  one row in the VAWO01 block, which this round does not own (§5). Nothing
  reads it. Deleting that row is a producer's line.
- **`test/screen_evidence_test.dart`** carries our one-line fix (the bonus
  fact is now `Bonus yield` plus a right-margin figure) **in the working tree,
  uncommitted**: another team has 452 lines of in-flight edits in that file
  and it does not currently parse, so staging it would have published their
  half-written work. Whoever commits that file next will carry our hunk with
  it. If they discard it, the assertion at the old `textContaining('bonus
  yield')` will fail against the slip.
- **`rarity_ui_test.dart` "the character sheet names the rank of what is
  worn"** fails on `find.text('unarmed')`. Pre-existing and not ours: the
  string lives in `lib/ui/screens/character/character_screen.dart:566`, which
  PROD-UI-CHARACTER rebuilt in `bd06dc2`. We touch no character surface.

## Requests filed (`REQUESTS_NAV.md`)

1. **A three-patch painter for `ribbon_label`.** Seven of nine verbs fit its
   ~65 dp of label room; `CRAFTING COMPLETE` and `GATHERING COMPLETE` do not,
   and the first render proved it by clipping to `CRAFTING COMPLE`. Those two
   are set as a plain stamped label instead of being shrunk below a type floor
   already under the platform minimum. `_Stamp._ribbonFloor` and its branch
   delete themselves the day the painter lands. Not blocking.
2. **`KitMarks.pathFor` answers the wrong file.** It builds
   `kit/${mark.name}.png` from a camelCase enum against snake_case assets, so
   it returns `ruleOrnateA.png` for a file that ships as `rule_ornate_a.png`.
   Wrong for every multi-word mark; `KitFrames.pathFor` has the same shape.
   Costs nothing on screen (the widgets use `of(...)`), cost one test failure
   here. Not blocking.

## Open questions

**Q-20 stays open and stays as DIR-13 left it**: craft completion's mark is
**art, not systems** — the verb ribbon *is* the mark. No `mark_craft_done`, no
new report field, no new event was invented to hang art on (G-3).

No new Q- was raised: nothing this round needed a decision that did not
already have one.

## Locks

No save, health, economy or step-cost change. No new item, recipe, node,
enemy or system. No FOMO, streak, decay or monetization language. Nothing
flashes, loops or counts up; the reward glow was **removed**, not added to.
No reserved teal — and one pre-existing teal drawing taken out of service.
Every session command call site untouched.
