# ART-01 — Executive Production Doctrine (FMPO02)

Art direction only; binds every creative director in this workstream. Evidence: the 4d9a81f
device renders, atlas review sheet, enemy stage, item sheets, GOV-01..06, and `ART_DIRECTION.md`.

## 1. The thesis — **scene over frame**

> **Stride is a place you look into. It is not a form with a leather border.**

The best thing in the build is the gather stage: a painted backdrop, a subject that belongs in
it, a figure on the same ground — a *picture*. Everything else is a column of rounded dark
rectangles, and 4d9a81f answered that by drawing a border around the rectangles. A frame is not
a picture; repeating one frame is the opposite of art direction.

**The move that reads as months of work:** every screen gets **one authored picture that is
about that screen**, built in the gather stage's proven three planes, and the interface becomes
what sits *beneath* the picture. Craft gets a workshop; Inventory a pack laid open; Character
the traveller in a place; Skills a worked surface; Encounter a lit clearing with a creature in
it, not a blank rectangle holding a small wolf; Combat gets its stage back by demoting the
command block from a framed panel to plain surface. Corollary, and the hardest instruction here:
**subtract chrome.** The chassis sits on all six `PanelRole`s today; most of what it decorates
should end with no raster edge at all, and removing frames is delivered work.

**The enforcing test — every screen, every family, every review:** render at 393x852, view at
25% or from arm's length. If it still reads as *a list of rectangles*, the art has not landed,
whatever the quality. Six screens must read as six places in one world, not six borders on a list.

## 2. Production order — visible impact per generation

**Track W runs continuously beside everything, from day one:** WORLD terrain. It is the owner's #1
complaint and cannot be front-loaded, because the repair mandate is single-region,
device-evidenced and never batched — rate-limited by process, not budget. Start it first; expect
it to finish last. Then, in strict order:

1. **UI scene architecture** — fewest assets, most pixels changed: picture plates, surfaces,
   header bands, demoted command block, encounter plate.
2. **Equipment universality** — the most-seen sprite in the game currently lies (Inventory shows
   bronze plate, Adventure a white shirt): a correctness defect on the highest-traffic asset.
3. **Items** — 59 icons seen constantly in Craft, Inventory and Reward, with confirmed
   perceptual duplicates (one crate per reclaim; four broths that are one broth).
4. **Enemies + encounter staging** — the empty preview box is a *staging* failure, not a creature
   shortage. Stage first, roster second.
5. **World life** — dragons, settlements, caravans, ambient magic: enormous payoff, one screen.
6. **Gather naturalisation** — architecture approved; correct only the over-staged scenes.
   **Rewards** last — already close. Polish, not rebuild.

## 3. Cross-family consistency rules — binding on every generation

- **Palette anchoring.** The atlas and accepted gather backdrops are the anchor; nothing re-keys
  them. Three families only: warm earth (bark, oat, canvas, oxidised bronze — L-19: reddish-copper,
  never bullion), cool complement (slate, frostmere ice), one vegetal green. The boar's magenta and
  the crawler's pastel blue are out of family and get corrected, not shipped. `#58D6C0` is
  walking's alone (L-16). Every subject keeps its darkest value *above* `surfaceGround #14120F` so
  it cannot hole through the app's ground; no chrome pixel exceeds `#7C7263` luminance; no partial
  alpha anywhere (`0<a<255` is guard-rejected).
- **Outline.** Subjects — items, creatures, figures, props, ornaments — carry a selective outline
  one step darker than the *local hue*, never black, opened on the key side. Backdrop planes carry
  **no** outline and separate by value clustering alone: this asymmetry is why the mine scene
  reads. Do not outline scenery; do not un-outline subjects.
- **Light and shading.** One sun, upper-left, ~45°, in every family, forever; every free-standing
  subject sits on a contact shadow in its plane's own ground shade. The item sheet lights the
  sword from the left and the chestplate from above — that alone makes good icons look *found*.
  Three values per material (shadow / body / light) plus at most one rim: four, hard cap;
  dithering only for atmospheric transitions on backdrops, never on a subject.
