/// Project Stride — game rules and simulation.
///
/// Pure Dart. This library must never import Flutter, a plugin, `dart:ui`, or
/// `dart:io`. Platform capabilities are reached through ports; time and
/// randomness enter as data.
///
/// M-2 scope: the module marker and the port definitions. Game state, events,
/// and the engine arrive in F-03; content schemas in F-02.
library;

export 'src/core_info.dart';
export 'src/ports/step_provider.dart';
