# Playable Demo Phase 1 — physical device acceptance result

```
STATUS: PASS — SIGNED AND CLOSED
Run on a physical iPhone, 2026-08-16
```

The ACTUAL column below was written by the owner, who ran the script. **The
verdict line is deliberately left unsigned** — `MISTAKES.md` M-04 requires it to
be written by someone who did not build the feature, and I built it. See §6.

---

## 1. Run record

| | |
|---|---|
| Commit | **`eae7700`** |
| Branch | `playable-demo-phase-1` |
| iPhone | iPhone 10 |
| iOS | 26.6 |
| Xcode | 26.6 (17F113) |
| Flutter | **3.47.0 / Dart 3.13.0** — CI pins 3.44.8. Run variable, see §4 |
| Build mode | **profile** — see §4 |
| Signing | Personal Team `TSUZN7Q8CL`, bundle `com.projectstride.stride` |
| Run by | owner |

## 2. The twenty criteria

| # | Criterion | Result |
|---|---|---|
| 1 | No first-frame zero/empty-state flash | **PASS** |
| 2 | Correct existing save loads | **PASS** |
| 3 | Current step balance correct | **PASS** |
| 4 | Foreground health sync works | **PASS** |
| 5 | Newly granted steps correct | **PASS** |
| 6 | Adventure screen renders | **PASS** |
| 7 | Haven's Rest vignette renders | **PASS** |
| 8 | Gather Meadow Herb succeeds | **PASS** |
| 9 | Exactly 90 steps spent | **PASS** |
| 10 | Exactly 2 Meadow Herb granted | **PASS** |
| 11 | Exactly +10 Foraging XP granted | **PASS** |
| 12 | Gather animation plays cleanly on-device | **PASS** — observed directly, not frame-scrubbed |
| 13 | Result feedback appears | **PASS** |
| 14 | Inventory reflects new herb count | **PASS** |
| 15 | Character/progression truthful | **PASS** |
| 16 | World screen and region map render | **PASS** |
| 17 | Close and relaunch | **PASS** |
| 18 | State persists | **PASS** |
| 19 | Sync again without new health data | **PASS** |
| 20 | No duplicate grant | **PASS** |

## 3. Recorded values

### Baseline — cold launch, before any sync

```
banked         407,976
TOTAL WALKED   408,066
SPENT               90
Meadow Herb         ×2
Foraging XP         10   (level 1)
```

**Independently corroborated.** `S01A_PHYSICAL_VALIDATION.md` records 961 steps
granted against a preserved 407,105. 407,105 + 961 = **408,066**, matching
`TOTAL WALKED` exactly, and `SPENT 90 / ×2 herb / 10 XP` is precisely one
gather. This is the S-01A save matched to the step against an independent
record — not merely state that resembled old data.

### Sync 1 — backlog drain

```
result line    "+47,395 steps banked"
faults         absent
granted        47,395

banked         455,371   == 407,976 + 47,395   EXACT
TOTAL WALKED   455,461   == 408,066 + 47,395   EXACT
SPENT               90   unchanged             EXACT
```

### Gather

```
banked         455,281   == 455,371 - 90       EXACT
TOTAL WALKED   455,461   unchanged             H-2 HOLDS — no clawback
SPENT              180   == 90 + 90            EXACT
Meadow Herb         ×4   == 2 + 2
Foraging XP         20   == 10 + 10
```

Cross-screen: no unrelated inventory mutation, no unrelated skill mutation, no
world-state change. Carried total 8 items.

### Force-quit and cold relaunch from the Home Screen

Every figure matched exactly. No flash of zeros or defaults on the first painted
frame.

### Sync 2 and 3 — the duplicate-grant test

```
sync 2:  TOTAL WALKED 455,461 -> 459,223, granted 3,762
         banked 455,281 + 3,762 = 459,043
         invariant 459,223 - 180 = 459,043   EXACT

sync 3:  (immediately, without moving)
         NOTHING CHANGED. No grant, no items, no XP.
```

**This is the result the whole persistence architecture exists to produce.** Two
consecutive syncs, the second granting nothing.

### Final state

```
banked         459,043
TOTAL WALKED   459,223
SPENT              180
Meadow Herb         ×4
Foraging XP         20   (level 1)
```

## 4. Two run variables, stated so a pass is not read as covering more than it did

**Flutter 3.47.0, not the pinned 3.44.8.** Every piece of evidence backing this
branch — 95 app tests, four goldens, `verify.sh --strict`, four green CI jobs —
was produced on 3.44.8. The Mac had 3.47.0 and the toolchain was deliberately
**not** changed mid-run (`RULES.md` G-2).

