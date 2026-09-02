# FINAL-09 — identity guardian, FMPO02 wave 3 (9e555d3)

Measured from the shipped PNGs and `git diff 4d9a81f..HEAD`, not from the reports.

1. **BLOCKER — the new turn marker is a coin.** `assets/ui/v1/combat/turn_marker.png`
   (added 061d0fa; drawn `combat_stage.dart:872` ×2, immediately left of `TURN 1`).
   Measured: round disc, concentric raised rim, stamped centre, every chromatic pixel
   H19–25° copper — the only round metal disc in the app, sitting beside a numeral.
   That is the read L-16's own rationale bans ("a numeral beside a glyph reads as
   currency, and Stride has none") and L-17 makes a wrong-system implication a defect
   "regardless of craft quality". Screen: `review/device/combat/combat_wolf_slash.png`.
   The code calls it "the authored leather tab"; the pixels are not a tab. It exists
   only because Q-22 records ART-09 §3's 32×16 **bar** being overridden by a wave-2
   dispatch (24×24 tab) that was never reconciled.
   **Fix:** revert to the 32×16 leather bar, or drop the ornament — `_Chip('TURN n')`
   already carried the fact.

2. **BLOCKER — the reward layer's frame is literally the reserved teal.**
   `review/device/board/board_layer.png`: sampled border pixels are `#58d6c0` exactly;
   1,215 pixels within ΔRGB 12 of the reserved accent on a screen whose subject is *an
   order delivered*, not steps. Same ink on the "ORDER DELIVERED" eyebrow and, in
   `board_open.png`, on the `READY` pill and "1 READY". Source:
   `board_card.dart:725 rewardInkOf(localNeed) => StrideColors.accentSteps`. L-16 admits
   no interface element using teal "for any other meaning". **Not introduced this round**
   (identical at 4d9a81f) — but FMPO02 owns the reward layer, re-rendered these screens,
   and submitted them as accepted evidence.
   **Fix:** `rewardInkOf(localNeed)` → `StrideColors.rewardLightInk` (already the combat
   layer's ink). Teal stays on the header's banked-steps figure alone.

3. **SHOULD-FIX — deferred Milestone 02+ vocabulary shipped as a heading, silently.**
   `activity_panel.dart:117` now reads `SectionHeading(label: 'Expedition kit')`; at
   4d9a81f it read `'Activities'`. `PROJECT_KERNEL/08_GLOSSARY.md` defers **Expedition**
   to Milestone 02+ and forbids it as a distinct system in the slice. Renaming the gather
   list after a deferred concept inside an art round, with no ADR, owner ruling, or
   `OPEN_QUESTIONS` entry, is G-3. Screen: `review/device/v3_adventure.png` (the band art
   itself bakes no text — L-18 is clean).
   **Fix:** restore `'Activities'`, or raise it as Q-27 and keep the band as authored.

4. **SHOULD-FIX — the three salvage crates use loot-box grammar.**
   `assets/art/v1/item/reclaim_{axe,pickaxe,chestplate}.png` (`review/items_old_new_x3.png`
   row 3): each is a wooden chest **with its lid lifting off**, contents showing, the
   distinguishing tool silhouette a low-contrast stamp on the front. At 48 dp the dominant
   read is "open this for a reward" — the container idiom `06_ANTI_FEATURES.md` names —
   while the recipes are fully deterministic (1 bronze axe → 1 bronze ingot). Three
   near-identical chests also do not resolve the owner's failure #5.
   **Fix:** drop the container; draw the process — the input item cut over an ingot —
   which separates all three by a silhouette the player already knows.

5. **SHOULD-FIX — `seal_masterwork` names a system that does not exist.** `reward_art.dart`
   documents it as "the ceiling of craft quality, **not** a rung on the rarity ladder";
   `craft_screen.dart:322` fires it on `significance == major`, which
   `craft_significance.dart` defines as `outputRarity >= Epic`. "masterwork" appears
   nowhere in `assets/content/v1/`. So a rarity rung is dressed as a quality tier, on 7
   repeatable recipes (Bronze Longsword, Hornbound Bronze Axe, Bearhide/Clawguard/
   Frostwarden Coat, Frost-lined Jerkin, Scale-Warmed Chestplate), every craft, beside an
   `EPIC` chip already saying it. **Fix:** rename the banner to what fires it, or record
   the missing predicate as an open question — as Q-24 correctly did for `marker_profession`.

6. **SHOULD-FIX — submitted evidence renders text as tofu.**
   `review/device/stage/mine_hardened_locked_selected.png` and
   `review/device/combat/gear_*.png` show solid white boxes for every label, so the
   locked-node claim is unverifiable and M-06 may be returning in the harness.
   **Fix:** re-render both sets with the product font loaded before claiming acceptance.

7. **NOTE — `LOCKED` contracts state no unlock condition.** `board_open.png`: two
   Charter rows say only `LOCKED`. No padlock is drawn, so L-17 holds — but the craft
   screen is honest ("Needs Smithing 6 — you are 1") and the board is not. **Fix:** carry
   the same phrasing onto the board.

8. **NOTE — `seal_project.png` is drawn in the dimmed step teal.** Fills H161–173° at
   S 61–100 (`#1b5546`, `#215e4b`) — `accentStepsDim`'s own hue relationship. It clears
   `check-art-palette.js` only because the guard tests ΔRGB against the bright accent, not
   hue. Pre-existing; reviewed this round (`review/reward_seal_project_x8.png`) and kept.
   **Fix:** move the plate to the quest violet or a leather ground on the next reward pass.

## What holds

9. **Bronze reads bronze.** Gold band (H38–60, S≥40, V≥55) is **0.0%** on the re-authored
   `bronze_longsword`, `fanghilt_sword`, `goblin_toothed_axe`, `tinbraced_pickaxe`; 82–100%
   sits in the bronze band. The two files at ~5% (`bronze_sword`, `bronze_chestplate`) are
   untouched this round and those pixels are V≈100 speculars. This round improved the read.
10. **No new persisted state; Health untouched.** `git diff -- packages/` is **empty**;
    nothing in `lib/runtime/` adds a version, codec, or save write; equipment projects from
    `Equipment.bySlot` at read time.
11. **No FOMO language.** Every daily/streak/limited/expires/hurry hit in `lib/ui` is a
    comment asserting the rule.
12. **World life is scenery by construction.** `atlas_layout.json` gained 8 overlays and 3
    props and **zero** locations, landmarks, routes or rumors; overlays carry no id and no
    `hitRadius`, so the dragons, fairy castle and ice tower on
    `worldlife/ATLAS_PLACEMENT_FINAL_x1.png` cannot be tapped into a dead panel. Wonder
    without a promised system — keep it that way when locations are next added.
13. **Q-18…Q-26 discipline is genuinely good** — nine questions recorded rather than
    guessed, including two the round could have quietly resolved. The one leak is Q-22:
    built to the dispatch and shipped, which produced finding 1.

**Verdict:** REJECT — a coin beside the turn number and 1,215 pixels of reserved teal
framing an order delivery, plus a deferred-vocabulary rename made silently; everything
structural (save, Health, FOMO, world-life promises, bronze) is clean, so this is four
small edits from a pass.
