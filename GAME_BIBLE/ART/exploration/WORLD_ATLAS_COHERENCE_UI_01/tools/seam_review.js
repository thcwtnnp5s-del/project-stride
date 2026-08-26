// Seam-review preflight artifact generator (MISTAKES.md M-14, RULES.md A-3).
//
// Human visual review is the authority — this tool does NOT score anything. It
// makes review hard to forget by emitting, from the SHIPPED atlas, one crop per
// generation boundary at roughly the size a player sees it on an iPhone, plus a
// single contact sheet of every join. Run it before any World device pass and
// look at each cell: no cell may show a straight generated rectangle.
//
// iPhone scale: the layout draws the atlas at scale 6, opening zoom 2/6 = 1/3,
// so 1 atlas px ≈ 2 logical dp; a ~196 dp-wide phone column is ~98 atlas px.
// Crops are taken a little wider than that and upscaled ×2 for a dp-accurate
// read, so a seam that vanishes here vanishes on the phone.
//
// Usage: node seam_review.js [atlas_base.png] [outDir]
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const atlasFile = process.argv[2] ||
  path.join(__dirname, '..', '..', '..', '..', '..', 'assets', 'art', 'v1', 'world', 'atlas_base.png');
const outDir = process.argv[3] || path.join(__dirname, '..', 'out', 'review', 'seams');
fs.mkdirSync(outDir, { recursive: true });

const atlas = png.load(atlasFile);
const W = 120; // atlas px per cell (≈ a phone column plus margin)
const H = 120;

// Every generation boundary, by the coordinate the compositor joins on. Named
// so the contact-sheet index below reads back to a place on the map.
const JOINS = [
  ['n_ice_wall_x512', 512, 128],
  ['n_comb_w_y128', 320, 128],
  ['n_comb_e_y128', 704, 128],
  ['n_master_top_c', 512, 256],
  ['ne_skerries', 832, 176],
  ['nw_corner', 160, 160],
  ['w_worldspine_x128', 128, 448],
  ['w_master_x256', 256, 512],
  ['e_master_x768', 768, 512],
  ['e_far_x896', 896, 512],
  ['volcano_coast', 736, 400],
  ['sw_block_y640', 128, 640],
  ['s_master_y768', 512, 768],
  ['s_delta_e', 660, 768],
  ['se_corner', 832, 832],
  ['s_outer_y896', 512, 896],
];

// The 12 authored bridges, by footprint [name, x, y, w, h]. A bridge can remove
// the original seam and still leave its OWN rectangular footprint visible if its
// interior differs from the surrounding terrain (MISTAKES.md M-14, the
// repair-crop-perimeter lesson). This emits each footprint with a margin of
// surrounding terrain so a reviewer can ask: could I infer this rectangle?
const BRIDGES = [
  ['north_west', 0, 0, 288, 288],
  ['north_center', 256, 0, 512, 288],
  ['north_east', 768, 0, 256, 288],
  ['north_master', 256, 224, 512, 80],
  ['nw_corner', 80, 80, 220, 220],
  ['north_junction', 256, 188, 512, 84],
  ['north_mtop', 300, 232, 420, 96],
  ['west_mid', 48, 256, 256, 512],
  ['east_x768', 640, 256, 256, 512],
  ['sw', 0, 592, 272, 304],
  ['south', 256, 720, 512, 128],
  ['se', 704, 704, 192, 192],
];
const perimDir = path.join(outDir, 'bridges');
fs.mkdirSync(perimDir, { recursive: true });
const M = 40; // margin of surrounding terrain around each footprint
for (const [name, bx, by, bw, bh] of BRIDGES) {
  const x = Math.max(0, bx - M);
  const y = Math.max(0, by - M);
  const w = Math.min(atlas.width - x, bw + 2 * M);
  const h = Math.min(atlas.height - y, bh + 2 * M);
  // Scale so the long side is ~ 520 px for a legible perimeter read.
  const s = Math.max(1, Math.round(520 / Math.max(w, h)));
  png.save(path.join(perimDir, `${name}.png`), png.scale(png.crop(atlas, x, y, w, h), s));
}
console.log(`seam_review: ${BRIDGES.length} bridge footprints+margin -> ${perimDir}`);

const cells = [];
for (const [name, cx, cy] of JOINS) {
  const x = Math.max(0, Math.min(atlas.width - W, cx - (W >> 1)));
  const y = Math.max(0, Math.min(atlas.height - H, cy - (H >> 1)));
  const crop = png.crop(atlas, x, y, W, H);
  png.save(path.join(outDir, `${name}.png`), png.scale(crop, 2));
  cells.push(crop);
}

// Contact sheet: 4 columns, ×2 upscale, 1 cell gap.
const cols = 4;
const rows = Math.ceil(cells.length / cols);
const gap = 4;
const sheet = new png.Raster(
  cols * W * 2 + (cols + 1) * gap,
  rows * H * 2 + (rows + 1) * gap,
);
png.fill(sheet, [20, 18, 15, 255]);
cells.forEach((crop, i) => {
  const r = Math.floor(i / cols);
  const c = i % cols;
  const dx = gap + c * (W * 2 + gap);
  const dy = gap + r * (H * 2 + gap);
  png.blit(sheet, png.scale(crop, 2), dx, dy);
});
png.save(path.join(outDir, 'contact_sheet.png'), sheet);

console.log(`seam_review: ${cells.length} boundary crops + contact_sheet.png -> ${outDir}`);
JOINS.forEach(([name], i) =>
  console.log(`  cell ${Math.floor(i / cols)},${i % cols}: ${name}`));
