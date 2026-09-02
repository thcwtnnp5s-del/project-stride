# GOV-01 — Canon / Rules Guardian report for EPO03

**Workstream:** Fable 5 Executive Production Overhaul 03, branch
`fable5-executive-production-overhaul-03` from `59c4723` (v2.40).
**Supersedes nothing.** `MILESTONES/evidence/FMPO02/wave0/GOV-01_canon_guardian.md`
stands in full — §1 locks, §2 numeric constraints, §3 reserved teal, §5 change
classes, §6 forbidden list and §7 traps all still bind. This report records only
**what changed** (a new owner directive) and **what this round needs** that the
FMPO02 report did not say.

Sources read this round: `RULES.md` (whole), `PROJECT_KERNEL/05`, `06`,
`DECISIONS/0029`, `0030`, `0031`, `0032`, `JOURNAL/OPEN_QUESTIONS.md` Q-18,
Q-25, Q-28, `CLAUDE.md` "When instructions conflict",
`STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`, `Scripts/art/package-art.js`
(protection code), `WORLD_ATLAS_REMASTER_01/landmark_registry.json` +
`tools/extract_goldens.js` + `tools/reauthorize_strand_w.js`,
`assets/content/v1/atlas/atlas_layout.json`, `assets/content/v1/items.json`,
`lib/ui/icons/traveler_art.dart`, `Scripts/verify.sh`, `.github/workflows/ci.yml`.

---

## 0. The owner directive this round, and its rank

> "The owner is explicitly authorizing aggressive replacement of weak existing
> art and layout." "If a section of the atlas cannot be salvaged cleanly:
> overwrite it." "some older terrain should not be protected merely because it
> exists." "THE MAP MAY BE REPAINTED. THE REGIONS MAY BE RECOMPOSED." "some map
> zones can and should be completely replaced."

