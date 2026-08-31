# UI Material Direction 01 — DRAFT

```
STATUS: DRAFT · NOT CANON · NOT APPROVED · DESIGN ONLY
Author: DIR-A (RPG UI Art Director) · Date: 2026-08-31
Branch: presentation-combat-evolution-01
Nothing here is a decision until the owner locks it
(STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md). No code was changed to write it.
```

**Charge.** The owner's finding: the game "still looks too much like generic /
AI-authored Flutter UI" — "an application displaying RPG data" rather than an
authored RPG. Target character: **dark fantasy travel journal + handcrafted
adventurer's field kit + warm reward light + regional material character.**

**Where this document sits.** `ART_DIRECTION.md` outranks it (`RULES.md` G-7).
It resolves nothing on that document's UNRESOLVED list, and it proposes exactly
one change to an existing token family, flagged as an owner decision in §7.

---

## 1. The diagnosis, sharpened

Ranked. The forensic evidence establishing each is in the FDO/presentation
review and is not re-derived here.

1. **Every screen is the same rectangle, repeated.** One container primitive
   (`SectionCard`, `lib/ui/components/surfaces.dart:25`), one radius, one border
   weight, one fill, ~34 call sites, and `cardGap = 10` between every pair on
   every screen (`lib/ui/theme/stride_metrics.dart:40`). Uniform gap over
   uniform cards is the defining signature of a table, and a table is what an
   application looks like.
2. **Nine of twelve surfaces contain no image at all.** Skills, Skill Detail,
   Inventory, Character, Step Tracker, Goal Board, Field Notes and Craft-at-rest
   render zero pictorial content, ever — while 896 art files exist and 5 of 10
   packaged location vignettes are never displayed. A screen with no picture
   cannot be a place.
3. **The header names the tool and demotes the world.** `stride_shell.dart:80`
   sets `title: _selected.label`, so the largest word on every screen is
   "Inventory" — a menu label — while the place is an 11 px eyebrow above it and
   the tab bar reprints the same word 4 dp below.
4. **Nothing in the interface is made of a material.** `assets/ui/v1/` is 21
   files, all nav and skill glyphs. There are zero frames, zero borders, zero
   textures; no 9-slice renderer, no `DecorationImage`, no `centerSlice`, no
   `ImageRepeat` anywhere in `lib/`. Every edge in the product is a 1 px
   `#372F27` stroke drawn by Skia.
5. **The contrast budget for hierarchy is spent.** Four near-black surfaces
   across ~14 L*, one reserved accent (L-16), one border weight, one border
   colour, no warning/positive/error hue by decision. Every card therefore
   claims equal importance and the eye has nowhere to land first.
6. **The rhythm carries no grouping information.** A strict 8-value spacing
   scale used uniformly means the space between two rows of the same idea and
   the space between two different ideas are the same number.
7. **The identity that exists is applied below perception.** Skill deeps and
   region deeps are authored within ~6 L* of the card colour and only 3 of 34
   cards pass one — identity spent at a strength that structurally cannot carry
   it.
8. **The net effect is competence without character:** every constraint in this
   system was written to prevent a specific defect, and not one was written to
   produce a specific feeling.

**The genericness is not LLM boilerplate.** There is no stock Material anywhere
in the app. This is an *authored* system that authored only its rules.

---

## 2. The target visual language

### 2.1 Shared DNA — what must persist on every screen

Six statements. A screen that breaks one has left the family.

| # | The rule |
|---|---|
| DNA-1 | **The page is a dark journal leaf; a panel is an object placed on it.** Not a region of the page — a made thing with an edge, tipped in. |
| DNA-2 | **Key light is upper-left, everywhere, always.** Already the content rule (`PIXELLAB_STYLE_SPEC_01` §4); it now binds the chrome too, so a frame cannot disagree with the sprite inside it. |
| DNA-3 | **Every screen shows at least one picture.** No exceptions. If a surface has no subject, it shows the place it is happening in. |
| DNA-4 | **Type is ink; images are artifacts.** No word is ever raster, and no picture ever carries a word the player must read. |
| DNA-5 | **Two levels of space, and only two.** `cardGap` between siblings; `subjectGap` + a ruled heading between subjects. |
| DNA-6 | **One frame family app-wide.** Per-system identity comes from the *band* and the *picture*, never from a second frame. A second frame is a second visual language. |

### 2.2 Per-system material identity

Every device below is either **(a)** an asset PixelLab can author, or **(b)**
Flutter layout/type/space. Nothing is "polish".

