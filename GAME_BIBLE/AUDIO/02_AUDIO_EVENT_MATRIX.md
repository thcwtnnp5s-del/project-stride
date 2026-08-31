# Audio Event Matrix

**Status:** DRAFT — Audio Director (DIR-D), presentation-combat-evolution-01.
Not yet owner-accepted. No code has been changed to match this document.
**Authority:** subordinate to `PROJECT_KERNEL/`, `DECISIONS/0005_AUDIO_SOURCING.md`,
`DECISIONS/0003` (retreat-not-death) and `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`.
**Canonical for:** the cue/event id table, cue priority, cooldown, ducking,
haptic pairing, the fallback contract, and the mix structure.
**Not canonical for:** asset provenance (that is `AUDIO/AUDIO_ASSET_MANIFEST.md`)
or packaging (that is `assets/audio/v1/README.md`).

---

## 0. The rule this document exists to enforce

`01_AUDIO_IDENTITY.md` requires **three beats per major action** — initiation,
material response, reward confirmation. Today the game ships the middle beat
only, on three call sites, none of which is a commit. Every id below is placed
on a **committed, visible beat**; none is placed on a timer, a step, a duration
or an unwatched queue.

Two hard constraints bind the whole table:

- **Semantic ids only.** Game and UI code emits a cue id. It never names a
  file, a path, or an asset id. (`DECISIONS/0005`.)
- **A missing cue is silence, never a substitute and never a crash.** §4.

---

## 1. Categories, priority bands, and the voice cap

| Band | Priority | Category | What lives here |
|---|---|---|---|
| 100 | Impact | `combat` | A blow landing. The only band that may interrupt anything. |
| 90–95 | Resolve | `reward` | A payoff layer rising. One per layer, never two. |
| 85–88 | Warning / discovery | `combat`, `reward` | The telegraph; the knowledge reveal. |
| 60–70 | Action | `combat`, `gather`, `craft` | Swings, stances, working strikes, completions. |
| 30 | UI | `ui` | The commit press. |

**Voice cap: 2 concurrent SFX voices** (accessibility envelope). A third
request evicts the lowest-priority sounding voice if the newcomer outranks it,
and is otherwise **dropped silently**. Equal priority: the newer voice wins —
a strike is more current than the strike before it.

**Music is not a voice.** It never counts against the cap and is never evicted.

---

## 2. The matrix

`CURRENT RESOLUTION` is what the player hears **today, with zero generation**.
`PLACEHOLDER` means an existing accepted asset stands in and the manifest's
`Used by` column must say so. `SILENCE` means exactly that.

### 2.1 Combat

| Event id | Fires on (committed beat) | Cat | Pri | CD ms | Ducks | Haptic | Current resolution |
|---|---|---|---|---|---|---|---|
| `combat.encounter.begin.01` | The encounter view is first adopted — `combat_screen.dart:132` (`_fightArrival++`). Also the moment `setCombat(true)` is called. | combat | 80 | 1500 | onset of the sustained −3 dB combat duck | existing `hapticMedium`, `encounter_card.dart:319` | SILENCE — P1 |
| `combat.swing.player.01` | `_startSegment` for a `PlayerStruckBeat` segment, at t=0 (the wind-up). | combat | 70 | 250 | no | none | SILENCE — P1 |
| `combat.impact.player.01` | The same segment, at its `lands` offset (`combat_choreography.dart:176`). | combat | 100 | 180 | −6 dB | none | **PLACEHOLDER `craft.smithing.01` @ −2 dB, owner-gated** — P0 |
| `combat.attack.enemy.01` | `_startSegment` for an `EnemyStruckBeat` segment, t=0. | combat | 70 | 250 | no | none | SILENCE — P1 |
| `combat.impact.enemy.01` | The same segment, at `lands` (`combat_choreography.dart:218`), when `heavy == false` and the round is not braced. | combat | 100 | 180 | −6 dB | none | SILENCE — P0. **No placeholder by ruling** (§2.5). |
| `combat.telegraph.heavy.01` | The `RoundEndedBeat` segment whose `telegraph` becomes `true` (`combat_choreography.dart:254`). | combat | 85 | 2000 | −3 dB | none | SILENCE — P0 |
| `combat.impact.heavy.01` | The `EnemyStruckBeat` segment with `heavy == true`, at `lands`. | combat | 100 | 400 | −9 dB | existing `hapticHeavy` — **moved from segment start to `lands`** (defect D10) | SILENCE — P1 |
| `combat.brace.01` | The `BracedBeat` segment start (`combat_choreography.dart:202`). | combat | 60 | 400 | no | **new** `hapticLight` | SILENCE — P0 |
| `combat.brace.absorb.01` | The `EnemyStruckBeat` segment immediately following a `BracedBeat`, at `lands`. Requires one new boolean on `StageSegment` (`bracedReply`), set in `choreograph`. | combat | 100 | 300 | −6 dB | none | SILENCE — P0 |
| `combat.heal.01` | The `ConsumableUsedBeat` segment start. | combat | 60 | 600 | no | none | SILENCE — P2 |
| `combat.enemy.defeated.01` | The `WonBeat` segment start — the fall, on the picture. | combat | 95 | 1000 | −6 dB | none | SILENCE — P0 |

