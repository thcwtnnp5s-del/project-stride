/// The semantic audio wiring (`DECISIONS/0005`): game code speaks in semantic
/// keys, these tables resolve key → **asset ID** → bundled file. Nothing in
/// the app references an audio filename directly — replacing a sound is a
/// one-row change here and in `AUDIO/AUDIO_ASSET_MANIFEST.md`, with no change
/// to the code that plays it.
///
/// ## Why string keys and not `ContentId`
///
/// The same boundary `AmbientAssets` documents: audio is presentation only,
/// and these tables are looked up from presentation code holding a
/// `skill.value` or `location.value` string. The caller unwraps; the table
/// stays `stride_core`-free.
///
/// ## Why one cue per activity
///
/// Owner ruling at the gathering gate (2026-08-24): for this playable phase
/// ONE strong, recognizable short cue per core activity is enough. Variants
/// are added only if physical-device play proves a repeated cue distracting —
/// which is why every asset ID ends `.01` and no rotation system exists.
library;

import 'dart:math' as math;

/// One profession action cue: which asset plays, and how the visible working
/// loop triggers it.
final class ActionCue {
  const ActionCue({
    required this.assetId,
    required this.cooldownMillis,
    this.trimDb = 0,
  });

  /// The manifest asset ID (`AUDIO/AUDIO_ASSET_MANIFEST.md`).
  final String assetId;

  /// Playback attenuation for this cue, in decibels. **Zero or negative,
  /// never positive** (PRESENTATION_COMBAT_EVOLUTION_01).
  ///
  /// ## Why the mix needs this at all
  ///
  /// The five accepted cues were mastered to a **peak** target (−1.0 dBTP,
  /// `assets/audio/v1/README.md`) while the five music tracks were mastered to
  /// a **loudness** target (−15.5 LUFS). Peak says nothing about how loud a
  /// sound *is*, so the shipped cues came out anywhere from −10.0 to −20.4
  /// LUFS-M max — measured on the shipped files, not estimated. A **10.4 dB
  /// spread**: the smithing hammer was more than ten decibels hotter than the
  /// mining pick, which is why one profession felt punchy and another felt
  /// like nothing happened.
  ///
  /// ## Why attenuation only, and why not in the files
  ///
  /// The obvious fix — re-gain every WAV to one loudness — is arithmetically
  /// impossible: they already sit at −1.0 dBTP, so the quiet ones would need
  /// boosting into clipping. Attenuating the loud ones instead is exact, is
  /// the same deterministic-scalar class as the packaging gains already in the
  /// README (`RULES.md` A-2), rewrites no owner-accepted file, cannot clip,
  /// and is retunable by ear in one line.
  ///
  /// Mining sits at the floor and **cannot be raised from here** — a cue can
  /// only be turned down. Bringing it up needs a deterministic limiter
  /// re-master of the source, which changes the packaging class and is
  /// therefore the owner's call, not this table's.
  final double trimDb;

  /// [trimDb] as a multiplier on the SFX bus. Exactly 1.0 when untrimmed.
  double get gain => trimDb == 0 ? 1 : math.pow(10, trimDb / 20).toDouble();

  /// The shortest interval between two firings of this cue, in milliseconds.
  ///
  /// The anti-stack guard, not a scheduler: the working loop's strike frame is
  /// what fires the cue, and this floor keeps a rebuild storm, a double
  /// mount, or a very short loop from stacking copies of the same loud
  /// transient. Chosen per cue at roughly three-quarters of its loop cycle —
  /// under the cycle so every visible strike sounds, far over a frame so
  /// nothing can double-fire.
  ///
  /// **Corrected (PRESENTATION_COMBAT_EVOLUTION_01).** Cooking's floor used to
  /// be 1,500 ms, justified here against a "1,430 ms cycle". The authored cook
  /// loop is 7 frames ping-ponged to 12 slots at 110 ms — **1,320 ms** — and
  /// has never been 1,430. The floor therefore sat *above* the cycle and
  /// skipped every other stir. It is 1,100 ms now, so every visible stir
  /// sounds, like every other profession.
  final int cooldownMillis;
}

abstract final class AudioCues {
  const AudioCues._();

