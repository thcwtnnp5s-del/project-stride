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

_(filled from wave 0: locks, seams, protection mechanics, tool capability,
audio go/no-go; the ADR that records the atlas replacement authority)_

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
