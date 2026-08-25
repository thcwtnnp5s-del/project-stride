// Compose the full 1024 x 1024 expanded base: the corrected inner ring and
// master (as in compose_preview.js, offset +128) surrounded by this round's
// second frontier ring. Same deterministic dither crossfade, now at seams
// {128, 256, 768, 896} on both axes. Preview for review; the shipping
// composition lands in Scripts/art/package-art.js.
//
// Usage: node compose_1024.js <out.png>
'use strict';
const path = require('path');
const REPO = path.join(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const WMP03 = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'WORLD_MAP_POLISH_03', 'out', 'world');
const R2 = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'WORLD_MAP_EXPANSION_REFINEMENT_02', 'out', 'world');
const MASTER = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'PRESENTATION_WORLD_REWARD_FEEL_01', 'out', 'world', 'whole_a_0.png');

const load = (dir, name, w, h) => {
  const r = png.load(path.join(dir, `${name}.png`));
  if (r.width !== w || r.height !== h) throw new Error(`${name}: ${r.width}x${r.height}, want ${w}x${h}`);
  return r;
};

const base = new png.Raster(1024, 1024);

// Outer ring (this round).
png.blit(base, load(R2, 'r2_corner_nw_f0', 128, 128), 0, 0);
png.blit(base, load(R2, 'r2_north_w_f0', 384, 128), 128, 0);
png.blit(base, load(R2, 'r2_north_e_f0', 384, 128), 512, 0);
png.blit(base, load(R2, 'r2_corner_ne_f0', 128, 128), 896, 0);
png.blit(base, load(R2, 'r2_west_n_f0', 128, 512), 0, 128);
png.blit(base, load(R2, 'r2_west_s_f0', 128, 256), 0, 640);
png.blit(base, load(R2, 'r2_east_n_f0', 128, 384), 896, 128);
png.blit(base, load(R2, 'r2_east_s_f0', 128, 384), 896, 512);
png.blit(base, load(R2, 'r2_corner_sw_f0', 128, 128), 0, 896);
png.blit(base, load(R2, 'r2_south_w_f0', 384, 128), 128, 896);
png.blit(base, load(R2, 'r2_south_e_f0', 384, 128), 512, 896);
png.blit(base, load(R2, 'r2_corner_se_f0', 128, 128), 896, 896);

// Inner ring (WMP03 retained + this round's replacements), offset +128.
png.blit(base, load(WMP03, 'corner_nw_128', 128, 128), 128, 128);
png.blit(base, load(WMP03, 'strip_north_512x128', 512, 128), 256, 128);
png.blit(base, load(R2, 'corner_ne_conformed_v2', 128, 128), 768, 128);
png.blit(base, load(R2, 'cand_strip_west_f0', 128, 512), 128, 256);
png.blit(base, load(R2, 'cand_strip_east_f0', 128, 512), 768, 256);
// WMP03's corner_sw carries a 1px white border on its left column and bottom
// row — invisible while those edges were the 768 canvas boundary, exposed now
// that they are interior joins. Replicate the adjacent line over each.
const cornerSW = load(WMP03, 'corner_sw_128', 128, 128);
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
png.blit(base, load(WMP03, 'strip_south_512x128', 512, 128), 256, 768);
png.blit(base, load(R2, 'cand_corner_se_f3', 128, 128), 768, 768);
png.blit(base, png.load(MASTER), 256, 256);

// In-place static patches (768-frame coords +128).
const patch = (name, w, h, x, y) => png.blit(base, load(R2, name, w, h), x + 128, y + 128);
patch('northfix2_edit_f0', 128, 128, 512, 0);
patch('eaststriptop_edit_f0', 128, 64, 640, 128);
patch('corridor_edit_f0', 128, 75, 128, 355);
patch('southjoin_edit_f0', 256, 60, 60, 610);
patch('roadjoin_edit_f0', 104, 72, 88, 352);

// Dither crossfade at every seam.
const before = base.clone();
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};
const BAND = 11;
const chance = (d) => 0.45 * (1 - (d - 1) / BAND);
const swap = (ax, ay, bx, by) => {
  const ai = base.idx(ax, ay);
  const bi = before.idx(bx, by);
  for (let k = 0; k < 4; k++) base.data[ai + k] = before.data[bi + k];
};
for (const seamY of [128, 256, 768, 896]) {
  for (let x = 0; x < 1024; x++) {
    for (let d = 1; d <= BAND; d++) {
      const pr = chance(d);
      if (hash(x, seamY - d, 1) < pr) swap(x, seamY - d, x, seamY + d - 1);
      if (hash(x, seamY + d - 1, 2) < pr) swap(x, seamY + d - 1, x, seamY - d);
    }
  }
}
for (const seamX of [128, 256, 768, 896]) {
  for (let y = 0; y < 1024; y++) {
    for (let d = 1; d <= BAND; d++) {
      const pr = chance(d);
      if (hash(seamX - d, y, 3) < pr) swap(seamX - d, y, seamX + d - 1, y);
      if (hash(seamX + d - 1, y, 4) < pr) swap(seamX + d - 1, y, seamX - d, y);
    }
  }
}
png.save(process.argv[2], base);
console.log('wrote', process.argv[2]);
