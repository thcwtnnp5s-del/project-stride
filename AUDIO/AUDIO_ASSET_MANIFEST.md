# Audio Asset Manifest

**Authority:** `DECISIONS/0005_AUDIO_SOURCING.md`
**Status:** First production set shipped — AUDIO_PRESENTATION_01 (2026-08-24): five region tracks, five profession action cues, all owner-accepted before integration.

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

The runtime mapping (event → asset ID → file) lives in
`lib/audio/audio_cues.dart`; `test/audio/audio_assets_test.dart` fails the
build when this drifts from the shipped files. Every asset below is a
Stability AI **Stable Audio** generation under Stability's licence for the
account's paid credit tier, owner-accepted in AUDIO_PRESENTATION_01, and
technically packaged (gain/trim/format only — see `assets/audio/v1/README.md`)
with full generation provenance in `AUDIO/evaluation/` beside its raw source.
Prompts are verbatim in the block after the table — they are long, and a
150-word cell is a table nobody can read.

| Asset ID | File | Source | Licence | Model / version | Prompt | Date | Used by |
|---|---|---|---|---|---|---|---|
| `music.haven.01` | `assets/audio/v1/music/music_haven_01.m4a` | Generated, Stability AI (HAVEN_R3_PIANO_A2A_3101, seed 3101, a2a strength 0.6 of HAVEN_R2_SA3_2101_cfg4) | Stability paid-tier | stable-audio-3, cfg 4, steps 8 | P-1 | 2026-08-23 | Region music, Haven's Rest |
| `music.whispering_woods.01` | `assets/audio/v1/music/music_whispering_woods_01.m4a` | Generated, Stability AI (WOODS_AP1_SA3_5101, seed 5101) | Stability paid-tier | stable-audio-3, cfg 4, steps 8 | P-2 | 2026-08-24 | Region music, Whispering Woods |
| `music.stonefall_mine.01` | `assets/audio/v1/music/music_stonefall_mine_01.m4a` | Generated, Stability AI (STONEFALL_AP1_SA3_5201, seed 5201) | Stability paid-tier | stable-audio-3, cfg 4, steps 8 | P-3 | 2026-08-24 | Region music, Stonefall Mine |
| `music.frostmere.01` | `assets/audio/v1/music/music_frostmere_01.m4a` | Generated, Stability AI (FROSTMERE_R3_PIANO_A2A_3201, seed 3201, a2a strength 0.6 of FROSTMERE_R2_SA3_2201_cfg4) | Stability paid-tier | stable-audio-3, cfg 4, steps 8 | P-4 | 2026-08-23 | Region music, Frostmere |
| `music.forgotten_hollow.01` | `assets/audio/v1/music/music_forgotten_hollow_01.m4a` | Generated, Stability AI (HOLLOW_AP1_SA3_5301, seed 5301) | Stability paid-tier | stable-audio-3, cfg 4, steps 8 | P-5 | 2026-08-24 | Region music, Forgotten Hollow |
| `gather.mining.01` | `assets/audio/v1/sfx/sfx_gather_mining_01.wav` | Generated, Stability AI (MINING_AP1_SA25_4102, seed 4102) | Stability paid-tier | stable-audio-2.5, defaults, 1 s | P-6 | 2026-08-24 | Mining action beats (all ore nodes, this phase) |
| `gather.woodcutting.01` | `assets/audio/v1/sfx/sfx_gather_woodcutting_01.wav` | Generated, Stability AI (WOOD_AP1_SA25_4203, seed 4203) | Stability paid-tier | stable-audio-2.5, defaults, 1 s | P-7 | 2026-08-24 | Woodcutting action beats (all tree nodes, this phase) |
| `gather.foraging.01` | `assets/audio/v1/sfx/sfx_gather_foraging_01.wav` | Generated, Stability AI (FORAGE_AP1_SA25_4301, seed 4301) | Stability paid-tier | stable-audio-2.5, defaults, 2 s | P-8 | 2026-08-24 | Foraging action beats (all plant nodes, this phase) |
| `craft.smithing.01` | `assets/audio/v1/sfx/sfx_craft_smithing_01.wav` | Generated, Stability AI (SMITH_AP1_SA25_4401, seed 4401) | Stability paid-tier | stable-audio-2.5, defaults, 1 s | P-9 | 2026-08-24 | Smithing action beats (all smithing recipes, this phase) |
| `craft.cooking.01` | `assets/audio/v1/sfx/sfx_craft_cooking_01.wav` | Generated, Stability AI (COOK_AP1_SA25_4503, seed 4503) | Stability paid-tier | stable-audio-2.5, defaults, 2 s | P-10 | 2026-08-24 | Cooking action beats (all cooking recipes, this phase) |

### Prompts, verbatim

