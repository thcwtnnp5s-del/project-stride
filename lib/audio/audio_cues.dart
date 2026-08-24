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

/// One profession action cue: which asset plays, and how the visible working
/// loop triggers it.
final class ActionCue {
  const ActionCue({required this.assetId, required this.cooldownMillis});

  /// The manifest asset ID (`AUDIO/AUDIO_ASSET_MANIFEST.md`).
  final String assetId;

  /// The shortest interval between two firings of this cue, in milliseconds.
  ///
  /// The anti-stack guard, not a scheduler: the working loop's strike frame is
  /// what fires the cue, and this floor keeps a rebuild storm, a double
  /// mount, or a very short loop from stacking copies of the same loud
  /// transient. Chosen per cue at roughly three-quarters of its loop cycle —
  /// under the cycle so every visible strike sounds, far over a frame so
  /// nothing can double-fire. Cooking's floor is deliberately **above** its
  /// 1,430 ms cycle: the 2 s sizzle would overlap itself fired every cycle,
  /// so alternate strike frames are skipped and the sizzle breathes.
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
  static const Map<String, ActionCue> skillCues = <String, ActionCue>{
    'skill.mining': ActionCue(assetId: 'gather.mining.01', cooldownMillis: 700),
    'skill.woodcutting': ActionCue(
      assetId: 'gather.woodcutting.01',
      cooldownMillis: 700,
    ),
    'skill.foraging': ActionCue(
      assetId: 'gather.foraging.01',
      cooldownMillis: 1500,
    ),
    'skill.smithing': ActionCue(
      assetId: 'craft.smithing.01',
      cooldownMillis: 1200,
    ),
    'skill.cooking': ActionCue(
      assetId: 'craft.cooking.01',
      cooldownMillis: 1500,
    ),
  };

  /// The music asset ID for [locationId], or null for silence — an unknown
  /// place, a null location (blocked bootstrap), or a region with no track.
  static String? musicForRegion(String? locationId) =>
      locationId == null ? null : regionMusic[locationId];

  /// The action cue for [skill], or null when the profession has none.
  static ActionCue? cueForSkill(String skill) => skillCues[skill];
}
