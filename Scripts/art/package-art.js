// Packages approved PixelLab exploration output into the shipped asset tree.
//
//   node Scripts/art/package-art.js [--check]
//
// Reads only from `GAME_BIBLE/ART/exploration/`, writes only to
// `assets/art/v1/` and one generated Dart file. `--check` writes nothing and
// exits non-zero if the shipped tree differs from what this script would emit,
// which is what CI runs.
//
// ## Why packaging is a script rather than a one-time copy
//
// Three of these assets are not byte-identical to their source — the vignette
// is keyed and cropped, and the footprint table is measured. A one-time manual
// copy would leave those transformations recorded nowhere, so the next person
// to touch the art would have to reverse-engineer them from the pixels. Here
// the framing decision, the key threshold and the measurement rule are all
// readable, reviewable, and reproducible from a clean checkout.
//
// ## What is deliberately NOT here
//
// No generation, no scaling, no palette change, no sharpening, no recolouring.
// Every operation is lossless with respect to the pixels it keeps: a copy, an
// alpha key on a flood-filled border region, a rectangular crop, and a
// measurement. Art is authored in PixelLab and corrected with targeted edits;
// this step packages it and must never become a second place it is changed.
'use strict';

const fs = require('fs');
const path = require('path');

const png = require('./png.js');

const ROOT = path.resolve(__dirname, '..', '..');
const EXPLORE = path.join(ROOT, 'GAME_BIBLE', 'ART', 'exploration');
const DEST = path.join(ROOT, 'assets', 'art', 'v1');
const FOOTPRINT_DART = path.join(
  ROOT, 'lib', 'ui', 'icons', 'sprite_footprints.dart',
);

const STABLE = path.join(EXPLORE, 'PIXELLAB_STABILIZATION_01', 'out');
const CHARACTER = path.join(EXPLORE, 'PIXELLAB_PROOF_02', 'out', 'character');

const checkOnly = process.argv.includes('--check');
const problems = [];
const emitted = new Map();

/** Records the bytes destined for [rel], or compares them under `--check`. */
function emit(rel, bytes) {
  emitted.set(rel.replace(/\\/g, '/'), bytes);
  const target = path.join(DEST, rel);
  if (checkOnly) {
    if (!fs.existsSync(target)) {
      problems.push(`missing: assets/art/v1/${rel}`);
    } else if (!fs.readFileSync(target).equals(bytes)) {
      problems.push(`stale:   assets/art/v1/${rel}`);
    }
    return;
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes);
}

/** Re-encodes [raster] through the writer so `--check` compares like with like. */
function encode(raster) {
  const tmp = path.join(
    fs.mkdtempSync(path.join(require('os').tmpdir(), 'stride-art-')),
    'o.png',
  );
  png.save(tmp, raster);
  const bytes = fs.readFileSync(tmp);
  fs.rmSync(path.dirname(tmp), { recursive: true, force: true });
  return bytes;
}

// ------------------------------------------------------------------- assets

/**
 * ITEM ICONS — the PixelLab 48 × 48 family.
 *
 * These replace the code-rendered 20 × 20 Round 04 set. That set was authored
 * in Node as *evidence*, and the Training Axe is the reason the difference
 * matters: three rounds of code-rendered attempts were read as "hammer" by
 * blind reviewers in-grid, and the PixelLab edit was the first to be read as an
 * axe (`PIXELLAB_STABILIZATION_01/README.md` §3 item 4).
 *
 * `icon_canvas_backpack_48.png` exists in the source set and is **not**
 * packaged: `items.json` has no `item.canvas_backpack`, and an icon for an item
 * that cannot exist is an icon nothing can ever render.
 */
const ITEM_ICONS = {
  'item.bronze_ingot': 'icon_bronze_ingot_48.png',
  'item.copper_ore': 'icon_copper_ore_48.png',
  'item.meadow_herb': 'icon_meadow_herb_48.png',
  'item.oak_handle': 'icon_oak_handle_48.png',
  'item.oak_log': 'icon_oak_log_48.png',
  'item.pine_log': 'icon_pine_log_48.png',
  'item.tin_ore': 'icon_tin_ore_48.png',
  'item.training_axe': 'icon_training_axe_48.png',
  'item.training_pickaxe': 'icon_training_pickaxe_48.png',
  'item.training_sword': 'icon_training_sword_48.png',
  'item.traveler_tunic': 'icon_traveler_tunic_48.png',

  // Phase 2. Two foraged materials and the two things cooked from them.
  //
  // Before these, all four rendered as the `unknown` slab — including on the
  // Craft screen, where two of them are the *output*, so the screen showed a
  // blank placeholder for the thing it was offering to make.
  //
  // The pairs are legible as pairs: the skewer carries the duskcap's own cap
  // shape and palette, and the tea carries the rime blossom's pale blue. That
  // is the only cue linking ingredient to product at 48 px, and it is
  // deliberate — see the QA record in `SKILL_ICONS_OD04/ROUND_01_RESULT.md`.
  'item.duskcap': 'icon_duskcap_48.png',
  'item.rime_blossom': 'icon_rime_blossom_48.png',
  'item.duskcap_skewer': 'icon_duskcap_skewer_48.png',
  'item.frostbloom_tea': 'icon_frostbloom_tea_48.png',
};

