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
  // `item.tin_ore` is NOT here. It is re-authored in the VAWO01 block below:
  // the original shipped as a round boulder differing from Copper Ore only by
  // inclusion colour (drift D-5). Two emitters for one path also break
  // `--check`, which compares every emit against disk — the first would report
  // the second's file as stale.
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
 * REGIONAL FAUNA — the four accepted 16 px stills (Regional Content Pack 01,
 * `REGIONAL_CONTENT_PACK_01/out/fauna/manifest.json`), shipped by Fable V2
 * Iteration 02 as ambient companion layers: a hare at Haven's Rest, a
 * songbird in the Woods, a crow in the Hollow, a ptarmigan at Frostmere.
 * Manifest-guarded: only `status: "accepted"` stills in the ship list are
 * emitted — `fauna_bat_16` stays out on its own QA line ("reads as a moth at
 * x2"), which is why Stonefall ships without a creature rather than with a
 * wrong one. Emitted as one-frame ambient tracks (`_f0`) with measured
 * footprints, exactly like every other companion.
 */
const FAUNA_SRC = path.join(
  EXPLORE, 'REGIONAL_CONTENT_PACK_01', 'out', 'fauna',
);
const FAUNA_SHIPPED = new Set([
  'fauna_hare_16', 'fauna_songbird_16', 'fauna_crow_16', 'fauna_ptarmigan_16',
]);
const faunaManifest = JSON.parse(
  fs.readFileSync(path.join(FAUNA_SRC, 'manifest.json'), 'utf8'),
);
for (const entry of faunaManifest) {
  if (!FAUNA_SHIPPED.has(entry.id)) continue;
  if (entry.status !== 'accepted') {
    throw new Error(`${entry.id}: in the fauna ship list but not accepted`);
  }
  const frame = png.load(path.join(FAUNA_SRC, `${entry.id}.png`));
  if (frame.width !== 16 || frame.height !== 16) {
    throw new Error(`${entry.id}: expected 16x16, got ${frame.width}x${frame.height}`);
  }
  ambientFootprints[`ambient_${entry.id}`] = png.footprint(frame);
  emit(`ambient/${entry.id}_f0.png`, encode(frame));
}

/**
 * TRAVELER WALK WEST — the six-frame west walk from the same trav_zip
 * character set the combat frames shipped from (PLAYABLE_EXPANSION_01),
 * adopted by Fable V2 Iteration 02 for the travel transition card. West
 * only, by review: the east cycle's vest vanishes on frames 0–1, and
 * mirroring frames is a creative change PixelLab owns (`RULES.md` A-2), so
 * one clean direction ships and the other waits for art. 64 × 64, feet on
 * row 62 — the ambient ground convention, verified per frame.
 */
const WALK_WEST_SRC = path.join(
  EXPLORE, 'PLAYABLE_EXPANSION_01', 'combat', 'candidates', 'trav_zip',
  'Idle', 'animations', 'traveler_walk', 'west',
);
for (let i = 0; i < 6; i++) {
  const frame = png.load(
    path.join(WALK_WEST_SRC, `frame_${String(i).padStart(3, '0')}.png`),
  );
  if (frame.width !== 64 || frame.height !== 64) {
    throw new Error(`traveler_walk_west f${i}: expected 64x64, got ${frame.width}x${frame.height}`);
  }
  if (i === 0) {
    ambientFootprints['traveler_walk_west'] = png.footprint(frame);
  }
  emit(`anim/traveler_walk_west_f${i}.png`, encode(frame));
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
  // FMPO02 wave 2 re-authored `hearty_stew` — see `fmpo02ItemPath`.
  const raster = png.load(
    fmpo02ItemPath(id) || path.join(ITEMS_SRC, `icon_${id}_48.png`),
  );
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
const VAWO_LYNX_TRACKS = new Set(['lynx_idle', 'lynx_attack', 'lynx_defeat']);
const COMBAT_WRD_SRC = path.join(
  EXPLORE, 'WORLD_REWARD_DEPTH_01', 'combat', 'out', 'combat',
);
const combatWrdManifest = JSON.parse(
  fs.readFileSync(path.join(COMBAT_WRD_SRC, 'manifest.json'), 'utf8'),
).filter((entry) => entry.status === 'accepted')
  // The three lynx tracks are re-authored in the VAWO01 block below (the
  // shipped pair read as one animal). Emitting both would give one path two
  // emitters, which `--check` rejects outright.
  .filter((entry) => !VAWO_LYNX_TRACKS.has(entry.id));
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
  // FMPO02 wave 2 re-authored `lynx_pelt` — see `fmpo02ItemPath`.
  const raster = png.load(
    fmpo02ItemPath(id) || path.join(ITEMS_WRD_SRC, `icon_${id}_48.png`),
  );
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
  // World Map Polish 03: the painting no longer ships as its own asset — it
  // is composed byte-preserved into `world/atlas_base` (below), which is the
  // one tile the layout draws. The size check stays: every in-place overlay
  // is a crop of this canvas.
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
  // The Scree Crawler (`DECISIONS/0027`, experimental): idle and attack are
  // pack-accepted; its defeat stayed withheld after blind QA, and the stage
  // tolerates a missing defeat exactly as it does the Guardian's.
  'crawler_idle', 'crawler_attack',
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
  // Gloom Silk joins under `DECISIONS/0027` (Verge tier); pack-accepted.
  gloom_silk: 'icon_gloom_silk_48.png',
})) {
  const raster = png.load(path.join(RCP_MATERIALS_SRC, file));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`${file}: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id}.png`, encode(raster));
}

// ------------------------------------------------ Fable V2 Experiment 01

/**
 * THE VERGE TIER (`DECISIONS/0027`, experimental) — the pack's accepted gear
 * icons for the three Epic pieces the experiment's content names. Status is
 * read from the pack's own gear manifest so a withheld icon can never ship:
 * the Reinforced Bronze Pickaxe's and Granite Chitin's stayed withheld, and
 * their items were struck from the content rather than shipped blank
 * (`GAME_BIBLE/ART/exploration/REGIONAL_CONTENT_PACK_01/INTEGRATION_MANIFEST.md`).
 */
const RCP_GEAR_SRC = path.join(
  EXPLORE, 'REGIONAL_CONTENT_PACK_01', 'out', 'gear',
);
const rcpGearManifest = JSON.parse(
  fs.readFileSync(path.join(RCP_GEAR_SRC, 'manifest.json'), 'utf8'),
);
for (const [id, srcId] of Object.entries({
  bronze_longsword: 'icon_bronze_longsword_48',
  bearhide_coat: 'icon_bearhide_coat_48',
  hornbound_bronze_axe: 'icon_hornbound_bronze_axe_48',
})) {
  const entry = rcpGearManifest.find((e) => e.id === srcId);
  if (!entry) throw new Error(`${srcId}: not in the gear manifest`);
  if (entry.status !== 'accepted') {
    throw new Error(`${srcId}: gear status is "${entry.status}", not accepted`);
  }
  // FMPO02 wave 2 re-authored `bronze_longsword` — see `fmpo02ItemPath`. The
  // pack's own manifest status is still read first: a withheld icon may not
  // ship, whether or not a later round redrew it.
  const raster = png.load(
    fmpo02ItemPath(id) || path.join(RCP_GEAR_SRC, `${srcId}.png`),
  );
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(`${srcId}: expected 48x48, got ${raster.width}x${raster.height}`);
  }
  emit(`item/${id}.png`, encode(raster));
}

/**
 * NODE ART FOR THE VERGE NODES — deterministic copies of shipped node
 * vignettes (`RULES.md` A-2: a copy invents nothing). Each new node reuses
 * the scenery of the node whose subject it deepens: the Deep Tin Seam is a
 * tin seam, the Old-Growth Frostpine is a frostpine stand, and the
 * Silkstrand Thicket is a thicket. Distinct authored scenery is a recorded
 * future PixelLab round, not a code job (A-1).
 */
for (const [id, sourceId] of Object.entries({
  deep_tin_seam: 'tin_seam',
  oldgrowth_frostpine: 'frostpine_stand',
  silkstrand_thicket: 'hollow_thicket',
})) {
  const raster = png.load(path.join(ITEMS_SRC, `node_${sourceId}_96.png`));
  emit(`node/${id}.png`, encode(raster));
}

/**
 * LOCATION VIGNETTE VARIANTS — the pack's five accepted second framings
 * (`out/vignettes/manifest.json`, all `accepted`), packaged at their
 * authored 384 × 176 and shipped as `location/alt_<id>.png`. The World
 * inspector shows a place's variant when one exists, so the atlas panel can
 * carry a picture of the destination without repeating the Adventure
 * backdrop pixel for pixel.
 */
const RCP_VIGNETTES_SRC = path.join(
  EXPLORE, 'REGIONAL_CONTENT_PACK_01', 'out', 'vignettes',
);
const rcpVignetteManifest = JSON.parse(
  fs.readFileSync(path.join(RCP_VIGNETTES_SRC, 'manifest.json'), 'utf8'),
);
for (const [locationId, srcId] of Object.entries({
  havens_rest: 'vignette_havens_rest_ford',
  whispering_woods: 'vignette_whispering_woods_ring',
  stonefall_mine: 'vignette_stonefall_spoil',
  forgotten_hollow: 'vignette_hollow_mere',
  frostmere: 'vignette_frostmere_pass',
})) {
  const entry = rcpVignetteManifest.find((e) => e.id === srcId);
  if (!entry) throw new Error(`${srcId}: not in the vignette manifest`);
  if (entry.status !== 'accepted') {
    throw new Error(`${srcId}: status is "${entry.status}", not accepted`);
  }
  const raster = png.load(path.join(RCP_VIGNETTES_SRC, `${srcId}.png`));
  if (raster.width !== 384 || raster.height !== 176) {
    throw new Error(`${srcId}: expected 384x176, got ${raster.width}x${raster.height}`);
  }
  emit(`location/alt_${locationId}.png`, encode(raster));
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
  // FMPO02 wave 2 re-authored `pristine_horn` — see `fmpo02ItemPath`. The
  // manifest's accepted/withheld filter above still decides what ships.
  const raster = png.load(
    fmpo02ItemPath(entry.id) || path.join(EPL_ITEMS_SRC, entry.file),
  );
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

// ------------------------------------------------------------- VAWO01 world
/**
 * WORLD LIFE — two dragons and three landmarks (`WORLD_LIFE_DIRECTION_01.md`).
 *
 * **All original designs.** The owner's references were mood shorthand, and
 * the direction document records what each design deliberately is *not*: the
 * Rimespire is an ice-accreted Nordic stave tower rather than a crystal
 * palace; Lanterngard is a ring of standing stones colonised by blackthorn
 * rather than a turreted castle, and its fairies are motes of light, never
 * humanoid figures; the Black Gable is a tarred Hebridean croft rather than a
 * Victorian mansion. Nothing here uses the teal-green family at all, because
 * `ART_DIRECTION.md` L-16 reserves it for walking — the palette guard measures
 * that on every one of these files.
 *
 * **The two channels are not interchangeable, and the choice is a performance
 * decision.** A landmark body is a *static* prop: no ticker, no `Opacity`, and
 * it does not consume one of the ~40 overlay slots. Only motion costs a slot,
 * so the dragons are overlays and the buildings are props. Both dragons are
 * **periodic** (`intervalMillis`), which keeps `FOUNDATION_K`'s in-frame
 * budget intact — 19 of the 30 shipped overlays are continuous and this round
 * adds none.
 */
const VAWO_WORLD_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'world');
// The two dragons this round authored at 72 × 32 are **superseded** by FMPO02
// wave 2 (`WORLDLIFE_report.md`), which re-drew both at 96 × 64 and 96 × 56
// with their own anatomy instead of one silhouette in two palettes. The
// emitter that owns `env/overlay_redwyrm_f*` and `env/overlay_stormdrake_f*`
// now lives in the FMPO02 world-life block; a second emitter here would not
// lose the race, it would make `--check` call the shipped file stale. The
// VAWO01 frames stay in the exploration tree as the record. Frame count is
// nine in both rounds, so no orphan frame is left on disk.
for (const [id, w, h] of [
  ['prop_rimespire', 48, 72],
  ['prop_lanterngard', 72, 56],
  ['prop_black_gable', 56, 52],
]) {
  const raster = png.load(path.join(VAWO_WORLD_SRC, `${id}.png`));
  if (raster.width !== w || raster.height !== h) {
    throw new Error(
      `${id}: expected ${w}x${h}, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`env/${id}.png`, encode(raster));
}

// -------------------------------------------------------------- VAWO01 gear
/**
 * VISIBLE EQUIPMENT — the armour figures (`DECISIONS/0030` § 3, Q-14 closed).
 *
 * Three coarse armour classes as full 64² standing figures, plus the base the
 * Traveler already ships. Produced with PixelLab's `create_character_state` on
 * the canonical Stride Traveler (`c82b7da5-…`, PIXELLAB_PROOF_01), which is
 * the same individual the shipped sprite is a rotation of — verified by
 * comparing the canonical south rotation against `sprite/traveler_south.png`
 * before a single state was ordered. That is what makes these variants rather
 * than lookalikes: the face, the proportions and the pack carry over, and only
 * the garment changes.
 *
 * **Not layered.** `FOUNDATION_G_EQUIPMENT.md` measured the alternative and it
 * does not survive contact: per-frame bounding-box centres travel 13–23.5 px,
 * no hand anchor exists on 219 frames, and the baked blade shares all seven of
 * its colours with the body, so the palette substitution a layer would need is
 * not deterministic and would not be A-2.
 */
const VAWO_GEAR_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'equip');
for (const cls of ['plate', 'jerkin', 'coat']) {
  const raster = png.load(path.join(VAWO_GEAR_SRC, `traveler_south_${cls}.png`));
  if (raster.width !== 64 || raster.height !== 64) {
    throw new Error(
      `gear ${cls}: expected 64x64, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`sprite/traveler_south_${cls}.png`, encode(raster));
}

// -------------------------------------------------------------- VAWO01 lynx
/**
 * THE FROST LYNX STOPS BEING A SECOND WOLF (`ENEMY_ROUND_RECORD_01.md`).
 *
 * Measured at stage scale, exactly one pair of the nine-enemy roster failed to
 * read apart: wolf and lynx, **74 % silhouette overlap in place**, with alpha
 * masks agreeing on 95.3 % of the canvas. Not a recolour — only 0.5 % of the
 * shared opaque pixels are the same colour — but the same animal drawn twice.
 *
 * The cause is in the previous round's own record: the lynx "follows the
 * wolf's method exactly" (`WORLD_REWARD_DEPTH_01/combat/README.md` §2), same
 * quadruped template, same camera, same size — and its accepted QA note
 * describes a "long-tailed quadruped", which is the one thing a lynx is not.
 *
 * Re-authored by the route that gives silhouette control rather than a
 * skeleton: `create_image_pixen` for the west-facing still, then
 * `animate_image` per track. `create_character` was tried first on both the
 * `cat` and `lion` quadruped templates and returned a flat white house cat
 * both times — standard mode is template-dominated and ignores the
 * descriptive cues, and v3 has no quadruped mode. The cues that matter are
 * the ones a wolf cannot have: black ear tufts, a stump tail, a cheek ruff,
 * long legs, a spotted tan coat.
 *
 * Geometry: authored 48 × 32, padded to the roster's 56² canvas with the
 * standing baseline on the manifest's own anchor row 39. **One offset per
 * track**, computed from that track's frame 0 — a per-frame re-centring would
 * iron the animation flat. Nothing is cropped, scaled or drawn (A-2).
 */
const VAWO_LYNX_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'lynx');
for (const [track, count] of [['idle', 7], ['attack', 9], ['defeat', 7]]) {
  for (let i = 0; i < count; i++) {
    const frame = png.load(path.join(VAWO_LYNX_SRC, `lynx_${track}_f${i}.png`));
    if (frame.width !== 56 || frame.height !== 56) {
      throw new Error(
        `lynx_${track} f${i}: expected 56x56, got ` +
          `${frame.width}x${frame.height}`,
      );
    }
    if (i === 0) {
      combatFootprints[`combat_lynx_${track}`] = png.footprint(frame);
    }
    emit(`combat/lynx_${track}_f${i}.png`, encode(frame));
  }
}

// ------------------------------------------------------------ VAWO01 reward
/**
 * THE MARKS A PAYOFF IS MADE OF (`REWARD_ROUND_RECORD_01.md`).
 *
 * The universal result card carried no authored art of its own: an item icon,
 * three lines of type, and a border that changed width when the result was
 * notable. Crafting a Bronze Sword and cooking Herb Broth were the same
 * picture with different words, which is the owner's "not casino-like, but it
 * must feel more significant" problem stated from the other side.
 *
 * Ten marks, on the two canvases the icon families already use — 24² for a
 * mark that sits beside a line of type (the skill-icon convention) and 48² for
 * a plate, badge or seal that stands on its own (the item-icon convention).
 * Both ship at ×1, so a mark keeps the same logical footprint in every row.
 *
 * The corner ornament is the one that does the heavy lifting. `DECISIONS/0029`
 * permits a raster in a panel's outer edge, as a tiled surface, or as **a
 * discrete ornament Flutter positions** — and after the frame batch failed to
 * produce a nine-patch worth shipping, the ornament is the sanctioned
 * mechanism that was left. It came back on an opaque white ground and was
 * keyed by flooding near-white from the far corner, then cropped to the
 * bracket: 596 px removed, nothing drawn.
 */
