# Milestone 01 Task Breakdown

> ⛔ **SUPERSEDED — historical record only.** This is the v1.1 native-Swift task breakdown, replaced on 2026-08-01.
>
> **Project Stride is a Flutter application** targeting Android and iOS, with first-party Swift (HealthKit) and Kotlin (Health Connect) adapters. See `DECISIONS/0010_CROSS_PLATFORM_STACK.md` and `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` (v2.0, Flutter).
>
> Do not implement anything described below. Retained so the reasoning, and the reason it stopped applying, remain legible.



**Project:** Project Stride
**Milestone:** 01 — First Adventure Vertical Slice
**Version:** 1.1 — review findings applied
**Date:** 2026-08-01
**Author:** Studio Stride
**Status:** Awaiting owner approval — no production code written
**Reviews:** `DESIGN_REVIEW.md` (approved with changes), `CRITIC_REPORT.md` (approved with findings). All eleven design-review changes and all four actionable critic findings are applied below and marked inline with their finding ID.

Replaces `MILESTONE_01_TASK_BREAKDOWN_TEMPLATE.md`. Sequenced per `MILESTONE_01_IMPLEMENTATION_PLAN.md`, architected per `ARCHITECTURE_IMPLEMENTATION_PLAN.md`, bounded by `DECISIONS/0001`–`0004`.

---

## How to read this

Every task carries **ID, Title, Owner agent, Objective, Inputs, Dependencies, Deliverables, Acceptance criteria, Tests, Documentation, Status** as required by the template.

Acceptance criteria are written to be **checkable** — a reviewer can say yes or no without interpretation. "Feels good" is never an acceptance criterion; where feel is the point, the criterion names the manual check and who signs it off.

**Status values:** `Not started` · `In progress` · `Blocked` · `In review` · `Done`

**Ordering rule:** the riskiest system in the project (step reconciliation) is tested before it is built, and built before anything depends on it.

---

## Phase 0 — Studio initialization

*Complete. Recorded here for traceability.*

| ID | Title | Owner | Status |
|---|---|---|---|
| P0-01 | Audit repository, produce `STUDIO_INITIALIZATION_REPORT.md` | Critic Agent | Done |
| P0-02 | Resolve contradictions C-01 – C-09 | Creative Director | Done |
| P0-03 | Select and record the technology stack | Technical Director | Done |
| P0-04 | Produce `ARCHITECTURE_IMPLEMENTATION_PLAN.md` | Technical Director | Done |
| P0-05 | Produce this task breakdown | Lead Game Designer | Done |
| P0-06 | Install version control and executable studio workflow | Technical Director | Done |
| P0-07 | Design, critic, and QA review of the plans | Critic Agent | Done |
| P0-08 | **Owner approval of the plans** | Owner | **Pending** |

---

## Phase 1 — Foundation

### F-01 — Project skeleton and core purity

- **Owner:** Technical Director
- **Objective:** Stand up the Xcode project, the `StrideCore` package, and the boundary that keeps them separate.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §2; `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md`
- **Dependencies:** P0-08
- **Scope limit:** project creation, `StrideCore` package, dependency and import boundaries, test targets, build verification, supporting documentation. **No gameplay, no HealthKit, no production UI.**
- **Deliverables:** Xcode project (iOS 17, Swift 6 strict concurrency, iPhone portrait only); `StrideCore` local package; app target depending on core; test targets; import boundary guard; verification script; `TECHNICAL/PROJECT_SETUP.md`
- **Acceptance criteria:**
  1. App builds and launches to a placeholder screen on both simulators in the test matrix
  2. `StrideCore` tests run with `swift test`, no simulator, in under a second
  3. The import guard **fails** when a forbidden import is added to a core file, demonstrated once
  4. `Info.plist` permits portrait only; a check verifies it *(0009)*
  5. Deployment target is iOS 17; the app target is iPhone-only, with no iPad idiom *(0009)*
  6. No third-party runtime dependency is declared
- **Tests:** Build check on both simulators; core purity test; deliberate-violation check; orientation and deployment-target checks
- **Documentation:** `TECHNICAL/PROJECT_SETUP.md`
- **Status:** **In review** — see `MILESTONES/F-01_COMPLETION_REPORT.md`. All authorable deliverables complete; build verification blocked on macOS access.

### F-02 — Content schemas and loader

- **Owner:** Technical Director, with Systems Designer
- **Objective:** Define the JSON schemas and the validated loading path, before any content exists to load.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §7; `GAME_BIBLE/SYSTEMS/`
- **Dependencies:** F-01
- **Deliverables:** `Codable` types for items, recipes, skills, resource nodes, locations, enemies, encounters, audio cues; `ContentLoader` port + bundle adapter; validator; **deferred-vocabulary guard**
- **Acceptance criteria:**
  1. All nine content files decode into typed values
  2. Validator rejects: unresolved ID references, a recipe unreachable from starting equipment, a gatherable with no consumer, a skill missing its XP curve, a material with no audio cue
  3. Every ID is a stable string slug; no array-index references anywhere
  4. Validation failure surfaces as a **test failure**, never a runtime crash
  5. Locations carry `isSafe`; Haven's Rest is safe, the other three are not *(TD-4)*
  6. Activities carry `activityKind: terminating | repeating` *(QA-1)*
  7. A test fails the build if `expedition`, `profession`, `adventureMomentum`, `currency`, `merchant`, or any combat-skill identifier appears in content or core source. Deferred concepts are guarded from the day the schema exists, not audited at the end *(CR-5)*
