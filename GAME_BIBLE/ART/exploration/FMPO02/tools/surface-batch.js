// surface-batch.js — the accepted surface recipe, one row per material.
//
// Every accepted tile is reproducible from this table plus the raw master in
// raw/ui/surface/. The table IS the record: master, flatten radius, grain depth,
// ramp target, window size. Nothing else varies.
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const { SURFACE } = require('./ramps.js');

// material : [master suffix, flatten radius, grain depth (ramp rungs), ramp target]
const RECIPE = {
  journal_leaf: ['a', 4, 2, 1],
  leather:      ['d', 4, 2, 1],
  steel:        ['b', 4, 2, 1],
  oilcloth:     ['a', 4, 2, 1],
  buckram:      ['a', 4, 2, 1],
  bench_oak:    ['d', 4, 2, 1],
  slate:        ['a', 4, 2, 1],
  // chart_vellum never produced grain: four masters, the best of them 99.4% one
  // ink. 'f' (burlap) DID carry texture and its texture read as BRICKWORK when
  // tiled, which is worse than flat. 'e' ships: it carries the family's interior
  // hue and no grain, and the report says so rather than pretending otherwise.
  chart_vellum: ['e', 4, 2, 1],
  // cork's master flecks upward: at target 1 its second ink is the MID, 6.83 L*
  // away, which is a reject. 0.9 drops the level by a tenth of a rung and the
  // grain sits on shadow+base like every other family. Recorded, not hidden.
  cork:         ['c', 4, 2, 0.9],
  plan_linen:   ['c', 4, 2, 1],
};

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'out/ui/surface');
fs.mkdirSync(outDir, { recursive: true });

for (const [m, [v, radius, depth, target]] of Object.entries(RECIPE)) {
  const src = path.join(root, 'raw/ui/surface/' + m + '_' + v + '.png');
  const out = path.join(outDir, 'grain_' + m + '.png');
  let log = '';
  try {
  log = execFileSync('node', [
    path.join(__dirname, 'surface.js'), src, '--ramp', m, '--out', out,
    '--flatten', String(radius), '--depth', String(depth), '--target', String(target),
    '--align', '--cut', '--pick', '--quad', '32',
  ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) { log = String(e.stdout || ''); }
  const verdict = (log.match(/verdict\s+(.*)/) || [])[1] || '?';
  const hist = (log.match(/two most used\s+(.*)/) || [])[1] || '';
  const cut = (log.match(/cut\s+(.*)/) || [])[1] || '';
  const tile = png.loadAny(out);

  fs.writeFileSync(out.replace(/\.png$/, '.json'), JSON.stringify({
    asset: 'grain_' + m,
    destination: 'assets/ui/v1/surface/grain_' + m + '.png',
    canvas: [tile.width, tile.height],
    kind: 'interior surface tile',
    corner: null,
    band: null,
    period: tile.width,
    scale: 2,
    tiles: 'both axes, from the interior rect top-left, last row/column clipped never rescaled',
    alpha: 'fully opaque, no alpha channel content',
    ramp: SURFACE[m],
    master: 'raw/ui/surface/' + m + '_' + v + '.png',
    recipe: { flattenRadius: radius, grainDepthRungs: depth, rampTarget: target, window: 32, method: 'cut, no mirror' },
    note: 'Geometry measured from the asset. A surface has no corner and no band: '
      + 'PanelSkin insets by the FRAME band, and this tile is clipped to that interior.',
  }, null, 2) + '\n');

  console.log(m.padEnd(14) + tile.width + 'x' + tile.height + '  ' + verdict);
  console.log('  ' + hist);
  console.log('  ' + cut);
}
