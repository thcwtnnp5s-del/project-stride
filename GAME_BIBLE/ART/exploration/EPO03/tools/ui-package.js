// ui-package.js — the last deterministic pass: everything that survived its
// blind read, cut to its shipped canvas, with a sidecar declaring the geometry
// the integrator needs and nothing it has to guess.
'use strict';
const { execFileSync } = require('child_process');
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
  return {
    teal, semi, over, colours: cols.size, maxHex, maxL: Number(maxL.toFixed(4)),
    verdict: teal + semi + over === 0 ? 'clean' : 'VIOLATION',
  };
}

function emit(outPath, raster, meta) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  png.save(outPath, raster);
  fs.writeFileSync(outPath.replace(/\.png$/, '.json'),
    JSON.stringify({ ...meta, canvas: [raster.width, raster.height], guards: guards(raster) }, null, 2) + '\n');
  const g = guards(raster);
  console.log(path.relative(root, outPath).padEnd(40) + raster.width + 'x' + raster.height
    + '  ' + g.colours + ' colours  max ' + g.maxHex + '  ' + g.verdict);
}

// --- buttons ---------------------------------------------------------------
// plate_c and compact_a won their reads; btn-prep already wrote the plate and
// every register beside it. Copy the two winners to their shipped names and
// declare the geometry MEASURED off them (production plan 3.2.1: PanelSkin
// insets by `band`, never by `corner`).
for (const [src, name, corner, band] of [
  ['out/ui/button/plate_a/plate_a.png', 'btn_plate', 4, 0],
  ['out/ui/button/compact_a/compact_a.png', 'btn_compact', 5, 2],
]) {
  const r = png.loadAny(R(src));
  emit(R('out/ui/button/' + name + '.png'), r, {
    asset: name,
    destination: 'assets/ui/v1/button/' + name + '.png',
    kind: 'nine-patch button plate, drawn through PixelFrame',
    corner,
    band,
    period: null,
    scale: 2,
    ramp: 'leather_primary #241F18 #3A332B #4A4034 #6B5A3E',
    states: 'NONE authored. Every register and both states are index remaps of this '
      + 'one plate (DECISIONS/0029) - see out/ui/button/<candidate>/<name>__*.png.',
    measuredAgainstBrief: 'ART-02 asked for corner 8 / band 4 (btn_plate) and corner 6 / band 3 '
      + '(btn_compact). The model drew a thinner rim than that on every candidate and the '
      + 'numbers above are what it actually drew. Declaring the brief instead of the asset is '
      + 'the exact defect production plan 3.2.1 exists to prevent.',
    master: src,
  });
}

// --- nav welt and header shelf --------------------------------------------
emit(R('out/ui/nav/nav_welt.png'), png.loadAny(R('out/ui/nav/nav_welt.png')), {
  asset: 'nav_welt',
  destination: 'assets/ui/v1/nav/nav_welt.png',
  kind: 'longitudinal tile, repeated along the top edge of the 64dp nav bar',
  corner: null,
  band: null,
  period: 8,
  scale: 2,
  tiles: 'horizontally only; the last tile is clipped, never rescaled',
  master: 'raw/ui/nav/welt_a.png',
});
emit(R('out/ui/header/header_shelf.png'), png.loadAny(R('out/ui/header/header_shelf.png')), {
  asset: 'header_shelf',
  destination: 'assets/ui/v1/header/header_shelf.png',
  kind: 'longitudinal tile, repeated along the header bottom edge in place of the 1px separator',
  corner: null,
  band: null,
  period: 8,
  scale: 2,
  tiles: 'horizontally only; the last tile is clipped, never rescaled',
  master: 'raw/ui/hdr/shelf_a.png',
});