| Screen | Material metaphor | Devices |
|---|---|---|
| **Adventure** | The journal, open at today's page | 1. *(b)* The `LocationStage` band already is the picture — leave it. 2. *(b)* The selected node becomes the screen's one **hero plate**: node art 96×96 ×1 in an `InsetWell`, everything else demoted to rows. 3. *(a)* Chassis frame on the hero plate only. |
| **Character** | The kit laid out; the portrait a tintype pinned to the page | 1. *(b)* Home location's **alt** vignette as a top-anchored scrimmed backdrop band behind the portrait card. 2. *(b)* The portrait card takes the hero plate role (the portrait `InsetWell` at 128 is already correct and does not change). 3. *(b)* The sheet below becomes ruled rows — 1 px `separator` between facts — the ledger reading, not four stacked cards. |
| **Skills** | Five trade guild plaques | 1. *(a)* A 384×32 **trade band** per skill, full card width, behind the icon+name row — the material of the trade (foliage, sawn timber, cut rock, scale and soot, hearth). This is the job the ~6 L* wash cannot do. 2. *(b)* `subjectGap` between the five cards: five trades are five subjects, not five rows. 3. *(b)* Highest-level trade takes the hero plate. |
| **Skill Detail** | The trade's own page, opened | 1. *(b)* `AmbientAssets.workBackdropFor(skill)` — authored, integrated, and used on exactly one surface today — as the scrimmed top band. Five trade pages become five places for zero new art. 2. *(b)* The roadmap becomes a vertical rail with rungs, not a stack of cards. |
| **Inventory** | The pack, emptied onto oilcloth | 1. *(a)* Oilcloth grain in the grid card's interior (≤6 L* variation — grain, not pattern). 2. *(b)* The equipped loadout becomes the hero plate: three slots, three 48 px icons in inset wells, above the grid. 3. *(b)* Equipment separated from materials by `subjectGap` + a ruled heading. The item tiles' inset wells are the field kit's compartments and are **already right** — do not touch them. |
| **Craft** | The workbench, from above | 1. *(a)* A workbench vignette (384×176) so Craft-at-rest has a place; until it exists, *(b)* the smithing/cooking work backdrop keyed to the selected category. 2. *(b)* The selected recipe becomes the hero plate: input icons → output icon on one row at 48 ×1. 3. *(a)* Oak grain in the bench plate's interior. |
| **World** | The atlas — **already correct** | No change. This screen is the proof that the rest is fixable. |
| **Step Tracker** | The pedometer page — the one ledger allowed to be a ledger | 1. *(b)* Current location's alt vignette as a 96 dp scrimmed band. 2. *(b)* Day rows separated by a rule, not by a card each. Keep the density; this screen's job is comparison. |
| **Goal Board** | The pinned contract board | 1. *(b)* Tracked goal takes the hero plate; the rest demote to slips. 2. *(a)* Cork/timber grain in the board panel. 3. *(a)* A discrete pin ornament on the tracked slip (Batch E). |
| **Field Notes** | The bestiary pages — the best-named screen in the app | 1. *(b)* Each **Known** creature shows `f0` of its idle at 64 ×1 in an `InsetWell`. 262 combat files exist; the one screen about creatures shows none of them. 2. *(b)* Region sections get the region's alt vignette as a scrimmed 96 dp section band. |
| **Combat modal** | The encounter, on the ground it happened on | 1. *(a)* The heavy frame — the **one** place an ornate edge belongs, because a modal must feel like an interruption. 2. *(b)* Stage unchanged. |
| **Travel transition** | Already correct | The model the rest copies. |

---

## 3. The primitive redesign

Eight primitives. The first three are the architecture; the rest are the
expression.

### P-1 — `PanelSkin` / `PanelRole` / `PanelSkins` (new: `lib/ui/components/panel_skin.dart`)

The registry. **Contains no image call of any kind** — it is a table of roles
and their materials.

