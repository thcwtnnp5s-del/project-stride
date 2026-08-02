# Decision: Audio Asset Sourcing and Licensing

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Closes:** Gap G-05 in `STUDIO_INITIALIZATION_REPORT.md`

## Context

Audio is a locked first-class system (`PROJECT_KERNEL/12_DECISION_LOG.md`), requiring region beds, weather variation, per-material gathering sounds, and combat feedback. Nothing specified where those files come from. `REFERENCES/README.md` forbids copying assets from other games, which closes the easy path without opening another.

## Decision

**A lean prototype budget.**

### Permitted sources

- **ElevenLabs**, free or the lowest practical tier
- **Original or generated assets**
- **CC0 or properly licensed royalty-free** placeholders

### Forbidden

- **Any asset extracted from the inspiration games.** WalkScape, Melvor Idle, Old School RuneScape, and New World are references for *identity*, never sources for files. This is absolute.
- **Paid libraries**, without explicit owner approval

### Required record-keeping

`AUDIO/AUDIO_ASSET_MANIFEST.md` records, for every asset:

- Asset ID
- Source
- Licence
- Generation prompt, where applicable
- Model and version, where applicable
- Generation or acquisition date
- Usage — which events and materials it serves

### Replaceable asset IDs

Audio is referenced throughout the game by **asset ID only**, never by filename or path. `audio_cues.json` maps semantic game events to asset IDs; the manifest maps asset IDs to files and provenance.

This means any placeholder can be replaced by a better recording later by swapping one manifest row, with no change to content, code, or cues.

## Reasoning

- The project needs *hooks* wired from Phase 3, not final audio. Placeholders that route correctly are worth far more now than a small number of perfect sounds.
- Generated audio is a good fit for the per-material identity the Game Bible demands — copper versus iron, oak versus pine — which is exactly where a generic royalty-free library disappoints.
- Provenance recorded at generation time costs minutes; reconstructed later it costs hours, and sometimes cannot be reconstructed at all. For anything that might reach TestFlight, licence clarity is not optional.
- The indirection through asset IDs is what makes "ship placeholders now" safe rather than a debt that calcifies.

## Consequences

- Task A-05 is unblocked.
- A missing manifest entry for a shipped asset is a **QA defect**, not a paperwork issue.
- The 30 MB audio memory budget in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4 is confirmed against real assets in A-05.
- If a paid library later proves necessary, it requires a new decision record.

## Follow-up

- `AUDIO/AUDIO_ASSET_MANIFEST.md` created with its schema and rules.
- Task A-04 acceptance criteria reference asset IDs.
- Task A-05 status changes from Blocked to Not started.
