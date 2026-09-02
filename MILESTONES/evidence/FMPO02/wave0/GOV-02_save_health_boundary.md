# GOV-02 — Save / Health Boundary Report

Scope: locate the boundaries a presentation overhaul (visible equipment, UI,
world overlays, audio) must not cross. No code changed by this report.

## 1. Health / step accounting — OFF LIMITS

Everything under these two locations, plus their platform channels:

- `packages/stride_health/` (whole package) — in particular:
  - `lib/src/cursor_authorization.dart`, `lib/src/origin_gateway.dart`,
    `lib/src/origin_pseudonymizer.dart`, `lib/src/platform_step_source.dart`,
    `lib/src/step_sync_source.dart`
  - `ios/.../HealthKitAdapter.swift`, `HealthKitStepStore.swift`
  - `android/.../HealthConnectAdapter.kt`, `HealthConnectStepSource.kt`,
    `StepBucketing.kt`
- `packages/stride_core/lib/src/steps/` — `step_ledger.dart`,
  `sync_batch.dart`, `reconciliation.dart` (StepLedger, cursor, per-origin
  watermarks, epoch/economy state all live here)
- `packages/stride_core/lib/src/engine/` files that reference the ledger and
  economy epoch: `game_engine.dart`, `game_state.dart`, `events.dart`,
  `event_reducer.dart`
- App-side consumers that read granted/session step state (read-only
  boundary, do not change their health-reading logic):
  `lib/runtime/stride_session.dart`, `lib/ui/state/session_controller.dart`,
  `lib/ui/state/activity_controller.dart`, `lib/runtime/runtime_bootstrap.dart`,
  `lib/runtime/identity_vault.dart`, `lib/audio/audio_controller.dart` (reads
  step events only to trigger cues — do not touch the read side)

A presentation task may *read* projections already exposed by
`StrideSession` (e.g. `equipmentVisualState`, `equippedSummary`) but must not
add new fields to `GameState`, `StepLedger`, `Equipment`, or any encoder in
`packages/stride_core/lib/src/save/` or `packages/stride_health/`.

## 2. Save/state schema

- **Current version:** `StateVersion.current = 9`
  (`packages/stride_core/lib/src/engine/state_version.dart:40`). Minimum
  supported is v1. `StateVersion.migrationRequired` is the sole signal that a
  save needs `StateMigrations` applied.
- **Version history table** lives as doc-comments on `StateVersion`
  (same file, lines 21–32) — one line per bump, each naming whether it
  re-based the economy.
- **Serialization:** `packages/stride_core/lib/src/save/save_codec.dart`
  (`encodeGameState`, `encodeSnapshot`, `encodeEnvelope`),
  `packages/stride_core/lib/src/save/journal_record.dart` (journal records +
  CRC32C digest), `packages/stride_core/lib/src/save/save_repository.dart`
  (ping-pong slot read/write, compare-and-swap), `state_migrations.dart`
  (per-version step table), `durable_state.dart` (canonical-JSON equality
  used for divergence checks — see below).
