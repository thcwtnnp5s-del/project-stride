# PixelLab UI Production Plan — the post-refresh queue

```
STATUS: production queue · NOT CANON · NOTHING HERE HAS BEEN GENERATED
Author: BUILD-D (PixelLab UI production planner) · Date: 2026-08-31
Branch: presentation-combat-evolution-01
Authority: DECISIONS/0029_UI_ART_DIRECTION_AMENDMENT.md (owner ruling,
2026-08-31) amending GAME_BIBLE/ART/ART_DIRECTION.md L-18.
Zero generations were spent writing this document. Zero may be spent
executing it before 2026-09-16.
```

**What this is.** The per-asset production queue `DECISIONS/0029` § Consequences
requires: dimensions, tiling strategy, transparency, palette, material identity,
verbatim prompt, variants, runtime destination, integrating component, priority
and generation estimate, for every interface asset PixelLab may now author.

**What this is not.** It is not a design document — `GAME_BIBLE/ART/UI_MATERIAL_DIRECTION_01.md`
(DIR-A, DRAFT) is the direction and outranks the taste calls here.
`ART_DIRECTION.md` outranks both (`RULES.md` G-7). Where this plan proposes a
change to DIR-A's draft architecture it says so in the open (§3.4, §4.2) rather
than quietly assuming it.

**Budget position, stated once.** `get_balance` must be called at the start of
every production session; a remembered figure has been wrong three times in this
project's history. The figure of record on 2026-08-31 is **exactly 25
generations, all reserved for the atlas emergency, cycle reset 2026-09-16**.
Account tier is **Tier 2 (Pixel Artisan)**, verified live this session, so
`inpaint_image` at 512×384 is available and the Tier-1 crop→inpaint→paste
workaround in `PIXELLAB_STYLE_SPEC_01.md` §12 is no longer forced (it remains
the better pattern for anything that must be provably unchanged outside the
mask).

---

## 1. The headline, before the tables

**This queue costs roughly 35 committed generations and a ceiling of 60 with
re-rolls, against a 4,516-generation cycle allowance.** Generations are not the
scarce resource here. **Blind review rounds are.** Every number in §9 should be
read as "cheap"; every QA gate in §8 should be read as "the actual cost".

**The first post-refresh window buys Batch A and nothing else.** Reasoning in
§9.2. Do not parallelise batches behind an unaccepted chassis: `ART_DIRECTION.md`
L-18 as amended requires one frame family app-wide, so if the chassis is wrong,
every asset authored to sit inside it is wrong too.

---

## 2. Preconditions — none of these is optional, all are free

| # | Precondition | Why it blocks generation | Owner |
|---|---|---|---|
| **P-0** | `get_balance` called live; the atlas reserve is confirmed released or separately funded | Three prior sessions planned from a remembered balance and were wrong | producer |
| **P-1** | **The palette guard exists and passes** (§7) | L-16 reserves `#58D6C0` system-wide and **nothing enforces it today**. UI art is the first art authored *near* interface colour, so it is the first that can collide. `PIXELLAB_STYLE_SPEC_01.md` §4.1 concedes the generated palettes only *appear* clear of teal — "an impression, not a measurement" | tooling |
| **P-2** | `PixelFrame` exists in `lib/ui/components/pixel_asset.dart`, with **four** independent edge fields (§3.4) | A frame drawn any other way slips the boundary guard and renders bilinear | UI engineer |
| **P-3** | `Scripts/check-ui-boundary.sh` catches `DecorationImage`, `paintImage` and `AssetImage` outside `pixel_asset.dart` | Pre-existing hole; becomes live the moment anyone acts on 0029 | tooling |
| **P-4** | `Scripts/art/check-tile-seam.js` exists (§8.3) | A seam that reads at one panel height and beats at another is invisible in a single-height review | tooling |
| **P-5** | `.gitignore` carries `!GAME_BIBLE/ART/exploration/UI_MATERIAL_01/out/**` | `exploration/**` is ignored by default; an untracked packaging source is a latent clean-checkout `--check` failure (this exact defect shipped once already — see `PIXELLAB_ASSET_INVENTORY.md` §2) | producer |
| **P-6** | The empty-registry golden test from DIR-A N-7 is green | It is the CI form of 0029's enforcing test: with every frame asset removed, the app still lays out, reads, navigates and passes accessibility | UI engineer |

### 2.1 Where files live, and who writes them

| Class | Exploration source (tracked) | Runtime destination | Writer | Declaration |
|---|---|---|---|---|
| Frames | `GAME_BIBLE/ART/exploration/UI_MATERIAL_01/out/frame/` | `assets/ui/v1/frame/` | **hand-maintained**; the sheet ships **whole**, uncut | `pubspec.yaml`, **file by file** |
| Surfaces, ornaments | `…/out/{surface,ornament}/` | `assets/ui/v1/{surface,ornament}/` | **hand-maintained**, folded/cut by `UI_MATERIAL_01/tools/cut.js` (A-2) | `pubspec.yaml`, **file by file** |
| Trade bands, workbench vignette | `GAME_BIBLE/ART/exploration/UI_MATERIAL_01/out/band/` | `assets/art/v1/band/`, `assets/art/v1/work/` | **`Scripts/art/package-art.js` only** | `pubspec.yaml`, file by file |

`assets/art/v1/` has exactly one writer and `--check` fails on any file it did
not emit, on wrong dimensions per family, and on protected-interior drift.
Adding a band therefore means adding a `BANDS` family to `package-art.js` with a
384×48 dimension assertion — not dropping a PNG in the directory. The workbench
vignette needs **no** pipeline change: `work/` already asserts 384×176.

`assets/ui/v1/` is hand-maintained and its `README.md` carries a provenance row
per file. **A shipped file with no provenance row is a QA defect, not a
paperwork oversight** — the standard `AUDIO_ASSET_MANIFEST.md` sets.

---

## 3. The scale, density and tiling contract

### 3.1 Density

Interface chrome is authored at **×2: one source pixel is two logical pixels.**
This is the existing UI density relationship (`RULES.md` G-3), not a new one —
`PixelAsset.nav` is 14 native at ×2, `PixelAsset.glyph` is 12 native at ×2.

**Nothing in this plan exceeds ×2.** Two families are drawn at ×1 and that is
below the ceiling, not above it: the 48-px item icons and the 24-px skill icons
(existing precedent, recorded in `assets/ui/v1/README.md`), and the 384-px
picture-class bands and vignettes in Batch B and G, which belong to the scene
family `PixelScene` already draws at ×1.

**No asset in this queue may be authored at a density chosen to make it
readable.** If a mark is not readable at ×2, the mark is wrong.

### 3.2 The frame geometry, fixed

| Quantity | Chassis (Batch A) | Modal (Batch D) |
|---|---|---|
| Band thickness | **6 src px = 12 logical** | **8 src px = 16 logical** |
| Corner tile | **16 × 16 src = 32 × 32 logical** | **24 × 24 src = 48 × 48 logical** |
| Corner radius | **7 src px = 14 logical** | **7 src px = 14 logical** |
| Edge tile, horizontal | **8 × 6 src = 16 × 12 logical** | **8 × 8 src = 16 × 16 logical** |
| Edge tile, vertical | **6 × 8 src = 12 × 16 logical** | **8 × 8 src = 16 × 16 logical** |
| Repeat period | **8 src px = 16 logical** | **8 src px = 16 logical** |

Radius 7 src = 14 logical is `StrideRadius.card` **exactly**. That is the whole
reason the raster frame and the painted `BoxDecoration` fallback are
interchangeable: the registry can be emptied in one commit and no corner moves.

