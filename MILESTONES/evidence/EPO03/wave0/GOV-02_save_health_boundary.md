# GOV-02 — Save / Health Boundary Report (EPO03)

Branch `fable5-executive-production-overhaul-03` at `59c4723`, 2026-09-02.
Supersedes `MILESTONES/evidence/FMPO02/wave0/GOV-02_save_health_boundary.md`;
everything there that is not restated here is still true (equipment visual
resolver, equippable item table, audio-sidecar rule). No code changed by this
report. Every path below was checked to exist at HEAD.

EPO03 is presentation-only: atlas repaint, `atlas_layout.json` overlays,
`lib/ui/` screen rebuilds, equipment sprite strips, item icons,
gather/encounter/combat art, audio files. Required save/health impact: **zero**.

## 1. DO-NOT-TOUCH paths

A diff that touches any of these is, by itself, evidence the change crossed
the boundary. Escalate to Technical Director; do not "fix" by editing.

**Health accounting / step ingestion (RULES.md H-*)**
- `packages/stride_health/` — whole package. Dart: `lib/src/cursor_authorization.dart`,
  `origin_gateway.dart`, `origin_pseudonymizer.dart`, `platform_step_source.dart`,
  `step_sync_source.dart`, `messages.g.dart`, `pigeons/`. Native:
  `ios/…/HealthKitAdapter.swift`, `HealthKitStepStore.swift`;
  `android/src/main/kotlin/com/projectstride/stride_health/*.kt`
  (`HealthConnectAdapter`, `HealthConnectStepSource`, `StepBucketing`,
  `OriginKeying`, `ReadPlan`, `StepSource`, `StrideHealthPlugin`).
- `packages/stride_core/lib/src/steps/` — `step_ledger.dart`, `sync_batch.dart`,
  `reconciliation.dart`, `completeness.dart`, `step_origin_key.dart`
  (ledger, cursor, per-origin watermarks, replay protection).
- `packages/stride_secure_store/` — device-bound keying salt / identity.
- `lib/runtime/identity_vault.dart`, `lib/runtime/runtime_bootstrap.dart`.

**Engine, economy, epoch, travel/craft cost, defeat rules**
- `packages/stride_core/lib/src/engine/` — all of it: `game_engine.dart`,
  `game_state.dart`, `events.dart`, `event_reducer.dart`, `commands.dart`,
  `combat.dart`, `combat_rules.dart` (defeat/retreat rules), `progression.dart`,
  `rejection.dart`, `state_version.dart`, `state_migrations.dart`
  (**note:** migrations live in `engine/`, not `save/` as the FMPO02 report said).
- `packages/stride_core/lib/src/content/` — `balance_profile.dart`,
  `definitions.dart`, `content_loader.dart`, `validation.dart`,
  `reachability.dart`, `schema_version.dart` (step costs, yields, travel legs,
  recipe costs are typed here).
- `assets/content/v1/*.json` **except** `atlas/atlas_layout.json`:
  `recipes.json` (craft step cost), `locations.json` (travel legs/cost),
  `enemies.json` (combat numbers), `resource_nodes.json`, `profiles.json`
  (balance), `items.json`, `skills.json`, `contracts.json`, `projects.json`,
  `rumors.json`. New art must be wired by id in `lib/ui/icons/*` tables, never by
  editing a content JSON's numbers.

**Save / persistence / single-writer / CAS**
- `packages/stride_core/lib/src/save/` — all: `save_codec.dart`,
  `journal_record.dart`, `save_repository.dart`, `durable_state.dart`,
  `event_codec.dart`, `crc32c.dart`, `reset.dart`, `save_outcomes.dart`.
- `packages/stride_core/lib/src/bootstrap/`, `ports/`, `diagnostics/`.
- `packages/stride_storage/` — whole package (`lib/src/file_storage.dart`
  holds `directoryName = 'project_stride'`, slots A/B, advisory lock).
- `packages/stride_core/test/fixtures/save/v1_baseline.save … v9_baseline.save`
  and `packages/stride_core/tool/generate_v*_baseline.dart`.