### 2.2 Outcome and reward

These fire from the **reward layer seam**, not from the stage: `showRewardLayer`
(`reward_layer.dart:55`) already owns the one-haptic-per-payoff rule and is the
only place a payoff is presented. Audio joins it there, under the same rule.

| Event id | Fires on | Cat | Pri | CD ms | Ducks | Haptic | Current resolution |
|---|---|---|---|---|---|---|---|
| `reward.victory.01` | The combat outcome layer rises with `outcome == won` (`combat_screen.dart:162` / `:175`). Fires on the **skip path too** — a skipped replay still resolves. | reward | 90 | 2000 | −9 dB, 1400 ms release | existing `hapticMedium` | SILENCE — **P0, first** |
| `reward.retreat.01` | The same layer with `outcome == lost` or `retreated`. | reward | 90 | 2000 | −6 dB, 1200 ms release | existing `hapticMedium` | SILENCE — P1 |
| `reward.discovery.01` | The outcome layer contains a knowledge-stage beat (`STUDIED`/`KNOWN`) or a signature reveal. Fires **inside** the victory layer, 600 ms after it. | reward | 88 | 2000 | no (already inside the victory duck) | none | SILENCE — P1 |
| `reward.levelup.01` | A layer whose beats include a level gained. **Outranks every other completion cue on the same layer** (§2.6). | reward | 92 | 3000 | −6 dB, 900 ms | inherited from the layer's tier | SILENCE — P1 |
| `reward.milestone.01` | A project stage or completion, a contract delivered, a bounty paid. | reward | 90 | 2000 | −6 dB, 900 ms | inherited from the layer's tier | SILENCE — P2 |

### 2.3 Gathering

| Event id | Fires on | Cat | Pri | CD ms | Ducks | Haptic | Current resolution |
|---|---|---|---|---|---|---|---|
| `gather.mining.01` | Working-loop strike frame (4 of 8) and the one-shot gather's play (`adventure_screen.dart:235`, `:238`). | gather | 50 | 700 | no | `hapticLight` on the tapped single gather only | **SHIPPED** `gather.mining.01` @ trim 0.0 dB |
| `gather.woodcutting.01` | As above, strike frame 4. | gather | 50 | 700 | no | as above | **SHIPPED** @ trim −2.0 dB |
| `gather.foraging.01` | As above, strike frame 8 of a 15-slot ping-pong (1650 ms cycle). | gather | 50 | 1500 | no | as above | **SHIPPED** @ trim 0.0 dB |
| `gather.complete.01` | The `ActivityResultHost` lands a **gather** result card (`activity_result.dart:301` `_consider`), or a `GATHERING COMPLETE` beat. | gather | 70 | 1200 | −3 dB | existing card haptic | **PLACEHOLDER: the profession's own action cue, one terminal strike @ −3 dB** ("the last blow" rule) — P2 |

### 2.4 Crafting

Completion tiers map **one-to-one** onto `craftSignificanceOf`
(`lib/ui/state/craft_significance.dart:32`). Three outputs, three ids. No
parallel taxonomy, no per-rarity ids, no per-profession completion ids.