**Why 6 src px and not 4.** A 4-px band can carry an outer outline, two body
values and an inner line and nothing else. The rendering language
(`PIXELLAB_STYLE_SPEC_01.md` §4) also requires an upper-left key light read
across the band and a closed dark outline on *both* sides of it. Six pixels is
the minimum that carries outer line, lit body, mid body, stitch, shadow body,
inner line.

#### 3.2.1 One arithmetic defect in the landed `PanelSkin`, found by measuring against it

`lib/ui/components/panel_skin.dart` landed this session and its sheet model —
one PNG, corners in the four corners, edges derived from the remainder — is
**better than the two-edge sketch it replaced** and is exactly what Batch A
authors. One line needs fixing before any asset lands:

```dart
double get inset => (corner * scale).toDouble();
```

`corner` is the **corner block**, not the band. A corner block must be at least
as large as the corner radius — 7 src px — plus the band, so it is 16, while the
band is 6. Inset by `corner * scale` costs every panel **32 logical px per side**
of content width. On a 320 dp phone that is 64 of 288, and the frame would be
blamed for a text-wrapping regression it did not cause.

`PanelSkins._reserve` currently predicts `8` and `12`, which back-solves to a
corner block of 4 or 6 src at ×2 — smaller than the 7-src radius the painted
fallback already uses (`StrideRadius.card` = 14 logical). No frame with that
geometry can exist.

**The fix, and it is free today:** `PanelSkin` gains a `band` field measured from
the asset, and `inset => band * scale`. Then `_reserve` becomes **12** for framed
roles and **16** for `modalFrame` — the §3.2 table, and a prediction the art can
actually honour. The reserve is spent right now by the painted fallback, so
changing it costs nothing today and reflows every call site if it is changed
after the first asset ships. This is the architecture owner's change, flagged,
not taken.

### 3.3 The repeat arithmetic, so nobody re-derives it

Card width = screen width − 32 (`StrideSpace.screenGutter` ×2). Horizontal run
between corners = card width − 64 logical.

| Phone | Card width | Run (logical) | Run (src) | Tiles of 16 logical |
|---|---|---|---|---|
| 320 dp | 288 | 224 | 112 | **14.0 — exact** |
| 360 dp | 328 | 264 | 132 | **16.5** |
| 393 dp | 361 | 297 | 148.5 | **18.5625** |
| 430 dp | 398 | 334 | 167 | **20.875** |

Four supported widths, four different fractional remainders, one of them exact.
This is the seam-review matrix and it is not negotiable down to one width.

Note the 393 dp row: the run is an **odd** number of logical pixels, so the last
tile is clipped at an offset that cuts a *source* pixel in half. **That is a
clip, not a rescale** — permitted, and precisely what `PixelScene` already does
— but it is the reason §3.4's authoring rule is a rule and not a preference.

Vertical runs are content-driven. Review at two: a short card (~120 logical →
3.5 tiles) and a tall card (~336 logical → 17.0 tiles).

### 3.4 What tiles, and what does not

This is the honest section. A frame whose edge cannot tile is a frame that must
be **authored differently**, not wished into working.

**Tiles honestly** — longitudinally invariant material. A run whose appearance is
the same wherever you cut it:

- a leather welt with one continuous stitch line
- straight sawn timber grain running along the run
- a rolled or folded edge with constant section
- a plain plaited or corded edge with period ≤ the tile width

**Does not tile, and must not be attempted in an edge strip** — anything with a
discrete centre. A clipped half of it is a defect at exactly one phone width and
invisible at the other three:

- rivets, studs, nail heads, bosses, medallions, rosettes
- lacing holes, eyelets, buckles, clasps, straps
- any motif whose period is a design statement rather than a texture

**Once-only ornament goes in one of two places, never in a run:** the corner tile
(which is drawn 1:1, once per corner, and has 16 × 16 src to work in), or a
separate `PixelAsset` positioned by Flutter (Batch E/F/H).

**Four edges, not two — and the landed API already gets this right.** DIR-A's
draft `FrameSkin` sketch carried `edgeH` and `edgeV`. A two-edge model
contradicts DNA-2 (key light upper-left, everywhere, always): the bottom run is
shadowed where the top run is lit, and the right run is shadowed where the left
run is lit. Mirroring the top run to make the bottom run flips the light and is a
craft blocker.

The `PanelSkin` that actually landed takes **one sheet** and derives all four
corners and all four runs from their own positions in it, so each is separately
authored by the model with the light in one place. That is the correct model and
Batch A is specified to feed it: **one 96 × 96 master, cut nowhere — the sheet
ships whole.** Nothing in this queue may be produced by reflecting an asset.

**Transparency.** Every frame, ornament and corner asset is authored with
**alpha 0 or alpha 255 and nothing between**. Zero semi-transparent pixels is
what makes integer scaling exact (`PIXELLAB_STYLE_SPEC_01.md` §4), and the
measured baseline across all 871 currently shipped PNGs is **zero**
semi-transparent pixels. This queue does not break that. The interior of a frame
corner is alpha 0 so the panel fill shows through; the outside of the corner arc
is alpha 0 so the page ground shows through.

**Interior surfaces (Batch C) are fully opaque** and carry no alpha at all.

### 3.5 Seamlessness is proved, never prompted

No prompt can make a tile seamless. Two paths, in order:

1. **Deterministic window search.** For an edge run generated as part of a larger
   plate, `tools/cut.js` scores every candidate 8-px window by the sum of
   absolute channel differences between its first and last column, and takes the
   argmin. Deterministic, A-2-clean, and usually enough for a longitudinally
   invariant run.
2. **Mirror fold, ends not duplicated.** A period-6 palindrome `c0 c1 c2 c3 c2 c1`
   tiles without a doubled column at the join; the naive `c0 c1 c2 c3 c3 c2 c1 c0`
   fold doubles `c0` and beats visibly every 8 px. Use the former, never the
   latter.
3. For Batch C interior tiles only, **quarter-mirror fold** of a 64×64 master into
   a 32×32 tile is seamless *by construction*. At ≤6 L\* variation there is no
   feature large enough for the symmetry to be noticeable — which is exactly why
   §5's brief forbids features in a grain.

**`inpaint_image` offset-and-fix is the fallback and costs 20–40 generations per
tile.** It is authorised only after a seam script failure is recorded, not as a
first move.

**A seam metric is a pre-filter, not acceptance evidence.** `RULES.md` A-3 was
written about atlas boundaries and its logic transfers exactly: a numeric seam
score plus a palette conform is triage. Acceptance is a blind read at device
scale, at the four widths in §3.3.

---

## 4. Reuse first — what must NOT be generated

Audited this session. Each verified on disk before it was written down.

| Material | Where | Verified | Use it for |
|---|---|---|---|
| **Six work backdrops, 384 × 176** — `bg_{cooking,smithing,woodworking,foraging,mining,woodcutting}.png` | `assets/art/v1/work/` | measured 384×176, shipped, in `pubspec`, `AmbientAssets.workBackdropFor` already resolves them | **Batch G's entire first pass.** `bg_woodworking` is plank courses; `bg_smithing` is a dark timber band; `bg_cooking` is a rubble stone field. Craft-at-rest gets a place for **zero** generations |
| **Five location vignettes, 512 × 384, unshipped** | `exploration/PIXELLAB_STABILIZATION_01/out/location/` | 5 files present; the shipped 384×176 banners are the `VIGNETTE_CROP {x:56, y:132}` window of these | **Batch I's entire content.** Any other 384×176 window is an A-2 recrop, not authoring. `x` may range 0–128 and `y` 0–208 |
| **Five alt vignettes, already shipped** | `assets/art/v1/location/alt_*.png` | consumed only by the atlas inspector and travel transition | DIR-A N-2's scrimmed backdrops on seven pictureless tabs — **zero generations** |
| **Seven env props** — boulders 48×40, cairn 32×40, dead_tree 40×48, hedgerow 48×32, lone_oak 48×48, pine_clump 48×56, snowdrift 48×32 | `assets/art/v1/env/prop_*.png` | past `--check`, in `pubspec`, **`lib/` references none of them** | Not interface art, and this plan does **not** conscript them into chrome. Recorded here so a future round stops rediscovering them; they belong to a world/atlas decision, not this one |
| **Best masonry in the repo** — `mine_masonry_s41.png` / `_s97.png` | `exploration/PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/` | tracked, unshipped, rejected for **placement**, not craft | **Batch C-3 reference**, and a candidate crop source for the mining trade band if B-3 fails twice |

