/// A fresh install must ASK for step access before it reads.
///
/// ## The device finding this pins
///
/// The first Release install of Transformation Build 01 showed `TOTAL WALKED
/// 0`, banked 0, and Project Stride was absent from Health's app list: nothing
/// in the product ever called `requestAuthorization` — only the dev harness
/// did — so the startup sync and every manual `Sync steps` read an
/// unauthorised store. On iOS such a read comes back **empty**, which the sync
/// truthfully reported as "no new steps". Zero samples is not evidence of
/// authorization.
///
/// The session now asks immediately before a sync until the answer is
/// `granted`, and every report carries the answer so a screen can tell
/// "nothing new" from "nobody was allowed to look".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps, {int index = 0, String cursor = 'c1'}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_fresh_auth'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> launch(StepSyncSource source) =>
      StrideSession.start(overrideRoot: root, source: source);

  test('a fresh install asks for access before its first read', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[page(1200)],
    );
    final StrideSession session = await launch(source);
    expect(session.lastAuthorization, isNull, reason: 'nothing asked yet');

    final SyncReport report = await session.syncSteps();

    expect(source.authorizationRequests, 1);
    expect(source.calls.first, 'authorize', reason: 'ask, then read');
    expect(source.calls, contains('fetch'));
    expect(report.authorization, HealthAuthorization.granted);
    expect(report.newlyGranted, 1200);
    expect(session.usableEnergy, 1200);
  });

  test('once granted, later syncs read without asking again', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[page(500)],
    );
    final StrideSession session = await launch(source);
    await session.syncSteps();
    await session.syncSteps();
    await session.syncSteps();
    expect(source.authorizationRequests, 1);
    // Duplicate-safe as before: one grant, then nothing.
    expect(session.totalGranted, 500);
    expect(session.usableEnergy, 500);
  });

  test(
    'a denied answer is carried on the report, keeps asking, and grants nothing',
    () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[page(900)],
        authorization: HealthAuthorization.denied,
      );
      final StrideSession session = await launch(source);

      // The mock still serves the page — a real iOS store would return
      // nothing — so what this proves is the *report* and the re-ask, not
      // the platform's silence.
      final SyncReport first = await session.syncSteps();
      expect(first.authorization, HealthAuthorization.denied);
      expect(session.lastAuthorization, HealthAuthorization.denied);

      // Manual sync after a denial asks again — the player may have allowed
      // Steps in Settings in between.
      final SyncReport second = await session.syncSteps();
      expect(second.authorization, HealthAuthorization.denied);
      expect(source.authorizationRequests, 2);

      // …and when they have, the next tap picks it up and stops asking.
      source.authorization = HealthAuthorization.granted;
      final SyncReport third = await session.syncSteps();
      expect(third.authorization, HealthAuthorization.granted);
      await session.syncSteps();
      expect(source.authorizationRequests, 3);
    },
  );

  test(
    'an unauthorised empty read establishes no cursor and no grant',
    () async {
      // The iOS shape: denied, and the store answers "no change" forever.
      final MockStepSource source = MockStepSource(
        authorization: HealthAuthorization.denied,
      );
      final StrideSession session = await launch(source);
      final SyncReport report = await session.syncSteps();

      expect(report.status, SyncStatus.noChange);
      expect(report.authorization, HealthAuthorization.denied);
      expect(session.hasCursor, isFalse);
      expect(session.totalGranted, 0);
      expect(session.usableEnergy, 0);
      expect(session.engine!.state.steps.epoch.isOrigin, isTrue);
      expect(session.isReady, isTrue, reason: 'the game stays playable');
    },
  );

  test(
    'an unavailable source is reported as unavailable, not denied',
    () async {
      final MockStepSource source = MockStepSource(
        authorization: HealthAuthorization.unavailable,
        available: false,
      );
      final StrideSession session = await launch(source);
      final SyncReport report = await session.syncSteps();
      expect(report.authorization, HealthAuthorization.unavailable);
      expect(session.totalGranted, 0);
    },
  );
}