  /// Asset ID → bundled file, relative to `assets/` (the prefix
  /// `audioplayers`' `AssetSource` supplies). The manifest's "File" column
  /// mirrors this table; a row here without a manifest row is a QA defect
  /// (`DECISIONS/0005`).
  static const Map<String, String> files = <String, String>{
    'music.haven.01': 'audio/v1/music/music_haven_01.m4a',
    'music.whispering_woods.01': 'audio/v1/music/music_whispering_woods_01.m4a',
    'music.stonefall_mine.01': 'audio/v1/music/music_stonefall_mine_01.m4a',
    'music.frostmere.01': 'audio/v1/music/music_frostmere_01.m4a',
    'music.forgotten_hollow.01': 'audio/v1/music/music_forgotten_hollow_01.m4a',
    'gather.mining.01': 'audio/v1/sfx/sfx_gather_mining_01.wav',
    'gather.woodcutting.01': 'audio/v1/sfx/sfx_gather_woodcutting_01.wav',
    'gather.foraging.01': 'audio/v1/sfx/sfx_gather_foraging_01.wav',
    'craft.smithing.01': 'audio/v1/sfx/sfx_craft_smithing_01.wav',
    'craft.cooking.01': 'audio/v1/sfx/sfx_craft_cooking_01.wav',
  };

  /// Location content-id string → region music asset ID. A location absent
  /// here is a location with no music yet — the music bus goes quiet there
  /// rather than guessing.
  static const Map<String, String> regionMusic = <String, String>{
    'location.havens_rest': 'music.haven.01',
    'location.whispering_woods': 'music.whispering_woods.01',
    'location.stonefall_mine': 'music.stonefall_mine.01',
    'location.frostmere': 'music.frostmere.01',
    'location.forgotten_hollow': 'music.forgotten_hollow.01',
  };

  /// Skill content-id string → the profession's one action cue.
  ///
  /// ## The trim column
  ///
  /// Measured LUFS-M max on the **shipped** files (ITU-R BS.1770 K-weighting,
  /// 400 ms momentary window, at the files' own 44.1 kHz):
  ///
  /// ```text
  /// smithing    -10.0      <- 10.4 dB hotter than mining
  /// foraging    -17.2
  /// woodcutting -18.4
  /// cooking     -18.9
  /// mining      -20.4      <- the floor
  /// ```
  ///
  /// The trims pull anything above a **−17.0 LUFS-M ceiling** down to it and
  /// leave the rest alone. Deliberately *not* a flat match to the quietest
  /// cue: a hammer on an anvil should be louder than fingers in a herb patch,
  /// and flattening every profession to mining's level would bury all five
  /// under the music instead of one. What this removes is the 10 dB outlier;
  /// what it keeps is the natural ordering. Residual spread: 3.4 dB.
  ///
  /// **Mining is the floor and stays there.** It is also the cue the owner
  /// named ("mining should ring"), and no entry in this table can raise it —
  /// `trimDb` only attenuates. Lifting mining needs a deterministic limiter
  /// re-master of the source, which is a change of packaging class and so an
  /// owner ruling, recorded in the milestone rather than taken here.
  static const Map<String, ActionCue> skillCues = <String, ActionCue>{
    'skill.mining': ActionCue(assetId: 'gather.mining.01', cooldownMillis: 700),
    'skill.woodcutting': ActionCue(
      assetId: 'gather.woodcutting.01',
      cooldownMillis: 700,
    ),
    'skill.foraging': ActionCue(
      assetId: 'gather.foraging.01',
      cooldownMillis: 1500,
      trimDb: -0.2,
    ),
    'skill.smithing': ActionCue(
      assetId: 'craft.smithing.01',
      cooldownMillis: 1200,
      trimDb: -7,
    ),
    // 1100, not 1500. The cook loop is 7 frames ping-ponged to 12 slots at
    // 110 ms = **1,320 ms**, so a 1,500 ms floor skipped every other stir and
    // the sizzle arrived once per 2.64 s — heard as intermittent room tone
    // rather than as an action. The old floor was justified in a comment
    // against a "1,430 ms cycle" that the authored frame list has never
    // matched.
    'skill.cooking': ActionCue(
      assetId: 'craft.cooking.01',
      cooldownMillis: 1100,
    ),
  };

  /// The music asset ID for [locationId], or null for silence — an unknown
  /// place, a null location (blocked bootstrap), or a region with no track.
  static String? musicForRegion(String? locationId) =>
      locationId == null ? null : regionMusic[locationId];

  /// The action cue for [skill], or null when the profession has none.
  static ActionCue? cueForSkill(String skill) => skillCues[skill];

