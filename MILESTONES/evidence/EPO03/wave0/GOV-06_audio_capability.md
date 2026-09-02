# GOV-06 — Audio Capability Audit (EPO03 wave 0)

**Role:** Audio Capability / Credential Auditor
**Date:** 2026-09-02
**Branch:** `fable5-executive-production-overhaul-03` from `59c4723`
**Prior:** `MILESTONES/evidence/FMPO02/wave0/GOV-06_audio_capability.md` (facts there
re-checked, not re-derived; nothing found that contradicts it)

---

## 1. Go / no-go

**NO-GO for producing any audio file this round.**

Exact reason: `STABILITY_API_KEY` (and `STABILITY_AUDIO_API_KEY`) are unset in this
shell (producer-verified; no other API-key env var exists). The only runner ever used,
`AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs`, reads
`process.env.STABILITY_API_KEY` and exits 2 without it. No ElevenLabs runner has ever
been written. No `ffmpeg`/`sox` is installed, so even an already-generated raw could
not be re-mastered to the package convention (−1.0 dBTP, 44.1 kHz/16-bit WAV).

Secondary fact for the record: the last *recorded* Stability balance is 61 credits
(2026-08-24). The queued work is 22 SFX rows × 20 credits = **440 credits** if
generated singly with no rerolls, so a key alone may not be enough — the owner
must read live balance (`/v1/user/balance`, built into every `gen2.mjs` run) before
planning the round.

## 2. Is any route other than the Stable Audio API permitted?

**Decision letter.** `DECISIONS/0005` permits: ElevenLabs (free/lowest tier),
"original or generated assets", and CC0 / properly licensed royalty-free.
`DECISIONS/0030` §2 amends 0005 to name **Stability AI** as a permitted generated
source, keeps ElevenLabs permitted for custom SFX, and records the owner's
tie-breaker: *"Stable accepted provider direction remains preferred. Do not
provider-hop casually."* `DECISIONS/0032` authorizes no generation at all.

| Route | Permitted by a decision? | Usable this round? |
|---|---|---|
| Stable Audio API | Yes (0005 as amended by 0030) — the preferred route | No — key unset |
| ElevenLabs API | Yes (0005, 0030) — secondary; casual hop discouraged | No — key unset, and no runner script exists |
| **Procedural / synthesized transients authored in code** | **No decision permits it, and the locked direction forbids the result.** 0005's "generated assets" was written for generation *services*; the accepted creative direction, restated in `AUDIO_PRODUCTION_QUEUE_02.md` §3 and `_03.md` §3, is *"real instruments and real materials, close-mic'd … no synthesis. No EDM, no synthwave, no arcade blips."* `RULES.md` A-1 (Claude does not manufacture production creative assets in code; escalate instead) is written for art, and no audio twin of it exists — so taking this route would be an implementation detail silently becoming a design decision (`RULES.md` G-3). **Owner decision required; not available to this round.** | No |
| CC0 / royalty-free placeholders | Yes by letter (0005) | Not exercised: never used by the studio, no sourcing tooling, requires the owner (not an agent) to select and download files and record licence + URL per manifest row; would still be second to the preferred provider under 0030's tie-breaker. Not a this-round route. |
| Package existing `AUDIO/evaluation/` material | Only if it is already-licensed material selected for a queued event — see below | **No — nothing there targets a queued event** |

### `AUDIO/evaluation/` — inventory (652 MB, untracked; nothing staged, nothing committed)

`.gitignore` lines 341–350 already ignore every `*.wav/*.mp3/*.flac/*.zip` under it and
whitelist only `provenance/*.json`, `tools/*.mjs`, `INDEX*.md`. `git status` shows
`?? AUDIO/evaluation/` — the whitelisted text files are untracked, not staged.

File counts by type: **76 json** (41 provenance records, incl. 6 `*.FAILED.json`;
35 `tools/job_*.json` runner inputs), **52 wav**, **18 mp3**, **13 mjs**, **9 zip**
(listening packages), **9 md** (indexes), **1 txt**.

Audio content, by round:

| Directory | Files | What it is | Status (from `provenance/*.json`) |
|---|---|---|---|
| `stable_audio_bakeoff_00/{haven,frostmere}/` | 6 wav + 6 mp3 | Round-1 region music, 150 s, SA3 | `EVALUATION_CANDIDATE` — direction rejected (too electronic) |
| `stable_audio_bakeoff_00/stonefall/` | 3 wav + 3 mp3 + 1 loop-test wav | "Underground mine ambience", 75 s, SA3 | `EVALUATION_CANDIDATE` — never gated; **no `ambience.*` event exists in code** |
| `stable_audio_bakeoff_00/pickaxe/` | 3 raw + 3 listening wav | Round-1 mining strikes, SA2.5 | `EVALUATION_CANDIDATE` — rejected ("cymbal-like") |
| `stable_audio_bakeoff_00/smoke/` | 1 wav | API smoke test | throwaway |
| `stable_audio_bakeoff_00/round2/` | 4 wav + 4 mp3 | Haven/Frostmere acoustic anchors | `EVALUATION_CANDIDATE`; 2101/2201 are the a2a sources of the shipped tracks |
| `stable_audio_bakeoff_00/round3/` | 2 wav + 2 mp3 | Haven/Frostmere piano siblings | shipped as `music.haven.01` / `music.frostmere.01` |
| `audio_presentation_01/{mining,woodcutting,foraging,cooking}/` | 12 raw + 12 listening wav | 3 candidates per profession | 1 `ACCEPTED_DIRECTION_ANCHOR` each (shipped), 2 `REJECTED_REFERENCE` each |
| `audio_presentation_01/smithing/` | 1 raw + 1 listening | smithing strike | `ACCEPTED_DIRECTION_ANCHOR` (shipped) |
| `audio_presentation_01/music/` | 3 raw wav + 3 mp3 | Woods / Stonefall / Hollow | `ACCEPTED_DIRECTION_ANCHOR` (shipped) |

