/// The state-migration table: one explicit step per state-version bump.
///
/// ## Why a table, and why each step says what it does
///
/// The Phase 2 cutover (`DECISIONS/0016`) was a single branch in
/// `BootstrapCoordinator`: *if the save is older than current, establish the
/// epoch*. That was right for one migration. It becomes wrong the moment a
/// second version exists, because "older than current" would then mean
/// **every** later version bump re-based the player's economy — a field added
/// to the save in v4 would zero a balance as a side effect of a format change.
///
/// So the branch is replaced by a table. Each [StateMigrationStep] declares,
/// in code, whether it re-bases the economy and which decision authorised it.
/// A step that only reshapes the save says `rebasesEconomy: false` and the
/// coordinator issues no `EstablishEconomyEpoch` for it. Re-basing is therefore
/// something a step has to **ask for by name**, never something it gets by
/// being newer.
///
/// ## What the table is not
///
/// It is not a decoder chain. `StateCodecs` remains a fan-in of *direct*
/// decoders — a v1 save is read by the v1 decoder into the current `GameState`
/// shape, never by successive JSON transformations. The table governs only the
/// **meaning** applied after decoding, which is the part that can move a
/// balance and so is the part that needs an audit trail.
library;

import 'package:meta/meta.dart';

import 'state_version.dart';

/// One step of the migration table.
@immutable
final class StateMigrationStep {
  const StateMigrationStep({
    required this.from,
    required this.to,
    required this.rebasesEconomy,
    required this.decision,
  }) : assert(to == from + 1, 'a step moves exactly one version');

  /// The state version this step reads.
  final int from;

  /// The state version this step produces.
  final int to;

  /// Whether this step re-bases the playable economy by establishing an
  /// `EconomyEpoch` at the ledger's current totals.
  ///
  /// **False unless a decision says otherwise.** This is the field that stops a
  /// format bump from being a balance reset by accident.
  final bool rebasesEconomy;

  /// The `DECISIONS/` document that authorised this step.
  final String decision;

  @override
  String toString() =>
      'StateMigrationStep(v$from→v$to; rebasesEconomy=$rebasesEconomy; '
      '$decision)';
}

/// The migration table, from [StateVersion.minimumSupported] to
/// [StateVersion.current].
final class StateMigrations {
  const StateMigrations._();

  /// Every step this build knows how to apply, in order.
  ///
  /// Contiguity — each step's `from` is the previous step's `to`, the first
  /// starts at [StateVersion.minimumSupported] and the last ends at
  /// [StateVersion.current] — is asserted by `transformation_epoch_test.dart`
  /// (group 0) rather than trusted, so widening either bound without a step fails a test
  /// rather than a device.
  static const List<StateMigrationStep> steps = <StateMigrationStep>[
    // The Phase 2 economy cutover. The Phase 1 device-validation balance
    // (459,043 banked) is retired; totals, cursor and slices pass through.
    StateMigrationStep(
      from: 1,
      to: 2,
      rebasesEconomy: true,
      decision: 'DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md',
    ),
    // The Transformation playtest epoch. The Phase 2 device-validation balance
    // is retired on the same terms, so the first "feels like a game" playtest
    // starts at zero spendable steps. Owner direction, 2026-08-17.
    StateMigrationStep(
      from: 2,
      to: 3,
      rebasesEconomy: true,
      decision: 'DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md',
    ),
  ];

  /// The steps that bring a state at [fromVersion] up to
  /// [StateVersion.current], in the order they must be applied.
  ///
  /// Empty when [fromVersion] is already current. Throws for a version the
  /// table cannot start from — that is a programming fault, not a save fault:
  /// `StateVersion.supports` should already have refused it.
  static List<StateMigrationStep> pathFrom(int fromVersion) {
    if (!StateVersion.supports(fromVersion)) {
      throw UnsupportedStateVersionException(fromVersion);
    }
    return steps
        .where((StateMigrationStep s) => s.from >= fromVersion)
        .toList(growable: false);
  }
}