| Event id | Fires on | Cat | Pri | CD ms | Ducks | Haptic | Current resolution |
|---|---|---|---|---|---|---|---|
| `craft.smithing.01` | Working-loop strike frame (6 of a 12-slot ping-pong, 1320 ms cycle) — `craft_screen.dart:1070`. | craft | 50 | **1200** (unchanged) | no | existing `hapticLight` at the repetition boundary (`craft_screen.dart:1181`) | **SHIPPED** @ trim −6.0 dB |
| `craft.cooking.01` | As above, strike frame 6, same 1320 ms cycle. | craft | 50 | **1100** (was 1500 — defect D3) | no | as above | **SHIPPED, re-trimmed** (§3.3) @ trim −1.0 dB |
| `craft.complete.minor.01` | `CraftSignificance.minor` — the result reaches the `ActivityResultHost` card, not the reward layer. | craft | 70 | 1200 | no | existing card haptic | **PLACEHOLDER: the profession's action cue, one terminal strike @ −3 dB** — P2 |
| `craft.complete.medium.01` | `showRewardLayer(tier: RewardTier.medium)` from `craft_screen.dart:247–249` with `significance == medium` — finished equipment, a level in the queue, a Rare output, or a first Uncommon+. | reward | 90 | 2000 | −6 dB, 900 ms | existing `hapticMedium` (`reward_layer.dart:72`) | **PLACEHOLDER: the profession's action cue @ 0 dB, under the duck** — P0 |
| `craft.complete.major.01` | The same seam with `significance == major` (rarity ≥ Epic). | reward | 95 | 2000 | −9 dB, 1400 ms | existing `hapticHeavy` (`reward_layer.dart:70`) | **PLACEHOLDER: as above, deeper duck** — P0 |

The placeholder tiers are audibly different **today**, at zero credits: the same
strike lands in progressively deeper silence. That is the whole difference
between a Bronze Sword and a Herb Broth until production reopens.

### 2.5 UI

| Event id | Fires on | Cat | Pri | CD ms | Ducks | Haptic | Current resolution |
|---|---|---|---|---|---|---|---|
| `ui.commit.01` | Any **primary commit** press: Set out, Craft, Gather, Engage, Attack, Brace, Equip, Deliver. One id, every button. | ui | 30 | 120 | no | the existing haptic already at each site | SILENCE — P2 |

### 2.6 Ids deliberately NOT created

| Not created | Why |
|---|---|
| `reward.loot.01` | Loot is a line inside the victory layer. `reward.victory.01` already resolves it, and a second cue would fire under a sounding one. A coin/bag flourish is also slot-machine adjacent, which the locked creative direction forbids. |
| `reward.signature.01` | Folded into `reward.discovery.01`. A signature reveal and a knowledge advance are the same event to the player: the world just told you something. |
| `reward.project.01`, `reward.contract.01` | Folded into `reward.milestone.01`. Same emotion, never co-occurring, and two near-identical resolves is noise. |
| `combat.impact.enemy.*` placeholder | Nothing we own is a body blow. Substituting `gather.mining.01` would make one asset mean both "the mine" and "you are being hit" — the exact failure `01_AUDIO_IDENTITY.md` forbids. Silence is the cheaper error. |
| Per-strike-quality ids (`strong` / `even` / `weak`) | Three impacts per weapon is the twelve-sounds-per-weapon trap. Quality is already in the log line and the damage figure. |
| Per-rarity craft completions (5) and per-profession completions (15) | The significance function has three outputs. The audio has three ids. |
| `ui.tap`, `ui.cancel`, `ui.tab`, `ui.expand`, `ui.scroll` | A UI click family is upkeep, not feedback. Thirteen haptic sites already punctuate navigation. |
| `ui.equip.01`, `ui.travel.setout.01` | Both are commits; `ui.commit.01` covers them. |
| Per-material gather variants (`gather.ore.copper.01`, …) | The owner's one-cue-per-activity ruling stands until device play proves repetition distracting. The **id shape is reserved** here so a variant round is a table edit and no trigger moves. |

---

## 3. Mix structure

### 3.1 Gain chain

```
MUSIC   = settings.musicVolume (0.55)   × combatScale × cueDuckScale
SFX     = settings.sfxVolume   (0.90)   × cue.trimDb
AMBIENCE= settings.ambienceVolume (0.70) × combatScale
```

`combatScale` and `cueDuckScale` are **runtime multipliers on the music
channel's volume write**. They never touch `_musicAssetId`, so `setRegion`'s
same-assignment early return (`audio_controller.dart:153`) is untouched and
region music never restarts.

Defaults are **not changed**. A default change reaches only fresh installs;
the owner's device already has a persisted settings file. Separation must come
from the trim table and the duck, both of which apply regardless of what is
saved.

### 3.2 The matching metric — integrated LUFS is retired for SFX

