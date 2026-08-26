# Project Stride — Mistakes

An evidence log of **durable lessons**, newest first.

## What belongs here

Only mistakes worth preventing again: architectural errors, process failures,
and recurring patterns. Each entry states what happened, why, what it cost, and
what prevents recurrence.

**This is not a bug diary.** An ordinary defect found and fixed inside its own
task does not belong here. A defect that reveals something about how the
project works — or how it goes wrong — does.

> **Repeated mistakes may graduate into `RULES.md`** when they represent a
> recurring pattern rather than a single incident. A rule that exists only as a
> war story is a rule nobody can enforce.

Entries are numbered in order of recording and never renumbered, so a reference
to `M-02` stays valid.

---

## M-14 — A composed atlas measured as joined, blended and border-clean still shipped rectangles to the phone

**Date:** 2026-08-26 · **Category:** art pipeline / verification (M-12 / M-04
family) · **Provenance:** World Map Polish 01 / 03, World Map Expansion
Refinement 02, and World Atlas Coherence UI 01, world-atlas stream

### What happened

M-12 said stop butt-joining separate paintings, and the world stream did. The
accepted 512² master is byte-preserved; every ring piece is style-referenced
against a 64² crop of the exact edge it touches; the joins get a deterministic
dither crossfade that invents no colours; water and snow tints are conformed by
a mean/std palette match; and each round composited a preview and reviewed seams
at ×4 on a desktop. `package-art.js --check` passed every time — hundreds of
files, all reproducible from tracked sources.

And the owner's iPhone still opened, pass after pass, on rectangles: an east
"torn scan-line" column, a north ice wall and comb, a south delta comb, a
far-east ocean panel and an SE beach cut-off — straight lattice lines the eye
read as pasted tiles at the layout's ×6 display scale.

### Root cause

**Pixel-edge continuity is not geographic or artistic continuity, and
everything the pipeline measured was pixel-edge continuity.** Byte-preservation,
style-reference chips, the dither crossfade, palette conform and a seam-distance
metric all answer *do the two sides meet smoothly at the cut line*. None can
answer *does the coastline continue, does the biome belong, does the drawing
hand match at the scale a player holds* — which is what the eye reads as a
rectangle. The dither is a 1-D pixel swap along a perfectly straight lattice
line: it narrows a seam to a noisy band but authors nothing across it, and a
straight axis-aligned band at ×6 is a straight axis-aligned band. `--check` is a
reproducibility gate and cannot see a seam; the desktop composite was viewed
downscaled-to-fit, where a 22 px band and small hue steps fall below threshold.
The one instrument that ever caught the defect — a rectangle at phone scale —
was the one the pipeline did not run before shipping.

### Consequence

No player harm — presentation only, caught on the owner's own device each round
— but the same class of defect cost four consecutive world passes, each declared
clean by `--check` and a desktop review before the phone found it.

### Prevention

- **A generated rectangle is a defect until a blind read at iPhone-viewport
  scale says otherwise. No visible generated boundary may remain in
  production.** A seam metric, a crossfade and a palette conform are triage,
  never the verdict.
- **Grow and repair by transition authoring, not seam blending.** Author each
  boundary from a wide crop that contains real terrain from *both* sides
  (inpaint the join, freeze the margins so it re-seats), or regenerate the
  region whole; carry the coastline, ridge, road and biome *through* the join.
  Reserve deterministic conform for flat open water, where one palette is the
  whole answer. This round did exactly that — twelve inpainted bridges over the
  seams and one ocean conform — and is the worked example (`RULES.md` A-3;
  `GAME_BIBLE/ART/exploration/WORLD_ATLAS_COHERENCE_UI_01/README.md`).
- **Review every generation boundary at every scale before the device pass:**
  full composite, high zoom, and representative iPhone-viewport scale — and at
  each boundary, all four of biome, coastline/waterline, detail-scale (drawing
  hand) and palette continuity. A join that fails any one at phone scale is not
  shipped.