// Playable Expansion 01 re-authored one of these for readability: the pine log
// was a hue-twin of the oak log at play scale (TRANSFORMATION_01/items QA). The
// corrected icon (Visual QA PASS at ×1/×2, PLAYABLE_EXPANSION_01/ambient/
// README.md §C) is read from that round's out/ folder; the emitted path is
// unchanged.
const ITEM_ICON_SOURCE_OVERRIDES = {
  'item.pine_log': path.join(EXPLORE, 'PLAYABLE_EXPANSION_01', 'out', 'items'),
};

for (const [id, file] of Object.entries(ITEM_ICONS)) {
  const raster = png.load(
    path.join(ITEM_ICON_SOURCE_OVERRIDES[id] ?? path.join(STABLE, 'icons_full'), file),
  );
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`${file}: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id.replace('item.', '')}.png`, encode(raster));
}

/**
 * THE UNKNOWN-ITEM SLAB — 48 × 48, drawn here rather than generated.
 *
 * This is the one file in the shipped art tree that is authored in code, and
 * the exception is deliberate: **it is not art, and it must not look like it.**
 * It stands in the grid cell most likely to be misread, so it asserts nothing —
 * two colours, a rim, and nothing inside. No aperture, no centred mark, no frame
 * ring.
 *
 * That constraint is not aesthetic. A small element centred inside a darker
 * frame is chrome grammar, and chrome grammar is what made the Hollow Sigil read
 * as a padlock, an equipment slot, a disabled cell and a coin across five
 * attempts — four systems Stride does not have.
 *
 * It should look unfinished, because it is.
 */
const UNKNOWN_FILL = [0x2c, 0x26, 0x20, 0xff];   // StrideColors.surfaceBlock
const UNKNOWN_RIM = [0x37, 0x2f, 0x27, 0xff];    // StrideColors.borderDefault
const UNKNOWN_INSET = 6;

const unknown = new png.Raster(48, 48);
for (let y = UNKNOWN_INSET; y < 48 - UNKNOWN_INSET; y++) {
  for (let x = UNKNOWN_INSET; x < 48 - UNKNOWN_INSET; x++) {
    const onRim = x === UNKNOWN_INSET || y === UNKNOWN_INSET
      || x === 47 - UNKNOWN_INSET || y === 47 - UNKNOWN_INSET;
    const color = onRim ? UNKNOWN_RIM : UNKNOWN_FILL;
    for (let c = 0; c < 4; c++) unknown.data[unknown.idx(x, y) + c] = color[c];
  }
}
emit('item/unknown.png', encode(unknown));

/** PORTRAIT — 64 × 64, PixelLab. A separate asset class from the sprite. */
const portrait = png.load(path.join(CHARACTER, 'traveler_portrait_64.png'));
emit('portrait/traveler.png', encode(portrait));

/** WORLD SPRITE — 64 × 64, south-facing rest pose. */
const spriteSouth = png.load(path.join(CHARACTER, 'traveler_south_64.png'));
emit('sprite/traveler_south.png', encode(spriteSouth));

/**
 * GATHER ANIMATION — the trimmed eight frames, with frame 5 repaired.
 *
 * `PIXELLAB_STABILIZATION_01` closed four of the owner's five criteria for this
 * animation and failed the fifth: blind review found frame 5's *"torso, both
 * arms and knee fuse into one mass"*. Trimming could not fix it — the defect is
 * in the generated frame — and the frame is load-bearing, because it is the
 * rise between the crouch and the standing hold.
 *
 * The repair is a single `inpaint_image` over a 21 × 25 box covering the left
 * arm, hip and knee. The herb hand at x ≥ 38 is **outside** the mask, so the
 * herb interaction could not drift, and the boot rows at y ≥ 59 are outside it
 * too, so the feet stay planted where the neighbouring frames put them.
 *
 * Measured, not assumed: **0 pixels changed outside the mask.**
 */
const GATHER_FRAMES = 8;
const GATHER_REPAIRED = {
  5: path.join(
    EXPLORE, 'PHASE1_CARRIED_CORRECTIONS', 'out', 'gather_f5_repaired.png',
  ),
};
const gather = [];
for (let i = 0; i < GATHER_FRAMES; i++) {
  const frame = png.load(
    GATHER_REPAIRED[i] ?? path.join(STABLE, 'animation', `gather_trim_f${i}.png`),
  );
  gather.push(frame);
  emit(`anim/gather_f${i}.png`, encode(frame));
}

