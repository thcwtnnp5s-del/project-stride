/// Project Stride — game rules and simulation.
///
/// Pure Dart. This library must never import Flutter, a plugin, `dart:ui`, or
/// `dart:io`. Platform capabilities are reached through ports; time and
/// randomness enter as data.
///
/// Current scope: the port definitions (F-01), the content foundation (F-02),
/// and the runtime spine — immutable state, typed commands and events, and a
/// deterministic engine (F-03). The step ledger and reconciliation arrive in
/// F-04.
library;

export 'src/bootstrap/bootstrap.dart';
export 'src/engine/commands.dart';
export 'src/engine/event_reducer.dart';
export 'src/engine/events.dart';
export 'src/engine/game_engine.dart';
export 'src/engine/game_state.dart';
export 'src/engine/rejection.dart';
export 'src/engine/state_version.dart';
export 'src/steps/completeness.dart';
export 'src/steps/reconciliation.dart';

export 'src/steps/step_ledger.dart';
export 'src/steps/step_origin_key.dart';
export 'src/steps/sync_batch.dart';

export 'src/content/balance_profile.dart';
export 'src/content/content_id.dart';
export 'src/content/content_loader.dart';
export 'src/content/content_registry.dart';
export 'src/content/definitions.dart';
export 'src/content/reachability.dart';
export 'src/content/schema_version.dart';
export 'src/content/validation.dart';
export 'src/core_info.dart';
export 'src/diagnostics/save_diagnostics.dart';
export 'src/ports/identity_store.dart';
export 'src/ports/save_store.dart';
export 'src/ports/transaction_lock.dart';
export 'src/ports/step_provider.dart';
export 'src/save/crc32c.dart';
export 'src/save/event_codec.dart';
export 'src/save/journal_record.dart';
export 'src/save/reset.dart';
export 'src/save/save_codec.dart';
export 'src/save/save_outcomes.dart';
export 'src/save/save_repository.dart';
