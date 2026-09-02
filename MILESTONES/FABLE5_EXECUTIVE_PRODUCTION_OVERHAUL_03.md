# Fable 5 Executive Production Overhaul 03 (EPO03)

**Opened:** 2026-09-02 · **Branch:** `fable5-executive-production-overhaul-03`
(from `fable5-mega-production-overhaul-02` @ `59c4723`) · **Status:** in
production · **Authority:** the owner's EPO03 directive (2026-09-02), quoted in
§1; `DECISIONS/` entry recorded in §4 · **Not merged.** The physical iPhone
remains the final authority.

Evidence: `MILESTONES/evidence/EPO03/wave0..3/` (guardians, directors,
producers, QA), `GAME_BIBLE/ART/exploration/EPO03/` (sources, accepted art,
review renders, rejected rolls with verdicts, per-family ledgers).

## 1. The verdict this answers

The owner's physical-iPhone read of `59c4723` (FMPO02 closeout, v2.40):
typography, Character, Inventory, gathering architecture, equipment
projection, encounter staging, Craft structure, some world regions and the
visibility of world life are **better**. Not good enough: the world still
reads stitched in places with uneven biome transitions; fantasy landmarks and
world life are not convincing; the UI is still systematised dark cards
("Claude generated"), Skills detail stacks rectangles, Craft's locked half
becomes a spreadsheet, the bottom nav is plain, the World sheet hides the map;
equipment must become fully convincing with no fallback; audio is incomplete.

The owner's explicit authority for this round, verbatim:

> "The owner is explicitly authorizing aggressive replacement of weak existing
> art and layout in order to reach a substantially higher quality bar." · "If a
> section of the atlas cannot be salvaged cleanly: overwrite it." · "some older
> terrain should not be protected merely because it exists." · "THE MAP MAY BE
> REPAINTED. THE REGIONS MAY BE RECOMPOSED. THE UI MAY BE REBUILT. THE OLD CARD
> STRUCTURE MAY BE REMOVED."

Acceptance target: **"This feels like a much more finished game."**

## 2. Doctrine

1. **Quality over preservation.** A weak region, screen or asset is replaced,
   not defended. Sunk cost is not an argument.
2. **Coherence over history.** Where a patch made a seam, both sides are
   re-authored as one transition; where a region is compositionally broken,
   the region is repainted, not the seam.
3. **Visible player value over internal cleverness.** A generation is
   justified only by what the phone shows.
4. **Protection stays in tooling.** Replacement inside a protected zone is
   done by re-basing the protected state in code (a new approved interior and
   re-extracted goldens in the same commit), never by weakening the guard
   (G-4, A-4).
5. **The single-defect loop stands for the atlas** (`STUDIO_OPERATIONS/
   WORKFLOW.md`, "World-atlas repairs"): one region → composite → guards →
   full atlas + ×2 perimeter + phone FOV → verdict → next.
6. **Nothing in the locks moves.** Health, ledger, save, epoch, replay,
   single-writer, sync policy, craft step cost, defeat rules, no-FOMO,
   strategic travel.

## 3. What landed, by commit

| Commit | What |
|---|---|
| _(filled as the round lands)_ | |

## 4. Facts proven before spending

Six guardians (`MILESTONES/evidence/EPO03/wave0/`), then sixteen directors
(`wave1/`), before any generation:

- **Canon (GOV-01).** The directive is a rank-1 owner instruction; it answers
  Q-18/Q-25 and changes *which state is approved*, not A-4. Recorded as
  `DECISIONS/0033`. All five playable locations sit inside the core with
  frozen coordinates; the Sunward Strand landmark must keep a beach; routes
  are content and never edited to fit art. Equipment: 23 items (4 weapons,
  10 armour, 4 axes, 5 pickaxes); per-item silhouettes are art; new items are
  not this round. `waywarden_tunic` was unmapped in the resolver.
- **Boundary (GOV-02).** Do-not-touch list verified at HEAD; every mutation
  flows through `SessionController`; save state v9 cannot be reached by
  assets, overlays, strips or layout JSON. Guards: core-purity,
  single-writer, origin-privacy, backup-exclusions, dependency-policy PASS;
  `check-ui-boundary.sh` fails on the pre-existing `craft_memory.dart`
  violation (CI red before this round); `check-step-model.sh`'s production
  scan carries 13 pre-existing false positives. 1,049 app / 738 core / 143
  health tests green at 59c4723.