- **Tests:** Round-trip decode; one deliberately broken fixture per validation rule
- **Documentation:** `TECHNICAL/CONTENT_SCHEMA.md`
- **Status:** Not started

### F-03 — GameState, events, and the engine entry point

- **Owner:** Technical Director, with Lead Game Designer
- **Objective:** Establish the value-type state, the event catalogue, and the single mutation path.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §2.4, §2.5, §3
- **Dependencies:** F-02
- **Deliverables:** `GameState`; `GameEvent` catalogue; `PlayerIntent`; `GameEngine` with `apply` and `ingest` only; seeded RNG in state
- **Acceptance criteria:**
  1. `GameState` is a value type, `Codable` and `Equatable`
  2. Every mutation returns its events; no mutation is silent
  3. The core reads no clock and draws no unseeded randomness — verified by inspection and by a repeat-run determinism test
  4. Identical state + identical intent ⇒ identical resulting state and identical event sequence, across 1,000 randomized cases
  5. **Step consumption is not publicly callable.** Steps can only be spent through activity progression, and an invariant test asserts `stepsConsumed` never increases without a matching activity-progress event *(TD-1)*
- **Tests:** Determinism suite; `Equatable` round-trip; event completeness
- **Documentation:** `TECHNICAL/CORE_ARCHITECTURE.md`
- **Status:** Not started

### F-04 — Step reconciliation test harness *(written before the feature)*

- **Owner:** QA Director, with Technical Director
- **Objective:** Encode the twelve reconciliation scenarios as failing tests **before** reconciliation exists.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §6.7
- **Dependencies:** F-03
- **Deliverables:** `SimulatedStepProvider` (scriptable batches, deletions, duplicates, out-of-order, errors); the twelve scenarios as tests
- **Acceptance criteria:**
  1. All twelve scenarios exist as tests and **all fail** for the right reason
  2. No test touches HealthKit, the file system, or the wall clock
  3. Full suite runs in under one second
- **Tests:** The suite is the deliverable
- **Documentation:** `TECHNICAL/STEP_RECONCILIATION_TESTS.md`
- **Status:** Not started
- **Note:** This ordering is deliberate and is the plan's main defence against risk A-01. Do not reorder it.

### F-05 — Save, ledger, and crash recovery

- **Owner:** Technical Director
- **Objective:** Durable local persistence that cannot double-count or lose a step batch across a crash.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §4, §6.3
- **Dependencies:** F-03
- **Deliverables:** `SaveStore` port; file adapter with atomic replace, rolling backup, `.completeFileProtectionUnlessOpen`; append-only ledger; version-1 schema with a no-op migration hook
- **Acceptance criteria:**
  1. Save → reload → state is `Equatable`-identical
  2. A write interrupted mid-flight leaves the previous save loadable
  3. A corrupt primary save falls back to the backup
  4. A version-0 fixture is rejected cleanly with a clear message, not a crash
  5. Ledger replay after a simulated crash between ledger-write and snapshot-write yields identical state
- **Tests:** Round-trip; interrupted write; corruption; version rejection; replay idempotence
- **Documentation:** `TECHNICAL/SAVE_FORMAT.md`
- **Status:** Not started

### F-06 — Skill framework

- **Owner:** Systems Designer
- **Objective:** XP, levels, curves, and milestone unlocks for the five skills, driven entirely by content.
- **Inputs:** `GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md`; `DECISIONS/0004`
- **Dependencies:** F-03
- **Deliverables:** Skill state and XP application; content-defined curves to level 20; milestone unlock hooks; `skillXPGained` / `skillLevelUp` events
- **Acceptance criteria:**
  1. Exactly five skills exist: Woodcutting, Mining, Foraging, Smithing, Cooking
  2. Cap is 20 and is enforced; excess XP is discarded without error
  3. No XP curve constant appears in Swift source
  4. Every level 1–20 for every skill has a defined XP threshold and no gaps
- **Tests:** Curve monotonicity; cap behavior; unlock firing; no-hardcoded-constants check
- **Documentation:** `GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md` (implementation note)
- **Status:** Not started

---

## Phase 2 — Step loop

### S-01 — StepProvider port and HealthKit adapter

- **Owner:** Technical Director
- **Objective:** Read steps from HealthKit behind the port, correctly and defensively.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §5
- **Dependencies:** F-04
- **Deliverables:** `HealthKitStepProvider` using `HKAnchoredObjectQuery` with anchor persistence, deletion handling, manual-entry filter; opportunistic background delivery; HealthKit capability and usage strings
- **Acceptance criteria:**
  1. Read-only `stepCount` authorization; no write scope requested anywhere in the project
  2. Manual entries filtered by default, includable by setting
  3. A failed query leaves the anchor unchanged and `stepsIngested` untouched
  4. Cold-launch backfill fully reconciles a multi-day absence with no network
  5. The app behaves identically whether authorization was denied or simply has no data
