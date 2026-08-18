/// The S-01A developer harness.
///
/// ===========================================================================
/// What this screen is for, and what it deliberately is not
/// ===========================================================================
///
/// It is the instrument panel for the one thing S-01A has to prove: that real
/// walking — read through HealthKit on iOS or Health Connect on Android —
/// becomes usable energy in a durable save, and that spending it on a real
/// action survives a force-stop.
///
/// **One harness, both platforms, and that is the point.** The provider's name
/// is the only thing below that varies; every button dispatches the same
/// command into the same `GameEngine` and every number is read from the same
/// `GameState`. A second screen for iOS would be a second thing to keep
/// correct, and the first place the two would silently diverge.
///
/// It runs on the **real** bootstrap, the real engine, the real repository, and
/// the real adapter. There is no prototype state model behind it and no
/// second persistence path — every number on it is read from `GameState`, and
/// every button dispatches a `GameCommand`. A harness with its own state would
/// prove that the harness works.
///
/// It is not the game's UI. Visual design is not S-01A, and the layout below is
/// chosen for legibility on a phone in one hand while walking, not for
/// character.
///
/// ===========================================================================
/// Redaction is a rule here, not a preference
/// ===========================================================================
///
/// Nothing on this screen may render a raw origin identifier, a package name, a
/// device label, a salt, a salt fingerprint, or the contents of a sync cursor.
/// The screen is the most likely thing in the project to end up in a screenshot
/// attached to a bug report, which makes it the most likely place for one of
/// those to escape.
///
/// So origins and buckets are shown as **counts**, the cursor as
/// **present/absent**, and every failure as a **typed code**. `SyncReport` and
/// `ActionReport` are built so that there is nothing else available to render —
/// the redaction is a property of the types, not of the widgets, because a
/// widget's discipline lasts until someone adds a `Text`.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import '../runtime/stride_session.dart';

/// The resource node the slice spends energy on.
///
/// `resource_node.meadow_patch` is chosen because it is the only node reachable
/// with nothing: it sits at `location.havens_rest`, which is where a new game
/// starts, it needs Foraging 1, and it needs no tool. Every other node in the
/// pack needs travel, a level, an axe, or a pickaxe — all of which are real
/// systems that S-01A is not building, and any of which would turn "can the
/// player spend energy" into "can the player satisfy a prerequisite".
///
/// Content-defined, not invented here: the cost, the yield, and the experience
/// all come from `assets/content/v1/resource_nodes.json` through the registry.
final ContentId kHarnessNode = ContentId.unchecked(
  'resource_node.meadow_patch',
);

/// What the health provider is called on this platform.
///
/// Cosmetic, and deliberately the **only** platform branch in this file. A
/// tester following the iOS checklist must not be reading a panel headed
/// "Health Connect", and a diagnostic that names the wrong subsystem is worse
/// than one that names none: it sends the reader to the wrong settings screen
/// and makes a correct "unavailable" look like a bug.
///
/// Nothing else here varies. The buttons dispatch the same commands, the
/// numbers come from the same `GameState`, and the redaction rules are the same
/// rules — because the two platforms produce the same normalized `SyncResponse`
/// and the whole contract exists so that they do.
String get healthProviderName {
  if (Platform.isIOS) return 'HealthKit';
  if (Platform.isAndroid) return 'Health Connect';
  // The host, under `flutter test`. Named honestly rather than defaulted to one
  // of the two: a widget test reading "HealthKit" on Windows would be asserting
  // something true on neither platform.
  return 'Health provider';
}

/// Root of the debug build.
class StrideHarnessApp extends StatelessWidget {
  const StrideHarnessApp({super.key, required this.session});

  final StrideSession session;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Project Stride — S-01A',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F6B52),
        brightness: Brightness.dark,
      ),
    ),
    home: DevHarnessScreen(session: session),
  );
}

class DevHarnessScreen extends StatefulWidget {
  const DevHarnessScreen({super.key, required this.session});

  final StrideSession session;

  @override
  State<DevHarnessScreen> createState() => _DevHarnessScreenState();
}

class _DevHarnessScreenState extends State<DevHarnessScreen> {
  StrideSession get session => widget.session;

  bool _busy = false;
  String? _availability;
  String? _permission;
  SyncReport? _sync;
  ActionReport? _action;
  String? _loadResult;
  String? _lastEvent;

  /// Runs one operation, with the whole screen disabled while it is in flight.
  ///
  /// Serialization matters more than it looks. Two syncs in flight would both
  /// commit against the same expected generation, and the second would be
  /// refused as a compare-and-swap conflict — a real refusal, correctly
  /// reported, caused entirely by the harness double-tapping itself.
  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkAvailability() => _run(() async {
    final HealthAvailability result = await session.checkAvailability();
    if (!mounted) return;
    setState(() {
      _availability = result.available
          ? 'available'
          : 'unavailable — ${result.reason?.name ?? 'unspecified'}';
    });
  });

