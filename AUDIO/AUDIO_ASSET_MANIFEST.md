# Audio Asset Manifest

**Authority:** `DECISIONS/0005_AUDIO_SOURCING.md`
**Status:** Schema established; no assets yet (audio work begins at task A-04)

Every audio asset shipped in Project Stride has a row here. A shipped asset with no manifest row is a **QA defect**, not a paperwork oversight.

---

## How audio is referenced

```text
GameEvent  →  audio_cues.json  →  asset ID  →  this manifest  →  file
```

Game code emits semantic events. Content maps events to **asset IDs**. This manifest maps asset IDs to files and provenance.

**Nothing in the game ever references a filename or a path.** Replacing a placeholder with a better recording is a one-row change here — no code change, no content change, no cue change.

### Asset ID convention

```text
<category>.<subject>.<variant>
```

Categories: `ambience`, `gather`, `craft`, `combat`, `ui`, `music`

Examples: `gather.wood.oak.01`, `gather.ore.copper.01`, `ambience.stonefall_mine.bed`, `combat.hit.blade.light.02`, `ui.confirm.01`

Variants are numbered so repeated actions can rotate between takes rather than repeating one sample — a chop that sounds identical every time reads as cheap.

---

## Sourcing rules

**Permitted**

- ElevenLabs, free or lowest practical tier
- Original recordings or generated assets
- CC0, or properly licensed royalty-free

**Forbidden**

- **Any asset extracted from WalkScape, Melvor Idle, Old School RuneScape, or New World.** These are references for identity, never sources for files. Absolute.
- Paid libraries without explicit owner approval

---

## Manifest

| Asset ID | File | Source | Licence | Model / version | Prompt | Date | Used by |
|---|---|---|---|---|---|---|---|
| *(none yet)* | | | | | | | |

### Column rules

- **Asset ID** — as referenced by `audio_cues.json`
- **File** — path within the audio bundle
- **Source** — ElevenLabs, original recording, or the specific CC0/royalty-free origin with a URL
- **Licence** — CC0, the specific royalty-free terms, or the generation service's licence for the tier used at generation time
- **Model / version** — for generated assets
- **Prompt** — verbatim, for generated assets. Verbatim matters: it is the only way to produce a matching variant later
- **Date** — generation or acquisition date. Licences change; the date is what pins which terms applied
- **Used by** — the events and materials this serves, so an asset's blast radius is visible before it is replaced

---

## Budget

Total audio memory: **30 MB provisional** (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4), confirmed against real assets in task A-05.

Short cues preload as buffers; ambience beds stream.

---

## Coverage requirement

`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md` requires material identity: copper must not sound like iron, oak must not sound like pine, a mine must not sound like a forest.

A content validation test fails the build when any material or tier in the Milestone 01 content set has no cue of its own and falls through to a generic sound. Placeholders are acceptable; silent gaps are not.