const VAWO_REWARD_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'reward');
const VAWO_REWARD = [
  ['mark_exp', 24],
  ['mark_skill_xp', 24],
  ['mark_bonus_yield', 24],
  ['mark_knowledge', 24],
  ['ornament_corner', 32],
  ['plate_level_up', 48],
  ['badge_milestone', 48],
  ['marker_profession', 48],
  ['seal_contract', 48],
  ['seal_project', 48],
];
for (const [id, size] of VAWO_REWARD) {
  const raster = png.load(path.join(VAWO_REWARD_SRC, `${id}.png`));
  if (raster.width !== size || raster.height !== size) {
    throw new Error(
      `reward ${id}: expected ${size}x${size}, got ` +
        `${raster.width}x${raster.height}`,
    );
  }
  emit(`reward/${id}.png`, encode(raster));
}

// ----------------------------------------------- VAWO01 combat gear variants
/**
 * THE TRAVELER FIGHTS WITH THE WEAPON HE IS ACTUALLY HOLDING.
 *
 * Until now every combat track baked one generic steel sword into the figure,
 * so a Traveler with an empty weapon slot still swung a blade he did not own.
 * That is a lie the interface tells about durable state, and the owner ruled it
 * out of the final build. These are the two ends of the honest set: **unarmed**
 * (nothing in the hands) and **bronze** (the Bronze Sword he can actually
 * forge). `TravelerArt.combatVariants` picks between them and the shipped base;
 * anything unmapped keeps the base, so no item loses its art.
 *
 * ## Why only two tracks sets rather than the full matrix
 *
 * The owner's own escape hatch: *"if the all-track matrix is too large, solve
 * the smallest coherent supported set that eliminates the lie."* Unarmed is the
 * lie itself, and bronze is the first weapon the player earns. Four tiers × four
 * tracks would be sixteen strips, each needing every frame inspected, and the
 * three steel tiers all read as "a sword" at 2× on a phone — the lie they tell
 * is a tier lie, not a category lie.
 *
 * ## Provenance and what was rejected
 *
 * v3 animation only, on the canonical Stride Traveler, with the held weapon
 * named explicitly in every prompt — the documented fix for PixelLab's template
 * animations, which discard held props (`EQUIPMENT_ROUND_RECORD_01.md`). Two
 * strips were rejected and re-rolled rather than shipped: a 7-frame bronze hit
 * that dropped the sword at f6, and the template bronze idle that came back
 * bare-handed.
 *
 * ## The deterministic preparation, in full (`RULES.md` A-2)
 *
 * - v3 returns an 88 × 88 square. Every frame is cropped to `(4, 12, 80, 64)`,
 *   which puts the standing baseline on row 62 — the same anchor row every
 *   shipped Traveler track already stands on — and is lossless: the union
 *   opaque box across all five v3 strips is x 9..77, y 12..75, wholly inside
 *   the window. The template `unarmed_idle` is native 80 × 64 and stands on
 *   row 63, which is why it declares its own anchor row rather than sharing one.
 * - `bronze_attack` f5 came back with 136 px of detached artifact — a green
 *   tuft floating at knee height plus four specks — beside an 1147 px figure.
 *   Removed by flooding the component that contains the standing foot and
 *   keying everything else to zero. Nothing was drawn: the bronze census over
 *   f3–f6 reads 78 / 77 / 82 / 80, so the blade is untouched.
 *
 * The single-component assertion below is the guard that keeps this honest. It
 * is not a style rule — it is the ghost-gear check. Across all 43 frames the
 * blade is always joined to the hand, so a frame that arrives in two pieces is
 * either a detached weapon or a floating artifact, and both are the defect the
 * owner said must not ship.
 */
const VAWO_TRACK_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'equip', 'tracks');
const VAWO_TRACKS = [
  ['traveler_unarmed_idle', 8],
  ['traveler_unarmed_attack', 7],
  ['traveler_unarmed_hit', 7],
  ['traveler_bronze_idle', 9],
  ['traveler_bronze_attack', 7],
  ['traveler_bronze_hit', 5],
  ['traveler_unarmed_stagger', 9],
  ['traveler_bronze_stagger', 9],
];
/** Opaque pixels reachable from the bottom-most opaque pixel, 8-connected. */
function attachedPixelCount(raster) {
  const w = raster.width;
  const h = raster.height;
  const opaque = (x, y) =>
    x >= 0 && y >= 0 && x < w && y < h && raster.data[(y * w + x) * 4 + 3] !== 0;
  let sx = -1;
  let sy = -1;
  for (let y = h - 1; y >= 0 && sy < 0; y--) {
    for (let x = 0; x < w; x++) {
      if (opaque(x, y)) {
        sx = x;
        sy = y;
        break;
      }
    }
  }
  if (sy < 0) return 0;
  const seen = new Int8Array(w * h);
  const stack = [[sx, sy]];
  seen[sy * w + sx] = 1;
  let n = 0;
  while (stack.length > 0) {
    const [cx, cy] = stack.pop();
    n++;
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1],
    ]) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (opaque(nx, ny) && seen[ny * w + nx] === 0) {
        seen[ny * w + nx] = 1;
        stack.push([nx, ny]);
      }
    }
  }
  return n;
}
for (const [id, frames] of VAWO_TRACKS) {
  for (let i = 0; i < frames; i++) {
    const frame = png.load(path.join(VAWO_TRACK_SRC, `${id}_f${i}.png`));
    if (frame.width !== 80 || frame.height !== 64) {
      throw new Error(
        `combat variant ${id} f${i}: expected 80x64, got ` +
          `${frame.width}x${frame.height}`,
      );
    }
    // The same bronze-not-gold remap the FMPO02 strips get (`toneBronze`,
    // defined with the FMPO02 block below; a hoisted function declaration).
    if (/bronze/.test(id)) toneBronze(frame);
    let opaque = 0;
    for (let p = 3; p < frame.data.length; p += 4) {
      if (frame.data[p] !== 0) opaque++;
    }
    if (attachedPixelCount(frame) !== opaque) {
      throw new Error(
        `combat variant ${id} f${i}: ${opaque - attachedPixelCount(frame)} px ` +
          'are not attached to the standing figure. A detached fragment is ' +
          'either a floating artifact or a weapon that has come off the hand, ' +
          'and neither may ship (VAWO01: "do not ship flickering/ghost gear").',
      );
    }
    if (i === 0) {
      combatFootprints[`combat_${id}`] = png.footprint(frame);
    }
    emit(`combat/${id}_f${i}.png`, encode(frame));
  }
}

// ------------------------------------------------------------- VAWO01 gather
/**
 * THE GATHER SCENE FAMILY (`DECISIONS/0031`, round record in
 * `GAME_BIBLE/ART/exploration/VAWO01/GATHER_ROUND_RECORD_01.md`).
 *
 * Eighteen plates that answer the owner's loudest presentation complaint. Two
 * things distinguish them from the six props above, and both are rules rather
 * than preferences:
 *
 * **Backdrops are keyed by REGION and SKILL, not by skill alone.** The three
 * incumbents are keyed by skill, so selecting an activity discarded the
 * regional painting and every foraging node in the game — Haven, the Woods,
 * Frostmere, the Hollow — showed Haven's meadow. Nothing on screen said where
 * the player was for the whole of a 48 s–3 min gather.
 *
 * **Subjects are 48 × 48 and drawn ×2, not 96 × 96 at ×1** (L-18a,
 * `DECISIONS/0031`). Everything sharing the figure's ground line shares the
 * figure's density. The on-screen footprint is unchanged at 96 dp, so this
 * moves no layout — it stops the subject's pixels being a quarter the area of
 * the pixels of the man swinging at it.
 *
 * The six 96 props stay packaged and unreferenced, as the exploration record.
 * They are superseded, not deleted.
 */
const VAWO_GATHER_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'gather');

