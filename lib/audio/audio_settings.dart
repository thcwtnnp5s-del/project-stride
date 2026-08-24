/// The player's audio preferences — presentation state, deliberately outside
/// the game save.
///
/// Volumes are not game state: they change no figure, gate no progression,
/// and losing them costs a shrug, not steps. Keeping them out of the save
/// means no schema change, no migration, and no way for an audio slider to
/// end up inside the single-writer commit path (`DECISIONS/0013`).
library;

/// One immutable snapshot of the audio preferences.
///
/// AMBIENCE has a volume because the bus exists in the controller's
/// architecture; no ambience content ships yet and no control is exposed for
/// it (AUDIO_PRESENTATION_01 — ambience is deferred until device play shows a
/// concrete need).
final class AudioSettings {
  const AudioSettings({
    this.enabled = true,
    this.musicVolume = defaultMusicVolume,
    this.sfxVolume = defaultSfxVolume,
    this.ambienceVolume = defaultAmbienceVolume,
  });

  /// Audio defaults ON (the owner's acceptance target), with music seated
  /// under the action cues so a strike reads over the bed rather than
  /// fighting it — the conservative initial balance the integration brief
  /// asked for. Device review retunes these by ear, not by code change:
  /// they are only the first launch's values.
  static const double defaultMusicVolume = 0.55;
  static const double defaultSfxVolume = 0.9;
  static const double defaultAmbienceVolume = 0.7;

  /// The master switch. Off means the music bus pauses and no cue fires;
  /// nothing else about the preferences is forgotten.
  final bool enabled;

  final double musicVolume;
  final double sfxVolume;
  final double ambienceVolume;

  AudioSettings copyWith({
    bool? enabled,
    double? musicVolume,
    double? sfxVolume,
    double? ambienceVolume,
  }) => AudioSettings(
    enabled: enabled ?? this.enabled,
    musicVolume: _clamp(musicVolume ?? this.musicVolume),
    sfxVolume: _clamp(sfxVolume ?? this.sfxVolume),
    ambienceVolume: _clamp(ambienceVolume ?? this.ambienceVolume),
  );

  Map<String, Object> toJson() => <String, Object>{
    'enabled': enabled,
    'musicVolume': musicVolume,
    'sfxVolume': sfxVolume,
    'ambienceVolume': ambienceVolume,
  };

  /// Tolerant by design: a missing or malformed field takes its default
  /// rather than failing the load. These are preferences — the worst
  /// corruption can do is reset a slider, and refusing to start audio over a
  /// bad JSON file would be a punishment out of scale with the offence.
  factory AudioSettings.fromJson(Map<String, Object?> json) => AudioSettings(
    enabled: json['enabled'] is bool ? json['enabled']! as bool : true,
    musicVolume: _readVolume(json['musicVolume'], defaultMusicVolume),
    sfxVolume: _readVolume(json['sfxVolume'], defaultSfxVolume),
    ambienceVolume: _readVolume(json['ambienceVolume'], defaultAmbienceVolume),
  );

  static double _readVolume(Object? value, double fallback) =>
      value is num ? _clamp(value.toDouble()) : fallback;

  static double _clamp(double v) => v.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is AudioSettings &&
      other.enabled == enabled &&
      other.musicVolume == musicVolume &&
      other.sfxVolume == sfxVolume &&
      other.ambienceVolume == ambienceVolume;

  @override
  int get hashCode =>
      Object.hash(enabled, musicVolume, sfxVolume, ambienceVolume);
}
