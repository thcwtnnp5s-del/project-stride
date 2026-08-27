/// Makes the app-scoped [AudioController] reachable from any screen, beside
/// [SessionScope] and for the same reasons — see `session_scope.dart` for why
/// `InheritedNotifier` and not a package.
///
/// The controller lives in `lib/audio/`, outside the UI boundary: widgets
/// call [AudioController.playSkillCue] and read `settings`; none of them
/// constructs a player, a file, or a timer of their own.
library;

import 'package:flutter/widgets.dart';

import '../../audio/audio_controller.dart';

class AudioScope extends InheritedNotifier<AudioController> {
  const AudioScope({
    super.key,
    required AudioController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, **subscribing** the caller to its notifications — for
  /// the settings block, which re-renders as the sliders move.
  static AudioController of(BuildContext context) {
    final AudioScope? scope = context
        .dependOnInheritedWidgetOfExactType<AudioScope>();
    assert(scope != null, 'No AudioScope above this widget.');
    return scope!.notifier!;
  }

  /// The controller **without** subscribing — for beat callbacks and
  /// `onPressed` closures.
  static AudioController read(BuildContext context) {
    final AudioScope? scope = context
        .getInheritedWidgetOfExactType<AudioScope>();
    assert(scope != null, 'No AudioScope above this widget.');
    return scope!.notifier!;
  }

  /// [read], but null when no scope is above — for shared presentation code
  /// (the reward layer) that component tests pump without the app shell. A
  /// missing scope silences the cue; it never crashes the payoff.
  static AudioController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AudioScope>()?.notifier;
}
