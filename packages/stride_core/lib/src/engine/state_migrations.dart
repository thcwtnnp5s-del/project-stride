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
    this.afterFirstReconcile = false,
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

  /// Whether this step must be applied **after the first foreground health
  /// reconciliation** of the launch that migrates, rather than at bootstrap.
  ///
  /// A re-basing step marks the epoch at the ledger's *current* totals. At
  /// bootstrap those totals do not yet include the steps walked between the
  /// player's last sync and this launch — the unsynced backlog — so a
  /// bootstrap-time mark would leave that backlog *outside* the retired body,
  /// and the first sync would then grant it as spendable. `DECISIONS/0018`
  /// wants the opposite: only walking after the cutover is spendable, and the
  /// backlog is retired with everything before it. So the step asks to run
  /// after the sync has had its one chance to observe the backlog.
  ///
  /// When any step on a save's remaining path sets this, `BootstrapCoordinator`
  /// commits **nothing** at bootstrap and hands the whole path back as a
  /// `PendingStateMigration` for the session to complete after its first sync
  /// — the whole path, not the tail, so that the migration is still one commit
  /// (`DECISIONS/0018` §4). False for a step that has no reason to wait: the
  /// Phase 2 cutover ran at bootstrap and its saves are already durable.
  final bool afterFirstReconcile;

  /// The `DECISIONS/` document that authorised this step.
  final String decision;

  @override
  String toString() =>
      'StateMigrationStep(v$from→v$to; rebasesEconomy=$rebasesEconomy; '
      '${afterFirstReconcile ? 'afterFirstReconcile; ' : ''}'
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
    //
    // Deferred past the first sync so the walking between the owner's last
    // Phase 2 sync and this launch is retired with the rest, rather than
    // arriving as a spendable balance a second after the cutover.
    StateMigrationStep(
      from: 2,
      to: 3,
      rebasesEconomy: true,
      afterFirstReconcile: true,
      decision: 'DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md',
    ),
    // Combat Slice 01: `GameState.encounter` and `WorldState.drivenOff` enter
    // the save. A format bump and nothing else — the case this table exists
    // for. No `EstablishEconomyEpoch` is issued; the migration commits the
    // version bump with an empty event list.
    StateMigrationStep(
      from: 3,
      to: 4,
      rebasesEconomy: false,
      decision: 'DECISIONS/0020_COMBAT_SLICE_01.md',
    ),
    // Repeatable encounters: `WorldState.drivenOff` (a set of enemies beaten
    // this visit) becomes `WorldState.visitVictories` (how many times each was
    // beaten this visit). The same case as v3→v4, and the same answer — a
    // reshape and nothing else. No `EstablishEconomyEpoch` is issued; the
    // migration commits the version bump with an empty event list.
    //
    // A v4 `drivenOff` entry decodes as a count of **1**, which is what it
    // meant: at v4 one victory was the whole allowance, so an enemy in that
    // set had been beaten exactly once since the player last moved. Nothing is
    // inferred and no balance moves — an enemy the player had driven off stays
    // spent for that visit if its authored count is 1, and becomes fightable
    // once more if the content pack now says 2.
    StateMigrationStep(
      from: 4,
      to: 5,
      rebasesEconomy: false,
      decision: 'DECISIONS/0021_REPEATABLE_ENCOUNTERS_AND_RARITY.md',
    ),
    // Finite background activity: `GameState.activityQueue` enters the save —
    // the durable, wall-clock-anchored queue whose reconciliation is P-4's one
    // named exception. A format bump and nothing else: a v5 save decodes with
    // no queue, which is what a v5 save meant — no queue could outlive the
    // process. No `EstablishEconomyEpoch` is issued; the migration commits the
    // version bump with an empty event list.
    StateMigrationStep(
      from: 5,
      to: 6,
      rebasesEconomy: false,
      decision: 'DECISIONS/0022_FINITE_BACKGROUND_ACTIVITY.md',
    ),
  ];

  /// Whether [path] must wait for the first foreground reconciliation before
  /// it is applied and committed. True when any step on it says so.
  static bool defersPastFirstReconcile(List<StateMigrationStep> path) =>
      path.any((StateMigrationStep s) => s.afterFirstReconcile);

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