```dart
/// What a panel is made of. A call site names a ROLE; this file decides
/// whether that role has authored art yet. Art therefore drops in with no
/// call-site change.
enum PanelRole {
  card,        // the default; 31 of 34 sites
  heroPlate,   // exactly one per screen
  tradePlate,  // a skill card
  benchPlate,  // craft
  kitTray,     // inventory grid
  boardSlip,   // goal board
  journalLeaf, // field notes
  modalFrame;  // combat

  /// Logical px each side reserved for a frame's art, spent TODAY by the
  /// painted fallback so nothing reflows when art lands.
  double get frameReserve => switch (this) {
    PanelRole.card || PanelRole.kitTray => 0,
    PanelRole.modalFrame => 12,
    _ => 8,
  };
}

sealed class PanelSkin { const PanelSkin(); }

/// Today's BoxDecoration. The fallback, forever.
final class PaintedSkin extends PanelSkin { ... }

/// A tiled nine-patch. See P-2 for why "tiled" and not "centerSlice".
final class FrameSkin extends PanelSkin {
  const FrameSkin({
    required this.corner,      // one 4-up sheet or four paths
    required this.edgeH,       // tileable, period == cornerSize
    required this.edgeV,
    required this.cornerSize,  // SOURCE px, square
    required this.scale,       // integer (L-18)
    this.interior,             // optional seamless grain tile
  });
}

abstract final class PanelSkins {
  /// EMPTY TODAY. One entry per authored batch, and that is the whole
  /// integration cost of a frame.
  static const Map<PanelRole, FrameSkin> _authored = <PanelRole, FrameSkin>{};
  static PanelSkin of(PanelRole role) => _authored[role] ?? PaintedSkin.card;
}
```

### P-2 — `PixelFrame` (new, and it **must** live in `lib/ui/components/pixel_asset.dart`)

The renderer that does not exist anywhere in `lib/`.

