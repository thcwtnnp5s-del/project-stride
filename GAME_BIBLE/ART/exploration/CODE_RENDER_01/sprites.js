// Project Stride - Code Render 01
// The authored artwork. Each asset is a reusable sprite on its own smallest
// sensible transparent canvas.
//
// PROVISIONAL FOR CODE RENDER 01 ONLY. Nothing here is an art decision.
// Sprite dimensions, proportions and rendering treatment are UNRESOLVED in
// GAME_BIBLE/ART/ART_DIRECTION.md (RULES.md G-3).
//
// Legend, from palette.js: lower case = dark ramp step, upper case = mid,
// third letter = light. '.' is transparent. Light is baked from the UPPER LEFT.

'use strict';
const { Surface, fromMap } = require('./surface');
const { L } = require('./palette');

// ---------------------------------------------------------------- player
// 24 x 34 canvas, figure occupies rows 1-32 => 32 px tall.
// Three-quarter front-right facing, matching the canonical Haven's Rest scene:
// head turned down-right toward the plant, canvas pack breaking the shoulder
// line on the viewer's LEFT, Training Sword at the character's LEFT hip which
// under this view reads on the viewer's RIGHT. Hands empty.
// Owner Refinement 01. The three-quarter turn is now carried by construction:
// the character is turned toward the viewer's RIGHT, so the viewer-LEFT side is
// the FAR side (pack peeking from behind it) and the viewer-RIGHT side is the
// NEAR side (sword worn on the character's left hip, closest to us). The far
// shoulder sits one row higher than the near one, the legs are not mirrored,
// and the far foot plants one row above the forward near foot.
const PLAYER_MAP = [
  '........................', //  0
  '........kkkkk...........', //  1  crown shifted back: skull mass sits behind
  '........kJHHhhk.........', //  2
  '........khHHhhk.........', //  3
  '........khWWSSk.........', //  4  fringe over the far brow
  '........khkWkSk.........', //  5  hair down the FAR side; far eye compressed
  '........khWWSsk.........', //  6
  '..........kWSsk.........', //  7  jaw recedes on the far side, chin points near
  '..........kssk..........', //  8  neck follows the chin, not the torso centre
  '...kkkUUTTTTTtk.........', //  9  FAR shoulder alone, one row higher
  '..kCVkUbTTTTTTTtk.......', // 10  near shoulder joins; pack; strap begins
  '..kCVkUTbTTTTTTtk.......', // 11
  '..kkkkTTTbTTTTTtk.......', // 12  pack flap seam
  '..kCVkTTTTbTTTTtk.......', // 13
  '..kkkkbBBBBXBBbbk.......', // 14  belt; pack base; strap lands at the buckle
  '.....kTtUTTTTtttkBk.....', // 15  near arm: shaded upper arm
  '.....kStUTTTTttTkbk.....', // 16  far hand terminates first; near forearm lit
  '.....kSkTTTTTtkSkMMMk...', // 17  near hand, then an outline, THEN the guard
  '......kTUTTTTttk.Mmk....', // 18  tunic flares below the belt
  '......kTUTTtTttk.Mmk....', // 19  one off-centre fold
  '.....kTUTTTtTtttkMmk....', // 20
  '.....kTUTTTTTtttkmk.....', // 21
  '.....kttttttttttk.......', // 22  knee-length hem
  '.......kPpkkQPk.........', // 23  far leg darker, near leg lighter
  '.......kPpkkQPk.........', // 24
  '.......kPpkkQPk.........', // 25
  '.......kPpkkQPk.........', // 26
  '.......kNBkkQPk.........', // 27  far boot cuff
  '.......kBbkkNBk.........', // 28  near boot cuff, one row lower
  '.......kBbkkBBk.........', // 29
  '......kBBbkkBBk.........', // 30
  '......kbbbkkBBBk........', // 31  far foot plants here
  '...........kbbbk........', // 32  near foot is forward, one row lower
  '........................', // 33
];

