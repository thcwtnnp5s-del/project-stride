# Playable Demo Phase 1 — manual device acceptance

```
STATUS: TO BE RUN BY THE OWNER, ON A PHYSICAL iPhone
Phase 1 is not complete because CI is green. It is complete when this passes.
```

Record before starting: **commit SHA**, **iPhone model**, **iOS version**, **date**.

Every expectation below is relative to values you record at the start, not to
absolute figures — the save on your device is whatever S-01A left on it.

---

## Build and run

Flutter cannot build iOS on Windows, so the Mac is in the loop as a
sign-and-install station. Free Personal Team signing; no paid membership.

**On the Dell (development machine):**

```bash
git fetch origin && git checkout playable-demo-phase-1
```

**On the Mac:**

```bash
flutter pub get
```

```bash
open ios/Runner.xcworkspace
```

Then in Xcode: select your iPhone as the destination, and **Run**. Signing is
already configured for the free Personal Team; if Xcode asks, trust the profile
on the phone under Settings → General → VPN & Device Management.

To run the full local verification pass first:

```bash
./Scripts/verify.sh --strict
```

---

## The script

| # | Step | Expected | ACTUAL | What failure looks like |
|---|---|---|---|---|
| 1 | Launch from Xcode | The app opens to the Adventure screen | | Immediate termination → a missing `NSHealthShareUsageDescription`. "Untrusted Developer" → trust the profile in Settings |
| 2 | **Watch the very first frame** | Real figures straight away | | **A visible `0` that then jumps to the real number.** Watch deliberately — it is one frame, and it is the defect `main.dart`'s await-before-`runApp` exists to prevent |
| 3 | Confirm the save loaded | Your inventory and skills are the ones S-01A left | | A brand-new game state → the save was not found or was refused. **Stop here.** This is the highest-severity outcome on the script |
| 4 | Record **banked steps B₀** (header, top right) | any value | | — |
| 5 | Record **Meadow Herb count H₀** (Inventory) and **Foraging XP X₀** (Character) | any values | | — |
| 6 | Confirm nothing identifying is on screen anywhere | No app names, device names, source names, file paths, no long hex strings | | Any of those visible is a privacy defect (H-7). Report it — but **do not attach the screenshot** |
| 7 | Walk ≥ 200 steps with the app closed, reopen, tap **Sync steps** | A line appears: `+N steps banked` | | A control that never resolves; a permission prompt at this point (it should already be granted); "not available" while Health is authorised |
| 8 | Confirm the grant | Banked == B₀ + N, exactly | | Banked moved by a different amount, or moved while N was 0 — a UI accumulating its own total |
| 9 | Check the **faults** line if one appeared | Usually absent | | If it lists anything, record it verbatim. `cursorOfferedWhenProhibited` is a real defect signal and must never be hidden |
| 10 | Read the Meadow Patch card | `STEPS 90 per gather`, `YIELD ×2 Meadow Herb`, `EXPERIENCE +10 Foraging XP` | | Any other cost → registry drift or a hardcoded number |
| 11 | If banked < 90, confirm the control refuses | Disabled, and says `Walk N more steps` | | A tappable control that then errors, or a silent no-op |
| 12 | Tap **Gather** once | One result line: `Meadow Herb ×2` and `+10 Foraging XP` | | Two results from one tap; a result that appears twice |
| 13 | Confirm the spend | Banked == (value at step 8) **− 90** | | −180 → double dispatch. −0 with a success message → fabricated success. A figure that only updates after leaving and re-entering the tab → a missing refresh |
| 14 | Wait ~5 seconds | The result line disappears on its own | | It persists → it has become a durable "recent gains" system, which Phase 1 does not have |
| 15 | Confirm `TOTAL WALKED` did **not** fall | Unchanged by the spend | | If it fell, granted was clawed back — a direct H-2 violation |
| 16 | Open **Inventory** | Meadow Herb == H₀ + 2 | | A count that disagrees with the result line → two screens reading different sources |
| 17 | Open **Character** | Foraging XP == X₀ + 10 | | XP unchanged → not persisted or not rendered from state |
| 18 | Check the Foraging **level** | Correct for the XP total. Foraging reaches level 2 at **100** XP | | A level-up at the wrong threshold → the curve is being computed somewhere it should not be |
| 19 | Tap **Skills**, **Craft**, **World** | Nothing happens. They look dimmed and unavailable | | Any of them navigates, or looks fully active |
| 20 | Record **B₁**, **H₁**, **X₁** | | | — |
| 21 | **Force-close** from the app switcher (swipe up) — not just background | App gone from the switcher | | — |
| 22 | Relaunch | Banked == B₁, herbs == H₁, XP == X₁, **exactly** | | **Any drift is a severity-1 data-integrity defect.** Reverting to step 4/5 values → the commit never landed. Herbs present but energy restored → the spend and the yield were not one transaction |
| 23 | Tap **Sync steps** again **without walking** | `No new steps to bank` | | A second `+N`, or banked rising. **This is the double-grant the whole architecture exists to prevent. Severity 1, stop testing** |
| 24 | Confirm no duplicate yield | Herbs still H₁, XP still X₁ | | A sync granting items → a command wired to the wrong path |
| 25 | Tap **Gather** twice, fast | One result, one spend of 90 | | 180 spent, or a "the last save did not land" banner appears — the banner here would mean the double-tap manufactured a compare-and-swap fault |
| 26 | Rotate the device | Stays portrait | | Any landscape layout violates `DECISIONS/0009` |
| 27 | Settings → Display & Brightness → Text Size, set to maximum, return | No clipped or cut-off text on any of the three screens. **Tab labels do not grow** — that is deliberate | | A number cut mid-digit, a control pushed off screen, overflow stripes |
| 28 | Long-press the banked-steps readout in the header | The dev harness opens (debug builds only) | | Nothing happens on a debug build → the debug affordance is not wired |

---

## Verdict

Per `MISTAKES.md` M-04, **the person who ran the script writes the ACTUAL column;
the verdict line is written by someone who did not build the feature.**

```
PHASE 1 DEVICE ACCEPTANCE:  PASS / FAIL
Commit:
Device / iOS:
Date:
Run by:
Verdict written by:
```

## What this script does NOT cover

Stated so a pass is not read as covering more than it did:

- **Android.** Physical Android validation remains paused by owner priority.
- **Background sync.** S-01B is not started and is out of Phase 1.
- **Denied health permission**, deletion escalation, cursor invalidation and
  recovery, and iCloud restore onto a second device.
- **A blocked bootstrap.** Reachable in principle; not reproducible on demand
  without corrupting a real save, which this script will not ask you to do.
- **Typographic parity against the approved HTML renders.** The golden images in
  `test/goldens/` are captured by `flutter test`, whose harness has no real font
  and renders every string as a filled rectangle. They are regression goldens
  between Flutter revisions and **cannot** be used to judge type. Step 27 and
  your own eyes on the device are the only typographic evidence Phase 1 has.
