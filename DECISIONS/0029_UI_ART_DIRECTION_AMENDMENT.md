# 0029 — PixelLab may author interface art: the L-18 amendment

**Status:** Approved — **owner ruling, 2026-08-31**
**Date:** 2026-08-31
**Owner:** Project owner (explicit, in writing, during
PRESENTATION_COMBAT_EVOLUTION_01)
**Amends:** `GAME_BIBLE/ART/ART_DIRECTION.md` **L-18** and the UI Baseline
Closeout status block (2026-08-16)
**Related:** `RULES.md` A-1, A-2, G-3, G-7 · `MILESTONES/PRESENTATION_COMBAT_EVOLUTION_01.md`

---

## Context

`GAME_BIBLE/ART/ART_DIRECTION.md` has carried `Status: LOCKED` since the UI
Baseline Closeout of 2026-08-16, and **L-18** read, in full:

> Every pixel asset is displayed at an exact integer multiple of its native
> size, with nearest-neighbour filtering and no sub-pixel positioning, in a
> container that layout cannot compress.
> Interface chrome — type, panels, borders, radii, tracks — is ordinary
> high-DPI native rendering. **The interface is not pixelated; the content is.**

That second paragraph was a real decision, not an omission. The closeout
records the single-canvas pixel-screen premise as **retired, not deferred**,
and the UNRESOLVED table lists the final UI visual language as *"closed at the
direction level"*. The consequence is visible on disk: `assets/ui/v1/` holds
twenty-one files, every one a 12–24 px nav or skill glyph. **No frame, no
border, no texture, no ornament, no panel plate exists anywhere in the
repository**, and `lib/` contains no nine-patch renderer, no `DecorationImage`
and no `centerSlice`.

Two things then collided.

**The forensic finding.** The owner's standing criticism — the product "still
looks too much like generic / AI-authored Flutter UI" — was audited in Wave 0
of PRESENTATION_COMBAT_EVOLUTION_01 and found to be accurate but misattributed.
There is *no* stock Material anywhere in the app: no `Card`, `Chip`,
`ListTile`, `ElevatedButton`, `LinearProgressIndicator`, `AlertDialog` or
`Icons.*`. What produces the generic read is narrower: `SectionCard` draws one
rectangle — radius 14, one 1 px border in one colour, one fill — at
**thirty-four call sites**, of which thirty-one do not even take the optional
hue wash; and the washes that do exist are authored within ~6 L\* of the card
colour, so they are sub-perceptual by construction and *cannot* carry identity.
Meanwhile an 896-file hand-authored pixel pipeline renders every piece of
**content** in the game. Hand-made sprites sit inside machine-drawn rectangles.

**The rule stood in the way of the fix.** Under L-18 as written, the most
direct remedy — giving panels an authored material — was not a production
backlog awaiting credits. It was forbidden.

`ART_DIRECTION.md`'s own header requires that an agent reading it *"must stop
and ask rather than infer"* (`RULES.md` G-3). The workstream stopped and asked.

## Decision

**The owner amends L-18. PixelLab may author production interface art.**

The owner's ruling, recorded in their own terms:

> Flutter remains responsible for layout, text, dynamic data, accessibility,
> interaction, responsiveness and hit targets.
>
> PixelLab may author production UI art where it materially improves the game:
> panel/frame art, headers, material surfaces, borders, dividers, reward
> frames, combat frames, craft/workbench presentation, inventory/equipment
> treatments, board/ledger treatments and restrained screen backplates.
>
> Do NOT turn whole screens into raster screenshots. Do NOT pixelate text. Do
> NOT sacrifice readability or mobile responsiveness. Prefer
> scalable/segmented/9-slice integration for authored frame assets. Maintain
> one coherent Stride visual language rather than making every screen
> stylistically unrelated.
>
> The goal is specifically to eliminate the generic rounded-card /
> LLM-generated application appearance and make Stride feel like an authored
> RPG.

### L-18 as amended

The **first** paragraph is untouched and remains in force. Integer scale,
nearest-neighbour, no sub-pixel positioning, non-compressible container: that
half of L-18 is a measurement discipline earned by three wrong diagnoses, and
it now governs *more* assets rather than fewer.

The **second** paragraph is replaced by:

> Interface chrome may be authored pixel art. Text, layout, measurement,
> state and interaction are never raster.

### The boundary, stated so it is enforceable

A raster asset in the interface may occupy only:

1. the **outer edge** of a panel — a frame, drawn as corners at 1:1 integer
   scale with tiled (never stretched) edge strips;
2. a panel's **interior as a tiled surface** of low tonal variation; or
3. a **discrete ornament** positioned by Flutter.

It may never carry a word, a number, a state, or a boundary that Flutter needs
to measure.

**The test that keeps this honest, and that CI runs:** with every frame asset
removed from the build, the app must still lay out, still read, still be
navigable and still pass its accessibility assertions. A raster asset may
change how Stride *feels*; it may never change what Stride *does*. This is why
the skin architecture ships with a painted fallback and an empty registry
(§ Consequences).

## What this decision does NOT authorize

