# FOUNDATION-E — Audio System Audit

**Workstream:** Visual / Audio / World Overhaul 01 (VAWO01), Wave 0
**Role:** Audio System Auditor
**Date:** 2026-09-01
**Branch at audit time:** `presentation-combat-evolution-01`
**Mode:** read-and-report. No file in the repository was modified except this one.

---

## 0. The headline

The audio **architecture** is in good shape and the audio **content** is not.

- Ten shipped assets: five 150 s region music tracks and five profession action
  cues. That is the entire sound of the game.
- **Combat is completely silent.** Not degraded — silent. `lib/audio/audio_cues.dart`
  contains no combat, reward, or UI cue table at all. The three cue maps in code
  are `files`, `regionMusic`, `skillCues`, and nothing else.
- **Every reward is silent.** Victory, retreat, level-up, discovery, loot,
  milestone, craft completion — all of them.
- A complete, implementation-ready design for all of the above exists as a
  **DRAFT** (`GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md`, 540 lines) with a
  matching **DRAFT** production queue (`AUDIO/AUDIO_PRODUCTION_QUEUE_01.md`,
  23 cues, verbatim prompts, seeds, costs, acceptance criteria). Neither is
  owner-accepted, and no line of the matrix has been implemented.
- **Generation capability is currently zero.** `STABILITY_API_KEY` is not set in
  this environment (verified in both bash and PowerShell scope). The last
  *recorded* balance is 61 credits (2026-08-24), which cannot buy P0 (200
  credits at one roll). Owner-supplied GitHub audio resources are still not
  recoverable from the repository (OD-06).
- **Audio *processing* capability IS available**: ffmpeg 9.0 is installed at
  `C:\Users\jwspa\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0-full_build\bin\ffmpeg.exe`
  — **not on PATH**, must be invoked by full path. Node is on PATH.

---

## 1. Canonical identity (`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`)

The document is short (484 bytes) and states audio is a **core gameplay
system**, not decoration.

**Five pillars:** Adventure · Satisfaction · Atmosphere · Material identity ·
Readable feedback.

**Per region it demands four things:** an ambient bed, wildlife/environmental
detail, weather variation, a distinct musical identity.

**Per major action it demands four beats:**

1. Initiation sound
2. Material response
3. Reward confirmation
4. Optional haptic pairing

Closing rule, quoted in full because everything downstream leans on it:
"Copper should not sound like iron. Oak should not sound like pine. A mine
should not sound like a forest."

**Current standing against that document:**

| Identity requirement | Status |
|---|---|
| Region ambient bed | **NOT SHIPPED** (bus architecture exists, zero content) |
| Wildlife / environmental detail | **NOT SHIPPED** |
| Weather variation | **NOT SHIPPED** |
| Distinct musical identity per region | **SHIPPED** — 5 of 5 regions |
| Action: initiation sound | **NOT SHIPPED** (no wind-up/swing/commit cue anywhere) |
| Action: material response | **SHIPPED** — this is the one beat that exists, on 3 call sites |
| Action: reward confirmation | **NOT SHIPPED** |
| Action: haptic pairing | **SHIPPED** — 13 haptic sites, rate-limited |
| Material identity (copper ≠ iron, oak ≠ pine) | **NOT SHIPPED** — one cue per profession by owner ruling; per-material id shape is reserved but unused |

`PRESENTATION_COMBAT_EVOLUTION_01.md` §5 states the arithmetic plainly: three
`playSkillCue` call sites against **twelve** haptic sites. Eleven of twelve
moments in the game have a haptic and no sound.

---

## 2. The canonical event matrix (`02_AUDIO_EVENT_MATRIX.md`)

**Status: DRAFT — Audio Director (DIR-D), not owner-accepted. No code changed
to match it.** It declares itself canonical for the cue/event id table, cue
priority, cooldown, ducking, haptic pairing, the fallback contract, and the mix
structure.

### 2.1 Priority bands and the voice cap

| Band | Priority | Category | Contents |
|---|---|---|---|
| 100 | Impact | `combat` | A blow landing. The only band that may interrupt. |
| 90–95 | Resolve | `reward` | A payoff layer rising. One per layer. |
| 85–88 | Warning / discovery | `combat`, `reward` | Telegraph; knowledge reveal. |
| 60–70 | Action | `combat`, `gather`, `craft` | Swings, stances, working strikes, completions. |
| 30 | UI | `ui` | The commit press. |

**Voice cap: 2 concurrent SFX voices.** A third request evicts the lowest-priority
sounding voice if it outranks it, otherwise is dropped silently. Ties go to the
newer voice. **Music is not a voice** and is never evicted.

### 2.2 The full declared matrix — 24 event ids

Combat (11):
`combat.encounter.begin.01`, `combat.swing.player.01`, `combat.impact.player.01`,
`combat.attack.enemy.01`, `combat.impact.enemy.01`, `combat.telegraph.heavy.01`,
`combat.impact.heavy.01`, `combat.brace.01`, `combat.brace.absorb.01`,
`combat.heal.01`, `combat.enemy.defeated.01`

Reward (5):
`reward.victory.01`, `reward.retreat.01`, `reward.discovery.01`,
`reward.levelup.01`, `reward.milestone.01`

Gathering (4):
`gather.mining.01`, `gather.woodcutting.01`, `gather.foraging.01`,
`gather.complete.01`

Crafting (5):
`craft.smithing.01`, `craft.cooking.01`, `craft.complete.minor.01`,
`craft.complete.medium.01`, `craft.complete.major.01`

UI (1):
`ui.commit.01` — one id for every primary commit press (Set out, Craft, Gather,
Engage, Attack, Brace, Equip, Deliver).

Plus one music id specified but not produced: `music.combat.tension.01`.

### 2.3 Ids deliberately NOT created (and why)

This is load-bearing for VAWO01 — do not "add" these back:

| Not created | Reason given |
|---|---|
| `reward.loot.01` | Loot is a line inside the victory layer; a coin/bag flourish is slot-machine adjacent, which the locked creative direction forbids. |
| `reward.signature.01` | Folded into `reward.discovery.01` — a signature reveal and a knowledge advance are the same event to the player. |
| `reward.project.01`, `reward.contract.01` | Folded into `reward.milestone.01`. |
| `combat.impact.enemy.*` placeholder | Nothing owned is a body blow; substituting mining would make one asset mean "the mine" and "you are being hit". Silence is the cheaper error. |
| Per-strike-quality ids (strong/even/weak) | The twelve-sounds-per-weapon trap. |
| Per-rarity craft completions (5), per-profession completions (15) | `craftSignificanceOf` has three outputs; audio has three ids. |
| `ui.tap`, `ui.cancel`, `ui.tab`, `ui.expand`, `ui.scroll` | A UI click family is upkeep, not feedback. |
| Per-material gather variants | Owner's one-cue-per-activity ruling stands until device play proves repetition distracting. **The id shape is reserved** so a variant round is a table edit. |

### 2.4 Mix structure declared