The shipped SFX were mastered to **peak** and the music to **loudness**. That
is defect D2. It cannot be repaired by re-gaining to a common integrated
target: every SFX already sits at −1.0 dBTP, so any upward gain clips. Mining
measures ≈20 dB of peak-to-loudness ratio; smithing ≈13. Matching those two on
integrated LUFS would demand +5.3 dB on a file with 1 dB of headroom.

**Ruling.** One-shots are matched on **LUFS-M max (400 ms momentary maximum)**,
measured on the *shipped* file, with −1.0 dBTP unchanged as the ceiling.
Integrated LUFS remains the music metric. Target for the action class:
**−13.0 LUFS-M max, ±1.0 LU.**

**Implementation: a per-asset `trimDb` in `AudioCues`, attenuation only.**

```
volume = settings.sfxVolume × 10^(trimDb / 20)      trimDb ≤ 0
```

This is the same deterministic-scalar-gain class as the README's packaging
gains (`assets/audio/v1/README.md`; `RULES.md` A-2 by analogy) — but it is
*safer*, because it rewrites no owner-accepted file, cannot clip, and is
retunable by ear on device in one line.

Trim table to author, pending the measurement pass:

| Asset | Shipped (raw LUFS-I + packaging gain) | `trimDb` | Rationale |
|---|---|---|---|
| `gather.mining.01` | −18.2 −3.1 = −21.3 | **0.0** | The floor. Anchor of the class. |
| `gather.foraging.01` | −16.0 −4.2 = −20.2 | **0.0** | Intentionally the quietest gesture; a leaf pull is not a hammer. |
| `gather.woodcutting.01` | −17.2 −1.2 = −18.4 | **−2.0** | |
| `craft.cooking.01` | −16.1 −5.3 = −21.4 | **−1.0** | Re-measure after the re-trim (§3.3). |
| `craft.smithing.01` | −14.0 +0.4 = −13.6 | **−6.0** | The outlier. 7.8 dB over mining today. |

These figures are **derived, not measured**: they are raw integrated LUFS plus
the README's gains, and foraging's 2.0 → 1.6 s trim moved its integrated value
by an unknown amount. **The implementing task measures the five shipped WAVs
for LUFS-M max first and authors the real numbers.** The ordering above is
what the measurement is expected to confirm; the arithmetic is what proves the
defect, not what fixes it.

Mining is the floor and cannot be raised by attenuation. If, after the trim
table and the duck, mining still fails to read on a phone speaker, the only
zero-credit remedy is a **deterministic true-peak limiter** re-master
(ffmpeg `alimiter`, fixed recorded parameters, ceiling −1.0 dBTP). That is a
**change of packaging class** — from "gain/trim/format" to "gain/trim/format +
limiting" — and it needs the owner's ear before it ships. It is queued as an
owner-gated packaging experiment, not an automatic fix, and it costs nothing.

### 3.3 Cooking — the ruling

Three faults compound at `audio_cues.dart:89–92`:

1. The cooldown is 1500 ms against a **1320 ms** loop cycle (7 frames
   ping-ponged to 12 slots × 110 ms), so the cue fires on alternate cycles —
   once every 2.64 s while the player watches a continuous stir.
2. The code comment justifies this against a **stale 1,430 ms** figure.
3. The source is provenance-recorded as a *steady sizzle plateau, no impact
   event anywhere in the profile*. It has no transient, so it cannot punctuate
   a strike frame at any cooldown.

**Ruling:**

- Cooldown **1500 → 1100 ms**, and the stale comment corrected.
- The shipped WAV is **re-trimmed to ≈900 ms** around its loudest 400 ms
  window (deterministic: argmax momentary, window `[peak−250 ms, peak+650 ms]`),
  10 ms in-fade, 120 ms out-fade. This is precisely the packaging class already
  applied to foraging (2.0 → 1.6 s with a 120 ms fade) — but it removes audible
  content rather than a silence floor, so it takes **one owner listening pass**
  before it ships. Zero credits.
- `craft.cooking.stir.01` — a real ladle-on-pot contact with a transient — is
  **P0** in the production queue. The re-trim is a bridge, not the answer.

### 3.4 The duck

One duck, on the music bus, driven by cue priority.

| Trigger | Depth | Attack | Hold | Release |
|---|---|---|---|---|
| Priority ≥ 100 (impact) | −6 dB | 120 ms | cue length | 700 ms |
| `combat.impact.heavy.01`, `craft.complete.major.01` | −9 dB | 120 ms | cue length | 1400 ms |
| Priority 85–95 (resolve, telegraph) | −6 dB (telegraph −3 dB) | 200 ms | cue length | 900 ms |
| Sustained combat (`setCombat(true)`) | −3 dB | 600 ms | whole encounter | 600 ms |

