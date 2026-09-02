// pull-track.js — download animation-track frames and build one contact sheet per track.
//   node pull-track.js <manifest.tsv>
// manifest.tsv columns (tab separated, '#' comments ignored):
//   set  track  char_id  anim_dir_id  nframes  direction
// anim_dir_id is the id in the animation FRAME URL (…/animations/<anim_dir_id>/<dir>/<i>.png),
// which is NOT the animation_group_id get_character prints in brackets.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const ACC = '037c0b2f-4030-4ac6-a4e7-0485e86af329';
const rows = fs.readFileSync(process.argv[2], 'utf8')
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'))
  .map((l) => l.split(/\t+/));

const lines = [];
const jobs = [];
for (const [set, track, charId, animId, nS, dirArg] of rows) {
  const n = Number(nS);
  const dir = dirArg || 'east';
  const outDir = path.join(ROOT, 'raw', 'equip', set, track);
  fs.mkdirSync(outDir, { recursive: true });
  const frames = [];
  for (let i = 0; i < n; i++) {
    const f = path.join(outDir, `f${i}.png`);
    frames.push(f);
    lines.push(`https://backblaze.pixellab.ai/file/pixellab-characters/${ACC}/${charId}/animations/${animId}/${dir}/${i}.png ${path.relative(ROOT, f).replace(/\\/g, '/')}`);
  }
  jobs.push({ set, track, n, frames });
}

const tmp = path.join(os.tmpdir(), `pull_${Date.now()}.txt`);
fs.writeFileSync(tmp, lines.join('\n'));
execFileSync('node', [path.join(ROOT, 'tools', 'fetch.js'), '--list', tmp], { cwd: ROOT, stdio: 'inherit' });

fs.mkdirSync(path.join(ROOT, 'review', 'equip'), { recursive: true });
for (const j of jobs) {
  const sheet = path.join(ROOT, 'review', 'equip', `${j.set}_${j.track}_x3.png`);
  execFileSync('node', [path.join(ROOT, 'tools', 'sheet.js'), sheet, '3', String(j.n), '#14120F', ...j.frames], { cwd: ROOT, stdio: 'inherit' });
}
