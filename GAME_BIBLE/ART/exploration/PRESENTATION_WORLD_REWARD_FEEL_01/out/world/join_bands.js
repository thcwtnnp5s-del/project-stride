// Assembles the three-band continent, once, into atlas_master_688x864.png.
// Deterministic: no randomness, no averaging, no invented pixels — every
// output pixel is a pixel from one of the three paintings (RULES.md A-2).
const png = require(process.cwd() + '/Scripts/art/png.js');
const D = 'GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/world/';

const north = png.load(D + 'band_north_0.png');
const master = png.load(D + 'atlas_master_688x384.png');
const south = png.load(D + 'band_south_0.png');

const NORTH_SRC_TOP = 96;
const N_TOP = 0, M_TOP = 256, S_TOP = 608;
const HEIGHT = S_TOP + 256;   // 864

const out = new png.Raster(688, HEIGHT);
const place = (src, srcTop, dstTop, rows) =>
  png.blit(out, png.crop(src, 0, srcTop, 688, rows), 0, dstTop);

place(north, NORTH_SRC_TOP, N_TOP, 288);
place(master, 0, M_TOP, 384);
place(south, 0, S_TOP, 256);

/// A deterministic wobble: three summed sines with fixed, mutually prime
/// periods. Not noise — the same every build — and not a straight line,
/// which is the only thing wrong with butting two paintings together.
///
/// An ordered dither was tried first and was worse: across two terrains of
/// different value it reads as a chequered stripe, which is a texture no
/// painter drew (M-12).
function boundary(x, seam, amp) {
  const w =
    Math.sin(x / 37.0) + Math.sin(x / 17.3 + 1.1) + Math.sin(x / 7.1 + 2.3);
  return Math.round(seam + (amp * w) / 3);
}

/// Re-lays the upper painting down to its own wobbling boundary, so the join
/// follows a coastline-ish line instead of a ruler.
function wobble(upper, upperSrcTop, upperDstTop, seam, amp) {
  for (let x = 0; x < 688; x++) {
    const edge = boundary(x, seam, amp);
    for (let y = seam - amp; y < edge; y++) {
      const sy = upperSrcTop + (y - upperDstTop);
      if (y < 0 || y >= HEIGHT || sy < 0 || sy >= upper.height) continue;
      const si = upper.idx(x, sy);
      upper.data.copy(out.data, out.idx(x, y), si, si + 4);
    }
  }
}
wobble(north, NORTH_SRC_TOP, N_TOP, M_TOP, 20);
wobble(master, 0, M_TOP, S_TOP, 26);

png.save(D + 'atlas_master_688x864.png', out);
console.log(`joined 688x${HEIGHT}`);
