# VAWO01 — Visual / Audio / World Overhaul 01, art production workspace

**Authority:** `DECISIONS/0030_VISUAL_AUDIO_WORLD_OVERHAUL_SCOPE.md`
**Queue:** `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` (UI batches A–I)
**Style:** `GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md`
**Direction:** `GAME_BIBLE/ART/ART_DIRECTION.md` (outranks everything here)

## Budget of record

Verified live at workstream open, 2026-09-01, per precondition P-0:

```
generations_remaining: 10000   generations_used: 0
subscription: Tier 3 (Pixel Architect)   reset: 2026-10-01
```

A remembered balance has been wrong three times in this project's history.
`get_balance` is called at the start of every production session, and the
figure above is a record of one reading — never a substitute for the next one.

## Layout

| Directory | Tracked | Holds |
|---|---|---|
| `out/` | yes | Selected, packaged-from sources. A clean checkout needs these. |
| `src/` | yes | Job arguments and crop parameters. |
| `tools/` | yes | Deterministic transformation scripts (A-2). |
| `review/` | yes | Render sets and blind-review verdicts. |
| `rejected/` | yes | Rejected rolls **with their written verdict**. |
| `raw/` | **no** | Unselected candidate dumps. Local only. |

`rejected/` is tracked deliberately: a rejected roll with a recorded reason is
the evidence the next round is built on, and re-learning a rejection costs
generations (`MISTAKES.md` M-05).

## The rule that governs every file here

`RULES.md` A-1 — PixelLab authors; Claude art-directs, prompts, selects,
rejects, and transforms deterministically. A-2 — crop, integer scale, keying,
sheet assembly and palette remap are permitted **only where they invent no new
object, silhouette, animation frame or illustrated content**.

Nothing in this directory is production art until it is packaged, declared, and
has passed a blind read at device scale. A seam score is triage (A-3).
