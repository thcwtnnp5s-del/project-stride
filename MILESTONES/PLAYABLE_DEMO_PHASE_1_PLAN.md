# Playable Demo Phase 1 — Implementation Plan

```
STATUS: IMPLEMENTATION PLAN · NOT CANON
Synthesized from four read-only audits at Stop Gate 1, 2026-08-16.
```

**Goal.** The smallest truthful gameplay loop, through the **product UI** rather than
the dev harness:

> launch → load save → sync steps → see banked steps → gather Meadow Herb →
> spend 90 → receive ×2 herb and +10 Foraging XP → UI updates → close → reopen →
> state correct → duplicate sync does not double-grant.

**Blockers found: none.** Two application-layer gaps were found and are already closed
(`edc4cfe`). Everything else is UI work against seams that already exist.

---

## 1. What the audits changed about the plan

Five corrections, each found by **measuring rather than reasoning**. Four of them
contradict a document this project wrote, including one of my own.

### 1.1 Skill level derivation exists — Slice 4 was never blocked on F-07

`FLUTTER_TRANSLATION_PLAN_01.md` §4 states "Nothing derives level from XP" and makes the
Character screen depend on F-07. **That is wrong.**
`SkillDefinition.levelAt(int experience)` is at
`packages/stride_core/lib/src/content/definitions.dart:149`, it is what
`GameEngine._gather` gates on (`game_engine.dart:420`), and it is covered by
`packages/stride_core/test/gather_resource_test.dart:258`.

A widget calling `registry.skills[id]!.levelAt(xp)` is **reading a domain function**, not
computing a rule. Phase 1 can show `Level 8` honestly.

The earlier claim came from a truncated grep that never displayed line 149. Corrected
here so the false dependency does not propagate.

**Still absent:** *XP into the current level* (the `220 / 720` span), which needs
`xpThresholds[level-1]` and `xpThresholds[level]`. Indexing the curve in a widget **is**
rule math. Phase 1 shows level and total XP, no bar. See §6.

### 1.2 "Walked today" has no data source and must not ship

The approved Adventure render's hero figure is `3,240 walked today`. `StepLedger` exposes
`totalObserved`, `totalGranted`, `totalSpent`, `banked`, and
`Map<ObservationKey, int> grantedSlices`. `TimeBucket` is a **UTC hour-granularity** span
(`sync_batch.dart:20`).

Deriving "today" requires choosing a local-day boundary and folding the slice map — a
**timezone policy and a game rule, invented in a widget**. It would disagree with itself
across a DST boundary and across travel, and it would look plausible in review.

**Phase 1 substitutes `TOTAL WALKED` = `totalGranted`.** Real, honestly labelled, same
class of fact. Recorded as **Q-UI-9**.

### 1.3 `ActionReport` dropped the XP it was handed — fixed

`ResourceGathered` carries `skill` and `experience`; the report did not. Every workaround
was wrong: `ResourceNodeDefinition.xp` is the **unscaled base** value while the engine
awards `profile.applyXp(xp)`, and diffing `SkillProgress` across the await is E-2 directly.
Closed in `edc4cfe`; verified end to end (`skill=Foraging xp=10`).

This supersedes Agent B's §6 fallback of reading `node.xp` for the success strip.
`GatherResultStrip` reads `report.experience` and `report.skillName`.

### 1.4 Single-flight belonged in the session — fixed

Every `_stale` gate is checked before the first `await` and never rechecked. The guarantee
lived in the dev harness's private `_busy` flag. Two overlapping commits compute against
one `_generation`; the loser is refused by CAS and sets `_stale` — **a real fault
manufactured by a double tap**. And call B could pass the `_stale` gate before call A's
failure set it. Closed in `edc4cfe`.

### 1.5 Two asset sizes in `UI_SYSTEM_PROPOSED_01.md` §5 are wrong

Measured from the PNG headers: **skill icons are 12 × 12 → 24**, not 14 × 14 → 28. The
portrait is 48 × 48 but lives in `WALKSCAPE_CHARACTER_EXPLORATION_01/out/`, not the
28 × 36 `portrait_placeholder_r01.png` sitting in the exploration assets directory.
Nav 14 × 14, glyphs 12 × 12, items 20 × 20, activity 40 × 40 all confirmed.