- **Tests:** Adapter against a stubbed HealthKit store; error paths; filter behavior
- **Documentation:** `TECHNICAL/HEALTHKIT_INTEGRATION.md`
- **Status:** Not started

### S-02 — Reconciliation engine *(turns F-04 green)*

- **Owner:** Technical Director
- **Objective:** Implement the ledger model until all twelve scenarios pass.
- **Inputs:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §6
- **Dependencies:** F-04, F-05, S-01
- **Deliverables:** Ingestion sequence (ledger before snapshot); monotonic counters; `discrepancyDebt` with cap and forgiveness; idempotent replay
- **Acceptance criteria:**
  1. **All twelve F-04 scenarios pass**
  2. `stepsIngested` and `stepsConsumed` never decrease, asserted as an invariant on every mutation
  3. No day-boundary or timezone arithmetic exists anywhere in the reconciliation path — verified by inspection
  4. No correction, deletion, or Health edit can reduce progress the player has already been granted
  5. Debt beyond the cap is forgiven and logged; the player is never permanently blocked
  6. The `discrepancyDebt` cap lives in content as a provisional tunable, not as a Swift constant. Its value is derived in `GAME_BIBLE/BALANCE/` once the owner's daily step count is known — roughly three days of walking *(TD-2)*
- **Tests:** The F-04 suite; invariant assertions; a 10,000-iteration randomized ingest/consume fuzz with monotonicity assertions
- **Documentation:** `TECHNICAL/STEP_RECONCILIATION.md`
- **Status:** Not started
- **On completion, start the fourteen-day real-data log immediately** *(QA-2)*. It runs in parallel through Phases 3–5 on the owner's device, so V-02 reviews a collected log rather than starting a two-week clock at the end of the milestone.

### S-03 — Activity selection and step allocation

- **Owner:** Lead Game Designer, with Systems Designer
- **Objective:** The "plan before you walk" interaction — the most important decision in the game.
- **Inputs:** `DECISIONS/0001`; `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md`
- **Dependencies:** S-02, F-06
- **Deliverables:** One selected activity at a time; explicit allocation of banked steps; overflow handling by activity kind; activity progress and completion events; `DECISIONS/0006_SINGLE_ACTIVITY.md`
- **Acceptance criteria:**
  1. Unallocated steps bank indefinitely and **never expire**
  2. **Terminating** activities (travel) complete on arrival and bank the remainder *(QA-1)*
  3. **Repeating** activities (gathering) continue consuming until the player's allocation is exhausted, then bank zero. The allocation is the boundary, not the activity *(QA-1)*
  4. Switching activity loses no banked steps and no partial progress on the previous activity
  5. Nothing in the game is unavailable at zero banked steps — every screen, every affordable craft, every prepared encounter remains accessible
  6. Progress advances **only** on step consumption; a state left untouched for a simulated year advances zero — **and loses nothing.** No banked steps, partial progress, resources, XP, or discoveries decay, spoil, or expire *(0008)*
  7. At zero available steps the player can still craft from owned resources, manage equipment, review skills and discoveries, and fight previously unlocked encounters *(0008)*
- **Tests:** Bank/expire; overflow behavior for both activity kinds; a 14-day-absence allocation test asserting gathering repeats and travel banks; activity switching; the zero-step and idle-year assertions
- **Documentation:** `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md`; `DECISIONS/0006_SINGLE_ACTIVITY.md`
- **Status:** Not started
- **Note:** Single-activity-at-a-time is a design decision, not an implementation convenience. It must be recorded by the Lead Game Designer before this task starts, naming the travel-versus-gather tension as intended *(CD-1)*.

### S-04 — Travel

- **Owner:** World Designer, with Systems Designer
- **Objective:** Step-driven travel between the four locations that reads as a journey.
- **Inputs:** `GAME_BIBLE/WORLD/02_EXPLORATION_AND_TRAVEL.md`
- **Dependencies:** S-03
- **Deliverables:** Location graph in content; travel as an activity; remaining-distance state; arrival and discovery events
- **Acceptance criteria:**
  1. Travel requires a chosen destination and reports remaining progress at all times
  2. Arrival unlocks that location's activities
  3. First arrival emits `locationDiscovered` exactly once, ever
  4. Travel state survives app termination mid-journey
  5. All four locations are reachable, and the route graph is content-defined
- **Tests:** Graph reachability; interrupted travel; single-fire discovery
- **Documentation:** `GAME_BIBLE/WORLD/02_EXPLORATION_AND_TRAVEL.md`
- **Status:** Not started

### S-08 — Early feel check *(added by Critic review CR-6)*

- **Owner:** Creative Director, with owner
- **Objective:** Put a real moment in front of the owner at task fourteen rather than task thirty-four.
- **Inputs:** `CRITIC_REPORT.md` CR-6
- **Dependencies:** S-04
- **Deliverables:** A short owner session: choose a destination, take a real walk, return, arrive at Whispering Woods — with placeholder visuals and placeholder sound
- **Acceptance criteria:**
  1. The owner takes at least one real walk against a real destination and reports back
  2. The question answered is narrow and honest: **did arriving produce a spark?**
  3. A "no" triggers a design review before Phase 3 begins
