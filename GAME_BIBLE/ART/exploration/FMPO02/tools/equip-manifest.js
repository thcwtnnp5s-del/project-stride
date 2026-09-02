// equip-manifest.js — turns PROD-EQUIPMENT's MANIFEST.json into equip-prep's
// input: one entry per accepted set with the packaging id, frame dir and the
// declared strip width. Naming: traveler_<body>[_<held>]_<track>.
//   node equip-manifest.js <MANIFEST.json> <raw-equip-dir> <out.json>
'use strict';
const fs = require('fs');
const path = require('path');
const [inFile, rawDir, outFile] = process.argv.slice(2);
const m = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const WIDE = new Set(['idle', 'attack', 'hit', 'stagger', 'mine', 'woodcut']);
const held = { bare: null, bronze: 'bronze', steel: 'steel', unarmed: 'unarmed', pick: 'bronzepick', axe: 'bronzeaxe' };
const out = [];
for (const s of m.sets) {
  if (s.verdict !== 'ACCEPT' && !(s.set === 'plate_pick' && s.track === 'mine')) continue;
  const [body, kind] = s.set.split('_');
  const h = held[kind];
  const id = h ? `traveler_${body}_${h}_${s.track}` : `traveler_${body}_${s.track}`;
  let dir = path.join(rawDir, s.set, s.track);
  if (!fs.existsSync(dir) && s.set === 'plate_pick') dir = path.join(rawDir, 'plate_pick_mine_w');
  out.push({ id, set: s.set, track: s.track, dir, frames: s.frames, canvasWidth: WIDE.has(s.track) ? 80 : 64, verdict: 'ACCEPT', maxClipTop: 12 });
}
fs.writeFileSync(outFile, JSON.stringify(out, null, 1));
console.log(`${out.length} sets → ${outFile}`);
