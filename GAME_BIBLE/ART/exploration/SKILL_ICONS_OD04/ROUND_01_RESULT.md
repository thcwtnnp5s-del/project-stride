# OD-04 Round 01 — QA VERDICT: **FAIL**. Not shipped.

**Date:** 2026-08-17 · **Spec:** `GAME_BIBLE/ART/SKILL_ICON_SPEC_01.md`
**Author:** orchestrator · **QA:** Visual QA, blind read, independent
**Outcome:** the five current `assets/ui/v1/skill_*.png` **stay in place**. No
asset from this round reached the app.

---

## The result in one line

The set passed the acceptance case it was written for and failed one nobody had
written down: **Cooking and Smithing separated cleanly, and Woodcutting and
Mining collapsed into each other at play scale.**

## What was produced

One round, five icons, generated against the frozen spec at 48 × 48 and reduced
to 12 × 12 (`reduce.js`). Sources and reductions are in `out/`. They are kept as
evidence, not as candidates.

## What QA found

| Sev | Plates | Finding |
|---|---|---|
| **BLOCKER** | Woodcutting, Mining | Read as **the same kind of object** at ×2. Both are "a horizontal metal head on a vertical shaft"; the head shape that distinguishes them is 1–2 px and is the first thing lost. A viewer sees the same icon twice. |
| MAJOR | Woodcutting, Mining | No containing outline, ~⅓ canvas occupancy — visibly lighter than the anvil and pot, so the set splits into two drawing conventions. |
| MAJOR | Smithing | The horn is the anvil's only diagnostic feature and is sub-perceptible at ×2. It reads as "a grey block". |
| MAJOR | all | No shared light direction; three perspective conventions across five icons. |
| MINOR | Smithing, Cooking | Separable by **hue only** — which §4 of the spec forbids. |
| MINOR | Foraging | Detached orphan pixels at the foliage extremes, failing A6. |

Only **Foraging** was defended unreservedly, and **Cooking** held its object
class. The pot/anvil case — the one the spec named as pass/fail — **passed**.

## The finding worth carrying, and it is not "try harder"

> **Two hafted tools cannot be told apart at 12 × 12.**

The spec's §3 tried to separate Woodcutting and Mining by the *shape of the
head*: one blade on one side versus two symmetric points. That is a correct
distinction and it is a real one at 48 px. At 12 it does not exist — both
reduce to a bar over a stick, and the difference lives entirely in pixels the
reduction cannot keep.

This is the M-05 lesson arriving in a new place. The round was authored and
self-reviewed at ×8, where the two are obviously different objects. The ×2 proxy
is what found it, and it found it immediately.

**So the next round must separate them by silhouette *family*, not by head
geometry.** Two candidate directions, neither chosen here:

- Mining stops being a tool. An **ore chunk** or a **cut rock face** is a mass,
  not a T-shape, and cannot be confused with an axe at any size.
- The axe head carries **large asymmetric bulk** — a broad blade occupying a
  third of the canvas — so the silhouette is lopsided rather than symmetric, and
  survives reduction as a shape rather than as a detail.

A third possibility worth costing: if two icons in a five-icon set must be
hafted tools, the set may simply be the wrong idea, and skills might be better
represented by their **material** (log, ore, herb, ingot, bread) than by their
implement. Materials are masses; tools are sticks.

## Process findings

- **The staging leaked.** QA named it unprompted: the directory is
  `SKILL_ICONS_OD04`, which told the critic these were skill icons before it saw
  a pixel, priming it toward tool shapes. The plates were also labelled `A`–`E`,
  an ordinal sequence implying `A` is the lead. Neutral staging means an opaque
  directory and opaque tokens. `NEUTRAL_STAGING_CHECKLIST.md` exists; it was not
  followed here.
- **The author must not pick the candidates *and* judge the set.** Five
  candidates were chosen from sixteen by the author on a ×8 view — which is the
  same error one step earlier in the pipeline than M-04 describes. Candidate
  selection should also happen at ×2.

## Spec amendments this round earns

`SKILL_ICON_SPEC_01.md` §3 should gain, before the next round:

1. **No two icons in the set may share a silhouette schema.** "Head on a shaft"
   is one schema and may be used at most once.
2. **The distinguishing feature must be at least 3 px in its smallest
   dimension**, at 12 × 12, or it does not exist at play scale.
3. **Candidate selection happens at ×2**, on the reduced file, before any ×8
   view is looked at.

These are not applied to the frozen §3 here, because amending a spec and
re-running the round is the next session's work and the spec should record what
this round was actually judged against.

---

## OD-03 — the step mark, same round, same outcome

One generation, sixteen candidates: two footprints side by side. **Not shipped,
and not taken to blind QA**, because it fails the same test on inspection —
two separate footprints at 12 × 12 are two 5-px masses with a gap, and the gap
is the first thing to close under reduction. The result would be one blob.

The brief for the retry is now sharper than it was: the mark must be **one
connected mass at 12 × 12**, which means the two prints have to overlap enough
to touch, or the mark should be a single print rather than a pair. The current
turquoise boot glyph stays until a round produces that.

**Both OD-03 and OD-04 remain open** in `JOURNAL/OPEN_QUESTIONS.md`, now with a
specification and a failed round behind them instead of only a complaint.