- **Tests:** None — this is a judgement check, and it is deliberately placed before the expensive phases
- **Documentation:** `JOURNAL/` entry recording the owner's reaction verbatim
- **Status:** Not started
- **Note:** Correctness is measurable early and feel is measurable late, so feel is usually discovered last. This task exists to break that pattern. If travel-on-real-steps is not satisfying with placeholders, no amount of Phase 5 polish will rescue it.

### S-05 — Debug step injector

- **Owner:** QA Director
- **Objective:** Make the game testable without walking ten kilometres per iteration.
- **Inputs:** Risk A-03
- **Dependencies:** S-02
- **Deliverables:** Debug-only panel injecting arbitrary step counts, simulating absences, forcing corrections and deletions; the three daily-step fixtures as one-tap presets; **the developer/test balance profile**
- **Acceptance criteria:**
  1. Compiled out of release builds entirely — verified by a symbol check on a release binary
  2. Injected steps traverse the identical reconciliation path as real ones
  3. Can simulate a 30-day absence in one action
  4. Low (2,500), reference (7,500), and high (15,000) daily fixtures are available as presets
  5. **The accelerated balance profile is a separate content profile.** Selecting it never mutates, overwrites, or migrates production balance data — asserted by a test that switches profiles and confirms production values are byte-identical afterwards *(0007)*
  6. The accelerated profile is unavailable in release builds
  7. Tests asserting *pacing* run against production values; the accelerated profile is only for tests that need to reach a state quickly
- **Tests:** Release-build absence check; profile-isolation test; a test asserting no pacing assertion runs under the accelerated profile
- **Documentation:** `TECHNICAL/DEBUG_TOOLS.md`
- **Status:** Not started

### S-06 — First-pass balance numbers

- **Owner:** Systems Designer, with owner input
- **Objective:** Close gap G-06 with a defensible starting point.
- **Inputs:** `DECISIONS/0007_PROGRESSION_PACING.md`
- **Dependencies:** S-03, S-05
- **Deliverables:** `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md`; all values in content files
- **Acceptance criteria:** every target below is met at the **reference fixture of 7,500 steps/day**, and the low (2,500) and high (15,000) fixtures are reported alongside.

  | Beat | Target |
  |---|---|
  | First gathering result | First few hundred allocated steps |
  | First combat encounter | ~1,000–2,000 total steps |
  | First bronze upgrade | ~3,000–6,000 allocated steps |
  | Access to ordinary starter areas | ~10,000–20,000 total steps |
  | Hollow Guardian readiness | ~25,000–40,000 total allocated steps |
  | Level 20 in one skill | 60,000–90,000 allocated steps |

  1. **The complete loop is exposed and validatable within one to two weeks of ordinary movement** at every fixture
  2. **Maxing all five skills is not required to complete Milestone 01**, and nothing in the game implies otherwise
  3. Every number lives in content and is marked provisional
  4. Step fixtures appear **nowhere** in player-facing copy, and nothing in the game presents a step count as a target, a recommendation, or expected behavior *(0007)*
- **Tests:** Projections at all three fixtures asserting each beat lands in its band; a copy audit for implied step recommendations
- **Documentation:** `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md`
- **Status:** Not started — unblocked by `DECISIONS/0007`

### S-07 — Privacy policy and permission copy

- **Owner:** Technical Director
- **Objective:** Close gap G-09 before it becomes a submission blocker.
- **Inputs:** `GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md`
- **Dependencies:** S-01
- **Deliverables:** Privacy policy; in-app rationale screen; `NSHealthShareUsageDescription`; disconnect-and-reset control
- **Acceptance criteria:**
  1. Policy states plainly that health data never leaves the device
  2. Rationale is shown before the system permission sheet
  3. A decline is never re-prompted automatically
  4. Disconnect-and-reset clears anchor, ledger, and step counters while leaving gameplay progress intact
- **Tests:** Reset-path integration test asserting gameplay progress survives
- **Documentation:** `LEGAL/PRIVACY_POLICY.md`
- **Status:** Not started

---

## Phase 3 — RPG activities

### A-00 — Author the starter content set *(added by QA review QA-5)*

- **Owner:** Systems Designer, with World Designer
- **Objective:** Own the item list and the connective tissue between it, so gaps surface at authoring time rather than when the validator fires four tasks later.
- **Inputs:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`; `GAME_BIBLE/SYSTEMS/05_ECONOMY_AND_RESOURCE_MODEL.md`
- **Dependencies:** F-02, S-06
- **Deliverables:** Complete `items.json` for the Milestone 01 set — raw materials, processed components, finished equipment, consumables — with tiers, and the material-to-recipe-to-use map
- **Acceptance criteria:**
  1. Every raw resource has a processing path and a finished use
  2. Every finished item answers the four crafting-framework questions
  3. No item exists that nothing produces and nothing consumes
  4. Traveler armor appears as granted equipment and in no recipe
  5. No currency item exists
- **Tests:** F-02 validator passes against the complete set; orphan-item check
- **Documentation:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`
- **Status:** Not started

### A-01 — Gathering: Woodcutting, Mining, Foraging