### 1.6 One empirical unknown, resolved by probe

Agent D could not determine whether a test can reach `isStale`. **It can**, through the
public API: session A commits, session B (opened against the committed head, so it has
energy) then commits against a stale expectation →
`rejection='commit_refused'`, `detail='conflictRetryLimitExhausted'`, `isStale=true`.

The obvious variant does **not** work: opening B before A commits leaves B with zero
banked, so it refuses on affordability long before reaching a commit. **No new test seam
is needed** — which matters, because `StrideSession` has a private constructor and is
`final`, so it cannot be faked.

---

## 2. Rulings on the questions the audits escalated

| Question | Ruling |
|---|---|
| Should the UI-boundary guard cover concrete command types (`GatherResource`, `ReconcileStepSync`)? | **Yes.** The UI must never construct a command. But the guard scans `lib/ui/` only. |
| What happens to `dev_harness.dart`? | **Moved to `lib/debug/`.** It legitimately needs `engine`, `runtime` and `health`; an allow-list hole inside the guard would grow. A separate directory makes the guard's scope statement true rather than caveated, and is honest about what the harness is. |
| Tokens: `ThemeExtension` or const classes? | **Const classes**, overriding my own earlier proposal. `lerp` is mandatory boilerplate for a transition the system forbids; every read becomes `Theme.of(context).extension<T>()!`; nothing can be `const`. The plan's stated reason for the extension — "a constant is reachable from `stride_core`" — is false: `stride_core` is a separate package and `check-core-purity.sh` already enforces it. |
| Navigation: hide non-working tabs, or disable them? | **Show all six, three visibly disabled.** Hiding produces the belief "Stride is a three-section app" — false, stated by the most load-bearing chrome on screen, and uncontradicted anywhere in the demo. Disabling produces "six sections, three unbuilt" — true. It also exercises the six-tab geometry, including its 320 dp touch-target risk, instead of deferring it. |
| Does Phase 1 need a `MILESTONES/` document? | **Yes — this file.** `PROJECT_STATE.md` still records the player-facing milestone as undefined; acceptance criteria against an unrecorded phase are not bindable (G-3, G-6). |
| State management package? | **No.** `ChangeNotifier` + `InheritedNotifier` + `ListenableBuilder` are all in `package:flutter`. Zero new dependencies. |

---

## 3. Architecture

```
lib/
  main.dart              one line changes: runApp(StrideApp(session: session))
                         the await-before-first-frame above it is untouched
  runtime/               unchanged
  debug/
    dev_harness.dart     MOVED from lib/ui/. Reachable in debug only.
  ui/
    theme/               stride_colors · stride_typography · stride_metrics · stride_theme
    icons/pixel_icons.dart   the ONLY place an asset path string appears
    components/          pixel_asset · walking_glyph · stride_scaffold · screen_header
                         banked_steps_readout · stride_tab_bar · section_card
                         surface_block · inset_well · labeled_value_tile · skill_chip
                         requirement_gate · stride_button · section_heading
    state/               session_controller · session_scope · gather_action_state
    shell/               stride_destination · stride_shell
    screens/
      adventure/         adventure_screen · steps_budget_card · gather_node_card
                         action_cost_summary · gather_button · gather_result_strip
      inventory/         inventory_screen · item_grid · item_tile
      character/         character_screen · character_identity_card · skill_xp_row
      system/            blocked_screen · stale_banner   (undesigned, deliberately plain)
assets/ui/v1/            24 pixel PNGs, declared file by file
Scripts/check-ui-boundary.sh
test/ui/
```

### Startup — the loading state is unrepresentable, not merely avoided

`SessionController`'s constructor **requires an already-started `StrideSession`**. There is
no `isLoading` field to forget, no `FutureBuilder`, no null session, no default
`GameState`. A flash of zeros cannot be expressed.

`FutureBuilder` is specifically forbidden: it renders before resolution, and a future
constructed in `build` re-runs `StrideSession.start` — a second bootstrap over the same
directory in the same isolate. A Flutter splash route has the same defect in different
clothing. A **native** launch screen is safe, because the OS draws it before `main`.