- Ducks **multiply**: a heavy impact during combat lands at −12 dB of bed.
- **Floor:** the music bus never goes below `musicVolume × 0.35` (−9.1 dB)
  no matter how many ducks stack.
- Written through the existing chained one-shot `_animateVolume` machinery
  (`audio_controller.dart:213`) with the step count scaled to the ramp.
  `Timer.periodic` stays forbidden.
- The duck **never** applies to gather or craft action cues (priority 50).
  A ten-minute gather queue pumping the music bed at 1.3 Hz would be worse
  than the problem it solves.

### 3.5 Combat music — Option B, ruled

Between (A) a dedicated battle loop, (B) regional music ducked plus a tension
overlay, and (C) regional combat variants: **B.**

- **C costs five tracks** (5 × 26 = 130 credits against a last-recorded 61) and
  cannot be built. **A** costs one track and, worse, discards regional identity
  at the exact moment the player is most present in the region.
- **A also fights the architecture.** `setRegion` has one call site
  (`stride_app.dart:170`) and self-dedupes on assignment. A battle track means a
  second assignment authority, a save/restore of the region assignment across
  victory, defeat, retreat and a mid-fight relaunch, and a new class of bug
  where the wrong region resumes. B needs **none of that**: it is a scalar on
  the volume write.
- B is buildable **today**, with zero assets, and the overlay drops in later
  without touching `setRegion`.

**Transition architecture, precise enough to implement now:**

```
AudioController.setCombat(bool active)      // idempotent; same value is a no-op
  → _combatActive = active
  → ramp combatScale 1.0 ⇄ 0.71 (−3 dB) over 600 ms, chained one-shot timers
  → music channel volume write = musicVolume × combatScale × cueDuckScale
```

- Called from exactly two places: `CombatScreen` adopting its first view
  (`combat_screen.dart:132`, beside `_fightArrival++`) and
  `acknowledgeCombat` / screen dispose.
- `_musicAssetId` is never touched, so travel during or after a fight behaves
  exactly as it does today.
- The release ramp on victory (600 ms) is deliberately co-timed with
  `reward.victory.01`'s duck release (1400 ms): the bed **swelling back up** is
  half of what "victory resolves" means, and it costs nothing.
- **The overlay, when produced** (`music.combat.tension.01`, P1): a second
  `MusicChannel` started at volume 0 on `setCombat(true)`, faded to
  `musicVolume × 0.45` over 900 ms, faded out and disposed over 900 ms on
  `setCombat(false)`. It layers under the ducked region bed; it does not
  replace it. The controller already owns at most two music channels
  (`audio_output.dart:16–23`), so this is the third slot and must be named.

---

## 4. The fallback contract

**A cue that cannot be resolved produces silence. Never a crash, never an
arbitrary sound.**

Three sites violate this today: `audio_controller.dart:161`, `:262` and `:360`,
all `AudioCues.files[assetId]!`. A typo'd asset id throws inside a `setState`
frame. `test/audio/audio_assets_test.dart` iterates `AudioCues.files` only and
never asserts `skillCues[*].assetId ⊆ files.keys`, so such a typo ships green.

### 4.1 The resolution rule

```
resolve(cueId) :=
  cue ← cues[cueId]                    ; unknown id      → SILENCE
  for hop in 0..2:
      path ← files[cue.assetId]
      if path ≠ null: return path
      if cue.fallbackTo = null: return SILENCE
      cue ← cues[cue.fallbackTo]       ; unknown target  → SILENCE
  return SILENCE                       ; chain too deep  → SILENCE
```

- `fallbackTo` is **declared in the table**, per cue. There is no implicit
  default, no "nearest category", no `files.values.first`.
- Maximum **3 hops**. A longer chain is a table defect, not a runtime concern.
- The declared fallbacks in this draft are exactly the PLACEHOLDER rows of §2
  and nothing else: `combat.impact.player.01 → craft.smithing.01`;
  `craft.complete.{minor,medium,major}.01 → the profession's action cue`;
  `gather.complete.01 → the profession's action cue`. Every other unproduced
  cue has `fallbackTo: null` and is honestly silent.

### 4.2 Replacing the three `!` sites

`AudioCues.files[id]!` becomes `AudioCues.pathFor(cueId)` returning `String?`,
and each caller reads:

```dart
final String? path = AudioCues.pathFor(cueId);
if (path == null) return;          // silence, not a throw
```