- `lib/runtime/stride_session.dart` — the single command façade. UI reads its
  projections; UI never adds fields, never reaches `session.engine` /
  `session.runtime` (guarded, §2).
- `lib/ui/state/session_controller.dart`, `activity_controller.dart`,
  `craft_controller.dart` — the dispatch layer. Rebuilders may re-wire
  widgets *to* these; they do not edit the command bodies.

**Guards, CI, canon**
- `Scripts/check-*.sh`, `Scripts/lib/`, `Scripts/CASE_MAP.md`, `Scripts/verify.sh`,
  `.github/workflows/ci.yml`.
- `GAME_STATE_SIGNATURE_COMPATIBILITY.md`, `DECISIONS/0012_SAVE_FORMAT.md`,
  `0013_SINGLE_WRITER_PERSISTENCE.md`, `0014_S01A_PRIORITY_AND_SCOPE.md`,
  `0026_STEP_TRACKER_PROJECTION.md`.

**Touch-with-care (presentation-adjacent, still not save)**
- `lib/runtime/atlas_layout.dart` — reader for `atlas_layout.json`;
  `atlasLayoutSchemaVersion = 5` (line 81), minimum 1 (line 84). An overlay
  that needs a new field bumps *this* constant with a back-compat parse branch
  (the pattern lines 574–579 already use). It is not `StateVersion`.
- `lib/audio/audio_settings_store.dart` — sidecar JSON, temp-then-rename, outside
  `project_stride/`. Any new presentation preference copies this pattern.
- `lib/ui/state/craft_memory.dart` — same sidecar pattern, but it is the file
  that keeps CI red (§2). Do not add a second one under `lib/ui/`.

## 2. Guards and tests that prove the boundary

```bash
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
cd "C:/Users/jwspa/Downloads/ProjectStride_ClaudeCode_Handoff_COMPLETE/ProjectStride"

bash Scripts/check-core-purity.sh              # stride_core imports nothing platform
bash Scripts/check-ui-boundary.sh              # lib/ui never reaches engine/runtime/fs
bash Scripts/check-single-writer.sh            # one writer isolate, approved sites only
bash Scripts/check-origin-privacy.sh           # raw origin ids never cross Pigeon
bash Scripts/check-backup-exclusions.sh
bash Scripts/check-dependency-policy.sh
bash Scripts/check-step-model.sh --self-test   # what CI runs (ci.yml:196)
bash Scripts/check-step-model.sh               # production scan — see caveat
flutter test --reporter compact                # app (root)
(cd packages/stride_core && dart test)         # save/ledger/epoch/migration proof
(cd packages/stride_health && flutter test)
(cd packages/stride_storage && dart test -j 1) # not run this round
bash Scripts/verify.sh                         # everything, ~10+ min
```

Required-green test files are unchanged from the FMPO02 report §5
(save_protocol / save_migration / save_corruption / save_fault_matrix /
save_privacy / step_ledger_invariants / economy_epoch_cutover /
reconciliation_scenarios / lost_grant_regression in `stride_core`; the
adapter-to-ledger, cursor and origin suites in `stride_health`; restart /
concurrency probes in `stride_storage`).

### Status at 59c4723 (run 2026-09-02)

