# AUDIO_PRESENTATION_01 — the playable audio foundation

**Status:** Implementation complete, awaiting owner review and physical-device
acceptance.
**Record of:** the first production audio workstream — asset generation
through five owner gates, then the minimum runtime layer.
**Authority relationships:** sourcing and the manifest contract are
`DECISIONS/0005`; the manifest itself is `AUDIO/AUDIO_ASSET_MANIFEST.md`;
the dependency record is `DEPENDENCIES.md`; this document records what was
built, what was ruled, and what is deferred.

---

## 1. The accepted asset foundation

Every asset passed the owner's ear **before** integration; nothing was
integrated on generation-day confidence. Provider: Stability AI Stable Audio
(`DECISIONS/0005`'s generated-assets lane; the bake-off that ruled the
provider and the music identity is `AUDIO/evaluation/stable_audio_bakeoff_00/`).

**Region music** (stable-audio-3, cfg 4, steps 8, 150 s, −14 LUFS matched):

| Region | Accepted generation | Seed |
|---|---|---|
| Haven's Rest | HAVEN_R3_PIANO_A2A_3101 (a2a 0.6 of HAVEN_R2_SA3_2101_cfg4) | 3101 |
| Whispering Woods | WOODS_AP1_SA3_5101 | 5101 |
| Stonefall Mine | STONEFALL_AP1_SA3_5201 | 5201 |
| Frostmere | FROSTMERE_R3_PIANO_A2A_3201 (a2a 0.6 of FROSTMERE_R2_SA3_2201_cfg4) | 3201 |
| Forgotten Hollow | HOLLOW_AP1_SA3_5301 | 5301 |

**Profession action cues** (stable-audio-2.5, one per activity by owner
ruling):

| Activity | Accepted generation | Seed | Gate history |
|---|---|---|---|
| Mining | MINING_AP1_SA25_4102 | 4102 | Gate 1 — passed first round (bake-off's 1401–1403 cymbal set had been rejected) |
| Woodcutting | WOOD_AP1_SA25_4203 | 4203 | Gate 2 |
| Foraging | FORAGE_AP1_SA25_4301 | 4301 | Gate 2 |
| Smithing | SMITH_AP1_SA25_4401 | 4401 | Gate 3 — single candidate, accepted |
| Cooking | COOK_AP1_SA25_4503 | 4503 | Gate 5 — third attempt; 4501 (utensil-dominated) and 4502 (vague stir texture) rejected and retained as reference |

Credits: the workstream opened at 399 and closed generation at **61**
(mining 60, gathering 120, smithing 20, cooking+regions 98, cooking
corrections 40). No further Stability spend without the owner explicitly
reopening generation.

Full provenance — prompts, seeds, request/generation IDs, hashes,
measurements, per-gate rulings — sits beside every raw file under
`AUDIO/evaluation/audio_presentation_01/` (evaluation material, deliberately
untracked; the shipped copies and the manifest carry everything canon needs).

## 2. Owner rulings recorded here

- **One strong cue per core activity.** No variant families, no rotation
  system; `.01` suffixes leave room. Variants come only if device play
  proves a repeated cue distracting.
- **Cues punctuate what the player watches.** They fire on visible
  animation beats; never tied to activity duration, step consumption, or
  queued/background progression. An unwatched queue is silent by design.
- **No long audio for long activities.** Short cues on beats; region music
  is the only continuous audio.
- **Combat keeps the regional music** and has no bespoke SFX this phase.
  Intentional, not an omission.
- **The Stonefall tail note is technical**, resolved by a 2 s packaging
  fade for loop wrap — never a reason to regenerate the accepted track.

## 3. The runtime layer (this milestone's build)

- **`lib/audio/`** — outside the UI boundary, reachable from nothing in
  `stride_core`:
  - `audio_cues.dart` — semantic key → asset ID → file (`DECISIONS/0005`'s
    indirection, in code); region and skill tables; per-cue anti-stack
    cooldowns.
  - `audio_controller.dart` — the one app-scoped owner. MUSIC bus: one
    region track, crossfade on region change (chained one-shot timers;
    `Timer.periodic` stays forbidden), same-assignment is a structural
    no-op so tabs/pushes/combat never restart the track. SFX bus:
    `playSkillCue` with cooldown floor. AMBIENCE: architecture only, no
    content. Lifecycle observer pauses on background, resumes in place —
    no background modes, no entitlement changes.
  - `audio_settings.dart` / `audio_settings_store.dart` — enabled +
    per-bus volumes, one JSON file in application support **beside, never
    inside** the save directory (`DECISIONS/0013` untouched); defaults ON,
    music 0.55 under SFX 0.9.
  - `audio_output.dart` — the `audioplayers` seam (`DEPENDENCIES.md` for
    the dependency record); `silent_audio_output.dart` — the widget-test
    fallback, silent and disabled.
- **Beats:** `AmbientStage`'s working loop fires `onActivityBeat` when it
  crosses the profession's strike frame (`AmbientAssets.strikeFrameFor`,
  authored beside the loops); the one-shot gather fires `onGatherCue` as it
  starts playing — on the result, never the tap, so a refused gather stays
  silent. Adventure and Craft stages wire both to the skill's cue. Leaving
  a screen unmounts the loop and the beats stop with it.