**The load-bearing call: this is a TILED nine-patch, not a `centerSlice` one.**
`centerSlice` stretches the edge bands and the middle. Stretching pixel art is
forbidden (L-18, `PixelAsset`'s own assert). So:

- Four corners are drawn 1:1 at integer `scale`, as `PixelAsset`s.
- Four edges are **repeated**, never stretched, at the same integer scale.
- The interior is **not art by default** — it is `surfaceCard`. An optional
  seamless grain tile may repeat there, at ≤6 L* variation.
- The last tile in a run is **clipped**, because a panel's height is
  content-driven and the repeat count is fractional. This imposes an authoring
  constraint, stated in §5: an edge strip must be tolerant of a partial repeat,
  so no once-only ornament may live inside an edge run. Once-only pieces go in
  the corners, or in a separate positioned ornament (Batch E).

**Where it lives is not a preference.** `Scripts/check-ui-boundary.sh:144-164`
confines `Image.asset` to `pixel_asset.dart` so `filterQuality: none` has one
home. A frame built with `DecorationImage` + `ImageRepeat` uses `AssetImage`,
not `Image.asset`, and would therefore **slip past that guard and render
bilinear with nothing to point at** — the exact failure class L-18 exists to
prevent, in the one place nobody would look. Two required changes:

1. `PixelFrame` is the third member of the family in `pixel_asset.dart`. "One
   image site" stays one site.
2. The guard's pattern gains `DecorationImage|paintImage|AssetImage` so a
   future frame cannot be drawn any other way.

### P-3 — `SectionCard` gains `role` (`lib/ui/components/surfaces.dart:25`)

```dart
const SectionCard({
  super.key,
  required this.child,
  this.padding,
  this.wash,
  this.role = PanelRole.card,   // NEW, defaulted
});
```

All ~34 existing call sites compile unchanged and render **byte-identical**
today. `build` resolves `PanelSkins.of(role)`, and the painted branch is exactly
today's `BoxDecoration`. The content box is derived from
`padding + role.frameReserve`, spent now by the painted fallback, so a frame
landing later changes the material and **not the layout**.

### P-4 — `ScreenHeader` inversion (`screen_header.dart`, `stride_shell.dart:78-86`)

`title` becomes the place; `eyebrow` becomes the section; `regionInk` moves from
the eyebrow to the title. See §4 N-1 for the exact change and its three risks.

### P-5 — `SectionHeading` gains a second level (`surfaces.dart:120`)

Today: an 11 px micro-label row. Add `SectionHeading.subject` — 16 px
`sectionHeading`, with a 1 px `separator` rule beneath at full width. Two
heading levels, matching the two gaps. This is where grouping information enters
the layout instead of being carried by nothing.

### P-6 — `StrideSpace.subjectGap = 20` (`stride_metrics.dart:40`)

A ninth token, and the justification must be written into its doc comment: the
scale tops at 16, and 16 is already `screenGutter` — a subject break equal to
the screen margin reads as a margin, not a break. 20 keeps the 2-multiple
discipline. **Two gaps, and there is no third.**

### P-7 — `ScreenBackdrop` (new: `lib/ui/components/screen_backdrop.dart`)

The top-anchored scrimmed vignette band. Full spec in §4 N-2.

### P-8 — `HeroPlate` (`surfaces.dart`)

`SectionCard(role: PanelRole.heroPlate, padding: cardPaddingCompact)` with a
**required** picture slot and a `cardTitle`. Exactly one per screen. This is how
hierarchy is bought without spending colour — with size, image and space, which
are the three budgets that are not exhausted.

**Rule: a hero plate is not rendered when its subject is absent.** No
placeholder, ever — the same reasoning `PixelIcons.vignetteFor` already uses
(`pixel_icons.dart:120-124`).

### Not touched

`InsetWell` (`surfaces.dart:81`) is already the right material and the only
honest one in the app. It stays exactly as it is.

---

## 4. What ships now, with zero new art

Ranked by identity gained ÷ cost.

### N-1 — The header inversion  *(≈6 lines; the largest identity gain in the document)*

- **Files.** `lib/ui/shell/stride_shell.dart:78-86`;
  `lib/ui/components/screen_header.dart:74-80`.
- **Change.** `eyebrow: _selected.label.toUpperCase()`,
  `title: controller.session.locationName`; move `color: regionInk` from the
  eyebrow's `AdaptiveText` to the title's; eyebrow stays `textMuted`. Rewrite
  the now-false comments at `stride_shell.dart:71-77` and
  `screen_header.dart:70-73`.
- **Risks.**
  1. *The duplication moves rather than disappears* — the eyebrow says
     "INVENTORY" and the tab bar says "Inventory". At 11 px muted against 9.5 px
     that is a breadcrumb, not a shout; **device test decides.** Fallback if it
     still reads doubled: drop the eyebrow on the six tabs entirely and keep it
     only on pushed screens, where `bestiary_screen.dart:68-69` already does the
     right thing ("THE TRAVELER'S JOURNAL" / "Field Notes").
  2. *The title is now player-visible content, not four short known strings.*
     "Whispering Woods" at 19 px beside a five-figure banked readout on a 320 dp
     phone is the D-01 shape one axis over. `AdaptiveText` shrinks rather than
     clips, and `bankedFigureMaxFraction` (0.62) caps the readout — but the
     comment justifying that cap assumed short titles and is now wrong. **Device
     check at 320 dp, text scale 1.4, six-figure banked value.**
  3. *Accessibility* — a screen-reader user loses "Adventure" as the first thing
     announced. Give the header a `Semantics` label reading section, then place.

### N-2 — The scrimmed location backdrop for the pictureless tabs  *(1 new widget, 7 call sites, 0 new art)*

Uses the five packaged-but-unused **alt** vignettes
(`PixelIcons.altVignetteFor`, `pixel_icons.dart:142`), whose only current
consumers are the atlas inspector and the travel transition.

- **Asset and scale.** `PixelScene.vignette(path, viewportHeight: 132,
  alignment: Alignment.topCenter)`. `PixelScene` already guarantees the
  contract: `OverflowBox` at the exact 384×176 display size inside a `ClipRect`,
  `BoxFit.fill` on a box that is exactly native size, `FilterQuality.none`
  (`pixel_asset.dart:236-271`). **Integer scale 1. Crop, never stretch. Nothing
  new is needed to satisfy L-18.**
- **Band height 132, top-anchored.** Not 176. 176 is the Adventure stage's
  height, and reusing it would make every tab look like the Adventure tab.
  Top-anchoring crops away the ground line where the Adventure stage puts its
  figures — that crop is precisely what distinguishes *backdrop* from *stage*.
- **Content overlap 36.** The screen's `ListView` top padding becomes
  `132 − 36 = 96`, so ~96 dp of picture is genuinely visible and the first card
  **sits on** it — a plate tipped onto a page. Without this the band would be
  visible only through 16 dp gutters and 10 dp gaps, and the change would be
  wasted.
- **Scrim, two layers.**
  1. Flat `0xB814120F` (~72% of the page ground) across the band. Heavier than
     `LocationStage._backdropScrim` (`0x8C`, ~55%) because nothing stands on
     this band — it sits behind *type*, and type wins.
  2. Vertical fade `0xB814120F → 0xFF14120F` over the lower 48 dp, so the band
     dissolves into the page instead of ending on a line.
- **Horizontal.** The vignette is 384 px; phones are 320–430 dp. Below 384 the
  scene clips (correct, and the framing already puts nothing load-bearing at the
  edges). Above 384 add a 24 dp fade to `surfaceGround` at both ends so no hard
  vertical edge appears. That fade is chrome, not pixel art — a gradient there
  is legal.
- **Absolute rule: no type ever sits on the band.** That is what removes the
  contrast question entirely rather than answering it per screen.
- **Files.** New `lib/ui/components/screen_backdrop.dart`. Wrap in a `Stack` and
  change top padding at: `skills_screen.dart:47-53`,
  `character_screen.dart:54-60`, `inventory_screen.dart:99-107`,
  `craft_screen.dart:266-273`, `step_tracker_screen.dart:98`,
  `goal_board_screen.dart:95`, `bestiary_screen.dart:89-95`. Adventure and World
  are excluded — both already carry art.
- **Risks.** (i) Five tabs sharing one image can read as wallpaper; mitigated by
  using the alt framing so the primary stays exclusive to the Adventure stage,
  and accepted otherwise — you *are* in one place. (ii) `altVignetteFor` returns
  null for an unknown location: the widget must render `SizedBox.shrink()` and
  expose a `contentTop` derived from the same nullability, or the layout jumps.
  (iii) Memory is a non-issue — six live `IndexedStack` children referencing at
  most one cached asset.

### N-3 — Field Notes gets the creature sprites  *(≈15 lines, one screen, enormous for that screen)*

262 combat files exist; the one screen about creatures shows zero. Each **Known**
entry gets `f0` of its idle via `combat_assets.dart` at 64 ×1 in an
`InsetWell.square(contentSize: 64)`, around `bestiary_screen.dart:121-140`.
**Risk:** an unknown creature must not show its sprite — that would spoil the
Known state. Gate on `known`; show `PixelIcons.itemUnknown`'s slab otherwise.

### N-4 — The two-level spacing rhythm  *(P-5 + P-6 plus ~6 call sites)*

Applied at `skills_screen.dart:59-62` (five trades are five subjects),
`craft_screen.dart:316-329` (readiness bands already have headings — give them
the subject form), `bestiary_screen.dart:110-120` (region sections), and the
Inventory group boundaries. **Risk:** ~10 dp per boundary on already-tall
screens — Skills gains 40, Craft ~30. Count boundaries before applying, and
accept nothing above 40 dp per screen without a device check.

### N-5 — One hero plate per screen  *(P-8 plus 4 call sites)*

Character: the portrait card. Skills: the highest-level standing (derivable from
`skillStandings` — **no new projection**, ties broken by list order). Inventory:
the equipped loadout, promoted from a one-line summary to three 48 px icons.
Craft: the selected recipe, or the first craftable. Adventure and World already
have theirs. **Risk:** an empty hero (nothing equipped, nothing craftable) reads
worse than no hero — P-8's not-rendered rule covers it.

### N-6 — Skill Detail gets the work backdrop  *(≈4 lines)*

`AmbientAssets.workBackdropFor(skill)` is authored, integrated, and consumed on
exactly one surface (`location_stage.dart:147-149`). The same `ScreenBackdrop`
keyed by skill makes five trade pages five different places for zero new art.

### N-7 — Ship the PanelSkin API with the painted fallback  *(P-1, P-2, P-3; zero visible change)*

No pixel moves. It is the entire reason a later art drop is one map entry rather
than 34 edits.

**Proportionate verification for the whole set** (`RULES.md` G-1; the concrete
risk is named before the work): one widget test that builds every screen with
`PanelSkins._authored` empty and asserts the golden matches today's painted
output. That single test is also the enforcement mechanism for §6.

---

## 5. What only PixelLab can author

**Zero generations are available now** — 25 remain and all are reserved for the
atlas emergency. Everything below is specified for the post-refresh queue and
must not start before it. Nothing here may be substituted with code-drawn art
(`RULES.md` A-1).

| Batch | Priority | Contents | Notes |
|---|---|---|---|
| **F — step glyph** | **1** | The replacement for the temporary turquoise boot (`OD-03`) | Standing debt. It is the symbol of the thing the product is about and it appears beside every step figure in the app. It outranks every frame. One mark used everywhere, in the two-colour pairing `walking_glyph.dart` requires. |
| **A — the chassis frame** | **1** | 4 corners @16×16, 4 tileable edges @16×8 / 8×16 | The one frame family (DNA-6). Journal-plate: warm timber/leather, upper-left key light, authored to the app's 14/10 radii so raster and painted fallback are interchangeable. **The centre is not art.** Edges must pass a deterministic tile-seam script before acceptance — no generations, and it catches the failure blind QA would miss. |
| **B — five trade bands** | **2** | 384×32 opaque banners, one per skill | The job the ~6 L* wash cannot do. Framed like a vignette: nothing load-bearing at the edges (`pixel_asset.dart:170-179`). |
| **G — the workbench vignette** | **2** | One 384×176 location-class vignette | So Craft-at-rest has a place. Content gate applies: no market stalls, no coin, no prices (`PIXELLAB_STYLE_SPEC_01` §10a). |
| **C — surface grains** | **3** | 4 seamless 32×32 tiles: oilcloth, bench oak, journal leaf, cork | Drawn at ×2 with `ImageRepeat.repeat`, ≤6 L* variation. **Grain, not pattern.** Must be seamless by construction and pass the same seam script. |
| **D — the modal frame** | **3** | 4 corners + 4 edges, heavier | The one place an ornate edge belongs. A modal must feel like an interruption. |
| **E — ornaments** | **4** | ~6 discrete pieces: corner pin, tab leather, hero cartouche, rule terminus | Once-only shapes that **cannot** live in a tiled edge run. Each positioned by Flutter as an ordinary `PixelAsset`. |

**Explicitly not PixelLab's, and it must not be asked:** radii, the border
colour, type, scrim values, spacing, tab-bar geometry, any state (pressed,
disabled, selected), any number.

**QA inherits the existing gates unchanged** (`PIXELLAB_STYLE_SPEC_01` §10),
plus one addition earned by the tiled construction: **a frame must be reviewed
at two panel heights whose repeat counts differ**, because a seam that reads at
one height and beats at another is invisible in a single-height review.

---

## 6. The line

### Flutter keeps owning, permanently

- **All text.** No word is ever raster. Raster type kills text scaling,
  localisation and accessibility, and is how a pixel UI ages badly.
- **All layout, all sizing, all hit targets.** A frame is painted *around* a box
  Flutter has already measured. It never sets a width.
- **Every dynamic value** — counts, levels, fills, fractions, distances.
- **Every state** — pressed, disabled, selected, locked. A frame has one state.
- **Accessibility** — `Semantics`, text scaling, reduced motion, contrast.
- **Responsiveness** — the frame tiles to whatever it is given.

### Raster owns

- **Content** — creatures, items, places, the Traveler. Already true.
- **Material** — the outer edge of a panel, the grain of its interior, and
  discrete positioned ornaments.

### The rule that prevents "the whole UI is images"

> **A raster asset in the interface may occupy only (a) the outer 12 logical px
> of a panel's edge, or (b) a panel's interior as a tiled grain of ≤6 L*
> variation, or (c) a discrete ornament positioned by Flutter. It may never
> carry a word, a number, a state, or a boundary that Flutter needs to measure.**
>
> **The test: with every frame asset removed from the build, the app must still
> work, still read, and still pass accessibility. If it does not, the line has
> been crossed.**

That test is not rhetorical — it is N-7's empty-registry golden, and it runs in
CI on every change.

---

## 7. UNRESOLVED — owner decisions this document does not take

- **The identity washes.** `SectionCard.wash` and the region/skill deeps are
  authored within ~6 L* of `surfaceCard` — deliberately sub-perceptual, and
  therefore structurally unable to carry identity. Two honest ends: **(a)**
  delete the wash and let the trade bands (Batch B) carry identity, or **(b)**
  re-value the deeps to ~12–14 L* and render them as a **band**, not a gradient.
  This document recommends **(b)** and does not take it. The deeps are Fable V2
  experimental tokens that graduate with their branch, so re-valuing them is a
  decision, not an implementation detail (`RULES.md` G-3).
- **Whether the section eyebrow survives the header inversion** (N-1 risk 1).
  Device evidence decides; both outcomes are specified.
- **Whether `PixelFrame` ships before its first asset.** Shipping a renderer
  with no assets is dead code; shipping it later makes the drop-in claim
  aspirational. This document assumes it ships with a committed **test-fixture**
  PNG (a test asset is not player-facing art, so A-1 does not apply) — but that
  is a judgement call and is flagged rather than assumed.

---

## Related

- `GAME_BIBLE/ART/ART_DIRECTION.md` — outranks this document (L-16, L-17, L-18)
- `GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md` —
  production rules, prohibited drift, QA gates
- `Scripts/check-ui-boundary.sh` — the image-site guard §3 P-2 requires extending
- `JOURNAL/OPEN_QUESTIONS.md` — OD-03 (the step glyph), Q-02
