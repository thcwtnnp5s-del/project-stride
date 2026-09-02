# GOV-06 — Audio Capability / Credential Audit

**Role:** Audio Capability / Credential Auditor
**Date:** 2026-09-01
**Scope:** Facts only — can audio be produced in this session, and if not, exactly what unblocks it.

---

## 1. Providers used before

**Only Stability AI Stable Audio has ever been called.** ElevenLabs is *permitted* by
`DECISIONS/0005_AUDIO_SOURCING.md` and `AUDIO/AUDIO_ASSET_MANIFEST.md` but no script,
provenance file, or manifest row shows it was ever used.

Runner scripts (identical logic, two copies):
- `AUDIO/evaluation/stable_audio_bakeoff_00/tools/gen.mjs` (v2, text-to-audio only)
- `AUDIO/evaluation/stable_audio_bakeoff_00/tools/gen2.mjs` and
  `AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs` (v3, adds audio-to-audio; byte-identical to each other)

Facts read directly from `gen2.mjs`:
- **Env var:** `process.env.STABILITY_API_KEY` — exits 2 if unset, never logged.
- **Base URL:** `https://api.stability.ai`
- **Endpoints:**
  - `/v2beta/audio/stable-audio/text-to-audio` (model `stable-audio-3`)
  - `/v2beta/audio/stable-audio-2/text-to-audio` (model `stable-audio-2.5`)
  - `/v2beta/audio/stable-audio/audio-to-audio` and `/v2beta/audio/stable-audio-2/audio-to-audio` (when `job.source` is set)
  - `/v2beta/audio/results/{generation_id}` (poll, up to 120×5s)
  - `/v1/user/balance` (credit check, `Accept: application/json`)
- **Auth:** `Authorization: Bearer <key>` header only.
- **Invocation:** `node gen2.mjs <job.json>`, one job file per candidate (`tools/job_*.json`).
- Patch scripts (`patch_accept_*.mjs`, `patch_reject_*.mjs`, `patch_prov_*.mjs`) only rewrite local provenance JSON status fields — no network calls, no keys.

Cost model (from `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md`): stable-audio-2.5 = 20 credits flat per generation; stable-audio-3 = 26 credits at 150s. Last **recorded** balance: 61 credits, 2026-08-24 — unverifiable live without a key.

## 2. Are any keys available? — NO

- `env | grep -iE "stable|eleven|api|key|token"` → only `ANTHROPIC_BASE_URL`, `API_TIMEOUT_MS`, `BAGGAGE`, `CLAUDE_CODE_MESSAGING_TOKEN` are set. **No `STABILITY_API_KEY`, no `ELEVENLABS_API_KEY`.**
- `find . -iname ".env*"` (excluding node_modules/build) → **no matches anywhere in the repo.**
- No script references a key file path (no `~/.stable_audio_key` or equivalent) — `gen2.mjs` reads the environment only, by design ("Never logs it").
- `~/.claude` (`C:\Users\jwspa\.claude`) contains only `settings.json`, `.last-cleanup`, and session/backup/telemetry directories — no key-shaped files present (checked presence only, no values read).
- This matches the project's own written record: `PROJECT_STATE.md`, `AUDIO/AUDIO_PRODUCTION_QUEUE_01.md`, `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md`, and `MILESTONES/VISUAL_AUDIO_WORLD_OVERHAUL_01.md` all independently record `STABILITY_API_KEY` (and `ELEVENLABS_API_KEY`) as unset and generation as blocked, most recently as of VAWO01 (2026-09-02 doc date).

## 3. Runtime audio architecture

Files in `lib/audio/`: `audio_controller.dart` (612 lines), `audio_cues.dart` (413), `audio_output.dart`, `audio_settings.dart`, `audio_settings_store.dart`, `silent_audio_output.dart`.

**`AudioCues.files` — 10 mapped asset IDs (all shipped, AUDIO_PRESENTATION_01):**
```
music.haven.01, music.whispering_woods.01, music.stonefall_mine.01,
music.frostmere.01, music.forgotten_hollow.01,
gather.mining.01, gather.woodcutting.01, gather.foraging.01,
craft.smithing.01, craft.cooking.01
```

**Unmapped (wired in `EventCues`, resolve to silence via `AudioCues.fileFor` → null) — 20 IDs**, `AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` §4:

Combat (11): `combat.encounter.begin.01`, `combat.swing.player.01`, `combat.impact.player.01`, `combat.attack.enemy.01`, `combat.impact.enemy.01`, `combat.telegraph.heavy.01`, `combat.impact.heavy.01`, `combat.brace.01`, `combat.brace.absorb.01`, `combat.heal.01`, `combat.enemy.defeated.01`

