# EPO03 — PROD-ENEMIES report

Branch `fable5-executive-production-overhaul-03`. Brief `DIR-12`. Cap **130**,
spent **68**. Files owned and changed: `lib/ui/screens/adventure/encounter_card.dart`,
`bestiary_screen.dart`, plus `lib/ui/icons/encounter_habitat.dart` and the
salamander/ram rows of `lib/ui/icons/combat_assets.dart` (unassigned in
PRODUCTION_RULES §5, named as this family's by DIR-12), the family block of
`Scripts/art/package-art.js`, `test/encounter_card_test.dart`, one assertion in
`test/combat_ui_test.dart`, and a new EPO03 ENEMIES block in
`test/screen_evidence_test.dart`. `encounter_card.dart:336` `startEncounter` is
untouched, and `adventure_screen.dart` was never opened.

Commits `65eb4a8`, `4885134`, `0dd917f`, `ca53b69` — all pushed.

Ledger: `GAME_BIBLE/ART/exploration/EPO03/ledger/ENEMIES.md` (every job id, cost
line and verdict). Device renders:
`GAME_BIBLE/ART/exploration/EPO03/review/device/enemies/`.

---

## 1. What the round found, and what it did about it

DIR-12's verdict was that **no sprite needed re-rolling** — thirteen silhouettes
hold at 76 dp — and that the failure was the ground. Confirmed on the seated
composite before a generation was spent: Stonefall creatures stood at the foot
of a wall, Frostmere feet were on the gravel *below* the drift, and the Hollow
had no floor at all. Nothing was ever drawn in front of a creature, so every
card was a cut-out on a picture.

**Five habitat windows and six foregrounds now ship.**

| Plate | Was | Is |
|---|---|---|
| `forest_floor` | leaf litter, creature stands on it | **kept unchanged** |
| `rocky_ledge` | masonry courses over a 6-row scree strip | scree bank as midground, rock columns as the top band, a wide worked floor in the lower third |
| `cave_shadow` | a face-on cobble wall, one lantern, the salamander floating (**Q-23**) | slate flagstone floor over the lower half, one ember fissure crossing it, basalt as a top band, no lantern — **Q-23 closed** |
| `snowbank` | drift ending at row 70, creatures on the grey band under it | wind-packed snow to the bottom row, rime treeline behind |
| `hollow_rootbed` | roots edge to edge over black, boss at 146 dp in a 152 band | **retired.** Replaced by `hollow_chamber`, 192 × 96 — a root tunnel with a bare earth floor — plus `hollow_chamber_awakened`, the same room roused in amber rune light |

Foregrounds — `habitat_fg_forest_floor`, `_rocky_ledge`, `_cave_shadow`,
`_snowbank`, `_hollow_chamber`, and the one canopy `habitat_top_cave_shadow` —
are 192 × 32 transparent strips drawn **above** the creature (the canopy above
the plate and below the creature, because a stalactite fringe is something a
creature stands beneath). Six accepted on the first roll each.

## 2. The dossier

`EncounterCard` is a field-guide entry on `journalLeaf`, and every chrome
element in it cost **zero generations** because the kit already had it:

* the habitat window in a **kit frame** — the landed `stageFrame` for a boss,
  `insetStage`'s honest square fallback for everything else;
* the knowledge tier **stamped on `ribbonLabel`** instead of a pill chip;
* the entry rule is the landed `ruleOrnateA`, which the kit contract authored
  naming this surface;
* the habitat **named in words** ("Frostmere · wind-packed snow") — the one
  fact a habitat window cannot say for itself;
* HP / ATK / DEF as **one ruled threat line**, behaviour as a sentence.

Three pill chips and three bordered value tiles are gone and nothing they said
is lost. `_EnemyStage.heightFor` now returns the *plate's own* height, so a
boss band is 192 dp against a wolf's 152 and the Guardian has headroom.

**One defect the device render found and the round fixed:** inset on all four
sides, the region ink behind the window painted a coloured mat between frame
and habitat — violet, loudly, on the Hollow. The frame's band is now spent on
the bottom edge alone, so the art bleeds under the other three. The remaining
thin ledge under the picture is deliberate: spending the band at the top
instead would put the frame's lower beam across the creature's feet, which is
the one thing this change exists to make visible.

**The Bestiary** is the guide: every row carries a `HabitatVignette` — the same
plate, foreground and idle frame at ×1 — with the habitat named under the
species and unsighted creatures drawn as ink silhouettes. Static, no meter, no
percentages, **zero generations**.

## 3. The salamander and the ram

**Salamander — 41 generations, all 29 frames.** The costed plan was to edit f0
and re-animate three tracks (~10). Rejected on measurement, not preference:
FMPO02 already recorded `animate_image`'s in-place-only output as too weak for
a collapse, so re-animating would trade an accepted attack cock-back and an
accepted defeat for worse ones. Per-frame `edit_image_pixen` (29 at cost 1)
preserves motion but recolours each frame independently — the flicker trap.
`edit_image` in **reference mode** — the accepted first-frame ember edit as the
reference, the shipped frames as inputs — keeps every pose, guarantees one
appearance, and prices by the frame grid: **20 generations for fourteen
frames**. Two calls covered idle, attack, hit and defeat. Canvases and f0 alpha
bounds match the shipped set track for track, the re-measured footprints came
out identical, and `combat_assets.dart` did not move.

**Ram — 0 generations.** FMPO02 packaged `ram2_idle` and left adoption to an
integrator on one condition: re-measure the boar↔ram silhouette IoU. Measured:
**0.702 → 0.727**. The re-horn is fractionally *closer* to the boar by that
number and clearly further from it on the ×4 sheet — the horn gains internal
ridging that reads as a curl where the shipped one is a dark blob — and the two
animals differ by palette as well. M-04's rule applies exactly: the sheet read
is the verdict, the number is triage. Adopted for the idle; the attack and
defeat keep the original horn, which is a texture difference at one silhouette.

## 4. Proof

`SCREEN_EVIDENCE` renders at 393 × 852 DPR 1, all read:
`epo_enemy_woods_wolf`, `epo_enemy_mine_salamander`, `epo_enemy_mine_goblin`,
`epo_enemy_frostmere_lynx`, `epo_enemy_frostmere_ram`, `epo_enemy_hollow_boss`,
`epo_enemy_field_guide`. The evidence block drives a real save through the
bronze-sword forge, because the Forgotten Hollow admits nobody without one.

Against DIR-12's seven success criteria: **1–7 met.** Every creature's feet are
on a visible floor plane; a foreground element crosses every creature's feet;
no log, lantern, cut block or plank survives on any plate; the Guardian's band
is taller, darker and heavier-framed with headroom above its head and the
Awakened chamber is distinguishably lit; the ram's horn and the salamander's
heat read at arm's length; the bestiary shows a vignette per row with unseen
creatures as silhouettes and no percentage anywhere; and the salamander card
closes Q-23.

Tests: `flutter test test/encounter_card_test.dart` — 11 passing, including new
assertions that the foreground paints above the creature, that the boss window
takes `stageFrame` and a common one `insetStage`, and that the chamber is 192 dp
against a roadside 152. `test/combat_ui_test.dart` — the encounter case passes
(one assertion updated: the behaviour label is a sentence now, not a shouted
chip). `flutter analyze` clean on every file touched. `package-art.js --check`,
`check-art-palette.js` clean. No `--update-goldens`.

## 5. What did not close

* **`test/combat_ui_test.dart` "the Character screen shows the combat figures"
  fails, and it is not this family's.** It scrolls for the text `COMBAT`, which
  no longer exists in `lib/ui/screens/character/` after PROD-UI-CHARACTER's
  folio rebuild (`bd06dc2`, `80e1d48`, `76b185b`). Nothing this family changed
  is on that screen. Flagged for that team rather than repaired here.
* **`test/screen_evidence_test.dart` was momentarily corrupted by a concurrent
  write** — a whole-file rewrite of this family's copy raced another team's
  in-flight edit and duplicated a 442-line region. Detected by `flutter
  analyze`, spliced back by hand, and the other team's DIR-13 block is intact
  and passing. **For anyone else in this file: append with a targeted edit, not
  a whole-file write.** Worth a rule if the producer agrees.
* The **rocky ledge is the greyest of the five windows** — the rubble
  foreground is prominent enough to flatten the floor a little. Accepted rather
  than re-rolled; it is a tone judgement for the owner's device, not a defect
  against any of the seven criteria.
* The **collapsed row still says "Hollow Guardian · Boss"** while the open
  dossier says "Guards this place". Both are true and the row is a list entry,
  but it is one redundancy the round did not remove.
* **No open Q- was added.** Nothing in this family's scope required a design
  decision that had not already been ruled: Q-21 stands as FMPO02 ruled it, and
  Q-23 is answered by the new `cave_shadow` and its device render.