  Future<void> _requestPermission() => _run(() async {
    final HealthAuthorization result = await session.requestPermission();
    if (!mounted) return;
    setState(() => _permission = result.name);
  });

  Future<void> _syncSteps() => _run(() async {
    final SyncReport report = await session.syncSteps();
    if (!mounted) return;
    setState(() {
      _sync = report;
      _lastEvent = switch (report.status) {
        SyncStatus.reconciled =>
          report.newlyGranted > 0
              ? '+${report.newlyGranted} energy'
              : 'reconciled, nothing new to grant',
        SyncStatus.noChange => 'no change since the last sync',
        SyncStatus.unavailable =>
          'health unavailable — ${report.unavailableReason?.name}',
        SyncStatus.contractViolation => 'delivery refused before the ledger',
        SyncStatus.commitRefused =>
          'commit refused (${report.commitDetail}) — reload',
        SyncStatus.keyingUnconfigured => 'health source is not keyed',
      };
    });
  });

  Future<void> _gather() => _run(() async {
    final ActionReport report = await session.gather(kHarnessNode);
    if (!mounted) return;
    setState(() {
      _action = report;
      _lastEvent = report.succeeded
          ? '−${report.cost} energy → ${report.quantity}× ${report.itemName}'
          : 'refused: ${report.rejection}';
    });
  });

  Future<void> _reload() => _run(() async {
    final LoadOutcome? outcome = await session.reload();
    if (!mounted) return;
    setState(() {
      _loadResult = switch (outcome) {
        null => 'no content loaded',
        SaveLoaded(:final int replayedTransactions, :final bool degraded) =>
          'loaded — $replayedTransactions replayed'
              '${degraded ? ', repaired' : ''}',
        NoSaveFound() => 'no save found',
        LoadRefused(:final LoadRefusal reason) => 'refused — ${reason.name}',
      };
    });
  });