**And what genuinely does not exist, so nobody plans as if it does:** there is no
parchment, no leather, no metal plate, no frame, no border, no divider, no
ornament and no seamless tile anywhere in this repository. `assets/ui/v1/` is
twenty-one files and every one is a 12–24 px nav or skill glyph. Batch A is
authoring a material class from nothing.

---

## 5. Prompt grammar and the three style clauses

The grammar is `PIXELLAB_STYLE_SPEC_01.md` §7 unchanged:

```
<noun phrase> <presentation clause>: <construction clause> — <style clause>
```

The construction clause is the load-bearing part. Enumerate the *parts* and how
they *attach*. Positive construction beats forbidding the wrong answer; the short
negative tail in each style clause exists because the specific drifts it names
were observed, not imagined (`PIXELLAB_STYLE_SPEC_01.md` §9).

`create_image_pixen` has **no style anchor** — `style_copy` is a
`create_image_pro` parameter at 20–40 generations. Family coherence in this queue
is therefore bought two ways: the style clause appended **verbatim and
unchanged**, and, after Batch A is accepted, a **deterministic index remap of
every later asset onto the accepted chassis ramp** (A-2, zero generations). That
makes kit coherence structural rather than a matter of discipline — the same
move `character_to_portrait` makes for identity.

### SC-UI — appended verbatim to every Batch A, D, E, F and H prompt

> — pixel art interface frame for a dark fantasy travel journal, seen flat and
> straight on, single dark outline along every edge, flat matte shading in a few
> clear steps, light from the upper left, dark warm brown leather and aged timber
> palette with no bright values, no glow, no emissive light, no white specular,
> no cast shadow, no gradient, no text, no numbers, no metal studs, no buckles,
> no clasps, no gemstones, no coins

### SC-SURFACE — appended verbatim to every Batch C prompt

> — pixel art material surface swatch, seen flat from directly above, filling the
> whole frame edge to edge with no border and no object on it, flat matte shading
> in a few clear steps, light from the upper left, very dark low-contrast warm
> palette close to near-black, no glow, no emissive light, no white specular, no
> cast shadow, no gradient, no text, no figures

### SC-BAND — appended verbatim to every Batch B and G prompt

The RCP01 vignette clause, which produced five accepted vignettes at first roll,
with one added darkness requirement:

> — pixel art location illustration, low top-down three-quarter view, single dark
> outline, flat matte shading in a few clear steps, light from the upper left,
> \<regional palette words\>, very dark and low contrast throughout, no text, no
> figures, no glow

---

## 6. The interface-art palette

Interface art sits on `surfaceGround #14120F` and inside `surfaceCard #201C17`.
Its job is to be an **edge and a material**, never a second piece of type.

**Proposed chassis ramp** — five inks, to be replaced by the *measured* ramp of
the accepted A-1 master and then imposed on every later batch by index remap:

| Role | Hex | Why |
|---|---|---|
| Outer outline | `#0F0D0B` | Darker than `surfaceGround`, so a panel's edge separates from the page rather than dissolving into it |
| Body shadow (bottom, right) | `#33291F` | |
| Body mid | `#4A3B2B` | |
| Body light (top, left) | `#6B5A3E` | This is `StrideColors.actionEdge`, already in the palette and already reasoned as "material, not type — below text contrast on purpose" |
| Stitch / construction line | `#7C6A4A` | Ceiling. **Nothing in interface art may exceed the luminance of `textMuted #7C7263`**, or the chrome starts competing with the words |

**Two hard palette rules, both enforceable:**

1. **L-16.** No interface asset may contain any pixel within ΔRGB 10 of
   `#58D6C0`. Measured baseline: across all **871** shipped PNGs, exactly **one**
   file carries teal — `assets/ui/v1/glyph_steps.png`, which is the one file
   L-16 says should. The guard's allowlist is that single path.
2. **Never draw an element in the palette index of the surface behind it.** The
   frame's innermost opaque ring must not be `#201C17`; its outermost must not be
   `#14120F`. A frame drawn in its own background's ink is a frame nobody can see
   and everybody signs off.

**L-19** applies to any warm metal that appears: bronze reads bronze, never
banded worked gold. A banded gold trapezoid is the universal bullion glyph and
asserts a currency Stride does not have.

---

## 7. The palette guard — P-1, and it must exist first

`Scripts/check-art-palette.js`, invoked from `Scripts/verify.sh`, following the
named-rule guard contract the other `check-*.sh` scripts use (exit `0` satisfied,
`1` named violation `STRIDE_GUARD[art-palette.<rule>]`, `2` infrastructure
`STRIDE_INFRA[…]`).

| Rule | Check | Measured baseline today |
|---|---|---|
| `art-palette.teal` | No opaque pixel within ΔRGB 10 of `#58D6C0` in `assets/art/v1/**` or `assets/ui/v1/**`, allowlist `assets/ui/v1/glyph_steps.png` | 871 files scanned, **1 hit, in the allowlisted file** |
| `art-palette.alpha` | No pixel with `0 < a < 255` | 871 files scanned, **0 hits** |
| `art-palette.ceiling` | No opaque pixel in `assets/ui/v1/{frame,surface,ornament}/**` brighter than `#7C7263` in relative luminance | directory does not exist yet, vacuously green |
| `art-palette.substrate` | No `assets/ui/v1/frame/**` pixel equal to `#201C17` or `#14120F` | vacuously green |

It lands green on the current tree. That is the point: a guard that is red the
day it ships gets weakened, and `RULES.md` G-4 exists because that has happened
before.

---

## 8. QA gate — identical for every batch, plus one addition for frames

Inherited unchanged from `PIXELLAB_STYLE_SPEC_01.md` §10. Every item was earned
by a specific failure.

### 8.1 The render set, per asset, every round

**native · ×2 · ×8 · in-context.** All four, always.

- **×2 is the verdict rung.** A round that supplies only an enlarged sheet cannot
  certify play-scale behaviour; when both were supplied, the two scales failed in
  *different cells*.
- **×8 is inspection only** and never carries a verdict.
- **In-context is mandatory for interface art, not optional.** CR-39 exists
  because an element judged against its own border is not judged against the
  frame. For a frame asset, "in context" means a real screenshot of a real
  screen at a real phone width — not a swatch on a grey card.

### 8.2 The reviewers

- **Neutral staging outside the repository**, per `NEUTRAL_STAGING_CHECKLIST.md`,
  on shuffled opaque codes. Self-certification is how one earlier round recorded
  four icons as reading "unambiguously as their nouns" when blind testing found
  only two did.
- **Three separate reviewers, three separate verdicts:** read/naming, set
  coherence, in-context screen. They return different answers on the same set —
  in one recorded round, naming FAIL and coherence PASS.
- **Never supply a menu of connotations before the reviewer looks.** Asking "does
  this read as a slot, a lock, a coin, a timer" tests recognition against a
  supplied list, not unprompted connotation. Ask openly, then read the answer
  against §11.