```
MUSIC    = settings.musicVolume (0.55)    × combatScale × cueDuckScale
SFX      = settings.sfxVolume   (0.90)    × cue.trimDb
AMBIENCE = settings.ambienceVolume (0.70) × combatScale
```

**Loudness metric ruling:** integrated LUFS is retired for SFX. One-shots are
matched on **LUFS-M max (400 ms momentary maximum)** measured on the shipped
file, with −1.0 dBTP unchanged as the ceiling. Target for the action class:
**−13.0 LUFS-M max ±1.0 LU**. Integrated LUFS remains the music metric.
Implementation is per-asset `trimDb`, **attenuation only** (`trimDb ≤ 0`).

**The duck** (one duck, on the music bus, driven by cue priority):

| Trigger | Depth | Attack | Hold | Release |
|---|---|---|---|---|
| Priority ≥ 100 (impact) | −6 dB | 120 ms | cue length | 700 ms |
| `combat.impact.heavy.01`, `craft.complete.major.01` | −9 dB | 120 ms | cue length | 1400 ms |
| Priority 85–95 (resolve, telegraph) | −6 dB (telegraph −3 dB) | 200 ms | cue length | 900 ms |
| Sustained combat (`setCombat(true)`) | −3 dB | 600 ms | whole encounter | 600 ms |

Ducks multiply; floor is `musicVolume × 0.35` (−9.1 dB). The duck **never**
applies to gather/craft action cues (priority 50).

