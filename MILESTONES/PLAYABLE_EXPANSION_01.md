# Playable Expansion 01 — record

**Opened / implemented:** 2026-08-19 · **Branch:** `playable-phase-2-multiregion` ·
**Starting HEAD:** `f66b29d` (Transformation Build 01 + 0019, device-validated).
**Owner direction:** the "Playable Expansion 01" master prompt, after the
physical-device validation of Transformation Build 01 (health authorisation,
fresh baseline, backlog retirement, new-step ingestion, duplicate protection,
banked/spent correctness, travel — all observed on the iPhone).
**Status:** implementation complete, awaiting the owner's device test (§10).

## 1. Objective

Cross from *walking-powered crafting prototype* toward *a small but real
walking-powered RPG*:

```text
walk → travel → gather → craft/equip → explore → encounter → fight/retreat
     → earn rewards → improve → continue traveling
```

Primary system: a **combat vertical slice** — contract
`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`, decision `DECISIONS/0020_COMBAT_SLICE_01.md`.
Alongside: device-informed ambient-stage composition, atlas device usability,
PixelLab combat production, a PixelLab correction round for withheld/weak art,
an in-place iOS install path, and — found on the way — the first **Equip**
control the product has ever had (`MISTAKES.md` M-11).

## 2. What is frozen (P0) — confirmed untouched

The health / step-accounting path proven on the phone: `totalGranted`
monotonic, forward-only cursor, per-origin watermarks, foreground startup +
manual sync only, `DECISIONS/0016/0018/0019`, single-writer persistence,
atomic commits. **No file under `packages/stride_core/lib/src/steps/`,
`packages/stride_health/`, or the session's sync section changed.** The
state-version table gained one step (v3→v4, `rebasesEconomy: false`); a v2
save now migrates v2→v4 in one commit with the 0018 mark still established at
3 and banked 0 (`test/deferred_epoch_session_test.dart`).

## 3. Execution graph (as run)

```text
Stage 1  bootstrap + contracts (COMBAT/02, DECISIONS/0020, this record)          lead
Stage 2  parallel, file-disjoint:
   B  combat domain, stride_core, state v4, 36 tests, v4 fixture                 done
   D  PixelLab combat art (Traveler east set, 3 enemies, effects, backdrops)     done, 61 gens
   E  ambient composition correction (code/compositing, measured extents)        done
   F  PixelLab ambient/readability correction round                              done, 16 gens
   G  atlas device usability pass                                                done
   I  iOS install save-preservation inspection                                   done
Stage 3  C1 session/controller/encounter card/placeholder screen · C3 Equip     done
Stage 4  C2 animated combat stage                                               done
Stage 5  integration (lead): packaging, scene table, refusal copy, goldens, docs done
Stage 6  verification (`Scripts/verify.sh --strict`)                             §8
```

## 4. Combat — what shipped