### `PixelAsset` — the one enforcement point for L-18

Takes a **native size and an integer scale**. It does not take a width, so a fractional
display size is *unrepresentable* rather than discouraged — the same technique as
`StrideProgressTrack` refusing a fill fraction.

Flutter's version of the Round 03 clip is **worse than CSS's**, and this is the single
most important implementation note in the plan: `Container` with a border adds the border
to the child's box (not `border-box`), and when a parent hands down a smaller bounded
constraint, `SizedBox` **honours the parent** — it reports the smaller size and
`BoxFit.fill` squashes the sprite to 4.7× instead of 5×. **No overflow stripe, no warning,
nothing to point at.** So `PixelAsset` wraps its child in a private render object whose
`performLayout` carries a debug assert that throws, naming the widget and both sizes, the
moment its constraints are smaller than its declared size.

Fixed settings: `FilterQuality.none`, `isAntiAlias: false`, `BoxFit.fill`,
`gaplessPlayback`. **`cacheWidth`/`cacheHeight` stay null** — they resample at decode,
permanently, before `filterQuality` is consulted. **No `2.0x/` variant directories** —
`AssetImage` would resolve by DPR and change the intrinsic size out from under the
explicit width. `InsetWell` sizes **outer = content + 2** so the border never eats the
sprite.

Fractional DPR is **accepted, not corrected**. At DPR 2.625 a 40 dp sprite covers 20
source pixels at 5.25 device px each, so some source pixels get 5 and some get 6. That is
*uneven, not blurry*, and unavoidable in a resolution-independent framework. Snapping
logical size to device-pixel integers would give a different logical size per device and
break every layout the renders locked.

### Two translation traps that would be silently wrong

- **`height` in Flutter is a multiplier, not pixels.** `height: 13` on an 11 px style
  gives a 143 px line box. Every role is written as the ratio (`13 / 11`) so the source
  numbers stay checkable against the spec.
- **`letterSpacing` is logical pixels, not em.** `+.085em` on 11 px is `0.935`, not
  `0.085`.

A widget test asserting the rendered line height of `microLabel` is cheap insurance.

---

## 4. Data / UI boundary

Widgets read `StrideSession` and `ContentRegistry` and call `StrideSession` methods. They
do not construct commands, engines, repositories, or storage. **A widget may format a
number; it may not decide one.** No literal progression value appears in any production
widget. No content id is hardcoded — the Adventure screen drives off
`registry.locations[currentLocation].resourceNodes`, so `kHarnessNode` stays in the
harness where it belongs.

`Scripts/check-ui-boundary.sh` — one guard, `GUARD_ID="ui-boundary"`, following the
`rulekit.sh` contract (exit 0/1/2, `STRIDE_GUARD[id.rule]` diagnostics, side-effect-free
above `guard_main`, mandatory `rule_preflight` reporting **infra** on an empty scan).

Rules:

| Rule | Forbids in `lib/ui/` |
|---|---|
| `no_storage_imports` | `package:stride_storage/`, `package:stride_core/src/`, `package:path_provider/`, `package:stride_secure_store/` |
| `no_engine_symbols` | `GameEngine`, `GameCommand`, `SaveRepository`, and the concrete command types |
| `no_session_internals` | `.engine`, `.runtime`, `.health`, `healthKeyingSalt`, `saltFingerprint` |
| `no_invented_time` | `grantedSlices`, `DateTime.now`, `.toLocal(` — closes risk 1 in §7 |
| `single_image_site` | `Image.asset` outside `pixel_asset.dart` |

**Comment stripping is mandatory.** Without it the guard fails on its own documentation:
`dev_harness.dart` names `GameEngine` and `GameCommand` in the doc comment that *states
the E-2 rule*. A guard that cannot tell code from prose makes the rule unwritable, and
this repository has already made that mistake twice. Register a
`uib_comment_false_positive` self-test case so the stripping is proven, not intended.

**`dart:io` is not blanket-forbidden** — `dart:io show Platform` is legitimate. Forbid the
symbols `Directory(`, `File(`, `RandomAccessFile` instead. `package:stride_core/stride_core.dart`
is **required**, not forbidden: `ContentId`, `ResourceNodeDefinition` and the outcome
types all come through it.

