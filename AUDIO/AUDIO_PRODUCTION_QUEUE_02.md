# Audio Production Queue 02 — combat, reward and completion events

**Opened:** 2026-09-02 (VAWO01)
**Authority:** `DECISIONS/0005_AUDIO_SOURCING.md`, `DECISIONS/0030` (audio
reopened), `DECISIONS/0032` (Reduce Motion keeps audio continuity)
**Enforced by:** `test/audio/event_cue_readiness_test.dart` — which fails if
this document and the `EventCues` tables ever disagree.

---

## 1. What this queue is for

The event-cue architecture landed in VAWO01 **ahead of the audio itself**:
twenty combat, reward and completion events name asset IDs, ten unrelated
files are bundled, and all twenty of these resolve to silence. That is
deliberate and safe — `AudioCues.fileFor` returns null for an unproduced ID,
and null is silence, never a crash and never some other sound.

The owner's requirement for this workstream was that the last mile be a
**one-row change**:

> *"produce a final exact generation queue, verify every event can accept its
> future file with no code change."*

This document is the first half. `event_cue_readiness_test.dart` is the second:
it proves that priority, gap floor, ducking and trim are already authored for
every unproduced event, so the only thing standing between this queue and
sound is a row in `AudioCues.files` and a file on disk.

## 2. The one-row contract, stated exactly

To land any sound below:

1. Produce the file.
2. Save it as `assets/audio/v1/sfx/<file>` using the name in the table.
3. Add one row to `AudioCues.files`:
   `'<asset ID>': 'audio/v1/sfx/<file>',`
4. Add one row to `AUDIO/AUDIO_ASSET_MANIFEST.md` with its provenance.

**Nothing else changes.** No cue table, no screen, no controller, no test. The
event already knows its priority, its minimum gap, how far it ducks the music
bed, and its trim; the mixer is waiting for bytes.

## 3. Direction (unchanged from the bake-off)

Acoustic fantasy lo-fi: real instruments and real materials, close-mic'd, a
little room, no synthesis. **Avoid** techno, synthwave, EDM, arcade blips,
orchestral bombast and slot-machine payoff stings — the last of these matters
most here, because half this queue is reward audio and the reward philosophy
is *significant, never casino*.

Every cue is a **transient**, not a phrase: 120–600 ms, one gesture, no tail
that outlives the beat it answers. They fire off a state machine that can
advance several steps inside a single frame, and under Reduce Motion advances
faster still, so anything with a long decay turns to mush (`DECISIONS/0032`).

## 4. The queue — 20 unproduced events

Priority bands: **10** ordinary action · **20** something landed · **30** the
moment resolves. Gap is the floor between two firings of the same cue. Duck is
how far the music bed moves under it, held 260 ms.

| Event | Asset ID | Pri | Trim dB | Duck dB | Gap ms |
|---|---|---:|---:|---:|---:|
| `combat.enter` | `combat.encounter.begin.01` | 30 | 0 | -3 | 400 |
| `combat.player.swing` | `combat.swing.player.01` | 10 | 0 | -3 | 120 |
| `combat.player.impact` | `combat.impact.player.01` | 20 | 0 | -6 | 140 |
| `combat.enemy.attack` | `combat.attack.enemy.01` | 10 | 0 | -3 | 120 |
| `combat.enemy.impact` | `combat.impact.enemy.01` | 20 | 0 | -6 | 140 |
| `combat.heavy.telegraph` | `combat.telegraph.heavy.01` | 20 | 0 | -3 | 200 |
| `combat.heavy.impact` | `combat.impact.heavy.01` | 20 | 0 | -9 | 200 |
| `combat.brace` | `combat.brace.01` | 10 | 0 | -3 | 160 |
| `combat.brace.absorb` | `combat.brace.absorb.01` | 20 | 0 | -6 | 160 |
| `combat.heal` | `combat.heal.01` | 20 | 0 | -3 | 200 |
| `combat.enemy.defeated` | `combat.enemy.defeated.01` | 30 | 0 | -6 | 300 |
| `reward.victory` | `reward.victory.01` | 30 | 0 | -6 | 400 |
| `reward.retreat` | `reward.retreat.01` | 30 | 0 | -3 | 400 |
| `reward.discovery` | `reward.discovery.01` | 30 | 0 | -6 | 400 |
| `reward.levelup` | `reward.levelup.01` | 30 | 0 | -6 | 400 |
| `reward.milestone` | `reward.milestone.01` | 30 | 0 | -6 | 400 |
| `craft.complete.minor` | `craft.complete.minor.01` | 20 | 0 | -3 | 300 |
| `craft.complete.food` | `craft.complete.food.01` | 20 | 0 | -3 | 300 |
| `craft.complete.gear` | `craft.complete.gear.01` | 30 | 0 | -6 | 300 |
| `gather.complete` | `gather.complete.01` | 20 | 0 | -3 | 250 |

## 5. Briefs and filenames

### 5.1 Combat — 11 cues