- **Settings UI:** an Audio block on the Character tab — sound on/off,
  music and effects in tenths. No ambience control (no content), no mixer
  screen.
- **Assets:** `assets/audio/v1/` (~19 MB of the 30 MB budget), mastered by
  deterministic ffmpeg packaging only — provenance in that directory's
  README and the manifest.

## 4. Verification

- App suite **646** (was 629; +17 audio: region mapping, single-channel
  crossfade ownership, cue mapping/cooldown, master switch, lifecycle,
  settings persistence and corrupt-file defaults, asset/manifest/pubspec
  agreement, ID convention).
- `flutter analyze` clean; dependency-policy, ui-boundary, single-writer,
  core-purity guards all green; Android debug build proves the plugin and
  asset bundling compile.
- Package suites untouched (no package changed).

## 5. Deferred, deliberately

Ambience production (all regions, forge bed, cooking hearth), combat SFX,
enemy sounds, battle music, World/Travel music, reward/rarity stingers, UI
click sounds, travel SFX, per-material cue variants, any DSP beyond volume,
haptics coupling. Each waits for the first integrated device build to show
a concrete need.

## 6. Polish observations (logged, not built)

- Strike-frame indices are first-pass loop-structure guesses; retune by ear
  on the device if a cue reads early/late against the tool contact.
- Initial mix (music 0.55 / SFX 0.9 defaults) is a first guess for phone
  speakers; the settings block covers per-player taste meanwhile.
- AAC loop wrap on region tracks relies on the composed fade tails; if the
  wrap reads abrupt on device, a controller-side end-crossfade is the next
  step (architecture already holds two channels).
- `AudioContextConfig(respectSilence: true)` honours the iOS mute switch;
  if the owner prefers game audio over the switch, it is a one-line change.

## 7. Device acceptance checklist

1. Launch: audio on by default, current region's track playing.
2. Travel Haven → Woods → Stonefall → Frostmere → Hollow: each region's own
   track, clean crossfade, no restart on tab changes within a region, no
   restart returning from combat or an activity screen in the same region.
3. Gathering: mining/woodcutting/foraging cues land on the visible strikes,
   single gathers included; comfortable under repetition.
4. Crafting: smithing hammer and cooking sizzle on the bench stage's beats.
5. Long activities: cues only while watching; leaving the screen silences
   them; queue mechanics unchanged.
6. Combat: regional music continues; no combat SFX expected.
7. Background/foreground: pause and resume in place; no duplicates, no
   stacked players; mute switch respected.
8. Settings: Character tab block — toggle and both volumes work and survive
   relaunch.
