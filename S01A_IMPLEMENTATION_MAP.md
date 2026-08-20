# S-01A — Implementation Map

Branch `s01a-foreground-health-harness`, from `e138f23`. Foreground only.

## What already exists, and is not being rebuilt

| Layer | State |
|---|---|
| `pigeons/health_api.dart` + three generated sides | Complete. Absolute per-`(origin, bucket)` observations, typed availability/authorization, candidate cursor, bounded rescan. Not changed. |
| `HealthConnectAdapter.kt` (746 lines) | Complete: fail-closed keying, changes-token drain, deletion-widened re-read, bounded recovery, pagination, `COMPLETE_THROUGH` only on the final page. Unit-tested on a plain JVM through the `StepSource` seam. |
| `HealthConnectStepSource.kt` | Real Health Connect calls. `READ_STEPS` only, no write scope, no passive monitoring. |
| `HealthConnectAvailability.kt` | API bands 24–25 / 26–27 / 28+. The 26–27 band answers `SERVICE_MISSING` without touching a Health Connect type. |
| `PlatformStepSource.translate` (Dart) | Page → `SyncFetch`. Nine `SyncFault` categories, cursor authorization, contract-violation rejection. |
| `StepReconciler` / `StepLedger` | Absolute reconciliation, per-origin watermarks, no-clawback, replay identity. |
| `GameEngine._reconcile` | `ReconcileStepSync` → events in commit order, checkpoint authorized **last**. |
| `SaveRepository.commit` | CAS, journal-first durability, two-slot ping-pong. |
| `bootstrapStride` (`lib/runtime/`) | Storage, identity vault, coordinator, `OriginPseudonymizer`. Android identity is the `_FileBackend` path — no native Android secure store is needed. |
| Content | `location.havens_rest` (start) holds `resource_node.meadow_patch`: foraging, level 1, `ToolKind.none`, 80 steps, yields 1 `item.meadow_herb`, 10 xp (retuned by Exploration & Progression Loop 01; originally 90 / 2 / 10). |

## The five real gaps

1. **Host-app manifest.** `android/app/src/main/AndroidManifest.xml` declares no Health
   Connect permission-rationale target. Health Connect refuses to present the permission
   sheet without one, so the plugin's `requestAuthorization` cannot succeed on a device
   even though every line behind it is correct.

2. **`lib/main.dart` never calls `bootstrapStride`.** It runs `RootPlaceholder`. Nothing
   in the app has ever constructed an engine, a repository, or a pseudonymizer.

3. **Nothing joins the two halves.** No code calls `PlatformStepSource.open`, loops
   `fetchSteps` pages, dispatches `ReconcileStepSync`, or commits the result. The adapter
   produces a `SyncFetch`; the engine consumes a `SyncResponse`; no wire runs between them.

4. **No action spends energy.** `AllocateSteps` debits the ledger and grants nothing —
   its own doc comment says F-03 had nothing to spend on. There is no gathering or travel
   command, so banked steps have no destination.

5. **No harness.** No screen, no diagnostics, no controls.

## What is being built

| Checkpoint | Files | Purpose |
|---|---|---|
| 1 | `android/app/src/main/AndroidManifest.xml` | The rationale activity + `VIEW_PERMISSION_USAGE` alias for Android 14+. Manifest only; the adapter is untouched. |
| 2 | `lib/main.dart`, `lib/runtime/step_sync_service.dart`, `lib/ui/harness/*` | Real bootstrap; the fetch → reconcile → commit loop; the redacted diagnostics screen. |
| 3 | `packages/stride_core/lib/src/engine/{commands,events,event_reducer,game_engine,rejection}.dart`, `save/event_codec.dart` | `GatherResource` → `ResourceGathered`. Spends banked steps, grants the item and the xp, in one event through the existing reducer. |
| 4 | tests, `S01A_DEVICE_VALIDATION.md`, debug APK | Fourteen acceptance properties, device instructions. |

## The path, end to end

```
Health Connect
  → HealthConnectStepSource          (raw records, package names)
  → OriginKeying.keyBytes            (FNV-1a over salt‖0x1F‖utf8; raw name dies here)
  → HealthConnectAdapter.emit        (absolute per-bucket totals, candidate token)
  → Pigeon PlatformSyncPage          (8-byte origin keys; no string identifier exists on the wire)
  → PlatformStepSource.translate     (validate, fault, authorize cursor)
  → SyncResponse
  → GameEngine.execute(ReconcileStepSync)
  → StepsGranted, then StepCheckpointAuthorized last
  → SaveRepository.commit            (journal fsync = the commit point)
  → banked = totalGranted - totalSpent, shown as usable energy
  → GatherResource(resource_node.meadow_patch)
  → ResourceGathered                 (spend 90, +2 meadow herb, +10 foraging xp)
  → SaveRepository.commit
```

## Constraints held

- No `WorkManager`, worker, service, receiver, passive monitoring, background isolate, or
  periodic schedule. `Scripts/check-android-target.sh` and `check-single-writer.sh` are the
  enforcement, and neither is being widened.
- No second `SaveRepository` construction site: the harness uses the one
  `bootstrapStride` returns. The allow-list in `check-single-writer.sh` is unchanged.
- No second step model: `Scripts/check-step-model.sh` stays as it is.
- No new ADR. Nothing here changes an approved decision — `DECISIONS/0014` already fixes
  S-01A as foreground-only, and everything above is inside it.