/**
 * REGION MAP — 384 × 640, with the watercourse terminus corrected.
 *
 * `PIXELLAB_STABILIZATION_01` recorded this one as **NOT CLOSED**. A tarn had
 * been generated at the stream's end and verified objectively — blue pixels
 * went 132 → 267 — and it still failed the only test that matters: at native
 * scale a blind reviewer looking directly at its coordinates reported the
 * stream *"narrows by perhaps a pixel and stops… no pool, no pond, no marsh"*.
 * The pool was about 20 px across on a 384 × 640 map and its blue sat close to
 * the grass in value.
 *
 * The correction is one `inpaint_image` over a 96 × 96 window, pasted back
 * here. Two things made it work where the previous attempt had not:
 *
 * - **Value, not area.** The brief asked for water *darker in value than the
 *   surrounding grass*. The earlier tarn was the right size and the wrong
 *   contrast, which is why measuring blue pixels said it had worked and looking
 *   at it said it had not.
 * - **An elliptical mask, not a rectangle.** The first attempt here used a
 *   rectangular mask and produced exactly the artefact the stabilization pass
 *   found when it inpainted a tavern floor: a visible hard-edged patch where
 *   the regenerated tone met the original. With no straight edges in the mask,
 *   the generated region cannot terminate along a line the eye reads as a
 *   boundary. That attempt was discarded rather than shipped.
 *
 * The patch is stored as the 96 × 96 window rather than as a replacement map,
 * so what changed stays legible: everything outside this rectangle is the
 * approved map, byte for byte, and **0 pixels changed outside the ellipse**
 * within it.
 *
 * Still open, and deliberately not attempted here: the watercourse has no banks
 * along its length, holds a constant one-to-two-pixel width from source to
 * mouth, and its blue is the highest-chroma element on the map. Those are
 * properties of the original generation, they are a composition question rather
 * than a legibility one, and the milestone brief says not to reopen world-map
 * composition.
 */
const TARN_PATCH = { x: 120, y: 224 };

/**
 * SUPERSEDED BY THE PHASE 2 MAP — the block above is preserved as the record of
 * the Phase 1 map and its one carried correction, because the *lesson* in it
 * outlives the image: value beats area, and an elliptical mask beats a
 * rectangular one.
 *
 * The Phase 1 map is retired rather than patched. It drew four locations, and
 * the implemented world now has five — Frostmere is a real destination in the
 * travel graph with a real 1,500-step route to it, and it was nowhere on the
 * picture. A map that omits a place the World screen offers to sell you a
 * journey to is not incomplete, it is wrong.
 *
 * The Phase 2 map is generated whole rather than patched, so the tarn
 * correction does not carry forward and does not need to: this generation was
 * asked for an edge-to-edge composition and returned one, with 0 white pixels
 * on the frame edge and 0 non-opaque pixels — verified, because the first
 * attempt came back with a 15 px white border that would have shown the page
 * ground through a full-bleed banner.
 *
 * **No post-processing at all.** No key, no crop, no patch. The bytes emitted
 * are the bytes PixelLab returned, which is the simplest provenance this tree
 * has.
 */
emit(
  'world/region_map.png',
  encode(png.load(
    path.join(STABLE, 'world', 'region_map_phase2_384x640.png'),
  )),
);

/**
 * LOCATION VIGNETTE — keyed, then framed.
 *
 * Two transformations, both deliberate:
 *
 * **1. The white field becomes transparent.** PixelLab returned the diorama on
 * an opaque white ground, which is 34% of the file and is the single brightest
 * area in an otherwise dark interface. Keying is a **border flood fill**, not a
 * global colour replace, so white *inside* the art — a highlight, a lit wall
 * face — cannot be punched out by a pixel that merely matches.
 *
 * **2. It is cropped to 384 × 176 rather than displayed whole.** The source is
 * 512 wide; no phone this project targets is. The options were to downscale
 * (non-integer, and a palisade of evenly spaced posts is the worst possible
 * subject for dropped columns), to centre-clip at runtime (an arbitrary framing
 * that changes with screen width), or to choose the framing once, here, where
 * it is reviewable. The window keeps what the scene is *for*: the gate and its
 * approach trail, the lodge, the forge, the well, and grass on both flanks.
 */
const VIGNETTE_CROP = { x: 56, y: 132, width: 384, height: 176 };

