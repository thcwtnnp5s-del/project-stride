# 0031 — Density is a property of a plane: the L-18a amendment

**Status:** Approved — **owner ruling, 2026-09-01**
**Date:** 2026-09-01
**Owner:** Project owner (explicit, in writing, continuing
VISUAL_AUDIO_WORLD_OVERHAUL_01)
**Amends:** `GAME_BIBLE/ART/ART_DIRECTION.md` **L-18**, adding **L-18a**
**Related:** `RULES.md` A-1, A-2, G-3 · `DECISIONS/0029`, `0030` ·
`GAME_BIBLE/ART/exploration/VAWO01/GATHER_SCENE_DIRECTION_01.md` § 3

---

## Context

L-18's first paragraph — integer scale, nearest-neighbour, no sub-pixel
positioning — governs **one asset at a time**. It is silent on what happens when
two assets of different native densities are composited into one frame, because
until the gather stage there was no case where that mattered.

The gather stage is that case, and the audit measured it. A gather scene draws:

| Layer | Native | Scale | One source pixel is |
|---|---|---|---|
| Backdrop | 384 × 176 | ×1 | 1 logical px |
| Subject (ore, tree, plant) | 96 × 96 | ×1 | 1 logical px |
| **Traveler** | 64 × 64 | **×2** | **4 logical px of area** |

Every asset satisfies L-18 individually. The composite does not read as one
place: the character's pixels are four times the area of everything he is
standing on and hitting, and the owner's word for the result was
**"mismatched"**.

`FOUNDATION_H_GATHER.md` flagged this as GH-05 and explicitly declined to settle
it, because the answer fixes the native size of every plate in the gathering
production round and is therefore a design decision, not an implementation
detail (`RULES.md` G-3). The owner has now settled it.

## Decision

**L-18a is added to `ART_DIRECTION.md`, immediately after L-18:**

> **L-18a — Density is a property of a PLANE, not of a frame.**
>
> Every element that shares a ground line with the figure, overlaps it, or is
> crossed by its tool arc is drawn at **the figure's density**. The single
> backdrop plate behind them stays at its own. **No asset may be drawn at a
> lower density in front of the figure.**
>
> In the composition that exists today that means: backdrop ×1, subject ×2,
> figure ×2.

The consequence for production, stated so it is not re-derived: **gather subject
plates are authored 48 × 48 native and drawn ×2.** Their footprint on screen is
96 dp — *identical to today* — so this is a change of authored resolution, not
of layout.

## Reasoning

- **A density mismatch is only legible where two densities meet at an edge.**
  The subject and the figure share a ground line, overlap by 40–55 dp, and the
  tool crosses the subject roughly twice a second for the whole of a 48 s–3 min
  gather. The backdrop touches neither; its finer staircase reads as *further
  away*, which is ordinary detail perspective — a painted flat behind built set
  pieces. **Today's arrangement is that cue inverted**, and that is precisely
  why it reads as wrong rather than merely as inconsistent.
- **This adds a constraint; it weakens nothing.** L-18 as written permits both
  ×1 and ×2, so a scene could previously be assembled either way by accident.
  L-18a removes the accident. `RULES.md` G-4 is not in play — nothing is being
  loosened to make anything pass.
- **The alternative was measured and is worse.** Levelling everything to one
  density means re-authoring the backdrop family at 192 × 88 — which is not six
  plates but sixteen, because **all ten accepted location vignettes** share that
  family and every one of them has passed a device read. Re-risking ten accepted
  paintings to fix a P1, on a workstream whose own thesis names blind review as
  the scarce resource, fails `RULES.md` G-1 on proportionality.
- **48 is the proven canvas, and 96 is the provenance of the defect.** The
  style spec's six-generation probe settled 48 × 48 as the working canvas for
  scene elements. 96 was never chosen as a family size — it arrived because the
  node *vignette* was 96 and the fallback reached for it, which is the same
  accident that put twelve inventory-icon plates on the stage.
- **It is what lets the grounding fix keep working.** `ContactShadowSpec` is
  expressed in **native pixels** — spread 3, inset 1, bleed 4. Those constants
  only mean the same number of device pixels on two canvases if the canvases
  share a scale. Without L-18a the shadow spec would have to fork per family,
  and a forked shadow spec is how a shadow drifts out of agreement with the
  figure standing on it.

## What this decision does NOT authorize

- **No change to the backdrop family.** 384 × 176 at ×1 stands, and the ten
  accepted location vignettes are untouched.
- **No re-scaling of an existing asset to comply.** A 96 → 48 nearest downscale
  destroys a one-pixel outline; the six incumbent props are **re-authored**, not
  resampled. Resampling would also not be A-2 — it invents the pixels it keeps.
- **No third density.** Two planes, two scales. A future element that fits
  neither is a question for this decision to be amended by, not a third case to
  be added quietly.
- **No relaxation of L-18's first paragraph.** Integer scale, nearest-neighbour
  and non-compressible containers bind exactly as before, and now bind a family
  that previously had no rule about how its members related.

## Consequences

- **18 plates in the shippable round**, not the audit's 9. The 9-plate plan was
  enumerated against the real node table and yields **11 distinct scenes across
  22 nodes — one fewer than today's 12**, because today's count is inflated by
  the *accidental* variety of six icon fallbacks that happen to differ from six
  props. Replacing them correctly makes every scene right and the count go down.
  The owner has ruled explicitly against collapsing back to 9.
- **Six existing props are re-authored at 48**: meadow, duskcap, oak, copper,
  tin, hardened copper. Their 96 originals are kept in `rejected/` with this
  decision cited, not deleted.
- **`StageScenery.native` becomes 48 for subjects**, and `_prop` draws at
  scale 2. The measured-footprint grounding from `514dc73` carries over
  unchanged — it reads the plate that ships, whatever its size.
- **`gather_grounding_test.dart`'s ratchets tighten** as plates land: 17
  duplicate nodes and 12 distinct plates today, 0 and 22 at the end of the
  round.

## Invariant check

**L-18** first paragraph: unchanged and now governs a relationship it did not
reach. **L-15/L-16/L-17**: untouched; the palette guard already measures the
teal reserve across every new plate. **A-1**: PixelLab authors every plate;
this decision only fixes their dimensions. **A-2**: the re-authors are
generations, not resamples, precisely because a resample would not qualify.
**P-1** mobile-first: the on-screen footprint is unchanged at 96 dp, so no
layout moves and no phone width is affected. **Health, steps, economy, save
format:** untouched — this decision reaches nothing outside art dimensions.