- **Ask every reviewer what leaked, every round**, and discount accordingly.
  Repo context primes reviewers toward resolving ambiguity in the game's favour,
  which biases *toward* passing.
- **A correction pass is re-reviewed end to end, never spot-checked.**

### 8.3 Frames only — the tile-seam gate

`Scripts/art/check-tile-seam.js` (deterministic, no generations):

1. Assemble the frame at each of the **four widths in §3.3** — 320 / 360 / 393 /
   430 dp — and at **two heights**, short (~3.5 vertical tiles) and tall (~17.0).
   That is eight assemblies. **A single-height review is not a review**: a seam
   that reads at one repeat count and beats at another is invisible in it.
2. For each assembly, report the maximum per-channel discontinuity across every
   tile join, and the position of the worst one.
3. Render each assembly at native and ×2 into the staging set.

Then, and only then, the blind in-context read decides. Per `RULES.md` A-3, the
metric is triage; the read is the verdict.

### 8.4 Machine gates before any human looks

`check-art-palette` (§7) · `check-ui-boundary` (P-3) · `package-art --check`
where the asset goes to `assets/art/v1/` · the empty-registry golden (P-6) ·
`check-tile-seam` for frames. All five green, then stage.

### 8.5 CR-41

The producing session reports **what it changed**. It does not report that it
worked. Every batch report ends `AUTHOR ASSESSMENT: …` and the verdict belongs to
the reviewers and the device.

---

## 9. The batches

Ordered as a ready-to-run queue. Every asset carries: purpose · dimensions ·
tiling · transparency · palette · material · prompt · variants · destination ·
integrating component · priority · generations.

---

### BATCH A — The chassis frame kit · **PRIORITY 1** · ~4 generations