function keyBorderWhite(raster, threshold = 248) {
  const { width, height } = raster;
  const seen = new Uint8Array(width * height);
  const isWhite = (x, y) => {
    const i = raster.idx(x, y);
    return raster.data[i] >= threshold
      && raster.data[i + 1] >= threshold
      && raster.data[i + 2] >= threshold;
  };

  const stack = [];
  for (let x = 0; x < width; x++) stack.push([x, 0], [x, height - 1]);
  for (let y = 0; y < height; y++) stack.push([0, y], [width - 1, y]);

  let cleared = 0;
  while (stack.length > 0) {
    const [x, y] = stack.pop();
    if (x < 0 || y < 0 || x >= width || y >= height) continue;
    const k = (y * width) + x;
    if (seen[k] === 1 || !isWhite(x, y)) continue;
    seen[k] = 1;
    raster.data[raster.idx(x, y) + 3] = 0;
    cleared++;
    stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  return cleared;
}

/**
 * Every location's crop window, chosen once and reviewable here.
 *
 * `x` is 64 on all four Phase 2 scenes — (512 − 384) / 2, a true horizontal
 * centre — because none of them has a subject pushed to one side the way Haven's
 * Rest's gate does. Haven's Rest keeps its authored 56 and is deliberately left
 * alone; re-centring it would move a framing the owner has already seen on a
 * device for no reason but symmetry.
 *
 * `y` is the part that carries judgement, and each is written down with what the
 * window is *for* — the same standard the Haven's Rest note above sets. A crop
 * is 46% of a 384 × 176 band's content decision, and "it looked fine" is not a
 * reason a later reader can check.
 */
const VIGNETTE_CROPS = {
  // The gate and its approach trail, the lodge, the forge, the well, and grass
  // on both flanks. Authored for Phase 1 and unchanged.
  havens_rest: { x: 56, y: 132 },

  // Trunk bases rather than canopy. The band that says "deep forest" is the one
  // with the path running into darkness between thick trunks; the canopy above
  // is atmosphere and reads as an undifferentiated green mass at 176 px.
  whispering_woods: { x: 64, y: 150 },

  // The adit mouth **with its timber lintel intact**, and the rails running out
  // of it. The first attempt at y 96 sheared the top beam off the frame and left
  // a dark hole in a rock face, which reads as a cave rather than as a working
  // mine — the whole point of the scene is that someone timbered it. Raising the
  // window to 64 costs the ore cart at the bottom, and that is the right trade:
  // the frame says "mine", the cart only says "worked".
  stonefall_mine: { x: 64, y: 64 },

  // The frozen tarn and both flanks that explain it: dark conifer below the
  // treeline on the left, bare scree above it on the right. Cropping to the ice
  // alone would lose the altitude, which is the whole identity of the place.
  frostmere: { x: 64, y: 104 },

  // The ruin in the bottom of the hollow, with the lip of the vale above it and
  // the standing damp below. The bare branches at the top are the mood and the
  // ruin is the subject, so the window favours the ruin.
  forgotten_hollow: { x: 64, y: 128 },
};

for (const [id, window] of Object.entries(VIGNETTE_CROPS)) {
  const vignette = png.load(
    path.join(STABLE, 'location', `${id}_vignette_512x384.png`),
  );
  // Harmless where there is no white ground — a border flood fill on an image
  // whose edge pixels are dark clears nothing at all.
  keyBorderWhite(vignette);
  emit(
    `location/${id}.png`,
    encode(png.crop(
      vignette,
      window.x, window.y,
      VIGNETTE_CROP.width, VIGNETTE_CROP.height,
    )),
  );
}

// ------------------------------------------------- Transformation Build 01

const TRANSFORM = path.join(EXPLORE, 'TRANSFORMATION_01', 'out');

/**
 * AMBIENT SCENES — the Traveler's downtime and the orange cat.
 *
 * Read from the PixelLab manifest, so the frame counts here cannot disagree
 * with what the art stream delivered. Everything is a straight copy except the
 * three 80 × 80 scenes, which are **cropped to 80 × 64 at rows 8..71**: the art
 * stream cut them from the same 88 px source 8 px further out on every side, so
 * dropping the top 8 rows and the bottom 8 puts the feet back on row 62 — the
 * row every 64 × 64 Traveler frame stands on — while keeping the width the
 * raised arms and the pick head need. A wider frame then shares the stage with
 * the rest pose without the figure jumping (`ambient_scene.dart` `anchorX`).
 *
 * The 96 × 64 combined Traveler + cat sprite is copied whole; its anchor is
 * declared in the scene table, not here.
 *
 * Footprints are measured on frame 0 of every sequence and emitted below, one
 * per sequence, so a companion cat gets its own derived contact shadow.
 */
const AMBIENT_SRC = path.join(TRANSFORM, 'ambient');
const ambientManifest = JSON.parse(
  fs.readFileSync(path.join(AMBIENT_SRC, 'manifest.json'), 'utf8'),
);
const AMBIENT_FIX_SRC = path.join(
  EXPLORE, 'PLAYABLE_EXPANSION_01', 'out', 'ambient',
);
const AMBIENT_FIX_OVERRIDES = new Set(['traveler_pick_inspect']);
const ambientFixManifest = [
  ...JSON.parse(fs.readFileSync(path.join(AMBIENT_FIX_SRC, 'manifest.json'), 'utf8')),
  ...JSON.parse(fs.readFileSync(path.join(AMBIENT_FIX_SRC, 'withheld_manifest.json'), 'utf8'))
    .filter((entry) => AMBIENT_FIX_OVERRIDES.has(entry.id)),
];
const ambientFixIds = new Set(ambientFixManifest.map((e) => e.id));

/**
 * WORLD & REWARD DEPTH 01 — ambient (`WORLD_REWARD_DEPTH_01/ambient/README.md`).
 * A third pass, run after the PE01 corrections: `manifest.json` holds only the
 * sequences the blind Visual QA passed (the book-scale `traveler_read`
 * replacing the PE01 one, and the two micro-idles for the idle cadence). Every
 * id in it supersedes the same id in the earlier passes.
 */
const AMBIENT_WRD_SRC = path.join(
  EXPLORE, 'WORLD_REWARD_DEPTH_01', 'ambient', 'out', 'ambient',
);
const ambientWrdManifest = JSON.parse(
  fs.readFileSync(path.join(AMBIENT_WRD_SRC, 'manifest.json'), 'utf8'),
);
const ambientWrdIds = new Set(ambientWrdManifest.map((e) => e.id));

const AMBIENT_TALL_CROP = { y: 8, height: 64 };
const ambientFootprints = {};
for (const entry of ambientManifest) {
  // Superseded by the Playable Expansion 01 correction pass below; emitting the
  // original here would make `--check` report the corrected file as stale.
  if (ambientFixIds.has(entry.id) || ambientWrdIds.has(entry.id)) continue;
  const [w, h] = Array.isArray(entry.canvas)
    ? entry.canvas
    : [entry.canvas, entry.canvas];
  for (let i = 0; i < entry.frames; i++) {
    const src = path.join(AMBIENT_SRC, `${entry.id}_f${i}.png`);
    let frame = png.load(src);
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (entry.id.startsWith('traveler_') && h === 80) {
      frame = png.crop(frame, 0, AMBIENT_TALL_CROP.y, w, AMBIENT_TALL_CROP.height);
    }
    if (i === 0) ambientFootprints[`ambient_${entry.id}`] = png.footprint(frame);
    emit(`ambient/${entry.id}_f${i}.png`, encode(frame));
  }
}

/**
 * AMBIENT CORRECTIONS — Playable Expansion 01 (`PLAYABLE_EXPANSION_01/ambient/
 * README.md`). A second pass over a second manifest, run AFTER the
 * Transformation set so a corrected sequence overwrites the original by id.
 *
 * `manifest.json` holds the sequences Visual QA passed at ×2 (`traveler_read`).
 * `withheld_manifest.json` holds the rest; ONE of them is packaged by lead
 * override, recorded in the README's disposition: `traveler_pick_inspect`, whose
 * QA line was PASS-WITH-NOTE "holding a pick, not mining; second read
 * idle-with-tool" — which is the read the correction was for. Everything else
 * in that file stays out of the shipped tree; the current assets stand.
 *
 * All 64 × 64, feet on row 62 (63 in the pick crouch frames), so no tall-crop
 * branch. Frame counts differ from the T01 originals (read 9 → 9, pick 9 → 7):
 * the T01 frames beyond the new count are simply not emitted, and the
 * `--check` sweep below reports them as unexpected if they linger.
 */
for (const entry of ambientFixManifest) {
  if (ambientWrdIds.has(entry.id)) continue; // superseded below
  const [w, h] = Array.isArray(entry.canvas)
    ? entry.canvas
    : [entry.canvas, entry.canvas];
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(path.join(AMBIENT_FIX_SRC, `${entry.id}_f${i}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i} (correction): expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (i === 0) ambientFootprints[`ambient_${entry.id}`] = png.footprint(frame);
    emit(`ambient/${entry.id}_f${i}.png`, encode(frame));
  }
}

for (const entry of ambientWrdManifest) {
  const [w, h] = Array.isArray(entry.canvas)
    ? entry.canvas
    : [entry.canvas, entry.canvas];
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(path.join(AMBIENT_WRD_SRC, `${entry.id}_f${i}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i} (WRD01): expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (i === 0) ambientFootprints[`ambient_${entry.id}`] = png.footprint(frame);
    emit(`ambient/${entry.id}_f${i}.png`, encode(frame));
  }
}

/**
 * WORLD ATLAS — the base geography, five landmarks, scatter props and the
 * ambient overlays (Transformation Build 01, stream C).
 *
 * The base is `create_image_pro` at 384 × 688 — the API's maximum for a 9:16
 * portrait — shown at ×2 by the atlas viewport (`atlas_layout.json` scale 2).
 * Straight copies, no post-processing: PixelLab returned an edge-to-edge
 * composition with 0 border pixels and 0 non-opaque pixels, verified by the
 * stream. Landmark and prop cutouts are `create_map_object` outputs whose
 * palette was conformed to the base by a deterministic nearest-colour remap
 * (A-2), recorded in `TRANSFORMATION_01/world/README.md`.
 *
 * Every world coordinate lives in `assets/content/v1/atlas/atlas_layout.json`,
 * not here. This step only moves and renames.
 */
// The Transformation base tile and the five landmark cutouts are retired by
// Activity Feel & Presentation 01: the atlas base is now ONE master painting
// (`world/atlas_master`, below) with every settlement and landmark painted in,
// so the layout references neither the old tiles nor any cutout. The sources
// stay in `TRANSFORMATION_01/out/world/`; only the emission is removed.
const ENV_SRC = path.join(TRANSFORM, 'env');
for (const file of fs.readdirSync(ENV_SRC).filter((f) => f.endsWith('.png'))) {
  // `prop_lone_oak_48x48.png` → `env/prop_lone_oak.png`;
  // `overlay_forest_mist_96x48_f3.png` → `env/overlay_forest_mist_f3.png`.
  const dest = file.replace(/_\d+x\d+(_f\d+)?\.png$/, '$1.png');
  emit(`env/${dest}`, encode(png.load(path.join(ENV_SRC, file))));
}

/**
 * WORLD ATLAS — World & Reward Depth 01 (`WORLD_REWARD_DEPTH_01/world/
 * README.md`, `PACKAGING.md`, `QA_VERDICT_ROUND1.md`). The round produced a
 * 2 × 2 tile grid; **two independent blind Visual QA passes failed the
 * composite on seam continuity** (hard hue / value / texture lines at the
 * east and south-east joins), while the base ↔ south join held. So the shipped
 * world is the **base + south** column (384 × 1376 native, ×2 in the
 * viewport): one more tile, the five location-kind marker glyphs, and only
 * the scatter / seam props the layout places. The east and south-east tiles,
 * the four landmark cutouts (unplaced — the tiles already draw those
 * features) and the unused props stay in the exploration directory,
 * withheld, for a future round. Straight copies: the round conformed every
 * cutout's palette to the base (A-2) and keyed the pick glyph's pad to
 * transparent (A-2, keying). Every world coordinate lives in
 * `atlas_layout.json`, not here.
 */
// `atlas_south` is retired with the base tile (see above); the kind-marker
// glyphs stay — the new layout's `kindMarkers` block still names them.
const WRD = path.join(EXPLORE, 'WORLD_REWARD_DEPTH_01', 'world', 'out');
const WORLD_WRD_FILES = {
  'marker_haven_20x20.png': 'world/marker_haven.png',
  'marker_wilds_20x20.png': 'world/marker_wilds.png',
  'marker_worksite_20x20.png': 'world/marker_worksite.png',
  'marker_perilous_20x20.png': 'world/marker_perilous.png',
  'marker_landmark_20x20.png': 'world/marker_landmark.png',
};
for (const [src, dest] of Object.entries(WORLD_WRD_FILES)) {
  const raster = png.load(path.join(WRD, 'world', src));
  const [, w, h] = src.match(/_(\d+)x(\d+)\.png$/).map(Number);
  if (raster.width !== w || raster.height !== h) {
    throw new Error(`${src}: expected ${w}x${h}, got ${raster.width}x${raster.height}`);
  }
  emit(dest, encode(raster));
}
// No WRD01 env props ship: every placed prop on the base + south column is one
// the Transformation set already has (oak, pine clump, hedgerow, dead tree);
// the crag / dune / sea stack / reed and strip props belong to the withheld
// tiles and stay in `WORLD_REWARD_DEPTH_01/world/out/env/`.

/**
 * ITEM ICONS — the nine that rendered the placeholder slab until now, and the
 * eight gather-node vignettes (Transformation Build 01, stream F).
 *
 * Same 48 × 48 family and rules as `ITEM_ICONS` above; only the source root
 * differs. The node art is a new family: 96 × 96, transparent, no figures,
 * drawn on the Adventure gather card.
 */
const ITEMS_SRC = path.join(TRANSFORM, 'items');
const ITEM_ICONS_T01 = [
  'hollow_root', 'pine_plank', 'bronze_sword', 'bronze_axe', 'bronze_pickaxe',
  'bronze_chestplate', 'herb_broth', 'hearty_stew', 'hollow_sigil',
];
for (const id of ITEM_ICONS_T01) {
  const raster = png.load(path.join(ITEMS_SRC, `icon_${id}_48.png`));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`icon_${id}_48: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id}.png`, encode(raster));
}
const NODE_ART = [
  'meadow_patch', 'oak_stand', 'duskcap_grove', 'copper_seam', 'tin_seam',
  'rimefrost_hollow', 'frostpine_stand', 'hollow_thicket',
];
for (const id of NODE_ART) {
  const raster = png.load(path.join(ITEMS_SRC, `node_${id}_96.png`));
  if (raster.width !== 96 || raster.height !== 96) {
    throw new Error(`node_${id}_96: expected 96x96, got ${raster.width}x${raster.height}`);
  }
  emit(`node/${id}.png`, encode(raster));
}