Reward/completion (9): `reward.victory.01`, `reward.retreat.01`, `reward.discovery.01`, `reward.levelup.01`, `reward.milestone.01`, `craft.complete.minor.01`, `craft.complete.food.01`, `craft.complete.gear.01`, `gather.complete.01`

**Voice cap / priority / duck (`audio_controller.dart`):**
- `_voiceCap = 2` (max 2 recent concurrent voices; new cue rejected if at cap unless it clears the stream floor).
- Priority bands (`EventCue.priority`): 30 outcome, 20 impact, 10 intent, 5 texture (texture unused today). A cue at or below `_lastEventPriority` is blocked within `minGapMillis`; strictly higher priority can cut through.
- Ducking: `_applyDuck` — deepest duck wins while cues overlap; music bus multiplied by `max(musicVolume * duck, musicVolume * 0.35)` (floor so a duck can never fully silence music); bed restored after `holdMillis + 40` unless a later cue extended `_duckUntil`.
- Haptics live in the same controller (`hapticLight/Medium/Heavy/Selection`), gated by `_settings.hapticsEnabled` and a per-strength floor in `_hapticFloorMillis`.

**`test/audio/event_cue_readiness_test.dart` contract:** every `EventCues` entry must (a) name an asset ID matching `<category>.<subject>.<variant>`, (b) not share an asset ID with another event, (c) resolve today to a real file or to silence (no crash), (d) for every still-unproduced event: priority > 0, minGapMillis > 0, duckDb ≤ 0, trimDb ≤ 0, and (e) the queue doc (`AUDIO_PRODUCTION_QUEUE_02.md`) must literally contain every unproduced asset ID — the test fails if doc and table drift.

**"One row per file" contract confirmed** (`AUDIO_PRODUCTION_QUEUE_02.md` §2): produce file → save to `assets/audio/v1/sfx/<name>` → one row in `AudioCues.files` → one manifest row. No cue table, screen, or controller change.

**Profession/UI cue check** (mining strike, ore fracture, woodcut chop, wood crack, forage rustle/collect, smith hammer/finish, cook prep/simmer/finish, confirm, equip, craft begin/finish):
| Cue | Status |
|---|---|
| Mining strike | **Exists** — `gather.mining.01`, one shared cue for all ore (owner ruling: one cue/activity this phase) |
| Ore fracture (separate) | **Missing** — no per-material or per-stage variant; ruled out for this phase |
| Woodcut chop | **Exists** — `gather.woodcutting.01`, shared across all tree nodes |
| Wood crack (separate) | **Missing** — same one-cue-per-activity ruling |
| Forage rustle / collect (separate beats) | **Missing as two** — single `gather.foraging.01` covers both; no split |
| Smith hammer | **Exists** — `craft.smithing.01` (action loop); **finish** = `craft.complete.gear.01` — **unproduced**, queued |
| Cook prep/simmer | **Exists** — single `craft.cooking.01` covers the loop; **finish** = `craft.complete.food.01` — **unproduced**, queued |
| Confirm (`ui.confirm`) | **Does not exist as a runtime asset ID anywhere.** `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md` documents a *planned* unified `ui.commit.01` (covers Set out/Craft/Gather/Engage/Attack/Brace/Equip/Deliver) currently marked **SILENCE — P2** in that design doc; not present in `lib/audio/audio_cues.dart` `EventCues`/`skillCues` at all. Not implemented, not queued in `AUDIO_PRODUCTION_QUEUE_02.md`. |
| Equip (`ui.equip`) | **Does not exist** as a distinct id — same doc notes `ui.equip.01`/`ui.travel.setout.01` are folded into the same planned `ui.commit.01`; not in code. |
| Craft begin (`craft.begin`) | **Does not exist** — no begin-of-craft cue in `EventCues` or `skillCues`; only craft *completion* cues (`craft.complete.minor/food/gear`, all unproduced) are queued. |

Net: the 20-event queue in `AUDIO_PRODUCTION_QUEUE_02.md` is exhaustive for what's wired today. `ui.confirm`/`ui.equip`/`craft.begin` are **design-doc concepts only**, not present in code and not in the current production queue — outside GOV-06's "20 queued events" scope but flagged as a gap between the event-matrix design doc and the shipped `AudioCues`/`EventCues` tables.

## 4. Local tooling for audio processing

- `ffmpeg`: **not found** (`which ffmpeg` → no match in PATH).
- `sox`: **not found**.
- `node`: found — `C:\Program Files\nodejs\node` (used by all `gen*.mjs` runners).
- `npm`: found — `C:\Program Files\nodejs\npm`.
- `python3`: found — `...\WindowsApps\python3` (Windows App Execution Alias; unverified as a real interpreter without further probing).
- No audio-processing node packages anywhere in the repo. The only `node_modules`/`package.json` in-repo is `Scripts/tooling` (`stride-guard-tooling`), whose sole dependency is `@xmldom/xmldom` for XML/plist guard parsing — unrelated to audio, not shipped, not linked to Dart/native code.
- Conclusion: **no local mastering/encoding tool is available.** The README-documented packaging (gain to exact dBTP, AAC 192kbps encode, fades) that produced the shipped v1 assets was done with tooling not present in this environment/session — ffmpeg is referenced only prospectively (a "deterministic limiter re-master" is queued as future work using "fixed, recorded ffmpeg parameters") and is not installed now.

