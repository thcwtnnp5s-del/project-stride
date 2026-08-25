// WMER02 layout edits, applied once after sweep_layout.js:
// dragon journey, fire relocation, three new eggs, and the label pass.
'use strict';
const fs = require('fs');
const path = require('path');
const f = path.join(__dirname, '..', '..', '..', '..', '..', 'assets', 'content', 'v1', 'atlas', 'atlas_layout.json');
const j = JSON.parse(fs.readFileSync(f, 'utf8'));

// 1. Dragon: 28-frame journey (two flight loops + the fire breath), plays
//    once per crossing; the packaged crop widened to 68x31 for the flame.
const dragon = j.overlays.find((o) => o.asset === 'env/overlay_skydragon');
dragon.frames = 28;
dragon.playLoops = 1;
dragon.width = 68;
dragon.height = 31;

// 2. fire2 -> fire3: the corridor runs through fire2's box, so the burn scar
//    is re-authored in the south-west forest. Crop origin base (272,624) +
//    box (12,0) => world (1704, 3744); box 44x52.
const fire = j.overlays.find((o) => o.asset === 'env/overlay_fire2');
fire.asset = 'env/overlay_fire3';
fire.x = 1704;
fire.y = 3744;
fire.frames = 10;
fire.width = 44;
fire.height = 52;

// 3. New eggs: the roadside stag, the marsh flock, the westbound caravan.
j.overlays.push(
  { asset: 'env/overlay_stag', x: 936, y: 2958, frames: 20, frameMillis: 400, intervalMillis: 34000, drift: { x: 0, y: 0 }, opacity: 1, width: 28, height: 22 },
  { asset: 'env/overlay_flock', x: 2736, y: 4380, frames: 13, frameMillis: 250, intervalMillis: 23000, drift: { x: 0, y: 0 }, opacity: 1, width: 64, height: 40 },
  { asset: 'env/overlay_caravan', x: 1350, y: 3072, frames: 1, frameMillis: 12000, intervalMillis: 52000, drift: { x: 0, y: 0 }, travel: { x: -12, y: -1 }, opacity: 1, width: 20, height: 19 },
);

// 4. Labels: drop Outer Shoal (four names stacked in one SE column on
//    device); move The Worldspine off the new pass onto the ridge it names;
//    three restrained frontier names for the outer ring (art-stream
//    proposals under Q-07, like every future-tier name).
j.landmarks = j.landmarks.filter((l) => l.id !== 'landmark.outer_shoal');
const ws = j.landmarks.find((l) => l.id === 'landmark.worldspine');
ws.x = 940;
ws.y = 2000;
const mk = { asset: 'world/marker_landmark', width: 20, height: 20, anchorX: 10, anchorY: 10 };
j.landmarks.push(
  { id: 'landmark.wayfarers_pass', name: "Wayfarer's Pass", x: 1120, y: 3250, tier: 'future', marker: { ...mk } },
  { id: 'landmark.white_reach', name: 'The White Reach', x: 3600, y: 360, tier: 'future', marker: { ...mk } },
  { id: 'landmark.far_isles', name: 'The Far Isles', x: 5820, y: 1500, tier: 'future', marker: { ...mk } },
);

fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
console.log('landmarks:', j.landmarks.length, 'future:', j.landmarks.filter((l) => l.tier === 'future').length, 'overlays:', j.overlays.length);
