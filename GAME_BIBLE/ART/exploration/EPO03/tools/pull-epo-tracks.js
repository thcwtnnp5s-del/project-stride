// pull-epo-tracks.js — EPO03 EQUIPMENT: download the v3 frames of every track
// in a tracks.tsv and lay each on a ×3 contact sheet, feet bottom-aligned.
//   node pull-epo-tracks.js <tracks.tsv>
// tsv columns: <name>\t<frames>\t<anim_dir_id>   (name is epo_<body>_<class>_<track>)
// The frame URL uses the animation's own directory id, which is NOT the
// animation_group_id get_character prints in brackets (FMPO02's finding).
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..');
const ACC = '037c0b2f-4030-4ac6-a4e7-0485e86af329';
const CHAR = 'c82b7da5-cda0-44eb-ae4e-30d73689e115';
const sep = String.fromCharCode(92);
const rows = fs.readFileSync(process.argv[2], 'utf8').split(/\r?\n/)
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#')).map((l) => l.split(/\t+/));
const lines = []; const jobs = [];
for (const [name, nS, animId, dirArg, charArg] of rows) {
  const dir = dirArg || 'east';
  const chr = charArg || CHAR;
  const n = Number(nS);
  const outDir = path.join(ROOT, 'raw', 'equip', name);
  fs.mkdirSync(outDir, { recursive: true });
  const frames = [];
  for (let i = 0; i < n; i++) {
    const f = path.join(outDir, `f${i}.png`);
    frames.push(f);
    lines.push('https://backblaze.pixellab.ai/file/pixellab-characters/' + ACC + '/' + chr + '/animations/' + animId + '/' + dir + '/' + i + '.png ' + path.relative(ROOT, f).split(sep).join('/'));
  }
  jobs.push({ name, n, frames });
}
const tmp = path.join(os.tmpdir(), `epopull_${Date.now()}.txt`);
fs.writeFileSync(tmp, lines.join('\n'));
execFileSync('node', [path.join(ROOT, 'tools', 'fetch.js'), '--list', tmp], { cwd: ROOT, stdio: 'inherit' });
for (const j of jobs) {
  execFileSync('node', [path.join(ROOT, 'tools', 'sheet.js'),
    path.join(ROOT, 'review', 'equip', `${j.name}_x3.png`), '3', String(j.n), '#1e1e1e', ...j.frames],
    { cwd: ROOT, stdio: 'inherit' });
}