- **Owner:** Systems Designer
- **Objective:** Convert allocated steps into resources and skill XP.
- **Inputs:** `GAME_BIBLE/SYSTEMS/`; `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`
- **Dependencies:** S-03, F-06
- **Deliverables:** Resource nodes per location; step-cost and yield in content; tool requirements; gathering events carrying material and tier
- **Acceptance criteria:**
  1. Each gathering skill has content-defined nodes with step cost, yield, XP, and tool requirement
  2. Tool requirements are satisfiable from the granted starting tools — no gathering is blocked at a fresh start
  3. Every gathered resource has at least one consumer, enforced by the F-02 validator
  4. Events carry material and tier, so audio can distinguish oak from pine and copper from iron
- **Tests:** Yield and XP determinism; tool gating; starting-state reachability
- **Documentation:** `GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md`
- **Status:** Not started

### A-02 — Inventory and equipment

- **Owner:** Systems Designer, with UX Designer
- **Objective:** Hold what the player earns without becoming management friction.
- **Inputs:** `GAME_BIBLE/SYSTEMS/06_INVENTORY_AND_EQUIPMENT_SYSTEM.md`; `DECISIONS/0004`
- **Dependencies:** A-01
- **Deliverables:** Stacking inventory with four categories; weapon/armor/tool equipment slots; starting grant
- **Acceptance criteria:**
  1. Categories are Materials, Equipment, Consumables, Quest/Discovery
  2. The player starts with Training Sword, Training Axe, Training Pickaxe, and Traveler armor
  3. Traveler armor exists as granted equipment and appears in **no** recipe
  4. Equipment changes are reflected in combat statistics immediately
  5. No inventory cap in Milestone 01; if one is ever proposed it needs a decision record
- **Tests:** Stacking; starting-grant fixture; equip/unequip stat effects
- **Documentation:** `GAME_BIBLE/SYSTEMS/06_INVENTORY_AND_EQUIPMENT_SYSTEM.md`
- **Status:** Not started

### A-03 — Crafting: Smithing and Cooking

- **Owner:** Systems Designer
- **Objective:** Turn movement-earned resources into capability.
- **Inputs:** `GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_FRAMEWORK.md`
- **Dependencies:** A-02
- **Deliverables:** Recipe execution; Bronze tier weapons, tools, and armor; healing food; crafting XP
- **Acceptance criteria:**
  1. Bronze is reachable from a fresh start using only granted tools and gathered materials — asserted by an automated path test
  2. Crafting is **instant on material availability** and costs no steps, since steps were already spent gathering
  3. Every recipe answers the four questions in the crafting framework, recorded in content comments or the design doc
  4. No recipe produces Traveler armor
- **Tests:** Fresh-start-to-Bronze path test; material consumption; XP award
- **Documentation:** `GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_FRAMEWORK.md`
- **Status:** Not started

### A-04 — Audio and haptic event hooks

