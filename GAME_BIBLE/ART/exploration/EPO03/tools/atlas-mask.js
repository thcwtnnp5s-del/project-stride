// FMPO02 — deterministic graded authorization mask builder for atlas regions.
//
// Produces the grayscale mask that `package-art.js`'s FMPO02_ATLAS_REGIONS
// block reads: red channel 255 = take the region generation, 0 = keep the
// base composite, anything between = hash dither-SELECT probability (A-2 —
// every output pixel is one of the two approved images' own pixels; nothing
// is ever averaged).
//
// Boundary authoring rules (ART-03 §3, the rule M-12/M-14 died on):
//   * 24 px alpha ramp on a free edge, 32 px where the boundary crosses a
//     texture change (canopy/meadow, snow/rock, sand/sward);
//   * each ramp is one-sided from the authored rect edge and its WIDTH is
//     hash-jittered ±60% by a low-frequency value noise, so the half-alpha
//     contour wanders ±10 px and no straight lattice line exists anywhere;
//   * alpha is forced to 0 within 20 px of any registered landmark golden,
//     and inside the A-4 frozen core deeper than its 20 px rim.
//
// Everything here is a pure function of (region geometry, salt) — no
// randomness, no image content — so the mask a review saw is the mask that
// ships.
'use strict';

const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..',
  'Scripts', 'art', 'png.js'));

// Same integer hash as package-art.js, so the mask and the compositor agree.
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};

// A-4 frozen core and its writable rim (package-art.js `PROT`).
const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 };
const protDepth = (x, y) => {
  if (x < PROT.x0 || x >= PROT.x1 || y < PROT.y0 || y >= PROT.y1) return 0;
  return Math.min(x - PROT.x0, y - PROT.y0, PROT.x1 - 1 - x, PROT.y1 - 1 - y) + 1;
};

// The 15 byte-enforced landmark goldens (ART-03 §1 / landmark_registry.json).
const GOLDENS = [
  ['frostmere_north_wall', 400, 256, 160, 20],
  ['east_watchtower_flank', 744, 273, 8, 50],
  ['volcano_east_cliff', 752, 260, 72, 210],
  ['roadjoin_corridor_west', 216, 480, 60, 78],
  ['west_caravan_road', 128, 495, 128, 80],
  ['caravan_corridor', 199, 506, 46, 26],
  ['stag_box', 156, 493, 28, 22],
  ['flock_south', 456, 748, 64, 27],
  ['south_strand_w', 128, 810, 400, 60],
  ['south_strand_e', 512, 810, 288, 60],
  ['wanderers_isles_w', 785, 490, 80, 47],
  ['wanderers_isles_e', 920, 503, 85, 34],
  ['cinder_skerries', 920, 175, 80, 75],
  ['far_isles', 940, 205, 55, 80],
  ['ne_iceberg', 974, 210, 17, 15],
];
const GOLDEN_KEEPOUT = 20;
const GOLDEN_RAMP = 24;

/**
 * Authorization factor in [0,1] imposed by the protected zones.
 *
 * Zero inside the A-4 core beyond its rim, and zero within 20 px of any
 * landmark golden — but the golden keepout then RAMPS back to full over a
 * further 24 px instead of stepping. A hard step would draw the golden's own
 * rectangle into the mask, which is precisely the artefact this round exists
 * to remove (M-14): the keepout must protect the feature without printing its
 * outline onto the terrain around it.
 */
function protectFactor(tx, ty, rimBlock) {
  const d = protDepth(tx, ty);
  if (d > PROT.band) return 0;
  // `rimBlock` refuses the writable A-4 rim as well. The rim is writable, but
  // package-art.js's own `keepRepair` hash-dither runs there unconditionally,
  // keeping a repair pixel with probability 1 - depth/21 — so a region that
  // writes the rim is composited roughly half-and-half with the old master
  // whatever its own mask says. Where the region and the master are different
  // terrain that reads as a speckled column (measured on W1: 1697 gen vs 1946
  // base pixels across 256..276). The guard is not the thing to change
  // (G-4); the region is. Regions whose edge would otherwise land in the rim
  // set this and stop at the core wall.
  if (rimBlock && d > 0) return 0;
  let f = 1;
  for (const [, gx, gy, gw, gh] of GOLDENS) {
    const dx = Math.max(gx - tx, tx - (gx + gw - 1), 0);
    const dy = Math.max(gy - ty, ty - (gy + gh - 1), 0);
    const d = Math.max(dx, dy);
    const g = Math.max(0, Math.min(1, (d - GOLDEN_KEEPOUT) / GOLDEN_RAMP));
    if (g < f) f = g;
    if (f === 0) return 0;
  }
  return f;
}