/** region × skill. A pair with no plate falls back in `AmbientAssets`. */
const GATHER_BACKDROPS = [
  'haven_foraging',
  'woods_woodcutting',
  'woods_foraging',
  'stonefall_mining',
  'frostmere_woodcutting',
  'frostmere_foraging',
  'hollow_foraging',
  // Project-built variants. Each of these nodes only unlocks once its
  // project is complete, so the built backdrop is unconditionally correct
  // and needs no state read on the stage.
  'haven_mill_garden',
  'woods_warded_grove',
  'stonefall_lift',
  'stonefall_gallery',
  'frostmere_shelter',
  'hollow_field_camp',
  'hollow_undercroft',
];
for (const id of GATHER_BACKDROPS) {
  // Four of these fifteen were re-authored by FMPO02 wave 2 — see
  // `fmpo02GatherPath`. Same name, same canvas, different rock.
  const raster = png.load(
    fmpo02GatherPath(`bg_${id}`) || path.join(VAWO_GATHER_SRC, `bg_${id}.png`),
  );
  if (raster.width !== 384 || raster.height !== 176) {
    throw new Error(
      `gather backdrop ${id}: expected 384x176, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`work/bg_${id}.png`, encode(raster));
}

/** The working face itself, one per resource family. */
const GATHER_SUBJECTS = [
  'meadow_bed',
  'duskcap_bed',
  'rime_cushion',
  'gloom_silk',
  'hollow_root',
  'oak_cut',
  'frostpine_cut',
  'copper_face',
  'tin_face',
  'hardened_copper_face',
  'ruin_face',
  // Tier subjects: the deeper node of a family gets its own face, so a
  // player who unlocked it sees what they unlocked.
  'heartwood_oak_cut',
  'deep_tin_lode',
  'oldgrowth_frostpine_cut',
];
for (const id of GATHER_SUBJECTS) {
  // Three of these fourteen were re-authored by FMPO02 wave 2 — see
  // `fmpo02GatherPath`. The transparent-margin assertion below still applies
  // to the replacement, which is the point of putting it in the loop.
  const raster = png.load(
    fmpo02GatherPath(`prop_${id}`)
      || path.join(VAWO_GATHER_SRC, `prop_${id}.png`),
  );
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(
      `gather subject ${id}: expected 48x48 (L-18a, DECISIONS/0031), `
      + `got ${raster.width}x${raster.height}`,
    );
  }
  // A subject that reaches its own frame edge is the point — it is a working
  // face continuing past the picture, not an object with air on all four
  // sides. But a plate with NO transparent margin anywhere is a full-bleed
  // rectangle, which is a backdrop that has been filed as a subject.
  let clear = 0;
  for (let i = 3; i < raster.data.length; i += 4) if (raster.data[i] === 0) clear += 1;
  if (clear < 128) {
    throw new Error(
      `gather subject ${id}: only ${clear} transparent px — this is a plate, not a subject`,
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
// Retired, World Map Polish 03: the owner's device review found the fire's
// black hollow read as a circular sticker. The replacement (`overlay_fire2`,
// below) is an irregular burn scar edited into the painting's own canopy.
// The v1 sources stay in `WORLD_MAP_POLISH_01/out/env/` as evidence; only
// the emission is removed.
const WMP01_ENV_SRC = path.join(EXPLORE, 'WORLD_MAP_POLISH_01', 'out', 'env');

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
// Retired, World Map Polish 03 — all three part-2 creature sprites failed
// the owner's device review on integration (the bear head was mascot-sized,
// the floating yeti read as pasted, the water dragon read as a slug). Their
// replacements below are grounded differently: the yeti and bear are edits
// of the painting itself (in-place scenes), and the serpent is a re-authored
// full-figure sprite. The v1 sources stay in `WORLD_MAP_POLISH_01/out/env/`
// as evidence; only the emissions are removed.

// ------------------------------------------------- World Map Polish 03

/**
 * THE EXPANDED WORLD BASE — a 768 × 768 composed continent (provenance in
 * `WORLD_MAP_POLISH_03/README.md`).
 *
 * The owner's scale-up brief: the world should feel about twice as big, with
 * frontier in all four directions. The accepted 512 × 512 master painting is
 * NOT repainted — it sits byte-preserved at (128, 128) inside a ring of eight
 * PixelLab Pro pieces, each style-referenced against a 64 × 64 crop of the
 * master's own adjacent edge: a mountain-wall west, a frozen polar sea north,
 * open ocean with islets east, and a southern coast of plains and estuary.
 *
 * The joins get a deterministic **dither crossfade**: within six pixels of a
 * seam, pixels swap across it with a probability that falls off with
 * distance, driven by an integer hash of the coordinate. Unlike an averaging
 * blend this invents no colours — every output pixel is one of the two
 * approved images' own pixels (A-2), and the interleave reads as texture
 * rather than as a line. M-12's failed composites were butt joins with no
 * treatment and no shared style ancestry; these pieces are style-referenced
 * to the very edges they touch and then interleaved.
 */
const WMP03 = path.join(EXPLORE, 'WORLD_MAP_POLISH_03', 'out');
// ------------------------------------ World Map Expansion Refinement 02
//
// The 1024 × 1024 base (provenance in
// `WORLD_MAP_EXPANSION_REFINEMENT_02/README.md`): the byte-preserved 512²
// master now sits at (256, 256) inside TWO rings. The inner ring keeps
// WMP03's north strip and NW/SW corners; its east strip, NE/SE corners and
// west strip are replaced by this round's seam-corrected pieces (the west
// strip carries the caravan pass). Five static in-place patches — the
// corridor cut and road join through the master's forest, the daylight
// conversion of the north strip's right end, the east strip's top fade, and
// the south join blend — are PixelLab edits of tracked crops, blitted at
// recorded coordinates before the crossfade. The outer ring is this round's
// twelve frontier pieces (the flat east ocean is a recorded deterministic
// assembly of the approved east strip's own water, A-2). WMP03's corner_sw
// carries a 1px white generation border on its formerly-canvas left/bottom
// edges; those lines are replicated over from their neighbours here, since
// they are interior joins now.
const WMER02 = path.join(EXPLORE, 'WORLD_MAP_EXPANSION_REFINEMENT_02', 'out');
{
  const piece = (dir, name, w, h) => {
    const raster = png.load(path.join(dir, 'world', `${name}.png`));
    if (raster.width !== w || raster.height !== h) {
      throw new Error(`${name}: expected ${w}x${h}, got ${raster.width}x${raster.height}`);
    }
    return raster;
  };
  const base = new png.Raster(1024, 1024);

  // Outer ring (WMER02).
  png.blit(base, piece(WMER02, 'r2_corner_nw_f0', 128, 128), 0, 0);
  png.blit(base, piece(WMER02, 'r2_north_w_f0', 384, 128), 128, 0);
  png.blit(base, piece(WMER02, 'r2_north_e_f0', 384, 128), 512, 0);
  png.blit(base, piece(WMER02, 'r2_corner_ne_f0', 128, 128), 896, 0);
  png.blit(base, piece(WMER02, 'r2_west_n_f0', 128, 512), 0, 128);
  png.blit(base, piece(WMER02, 'r2_west_s_f0', 128, 256), 0, 640);
  png.blit(base, piece(WMER02, 'r2_east_n_f0', 128, 384), 896, 128);
  png.blit(base, piece(WMER02, 'r2_east_s_f0', 128, 384), 896, 512);
  png.blit(base, piece(WMER02, 'r2_corner_sw_f0', 128, 128), 0, 896);
  png.blit(base, piece(WMER02, 'r2_south_w_f0', 384, 128), 128, 896);
  png.blit(base, piece(WMER02, 'r2_south_e_f0', 384, 128), 512, 896);
  png.blit(base, piece(WMER02, 'r2_corner_se_f0', 128, 128), 896, 896);

  // Inner ring: WMP03 retained + WMER02 replacements, offset +128.
  png.blit(base, piece(WMP03, 'corner_nw_128', 128, 128), 128, 128);
  png.blit(base, piece(WMP03, 'strip_north_512x128', 512, 128), 256, 128);
  png.blit(base, piece(WMER02, 'corner_ne_conformed_v2', 128, 128), 768, 128);
  png.blit(base, piece(WMER02, 'cand_strip_west_f0', 128, 512), 128, 256);
  png.blit(base, piece(WMER02, 'cand_strip_east_f0', 128, 512), 768, 256);
  const cornerSW = piece(WMP03, 'corner_sw_128', 128, 128);
  for (let y = 0; y < 128; y++) {
    const a = cornerSW.idx(0, y);
    const b = cornerSW.idx(1, y);
    for (let k = 0; k < 4; k++) cornerSW.data[a + k] = cornerSW.data[b + k];
  }
  for (let x = 0; x < 128; x++) {
    const a = cornerSW.idx(x, 127);
    const b = cornerSW.idx(x, 126);
    for (let k = 0; k < 4; k++) cornerSW.data[a + k] = cornerSW.data[b + k];
  }
  png.blit(base, cornerSW, 128, 768);
  png.blit(base, piece(WMP03, 'strip_south_512x128', 512, 128), 256, 768);
  png.blit(base, piece(WMER02, 'cand_corner_se_f3', 128, 128), 768, 768);
  const master = png.load(path.join(PWRF_WORLD_SRC, 'whole_a_0.png'));
  png.blit(base, master, 256, 256);

  // Static in-place patches (edited crops; coordinates in 1024 space).
  const patch = (name, w, h, x, y) => png.blit(base, piece(WMER02, name, w, h), x, y);
  patch('northfix2_edit_f0', 128, 128, 640, 128);
  patch('eaststriptop_edit_f0', 128, 64, 768, 256);
  patch('corridor_edit_f0', 128, 75, 256, 483);
  patch('southjoin_edit_f0', 256, 60, 188, 738);
  patch('roadjoin_edit_f0', 104, 72, 216, 480);

  // The dither crossfade. `before` is the untouched composition so a swapped
  // pixel is always sourced from the original, never from another swap.
  const before = base.clone();
  const hash = (x, y, salt) => {
    let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
    h = (h ^ (h >>> 13)) >>> 0;
    return (h % 1024) / 1024;
  };
  const BAND = 11;
  const chance = (d) => 0.45 * (1 - (d - 1) / BAND); // d in 1..BAND
  const swap = (ax, ay, bx, by) => {
    const ai = base.idx(ax, ay);
    const bi = before.idx(bx, by);
    for (let k = 0; k < 4; k++) base.data[ai + k] = before.data[bi + k];
  };
  for (const seamY of [128, 256, 768, 896]) {
    for (let x = 0; x < 1024; x++) {
      for (let d = 1; d <= BAND; d++) {
        const p = chance(d);
        if (hash(x, seamY - d, 1) < p) swap(x, seamY - d, x, seamY + d - 1);
        if (hash(x, seamY + d - 1, 2) < p) swap(x, seamY + d - 1, x, seamY - d);
      }
    }
  }
  for (const seamX of [128, 256, 768, 896]) {
    for (let y = 0; y < 1024; y++) {
      for (let d = 1; d <= BAND; d++) {
        const p = chance(d);
        if (hash(seamX - d, y, 3) < p) swap(seamX - d, y, seamX + d - 1, y);
        if (hash(seamX + d - 1, y, 4) < p) swap(seamX + d - 1, y, seamX - d, y);
      }
    }
  }

  // ------------------------------------- Protected interior (World Atlas
  // Restore 01). Everything composed up to this point — the byte-preserved
  // master, the approved static patches and the dither — is the approved
  // interior of record (the 559669e state). The repair layers below may not
  // repaint it: bridge and edge blits are restored/clipped against this
  // snapshot outside a narrow rim band, and a guard at the end of the block
  // throws if any non-water pixel of the protected core drifts. This exists
  // because the WACUI bridge passes intruded up to 128 px into the master and
  // erased the Frostmere frozen basin and the volcano's watchtowers
  // (`MISTAKES.md` M-15).
  const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 };
  // `let`, not `const`: the EPO03 block below re-takes this snapshot once
  // its owner-authorised regions are in (DECISIONS/0033). Until then every
  // layer sees the 559669e state exactly as before.
  let approved = base.clone();
  // Pixels the EPO03 block wrote. `protDepth` treats a claimed pixel as hard
  // core wherever it sits on the canvas, so the sage pass, the drift guard
  // and any layer inserted after the block cannot repaint the new approved
  // state. Empty until the block runs — rows above behave exactly as today.
  const claimed = new Uint8Array(1024 * 1024);
  // Landmark goldens an EPO03 region declared it overwrites (each is
  // re-extracted in the same commit; the golden guard still compares).
  const reauthorized = new Set();
  // Depth inside the protected rect (0 = outside; 1 = rim pixel).
  const protDepth = (x, y) => {
    if (claimed[y * 1024 + x]) return PROT.band + 1;
    if (x < PROT.x0 || x >= PROT.x1 || y < PROT.y0 || y >= PROT.y1) return 0;
    return Math.min(x - PROT.x0, y - PROT.y0, PROT.x1 - 1 - x, PROT.y1 - 1 - y) + 1;
  };
  // In the rim band a hash dither keeps repair pixels near the perimeter and
  // approved pixels toward the core, so the clip line is never straight.
  const keepRepair = (x, y, d) => d <= PROT.band && hash(x, y, 5) >= d / (PROT.band + 1);

  // ---------------------------- World Atlas Coherence UI 01 (device review)
  //
  // The dither above narrows each generation seam to a noisy band; on a
  // physical iPhone, at the layout's ×6 display scale, those bands and the
  // straight lattice lines still read as rectangles (`MISTAKES.md` M-14). The
  // fix is to author the boundaries rather than blend them: for each visible
  // seam an `inpaint_image` bridge was generated from a wide crop of THIS
  // composite (real terrain from both sides of the join, the crop's outer
  // margins frozen so it re-seats), and the open ocean's several teal dialects
  // are conformed to one accepted swatch (A-2 palette remap). The bridges are
  // blitted here — after the dither, over the seams — in the order they were
  // authored (later wins where they overlap); the ocean conform runs last.
  // Provenance, the review composite and the seam map:
  // `GAME_BIBLE/ART/exploration/WORLD_ATLAS_COHERENCE_UI_01/README.md`.
  const WACUI = path.join(EXPLORE, 'WORLD_ATLAS_COHERENCE_UI_01');
  const bridge = (name, w, h) => {
    const raster = png.load(path.join(WACUI, 'out', 'bridges', `${name}_f0.png`));
    if (raster.width !== w || raster.height !== h) {
      throw new Error(`bridge ${name}: expected ${w}x${h}, got ${raster.width}x${raster.height}`);
    }
    return raster;
  };
  for (const [name, w, h, x, y] of [
    ['north_west', 288, 288, 0, 0],
    ['north_center', 512, 288, 256, 0],
    ['north_east', 256, 288, 768, 0],
    ['north_master', 512, 80, 256, 224],
    ['nw_corner', 220, 220, 80, 80],
    ['north_junction', 512, 84, 256, 188],
    ['north_mtop', 420, 96, 300, 232],
    ['west_mid', 256, 512, 48, 256],
    // east_x768 is retired (World Atlas Restore 01): it reached 128 px into
    // the master, rewrote the approved east coastline into invented
    // forest/beach and deleted the volcano's watchtowers. Its water seam is
    // owned by the global ocean conform below; its land join is reviewed in
    // `GAME_BIBLE/ART/exploration/WORLD_ATLAS_RESTORE_01/`.
    ['sw', 272, 304, 0, 592],
    ['south', 512, 128, 256, 720],
    ['se', 192, 192, 704, 704],
  ]) {
    png.blit(base, bridge(name, w, h), x, y);
  }

  // Protected-interior restore: undo every bridge pixel that landed deeper
  // than the rim band, feathering across the band so no straight clip line
  // can read (World Atlas Restore 01). This brings back the Frostmere frozen
  // basin, the volcano watchtowers and the approved east coastline.
  for (let y = PROT.y0; y < PROT.y1; y++) {
    for (let x = PROT.x0; x < PROT.x1; x++) {
      const d = protDepth(x, y);
      if (keepRepair(x, y, d)) continue;
      const ai = base.idx(x, y);
      for (let k = 0; k < 4; k++) base.data[ai + k] = approved.data[ai + k];
    }
  }

  const oceanTool = require(path.join(WACUI, 'tools', 'ocean_unify.js'));

  // ---------------------------- World Atlas Restore 01 (east-join inpaint)
  //
  // Retiring east_x768 re-exposed the master-east seam where the volcano's
  // dark slope met the strip sea as a mechanical dither column. One surgical
  // inpaint (crop (656,224) 256×288, mask x 752..819) re-authors that join as
  // the volcano's eastern cliff dropping to rocky coves and pale shallows.
  // Only the cliff-and-cove band of the result is adopted — the generation's
  // top and bottom thirds invented red haze over the sea and debris on the
  // ice shelf and are rejected on the record
  // (`GAME_BIBLE/ART/exploration/WORLD_ATLAS_RESTORE_01/README.md`). The
  // band's horizontal edges are hash-feathered so no straight cut reads, and
  // its west edge obeys the protected-interior rule like every repair.
  {
    const WAR01 = path.join(EXPLORE, 'WORLD_ATLAS_RESTORE_01');
    // Adopt a band of an inpaint result. `cropX/cropY` place the source crop
    // on the atlas; `ad` is the adopted rect in atlas coordinates (the mask
    // band, trimmed of any rejected stretch). All four edges are
    // hash-feathered over `feather` px so no straight cut reads, and the
    // protected-interior depth guard applies at full strength — an adoption
    // may enter the permitted rim band (that is what the band is for) but
    // never the core.
    const adopt = (file, w, h, cropX, cropY, ad) => {
      const rast = png.load(path.join(WAR01, 'out', `${file}_f0.png`));
      if (rast.width !== w || rast.height !== h) {
        throw new Error(`${file}: expected ${w}x${h}, got ${rast.width}x${rast.height}`);
      }
      const feather = 8;
      for (let ty = ad.y0; ty < ad.y1; ty++) {
        for (let tx = ad.x0; tx < ad.x1; tx++) {
          if (protDepth(tx, ty) > PROT.band) continue;
          const e = Math.min(ty - ad.y0, ad.y1 - 1 - ty, tx - ad.x0, ad.x1 - 1 - tx);
          if (e < feather && hash(tx, ty, 6) >= (e + 1) / (feather + 1)) continue;
          const si = rast.idx(tx - cropX, ty - cropY);
          const ai = base.idx(tx, ty);
          for (let k = 0; k < 4; k++) base.data[ai + k] = rast.data[si + k];
        }
      }
    };
    // East join: the volcano's eastern cliff dropping to rocky coves. Only
    // the cliff-and-cove band is adopted — the generation's top and bottom
    // thirds invented red haze and ice debris, rejected on the record.
    adopt('east_join', 256, 288, 656, 224, { x0: 752, y0: 272, x1: 820, y1: 436 });
    // West join: the dark forest thinning into the pale western meadow as
    // scattered trees, replacing the dotted crossfade column at x≈256.
    adopt('west_join', 160, 224, 176, 360, { x0: 236, y0: 360, x1: 276, y1: 584 });
    // South strand: the beach fading into dune grass, scrub and driftwood,
    // replacing the straight sand-to-green line at y≈830.
    adopt('south_strand', 448, 128, 120, 752, { x0: 128, y0: 810, x1: 528, y1: 870 });
    // Eastern strand: the flat green filler band east of the delta becomes
    // the sea meeting the beach — surf, shallows and dune grass continuing
    // the western strand's language. One invented ghost sail is removed by
    // the flotsam cleanup below.
    adopt('south_strand_e', 448, 128, 480, 752, { x0: 512, y0: 810, x1: 800, y1: 870 });
  }

  // Edge-integration pass (the device found several bridges whose own
  // rectangular footprint still read once the original seam was gone — the
  // repair-crop perimeter, M-14). These edits dissolve those perimeters by
  // continuing the geography outward across them (glacier/mountains fraying
  // into pack ice, plain descending into valley, a flat headland made detailed
  // forest, floes thinning into snow and sea). Cut from the post-conform
  // composite, so blitted last, in authoring order.
  const edge = (name, w, h) => {
    const raster = png.load(path.join(WACUI, 'out', 'fix2', 'bridges', `${name}_f0.png`));
    if (raster.width !== w || raster.height !== h) {
      throw new Error(`edge ${name}: expected ${w}x${h}, got ${raster.width}x${raster.height}`);
    }
    return raster;
  };
  for (const [name, w, h, x, y] of [
    ['d1_nw', 256, 272, 176, 24],
    ['d1c_nw', 300, 300, 0, 0],
    ['d4_west', 300, 120, 0, 544],
    ['d5_se', 200, 152, 684, 684],
    ['d2_north', 430, 104, 290, 236],
    ['d2b_floe', 240, 160, 240, 140],
    ['d3_ne', 160, 260, 740, 40],
  ]) {
    // Clipped against the protected interior: an edge fix may write the rim
    // band (feathered) but never the core, whose post-conform pixels stand.
    const raster = edge(name, w, h);
    for (let sy = 0; sy < h; sy++) {
      for (let sx = 0; sx < w; sx++) {
        const tx = x + sx, ty = y + sy;
        if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
        const d = protDepth(tx, ty);
        if (d > 0 && !keepRepair(tx, ty, d)) continue;
        const ai = base.idx(tx, ty), si = raster.idx(sx, sy);
        for (let k = 0; k < 4; k++) base.data[ai + k] = raster.data[si + k];
      }
    }
  }

  // ---------------------------- World Atlas Remaster 01 (regional layers)
  //
  // Regional recompositions: coherent geographic regions re-authored whole
  // through PixelLab (inpaint over a wide crop of THIS composite with frozen
  // margins) rather than seam-patched (`MISTAKES.md` M-14's lesson at
  // regional grain). Each region is a tracked manifest entry: the accepted
  // generation, a graded grayscale mask (white = region, black = base, gray =
  // hash-dither feather — selection, never averaging, so every output pixel
  // is one of the two approved images' own pixels, A-2), and a status gate
  // (anything but 'accepted' throws, the RCP pattern). Regions blit after
  // every legacy repair layer — a region deliberately supersedes any bridge
  // or edge fix under its mask — and before the flotsam fills and the global
  // ocean conform, so generated deep water folds into the one sea. The A-4
  // protected-interior machinery applies unchanged: region pixels clip
  // against the rim band exactly like any repair, and the drift guard below
  // still holds. Landmarks outside the core are held by the landmark
  // registry guard at the end of this block. Round record:
  // `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/README.md`.
  const REM01 = path.join(EXPLORE, 'WORLD_ATLAS_REMASTER_01');
  {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(REM01, 'regions_manifest.json'), 'utf8'));
    for (const region of manifest.regions) {
      if (region.status !== 'accepted') {
        throw new Error(`atlas region ${region.id}: status '${region.status}' — ` +
          `only accepted regions may ship`);
      }
      const gen = png.load(path.join(REM01, 'out', region.file));
      const mask = png.load(path.join(REM01, 'src', region.mask));
      if (gen.width !== region.w || gen.height !== region.h ||
          mask.width !== region.w || mask.height !== region.h) {
        throw new Error(`atlas region ${region.id}: expected ${region.w}x${region.h}, ` +
          `got gen ${gen.width}x${gen.height}, mask ${mask.width}x${mask.height}`);
      }
      for (let sy = 0; sy < region.h; sy++) {
        for (let sx = 0; sx < region.w; sx++) {
          const m = mask.data[mask.idx(sx, sy)];
          if (m === 0) continue;
          const tx = region.x + sx, ty = region.y + sy;
          if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
          if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
          const d = protDepth(tx, ty);
          if (d > 0 && !keepRepair(tx, ty, d)) continue;
          const ai = base.idx(tx, ty), si = gen.idx(sx, sy);
          for (let k = 0; k < 4; k++) base.data[ai + k] = gen.data[si + k];
        }
      }
    }
  }

  // NW-ice red-fleck despeckle (deterministic, A-2, World Atlas Remaster
  // 01): eleven isolated bright-red artifact pixels sit on the nunatak row
  // and pond rim (281..406, 128..153) — pre-existing generation debris on
  // snow/rock where nothing legitimate is red (the volcano is at x 580+).
  // Each is replaced with the pixel two rows below it, exactly like the
  // flotsam fills; scoped to the one rect so no legitimate warm pixel
  // elsewhere can match.
  for (let y = 120; y < 160; y++) {
    for (let x = 270; x < 410; x++) {
      const i = base.idx(x, y);
      const r = base.data[i], g = base.data[i + 1], b = base.data[i + 2];
      if (r > 150 && r > g + 60 && r > b + 60) {
        const si = base.idx(x, y + 2);
        for (let k = 0; k < 4; k++) base.data[i + k] = base.data[si + k];
      }
    }
  }

  // Treeline confetti despeckle (deterministic, A-2, WAR Remaster 01
  // Iteration 02, register D-06 — owner-marked on device): a band of isolated
  // 1–2 px dark flecks hovers on the open snow ABOVE the Longwood treeline
  // canopy (measured: 74 px, all inside 257–374 × 257–272 — the writable A-4
  // rim band). A fleck is a dark pixel with ≥5 pale-snow neighbours; a real
  // conifer tip never qualifies (its lower neighbours are canopy-dark). Each
  // fleck takes the nearest pale neighbour's snow, first match from a fixed
  // offset list. Clipped to y ≤ 275 / x ≤ 399 and to the rim band
  // (ATLAS-L constraints — Frostmere north-wall golden starts at x 400,
  // the frozen core at depth > band).
  {
    const pale = (x, y) => {
      const i = base.idx(x, y);
      return base.data[i] > 185 && base.data[i + 1] > 200 && base.data[i + 2] > 200;
    };
    // A fleck is canopy-dark OR mid-green debris; teal crack lines (b ≥ g)
    // and snow shading are excluded by construction.
    const fleck = (x, y) => {
      const i = base.idx(x, y);
      const r = base.data[i], g = base.data[i + 1], b = base.data[i + 2];
      if (r < 110 && g < 130 && b < 130) return true;
      return g > 60 && g < 185 && g > r + 10 && g > b + 15;
    };
    // Three erosion passes: removing a cluster's rim exposes its interior to
    // the ≥5-pale-neighbour test on the next pass; a conifer tip never erodes
    // because the canopy column beneath it is never pale.
    for (let pass = 0; pass < 3; pass++) {
      const fills = [];
      for (let y = 240; y <= 275; y++) {
        for (let x = 245; x <= 399; x++) {
          if (protDepth(x, y) > PROT.band) continue;
          if (!fleck(x, y)) continue;
          let paleN = 0;
          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
              if (!dx && !dy) continue;
              if (pale(x + dx, y + dy)) paleN++;
            }
          }
          if (paleN < 5) continue;
          for (const [ox, oy] of [[0, -3], [-3, 0], [3, 0], [0, -5], [-5, -3], [5, -3]]) {
            if (pale(x + ox, y + oy)) { fills.push([x, y, x + ox, y + oy]); break; }
          }
        }
      }
      if (!fills.length) break;
      // Two-phase (collect, then write) so one fill never feeds another
      // within a pass.
      for (const [x, y, sx, sy] of fills) {
        const ai = base.idx(x, y), si = base.idx(sx, sy);
        for (let k = 0; k < 4; k++) base.data[ai + k] = base.data[si + k];
      }
    }
  }

  // Green-confetti cliff cleanup (deterministic, A-2, WAR Remaster 01
  // Iteration 02, register D-14 — owner-marked on device; ATLAS-H called it
  // the north's ugliest remaining patch): a smear of green debris with drip
  // trails hangs over the ice cliff NW of the volcano cape (~705–761 ×
  // 235–303). Nothing legitimate is green there — the cape's real vegetation
  // sits east of the two registry exclusions below. Greens erode rim-first
  // over up to twelve passes, each pixel taking its nearest non-green
  // neighbour (ice, sea or rock). Clips (ATLAS-L): the volcano_east_cliff
  // golden (752–824 × 260–470 — the registry rect, not the adoption band),
  // the east_watchtower_flank golden (744–751 × 273–322), and the A-4 core
  // beyond the rim band, defensively.
  {
    const green = (x, y) => {
      const i = base.idx(x, y);
      const r = base.data[i], g = base.data[i + 1], b = base.data[i + 2];
      return g > 60 && g > r + 15 && !(b > g + 10);
    };
    // Dark scribble remains of the same smear (the green sat on top of it).
    // Every legitimate dark pixel in the rect — the watchtower, the volcano
    // ridge, the cape rock — lives inside an exclusion below, so 'dark in
    // the writable remainder' is debris by construction.
    const darkDebris = (x, y) => {
      const i = base.idx(x, y);
      return base.data[i] < 150 && base.data[i + 1] < 150 && base.data[i + 2] < 150;
    };
    const excluded = (x, y) =>
      (x >= 752 && y >= 260) ||
      (x >= 727 && x <= 751 && y >= 270 && y <= 323) ||
      protDepth(x, y) > PROT.band;
    const debris = (x, y) => green(x, y) || darkDebris(x, y);
    for (let pass = 0; pass < 12; pass++) {
      const fills = [];
      for (let y = 235; y <= 303; y++) {
        for (let x = 705; x <= 761; x++) {
          if (excluded(x, y) || !debris(x, y)) continue;
          for (const [ox, oy] of [[-3, 0], [0, -3], [3, 0], [0, 3], [-6, 0],
            [0, -6], [-3, -3], [3, -3], [-9, 0], [0, -9]]) {
            if (!debris(x + ox, y + oy) && !excluded(x + ox, y + oy)) {
              fills.push([x, y, x + ox, y + oy]); break;
            }
          }
        }
      }
      if (!fills.length) break;
      for (const [x, y, sx, sy] of fills) {
        const ai = base.idx(x, y), si = base.idx(sx, sy);
        for (let k = 0; k < 4; k++) base.data[ai + k] = base.data[si + k];
      }
    }
  }

  // Red-dash trail despeckle (deterministic, A-2, WAR Remaster 01
  // Iteration 02, register D-04): a 54-px dotted rust-red trail runs from the
  // canopy's south cut onto the strand (275–404 × 758–815) — old master
  // debris with no route data behind it (no polyline exists there), reading
  // as speck noise at phone FOV. Same predicate as the NW red-fleck pass;
  // each dot takes the pixel three rows below (five if that is also red).
  // The trail's last 12 px sit inside the south_strand_w golden — that
  // golden is deliberately re-authorized in the same commit
  // (`iteration_02/tools/reauthorize_strand_dots.js`, the R3b pattern).
  for (let y = 758; y <= 816; y++) {
    for (let x = 275; x <= 404; x++) {
      const i = base.idx(x, y);
      const isRed = (j) => base.data[j] > 150 &&
        base.data[j] > base.data[j + 1] + 60 && base.data[j] > base.data[j + 2] + 60;
      if (!isRed(i)) continue;
      let si = base.idx(x, y + 3);
      if (isRed(si)) si = base.idx(x, y + 5);
      for (let k = 0; k < 4; k++) base.data[i + k] = base.data[si + k];
    }
  }

  // Density-ladder stamp belts (deterministic composite, WAR Remaster 01
  // Iteration 02 Tier 2 — owner-authorized "composited from existing
  // assets"): whole approved tree sprites harvested from this composite are
  // stamped onto open ground in graded transition belts so forest masses
  // taper instead of ending at a wall (register D-01/D-06/D-12, ATLAS-J's
  // density ladder). Substrate-matched, hash-jittered, mirrored, A-4- and
  // occupancy-checked; each belt is revertable whole via its `enabled` flag.
  // Module: GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/iteration_02/
  // tools/stamp_belts.js (salt 15).
  {
    const stamps = require(path.join(
      EXPLORE, 'WORLD_ATLAS_REMASTER_01', 'iteration_02', 'tools', 'stamp_belts.js'));
    const counts = stamps.apply(base, hash, protDepth, PROT);
    console.log(`  atlas stamp belts: ${JSON.stringify(counts)}`);
  }

  // ------------------------- FMPO02_ATLAS_REGIONS (ART-03 regional terrain)
  //
  // The owner's #1 complaint: roughly 40% of the canvas — the northern
  // cracked-plate field, the western dead acreage, the southern latitude
  // layer-cake — reads as surface rather than country. ART-03 answers it the
  // one way with a record here: re-author whole geographic regions by
  // `inpaint_image` over a wide crop of THIS composite with frozen margins,
  // one region at a time, each carried through composite -> guards -> full
  // atlas + x2 perimeter + 197x426 phone FOV -> an explicit verdict before
  // the next opens (`WORLD_ATLAS_REMASTER_01/README.md` §10).
  //
  // Placed after the stamp belts deliberately: the belts are baked into the
  // composite each region was cropped from, so a region already contains
  // them and must supersede them under its own mask. Placed before the
  // flotsam fills and the global ocean conform, so any generated deep water
  // folds into the one sea.
  //
  // Boundary authoring is the whole game (M-12/M-14/M-15 all died here), so
  // no boundary is drawn by this loop at all. Each region ships with a
  // committed graded mask built deterministically by
  // `GAME_BIBLE/ART/exploration/FMPO02/tools/atlas-mask.js`: 24 px alpha ramp
  // on a free edge, 32 px where the boundary crosses a texture change, the
  // ramp midline hash-jittered +/-10 px by a low-frequency value noise so no
  // straight lattice line exists on any edge, alpha forced to 0 inside the
  // A-4 core beyond its rim and within 20 px of any landmark golden (ramping
  // back over a further 24 px, so a keepout never prints the golden's own
  // rectangle onto the terrain). Compositing is hash dither-SELECT, never an
  // average: every output pixel is one of the two approved images' own
  // pixels (A-2). The A-4 rim clip and both guards below apply unchanged.
  {
    const FMPO02 = path.join(EXPLORE, 'FMPO02', 'out', 'atlas');
    const manifest = JSON.parse(
      fs.readFileSync(path.join(FMPO02, 'manifest.json'), 'utf8'));
    for (const region of manifest.regions) {
      if (region.status !== 'accepted') {
        throw new Error(`FMPO02 atlas region ${region.id}: status ` +
          `'${region.status}' — only accepted regions may ship`);
      }
      const gen = png.load(path.join(FMPO02, `${region.id}.png`));
      const mask = png.load(path.join(FMPO02, `${region.id}_mask.png`));
      if (gen.width !== region.w || gen.height !== region.h ||
          mask.width !== region.w || mask.height !== region.h) {
        throw new Error(`FMPO02 atlas region ${region.id}: expected ` +
          `${region.w}x${region.h}, got gen ${gen.width}x${gen.height}, ` +
          `mask ${mask.width}x${mask.height}`);
      }
      for (let sy = 0; sy < region.h; sy++) {
        for (let sx = 0; sx < region.w; sx++) {
          const m = mask.data[mask.idx(sx, sy)];
          if (m === 0) continue;
          const tx = region.x + sx, ty = region.y + sy;
          if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
          // Selection, not blending: the mask is a probability, and the
          // pixel that wins is whole.
          if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
          const si = gen.idx(sx, sy);
          // A transparent source pixel is crop padding past the canvas, not
          // authored terrain.
          if (gen.data[si + 3] === 0) continue;
          const d = protDepth(tx, ty);
          if (d > 0 && !keepRepair(tx, ty, d)) continue;
          const ai = base.idx(tx, ty);
          for (let k = 0; k < 4; k++) base.data[ai + k] = gen.data[si + k];
        }
      }
    }
    if (manifest.regions.length) {
      console.log(`  atlas FMPO02 regions: ${manifest.regions.map((r) => r.id).join(', ')}`);
    }
  }

  // Flotsam cleanup (deterministic, A-2): two pre-existing generation
  // artifacts sit in open water — a dark scribble blob at (886..910, 622..662)
  // and whitecap marks at (866..906, 760..784) that read as tiny printed text
  // at zoom. Each pixel is replaced with the open water a fixed offset away,
  // so nothing is invented; the conform below then folds the fill into the
  // one sea. Both rects are far outside the protected interior.
  for (const [x0, y0, x1, y1, dx, dy] of [
    [886, 622, 910, 662, -40, 0],
    [866, 760, 906, 784, 36, 0],
  ]) {
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        const ai = base.idx(x, y), si = base.idx(x + dx, y + dy);
        for (let k = 0; k < 4; k++) base.data[ai + k] = base.data[si + k];
      }
    }
  }

  // Ghost-sail removal, corrected (WAR Remaster 01 Iteration 02, register
  // D-05/D-15): the original blanket fill [748,844)–(796,906) ← (0,+66)
  // deleted the eastern-strand inpaint's ghost sail — but also the strand's
  // own tapering beach toe and surf in rows 844–851, leaving an L-shaped
  // razor cut at x=748 / y=844 that the owner's device screenshots exposed.
  // The sail is a measured cluster at (760–787 × 853–880): mast column
  // x 765–767, boom and rigging tans to x 784. This pass restores the
  // adopted generation's own pixels across the old fill rect down to the
  // generation's last row (879) and applies the sea fill ONLY to the sail
  // box and the rows below 880 (which also erases any rigging remnant to
  // y≈905). The strand_e golden held conformed deep sea over this sub-rect,
  // so the water exemption covers the restore; the golden is re-extracted in
  // the same commit to record the restored beach (R3b authorization trail).
  {
    const gen = png.load(path.join(
      EXPLORE, 'WORLD_ATLAS_RESTORE_01', 'out', 'south_strand_e_f0.png'));
    const GX = 480, GY = 752;
    const inSail = (x, y) => x >= 760 && x <= 787 && y >= 853 && y <= 880;
    for (let y = 844; y < 906; y++) {
      for (let x = 748; x < 796; x++) {
        const ai = base.idx(x, y);
        if (y <= 879 && !inSail(x, y)) {
          const si = gen.idx(x - GX, y - GY);
          for (let k = 0; k < 4; k++) base.data[ai + k] = gen.data[si + k];
        } else {
          const si = base.idx(x, y + 66);
          for (let k = 0; k < 4; k++) base.data[ai + k] = base.data[si + k];
        }
      }
    }
  }

  // ------------------------- EPO03_ATLAS_REGIONS (owner-authorised replacement)
  //
  // DECISIONS/0033: the approved atlas is a state the owner may replace. The
  // regions here are that replacement, so — unlike every layer above — they
  // are NOT clipped against the A-4 core or its rim, and may overwrite a
  // landmark golden they DECLARE in `reauthorizes` (the golden is then
  // re-extracted in the same commit; the golden guard below still compares).
  // What keeps the new state protected: every pixel this block writes is
  // marked `claimed`, `protDepth` treats a claimed pixel as hard core, the
  // `approved` snapshot is re-taken as the block's last statement, and the
  // drift guard walks the whole canvas. The guard is never weakened (G-4).
  //
  // Placed here, after the ghost-sail restore and before the water-only
  // conform, because at this point the base IS the shipped composite the
  // regions were cropped from (GOV-03 §1a): a mask's ramp dithers the
  // generation against the terrain the reviewer actually saw, and nothing
  // content-bearing runs after it.
  //
  // Five manifests, one per producer team, in fixed order (later wins where
  // masks overlap; landmarks last so a re-authored landmark supersedes
  // regional terrain). Every team commits {"regions":[]} at kickoff so a
  // missing file is a defect, not an absence. Salts are >= 40 and unique
  // (1–15 legacy, 20–32 FMPO02). Masks are built by
  // `GAME_BIBLE/ART/exploration/EPO03/tools/atlas-mask.js` with
  // `coreAuthor` / `reauthorizes`; compositing is the same hash dither-SELECT
  // as FMPO02 (A-2 — never an average).
  {
    const EPO03 = path.join(EXPLORE, 'EPO03', 'out', 'atlas');
    const MANIFESTS = ['manifest_north.json', 'manifest_south.json',
      'manifest_west.json', 'manifest_east.json', 'manifest_landmarks.json'];
    const reg = JSON.parse(
      fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8'));
    const seenIds = new Set(), seenSalts = new Set(), shipped = [];
    for (const file of MANIFESTS) {
      const mf = path.join(EPO03, file);
      if (!fs.existsSync(mf)) {
        throw new Error(`EPO03 atlas: ${file} missing — every team commits ` +
          `{"regions":[]} at kickoff so --check stays honest`);
      }
      const manifest = JSON.parse(fs.readFileSync(mf, 'utf8'));
      for (const region of manifest.regions) {
        if (region.status !== 'accepted') {
          throw new Error(`EPO03 atlas region ${region.id} (${file}): status ` +
            `'${region.status}' — only accepted regions may ship`);
        }
        if (seenIds.has(region.id)) {
          throw new Error(`EPO03 atlas: duplicate region id ${region.id}`);
        }
        if (typeof region.salt !== 'number' || seenSalts.has(region.salt) || region.salt < 40) {
          throw new Error(`EPO03 atlas region ${region.id}: salt ${region.salt} — ` +
            `must be unique across all five manifests and >= 40`);
        }
        seenIds.add(region.id); seenSalts.add(region.salt);
        const gen = png.load(path.join(EPO03, `${region.id}.png`));
        const mask = png.load(path.join(EPO03, `${region.id}_mask.png`));
        if (gen.width !== region.w || gen.height !== region.h ||
            mask.width !== region.w || mask.height !== region.h) {
          throw new Error(`EPO03 atlas region ${region.id}: expected ` +
            `${region.w}x${region.h}, got gen ${gen.width}x${gen.height}, ` +
            `mask ${mask.width}x${mask.height}`);
        }
        // A golden the mask touches must be declared; the declaration is the
        // producer's statement that the golden is re-extracted in this commit.
        const declared = new Set(region.reauthorizes || []);
        for (const lm of reg.landmarks) {
          if (declared.has(lm.id)) continue;
          const sx0 = Math.max(0, lm.x - region.x), sy0 = Math.max(0, lm.y - region.y);
          const sx1 = Math.min(region.w, lm.x + lm.w - region.x);
          const sy1 = Math.min(region.h, lm.y + lm.h - region.y);
          for (let sy = sy0; sy < sy1; sy++) {
            for (let sx = sx0; sx < sx1; sx++) {
              if (mask.data[mask.idx(sx, sy)] !== 0) {
                throw new Error(`EPO03 atlas region ${region.id}: mask touches ` +
                  `golden '${lm.id}' at (${region.x + sx},${region.y + sy}) but ` +
                  `does not declare it in reauthorizes`);
              }
            }
          }
        }
        for (const id of declared) {
          if (!reg.landmarks.some((lm) => lm.id === id)) {
            throw new Error(`EPO03 atlas region ${region.id}: reauthorizes unknown golden '${id}'`);
          }
          reauthorized.add(id);
        }
        for (let sy = 0; sy < region.h; sy++) {
          for (let sx = 0; sx < region.w; sx++) {
            const m = mask.data[mask.idx(sx, sy)];
            if (m === 0) continue;
            const tx = region.x + sx, ty = region.y + sy;
            if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
            // Selection, not blending: the mask is a probability, and the
            // pixel that wins is whole.
            if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
            const si = gen.idx(sx, sy);
            // A transparent source pixel is crop padding, not authored terrain.
            if (gen.data[si + 3] === 0) continue;
            // No protDepth / keepRepair clip: this layer IS the new approved state.
            const ai = base.idx(tx, ty);
            for (let k = 0; k < 4; k++) base.data[ai + k] = gen.data[si + k];
            claimed[ty * 1024 + tx] = 1;
          }
        }
        shipped.push(`${file.replace(/^manifest_|\.json$/g, '')}/${region.id}`);
      }
    }
    if (shipped.length) console.log(`  atlas EPO03 regions: ${shipped.join(', ')}`);
    if (reauthorized.size) {
      console.log(`  atlas EPO03 re-authorised goldens: ${[...reauthorized].join(', ')}`);
    }
    // The interior of record is now the EPO03-inclusive composite.
    approved = base.clone();
  }

  // Deterministic open-ocean conform (single source of the water math). Runs
  // LAST — after the restore and the edge fixes — so every layer's deep water
  // (strip, bridge, master coast, edge pieces with older conforms baked in)
  // maps through ONE global transform and no tonal panel edge can survive
  // between layers. The guards touch only teal deep water — never ice, land
  // or shallows.
  //
  // World Atlas Remaster 01, Phase 0: two conform-rect edges read as straight
  // lines in flat water on the phone (the east-bay waterline at x=636 and the
  // far-NE corner above y=60). The remaster's water_join tool adds those two
  // strips to the SAME global transform, then dissolves the bay edge into a
  // hash-dithered shoaling ramp (salt 7) between the bright master-painted
  // bay water and the one sea. Provenance:
  // `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/README.md`.
  const remWater = require(path.join(
    EXPLORE, 'WORLD_ATLAS_REMASTER_01', 'tools', 'water_join.js'));
  const preConform = base.clone();
  oceanTool.unify(base, remWater.EXTRA_RECTS);
  remWater.shoalRamp(base, preConform, hash);

  // Sea-ice sage cleanup (deterministic, A-2). FINAL-04 #7: a sage-green
  // patch sits in the leads between the northern floes at roughly
  // 700..750 x 160..220 — 343 px of #6dc5b2, a hue nothing in the pack ice is
  // legitimately made of (the shelf teal runs the other way: blue leads
  // green). It is in neither the 4d9a81f master nor N3's own generation, so
  // it is compositor debris, not authored terrain, and it is removed here
  // rather than in a region source for that reason. Each debris pixel takes
  // the colour of the nearest clean pixel on a fixed offset list — nothing is
  // invented and nothing is averaged. The rect is mandatory: the same
  // predicate matches every blade of grass on the map.
  {
    const isSage = (i) => base.data[i + 1] > base.data[i] + 40
      && base.data[i + 1] > base.data[i + 2] + 8;
    const OFF = [[0, 2], [0, -2], [2, 0], [-2, 0], [0, 4], [0, -4],
      [4, 0], [-4, 0], [3, 3], [-3, 3], [3, -3], [-3, -3]];
    const [x0, y0, x1, y1] = [620, 90, 790, 240];
    let removed = 0;
    for (let pass = 0; pass < 24; pass++) {
      const fills = [];
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          // An EPO03-replaced shelf is approved terrain, not N3 seam debris.
          if (protDepth(x, y) > PROT.band) continue;
          const i = base.idx(x, y);
          if (!isSage(i)) continue;
          for (const [ox, oy] of OFF) {
            const si = base.idx(x + ox, y + oy);
            if (isSage(si)) continue;
            fills.push([i, si]);
            break;
          }
        }
      }
      if (!fills.length) break;
      const snapshot = Buffer.from(base.data);
      for (const [ai, si] of fills) {
        for (let k = 0; k < 4; k++) base.data[ai + k] = snapshot[si + k];
      }
      removed += fills.length;
    }
    if (removed) console.log(`  atlas sea-ice sage cleanup: ${removed} px`);
  }


  // Golden re-extraction (DECISIONS/0033): the golden guard below throws
  // before `emit`, so a composite that legitimately re-authors a landmark is
  // never written. With ATLAS_DUMP set, the pre-guard composite is saved to
  // that path so the re-extraction tool can crop the new golden from it;
  // the guard still runs and still throws — nothing is bypassed.
  if (process.env.ATLAS_DUMP) png.save(process.env.ATLAS_DUMP, base);

  // Protected-interior guard: beyond the rim band, every pixel that is not
  // conformable open water must be byte-identical to the approved snapshot.
  // Any future repair layer that repaints the master interior fails packaging
  // (and therefore `--check`) rather than shipping drift (`MISTAKES.md` M-15).
  // Walks the whole canvas: a claimed EPO03 pixel is hard core anywhere.
  {
    let drift = 0;
    for (let y = 0; y < 1024; y++) {
      for (let x = 0; x < 1024; x++) {
        if (protDepth(x, y) <= PROT.band) continue;
        const i = base.idx(x, y);
        const same = base.data[i] === approved.data[i] &&
          base.data[i + 1] === approved.data[i + 1] &&
          base.data[i + 2] === approved.data[i + 2];
        if (same) continue;
        // The ocean conform legitimately remaps teal deep water in place.
        if (oceanTool.isDeep(approved.data[i], approved.data[i + 1], approved.data[i + 2])) continue;
        drift++;
      }
    }
    if (drift > 0) {
      throw new Error(`world/atlas_base: protected interior drift — ${drift} px ` +
        `of the approved master core were repainted by a repair layer (M-15)`);
    }
  }

  // Landmark-registry guard (World Atlas Remaster 01): protected features
  // OUTSIDE the master core — the volcano's east cliff, the caravan road,
  // the south strand, the island clusters, overlay grounds in the rim band —
  // are held against committed golden crops extracted from the accepted
  // composite post-conform. Any layer that touches one fails packaging and
  // `--check`. Deliberate re-authoring of a landmark = re-extracting its
  // golden in the same commit (the golden's git diff is the authorization).
  // Deep-teal water in a golden is exempt, exactly like the A-4 guard: the
  // global conform's statistics legitimately shift when any layer changes
  // any water anywhere.
  {
    const reg = JSON.parse(
      fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8'));
    for (const lm of reg.landmarks) {
      const golden = png.load(path.join(REM01, 'goldens', `${lm.id}.png`));
      if (golden.width !== lm.w || golden.height !== lm.h) {
        throw new Error(`landmark ${lm.id}: golden is ${golden.width}x${golden.height}, ` +
          `registry says ${lm.w}x${lm.h}`);
      }
      let drift = 0;
      for (let sy = 0; sy < lm.h; sy++) {
        for (let sx = 0; sx < lm.w; sx++) {
          const gi = golden.idx(sx, sy), ai = base.idx(lm.x + sx, lm.y + sy);
          const same = base.data[ai] === golden.data[gi] &&
            base.data[ai + 1] === golden.data[gi + 1] &&
            base.data[ai + 2] === golden.data[gi + 2];
          if (same) continue;
          if (oceanTool.isDeep(golden.data[gi], golden.data[gi + 1], golden.data[gi + 2])) continue;
          drift++;
        }
      }
      if (drift > 0) {
        throw new Error(`world/atlas_base: protected landmark '${lm.id}' drifted ` +
          `(${drift} px vs its golden) — a layer repainted a registry feature ` +
          `(A-4 extension, World Atlas Remaster 01)`);
      }
    }
  }

  emit('world/atlas_base.png', encode(base));
}

/**
 * REWORKED IN-PLACE SCENES — the fire, the yeti and the bear, this time as
 * edits of the painting itself so nothing can float (the device review's
 * verdict on the pasted sprites). Each is a 64 × 64 crop of the master,
 * edited by PixelLab (`edit_image`) and animated by `animate_image`.
 *
 * The animations wobble the terrain around the subject, so unlike the part-2
 * feather — which trusted the whole frame — each frame here is composited
 * back onto its source crop through a fixed **content box**: outside the box
 * the pixels are the source's own; the box's outer rings blend inward
 * (0–1 source, 2–3 blend 2:1, 4–5 blend 1:2, interior generated). Only the
 * box is emitted; everything outside it is identical to the painting and
 * would be dead weight. Box coordinates were measured on the accepted frames
 * and are recorded here so the transformation is reproducible.
 */
const WMP03_ENV = path.join(WMP03, 'env');
/** [gen] composited onto [src] through [box] = [x, y, w, h], then cropped. */
function boxFeather(src, gen, box) {
  const [bx, by, bw, bh] = box;
  const out = new png.Raster(bw, bh);
  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      const ring = Math.min(x, y, bw - 1 - x, bh - 1 - y);
      const w = ring < 2 ? 3 : ring < 4 ? 2 : ring < 6 ? 1 : 0;
      const si = src.idx(bx + x, by + y);
      const gi = gen.idx(bx + x, by + y);
      const oi = out.idx(x, y);
      for (let k = 0; k < 4; k++) {
        out.data[oi + k] = Math.round(
          (src.data[si + k] * w + gen.data[gi + k] * (3 - w)) / 3,
        );
      }
    }
  }
  return out;
}
const WMP03_SCENES = {
  // fire2 is retired: the caravan corridor cut through the master's forest
  // (WMER02) runs through its content box, so the always-visible frame 0
  // would paint pre-corridor forest over the road. The burn-scar concept is
  // re-authored as fire3 in the south-west forest (WMER02 scenes below);
  // the fire2 sources stay in WMP03's out/ as evidence.
  // The yeti's box starts two rows lower than the content measurement said,
  // deliberately: at [10, 10] the emitted region's top edge grazed
  // Frostmere's hit circle in the placement sweep, and the two trimmed rows
  // are blank ice the feather returned to the painting anyway.
  yeti2: { box: [10, 12, 44, 34], frames: [1, 2, 3, 4, 5, 6, 7, 8] },
  // The bear is a discovery: its cycle opens on the untouched canopy
  // (frame 0 = the source box, so an intermittent play fades in from the
  // painting), rises through the duck-away frames REVERSED, then plays the
  // look-around-and-duck forward. f12 is pinned to the empty canopy and is
  // the natural exit; the sampled reverse is its entrance.
  bear2: {
    box: [20, 16, 26, 28],
    cycle: [null, 10, 8, 6, 4, 2, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  },
};
for (const [id, spec] of Object.entries(WMP03_SCENES)) {
  const src = png.load(path.join(WMP03_ENV, `inplace_${id}_src_64.png`));
  if (src.width !== 64 || src.height !== 64) {
    throw new Error(`inplace ${id}: source is ${src.width}x${src.height}`);
  }
  const gen = (i) => {
    const frame = png.load(
      path.join(WMP03_ENV, `inplace_${id}_raw_64_f${i}.png`),
    );
    if (frame.width !== 64 || frame.height !== 64) {
      throw new Error(`inplace ${id} f${i}: ${frame.width}x${frame.height}`);
    }
    return frame;
  };
  const sequence = spec.cycle ?? spec.frames;
  let out = 0;
  for (const i of sequence) {
    const frame = i == null
      ? png.crop(src, ...spec.box)
      : boxFeather(src, gen(i), spec.box);
    emit(`env/overlay_${id}_f${out++}.png`, encode(frame));
  }
}

/**
 * WMER02 IN-PLACE SCENES — the same crop → edit → animate → box-feather
 * method as WMP03, with this round's file naming (`<id>_src_64.png`,
 * `<id>_f<i>.png`). fire3 replaces the corridor-displaced fire2 in the
 * south-west forest. The stag follows the bear's discovery pattern: cycle
 * opens on the untouched roadside (frame 0 = the source box), enters through
 * sampled reversed exit frames, holds its standing look, then exits forward
 * (f10 is pinned to the empty source). The flock's animation is pinned at
 * both ends to the untouched marsh, so the plain frame sequence opens and
 * closes empty.
 */
const WMER02_ENV = path.join(WMER02, 'env');
const WMER02_SCENES = {
  fire3: { box: [12, 0, 44, 52], frames: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] },
  stag: {
    box: [8, 12, 28, 22],
    cycle: [null, 9, 7, 5, 3, 1, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  },
  flock: {
    box: [0, 24, 64, 40],
    frames: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    filePrefix: 'flock2',
  },
};
for (const [id, spec] of Object.entries(WMER02_SCENES)) {
  const src = png.load(path.join(WMER02_ENV, `${id}_src_64.png`));
  if (src.width !== 64 || src.height !== 64) {
    throw new Error(`wmer02 ${id}: source is ${src.width}x${src.height}`);
  }
  const gen = (i) => {
    const frame = png.load(
      path.join(WMER02_ENV, `${spec.filePrefix ?? id}_f${i}.png`),
    );
    if (frame.width !== 64 || frame.height !== 64) {
      throw new Error(`wmer02 ${id} f${i}: ${frame.width}x${frame.height}`);
    }
    return frame;
  };
  const sequence = spec.cycle ?? spec.frames;
  let out = 0;
  for (const i of sequence) {
    const frame = i == null
      ? png.crop(src, ...spec.box)
      : boxFeather(src, gen(i), spec.box);
    emit(`env/overlay_${id}_f${out++}.png`, encode(frame));
  }
}

/**
 * REWORKED AND NEW CREATURES — transparent travelling sprites: the loch
 * serpent (replacing the slug-read water dragon), the sky dragon, the whale,
 * and the sail. Each set is cropped to the union of every frame's opaque
 * bounds, measured here (the same rule the part-2 creatures recorded by
 * hand), padded by one pixel and clamped to the canvas.
 */
const WMP03_CREATURES = {
  // The serpent's cycle is two pinned animations joined at the risen still:
  // rise (submerged → risen, 7 frames counting the input) then swim-and-dive
  // (risen → submerged, 11). The rise's input frame IS the dive's pinned
  // ending, so the joined cycle opens and closes on the same near-empty
  // splash and nothing pops.
  nessie: {
    canvas: [48, 36],
    files: [
      ...Array.from({ length: 7 }, (_, i) => `creature_nessie_rise_48x36_f${i}.png`),
      ...Array.from({ length: 10 }, (_, i) => `creature_nessie_swim_48x36_f${i + 1}.png`),
    ],
  },
  // The dragon's journey is two flight loops then the WMER02 fire-breath
  // moment (owner brief): the breath was animated from the same still the
  // flight loop grew from, so the splice frames nearly coincide. With
  // `playLoops: 1` in the layout, the breath happens exactly once per
  // crossing. Direction note: the sprite's head faces west and the layout's
  // travel vector now points west too — the WMP03 data had it flying
  // tail-first east.
  skydragon: {
    canvas: [72, 32],
    files: [
      ...Array.from({ length: 10 }, (_, i) => `creature_skydragon_raw_72x32_f${i + 1}.png`),
      ...Array.from({ length: 10 }, (_, i) => `creature_skydragon_raw_72x32_f${i + 1}.png`),
      ...Array.from({ length: 8 }, (_, i) => ({
        dir: path.join(WMER02, 'env'),
        name: `firebreath_f${i + 1}.png`,
      })),
    ],
  },
  whale: {
    canvas: [64, 64],
    files: Array.from({ length: 9 }, (_, i) => `creature_whale_raw_64_f${i}.png`),
  },
  ship: { canvas: [64, 64], files: ['creature_ship_still_64.png'] },
  // WMER02: a tiny covered wagon for the caravan corridor. One still; motion
  // is the layout's v5 `travel`, the ship's pattern.
  caravan: {
    canvas: [24, 24],
    files: [{ dir: path.join(WMER02, 'env'), name: 'caravan_f0.png' }],
  },
};
for (const [id, spec] of Object.entries(WMP03_CREATURES)) {
  const [cw, ch] = spec.canvas;
  const frames = spec.files.map((file) => {
    const frame = typeof file === 'string'
      ? png.load(path.join(WMP03_ENV, file))
      : png.load(path.join(file.dir, file.name));
    if (frame.width !== cw || frame.height !== ch) {
      throw new Error(`${file}: expected ${cw}x${ch}, got ${frame.width}x${frame.height}`);
    }
    return frame;
  });
  let x0 = cw, y0 = ch, x1 = -1, y1 = -1;
  for (const frame of frames) {
    for (let y = 0; y < ch; y++) {
      for (let x = 0; x < cw; x++) {
        if (frame.alphaAt(x, y) > 0) {
          if (x < x0) x0 = x;
          if (y < y0) y0 = y;
          if (x > x1) x1 = x;
          if (y > y1) y1 = y;
        }
      }
    }
  }
  x0 = Math.max(0, x0 - 1);
  y0 = Math.max(0, y0 - 1);
  x1 = Math.min(cw - 1, x1 + 1);
  y1 = Math.min(ch - 1, y1 + 1);
  frames.forEach((frame, i) => {
    emit(
      `env/overlay_${id}_f${i}.png`,
      encode(png.crop(frame, x0, y0, x1 - x0 + 1, y1 - y0 + 1)),
    );
  });
  console.log(`  ${id}: ${frames.length} frames at ${x1 - x0 + 1}x${y1 - y0 + 1} (crop ${x0},${y0})`);
}

// ------------------------------------------------ Fable V2 Iteration 03

/**
 * THE DEPTH PASS — recorded placeholder art, all A-2 byte copies, zero
 * generations (`MILESTONES/FABLE_V2_EXPERIMENT_01.md`, Iteration 03).
 *
 * Item icons: every Masterwork variant CONSUMES the item whose icon it
 * copies (the fiction is the same piece, reforged around a trophy), so the
 * copy and its donor almost never share a bag; the two foods copy the dish
 * they are cooked from. Distinct authored icons are the recorded future
 * PixelLab round. Copied from the emitted bytes so the copy can never
 * drift from what actually shipped.
 */
for (const [id, donor] of Object.entries({
  // All eight are now authored icons — see the VAWO01 block below.
})) {
  const bytes = emitted.get(`item/${donor}.png`);
  if (!bytes) throw new Error(`iteration 03 icon donor missing: item/${donor}.png`);
  emit(`item/${id}.png`, bytes);
}

/**
 * VAWO01 — THE AUTHORED ICONS THAT REPLACE THE RECORDED BYTE COPIES.
 *
 * Eleven items shipped a byte-identical copy of another item's icon, recorded
 * in the two blocks below as placeholders awaiting "the recorded future
 * PixelLab round". This is that round.
 *
 * The justification for the copies was that a Masterwork piece CONSUMES its
 * donor, so "the copy and its donor almost never share a bag". True of the bag,
 * and false of the screen: the Craft screen shows 39 rows drawn from 21 distinct
 * pictures, donor and copy side by side, and three of the donors are starter
 * gear worn from minute one.
 *
 *  is here for a different reason and is not a copy. It shipped as a
 * ROUND boulder differing from Copper Ore only by inclusion colour — 90.5%
 * silhouette overlap, which is drift D-5, named and banned by this project's
 * own style spec and shipped anyway. It is re-authored angular, so the two are
 * tellable apart in greyscale.
 */
const VAWO_ITEM_SRC = path.join(EXPLORE, 'VAWO01', 'out', 'items');
for (const id of [
  'fanghilt_sword',
  'tuskbound_jerkin',
  'goblin_toothed_axe',
  'scalewarmed_chestplate',
  'clawguard_coat',
  'hornpoint_pickaxe',
  'traveler_ration',
  'expedition_stew',
  'waywarden_tunic',
  'tinbraced_pickaxe',
  'frostwarden_coat',
  'tin_ore',
]) {
  // FMPO02 wave 2 re-authored five of these twelve — see `fmpo02ItemPath`.
  const raster = png.load(
    fmpo02ItemPath(id) || path.join(VAWO_ITEM_SRC, `${id}.png`),
  );
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(
      `item ${id}: expected 48x48, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`item/${id}.png`, encode(raster));
}

/**
 * Node plates for the five depth nodes — the same deterministic-copy rule
 * as the Verge nodes: each reuses the scenery of the node whose subject it
 * deepens (a heartwood oak is an oak stand; the old workings are a worked
 * seam; the veiled silkstrand is a thicket; the sheltered meadow is the
 * rimefrost hollow behind a windbreak; the mill garden is the meadow,
 * cultivated). Distinct authored scenery is a recorded future round (A-1).
 */
for (const [id, sourceId] of Object.entries({
  heartwood_oak: 'oak_stand',
  old_workings: 'copper_seam',
  veiled_silkstrand: 'hollow_thicket',
  sheltered_frost_meadow: 'rimefrost_hollow',
  mill_garden: 'meadow_patch',
})) {
  const raster = png.load(path.join(ITEMS_SRC, `node_${sourceId}_96.png`));
  emit(`node/${id}.png`, encode(raster));
}

// ------------------------------------------- Fable Depth Offensive 01

/**
 * THE DEPTH OFFENSIVE PASS (`DECISIONS/0028`) — recorded placeholder art,
 * all A-2 byte copies, zero generations.
 *
 * Item icons: each bronze-lineage piece CONSUMES the item whose icon it
 * copies (the fiction is the same piece, rebuilt around the trophy haul),
 * so the copy and its donor almost never share a bag. Distinct authored
 * icons are the recorded future PixelLab round. Copied from the emitted
 * bytes so the copy can never drift from what actually shipped.
 *
 * The four Veteran Hunt elites need NO rows here — they reuse their
 * species' full packaged combat sets via `CombatAssets.enemyFor` (code,
 * not packaged bytes).
 */
for (const [id, donor] of Object.entries({
  // All three are now authored icons — see the VAWO01 block below.
})) {
  const bytes = emitted.get(`item/${donor}.png`);
  if (!bytes) throw new Error(`depth offensive icon donor missing: item/${donor}.png`);
  emit(`item/${id}.png`, bytes);
}

/**
 * Node plates for the five depth nodes — the same deterministic-copy rule
 * as Iteration 03: each reuses the scenery of the node whose subject it
 * deepens (the warded grove is the oak line's deep stand; the gallery tin
 * lode deepens the tin line; the collapsed span is the scrap line's deep
 * working; the undercroft silkfall deepens the silk line; the deep hollow
 * thicket is the root line, further down). Copied from the emitted bytes —
 * some donors are themselves recorded copies, and the chain must land on
 * what actually shipped. Distinct authored scenery is a recorded future
 * round (A-1).
 */
for (const [id, donor] of Object.entries({
  warded_grove: 'heartwood_oak',
  gallery_tin_lode: 'deep_tin_seam',
  collapsed_span: 'old_workings',
  undercroft_silkfall: 'veiled_silkstrand',
  deep_hollow_thicket: 'hollow_thicket',
})) {
  const bytes = emitted.get(`node/${donor}.png`);
  if (!bytes) throw new Error(`depth offensive plate donor missing: node/${donor}.png`);
  emit(`node/${id}.png`, bytes);
}

// ------------------------------------------------------- FMPO02 wave 2 art
/**
 * THE WAVE-2 FAMILIES (`MILESTONES/evidence/FMPO02/wave2/*_report.md`).
 *
 * Six accepted families land here — gather, items, enemies, world life,
 * rewards and the combat stage. Two rules govern all of them.
 *
 * **One emitter owns one path.** Four of the six *replace* art an earlier
 * round shipped. A second `emit` for the same file does not quietly win:
 * under `--check` the earlier call compares its bytes against the file on
 * disk and reports `stale:`, so CI fails on a file that is in fact correct.
 * A replacement therefore moves the **source** of the existing emitter rather
 * than adding a second one. `fmpo02ItemPath` and `fmpo02GatherPath` below are
 * that override; they are called from the item and gather blocks hundreds of
 * lines above this one, which is legal because a function declaration is
 * hoisted to the top of the module and `EXPLORE` is initialised long before
 * either is ever called.
 *
 * **A manifest is the contract wherever the round wrote one.** World life
 * ships 131 frames whose canvas differs per asset; every size asserted here is
 * read from `out/worldlife/manifest.json`, so packaging cannot silently
 * disagree with what the round delivered.
 */
const FMPO02_OUT = path.join(EXPLORE, 'FMPO02', 'out');

/**
 * The source file for `item/<id>.png` when FMPO02 wave 2 re-authored it, and
 * `null` when it did not — the caller then keeps its own source.
 *
 * Nine icons across five earlier rounds (`ITEMS_report.md`): three that
 * measured a silhouette collision against a sibling, three that read as the
 * wrong object, and three re-authored for tier legibility. The ids stay in
 * their original lists so each round's roster still reads as that round's
 * roster; only where the pixels come from changes.
 */
function fmpo02ItemPath(id) {
  const REAUTHORED = new Set([
    'hearty_stew',
    'goblin_toothed_axe',
    'tinbraced_pickaxe',
    'clawguard_coat',
    'lynx_pelt',
    'pristine_horn',
    'scalewarmed_chestplate',
    'bronze_longsword',
    'fanghilt_sword',
  ]);
  // `EXPLORE` rather than `FMPO02_OUT`: this runs from the item blocks above,
  // where the `const` a few lines up is still in its temporal dead zone.
  return REAUTHORED.has(id)
    ? path.join(EXPLORE, 'FMPO02', 'out', 'items', `icon_${id}_48.png`)
    : null;
}

/**
 * The source file for a gather plate FMPO02 wave 2 re-authored, or `null`.
 *
 * [file] is the plate's own basename — `bg_stonefall_lift`, `prop_meadow_bed`
 * — not the region×skill key, because that is what both VAWO01 loops build
 * before they load. Four backdrops whose rock read as dressed masonry or a
 * doorway, and three subjects that sat on an isometric tile or a plinth
 * instead of on the ground (`GATHER_report.md`).
 */
function fmpo02GatherPath(file) {
  const REAUTHORED = new Set([
    'bg_stonefall_mining',
    'bg_stonefall_lift',
    'bg_stonefall_gallery',
    'bg_hollow_foraging',
    'prop_meadow_bed',
    'prop_rime_cushion',
    'prop_hollow_root',
  ]);
  // `EXPLORE`, for the same dead-zone reason as `fmpo02ItemPath`.
  return REAUTHORED.has(file)
    ? path.join(EXPLORE, 'FMPO02', 'out', 'gather', `${file}.png`)
    : null;
}

/**
 * The three salvage-crate icons (`ITEMS_report.md`, `ART-07_item_brief.md` §3).
 *
 * Net-new paths rather than replacements: all three reclaim recipes output
 * `item.bronze_ingot`, so the bench drew one plain ingot on three rows with
 * nothing to say which piece was being broken down. These are recipe-level
 * art — one crate motif, differentiated by the ghost stamp inside the lid —
 * and `PixelIcons._recipeIcons` already names these three paths.
 */
for (const [id, src] of Object.entries({
  reclaim_axe: 'icon_reclaim_axe_48.png',
  reclaim_pickaxe: 'icon_reclaim_pickaxe_48.png',
  reclaim_chestplate: 'icon_reclaim_chestplate_48.png',
})) {
  const raster = png.load(path.join(FMPO02_OUT, 'items', src));
  if (raster.width !== 48 || raster.height !== 48) {
    throw new Error(
      `${src}: expected 48x48, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`item/${id}.png`, encode(raster));
}

/**
 * THE ENEMY ROUND (`ENEMIES_report.md`, brief `ART-08_enemy_brief.md`).
 *
 * Three things the roster did not have:
 *
 * - **Five habitat plates**, 192 × 76 and fully opaque, one per region a
 *   fight can happen in. They are packaged at the family's own canvas and
 *   carry no footprint: a habitat is ground, and grounding the ground would
 *   draw a contact shadow across the middle of the stage.
 * - **The missing flinches.** Four families recoiled by translation because
 *   no hit track existed; boar, bear, salamander and crawler now have one,
 *   and the crawler gets the defeat its pack round withheld. Every canvas and
 *   anchor row matches the family's shipped idle exactly, so nothing on the
 *   stage moves.
 * - **Four elites with their own sprites.** `DECISIONS/0028` shipped the
 *   Veteran Hunts pointing at the base species' files, so a named elite was
 *   its species with a different label. Each now has an idle and an attack of
 *   its own; the hit, defeat and heavy tracks stay borrowed from the base
 *   family, which is recorded in `combat_assets.dart` rather than hidden.
 *
 * `rimeclaw_matriarch` sits one row lower than the shipped lynx (40 against
 * 39) because the edit made the cat huskier. Each elite carries its own
 * measured footprint, so no correction is needed for that.
 */
const FMPO_ENEMY_SRC = path.join(FMPO02_OUT, 'enemies');
for (const id of [
  'habitat_forest_floor',
  'habitat_rocky_ledge',
  'habitat_cave_shadow',
  'habitat_snowbank',
  'habitat_hollow_rootbed',
]) {
  const raster = png.load(path.join(FMPO_ENEMY_SRC, `${id}.png`));
  if (raster.width !== 192 || raster.height !== 76) {
    throw new Error(
      `${id}: expected 192x76, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`combat/${id}.png`, encode(raster));
}
// [id, frames, canvas edge] — every canvas is the family's shipped square.
const FMPO_ENEMY_TRACKS = [
  ['boar_hit', 6, 56],
  ['bear_hit', 6, 76],
  ['salamander_hit', 6, 56],
  ['crawler_hit', 6, 48],
  ['crawler_defeat', 8, 48],
  ['old_grey_idle', 8, 56],
  ['old_grey_attack', 8, 56],
  ['gallery_foreman_idle', 8, 56],
  ['gallery_foreman_attack', 8, 56],
  ['rimeclaw_matriarch_idle', 8, 56],
  ['rimeclaw_matriarch_attack', 8, 56],
  ['guardian_awakened_idle', 8, 96],
  ['guardian_awakened_attack', 8, 96],
];
for (const [id, frames, edge] of FMPO_ENEMY_TRACKS) {
  for (let i = 0; i < frames; i++) {
    const frame = png.load(path.join(FMPO_ENEMY_SRC, `${id}_f${i}.png`));
    if (frame.width !== edge || frame.height !== edge) {
      throw new Error(
        `${id}_f${i}: expected ${edge}x${edge}, got ${frame.width}x${frame.height}`,
      );
    }
    if (i === 0) combatFootprints[`combat_${id}`] = png.footprint(frame);
    emit(`combat/${id}_f${i}.png`, encode(frame));
  }
}

/**
 * The re-horned ram idle, packaged as `ram2_idle` and wired to nothing.
 *
 * `ENEMIES_report.md` §4 offers these seven frames as a *candidate* full
 * replacement for the shipped `ram_idle`, and leaves the adoption to the
 * integrator on one stated condition — re-measuring the boar↔ram silhouette
 * IoU — which that round did not have the tooling to do. Adopting it here
 * would turn an unmet precondition into a silent design decision
 * (`RULES.md` G-3), so the frames ship under their own id, the combat table
 * is untouched, and the owner's ruling costs one table edit rather than a
 * re-run. Same 56² canvas and anchor row 42 as the shipped set.
 */
for (let i = 0; i < 7; i++) {
  const frame = png.load(path.join(FMPO_ENEMY_SRC, `ram_idle_insurance_f${i}.png`));
  if (frame.width !== 56 || frame.height !== 56) {
    throw new Error(
      `ram2_idle f${i}: expected 56x56, got ${frame.width}x${frame.height}`,
    );
  }
  if (i === 0) combatFootprints['combat_ram2_idle'] = png.footprint(frame);
  emit(`combat/ram2_idle_f${i}.png`, encode(frame));
}

/**
 * WORLD LIFE (`WORLDLIFE_report.md`, briefs ART-03 §6 and ART-04).
 *
 * Seventeen overlays and three landmark props for the world atlas. Two of the
 * overlays **supersede** VAWO01's dragons: the red wyrm grows from 72 × 32 to
 * 96 × 64 and the storm drake to 96 × 56, both still nine frames, both
 * re-drawn as their own anatomy rather than a palette swap of each other. The
 * VAWO01 emitter that used to own those two paths is retired above — exactly
 * one emitter may own a file — and the frame count is unchanged, so no orphan
 * frame is left behind for `--check` to report as unexpected.
 *
 * Placement is not decided here. `assets/content/v1/atlas/atlas_layout.json`
 * is a separate hand-authored table with a slot budget the report proposes
 * retirements against; packaging a sprite makes it available, not placed.
 */
const FMPO_WORLDLIFE_SRC = path.join(FMPO02_OUT, 'worldlife');
const fmpoWorldlife = JSON.parse(
  fs.readFileSync(path.join(FMPO_WORLDLIFE_SRC, 'manifest.json'), 'utf8'),
);
for (const entry of fmpoWorldlife.assets) {
  const [w, h] = entry.canvas.split('x').map(Number);
  const check = (raster, what) => {
    if (raster.width !== w || raster.height !== h) {
      throw new Error(
        `worldlife ${what}: manifest says ${entry.canvas}, `
        + `got ${raster.width}x${raster.height}`,
      );
    }
  };
  if (entry.kind === 'prop') {
    const raster = png.load(path.join(FMPO_WORLDLIFE_SRC, `${entry.name}.png`));
    check(raster, entry.name);
    emit(`env/${entry.name}.png`, encode(raster));
    continue;
  }
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(
      path.join(FMPO_WORLDLIFE_SRC, `${entry.name}_f${i}.png`),
    );
    check(frame, `${entry.name}_f${i}`);
    emit(`env/${entry.name}_f${i}.png`, encode(frame));
  }
}

/**
 * THE REWARD MARKS (`REWARDS_report.md`, brief `ART-10_reward_brief.md`).
 *
 * Three of the round's four files: a rarity-neutral drop sack at 24², and two
 * 96 × 48 banner seals for the two completions that earn one. The fourth,
 * `grain_notable_plate`, is a card **surface** rather than a mark, so it ships
 * in the hand-maintained `assets/ui/v1/` tree with a provenance row, not here
 * — this script writes `assets/art/v1/` and only that.
 */
for (const [id, w, h] of [
  ['mark_rare_drop', 24, 24],
  ['seal_signature', 96, 48],
  ['seal_masterwork', 96, 48],
]) {
  const raster = png.load(path.join(FMPO02_OUT, 'reward', `${id}.png`));
  if (raster.width !== w || raster.height !== h) {
    throw new Error(
      `reward ${id}: expected ${w}x${h}, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`reward/${id}.png`, encode(raster));
}

/**
 * THE TALLER COMBAT BACKDROPS (`COMBAT_STAGE_report.md`, brief ART-09).
 *
 * The stage's four biome plates repainted 192 × 96 → 192 × 128: the original
 * rows 32–127 are the shipped picture unchanged, and the new top 40 rows are
 * inpainted atmosphere above it. The ground row moves 88 → 120 and the two
 * figure columns (58 and 138) do not move, because only the canvas grew.
 *
 * They ship under new ids beside the 96-tall originals rather than over them.
 * The stage geometry that consumes them is a separate task; until it lands,
 * `CombatAssets` still resolves the 96-tall set, and a backdrop nothing draws
 * yet is cheaper than a half-wired stage.
 */
for (const biome of ['forest', 'mine', 'hollow', 'frostmere']) {
  const id = `backdrop_${biome}_128`;
  const raster = png.load(path.join(FMPO02_OUT, 'combat', `${id}.png`));
  if (raster.width !== 192 || raster.height !== 128) {
    throw new Error(
      `${id}: expected 192x128, got ${raster.width}x${raster.height}`,
    );
  }
  emit(`combat/${id}.png`, encode(raster));
}

// -------------------------------------------------- FMPO02 equipment matrix
/**
 * THE TRAVELER WEARS WHAT HE EQUIPPED, EVERYWHERE.
 *
 * VAWO01 put the armour on the Inventory figure and left the shirt on every
 * other surface; the owner's device found the contradiction at once. FMPO02
 * authors the matrix `ART-05_equipment_brief.md` costs out: three armoured
 * bodies (plate, jerkin, coat) × three weapon classes (bronze, steel, unarmed)
 * in combat, plus per-body forage / idle-breathe / look-around / walk-west
 * strips and five bronze-tool working loops. 52 of 56 ordered tracks were
 * accepted (`MILESTONES/evidence/FMPO02/wave2/EQUIPMENT_report.md`); the
 * plate + bronze pick probe joins them.
 *
 * ## Deterministic preparation (`RULES.md` A-2)
 *
 * `FMPO02/tools/equip-prep.js` cropped every v3 square (88–104²) to one
 * window per strip — `canvasWidth` × 64, the **modal** foot row on row 62 —
 * and keyed the detached specks the model leaves; the window is one per
 * strip, never per frame, so nothing jumps. Three raised sword tips lose
 * 1–14 px off the top of one frame each and are accepted; the numbers are in
 * `out/equip/tracks/PREP_SUMMARY.json`.
 *
 * The three forage strips were animated west and turned east to kneel —
 * the model's own choice — while the stage stands the plant to the west, so
 * they are **mirrored** here. A mirror is a transform of authored frames, not
 * a drawing; the light flips with it, which is invisible on a crouching
 * figure and is recorded rather than hidden.
 *
 * The single-component assertion is the same ghost-gear guard the VAWO01
 * sets ship under: a frame whose opaque pixels are not one piece is a weapon
 * off the hand or a floating artifact, and neither may ship.
 */
const FMPO_EQUIP_SRC = path.join(EXPLORE, 'FMPO02', 'out', 'equip', 'tracks');
// Brace (6f) is the fifth track: the stance the choreography used to fake
// with a held idle because no authored pose existed. One v3 roll per state,
// all eleven accepted first time (`review/equip/brace_all_x2.png`).
const FMPO_COMBAT_TRACKS = [
  ['idle', 8], ['attack', 8], ['hit', 6], ['stagger', 8], ['brace', 6],
];
const FMPO_COMBAT_SETS = [
  // The two VAWO01 base-body sets gain their brace here; the base + steel
  // set is the pre-PixelLab shipped art and has no state to animate.
  ['traveler_base_unarmed_brace', 6],
  ['traveler_base_bronze_brace', 6],
];
for (const body of ['plate', 'jerkin', 'coat']) {
  for (const held of ['bronze', 'steel', 'unarmed']) {
    for (const [track, frames] of FMPO_COMBAT_TRACKS) {
      FMPO_COMBAT_SETS.push([`traveler_${body}_${held}_${track}`, frames]);
    }
  }
}
// [id, frames, width, mirror]
const FMPO_AMBIENT_STRIPS = [
  ['traveler_jerkin_bronzeaxe_woodcut', 8, 80, false],
  ['traveler_coat_bronzeaxe_woodcut', 8, 80, false],
  ['traveler_base_bronzeaxe_woodcut', 8, 80, false],
  ['traveler_jerkin_bronzepick_mine', 8, 80, false],
  // `traveler_plate_bronzepick_mine` moved to the EPO03 EQUIPMENT block
  // below — its head was recoloured to the muted copper the other four bronze
  // tool strips use, so its source is now `EPO03/out/equip/tracks/`. Emitting
  // it from both places would make `--check` compare the old bytes against
  // the new file and report a permanent staleness, so the row moves rather
  // than being overridden. See that block for the reason and the evidence.
  // Re-dressed from the jerkin pick strip by reference edit (garment swapped,
  // pose and tool kept) after v3 failed twice on each — see traveler_art.dart.
  ['traveler_coat_bronzepick_mine', 8, 80, false],
  ['traveler_base_bronzepick_mine', 8, 80, false],
  ['traveler_plate_bronzeaxe_woodcut', 8, 80, false],
  // The steel column: the bronze strips with the tool head recoloured to
  // dull steel by a text edit (~20 gens each), so an armoured Traveler with a
  // training tool shows the tool he holds rather than borrowing bronze.
  ['traveler_plate_steelpick_mine', 8, 80, false],
  ['traveler_jerkin_steelpick_mine', 8, 80, false],
  ['traveler_coat_steelpick_mine', 8, 80, false],
  ['traveler_plate_steelaxe_woodcut', 8, 80, false],
  ['traveler_jerkin_steelaxe_woodcut', 8, 80, false],
  ['traveler_coat_steelaxe_woodcut', 8, 80, false],
  ['traveler_plate_forage', 9, 64, true],
  ['traveler_jerkin_forage', 9, 64, true],
  ['traveler_coat_forage', 9, 64, true],
  // The craft loops re-dressed by reference edit from the shipped
  // activity_smith / activity_cook frames (74x64 and 46x64, foot row 62 kept
  // by the edit; measured before packaging, no prep). FINAL-03 blocker 1:
  // Craft drew the base body while every other stage wore the armour.
  ['traveler_plate_smith', 7, 74, false],
  ['traveler_jerkin_smith', 7, 74, false],
  ['traveler_coat_smith', 7, 74, false],
  ['traveler_plate_cook', 7, 46, false],
  ['traveler_jerkin_cook', 7, 46, false],
  ['traveler_coat_cook', 7, 46, false],
  ['traveler_plate_idle_breathe', 8, 64, false],
  ['traveler_jerkin_idle_breathe', 8, 64, false],
  ['traveler_coat_idle_breathe', 8, 64, false],
  ['traveler_plate_look_around', 7, 64, false],
  ['traveler_jerkin_look_around', 7, 64, false],
  ['traveler_coat_look_around', 7, 64, false],
  ['traveler_plate_walk_west', 6, 64, false],
  ['traveler_jerkin_walk_west', 6, 64, false],
  ['traveler_coat_walk_west', 6, 64, false],
];
/**
 * Bronze reads as bronze, not gold (`ART_DIRECTION.md` L-19).
 *
 * The council's pixel director measured the PixelLab bronze blades and tool
 * heads at their two hottest inks — (246,144,39) and (235,99,7), with a few
 * (240,138,87) siblings — against the item family's copper highlight
 * (200,133,54): the strips glowed where the icons did not. This is a palette
 * remap, not a drawing (A-2): every pixel whose colour is brighter and more
 * saturated than the hair ramp can ever be (R ≥ 225, G ≤ 150, B ≤ 90, and
 * R − G ≥ 80) is snapped to the icon family's highlight. The jerkin's
 * reddish hair tops out at (227,152,88) — G 152 — so the threshold misses it
 * by construction, and every other body colour is far below it.
 */
function toneBronze(frame) {
  // The item family's copper highlight (bronze_sword.png, measured).
  const copper = [200, 133, 54];
  const d = frame.data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] === 0) continue;
    const r = d[i], g = d[i + 1], b = d[i + 2];
    if (r >= 225 && g <= 150 && b <= 90 && r - g >= 80) {
      d[i] = copper[0];
      d[i + 1] = copper[1];
      d[i + 2] = copper[2];
      n++;
    }
  }
  return n;
}
/** Drops every 8-connected opaque component smaller than [minPixels]. */
function despeckle(frame, minPixels) {
  const d = frame.data;
  const W = frame.width;
  const H = frame.height;
  const seen = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) {
    if (seen[i] || d[i * 4 + 3] === 0) continue;
    const comp = [i];
    seen[i] = 1;
    for (let k = 0; k < comp.length; k++) {
      const x = comp[k] % W;
      const y = (comp[k] - x) / W;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx;
          const ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          const j = ny * W + nx;
          if (!seen[j] && d[j * 4 + 3] !== 0) {
            seen[j] = 1;
            comp.push(j);
          }
        }
      }
    }
    if (comp.length < minPixels) for (const j of comp) d[j * 4 + 3] = 0;
  }
}
function fmpoStrip(id, frames, width, mirror, dest, footprints) {
  const bronze = /bronze/.test(id);
  for (let i = 0; i < frames; i++) {
    let frame = png.load(path.join(FMPO_EQUIP_SRC, `${id}_f${i}.png`));
    if (frame.width !== width || frame.height !== 64) {
      throw new Error(
        `FMPO02 ${id} f${i}: expected ${width}x64, got ${frame.width}x${frame.height}`,
      );
    }
    if (mirror) frame = flipX(frame);
    if (bronze) toneBronze(frame);
    // The plate + bronze pick probe kept its swing-streak effect: 217
    // near-white pixels in f4 and none anywhere else in the strip or on the
    // figure (no body colour has every channel >= 225). Keying them removes
    // an effect the model drew; it draws nothing (A-2). FINAL-03/FINAL-12.
    if (id === 'traveler_plate_bronzepick_mine') {
      const d = frame.data;
      for (let p = 0; p < d.length; p += 4) {
        if (d[p + 3] !== 0 && Math.min(d[p], d[p + 1], d[p + 2]) >= 225) {
          d[p + 3] = 0;
        }
      }
    }
    // Lone pixels are not ghost gear. The keyed streak above leaves two, one
    // of them on row 63 under the feet — exactly where a "standing figure"
    // flood starts (M-17) — and the cook re-dress edits leave a 2 px chip off
    // the spoon in one frame. Any 8-connected component under four pixels is
    // dropped on these strips only; the figure is one component of ≈1,300.
    if (id === 'traveler_plate_bronzepick_mine' || /_(smith|cook)$/.test(id)) {
      despeckle(frame, 4);
    }
    let opaque = 0;
    for (let p = 3; p < frame.data.length; p += 4) {
      if (frame.data[p] !== 0) opaque++;
    }
    if (attachedPixelCount(frame) !== opaque) {
      throw new Error(
        `FMPO02 ${id} f${i}: ${opaque - attachedPixelCount(frame)} px are not ` +
          'attached to the standing figure (ghost gear or a floating artifact).',
      );
    }
    if (i === 0) footprints[`${dest}_${id}`] = png.footprint(frame);
    emit(`${dest}/${id}_f${i}.png`, encode(frame));
  }
}
for (const [id, frames] of FMPO_COMBAT_SETS) {
  fmpoStrip(id, frames, 80, false, 'combat', combatFootprints);
}
// The armoured busts for the Character folio: the shipped portrait with the
// garment swapped by a single-frame edit, one per body class, so the face at
// the top of the sheet wears what the figure below it wears.
for (const body of ['plate', 'jerkin', 'coat']) {
  const bust = png.load(
    path.join(EXPLORE, 'FMPO02', 'out', 'portrait', `traveler_${body}.png`),
  );
  if (bust.width !== 64 || bust.height !== 64) {
    throw new Error(`FMPO02 portrait ${body}: expected 64x64`);
  }
  emit(`portrait/traveler_${body}.png`, encode(bust));
}
for (const [id, frames, width, mirror] of FMPO_AMBIENT_STRIPS) {
  fmpoStrip(id, frames, width, mirror, 'ambient', ambientFootprints);
}

// ------------------------------------------- EPO03 EQUIPMENT (PROD-EQUIPMENT)
/**
 * EPO03 wave 2, the equipment family — DIR-08's top failures, closed in
 * priority order. Every strip here is 80 x 64 with the feet on row 62 already,
 * so it needs no `equip-prep` window: each was made by editing an *accepted,
 * shipped* strip frame-for-frame, which carries the geometry over by
 * construction (the same route the FMPO02 craft re-dresses took).
 *
 * This block runs AFTER the FMPO02 matrix on purpose. `emit()` keys by path,
 * so a strip re-emitted here replaces the FMPO02 one in the packaged set and
 * in `--check`, without editing another round's list.
 *
 * **P1a — `base|weapon.steel` has a brace at last.** DIR-08 failure 4: a
 * training-sword player pressing Brace had no braced figure at all (0 files),
 * because FMPO02 authored brace for the two VAWO01 base sets and the nine
 * armoured loadouts but not for the pre-PixelLab base + steel set. The strip
 * is `traveler_base_bronze_brace` with the bronze blade re-drawn as the plain
 * pale steel training blade by one 6-frame `edit_image` text edit; the man,
 * his shirt and vest, his pack and the whole six-frame guard are the accepted
 * strip's own pixels. It inherits its source's one weakness — the blade reads
 * in f0-f2 and is hidden behind the forearms in f3-f5 — which the armoured
 * brace strips do not have; that is the source's pose, not the edit's
 * (`EPO03/review/equip/p1_base_steel_brace_x3.png`, and the family sheet
 * `brace_family_x3.png` beside it).
 *
 * **P1b — the Plate Bronze Pick stops being the odd one out.** DIR-08 failure
 * 2: five bronze tool strips, and the plate pick was a saturated orange the
 * other four were not (it is the wave-A probe `0f7a53bf`, ordered before the
 * other four states set the family's muted copper). One 8-frame `edit_image`
 * text edit recolours the head to that muted copper and touches nothing else.
 * Two things fall out of it, both measured: the strip now snaps **0** pixels
 * under `toneBronze` (it is already inside the copper ramp, where the old one
 * was not), and the swing-streak the FMPO02 block keys out of f4 is simply
 * gone — the keying above is left in place, harmless, because it is that
 * block's record of what its own source needed.
 */
const EPO_EQUIP_SRC = path.join(EXPLORE, 'EPO03', 'out', 'equip', 'tracks');
const EPO_LS_SRC = path.join(EXPLORE, 'EPO03', 'out', 'equip', 'ls');
function epoStrip(id, frames, width, dest, footprints, src = EPO_EQUIP_SRC) {
  for (let i = 0; i < frames; i++) {
    const frame = png.load(path.join(src, `${id}_f${i}.png`));
    if (frame.width !== width || frame.height !== 64) {
      throw new Error(
        `EPO03 ${id} f${i}: expected ${width}x64, got ` +
          `${frame.width}x${frame.height}`,
      );
    }
    if (/bronze|longsword/.test(id)) toneBronze(frame);
    // A lone pixel is not ghost gear. The craft re-dress leaves a 2 px chip
    // off the spoon in one cook frame — the same artifact, from the same
    // route, that the FMPO02 block despeckles above; the figure is one
    // component of about 1,300, so a component under four pixels cannot be
    // anything a player sees.
    if (/_(smith|cook)$/.test(id)) despeckle(frame, 4);
    // The same ghost-gear guard every Traveler strip ships under: a frame
    // whose opaque pixels are not one 8-connected piece is a weapon off the
    // hand or a floating artifact (`RULES.md` A-1).
    let opaque = 0;
    for (let p = 3; p < frame.data.length; p += 4) {
      if (frame.data[p] !== 0) opaque++;
    }
    if (attachedPixelCount(frame) !== opaque) {
      throw new Error(
        `EPO03 ${id} f${i}: ${opaque - attachedPixelCount(frame)} px are not ` +
          'attached to the standing figure (ghost gear or a floating artifact).',
      );
    }
    if (i === 0) footprints[`${dest}_${id}`] = png.footprint(frame);
    emit(`${dest}/${id}_f${i}.png`, encode(frame));
  }
}
const EPO_COMBAT_STRIPS = [['traveler_base_steel_brace', 6]];
const EPO_AMBIENT_STRIPS = [['traveler_plate_bronzepick_mine', 8, 80]];
for (const [id, frames] of EPO_COMBAT_STRIPS) {
  epoStrip(id, frames, 80, 'combat', combatFootprints);
}
for (const [id, frames, width] of EPO_AMBIENT_STRIPS) {
  epoStrip(id, frames, width, 'ambient', ambientFootprints);
}

/**
 * **P2 — the Bronze Longsword stops being the Bronze Sword** (DIR-08 failure
 * 1; the owner's own words, "must visibly differ, not just colour").
 *
 * Four bodies × five combat tracks. The epic longsword and the uncommon
 * bronze sword were one blade shape in one colour, so the reward for a long
 * chain of crafting looked exactly like its own ingredient.
 *
 * ## How it was made, and why it cost 30 generations rather than 245
 *
 * The FMPO02 route to a new held item was `create_character_state` (≈44) per
 * body plus one `animate_character` per track — ≈49 a body, ≈245 for five.
 * This round found a cheaper one that is also more faithful:
 *
 * 1. `edit_image_pixen` (**1 generation**) on the body's own accepted
 *    `traveler_<body>_bronze_idle_f0` — a shipped frame — replacing the short
 *    leaf blade with a long straight one, cross-guard and two-hand grip. The
 *    body, the armour, the pack and the foot row are the shipped frame's own
 *    pixels; only the blade changes, and the opaque box grows to the right by
 *    11–19 px, which is the silhouette difference, measured.
 * 2. `animate_character` v3 (**1 generation** per track) with that PNG as
 *    `custom_start_frame_url`, which the tool accepts in place of the
 *    character's rotation. Identity comes from the canonical Traveler; the
 *    gear comes from the frame.
 *
 * ## The canvas the base body needed
 *
 * The base figure's blade came back the longest of the four (its tip reaches
 * x 79 of an 80-wide start frame), and three of its five tracks then measured
 * a union box up to 98 px across. ART-05 §3 says the *declared* width grows
 * and is recorded — never a per-frame re-crop — so **all five base tracks are
 * 104 wide**, the whole set together so the figure cannot shift between
 * tracks. The other three bodies stay at 80. `CombatTrack` has always carried
 * width per track (the shipped base set is 80/64/56 across its own four), and
 * every strip still stands on row 62.
 *
 * ## Judged, not assumed
 *
 * Twenty-five v3 rolls for twenty tracks. Five were rejected on the reading
 * and re-rolled: four staggers that walked backwards instead of going down on
 * a knee, and a `base` flinch that lost the blade entirely at f3 (the
 * documented v3 failure). The re-roll wording is the FMPO02 fix — name the
 * garment, name the blade "fully visible in every frame", "seen from the side
 * facing right the whole time", "the figure staying the same size" — plus, for
 * the staggers, describing the *end pose* rather than the motion. Sheets are
 * in `EPO03/review/equip/ls_*`; the census over every accepted frame reads 0
 * gold-leaning pixels, 0 detached components and 0 partial-alpha pixels.
 */
const EPO_LONGSWORD_TRACKS = [['idle', 8], ['attack', 8], ['hit', 6],
  ['stagger', 8], ['brace', 6]];
for (const body of ['plate', 'jerkin', 'coat', 'base']) {
  for (const [track, frames] of EPO_LONGSWORD_TRACKS) {
    epoStrip(`traveler_${body}_longsword_${track}`, frames,
      body === 'base' ? 104 : 80, 'combat', combatFootprints, EPO_LS_SRC);
  }
}

/**
 * **P3 — the Waywarden's Tunic gets a body of its own** (DIR-08 failure 3 and
 * its new `armor.warden` class).
 *
 * Two rare and epic chest pieces — `waywarden_tunic` and `frostwarden_coat` —
 * shared a class with garments they do not look like: the tunic had no row at
 * all and drew the starting shirt in all ten contexts, and the Frostwarden
 * Coat borrowed the bearhide coat. The warden is the fifth body: a **pointed
 * hood up**, a tiered cloth mantle wider than the shoulders, a knee-length
 * coat split up the front so both legs show, and tall boots — a silhouette
 * that separates from plate, jerkin, coat and the base shirt at arm's length,
 * which is DIR-08's own success criterion.
 *
 * ## One state, thirty strips
 *
 * `create_character_state` on the canonical Traveler at 80 x 64 (job
 * `76bf1ace`) — so this is the same individual, and its eight rotations come
 * back already 80 x 64 with the feet on **row 62**, which is the shipped
 * anchor with no cropping at all. Everything else derives from those three
 * rotations:
 *
 * - **combat**, four held classes x five tracks. The east rotation *is* the
 *   unarmed pose; the steel, bronze and longsword poses are one-generation
 *   `edit_image_pixen` edits of it that change only what is in his hands
 *   (measured: the opaque box grows to the right by 13, 13 and 27 px). Each
 *   is then the `custom_start_frame_url` of one v3 animation per track.
 * - **bare**: idle-breathe and look-around from the south rotation, walk-west
 *   and forage from the west rotation, animated directly.
 * - **gather**: the west rotation with each of the four tool heads put in his
 *   hands by a one-generation edit, then one v3 loop each.
 * - **craft**: the shipped `activity_smith` / `activity_cook` frames
 *   re-dressed by a 7-frame `edit_image` text edit, the pose, the hammer, the
 *   spoon, the pack and the foot row kept — the FMPO02 craft route.
 * - **figure and bust**: the south rotation centre-cropped to 64 x 64 (a
 *   window, not a redraw), and the shipped coat portrait re-hooded by one
 *   edit so the face at the top of the Character folio is the same man.
 *
 * ## What was rejected on the reading
 *
 * The unarmed punch came back with a black-and-white checkerboard where the
 * fist should be, and both the steel and longsword overhead cuts swung the
 * blade clean out of the 64-row window (19 and 38 px above it, and the
 * longsword's union box measured 84 px across an 80-wide canvas). All three
 * were re-rolled: the punch as "a bare hand plainly a hand in every frame",
 * the two cuts as "a flat horizontal sweep at waist height, the blade never
 * rising above his shoulder" — which is the same lever that fixed the coat's
 * longsword brace. The mining loop's impact sparks (29 px across two frames)
 * are keyed by `equip-prep`'s largest-component rule, as every strip's are.
 */
const EPO_WARDEN_SRC = path.join(EXPLORE, 'EPO03', 'out', 'equip', 'warden');
const EPO_WARDEN_SPRITE = path.join(
  EXPLORE, 'EPO03', 'out', 'equip', 'warden_sprite',
);
for (const held of ['unarmed', 'steel', 'bronze', 'longsword']) {
  for (const [track, frames] of EPO_LONGSWORD_TRACKS) {
    // The warden's longsword needs the wider declared canvas the base body's
    // does, for the same reason: its union box measures 84 px across.
    epoStrip(`traveler_warden_${held}_${track}`, frames,
      held === 'longsword' ? 104 : 80, 'combat', combatFootprints,
      EPO_WARDEN_SRC);
  }
}
// [id, frames, width]. Forage is authored west and kneels west, which is the
// side the stage stands the plant on, so unlike the FMPO02 forage strips it
// is **not** mirrored.
const EPO_WARDEN_AMBIENT = [
  ['traveler_warden_bronzepick_mine', 8, 80],
  ['traveler_warden_steelpick_mine', 8, 80],
  ['traveler_warden_bronzeaxe_woodcut', 8, 80],
  ['traveler_warden_steelaxe_woodcut', 8, 80],
  ['traveler_warden_forage', 9, 64],
  ['traveler_warden_idle_breathe', 8, 64],
  ['traveler_warden_look_around', 7, 64],
  ['traveler_warden_walk_west', 6, 64],
  ['traveler_warden_smith', 7, 74],
  ['traveler_warden_cook', 7, 46],
];
for (const [id, frames, width] of EPO_WARDEN_AMBIENT) {
  epoStrip(id, frames, width, 'ambient', ambientFootprints, EPO_WARDEN_SRC);
}
{
  const figure = png.load(
    path.join(EPO_WARDEN_SPRITE, 'traveler_south_warden.png'),
  );
  if (figure.width !== 64 || figure.height !== 64) {
    throw new Error('EPO03 warden figure: expected 64x64');
  }
  emit('sprite/traveler_south_warden.png', encode(figure));
  const bust = png.load(
    path.join(EPO_WARDEN_SPRITE, 'traveler_warden_portrait.png'),
  );
  if (bust.width !== 64 || bust.height !== 64) {
    throw new Error('EPO03 warden portrait: expected 64x64');
  }
  emit('portrait/traveler_warden.png', encode(bust));
}
/**
 * **P4 — the Hornpoint Pickaxe stops being the bronze pick** (DIR-08 failure
 * 2, the half of it that survives).
 *
 * Five T2 tool heads all drew the plain bronze head. This ships the one that
 * came back clean: a **pale bone-white curved horn tip** on the same
 * copper-bronze socket and the same haft, swapped into each of the five
 * bodies' own bronze mining loops by one 8-frame `edit_image` text edit. It
 * reads at a glance because the horn is the opposite value to the copper, and
 * it holds its shape in all forty frames, with every frame's foot row equal to
 * its source's.
 *
 * **The special AXE head was rejected**, and its two items stay on
 * `tool.axe.bronze`. The same route gave a wider hooked head with a serrated
 * bit — genuinely different — but the head *morphs between frames*: on the
 * warden strip it is pale in f1, small and dark in f2 and a forked orange hook
 * in f3 and f5, and the plate strip leaves a stray chip in f5. A tool whose
 * head changes shape mid-swing is a worse defect than the hue-only difference
 * it was meant to fix, and there was no budget left to re-roll five strips.
 * The candidates are kept under `EPO03/raw/equip/spec_*_axe/` and the reasoning
 * is in the ledger; the items resolve to bronze, which is what they are made
 * of.
 */
const EPO_SPECIAL_SRC = path.join(
  EXPLORE, 'EPO03', 'out', 'equip', 'special',
);
for (const body of ['plate', 'jerkin', 'coat', 'base', 'warden']) {
  epoStrip(`traveler_${body}_hornpick_mine`, 8, 80, 'ambient',
    ambientFootprints, EPO_SPECIAL_SRC);
}


// ----------------------------------------- EPO03 LANDMARKS (PROD-WORLD-LANDMARKS)
/**
 * EPO03 wave 2, the fantasy-landmark family — DIR-03.
 *
 * The three landmarks stopped being props this round. The fairy castle, the
 * storm house and the ice tower were 31 x 39, 25 x 21 and 48 x 80 sprites
 * standing ON the map; each is now painted INTO the terrain as an atlas region
 * (`out/atlas/manifest_landmarks.json`, composited by the EPO03 atlas block
 * far above), which is also why a landmark survives overview zoom, where props
 * are hidden. What ships here is the motion that sits on top of the painting.
 *
 * Four overlays, all at NET-NEW paths. Three supersede an older overlay in
 * SLOT rather than in file: `overlay_fairy_motes` (five toned discs),
 * `overlay_storm_lightning` (a 6 %-duty bolt over nothing) and
 * `overlay_ice_beacon` (48 x 80, on a pedestal that no longer exists). Their
 * files are deliberately left packaged and untouched, because
 * `assets/content/v1/atlas/atlas_layout.json` still points at them and its
 * `overlays` array belongs to PROD-WORLD-LIFE: re-emitting one of those paths
 * at a new canvas would fail `atlas_layout_test` the moment it landed, hours
 * before the team that owns the row could swap it. The four rows are requested
 * in `MILESTONES/evidence/EPO03/wave2/REQUESTS_LIFE.md` with exact JSON; once
 * they land, the three superseded files are unreferenced and the producer may
 * retire their emitters at closeout.
 *
 * Every canvas below is asserted from the family manifest, so packaging cannot
 * silently disagree with what the round delivered, and `env/` is a
 * per-directory pubspec entry, so no new frame needs a pubspec line.
 */
const EPO_LANDMARK_SRC = path.join(EXPLORE, "EPO03", "out", "landmarks");
const epoLandmarks = JSON.parse(
  fs.readFileSync(path.join(EPO_LANDMARK_SRC, "manifest.json"), "utf8"),
);
for (const entry of epoLandmarks.assets) {
  const [w, h] = entry.canvas.split("x").map(Number);
  for (let i = 0; i < entry.frames; i++) {
    const frame = png.load(
      path.join(EPO_LANDMARK_SRC, `${entry.name}_f${i}.png`),
    );
    if (frame.width !== w || frame.height !== h) {
      throw new Error(
        `EPO03 landmarks ${entry.name}_f${i}: manifest says ${entry.canvas}, `
        + `got ${frame.width}x${frame.height}`,
      );
    }
    emit(`env/${entry.name}_f${i}.png`, encode(frame));
  }
}

// ---------------------------------------------- EPO03 UI-SKILLS (PROD-UI-SKILLS)
/**
 * EPO03 wave 2, the Skills journey family (`DIR-07`) — the marks the rebuilt
 * roadmap hangs on its road. Consumed through
 * `lib/ui/screens/skills/track_art.dart`, which is SKILLS' own registry: the
 * journey names in the shared kit contract are deliberately left unregistered
 * this round (`KIT_CONTRACT` §8), so nothing here is NAV's.
 *
 * Two rules this block enforces, because both are the kind of thing that is
 * invisible until it is on a phone:
 *
 * - **the declared canvas.** A joint is 24 x 24 drawn at x2 and an emblem is
 *   64 x 64 drawn at x1; `PixelAsset` asserts on a mismatch at run time, and a
 *   packaging step that lets the wrong size through only moves the failure to
 *   the device.
 * - **transparency.** Every mark is placed on the page's own buckram, so an
 *   opaque background box would draw a rectangle on a screen whose entire
 *   point is that it has none.
 *
 * What is NOT here, and why: the road strip itself. Two `pixen` rolls at 32²
 * (`2c2607ad`, `3c09d3dd`) came back as a wood-plank fence and as a
 * two-colour orange/grey checkerboard dither — the tool's flat-tileable-chrome
 * boundary the kit owner measured at 31 rejected rolls
 * (`ledger/UI_KIT.md`, `KIT_CONTRACT` §8). The road, the folds, the caps and
 * the badge plates stay Flutter-painted in `skill_detail_screen.dart`, at
 * exactly the geometry `TrackArt` declares, so a strip that lands later needs
 * no reflow.
 */
const EPO_SKILLS_SRC = path.join(EXPLORE, 'EPO03', 'out', 'skills');
const EPO_SKILLS_MARKS = [
  ['joint_reached', 24],
  ['joint_here', 24],
  ['joint_next', 24],
  ['joint_far', 24],
  ['gate_seal', 24],
  ['emblem_mining', 64],
  ['emblem_foraging', 64],
  ['emblem_smithing', 64],
  ['emblem_woodcutting', 64],
  ['emblem_cooking', 64],
];
for (const [name, extent] of EPO_SKILLS_MARKS) {
  const mark = png.load(path.join(EPO_SKILLS_SRC, `${name}.png`));
  if (mark.width !== extent || mark.height !== extent) {
    throw new Error(
      `EPO03 track ${name}: expected ${extent}x${extent}, got ` +
        `${mark.width}x${mark.height}`,
    );
  }
  let opaqueEdge = 0;
  for (let x = 0; x < mark.width; x++) {
    if (mark.data[(0 * mark.width + x) * 4 + 3] === 255) opaqueEdge++;
    if (mark.data[((mark.height - 1) * mark.width + x) * 4 + 3] === 255) {
      opaqueEdge++;
    }
  }
  if (opaqueEdge === mark.width * 2) {
    throw new Error(
      `EPO03 track ${name}: the top and bottom rows are fully opaque — this ` +
        'is a mark on the page, not a plate with a background.',
    );
  }
  emit(`track/${name}.png`, encode(mark));
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

/**
 * The contact span of every gather-scene subject plate.
 *
 * Measured in one sweep over what was emitted rather than at each of the six
 * `emit('node/…')` sites, so a plate added by a future round is measured by
 * existing here rather than by someone remembering to instrument its branch.
 * Reading the bytes back (rather than the raster) is what makes the figure
 * identical under `--check`, where nothing is written to disk.
 *
 * **Why these need footprints at all.** `GroundedSprite`'s own documentation
 * says a bare `PixelAsset` on a background *is* the floating defect, and the
 * Traveler has gone through it since Playable Polish 01 — but the thing he is
 * hitting never did. It was built by `_prop` as a bare `PixelAsset`, so for
 * every gather in the product the man was grounded and the ore seam was not.
 * That asymmetry is the mechanical half of the owner's "weird isolated object
 * floating in the centre of a scene": the geometry was always right — the
 * subject's base sits on the ground line — and the *light* was always wrong.
 */
/**
 * Both families a gather scene can resolve a subject from, and only those:
 *
 * - `node/*.png` — the 96² vignette plates, which twelve of the twenty-two
 *   nodes still fall through to;
 * - `work/prop_*.png` — the ten authored work props, which the other ten use.
 *
 * `work/bg_*` and `work/station_*` are deliberately excluded. A backdrop is the
 * ground; grounding the ground would darken a strip across the middle of the
 * scene for nothing.
 */
const SUBJECT_FAMILIES = [/^node\/(.+)\.png$/, /^work\/(prop_.+)\.png$/];

const nodeFootprints = {};
for (const [rel, bytes] of emitted) {
  for (const re of SUBJECT_FAMILIES) {
    const m = re.exec(rel);
    if (!m) continue;
    nodeFootprints[rel] = png.footprint(png.decodeAny(bytes, rel));
    break;
  }
}

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

  /// Every gather-scene subject plate, keyed by the asset path the scene
  /// resolves.
  ///
  /// A map rather than named constants because the consumer is
  /// \`AmbientStage._prop\`, which is handed a \`StageScenery\` and knows only its
  /// \`assetPath\`. Hand-wiring a footprint into each of the twenty-odd
  /// \`StageScenery\` literals would put the measurement and the plate in two
  /// places that can disagree; this cannot drift, because both sides come from
  /// the same packaging run.
  static const Map<String, SpriteFootprint> byNodeAsset =
      <String, SpriteFootprint>{
${Object.entries(nodeFootprints).sort(([a], [b]) => a.localeCompare(b)).map(([rel, f]) => `    'assets/art/v1/${rel}': SpriteFootprint(
      left: ${f.left},
      right: ${f.right},
      bottom: ${f.bottom},
    ),`).join('\n')}
  };
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