- **Owner:** Audio Director, with Technical Director
- **Objective:** Make audio a first-class system from the moment there is something to hear, with placeholder assets.
- **Inputs:** `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`; `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8
- **Dependencies:** A-01
- **Deliverables:** `AudioDirecting` and `HapticPlaying` adapters; four-bus AVAudioEngine graph; `audio_cues.json`; placeholder cues
- **Acceptance criteria:**
  1. No simulation code references a sound file
  2. Every gathering, crafting, and combat event has a cue entry; missing material coverage **fails a content test**
  3. Audio ducks for other apps' audio and respects the silent switch
  4. Independent volume per bus, plus master mute, plus a haptics toggle
  5. No haptic conveys information that is not also conveyed visually or audibly
- **Tests:** Cue coverage test; event-to-cue mapping; bus routing
- **Documentation:** `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`; `TECHNICAL/AUDIO_ARCHITECTURE.md`
- **Status:** Not started

### A-05 — Audio asset sourcing plan

- **Owner:** Audio Director
- **Objective:** Close gap G-05 before placeholders calcify into shipped sound.
- **Inputs:** `DECISIONS/0005_AUDIO_SOURCING.md`; `AUDIO/AUDIO_ASSET_MANIFEST.md`
- **Dependencies:** A-04
- **Deliverables:** Generated and CC0 placeholder assets; complete manifest rows; per-material cue matrix for the Milestone 01 content set
- **Acceptance criteria:**
  1. Every asset has a manifest row with source, licence, model, verbatim prompt, date, and usage. **A shipped asset with no row is a defect.**
  2. Every source is lawfully licensed for TestFlight distribution
  3. **No asset originates from WalkScape, Melvor Idle, Old School RuneScape, or New World** — verified by provenance audit
  4. The cue matrix covers every material and tier in the Milestone 01 set; a material falling through to a generic sound fails the build
  5. Audio is referenced by asset ID only — no filename or path appears in code or content
  6. Total audio memory within the 30 MB budget, or the budget is revised with reasoning
  7. No paid library is used without a new decision record
- **Tests:** Manifest completeness check against bundled assets; cue coverage test; asset-ID-only reference check; automated budget check
- **Documentation:** `AUDIO/AUDIO_ASSET_MANIFEST.md`
- **Status:** Not started — unblocked by `DECISIONS/0005`

---

## Phase 4 — Combat prototype

### C-01 — Combat state and resolver

- **Owner:** Combat Designer, with Technical Director
- **Objective:** Deterministic turn-based encounters that survive interruption.
- **Inputs:** `DECISIONS/0003`; `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`
- **Dependencies:** A-03
- **Deliverables:** Encounter state in `GameState`; turn resolver; player actions (attack, use consumable, retreat); enemy behavior from content
- **Acceptance criteria:**
  1. Same state + same seed + same actions ⇒ identical outcome, every time
  2. Encounter state persists across app termination and resumes exactly
  3. No real-time pressure: no timer influences any outcome
  4. Ordinary encounters resolve in 6–12 turns at the intended preparation level
- **Tests:** Determinism across 1,000 seeded encounters; persistence round-trip mid-encounter; turn-count distribution
- **Documentation:** `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`
- **Status:** Not started

### C-02 — Defeat and retreat

- **Owner:** Combat Designer
- **Objective:** Implement retreat-not-death exactly as approved.
- **Inputs:** `DECISIONS/0003`
- **Dependencies:** C-01
- **Deliverables:** Defeat handling; return to last safe destination; encounter reset
- **Acceptance criteria:**
  1. Defeat removes **no** equipment, **no** inventory, **no** skill XP, **no** character XP, and **no** world progress — asserted by a full state diff showing only HP, consumables used, and location differ
  2. Consumables spent during the encounter stay spent
  3. The encounter resets and can be retried without limit
  4. There is no death state, no penalty timer, and no progress rollback anywhere in the codebase
  5. **The retreat screen explains why the player lost** in concrete terms — "the Guardian's hide turned your bronze blade" — so a loss teaches preparation rather than inviting a reroll *(CR-2)*
  6. `isSafe` locations are defined in content; retreat returns the player to the most recent safe one *(TD-4)*
  7. **Boss retries never require freshly-walked steps.** A player holding the necessary supplies can retry at zero available steps *(0008)*
- **Tests:** Full state-diff assertion on defeat; retry-without-limit test; retreat destination resolution
- **Documentation:** `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`
- **Status:** Not started

### C-03 — Character progression

- **Owner:** Systems Designer, with Combat Designer
- **Objective:** The only combat-power axis in the slice, alongside equipment.
- **Inputs:** `GAME_BIBLE/SYSTEMS/01_PROGRESSION_FRAMEWORK.md`; `DECISIONS/0003`
- **Dependencies:** C-01
- **Deliverables:** Character level and XP from encounters and skill milestones; HP and a small attack/defence contribution
- **Acceptance criteria:**
  1. No combat skill exists anywhere in content or code
  2. Character level contributes meaningfully but less than equipment and consumables — quantified in the balance document
  3. Character XP is never lost
- **Tests:** Level-up effects; the no-combat-skill content assertion
- **Documentation:** `GAME_BIBLE/SYSTEMS/01_PROGRESSION_FRAMEWORK.md`
- **Status:** Not started

### C-04 — Three starter enemies

- **Owner:** Combat Designer, with World Designer
- **Objective:** Forest Wolf, Cave Goblin, Hollow Guardian — a curve that teaches then tests.
- **Inputs:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`
- **Dependencies:** C-02, C-03
- **Deliverables:** Enemy definitions in content; the Hollow Guardian as the preparation gate; reward tables
- **Acceptance criteria:**
  1. Forest Wolf is winnable with starting equipment
  2. Cave Goblin requires at least one Bronze upgrade
  3. **Hollow Guardian is unwinnable without deliberate preparation** — asserted by a simulation showing an underprepared build loses across 100 seeds **under optimal play**, and a prepared build wins across 100 seeds *(CR-2)*
  4. No enemy is a health sponge: none exceeds the 12-turn target at its intended preparation level
  5. Difficulty comes from required preparation, never from attrition or punishment
- **Tests:** The seeded preparation-gate simulations, driven by an optimal-play solver rather than a fixed action sequence; turn-count bounds per enemy
- **Note:** With unlimited retries, deterministic resolution, and no time pressure, a gate that an optimal underprepared player can beat is not a gate — it is a puzzle the player will brute-force. The optimal-play qualifier is what makes criterion 3 mean anything *(CR-2)*.
- **Documentation:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`
- **Status:** Not started

---

## Phase 5 — Presentation

### P-01 — Visual identity

- **Owner:** UX Designer, with Creative Director
- **Objective:** Close gap G-04 before screens are built against an undefined aesthetic.
- **Inputs:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`
- **Dependencies:** P0-08
- **Deliverables:** `GAME_BIBLE/ART/01_VISUAL_IDENTITY.md` — palette, typography, iconography, illustration approach, motion language, **and an asset sourcing plan for a team with no artist**
- **Acceptance criteria:**
  1. Palette passes WCAG AA contrast in light and dark
  2. Motion language defines what progress, arrival, and level-up look like
  3. The sourcing plan is achievable without an artist and without copying assets
- **Tests:** Contrast audit
- **Documentation:** `GAME_BIBLE/ART/01_VISUAL_IDENTITY.md`
- **Status:** Not started

### P-02 — Navigation and six tabs