/** True where a mask pixel may never be authorized at all. */
function forbidden(tx, ty, rimBlock) {
  return protectFactor(tx, ty, rimBlock) === 0;
}

// Low-frequency value noise in [-1,1] along one axis: hash per 24 px cell,
// linearly interpolated, so the jittered midline wanders instead of buzzing.
const CELL = 24;
function wander(i, salt) {
  const c = Math.floor(i / CELL);
  const t = (i - c * CELL) / CELL;
  const a = hash(c, salt * 7 + 1, salt) * 2 - 1;
  const b = hash(c + 1, salt * 7 + 1, salt) * 2 - 1;
  const s = t * t * (3 - 2 * t);
  return a + (b - a) * s;
}

/**
 * Local dissimilarity between the generation and the base crop: mean absolute
 * RGB difference over a 5×5 box, per pixel.
 *
 * A dither ramp mixes two images by SELECTING whole pixels from each. Where
 * the two agree — meadow against meadow — that reads as texture and the
 * boundary disappears, which is the whole point. Where they disagree — a new
 * meadow bay against the old canopy wall — a 50/50 selection reads as
 * salt-and-pepper: exactly the "dither column" ART-03 §7.3 rejects, and the
 * artefact four previous passes shipped (M-14).
 *
 * So the ramp is graded by agreement, below.
 */
function dissimilarity(gen, src, w, h) {
  const raw = new Float32Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = gen.idx(x, y);
      raw[y * w + x] = (Math.abs(gen.data[i] - src.data[i]) +
        Math.abs(gen.data[i + 1] - src.data[i + 1]) +
        Math.abs(gen.data[i + 2] - src.data[i + 2])) / 3;
    }
  }
  const out = new Float32Array(w * h);
  const R = 2;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let s = 0, n = 0;
      for (let dy = -R; dy <= R; dy++) {
        const yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (let dx = -R; dx <= R; dx++) {
          const xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          s += raw[yy * w + xx]; n++;
        }
      }
      out[y * w + x] = s / n;
    }
  }
  return out;
}

// Below AGREE_LO the two images are the same terrain and the ramp dithers
// freely; above AGREE_HI they are different terrain and the ramp commits
// wholly to one side, so the join is drawn as an edge instead of sprayed as
// noise. The commit contour is the jittered midline itself, which wanders
// ±10 px and is never straight — a treeline, not a lattice.
const AGREE_LO = 12;
const AGREE_HI = 45;

/**
 * Build one region mask.
 *
 * @param {object} spec
 *   w,h        mask (and generation) size — the crop size
 *   ox,oy      crop origin on the 1024² atlas
 *   rect       {x0,y0,x1,y1} authored rect in CROP coords (half-open)
 *   ramps      {left,right,top,bottom} ramp width px (24 free / 32 texture)
 *   jitter     max midline wander px (default 10)
 *   salt       hash salt, unique per region
 *   gen,src    optional rasters; when both are given the ramp is graded by
 *              local agreement as described above
 * @returns {{raster: object, stats: object}}
 */
