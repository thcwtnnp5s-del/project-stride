// Project Stride - Code Render 01
// PROVISIONAL DIRECTION A PROOF PALETTE.
//
// PROVISIONAL FOR CODE RENDER 01 ONLY. Palette is UNRESOLVED in
// GAME_BIBLE/ART/ART_DIRECTION.md and this file does not change that. A value
// used to make a proof renderable has not been chosen (RULES.md G-3).
//
// Structure: index 0 is transparent; every other entry belongs to a named
// three-step ramp (dark / mid / light). No glow ramp, no specular ramp, no
// cinematic highlight ramp -- the rendering floor forbids all three.
//
// Light is baked from the UPPER LEFT: within any ramp, the light step faces
// up-left and the dark step faces down-right. That is a drawing convention held
// by hand in the sprite maps, not a lighting system.

'use strict';

// name -> [dark, mid, light] as #rrggbb
const RAMPS = {
  ink:      ['#17141a', '#241f26', '#332c33'], // outlines and deepest shadow
  skin:     ['#7d5340', '#a87a5a', '#cfa07c'],
  hair:     ['#33241a', '#4d3826', '#6b5038'],
  tunic:    ['#7a6142', '#a98b5e', '#d6bb8c'], // oat / sand cloth
  trouser:  ['#2f2c2a', '#474240', '#615a55'], // slate-brown
  leather:  ['#402d20', '#63472f', '#8a6543'], // belt, boots, straps
  canvas:   ['#5c5340', '#7d7157', '#9d9175'], // travel pack
  metal:    ['#3f454b', '#666e76', '#949ca4'], // sword, buckle
  grass:    ['#37492f', '#4c6440', '#648256'], // ordinary meadow, muted
  herb:     ['#3d6b2f', '#5c9440', '#86bd57'], // node green: one step up in both
  flower:   ['#9c8a58', '#cfbc84', '#f2e7bd'], // cream head
  timber:   ['#3f3325', '#63513a', '#8a7253'], // UI / earth neutral
  stone:    ['#383e42', '#565e63', '#7b848a'], // cool counterweight
  dirt:     ['#463726', '#66523c', '#8a7153'],
  panel:    ['#1e1a17', '#302a24', '#463d34'], // UI plate body
  text:     ['#8a7f6d', '#c2b59a', '#ede2c8'], // UI type
};

const PALETTE = [[0, 0, 0]]; // index 0, transparent via tRNS
const IDX = {};

for (const [name, ramp] of Object.entries(RAMPS)) {
  IDX[name] = ramp.map((hex) => {
    PALETTE.push([
      parseInt(hex.slice(1, 3), 16),
      parseInt(hex.slice(3, 5), 16),
      parseInt(hex.slice(5, 7), 16),
    ]);
    return PALETTE.length - 1;
  });
}

// Single-character legend used by every sprite map in this proof.
// Lower case = dark step, upper case = mid step, and a third distinct letter
// = light step, so a map row is readable as shading at a glance.
const L = {
  k: IDX.ink[0],      K: IDX.ink[1],      // K is the softer inner shadow
  s: IDX.skin[0],     S: IDX.skin[1],     W: IDX.skin[2],
  h: IDX.hair[0],     H: IDX.hair[1],     J: IDX.hair[2],
  t: IDX.tunic[0],    T: IDX.tunic[1],    U: IDX.tunic[2],
  p: IDX.trouser[0],  P: IDX.trouser[1],  Q: IDX.trouser[2],
  b: IDX.leather[0],  B: IDX.leather[1],  N: IDX.leather[2],
  c: IDX.canvas[0],   C: IDX.canvas[1],   V: IDX.canvas[2],
  m: IDX.metal[0],    M: IDX.metal[1],    X: IDX.metal[2],
  g: IDX.grass[0],    G: IDX.grass[1],    Y: IDX.grass[2],
  e: IDX.herb[0],     E: IDX.herb[1],     R: IDX.herb[2],
  f: IDX.flower[0],   F: IDX.flower[1],   O: IDX.flower[2],
  w: IDX.timber[0],   Z: IDX.timber[1],   A: IDX.timber[2],
  n: IDX.stone[0],    D: IDX.stone[1],    I: IDX.stone[2],
  d: IDX.dirt[0],     r: IDX.dirt[1],     q: IDX.dirt[2],
  a: IDX.panel[0],    x: IDX.panel[1],    y: IDX.panel[2],
  u: IDX.text[0],     v: IDX.text[1],     z: IDX.text[2],
};

module.exports = { PALETTE, IDX, L, RAMPS };
