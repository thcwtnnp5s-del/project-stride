# FINAL-07 — Audio Director adversarial review, FMPO02 wave 3 (HEAD 9e555d3)

## Findings

1. **BLOCKER — the "one-row, no code change" claim is false for all 20 QUEUE_02
   events.** `grep -rn "playEvent(" lib/` returns exactly two hits in the whole
   app: the definition in `lib/audio/audio_controller.dart:288` and one call
   site, `lib/audio/audio_events.dart:34` (`AudioEvents.commit`). Not one of
   `combat.enter/player.swing/player.impact/enemy.attack/enemy.impact/
   heavy.telegraph/heavy.impact/brace/brace.absorb/heal/enemy.defeated`,
   `reward.victory/retreat/discovery/levelup/milestone`, or
   `craft.complete.minor/food/gear`, `gather.complete` is ever invoked from
   game code — `combat_stage.dart` fires only `hapticLight`/`hapticHeavy`
   (lines 403, 512), `reward_layer.dart` fires only `hapticHeavy`/
   `hapticMedium` (lines 80, 82), `activity_result.dart` fires only
   `hapticLight` (line 422). `AUDIO_PRODUCTION_QUEUE_02.md` §2 states "the
   only thing standing between this queue and sound is a row in
   `AudioCues.files` and a file on disk" — untrue for all 20: dropping a file
   and adding the row produces silence forever, because nothing ever calls
   `EventCues.of('combat.enter')`'s `playEvent`. The table/priority/duck
   authoring is real and safe, but "no code change" is not — each event also
   needs a new call site at its game moment. Fix: either add the 20 call
   sites now, or rewrite QUEUE_02 §2 and the readiness test's docstring to
   say "a row, a file, **and a call site**."

2. **BLOCKER — ART-11's own instruction was not carried out; equip and
   craft-begin are unwired.** `AUDIO_PRODUCTION_QUEUE_03.md` §8 records this
   exact debt ("Recorded for the integrator to add... craft_screen.dart:885...
   inventory_screen.dart:924... add `AudioEvents.commit(...)`"). At HEAD,
   `grep -rn "AudioEvents.commit" lib/` finds one call site only:
   `lib/ui/screens/world/atlas/atlas_selection_panel.dart:717` (travel-start).
   `lib/ui/screens/craft/craft_screen.dart:1582` (craft-begin,
   `AudioScope.read(context).hapticLight()`) and
   `lib/ui/screens/inventory/inventory_screen.dart:1115` (equip,
   `AudioScope.maybeRead(context)?.hapticSelection()`) each still fire only
   their haptic. Two of `ui.commit`'s four named commit sites are dead. No
   test catches this: `event_cue_readiness_test.dart` checks only that the
   tables and the queue documents agree with each other, never that a real
   call site exists. Fix: add the two lines exactly as QUEUE_03 §8
   specifies, beside the existing haptics (not in place of them), and add a
   widget test asserting `AudioEvents.commit`/`playEvent('ui.commit')` fires
   on an Equip press and a Craft-begin press.

3. **should-fix — stale "Named gaps" comment, `lib/ui/icons/traveler_art.dart:
   268-272`.** It names three loadouts as unauthored fallbacks — "plate +
   bronze axe, coat + bronze pick, base + bronze pick" — but the very map
   below it contains real entries for all three:
   `'skill.woodcutting|armor.plate|tool.axe.bronze'` (line 295),
   `'skill.mining|armor.coat|tool.pick.bronze'` (line 316),
   `'skill.mining|base|tool.pick.bronze'` (line 322). They are re-dressed
   assets, not gaps — the adjacent per-entry comments say so. A future
   session reading the doc comment alone will believe a fallback is live
   where a real (if re-skinned) strip already renders. Fix: delete or rewrite
   the "Named gaps" paragraph; it describes nothing that exists in this file.

4. **note — strike-frame authoring checks out.** Decoded all 14 new
   bronze/steel axe/pick strips in `assets/art/v1/ambient/` pixel-for-pixel
   (no image tool on this box, so a from-scratch Node PNG/zlib decoder) and
   measured each frame's western-most non-transparent pixel against the
   declared `strikeFrame` in `traveler_art.dart`'s `gatherVariants`. 13 of 14
   land exactly on the measured west-reach frame (`coat_bronzeaxe_woodcut`→f1,
   `plate_bronzepick_mine`→f0, etc.). One is off by a single pixel
   (`base_bronzeaxe_woodcut`: declared f7 at x=5, true minimum is f0 at x=4 —
   a tie within anti-aliasing noise, not a visible miss on a 393-wide device
   screen). No fix needed; `measure-reach.js`'s claim is honest.

5. **note — `combat.brace` haptic timing is correct but its sound can never
   land** (subset of Finding 1): `combat_stage.dart:403` fires `hapticLight`
   once at the braced segment's start, matching the design comment exactly.
   But `combat.brace`/`combat.brace.absorb` are EventCue ids with no
   `playEvent` call anywhere, so even a landed file plays nothing here until
   Finding 1 is fixed.

6. **Verified safe — the silence fallback holds.** `AudioCues.fileFor`
   (`audio_cues.dart:195`) and every `playEvent`/`playSkillCue` call site
   check for `null` before touching `_output.playCue`; no `!` unwrap remains
   anywhere in the resolution path. An unmapped or unproduced id is silence,
   never a crash, confirmed by reading, not just by the passing test.

## Verdict

BLOCKER: the audio "wiring" this round claims as complete is half-built —
`ui.commit` is missing two of its four call sites exactly where QUEUE_03 said
to add them, and all twenty QUEUE_02 combat/reward/completion events have no
call site at all, so the round's central promise ("a row and a file, no code
change") is false until those call sites exist.
