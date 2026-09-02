// kit-package.js — the EPO03 UI kit's last deterministic pass: each accepted
// piece at its shipped canvas with a sidecar declaring the geometry the
// integrator needs and nothing it has to guess. Same schema and same guards as
// FMPO02's ui-package.js (GOV-05 §4); the tree it feeds, assets/ui/v1/, is
// hand-maintained on purpose — package-art.js writes assets/art/v1/ and only that.
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const root = path.resolve(__dirname, '..');
const R = (p) => path.join(root, p);
const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function guards(r) {
  let teal = 0; let semi = 0; let over = 0; let maxL = 0; let maxHex = '';
  const cols = new Set();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semi += 1;
      if (px[3] !== 255) continue;
      cols.add(C.hex(px[0], px[1], px[2]));
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }
  return { teal, semi, over, colours: cols.size, maxHex, maxL: Number(maxL.toFixed(4)),
    verdict: teal + semi + over === 0 ? 'clean' : 'VIOLATION' };
}

function emit(outPath, raster, meta) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  png.save(outPath, raster);
  const g = guards(raster);
  fs.writeFileSync(outPath.replace(/\.png$/, '.json'),
    JSON.stringify({ ...meta, canvas: [raster.width, raster.height], guards: g }, null, 2) + '\n');
  console.log(path.relative(root, outPath).padEnd(38) + `${raster.width}x${raster.height}`
    + `  ${g.colours} colours  max ${g.maxHex} L=${g.maxL}  ${g.verdict}`);
  if (g.verdict !== 'clean') process.exitCode = 1;
}

emit(R('out/ui/nav/nav_welt_v2.png'), png.loadAny(R('out/ui/nav/nav_welt_v2.png')), {
  asset: 'nav_welt_v2',
  destination: 'assets/ui/v1/nav/nav_welt_v2.png',
  kind: 'longitudinal tile, repeated along the top edge of the 64dp nav bar and, at the same '
    + 'period and scale, along the header shelf — one chassis, one stitch (DIR-15 §2)',
  corner: null,
  band: null,
  period: 8,
  scale: 2,
  tiles: 'horizontally only; the last tile is clipped, never rescaled',
  ramp: 'the master\'s own leather, ceiling-clamped; no ramp snap',
  master: 'raw/ui/nav_welt_v2_b.png (pixen 64x32, job 7a0c4880)',
  recipe: {
    crop: 'rows 0-5, the stitch band',
    clamp: 'tools/ceiling-clamp.js — 1 colour / 8 px, #A87353 -> #97674A, linear-light rescale',
    cut: 'tools/tile-cut.js --w 8 --h 6, best-wrapping window at (12,0), join 15.219 / interior 38.341',
  },
  note: 'Replaces nav_welt (8x4). 12 dp at x2, which is the header shelf\'s 12 exactly, so the '
    + 'bar and the header are terminated by the same stitch. The master\'s bottom row was pure '
    + 'white and its two stitch rows sat over the ceiling; the band cut and the clamp are why '
    + 'neither ships.',
});