Registration in four places or the tree goes red: `check-source-safety.sh`
(`SOURCE_SAFE_GUARDS`), `Scripts/lib/cases.sh` (`reg_guard` + one `reg_case`/`mut_*` per
injection), `Scripts/verify.sh`, `.github/workflows/ci.yml`.

---

## 5. What Phase 1 does NOT build, and why each cut is safe

| Cut | Reason |
|---|---|
| **`StrideProgressTrack`** | **The most important cut.** Phase 1 has *nothing legitimate to fill it with* — no partial gather progress (owner ruling), no XP-into-level span without rule math. Shipping it with no honest caller is a standing invitation to fabricate a fraction, which is exactly the Round 02 defect where four of five bars contradicted their captions. **A widget that does not exist cannot be given a fake number.** |
| `54 / 90`, `Stop`, `Change activity` | No persistent activity state exists. Owner ruling. |
| `RECENT GAINS` | Names a retained system (Q-UI-7) that does not exist. Replaced by `GatherResultStrip`, explicitly ephemeral — different name because it is a different thing. |
| `FilterPillBar` | Five item kinds. The pills also assert quest and consumable systems with no items, and cutting them removes the 24.5 pt touch-target defect for free. |
| `EquipmentSlotTile` / the `EQUIPPED` card | `EventReducer._started` adds the loadout to **inventory only** — nothing is equipped on a new game, and Phase 1 has no equip affordance. Three permanently empty boxes. Also removes the portrait-duplication regression. |
| `item_bronze_axe`, `item_tin_ore` and the rest of the icon set | Phase 1's grid holds only what the player can hold: the four loadout items plus Meadow Herb. The unresolved icons are not in scope, so they block nothing. |

`PortraitWell` **is** built, with `portrait_traveler.png` marked `TEMPORARY` in code and in
the asset manifest. No portrait *work* is planned. The frame is a component, the image is
an asset, and they swap independently.

---

## 6. Screens

**Adventure.** Header (`HAVEN'S REST` / `Adventure` / `BankedStepsReadout`). `StaleBanner`
when stale. `StepsBudgetCard` — `TOTAL WALKED` = `totalGranted`, `SPENT` = `totalSpent`,
and the sentence *"Banked steps cover N more gathers"* which is the fix for the audit's
M-4 (the approved render states the relationship between the header figure and the cost
nowhere). `GatherNodeCard` per node at this location — illustration in an `InsetWell`,
skill chip, title, requirement gates from `ResourceNodeDefinition`, the
`STEPS 90 → YIELD ×2 → EXPERIENCE +10` triple, an `AVAILABLE` row, the gather button, and
the ephemeral result strip. `SkillXpRow` for the trained skill.

**Inventory.** Grid of everything in `state.inventory.counts` (a `SplayTreeMap`, so
iteration order is stable across runs and platforms; zero-quantity keys cannot exist).
Icon + label + count. Fluid 4 columns.

**Character.** Portrait, character level, `TOTAL WALKED` / `TOTAL SKILL XP`, and one
`SkillXpRow` per skill showing name in hue, `Level N` via `levelAt`, and total XP. **No
bar.**

### The gather state machine

`GatherUnavailable · GatherInsufficientSteps · GatherReady · GatherExecuting ·
GatherSucceeded · GatherRefused`.

**Computed on demand in `SessionController`, never stored.** A stored state machine is a
second source of truth that can disagree with the session; a computed one cannot.

Re-entrancy is prevented **in the controller and in the session**, not by the disabled
button: a disabled `onPressed` only takes effect on the next rebuild, and two taps inside
one frame both dispatch before `notifyListeners()` runs.

`canGather()` **disables**; it never decides. It checks affordability and readiness only —
not location, skill level, or tool. The engine re-validates all five and its answer is
authoritative, so a refusal that arrives anyway renders as `GatherRefused` rather than
being swallowed.

The success strip clears on a 5 s timer, on the next gather, and on tab change.
**Auto-clearing is load-bearing**: a success line that persists is indistinguishable from
the durable "recent gains" system the owner ruled out.