It compiled the branch cleanly with no source changes, and `flutter pub get`
mutated only `analysis_options.yaml` and six SDK-pinned lockfile entries — no
runtime dependency drift, verified rather than assumed. Drift captured at
`~/phase1-flutter347-drift.diff` on the Mac. **This is the first favourable data
point for the deferred 3.47 evaluation**, and it is not that evaluation.

**Profile build, not debug.** iOS 14+ blocks launching a JIT debug build from the
Home Screen, which criteria 1, 17 and 18 require. Not a product defect; a
documented Flutter/iOS constraint.

Consequences worth stating: `kDebugMode` is false, so the dev-harness long-press
is inert in this build — no criterion depended on it. Debug asserts compile out,
including the `PixelAsset` guard against silent sprite rescaling, so profile mode
is a **weaker instrument** for sprite-sizing faults than debug would have been.
AOT startup is also faster than debug, making criterion 1 a slightly weaker test
than a debug launch would have been — mitigated by observing it on a cold
Home Screen launch with nothing attached.

The container survived the debug → profile reinstall; same bundle id, same team.

## 5. Defect found — D-01

### D-01 · The banked-steps header clips its final digit

**Severity: presentation. Data integrity unaffected** — the owner confirmed the
underlying value is correct everywhere it is used, and every arithmetic invariant
above holds.

**Found:** on the physical iPhone at a banked value of 455,281.

**Cause, measured not guessed.** `BankedStepsReadout`
(`lib/ui/components/screen_header.dart:92`) places the figure in a fixed
`SizedBox(width: StrideGeometry.bankedFigureWidth)` — **72 dp** — with
`overflow: TextOverflow.clip`. `formatSteps(455281)` is `"455,281"`: seven
characters at `StrideType.headerValue`, which does not fit 72 dp.

The fixed width is deliberate and its reasoning is sound — it keeps a growing
figure from shifting the eyebrow beside it and off a fractional x. **72 was
simply chosen for smaller numbers than a real player accumulates.**

**Why nothing caught it, and it is the same root cause as M-06 a third time:**

- `TextOverflow.clip` **throws nothing**. Unlike a `RenderFlex` overflow it
  paints no stripe and raises no exception, so the five overflow tests — which
  assert `tester.takeException()` is null at 320/360/375/393/430 dp — cannot see
  it. Clipping is silent by design.
- The goldens render banked as `12,480`. **Six characters, which fits.** The
  evidence used a value that did not exercise the case.

So the defect needed a real save with six-figure banked steps, and only a device
run had one.

**Deferred by owner decision** to the UI facelift rather than fixed during
acceptance. Recorded here so the facelift inherits the cause, not the symptom.

**When it is fixed, the regression test must assert a rendered width or a
character count against a seven-figure value** — not the absence of an
exception, because there will never be one.

> **Fixed in UI Facelift 01, awaiting the owner's device confirmation.**
> Branch `ui-facelift-01`, record `MILESTONES/UI_FACELIFT_01.md`. The fix is to
> the shape, not the number: the box is now a *minimum* and the figure takes the
> width it needs. The regression test asserts what this section asked for — the
> rendered string equals `formatSteps(value)` in full, and the paragraph's
> required width fits its laid-out box — at seven stress values across four
> widths, with a real font loaded. **This entry closes when the owner sees the
> whole figure on the phone**, not when the tests are green; that distinction is
> the entire content of `MISTAKES.md` M-06.

## 6. Verdict

`MISTAKES.md` M-04: *the person who ran the script writes the ACTUAL column; the
verdict line is written by someone who did not build the feature.*

I built this feature and therefore must not declare it passed. The owner ran the
script and did not build it, and so is qualified to write the verdict.

```
PHASE 1 DEVICE ACCEPTANCE:   PASS
Commit:                      eae7700
Device / iOS:                iPhone 10 / iOS 26.6
Date:                        2026-08-16
Run by:                      owner
Verdict written by:          owner (did not build the feature — M-04)
```

## 7. What this run does NOT cover

Stated so a pass is not read as covering more than it did:

- **Android.** Physical Android validation remains paused by owner priority.
- **Background sync.** S-01B is not started and is out of Phase 1.
- **Denied health permission**, deletion escalation, cursor invalidation and
  recovery, and iCloud restore onto a second device.
- **A blocked bootstrap.** Not reproducible without corrupting a real save.
- **The insufficient-steps refusal path.** Unreachable at 455,281 banked; covered
  by automated tests at the exact 89/90 boundary.
- **The dev harness**, inert in a profile build.
- **Typographic parity against the approved renders.** Judged by eye on the
  device; the goldens cannot judge type (M-06).
- **A release build.** This was profile.
