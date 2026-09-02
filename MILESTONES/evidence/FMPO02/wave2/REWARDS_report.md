# REWARDS_report — FMPO02 wave2 (PROD-REWARDS)

Balance: open 9,551 / 449 used → close 9,102 / 898 used (shared account; this
family spent 21 generations of its 90 cap). Full job-by-job ledger:
`GAME_BIBLE/ART/exploration/FMPO02/ledger/REWARDS.md`.

## Accepted → `out/reward/`

| File | Native canvas | Reads as |
|---|---:|---|
| `mark_rare_drop.png` | 24² | a round-bottomed cloth sack cinched at the neck with a knotted cord — rarity-neutral, no gem/star/coin |
| `seal_signature.png` | 96×48 | a rectangular leather plate, 4 rivets, stitched border, 3 diagonal claw gouges |
| `seal_masterwork.png` | 96×48 | a dark wood plank with a bronze medallion stamped with crossed hammer-and-tongs |
| `grain_notable_plate.png` | 32² | a seamless, low-contrast warm dark parchment tile (mirror-folded, deterministic — 0 extra generations) |

All four were reviewed on `review/reward/final_incontext_x4.png`, a sheet
beside all 10 shipped `RewardArt` marks at ×2 and ×4 on `#14120F`. They read
as one family with the shipped set: same outline weight, same upper-left key
light, ≤4 values per material, no coin/gem/star/timer in any of them, zero
partial-alpha pixels, bronze reads reddish-copper (checked against
`badge_milestone`/`plate_level_up`), no `#58D6C0`.

## RewardArt table rows for the integrator

Add to the table in `MILESTONES/evidence/FMPO02/wave1/ART-10_reward_brief.md`
§1 / wherever `RewardArt` is enumerated in code:

| Mark | Canvas | Placement (file → widget) |
|---|---:|---|
| `mark_rare_drop` | 24² beside type | `activity_result.dart` → `_MarkedLine`, new line shown when output rarity ≥ Rare, above the XP line (per ART-10 §1) |
| `seal_signature` | 96×48 banner | `RewardLayer.emblem` (needs the optional `emblemSize` parameter ART-10 §3 describes — 96×48 for this and masterwork only), `RewardTier.major`, signature/one-of-a-kind drops |
| `seal_masterwork` | 96×48 banner | `RewardLayer.emblem`, `RewardTier.major`, masterwork completion only |
| `grain_notable_plate` | 32² tile, seamless | `PixelFrame.surfacePath` (not yet wired — `PixelFrame` doesn't render `surfacePath` per ART-10 §3/record §7) — draw under the card body only when `notable`, tinted by `RarityStyle.accent` at ~12–15% alpha via `ColorFiltered`, 32×32 native tiled at the same density as other ART-02 surfaces |

No Dart or `package-art.js` was touched (out of this task's scope) — the
integrator wires these four files in.

## Not produced, and why

- **`mark_craft_done`** — **not generated.** The task list asked for a
  "finished-item tag" mark, but the canonical brief
  (`ART-10_reward_brief.md` §1) explicitly rules this out: *"Craft completion
  gets no new asset — the record's notable escalation (rarity ink + bracket)
  already is that language... A mark per craft repeats eleven unrelated
  borders one family later."* Per `CLAUDE.md`'s conflict order, the current
  milestone's brief outranks an individual task instruction, so I did not
  generate it and did not silently decide the design question either way.
  Recorded **UNRESOLVED** in `JOURNAL/OPEN_QUESTIONS.md` for the owner.
- **`plate_project`** — **not generated, by design.** `seal_project`
  (existing, shipped, already wired to `board_card.dart` on project
  completion) reads clearly on its own: a teal medallion with a
  set-square/ruler stamp, silhouette distinct from `seal_contract`'s scroll.
  Verified at ×8 (`review/reward_seal_project_x8.png`) before deciding to
  skip rather than ship a redundant asset.

## Flagged, not fixed (out of scope for this task)

`seal_project`'s fill colour is teal — in the reserved `#58D6C0` family that
`ART-01_executive_doctrine.md` §3 reserves for walking (L-16/L-19). This is a
pre-existing defect in an already-shipped asset, not something introduced or
touched this round; fixing it would mean re-generating and re-wiring a
placed, working mark, which is outside this task's four-item scope. Flagged
for a separate owner-scoped fix.

## UNRESOLVED

Recorded in `JOURNAL/OPEN_QUESTIONS.md`: whether `mark_craft_done` should
exist at all, given the direct task instruction conflicts with ART-10's
explicit design reasoning against it. Needs the owner's ruling before any
future round spends generations on it.