- **No PixelLab generation in this workstream.** The remaining balance is
  **exactly 25** and it is the atlas emergency reserve. The owner's ruling
  states this directly — *"The remaining 25 PixelLab generations are STILL
  RESERVED for the atlas and are NOT authorized for this workstream"* — and it
  matches the standing position carried since WORLD_ATLAS_REMASTER_01, where a
  single inpaint call bills 20–40 and therefore consumes the whole correction
  capacity. Reset is 2026-09-16. Everything below is architecture plus a
  production queue.
- **No pixelated text**, at any size, anywhere. Bitmap type is not in scope and
  is not a future option under this decision.
- **No full-screen raster.** A screen is a composition Flutter performs; a
  backplate is restrained, scrimmed, and behind everything.
- **No per-screen frame family.** One chassis, app-wide. Identity comes from
  bands, surfaces and pictures, never from eleven different borders — the
  failure mode this decision is most likely to produce if unwatched.
- **No stretched pixel art.** `centerSlice` stretches its edge bands and is
  therefore forbidden for pixel frames; tiling is the only permitted edge
  behaviour, which imposes a real authoring constraint (no once-only ornament
  inside a repeating strip).
- **No change to L-16** (teal is walking, exclusively), **L-15/L-17** (an icon
  may not change referent; a wrong semantic is a blocker), or **A-1/A-2**
  (PixelLab authors; deterministic transformation is not authoring). A frame
  that reads as an equipment slot, a lock, a coin or a capacity meter is a
  blocker on semantics regardless of craft.

## Reasoning

- **The rule was right for the product it described, and that product
  changed.** L-18's second paragraph settled a question about *type rendering*
  — the single-canvas pixel screen, where a bitmap font fought real
  anti-aliased text. That premise is genuinely retired. Nothing in it was ever
  an argument that a panel's *edge* must be drawn by Skia rather than
  authored, and treating a settled typography question as a permanent ban on
  interface material was an over-reading the closeout did not intend.
- **The diagnosis names a cause the old rule made unfixable.** Thirty-one of
  thirty-four panels identical, hierarchy carried by a wash below the
  perceptual threshold, and a palette whose contrast budget is four near-blacks
  spanning ~14 L\* with its one accent reserved by L-16. Under those
  constraints, size, image and space are the *only* remaining hierarchy tools —
  and image was the one the rule prohibited.
- **The asymmetry was indefensible.** Every creature, item, place and character
  in Stride is hand-authored pixel art. Every container around them was a
  rounded rectangle from a layout engine. The owner's "authored RPG versus
  application displaying RPG data" is precisely that seam, described from the
  player's side.
- **Amending beats exempting.** A one-off exception for "just the combat frame"
  would have left the rule saying something the codebase contradicted, which
  `RULES.md`'s own preamble names as how a rule comes to disagree with itself.

## Consequences

- `GAME_BIBLE/ART/ART_DIRECTION.md` L-18 is amended in place, with its previous
  text preserved and this decision cited. The file stays **LOCKED**; a locked
  document is one that changes by decision, not one that never changes.
- **`SectionCard` gains a `role`, and a skin registry decides whether that role
  has art.** All existing call sites compile unchanged and render
  byte-identical until a registry entry exists, so the architecture lands with
  zero visual risk and the art drops in later without touching thirty-four call
  sites.
- **A tiled nine-patch renderer joins `pixel_asset.dart`**, not a new file —
  `Scripts/check-ui-boundary.sh` confines image drawing to that one file so
  `filterQuality: none` has a single home.
- **`Scripts/check-ui-boundary.sh` is strengthened**, not relaxed. Its L-18
  guard matched `Image.(asset|file|network|memory)` only, so a frame written
  the obvious way — `DecorationImage` in a `BoxDecoration` — would have
  rendered bilinear and passed CI silently. `DecorationImage` and `paintImage`
  are now caught outside `pixel_asset.dart`. This hole predates the decision
  and would have become live the moment anyone acted on it.
- **A palette guard becomes necessary before the first UI-art round.** L-16
  reserves `#58D6C0` system-wide and *nothing enforces it* — the style spec
  concedes the generated palettes only *appear* clear of it, "an impression,
  not a measurement". A UI-art family is the first art authored near interface
  colour, so it is the first that could collide. The guard is a prerequisite of
  production, not of this decision.
- **The production queue is written now and runs after 2026-09-16.**
  `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` carries per-asset dimensions,
  tiling strategy, transparency, palette, prompt, variants, runtime
  destination, integrating component, priority and estimated generations.
- **Reversible.** If device review rejects the direction, the registry is
  emptied and every screen returns to the painted fallback in one commit. That
  property is deliberate and must be preserved as the architecture grows.

## Invariant check

**P-1** mobile-first: unchanged; the tiling renderer is chosen *because*
stretching breaks on varying phone widths. **P-6** no monetization: the
semantic ban carries forward — no coin, no price, no premium framing.
**E-2/E-5**: art is presentation; no frame carries or derives a game fact.
**A-1**: Claude does not draw production artwork; the fallback is a painted
`BoxDecoration`, which is chrome, not art. **A-2**: crops and recrops of
approved plates remain deterministic transformation. **L-16**: unchanged and
now scheduled for real enforcement. **G-4**: the boundary guard is
strengthened; nothing is loosened to make anything pass. **Health, steps,
economy, save format, combat resolution:** untouched — this decision reaches
nothing outside `lib/ui`, `assets/ui`, and the art pipeline.
