// check-item-distinctness.js — ART-07 §6 pairwise perceptual-collision gate.
//
// For every same-family pair named in ART-07 §1/§2, measures:
//   1. Silhouette IoU  — binary alpha mask (opaque > threshold), each icon
//      cropped to its opaque bounding box and re-centred on its alpha
//      centroid onto a shared canvas so pose/offset does not skew the score.
//   2. Colour-histogram intersection — 16 bins/channel (R,G,B), each
//      channel's histogram normalized to sum 1 over the opaque pixels, the
//      three per-channel intersections averaged into one score in [0,1].
//   3. Greyscale re-check — this repo's guguard rejects any 0<alpha<255
//      pixel (no partial alpha ships), so alpha itself carries no colour and
//      a literal "desaturate then redo the alpha IoU" is a no-op by
//      construction. To give the D-5 check real teeth, "greyscale IoU" here
//      instead thresholds each icon's OWN opaque pixels at its own median
//      luminance into a light/dark value-partition, aligns those partitions
//      the same way as step 1, and takes the IoU of the two "light" regions.
//      This asks a different question than step 1 (does the internal
//      shading/value pattern also line up, not just the outline) and is
//      documented here precisely because ART-07 §6 does not spell out the
//      literal algorithm — this is a reasoned, stated interpretation, not
//      a guess left implicit.
//
// Verdict per pair:
//   COLLISION  — shapeIoU > 0.55 AND colourIntersection > 0.6 (§6.5: a pair
//                failing both silhouette and colour tests is a collision
//                regardless of names).
//   HUE_ONLY   — colourIntersection > 0.6 AND |greyIoU - shapeIoU| <= 0.05
//                (§6.4: separated by hue alone — the D-5 failure mode).
//                Auto-fail, reported even if COLLISION did not already fire.
//   WATCH      — exactly one of shapeIoU>0.55 / colourIntersection>0.6 fires
//                (§6.5: "failing only [greyscale] still needs a pattern/shape
//                tell" — recorded for visibility, not a hard fail).
//   PASS       — neither threshold fires.
//
// Usage: node check-item-distinctness.js [--dir <item png dir>]
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.resolve(__dirname, '../Scripts/art/png.js'));

const args = process.argv.slice(2);
const dirFlag = args.indexOf('--dir');
const DIR = dirFlag >= 0 ? path.resolve(args[dirFlag + 1])
  : path.resolve(__dirname, '../assets/art/v1/item');

// Same-family pairs named in ART-07 §1 (verdict table) and §2 (family
// design language). Every KEEP/RE-AUTHOR pair the brief calls out by name,
// plus the new reclaim trio against bronze_ingot and each other.
const FAMILIES = {
  ores: ['copper_ore', 'tin_ore'],
  logs: ['oak_log', 'pine_log'],
  planks: ['oak_plank', 'pine_plank'],
  vessels_food: ['hearty_stew', 'herb_broth', 'expedition_stew', 'traveler_ration', 'duskcap_skewer', 'frostbloom_tea'],
  axes: ['training_axe', 'bronze_axe', 'hornbound_bronze_axe', 'goblin_toothed_axe'],
  pickaxes: ['training_pickaxe', 'reinforced_pickaxe', 'tinbraced_pickaxe', 'hornpoint_pickaxe'],
  swords: ['training_sword', 'bronze_sword', 'bronze_longsword', 'fanghilt_sword'],
  jerkins: ['wolfhide_jerkin', 'frostlined_jerkin', 'tuskbound_jerkin', 'traveler_tunic'],
  coats: ['bearhide_coat', 'clawguard_coat', 'frostwarden_coat'],
  chestplates: ['bronze_chestplate', 'scalewarmed_chestplate'],
  pelts: ['wolf_pelt', 'lynx_pelt', 'bear_pelt', 'boar_hide'],
  horns_tusks: ['ram_horn', 'pristine_horn', 'boar_tusk', 'great_tusk', 'pristine_wolf_fang'],
  hazard_materials: ['heat_scale', 'frost_claw', 'ember_core', 'scrap_metal'],
  herbs_materials: ['meadow_herb', 'duskcap', 'rime_blossom', 'hollow_root', 'gloom_silk'],
  reclaim: ['reclaim_bronze_axe', 'reclaim_bronze_pickaxe', 'reclaim_bronze_chestplate', 'bronze_ingot'],
};

const SHAPE_IOU_FLAG = 0.55;
const COLOUR_INTERSECT_FLAG = 0.6;
const GREY_DELTA_FLAG = 0.05;
const ALPHA_THRESHOLD = 8;
const CANVAS = 96; // generous margin around a 48x48 icon after centroid shift

function loadIcon(id) {
  const direct = path.join(DIR, `${id}.png`);
  if (fs.existsSync(direct)) return png.loadAny(direct);
  return null;
}

function centroid(raster) {
  let sx = 0; let sy = 0; let n = 0;
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= ALPHA_THRESHOLD) continue;
      sx += x; sy += y; n++;
    }
  }
  if (n === 0) return null;
  return { x: sx / n, y: sy / n, n };
}

