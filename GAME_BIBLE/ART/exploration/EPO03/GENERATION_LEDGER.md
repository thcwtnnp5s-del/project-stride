# EPO03 — PixelLab generation ledger

Live `get_balance` at open (2026-09-02): **7,989 remaining / 2,010 used / 10,000 total** (Tier 3 Pixel Architect, resets 2026-10-01). Credits $0.00.

**Accounting rule (M-17).** Only the balance checkpoints below are facts. Every
family figure is the lead's own **sum of the tool's cost lines** (`cost: ~20
generations`), never a balance delta — more than one agent holds this account at
once, and a delta taken mid-round is the round's number, not a family's. A unit
cost that will drive a cut is checked against one isolated job first.

Per-family ledgers: `ledger/<FAMILY>.md`, one row per job: what was asked, the
tool, the job id, the cost line, the verdict (ACCEPT / REJECT / RE-ROLL /
REPLACE SECTION) and the reason. Rejected rolls keep their reason so a re-roll
never repeats them (M-05).

## Target allocation (owner brief, approximate)

| Family | Target |
|---|---:|
| World recomposition (regions) | 700–1,000 |
| World landmarks / life | 350–600 |
| UI | 450–700 |
| Character / equipment | 250–450 |
| Items | 150–300 |
| Gathering / encounters | 150–300 |
| Reward / other | 100–200 |
| **Session target** | **2,000–3,000** |

## Balance checkpoints (live `get_balance`)

| When | Remaining | Used this round | Note |
|---|---:|---:|---|
| open, 2026-09-02 | 7,989 | 0 | Tier 3, resets 2026-10-01 |
| wave 2 launched (19 teams), 2026-09-02 | 7,962 | 27 | first probes in flight |
| after the session-limit outage, all 19 teams resumed | 7,624 | 365 | every team had committed sources; no active jobs lost |
| second outage; L3 landed and committed; batching to 4 teams at a time | 7,536 | 453 | 19 concurrent agents exhaust the session limit in minutes — the round now runs in batches |
| south territory complete, kit frames landed, checkpoint 1 | 7,112 | 877 | 6 atlas regions accepted (S1,S2,S3,SA1,L3,L2); packaging 1,971 files |

## Family totals (each lead's own sum of cost lines)

| Family | Requested | Accepted | Rejected | Visible value |
|---|---:|---:|---:|---|
| _(filled by the leads)_ | | | | |