**Purpose.** The one frame family, app-wide (L-18 as amended: "one chassis family
app-wide; screens differ by band, surface and picture, never by eleven different
borders"). It is the single change that lifts thirty-one identical Skia
rectangles off the generic read at once.

**Material identity.** A journal plate: oiled dark leather welt over an aged
timber edge, one fine stitch line running the length of every run. Not metal —
metal with fastenings reads as armour or as a slot. Not gold — gold reads as
currency (`RULES.md` P-6).

**Call.** `create_image_pixen(description = P-A1, width = 96, height = 96,
no_background = true, view = "side", outline = "single color outline")`.
`view = "side"` is **unproven for this asset class** — every prior round in this
repo used `low top-down` or `high top-down`. Record the finding on round 1; if
`side` produces a three-quarter frame, fall back to `high top-down`.

**Risk, and its free mitigation.** The model may fill the frame's centre instead
of leaving it empty. If it does, the interior is removed by the flood-fill alpha
key `package-art.js` already implements (the vignette background routine) —
deterministic, A-2, zero generations. Do **not** re-roll for this.

#### The asset — one file

| File | Src px | Corner block | Band | Tiling | Alpha | Destination |
|---|---|---|---|---|---|---|
| `chassis_96.png` | 96 × 96 | 16 | 6 | corners 1:1; the 64-px run on each side is the repeating strip, period 8 | 0 or 255 only | `assets/ui/v1/frame/chassis_96.png` |

**One generation produces one shipped file.** The landed `PanelSkin` takes the
sheet whole and derives all four corners and all four runs from their own
positions in it, so the model draws each with the light in one place and nothing
is cut, mirrored or reassembled. The 96 master leaves a 64-px run per side —
ample for the §3.5 seam-window search, which selects the tiling offset within the
run rather than extracting a file.

**`PanelSkin` row this produces:**

```dart
PanelRole.card: PanelSkin(
  assetPath: 'assets/ui/v1/frame/chassis_96.png',
  nativeWidth: 96, nativeHeight: 96,
  corner: 16, band: 6, scale: 2,          // band: see §3.2.1
),
```

**Variants.** None. A frame has one state: pressed, disabled, selected and locked
are Flutter's, permanently. The **reward** variant is Batch E and is a palette
remap of this same file, not a second family.

**Integrating component.** `PixelFrame` in `lib/ui/components/pixel_asset.dart`,
registered in `PanelSkins.authored` (`lib/ui/components/panel_skin.dart`) under
`PanelRole.card` and reused verbatim by `heroPlate` and `boardSlip`; reached from
~34 call sites through `SectionCard(role:)` with no call-site edits.

**Generations.** 1 accepted + 3 re-roll budget = **4**.

> **P-A1** (`chassis frame master`, 96 × 96, transparent):
>
> `An empty rectangular panel frame from a traveller's leather-bound journal, laid flat and seen straight on, with nothing at all inside it: a narrow border six pixels thick running unbroken the whole way round a completely empty centre, built as an outer dark line, a band of oiled dark brown leather welt, and an inner dark line; one fine paler stitch line runs along the middle of the leather band from corner to corner without interruption; the leather is lit along the top and left runs and shadowed along the bottom and right runs; the four corners turn as rounded quarter circles about seven pixels in radius with the leather and the stitch line continuous around each turn; nothing is fastened to the border anywhere along its length — pixel art interface frame for a dark fantasy travel journal, seen flat and straight on, single dark outline along every edge, flat matte shading in a few clear steps, light from the upper left, dark warm brown leather and aged timber palette with no bright values, no glow, no emissive light, no white specular, no cast shadow, no gradient, no text, no numbers, no metal studs, no buckles, no clasps, no gemstones, no coins`

---

### BATCH C — Surface grains · **PRIORITY 2** · ~8 generations

Promoted above Batch B deliberately: a grain only shows *inside* a framed panel,
so it completes Batch A's material story on the same device review, and it is the
cheapest identity per generation in the queue.

**Purpose.** A panel's interior as a low-variation tiled surface — the second of
the three things L-18 as amended permits a raster asset to be.

**The hard constraint, stated plainly.** `≤ 6 L*` total variation. **Grain, not
pattern.** Anything a reviewer can point at is a feature, and a feature repeated
every 64 logical px is wallpaper. If a tile is interesting, it is wrong.

**Method.** Generate a 64 × 64 opaque master; produce the shipped 32 × 32 tile by
**quarter-mirror fold** (§3.5 path 3), which is seamless by construction. At ≤6
L\* there is no feature large enough for the symmetry to register.

**Call.** `create_image_pixen(description = P-C*, width = 64, height = 64,
no_background = false, view = "high top-down", outline = "single color outline")`.

| File | Src px | Tiling | Alpha | Material | Serves | Status |
|---|---|---|---|---|---|---|
| `grain_oilcloth.png` | 32 × 32 | repeats X and Y, period 32 src / 64 logical | fully opaque | waxed dark olive-brown canvas | `PanelRole.kitTray` — Inventory | committed |
| `grain_cork.png` | 32 × 32 | as above | fully opaque | dark cork board | `PanelRole.boardSlip` — Goal Board | committed |
| `grain_journal_leaf.png` | 32 × 32 | as above | fully opaque | heavy dark laid paper | `PanelRole.heroPlate` — the one focal panel on any screen | committed |
| `grain_bench_oak.png` | 32 × 32 | as above | fully opaque | scrubbed oak bench top | **no role exists for it** — see below | **held** |

**Destination.** `assets/ui/v1/surface/`.
**Integrating component.** `PanelSkin.surfacePath` / `surfaceNative: 32`, drawn
by `PixelFrame` at ×2 inside the frame's content box.
**Variants.** None.

**Why bench oak is held, and this is a real constraint, not caution.** The
`PanelRole` enum that landed is a deliberately closed set of six —
`card, heroPlate, modalFrame, kitTray, combatFrame, boardSlip` — and its doc
comment is explicit that roles name *kinds of surface, not screens*, because the
failure mode this direction is most likely to produce is eleven unrelated
borders. There is no `benchPlate`. Assigning oak to `heroPlate` would put a
workbench behind the focal panel of **every** screen, which is exactly the
category error the closed set exists to prevent.

Two honest ends, and this plan does not take either: add a `benchPlate` role
(one line, and it starts the per-screen slide the enum was closed to stop), or
let Craft's identity be carried by Batch G's backdrop and Batch B's material,
which is what the rest of the queue does. **Recommendation: the second.** Ship
three grains.

**Generations.** 3 accepted + 3 re-roll budget = **6**, plus **2 conditional**
for bench oak if a role is added. If a tile fails the seam gate after mirror-fold
— which should be impossible by construction, so record it loudly if it happens —
the `inpaint_image` offset fix is 20–40 and must be escalated before it is spent.

> **P-C1** (`grain_oilcloth`): `A patch of waxed dark oilcloth stretched flat, seen from directly above, filling the whole frame: a close even weave of very dark olive brown waxed canvas, the weave reading as a fine regular crosshatch of two values only, a faint even mottling across it, no seam, no hem, no stitching, no fold and no object lying on it — pixel art material surface swatch, seen flat from directly above, filling the whole frame edge to edge with no border and no object on it, flat matte shading in a few clear steps, light from the upper left, very dark low-contrast warm palette close to near-black, no glow, no emissive light, no white specular, no cast shadow, no gradient, no text, no figures`
>
> **P-C2** (`grain_bench_oak`): `A patch of a scrubbed oak workbench top, seen from directly above, filling the whole frame: straight long grain running left to right in narrow dark brown and slightly lighter brown lines, a few short fine chisel nicks, no plank joint, no board edge, no knot, no tool and no object lying on it — [SC-SURFACE verbatim as above]`
>
> **P-C3** (`grain_journal_leaf`): `A patch of an old dark journal leaf, seen from directly above, filling the whole frame: heavy laid paper in a very dark warm brown, faint horizontal laid lines and a slightly uneven fibre mottle, no edge, no tear, no crease, no writing, no ruling and no object lying on it — [SC-SURFACE verbatim as above]`
>
> **P-C4** (`grain_cork`): `A patch of an old cork noticeboard, seen from directly above, filling the whole frame: dense dark brown cork granules in two or three close values, an even irregular grain across the whole surface, no frame, no border, no batten, no pin holes, no paper and no pin in it — [SC-SURFACE verbatim as above]`

---

### BATCH B — The skills kit: five trade bands · **PRIORITY 2** · ~10 generations

**Purpose.** The job the identity wash structurally cannot do. `SectionCard.wash`
and the skill deeps are authored within ~6 L\* of the card colour — deliberately
sub-perceptual, and therefore unable to carry identity. A picture can.

**Dimensions, and why not DIR-A's 384 × 32.** **384 × 48**, drawn ×1. The
icon-plus-name row it sits behind is a 24-px icon plus padding, ≈ 44–48 logical
tall; a 32-px band ends mid-row and reads as a stripe laid across the card rather
than as the ground the row stands on. 48 also gives the model a canvas it can
compose material in.

**Horizontal behaviour.** 384 px against card widths of 288–398 logical, so the
band **clips** at every supported width, exactly as the vignettes do. Nothing
load-bearing in the outer 48 px of either end. This is a clip, never a stretch.

**Call.** `create_image_pixen(description = P-B*, width = 384, height = 48,
no_background = false, view = "low top-down", outline = "single color outline")`.
384 × 176 opaque pixen is proven (RCP01, five accepted vignettes); **384 × 48 is
an 8:1 aspect and is not.** If the model composes a scene rather than a strip,
author at **384 × 96** and take the lower 48 by deterministic crop — A-2, no
extra generation, and it also gives the composition somewhere to put a horizon it
was always going to draw.

**Brightness.** These will come back too bright for a near-black card. The
correction is the **A-2 luminance remap** already used to conform the step glyph,
not a re-roll. Budget zero generations for it and one integration step. Scrim
belongs to `ScreenBackdrop`, not to the asset.

| File | Skill | Material | Palette words for SC-BAND |
|---|---|---|---|
| `band_foraging.png` | Foraging | meadow herb ground | muted olive green, khaki and dark earth brown |
| `band_woodcutting.png` | Woodcutting | stacked sawn oak rounds | muted brown, grey-brown and dull ochre |
| `band_mining.png` | Mining | cut granite face and spoil | muted grey, slate and dark stone brown |
| `band_smithing.png` | Smithing | cold soot-blacked forge floor | soot black, dark grey and dull rust brown |
| `band_cooking.png` | Cooking | cold hearth and ash | dull brick red, warm grey and ash |

**Destination.** `assets/art/v1/band/band_<skill>.png`, emitted by a new `BANDS`
family in `package-art.js` asserting 384 × 48.
**Integrating component.** A `PixelScene`-class clipped band inside an ordinary
`SectionCard(role: PanelRole.card)`; `skills_screen.dart`. **A band is not a
role.** The landed `PanelRole` set is closed at six and names kinds of surface,
not screens; a trade band is a *picture placed inside* a card by Flutter, which
is the third thing L-18 as amended permits and needs no registry entry at all.
**Variants.** None. Five assets, five skills, no states.
**Generations.** 5 accepted + 5 re-roll budget = **10**.

**Two semantic gates specific to this batch.** The smithing band must contain
**no glowing metal and no fire** — emissive colour was an observed drift (D-2,
"ore vs magma judged a coin-flip") and a glow in a skill band reads as heat, then
as a process, then as a timer. The cooking band must contain **no flame and no
embers**, for the same chain. Both are written into the prompts.

**L-16 gate.** The mining band's blue-grey must stay far off 170°; the palette
guard is the check, not the eye.

> **P-B1** (`band_foraging`): `A low horizontal strip of meadow herb ground seen from just above and in front: dense low olive green herbage and small dark leaf clumps running the whole width of the frame, a few slender seed stalks, dark damp earth showing between the clumps, the ground continuing off both the left and right edges — pixel art location illustration, low top-down three-quarter view, single dark outline, flat matte shading in a few clear steps, light from the upper left, muted olive green, khaki and dark earth brown, very dark and low contrast throughout, no text, no figures, no glow`
>
> **P-B2** (`band_woodcutting`): `A low horizontal strip of a woodcutter's stacked timber seen from just above and in front: sawn oak rounds stacked on their sides in courses running the whole width of the frame, pale end grain rings on the cut faces, dark bark on the curved sides, a few loose split billets, the stack continuing off both the left and right edges — [SC-BAND, muted brown, grey-brown and dull ochre]`
>
> **P-B3** (`band_mining`): `A low horizontal strip of a cut rock face seen from just above and in front: broken grey granite blocks and fractured stone running the whole width of the frame, a scatter of loose spoil rubble along the base, a few dull dark ore flecks in the fractures, the rock face continuing off both the left and right edges — [SC-BAND, muted grey, slate and dark stone brown]`
>
> **P-B4** (`band_smithing`): `A low horizontal strip of a forge floor seen from just above and in front: soot blackened stone flags running the whole width of the frame, dark hammer scale scattered across them, a heap of cold charcoal along the base, the floor continuing off both the left and right edges, no fire, no embers and no glowing metal anywhere — [SC-BAND, soot black, dark grey and dull rust brown]`
>
> **P-B5** (`band_cooking`): `A low horizontal strip of a cold hearth floor seen from just above and in front: worn fire brick and flat hearthstone running the whole width of the frame, a bank of cold grey ash and a few charred sticks along the base, an empty iron trivet standing to one side, the hearth continuing off both the left and right edges, no flame and no embers anywhere — [SC-BAND, dull brick red, warm grey and ash]`

---

### BATCH D — The combat kit · **PRIORITY 3** · ~4 generations

**Purpose.** The combat modal is the one place an ornate edge belongs, because a
modal must feel like an interruption. It is the **only** licensed second frame
and it earns that by being modal, not by being combat.

**The rule it must obey.** It is the same material, more of it — heavier leather,
a thicker band, an iron strap at the corner turn. It is **not** a second visual
language. If a reviewer describes it as a different object from the chassis,
that is a failure of DNA-6 and the asset is rejected however well drawn.

**The semantic hazard, named before it is drawn.** Iron corner fittings plus
round heads read as **armour plate**, then as an **equipment slot**, and L-15 /
L-17 make a wrong semantic a blocker regardless of craft. Mitigations written
into the prompt: the strap is a flat L laid over the turn, its ends cut square;
**no round heads, no rivets standing proud, no buckle.** A small warm round metal
disc at ×2 is the coin register, and Stride has no currency (`RULES.md` P-6).

**Call.** `create_image_pixen(description = P-D1, width = 128, height = 128,
no_background = true, view = "side", outline = "single color outline")`.

| File | Src px | Corner block | Band | Tiling | Alpha | Destination |
|---|---|---|---|---|---|---|
| `modal_128.png` | 128 × 128 | 24 — carries the iron strap | 8 | corners 1:1; the 80-px run per side repeats, period 8 | 0 or 255 only | `assets/ui/v1/frame/modal_128.png` |

**Integrating component.** `PanelSkins.authored[PanelRole.modalFrame]`, drawn by
`PixelFrame`. `PanelRole.combatFrame` — which the landed enum distinguishes from
`modalFrame` because "combat is not an interruption, it is a place" — takes the
**chassis** from Batch A, not this. The combat **stage** is unchanged; it already
carries scene art and 262 combat files, and this batch adds nothing inside it.
**Variants.** None. A frame has one state; hit, brace, victory and defeat are
Flutter's, and the danger/defence tokens already exist.
**Generations.** 1 accepted + 3 re-roll budget = **4**.

> **P-D1** (`modal frame master`, 128 × 128, transparent): `An empty rectangular panel frame from a heavy strapped campaign chest lid, laid flat and seen straight on, with nothing at all inside it: a border eight pixels thick running unbroken the whole way round a completely empty centre, built as an outer dark line, a band of dark oiled leather laid over aged timber, and an inner dark line; along each of the four runs the leather is plain and unbroken from corner to corner; at each of the four corners a flat blackened iron strap is laid over the turn in an L, its two ends cut square and its face flat and unpolished with no round heads and nothing standing proud of it; the leather is lit along the top and left runs and shadowed along the bottom and right runs; the corner turns are rounded quarter circles about seven pixels in radius — [SC-UI verbatim]`

---

### BATCH E — The reward kit · **PRIORITY 3** · ~3 generations

**Purpose.** L-18 as amended lists reward frames. This batch authors almost none
of one, and that is the finding.

**E-a — The reward frame is Batch A, remapped. Zero generations.** The reward
layer's warmth is already a palette fact: `rewardLightInk #E8C883`,
`rewardGlow`, `rewardWashTop`. A warm-lit variant of `chassis_96.png` is a
**deterministic index remap** (A-2 — "palette or index remap … permitted in
code, provided they invent no new object or silhouette"). It is also the *right*
answer under DNA-6: the same object, in warmer light, is what a reward moment
should look like. Destination `assets/ui/v1/frame/chassis_reward_96.png`,
produced by `UI_MATERIAL_01/tools/remap.js`, registered under
`PanelRole.modalFrame` **only if** the reward layer is judged an interruption and
Batch D's heavier frame is judged too heavy for it — a device call, not a
planning one. The remap ceiling in §6 still binds: nothing may exceed `#7C7263`,
so `rewardLightInk` is the *hue* target, not the *value* target.

**E-b — The divider rule and its two termini. 3 generations.** The one genuinely
missing reward piece: the ornament that caps the rule above a reward list.

Authored as **one 64 × 16 plate carrying both ends**, not one end mirrored.
Mirroring an ornament flips its key light to the upper right and breaks DNA-2 —
a small, cheap, permanent error. One plate, three cuts:

| File | Src px | Role | Alpha | Destination |
|---|---|---|---|---|
| `rule_cap_left.png` | 12 × 16 | positioned once, left end | 0 or 255 | `assets/ui/v1/ornament/` |
| `rule_cap_right.png` | 12 × 16 | positioned once, right end | 0 or 255 | `assets/ui/v1/ornament/` |
| `rule_run.png` | 8 × 4 | repeats +X, period 8, between the caps | 0 or 255 | `assets/ui/v1/ornament/` |

**Integrating component.** Three `PixelAsset`s in a `Row`, placed by
`reward_layer.dart` / `reward_beat.dart`; the run tiles through `PixelFrame`'s
edge path.
**Variants.** None.
**Generations.** 1 accepted + 2 re-roll = **3**.

**Explicitly not authored here:** a halo, a burst, a radiance or a starburst
behind a reward icon. A four-point star reads as a *sparkle*; a radial burst is a
gradient by another name and gradients are forbidden; and a ring behind an item
is one blind-review round away from reading as a rarity tier. Warm reward light
is already a Flutter token and stays one.

> **P-E1** (`divider rule plate`, 64 × 16, transparent): `A single horizontal divider rule with a turned terminus at each end, laid flat and seen straight on, with nothing above or below it: a plain straight dark bar two pixels thick running the full width of the frame, and at each end the bar finishing in a small flat cap of folded dark leather closing the end off, the left cap and the right cap each drawn independently with the light falling from the upper left on both of them, nothing else anywhere in the frame — [SC-UI verbatim]`

---

### BATCH F — The inventory and equipment kit · **PRIORITY 3** · ~3 generations

**Purpose.** L-18 as amended lists inventory and equipment treatments. This batch
authors **one** asset and refuses the obvious one.

**What it refuses, and why.** No slot chrome. No recessed socket, no silhouette
hint, no compartment plate. Two independent reasons and either alone is
sufficient: (i) L-17 makes an interface element that confidently reads as a slot
a defect, and a drawn slot *is* one; (ii) a slot is a **boundary Flutter needs to
measure**, which 0029's boundary clause forbids outright. `InsetWell` already
does this job in code and DIR-A is right that it is the most honest material in
the app. It is not touched.

**So the inventory kit is:** Batch A's chassis + Batch C's oilcloth grain +
**one** ornament.

**F-1 — Mounting corners.** Four small leather corner tabs, the photo-album
register: *mounted and kept*, not *slotted and equipped*. They mark the equipped
loadout as the screen's hero plate without asserting a container.

Authored as **one 64 × 64 plate carrying all four tabs around an empty square**,
so the model draws each with the light in one place. Four cuts of 12 × 12 src
(24 × 24 logical).

| File | Src px | Role | Alpha | Destination |
|---|---|---|---|---|
| `strap_corner_{tl,tr,bl,br}.png` | 12 × 12 | positioned once each, by Flutter | 0 or 255 | `assets/ui/v1/ornament/` |

**Integrating component.** Four `PixelAsset`s in a `Stack`, placed by the
equipped-loadout hero plate in `inventory_screen.dart`.
**Variants.** None.
**Generations.** 1 accepted + 2 re-roll = **3**.

> **P-F1** (`mounting corners plate`, 64 × 64, transparent): `Four leather mounting corners arranged at the four corners of an empty square, laid flat and seen straight on, with nothing at all between them: each corner a small flat triangular tab of dark oiled leather folded over the corner it sits on, its two outer edges straight and its inner edge a straight diagonal, each of the four tabs drawn independently with the light falling from the upper left on all of them, the whole centre of the frame completely empty — [SC-UI verbatim]`

---

### BATCH H — The board and ledger kit · **PRIORITY 4** · ~3 generations

**Purpose.** L-18 as amended lists board and ledger treatments. Board = Batch A's
chassis + Batch C's cork grain + **one** ornament. Ledger — the Step Tracker —
takes **no** art at all: it is the one screen whose job is comparison, its
density is correct, and a frame around each day row would be the table-of-cards
failure repeated in a nicer material.

**H-1 — The tack.** The mark that says *this goal is the tracked one*.

**The register hazard, named before it is drawn.** A pin head is a small round
disc. At 24 logical px a small round warm-metal disc is a **coin**, and Stride
has no currency. The prompt therefore specifies the head **seen edge-on, a flat
rectangle, foreshortened, never a circular face**, with the shank visible going
into the surface at an angle. The shank is what makes it a fixing rather than a
token.

**Size.** Authored at 16 × 16 (PixelLab's floor), trimmed to its own bounding box
and shipped at whatever ≤ 12 × 12 that measures — the exact recipe that produced
the shipped step glyph from `boot_bold_a_16.png`. At ×2 that is ≤ 24 logical.

| File | Src px | Role | Alpha | Destination |
|---|---|---|---|---|
| `tack.png` | ≤ 12 × 12 (trimmed from 16 × 16) | positioned once, by Flutter | 0 or 255 | `assets/ui/v1/ornament/` |

**Integrating component.** One `PixelAsset` in the tracked slip's `Stack`;
`goal_board_screen.dart`.
**Variants.** None. The untracked state is the **absence** of the tack, not a
second asset — a "dim tack" would be a state carried in raster, which 0029
forbids.
**Generations.** 1 accepted + 2 re-roll = **3**.

> **P-H1** (`tack`, 16 × 16, transparent): `A single short iron tack driven into wood at a slight angle, seen straight on: a short square dark iron shank running down and to the right into the surface, and at its top a head that is a small flat rectangle seen edge on and slightly foreshortened rather than a round face, one fine paler line along the head's upper left edge, no circular face, no shine, no board and nothing else anywhere in the frame — [SC-UI verbatim]`

---

### BATCH G — The craft and workshop kit · **PRIORITY 4** · **0 generations, then 3 conditionally**

**Purpose.** Craft-at-rest renders no pictorial content, ever. It needs a place.

**First pass: zero generations.** Six 384 × 176 work backdrops are already
shipped, already in `pubspec`, and already resolved by
`AmbientAssets.workBackdropFor` — and consumed on exactly **one** surface today.
`bg_woodworking` is plank courses; `bg_smithing` is a dark timber band.
Key the existing plate to the selected craft category through `ScreenBackdrop`
and Craft has a place this week, for nothing.

**Conditional second pass: 3 generations.** Only if device review finds the
existing plates read as *gathering sites* rather than as a bench — which is a
real risk, since they were authored as work backdrops for gathering and crafting
actions, not as a room. Then, and only then:

| File | Src px | Tiling | Alpha | Destination |
|---|---|---|---|---|
| `bg_workbench.png` | 384 × 176 | none; clipped by `PixelScene` | fully opaque | `assets/art/v1/work/` — **existing family, existing 384 × 176 assertion, no pipeline change** |

**Content gate.** M01 has no buying or selling (`DECISIONS/0004`): **no market
stalls, no shop signage, no price boards, no coin**, however natural they look in
a workshop. **No fire and no forge glow** — same emissive chain as Batch B.
**No figures**: a vignette answers "where am I", not "who is here", and a person
in it re-imports the free-roam promise the presentation scales exist to prevent.

**Integrating component.** `ScreenBackdrop` + `AmbientAssets.workBackdropFor`;
`craft_screen.dart`.
**Generations.** 0 committed, **3 conditional**.

> **P-G1** (`bg_workbench`, 384 × 176, opaque, **conditional**): `A craftsman's workbench in a quiet workshop, seen from just above and in front, completely empty of people: a long scrubbed oak bench running the width of the scene with a wooden vice at one end, a rack of plain hand tools hanging on the dark plank wall behind it, a low stool pushed under the bench, shavings and offcuts on the floor, a shuttered window letting in flat grey light, no fire, no forge, no glowing metal, no goods laid out for sale and no prices anywhere — pixel art location illustration, low top-down three-quarter view, single dark outline, flat matte shading in a few clear steps, light from the upper left, muted brown, grey-brown and dull ochre, very dark and low contrast throughout, no text, no figures, no glow`

---

### BATCH I — Restrained backplates · **PRIORITY 2** · **0 generations**

**Purpose.** L-18 as amended permits restrained screen backplates. **None needs
authoring.** This batch exists so the queue records that, rather than leaving a
gap someone helpfully fills with a generation.

- Five **alt** vignettes are shipped and consumed by two surfaces. DIR-A N-2
  puts them behind seven pictureless tabs at 132 dp, top-anchored, double-scrimmed,
  with **no type on the band, ever**. Zero generations.
- Five **512 × 384** location masters are tracked and unshipped in
  `PIXELLAB_STABILIZATION_01/out/location/`. The shipped 384 × 176 banners are
  the `{x:56, y:132}` window of these. **Any other 384 × 176 window is an A-2
  recrop**, giving a third framing of every location for free — `x` may range
  0–128, `y` 0–208. Route it through `package-art.js`, which already asserts
  384 × 176 on that family.

**The only reason to spend a generation on a backplate** is a screen whose place
does not exist as art. On the current twelve surfaces there is none.

---

## 10. Budget

| Batch | Priority | Committed gens | Contingency | Files shipped |
|---|---|---|---|---|
| A — chassis frame | 1 | 1 | 3 | **1** |
| C — surface grains | 2 | 3 | 3 (+2 conditional, bench oak) | 3 |
| B — trade bands | 2 | 5 | 5 | 5 |
| I — backplates | 2 | **0** | 0 | 0 new, ≤5 recrops |
| D — combat / modal frame | 3 | 1 | 3 | **1** |
| E — reward kit | 3 | 1 | 2 | 3 + 1 remapped |
| F — inventory / equipment | 3 | 1 | 2 | 4 |
| H — board / ledger | 4 | 1 | 2 | 1 |
| G — craft / workshop | 4 | **0** | 3 (conditional) | 0, or 1 |
| **Total** | | **13** | **25** | **18–20 files** |

**Grand total: 13 committed, 38 ceiling with every contingency, the conditional
workbench and the conditional bench-oak grain all spent.** Against a
4,516-generation cycle allowance this is noise. Add one full `inpaint_image`
escalation (40) only if a seam genuinely fails, and the absolute worst case is
**78**.

Note how few *files* this is. The landed `PanelSkin` takes a whole sheet, so the
two frames are two PNGs rather than sixteen. **Twenty files is the entire
material identity of the product**, which is worth saying out loud next to a
896-file content pipeline.

**Say it plainly: generations are not the constraint on this queue.** Nine blind
review rounds, three reviewers each, plus a device review per batch — that is the
constraint, and it is why §10.2 buys one batch at a time.

### 10.2 What the first post-refresh window buys

**Batch A. Alone. Four generations.**

1. L-18 as amended requires **one chassis family app-wide**. Every later batch is
   authored to sit inside it, is palette-conformed to its accepted ramp, or is
   literally a remap of it (Batch E). If the chassis is wrong, all of that is
   wrong, and re-rolling it after Batches B–H have been conformed to it costs the
   whole queue, not four generations.
2. It is the change with the widest reach in the product: thirty-four call sites,
   through one registry entry, with zero call-site edits.
3. It is the only batch whose failure mode is *architectural* rather than local.
   Everything else can be dropped without consequence.

**Then stop.** Device review, at 320 and 393 dp, at text scale 1.0 and 1.4, with
the seam matrix from §3.3 in hand. Only after the chassis is accepted on a real
iPhone does window two buy **C, then B**, then the priority-3 batches in any
order.

**Do not buy Batch D early because combat is exciting.** The modal frame is
defined as *the chassis, heavier*. It cannot be authored before the thing it is
heavier than.

---

## 11. DO NOT AUTHOR

Each line is a blocker on **semantics**, not on craft. A perfectly drawn asset on
this list is refused (L-15, L-17).

**Systems Stride does not have.** No timer, hourglass, clock face, countdown,
cooldown ring, decay mark, durability bar or expiry. No capacity meter, no
fill-level track, no gauge. No lock, padlock, keyhole, chain or barred gate. No
coin, purse, price tag, ledger of prices, market stall, shop sign or merchant.
No rarity gem, tier chevron, star rating or rank pip. No streak mark, no refill
prompt, no energy *meter*.

**The two shapes this project has already paid for.** A **four-point star** reads
as a sparkle. A **symmetric waisted mass** reads as an hourglass, therefore as a
timer — the single register this product most needs to avoid. Neither may appear
in an ornament, a corner, a terminus or a frame turn.

**Banked walking energy is a stock the player owns.** A numeral with a glyph.
Never a bar, never a ring, never a thing that drains. No asset in this queue goes
anywhere near it.

**Movement Stride does not have.** No joystick, thumbstick, D-pad, movement pad
or free-roam affordance, and no composition that implies steering a character
around a field. A walkable tile field with a figure on it was tested blind and
was the one plate of four a reviewer expected to control "with a stick or
d-pad". Art must not introduce mechanics.

**Text, numbers and state.** No word, no numeral, no letterform, no punctuation
in any raster asset, at any size, anywhere — including a decorative "abc" in a
frame's tooling. **Bitmap type is not in scope and is not a future option under
0029.** No pressed, disabled, selected, hovered or locked variant of any frame:
a frame has one state and Flutter owns the rest.

**Structure Flutter must measure.** No slot, socket, compartment, cell, grid line,
column rule or tab shape. If an element has a boundary the layout depends on, it
is not raster.

**Whole screens.** No screen is a raster. A backplate is restrained, scrimmed and
behind everything; it is not a screenshot.

**Craft-level prohibitions carried from `PIXELLAB_STYLE_SPEC_01.md` §4 and §9.**
No anti-aliasing. No semi-transparent pixel. No gradient. No emissive or glowing
colour. No bloom. No white specular. No blown highlight above the §6 ceiling. No
cast or contact shadow — the compositor grounds things. No constructed isometric
projection on a flat interface element. No sub-pixel positioning. No smooth or
vector asset. No `centerSlice`, because it stretches.

**And one register rule with no exception.** `#58D6C0` appears in exactly one
file in this repository and this queue does not add a second.

---

## 12. OD-03 — the standing step-glyph debt, and where it ranks

**It ranks nowhere, because it is closed.** This is a correction, and the
evidence is on disk.

`UI_MATERIAL_DIRECTION_01.md` §5 lists "Batch F — step glyph, priority 1, the
replacement for the temporary turquoise boot (OD-03)" and calls it standing debt
that "outranks every frame". That reading is **stale**. It traces to
`MILESTONES/UI_FACELIFT_01.md` line 509, which is correct for its own date and
predates the round that closed the question.

What actually happened:

- `JOURNAL/OPEN_QUESTIONS.md` line 239: **"OD-03 — The step-economy mark — CLOSED,
  shipped (Activity Feel 01, 2026-08-20)"**, closed by **three blind rounds**.
- `assets/ui/v1/README.md`, the `glyph_steps.png` provenance row: a **PixelLab
  cuffed traveler's boot**, 12 × 12, palette-conformed by A-2 luminance remap from
  `ACTIVITY_FEEL_01/step_icon/boot_bold_a_16.png`, blind round-3 verdict
  PASS-WITH-NOTE against the retired chrome glyph — which itself misread as "the
  letter L".
- The shipped file is on disk and, measured this session, is the **only one of
  871** shipped PNGs carrying `#58D6C0`. It is not a temporary chrome glyph; it
  is the accepted PixelLab mark in the canonical teal, with its muted twin
  preserving the `walking_glyph.dart` two-colour pairing exactly.

**What is genuinely still live** is one sentence of residual risk from blind
round 3: *"a boot can read as an equipment slot; adjacency to the step figure
resolves it."* That is a **device-review watch item**, not a generation. It costs
zero and belongs on the next device checklist beside the Scree Crawler's
identity read.

**If, and only if, device review reopens it**, it becomes Batch Z at priority 1
ahead of everything here — it is the symbol of the thing the product is about and
it appears beside every step figure in the app — and the recipe is already known:
`create_image_pixen` at 16 × 16 (the tool's floor), one connected mass, bold
silhouette with at most one interior line, trimmed and A-2-conformed to 12 × 12,
then the same three blind rounds. Budget **6** generations for that round. Two
geometry findings are already paid for and must not be re-learned: a boot *print*
cannot fit the 12 × 12 slot (all 64 connected candidates measured 8×14–10×16, and
a trimmed print blind-read as "a padlock / keyhole"), and shaded detail fragments
at 24 dp.

**Recorded so the next reader does not re-derive it:** the OD-03 row in
`UI_MATERIAL_DIRECTION_01.md` §5 should be struck when that draft is next
revised. That is DIR-A's document to change, not this one's.

---

## 13. Open, and deliberately not decided here

- **`PanelSkin.inset` is `corner * scale` and must be `band * scale`,** with
  `band` added as a measured field, and `PanelSkins._reserve` moved to 12 / 16.
  §3.2.1 gives the arithmetic. It is free today and reflows thirty-four call
  sites the day after the first asset ships. **This is the one blocking
  architecture item in this document.**
- **Whether `PanelRole` gains `benchPlate`.** Batch C holds one grain on it. The
  enum is deliberately closed at six kinds-of-surface and adding a seventh for
  one screen is the start of the failure it was closed to prevent. This plan
  recommends *not* adding it and letting Batch G carry Craft.
- **`view = "side"` is unproven for flat interface art** in this repository.
  Round 1 of Batch A records the finding either way.
- **384 × 48 pixen at 8:1 is unproven.** §Batch B gives the 384 × 96-and-crop
  fallback; if the fallback is also wrong, the band family is re-specified, not
  re-rolled indefinitely.
- **The identity washes.** DIR-A §7 leaves open whether the ~6 L\* skill and
  region deeps are deleted or re-valued to 12–14 L\*. This plan is written to
  work under either: Batch B carries identity as a picture, which is the
  recommendation, and does not depend on the wash decision.
- **Whether `PixelFrame` ships before its first asset.** DIR-A flags it. This
  plan assumes it ships with a committed test-fixture PNG, since a test asset is
  not player-facing art and A-1 does not reach it.

## Related

- `DECISIONS/0029_UI_ART_DIRECTION_AMENDMENT.md` — the authority for this queue
- `GAME_BIBLE/ART/ART_DIRECTION.md` — outranks this document (L-15, L-16, L-17,
  L-18 as amended, L-19)
- `GAME_BIBLE/ART/UI_MATERIAL_DIRECTION_01.md` — the direction this queue serves
- `GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md` —
  rendering language §4, prompt grammar §7, prohibited drift §9, QA gates §10
- `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` — the reuse index §4 draws on
- `GAME_BIBLE/ART/exploration/NEUTRAL_STAGING_CHECKLIST.md` — §8.2's staging
- `Scripts/art/package-art.js` · `Scripts/check-ui-boundary.sh` ·
  `lib/ui/components/pixel_asset.dart` · `lib/ui/theme/stride_colors.dart`