### Refresh

`await` the session call → `notifyListeners()` → dependents rebuild → they re-read the
getters, which are now post-commit. **No cache, no copy, no optimistic rendering across
the await** — the engine applies before the commit resolves, so a widget that increments
a count before awaiting renders exactly the "herbs that vanish on the next launch" the
session's own comment names.

---

## 7. Ranked risks

1. **Someone implements "walked today" anyway.** It is the most prominent number on the
   approved render. An implementer will find `grantedSlices` and write a `DateTime.now()`
   fold. Invisible in review because the number looks plausible. → guard rule
   `no_invented_time`, and `TOTAL WALKED` specified up front so there is a right answer to
   reach for.
2. **Pixel crispness degrades and nobody can name why.** Flutter shrinks silently where
   CSS clipped. → the `PixelAsset` debug assert, and `Image.asset` confined to one file.
3. **9.5 px type in a six-tab bar at 320 dp under text scaling.** → the `textScaler` clamp
   is scoped to **tab labels only**, taken deliberately and recorded as an accessibility
   cost; every content surface keeps free scaling. Labels clip rather than ellipsize — a
   clipped label is information, an ellipsis is a lie about a string that was never too
   long by design.
4. **Scope creep back toward the render.** The renders are persuasive and show five
   systems that do not exist. → §5.
5. **Timer/notifier lifetime.** → cancelled in `dispose` and in `_clearResult`;
   `gather()`'s `finally` is unconditional.
6. **`isStale` is exercised for the first time by a player.** Undesigned by decision
   (Q-UI-8), not oversight. → prominent banner with a working Reload; harness reachable in
   debug.
7. **Parity review becomes a pixel hunt** (M-01). → only "this reads as a different
   application" blocks; everything else is a finding with a severity.
8. **`item_unknown` accidentally becomes semantic.** → flat slab, two colours, no interior
   mark, no aperture, no frame ring. It should look unfinished, because it is.

---

## 8. Tests — twelve, not fifty

**Nine of the fifteen "required" cases are already proven** at session level, on hardware,
or by existing guards. Re-asserting them through a widget is the M-01 pattern under a new
name. `test/s01a_vertical_slice_test.dart` already covers the literal 90/2/10 figures
across a relaunch, duplicate sync, insufficient-energy refusal, and exact-cost spend;
`integration_test/restart_test.dart` and the process-death harness cover persistence.

New surface only:

- **State-origin family** — every render assertion runs against **two different known
  states in one test**. A single-value assertion is satisfiable by a hardcoded literal,
  which is the defect class being tested for. (banked 613/1041, herbs 2/4, XP 10/20.)
- **First-frame** — assert *without* `pumpAndSettle`, or the test cannot fail.
- **Refresh** — assert against **rendered text**, not the session, or it cannot fail.
- **Exactly-at-cost boundary (90 vs 89)** — untested at any layer today; `canGather` uses
  `<=` and nothing proves it.
- **Double-tap spends once.**
- **Stale refusal** — the real gap: `isStale` is exercised by nothing in the repository.
  Constructed by the two-session route proven in §1.6.
- **Overflow** at 320 / 360 / 375 / 393 / 430, plus 320 at 1.3× text scale.

Injection: `StrideSession.start(overrideRoot: tempDir, source: MockStepSource(...))`.
Passing a non-null `source` short-circuits `PlatformStepSource.open()`, so **no platform
channel is touched**. The real filesystem **is** used, and must be —
`check-single-writer.sh` approves exactly six construction sites and an in-memory store
would need a seventh. Boot inside `tester.runAsync`; real file I/O never completes under
`FakeAsync`.

---

## 9. Slices

1. **Canon + tokens + shell** — theme, `PixelAsset`, `StrideScaffold`, `ScreenHeader`,
   `BankedStepsReadout` (real data from the first slice), `StrideTabBar`, assets, guard,
   harness moved to `lib/debug/`.
2. **Adventure / gather** — the loop.
3. **Inventory + Character.**
4. **Tests, Visual QA, one correction pass.**

Commit at each boundary. Push after verification.
