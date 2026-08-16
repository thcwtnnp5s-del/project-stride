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
};

for (const [id, file] of Object.entries(ITEM_ICONS)) {
  const raster = png.load(path.join(STABLE, 'icons_full', file));
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

const regionMap = png.load(path.join(STABLE, 'world', 'region_map_384x640.png'));
png.blit(
  regionMap,
  png.load(path.join(
    EXPLORE, 'PHASE1_CARRIED_CORRECTIONS', 'out',
    'region_map_tarn_patch_96x96.png',
  )),
  TARN_PATCH.x,
  TARN_PATCH.y,
);
emit('world/region_map.png', encode(regionMap));

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

const vignette = png.load(
  path.join(STABLE, 'location', 'havens_rest_vignette_512x384.png'),
);
keyBorderWhite(vignette);
emit(
  'location/havens_rest.png',
  encode(png.crop(
    vignette,
    VIGNETTE_CROP.x, VIGNETTE_CROP.y,
    VIGNETTE_CROP.width, VIGNETTE_CROP.height,
  )),
);

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