- **Owner:** UX Designer
- **Objective:** The six-destination shell.
- **Inputs:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`; `DECISIONS/0004`
- **Dependencies:** P-01, A-03
- **Deliverables:** Adventure, Character, Skills, Inventory, Craft, World
- **Acceptance criteria:**
  1. Exactly six tabs; Combat is not among them
  2. Every primary action is reachable one-handed on the largest supported device
  3. Maximum two levels of depth below any tab
  4. Touch targets ≥ 44 pt
  5. Within seconds of launch the player can answer: where am I, what am I doing, what changed, what next
- **Tests:** XCUITest navigation smoke; manual one-handed reachability check
- **Documentation:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`
- **Status:** Not started

### P-03 — The return summary

- **Owner:** UX Designer, with Lead Game Designer
- **Objective:** The hardest and most important screen in the game — what changed while you were away.
- **Inputs:** `GAME_BIBLE/VISION/01_CORE_GAME_LOOP.md` (Discover); `PROJECT_STATE.md` required experience #8
- **Dependencies:** P-02, S-03
- **Deliverables:** Post-reconciliation summary of steps ingested, activity progress, completions, resources, XP, level-ups, and remaining banked steps
- **Acceptance criteria:**
  1. Understandable in under ten seconds after a two-week absence
  2. Shows remaining banked steps and invites the next decision
  3. Contains **no** urgency language, no streak, no "you missed", no expiry warning — checked against `06_ANTI_FEATURES.md` line by line
  4. A zero-step return is calm and non-judgemental, with no nagging, and surfaces what the player *can* still do — craft, review, fight what is already unlocked *(0008)*
  5. No screen presents a step count as a target, a goal, or a recommendation *(0007)*
- **Tests:** Snapshot tests at 0, typical, and two-week-absence step volumes; anti-feature copy audit; step-recommendation copy audit
- **Documentation:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`
- **Status:** Not started

### P-04 — Combat screen

- **Owner:** UX Designer, with Combat Designer
- **Objective:** The full-screen encounter modal.
- **Inputs:** `DECISIONS/0004` §5
- **Dependencies:** P-02, C-04
- **Deliverables:** Combat modal presented from Adventure or World
- **Acceptance criteria:**
  1. Presented as a modal, not a tab; dismissible only by resolving or retreating
  2. Player and enemy state readable at a glance
  3. All actions reachable one-handed
  4. Backgrounding and relaunching mid-encounter resumes exactly where it left off
- **Tests:** XCUITest encounter flow; interruption resume test
- **Documentation:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`
- **Status:** Not started

### P-05 — Onboarding at Haven's Rest

- **Owner:** World Designer, with Lead Game Designer and UX Designer
- **Objective:** Grant the starting equipment and teach the whole loop. Treated as a real feature, not a formality (risk A-08).
- **Inputs:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`; `DECISIONS/0004`
- **Dependencies:** P-03, A-03
- **Deliverables:** First-run flow; equipment grant; HealthKit rationale and request; first activity selection; introductory NPC presence
- **Acceptance criteria:**
  1. Grants Training Sword, Training Axe, Training Pickaxe, and Traveler armor exactly once
  2. Teaches plan → walk → return without a wall of text
  3. Fully completable with zero steps available
  4. NPCs appear for lore and guidance and **cannot buy or sell anything**
  5. Skippable, and re-readable later from Character
- **Tests:** First-run integration test; single-grant assertion; zero-step completion test
- **Documentation:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`
- **Status:** Not started

### P-06 — Region ambience

- **Owner:** Audio Director
- **Objective:** Give each location its own sonic identity.
- **Inputs:** `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`
- **Dependencies:** A-05, P-04
- **Deliverables:** Four ambient beds with crossfade on location change; weather or time-of-day variation where cheap
- **Acceptance criteria:**
  1. Each location has a distinct ambient bed; a mine does not sound like a forest
  2. Crossfades on arrival with no audible seam or gap
  3. Ambience stops when the app is backgrounded
- **Tests:** Bed coverage per location; crossfade behavior
- **Documentation:** `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`
- **Status:** Not started

### P-07 — Accessibility pass *(split out by QA review QA-4)*

- **Owner:** UX Designer
- **Objective:** Make the game usable by more people, resourced as real work rather than a trailing acceptance line.
- **Inputs:** `STUDIO_OPERATIONS/QUALITY_STANDARDS.md`
- **Dependencies:** P-04
- **Deliverables:** Dynamic Type support; VoiceOver labels and traits; Reduce Motion; contrast verification; colour-independence audit
- **Acceptance criteria:**
  1. All text scales to the largest accessibility size without truncation or overlap
  2. Every interactive element has a VoiceOver label and correct traits
  3. **The full core loop — plan, return, gather, craft, equip, fight — is completable with VoiceOver**
  4. Reduce Motion is honored
  5. No information is conveyed by colour alone