**Provenance:** every audio file is a Stability AI Stable Audio generation (model,
seed, request/generation ID, verbatim prompt, timestamp, credits in its JSON).
**Licence:** the provenance JSONs carry **no licence field**; the licence assertion
("Stability paid-tier") lives only in `AUDIO/AUDIO_ASSET_MANIFEST.md`. The same terms
would apply to any of these files — but that is inferred from the manifest, not
recorded per file.

**Packageable under the one-row contract: none.** Every file is either (a) one of
the 10 already-shipped assets or a rejected sibling of it, (b) rejected Round-1
direction, or (c) the three Stonefall ambience beds — which were never
owner-accepted and for which **no cue, asset ID or event exists in
`audio_cues.dart`** (there is no ambience table; the region music bus is the only
bed). Landing one would need a new cue slot = a code and design change, not a row.
`DECISIONS/0030` §4's "40+ already-paid-for candidate files … never re-auditioned
against the current mix" is accurate as a statement about *alternates for the ten
shipped slots*; it is not a stock of material for the 22 queued rows. **No
candidate exists for any combat, reward, completion, `ui.commit` or
`craft.cooking.stir` brief.**

## 3. Events with a call site and no file

Source of truth: `lib/audio/audio_cues.dart` `EventCues` (21 ids) +
`AUDIO_PRODUCTION_QUEUE_02.md` §5 / `_03.md` §5 filenames. `AudioCues.files` holds
exactly the 10 shipped ids; every id below resolves to silence via
`AudioCues.fileFor → null`. Call sites verified by grep this session.

### Combat — 11 (`lib/ui/screens/combat/combat_stage.dart:281–299, 364`)

| Event | Asset ID | Target file |
|---|---|---|
| `combat.enter` | `combat.encounter.begin.01` | `sfx_combat_encounter_begin_01.wav` |
| `combat.player.swing` | `combat.swing.player.01` | `sfx_combat_swing_player_01.wav` |
| `combat.player.impact` | `combat.impact.player.01` | `sfx_combat_impact_player_01.wav` |
| `combat.enemy.attack` | `combat.attack.enemy.01` | `sfx_combat_attack_enemy_01.wav` |
| `combat.enemy.impact` | `combat.impact.enemy.01` | `sfx_combat_impact_enemy_01.wav` |
| `combat.heavy.telegraph` | `combat.telegraph.heavy.01` | `sfx_combat_telegraph_heavy_01.wav` |
| `combat.heavy.impact` | `combat.impact.heavy.01` | `sfx_combat_impact_heavy_01.wav` |
| `combat.brace` | `combat.brace.01` | `sfx_combat_brace_01.wav` |
| `combat.brace.absorb` | `combat.brace.absorb.01` | `sfx_combat_brace_absorb_01.wav` |
| `combat.heal` | `combat.heal.01` | `sfx_combat_heal_01.wav` |
| `combat.enemy.defeated` | `combat.enemy.defeated.01` | `sfx_combat_enemy_defeated_01.wav` |

### Craft — 3 events (`lib/ui/screens/craft/craft_screen.dart:231–235`) + 1 swap

| Event | Asset ID | Target file |
|---|---|---|
| `craft.complete.minor` | `craft.complete.minor.01` | `sfx_craft_complete_minor_01.wav` |
| `craft.complete.food` | `craft.complete.food.01` | `sfx_craft_complete_food_01.wav` |
| `craft.complete.gear` | `craft.complete.gear.01` | `sfx_craft_complete_gear_01.wav` |
| *(not an event — `skillCues['skill.cooking']` `ActionCue` replacement, QUEUE_03 §5.2)* | `craft.cooking.stir.01` | `sfx_craft_cooking_stir_01.wav` |

### Gathering — 1 (`lib/ui/screens/adventure/adventure_screen.dart:93`)

| Event | Asset ID | Target file |
|---|---|---|
| `gather.complete` | `gather.complete.01` | `sfx_gather_complete_01.wav` |

### Reward — 5 (`lib/ui/screens/combat/combat_screen.dart:141–152`)

