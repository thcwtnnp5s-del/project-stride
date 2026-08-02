import 'package:stride_core/stride_core.dart';

import 'messages.g.dart';

/// Translates the platform boundary into the core's [StepProvider] port.
///
/// This class is the only place where platform types meet core types. It
/// contains no reconciliation logic: it converts, and nothing more. Ledger
/// arithmetic lives in `stride_core` where it can be tested without a device.
class PlatformStepProvider implements StepProvider {
  PlatformStepProvider({HealthHostApi? api}) : _api = api ?? HealthHostApi();

  final HealthHostApi _api;

  @override
  Future<bool> isAvailable() => _api.isAvailable();

  @override
  Future<StepAuthorization> requestAuthorization() async {
    final PlatformAuthorization result = await _api.requestAuthorization();
    return switch (result) {
      PlatformAuthorization.granted => StepAuthorization.granted,
      PlatformAuthorization.denied => StepAuthorization.denied,
      PlatformAuthorization.unavailable => StepAuthorization.unavailable,
    };
  }

  @override
  Future<StepFetchResult> fetchNewSteps({
    StepCursor? cursor,
    DateTime? watermark,
  }) async {
    final PlatformFetchResult result = await _api.fetchNewSteps(
      cursor?.bytes,
      watermark?.millisecondsSinceEpoch,
    );

    return StepFetchResult(
      status: switch (result.status) {
        PlatformCursorStatus.valid => CursorStatus.valid,
        PlatformCursorStatus.invalidated => CursorStatus.invalidated,
      },
      newSteps: result.newSteps,
      deletedSteps: result.deletedSteps,
      cursor: result.cursor == null ? null : StepCursor(result.cursor!),
      rescan: _toRescan(result.rescan),
    );
  }

  StepRescan? _toRescan(PlatformRescan? rescan) {
    if (rescan == null) return null;
    return StepRescan(
      windowStart: DateTime.fromMillisecondsSinceEpoch(
        rescan.windowStartMillis,
      ),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(rescan.windowEndMillis),
      windowTotal: rescan.windowTotal,
      truncated: rescan.truncated,
    );
  }
}