- **Density planes (L-18/L-18a, locked).** Backdrop 384x176 @x1 · subject/prop 48² @x2 · figure
  and creature 64² @x2 · list icon 48² @x1, hero icon @x2 · chrome 64² @x2. **New binding rule:**
  authored *detail frequency* follows display density, not canvas — a backdrop shown at x1 is drawn
  with feature sizes roughly twice those of a 48 subject at x2, or the scenery out-details the
  figure on it. Visible today: the copper-seam stonework is finer than the traveller mining it.
- **UI art vs sprite art.** UI art is **material** — leather, oiled wood, slate, canvas — low
  variation, no depicted objects, no light source of its own. Sprite art is **depicted**, under
  the one sun. A UI asset that depicts an object is an ornament; ornaments are counted, rationed
  and justified one at a time. One chassis family app-wide (L-18); screens differ by **band,
  surface and picture**, and a second border family is refused on sight.

## 4. The three ways this fails, and the rule that stops each

**F1 — Frame inflation.** The swarm answers "too repetitive" with more borders; exactly how
4d9a81f failed. **R1 — one framed element per screen, maximum.** The screen's picture gets the
raster edge; everything else is surface, type and spacing, and a second border is answered with
a surface or with nothing.

**F2 — Style drift across parallel families.** Eight directors generating at once produce eight
houses; the item sheet already mixes outlines, light direction and fidelity inside one set.
**R2 — the Anchor Sheet governs every call.** Before any family generates volume, one PNG carrying
the palette anchor, outline rule, sun angle, 3-value ramp and one exemplar per family is committed
**and pushed** (PixelLab reaches only `raw.githubusercontent.com` and its own results); every
`create_image_*` cites it or reuses its prompt stem verbatim.

**F3 — Volume without composition.** 2,400 generations spent on more, better-drawn boxes: more
icons, creatures, overlays — same screens. **R3 — composition first, then volume.** A family's
first spend is the staging asset that changes its screen from across the room, and none spends
past **40%** of its allocation until one 393x852 device render of its screen passes the squint
test in §1. Failing it returns the family to planning, not to more generations.

## 5. Generation allocation — 2,400

| Family | Gens | What it buys |
|---|---:|---|
| UI | 380 | 6 screen picture plates, 4 material surfaces, header bands, encounter plate, demoted combat command block, ornaments, frame *removals* |
| Equipment | 420 | universal armour/weapon states across gather, adventure, combat, inventory (`create_character_state` 20–40 each) plus animation passes |
| Items | 330 | disambiguate reclaims, broths, stews, pots first; new icons only once duplicates are gone |
| Gather | 200 | naturalise over-staged scenes; a few new subjects and region backdrops |
| World | 430 | 260 terrain (outer ring, biome transitions, west forest wall, south layer-cake, SW slab, marsh/surf joins, dead zones) + 170 world life (dragons, fairy castle, storm house, ice tower, caravans, settlement life, fauna) |
| Enemies | 280 | encounter staging and backdrops first, then roster consistency and missing hit/defeat tracks |
| Rewards | 120 | marks, plates and seals brought onto the Anchor Sheet |
| **Reserve** | **240** | re-rolls, atlas repair-loop retries, anchor-pass failures |
| **Total** | **2,400** | |

Audio gets **0**: `STABILITY_API_KEY` is unset, so none can be produced this session (GOV-06).

## 6. Standing orders

- Frozen atlas core (256..768)² and the 15 landmark goldens are untouchable; the outer ring is
  fair game. One region per repair, device evidence each time.
- Zero new persisted save state; equipment visuals project from `Equipment.bySlot` at read time.
- No coins, timers, locks, durability, cooldowns, FOMO, dailies or streaks — a frame reading as a
  slot or a meter is refused however well it is drawn.
- Text is never raster. With every frame asset deleted, the app must still lay out, read, navigate
  and pass its accessibility assertions. PixelLab authors; we art-direct and transform.