// ------------------------------------------------- Playable Expansion 01

/**
 * COMBAT STAGE — the Traveler's east-facing combat set, the three enemies
 * (west-facing), the hit effects and the three side-view backdrops
 * (Combat Slice 01, `GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md` §10).
 *
 * Read from the combat manifest so frame counts, canvases and baselines cannot
 * disagree with what the art round delivered. Everything is a straight copy:
 * the art round already cropped every Traveler frame to the 64 × 64 anchor
 * (feet on row 62, the same row as `sprite/traveler_south.png` and the ambient
 * set) or to 80 × 64 for the wide attack, and every enemy to one fixed square
 * canvas per enemy (wolf 56, goblin 56, guardian 96) with a constant standing
 * baseline (`anchor` in the manifest). Backdrops are 192 × 96, drawn at ×2.
 *
 * Sequences the manifest marks `withheld` are still emitted — the frames are
 * packaged so a correction round can compare against them — but the manifest
 * status is the contract: the stage must not draw a withheld sequence.
 *
 * Footprints are measured on frame 0 of every figure sequence and emitted as
 * `combat_<id>`, so an enemy gets its own derived contact shadow.
 */
const COMBAT_SRC = path.join(EXPLORE, 'PLAYABLE_EXPANSION_01', 'out', 'combat');
const combatManifest = JSON.parse(
  fs.readFileSync(path.join(COMBAT_SRC, 'manifest.json'), 'utf8'),
);
const combatFootprints = {};
for (const entry of combatManifest) {
  const [w, h] = entry.canvas;
  if (entry.kind === 'backdrop') {
    const frame = png.load(path.join(COMBAT_SRC, `${entry.id}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    emit(`combat/${entry.id}.png`, encode(frame));
    continue;
  }
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(path.join(COMBAT_SRC, `${entry.id}_f${i}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (i === 0 && entry.kind !== 'effect') {
      combatFootprints[`combat_${entry.id}`] = png.footprint(frame);
    }
    emit(`combat/${entry.id}_f${i}.png`, encode(frame));
  }
}

/**
 * WORLD & REWARD DEPTH 01 — the Frost Lynx (Frostmere's first enemy, west-
 * facing, 56² canvas, anchor row 39), the alpine backdrop, and four item icons
 * (`WORLD_REWARD_DEPTH_01/{combat,items}/README.md`). Only manifest entries
 * with status `accepted` — the blind Visual QA verdict — are emitted;
 * `lynx_hit` is withheld (reads as a prowl) and the stage recoils the figure.
 */
const COMBAT_WRD_SRC = path.join(
  EXPLORE, 'WORLD_REWARD_DEPTH_01', 'combat', 'out', 'combat',
);
const combatWrdManifest = JSON.parse(
  fs.readFileSync(path.join(COMBAT_WRD_SRC, 'manifest.json'), 'utf8'),
).filter((entry) => entry.status === 'accepted');
for (const entry of combatWrdManifest) {
  const [w, h] = Array.isArray(entry.canvas)
    ? entry.canvas
    : [entry.canvas, entry.canvas];
  if (entry.kind === 'backdrop') {
    const frame = png.load(path.join(COMBAT_WRD_SRC, `${entry.id}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    emit(`combat/${entry.id}.png`, encode(frame));
    continue;
  }
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(path.join(COMBAT_WRD_SRC, `${entry.id}_f${i}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (i === 0) combatFootprints[`combat_${entry.id}`] = png.footprint(frame);
    emit(`combat/${entry.id}_f${i}.png`, encode(frame));
  }
}
const ITEMS_WRD_SRC = path.join(
  EXPLORE, 'WORLD_REWARD_DEPTH_01', 'items', 'out',
);
for (const id of ['wolf_pelt', 'lynx_pelt', 'wolfhide_jerkin', 'frostlined_jerkin']) {
  const raster = png.load(path.join(ITEMS_WRD_SRC, `icon_${id}_48.png`));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`icon_${id}_48: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id}.png`, encode(raster));
}

// --------------------------------------- Activity Feel & Presentation 01

/**
 * GATHERING ACTIVITY LOOPS — the Traveler working, west-facing, one loop per
 * profession (`ACTIVITY_FEEL_01/README.md` §2). PixelLab `animate_character`
 * v3 output on large canvases (108/96/88 wide); each loop is cropped here to
 * one fixed box per loop — 64 rows tall with the feet on row 62, the ambient
 * convention — wide enough for the tool's whole swing (the union opaque box
 * of the shipped frames, measured 2026-08-20, plus margin).
 *
 * The frame lists are the blind-QA frame selection, not the raw output:
 * woodcut drops source frame 4 (the axe reads detached from the hands for
 * that one frame), mine drops 3/6/7 (stray debris flecks hover at head
 * height). Renumbered contiguously on emit. Forage ships all nine; its
 * ping-pong playback order is authored in `ambient_assets.dart`, not by
 * duplicating frames here.
 */
const ACTIVITY_SRC = path.join(EXPLORE, 'ACTIVITY_FEEL_01', 'out', 'ambient');
const ACTIVITY_LOOPS = {
  activity_woodcut: {
    src: 'woodcut2', frames: [0, 1, 2, 3, 5, 6, 7, 8],
    canvas: [108, 92], crop: { x: 14, y: 14, width: 76, height: 64 },
  },
  activity_mine: {
    src: 'mine2', frames: [0, 1, 2, 4, 5, 8],
    canvas: [96, 92], crop: { x: 13, y: 14, width: 66, height: 64 },
  },
  activity_forage: {
    src: 'forage', frames: [0, 1, 2, 3, 4, 5, 6, 7, 8],
    canvas: [88, 88], crop: { x: 16, y: 12, width: 44, height: 64 },
  },
};
for (const [id, spec] of Object.entries(ACTIVITY_LOOPS)) {
  spec.frames.forEach((srcIndex, outIndex) => {
    const frame = png.load(path.join(ACTIVITY_SRC, `${spec.src}_f${srcIndex}.png`));
    if (frame.width !== spec.canvas[0] || frame.height !== spec.canvas[1]) {
      throw new Error(
        `${spec.src}_f${srcIndex}: expected ${spec.canvas[0]}x${spec.canvas[1]}, ` +
        `got ${frame.width}x${frame.height}`,
      );
    }
    const cut = png.crop(frame, spec.crop.x, spec.crop.y, spec.crop.width, spec.crop.height);
    if (outIndex === 0) ambientFootprints[`ambient_${id}`] = png.footprint(cut);
    emit(`ambient/${id}_f${outIndex}.png`, encode(cut));
  });
}

/**
 * WORLD MASTER — the whole landmass as ONE 384 × 688 painting, displayed at
 * atlas scale 4 (1536 × 2752 world px). Replaces the retired base + south
 * tile column: a single generation cannot have a seam, which is `MISTAKES.md`
 * M-12 applied rather than survived. r2 carries one targeted inpaint (the
 * Forgotten Hollow cave region, blind-QA MAJOR in r1). Straight copy;
 * provenance and both blind verdicts in `ACTIVITY_FEEL_01/README.md` §1.
 */
const AF_WORLD_SRC = path.join(EXPLORE, 'ACTIVITY_FEEL_01', 'out', 'world');
{
  const master = png.load(path.join(AF_WORLD_SRC, 'atlas_master_384x688.png'));
  if (master.width !== 384 || master.height !== 688) {
    throw new Error(`atlas_master: expected 384x688, got ${master.width}x${master.height}`);
  }
  emit('world/atlas_master.png', encode(master));
}

/**
 * WORLD LIFE — a drifting bird-flock overlay (three dark silhouettes, six
 * frames, seamless: the last generated frame was pinned to the first).
 * Straight copies; placed by `atlas_layout.json` like every overlay.
 */
const AF_ENV_SRC = path.join(EXPLORE, 'ACTIVITY_FEEL_01', 'out', 'env');
for (let i = 0; i < 6; i++) {
  const frame = png.load(path.join(AF_ENV_SRC, `overlay_birds_24x24_f${i}.png`));
  if (frame.width !== 24 || frame.height !== 24) {
    throw new Error(`overlay_birds_f${i}: expected 24x24, got ${frame.width}x${frame.height}`);
  }
  emit(`env/overlay_birds_f${i}.png`, encode(frame));
}

// -------------------------------------------------------- footprint metrics

/**
 * The contact span of every sprite that can be placed on a background.
 *
 * The animation is measured on its **rest frame only**, and every frame shares
 * that one footprint. Measuring each frame would be more faithful and would
 * look wrong: the figure crouches, so a per-frame shadow would swell and shrink
 * underneath a character whose feet never move. The ground contact is a
 * property of where the figure is standing, not of what its arms are doing.
 */
const footprints = {
  'traveler_south': png.footprint(spriteSouth),
  'gather': png.footprint(gather[0]),
  ...ambientFootprints,
  ...combatFootprints,
};

const dart = `// GENERATED by Scripts/art/package-art.js — do not edit by hand.
//
// Where each sprite meets the ground, in sprite-local pixel coordinates.
//
// This table is what makes the contact shadow *derived from the sprite* rather
// than tuned per scene. A caller places a sprite; it never supplies a shadow
// width, so the shadow cannot disagree with the figure standing on it.
//
// Measured across the lowest four opaque rows of the sprite, which is the part
// touching the ground — not the opaque bounding box, which would include the
// head and the backpack.
library;

/// The ground-contact span of one sprite.
final class SpriteFootprint {
  const SpriteFootprint({
    required this.left,
    required this.right,
    required this.bottom,
  });

  /// Leftmost contact column, sprite-local.
  final int left;

  /// Rightmost contact column, sprite-local.
  final int right;

  /// The sprite's lowest opaque row.
  final int bottom;

  /// Contact width in sprite pixels.
  int get width => right - left + 1;

  /// The horizontal centre of the contact span, sprite-local.
  double get centerX => (left + right + 1) / 2;
}

abstract final class SpriteFootprints {
${Object.entries(footprints).map(([name, f]) => `  /// \`${name}\` — ${f.width} px of contact, ${f.left}..${f.right}.
  static const SpriteFootprint ${name.replace(/_(.)/g, (_, c) => c.toUpperCase())} = SpriteFootprint(
    left: ${f.left},
    right: ${f.right},
    bottom: ${f.bottom},
  );`).join('\n\n')}
}
`;

if (checkOnly) {
  if (!fs.existsSync(FOOTPRINT_DART)
      || fs.readFileSync(FOOTPRINT_DART, 'utf8') !== dart) {
    problems.push('stale:   lib/ui/icons/sprite_footprints.dart');
  }
} else {
  fs.writeFileSync(FOOTPRINT_DART, dart);
}

// ------------------------------------------------------------------- report

/** Every file this script is responsible for, so a stray one is detectable. */
if (checkOnly) {
  const walk = (dir, prefix = '') => {
    if (!fs.existsSync(dir)) return [];
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
      e.isDirectory()
        ? walk(path.join(dir, e.name), `${prefix}${e.name}/`)
        : [`${prefix}${e.name}`]);
  };
  for (const found of walk(DEST)) {
    if (found.endsWith('.md')) continue;
    if (!emitted.has(found)) problems.push(`unexpected: assets/art/v1/${found}`);
  }

  if (problems.length > 0) {
    console.error('Shipped art does not match the packaging step:\n');
    for (const p of problems) console.error(`  ${p}`);
    console.error('\nRun: node Scripts/art/package-art.js');
    process.exit(1);
  }
  console.log(`art packaging: ${emitted.size} files up to date`);
} else {
  console.log(`art packaging: wrote ${emitted.size} files to assets/art/v1/`);
  for (const [name, footprint] of Object.entries(footprints)) {
    console.log(
      `  footprint ${name}: x ${footprint.left}..${footprint.right} `
      + `(${footprint.width} px), bottom ${footprint.bottom}`,
    );
  }
}