// --- EPO03 batch 5: the pro frames, and the four remapped pixen assets -------
for (const [file, meta] of [
  ['out/ui/kit/inset_well.png', {
    asset: 'inset_well', kind: 'nine-patch window frame, drawn through PixelFrame',
    corner: 16, band: 15, period: null, scale: 1,
    master: 'raw/ui/pro_insetwell_1.png (create_image_pro, job e2f51423, candidate 1 of 16)',
    recipe: { crop: 'to content, 64x64 -> 61x61', geometry: 'MEASURED by tools/frame-measure.js: band 15/15/15/15, spread 0' },
    note: 'Drawn at x1. Band 15 at x2 would inset every well by 30 logical px a side.',
  }],
  ['out/ui/kit/slot_well.png', {
    asset: 'slot_well', kind: 'nine-patch compartment well, drawn through PixelFrame',
    corner: 6, band: 4, period: null, scale: 2,
    master: 'raw/ui/pro_slotwell_6.png (create_image_pro, job e7fdfe47, candidate 6 of 16)',
    recipe: { crop: 'to content, 48x48 -> 32x32', geometry: 'MEASURED: band 5/4/5/4, spread 1; the MINIMUM is declared' },
  }],
  ['out/ui/kit/stage_frame.png', {
    asset: 'stage_frame', kind: 'nine-patch stage frame, drawn through PixelFrame',
    corner: 26, band: 19, period: null, scale: 1,
    master: 'raw/ui/pro_stageframe_3.png (create_image_pro, job 23986e06, candidate 3 of 4)',
    recipe: {
      crop: 'to content, 128x128 -> 114x114',
      geometry: 'MEASURED: band 19/19/19/19, spread 0',
      corner: 'corner 26, NOT 19, proved by tools/ninepatch-proof.js: at 26 the beams run '
        + 'unbroken; at 19 the iron corner cap falls inside the edge strip and repeats along '
        + 'every beam. review/ui/np_stage26.png vs np_stage19.png.',
    },
    note: 'L-18a: this frames a picture and shares no ground line with the figures inside it, '
      + 'so it adds no third density (DECISIONS/0031).',
  }],
  ['out/ui/kit/rule_journal.png', {
    asset: 'rule_journal', kind: 'longitudinal rule tile, transparent ground',
    corner: null, band: null, period: 8, scale: 2,
    tiles: 'horizontally only; the last tile is clipped',
    master: 'raw/ui/rule_journal_b.png (pixen 96x32, job 6ce69c34)',
    recipe: { key: 'tools/rule-cut.js --key 0.09: the cream paper keyed to alpha 0, 95 px of ink kept', cut: 'rows 12-17, best-wrapping 8-wide window at x=64, join 0.917' },
    note: 'The paper is not the asset; the LINE is. A rule is drawn over whatever page material '
      + 'the screen already has.',
  }],
  ['out/ui/kit/rule_chart.png', {
    asset: 'rule_chart', kind: 'longitudinal rule tile with scale ticks, transparent ground',
    corner: null, band: null, period: 8, scale: 2,
    tiles: 'horizontally only; the last tile is clipped',
    master: 'raw/ui/rule_chart_b.png (pixen 96x32, job a3bee939)',
    recipe: { key: 'tools/rule-cut.js --key 0.16 --band 0.02: vellum keyed out, 119 px of ink kept', cut: 'rows 14-17 (the rule and the ticks standing on it), 8-wide window at x=16, join 0.000' },
  }],
  ['out/ui/kit/rail_shelf.png', {
    asset: 'rail_shelf', kind: 'picture-class rail, drawn once at x1 and clipped',
    corner: null, band: null, period: 384, scale: 1,
    master: 'raw/ui/rail_shelf_b.png (pixen 384x72, job 62529e80)',
    recipe: {
      clamp: 'tools/ceiling-clamp.js: 4 colours moved under the ceiling, linear-light rescale',
      crop: 'rows 17-48, the plank front only - the stone wall the model drew above and below it is not the shelf',
    },
  }],
  ['out/ui/kit/tab_plate.png', {
    asset: 'tab_plate', kind: 'discrete ornament, positioned by Flutter - NOT a nine-patch',
    corner: null, band: null, period: null, scale: 1,
    master: 'raw/ui/tab_plate_b.png (pixen 48x32, job d28d7cfa)',
    recipe: { crop: 'none needed; already under the ceiling at max #8C614A L=0.1462' },
    note: 'Measured band T/B/L/R 19/1/28/1 - wildly asymmetric, so it cannot carry one inset and '
      + 'cannot be a nine-patch (the FMPO02 banked_cartouche reject, same shape). It is a fixed '
      + 'index tab, which is the third thing DECISIONS/0029 allows a raster to be.',
  }],
]) {
  emit(R(file), png.loadAny(R(file)), { ...meta, destination: 'assets/ui/v1/kit/' + path.basename(file) });
}

// --- EPO03 batch 7: the second pro wave ------------------------------------
for (const [file, meta] of [
  ['out/ui/kit/btn_plate_v2.png', {
    asset: 'btn_plate_v2', kind: 'nine-patch button plate, drawn through PixelFrame',
    corner: 8, band: 5, period: null, scale: 2,
    master: 'raw/ui/pro_btn_1.png (create_image_pro, job 407e9549, candidate 1 of 4)',
    recipe: {
      key: 'the plate came back with a WHITE face, not a transparent one; every pixel over '
        + 'L 0.5 keyed to alpha 0 (deterministic, the keyBorderWhite operation). This turned '
        + 'three "solid plate" rejects into three usable frames.',
      crop: 'to content, 96x48 -> 56x24',
      geometry: 'MEASURED band 5/5/5/5, spread 0. Corner 8 not 5: ninepatch-proof.js shows the '
        + 'rounded corner clipped at 5 (review/ui/np_btn5.png vs np_btn8.png).',
    },
    note: 'Replaces btn_plate (58x26, corner 4 / band 0-declared-1) when StrideButton is '
      + 'repointed. Not yet wired: the button is on 43 call sites and that swap is its own change.',
  }],
  ['out/ui/kit/edge_spine.png', {
    asset: 'edge_spine', kind: 'longitudinal tile, repeated VERTICALLY down a page left edge',
    corner: null, band: null, period: 7, scale: 1,
    tiles: 'vertically only; the last tile is clipped',
    master: 'raw/ui/edge_spine_a.png (pixen 32x64, job 9901cfb5)',
    recipe: {
      period: 'measured from the binding cords: peaks at rows 1,7,13,20,26,32,38,45,51,57 -> '
        + 'gaps of 6 and 7; the 7-row window at row 51 wraps best (delta 7.10)',
      clamp: 'tools/ceiling-clamp.js, 1 colour',
    },
  }],
  ['out/ui/kit/ribbon_label.png', {
    asset: 'ribbon_label', kind: 'discrete ornament, positioned by Flutter - NOT a nine-patch',
    corner: null, band: null, period: null, scale: 1,
    master: 'raw/ui/pro_ribbon_2.png (create_image_pro, job a5f7d9f2, candidate 2 of 4)',
    note: 'A ribbon is a THREE-patch - fixed swallowtail ends with a tiling middle - and the '
      + 'painter only does nine-patches. Measured band 6/0/0/0: the left and right "bands" are '
      + 'the notches, which are transparent at mid-height, so it cannot carry one uniform inset. '
      + 'It ships at its authored 96x32 and holds a short label (a level, a rarity, a boss mark, '
      + 'a cost). A label wider than that needs a three-patch painter, which is a separate change.',
  }],
]) {
  emit(R(file), png.loadAny(R(file)), { ...meta, destination: 'assets/ui/v1/kit/' + path.basename(file) });
}
