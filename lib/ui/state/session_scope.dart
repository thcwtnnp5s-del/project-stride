/// Makes the [SessionController] reachable from any screen, and rebuilds
/// dependents when it notifies.
///
/// `InheritedNotifier` is used rather than a state-management package because
/// the app needs exactly one thing a package would provide — "this changed,
/// rebuild" — and that is already in `package:flutter`. `pubspec.yaml` carries
/// an explicit note about what may appear in it, and `DEPENDENCIES.md` plus the
/// CI dependency-policy job exist to make adding a dependency a decision rather
/// than a reflex.
///
/// Plain `setState` does not work here and it is worth being precise about why:
/// the banked-steps figure lives in the header, *above* the body, and the gather
/// button lives in a screen *below* it. A `setState` in the screen cannot
/// rebuild its own ancestor. The alternatives are threading an `onChanged`
/// callback down four constructor levels — which every new screen must redo — or
/// rebuilding the whole shell, including both inactive screens, to update one
/// number.
library;

import 'package:flutter/widgets.dart';

import 'session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, **subscribing** the caller to its notifications.
  static SessionController of(BuildContext context) {
    final SessionScope? scope = context
        .dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget.');
    return scope!.notifier!;
  }

  /// The controller **without** subscribing.
  ///
  /// For callbacks that need to call a command but must not rebuild on every
  /// notification — an `onPressed` closure, mainly.
  static SessionController read(BuildContext context) {
    final SessionScope? scope = context
        .getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget.');
    return scope!.notifier!;
  }
}
