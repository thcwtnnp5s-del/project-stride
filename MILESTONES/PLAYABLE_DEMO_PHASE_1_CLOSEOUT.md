# Playable Demo Phase 1 — closeout

```
STATUS: IMPLEMENTATION COMPLETE — AWAITING PHYSICAL DEVICE ACCEPTANCE
Branch: playable-demo-phase-1
Date: 2026-08-16
```

Phase 1 is **functionally complete and verified on emulated hardware**. It is
**not closed**, because closure requires the owner's physical iPhone run —
`PLAYABLE_DEMO_PHASE_1_ACCEPTANCE.md` is the script, and no CI result
substitutes for it.

---

## 1. What this session added to the branch

The branch already carried the product shell, Adventure, Inventory, Character,
the gather integration and the first test pass. Three things in the milestone
brief were **not** in it, and all three are now:

| Gap | State on arrival | Now |
|---|---|---|
| **World** | Tab present but **disabled**; no screen | Functional, with the illustrated region map |
| **The PixelLab production art** | None shipped — icons and portrait were code-rendered evidence | 24 assets, packaged reproducibly |
| **The two carried corrections** | Both open | Both closed |
| The grounding rule | Not implemented | `GroundedSprite`, footprint-derived |
| Location vignette | Not shown anywhere | Full-bleed band on Adventure |
| Gather animation | Not shown anywhere | Plays once per successful gather |

## 2. The art pipeline

`Scripts/art/package-art.js` packages approved PixelLab exploration output into
`assets/art/v1/`. `Scripts/verify.sh` and CI both run it with `--check`, so a
hand-edited asset fails the build rather than shipping and being silently
reverted by the next packaging run.

It depends on **Node's standard library alone**. The exploration tools under
`GAME_BIBLE/ART/exploration/*/tools/` require `pngjs`, and nothing in this
repository installs it — so they cannot run on a clean clone, which is the state
every future session starts from. `Scripts/art/png.js` is a self-contained RGBA8
reader/writer built on `zlib`.

**The inputs are tracked.** The 26 PixelLab outputs the packaging step consumes
are committed. Everything else under `exploration/` — the failed rounds, and
`WALKSCAPE_REFERENCE_SET` in particular — stays uncommitted: external reference
imagery must not ship, and none of it is a build input.

### Three assets are not straight copies

- **The vignette** is white-keyed by border flood fill (PixelLab returned the
  diorama on an opaque white ground, 34% of the file and the brightest area in
  a dark interface), then cropped 512 × 384 → **384 × 176**. The framing is
  chosen once, in the script, where it is reviewable.
- **`item/unknown.png`** is drawn by the script. It is not art and must not look
  like it: two colours, a rim, nothing inside.
- **The sprite footprints** are measured, and emitted as
  `lib/ui/icons/sprite_footprints.dart`.

## 3. The grounding rule

`GroundedSprite` applies a footprint-derived contact shadow wherever a sprite is
composited onto a background — which blind review identified as the **only**
place the floating defect occurs:

> "The environment is grounded. The three figures are the only floating
> elements."

PixelLab grounds what it generates *inside* a scene. It is compositing that
floats. So this is a composition step, not an asset pass.

The width comes from the sprite's own lowest opaque rows, measured at packaging
time. **A caller cannot pass a shadow width**, so the shadow cannot disagree
with the figure standing on it.

One thing worth carrying: the shadow was invisible on its first render.
`surfaceGround` is near black, and a 0.72 multiply against it moves the pixels
by about four values. Raising the strength would have been the wrong fix — the
ellipse would then have been invisible there and far too heavy on the next
surface. The stage uses `surfaceBlock` instead: a surface with something to
darken. **A multiply shadow needs a ground with luminance, not a stronger
multiply.**

## 4. Visual QA — the device pass

Run on a running device at 411 × 914, on all four screens. It found three
defects, and **none of them was findable by the tests or the goldens**.

| Defect | Why nothing caught it |
|---|---|
| **Every string in the product was underlined** — no `Material` ancestor, so `DefaultTextStyle` resolved to Flutter's fallback, which carries `TextDecoration.underline` | Widget tests read a string's *content*, never its decoration. The golden harness has no real font and draws every glyph as a filled rectangle, so the underline merged into the box |
| **The inventory grid inherited the device's status-bar inset** — `GridView` defaults to `primary: true`, which adopts `MediaQuery.padding` | `flutter test` supplies **zero** safe-area insets, so the gap was exactly 0 under test and 57 dp on hardware |
| **The region list opened on Forgotten Hollow** — `locations` iterates alphabetically | Nothing asserted ordering |

