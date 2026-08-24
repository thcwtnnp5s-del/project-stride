/// An [AudioOutput] that plays nothing.
///
/// The fallback `StrideApp` constructs when it is handed no controller —
/// which is every widget test: the tree still gets a real `AudioScope`, beat
/// callbacks still fire and are still policy-checked by the controller, and
/// no platform channel is ever touched. Deliberately in its own file so
/// importing it pulls in no plugin.
library;

import 'audio_output.dart';

final class SilentAudioOutput implements AudioOutput {
  const SilentAudioOutput();

  @override
  Future<void> init() async {}

  @override
  Future<MusicChannel> startMusic(
    String assetPath, {
    required double volume,
  }) async => _SilentChannel();

  @override
  Future<void> playCue(String assetPath, {required double volume}) async {}

  @override
  Future<void> dispose() async {}
}

final class _SilentChannel implements MusicChannel {
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {}
}