| Check | Result |
|---|---|
| `flutter test` (app) | **1,049 passed**, 1 m 58 s |
| `stride_core` `dart test` | **738 passed** |
| `stride_health` `flutter test` | **143 passed** |
| check-core-purity | PASS |
| check-single-writer (production) | PASS — 153 Dart / 13 native scanned, 6 approved construction sites in 2 files, 0 background entry points |
| check-origin-privacy | PASS |
| check-backup-exclusions | PASS |
| check-dependency-policy | PASS |
| check-ui-boundary | **FAIL (exit 1), pre-existing** — `lib/ui/state/craft_memory.dart` imports `package:path_provider/` and calls `File()` (since GFCP01 `830f1a1`). `ci.yml:125` runs this before the analyzer, so **CI is red on every branch** and all suite figures are local. Still open. Belongs to a scoped fix task, not to a UI rebuild — but a rebuilder who moves `craft_memory.dart` under `lib/ui/` again re-creates it. |
| check-step-model (production scan) | **13 `signature_allowed_files` findings, all false positives, pre-existing** since `a4c7ae9` (11 at PP02; +2 from `encounter_card.dart:299` and `content/definitions.dart:1064`). The `\.signature\b` pattern matches `DropDefinition.signature` (a boolean drop flag: `stride_session.dart:233 this.signature = false`, `encounter_card.dart:299 d.signature ? '★'`), not `StepLedger.signature`. CI and `verify.sh` run only `--self-test`, so this never fails a build. **Do not weaken the pattern (G-4)**; the fix is a `SIGNATURE_APPROVED`-style disambiguation owned by the guard's owner. |
| check-step-model `--self-test`, ios/android target, guard-parsers, rulekit, causality, supervisor, `package-art.js --check` | not run this round (CI runs them; art check is GOV-04's) |

Timing caveat for this Windows box: `check-ui-boundary.sh` takes ~70 s and
the `check-step-model.sh` production scan >4 min (it emits all 13 findings
then keeps scanning); both were starved past 5 min when run concurrently with
`flutter test`. Run guards and suites sequentially.

## 3. `lib/ui` call sites that mutate session/save — keep intact

All durable mutation goes through `SessionController` (or `ActivityController`
/ `CraftController`, which wrap it). A rebuilt screen must call the same
method with the same argument; it may move the button, not the wire.
`check-ui-boundary.sh` rejects any `session.engine` / `session.runtime` reach.

`SessionController` (`lib/ui/state/session_controller.dart`): `syncSteps`:212,
`eatFood`:294, `trackGoal`:305, `trackGoalContract`:309, `trackGoalPursuit`:313,
`trackGoalJourney`:317, `acceptContract`:321, `completeContract`:325,
`contributeToProject`:329, `resetPlaytest`:338, `startupSync`:389, `gather`:403,
`travel`:423, `travelJourney`:435, `craftQueued`:492, `craft`:504, `equip`:521,
`unequip`:525, `startEncounter`:549, `combatAttack`:553, `combatEat`:556,
`combatBrace`:561, `combatRetreat`:564, `startActivityQueue`:598,
`reconcileActivityQueue`:624, `stopActivityQueue`:642, `reload`:661.

| File | Line | Call |
|---|---|---|
| `lib/ui/stride_app.dart` | 165 | `_controller.startupSync()` — the one startup sync |
| `lib/ui/screens/adventure/adventure_screen.dart` | 581 | `controller.syncSteps()` |
| same | 133, 292 | `onReload: c.reload` (StaleBanner) |
| same | 383 | `controller.acknowledgeOpportunities` |
| `lib/ui/screens/adventure/encounter_card.dart` | 336 | `c.startEncounter(o.enemyId)` |
| `lib/ui/screens/adventure/board_card.dart` | 62 / 89 / 98 | `completeContract` / `acceptContract` / `contributeToProject` |
| same | 215, 248 | `trackGoalContract` |
| `lib/ui/screens/adventure/goal_tracker_card.dart` | 139 | `controller.trackGoal(slot, null)` |
| `lib/ui/screens/character/step_tracker_screen.dart` | 186 | `c.syncSteps()` |
| `lib/ui/screens/character/playtest_block.dart` | 55 | `c.resetPlaytest(freshStart: …)` |
| `lib/ui/screens/character/character_screen.dart` | 67 | `c.reload` |
| `lib/ui/screens/combat/combat_screen.dart` | 719 / 745 / 801 | `c.combatAttack` / `c.combatBrace` / `c.combatRetreat` (tear-offs) |
| same | 788 | `c.combatEat(e.itemId)` |
| same | 240, 265 | `onDismiss: c.acknowledgeCombat` |
| `lib/ui/screens/craft/craft_screen.dart` | 2201 | `SessionScope.read(context).equip(recipe.outputItem)` |
| same | 838, 1673 | `trackGoalPursuit(recipe.outputItem)` |
| same | 423 | `controller.reload` |
| `lib/ui/state/craft_controller.dart` | 379, 421 | `_sessions.craftQueued(_recipe!)` — craft begin lives here, not in the screen |
| `lib/ui/state/activity_controller.dart` | 432 / 472 / 522 | `startActivityQueue` / `reconcileActivityQueue` / `stopActivityQueue` — gather runs through the queue; no screen calls `gather` directly |
| `lib/ui/screens/inventory/inventory_screen.dart` | 1043 | `controller.eatFood(item)` |
| same | 1107, 1113 | `controller.unequip(slot)`, `controller.equip(item)` |
| same | 154 | `c.reload` |
| `lib/ui/screens/skills/skill_detail_screen.dart` | 622 | `trackGoalPursuit(item)` |
| `lib/ui/screens/skills/skills_screen.dart` | 78 | `controller.reload` |
| `lib/ui/screens/world/world_screen.dart` | 662 | `controller.travel(option.id)` |
| same | 242, 465 | `c.reload` |
| `lib/ui/screens/world/atlas/atlas_selection_panel.dart` | 133 | `controller.travelJourney(legs)` |
| same | 182, 183 | `trackGoal(GoalSlot.journey, null)` / `trackGoalJourney(place.id)` |

Read-side projections a rebuild may consume freely (no persistence behind
them): `equipmentVisualState`, `equippedSummary`, `combatFigures`,
`equippedIn(slot)`, `atlasLayout` / `atlasLayoutProblems`, `stepHistory()`,
`costOf` / `yieldOf` / `xpOf` / `displayNameOf`, `activityQueue`.

## 4. Save state version — v9, and why this round cannot move it

- `StateVersion.current = StateVersion(9)` —
  `packages/stride_core/lib/src/engine/state_version.dart:40`;
  `minimumSupported = 1` at line 50. Version history is the doc-comment table
  above it. Pinned by `packages/stride_core/test/fixtures/save/v9_baseline.save`
  (generated once by `tool/generate_v9_baseline.dart`; consumed in
  `test/save_migration_test.dart:328`).
- Three independent version axes; only the first is the save:
  1. `StateVersion` (save schema) — 9.
  2. `SchemaVersion.current = 1` (`content/schema_version.dart:26`) — content
     JSON. Untouched this round (§1).
  3. `atlasLayoutSchemaVersion = 5` (`lib/runtime/atlas_layout.dart:81`) —
     overlay JSON, app-side reader only.
- `grep -i 'atlas|layout|sprite|icon|audio|overlay'` across
  `packages/stride_core/lib/src/save/*.dart`, `engine/game_state.dart`,
  `engine/state_version.dart` returns nothing save-relevant: no art, layout,
  overlay or audio fact is encoded. `AtlasLayout` is loaded by
  `StrideSession._loadAtlas` (`stride_session.dart:2274`) into an in-memory
  field (`:2157`), never into `GameState`.
- Asset registration is `pubspec.yaml` only: `assets/art/v1/{ambient,combat,
  world,env,node,work,reward}/` are declared as directories (lines 263–269),
  so new sprite strips there need no manifest edit; `assets/ui/v1/…` is
  enumerated file-by-file (179 entries) and a new icon needs its line.
  Neither is a persisted fact. Item icons key off existing `ContentId`s.
- Equipment visuals derive at read time from `Equipment.bySlot` + `items.json`
  (FMPO02 report §3–4 still exact). Therefore: **adding assets, overlays,
  sprite strips, icons, audio files, or `atlas_layout.json` entries cannot
  change `StateVersion`.** The only move that would is threading a *new*
  player-chosen fact (skin, dye, overlay toggle) into `GameState` — that is a
  v10 bump plus ADR, owned by Technical Director, out of EPO03 scope. A
  toggle that must persist goes in a sidecar (§1 touch-with-care).

## 5. Open items carried forward

1. `craft_memory.dart` UI-boundary violation — CI red, pre-existing, unowned
   by EPO03. Must be closed before any EPO03 merge is judged on CI colour.
2. `check-step-model.sh` production-scan false positives (13) — pre-existing,
   guard-owner fix, never a pattern loosening.
3. `stride_storage` and `stride_secure_store` suites not run this round.