/** Places [raster]'s opaque pixels onto a CANVASxCANVAS grid, centroid at the middle. */
function alignedMask(raster) {
  const c = centroid(raster);
  const mask = new Uint8Array(CANVAS * CANVAS);
  if (!c) return mask;
  const ox = Math.round(CANVAS / 2 - c.x);
  const oy = Math.round(CANVAS / 2 - c.y);
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= ALPHA_THRESHOLD) continue;
      const dx = x + ox; const dy = y + oy;
      if (dx < 0 || dy < 0 || dx >= CANVAS || dy >= CANVAS) continue;
      mask[dy * CANVAS + dx] = 1;
    }
  }
  return mask;
}

/** As alignedMask, but only the subset of opaque pixels above [raster]'s own median luminance. */
function alignedLightMask(raster) {
  const c = centroid(raster);
  const mask = new Uint8Array(CANVAS * CANVAS);
  if (!c) return mask;
  const lums = [];
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
      lums.push(0.299 * raster.data[i] + 0.587 * raster.data[i + 1] + 0.114 * raster.data[i + 2]);
    }
  }
  lums.sort((a, b) => a - b);
  const median = lums.length ? lums[lums.length >> 1] : 128;
  const ox = Math.round(CANVAS / 2 - c.x);
  const oy = Math.round(CANVAS / 2 - c.y);
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
      const lum = 0.299 * raster.data[i] + 0.587 * raster.data[i + 1] + 0.114 * raster.data[i + 2];
      if (lum < median) continue;
      const dx = x + ox; const dy = y + oy;
      if (dx < 0 || dy < 0 || dx >= CANVAS || dy >= CANVAS) continue;
      mask[dy * CANVAS + dx] = 1;
    }
  }
  return mask;
}

function iou(a, b) {
  let inter = 0; let union = 0;
  for (let i = 0; i < a.length; i++) {
    const av = a[i]; const bv = b[i];
    if (av || bv) union++;
    if (av && bv) inter++;
  }
  return union === 0 ? 0 : inter / union;
}

function colourHistogramIntersection(a, b) {
  const BINS = 16;
  function hist(raster) {
    const h = [new Float64Array(BINS), new Float64Array(BINS), new Float64Array(BINS)];
    let n = 0;
    for (let y = 0; y < raster.height; y++) {
      for (let x = 0; x < raster.width; x++) {
        const i = raster.idx(x, y);
        if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
        for (let c = 0; c < 3; c++) {
          const bin = Math.min(BINS - 1, (raster.data[i + c] / 256 * BINS) | 0);
          h[c][bin]++;
        }
        n++;
      }
    }
    if (n > 0) for (let c = 0; c < 3; c++) for (let k = 0; k < BINS; k++) h[c][k] /= n;
    return h;
  }
  const ha = hist(a); const hb = hist(b);
  let total = 0;
  for (let c = 0; c < 3; c++) {
    let s = 0;
    for (let k = 0; k < BINS; k++) s += Math.min(ha[c][k], hb[c][k]);
    total += s;
  }
  return total / 3;
}

function comparePair(idA, idB) {
  const a = loadIcon(idA);
  const b = loadIcon(idB);
  if (!a || !b) return { idA, idB, missing: true };
  const maskA = alignedMask(a);
  const maskB = alignedMask(b);
  const shapeIoU = iou(maskA, maskB);
  const colourIntersection = colourHistogramIntersection(a, b);
  const lightA = alignedLightMask(a);
  const lightB = alignedLightMask(b);
  const greyIoU = iou(lightA, lightB);

  const collision = shapeIoU > SHAPE_IOU_FLAG && colourIntersection > COLOUR_INTERSECT_FLAG;
  const hueOnly = colourIntersection > COLOUR_INTERSECT_FLAG
    && Math.abs(greyIoU - shapeIoU) <= GREY_DELTA_FLAG;
  const watch = !collision && (shapeIoU > SHAPE_IOU_FLAG || colourIntersection > COLOUR_INTERSECT_FLAG);

  let verdict = 'PASS';
  if (hueOnly) verdict = 'HUE_ONLY (D-5 auto-fail)';
  else if (collision) verdict = 'COLLISION';
  else if (watch) verdict = 'WATCH';

  return { idA, idB, shapeIoU, colourIntersection, greyIoU, verdict };
}

const rows = [];
for (const [family, items] of Object.entries(FAMILIES)) {
  for (let i = 0; i < items.length; i++) {
    for (let j = i + 1; j < items.length; j++) {
      rows.push({ family, ...comparePair(items[i], items[j]) });
    }
  }
}

const fmt = (n) => (typeof n === 'number' ? n.toFixed(3) : 'n/a');
console.log('family\titemA\titemB\tshapeIoU\tcolourIntersection\tgreyIoU\tverdict');
for (const r of rows) {
  if (r.missing) {
    console.log(`${r.family}\t${r.idA}\t${r.idB}\tMISSING\t\t\t`);
    continue;
  }
  console.log(`${r.family}\t${r.idA}\t${r.idB}\t${fmt(r.shapeIoU)}\t${fmt(r.colourIntersection)}\t${fmt(r.greyIoU)}\t${r.verdict}`);
}
const flagged = rows.filter((r) => !r.missing && r.verdict !== 'PASS');
console.log(`\n${flagged.length} of ${rows.length} pairs flagged (COLLISION / HUE_ONLY / WATCH).`);
for (const r of flagged) {
  console.log(`  [${r.verdict}] ${r.family}: ${r.idA} vs ${r.idB} (shape=${fmt(r.shapeIoU)} colour=${fmt(r.colourIntersection)} grey=${fmt(r.greyIoU)})`);
}