`CLAUDE.md` conflict order: **1 explicit owner instruction → 2 `PROJECT_KERNEL/`
→ 3 approved `DECISIONS/` → 4 `GAME_BIBLE/` → 5 milestone → 6 task.** The
directive is rank 1. The clauses it collides with are rank 3 (`0030` "not a
licence to touch the core") and the A-4 tooling baseline. Nothing in the Kernel
(rank 2, `05`/`06`) speaks to atlas protection, so nothing outranks the
directive on this point.

The absolute locks the owner restated are all already rules and are **not**
touched by any reading of the directive: H-1…H-7 (health accounting, granted
monotonicity, forward-only cursor, source accounting, foreground-only, no
background Health), P-5 (economy epoch is not a decay; no streaks/FOMO/decay),
P-6 (no monetization), E-3 (single-writer/CAS, save atomicity via `0012`/`0013`),
replay protection (`check-backup-exclusions.sh`), P-7 + `0020` (defeat-retreat
rules), crafting step cost (`stride_core`, step-clocked per P-4), strategic
travel identity (`0023`, routes are content).

---

## 1. Answer 2(a) — may the core be recomposed and the strand goldens re-extracted?

**Yes, conditionally.** The directive is an explicit owner instruction (rank 1)
and it directly answers what Q-18 and Q-25 both said was "an owner
authorization, not mine": whether `south_strand_w` (128,810 400×60) and
`south_strand_e` (512,810 288×60) may be re-authored and their goldens
re-extracted, and whether terrain **inside the A-4 core** (256..768)² may be
recomposed rather than only repaired in its 20 px rim. `0030`'s "not a licence
to touch the core" was the producer's reading of the *previous* directive
("recompose weak, non-protected areas"); the new directive removes that
qualifier in the owner's own words ("should not be protected merely because it
exists"). Rank 1 beats rank 3.

**What the directive does not do.** It does not amend **A-4 as a rule.** A-4 says
*approved* interiors are protected in tooling and a repair writes only its band.
The directive changes **which state is approved**, not whether approval is
protected. The mechanism the registry already defines is the mechanism to use:
*"Deliberate re-authoring of a landmark = re-extracting its golden in the same
commit; the golden's git diff is the authorization."* That pattern has run
before under a recorded authorization (`reauthorize_strand_w.js` R3b;
`iteration_02/tools/reauthorize_strand_dots.js`; the strand_e sail restore) —
each a *sliver*. This round applies it at zone scale, so it needs an ADR, not a
tool comment.

**Conditions that keep it a recorded decision and not a silent one (G-3, G-4,
G-5, RULES preamble "changing a rule requires changing its canonical source
first"):**

1. **Write `DECISIONS/0033` first** (title and content in §1.1), *before* the
   first core pixel or golden changes. Until it exists, `0030`'s carve-out is
   the standing record and a producer who repaints the core is inferring past
   G-3.
2. **The guard is re-baselined, never disabled or widened.** In
   `Scripts/art/package-art.js` the A-4 baseline is `const approved =
   base.clone()` at line 2038, taken *before* the bridge/repair layers; every
   pixel deeper than `PROT.band` (20) is restored to it and the `--check`
   drift test at ~2599 compares against it. A replaced zone must therefore be
   composited into the **master** before that snapshot (it *becomes* the
   approved state), never applied as a later "repair" layer that the guard
   then has to be loosened to accept. Changing `PROT`, `band`, `keepRepair`,
   the drift throw, or the golden compare to make a zone pass is G-4 and is
   refused. Deleting a golden instead of re-extracting it is the same defect.
3. **Goldens are re-extracted in the same commit as the zone** (`node
   GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/tools/extract_goldens.js`
   after `node Scripts/art/package-art.js`), and the commit message names the
   landmark ids whose goldens changed. A golden that changes in a commit whose
   message does not name it is an M-15 signal.
4. **The registry itself is data, not fixed.** If a replaced zone makes a
   registered landmark obsolete (e.g. the strand ceases to be a latitude band),
   `landmark_registry.json` is edited in the same commit to the *new* rect the
   owner is accepting — the registry protects the new identity, not the old
   pixels. Zero registered landmarks is not an acceptable end state for a zone
   that had one: the protected count may move, not vanish.
5. **A-3 is untouched and still decides every boundary.** "Overwrite it" is
   about scope, not about acceptance. A replaced zone ships only after a blind
   iPhone-viewport read confirms biome/coastline/detail-scale/palette
   continuity with no visible generated rectangle. Desktop composites and seam
   metrics remain triage (M-12, M-14).
6. **The single-defect loop's *acceptance* discipline still binds; its
   *minimal-correction* clause does not fit a replacement, and 0033 must say
   so explicitly.** Concretely: one zone at a time, the actual production
   atlas recomposed via `package-art.js`, the owner's iPhone verdict on that
   zone before the next zone lands on top of it, and any replacement that
   introduces a new visible perimeter is rejected rather than accumulated
   (`STUDIO_OPERATIONS/WORKFLOW.md` "World-atlas repairs", still an owner
   mandate). **Never batch unreviewed zone replacements.**
7. **Identity anchors (§2) stay in place.** Terrain may change; the places may
   not move, and each must still read as what its name says it is.

### 1.1 The record that must be written

**`DECISIONS/0033_ATLAS_REBASELINE_AUTHORITY.md` — "The approved atlas is a
state the owner may replace: re-baselining the A-4 core and the landmark
goldens under EPO03".** Next free number confirmed: `0032` is the highest file,
no `0033*` exists.

It must contain, in the `0029`→`0031` template:

- **Status / Owner / Date:** Approved — owner ruling, 2026-09-02 (quote the five
  directive sentences above verbatim as the ruling).
- **Amends:** `DECISIONS/0030` § "What this decision does NOT authorize", 4th
  bullet ("No relaxation of the atlas protections… not a licence to touch the
  core") — replaced by: the protections stand *as tooling*; the *baseline*
  they protect is the owner's to replace, zone by zone, under this decision.
  `RULES.md` A-3 and A-4 text **unchanged**; A-4's reference list gains
  `DECISIONS/0033`.
- **Resolves:** `Q-18` and `Q-25` (yes: the strand goldens may be re-extracted
  from a device-accepted result; the A-4 core may be recomposed under the
  conditions in §1). State `Q-13`'s status explicitly — either the owner
  settles the lime identity here, or 0033 records that the strand's form is
  delegated to the atlas art director *within this decision's authority* and
  Q-13 closes by that delegation. It may not be left ambiguous (G-3).
- **The exact mechanism** (§1 items 2–4): master-first compositing, same-commit
  golden re-extraction, registry edits to the accepted rect, and the sentence
  "`PROT`, `band`, `keepRepair` and the drift/golden throws are not changed by
  this decision; any change to them is a separate decision."
- **The acceptance discipline** (§1 items 5–6) and the identity anchors (§2)
  as named lists, not by reference.
- **What it does NOT authorize:** moving any `atlas_layout.json` location or
  landmark coordinate, editing `routes`, changing travel step costs or any
  content number to fit the new art; any Health/save/economy change; new
  items (§3); reward manipulation (P-5/P-6, unchanged from `0030`).
- **Invariant check** naming P-3/P-4 (no progression touched), H-1…H-7
  (nothing under `packages/stride_health`), E-2/E-5, A-1/A-2 (PixelLab
  authors, code composes), G-4 (nothing loosened), G-8 (explicit paths — the
  working tree still holds ~30 untracked exploration dirs including
  third-party reference imagery).
- **Consequences:** `RULES.md` A-4 reference line, `MISTAKES.md` M-15 gets a
  one-line "see 0033 for the authorized re-baseline path" note,
  `OPEN_QUESTIONS.md` Q-18/Q-25 → resolved, `landmark_registry.json` comment
  updated to cite 0033.

---

## 2. Answer 2(b) — identity anchors that stay in place and recognizable regardless

`atlas_layout.json`: `world` 6144×6144, `scale` 6, base tile `world/atlas_base`
1024×1024. Atlas px = world/6. **All five playable locations sit inside the A-4
core (256..768)² — that is what the core was protecting.** Recomposing the core
is repainting under the gameplay nodes, so these are the hard anchors:

| id | name | atlas px (x,y) | must still read as |
|---|---|---|---|
| `location.havens_rest` | Haven's Rest | 456, 521 | the settlement / haven; road hub of all five routes |
| `location.whispering_woods` | Whispering Woods | 383, 509 | forest (gather: woodcutting) |
| `location.stonefall_mine` | Stonefall Mine | 566, 496 | rock / mine works (see Q-21: two grounds, one key) |
| `location.forgotten_hollow` | Forgotten Hollow | 561, 551 | a hollow, perilous kind marker |
| `location.frostmere` | Frostmere | 498, 311 | frozen lake / tundra basin (M-15 erased it once already) |

Their `x,y` and `hitRadius` (72) are content; markers and hit targets are drawn
from them. **They may not move.** Moving one is a content change to
`atlas_layout.json`/`locations.json` needing World Designer review, never a
side effect of a repaint.

**Routes (travel identity, `0023`, P-9):** five polylines —
havens_rest↔whispering_woods (1 pt), havens_rest↔stonefall_mine (2),
whispering_woods↔stonefall_mine (3), whispering_woods↔forgotten_hollow (3),
stonefall_mine↔frostmere (3). A road/track must remain readable along each
polyline after any repaint; the polylines themselves are not edited to fit art.
Step costs are content, not pixel distance — they do not change.

**Minor landmarks with physical implication (both in the core):**
`landmark.stone_bridge` "Millbridge" (499, 556) — a river must exist there to be
bridged; `landmark.ferry_crossing` "Ferry Crossing" (556, 606) — water to cross.

**Future-tier landmarks (21).** Names are world content; the terrain type is in
the name and must be present at the coordinate. Inside or at the core's edge:
Glasslake (461,334) lake · Rimewatch (639,296) · Emberhold (743,288) volcanic
east · The Longwood (316,296) forest · Greenwatch (286,431) · Deepwood Shrine
(304,556) forest · Amberfield (481,628) fields · Tern Isles (711,524) islets ·
Saltreach Light (724,628) coast/lighthouse · Wolfwood (334,686) · Reedmouth
(606,686) river mouth · Marshlight (508,708) marsh · Sunken Rows (406,711).
Outside the core: The Worldspine (157,333) mountains · Wayfarer's Pass (187,542)
pass · The Frozen Shelf (445,176) ice · The White Reach (600,60) ice/snow ·
Cinder Skerries (825,181) volcanic skerries · Wanderer's Isles (830,461) islands ·
The Far Isles (970,250) islands · **Sunward Strand (511,860) — a beach.** Note
the last: it sits exactly inside the `south_strand_w/e` goldens band
(y 810–870). Fixing the "layer-cake" may turn the strand from a latitude stripe
into a coast, but *a strand must still exist at (511,860)* or the landmark is
a lie.

The 15 registry goldens are **protection rects, not identity anchors** — three
of them (`west_caravan_road`, `caravan_corridor`, `roadjoin_corridor_west`) do
protect road corridors that correspond to travel identity, and `stag_box`/
`flock_south` protect accepted world-life placements. Under 0033 they may be
re-extracted; the *routes* under them may not move.

---

## 3. Answer 2(c) — equipment items, and art vs systems

`assets/content/v1/items.json` (`kind` entries, 61 items). Equipment = 23
items in three slots. TravelerArt classes from `lib/ui/icons/traveler_art.dart`.

**Weapons (slot `weapon`, 4):**
- `item.training_sword` — T0 common — class `weapon.steel`
- `item.bronze_sword` — T1 uncommon — `weapon.bronze`
- `item.fanghilt_sword` — T1 rare — `weapon.bronze`
- `item.bronze_longsword` — T1 epic — `weapon.bronze`

**Armour (slot `armor`, 10):**
- `item.traveler_tunic` — T0 common — base body (by design)
- `item.bronze_chestplate` — T1 uncommon — `armor.plate`
- `item.wolfhide_jerkin` — T1 rare — `armor.jerkin`
- `item.tuskbound_jerkin` — T1 rare — `armor.jerkin`
- `item.waywarden_tunic` — T1 rare — **UNMAPPED → falls to base body** (gap;
  the only non-starter armour with no class)
- `item.frostlined_jerkin` — T2 epic — `armor.jerkin`
- `item.scalewarmed_chestplate` — T2 epic — `armor.plate`
- `item.bearhide_coat` — T2 epic — `armor.coat`
- `item.clawguard_coat` — T2 epic — `armor.coat`
- `item.frostwarden_coat` — T2 epic — `armor.coat`

**Tools — axe (slot `tool`, `toolKind: axe`, 4):**
- `item.training_axe` — T0 common — `tool.axe.steel`
- `item.bronze_axe` — T1 uncommon — `tool.axe.bronze`
- `item.goblin_toothed_axe` — T2 rare — `tool.axe.bronze`
- `item.hornbound_bronze_axe` — T2 epic — `tool.axe.bronze`

**Tools — pickaxe (slot `tool`, `toolKind: pickaxe`, 5):**
- `item.training_pickaxe` — T0 common — `tool.pick.steel`
- `item.bronze_pickaxe` — T1 uncommon — `tool.pick.bronze`
- `item.reinforced_pickaxe` — T2 rare — `tool.pick.bronze`
- `item.hornpoint_pickaxe` — T2 rare — `tool.pick.bronze`
- `item.tinbraced_pickaxe` — T2 rare — `tool.pick.bronze`

**Giving each existing item its own silhouette = art, allowed.** It is rows in
`TravelerArt.variantOfItem` (authored data, E-5) plus PixelLab-authored strips
(A-1) packaged deterministically (A-2), read as a pure projection off
`equipment.bySlot` (`0030` §3 — no persisted art key, no schema change,
refused if proposed). Two things must be recorded rather than done quietly:
(i) `traveler_art.dart` states the classes are "coarse by tier, never per item
(ART-05 §1)" as an art-direction decision — per-item silhouettes revise that
and the brief/0033 must cite the owner's instruction as the authority (rank 1
over rank 4); (ii) `test/equipment_projection_test.dart` asserts "no revert to
base clothes" — `waywarden_tunic` must be mapped, not exempted (G-4). L-19
still binds: bronze reads bronze, never gold bullion. L-18a: any new held-item
or body strip is drawn at the figure's density (×2, 64×64 native).

**Adding new items = not this round.** `CHANGE_MANAGEMENT.md` classes "new
item" as a *Content change* (specialist review), but an equipment item carries
`power`/`toolBonusYieldPercent`/`frostGuard`/`wildernessYieldPercent` and needs
a recipe or drop source — that is a progression/economy change (*System change*:
design + technical review + decision log), and `0030` "No gameplay-systems
expansion" stands unamended by this directive. Also: acquiring a new item makes
the save one-way against the accepted build. Refuse and record as UNRESOLVED if
proposed.

---

## 4. Answer 2(d) — next free numbers

- **Next ADR: `DECISIONS/0033`** (highest existing `0032_REDUCE_MOTION_AUDIO_CONTINUITY.md`).
- **Next open question: `Q-29`** (highest existing Q-28; `grep -c "Q-29"` = 0).
- (Next mistake entry, if one is earned: **M-19**; highest is M-18.)

---

## 5. Guard scripts that enforce the locks, and how to run them

Every command from repo root in Git Bash, after:

```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
cd /c/Users/jwspa/Downloads/ProjectStride_ClaudeCode_Handoff_COMPLETE/ProjectStride
bash Scripts/bootstrap-tooling.sh   # once per clone: Scripts/tooling node_modules (xmldom); verify.sh refuses to run without it
```

| Lock | Guard | Command |
|---|---|---|
| H-1…H-4 one step-ingestion model, granted/observed split, cursor order | `Scripts/check-step-model.sh` | `bash Scripts/check-step-model.sh --self-test` (CI runs `--self-test`; the bare production scan has a known pre-existing false positive — do not "fix" the guard, G-4) |
| E-3 single-writer / CAS, save atomicity (`0013`) | `Scripts/check-single-writer.sh` | `bash Scripts/check-single-writer.sh --self-test` |
| H-7 origin privacy | `Scripts/check-origin-privacy.sh` | `bash Scripts/check-origin-privacy.sh --self-test` |
| H-5 foreground-only Health (background-delivery entitlement ABSENT), `0009` portrait/phone/iOS 17 | `Scripts/check-ios-target.sh` | `bash Scripts/check-ios-target.sh --self-test` |
| Android policy (do not touch this round) | `Scripts/check-android-target.sh` | `bash Scripts/check-android-target.sh --self-test` |
| Replay protection — ledger never backed up/restored | `Scripts/check-backup-exclusions.sh` | `bash Scripts/check-backup-exclusions.sh` |
| H-6 no third-party health plugin | `Scripts/check-dependency-policy.sh` | `bash Scripts/check-dependency-policy.sh` |
| E-1 `stride_core` purity | `Scripts/check-core-purity.sh` | `bash Scripts/check-core-purity.sh` |
| E-2 UI boundary + raster confined to `pixel_asset.dart` | `Scripts/check-ui-boundary.sh` | `bash Scripts/check-ui-boundary.sh` |
| **A-4 protected core + 15 landmark goldens; packaging reproducible** | `Scripts/art/package-art.js` | `node Scripts/art/package-art.js --check` (run `node Scripts/art/package-art.js` to recompose, then `--check`) |
| A-2 nav `_hi` derivation | `Scripts/art/nav-active-variant.js` | `node Scripts/art/nav-active-variant.js --check` |
| L-16 reserved teal | `Scripts/art/check-art-palette.js` | `node Scripts/art/check-art-palette.js --self-test && node Scripts/art/check-art-palette.js` |
| L-18 tiled frame edges | `Scripts/art/check-tile-seam.js` | `node Scripts/art/check-tile-seam.js --self-test && node Scripts/art/check-tile-seam.js` |
| Golden re-extraction (authorization trail, 0033 only) | `WORLD_ATLAS_REMASTER_01/tools/extract_goldens.js` | `node GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/tools/extract_goldens.js` (after packaging; commit the golden diffs with the zone) |
| Guard-framework self-proofs (run by verify.sh) | `check-rulekit.sh`, `check-guard-parsers.sh`, `check-source-safety.sh`, `check-causality-framework.sh`, `check-supervisor.sh`, `registry-report.sh` | `bash Scripts/<name>.sh` |

Economy epoch, crafting step cost, defeat-retreat, P-9/P-10 and the equipment
projection are enforced by tests, not shell guards:

```bash
(cd packages/stride_core && dart pub get >/dev/null && dart analyze --fatal-infos && dart test)
(cd packages/stride_storage && dart pub get >/dev/null && dart analyze --fatal-infos && dart test -j 1)   # incl. linux_lock_semantics_test, closure_probes_test (CAS/lock proofs)
flutter analyze --fatal-infos
flutter test                                    # incl. test/equipment_projection_test.dart ("no revert to base clothes")
(cd packages/stride_health && flutter test)
bash Scripts/verify.sh                          # the whole pass in CI order; --strict to fail on a missing toolchain
```

---

## 6. New this round — what must not break that the FMPO02 report did not say

1. **The five playable locations are inside the A-4 core.** Recomposing the
   core is repainting under Haven's Rest, Whispering Woods, Stonefall Mine,
   Forgotten Hollow and Frostmere. Coordinates are frozen; biome-at-coordinate
   must match the name (§2).
2. **Sunward Strand (511,860) lives inside the strand goldens.** The layer-cake
   fix may reshape the strand; it may not delete the beach under the landmark.
3. **Millbridge and Ferry Crossing require water at fixed coordinates.**
4. **Re-baselining is master-first.** A replaced zone becomes the `approved`
   snapshot (line 2038) — it is never a repair layer the guard is loosened to
   accept. `PROT`/`band`/`keepRepair`/drift throw/golden compare are not
   edited under 0033.
5. **Goldens are re-extracted, never deleted; the registry moves, never
   empties.** Same commit, commit message names the ids.
6. **0033 must exist before the first core pixel changes**, and must state
   Q-13's status and that the single-defect loop's *acceptance* discipline
   (one zone, device verdict, no accumulation) survives the "overwrite"
   authority.
7. **`waywarden_tunic` is unmapped** in `TravelerArt.variantOfItem` — a
   per-item silhouette pass must include it; exempting it from
   `equipment_projection_test.dart` is G-4.
8. **No new items this round** — a new equipment item is a System change
   under `0030`'s standing "no gameplay-systems expansion"; the directive
   authorizes art and layout replacement, not content growth.
9. **The ~30 untracked exploration dirs are still on disk** (G-8/M-08); this
   branch adds a fresh `MILESTONES/evidence/EPO03/` tree — stage by path.