function buildMask(spec) {
  const { w, h, ox, oy, rect, ramps, salt } = spec;
  const rimBlock = spec.rimBlock === true;
  const jitter = spec.jitter ?? 10;
  const diff = (spec.gen && spec.src)
    ? dissimilarity(spec.gen, spec.src, w, h) : null;
  const out = new png.Raster(w, h);
  let authorized = 0;
  let feathered = 0;
  let blocked = 0;

  for (let sy = 0; sy < h; sy++) {
    for (let sx = 0; sx < w; sx++) {
      const tx = ox + sx, ty = oy + sy;
      let m = 0;
      const inside = tx >= 0 && ty >= 0 && tx < 1024 && ty < 1024;
      const pf = inside ? protectFactor(tx, ty, rimBlock) : 0;
      if (pf > 0) {
        // Each ramp is ONE-SIDED and anchored exactly on the authored rect
        // edge, which is the inpaint rectangle's own edge: alpha is 0 there
        // and rises inward. A symmetric ramp on a jittered midline cannot
        // work here, because the midline's wander can only ever move the
        // visible boundary further INSIDE the generation — never outside it,
        // where there is nothing to move into. Half the columns therefore fell
        // back to the inpaint's own hard cut and the join read as a razor
        // straight line (seen on W2 roll 1, atlas y=258, ~175 px long).
        //
        // The wander is applied to each ramp's WIDTH instead (±60%), so the
        // half-alpha contour still wanders ±10 px, but it is always strictly
        // inside authored terrain. Each edge draws its wander from its own
        // salt, so the four boundaries never share a phase and no corner
        // reads as square.
        const t = (d, r, wob) => {
          if (r <= 0) return d >= 0 ? 1 : 0;
          const rr = r * (1 + 0.6 * wob);
          return Math.max(0, Math.min(1, d / rr));
        };
        let a = Math.min(
          t(sx - rect.x0, ramps.left, wander(sy, salt + 0)),
          t(rect.x1 - 1 - sx, ramps.right, wander(sy, salt + 1)),
          t(sy - rect.y0, ramps.top, wander(sx, salt + 2)),
          t(rect.y1 - 1 - sy, ramps.bottom, wander(sx, salt + 3)),
        );
        if (diff) {
          // Commit strength: 0 where the two images agree (dither freely),
          // 1 where they differ (snap to whichever side the ramp already
          // favours, so no mixed pixels are produced).
          const dv = diff[sy * w + sx];
          const c = Math.max(0, Math.min(1, (dv - AGREE_LO) / (AGREE_HI - AGREE_LO)));
          a = a >= 0.5 ? a + (1 - a) * c : a * (1 - c);
        }
        m = Math.round(a * pf * 255);
      }
      if (inside && pf === 0) blocked++;
      if (m === 255) authorized++;
      else if (m > 0) feathered++;
      const i = out.idx(sx, sy);
      out.data[i] = m; out.data[i + 1] = m; out.data[i + 2] = m;
      out.data[i + 3] = 255;
    }
  }
  return { raster: out, stats: { authorized, feathered, blocked } };
}

module.exports = { buildMask, forbidden, protDepth, PROT, GOLDENS, hash };

// CLI: node atlas-mask.js <regionId> — reads regions.json, writes the mask.
if (require.main === module) {
  const fs = require('fs');
  const ROOT = path.join(__dirname, '..');
  const id = process.argv[2];
  const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', 'regions.json'), 'utf8'));
  const region = cfg.regions.find((r) => r.id === id);
  if (!region) throw new Error(`unknown region ${id}`);
  // Grade by agreement once the generation exists; before that (mask preview)
  // fall back to the purely geometric ramp.
  const genPath = path.join(ROOT, 'out', 'atlas', `${id}.png`);
  const srcPath = path.join(ROOT, 'src', 'atlas', `${id}_crop.png`);
  const graded = fs.existsSync(genPath) && fs.existsSync(srcPath);
  const { raster, stats } = buildMask({
    w: region.w, h: region.h, ox: region.x, oy: region.y,
    rect: region.rect, ramps: region.ramps, salt: region.salt,
    rimBlock: region.rimBlock === true,
    gen: graded ? png.load(genPath) : null,
    src: graded ? png.load(srcPath) : null,
  });
  if (!graded) console.log('  (geometric ramp only — no generation on disk yet)');
  const dest = path.join(ROOT, 'out', 'atlas', `${id}_mask.png`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  png.save(dest, raster);
  console.log(`${id} mask ${region.w}x${region.h} -> ${dest}`, JSON.stringify(stats));
}
