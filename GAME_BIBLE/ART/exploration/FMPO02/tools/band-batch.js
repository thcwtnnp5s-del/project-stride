// band-batch.js — the accepted band selection, one row per family.
// master : the 384x96 candidate that won its blind read.
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const PICK = {
  band_forge: ['forge_96', null],
  band_cookfire: ['cookfire_a', null],
  band_bench: ['bench_b', null],
  band_foraging: ['foraging_b', null],
  band_mining: ['mining_c', null],
  band_world_chart: ['world_chart_b', null],
  band_encounter_ground: ['encounter_ground_c', null],
  band_adventure_trail: ['adventure_trail_b', null],
  band_combat_kit: ['combat_kit_b', null],
  band_boards_batten: ['boards_batten_b', null],
};

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'out/ui/band');
fs.mkdirSync(outDir, { recursive: true });

for (const [name, [master, row]] of Object.entries(PICK)) {
  const src = path.join(root, 'raw/ui/band/' + master + '.png');
  const out = path.join(outDir, name + '.png');
  const argv = [path.join(__dirname, 'band.js'), src, '--out', out, '--textsafe'];
  if (row !== null) argv.push('--row', String(row));
  let log = '';
  try { log = execFileSync('node', argv, { encoding: 'utf8' }); } catch (e) { log = String(e.stdout || ''); }
  const grab = (re) => ((log.match(re) || [])[1] || '').trim();
  const img = png.loadAny(out);

  fs.writeFileSync(out.replace(/\.png$/, '.json'), JSON.stringify({
    asset: name,
    destination: 'assets/ui/v1/band/' + name + '.png',
    canvas: [img.width, img.height],
    kind: 'picture band, drawn once edge to edge, never tiled and never stretched',
    corner: null,
    band: null,
    scale: 1,
    note: 'Picture class, like PixelScene: drawn at x1, clipped to the card width, '
      + 'not a nine-patch and not a tile. No corner and no band to declare.',
    master: 'raw/ui/band/' + master + '.png',
    crop: grab(/crop\s+(.*)/),
    textSafe: grab(/text-safe\s+(.*)/),
    ceiling: grab(/max luminance\s+(.*)/),
    guards: grab(/guards\s+(.*)/),
  }, null, 2) + '\n');

  console.log(name.padEnd(24) + img.width + 'x' + img.height);
  console.log('    ' + grab(/crop\s+(.*)/));
  console.log('    ' + grab(/text-safe\s+(.*)/));
  console.log('    ' + grab(/guards\s+(.*)/));
}