**Combat music: Option B, ruled** — keep the regional bed, duck it, and layer an
optional tension overlay. Rejected: (A) a dedicated battle loop (fights
`setRegion`'s single-assignment architecture, discards regional identity),
(C) per-region combat variants (130 credits, unbuildable). `setCombat(bool)` is
specified as idempotent, ramping `combatScale` 1.0 ⇄ 0.71 over 600 ms via chained
one-shot timers, called from `combat_screen.dart:132` and `acknowledgeCombat`/
dispose. **Not implemented.**

### 2.5 The fallback contract

"A cue that cannot be resolved produces silence. Never a crash, never an
arbitrary sound." Declared `fallbackTo` per cue, max 3 hops, acyclic. The three
`AudioCues.files[id]!` crash sites this was written against **have already been
fixed** — `AudioCues.fileFor()` returning `String?` now exists in code. The
declared `fallbackTo` field itself does **not** exist yet.

### 2.6 Accessibility envelope (binding)

- Cues fire off the segment machine, never the frame ticker (defect D1 / M-16).
- Reduce Motion collapses combat timing to ~5 %; the priority rule and 2-voice
  cap are what make it survivable. **Outcome cues fire from the reward layer,
  not from a segment.**
- Every cue declares a cooldown. Monotonic clock only. No `Timer.periodic` in `lib/`.
- The skip path stays silent; the outcome cue still fires from the layer.
- No information is audio-only.
- Haptics need a rate limit — **1200 ms floor per strength**. (Implemented; see §6.)
- iOS `respectSilence: true` stays. The ring/silent switch muting the game is
  the documented contract, not a defect.

---

## 3. `DECISIONS/0005_AUDIO_SOURCING.md` — sanctioned providers and constraints

**Status: Approved, 2026-08-01, owner.**

### Permitted sources

1. **ElevenLabs** — free or the lowest practical tier
2. **Original or generated assets**
3. **CC0 or properly licensed royalty-free** placeholders

### Forbidden

- **Any asset extracted from the inspiration games** — WalkScape, Melvor Idle,
  Old School RuneScape, New World. References for *identity*, never sources for
  files. Marked **absolute**.
- **Paid libraries** without explicit owner approval. If one later proves
  necessary it requires a **new decision record**.

### Binding constraints

- `AUDIO/AUDIO_ASSET_MANIFEST.md` must record, for every asset: asset ID,
  source, licence, generation prompt, model and version, generation/acquisition
  date, and usage (which events and materials it serves).
- **A missing manifest entry for a shipped asset is a QA defect**, not a
  paperwork issue.
- **Replaceable asset IDs.** Audio is referenced by asset ID only, never by
  filename or path. Game code emits a semantic key; the cue table maps key →
  asset ID; the manifest maps asset ID → file + provenance. Swapping a
  placeholder for a better recording is a one-row change.
- The 30 MB audio memory budget (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4).

### What actually shipped versus the decision

Stability AI Stable Audio (stable-audio-3 for music, stable-audio-2.5 for SFX)
was used under the "generated assets" lane. The bake-off
(`AUDIO/evaluation/stable_audio_bakeoff_00/`) ruled Stable Audio the production
provider and explicitly ruled **not** to evaluate ElevenLabs at that time. The
production queue records "**Do not provider-hop**" as standing discipline.
ElevenLabs remains permitted by 0005 and by OD-06 ("may remain part of the
custom sound-design pipeline where useful") but is not the ruled provider.

---

## 4. Milestone record — what shipped, what was deferred

### 4.1 `MILESTONES/AUDIO_PRESENTATION_01.md`

**Status: implementation complete, awaiting owner review and physical-device
acceptance.**

Shipped — region music (stable-audio-3, cfg 4, steps 8, 150 s, −14 LUFS matched):

| Region | Accepted generation | Seed |
|---|---|---|
| Haven's Rest | HAVEN_R3_PIANO_A2A_3101 (a2a 0.6 of HAVEN_R2_SA3_2101_cfg4) | 3101 |
| Whispering Woods | WOODS_AP1_SA3_5101 | 5101 |
| Stonefall Mine | STONEFALL_AP1_SA3_5201 | 5201 |
| Frostmere | FROSTMERE_R3_PIANO_A2A_3201 (a2a 0.6 of FROSTMERE_R2_SA3_2201_cfg4) | 3201 |
| Forgotten Hollow | HOLLOW_AP1_SA3_5301 | 5301 |

Shipped — profession action cues (stable-audio-2.5, one per activity by owner ruling):

| Activity | Accepted generation | Seed | Gate |
|---|---|---|---|
| Mining | MINING_AP1_SA25_4102 | 4102 | Gate 1, first round |
| Woodcutting | WOOD_AP1_SA25_4203 | 4203 | Gate 2 |
| Foraging | FORAGE_AP1_SA25_4301 | 4301 | Gate 2 |
| Smithing | SMITH_AP1_SA25_4401 | 4401 | Gate 3, single candidate |
| Cooking | COOK_AP1_SA25_4503 | 4503 | Gate 5, third attempt (4501, 4502 rejected) |

Credits: opened at 399, closed generation at **61**.

Owner rulings recorded there:
- One strong cue per core activity; no variant families, no rotation.
- Cues punctuate what the player **watches** — never activity duration, step
  consumption, or queued/background progression. An unwatched queue is silent
  by design.
- No long audio for long activities. Region music is the only continuous audio.
- **Combat keeps the regional music and has no bespoke SFX this phase.
  Intentional, not an omission.**
- The Stonefall tail note is technical (2 s packaging fade for loop wrap), never
  a reason to regenerate.

Deferred, deliberately (§5, verbatim scope): ambience production (all regions,
forge bed, cooking hearth), combat SFX, enemy sounds, battle music, World/Travel
music, reward/rarity stingers, UI click sounds, travel SFX, per-material cue
variants, any DSP beyond volume, haptics coupling.

Suite after integration: app **646** (+17 audio).

### 4.2 `MILESTONES/PRESENTATION_COMBAT_EVOLUTION_01.md` — audio sections

**Zero audio generated** — `STABILITY_API_KEY` unset, balance unverifiable.

Diagnosis §5: "Mechanically the fight is sound. It has no voice." Six defects,
all fixed without generation:

| # | Defect | Resolution |
|---|---|---|
| 1 | Reduce Motion was a **total product-wide SFX blackout** — `ambient_stage.dart:582` stopped the controller, so `_onTick` never ran, so `onBeat` never fired | Fixed: cadence cursor separated from drawn frame. Recorded as **M-16**, pinned by `test/activity_beat_audio_test.dart` |
| 2 | Mix never level-matched — SFX to peak, music to loudness; 10.4 dB spread | Fixed: `ActionCue.trimDb`, smithing −7.0, foraging −0.2 |
| 3 | Cooking fired every *other* stir (1500 ms floor over a 1320 ms cycle) | Fixed: cooldown 1500 → 1100 ms |
| 4 | Three `AudioCues.files[id]!` crash sites throwing from inside `setState` | Fixed: `AudioCues.fileFor()` → `String?` |
| 5 | Heavy haptic fired up to 625 ms early | Fixed: moved to the frame the blow lands |
| 6 | No haptic rate limit anywhere | Fixed: per-strength floors with a `payoff` bypass |

Deferred (§10) with reasons:
- **The combat engage beat** — `replays()` semantics change would break
  `combat_busy_test` and `combat_presentation_order_test`; "its payload is
  mostly a sound that cannot be produced yet".
- **Combat music duck** — architecture ruled (Option B), not implemented.
- Brace's held pose, the 8 s idle freeze.

Known issue §11: "Combat still has **no sound**, by necessity. The wiring is
ready; the assets are not producible." Also: **CI is RED on this branch and was
red before it** — `lib/ui/state/craft_memory.dart` violates two UI-boundary
rules (pre-existing, from GFCP01 `830f1a1`), and `check-ui-boundary.sh` runs
*before* the test suites, so CI never reaches them.

---

## 5. AUDIO/ directory inventory

### 5.1 Top level — 2 tracked documents

| File | Size | What it is |
|---|---|---|
| `AUDIO/AUDIO_ASSET_MANIFEST.md` | 14,028 B | Canonical provenance: 10 rows (P-1…P-10), asset ID → file → source → licence → model → prompt ref → date → usage |
| `AUDIO/AUDIO_PRODUCTION_QUEUE_01.md` | 77,223 B | **DRAFT**, not owner-accepted. 23 cues, verbatim prompts, seeds, costs, acceptance/rejection criteria, transport rules, measurement gate, budget arithmetic |

### 5.2 `AUDIO/evaluation/` — 178 files, **untracked** (`git status` shows `?? AUDIO/evaluation/`)

This is source/evaluation material, deliberately not in the repository. Nothing
here ships.

**`audio_presentation_01/`** (the production workstream):

| Group | Files | Format | Notes |
|---|---|---|---|
| Index documents | 6 × .md | — | INDEX_MINING, INDEX_GATHERING, INDEX_SMITHING, INDEX_COOKING_AND_REGIONS, INDEX_COOKING_CORRECTION, INDEX_COOKING_FINAL |
| Mining | 3 raw + 3 listening | WAV 192,540 B raw / 176,478 B listening | 1 s each; seeds 4101–4103; **4102 shipped** |
| Woodcutting | 3 raw + 3 listening | same | 1 s; seeds 4201–4203; **4203 shipped** |
| Foraging | 3 raw + 3 listening | 368,940 B raw / 352,878 B listening | 2 s; seeds 4301–4303; **4301 shipped** (trimmed to 1.6 s) |
| Smithing | 1 raw + 1 listening | 192,540 / 176,478 B | 1 s; seed 4401; **shipped** |
| Cooking | 3 raw + 3 listening | 368,940–545,340 B | 2–3 s; seeds 4501–4503; **4503 shipped** |
| Music | 3 raw WAV (26,476,138 B ea.) + 3 listening MP3 (6,002,981 B ea.) | 150 s | WOODS_5101, STONEFALL_5201, HOLLOW_5301 — all three shipped |
| Provenance | 16 × .json | — | One per candidate: prompt, seed, request/generation IDs, sha256, credits before/after, measurements, owner ruling |
| Listening ZIPs | 6 | — | 104 KB … 18.1 MB; owner-delivery bundles |
| `tools/` | `gen2.mjs` + 16 job JSONs + 10 patch .mjs | — | The generation runner and its per-job inputs |

**`stable_audio_bakeoff_00/`** (the provider/identity bake-off, closed 2026-08-23):

| Group | Files | Notes |
|---|---|---|
| Round 1 Haven | 3 raw WAV + 3 listening MP3 | seeds 1101–1103 — **REJECTED** (chiptune/techno direction) |
| Round 1 Frostmere | 3 + 3 | seeds 1201–1203 — **REJECTED** |
| Round 1 Stonefall | 3 raw (13,246,138 B) + 3 listening + 1 LOOP_TEST WAV | seeds 1301–1303 |
| Round 1 Pickaxe | 3 raw + 3 listening | seeds 1401–1403 — **REJECTED** (cymbal-like) |
| Round 2 | Haven cfg4/cfg7, Frostmere cfg4/cfg7 | seeds 2101/2102, 2201/2202 — cfg 4 became the house baseline |
| Round 3 (piano a2a) | 2 raw + 2 listening | **HAVEN_R3_PIANO_A2A_3101 and FROSTMERE_R3_PIANO_A2A_3201 — both shipped** |
| Smoke | 1 WAV + 1 provenance | SMOKE_TEMP_THROWAWAY_wooden_tap, seed 1001 |
| Provenance | 22 .json incl. 6 `.FAILED.json` | The six FAILED files are the 156-credit `internal_shape` loss |
| Listening ZIPs | 3 | 23.9 MB, 23.9 MB, 56.2 MB |
| `tools/` | `gen.mjs`, `gen2.mjs`, `ids.txt`, 18 job JSONs | |

**Source vs shipped, stated plainly:** everything under `AUDIO/evaluation/` is
source material and is untracked. Everything under `assets/audio/v1/` is shipped
and tracked. The two are linked by `assets/audio/v1/README.md`'s packaging
table and by `AUDIO/AUDIO_ASSET_MANIFEST.md`'s provenance rows.

---

## 6. Shipped audio assets

Declared in `pubspec.yaml` lines 230–239, file-by-file (an undeclared file is
audio that does not exist; a stray one is audio nobody reviewed).

| Asset ID | File | Format (probed) | Duration | Size | Purpose |
|---|---|---|---|---|---|
| `music.haven.01` | `assets/audio/v1/music/music_haven_01.m4a` | AAC 44.1 kHz stereo 196 kbps | 150.0 s | 3,691,264 B | Region music, Haven's Rest |
| `music.whispering_woods.01` | `.../music_whispering_woods_01.m4a` | AAC 44.1 kHz stereo 196 kbps | 150.0 s | 3,681,318 B | Region music, Whispering Woods |
| `music.stonefall_mine.01` | `.../music_stonefall_mine_01.m4a` | AAC 44.1 kHz stereo 195 kbps | 150.0 s | 3,650,561 B | Region music, Stonefall Mine (2 s technical fade at 148 s for loop wrap) |
| `music.frostmere.01` | `.../music_frostmere_01.m4a` | AAC 44.1 kHz stereo 194 kbps | 150.0 s | 3,634,529 B | Region music, Frostmere |
| `music.forgotten_hollow.01` | `.../music_forgotten_hollow_01.m4a` | AAC 44.1 kHz stereo 194 kbps | 150.0 s | 3,636,602 B | Region music, Forgotten Hollow |
| `gather.mining.01` | `assets/audio/v1/sfx/sfx_gather_mining_01.wav` | PCM s16le 44.1 kHz stereo | 1.0 s | 176,478 B | Mining action beat, all ore nodes |
| `gather.woodcutting.01` | `.../sfx_gather_woodcutting_01.wav` | PCM s16le 44.1 kHz stereo | 1.0 s | 176,478 B | Woodcutting action beat, all tree nodes |
| `gather.foraging.01` | `.../sfx_gather_foraging_01.wav` | PCM s16le 44.1 kHz stereo | 1.6 s | 282,318 B | Foraging action beat, all plant nodes (trimmed 2.0 → 1.6 s, 120 ms fade) |
| `craft.smithing.01` | `.../sfx_craft_smithing_01.wav` | PCM s16le 44.1 kHz stereo | 1.0 s | 176,478 B | Smithing action beat, all smithing recipes |
| `craft.cooking.01` | `.../sfx_craft_cooking_01.wav` | PCM s16le 44.1 kHz stereo | 2.0 s | 352,878 B | Cooking action beat, all cooking recipes |

**Total: ~19 MB** (17.9 music + 1.1 SFX) against a 30 MB budget.

**Measured loudness on the shipped files** (BS.1770, 400 ms momentary max):

| File | LUFS-I | LUFS-M max | Sample peak | Runtime `trimDb` | Result |
|---|---|---|---|---|---|
| smithing | −13.6 | **−10.0** | −1.8 dBFS | −7.0 | −17.0 |
| foraging | −19.6 | −17.2 | −4.2 dBFS | −0.2 | −17.4 |
| woodcutting | −18.4 | −18.4 | −1.2 dBFS | 0.0 | −18.4 |
| cooking | −21.4 | −18.9 | −5.3 dBFS | 0.0 | −18.9 |
| mining | −21.3 | **−20.4** | −3.1 dBFS | 0.0 | −20.4 (**the floor — cannot be raised by trim**) |

`AUDIO/AUDIO_ASSET_MANIFEST.md` carries a matching row (P-1…P-10) for all ten
with verbatim prompts, so `DECISIONS/0005`'s record-keeping requirement is
currently satisfied — 10 assets, 10 manifest rows.

---

## 7. The audio runtime

### 7.1 Files

| Path | Lines | Responsibility |
|---|---|---|
| `lib/audio/audio_controller.dart` | 502 | The one app-scoped owner: music bus, SFX bus, settings, haptics, lifecycle |
| `lib/audio/audio_cues.dart` | 197 | Semantic key → asset ID → file. `ActionCue` (assetId, cooldownMillis, trimDb) |
| `lib/audio/audio_output.dart` | 146 | The `audioplayers` seam: `AudioOutput`, `MusicChannel`, `AudioplayersOutput` |
| `lib/audio/audio_settings.dart` | 106 | Immutable `AudioSettings` snapshot + JSON |
| `lib/audio/audio_settings_store.dart` | 65 | One JSON file at `<app support>/audio_settings.json`, temp-then-rename |
| `lib/audio/silent_audio_output.dart` | 43 | Widget-test fallback, silent and disabled |
| `lib/ui/state/audio_scope.dart` | ~45 | `InheritedNotifier<AudioController>`; `of` / `read` / `maybeRead` |

Dependency: `audioplayers: 6.8.1`, pinned exactly (`pubspec.yaml:30`).

### 7.2 Public API — the complete surface

```dart
// Construction
static Future<AudioController> start({AudioOutput?, AudioSettingsStore?})

// MUSIC
Future<void> setRegion(String? locationId)      // one call site: stride_app.dart:170
String? get currentMusicAssetId

// SFX
void playSkillCue(String skill)                 // three call sites (see 7.4)

// Settings
AudioSettings get settings
void setEnabled(bool)
void setMusicVolume(double)
void setSfxVolume(double)
void setHapticsEnabled(bool)

// Haptics
void hapticLight()
void hapticMedium({bool payoff = false})
void hapticHeavy({bool payoff = false})
void hapticSelection()

// Lifecycle
void didChangeAppLifecycleState(AppLifecycleState)  // WidgetsBindingObserver
void dispose()
```

**That is the whole API.** There is no `playCue(cueId)`, no `setCombat(bool)`,
no duck, no voice cap, no priority. Confirmed by grep: `combatCues`,
`rewardCues`, `uiCues`, `setCombat`, `playEventCue` return **zero hits** in
`lib/`. `playCue` exists only as the private `AudioOutput` method the controller
calls internally.

### 7.3 Event → file mapping

Three tables, all in `audio_cues.dart`:

- `files: Map<String, String>` — 10 asset IDs → paths relative to `assets/`
- `regionMusic: Map<String, String>` — 5 location content-id strings → music asset IDs
- `skillCues: Map<String, ActionCue>` — 5 skill content-id strings → `ActionCue`

Resolution helpers: `musicForRegion(String?)`, `cueForSkill(String)`,
`fileFor(String?)` — the last returns `String?`, so an asset ID with no bundled
file is **silence, never a crash**. This is what makes "wire the event now, ship
the sound later" safe.

### 7.4 How SFX fire

`playSkillCue(skill)` gate order, `audio_controller.dart:254–274`:

1. `if (_disposed || _halted) return;` — backgrounded means silent
2. `if (!_settings.enabled || _settings.sfxVolume <= 0) return;`
3. `cueForSkill(skill)` — unknown skill → silent, no error
4. **`fileFor(cue.assetId)` resolved BEFORE the cooldown is stamped** — silence
   must not consume the cooldown slot of the sound that will replace it
5. Cooldown check on the monotonic clock (`Stopwatch`, never `DateTime.now`)
6. `_output.playCue(file, volume: sfxVolume * cue.gain)` where
   `gain = 10^(trimDb/20)`, `trimDb ≤ 0`

Three call sites:

| Site | Trigger |
|---|---|
| `adventure_screen.dart:244` | `onActivityBeat` — the gather working loop crosses its strike frame |
| `adventure_screen.dart:249` | `onGatherCue` — a single successful gather's one-shot begins playing (on the *result*, never the tap, so a refused gather stays silent) |
| `craft_screen.dart:1071` | `onActivityBeat` — the bench working loop crosses its strike frame |

Strike frames (`lib/ui/icons/ambient_assets.dart:373`): mining 4, woodcutting 4,
foraging 8, smithing 6, cooking 6. First-pass authoring by loop structure,
expected to be retuned by ear on the device.

The beat itself (`ambient_stage.dart` `_ActivityLoopState._onTick`) is a
**crossing test**, not an equality test — under load a slow frame can jump the
counter past the strike frame, and equality would silently drop that cycle. Post
M-16 fix, the cadence cursor `_cursor` advances in **both** motion modes while
the drawn frame `_frame` is pinned to 0 under Reduce Motion, so audio survives
the accessibility setting.

### 7.5 How music loops and crossfades

- `AudioplayersOutput.startMusic` sets `ReleaseMode.loop`; the loop wrap relies
  on the composed fade tails in the files.
- `setRegion(locationId)`: **same assignment → immediate return.** That single
  early return is the acceptance line "same-region navigation does not restart
  music" — tab changes, screen pushes and combat all re-announce the same
  location and all leave here.
- A new assignment crossfades: `_retireCurrentMusic()` fades the old to 0 and
  disposes it; the new starts at volume 0 and fades up.
- Fade shape: **9 steps over 1080 ms**, chained one-shot `Timer`s.
  `Timer.periodic` is forbidden in `lib/` and enforced by
  `s01a_vertical_slice_test.dart` §14.
- `_musicEpoch` increments on every region change; an async start that returns
  to a newer epoch disposes itself — this is what makes rapid travel taps end
  with exactly one track.
- At most **two** music channels exist: `_music` and `_fadingOut`. Anything
  already fading when a third change arrives is disposed on the spot.

### 7.6 Concurrency limits

- **Music:** hard maximum of 2 channels (live + dying), enforced structurally.
- **SFX:** `AudioplayersOutput` keeps **one persistent `AudioPlayer` per cue
  path**, created on first use, `PlayerMode.lowLatency`, `ReleaseMode.stop`.
  `playCue` does `stop()` then `play()`, so **the same cue retriggers rather
  than layering**. Different cues can overlap freely — **there is no global
  voice cap today**; the matrix's 2-voice cap is design, not code.
- A first-use race was fixed in PCE01: the player configuration is now awaited,
  with a re-check for an interleaved installer, because the very first strike of
  every cue path used to race its own configuration.

### 7.7 Mixing, volume, ducking

- Music volume: `settings.musicVolume`, written directly on the channel except
  while a fade owns it.
- SFX volume: `settings.sfxVolume × cue.gain`. Attenuation only.
- Ambience: the volume field and the bus concept exist; **no content, no bus
  implementation, no control**.
- **Ducking: does not exist.** No `combatScale`, no `cueDuckScale`, no priority.
  Fully specified in the matrix §3.4/§3.5 and entirely unimplemented.

### 7.8 Lifecycle

`AudioController` is a `WidgetsBindingObserver`.

- `_halted` is true when the lifecycle state is non-null and not `resumed`.
  Null (widget-test harness, fresh launch) is treated as foreground.
- **On background:** the dying channel is disposed silently; the live channel is
  **paused, not stopped** — it resumes where it left off. `playSkillCue` refuses
  while halted.
- **On resume:** `_resumeAssignedMusic()` — resumes the held channel, or starts
  the assignment fresh if the region changed while audio was off.
- **Hidden tab:** handled one level up. `TickerMode` stops the working loop's
  `AnimationController`, so `onBeat` stops firing and the profession cue goes
  quiet. Music is unaffected — it is not driven by a ticker.
- `dispose()` flushes a pending debounced settings save rather than losing it,
  cancels every fade timer, disposes both channels and the output, and removes
  the observer.
- iOS: `AudioContextConfig(respectSilence: true)` — the *ambient* session
  category. The game honours the ring/silent switch, mixes politely, and is
  silenced by the OS in the background. No background-mode entitlement.

---

## 8. The settings surface

### 8.1 Exact field names — `lib/audio/audio_settings.dart`

| Field | Type | Default | Persisted JSON key |
|---|---|---|---|
| `enabled` | `bool` | `true` | `enabled` |
| `musicVolume` | `double` | `0.55` (`AudioSettings.defaultMusicVolume`) | `musicVolume` |
| `sfxVolume` | `double` | `0.9` (`AudioSettings.defaultSfxVolume`) | `sfxVolume` |
| `ambienceVolume` | `double` | `0.7` (`AudioSettings.defaultAmbienceVolume`) | `ambienceVolume` |
| `hapticsEnabled` | `bool` | `true` | `hapticsEnabled` |

All volumes clamp to `[0.0, 1.0]`. `fromJson` is tolerant by design — a missing
or malformed field takes its default rather than failing the load.

Persistence: `<application support>/audio_settings.json`, written
temp-then-rename, **beside and never inside** the save directory, so
`DECISIONS/0013` (single-writer persistence) has no subject here. Saves are
debounced 400 ms so a slider drag is one write, not sixty.

### 8.2 Where the UI exposes them — `lib/ui/screens/character/audio_block.dart`

`AudioBlock` is a `SectionCard` on the **Character tab**, headed **"Sound & feel"**.
Four controls:

| Control | Label | Wires to |
|---|---|---|
| Master toggle | "Sound is on" / "Sound is off" + Turn on/Turn off button | `setEnabled(!on)` |
| Music volume | `MUSIC` row, − / percentage / + | `setMusicVolume(v)` |
| SFX volume | `EFFECTS` row, − / percentage / + | `setSfxVolume(v)` |
| Haptics toggle | "Vibration is on" / "Vibration is off" + Turn on/Turn off | `setHapticsEnabled(!haptics)` |

Volumes step in **tenths** through a −/+ pair, rendered as a percentage
(`_VolumeRow`), not a `Slider` — the screens import `widgets`, not `material`.
The two volume rows are disabled (greyed) when `enabled` is false.

**No ambience control** — a slider for silence would be a promise the build does
not keep.

### 8.3 Haptics — vibration model

All haptics fire through `AudioController`, so the toggle and the scarcity rule
live in one greppable place. Per-strength rate floors
(`_hapticFloorMillis`): light **120 ms**, medium **400 ms**, heavy **1200 ms**,
selection **80 ms**. `hapticMedium`/`hapticHeavy` accept `payoff: true`, which
**bypasses** the floor — review found that a heavy blow followed by a MAJOR
reward layer inside 1200 ms would suppress the *payoff* precisely because the
blow before it was strong.

Thirteen haptic call sites: `activity_result.dart:316`, `reward_layer.dart:77`
and `:79`, `activity_panel.dart:520`, `adventure_screen.dart:250` and `:552`,
`encounter_card.dart:319`, `step_tracker_screen.dart:188`,
`combat_stage.dart:469`, `craft_screen.dart:885` and `:1181`,
`inventory_screen.dart:891`, `atlas_selection_panel.dart:689`.

### 8.4 Reduce-motion interaction

`hapticsEnabled` is **deliberately not coupled to Reduce Motion** — they are
separate accessibility axes, documented in the field's own comment. The OS
System Haptics setting still sits beneath it.

Reduce Motion (`MediaQuery.disableAnimationsOf`) is read in 12 places across
`lib/ui/`. Its audio-relevant behaviour after the M-16 fix: the working loop's
`AnimationController` **runs in both modes**; under reduced motion it drives the
cadence only, issuing no `setState`, so the picture holds still and the cue
keeps its timing. Costs one vsync callback of arithmetic and zero rebuilds.
`TickerMode` still stops it on a hidden tab.

**Combat has no Reduce Motion path at all** — `lib/ui/screens/combat/` reads
`disableAnimationsOf` nowhere. Recorded as a PCE01 deferral, and it is a live
hazard for VAWO01: Flutter collapses a 2.5 s round to ~125 ms under the setting,
so segment-placed cues would arrive nearly simultaneously with no voice cap to
absorb them. This is Q-16, **UNRESOLVED**.

---

## 9. THE GAP — full coverage table

Legend: **SOUNDS** = an asset exists and plays today · **SILENT (wired)** = the
trigger exists in code but no cue is emitted · **SILENT (unwired)** = neither
cue nor trigger exists.

### 9.1 Combat — 11 events, **0 sounding**

| Event id | Trigger site named by the matrix | Asset? | Code cue? | Status |
|---|---|---|---|---|
| `combat.encounter.begin.01` | `combat_screen.dart:132` (`_fightArrival++`) / `setCombat(true)` | none | none | **SILENT (unwired)** — engage beat itself is a PCE01 deferral |
| `combat.swing.player.01` | `_startSegment` for `PlayerStruckBeat`, t=0 | none | none | **SILENT (unwired)** |
| `combat.impact.player.01` | Same segment at `lands` (`combat_choreography.dart:176`) | none (matrix proposes placeholder `craft.smithing.01` @ −2 dB, **owner-gated, not applied**) | none | **SILENT (unwired)** |
| `combat.attack.enemy.01` | `_startSegment` for `EnemyStruckBeat`, t=0 | none | none | **SILENT (unwired)** |
| `combat.impact.enemy.01` | Same segment at `lands` (`combat_choreography.dart:218`), non-heavy, unbraced | none — **no placeholder by ruling** | none | **SILENT (unwired)** |
| `combat.telegraph.heavy.01` | `RoundEndedBeat` whose `telegraph` becomes true (`combat_choreography.dart:254`) | none | none | **SILENT (unwired)** |
| `combat.impact.heavy.01` | `EnemyStruckBeat` with `heavy == true`, at `lands` | none | **haptic only** — `combat_stage.dart:469` `hapticHeavy()` | **SILENT (haptic present)** |
| `combat.brace.01` | `BracedBeat` segment start (`combat_choreography.dart:202`) | none | none (matrix specifies a **new** `hapticLight` too) | **SILENT (unwired)** |
| `combat.brace.absorb.01` | `EnemyStruckBeat` immediately after a `BracedBeat`, at `lands`. Needs a new `bracedReply` bool on `StageSegment` | none | none | **SILENT (unwired)** |
| `combat.heal.01` (use food) | `ConsumableUsedBeat` segment start | none | none | **SILENT (unwired)** |
| `combat.enemy.defeated.01` | `WonBeat` segment start — the fall | none | none | **SILENT (unwired)** |

Combat music: the regional bed plays unducked throughout. `setCombat` does not
exist. `setRegion` has one call site, on location change only.

### 9.2 Reward and outcome — 5 events, **0 sounding**

| Event id | Trigger | Asset? | Code cue? | Status |
|---|---|---|---|---|
| `reward.victory.01` | Outcome layer with `outcome == won` (`combat_screen.dart:162`/`:175`), incl. skip path | none | **haptic only** — `reward_layer.dart:79` `hapticMedium(payoff: true)` | **SILENT — P0, the single most-named gap** |
| `reward.retreat.01` | Same layer, `outcome == lost`/`retreated` | none | haptic only | **SILENT** |
| `reward.discovery.01` (knowledge advance + signature drop) | Outcome layer containing a `STUDIED`/`KNOWN` beat or a signature reveal, 600 ms after victory | none | none | **SILENT (unwired)** |
| `reward.levelup.01` | A layer whose beats include a level gained; outranks every other completion on that layer | none | haptic via layer tier | **SILENT** |
| `reward.milestone.01` (project stage, contract delivered, bounty paid) | Reward layer | none | haptic via layer tier | **SILENT** |
| **Loot** | — | — | — | **NO ID BY RULING** — resolved inside `reward.victory.01`; a coin/bag flourish is slot-machine adjacent and forbidden |

### 9.3 Gathering — 4 events, **3 sounding**

| Event id | Trigger | Asset | Status |
|---|---|---|---|
| `gather.mining.01` (mining strike) | Strike frame 4 of 8; also the one-shot gather's play | `sfx_gather_mining_01.wav`, 1.0 s, trim 0.0 | **SOUNDS** — but it is the loudness floor (−20.4 LUFS-M max) and the owner said "mining should ring". Q-17 open. |
| `gather.woodcutting.01` (axe bite) | Strike frame 4 | `sfx_gather_woodcutting_01.wav`, 1.0 s, trim 0.0 | **SOUNDS** |
| `gather.foraging.01` (rustle) | Strike frame 8 of a 15-slot ping-pong, 1650 ms cycle | `sfx_gather_foraging_01.wav`, 1.6 s, trim −0.2 | **SOUNDS** |
| `gather.complete.01` | `ActivityResultHost` lands a gather result card (`activity_result.dart:301`) | none (matrix proposes the profession's own cue as a terminal strike @ −3 dB — not applied) | **SILENT** |
| Per-material variants (copper vs iron, oak vs pine) | — | none | **SILENT — the identity document's core demand, unmet.** Id shape reserved; owner ruling holds one cue per activity until device play proves repetition distracting. |

### 9.4 Crafting — 5 events, **2 sounding**

| Event id | Trigger | Asset | Status |
|---|---|---|---|
| `craft.smithing.01` (hammer) | Strike frame 6 of a 12-slot ping-pong, 1320 ms cycle (`craft_screen.dart:1070`) | `sfx_craft_smithing_01.wav`, 1.0 s, trim **−7.0** | **SOUNDS** |
| `craft.cooking.01` (sizzle) | Same, frame 6 | `sfx_craft_cooking_01.wav`, 2.0 s, trim 0.0, cooldown corrected 1500 → 1100 ms | **SOUNDS, but structurally wrong** — its own provenance records "a steady sizzle plateau, no impact event anywhere in the profile". It has **no transient**, so it cannot punctuate a strike frame at any cooldown. Real answer is `craft.cooking.stir.01`. |
| `craft.complete.minor.01` | `CraftSignificance.minor` → `ActivityResultHost` card | none | **SILENT** |
| `craft.complete.medium.01` | `showRewardLayer(tier: medium)` from `craft_screen.dart:247–249` | none | **SILENT** — haptic only (`reward_layer.dart:72`) |
| `craft.complete.major.01` | Same seam, `significance == major` (rarity ≥ Epic) | none | **SILENT** — haptic only (`reward_layer.dart:70`) |
| Level-up from a craft | Folded into `reward.levelup.01` | none | **SILENT** |

Crafting completions map **one-to-one** onto `craftSignificanceOf`
(`lib/ui/state/craft_significance.dart:32`) — three outputs, three ids. No
per-rarity or per-profession completion ids, by ruling.

### 9.5 UI and everything else

| Event | Status |
|---|---|
| `ui.commit.01` (Set out, Craft, Gather, Engage, Attack, Brace, Equip, Deliver) | **SILENT (unwired)** — one id for all eight by ruling |
| Travel / set-out SFX | **SILENT** — folded into `ui.commit.01`; no travel audio of any kind |
| Region ambience (all 5) | **SILENT** — bus architecture only, zero content |
| Forge bed, cooking hearth, town/interior ambience | **SILENT** |
| Wind, weather, wildlife | **SILENT** |
| World / Travel / Atlas music | **SILENT** — the World and Atlas screens carry the current region's bed |
| Combat music (bespoke or tension overlay) | **SILENT** — `music.combat.tension.01` specified, not produced |
| Fishing | Not implemented as a mechanic |

### 9.6 Tally

| Category | Declared events | Sounding today | Silent |
|---|---|---|---|
| Combat | 11 | **0** | 11 |
| Reward / outcome | 5 | **0** | 5 |
| Gathering | 4 | 3 | 1 |
| Crafting | 5 | 2 | 3 |
| UI | 1 | **0** | 1 |
| Region music | 5 | 5 | 0 |
| Ambience | (all) | **0** | all |
| **Total declared cue ids** | **26** | **10** | **16** |

Of the 10 that sound, one (cooking) is transient-less and one (mining) sits at
an unfixable floor. So the honest count of cues that both exist and do their job
is **8 of 26**, and **combat and reward together are 0 of 16**.

---

## 10. Generation capability, right now

### 10.1 Credentials — the binding constraint

| Item | State | How verified |
|---|---|---|
| `STABILITY_API_KEY` | **NOT SET** | Checked in this session's bash environment and in PowerShell `$env:` scope. Both empty. |
| `ELEVENLABS_API_KEY` | **NOT SET** | Same check. |
| Any committed credential file | **None found** | Searched `*.md`, `*.mjs`, `*.js`, `*.sh`, `*.ps1`, `*.yaml`, `*.yml`, `*.json` for provider names and key names. Only *references* to the key's name exist, never a value. |

No secret value was printed or read anywhere in this audit.

Note from memory `audio-bakeoff-00-outcome`: the key was recorded as a **Windows
User-scope environment variable**, and "a stale shell may predate it — read from
User scope." This session's PowerShell read of `$env:STABILITY_API_KEY` came back
empty, which is a User-scope read. Treat generation as unavailable until a fresh
shell or the owner proves otherwise.

`AUDIO/AUDIO_PRODUCTION_QUEUE_01.md` §0 records the same finding independently:
"`STABILITY_API_KEY` **is not set in this environment**. `gen2.mjs` exits 2
without it." And: "Live balance: **Unverifiable.** No key, no
`/v1/user/balance` call possible."

### 10.2 Budget

- Last **recorded** balance: **61 credits, 2026-08-24**. This is a record, not a
  reading. The queue explicitly says "**Never trust a remembered figure** —
  including the 61 in this document."
- stable-audio-2.5: **20 credits flat, any duration.**
- stable-audio-3: **26 credits at 150 s**; cost at shorter durations unrecorded.
- P0 (10 cues) at one roll: **200 credits.** At this project's measured reroll
  rate: ~520. The full 23-cue queue at two rolls: **≈812–920 credits.**
- **61 credits cannot buy P0.** The matrix's ruling if exactly 61 must be spent:
  all of it on `reward.victory.01`, three rolls, 60 credits.
- Standing rule from `AUDIO_PRESENTATION_01.md` §1: "No further Stability spend
  without the owner explicitly reopening generation."

### 10.3 Owner-supplied GitHub audio resources

**Not recoverable from the repository.** `JOURNAL/OPEN_QUESTIONS.md` OD-06
records three separate searches (2026-08-19, 2026-08-20, and again during
PCE01) that found no URLs, no manifest rows, no audio dependency. The entry
carries an explicit instruction: "**Do not guess or invent those repositories.**
A plausible-looking URL recorded here would be worse than an acknowledged gap."
They must be resent by the owner. **VAWO01 must not invent one.**

OD-06 also fixes the order of work when it opens: recover the source → audit
licensing → audit Flutter/mobile compatibility → audit formats/looping/memory →
decide source vs custom-generated → integrate through **one coherent audio
layer**, not per-screen playback calls.

### 10.4 Tooling that DOES exist

| Tool | Location | State |
|---|---|---|
| `gen2.mjs` (Stable Audio runner) | `AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs`, duplicated in `stable_audio_bakeoff_00/tools/` | Working, complete. Node + FormData. Supports text-to-audio and audio-to-audio on both sa25 and sa3. Reads the key from env only; never logs it. Writes provenance JSON before, during and after every call, including `credits_before`/`credits_after`/`credit_cost`. Exits 2 without the key. |
| `gen.mjs` (v1) | `stable_audio_bakeoff_00/tools/gen.mjs` | Superseded by gen2 |
| Job JSON schema | 34 example job files across both workstreams | `{id, family, prompt, seed, duration, output_format, provDir, outDir}`; `family` ∈ `sa25`\|`sa3` |
| Provenance patch scripts | 10 `patch_*.mjs` under `audio_presentation_01/tools/` | Record gate rulings into provenance JSONs |
| **ffmpeg 9.0** | `C:\Users\jwspa\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0-full_build\bin\ffmpeg.exe` | **Installed and working, NOT on PATH.** Verified by probing all ten shipped assets. Must be invoked by full path or prepended to PATH. |
| ffprobe | Same directory | Same |
| sox | — | **Not installed** |
| node | `C:\Program Files\nodejs\node` | On PATH |
| `Scripts/` audio tooling | — | **None.** `Scripts/` holds 20 guard scripts, `Scripts/art/` (4 JS files for image packaging), `Scripts/ios/`, `Scripts/lib/`. **No audio script of any kind, and no ffmpeg or sox invocation anywhere in `Scripts/`.** All audio packaging to date was done by hand-run ffmpeg commands recorded in `assets/audio/v1/README.md`. |

### 10.5 What this means for VAWO01, concretely

**Available at zero credits, today:**

1. **All runtime architecture work** — the cue tables (combat/reward/UI), the
   duck, `setCombat`, the voice cap and priority system, the `fallbackTo` field
   and its resolver, the trigger wiring at every site the matrix names. This is
   the majority of the matrix and none of it needs a sound file.
2. **Deterministic ffmpeg processing** of existing accepted assets — the
   cooking re-trim (§3.3, needs one owner listening pass), the mining limiter
   re-master (§3.2, changes packaging class, owner ruling required), the mining
   anchor swap to the unshipped `MINING_AP1_SA25_4101` (free but a creative
   re-acceptance).
3. **Re-measurement** of the five shipped SFX for LUFS-M max, and of the
   unshipped candidates sitting in `AUDIO/evaluation/` — 40+ already-paid-for
   candidate files exist there and have never been re-auditioned against the
   current mix.
4. **Placeholder routing** — the matrix's two PLACEHOLDER rows
   (`combat.impact.player.01 → craft.smithing.01`; craft completions → the
   profession's terminal strike). Both are owner-gated and both revert to
   silence at zero cost.

**Not available without the owner:**

- Any new sound. No key, no credits, no alternative sanctioned provider
  configured, no recovered GitHub source.
- ElevenLabs is *permitted* by `DECISIONS/0005` but has no key configured and
  was ruled out of evaluation by the bake-off ("do not provider-hop").

---

## 11. Tests and how to run them

### 11.1 The audio test files

| File | Contents |
|---|---|
| `test/audio/audio_assets_test.dart` (131 lines, 8 tests) | Every asset ID resolves to a file that exists **and** is declared in `pubspec.yaml`; every region key is a real location in `locations.json`; the five shipped regions specifically; every action-cue key is a real skill; the ID convention regex; **every skill cue names an asset the tables define**; every region music key names a defined asset; a cue naming an unknown asset resolves to silence, never a throw |
| `test/audio/audio_controller_test.dart` (384 lines, 5 groups, 14 tests) | *region music mapping* — every playable region starts its accepted track; the same region never restarts it; a region change ends with exactly one live channel faded in; unknown/null location is silence. *action cues* — each profession fires its one cue at its trimmed volume; a trim only ever attenuates and mining is the untouched floor; cooking fires on every stir; the cooldown floor swallows a double-fire but not the next beat; a skill with no cue is silent. *the master switch* — off pauses music, refuses cues, remembers the assignment; off→travel→on plays the NEW region once. *lifecycle* — background pauses, resume resumes the same channel. *settings persistence* — a change survives into a fresh store; a missing or corrupt file loads defaults, never throws |
| `test/activity_beat_audio_test.dart` | The M-16 regression pin: the working loop's action beat must keep its timing under Reduce Motion while the picture holds still. Uses `testWidgets`. A future change that silences one to achieve the other fails here |
| `test/gather_rarity_parity_test.dart` | Touches audio only incidentally (gather rarity through the result card) |

Also relevant: `s01a_vertical_slice_test.dart` §14 forbids `Timer.periodic` in
`lib/`, which the audio layer's fade machinery is written against.

### 11.2 How to run

Flutter and the JDK are **not on PATH** in this environment. Export first:

```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
```

Without the second, every `dart`/`flutter` call exits 127, and
`Scripts/verify.sh` without `--strict` treats an absent toolchain as a **skip** —
a run can report success having verified nothing.

```bash
# The audio suites alone
flutter test test/audio/

# Including the beat regression
flutter test test/audio/ test/activity_beat_audio_test.dart

# One test by name
flutter test test/audio/audio_controller_test.dart --plain-name "cooking fires on every stir"

# The whole app suite as CI runs it
flutter test --exclude-tags golden
```

`ffmpeg` for any measurement work:

```bash
export PATH="/c/Users/jwspa/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0-full_build/bin:$PATH"
ffmpeg -i CAND.wav -af ebur128=peak=true:framelog=verbose -f null -
```

### 11.3 CI reality

`.github/workflows/ci.yml:307` runs `flutter test --exclude-tags golden` for the
app suite. **But CI is currently RED and never reaches it**:
`check-ui-boundary.sh` runs unconditionally at line 125, *before* the analyzer
and the suites, and fails on a pre-existing `lib/ui/state/craft_memory.dart`
violation (`path_provider` import at :29, `File()` at :47 and :81) introduced by
GFCP01 `830f1a1`. **Every suite figure quoted for this branch is a local run,
not a CI result.** PCE01 §11 states this must close before the branch merges.

Golden tests are excluded from CI deliberately (`dart_test.yaml`) — reference
images were captured on Windows and Flutter's text rasterization differs on the
Linux runner.

---

## 12. What VAWO01 should know before it starts

1. **The design work is done and is high quality.** `02_AUDIO_EVENT_MATRIX.md`
   and `AUDIO_PRODUCTION_QUEUE_01.md` are implementation-ready: every cue has a
   trigger site with a file and line number, a priority, a cooldown, a duck
   depth, a haptic pairing, a verbatim prompt, a seed, a cost and a written
   rejection criterion. **Both are DRAFT and neither is owner-accepted.** The
   first VAWO01 decision is whether to adopt them as-is.
2. **The two draft documents disagree on P0 composition in four places.** The
   queue's §8 lists the differences for the owner and DIR-D to settle. No
   prompt, seed or acceptance criterion is affected — only which batch a cue
   sits in.
3. **A large amount of value is available at zero credits.** The entire runtime
   half of the matrix — cue tables, priority, voice cap, duck, `setCombat`,
   fallback chains, and trigger wiring at ~20 sites — costs nothing and can be
   built and tested before a single sound exists, because `fileFor()` already
   makes an unresolved cue silent rather than fatal.
4. **Four free listening passes are queued and blocking nothing else:** the two
   placeholder rows, the cooking re-trim, and the mining limiter/anchor-swap
   choice (Q-17). Each reverts at zero cost.
5. **Combat has no Reduce Motion path at all** and no voice cap. Adding
   segment-placed combat cues before those two exist would reproduce M-16's
   failure class in a new channel — under Reduce Motion an entire 2.5 s round's
   cues arrive inside ~125 ms. Q-16 is UNRESOLVED and should be answered before,
   not after.
6. **Do not add `reward.loot.01` or a coin/jackpot flourish.** It is excluded by
   an explicit creative ruling that names slot-machine audio as forbidden.
7. **Do not invent a GitHub audio URL.** OD-06 forbids it by name.
8. **Do not spend credits without the owner reopening generation in writing**,
   and read the live balance before anything else when it does reopen — never
   trust the recorded 61.
9. **Transport lessons are paid for.** `Accept: audio/*`, never
   `Accept: application/json` — six SA3 calls with the JSON transport returned
   HTTP 500 `internal_shape` with no audio and **burned 156 credits**. Fire one
   call, verify, then fire the batch.
10. **Produce hot, ship trimmed.** `ActionCue.trimDb` can only attenuate, so a
    quiet take is unfixable without a re-master, and a re-master of an accepted
    asset is an owner ruling. Mining is the standing proof.
