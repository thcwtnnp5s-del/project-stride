// gather-composite.js — stage review composite for a gather scene candidate.
// A-2 permitted: scale + blit only, invents nothing.
//
//   node gather-composite.js <backdrop.png> <subject.png> <traveler.png> <out.png> [subjectCenterX=176] [groundRow=162]
//
// Backdrop is drawn at x1 (native, opaque, 384x176). The subject (48x48
// transparent) is drawn at x2 and grounded so its lowest opaque row sits on
// [groundRow], centred horizontally on [subjectCenterX] (columns ~122-230 is
// the keep-clear/subject band per GATHER_SCENE_DIRECTION_01 §1.3). The
// traveler frame (shipped activity_mine_f0.png / activity_forage_f0.png) is
// drawn at x2 to its east (right), also grounded on [groundRow], matching the
// runtime rule that the figure sits east of the subject.
//
// Thin guide lines (ground row, keep-clear columns 122/230) are drawn on a
// COPY only for this review canvas — never on the accepted source plates.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [backdropFile, subjectFile, travelerFile, outFile, cxS, groundS] = process.argv.slice(2);
if (!backdropFile || !subjectFile || !travelerFile || !outFile) {
  console.error('usage: node gather-composite.js <backdrop.png> <subject.png> <traveler.png> <out.png> [subjectCenterX=176] [groundRow=162]');
  process.exit(1);
}
const centerX = cxS ? Number(cxS) : 176;
const groundRow = groundS ? Number(groundS) : 162;

const backdrop = png.load(backdropFile);
if (backdrop.width !== 384 || backdrop.height !== 176) {
  console.error(`WARN: ${backdropFile} is ${backdrop.width}x${backdrop.height}, expected 384x176`);
}

const canvas = backdrop.clone();

// Subject at x2, grounded on groundRow, centred on centerX.
const subjectSrc = png.load(subjectFile);
const subjectFoot = png.footprint(subjectSrc, 3);
const subject2x = png.scale(subjectSrc, 2);
const subjLeft = Math.round(centerX - subject2x.width / 2);
// lowest opaque row of the *scaled* sprite, in canvas-local Y once placed at subjTop
const subjBoxScaled = png.bounds(subject2x);
const subjTop = subjBoxScaled
  ? Math.round(groundRow - (subjBoxScaled.bottom + 1))
  : Math.round(groundRow - subject2x.height);
png.blit(canvas, subject2x, subjLeft, subjTop);

// Traveler at x2, grounded on groundRow, placed east of the subject with an 8px (native) gap.
const travelerSrc = png.load(travelerFile);
const traveler2x = png.scale(travelerSrc, 2);
const travBoxScaled = png.bounds(traveler2x);
const gapNative = 8;
const travLeft = subjLeft + subject2x.width + gapNative * 2;
const travTop = travBoxScaled
  ? Math.round(groundRow - (travBoxScaled.bottom + 1))
  : Math.round(groundRow - traveler2x.height);
png.blit(canvas, traveler2x, travLeft, travTop);

// Guides: ground line (row) and keep-clear columns 122 / 230, drawn faint magenta.
const GUIDE = [255, 0, 200, 140];
for (let x = 0; x < canvas.width; x += 2) {
  const i = canvas.idx(x, groundRow);
  canvas.data[i] = GUIDE[0]; canvas.data[i + 1] = GUIDE[1]; canvas.data[i + 2] = GUIDE[2]; canvas.data[i + 3] = GUIDE[3];
}
for (const gx of [122, 230]) {
  for (let y = 90; y < 176; y += 2) {
    const i = canvas.idx(gx, y);
    canvas.data[i] = GUIDE[0]; canvas.data[i + 1] = GUIDE[1]; canvas.data[i + 2] = GUIDE[2]; canvas.data[i + 3] = GUIDE[3];
  }
}

png.save(outFile, canvas);
console.log(
  `${outFile} ${canvas.width}x${canvas.height} subject@(${subjLeft},${subjTop}) foot=${JSON.stringify(subjectFoot)} traveler@(${travLeft},${travTop})`,
);