  Future<void> _reset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset local save?'),
        content: const Text(
          'This erases the save, the journal and the device identity on this '
          'phone. Earned energy and gathered resources are gone and cannot be '
          'recovered. The app must be restarted afterwards.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final EraseOutcome outcome = await session.resetLocalSave();
      if (!mounted) return;
      setState(() {
        _loadResult = switch (outcome) {
          EraseComplete() => 'erased — restart the app',
          EraseRefused(:final EraseRefusal reason) =>
            'erase refused — ${reason.name}',
        };
        _lastEvent = 'local save reset';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapOutcome outcome = session.outcome;
    return Scaffold(
      appBar: AppBar(title: const Text('Stride — S-01A harness')),
      body: outcome is BootstrapBlocked
          ? _Blocked(outcome: outcome)
          : SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final SyncReport? sync = _sync;
    final ActionReport? action = _action;
    final int? cost = session.costOf(kHarnessNode);
    final ResourceNodeDefinition? node =
        session.registry?.resourceNodes[kHarnessNode];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _EnergyCard(
          usable: session.usableEnergy,
          granted: session.totalGranted,
          spent: session.totalSpent,
          retired: session.retiredSteps,
          migration: session.migration,
          migrationPending: session.migrationPending,
          migrationRefusal: session.migrationRefusal,
          lastEvent: _lastEvent,
        ),
        const SizedBox(height: 16),

        _Section(
          title: 'Action',
          children: <Widget>[
            _Row('Location', session.locationName),
            _Row('Action', node?.displayName ?? kHarnessNode.value),
            _Row('Cost', cost == null ? '—' : '$cost energy'),
            _Row(
              'Held',
              node == null
                  ? '—'
                  : '${session.inventoryCount(node.yieldsItem)}× '
                        '${session.registry?.items[node.yieldsItem]?.displayName ?? node.yieldsItem.value}',
            ),
            if (action != null)
              _Row(
                'Result',
                action.succeeded
                    ? '${action.quantity}× ${action.itemName}'
                    : 'refused — ${action.rejection}',
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              // Disabled on insufficient energy rather than hidden, so the cost
              // above stays visible and the player can see what they are
              // walking towards. The engine re-validates regardless; this is a
              // hint, not the rule.
              onPressed: _busy || !session.canGather(kHarnessNode)
                  ? null
                  : _gather,
              icon: const Icon(Icons.grass),
              // Named for the thing the player gets, not for the verb. "Gather"
              // is what the button does; "Gather Meadow Herb" is what it is
              // for, and a validation checklist has to be able to name the
              // control the tester is looking at.
              label: Text(
                cost == null
                    ? 'Gather ${_yieldName(session, node)}'
                    : 'Gather ${_yieldName(session, node)} — $cost energy'
                          '${session.canGather(kHarnessNode) ? '' : ' (not enough)'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          title: healthProviderName,
          children: <Widget>[
            _Row('Availability', _availability ?? 'not checked'),
            _Row('Permission', _permission ?? 'not requested'),
            _Row('Source state', session.sourceState.name),
            if (session.keyingRefusal != null)
              _Row('Origin keying', 'refused — ${session.keyingRefusal!.name}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _busy ? null : _checkAvailability,
                  child: Text('Check $healthProviderName'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _requestPermission,
                  child: const Text('Request permission'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : _syncSteps,
                  child: const Text('Sync steps'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          title: 'Last sync',
          children: <Widget>[
            _Row('Status', sync?.status.name ?? 'not run'),
            _Row('Delivery kind', sync?.deliveryKind ?? '—'),
            _Row('Pages', '${sync?.pages ?? 0}'),
            _Row(
              'Query interval',
              sync?.intervalStartMillis == null
                  ? 'not asserted'
                  : '${_utc(sync!.intervalStartMillis!)} → '
                        '${_utc(sync.intervalEndMillis!)} UTC',
            ),
            // Counts, never identities. The harness may know that four sources
            // contributed; it may not know which.
            _Row('Origins', '${sync?.originCount ?? 0}'),
            _Row('UTC buckets', '${sync?.bucketCount ?? 0}'),
            _Row('Observed steps', '${sync?.observedSteps ?? 0}'),
            _Row('Newly granted', '${sync?.newlyGranted ?? 0}'),
            _Row(
              'Faults',
              sync == null || sync.faults.isEmpty
                  ? 'none'
                  : sync.faults.map((SyncFault f) => f.name).join(', '),
            ),
            if (sync?.rejection != null) _Row('Rejected', sync!.rejection!),
            if (sync?.commitDetail != null)
              _Row('Commit', 'refused — ${sync!.commitDetail}'),
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          title: 'Save',
          children: <Widget>[
            _Row('Syncs committed', '${session.syncCount}'),
            // Present or absent, never the bytes. A changes token on a screen
            // is platform sync state one screenshot away from a bug report.
            _Row('Cursor', session.hasCursor ? 'present' : 'absent'),
            _Row('State', session.isStale ? 'STALE — reload' : 'in sync'),
            _Row('Reload', _loadResult ?? 'not run'),
            _Row(
              'Backup exclusion',
              session.runtime.backupExclusionHealthy ? 'clean' : 'FAILED',
            ),
            _Row('Identity storage', session.runtime.identityStorage),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _busy ? null : _reload,
                  child: const Text('Reload saved state'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Reset local save'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Foreground only. No background worker, no scheduled sync, no '
          'passive monitoring. Every read above happened because a button was '
          'pressed.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  /// The display name of what a node yields, from content.
  ///
  /// Falls back to the content id rather than to a hard-coded string: a label
  /// that says "Meadow Herb" while the registry says otherwise is a label that
  /// will keep saying it after someone retunes the pack.
  static String _yieldName(
    StrideSession session,
    ResourceNodeDefinition? node,
  ) {
    if (node == null) return 'resource';
    return session.registry?.items[node.yieldsItem]?.displayName ??
        node.yieldsItem.value;
  }

  /// Instants are rendered in UTC, never in the device's calendar.
  ///
  /// The whole contract is built on UTC intervals precisely so that daylight
  /// saving, travel, and midnight are non-events. Rendering a local time here
  /// would make a tester in a different timezone read a different interval than
  /// the one the adapter queried.
  static String _utc(int millis) => DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String().substring(0, 16);
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.outcome});

  final BootstrapBlocked outcome;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.report_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Stride could not start',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        // Already player-legible and already guaranteed free of anything
        // health-derived — `BootstrapBlocked.explanation` carries that
        // obligation in its own documentation, which is why it is rendered
        // rather than reworded here.
        Text(outcome.explanation),
        const SizedBox(height: 16),
        Text('reason: ${outcome.reason.name}'),
        Text('stopped at: ${outcome.stoppedAt.name}'),
        for (final String line in outcome.detail)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({
    required this.usable,
    required this.granted,
    required this.spent,
    required this.retired,
    required this.migration,
    required this.migrationPending,
    required this.migrationRefusal,
    required this.lastEvent,
  });

  final int usable;
  final int granted;
  final int spent;

  /// The retired body (`EconomyEpoch.retiredSteps`), so the harness can show
  /// that the historical steps are still accounted for and merely unspendable.
  final int retired;

  /// Non-null only on the launch that migrated the save. Rendered so the
  /// acceptance script can see the cutover happen once and never again.
  final StateMigrationReport? migration;

  /// True between load and the first sync on the launch that migrates a v2
  /// save (`DECISIONS/0018`): the cutover is waiting to see the backlog, and
  /// `usable` is the zero it will leave. Rendered so the script can see the
  /// order — pending, then the report — rather than infer it.
  final bool migrationPending;

  /// Set only if the engine refused the pending migration. Should never show.
  final String? migrationRefusal;

  final String? lastEvent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Usable energy', style: theme.textTheme.labelLarge),
            Text(
              '$usable',
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'granted $granted · spent $spent · retired $retired',
              style: theme.textTheme.bodySmall,
            ),
            if (migrationPending) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Save migration pending — completes after the first sync',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (migrationRefusal != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Save migration REFUSED: $migrationRefusal',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (migration != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'This launch migrated the save: $migration',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (lastEvent != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(lastEvent!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
