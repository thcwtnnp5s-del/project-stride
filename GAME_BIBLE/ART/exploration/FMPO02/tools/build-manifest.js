// build-manifest.js — write raw/equip/MANIFEST.json from tracks.tsv + the frames on disk.
//   node build-manifest.js <tracks.tsv> <verdicts.tsv>
// tracks.tsv:   set  track  char_id  anim_dir_id  frames  dir
// verdicts.tsv: set  track  verdict  note      (missing row => "UNREVIEWED")
//
// Every geometric number here is measured from the downloaded PNGs, never assumed:
// union_bbox is the union of per-frame opaque boxes and foot_row the lowest opaque
// row across the track, both in the raw v3 canvas. crop_hint/anchor_row are derived
// from those, so a bad strip shows up as a wrong anchor rather than silently packing.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const rows = (f) => fs.readFileSync(f, 'utf8').split(/\r?\n/).map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#')).map((l) => l.split(/\t+/));

// A re-rolled track appends a second row for the same (set, track); the LAST row wins,
// because that is the animation whose frames are actually on disk.
const seen = new Map();
for (const r of rows(process.argv[2])) seen.set(r[0] + '|' + r[1], r);
const tracks = [...seen.values()];
const verdicts = new Map();
if (process.argv[3] && fs.existsSync(process.argv[3])) {
  for (const [set, track, v, ...note] of rows(process.argv[3])) {
    verdicts.set(set + '|' + track, { verdict: v, note: note.join(' ') });
  }
}

const out = [];
for (const [set, track, charId, animId, nS, dirArg] of tracks) {
  const dir = path.join(ROOT, 'raw', 'equip', set, track);
  let files = [];
  try {
    files = fs.readdirSync(dir).filter((f) => /^f[0-9]+[.]png$/.test(f))
      .sort((a, b) => Number(a.match(/[0-9]+/)[0]) - Number(b.match(/[0-9]+/)[0]))
      .map((f) => path.join(dir, f));
  } catch (e) { /* not downloaded */ }
  if (!files.length) continue;
  const m = JSON.parse(execFileSync('node', [path.join(__dirname, 'measure.js'), ...files]).toString());
  const [cw, chh] = m.canvas.split('x').map(Number);
  // v3 does NOT return one fixed square: 88x88 for most tracks, 92x92 for others
  // (coat_steel). So the crop is DERIVED from the measured foot row, never assumed —
  // cropY places the lowest opaque row on row 62 of the 64-row canvas (ART-05 §3),
  // and cropX centres the 80-wide window. `fits` says whether the union box survives it.
  const outW = 80;
  const cropX = Math.round((cw - outW) / 2);
  const cropY = m.foot_row - 62;
  const [ux, uy, uw, uh] = m.union_bbox;
  const fits = ux >= cropX && ux + uw <= cropX + outW && uy >= cropY && uy + uh <= cropY + 64;
  const v = verdicts.get(set + '|' + track) || { verdict: 'UNREVIEWED', note: '' };
  out.push({
    set,
    track,
    state_id: charId,
    animation_group_id: animId,
    frames: files.length,
    direction: dirArg || 'east',
    canvas: m.canvas,
    union_bbox: m.union_bbox,
    foot_row: m.foot_row,
    foot_row_min: m.foot_row_min,
    crop_hint: [cropX, cropY, outW, 64],
    anchor_row_after_crop: 62,
    union_fits_crop: fits,
    // How far the union box escapes the 80x64 window keyed to foot row 62. Non-zero top
    // means a raised weapon leaves the canvas: the DECLARED height must grow (ART-05 §3),
    // never a per-frame re-crop.
    overflow_rows_top: Math.max(0, cropY - uy),
    overflow_rows_bottom: Math.max(0, (uy + uh) - (cropY + 64)),
    overflow_cols_left: Math.max(0, cropX - ux),
    overflow_cols_right: Math.max(0, (ux + uw) - (cropX + outW)),
    detached_frames: m.detached_frames,
    gold_frames: m.gold_frames,
    partial_alpha_frames: m.partial_alpha_frames,
    verdict: v.verdict,
    note: v.note,
  });
}

const dest = path.join(ROOT, 'raw', 'equip', 'MANIFEST.json');
fs.writeFileSync(dest, JSON.stringify({
  round: 'FMPO02',
  family: 'EQUIPMENT',
  generated: new Date().toISOString().slice(0, 10),
  note: 'Raw v3 output, UNCROPPED. crop_hint/anchor_row_after_crop are derived from the '
      + 'measured union box; the integrator crops, packaging does not re-measure.',
  sets: out,
}, null, 2));
console.log(`${dest}  ${out.length} tracks`);
for (const s of out) {
  console.log([s.set, s.track, s.frames + 'f', s.canvas, 'union=' + s.union_bbox.join(','),
    'foot=' + s.foot_row, 'crop=' + s.crop_hint.join(','),
    s.union_fits_crop ? 'fits' : 'OVERFLOWS', s.verdict].join('\t'));
}
