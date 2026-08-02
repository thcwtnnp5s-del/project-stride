# Studio Initialization Report

**Project:** Project Stride
**Report version:** 1.0
**Date:** 2026-08-01
**Prepared by:** Studio Stride (Claude Code)
**Status:** Awaiting owner decisions — no production code written

---

## 1. Confirmed understanding

### 1.1 What Project Stride is

A mobile-first, solo, offline-first RPG for iOS in which real-world step count is the primary progression engine. Steps are spent on player-chosen activities (travel, gathering, expedition progress); those activities yield resources and skill XP; resources become crafted equipment and consumables; equipment and consumables enable active PvE encounters; encounters unlock further world and progression. The game is built for the owner and a small circle of friends, not for a market.

The emotional target, restated from `PROJECT_KERNEL/01_WHY.md`:

> I was already going to take that walk. Now it meant something.

### 1.2 Authority model I am operating under

1. Explicit owner instruction
2. `PROJECT_KERNEL/`
3. Approved decisions in `DECISIONS/`
4. `GAME_BIBLE/`
5. Current milestone
6. Individual task instructions

I will not silently resolve a Kernel-level conflict. Every conflict found below is escalated, not decided.

### 1.3 Current milestone

**Milestone 01 — First Adventure Vertical Slice.** Scope is fixed by `MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md`: four locations (Haven's Rest, Whispering Woods, Stonefall Mine, Forgotten Hollow), five skills, three enemies, seven screens, HealthKit ingestion, local save, audio and haptic hooks. Level cap 20. Explicitly excluded: multiplayer, trading, guilds, PvP, monetization, large world, live economy.

### 1.4 Hard constraints I will hold

- iOS only. No desktop, no Android in Milestone 01.
- Core gameplay works with no network connection at any point.
- No FOMO, no streaks, no expiring rewards, no decay, no energy gate on *access*.
- Audio and haptics are designed with each mechanic, not appended at the end.
- Content is data, not code.
- Nothing goes idea → code. Every feature passes design, critic, technical, and QA review first.

### 1.5 State of the repository

The repository is a complete pre-production package: 61 markdown documents covering identity, pillars, systems, world, combat, audio, UX, health integration, starter content, agent roles, workflows, and milestone sequencing. It contains **zero source code, zero content data files, and no version control**. That is the expected state at this point.

Documentation quality is high and internally consistent in tone and intent. The contradictions below are mostly *unresolved decisions presented as settled prose*, not authoring errors.

---

## 2. Contradictions

Ranked by how much downstream work they block.

### C-01 — "Idle RPG" vs. "walking is the progression engine" — **BLOCKING**

`PROJECT_KERNEL/00_PROJECT.md` and `PROJECT_STATE.md` call Stride a "solo **idle** RPG." `PROJECT_KERNEL/08_GLOSSARY.md` defines idle progression as "progress that occurs while the player is away." `PROJECT_KERNEL/13_INSPIRATION.md` asks to borrow Melvor Idle's "idle planning."

But `PROJECT_KERNEL/03_DESIGN_PILLARS.md` says movement "should unlock choices and progress," `12_DECISION_LOG.md` locks "all primary progression systems must meaningfully connect to real-world movement," and `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md` makes steps the input to travel, gathering, expeditions, and exploration.

These are two different games:

- **Step-clocked** (WalkScape model): an activity advances *only* as steps are earned. Sitting still yields nothing. Walking is genuinely the engine.
- **Time-clocked with a step multiplier** (Melvor model): an activity advances on wall-clock time; steps accelerate it. Walking is a bonus.

Every other system inherits from this: reconciliation, save format, activity math, balance, offline behavior, the meaning of "idle progression" in the glossary, and whether the phrase "idle RPG" belongs in the Kernel at all.

**Recommendation:** lock **step-clocked**. It is the only reading consistent with the locked decision "walking is core gameplay" and with the player promise. Time-clocked progression would make the walk optional, which contradicts the entire *why*. Retire the word "idle" from the Kernel and replace it with "movement-driven, offline-first." Keep the glossary's "idle progression" entry, but redefine it as: *progress resolved from steps that accrued while the app was closed.*

This is a Kernel change and requires owner approval.

### C-02 — Combat model is provisional and gates Phase 4 — **BLOCKING**

`12_DECISION_LOG.md` marks turn-based as **Provisional** and explicitly instructs review. `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md` offers "turn-based or time-sliced prototype." `CLAUDE.md` says "active solo PvE combat" and "mobile-friendly PvE combat." No document defines an encounter's length, action economy, or failure consequence.

Failure consequence is the sharpest edge: the Kernel forbids punishment for absence, but says nothing about punishment for *losing a fight*. A death penalty that destroys hours of walked progress would violate the player promise; a fight with no stakes makes preparation pointless.

**Recommendation:** turn-based, deterministic-with-seeded-variance, 6–12 turns per encounter, no real-time pressure (respects one-handed use and interruption), and a **retreat-not-death** model: losing costs consumables and time-to-return, never inventory, XP, or equipment. Needs a full `/design-review` before Phase 4.

### C-03 — No combat progression axis exists — **BLOCKING for Forgotten Hollow**

`GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md` marks combat ability/weapon mastery "provisional." `MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` lists five skills, none of them combat. `01_PROGRESSION_FRAMEWORK.md` promises "persistent character level, attributes."

So the vertical slice ships a mini-boss (Hollow Guardian) with no defined way for the player to get stronger except equipment and food. Either that is the intended design — which is defensible and elegant, "walking prepares the hero" — or a combat/character level is missing from the milestone scope.

**Recommendation:** Milestone 01 ships **character level only** (XP from encounters and skill milestones, feeding HP and a small attack/defence attribute), and **no combat skills**. This keeps the boss gated on preparation rather than grinding, which is exactly what `COMBAT_PHILOSOPHY.md` asks for, and defers weapon mastery to Milestone 02.

### C-04 — Traveler armor has no crafting skill

`GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` lists a "Traveler armor set" in starting equipment. Milestone 01's production skills are Smithing and Cooking only. `03_SKILL_SYSTEM_FRAMEWORK.md` also lists "General Crafting" — which Milestone 01 silently drops. Gathering skills produce logs, ore, and herbs; nothing produces leather or cloth.

**Recommendation:** Traveler armor is **starting gear only, not craftable** in Milestone 01. The craftable armor path is Smithing → Bronze. Do not add a sixth skill to the slice. Confirm that Milestone 01 has exactly five skills and that "General Crafting" is a Milestone 02 concern.

### C-05 — Tool bootstrap is circular

Gathering requires tools (Basic Axe, Basic Pickaxe). Tools are Smithing products. Smithing requires ore. Ore requires a pickaxe. Nothing in the documents states what the player starts with.

**Recommendation:** the player begins with Training Sword, Basic Axe, and Basic Pickaxe granted by the Haven's Rest onboarding. Bronze tier is the first *crafted* upgrade. This needs to be an explicit content decision, not an implementation assumption.

### C-06 — Merchants and currency are in the world but not in the milestone

`GAME_BIBLE/SYSTEMS/05_ECONOMY_AND_RESOURCE_MODEL.md` allows currency for NPC transactions. `CONTENT/01_STARTER_CONTENT_BIBLE.md` gives Haven's Rest "merchant or NPC services." Milestone 01's required screens include no shop, and starter content defines no currency, no prices, and no merchant inventory.

**Recommendation:** **no currency and no merchant in Milestone 01.** Every resource comes from movement; every item comes from crafting. A shop at this stage is an untested short-circuit around the loop the slice exists to validate. Defer to Milestone 02.

### C-07 — Screen count mismatch

`GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` defines six navigation destinations (Adventure, Character, Skills, Inventory, Craft, World). `MILESTONE_01_FIRST_ADVENTURE.md` requires seven screens, adding Combat.

**Recommendation:** six tabs; Combat is a full-screen modal presented from Adventure or World, dismissible only by resolving or retreating. Minor, but it should be written down before UX work starts.

### C-08 — Steps as a rate gate vs. the anti-feature "energy systems"

`06_ANTI_FEATURES.md` forbids "energy systems designed to restrict play." Steps are, mechanically, an energy currency. This is not a real violation — but the boundary is undocumented and easy to drift across.

**Recommendation:** adopt an explicit rule in the Kernel: *steps gate the rate of progress; steps never gate access.* Every screen, every crafting recipe the player has materials for, every fight the player is prepared for, is always available at zero steps. Nothing is ever "locked until you walk."

### C-09 — "Keep raw health history local **when possible**"

`GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md` hedges. For a game with no server, no accounts, and no cloud in scope, the hedge is unnecessary and creates room for a future mistake.

**Recommendation:** harden to a non-negotiable — *raw health data never leaves the device, in any milestone, without an explicit new owner decision.* The game persists only derived counters (ingested total, consumed total, sync anchor), never a step history.

---

## 3. Gaps

### G-01 — The slash commands are not installed as slash commands

`CLAUDE.md` advertises `/studio-init`, `/spawn-agents`, `/design-review`, `/execute-phase`, `/critic-loop`, `/qa-check`, `/milestone-report`. The definitions live in `COMMANDS/*.md`. Claude Code only registers slash commands from `.claude/commands/`. As shipped, typing `/studio-init` does nothing.

**Fix:** create `.claude/commands/` containing those seven files. Trivial, and it makes the documented workflow real.

### G-02 — The agent roles are not installed as subagents

`AGENTS/*.md` are role charters written as prose. Claude Code subagents require `.claude/agents/*.md` with YAML frontmatter (`name`, `description`, `tools`, optional `model`). Today the ten roles are documentation, not executable agents.

**Fix:** generate `.claude/agents/` definitions from the existing charters, preserving each role's mission, responsibilities, the five required review questions, and the required output format. This is what `/spawn-agents` should actually do.

### G-03 — No version control

The project root is not a git repository. A design corpus this dense, about to receive an Xcode project, has no history and no undo.

**Fix:** `git init`, a Swift/Xcode `.gitignore`, and an initial commit before any code exists. This should be the first physical action taken.

### G-04 — No visual direction document

`GAME_BIBLE/` has a full audio identity document and a mobile UX document, but no art, visual, or presentation direction. `01_MOBILE_EXPERIENCE.md` asks for "calm, atmospheric presentation" with no definition of what that looks like. Given "audio is gameplay" is a pillar and the game will be judged on feel, the visual half is unspecified.

**Fix:** add `GAME_BIBLE/ART/01_VISUAL_IDENTITY.md` covering palette, typography, iconography, illustration approach, motion language, and — critically — the **asset sourcing plan** for a team with no artist.

### G-05 — No audio asset sourcing or licensing plan

Audio is a first-class system with region beds, weather variation, per-material gathering sounds, and combat feedback. Nothing addresses where those files come from, their licences, format, memory budget, or mixing architecture. `REFERENCES/README.md` correctly forbids copying assets from other games, which closes the easy path without opening another.

**Fix:** a decision record naming licensed sources (e.g. commercially-licensed libraries), a per-material sound matrix for the Milestone 01 content set, and a memory/format budget. Needed before Phase 5, ideally before Phase 3 so gathering is built with real hooks.

### G-06 — No numbers anywhere

There is no XP curve, no steps-per-log, no steps-per-kilometre-of-travel, no encounter length, no damage values, no gathering yield, no level-20 target pacing. The design is entirely qualitative. `02_WALKING_INTEGRATION.md` says rates "must be balanced through testing rather than assumed," which is right — but the slice cannot be built without a first-pass number set to test against.

**Fix:** a `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md` anchored on one owner-supplied figure: **typical daily step count**. Everything else derives from it. My working proposal, to be reviewed: a 6,000-step day should produce roughly 25–40 minutes of meaningful decisions and visible progress, and level 20 in a single skill should take on the order of 4–6 weeks of ordinary walking.

### G-07 — No acceptance criteria or test strategy

`MILESTONE_01_FIRST_ADVENTURE.md` ends with a narrative success test. `/qa-check` lists evaluation categories. Neither is testable. There is no definition of what "step accounting is correct" means as a pass/fail assertion.

**Fix:** the task breakdown must carry per-task acceptance criteria, plus a dedicated step-reconciliation test suite specification (see §4.5).

### G-08 — Step authenticity has no stated position

Nothing addresses manually-entered Health data, shaken phones, treadmills, or step imports. `HEALTH_INTEGRATION` proposes a "manual test provider" and an "import provider" without saying how they interact with legitimacy.

**Recommendation:** for a solo game with no leaderboards, cheating is the player's own business — but the *default* should reflect real movement. Filter `HKMetadataKeyWasUserEntered` samples out by default with a visible setting to include them; keep the developer/test provider behind a debug build flag that never ships. Revisit if Milestone 04 adds friend comparison.

### G-09 — No privacy policy artifact

Any App Store app requesting HealthKit read access requires a privacy policy, and the App Privacy questionnaire must declare health data usage. Even for TestFlight distribution to friends, review applies.

**Fix:** a short privacy policy and in-app permission-rationale copy, drafted during Phase 2, not at submission time.

### G-10 — Undefined terms carried into implementation

"Adventure Momentum" is defined in the glossary as a working term with implementation "subject to design review," and then never used again in any document. "Profession" is defined and never used. "Expedition" appears in the loop and the glossary but has no system definition — it is unclear whether it is distinct from travel or gathering.

**Fix:** either give **Expedition** a system definition or strike it from Milestone 01 (I recommend striking it — travel and gathering cover the slice). Mark "Adventure Momentum" and "Profession" explicitly as Milestone 02+ vocabulary so they do not leak into code as half-implemented concepts.

---

## 4. Recommended technology stack

### 4.1 Recommendation

> **Native iOS — Swift 6 + SwiftUI, iOS 17 minimum, with the entire game simulation in a pure-Swift package containing no Apple framework dependencies.**

Supporting choices:

| Concern | Choice |
|---|---|
| UI | SwiftUI, `@Observable` view models |
| Game core | `StrideCore` — a local Swift package, pure logic, deterministic, no I/O, no UIKit, no HealthKit |
| Content | JSON files, versioned schemas, decoded into `StrideCore` value types at launch |
| Persistence | Versioned `Codable` snapshot written atomically, plus an append-only step ledger; SQLite via GRDB is the documented escalation path if the save outgrows a snapshot |
| Health | HealthKit directly, behind a `StepProvider` protocol with HealthKit, Manual, and Simulated implementations |
| Audio | AVAudioEngine, with a small event-driven `AudioDirector` layer so systems emit semantic events, never file names |
| Haptics | Core Haptics, paired to the same semantic events as audio |
| Tests | Swift Testing for `StrideCore`, XCTest for integration, snapshot tests for save migration |

### 4.2 Why native

- **HealthKit is the project's spine, and it is a native API.** Anchored queries, deletion handling, background delivery, and the locked-device read restriction are exactly the details that cross-platform wrappers abstract badly and document poorly. The single hardest correctness requirement in the project — never double-count, never lose legitimate steps — should sit on the API directly, not two layers away.
- **Core Haptics and AVAudioEngine are first-class here.** A pillar states audio and haptics *are* gameplay. Native gives full control over mixing, ducking, ambience crossfades, and haptic pattern authoring.
- **The game is not a renderer.** Stride is a data-driven journal app with an encounter view. There is no 3D scene, no physics, no sprite-heavy real-time loop. A game engine would add a runtime, a build pipeline, and a whole asset workflow to draw list views and progress bars.
- **Battery and background behavior** are constraints (`QUALITY_STANDARDS.md`), and native gives the clearest picture of what the app is doing when backgrounded.
- **Testability of the thing that matters.** Putting the simulation in a dependency-free Swift package means step reconciliation, XP, crafting, and combat are all testable in milliseconds with no simulator, no HealthKit, and no UI.

### 4.3 Alternatives considered

**React Native / Expo** — Fast UI iteration, one language across the app, large ecosystem. Rejected: HealthKit access depends on community bridges whose coverage of anchored queries, deletions, and background delivery is uneven; audio and haptics of the required fidelity need native modules anyway; you end up maintaining Swift *and* TypeScript, which is worse than maintaining Swift.

**Flutter** — Excellent UI control and performance, genuine cross-platform path to Health Connect later. Rejected for the same HealthKit-fidelity reason, plus Dart's audio story on iOS is a step down from AVAudioEngine. This is the strongest runner-up if Android becomes a near-term requirement rather than a "may be considered later."

**Kotlin Multiplatform (shared core + SwiftUI shell)** — Architecturally the most honest answer to "iOS now, Android maybe later": the simulation would be genuinely portable while each platform keeps native health, audio, and haptics. Rejected for Milestone 01 on cost — it adds a second toolchain, a second language, and interop friction to a solo project that has not yet validated its core loop. Worth revisiting *only if* Android is promoted from "maybe" to "planned."

**Unity / Godot** — Rejected. Both bring a heavy runtime, larger binaries, worse battery characteristics, and awkward HealthKit integration in exchange for rendering capability this game does not use. Godot's mobile export and Unity's licensing history are additional risk with no offsetting benefit.

### 4.4 The Android tradeoff, stated plainly

Native iOS defers Android cost rather than eliminating it. If Android is ever built, the UI, persistence, audio, and health layers are rewritten; only the design and content data carry over directly. The mitigation — keeping `StrideCore` pure, deterministic, and framework-free, with all content in JSON — means a future port re-implements a known, specified, fully-tested simulation rather than reverse-engineering one out of view controllers. That is the correct trade for a project whose Kernel says "mobile only, initial platform iOS" and whose audience is the owner and friends.

### 4.5 Step reconciliation model (the load-bearing design)

This is the one system where a subtle bug silently destroys trust in the whole game, so it gets specified here rather than deferred.

- Use `HKAnchoredObjectQuery` on `HKQuantityTypeIdentifier.stepCount`. Persist the returned anchor.
- Maintain two monotonic counters in the save: `stepsIngested` (everything ever read from the provider) and `stepsConsumed` (everything ever spent on activities). Available steps = the difference. Both only ever increase.
- **No day boundaries. No timezone logic.** Steps are a ledger, not a daily budget. This removes an entire class of bugs — travel, DST, midnight, and retroactive Health writes all become non-events.
- Process `deletedObjects` from the anchored query. If a correction reduces the ingested total below what has been consumed, **never claw back granted progress** — record the discrepancy, cap the debt, and absorb it against future ingestion. The player must never see progress disappear. This directly serves "no punishment."
- HealthKit reads fail while the device is locked (health data is encrypted at rest). Background delivery is therefore best-effort; **foreground launch backfill is the source of truth**. The app must reconcile fully and correctly on cold launch after any period of absence, with no network.
- Every ingestion writes an entry to the append-only ledger before any gameplay consumes it, so a crash mid-reconciliation cannot double-count on replay.
- The `StepProvider` protocol lets the entire model be tested deterministically — delayed syncs, out-of-order samples, deletions, week-long absences, clock changes — with zero HealthKit involvement.

### 4.6 What I need from the owner to finalize

Xcode version and target device set (this pins the iOS minimum), and confirmation that distribution is TestFlight to friends rather than public App Store release.

---

## 5. Risk register

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R-01 | Step reconciliation bug silently corrupts progress | Critical | Ledger model, deterministic test provider, no-clawback rule, test suite written before the feature |
| R-02 | C-01 stays unresolved and is decided implicitly in code | Critical | Blocking owner decision before any architecture work |
| R-03 | Balance is unknowable without real walking data | High | Ship a debug step injector and a rate-tuning config; treat first numbers as provisional |
| R-04 | Audio is deferred despite being a pillar | High | Semantic audio events emitted from Phase 3 onward, even with placeholder sounds |
| R-05 | Content scope creeps past four locations / five skills / three enemies | High | Milestone 01 content set is frozen; additions require a decision record |
| R-06 | Overengineering the architecture before the loop is validated | High | Snapshot save, no cloud, no DI framework, no premature abstraction |
| R-07 | HealthKit permission denied or revoked mid-play | Medium | Manual entry fallback, graceful degraded mode, clear re-request path |
| R-08 | Health-data privacy mistake | Medium | Hardened local-only rule (C-09), no analytics, no third-party SDKs in Milestone 01 |
| R-09 | Solo project loses momentum in documentation | Medium | Task breakdown with small, independently-shippable, testable tasks |
| R-10 | No artist, no visual identity | Medium | G-04 visual direction document with an explicit sourcing plan |

---

## 6. Recommended next step

### 6.1 The single next action

**Owner resolves the five blocking decisions and approves the stack.** Nothing else in Milestone 01 can be correctly specified until then, and every one of them is Kernel-adjacent, which means they are the owner's to make and not mine.

1. **C-01 — Progression clock.** Step-clocked, or time-clocked with a step multiplier? *(I recommend step-clocked; it requires a Kernel edit retiring the word "idle.")*
2. **Stack.** Native Swift + SwiftUI as specified in §4? *(I recommend yes.)*
3. **C-02 — Combat model and loss consequence.** Turn-based with retreat-not-death? *(I recommend yes; full design review follows.)*
4. **C-03 — Combat progression.** Character level only, no combat skills in the slice? *(I recommend yes.)*
5. **C-06 — Currency and merchants.** Excluded from Milestone 01? *(I recommend excluded.)*

Alongside those, the smaller content confirmations: C-04 (Traveler armor not craftable), C-05 (starting tool grant), C-07 (six tabs, Combat as modal), G-10 (strike "Expedition" from the slice), and one number — **your typical daily step count** — which anchors all of G-06.

### 6.2 What I do the moment those are answered

In order, still without production code:

1. `git init`, `.gitignore`, initial commit of the current corpus.
2. Install `.claude/commands/` and `.claude/agents/` so the documented workflow is executable (G-01, G-02).
3. Write `DECISIONS/0001_TECHNOLOGY_STACK.md` and `DECISIONS/0002_PROGRESSION_CLOCK.md` using the existing decision template.
4. Write `ARCHITECTURE_IMPLEMENTATION_PLAN.md` against every section required by `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_TEMPLATE.md`.
5. Write `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`, replacing the template, with per-task ID, owner agent, dependencies, acceptance criteria, and tests.
6. Run `/spawn-agents`, then `/design-review` on both documents, then `/critic-loop`.
7. Stop and wait for owner approval.

### 6.3 The first implementation task, once approved

For the record, so the shape of Phase 1 is visible now:

> **F-01 — Foundation skeleton.** Xcode project, `StrideCore` pure-Swift package, `StepProvider` protocol with a simulated implementation, save v1 with an atomic write and a migration hook, and a deterministic test harness proving a week of simulated walking reconciles exactly once. **No gameplay, no UI beyond a debug screen.**

That task exists to make the riskiest thing in the project (R-01) testable before a single feature depends on it.

---

## 7. Confirmation

No production code has been written. No design decision has been made unilaterally. Every contradiction found is escalated above rather than resolved in place.

Ten studio roles are defined and ready to be instantiated on `/spawn-agents`; the Critic Agent will review their initialization summaries per `COMMANDS/spawn-agents.md`.

Awaiting owner input on §6.1.