- **Catch mechanical border artefacts with a tool, not memory.** A 1 px uniform
  generation border is deterministic; packaging should fail on it rather than
  relying on someone re-running an edge scan.

## M-13 — Blind QA was staged inside a directory whose path named the intent

**Date:** 2026-08-20 · **Category:** process / visual production (M-04 family) ·
**Provenance:** Activity Feel & Presentation 01, all three blind rounds

### What happened

Every blind Visual QA round of the milestone staged its neutrally named
plates (`seq_1`, `map_b`, `marks3`) under
`GAME_BIBLE/ART/exploration/ACTIVITY_FEEL_01/step_icon/qa…` — and the
reviewers reported the leak themselves, twice: locating the plates exposed
sibling production filenames (`woodcut_f*`, `boot_*`, `crop_mine`) that
announce every asset's intended semantics, and the path segment `step_icon`
told the icon reviewer what the marks were for before a pixel was seen. One
task prompt also disclosed the intent ("icon beside a step counter") ahead of
the first-impression question.

### Root cause

M-04's blind-semantic-read rule was enforced on the **file names** and not on
the **path or the prompt**. Staging inside the working round directory is the
natural place to put plates, and it is exactly the place where every
neighbouring byte is labelled with intent.

### Consequence

None to the verdicts that mattered — the reviewers disclosed the
contamination and separated primed from perceptual answers, and the two FAIL
verdicts (a print misread as a padlock; a shaded boot misread as a sprout)
were *against* the primed direction, which is what makes them trustworthy.
The cost is that every PASS this milestone carries a "formally compromised"
asterisk the verdict did not need to carry.

### Prevention

- **Stage blind plates in a neutral directory whose path names nothing** —
  a scratch folder with generic segments, never the round's working tree.
- **The tasking prompt asks the first-impression question before revealing
  any purpose** the answer is judged against; purpose-dependent questions
  come after the blind reads, clearly separated.
- A reviewer reporting staging contamination is the process working —
  keep asking for that report.

---

## M-12 — A tiled AI-generated world measured as joined and read as four paintings

**Date:** 2026-08-19 · **Category:** art pipeline / verification (M-04 family) ·
**Provenance:** World & Reward Depth 01, world atlas stream

### What happened

The atlas was grown from one 384 × 688 PixelLab tile to a 2 × 2 grid. Every
tile was generated with the same palette reference, prompts were written from
the measured colours of the neighbouring edge, a per-band seam-distance tool
was built, a re-roll lowered the worst seam's measured distance from 48 to 28,
and the author's own ×2 composites looked plausible. **Two independent blind
Visual QA passes failed the composite on continuity** — "four maps from
different games pasted into a grid" — while passing almost every single-tile
viewport. 335 generations were spent across the two rounds; only the one join
both reviewers called faint (base ↔ south, where the river continues across)
shipped. The east and south-east tiles are withheld.

### Root cause

