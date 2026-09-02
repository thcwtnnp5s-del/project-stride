# DIR-14 — Audio (EPO03 wave 1)

**Audio Director** · `fable5-executive-production-overhaul-03` @ `9cabe4f` · 0 generations, 0 files, code untouched.

## 1. Recorded once — milestone record §6, verbatim

> Audio was audited at wave 0 (`GOV-06`) and ruled NO-GO: `STABILITY_API_KEY`
> unset, no permitted alternative route, nothing in `AUDIO/evaluation/`
> packageable for a queued event. The 22 owed files (21 `EventCues` ids plus
> the cooking-stir swap) stay silent by design via `AudioCues.fileFor → null`;
> their briefs, filenames, priorities, gaps, ducks and trims are already
> authored in `AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` §5 and `_03.md` §5 and
> guarded by `test/audio/event_cue_readiness_test.dart`. EPO03 produced zero
> audio files, spent zero credits and did not debug credentials. The gap
> closes one row per file when a key exists.

## 2. Zero-file improvements

| # | Change (≤10 lines) | Felt now |
|---|---|---|
| 1 | **Combat commits have no haptic.** `lib/ui/screens/combat/combat_screen.dart` — Attack (`:719`), Eat choice (`:784`), Retreat (`:801`) `onPressed`: prepend `AudioScope.maybeRead(context)?.hapticLight();` (Attack: wrap `c.combatAttack` in a closure). Matrix §2.5 assumes "the existing haptic" at Attack; none exists. Brace got its pulse in FMPO02; the most-pressed button did not. Same weight as Brace, Craft-begin, Travel-start. | **Yes** |
| 2 | Same sites: `AudioEvents.commit(AudioScope.maybeRead(context));` beside the haptic, plus one import. Wires §2.5; silent until `sfx_ui_commit_01.wav`. | No |
| 3 | **Telegraph timing.** `combat_choreography.dart` `choreograph`: `RoundEndedBeat` segment (`:391`) gains `startCue: b.telegraph ? StageCue.heavyTelegraph : null`; heavy `EnemyStruckBeat` `startCue` (`:358`) becomes `StageCue.enemyAttack`. Matrix §2.1 puts the "question" where the HUD line brightens, before the Brace decision — not 500–625 ms before the blow. No test asserts placement. | No |
| — | **Gap floors:** `enemy.defeated`(30) → `reward.*`(30, gap 400) is ≥400 ms apart (WonBeat ≥ `_afterBlow`); swing→impact passes on priority. **None.** | |
| — | **Duck:** nothing ducks until a file exists. Drift recorded: code holds 260 ms and snaps; matrix §3.4 wants 120 ms attack, cue-length hold, 700/1400 ms release, and a `setCombat` −3 dB that does not exist. Systems change — **none.** | |
| — | **Ambience:** `music.stonefall_mine.01` is already the Stonefall bed; the evaluation beds have no cue slot, no per-file licence. **None.** | |

## 3. Dangling reference

`lib/audio/audio_cues.dart:273` and `DECISIONS/0032_REDUCE_MOTION_AUDIO_CONTINUITY.md:106` cite `AUDIO/AUDIO_PRODUCTION_BRIEF_VAWO01.md`, which never existed. Correct target: **`AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` §5** (the 20 VAWO01 briefs) plus **`_03.md` §5** for `ui.commit.01`, which "every id below" now covers. The `0030 §4` pointer beside it is sound. Fix 0032 by errata line, not rewrite.

## 4. First three commands for a keyed session

Owner exports `STABILITY_API_KEY` before launch; the session reads no key file and never echoes the value.

```sh
test -n "$STABILITY_API_KEY" && echo KEY_SET || echo KEY_UNSET
node -e "fetch('https://api.stability.ai/v1/user/balance',{headers:{Authorization:'Bearer '+process.env.STABILITY_API_KEY,Accept:'application/json'}}).then(r=>r.json()).then(j=>console.log('credits',j.credits))"
cd AUDIO/evaluation/audio_production_02 && node ../audio_presentation_01/tools/gen2.mjs tools/job_reward_victory_7101.json
```

Command 2 is `gen2.mjs`'s own `/v1/user/balance` call without its 20-credit spend; plan against it, never the remembered 61. Command 3 presupposes `tools/ provenance/ reward/raw/` and one job JSON in the `job_smith_4401.json` shape — `family: "sa25"`, verbatim QUEUE_02 §5.2 brief prefixed `TrackType: SFX.`, `seed: 7101`, `duration: 4`, `wav`, `provDir: "provenance"`, `outDir: "reward/raw"` (matrix §6 P0 row 1). Then GOV-06 §4 steps 4–11.