| Event | Asset ID | Target file |
|---|---|---|
| `reward.victory` | `reward.victory.01` | `sfx_reward_victory_01.wav` |
| `reward.retreat` | `reward.retreat.01` | `sfx_reward_retreat_01.wav` |
| `reward.discovery` | `reward.discovery.01` | `sfx_reward_discovery_01.wav` |
| `reward.levelup` | `reward.levelup.01` | `sfx_reward_levelup_01.wav` |
| `reward.milestone` | `reward.milestone.01` | `sfx_reward_milestone_01.wav` |

### UI — 1 (`AudioEvents.commit`: `craft_screen.dart:824,1658`, `inventory_screen.dart:1118`, `atlas_selection_panel.dart:723`)

| Event | Asset ID | Target file |
|---|---|---|
| `ui.commit` | `ui.commit.01` | `sfx_ui_commit_01.wav` |

### Ambience — 0

No ambience event, cue or asset ID exists in `audio_cues.dart`; region beds are music
(`AudioCues.regionMusic`, all 5 filed). The three Stonefall ambience candidates in
`AUDIO/evaluation/` have nothing to plug into.

**Totals:** 21 wired events unfiled (11 combat, 3 craft, 1 gathering, 5 reward,
1 UI, 0 ambience) + 1 ActionCue swap = **22 files owed**. Every brief is
production-ready in QUEUE_02 §5 (20) and QUEUE_03 §5 (2).

## 4. The record, and the future session's steps

### Statement for the milestone record (recorded once, moved on)

> Audio generation was audited at EPO03 wave 0 and is **blocked on credentials,
> not on design**: `STABILITY_API_KEY` is unset, no ElevenLabs runner exists, and
> no local mastering tool is installed. No decision permits code-synthesized
> transients (the locked direction is "no synthesis"), no CC0 sourcing has been
> commissioned, and `AUDIO/evaluation/` holds no candidate for any queued event —
> only alternates for the ten shipped assets and never-gated ambience beds with no
> cue to receive them. The 21 wired events and the cooking-stir swap (22 files)
> stay silent by design (`AudioCues.fileFor → null`), each with its brief, filename,
> priority, gap, duck and trim already authored in `AUDIO_PRODUCTION_QUEUE_02.md`
> and `_03.md` and guarded by `test/audio/event_cue_readiness_test.dart`. This
> round produced zero audio files and changed no audio code; the gap is visible in
> exactly two tables and closes one row at a time when a key exists.

### Steps for a future session that has a key (the one-row contract)

1. Owner exports `STABILITY_API_KEY` in the shell before launching the session.
   Nothing else is read — no config file, no key file.
2. Read live balance first: any `node AUDIO/evaluation/audio_presentation_01/tools/gen2.mjs <job.json>`
   run calls `/v1/user/balance`. Do not plan against the remembered 61.
   Full queue = 22 × 20 credits (stable-audio-2.5, `TrackType: SFX`).
3. For each row, write a `tools/job_<ID>.json` with the verbatim prompt from
   QUEUE_02 §5 / QUEUE_03 §5, model `stable-audio-2.5`, duration per brief
   (~90–700 ms; request 1 s, 2 s for the longer reward cues), a fresh seed in a new
   block (QUEUE_03 suggests 46xx for cooking-stir), and run `gen2.mjs`.
4. Save raw + provenance JSON under a new `AUDIO/evaluation/<round>/` (audio ignored
   by `.gitignore`; provenance/index whitelisted — stage by explicit path, `RULES.md` G-8).
5. Owner audition gate on iPhone; mark `ACCEPTED_DIRECTION_ANCHOR` / `REJECTED_REFERENCE`.
6. Package the accepted raw: gain-trim to −1.0 dBTP, 44.1 kHz/16-bit stereo WAV
   (deterministic gain only — `RULES.md` A-2 class; needs ffmpeg or equivalent
   installed). Measure LUFS-M max; set `trimDb` only if above the −17.0 LUFS-M ceiling.
7. Save as `assets/audio/v1/sfx/<file>` using the table name.
8. Add one row to `AudioCues.files`: `'<asset ID>': 'audio/v1/sfx/<file>',`
9. Add one row to `AUDIO/AUDIO_ASSET_MANIFEST.md` (asset ID, file, source with
   candidate name + seed, licence, model, prompt ref, date, used-by).
10. For `craft.cooking.stir.01` only: also change `skillCues['skill.cooking'].assetId`
    from `craft.cooking.01` to `craft.cooking.stir.01` (QUEUE_03 §5.2 — a one-row
    swap, not an EventCue).
11. Run `flutter test test/audio/` — `audio_assets_test` proves the row and file
    agree; `event_cue_readiness_test` proves the queue docs still name every
    still-unproduced id. Nothing else changes.

## Flags (not fixed here)

- `lib/audio/audio_cues.dart:273` and `DECISIONS/0032` cite
  `AUDIO/AUDIO_PRODUCTION_BRIEF_VAWO01.md`, which **does not exist**; the briefs live
  in `AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` §5. Stale pointer only.
- Provenance JSONs carry no licence field; the licence is asserted at manifest level.