  /// The bundled file for [assetId], or **null when nothing is bundled for it**.
  ///
  /// The fallback contract, and the reason this exists rather than
  /// `files[id]!` at three call sites
  /// (PRESENTATION_COMBAT_EVOLUTION_01): an asset ID with no file is
  /// **silence**, never a crash and never some other sound. The `!` form threw
  /// a `_CastError` from inside an animation tick — a `setState` frame — so a
  /// one-character typo in a cue table took the screen down rather than going
  /// quiet, and `audio_assets_test` could not see it because it iterated
  /// [files] itself and so was structurally incapable of catching a key that
  /// was not in [files].
  ///
  /// This is what lets the event table below name cues whose audio has not
  /// been produced yet: the wiring lands now, the sound arrives later, and the
  /// gap in between is silence rather than a fault.
  static String? fileFor(String? assetId) =>
      assetId == null ? null : files[assetId];
}

/// How loud, how urgent, and how often — one game event's audio contract.
///
/// ## Why events need a different type from [ActionCue]
///
/// A profession cue fires off a *visible strike frame* in a loop the player is
/// watching, so its own cooldown is the whole of its scheduling. Combat and
/// reward cues fire off a **state machine** that can advance several steps
/// inside one frame, and under Reduce Motion advances far faster than that
/// (`DECISIONS/0032`). Three things follow, and none of them is expressible in
/// [ActionCue]:
///
/// - **[priority]**, because when two cues collide one of them has to win, and
///   it must be the one carrying information the player needs — a blow landing
///   outranks a footstep.
/// - **[duckDb]**, because a transient competing with a music bed at the same
///   level reads as mush on a phone speaker, and the fix is to move the bed
///   rather than to shout over it.
/// - **[minGapMillis]**, a floor between *any* two cues in the same band, which
///   is what stops an accelerated round becoming one indistinct noise.
final class EventCue {
  const EventCue({
    required this.assetId,
    required this.priority,
    this.trimDb = 0,
    this.duckDb = 0,
    this.minGapMillis = 0,
  });

  final String assetId;

  /// Higher wins a collision. Bands, not a continuum:
  ///
  /// - **30 — outcome.** Victory, defeat, retreat, level-up. The player must
  ///   never miss one; these are what the whole encounter was for.
  /// - **20 — impact.** A blow landing, in either direction, and a brace
  ///   absorbing one. The load-bearing feedback of a fight.
  /// - **10 — intent.** A swing starting, a telegraph. Useful, and the first
  ///   thing that should be dropped when the machine is running hot.
  /// - **5 — texture.** Ambient detail. Dropped freely.
  final int priority;

  /// Attenuation, in decibels, never positive. Same contract and reasoning as
  /// [ActionCue.trimDb].
  final double trimDb;

  /// How far to pull the music bed down while this plays, in decibels.
  ///
  /// Negative or zero. Applied to the music bus, not to this cue, so a player
  /// who has turned music down never hears it pushed *up* by a duck ending.
  final double duckDb;

  /// The floor between this cue and the previous cue of the same or lower
  /// priority, in milliseconds.
  ///
  /// Distinct from a per-cue cooldown: this governs the **stream**, which is
  /// the thing that breaks under Reduce Motion.
  final int minGapMillis;

  double get gain => trimDb == 0 ? 1 : math.pow(10, trimDb / 20).toDouble();

  double get duckScale =>
      duckDb == 0 ? 1 : math.pow(10, duckDb / 20).toDouble();
}

/// The combat, outcome and UI-commit event tables.
///
/// **Every asset ID here is currently unbundled, and that is the designed
/// state.** `AudioCues.fileFor` returns null for an unknown ID and the
/// controller treats null as silence, so the wiring, the priority bands, the
/// voice cap and the duck are all live and testable now, and each sound
/// becomes audible the moment its file lands — one row in
/// `AUDIO/AUDIO_ASSET_MANIFEST.md`, no code change.
///
/// Generation is blocked on credentials, not on design: both provider keys are
/// unset (`DECISIONS/0030` § 4). `AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` § 5 (and
/// `_03.md` § 5 for `ui.commit`) carry a ready-to-run brief for every id below.
abstract final class EventCues {
  const EventCues._();