- **Compatibility doc:** `GAME_STATE_SIGNATURE_COMPATIBILITY.md` (repo root).
  Also canonical for the save format's durability model:
  `DECISIONS/0012_SAVE_FORMAT.md` (two-slot ping-pong + journal, CAS,
  cursor-authority rule, profile authority) and
  `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md` (why sidecar prefs like audio
  must stay outside the save's CAS world).
- **Guard tests** (must stay green, unmodified in behavior):
  `packages/stride_core/test/save_protocol_test.dart`,
  `save_migration_test.dart`, `save_corruption_test.dart`,
  `save_fault_matrix_test.dart`, `save_privacy_test.dart`,
  `save_diagnostics_privacy_test.dart`, `phase2_migration_bootstrap_test.dart`,
  `equal_generation_divergence_test.dart`, `bootstrap_test.dart`,
  plus the versioned fixtures in `packages/stride_core/test/fixtures/save/`
  (`v1_baseline.save` … `v9_baseline.save`) and their generators in
  `packages/stride_core/tool/generate_v*_baseline.dart`.
  No item/equipment id string appears in fixture generators as a version
  discriminant — new content ids do not require a new fixture.

## 3. Equipment state and the visual resolver

- `Equipment.bySlot` — a `Map<EquipmentSlot, ContentId>` in
  `packages/stride_core` engine state (`game_state.dart`), keyed by
  `EquipmentSlot.weapon/.armor/.tool`. This is the one map both the engine
  (gather tool checks, combat weapon lookup) and every UI/visual reader
  consult — see `lib/runtime/stride_session.dart:3187` (tool-tier gate) and
  `:4237` (`equippedSummary`).
- `StrideSession.equipmentVisualState` (`lib/runtime/stride_session.dart:4258`)
  returns a `const EquipmentVisualState({weapon, armor, tool})` of
  `EquippedVisualFact { itemId, tier, toolKind }` (defined at lines 311–355),
  built **on every read**, directly off `active.state.equipment.bySlot` and
  `content.items[...]` — no field is stored, cached, or persisted for it.
- **Resolver:** `lib/ui/icons/traveler_art.dart`, `abstract final class
  TravelerArt`.
  - `variantOfItem: Map<String,String>` — item id → coarse variant class
    (`armor.plate` / `armor.jerkin` / `armor.coat` / `weapon.bronze`). An
    unmapped id (including `item.training_sword`, deliberately) falls
    through to the base figure/set.
  - `armorFigures` — variant class → one 64² standing-figure PNG.
  - `combatVariants` — variant class → `CombatantArt` set
    (`weapon.unarmed`, `weapon.bronze`; unarmed is a real value, not a
    fallback — see `combatantFor`).
  - `walkWestVariants` — currently empty; walk cycle always degrades to
    `travelerWalkWestFrames`.
  - Entry points: `figureFor(EquipmentVisualState)`,
    `combatantFor(EquipmentVisualState)`, `walkWestFor(EquipmentVisualState)`.

### Equippable item ids (from `assets/content/v1/items.json`)

| id | name | slot | tier | power |
|---|---|---|---:|---:|
| item.training_sword | Training Sword | weapon | 0 | 3 |
| item.bronze_sword | Bronze Sword | weapon | 1 | 9 |
| item.bronze_longsword | Bronze Longsword | weapon | 1 | 12 |
| item.fanghilt_sword | Fang-Hilted Sword | weapon | 1 | 10 |
| item.training_axe | Training Axe | tool (axe) | 0 | 1 |
| item.bronze_axe | Bronze Axe | tool (axe) | 1 | 4 |
| item.hornbound_bronze_axe | Hornbound Bronze Axe | tool (axe) | 2 | 6 |
| item.goblin_toothed_axe | Goblin-Toothed Axe | tool (axe) | 2 | 6 |
| item.training_pickaxe | Training Pickaxe | tool (pickaxe) | 0 | 1 |
| item.bronze_pickaxe | Bronze Pickaxe | tool (pickaxe) | 1 | 4 |
| item.reinforced_pickaxe | Reinforced Pickaxe | tool (pickaxe) | 2 | 6 |
| item.hornpoint_pickaxe | Hornpoint Pickaxe | tool (pickaxe) | 2 | 6 |
| item.tinbraced_pickaxe | Tin-Braced Pickaxe | tool (pickaxe) | 2 | 6 |
| item.traveler_tunic | Traveler Tunic | armor | 0 | 2 |
| item.bronze_chestplate | Bronze Chestplate | armor | 1 | 7 |
| item.scalewarmed_chestplate | Scale-Warmed Chestplate | armor | 2 | 7 |
| item.wolfhide_jerkin | Wolfhide Jerkin | armor | 1 | 4 |
| item.tuskbound_jerkin | Tuskbound Jerkin | armor | 1 | 6 |
| item.frostlined_jerkin | Frost-lined Jerkin | armor | 2 | 6 |
| item.bearhide_coat | Bearhide Coat | armor | 2 | 9 |
| item.clawguard_coat | Clawguard Coat | armor | 2 | 9 |
| item.frostwarden_coat | Frostwarden Coat | armor | 2 | 8 |
| item.waywarden_tunic | Waywarden's Tunic | armor | 1 | 5 |

Of these, only 3 weapons and 8 armor items have an authored `TravelerArt`
variant class today (all 6 tools and `item.waywarden_tunic` fall through to
base). Adding more variant rows is a `TravelerArt` table edit only — no
schema change.

## 4. Zero-new-persisted-fields confirmation

Yes — visual state is fully derivable at read time from data already in the
save (`Equipment.bySlot` values) plus the content registry (`items.json`,
already-loaded, not persisted). `EquipmentVisualState` /
`EquippedVisualFact` are plain in-memory value objects constructed fresh on
each `equipmentVisualState` read; `TravelerArt`'s tables are static
compile-time constants. A presentation pass can extend `TravelerArt`'s
variant/figure/combat/walk tables and add new PNGs without touching
`GameState`, `save_codec.dart`, `state_version.dart`, or any fixture. The
only prohibited move is threading a *new* fact (e.g. a dye/skin choice) that
isn't already `bySlot` + `items.json` into persistence — that would need a
version bump and belongs to Technical Director / an ADR, not this workstream.

## 5. Tests that must stay green

Command (Flutter/Dart not on PATH by default):

```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
cd packages/stride_core && flutter test
cd ../stride_health && flutter test
cd ../stride_storage && flutter test
```

Do not run these as part of this task — named for the producer to gate the
presentation PR on. Minimum required-green set:

- `packages/stride_core/test/save_protocol_test.dart`
- `packages/stride_core/test/save_migration_test.dart`
- `packages/stride_core/test/save_corruption_test.dart`
- `packages/stride_core/test/save_fault_matrix_test.dart`
- `packages/stride_core/test/save_privacy_test.dart`
- `packages/stride_core/test/save_diagnostics_privacy_test.dart`
- `packages/stride_core/test/phase2_migration_bootstrap_test.dart`
- `packages/stride_core/test/equal_generation_divergence_test.dart`
- `packages/stride_core/test/bootstrap_test.dart`
- `packages/stride_core/test/step_ledger_invariants_test.dart`
- `packages/stride_core/test/economy_epoch_cutover_test.dart`
- `packages/stride_core/test/transformation_epoch_test.dart`
- `packages/stride_core/test/reconciliation_scenarios_test.dart`
- `packages/stride_core/test/lost_grant_regression_test.dart`
- `packages/stride_core/test/origin_keying_unconfigured_test.dart`
- `packages/stride_health/test/adapter_to_ledger_test.dart`,
  `adapter_to_ledger_defects_test.dart`,
  `cursor_authorization_matrix_test.dart`,
  `cursor_invalidation_durability_test.dart`,
  `multi_page_cursor_regression_test.dart`, `origin_privacy_test.dart`,
  `origin_pseudonymizer_test.dart`, `mock_step_source_test.dart`
- `packages/stride_storage/test/restart_integration_test.dart`,
  `concurrency_test.dart`, `closure_probes_test.dart`, `critic_probes_test.dart`

If a presentation change is scoped correctly (art tables, UI, audio only),
none of the above should ever need editing — an edit to any file in this
list is itself a signal the change crossed the boundary.

## 6. Audio settings storage

`lib/audio/audio_settings_store.dart` — persists `AudioSettings` as one JSON
file at `<application support>/audio_settings.json`, via
`path_provider`'s `getApplicationSupportDirectory()`.

The save lives one level deeper, at
`<application support>/project_stride/` (`directoryName = 'project_stride'`
in `packages/stride_storage/lib/src/file_storage.dart:53`, holding
`save_slot_a` / `save_slot_b`).

The rule, stated in the file's own doc comment: audio settings must **not**
touch the save directory, must not construct any save-persistence type, and
must not run anywhere but the root isolate. Write is temp-file-then-rename
(a torn write costs a default, never a corrupt game) — deliberately *not*
the ping-pong/CAS protocol `DECISIONS/0012` and `DECISIONS/0013` mandate for
the actual save, because a preference sidecar has nothing transactional to
protect. Any new presentation-settings persistence (UI theme, overlay
toggles, etc.) should follow this same sidecar pattern, not extend
`GameState` or write into `project_stride/`.