| Asset ID | File | Brief |
|---|---|---|
| `combat.encounter.begin.01` | `sfx_combat_encounter_begin_01.wav` | One low struck note on a damped string, plus a breath of air. The fight starting, not a fanfare. ~400 ms |
| `combat.swing.player.01` | `sfx_combat_swing_player_01.wav` | A short cloth-and-air whoosh with the weight of a held weapon behind it. No metal ring — the blade has not hit anything. ~180 ms |
| `combat.impact.player.01` | `sfx_combat_impact_player_01.wav` | The Traveler's blow landing: a dull dense thud into hide with one leather-creak transient over it. Not a clang. ~220 ms |
| `combat.attack.enemy.01` | `sfx_combat_attack_enemy_01.wav` | A creature's lunge — a short scrape of claw on ground and a rush of air. Animal, never mechanical. ~180 ms |
| `combat.impact.enemy.01` | `sfx_combat_impact_enemy_01.wav` | A blow landing *on* the Traveler: duller and closer than the player's, with a cloth slap. Must read as "you were hit". ~220 ms |
| `combat.telegraph.heavy.01` | `sfx_combat_telegraph_heavy_01.wav` | The wind-up warning: a rising drawn scrape, deliberately unresolved. It has to sound like a question. ~300 ms |
| `combat.impact.heavy.01` | `sfx_combat_impact_heavy_01.wav` | The heavy landing: the normal impact's family, lower and with more body, plus one low drum. Ducks 9 dB — the loudest thing in the fight. ~350 ms |
| `combat.brace.01` | `sfx_combat_brace_01.wav` | Taking a stance: a short leather-and-strap creak, feet set. ~200 ms |
| `combat.brace.absorb.01` | `sfx_combat_brace_absorb_01.wav` | A blow arriving into a braced guard: the impact thud, damped and shortened, with a wood-on-wood knock. Reads as "that would have hurt more". ~250 ms |
| `combat.heal.01` | `sfx_combat_heal_01.wav` | A stopper pulled and a swallow, plus one soft warm bowed note. Herbal, not holy. ~400 ms |
| `combat.enemy.defeated.01` | `sfx_combat_enemy_defeated_01.wav` | A body settling into leaf litter and going still. **Not** a death cry — defeat is retreat (`RULES.md` P-7). ~450 ms |

### 5.2 Reward — 5 cues

The hard ones. These answer the same philosophy the reward art answers:
**significant, never casino.** No ascending arpeggio, no chime stack, no coin.

| Asset ID | File | Brief |
|---|---|---|
| `reward.victory.01` | `sfx_reward_victory_01.wav` | Two notes on a plucked string, the second landing lower and settling — resolution, not celebration. One soft room tail. ~600 ms |
| `reward.retreat.01` | `sfx_reward_retreat_01.wav` | The same two-note shape, unresolved and quieter, over a breath. Being driven back is a *result*, not a punishment. ~600 ms |
| `reward.discovery.01` | `sfx_reward_discovery_01.wav` | One struck bowl note with a long clean decay, a page turning underneath. Curiosity, not treasure. ~600 ms |
| `reward.levelup.01` | `sfx_reward_levelup_01.wav` | One low bowed note rising into a held open fifth, with a struck wood block on the arrival. The largest sound in the game, and still a single gesture. ~700 ms |
| `reward.milestone.01` | `sfx_reward_milestone_01.wav` | A stone set onto stone — a cairn — with one distant bowl note behind it. Distance covered, not a prize. ~600 ms |

### 5.3 Completion — 4 cues

These fire on the universal Activity Result card, so they are the **most
frequently heard sounds in the game**. Small, dry, and easy to hear a hundred
times in a session.

| Asset ID | File | Brief |
|---|---|---|
| `gather.complete.01` | `sfx_gather_complete_01.wav` | Something dropped into a pack: one soft cloth-and-contents thump. ~200 ms |
| `craft.complete.minor.01` | `sfx_craft_complete_minor_01.wav` | A finished small thing set down on a bench. One dry knock. ~200 ms |
| `craft.complete.food.01` | `sfx_craft_complete_food_01.wav` | A lid onto a pot, and a spoon set down beside it. ~250 ms |
| `craft.complete.gear.01` | `sfx_craft_complete_gear_01.wav` | Finished metal: one quenching hiss in the tail of a single hammer strike. The only cue in this section that may ring. ~400 ms |

## 6. Why nothing was generated in VAWO01

The workstream's audio budget was reopened by `DECISIONS/0030`, but sound
effects do not come from the PixelLab account this session holds — they need
the Stable Audio credentials recorded as missing at the end of the previous
workstream. The owner's instruction was explicit that this must not block the
round:

> *"AUDIO — keep the landed architecture, produce a final exact generation
> queue, verify every event can accept its future file with no code change;
> don't block on missing credentials."*

So the architecture, the mixer parameters, this queue and the readiness test
all landed, and **zero sounds were produced**. The gap is honest, and it is
visible in exactly one place: the table in §4.