## 5. Loudness/format conventions (from `assets/audio/v1/README.md` and the manifest)

- **Music:** AAC 192 kbps `.m4a`, 150 s per track. Mastered to **−15.5 LUFS integrated**, uniform −1.5 dB gain across all five tracks, true peak ≤ −1.0 dBTP after AAC encode.
- **SFX:** WAV, 44.1 kHz, 16-bit, stereo. Mastered to **−1.0 dBTP** per-file peak (not loudness).
- Consequence documented as a defect and fixed at the *playback* layer, not by re-mastering: SFX peak-only mastering produced a 10.4 dB LUFS-M spread (smithing −10.0 to mining −20.4); `ActionCue.trimDb` in `audio_cues.dart` pulls anything above a **−17.0 LUFS-M ceiling** down to it, leaving natural ordering (residual spread 3.4 dB). Mining is the floor and cannot be raised without a source re-master (queued, owner call).
- Any newly generated SFX for the Queue 02 events should be expected to need the same treatment: peak-normalize to ~−1.0 dBTP at generation/packaging time, then set `trimDb` per-cue against the same −17.0 LUFS-M ceiling before shipping, per the existing convention.

## 6. Haptics

Wired centrally in `lib/audio/audio_controller.dart` (`hapticLight()`, `hapticMedium({payoff})`, `hapticHeavy({payoff})`, `hapticSelection()`), each gated by `_settings.hapticsEnabled` and rate-limited via `_hapticFloorMillis` per strength (`_admitHaptic`). Uses `package:flutter/services.dart` `HapticFeedback.lightImpact/mediumImpact/heavyImpact/selectionClick`.

Call sites found in `lib/`:
- `ui/components/activity_result.dart:394` — light, on the universal Activity Result card.
- `ui/components/reward_layer.dart:79,81` — heavy/medium payoff haptic scaled to reward tier.
- `ui/screens/adventure/activity_panel.dart:518` — light.
- `ui/screens/adventure/adventure_screen.dart:250` — light, per visible loop strike.
- `ui/screens/adventure/adventure_screen.dart:552` — light, on a banked step-sync.
- `ui/screens/combat/combat_choreography.dart:119` — heavy blow landing (referenced in a comment; confirms combat haptic exists).
- `ui/screens/adventure/encounter_card.dart:319` — medium.
- `ui/screens/character/step_tracker_screen.dart:188` — light.

Settings: `hapticsEnabled` (default `true`) in `lib/audio/audio_settings.dart`, toggled independently of audio volume in `ui/screens/character/audio_block.dart` — a separate accessibility axis from sound, and independent of the OS-level System Haptics switch (per the code comments).

## Verdict

**CAN AUDIO BE PRODUCED IN THIS SESSION? NO.**

The only provider ever used (Stability AI Stable Audio) and the only alternative permitted by policy (ElevenLabs) both require an API key read from environment variables that are **not set** in this shell, and **no `.env` file, key file, or credential of any kind exists anywhere in the repo or in `~/.claude`**. `gen2.mjs` exits with code 2 immediately if `STABILITY_API_KEY` is absent — this is a hard stop, not a workaround-able one, and no local ffmpeg/sox exists to synthesize or process audio as a substitute.

**Exact blocker:** `STABILITY_API_KEY` environment variable unset.

**What the owner must do to unblock the next session, with zero code changes:**
1. Set the environment variable `STABILITY_API_KEY` (value = the Stability AI account API key) in the shell that runs the session — e.g. `export STABILITY_API_KEY=sk-...` before launching Claude Code, or via the OS environment.
2. That's the only requirement. `gen2.mjs` at `AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs` (or the bakeoff copy) reads `process.env.STABILITY_API_KEY` directly — no config file, no other code path.
3. If ElevenLabs is preferred/needed instead, note **no ElevenLabs runner script exists yet** — one would need to be written (not just a key supplied); today only the Stable Audio path is implemented.
4. Once the key is present, confirm live balance via `node gen2.mjs` calling `/v1/user/balance` (built into every run) before spending credits — the last recorded balance (61, 2026-08-24) is a record, not a current reading, and generation costs are 20 credits (stable-audio-2.5, SFX) or 26 credits (stable-audio-3, music, 150s).
5. `AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` is production-ready as the exact brief/filename/asset-ID list for all 20 unproduced events — no further design work is needed before generating.