// --- rule ornament ---------------------------------------------------------
// One 64x16 plate carries both ends and the run, authored in one roll so the key
// light stays upper-left on every piece (ART-02 ORN; mirroring is refused).
{
  const plate = png.loadAny(R('raw/ui/orn/rule_plate_b.png'));
  emit(R('out/ui/ornament/rule_plate_64x16.png'), plate, {
    asset: 'rule_plate_64x16',
    destination: 'assets/ui/v1/ornament/rule_plate_64x16.png',
    kind: 'ornament plate carrying both rule caps and the tileable run',
    corner: null,
    band: null,
    period: 8,
    scale: 2,
    cuts: {
      rule_cap_left: [1, 1, 12, 14],
      rule_cap_right: [51, 1, 12, 14],
      rule_run: 'the best-wrapping 8x4 window inside x 14..50, cut by tools/tile-cut.js',
    },
    note: 'Ships whole. Flutter positions the caps once each and tiles the run between them; '
      + 'nothing here is mirrored.',
    master: 'raw/ui/orn/rule_plate_b.png',
  });
  const capL = png.crop(plate, 1, 1, 12, 14);
  const capR = png.crop(plate, 51, 1, 12, 14);
  emit(R('out/ui/ornament/rule_cap_left.png'), capL, {
    asset: 'rule_cap_left', destination: 'assets/ui/v1/ornament/rule_cap_left.png',
    kind: 'discrete ornament, positioned by Flutter', corner: null, band: null, scale: 2,
    master: 'raw/ui/orn/rule_plate_b.png (cut 1,1,12,14)',
  });
  emit(R('out/ui/ornament/rule_cap_right.png'), capR, {
    asset: 'rule_cap_right', destination: 'assets/ui/v1/ornament/rule_cap_right.png',
    kind: 'discrete ornament, positioned by Flutter', corner: null, band: null, scale: 2,
    note: 'Authored, not mirrored from the left cap - a mirror flips the key light to the '
      + 'upper right (production plan 3.4).',
    master: 'raw/ui/orn/rule_plate_b.png (cut 51,1,12,14)',
  });
  // The rule body is a thin strip inside a 16-tall canvas, so crop it to its own
  // opaque rows before looking for a run: a window that straddles the transparent
  // surround is not a tile.
  let ry0 = 14; let ry1 = 1;
  for (let y = 1; y < 15; y += 1) { let solid = true; for (let x = 14; x < 50; x += 1) if (P(plate, x, y)[3] !== 255) { solid = false; break; } if (solid) { if (y < ry0) ry0 = y; if (y > ry1) ry1 = y; } }
  const mid = png.crop(plate, 14, ry0, 36, Math.max(4, ry1 - ry0 + 1));
  fs.mkdirSync(R('out/ui/ornament'), { recursive: true });
  png.save(R('out/ui/ornament/_rule_mid.png'), mid);
  let runOk = true;
  try {
  execFileSync('node', [path.join(__dirname, 'tile-cut.js'), R('out/ui/ornament/_rule_mid.png'),
    '--w', '8', '--h', String(Math.min(4, mid.height)), '--out', R('out/ui/ornament/rule_run.png')], { stdio: 'ignore' });
  } catch (e) { runOk = false; }
  fs.unlinkSync(R('out/ui/ornament/_rule_mid.png'));
  if (!runOk) console.log('rule_run'.padEnd(40) + 'NOT EXTRACTABLE - no fully opaque 8x' + Math.min(4, mid.height) + ' window in the rule body');
  if (runOk)
  emit(R('out/ui/ornament/rule_run.png'), png.loadAny(R('out/ui/ornament/rule_run.png')), {
    asset: 'rule_run', destination: 'assets/ui/v1/ornament/rule_run.png',
    kind: 'longitudinal tile, repeated between the two caps',
    corner: null, band: null, period: 8, scale: 2,
    master: 'raw/ui/orn/rule_plate_b.png (best-wrapping 8x4 window in the run)',
  });
}

// --- craft backdrop --------------------------------------------------------
emit(R('out/ui/bg/bg_workbench.png'), png.loadAny(R('raw/ui/bg/workbench_a.png')), {
  asset: 'bg_workbench',
  destination: 'assets/ui/v1/bg/bg_workbench.png',
  kind: 'picture-class backdrop, drawn once at x1 behind everything and scrimmed',
  corner: null,
  band: null,
  scale: 1,
  note: 'Scrim-ready and deliberately unlit: no fire, no forge, no figures, no stall. '
    + 'It is a backplate, not a screen (production plan 11).',
  master: 'raw/ui/bg/workbench_a.png',
});

// --- nav glyphs ------------------------------------------------------------
// Shipped as CANDIDATES. See the report: re-materialising these into the chassis
// ramp costs legibility at 14px and weakens the active signal, and world_hi is a
// hard reject.
for (const g of ['adventure', 'adventure_hi', 'character', 'character_hi', 'skills', 'skills_hi',
  'inventory', 'inventory_hi', 'craft', 'craft_hi', 'world']) {
  const p = R('out/ui/nav/nav_' + g + '.png');
  if (!fs.existsSync(p)) continue;
  emit(p, png.loadAny(p), {
    asset: 'nav_' + g,
    destination: 'assets/ui/v1/nav_' + g + '.png',
    kind: 'nav glyph, 14 native at x2',
    corner: null, band: null, scale: 2,
    status: 'CANDIDATE - not recommended for swap without a device read (see UI_report.md)',
    master: 'raw/ui/nav/' + g + '.png (pixen 16x16, cropped to content, centred in 14x14, '
      + 'remapped onto the measured chassis_64 ramp)',
  });
}
