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
