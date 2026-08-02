/// Project Stride — game rules and simulation.
///
/// Pure Dart. This library must never import Flutter, a plugin, `dart:ui`, or
/// `dart:io`. Platform capabilities are reached through ports; time and
/// randomness enter as data.
///
/// Current scope: the port definitions (F-01) and the content foundation
/// (F-02). Game state, events, and the engine arrive in F-03.
library;

export 'src/content/balance_profile.dart';
export 'src/content/content_id.dart';
export 'src/content/content_loader.dart';
export 'src/content/content_registry.dart';
export 'src/content/definitions.dart';
export 'src/content/reachability.dart';
export 'src/content/schema_version.dart';
export 'src/content/validation.dart';
export 'src/core_info.dart';
export 'src/ports/step_provider.dart';