For the music sites (`:161`, `:360`) `null` additionally means "leave the bus
unassigned" — the behaviour a region with no track already has
(`audio_cues.dart:66–72`), extended to a broken row.

### 4.3 What proves it

Five tests, all cheap, none a new framework:

1. **Containment.** Every cue in the union of `skillCues`, `combatCues`,
   `rewardCues`, `uiCues` and `regionMusic` has `assetId ∈ files.keys` **or**
   a declared `fallbackTo`. This is the assertion whose absence is defect D4.
2. **Termination.** Every cue's fallback chain terminates in a real file or in
   `null` within 3 hops; the fallback graph is acyclic.
3. **Silence, not throw.** A controller test with a fake output and a cue whose
   asset id is deliberately absent: `playCue` is never called, no exception is
   raised, and the controller stays usable afterwards.
4. **No bang.** A source-scan guard (same class as the existing step-model
   guard) fails on `AudioCues.files[` followed by `]!` anywhere in `lib/`.
5. **Convention.** The existing regex test extended to the new categories:
   `^(music|gather|craft|combat|reward|ui)\.[a-z_.]+\.\d{2}$`.

---

## 5. Accessibility envelope (binding)

- **Cues fire off the segment machine, never the frame ticker.** Defect D1 —
  `ambient_stage.dart:582` stops the controller under
  `MediaQuery.disableAnimationsOf`, so `_onTick` never runs, so `onBeat` never
  fires, so **all five shipped cues are silent under Reduce Motion, forever**.
  Combat cues must not repeat that: they are placed at `_startSegment` and at
  declared offsets within a segment, both of which survive.
- **Reduce Motion collapses combat timing.** Flutter scales an
  `AnimationController` with `AnimationBehavior.normal` to 5 % under
  `disableAnimations`, so a 2.5 s round completes in ~125 ms and its segment
  cues arrive nearly simultaneously. The priority rule and the 2-voice cap are
  what make that survivable: the impact survives, the swing is dropped.
  **Outcome cues therefore fire from the reward layer, not from a segment**,
  so victory always resolves at full length regardless of animation speed.
- **Every cue declares a cooldown.** No exceptions in §2.
- **Monotonic clock only** — `audio_controller.dart:100` already; extended to
  the duck and the voice cap. `DateTime.now` stays forbidden.
- **No `Timer.periodic` in `lib/`.** Ducks and ramps use chained one-shots.
- **The skip path stays silent.** `_applyRemaining` fires no segment cue.
  The outcome cue still fires, from the layer.
- **No information is audio-only.** Every cue in §2 duplicates a visible fact.
- **Haptics need a rate limit.** There is none today: `hapticHeavy` can fire
  from `combat_stage.dart:346` and again from `reward_layer.dart:70` within
  ~2.5 s. Ruling: a **1200 ms floor per haptic strength**, in
  `AudioController`, beside the existing toggle.
- **iOS `respectSilence: true`** (`audio_output.dart:58`) stays. The ring/silent
  switch muting the game is the documented lifecycle contract, and a player who
  reports "no sound" with the switch flipped is not a defect.

---

## 6. Production queue

Ordered by how much the owner's brief names the gap. Every prompt is verbatim
and in the established house voice (compare P-1…P-10 in
`AUDIO/AUDIO_ASSET_MANIFEST.md`).

**Seed policy.** Combat SFX take the **6xxx** block, reward/UI the **7xxx**
block, new music the **8xxx** block. A reroll increments the last digit, as
mining did (4101 → 4102) and cooking did (4501 → 4502 → 4503). Every roll's
provenance JSON is written before the file is judged.

**Cost.** stable-audio-2.5 = **20 credits** per generation, flat, any duration.
stable-audio-3 = **26 credits** at 150 s. Recorded balance: **61**, 2026-08-24.
Generation is **unavailable this workstream** — `STABILITY_API_KEY` is not set
and the live balance is unverifiable.

### P0 — the owner's headline gaps