A seam is perceived as a **simultaneous** hue, value, saturation *and texture*
step, and the reviewers named texture ("flat geometric fields against
illustrated ones", "smooth ground against speckled scree") as often as colour.
Palette conform and colour-distance metrics cannot see texture or drawing
hand, and PixelLab cannot outpaint at this tier, so every tile is a fresh
painting whose edge merely *describes* its neighbour. Full-width cover strips
made it worse (they read as ruled borders). The measurement told the author
the seam was fixed; only the blind read could say it was not.

### Prevention

- **A tile is not accepted until its join passes a blind read** — a seam
  metric is a triage tool, not a verdict. Gate the *second* tile on the first
  join, as the brief said, and stop when the join fails twice.
- A world that grows should grow by **natural boundaries the art can own** —
  a coast, a ridge, a river the new tile is generated *around* — or by
  re-generating the whole base at the size wanted, never by butting paintings
  edge to edge and hoping palette carries it.
- Keep the withheld tiles: a future round that regenerates the *east* tile
  from the base's measured edge has the only unqualified-PASS tile to
  start from.

---

## M-11 — Two device milestones shipped with no way to equip anything

**Date:** 2026-08-19 · **Category:** content / verification (M-07 family) ·
**Provenance:** Playable Expansion 01, found while wiring combat

### What happened

`GameStarted` grants the starting loadout to the *inventory only*; the
engine requires a tool to be **equipped** to work `oak_stand` or
`copper_seam`, and the combat slice reads the *equipped* weapon and armour.
No product surface — and not the debug harness either — has ever offered an
equip control. `PLAYABLE_PHASE_2_ACCEPTANCE.md` step 25 says "Equip the
Training Axe in Inventory"; the Inventory screen's own header comment says
there is deliberately no equipped card "because Phase 1 has no equip
affordance". Woodcutting and Mining were therefore unreachable on the phone
through Playable Phase 2 *and* Transformation Build 01, and nobody noticed
because the owner's device sessions foraged, travelled and synced.

### Root cause

The same shape as M-07: every structural check passed (the command exists,
the engine equips, the reachability validator proves the bronze chain) and
nothing *plays* the product UI end to end. The acceptance script named an
affordance the UI did not have, and a script step nobody executed is
indistinguishable from one that passed.

### Prevention

- Inventory now carries **Equip / Unequip** on equipment tiles and an
  Equipped summary; the session exposes `equip` / `unequip`.
- **An acceptance-script step must name a control that exists in the build
  it tests**, and the device script for this milestone exercises equip
  explicitly (steps 6–7).
- A widget test now drives new game → equip Training Axe → the tool slot is
  filled, so the affordance cannot silently vanish again.

---

## M-10 — The product never asked HealthKit for read access; the dev harness had

**Date:** 2026-08-18 · **Category:** architecture / device workflow ·
**Provenance:** Transformation Build 01 first Release install

### What happened

A genuinely fresh Release install showed `TOTAL WALKED 0`, banked 0, no
permission sheet, and Project Stride absent from Health's app list. Startup
sync and manual `Sync steps` both reported "no new steps".

### Root cause

`StrideSession.requestPermission` existed and was wired to the Swift adapter's
`requestAuthorization` — and its **only caller was the dev harness**. Every
earlier device run had authorised Steps through the S-01A harness once, and
HealthKit authorisation persists per bundle id, so the product UI's omission
was invisible for three milestones. On iOS an unauthorised read returns an
empty result rather than an error, so the sync's honest "no change" report
was indistinguishable from "nobody was allowed to look".

### Prevention

- The session asks for read access **immediately before every sync until the
  answer is granted** (foreground, H-5 intact); the request lives beside the
  read, not on a screen someone must remember to visit.
- `SyncReport.authorization` carries the answer and the walking band renders
  denied / unavailable distinctly from "no new steps".
- **A device finding from a fresh container is a different test from a
  reinstall over an authorised one.** `test/fresh_install_authorization_test`
  pins the ask-before-read order; the device script now includes the
  permission sheet as a step to observe.

---

## M-09 — `flutter build ios --profile`, then Xcode's Run button, installed a Debug build

**Date:** 2026-08-17 · **Category:** process / device workflow ·
**Graduated to:** `TECHNICAL/IOS_DEVICE_INSTALL.md`, `Scripts/ios/`

### What happened

Two device installs were recorded as `--profile` builds because that is the
`flutter build` command the acceptance documents named. On the owner's phone
the app then refused to launch from the Home Screen: *debug-mode Flutter
applications can only be launched from Flutter tooling*. The install was
Debug.

### Root cause

`ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` has
`LaunchAction buildConfiguration="Debug"`. Pressing **Run** in Xcode rebuilds
and installs Debug regardless of what `flutter build ios --profile` produced a
moment earlier. Two tools, one phone, and the second one silently won. The
milestone records described the command, not what landed on the device.

### Consequence

The Phase 2 device review was run tethered, and the "unplugged" test the
milestone needed could not be run at all. Nothing about the health, save or
gameplay evidence is affected — a Debug build computes the same numbers — but
the *distribution* question was answered wrongly twice.

### Prevention

- **The install step must not end in Xcode's Run button.** `Scripts/ios/
  build-release-device.sh` builds `--release` (codesigned) and
  `install-device.sh` installs that bundle; the script verifies the bundle is
  AOT (`kernel_blob.bin` absent) before handing off.
- **Record what is on the phone, not what was typed.** A device record names
  the build configuration as read from the bundle.
- The signing team lives in an untracked `ios/Flutter/Local.xcconfig`, never
  in the tracked project (`RULES.md` G-8's reasoning applied to a team id).

---

## M-08 — `git add -A` published 929 files, including third-party imagery, to a public repository

**Date:** 2026-08-17 · **Category:** process / repository hygiene ·
**Graduated to:** `RULES.md` G-8, `.gitignore`

### What happened

Four Playable Phase 2 commits were staged with `git add -A`. The working tree
contained a large body of **untracked** visual-exploration evidence from earlier
sessions, and all of it went in: **929 files across nineteen directories**.

Twelve of them are in `GAME_BIBLE/ART/exploration/WALKSCAPE_REFERENCE_SET/`, and
nine of those are **third-party reference imagery** — screenshots of a
commercial game and external pixel-art references, gathered for a forensic style
study.

That directory's own README opens with:

```text
STATUS: REFERENCE EVIDENCE ONLY — NOT CANON — NOT A PROJECT STRIDE ASSET
DO NOT COMMIT
```

The repository is **public and deliberately so** (`PROJECT_STATE.md`). The
commits were pushed.

### Root cause

**`git add -A` stages by absence of a rule, not by intent.** It cannot
distinguish "a file I just created for this commit" from "a file that has been
sitting in the tree for three sessions because nobody wanted it tracked". The
only thing standing between an untracked file and publication was a README —
that is, a document addressed to a *reader*, guarding against an action taken by
a *command*.

Three things made it invisible rather than obvious:

- The commit message was written from intent, not from `git status`. The staged
  list was never read.
- `git commit` reports a count, not a manifest, and 946 files added is not
  visibly different from 17 in a terminal that scrolls.
- `.gitignore` had no rule for `GAME_BIBLE/ART/exploration/`, because until then
  nothing had ever tried to add it.

### Consequence

The material was publicly fetchable for the time the branch was pushed.
**Untracking at the tip is not a remedy** — the blobs remain reachable through
the pushed commits — so this required a history rewrite and a force-push, which
is the most disruptive operation available on a shared branch and was needed
only because of a two-character flag.

It also inflated the branch: 929 files of prior evidence landed in a milestone
whose actual art output was six images.

### Prevention

- **`RULES.md` G-8: stage explicit paths.** `git add -A` and `git add .` are not
  to be used. Name the paths, or read `git status --short` before committing.
- **Invert the default where the risk lives.** `.gitignore` now ignores
  `GAME_BIBLE/ART/exploration/**` and re-includes the specific packaging sources
  and round records that must be tracked. A rule beats a README, because the
  README was already right and was still not read by the command that mattered.
- **Never rely on an in-file instruction to prevent a repository action.** A
  `DO NOT COMMIT` header is a note to a person. The mechanism has to be a rule a
  tool enforces.
- **A commit that adds more files than the change describes is a defect
  signal.** If the message names four screens and the commit adds nine hundred
  files, the two do not agree and the commit is wrong.

---

## M-07 — Every structural validator passed, and the loop was unplayable

**Date:** 2026-08-17 · **Category:** content / verification ·
**Provenance:** Playable Phase 2, `MILESTONES/PLAYABLE_PHASE_2.md`

### What happened

Phase 2's content set passed everything the repository could ask of it. The
loader resolved every reference. The **reachability validator** — 300 lines
built precisely to catch progression deadlocks, with named diagnoses for tool
bootstrap cycles and unobtainable gates — proved the whole bronze chain
obtainable. New world-graph tests proved every location connected to the start,
every route symmetric, every node hosted exactly once, every crafted output
consumed by something.

All green. Then a test walked the loop end to end and was refused at the forge:

```text
CraftItem was refused: "Bronze Ingot" needs Smithing 2; the player is level 1
```

**To smelt ore, you first had to whittle ten oak handles.** Bronze Ingot sat at
Smithing 2, and the only level-1 Smithing recipe was Oak Handle at 15 xp — so
150 xp meant ten handles, meaning twenty oak logs, meaning a return trip to a
different region. A player who walked to Stonefall, mined copper and tin, and
opened the Craft screen was told to go back to the woods.

### Root cause

**The validator answers "is this possible", and the question that mattered was
"would anyone find it".**

Reachability excludes skill levels *by design*, and the exclusion is correct and
documented: a level requirement is always satisfiable given enough of an
activity the player can already do, so folding it in would turn a structural
check into a pacing check and hide the structural answer.

That reasoning is sound and it leaves a gap exactly the width of this defect.
The chain **was** completable. It was completable in an order nobody would guess
and no screen explains, and "completable" was the only property anything
measured.

The tests that existed were all of the same *kind*: they inspect the content
graph as a graph. Not one of them played it.

### Consequence

Caught before the device, by a test written during the integration critic pass
rather than by any of the twelve validators. Had it shipped, the owner's first
session would have ended at the Craft screen with ore in hand and no way to use
it — on the milestone whose entire purpose was to feel like a game.

### Prevention

- **Walk the loop.** `phase2_loop_budget_test.dart` plays the advertised
  sequence with the real engine and the real content, and fails if any step is
  refused. It is the only test in the repository that would have caught this,
  and it is thirty lines.
- **Assert the bill, not just the possibility.** The same test prints the step
  cost of every leg and asserts the total stays between one and five days of
  ordinary walking. A retune that makes the milestone untestable now fails in CI
  rather than on the owner's phone.
- **A graph check and a play check are different instruments**, and the second
  is not implied by any number of the first. This is `M-06`'s shape in a new
  place: there, green tests said nothing about *appearance*; here, green tests
  said nothing about *sequence*.
- **Where a validator excludes something deliberately, that exclusion is a
  named gap.** Reachability's own doc comment says it ignores levels. Nothing
  covered what it left out until something did.

**This does not license a validation campaign** (`RULES.md` G-1). One test that
plays the loop, and it doubles as the balance record.

---

## M-06 — A UI was declared done on evidence that was structurally blind to how it looked

**Date:** 2026-08-16 · **Category:** process / verification ·
**Provenance:** Playable Demo Phase 1, `MILESTONES/PLAYABLE_DEMO_PHASE_1_CLOSEOUT.md` §4

### What happened

Playable Demo Phase 1's product UI passed **93 widget tests and four golden
images** and was carried as complete. The first time it was run on a device, it
had three visible defects — one of them affecting **every string in the
application**.

| Defect | Visible severity |
|---|---|
| No `Material` ancestor, so `DefaultTextStyle` resolved to Flutter's fallback — which carries `TextDecoration.underline` in double yellow | Every word in the product was underlined |
| The inventory `GridView` defaulted to `primary: true` and adopted `MediaQuery.padding` | 57 dp of dead space above the first row |
| The region list iterated `locations` alphabetically | "Where am I?" was answered with a place the player has never been |

### Root cause

**The two evidence sources were blind to these defect classes by construction,
and nobody had written down that they were.**

- `flutter test` has **no real font**. Its harness draws every glyph as a filled
  rectangle, so a golden image cannot show an underline, a wrong weight, a
  clipped descender, or any typographic fault at all. The underline merged into
  the box.
- `flutter test` supplies **zero safe-area insets**. Any defect that is a
  function of real device padding measures as exactly 0 under test. The
  inventory gap was not "small in the test" — it was *absent*, and present on
  hardware.
- Widget tests assert a string's **content**. Almost none assert its resolved
  style, so decoration, colour and weight are unguarded unless someone
  deliberately reaches for them.

The count of passing tests was doing work it could not do. 93 green tests
created confidence about *appearance*, which is not what any of them measured.

### Consequence

Caught before the owner saw it, at the cost of one device pass. Had the physical
acceptance run happened first, the owner's report would have opened with "every
word is underlined" — and the two-week judgment about whether Stride *feels*
right would have been taken against a build that looked broken.

### Prevention

- **A UI is not done until it has been looked at, running, on a device.** No
  count of green tests substitutes. This is the same lesson as M-04 — a
  technically correct change reported as a fix without perceptual verification —
  arriving through automated tests rather than through pixel measurements.
- **Golden images are regression evidence between framework revisions, and
  nothing else.** They cannot judge type. `PLAYABLE_DEMO_PHASE_1_ACCEPTANCE.md`
  already said so in prose; it needed saying where the goldens are generated,
  and now is.
- When a device pass finds a defect a test *could* have caught, **add the test
  that asserts the resolved property**, not the widget that happens to fix it.
  The underline guard asserts the inherited `TextStyle`, so it still fails if a
  `Material` is added somewhere that does not cover every screen.
- Prefer **verifying the harness's blind spots explicitly** over trusting a
  green total: insets, text scaling, and type all need a real surface.

**This does not license a verification campaign** (`RULES.md` G-1). One device
pass, on the screens that changed, with the findings written down.

### Update — 2026-08-16, third occurrence, and what finally changed

D-01 was the third instance: a fixed 72 dp box clipped the last digit off
`455,281` on the owner's phone while five overflow tests and four goldens passed.
Neither could have caught it. `TextOverflow.clip` **raises no exception**, so
`takeException() == null` is satisfied by a clipped string and an intact one
alike; and the goldens rendered `12,480`, six characters, which fits the box that
seven did not.

UI Facelift 01 changed the instruments rather than adding more of the same, and
the change is the durable part:

- **Assert the property, not the absence of an exception.** For every
  single-line paragraph in the tree, the width the text *needs* is compared with
  the width layout *gave* it. That is a screen-wide clipping detector, and it is
  what the old tests were reaching for and could not express.
- **A test that measures type needs type.** `flutter test`'s fallback font draws
  every glyph as a filled rectangle about 0.84 em wide, against Roboto's 0.55 —
  so a width assertion against it is a measurement of the harness, and "fixing"
  the app to satisfy it would shrink real type for a fake reason. A real face is
  now loaded, and its **absence fails rather than skips**.
- **Fixtures must resemble accepted saves.** The stress values are the device
  run's own figures, and a golden set now renders 455,281 beside the old 12,480.

The measurement's first run found **two further on-device defects nothing in the
repository could see**: `EXPERIENCE` clipped in the third cost tile at every
supported width, and the step cost `90` given 16 dp where it needed 19.8. Both
had shipped. Changing the instrument found in one run what looking harder had
not found in three.

The rest of M-06 stands unchanged, and the first line of it most of all: **none
of this replaces looking at a device.**

---

## M-05 — Visual decisions were made without a play-scale verdict view

**Date:** 2026-08-14 · **Category:** process / visual production ·
**Graduated to:** `PIXEL_ART_CRAFT_SPEC.md` §8,
`STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — *Target scale and the standard
output set*

### What happened

`VISUAL_STUDIO_BASELINE_AUDIT_01` found that **no ×2 render existed anywhere in
the repository**. `TRAVELER_REFINE_03/out/` held fifteen ×8 files, three natives
and no ×2; the only available character context views were ×8 crops. Every
Traveler decision to that point had been taken on that evidence set.

### Root cause

The exploration renderers emitted native and ×8 inspection views and no ×2
play-scale proxy — not by omission in any one pass, but because each `render.js`
selected a single `SCALE` constant and wrote only that view. Review therefore
judged player-facing readability at a scale that enlarged and flattered
low-resolution detail.

**This is distinct from M-04.** M-04 is about who was permitted to judge. M-05 is
about what they were given to judge: the evidence set did not contain the view the
verdict required, so even a correctly independent reviewer would have been
deciding at the wrong scale.

### Consequence

Several Traveler defects survived repeated review because they were more legible
at ×8 than at likely game scale — hands, equipment silhouettes, material
separation, and the small corrective changes made across three passes. Blind
review later confirmed the pattern directly: the ×8 view distinguished versions
that were indistinguishable at ×2, and the single clearest piece of object craft
in the set was invisible at play scale.

### Prevention

- **Every meaningful visual review set includes ×2**, and ×2 is the verdict view.
- **×8 is inspection only** and never sufficient for graduation.
- **True in-context views must reflect actual presentation scale.** An enlarged
  crop is not a context view.
- **Silhouette-only output is required for major character work.**
- **A visual pass without the required verdict view is returned unreviewed** —
  not reviewed at whichever scale happens to be available.

### Evidence

`VISUAL_STUDIO_BASELINE_AUDIT_01`, 2026-08-14 · `TRAVELER_REFINE_03/out/`
(18 files, no ×2) · `GAME_BIBLE/ART/exploration/CODE_RENDER_01/review_set.js`

---

## M-04 — A technically correct pixel change was reported as a fix without perceptual verification

**Date:** 2026-08-14 · **Category:** process / visual production ·
**Graduated to:** `PIXEL_ART_CRAFT_SPEC.md` CR-41,
`STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — Visual Studio

### What happened

Across three consecutive Traveler passes, the implementation report described
substantial, defensible source-level corrections — dozens of moved pixels, a
repositioned sword, a re-silhouetted pack, a palette separation — and the owner
looked at the before and after images and said they basically looked the same.

### Root cause

**The agent that authored the pixels was also the only judge of whether they
worked, and it judged them against source intent rather than against the rendered
image at the scale a player would see.** Every claim was true at the level of the
sprite map and unverified at the level of perception. The final pass then ended
with a single self-written line, `GRADUATE TRAVELER — YES`, with no independent
assessment beside it.

Two multipliers: review happened at ×8, which flatters everything and hid reads
that failed at play scale; and the source carried explicit semantic labels —
`PACK`, `SWORD`, *"the strap terminates ON the bag"* — so any reviewer with
access to it was told what to see before looking.

### Consequence

Owner review rounds spent on corrections the owner could not perceive, and a
character reported as ready that the owner still read as carrying a shield.

### Prevention

- **The perceptual law.** Source intent gets no credit — not a variable name, a
  comment, a pixel count, or a passing assertion.
- **Blind semantic read.** The critic sees neutrally staged renders before any
  intent, name, source, or version label. Staging enforces this, not intentions.
- **Perceptual delta test.** Before/after shown unlabelled and randomised. A
  correction the author called significant that reads *functionally the same* has
  not solved the problem.
- **A ×2 play-scale proxy in every render set.** ×8 is inspection scale, never
  verdict scale.
- **Separate AUTHOR ASSESSMENT and QA VERDICT lines.** The author never writes
  the second one.

### Evidence

Owner review of `TRAVELER_REFINE_03`, 2026-08-14 · the R03F → R03C correction
(53 pixels changed, reported as significant) · `AGENTS/visual_qa.md`

---

## M-03 — A HealthKit candidate cursor was offered on non-final pages

**Date:** 2026-08-13 · **Category:** architecture · **Graduated to:** `RULES.md` H-4, G-4

### What happened

The first sync on a real iPhone drained in eight pages and reported seven
`cursorOfferedWhenProhibited` faults — one per non-final page.

### Root cause

`HKAnchoredObjectQuery` returns one updated anchor per page, and that anchor is
the correct value for two different things. As a **continuation** it means
"carry on from here", which is true mid-read. As a **candidate cursor** it means
"you have seen everything up to here", which on page one of eight is false.

`HealthKitStepStore` assigned it to both on every page, and
`HealthKitAdapter.map` forwarded it as `nextCursor` without consulting
`isFinalPage` — **the only one of that page's three outbound fields that was not
gated on it**, sitting directly beside a completeness assertion and a
continuation that both were.

The Kotlin adapter already had the gate and a multi-page test for it. iOS was
the outlier, and every Swift test that supplied an anchor also declared its page
final, so 46 green tests said nothing about eight real pages of the defect.

### Consequence

**None to the player, and that is the important part.** `authorizeCursor`
refused all seven, the bridge dropped them, and only the eighth cursor reached
the save. No step was skipped or double-granted, and the save was never reset.

The real cost was to the **signal**: a correct adapter tripped the fault channel
during ordinary operation, and a fault that fires on every normal read is one
nobody will read when it matters.

### Prevention

- Where one native value feeds several outbound fields, **gate every field on
  the same page state**, or the ungated one becomes the defect.
- When two platform adapters implement one contract, a rule present in one and
  absent in the other is a defect, not a style difference. Compare them.
- A test that supplies a mid-read value must **declare the page mid-read**.
  Fixtures that always take the easy path test only the easy path.
- Never weaken the fault that caught it. The refusal was correct throughout.

### Evidence

Fix `5b68d33` · closure `6b6f596` · `S01A_PHYSICAL_VALIDATION.md` ·
`packages/stride_health/test/multi_page_cursor_regression_test.dart` ·
`packages/stride_health/example/ios/RunnerTests/RunnerTests.swift`

---

## M-02 — CI floated on Flutter `stable` and moved 3.44.8 → 3.47.0 unannounced

**Date:** 2026-08-13 · **Category:** toolchain / process · **Graduated to:** `RULES.md` G-2

### What happened

The workflow requested `channel: stable` with no version. Stable moved from
3.44.8 to 3.47.0, `dart format` changed its output, and the format check began
failing on three files nobody had touched since early August — all three
byte-identical to master.

### Root cause

An unpinned toolchain. CI ran against whatever stable was on the day, so a run's
result depended on the **date it was started** rather than on the commit.

### Consequence

The failure landed in the middle of an unrelated HealthKit defect fix and
blocked the macOS job, which `needs: [core, pigeon]` — so a formatter version
bump silently withheld the Swift and iOS evidence the fix was waiting on. It
also cost a round of diagnosis to establish the failure was not caused by the
change under review.

### Prevention

- **Pin toolchain versions exactly.** The version CI uses and the version the
  project develops on must be the same version, and must be stated.
- A toolchain upgrade is **its own task, on its own branch**, with its own
  reformatting and its own full run. It is never absorbed into unrelated work.
- When CI fails, establish whether the failing files are even in the change
  before fixing anything.

### Evidence

Pin `853b293` · `.github/workflows/ci.yml` · follow-up recorded in
`PROJECT_STATE.md` (deliberate Flutter 3.47 evaluation, not yet scheduled)

---

## M-01 — Verification depth expanded beyond the risk being covered

**Date:** 2026-08 · **Category:** process / governance · **Graduated to:** `RULES.md` G-1

### What happened

During Commit B, verification expanded substantially beyond the minimum
evidence required to close the feature. The work included broad causality,
falsification, supervisor, and mutation validation, plus a proposed
repeated-run validation campaign.

### Root cause

Verification ceased being purely risk-driven and began **generating additional
verification work of its own**. Each layer suggested the next, and no step in
that sequence was gated on a named uncovered risk.

### Consequence

Player-facing progress slowed despite strong existing regression evidence
already being in place.

### Prevention

- Verification must remain **proportional to a concrete uncovered risk**.
- Prefer the smallest focused regression proof plus existing CI and guards.
- A new verification framework, or a repeated validation campaign, requires an
  **explicit uncovered risk named before the work begins**. "It would be more
  rigorous" is not such a risk.
- Depth of verification is a scope decision and belongs to the owner.

### Provenance

Owner and project review during Commit B closure, 2026-08.

**This is a process lesson, not a defect attributable to any one code commit.**
No repository citation is offered for the management judgment, because the
judgment was made in review rather than recorded in a commit — and inventing a
citation for it would make this log less trustworthy, not more. Commit B
artifacts and `PROJECT_STATE.md` provide supporting context only.