**This is the durable lesson of the milestone.** The golden harness is blind to
type and the test harness is blind to insets, both by construction. Neither is a
substitute for looking at a running build, and a screen can pass 93 tests and
four goldens while being visibly broken in the two most common ways a Flutter
app breaks.

The underline defect now has a regression test that asserts the *resolved* text
style rather than the presence of a `Material` widget, and it was confirmed to
fail without the fix.

## 5. The two carried corrections — both CLOSED

Full record: `GAME_BIBLE/ART/exploration/PHASE1_CARRIED_CORRECTIONS/README.md`.

### A — the region map's watercourse

The stabilization pass left this **NOT CLOSED** having verified it objectively:
blue pixels went 132 → 267, and a blind reviewer looking directly at those
coordinates still saw the stream *"narrow by perhaps a pixel and stop"*.

Two changes closed it, and only one was obvious.

**Value, not area.** The previous tarn had roughly the right size and the wrong
contrast — its blue sat close to the grass in *value*. That is precisely why
counting blue pixels reported success while looking reported failure: **the
measurement was answering a different question from the one that mattered.**

**An elliptical mask.** The first attempt here used a rectangle and reproduced
the artefact the stabilization pass found on the tavern floor — a visible
hard-edged patch where the regenerated tone met the original. It was **discarded
rather than shipped**; a hard rectangle in the middle of the map is worse than a
stream that fades.

Verified on the device at native scale, not only at magnification.

### B — gather frame 5

One inpaint over a 21 × 25 box covering the fused arm, hip and knee. The herb
hand (x ≥ 38) and the boot rows (y ≥ 59) are outside the mask, so the herb
interaction and the planted feet could not drift.

**Measured for both corrections: 0 pixels changed outside the mask.**

### Still open, deliberately

The watercourse has no banks along its length, holds a constant one-to-two-pixel
width, and its blue is the highest-chroma element on the map. Those are
composition questions, and the brief says not to reopen world-map composition.

## 6. World — presentation that must not become an affordance

The screen answers *"where am I?"* and *"where can I eventually go?"*. It does
not answer "how do I get there", because nothing in `stride_core` can.

There is no travel activity at any layer. `EnterLocation` exists and its own
comment records the gap: *"No travel cost here. Travel consumes steps over
time."* That command is unwritten.

So **nothing on the screen is a control** — the map has no hit testing, the
legend rows are text, and the step figures are labelled as distances rather than
prices and rendered muted rather than teal (L-16 reserves the accent for steps
the player owns). A `Travel` button here would be the most convincing lie in the
demo: real roads, real costs from the content pack, real banked steps, and no
system behind any of it. The screen says so in one sentence instead of leaving
the player hunting the map for a tappable road.

Two tests hold that line: no `StrideButton` anywhere on the screen, and the
disclaimer present.

## 7. Tests

**95 automated app tests, plus four goldens.** New this session:

- World navigates and renders every location from the content pack
- World offers no travel control, structurally — no button of any kind
- Route distances do not use the banked-steps accent
- The current location leads the region list
- A refused gather leaves the figure at its rest frame
- The figure is grounded from its own measured footprint
- **No text inherits the missing-Material fallback style**
- Overflow at 320 / 360 / 375 / 393 / 430 now covers World

## 8. Known limitations

- **Physical iPhone acceptance has not been run.** This is the gate.
- Emulated Android is what Visual QA used. It is a real renderer with real
  fonts, and it is not the target platform.
- The **contact shadow has not been blind-reviewed**. It was tuned against a
  finding, checked by eye at magnification and on the device, and read as
  grounded — but the stabilization pass's own record shows this exact quantity
  being misjudged twice, so treat it as unverified.
- The World map is **384 px wide at ×1**. A 320 or 360 dp phone clips 32 or 12
  px from each flank, which is forest and cliff. No supported phone loses
  anything load-bearing, but it is a clip, not a fit.
- **`item_unknown` covers nine of twenty items.** None is obtainable in Phase 1.
- The gather animation is **8 frames at 110 ms**, one-shot. It depicts a
  discrete command and deliberately does not loop.
- Android physical validation remains paused by owner priority; nothing here
  changes that.

## 9. What Phase 1 still does not build

Unchanged from the plan, and each cut still holds: no progress track, no
`54 / 90`, no Stop or Change-activity, no durable recent-gains view, no filter
pills, no equipment slots. Skills and Craft remain visibly disabled rather than
hidden — six sections with two unbuilt is true; three sections is not.
