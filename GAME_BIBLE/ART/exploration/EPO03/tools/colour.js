// colour.js — the two luminance measures this round uses, and nothing else.
//
// WCAG relative luminance answers "does this out-shine the text" (the ceiling
// guard's question). CIE L* answers "how far apart do these two inks look"
// (the <=6 L* grain question). They are different questions and using one for
// the other is how a flat-looking tile passes a check it should fail.
'use strict';

function relLum(r, g, b) {
  const f = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
  return (0.2126 * f(r)) + (0.7152 * f(g)) + (0.0722 * f(b));
}

/** CIE L* (D65), 0..100. */
function lstar(r, g, b) {
  const Y = relLum(r, g, b);
  return Y > 0.008856 ? (116 * Math.cbrt(Y)) - 16 : 903.3 * Y;
}

const CEILING_HEX = '#7C7263';
const CEILING_L = relLum(0x7c, 0x72, 0x63);
const TEAL = [0x58, 0xd6, 0xc0];

const hex = (r, g, b) => `#${[r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('')}`.toUpperCase();
const parse = (h) => { const s = h.replace('#', ''); return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)]; };
const cheb = (r, g, b, t) => Math.max(Math.abs(r - t[0]), Math.abs(g - t[1]), Math.abs(b - t[2]));

module.exports = { relLum, lstar, hex, parse, cheb, CEILING_L, CEILING_HEX, TEAL };