- **Tests:** VoiceOver loop walkthrough; Dynamic Type snapshots at largest size; contrast audit
- **Documentation:** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`
- **Status:** Not started
- **Note:** This was originally one acceptance line inside the ambience task. It is a substantial piece of work and is separated so it can be resourced properly or consciously reduced — not silently dropped when the milestone runs long *(QA-4)*.

---

## Phase 6 — Validation

### V-01 — Functional QA

- **Owner:** QA Director
- **Objective:** Verify the complete loop end to end.
- **Dependencies:** All Phase 5 tasks
- **Acceptance criteria:** All eight required player experiences from `PROJECT_STATE.md` pass on a real device; zero critical or high defects open; **a full session at zero available steps is playable, calm, and loses nothing** *(0008)*
- **Tests:** Full suite green; manual checklist
- **Documentation:** `QA_REPORT.md`
- **Status:** Not started

### V-02 — Step-accounting QA on real data

- **Owner:** QA Director
- **Objective:** Review the fourteen-day real-data log that has been collecting since S-02.
- **Dependencies:** V-01, **and the log started at S-02**
- **Acceptance criteria:**
  1. Fourteen consecutive days on a real device with real walking: game total matches Health total exactly, allowing only for the manual-entry filter
  2. Airplane mode for a full day changes nothing
  3. A timezone change during the period has no effect
  4. No double-count and no loss observed at any point
- **Tests:** Review of the collected log; daily reconciliation against the Health app
- **Note:** The fourteen-day clock starts when S-02 lands and runs in parallel through Phases 3–5. Scheduling collection here would have added two idle weeks to the end of the milestone *(QA-2)*.
- **Documentation:** `QA_REPORT.md`
- **Status:** Not started

### V-03 — Save, offline, and interruption QA

- **Owner:** QA Director
- **Dependencies:** V-01
- **Acceptance criteria:** Force-quit at 20 points across the loop loses no progress; the app is fully playable in airplane mode from cold launch; no code path requires the network
- **Tests:** Kill-point matrix; airplane-mode session
- **Documentation:** `QA_REPORT.md`
- **Status:** Not started

### V-04 — Balance review

- **Owner:** Systems Designer, with QA Director
- **Dependencies:** V-02
- **Acceptance criteria:** Real fourteen-day data confirms the S-06 pacing targets, or the numbers are revised and the revision recorded
- **Tests:** Projection versus actual comparison
- **Documentation:** `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md` revision
- **Status:** Not started

### V-05 — Critic review

- **Owner:** Critic Agent
- **Dependencies:** V-01 – V-04
- **Acceptance criteria:** No Kernel violation; no anti-feature present; no unjustified complexity; scope still frozen
- **Tests:** Anti-feature audit of all player-facing copy. The deferred-vocabulary check is no longer performed here — it runs as a build-failing test from F-02 onward, so a forbidden concept fails on the day it is introduced rather than four phases later *(CR-5)*
- **Documentation:** `CRITIC_REPORT.md`
- **Status:** Not started

### V-06 — Playtest and milestone report

- **Owner:** Creative Director, with owner
- **Dependencies:** V-05
- **Acceptance criteria:** The owner walks, returns, understands what changed, improves their character, defeats the Hollow Guardian, and **wants to continue**. That last clause is the real acceptance criterion for the entire milestone, and only the owner can sign it.

  **Maxing the five skills is explicitly not required.** The milestone is complete when the loop is validated, which `DECISIONS/0007` targets at one to two weeks of ordinary movement — not when the content is exhausted.
- **Tests:** One-to-two-week owner playtest, extended at the owner's discretion
- **Documentation:** `MILESTONES/MILESTONE_01_REPORT.md`
- **Status:** Not started

---

## Dependency spine

```text
P0-08 approval
  └─ F-01 → F-02 → F-03 ─┬─ F-04 ──┐
                          ├─ F-05 ──┤
                          └─ F-06   │
                                    ↓
                        S-01 → S-02 → S-03 → S-04 → S-08 (feel check)
                                 │       └─ S-06 (needs owner step count)
                                 ├─ S-05
                                 ├─ S-07
                                 └─ ⏱ 14-day real-data log starts here,
                                      runs in parallel through Phase 5
                                    ↓
                        A-00 → A-01 → A-02 → A-03
                                 └─ A-04 → A-05 (needs owner audio budget)
                                    ↓
                        C-01 → C-02 → C-03 → C-04
                                    ↓
        P-01 → P-02 → P-03 → P-04 ─┬─ P-05
                                    ├─ P-06
                                    └─ P-07 (accessibility)
                                    ↓
                   V-01 → V-02 → V-03 → V-04 → V-05 → V-06
```

**Critical path:** F-01 → F-03 → F-04 → S-02 → S-03 → A-00 → A-01 → A-03 → C-01 → C-04 → P-03 → V-06.

Note what is no longer on the critical path: the fourteen-day real-data log. Starting it at S-02 instead of V-02 removes two idle weeks from the milestone's tail.

**No task is blocked on owner input.** S-06 is unblocked by `DECISIONS/0007`, A-05 by `DECISIONS/0005`, and F-01 by `DECISIONS/0009`. **P-01** has no code dependency and can begin at any time.

The one outstanding constraint is physical: iOS builds require macOS. See `MILESTONES/F-01_COMPLETION_REPORT.md`.

**S-08 is a checkpoint, not a formality.** A negative result there sends the design back before Phases 3–5 are built on top of it.

---

## Scope guard

The Milestone 01 content set is frozen at four locations, five skills, three enemies, six tabs plus one modal, zero currencies, zero merchants (`DECISIONS/0004`).

Any addition — a sixth skill, a fourth enemy, a shop, an expedition system, a combat skill, an inventory cap — requires a new decision record before it enters a task. This is the primary defence against risk R-05, and it applies to good ideas as much as bad ones. Good ideas go in `JOURNAL/`, where nothing is approved by default.
