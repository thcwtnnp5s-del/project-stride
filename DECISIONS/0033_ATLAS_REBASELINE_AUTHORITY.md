# 0033 — The approved atlas is a state the owner may replace: re-baselining the A-4 core and the landmark goldens under EPO03

**Status:** Approved — **owner ruling, 2026-09-02** (the EPO03 directive,
quoted below)
**Date:** 2026-09-02
**Owner:** Project owner (explicit, in writing, opening
FABLE5_EXECUTIVE_PRODUCTION_OVERHAUL_03)
**Amends:** `DECISIONS/0030` § "What this decision does NOT authorize"
(fourth bullet — the frozen core and the goldens are "not a licence to
touch") · the `landmark_registry.json` comment's "deliberate re-authoring =
re-extracting its golden in the same commit" is confirmed as the mechanism
**Resolves:** `JOURNAL/OPEN_QUESTIONS.md` **Q-18**, **Q-25** (the south strand
goldens), **Q-13** (the lime band, by the directive's coast specification),
**Q-28** (the fairy motes, by the directive's "fairies read as fairies")
**Related:** `RULES.md` A-2, A-3, A-4, G-3, G-4 · `MISTAKES.md` M-12, M-14,
M-15 · `STUDIO_OPERATIONS/WORKFLOW.md` "World-atlas repairs" ·
`MILESTONES/FABLE5_EXECUTIVE_PRODUCTION_OVERHAUL_03.md`

---

## Context

`RULES.md` A-4 protects the approved atlas interior in tooling: the
composition pipeline snapshots the approved core (256..768)² before any
repair layer, restores every repair pixel deeper than a 20 px rim band, and
fails packaging on any core drift; fifteen landmark goldens do the same for
features outside the core. The rule exists because M-15's seam repairs
silently erased the Frostmere basin and the volcano's towers. It has held
since World Atlas Restore 01.

The protection has a documented cost (Q-18, Q-25): the south "layer-cake"
strand at y 810–870 is held byte-for-byte by two goldens, the west forest
wall at x≈256 sits inside the core's rim, and the rim's own hash dither turns
any *content change* there into a speckled column. FMPO02 authored the south
and west *around* those zones and named the residue as owner debt.

On 2026-09-02 the owner opened EPO03 with an explicit, written ruling:

> "The owner is explicitly authorizing aggressive replacement of weak
> existing art and layout in order to reach a substantially higher quality
> bar." · "If a section of the atlas cannot be salvaged cleanly: overwrite
> it." · "some older terrain should not be protected merely because it
> exists." · "some map zones can and should be completely replaced." ·
> "If a previous map section is compositionally broken: repaint the region,
> not the seam." · "THE MAP MAY BE REPAINTED. THE REGIONS MAY BE RECOMPOSED."

Under `CLAUDE.md` "When instructions conflict", an explicit owner instruction
ranks above `DECISIONS/` and `GAME_BIBLE/`. It directly answers Q-18 and
Q-25. Recording it here is what makes it a decision rather than an inference
(G-3).

## Decision

1. **The approved atlas interior is a state, and the owner has replaced its
   authority for this round.** Under EPO03, a region inside the A-4 core, or
   a zone covered by a landmark golden, may be re-authored — retouched,
   recomposed, or fully replaced — when the round's World Atlas Creative
   Director judges the existing terrain weak and the producer accepts the
   replacement under the single-defect loop.

2. **The mechanism re-baselines; it never weakens the guard (G-4).**
   - A core recomposition is composited into the master **before** the
     `approved` snapshot in `Scripts/art/package-art.js` (the line that reads
     `const approved = base.clone();`), from a committed generation and a
     committed graded mask, so the new pixels *become* the protected interior
     of record and every later repair layer is clipped against them exactly
     as before. `PROT`, `band`, `keepRepair`, the drift throw and the golden
     comparison are not edited.
   - A golden's zone is re-authored by re-extracting that golden in the same
     commit (`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/tools/
     extract_goldens.js`); the golden's git diff is the authorization trail,
     as the registry has always said. A registry rect may be edited to follow
     the re-authored feature; it is never emptied or deleted.
   - Every such region ships with its own manifest entry, generation, mask,
     job id, seed and review renders under `GAME_BIBLE/ART/exploration/EPO03/`.

3. **Identity anchors do not move.** The five playable locations (all inside
   the core), Millbridge and the Ferry Crossing (need water at their fixed
   coordinates), the Sunward Strand landmark (a beach must survive at its
   coordinates), every `routes` entry, and every other `atlas_layout.json`
   coordinate stay where they are; the biome under a place must still match
   its name. Routes and location content are never edited to fit art.

4. **The acceptance discipline binds unchanged.** A-3's blind read at
   iPhone-viewport scale, the single-defect loop (one region → composite →
   guards → full atlas + ×2 perimeter + phone FOV → verdict → next), and
   "no generated rectangle may remain" all apply to every re-baselined zone.
   The physical iPhone remains the final authority.

5. **Q-13 is answered by the directive's coast specification** — "COAST →
   SEA: clean surf, sand, rock, shallows, no rectangular shoreline joins" and
   "MAKE COASTS LOOK DELIBERATE": the south is drawn as a coast that follows
   terrain, and the lime survives only as coastal machair where a dune belt
   makes it read as geography, never as a latitude band.

6. **Q-28 is answered by the directive's fairy specification** — "Not just
   dots … tiny winged silhouettes, small warm-light figures, readable motion":
   the motes are replaced by authored fairy silhouettes; the toned discs are
   not final.

## What this decision does NOT authorize

- Weakening, disabling, or widening the A-4 guard, the rim dither, or the
  golden comparison, in code or by omission.
- Moving or renaming any location, landmark, route or prop coordinate to
  suit a painting.
- Re-baselining outside EPO03 without its own recorded owner ruling — this
  is a per-round authority, not a standing one.
- Atlas footprint expansion. The map keeps its 1024² footprint this round;
  the directive permits expansion only where it "materially improves" the
  world, and the producer's read (a quarter of the canvas is already open
  sea) is that recomposition, not acreage, is the whole budget.

## Consequences

- `RULES.md` A-4 gains no new text; its canonical sources now include this
  decision as the recorded way an approved interior is replaced.
- `JOURNAL/OPEN_QUESTIONS.md` Q-13, Q-18, Q-25 and Q-28 are marked resolved
  by this decision.
- The EPO03 record names every re-baselined zone, its golden diffs, and its
  device verdict.