// ---------------------------------------------------------------- herb node
// 20 x 19. A raised tuft of blades fanning from one root point, three pale
// stems rising above it, one cream flower head. Its separation from ordinary
// ground comes from palette and silhouette alone -- never from light.
const HERB_MAP = [
  '....................', //  0
  '.........OO.........', //  1  one cream flower head, slightly off-centre
  '........FOOF........', //  2
  '.........FOF........', //  3
  '..........F.........', //  4
  '..........F..F......', //  5  three pale stems, unequal heights
  '.......F..F..F......', //  6
  '.......F..F..F......', //  7
  '........F.F.F.......', //  8
  '.....E...FFF........', //  9  one blade already reaching past the stems
  '..e..E.R..R..E.e....', // 10  blade tips at irregular heights
  '..eE.EE.RR.RR.Ee....', // 11  outlying one-pixel blade removed
  '...EEeER.RRR.RE.E...', // 12
  '...eEERRRRRRREEe....', // 13
  '....eERRRRRRREEe....', // 14
  '.....eEERRRREEe.....', // 15
  '......eEERREEe......', // 16
  '.......eEEEe........', // 17
  '.........ee.........', // 18  single root point
];

// ---------------------------------------------------------------- herb icon
// 8 x 8. The card's icon echoes the node's silhouette family so the interface
// and the world read as one product.
const HERB_ICON_MAP = [
  '....O...',
  '...FOF..',
  '....F...',
  '..E.E...',
  '.EERREE.',
  'EERRRREE',
  '.EERREE.',
  '..eEe...',
];

// ---------------------------------------------------------------- bitmap font
// 3 x 5 glyphs on a 4 px advance. Deliberately disciplined: this is the whole
// typographic vocabulary the card needs.
const GLYPHS = {
  '0': ['###', '#.#', '#.#', '#.#', '###'],
  '1': ['.#.', '##.', '.#.', '.#.', '###'],
  '2': ['###', '..#', '###', '#..', '###'],
  '9': ['###', '#.#', '###', '..#', '###'],
  '+': ['...', '.#.', '###', '.#.', '...'],
  'x': ['...', '#.#', '.#.', '#.#', '...'], // multiplication sign
  'X': ['#.#', '#.#', '.#.', '#.#', '#.#'],
  'P': ['##.', '#.#', '##.', '#..', '#..'],
  ' ': ['...', '...', '...', '...', '...'],
};

function drawText(surf, text, x, y, idx) {
  let cx = x;
  for (const ch of text) {
    const g = GLYPHS[ch];
    if (!g) throw new Error(`no glyph for '${ch}'`);
    g.forEach((row, dy) => {
      for (let dx = 0; dx < row.length; dx++) if (row[dx] === '#') surf.set(cx + dx, y + dy, idx);
    });
    cx += 4;
  }
  return cx - 1;
}

function textWidth(text) { return text.length * 4 - 1; }

// ---------------------------------------------------------------- gather card
// 36 x 22. Neutral / common Direction A interface language only -- no A1, A2
// or A3 chrome is chosen here. A flat opaque plate seated on a one-pixel ink
// border, with a single construction bevel: light on the upper-left inner
// edge, dark on the lower-right. The bevel is a construction line, not a shine.
function buildGatherCard() {
  const W = 36, H = 24;
  const s = new Surface(W, H);

  s.rect(1, 1, W - 2, H - 2, L.x);      // panel body
  s.frame(0, 0, W, H, L.k);             // ink border
  s.set(0, 0, 0); s.set(W - 1, 0, 0);   // clipped corners keep it from reading
  s.set(0, H - 1, 0); s.set(W - 1, H - 1, 0); //  as a hard rectangle

  for (let x = 1; x < W - 1; x++) { s.set(x, 1, L.y); s.set(x, H - 2, L.a); }
  for (let y = 1; y < H - 1; y++) { s.set(1, y, L.y); s.set(W - 2, y, L.a); }
  s.set(W - 2, 1, L.x); s.set(1, H - 2, L.x);

  s.blit(HERB_ICON, 3, 4);                       // yield: what you get
  drawText(s, 'x2', 15, 6, L.z);

  for (let x = 3; x < W - 3; x++) {              // engraved seam, not a shine
    s.set(x, 14, L.a);
    s.set(x, 15, L.y);
  }
  drawText(s, '90', 3, 17, L.v);                 // cost
  const xp = '+10XP';
  drawText(s, xp, W - 3 - textWidth(xp), 17, L.v); // gain, right-aligned

  return s;
}

const PLAYER = fromMap(PLAYER_MAP, L);
const HERB = fromMap(HERB_MAP, L);
const HERB_ICON = fromMap(HERB_ICON_MAP, L);
const GATHER_CARD = buildGatherCard();

module.exports = { PLAYER, HERB, HERB_ICON, GATHER_CARD, drawText, textWidth, GLYPHS };