  static const Map<String, EventCue> combat = <String, EventCue>{
    'combat.enter': EventCue(
      assetId: 'combat.encounter.begin.01',
      priority: 30,
      duckDb: -3,
      minGapMillis: 400,
    ),
    'combat.player.swing': EventCue(
      assetId: 'combat.swing.player.01',
      priority: 10,
      duckDb: -3,
      minGapMillis: 120,
    ),
    'combat.player.impact': EventCue(
      assetId: 'combat.impact.player.01',
      priority: 20,
      duckDb: -6,
      minGapMillis: 140,
    ),
    'combat.enemy.attack': EventCue(
      assetId: 'combat.attack.enemy.01',
      priority: 10,
      duckDb: -3,
      minGapMillis: 120,
    ),
    'combat.enemy.impact': EventCue(
      assetId: 'combat.impact.enemy.01',
      priority: 20,
      duckDb: -6,
      minGapMillis: 140,
    ),
    'combat.heavy.telegraph': EventCue(
      assetId: 'combat.telegraph.heavy.01',
      priority: 20,
      duckDb: -3,
      minGapMillis: 200,
    ),
    'combat.heavy.impact': EventCue(
      assetId: 'combat.impact.heavy.01',
      priority: 20,
      duckDb: -9,
      minGapMillis: 200,
    ),
    'combat.brace': EventCue(
      assetId: 'combat.brace.01',
      priority: 10,
      duckDb: -3,
      minGapMillis: 160,
    ),
    'combat.brace.absorb': EventCue(
      assetId: 'combat.brace.absorb.01',
      priority: 20,
      duckDb: -6,
      minGapMillis: 160,
    ),
    'combat.heal': EventCue(
      assetId: 'combat.heal.01',
      priority: 20,
      duckDb: -3,
      minGapMillis: 200,
    ),
    'combat.enemy.defeated': EventCue(
      assetId: 'combat.enemy.defeated.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 300,
    ),
  };

  static const Map<String, EventCue> reward = <String, EventCue>{
    // Loot deliberately has no id. It resolves inside the victory layer, and
    // a separate coin-or-bag flourish is the slot-machine register the locked
    // creative direction forbids (`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`).
    'reward.victory': EventCue(
      assetId: 'reward.victory.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 400,
    ),
    'reward.retreat': EventCue(
      assetId: 'reward.retreat.01',
      priority: 30,
      duckDb: -3,
      minGapMillis: 400,
    ),
    'reward.discovery': EventCue(
      assetId: 'reward.discovery.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 400,
    ),
    'reward.levelup': EventCue(
      assetId: 'reward.levelup.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 400,
    ),
    'reward.milestone': EventCue(
      assetId: 'reward.milestone.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 400,
    ),
    'craft.complete.minor': EventCue(
      assetId: 'craft.complete.minor.01',
      priority: 20,
      duckDb: -3,
      minGapMillis: 300,
    ),
    'craft.complete.food': EventCue(
      assetId: 'craft.complete.food.01',
      priority: 20,
      duckDb: -3,
      minGapMillis: 300,
    ),
    'craft.complete.gear': EventCue(
      assetId: 'craft.complete.gear.01',
      priority: 30,
      duckDb: -6,
      minGapMillis: 300,
    ),
    'gather.complete': EventCue(
      assetId: 'gather.complete.01',
      priority: 20,
      duckDb: -3,
      minGapMillis: 250,
    ),
  };

  /// The shared UI-commit table (ART-11, FMPO02 wave 1).
  ///
  /// One id, `ui.commit.01`, covers every primary-commit press — Confirm,
  /// Equip, Craft-begin, Travel-start (and, per
  /// `GAME_BIBLE/AUDIO/02_AUDIO_EVENT_MATRIX.md` §2.5, every other commit the
  /// game gains later) — because a click family is upkeep, not a taxonomy.
  /// Every one of those sites already fires a haptic; this plays **beside**
  /// it, never in place of it. Priority 10 (intent, not outcome) so it never
  /// out-ranks the impact/outcome tiers above, and no duck — the quietest,
  /// most frequent cue in the game must never move the music bed.
  static const Map<String, EventCue> ui = <String, EventCue>{
    'ui.commit': EventCue(
      assetId: 'ui.commit.01',
      priority: 10,
      minGapMillis: 120,
    ),
  };

  /// The cue for [event], from any table, or null when nothing is wired.
  static EventCue? of(String event) => combat[event] ?? reward[event] ?? ui[event];

  /// Every wired event id — the surface `audio_event_test` enumerates.
  static Iterable<String> get all =>
      <String>[...combat.keys, ...reward.keys, ...ui.keys];
}