| # | Cue | Model | Dur | Seed | Cost |
|---|---|---|---|---|---|
| 1 | `reward.victory.01` | stable-audio-2.5 | 4 s | 7101 | 20 |
| 2 | `combat.impact.player.01` | stable-audio-2.5 | 1 s | 6101 | 20 |
| 3 | `combat.impact.enemy.01` | stable-audio-2.5 | 1 s | 6201 | 20 |
| 4 | `combat.brace.absorb.01` | stable-audio-2.5 | 1 s | 6301 | 20 |
| 5 | `combat.brace.01` | stable-audio-2.5 | 1 s | 6801 | 20 |
| 6 | `combat.telegraph.heavy.01` | stable-audio-2.5 | 2 s | 6401 | 20 |
| 7 | `combat.enemy.defeated.01` | stable-audio-2.5 | 2 s | 6501 | 20 |
| 8 | `craft.complete.medium.01` | stable-audio-2.5 | 3 s | 7601 | 20 |
| 9 | `craft.cooking.stir.01` | stable-audio-2.5 | 1 s | 4601 | 20 |

**P0-1 `reward.victory.01`** — *"VICTORY SHOULD RESOLVE."*

> `TrackType: Music, VocalType: Instrumental. Short warm acoustic fantasy resolve for a small victory in an adventure RPG. Three or four rising plucked lute notes settle onto one warm sustained major chord from nylon-string guitar and soft felt piano, a breathy wooden flute holding a single note above it, warm low strings underneath; the phrase arrives, breathes and decays naturally into silence. Earned, satisfied, human warmth; a small triumph among friends, never a fanfare, never brass, never a jackpot or arcade flourish. Lo-fi production: warm tape saturation, rounded highs, soft even dynamics. Moderate tempo, one complete phrase, ending in quiet.`

Acceptance: heard over the Haven bed at 0.55 on a phone speaker under a −9 dB
duck, the phrase must **complete inside 4 s** and read as an ending, not a
loop fragment. No brass. No ascending arpeggio ladder. Reject anything that a
blind listener calls "a reward chime".

**P0-2 `combat.impact.player.01`** — *"A SWORD SHOULD LAND WITH WEIGHT."*

> `TrackType: SFX. Close-mic recording of one single sword blow landing on a leather-and-hide covered body: a heavy steel blade meets thick hide with a dense muffled cut, a hard weighted body-mass thud underneath, a very short bright edge contact at the front, no metallic ring, no sustained blade tone, the flesh and leather absorb the blow entirely, extremely short decay, dry close recording space, physical and believable.`

Acceptance: the contact must resolve within **120 ms**; no ring survives past
400 ms (a tail that outlives the duck release reads as a bell). Must be
distinguishable from `craft.smithing.01` in blind A/B — if it reads as an anvil
we have paid 20 credits for the placeholder we already own.

**P0-3 `combat.impact.enemy.01`**

> `TrackType: SFX. Close-mic recording of one single heavy blow landing on a person wearing a padded cloth and leather travelling coat: a broad dull body impact, dense mass contact, a soft cloth and leather compression at the front, low muffled weight underneath, no metal, no ring, no vocalisation, extremely short decay, dry close recording space.`

Acceptance: must be **immediately distinguishable from P0-2** in blind A/B —
one is you hitting, one is you being hit, and the player must never have to
look. Duller, broader, no edge transient.

**P0-4 `combat.brace.absorb.01`** — *"A BLOCK SHOULD SOUND LIKE A BLOCK."*

> `TrackType: SFX. Close-mic recording of one heavy blow caught on a braced wooden shield with an iron boss: a hard weighted impact into thick planks, a short dry wood crack and a brief low metal boss knock together, the whole body of the shield absorbing and damping the force, a faint strap and leather creak immediately after, no ring, no reverb, very short decay, dry close recording space.`

Acceptance: unmistakably **stopped**, not landed. The wood-and-boss knock must
be recognisable in isolation. This cue is the entire feedback for Brace and
the evidence Q-06 needs.

**P0-5 `combat.brace.01`**

> `TrackType: SFX. Very close quiet recording of a person setting their stance behind a shield: leather straps tightening, a short creak of a wooden shield being brought up and planted, one soft boot scuff settling on hard ground, small and intimate, no impact, no ring, dry close recording space, extremely short.`

Acceptance: quiet and preparatory. It must not compete with the absorb cue
that follows ~350 ms later.

**P0-6 `combat.telegraph.heavy.01`**

> `TrackType: SFX. Close recording of a large heavy creature drawing itself up to strike: a slow deep intake of breath, a low chest rumble, the drag and settle of heavy weight shifting on stone, gathering tension building over about a second and a half and then holding, no roar, no shriek, no musical tone, natural and organic, dry close recording space.`

Acceptance: reads as **warning**, not as a hit. A player who hears it must
reach for Brace. Nothing tonal — it plays under region music in five different
keys.