- **Atlas mechanics (GOV-03).** The EPO03 layer must run after the ghost-sail
  restore and before the water-only conform (so crops and substrate are the
  same image), mark its pixels `claimed`, re-take `approved`, and the drift
  guard must walk the whole canvas. Golden overlaps per candidate zone
  measured; a golden is re-extracted from an `ATLAS_DUMP` pre-guard
  composite. Build 6–7 s; concurrent builds corrupt reads → the build lock.
- **Pipeline (GOV-04).** Real FMPO02 costs: pixen 1 at every size; pro 40;
  edit_image ≈20 per call (whole frame grid); inpaint 20/25/40 by size;
  animate_image 1–2; character state ≈44; map object ≈32. Hosting by commit
  SHA on raw.githubusercontent; inline base64 caps ≈5 KB. Overlays: frame
  loop, cadence, drift and straight travel exist; **no waypoint path, no
  per-overlay scale** — DIR-04 specified the path schema LIFE builds.
  Device render: `SCREEN_EVIDENCE_DIR=… flutter test test/screen_evidence_test.dart`
  (393×852 @ DPR 1).
- **UI (GOV-05).** Single-owner list for the kit files (PROD-UI-NAV); combat
  is a child of Adventure's list, not a route (branch frozen); one golden test
  renders all six tabs — producers prove with evidence renders, the producer
  regenerates goldens once; registries are name-guarded.
- **Audio (GOV-06).** **No-go.** `STABILITY_API_KEY` unset; ElevenLabs is
  permitted by 0005/0030 but has no runner and no key; procedural synthesis
  is forbidden by the locked direction; nothing in `AUDIO/evaluation/` is
  packageable. 22 files owed (combat 11, craft 3 + 1 swap, gathering 1,
  reward 5, UI 1). Recorded once; DIR-14 named three zero-file improvements
  (haptics on Attack/Eat/Retreat, the telegraph cue's segment, a doc fix).

## 4a. First executive checkpoint

Taken with six atlas regions accepted and the interface kit landing.

**Is enough visible production shipping?** Yes, and the largest item is the
one the owner named first. The south territory is complete: four regions
replaced the latitude stripe with a coast that follows terrain — measured,
sand in the old belt 172–440 × 810–870 fell **31.9 % → 2.3 %**, and the
Sunward Strand anchor went the other way, 2.3 % → 49.5 %, so the landmark
still stands on a beach. The shore bends, with surf, angled dunes, machair,
a creek at a rock headland, braided channels into flats and a spit hooking
south. Three landmark goldens were re-extracted under `DECISIONS/0033`;
all fifteen hold and protected-interior drift is 0.

**Has the world materially changed?** Yes. Beyond the south: the Ice-Mage
Tower is no longer an icon on flat snow but an ice bastion on a glacial
foundation with a pillared causeway (L3), and the Storm House now sits in
its own dark grove on a headland with lit windows (L2).

**Has the UI structurally changed?** Partly, and this is the gap. The
bottom navigation — which the owner called one of the least authored parts
of the game — is rebuilt: a leather strap running into the home-indicator
inset, stamped icon wells, and a raised lit plate that breaks the stitched
welt. The shared kit is landing. **The screen rebuilds are the weakest area
of the round so far** and are the next priority as capacity frees.

**Was PixelLab used productively, and did weak work survive because
replacement was inconvenient?** One correction was needed and made. The kit
owner declared the frame and mark families closed after 31 rejected rolls,
leaving 288 generations unspent — exactly the outcome the directive forbids.
Two of the three failure reasons were sound tool limits; the third was not:
four assets had been rejected for brightness alone, which this repository
already fixes deterministically (`49c91f9`, and `RULES.md` A-2). Sent back,
the four shipped for **zero generations**, and a tool the pass had never
tried — `create_image_pro` with an accepted grain as a labelled style
reference — produced all three frame families **on the first call**, 60
generations for the set. The "frame class is closed" conclusion was
retracted in the ledger in place. The measured tool facts are now in
`wave2/PRODUCTION_RULES.md` §2a so no later team pays for them again.

**Course correction applied.** Nineteen concurrent producers exhausted the
session usage limit twice, killing every team mid-flight; the round now
runs four at a time, and every team commits after each accepted item and
records job ids at submission, because a submitted job survives the outage
and can be re-fetched rather than re-rolled (§9a).

## 5. Budget ledger

Opened at **7,989** (live). Family figures are leads' own cost-line sums;
checkpoints are in `GAME_BIBLE/ART/exploration/EPO03/GENERATION_LEDGER.md`.

## 6. Known gaps, named

_(filled at closeout — never softened)_

## 7. Physical iPhone acceptance checklist

_(filled at closeout — every step names a control that exists in the build)_

## 8. Reviewer verdicts

_(FINAL-A … FINAL-M)_

## 9. Closeout

_(the 36-item return)_
