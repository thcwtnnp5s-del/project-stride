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
// PLAYABLE_POLISH_02 replaces the Traveler's combat idle: the PE01 v3 output
// drifted to three-quarter view and read as facing away from the enemy on
// the owner's device. The PE01 frames stay in the exploration tree as
// evidence; the replacement is emitted in the Polish 02 section below.
const REPLACED_BY_POLISH2 = new Set(['traveler_combat_idle']);
const combatFootprints = {};
for (const entry of combatManifest) {
  if (REPLACED_BY_POLISH2.has(entry.id)) continue;
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
// PLAYABLE_POLISH_01 §1: the mining loop is re-authored. The ACTIVITY_FEEL_01
// loop (`mine2`) was a west-facing figure whose strike landed EAST — behind
// his own back — so the stage had to put the seam behind him to get the
// pick to touch it, and the owner's device read the whole scene as
// backward. `mine3a` raises the pick over the shoulder and brings it down
// in FRONT (west), like every other profession, so the seam goes back to
// the west with the rest of the props. Frame 5 (the pick passing directly
// over the head, reading as a halo) is dropped; the rest ship in order.
const POLISH_AMBIENT_SRC = path.join(
  EXPLORE, 'PLAYABLE_POLISH_01', 'out', 'ambient',
);
const ACTIVITY_LOOPS = {
  activity_woodcut: {
    src: 'woodcut2', frames: [0, 1, 2, 3, 5, 6, 7, 8],
    canvas: [108, 92], crop: { x: 14, y: 14, width: 76, height: 64 },
  },
  activity_mine: {
    dir: POLISH_AMBIENT_SRC,
    src: 'mine3a', frames: [0, 1, 2, 3, 4, 6, 7, 8],
    canvas: [96, 96], crop: { x: 12, y: 16, width: 60, height: 64 },
  },
  activity_forage: {
    src: 'forage', frames: [0, 1, 2, 3, 4, 5, 6, 7, 8],
    canvas: [88, 88], crop: { x: 16, y: 12, width: 44, height: 64 },
  },
};
for (const [id, spec] of Object.entries(ACTIVITY_LOOPS)) {
  spec.frames.forEach((srcIndex, outIndex) => {
    const frame = png.load(
      path.join(spec.dir ?? ACTIVITY_SRC, `${spec.src}_f${srcIndex}.png`),
    );
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
 * DEFEAT STAGGER — the Traveler driven to one knee, east-facing (the combat
 * stage's orientation), for the driven-back sequence the device pass asked
 * for (correction §15: "I lost the fight and had to retreat", never a
 * corpse). Nine v3 frames on an 88² canvas, cropped like the activity loops
 * to one fixed box with the STANDING frame's ground on row 62 — the fall is
 * what moves, the ground must not. Footprint measured on frame 0 (standing),
 * the rest-frame convention.
 */
const AF_COMBAT_SRC = path.join(EXPLORE, 'ACTIVITY_FEEL_01', 'out', 'combat');
{
  const crop = { x: 16, y: 12, width: 56, height: 64 };
  for (let i = 0; i <= 8; i++) {
    const frame = png.load(path.join(AF_COMBAT_SRC, `stagger_f${i}.png`));
    if (frame.width !== 88 || frame.height !== 88) {
      throw new Error(`stagger_f${i}: expected 88x88, got ${frame.width}x${frame.height}`);
    }
    const cut = png.crop(frame, crop.x, crop.y, crop.width, crop.height);
    if (i === 0) combatFootprints['combat_traveler_stagger'] = png.footprint(cut);
    emit(`combat/traveler_stagger_f${i}.png`, encode(cut));
  }
}

/**
 * WORLD MASTER — the whole landmass as ONE 384 × 688 painting, displayed at
 * atlas scale 4 (1536 × 2752 world px). Replaces the retired base + south
 * tile column: a single generation cannot have a seam, which is `MISTAKES.md`
 * M-12 applied rather than survived.
 *
 * Correction pass, 2026-08-20: the source is now the CONTINENT master
 * (master3_r3) — the device pass judged the first master's world still too
 * small, so the inhabited region is re-authored as a modest north-eastern
 * slice of a continent (west cordillera, forest and lakes, tundra, southern
 * arid plains, island sea). Three targeted inpaints ride in it: the mine
 * portal, the Forgotten Hollow cave mouth, and the arched Millbridge span.
 * Blind verdicts: r2-continent FAIL (region read as pasted, landmarks
 * illegible at half scale); r3 PASS-WITH-NOTE, six of seven landmarks clean,
 * bridge fixed by the third inpaint. Straight copy; full provenance in
 * `ACTIVITY_FEEL_01/README.md`.
 */
// Superseded, 2026-08-21 (PRESENTATION_WORLD_REWARD_FEEL_01): the portrait
// AF01 master is replaced by the wide-format continent below. The AF01
// source stays in its round directory as evidence; nothing else in its
// block changes.
//
// The PWRF01 continent: one 688 × 384 PixelLab Pro generation (no seams by
// construction — M-12), style-referenced to the AF01 master (outline,
// detail, shading; palette free for the §35 regional vibrancy), corrected by
// five localized inpaints (mine adit, Whispering Woods light woodland,
// hamlet merge + town shrink, marsh legibility, marsh–sea continuity). Two
// blind Visual QA rounds: the raw candidate FAILED (mine unreadable, light
// forest missing, hamlet split, town oversized, marsh speckle); the
// corrected painting PASSED with all five playable locations blind-findable
// and every seam CLEAN or VISIBLE-BUT-ACCEPTABLE. Full provenance in
// `PRESENTATION_WORLD_REWARD_FEEL_01/out/world/README.md`.
const PWRF = path.join(EXPLORE, 'PRESENTATION_WORLD_REWARD_FEEL_01', 'out');
const PWRF_WORLD_SRC = path.join(PWRF, 'world');
{
  const master = png.load(
    path.join(PWRF_WORLD_SRC, 'whole_a_0.png'),
  );
  if (master.width !== 512 || master.height !== 512) {
    throw new Error(`atlas_master: expected 512x512, got ${master.width}x${master.height}`);
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

// Chimney smoke for the hamlet (correction pass §26). The pixen source draws
// a chimney stack under the wisp; at atlas scale 4 that stack would be a
// building-sized grey column, so packaging crops to the WISP alone (rows
// 0..13 hold it in all six frames, measured 2026-08-20) and the overlay is
// anchored over a hut roof by the layout. The rejected coastal-wave loop
// (side-view surf on a top-down sea) stays in `world_life/`, withheld.
for (let i = 0; i < 6; i++) {
  const frame = png.load(path.join(AF_ENV_SRC, `overlay_smoke_20x20_f${i}.png`));
  if (frame.width !== 20 || frame.height !== 20) {
    throw new Error(`overlay_smoke_f${i}: expected 20x20, got ${frame.width}x${frame.height}`);
  }
  emit(`env/overlay_smoke_f${i}.png`, encode(png.crop(frame, 2, 0, 16, 14)));
}

// ---------------------------------- Exploration & Progression Loop 01

/**
 * REGIONAL CONTENT PACK 01 — the three new regional enemies and the optional
 * high-danger bear, integrated from the pack's READY stage sets
 * (`REGIONAL_CONTENT_PACK_01_HANDOFF.md` §4/§6; `DECISIONS/0023`).
 *
 * Only the selected, blind-QA-accepted tracks are packaged: boar and ram and
 * salamander idle/attack/defeat, and the bear's idle, round-2 attack
 * (`bear_attack2`, the QA_PASS_D ACCEPT) and defeat. Everything the pack
 * withheld — the bat, the weaver, the crawler's defeat, `bear_attack`
 * round 1, `ram_hit` — stays withheld and is not emitted. The ram has no hit
 * track for the same reason the wolf has none: the stage recoils the figure.
 *
 * The pack's proposed content ids (`enemy.bristleback_boar` etc.) are the
 * pack's; the shipped content pack names them `enemy.wild_boar`,
 * `enemy.mountain_ram`, `enemy.salamander`, `enemy.oakback_bear` — the
 * mapping is the file id, which both sides share.
 */
const RCP_ENEMIES_SRC = path.join(
  EXPLORE, 'REGIONAL_CONTENT_PACK_01', 'out', 'enemies',
);
const RCP_SELECTED = [
  'boar_idle', 'boar_attack', 'boar_defeat',
  'ram_idle', 'ram_attack', 'ram_defeat',
  'salamander_idle', 'salamander_attack', 'salamander_defeat',
  'bear_idle', 'bear_attack2', 'bear_defeat',
];
const rcpManifest = JSON.parse(
  fs.readFileSync(path.join(RCP_ENEMIES_SRC, 'manifest.json'), 'utf8'),
).filter((entry) => RCP_SELECTED.includes(entry.id));
for (const id of RCP_SELECTED) {
  const entry = rcpManifest.find((e) => e.id === id);
  if (!entry) throw new Error(`${id}: not in the pack manifest`);
  if (entry.status !== 'accepted') {
    throw new Error(`${id}: pack status is "${entry.status}", not accepted`);
  }
}
for (const entry of rcpManifest) {
  const [w, h] = entry.canvas;
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(path.join(RCP_ENEMIES_SRC, `${entry.id}_f${i}.png`));
    if (frame.width !== w || frame.height !== h) {
      throw new Error(`${entry.id}_f${i}: expected ${w}x${h}, got ${frame.width}x${frame.height}`);
    }
    if (i === 0) combatFootprints[`combat_${entry.id}`] = png.footprint(frame);
    emit(`combat/${entry.id}_f${i}.png`, encode(frame));
  }
}

/**
 * The pack's accepted material icons for the three new materials the shipped
 * items.json names (`INTEGRATION_MANIFEST.md`; boar tusk ACCEPT, bear pelt
 * ACCEPT, ram horn PASS-WITH-NOTE — the owner call the pack recorded is
 * resolved by shipping it: the "coiled horn" read is the object).
 */
const RCP_MATERIALS_SRC = path.join(
  EXPLORE, 'REGIONAL_CONTENT_PACK_01', 'out', 'materials',
);
for (const [id, file] of Object.entries({
  boar_tusk: 'icon_boar_tusk_48.png',
  bear_pelt: 'icon_bear_pelt_48.png',
  ram_horn: 'icon_ram_horn_48.png',
})) {
  const raster = png.load(path.join(RCP_MATERIALS_SRC, file));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`${file}: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id}.png`, encode(raster));
}

/**
 * The milestone's own icon round — the new materials, the signature drops and
 * the Reinforced Pickaxe (`EXPLORATION_PROGRESSION_LOOP_01/items/README.md`).
 * Only entries the round record marks accepted are emitted; a withheld icon
 * withholds its item with it, never ships a blank slab.
 */
const EPL_ITEMS_SRC = path.join(
  EXPLORE, 'EXPLORATION_PROGRESSION_LOOP_01', 'out', 'items',
);
const eplManifest = JSON.parse(
  fs.readFileSync(path.join(EPL_ITEMS_SRC, 'manifest.json'), 'utf8'),
).filter((entry) => entry.status === 'accepted');
for (const entry of eplManifest) {
  const raster = png.load(path.join(EPL_ITEMS_SRC, entry.file));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`${entry.file}: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${entry.id}.png`, encode(raster));
}

// ------------------------------------- Presentation, World & Reward Feel 01

/**
 * The Hardened Copper Seam node vignette (PRESENTATION_WORLD_REWARD_FEEL_01
 * B-3): the one gather node REGIONAL_CONTENT_PACK_01 shipped without stage
 * art, so its activity stage rendered empty on the owner's device. Same
 * 96 × 96 transparent node family and rules as NODE_ART above; provenance
 * and the blind-QA record in
 * `GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/nodes/README.md`.
 */
const NODE_ART_PWRF = ['hardened_copper_seam'];
for (const id of NODE_ART_PWRF) {
  const raster = png.load(path.join(PWRF, 'nodes', `node_${id}_96.png`));
  if (raster.width !== 96 || raster.height !== 96) {
    throw new Error(`node_${id}_96: expected 96x96, got ${raster.width}x${raster.height}`);
  }
  emit(`node/${id}.png`, encode(raster));
}


// ------------------------------------- Presentation, World & Reward Feel 01

/**
 * CRAFT ACTIVITY LOOPS — the Traveler making something, west-facing, one
 * loop per craft profession, and the two station props they work at
 * (PRESENTATION_WORLD_REWARD_FEEL_01 §17).
 *
 * Same family and same rules as the gathering loops above: PixelLab
 * `animate_character` v3 on the canonical Traveler, cropped here to a 64-row
 * box with the feet on row 62 so a craft loop and a gather loop stand on the
 * same ground line and the figure never jumps between them.
 *
 * The frame lists are the blind-QA frame selection, not the raw output. Both
 * loops drop their leading reference frames, where the Traveler is empty
 * handed: a working loop that starts without its tool and then pops one into
 * frame reads as a glitch, and the loop only ever plays while a craft is
 * actually running. Renumbered contiguously on emit.
 *
 * The stations are ×1 scenery, not figures — the same role the node
 * vignettes play on the gathering stage.
 */
const PWRF_CRAFT_SRC = path.join(PWRF, 'craft');
const CRAFT_LOOPS = {
  activity_smith: {
    src: 'smith4', frames: [2, 3, 4, 5, 6, 7, 8],
    canvas: [88, 88], crop: { x: 6, y: 12, width: 74, height: 64 },
  },
  activity_cook: {
    src: 'cook', frames: [2, 3, 4, 5, 6, 7, 8],
    canvas: [88, 88], crop: { x: 15, y: 12, width: 46, height: 64 },
  },
};
for (const [id, spec] of Object.entries(CRAFT_LOOPS)) {
  spec.frames.forEach((srcIndex, outIndex) => {
    const frame = png.load(
      path.join(PWRF_CRAFT_SRC, `${spec.src}_f${srcIndex}.png`),
    );
    if (frame.width !== spec.canvas[0] || frame.height !== spec.canvas[1]) {
      throw new Error(
        `${spec.src}_f${srcIndex}: expected ${spec.canvas[0]}x${spec.canvas[1]}, ` +
        `got ${frame.width}x${frame.height}`,
      );
    }
    const cut = png.crop(
      frame, spec.crop.x, spec.crop.y, spec.crop.width, spec.crop.height,
    );
    if (outIndex === 0) ambientFootprints[`ambient_${id}`] = png.footprint(cut);
    emit(`ambient/${id}_f${outIndex}.png`, encode(cut));
  });
}
// The stations are authored 64 x 48 and shipped on a 64-square canvas,
// bottom-aligned: `StageScenery` places scenery by one native edge, so a
// non-square prop would be drawn into a square box and stretched. Padding
// with transparent rows is a lossless deterministic transform (`RULES.md`
// A-2) and keeps the measured bounds honest — they simply shift down by the
// pad.
for (const id of ['station_forge', 'station_cookfire']) {
  const raster = png.load(path.join(PWRF_CRAFT_SRC, `${id}_64x48.png`));
  if (raster.width !== 64 || raster.height !== 48) {
    throw new Error(`${id}: expected 64x48, got ${raster.width}x${raster.height}`);
  }
  const square = new png.Raster(64, 64);
  png.blit(square, raster, 0, 16);
  emit(`node/${id}.png`, encode(square));
}

/**
 * WORK STAGES — the focused profession compositions
 * (PRESENTATION_WORLD_REWARD_FEEL_01 correction round, §3–§5).
 *
 * Two kinds of asset, one per profession family and one per resource:
 *
 * - **Backdrops**, 384 × 176, the location vignettes' own frame size. A
 *   deliberately plain place for a figure to stand in front of: a rock face,
 *   a stand of trunks, a scrub bank. They replace the full location painting
 *   while an activity is selected, because the owner's device found the idle
 *   painting, the Traveler, the cat and a resource all competing inside one
 *   176 dp band.
 *
 * - **Props**, 96 × 96 transparent, the near thing the tool lands on. Placed
 *   by `AmbientStageLayout.propRect` on the figure's own ground line, not in
 *   the far scenery slot. Three of them are inpainted from one accepted rock,
 *   so Copper, Tin and Hardened Copper are the same outcrop with different
 *   metal in it — the interchangeable resource object the brief asked for,
 *   rather than a bespoke scene per ore.
 *
 * A node with no work prop falls back to its ordinary node vignette, still
 * placed at the interaction point. Provenance and the blind-QA record in
 * `GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/stage/README.md`.
 */
const PWRF_STAGE_SRC = path.join(PWRF, 'stage');
// PLAYABLE_EXPERIENCE_REFINEMENT_01 §6: the mining and woodcutting backdrops
// were re-authored for region identity (the owner's device found the first
// mining plate "a test chamber"). Provenance, the rejected candidates and
// the reason the mining plate ships mirrored are in the source README.
const PER01_STAGE_SRC = path.join(
  EXPLORE,
  'PLAYABLE_EXPERIENCE_REFINEMENT_01',
  'out',
  'stage',
);
/** A horizontal mirror: a deterministic transform that invents nothing (A-2). */
function flipX(src) {
  const out = new png.Raster(src.width, src.height);
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < src.width; x++) {
      const from = src.idx(x, y);
      const to = out.idx(src.width - 1 - x, y);
      out.data[to] = src.data[from];
      out.data[to + 1] = src.data[from + 1];
      out.data[to + 2] = src.data[from + 2];
      out.data[to + 3] = src.data[from + 3];
    }
  }
  return out;
}
const WORK_BACKDROPS = {
  mining: { dir: PER01_STAGE_SRC, src: 'mine_rock_s7', flip: false },
  woodcutting: { dir: PER01_STAGE_SRC, src: 'woods_open_s7', flip: false },
  foraging: { dir: PWRF_STAGE_SRC, src: 'work_foraging_0', flip: false },
};
for (const [id, { dir, src, flip }] of Object.entries(WORK_BACKDROPS)) {
  let raster = png.load(path.join(dir, `${src}.png`));
  if (flip) raster = flipX(raster);
  if (raster.width !== 384 || raster.height !== 176) {
    throw new Error(
      `work ${id}: expected 384x176, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`work/bg_${id}.png`, encode(raster));
}

// PLAYABLE_POLISH_01 §2: the three ore seams are re-authored. The PWRF
// props were one boulder with the vein patch swapped, and the owner's device
// read them as "the same node with a pasted overlay". Each seam is now its
// own generation under one shared prompt skeleton, differing only in the
// material clause — copper: warm orange-brown veins in blue-grey slate;
// tin: wide pale silver bands in darker slate; hardened copper: a denser,
// darker, blockier outcrop with thick dull bronze bands and jutting
// crystals. Candidates, seeds and rejections in the round's README.
const POLISH_PROP_SRC = path.join(
  EXPLORE, 'PLAYABLE_POLISH_01', 'out', 'props',
);
const WORK_PROPS = {
  copper_seam: { dir: POLISH_PROP_SRC, src: 'prop_copper_seam_96' },
  tin_seam: { dir: POLISH_PROP_SRC, src: 'prop_tin_seam_96' },
  hardened_copper_seam: {
    dir: POLISH_PROP_SRC, src: 'prop_hardened_copper_seam_96',
  },
  oak_stand: { dir: PWRF_STAGE_SRC, src: 'prop_wood_a_2' },
  meadow_patch: { dir: PWRF_STAGE_SRC, src: 'prop_forage_a_0' },
  duskcap_grove: { dir: PWRF_STAGE_SRC, src: 'prop_duskcap_0' },
};
for (const [id, { dir, src }] of Object.entries(WORK_PROPS)) {
  const raster = png.load(path.join(dir, `${src}.png`));
  if (raster.width !== 96 || raster.height !== 96) {
    throw new Error(
      `prop ${id}: expected 96x96, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`work/prop_${id}.png`, encode(raster));
}

// ------------------------------------------------- Playable Polish 02

/**
 * THE CRAFT SCENES AND THE GUARD IDLE RE-AUTHOR (the physical-device polish
 * pass; provenance and review in `PLAYABLE_POLISH_02/README.md`).
 *
 * - Three craft work backdrops, the same 384 × 176 family as the profession
 *   work backdrops: the smithy interior, the carpenter's workshop, the
 *   hearth. Keyed by workstation, not by profession — an oak plank is bench
 *   work even though Smithing owns it (`RecipeDefinition.station`).
 * - Three 96² station props the figure works at: anvil, bench, cookpot.
 *   These supersede the 64² `node/station_*.png` pair on the craft stage
 *   (the owner's device read the old scale as "a tiny forge in a box");
 *   the old files stay packaged for the exploration record.
 * - The Traveler's combat guard idle, re-authored east-in-profile with the
 *   sword visible (see `REPLACED_BY_POLISH2` above). Raw 96 × 88 frames are
 *   cropped here to an 80 × 64 canvas with the feet on row 62 — the same
 *   crop-at-packaging rule the vignettes follow, from the manifest's own
 *   `crop` offsets, so the transformation is recorded and reproducible.
 */
const POLISH2 = path.join(EXPLORE, 'PLAYABLE_POLISH_02', 'out');
const CRAFT_BACKDROPS = {
  smithing: 'bg_smithing_384',
  woodworking: 'bg_woodworking_384',
  cooking: 'bg_cooking_384',
};
for (const [id, src] of Object.entries(CRAFT_BACKDROPS)) {
  const raster = png.load(path.join(POLISH2, 'stage', `${src}.png`));
  if (raster.width !== 384 || raster.height !== 176) {
    throw new Error(
      `craft ${id}: expected 384x176, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`work/bg_${id}.png`, encode(raster));
}
const CRAFT_STATIONS = {
  forge: 'station_forge_96',
  woodbench: 'station_woodbench_96',
  cookfire: 'station_cookfire_96',
};
for (const [id, src] of Object.entries(CRAFT_STATIONS)) {
  const raster = png.load(path.join(POLISH2, 'stage', `${src}.png`));
  if (raster.width !== 96 || raster.height !== 96) {
    throw new Error(
      `station ${id}: expected 96x96, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`work/station_${id}.png`, encode(raster));
}
const polish2Combat = JSON.parse(
  fs.readFileSync(path.join(POLISH2, 'combat', 'manifest.json'), 'utf8'),
);
for (const entry of polish2Combat) {
  if (entry.status !== 'accepted') continue;
  const [w, h] = entry.canvas;
  const [cx, cy] = entry.crop;
  for (let i = 0; i < entry.frames; i++) {
    const raw = png.load(path.join(POLISH2, 'combat', 'raw', `${i}.png`));
    const cut = png.crop(raw, cx, cy, w, h);
    if (i === 0) {
      combatFootprints[`combat_${entry.id}`] = png.footprint(cut);
    }
    emit(`combat/${entry.id}_f${i}.png`, encode(cut));
  }
}

// ------------------------------------------------- World Map Polish 01

/**
 * THE WESTERN FOREST FIRE (provenance and the rejected candidates in
 * `WORLD_MAP_POLISH_01/README.md`).
 *
 * One animated atlas overlay: a burnt hollow eaten into the western forest
 * with two live flames, style-matched by PixelLab inpainting against the
 * shipped master's own canopy at the river fork, then animated with
 * `animate_image`. The loop is the eight *generated* frames — the input
 * still's flames are a size larger, so wrapping through it would pop — and
 * each source frame is already the deterministic 40 × 40 content crop of the
 * 64 × 64 canvas (A-2: crop only, nothing invented). Placement lives in
 * `atlas_layout.json`, never here.
 */
const WMP01_ENV_SRC = path.join(EXPLORE, 'WORLD_MAP_POLISH_01', 'out', 'env');
for (let i = 0; i < 8; i++) {
  const frame = png.load(
    path.join(WMP01_ENV_SRC, `overlay_forest_fire_40x40_f${i}.png`),
  );
  if (frame.width !== 40 || frame.height !== 40) {
    throw new Error(
      `overlay_forest_fire_f${i}: expected 40x40, got ${frame.width}x${frame.height}`,
    );
  }
  emit(`env/overlay_forest_fire_f${i}.png`, encode(frame));
}

/**
 * THE AMBIENT-LIFE PASS (World Map Polish 01, part 2 — the completed "map
 * feels alive" request; provenance in `WORLD_MAP_POLISH_01/README.md`).
 *
 * Two asset families, one rule each:
 *
 * **In-place living regions** — a crop of the shipped master painting,
 * animated by `animate_image`, placed back at its exact source coordinate so
 * the painting itself appears to move (volcano activity, tree rustle, water
 * ripples). Frame 0 is the untouched source crop — identical to the pixels
 * beneath, so an intermittent play fades in from nothing. The generated
 * frames get a deterministic **edge feather**: the outer two rings are the
 * source's own pixels, the next two blend 2:1 toward the source, the next
 * two 1:2 — so the living region has no hard seam against the still painting
 * around it. Compositing two approved images is transformation, not
 * authoring (A-2); the motion inside is PixelLab's.
 *
 * **Creature sprites** — transparent easter eggs (yeti, water dragon, bear),
 * style-matched map objects animated by `animate_image`, cropped here to the
 * union of every frame's opaque bounds. Straight crops, nothing else.
 */
const WMP01_INPLACE = {
  volcano: { size: 64, frames: 16 },
  tree_rustle_a: { size: 48, frames: 8 },
  // `out` crops the emitted frames after feathering: an opaque in-place
  // region paints above the landmark-art layer, so where a generated crop's
  // edge reaches into a landmark glyph's box, the reaching edge is cut off
  // rather than the glyph swallowed (rustle_b vs Sunken Rows, the delta vs
  // Reedmouth, the coast vs Outer Shoal — each checked against the layout's
  // anchors). The layout's coordinates and sizes describe the cropped frames.
  tree_rustle_b: { size: 48, frames: 8, out: [0, 0, 44, 44] },
  // Continuous loops: the two ripple sets ship without their source frame —
  // a still frame inside a continuous water loop reads as a stutter.
  ripple_coast: { size: 48, frames: 8, loopOnly: true, out: [0, 0, 40, 48] },
  ripple_delta: { size: 48, frames: 8, loopOnly: true, out: [12, 0, 36, 48] },
};
/** The generated frame feathered onto its source: ring 0–1 source, 2–3 blend
 * 2:1 source, 4–5 blend 1:2, interior generated. Deterministic integers. */
function feather(src, gen, size) {
  const out = new png.Raster(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const ring = Math.min(x, y, size - 1 - x, size - 1 - y);
      const i = (y * size + x) * 4;
      // Weights in thirds: 3 = all source, 0 = all generated.
      const w = ring < 2 ? 3 : ring < 4 ? 2 : ring < 6 ? 1 : 0;
      for (let k = 0; k < 4; k++) {
        out.data[i + k] = Math.round(
          (src.data[i + k] * w + gen.data[i + k] * (3 - w)) / 3,
        );
      }
    }
  }
  return out;
}
for (const [id, spec] of Object.entries(WMP01_INPLACE)) {
  const src = png.load(
    path.join(WMP01_ENV_SRC, `inplace_${id}_src_${spec.size}.png`),
  );
  if (src.width !== spec.size || src.height !== spec.size) {
    throw new Error(`inplace ${id}: source is ${src.width}x${src.height}`);
  }
  const cut = (frame) =>
    spec.out == null ? frame : png.crop(frame, ...spec.out);
  let out = 0;
  if (!spec.loopOnly) emit(`env/overlay_${id}_f${out++}.png`, encode(cut(src)));
  for (let i = 1; i <= spec.frames; i++) {
    const gen = png.load(
      path.join(WMP01_ENV_SRC, `inplace_${id}_raw_${spec.size}_f${i}.png`),
    );
    if (gen.width !== spec.size || gen.height !== spec.size) {
      throw new Error(`inplace ${id} f${i}: ${gen.width}x${gen.height}`);
    }
    emit(
      `env/overlay_${id}_f${out++}.png`,
      encode(cut(feather(src, gen, spec.size))),
    );
  }
}
const WMP01_CREATURES = {
  // crop: [x, y, w, h] on the 64x64 canvas — the union of opaque bounds
  // across every frame, padded to whole even sizes, recorded here so the
  // transformation is reproducible.
  // The yeti is a single still: two `animate_image` attempts dropped the
  // fishing rod in most frames (a flickering rod is worse than a patient
  // fisher), both kept in `rejected/`. A-1: the failure is recorded, the
  // accepted still ships, the idle-motion seam stays open.
  yeti: { crop: [22, 18, 24, 30], frames: 1 },
  water_dragon: { crop: [12, 12, 40, 36], frames: 9 },
  bear_peek: { crop: [18, 20, 28, 24], frames: 9 },
};
for (const [id, spec] of Object.entries(WMP01_CREATURES)) {
  const [cx, cy, w, h] = spec.crop;
  for (let i = 0; i < spec.frames; i++) {
    const raw = png.load(
      path.join(WMP01_ENV_SRC, `creature_${id}_raw_64_f${i}.png`),
    );
    if (raw.width !== 64 || raw.height !== 64) {
      throw new Error(`creature ${id} f${i}: ${raw.width}x${raw.height}`);
    }
    emit(`env/overlay_${id}_f${i}.png`, encode(png.crop(raw, cx, cy, w, h)));
  }
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
