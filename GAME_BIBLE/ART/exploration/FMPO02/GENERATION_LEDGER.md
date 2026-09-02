# FMPO02 — PixelLab generation ledger

Live `get_balance` at open (2026-09-01): **9,762 remaining / 238 used / 10,000 total** (Tier 3, resets 2026-10-01).

Every row: what was asked, the tool, the cost class, and the verdict with reason. Rejected rolls keep their reason so a re-roll never repeats them (M-05).

| # | Family | Tool | Job / id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | equipment probe | create_character_state (Bronze Plate → + bronze pickaxe, 80x64) | 0f7a53bf | 20–40 | pending | does a state carry a held tool reliably? |
| 2 | ui surface probe | pixen 64² parchment tile | 7c99a997 | 1 | pending | |
| 3 | ui surface probe | pixen 64² oiled leather tile | b52ef2ec | 1 | pending | |
| 4 | landmark probe | pixen 96x80 fairy castle | a8efddfd | 1 | pending | |
| 5 | world life probe | pixen 96x64 red dragon still | b21f2836 | 1 | pending | |
| 6 | encounter probe | pixen 192x76 forest floor band | 4f3d3a3d | 1 | pending | |

## Balance checkpoints (live `get_balance`)

| When | Remaining | Used this session | Note |
|---|---:|---:|---|
| open, 2026-09-02 | 9,762 | 0 | Tier 3, resets 2026-10-01 |
| wave 2 launch + ~25 min | 9,217 | 545 | 8 production leads + combat stage lead running; 17 jobs active |

Per-family ledgers: `ledger/<FAMILY>.md` (written by each PROD lead). Probe verdicts:
1 ACCEPT (state carries tool; west mine swing keeps armor + pick in 8/8 frames), 2–3 REJECT (busy weave / directional stripe — not ≤6 L*), 4 ACCEPT (fairy castle glade reads at 96×80), 5 ACCEPT (+ wingbeat loop f87ddf27, 9f clean), 6 ACCEPT (forest floor band; handed to PROD-ENEMIES), plus two 32² tile rerolls REJECT (speckle, dither checkerboard).
| after all PROD leads + integrators | 8,297 | 1,465 | terrain 455 (9 regions + 2 bridges), equipment 909 + 11 brace + 3 re-dress edits (60) + 1 tool swap (20), UI 95, items 72, gather 180, enemies 43, world life 60, rewards 21, combat stage 130, NB2 20 |
| producer closure (steel column, busts) | — | +~131 | 6 steel-head text edits (~120) on the accepted bronze strips; 4 portrait edits (jerkin, coat accepted first roll; plate re-rolled once for gold→bronze) |
| council fixes in flight (craft re-dress ≈120, crates 3, WORLD-FIX partway) | 8,018 | 1,744 | live get_balance 2026-09-02 |
| closeout, 2026-09-02 | 7,989 | 1,773 | craft re-dress ≈120, crates 3, WORLD-FIX 184 (see ledger/WORLD_FIX.md) |

Closing figure recorded at closeout (see §9 of the milestone record).

## Reconciliation (FINAL-11, 2026-09-02)

**The per-family figures above do not reconcile and the live balance is the
only authoritative total.** Summed per job, the family ledgers come to
≈2,076–2,238 against a live delta of ≈1,600; the discrepancy is the
Equipment lead recording the shared-account delta (9,551 → 8,642 = 909) as
its own spend, the exact error this ledger warns every lead about. By
subtraction Equipment's real spend is ≈500, which also means an 80×64
`create_character_state` cost ≈44 generations, not the ≈120 the lead
reported — a figure that drove the round's biggest cut (the steel tool column,
later closed for ≈120 generations of text edits). Only the balance checkpoints
are facts; every family row is a lead's own report.