- **P-1** (`music.haven.01`): `TrackType: Music, VocalType: Instrumental. Warm acoustic fantasy lo-fi for a cozy village refuge in an adventure RPG. Gentle nylon-string guitar and lute-like plucked strings carry the slow, restrained melody as the lead voice; a soft felt upright piano quietly joins as a secondary voice - occasional answering notes after the plucked-string phrases, sparse soft chords at section transitions, one or two understated melodic responses, with long stretches containing little or no piano. Breathy wooden flute accents, warm ambient pads and soft sustained strings underneath, sparse gentle hand percussion far back. Spacious, intimate arrangement with silence between phrases; the piano never leads, never loops a chord pattern, never crowds the strings. Lo-fi production: warm tape saturation, soft vinyl crackle, rounded highs, fireside intimacy. Slow tempo, 72 BPM.`
- **P-2** (`music.whispering_woods.01`): `TrackType: Music, VocalType: Instrumental. Warm acoustic fantasy lo-fi for peaceful old-forest wandering in an adventure RPG. Lute-like plucked strings and nylon-string guitar carry a slow, curious melody as the lead voice; a breathy wooden flute answers with short restrained phrases; soft warm strings sustain underneath; a sparse felt upright piano appears only occasionally as a quiet supporting musician - a few answering notes after the plucked-string phrases, long stretches without piano. Very light hand percussion far back, airy spacious arrangement with silence between phrases, gentle wonder and natural magic, warm filtered sunlight through old trees. Lo-fi production: warm tape saturation, soft vinyl crackle, rounded highs, organic intimacy. Slow tempo, 76 BPM.`
- **P-3** (`music.stonefall_mine.01`): `TrackType: Music, VocalType: Instrumental. Grounded acoustic fantasy lo-fi for patient underground craftsmanship in an adventure RPG. Low warm plucked strings and a deep-bodied acoustic guitar carry a slow, steady melody; a restrained felt piano adds sparse low and mid register phrases, never leading for long; warm low strings hold patient sustained tones underneath; minimal soft hand percussion marks a slow unhurried pulse far back. Ancient stone solidity, quiet determination, solitary calm labor at a safe working depth. Heavier and more grounded than a village theme yet pleasant for long listening. Lo-fi production: warm tape saturation, rounded highs, soft even dynamics. Slow tempo, 66 BPM, minimal harmonic movement.`
- **P-4** (`music.frostmere.01`): `TrackType: Music, VocalType: Instrumental. Sparse, crystalline acoustic fantasy lo-fi for a beautiful frozen wilderness in an adventure RPG. Delicate celesta, music box and glassy chimes place slow phrases with long silences; a very sparse soft felt piano adds isolated mid and high register notes and occasional short phrases, with substantial silence between piano statements - a gentle human warmth inside the cold landscape, never a repeating accompaniment, never a sentimental ballad. Airy sustained string harmonics and a distant breathy flute drift underneath; almost no percussion. Cold, spacious, contemplative, quiet wonder; remote and beautiful, never threatening, no festive jingle character. Lo-fi production: gentle tape hiss, soft even dynamics, rounded, hushed, wintery air. Very slow tempo, 62 BPM, minimal harmonic movement.`
- **P-5** (`music.forgotten_hollow.01`): `TrackType: Music, VocalType: Instrumental. Sparse, mysterious acoustic fantasy lo-fi for a forgotten ancient place in an adventure RPG. A soft felt piano leads with slow, slightly melancholy phrases separated by long silences - more emotional presence than elsewhere, yet always restrained, never sentimental; quiet acoustic plucked strings answer gently; a warm low cello holds patient sustained notes; an occasional breathy wooden flute drifts far away. Spacious contemplative arrangement, beautiful unease, quiet discovery, ancient and slightly sad, never frightening. Lo-fi production: gentle tape hiss, warm saturation, rounded hushed highs, soft even dynamics. Very slow tempo, 60 BPM, minimal harmonic movement.`
- **P-6** (`gather.mining.01`): `TrackType: SFX. Close-up field recording: a geologist's rock pick chips a small flake off a dense mineral-bearing boulder in one short strike. Dull muted contact, hard stone knock, tiny grit and stone-chip debris scattering, dry and tight, short natural decay, grounded, quiet, realistic.`
- **P-7** (`gather.woodcutting.01`): `TrackType: SFX. One single axe chop recorded close and dry: a hardened steel blade sinks into a solid seasoned log, a compact heavy wood knock, faint splinter crack detail, the trunk absorbs the blow, damped contact, extremely short decay, dead dry recording space.`
- **P-8** (`gather.foraging.01`): `TrackType: SFX. Very quiet close-mic recording: fingers brush through leafy wild herbs and gently pluck a stem, tiny leaf movement, a soft short plant pull, delicate foliage rustle settling quickly, intimate, natural, calm, small and soft, dry close recording.`
- **P-9** (`craft.smithing.01`): `TrackType: SFX. Close-mic blacksmith workshop recording of one single hammer strike: a heavy forging hammer lands squarely on a glowing heated iron workpiece resting on a damped steel anvil. Solid weighty impact, the soft hot metal absorbs the blow, dense hammer mass contact, short controlled low resonance dying quickly, tight decay, dry close workshop air, physical and believable.`
- **P-10** (`craft.cooking.01`): `TrackType: SFX. Close-mic field recording of a small piece of meat cooking over a hot rustic wood fire: clear gentle frying and sizzling from the food, tiny fat pops, a few soft dry fire crackles underneath, warm intimate hearth cooking sound, realistic natural texture, one short steady cooking moment.`

### Phase note on material identity

The coverage requirement below (copper ≠ iron, oak ≠ pine) stands as the
eventual bar. For the current playable phase the owner ruled **one strong cue
per core activity** — every ore node shares `gather.mining.01`, every tree
`gather.woodcutting.01` — with per-material variants added only when
physical-device play proves the repetition distracting. That ruling is why the
`Used by` column names whole professions.

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