**P0-7 `combat.enemy.defeated.01`**

> `TrackType: SFX. Close recording of a heavy creature collapsing onto packed earth and stone: a broad soft body fall, a dull weighted thud settling, a scatter of small grit and stone displaced, one last faint exhale, then stillness; short natural decay, no music, no vocal cry, dry close recording space, grounded and final.`

Acceptance: it must land under the fall's own animation and be **finished**
before the victory layer rises ~700 ms later.

**P0-8 `craft.complete.medium.01`**

> `TrackType: SFX. Close-mic blacksmith workshop recording of finished work being set down: one last light hammer tap on cooling metal, then the finished piece laid onto a heavy wooden bench with a solid settling knock, a faint tool set aside beside it, quiet workshop air after, satisfied and final, warm and physical, short natural decay, dry close workshop recording.`

Acceptance: it must read as **completion** while remaining in the same room as
`craft.smithing.01`. No chime, no sparkle, no musical interval.

**P0-9 `craft.cooking.stir.01`**

> `TrackType: SFX. Close-mic field recording of one single stir in a cast iron cookpot over a fire: a wooden spoon makes a clear firm contact with the pot's inner wall, a short thick liquid drag through stew, one small fat pop, a faint fire crackle far under, one clean discrete cooking gesture, extremely short decay, dry close recording space.`

Acceptance: it must have a **contact transient** at its front — the entire
failure of `craft.cooking.01` is that it has none. Must survive being fired
every 1.32 s without smearing.

**P0 subtotal at one roll each: 180 credits. At the recorded two-roll
convention: 360.**

### P1 — the fight becomes a scene

`combat.swing.player.01` (6601, 1 s), `combat.attack.enemy.01` (6701, 1 s),
`combat.impact.heavy.01` (6901, 2 s), `combat.encounter.begin.01` (6011, 2 s),
`reward.retreat.01` (7201, 4 s), `reward.discovery.01` (7301, 3 s),
`reward.levelup.01` (7401, 4 s), `craft.complete.major.01` (7701, 4 s) —
8 × 20 = **160 credits**; plus `music.combat.tension.01`
(stable-audio-3, 45 s, seed 8101, **26 credits**):

> `TrackType: Music, VocalType: Instrumental. Restrained acoustic fantasy lo-fi tension layer for a dangerous encounter in an adventure RPG, designed to sit quietly UNDER an existing regional track without competing. A low sustained cello drone with slow swells, a sparse low plucked string pulse marking an unhurried heartbeat, a faint tense high string harmonic drifting far above, almost no melody and no chord progression, minimal soft low percussion far back. Alert, watchful, dangerous but never frantic; no drums build, no orchestral bombast, no synthesizers. Lo-fi production: warm tape saturation, gentle hiss, rounded hushed highs, very soft even dynamics. Slow tempo, 66 BPM, harmonically static and loopable.`

Acceptance: harmonically static enough to layer under all **five** region
tracks without a key clash. If it clashes with even one, it is rejected — the
whole point of Option B is that regional identity survives.

### P2 — the rest of the language

`combat.heal.01` (6111), `reward.milestone.01` (7501), `ui.commit.01` (7801),
`gather.complete.01` (7901), `craft.complete.minor.01` (7611) — 5 × 20 =
**100 credits**.

### What 61 credits actually buys

- **Three SFX generations, single roll each, no reroll budget** (60 of 61); or
- **One cue done properly** — three rolls, which is exactly what cooking needed
  (4501, 4502, 4503) before it passed a gate.

61 credits **cannot buy P0.** P0 alone is 180 at one roll, 360 at the recorded
convention. The full matrix is **≈812 credits** at two rolls per cue.

**Ruling: spend nothing until the balance is verified and the owner reopens
generation.** If exactly 61 credits must be spent today, they go entirely to
`reward.victory.01` — three rolls, 60 credits — because victory resolving is
the gap the owner named most directly and the one thing no asset we own can
stand in for.

---

## 7. Open items for the owner

- The two PLACEHOLDER rows in §2 (`combat.impact.player.01 → craft.smithing.01`,
  and the craft-completion terminal strike) need **one listening pass**. Both
  revert to silence at zero cost.
- The cooking re-trim (§3.3) removes audible content from an accepted asset and
  needs **one listening pass**.
- The mining limiter experiment (§3.2) changes the packaging class and needs
  **one listening pass**. All three are free.
- Whether combat's sustained duck should be −3 dB or −6 dB is a device call.
  The value is one constant.