| | |
|---|---|
| Region / enemies | the three canonical enemies at their canonical locations: **Forest Wolf** (Whispering Woods, *flurry* — two light bites a turn), **Cave Goblin** (Stonefall Mine, *steady*), **Hollow Guardian** (Forgotten Hollow, boss, *guarded* — every third turn a heavy strike, telegraphed the round before) |
| Entry | an **Encounter card** on the Adventure tab at the enemy's location; *Start Combat* costs no steps; disabled truthfully ("Driven off — returns after you travel" / "Finish your current encounter" / "Reload before fighting") |
| Player model | `maxHp = 40 + 4·(level−1)`; `attack = equipped weapon power (1 unarmed) + (level−1)~/2`; `defence = equipped armour power`; tools never count; snapshotted into the encounter at start |
| Actions | **Attack** · **Eat** (an owned consumable with `healing`; refused at full HP) · **Retreat — nothing is lost** |
| A round | one command, one commit: player action then the enemy's reply; a durable save is always at the start of a player turn |
| Damage | `max(1, attack − defence + roll)`, `roll ∈ {−1,0,+1}` from a seeded deterministic hash (`CombatRules`); heavy = `max(1, 2·attack − defence)`; no `Random` in core (guarded) |
| Equipment effects | Training Sword 3 → Bronze Sword 9; Traveler Tunic 2 → Bronze Chestplate 7; with the starting kit the wolf wins in 6–9 rounds, the goblin needs bronze (5–6 rounds), the guardian needs bronze + chestplate + food |
| Retreat / defeat | both clear the encounter and move the player to the **nearest safe location** (BFS over the content graph; Haven's Rest today); inventory, equipment, skill XP, character XP, unlocked places, banked steps untouched; food eaten stays eaten |
| Rewards | one `EncounterWon` event carries character XP (wolf 30 / goblin 60 / guardian 150) and drops (wolf meadow herb @60 %; goblin copper ore ×2 @55 %, tin ore @30 %; guardian hollow sigil @100 %, hollow root ×2 @70 %) and clears the encounter — **exactly once by construction** |
| Availability | after a victory the enemy is **driven off here until the player moves** (any location change clears it) — the only limiter on repeat fights, step-clocked through travel |
| Character | Level / XP / Max HP / Attack (weapon) / Defence (armour) block on the Character screen; thresholds L2 100 · L3 300 · L4 600 … L10 4 500 (cap) |
| Persistence | `GameState.encounter`, `WorldState.drivenOff`, live `PlayerState`; **state version 4**; v1–v3 decode with no encounter; frozen `v4_baseline.save`; cold relaunch resumes the fight at the start of the player's turn |
| Refusals | gather and travel refuse `encounter_in_progress` ("Finish or retreat from your encounter first") |

Balance figures are **provisional test balance**.

## 5. PixelLab production (`GAME_BIBLE/ART/exploration/PLAYABLE_EXPANSION_01/`)

| Stream | Accepted | Withheld / rejected | Spend |
|---|---|---|---|
| D combat | Traveler east: `combat_idle` 7 f, `attack` 4 f (80×64, blade sweep), `hit` 6 f · wolf `idle/attack/defeat` (56²) · goblin `idle/attack/hit/defeat` (56²) · guardian `idle/attack(heavy)/swipe/hit` (96²) · `fx_impact`, `fx_bite` (32², 5 f) · backdrops `forest/mine/hollow` (192×96) — **119 files** in `assets/art/v1/combat/` | `wolf_hit` (3 rounds, read as a run/leap — the stage uses impact + a UI recoil instead), `guardian_defeat` (identity drift); rejected `fx_slash` (the attack frames carry the sweep), `traveler_fight_stance`, the standard-mode guardian set | 61 |
| F corrections | `traveler_read` (large dark book, bright pages — PASS), `traveler_pick_inspect` (crouched, pick horizontal, never raised — PASS-WITH-NOTE "holding a pick, not mining", **enabled by lead override**, recorded), `icon_pine_log` (oak/pine separation), `skill_foraging` (contrast) | `traveler_axe_inspect` (re-roll read as a mallet), a side-stretch alternative, a push-up alternative, `node_tin_seam` (vein reads, silhouette reads tile), `icon_pine_plank` (collides with oak_handle) | 16 |

Three blind Visual QA passes for combat and one for the corrections, verdicts
verbatim in each stream README (M-04). Balance ≈ 779 → 700 generations. Enemy
character ids and animation groups are in `combat/README.md` §4.

## 6. Device-observed presentation problems — what changed

| Observed on iPhone | Change | Kind |
|---|---|---|
| Traveler stands *through* the gather-node vignette | node art is now **far scenery**: drawn behind, left, with its measured lowest opaque row ~39 dp above the Traveler's ground line; the figure stands in the **near zone** right of it (`AmbientStageLayout`) | code / compositing |
| Cat in awkward places, off the stage | every layer offset re-authored in 64-box coordinates against **measured union extents** (`Scripts/art/measure-ambient-extents.js`), all companions on the ground at the Traveler's left; the stage **clips** | code |
| Fire / yarn compete with node art | fire moved behind and right of the seated Traveler, cat between; no layer may touch the scenery (tested) | code |
| Wide/prone poses overflow / sit oddly | a real defect found: `AmbientScene.canvasHeight` defaulted to the *width*, so every 80/96-wide scene was drawn stretched square — fixed; the widest frame keeps 6 dp of right margin | code (bug fix) |
| Scenes read as layered PNGs | per-scene authored composition + `test/ambient_composition_test.dart` (every scene × every node: inside the stage, allowance-bounded overlap, scenery clear of the figure) | code |
| `stretch` peak reads "cheer" | frames 0..3 only (the arms-up peak cut), pingpong ×3 | playback |
| `pushups` prone reads "collapsed" | frame content; a PixelLab alternative did not beat it — **kept, owner to judge** | — |
| axe / pick / read withheld | read and pick corrected and in rotation; axe still withheld | PixelLab |

## 7. Atlas — device pass (code only, `atlas_layers.dart`, `atlas_layout.json`)

Hit targets measure 80–88 dp at 1× (no overlaps, test added); labels 11/22 dp
on a dark plate with no neighbour overlap; **current place now a bullseye**
(solid centre dot) and the pulse ring gets a dark contour — it was
near-identical to "selected" at rest and invisible on snow; **route dots get a
dark contour** (vanished on snow/pale rock); forest mist moved off the Hollow
ruin and the mine landmark; zoom 1–2× focal-anchored and pixel-snapped, pan
clamped on all edges, camera recentres after travel (tests added); overlays
below markers and untappable (test). World goldens regenerated. Needs art,
not code (not done): pixel-native marker rings and mist.

## 8. Verification

`Scripts/verify.sh --strict` (guards, core purity, UI boundary incl. the four
new command names, art packaging `--check` 386 files, dependency policy,
iOS/Android target guards, single-writer, step-model, origin-privacy, format,
`stride_core` **592**, `stride_storage` **108**, app suite incl. combat
session/UI/stage/golden, inventory equip, ambient composition (164 cases),
atlas; 13 goldens regenerated and reviewed by eye). Result recorded in §8a.

### 8a. Result

`Scripts/verify.sh --strict` on the committed tree (2026-08-19): **All checks
passed** — every guard and self-test green, `dart format` clean, `stride_core`
**592**, `stride_storage` **108**, app **409**, `stride_health` **143**,
`stride_secure_store` **31**; art packaging `--check` 386 files up to date.

## 9. Known issues

- **BLOCKER:** none known.
- **GAMEPLAY / DESIGN:** balance is provisional (wolf may be too easy with
  bronze, guardian needs two stews); no persistent HP / rest; no guard action
  against the telegraphed heavy strike (Q-06); drops duplicate gathering for
  the goblin (canonical content, kept); `pushups` prone read; character XP is
  QA-profile-scaled like every other XP.
- **COSMETIC:** `traveler_attack` drifts toward ¾ view and the blade is cold
  grey; `guardian_swipe` cuts abruptly; `fx_bite` thin; mine backdrop adit
  reads as a doorway; wolf slightly small beside the Traveler; heavy-strike
  emphasis is weight/brightness only (no warning hue exists in the palette);
  `node_tin_seam` still reads boulder/cookie; `pine_plank` still reads paper;
  axe inspect still withheld; anti-aliased vector rings on the atlas.

## 10. Physical-device test script (owner)

1. **Mac:** pull the branch. `bash Scripts/ios/build-release-device.sh` — it now
   installs **in place** (`devicectl`), so the existing save survives; note
   `TOTAL WALKED` before and after. Unplug.
2. Launch from the Home Screen. Banked, TOTAL WALKED, location, inventory as
   before (a v3 save migrates to v4 silently).
3. **Sync steps** twice: the second grants nothing.
4. Walk 500+ steps, reopen: banked rises once.
5. **Inventory:** Equip the Training Sword and the Training Axe (WEAPON / TOOL
   slots fill). Character: Attack reads 3, Defence 0, Max HP 40.
6. **World:** the current place is a bullseye; pinch, pan; tap Whispering
   Woods → Travel (600).
7. **Adventure at Whispering Woods:** gather Oak Stand once (the axe now
   works). Note the ambient stage: tree behind-left, Traveler front-right, cat
   at his feet, nothing clipping; let it play ~30 s.
8. **Forest Wolf card → Start Combat.** Attack; watch the slash, the impact,
   the wolf's bites, both HP bars. Tap the stage once to skip a replay.
9. **Mid-fight, force-quit** (swipe away). Cold launch: the fight resumes at
   the same turn and HP.
10. Win. The result panel shows +30 XP and any drop **once**; OK. The card
    says "Driven off — returns after you travel". Inventory shows the drop
    once; Character shows 30 / 100.
11. Equip the Traveler Tunic, travel to Stonefall Mine, **Start Combat** on
    the Cave Goblin with the training sword, attack until you fall (or tap
    Retreat): "You retreat to Haven's Rest. Nothing was lost." Confirm
    inventory, equipment, skill XP, character XP, banked steps unchanged.
12. Eat in a fight: cook a Herb Broth first, then mid-fight Eat → "+12", one
    broth gone.
13. Force-quit and relaunch: everything intact; no encounter.
14. After 7 days the free profile expires: rerun step 1 — still in place.

## 11. Recommendation

Play it. On this evidence the next milestone should be **content /
progression depth on top of combat**: a second enemy variant per region
(cheap now — the resolver and stage are generic), combat-only materials (a
pelt, a fang) that feed one or two narrow recipes, the persistent-HP / rest
question (Q-06), and the two remaining art corrections (tin seam, pine
plank). Audio stays blocked on the owner's source references (§12). Dungeon
design should wait until this slice has been fought on the phone.

## 12. Audio

Searched the repository and context for the owner's previously supplied audio
resource references: **none exist** (no URLs, no manifest rows, no audio
dependency). Per the handoff (§13) they are not to be guessed. **Audio
foundation deferred; source selection remains pending the owner resending the
references.** `DECISIONS/0005` and `AUDIO/AUDIO_ASSET_MANIFEST.md` remain the
frame for when they arrive.

## 13. iOS install — save preservation (`TECHNICAL/IOS_DEVICE_INSTALL.md` §1.4)

`flutter install` **uninstalls first** — literally
(`flutter_tools/commands/install.dart`, no opt-out) — which deletes the data
container: that, not a team change, explains the fresh container in
Transformation Build 01 §7a. `install-device.sh` now defaults to
`xcrun devicectl device install app` (in place) with `flutter run --release`
(also in place) as the fallback; `flutter install` survives only as
`--wipe-reinstall` behind a typed `WIPE`. A different Team ID makes iOS
*refuse* the upgrade until the app is deleted. UNVERIFIED on the Mac:
`devicectl list devices --hide-headers`; the script falls back if not. No
backup mechanism built (an in-container backup would die with the container).

## 14. Progress log

- 2026-08-19 — bootstrap read; contracts written; fan-out launched; all
  streams returned; integration, goldens, docs; verification run.
