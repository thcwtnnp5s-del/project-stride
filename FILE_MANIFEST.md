# File Manifest

**Architecture:** Flutter for Android and iOS, pure-Dart simulation core, first-party Swift and Kotlin health adapters. See `DECISIONS/0010_CROSS_PLATFORM_STACK.md`.

> The superseded native-Swift scaffold was retired at M-5. It survives in history at commit `859d0ac`. Documents describing it are banded as superseded and listed under *Historical* below.

---

## Source

### Application

- `lib/main.dart` — entry point; runs the real bootstrap before the first frame
- `lib/runtime/runtime_bootstrap.dart` — storage, identity, coordinator wiring
- `lib/runtime/identity_vault.dart` — where the reconciliation identity lives
- `lib/runtime/stride_session.dart` — S-01A: the fetch → reconcile → commit loop
- `lib/runtime/asset_content.dart` — content pack from the asset bundle
- `lib/ui/dev_harness.dart` — S-01A developer harness (redacted diagnostics)
- `test/s01a_vertical_slice_test.dart` — the fourteen S-01A acceptance properties
- `test/identity_vault_test.dart`, `test/identity_vault_orphan_test.dart`
- `test/per_write_exclusion_diagnostic_test.dart`
- `pubspec.yaml`, `analysis_options.yaml`
- `android/`, `ios/` — Flutter platform runners

> `lib/ui/root_placeholder.dart` and `test/app_shell_test.dart` were the M-2
> skeleton and were removed in S-01A: the app now boots into the harness, so a
> test asserting that the placeholder renders and carries no buttons was
> asserting the absence of the thing that had just been built.

### `packages/stride_core` — pure Dart simulation

Imports no Flutter, no plugin, no `dart:io`. Enforced structurally and by test.

- `pubspec.yaml` — declares no Flutter dependency
- `lib/stride_core.dart` — public API
- `lib/src/core_info.dart` — module marker, forbidden-import list
- `lib/src/ports/step_provider.dart` — `StepProvider` port and the cursor-recovery contract
- `test/core_info_test.dart`, `test/core_purity_test.dart`

### `packages/stride_health` — first-party health plugin

- `pigeons/health_api.dart` — the contract, single source of truth
- `lib/stride_health.dart`, `lib/src/platform_step_provider.dart`, `lib/src/mock_step_provider.dart`
- `lib/src/messages.g.dart` — generated Dart
- `android/…/StrideHealthPlugin.kt`, `HealthConnectAdapter.kt`, `Messages.g.kt`
- `android/src/test/…/HealthConnectAdapterTest.kt` — 5 JVM tests
- `ios/stride_health/Sources/stride_health/StrideHealthPlugin.swift`, `HealthKitAdapter.swift`, `Messages.g.swift`
- `example/` — host app for native tests
- `example/ios/RunnerTests/RunnerTests.swift` — 12 Swift tests
- `example/integration_test/plugin_integration_test.dart` — on-device channel checks
- `test/mock_step_provider_test.dart` — 7 Dart tests

### Tooling

- `.github/workflows/ci.yml` — four-job matrix
- `Scripts/check-core-purity.sh`, `Scripts/check-dependency-policy.sh`, `Scripts/verify.sh`
- `.gitignore`

---

## Project operating system

### Root

- `README.md`, `CLAUDE.md`, `PROJECT_STATE.md`, `HANDOFF_INSTRUCTIONS.md`, `FILE_MANIFEST.md`

### Project Kernel

`PROJECT_KERNEL/00_PROJECT.md` … `13_INSPIRATION.md` — identity, why, vision, pillars, promise, non-negotiables, anti-features, decision framework, glossary, success criteria, roadmap, AI operating instructions, decision log, inspiration.

### Studio Operations

`STUDIO_OPERATIONS/` — agent orchestration, workflow, review process, quality standards, change management, Claude launch protocol.

### Agents and commands

- `AGENTS/` — ten role charters
- `.claude/agents/` — the same ten installed as subagents
- `COMMANDS/` — seven workflow definitions
- `.claude/commands/` — the same seven installed as slash commands

### Game Bible

`GAME_BIBLE/VISION/`, `SYSTEMS/` (progression, walking, skills, crafting, economy, inventory), `WORLD/`, `COMBAT/`, `AUDIO/`, `UI_UX/`, `HEALTH_INTEGRATION/`, `CONTENT/`, `TECHNICAL/`.

Planned, not yet written: `GAME_BIBLE/ART/01_VISUAL_IDENTITY.md` (task P-01), `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md` (task S-06).

---

## Decisions

| # | Decision | Status |
|---|---|---|
| 0001 | Progression is step-clocked only | Active |
| 0002 | Native Swift + SwiftUI | ⛔ **Superseded by 0010** |
| 0003 | Turn-based, retreat-not-death combat | Active |
| 0004 | Milestone 01 scope freeze | Active |
| 0005 | Audio sourcing and provenance | Active |
| 0006 | One activity at a time | Active |
| 0007 | Progression pacing and step fixtures | Active |
| 0008 | Stepless-week behavior | Active |
| 0009 | Platform targets and distribution | Active, amended by 0010 and 0011 |
| **0010** | **Flutter, pure Dart core, first-party health adapters** | ✅ **Active architecture decision** |
| 0011 | Staged private distribution | Active |

Template: `DECISIONS/DECISION_TEMPLATE.md`.

---

## Active planning and technical documents

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md` — v2.0, Flutter
- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` — v2.0, 41 tasks
- `MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md`, `MILESTONE_01_IMPLEMENTATION_PLAN.md`
- `TECHNICAL/PROJECT_SETUP.md` — how to build and verify
- `TECHNICAL/PROJECT_STRUCTURE.md` — package layout and the Pigeon boundary
- `TOOLCHAIN_REPORT_WINDOWS.md` — verified Windows toolchain
- `AUDIO/AUDIO_ASSET_MANIFEST.md` — asset provenance
- `JOURNAL/OPEN_QUESTIONS.md`

## Reviews

- `DESIGN_REVIEW.md`, `CRITIC_REPORT.md` — original plans
- `DESIGN_REVIEW_FLUTTER.md` — Flutter plans, four roles
- `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md` — why Flutter

## Migration record

- `MIGRATION_EXECUTION_PLAN.md` — M-1 to M-6
- `MIGRATION_IMPACT_F01.md` — cost assessment
- `MIGRATION_COMPLETION_REPORT.md` — M-1 to M-3
- `M4_CI_COMPLETION_REPORT.md` — CI validation
- `MIGRATION_CLOSURE_REPORT.md` — M-5 and M-6, final
- `MILESTONES/evidence/m2_android_emulator.png`

## Historical — superseded, retained, **do not implement**

- `DECISIONS/0002_TECHNOLOGY_STACK.md`
- `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`
- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`
- `MILESTONES/F-01_COMPLETION_REPORT.md`
- `STUDIO_INITIALIZATION_REPORT.md` §4 (stack recommendation only; the audit stands)
- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_TEMPLATE.md`, `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_TEMPLATE.md`

Each carries a banner at the top of the file. None describes files that still exist.
