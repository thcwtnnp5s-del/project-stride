// summarise.js — one compact line per track from measure.js JSON. Reads only.
//   node summarise.js <trackDir> [<trackDir> ...]
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

for (const d of process.argv.slice(2)) {
  let files;
  try {
    files = fs.readdirSync(d).filter((f) => /^f[0-9]+[.]png$/.test(f))
      .sort((a, b) => Number(a.match(/[0-9]+/)[0]) - Number(b.match(/[0-9]+/)[0]))
      .map((f) => path.join(d, f));
  } catch (e) { console.log(d + '\tMISSING'); continue; }
  if (!files.length) { console.log(d + '\tNO FRAMES'); continue; }
  const j = JSON.parse(execFileSync('node', [path.join(__dirname, 'measure.js'), ...files]).toString());
  console.log([
    d.split(path.sep).join('/'),
    'n=' + j.frames.length,
    'canvas=' + j.canvas,
    'union=' + j.union_bbox.join(','),
    'foot=' + j.foot_row + '(min ' + j.foot_row_min + ')',
    'bronze=[' + j.frames.map((f) => f.bronze).join(' ') + ']',
    'steel=[' + j.frames.map((f) => f.steel).join(' ') + ']',
    'detached=' + (j.detached_frames.length ? j.detached_frames.join(' ') : 'none'),
    'gold=' + (j.gold_frames.length ? j.gold_frames.join(' ') : 'none'),
    'partialAlpha=' + (j.partial_alpha_frames.length ? j.partial_alpha_frames.join(' ') : 'none'),
  ].join('\t'));
}
