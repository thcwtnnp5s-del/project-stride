// Project Stride - Haven's Rest Base Scene 01
// The full-world scene: 128 x 192 native, composed from the CODE_RENDER_01
// sprites plus the environment authored here.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Nothing here is an art decision. The
// 128 x 192 frame is PROVISIONAL (PIXEL_ART_CRAFT_SPEC.md sec.10) and is not
// promoted into ART_DIRECTION.md.
//
// SHARED / NEUTRAL DIRECTION A ONLY. No A1 Frontier Hearth repair language, no
// A2 Waymarked marks, no A3 Wild Trails terrain-wear identity. This is the base
// grammar those three would later be applied to.
//
// Composition is translated from
//   GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/composition_blockout.png
// which is 1024 x 1536 -- exactly x8 of this frame -- so blockout pixel / 8 is
// this scene's coordinate. That file is read as reference only and is not
// modified.

'use strict';
const { Surface } = require('../CODE_RENDER_01/surface');
const { HERB } = require('../CODE_RENDER_01/sprites');
const { L } = require('./palette_ext');
const { drawText, textWidth } = require('./font_ext');
const {
  NPC, TREE_A, TREE_B, PLAYER_SCENE, SCENE_GATHER_CARD,
  TAB_MASKS, BOOT_MASK, drawMask,
} = require('./scene_sprites');

const W = 128;
const H = 192;

// ---------------------------------------------------------------- frame bands
const HUD_TOP_H = 13;        // rows 0..12 panel, row 13 ink rule
const HUD_BOT_Y = 179;       // row 178 ink rule, rows 179..191 panel
const WORLD_TOP = 14;
const WORLD_BOT = 177;

const HORIZON = 39;          // ground plane begins
const SKY_TOP_BAND = 19;     // rows 14..18 sit one step deeper

// ---------------------------------------------------------------- main path
// One continuous path from the gate mouth to the bottom of the world band.
// Quiet dirt: no A3 tread channels, no compaction identity.
const PATH_Y0 = 79;
const PATH_Y1 = WORLD_BOT;

function pathT(y) {
  const t = (y - PATH_Y0) / (PATH_Y1 - PATH_Y0);
  return t < 0 ? 0 : t > 1 ? 1 : t;
}
function pathCentre(y) { return 38 + 33 * Math.pow(pathT(y), 0.65); }
function pathHalf(y) { return 4 + 7 * pathT(y); }

// ---------------------------------------------------------------- helpers
// Integer midpoint ellipse, filled. No float reaches a pixel decision.
function contactShadow(s, cx, cy, rx, ry, idx) {
  for (let y = -ry; y <= ry; y++) {
    for (let x = -rx; x <= rx; x++) {
      if (x * x * ry * ry + y * y * rx * rx <= rx * rx * ry * ry) s.set(cx + x, cy + y, idx);
    }
  }
}

// A narrow dirt road band that recedes. Body plus ONE dark edge on the far
// side and no lit edge at all -- Pass 1's lit top edge made the right-hand road
// read as a raised timber rail instead of as ground.
function road(s, x0, y0, x1, y1, t0, t1) {
  const steps = Math.abs(x1 - x0);
  const step = x1 > x0 ? 1 : -1;
  for (let i = 0; i <= steps; i++) {
    const x = x0 + i * step;
    const f = i / steps;
    const y = Math.round(y0 + (y1 - y0) * f);
    const th = Math.max(1, Math.round(t0 + (t1 - t0) * f));
    for (let k = 0; k < th; k++) s.set(x, y + k, L.r);
    s.set(x, y + th, L.d);
  }
}

// A low roof mass: three values, a horizontal lit ridge, a shaded far slope, a
// dark eave line, and a band of building wall below it. Pass 1's pitch was so
// steep the roofs read as tents rather than as buildings.
function roofMass(s, cx, ridgeHalf, eaveHalf, ridgeY, eaveY) {
  for (let y = ridgeY; y <= eaveY; y++) {
    const f = (y - ridgeY) / (eaveY - ridgeY);
    const hw = Math.round(ridgeHalf + (eaveHalf - ridgeHalf) * f);
    for (let x = cx - hw; x <= cx + hw; x++) {
      let idx = x < cx ? L[5] : L[4];
      if (y === ridgeY) idx = L[6];
      if (y === eaveY) idx = L[4];
      s.set(x, y, idx);
    }
  }
  // The band of building wall below the eave, before the palisade covers it.
  // Pass 2 inset this by two on each side and the narrow dark stem under a wide
  // roof made the buildings read as toadstools; the wall now sits just inside
  // the eave line so roof and building read as one mass.
  for (let y = eaveY + 1; y < 64; y++) {
    for (let x = cx - eaveHalf + 1; x <= cx + eaveHalf - 1; x++) {
      s.set(x, y, x < cx ? L.Z : L.w);
    }
  }
}

// ---------------------------------------------------------------- the scene
function buildScene() {
  const s = new Surface(W, H, L.G);

  // --- sky -----------------------------------------------------------------
  for (let y = WORLD_TOP; y < HORIZON; y++) {
    for (let x = 0; x < W; x++) s.set(x, y, y < SKY_TOP_BAND ? L[2] : L[3]);
  }

  // --- distant treeline ----------------------------------------------------
  // Depth is bought with value and saturation loss, not with a new green ramp:
  // the horizon wood is drawn in the cool stone mid step. Irregular overlapping
  // bumps, so the silhouette is a wood rather than a repeating scallop.
  const BUMPS = [
    [3, 5], [12, 4], [19, 6], [29, 4], [37, 5], [47, 3], [54, 6], [64, 4],
    [72, 5], [81, 6], [90, 4], [98, 5], [107, 6], [116, 4], [124, 5],
  ];
  for (const [bx, br] of BUMPS) {
    for (let x = bx - br; x <= bx + br; x++) {
      const dx = x - bx;
      const rise = Math.round(Math.sqrt(Math.max(0, br * br - dx * dx)));
      for (let y = HORIZON - rise; y < HORIZON; y++) s.set(x, y, L.D);
    }
  }
  for (let x = 0; x < W; x++) { s.set(x, HORIZON - 2, L.D); s.set(x, HORIZON - 1, L.D); }

  // --- ground --------------------------------------------------------------
  for (let y = HORIZON; y <= WORLD_BOT; y++) {
    for (let x = 0; x < W; x++) s.set(x, y, y < HORIZON + 8 ? L.g : L.G);
  }

  // --- restrained field variation -----------------------------------------
  // Four placed shallow patches. Not scatter, not noise, not speckle -- four,
  // chosen to sit where the field would otherwise run flat for a long distance.
  // Pass 1 drew these as two-row dashes and they read as smudges; they are now
  // irregular three-row patches that read as a shallow dip in the meadow.
  const PATCHES = [[14, 112], [92, 104], [24, 148], [100, 156]];
  for (const [cx, cy] of PATCHES) {
    const profile = [4, 8, 6];
    profile.forEach((run, dy) => {
      const off = dy === 1 ? -1 : dy === 2 ? 1 : 0;
      for (let x = cx + off; x < cx + off + run; x++) s.set(x, cy + dy, L.g);
    });
  }

  // --- two narrow roads leaving the frame ----------------------------------
  road(s, 24, 82, 0, 94, 4, 7);    // left edge, out past the settlement
  road(s, 69, 86, 127, 58, 5, 3);  // right edge

  // --- main path -----------------------------------------------------------
  for (let y = PATH_Y0; y <= PATH_Y1; y++) {
    const c = pathCentre(y);
    const hw = pathHalf(y);
    const x0 = Math.round(c - hw);
    const x1 = Math.round(c + hw);
    for (let x = x0; x <= x1; x++) s.set(x, y, L.r);
    s.set(x0, y, L.q);      // lit edge, up-left
    s.set(x1, y, L.d);      // shaded edge, down-right
  }

  // --- thin grass fringe, bottom-left only ---------------------------------
  // Connected clumps on a continuous base, not single blades. Pass 1's
  // one-pixel-wide blades read as a row of isolated specks (CR-18).
  const CLUMPS = [[0, 5, 3], [7, 4, 2], [13, 5, 3], [20, 6, 2], [28, 5, 3], [35, 6, 2]];
  for (let x = 0; x <= 40; x++) s.set(x, WORLD_BOT, L.g);
  for (const [cx, cw, ch] of CLUMPS) {
    for (let x = cx; x < cx + cw; x++) {
      const rise = ((x - cx) % 2 === 0) ? ch : ch - 1;
      for (let y = 0; y <= rise; y++) s.set(x, WORLD_BOT - y, y === rise ? L.Y : L.g);
    }
  }

  // --- settlement roofs ----------------------------------------------------
  roofMass(s, 21, 5, 8, 52, 60);
  roofMass(s, 44, 6, 9, 49, 59);
  roofMass(s, 62, 3, 5, 54, 61);

  // --- one thin smoke plume ------------------------------------------------
  // From the first roof's ridge. One pixel wide, wandering, and breaking up as
  // it rises. It is drawn in sky values, so it cannot read as an effect.
  const SMOKE = [
    [22, 50], [22, 49], [22, 48], [22, 47], [23, 46], [23, 45], [23, 44],
    [23, 43], [23, 42], [24, 41], [24, 40], [24, 39], [24, 38], [23, 37],
    [23, 36], [23, 35], [24, 34], [24, 33], [24, 32], [25, 31], [25, 30],
    [25, 28], [26, 27], [26, 25],
  ];
  for (const [sx, sy] of SMOKE) s.set(sx, sy, L[3]);

  // --- two trees -----------------------------------------------------------
  contactShadow(s, 12, 66, 6, 2, L.g);
  s.blit(TREE_A, 4, 43);
  contactShadow(s, 70, 72, 6, 2, L.g);
  s.blit(TREE_B, 62, 46);

  // --- palisade wall and gate ----------------------------------------------
  const WALL_X0 = 6, WALL_X1 = 64, WALL_TOP = 64, WALL_BASE = 81;
  const GATE_X0 = 33, GATE_X1 = 42;
  for (let x = WALL_X0; x <= WALL_X1; x++) {
    if (x >= GATE_X0 && x <= GATE_X1) continue;
    const post = (x - WALL_X0) % 3;
    s.set(x, WALL_TOP, post === 0 ? L.A : L.w);            // pointed post tops
    for (let y = WALL_TOP + 1; y <= WALL_BASE - 1; y++) {
      s.set(x, y, post === 2 ? L.w : L.Z);                 // plank seam every 3 px
    }
    s.set(x, WALL_BASE, L.w);                              // base shadow line
  }
  // Gate: shadowed opening between two light posts under a heavy lintel.
  for (let y = WALL_TOP + 4; y <= WALL_BASE; y++) {
    for (let x = GATE_X0 + 1; x <= GATE_X1 - 1; x++) s.set(x, y, L.w);
  }
  for (let y = WALL_TOP; y <= WALL_BASE; y++) { s.set(GATE_X0, y, L.A); s.set(GATE_X1, y, L.Z); }
  for (let x = GATE_X0 - 1; x <= GATE_X1 + 1; x++) {
    s.set(x, WALL_TOP + 2, L.A);
    s.set(x, WALL_TOP + 3, L.Z);
  }

  // --- low scrub along the palisade base -----------------------------------
  // Three clusters. Economical on purpose: the wall's base line is what needs
  // softening, not the whole field.
  // Pass 1's scrub was one row of alternating pixels and vanished. It is now
  // three low mounds with a readable silhouette against the wall's base line.
  const SCRUB = [[8, 8], [19, 7], [57, 7]];
  for (const [bx, bw] of SCRUB) {
    for (let x = bx; x < bx + bw; x++) {
      const k = x - bx;
      const rise = k === 0 || k === bw - 1 ? 1 : (k % 3 === 1 ? 3 : 2);
      for (let y = 0; y < rise; y++) s.set(x, 81 - y, y === rise - 1 ? L[8] : L[7]);
    }
  }

  // --- three firewood logs -------------------------------------------------
  // Two below, one above, seen end-on so the cut faces read. Pass 1's logs were
  // five pixels wide with a one-pixel core and read as a smudge.
  function log(x, y) {
    const rows = [
      '.wwww.',
      'wZAAZw',
      'wZAAZw',
      '.wwww.',
    ];
    rows.forEach((r, dy) => {
      for (let dx = 0; dx < r.length; dx++) if (r[dx] !== '.') s.set(x + dx, y + dy, L[r[dx]]);
    });
  }
  contactShadow(s, 23, 105, 8, 2, L.g);
  log(17, 100); log(24, 100); log(20, 96);

  // --- signpost ------------------------------------------------------------
  // Plain functional timber, two arms, no writing and no marks of any kind.
  // The arms are now tapered to points so the post stops reading as a plus
  // sign; the post carries a three-value break so it reads as round timber.
  for (let y = 95; y <= 109; y++) { s.set(64, y, L.A); s.set(65, y, L.Z); s.set(66, y, L.w); }
  // Both arms step away from the post as they run, so they read as pointing
  // rather than as a horizontal cross-bar. Pass 2's arms were level and the
  // signpost read as a plus sign.
  const ARM_V = [L.A, L.Z, L.w];
  for (let x = 67; x <= 77; x++) {
    const dy = Math.floor((x - 67) / 4);
    const len = x <= 74 ? 3 : x <= 76 ? 2 : 1;
    for (let k = 0; k < len; k++) s.set(x, 97 + dy + k, ARM_V[k]);
  }
  for (let x = 63; x >= 56; x--) {
    const dy = Math.floor((63 - x) / 4);
    const len = x >= 58 ? 3 : x >= 57 ? 2 : 1;
    for (let k = 0; k < len; k++) s.set(x, 102 + dy + k, ARM_V[k]);
  }
  contactShadow(s, 65, 109, 3, 1, L.g);

  // --- two path stones -----------------------------------------------------
  // Seated, not floating: rounded, no light step, and a dark bottom row so the
  // stone sits in the dirt rather than on it. Pass 1's stones read as pale
  // cool lozenges lying on the surface.
  function stone(x, y, w) {
    for (let dx = 1; dx < w - 1; dx++) s.set(x + dx, y, L.D);
    for (let dx = 0; dx < w; dx++) s.set(x + dx, y + 1, L.D);
    for (let dx = 1; dx < w - 1; dx++) s.set(x + dx, y + 2, L.n);
  }
  // The upper stone moves up the path so the enlarged gather card does not
  // cover it. Two stones, still two, still in the path, better separated.
  stone(53, 122, 4);
  stone(66, 157, 5);

  // --- the resident --------------------------------------------------------
  contactShadow(s, 51, 86, 4, 1, L.g);
  s.blit(NPC, 46, 65);

  // --- the Traveler --------------------------------------------------------
  // Owner Refinement 02, unchanged, standing on the grass at the left edge of
  // the path. Placed so the sword at the near hip clears the path edge rather
  // than tangenting it (CR-16).
  contactShadow(s, 42, 138, 8, 2, L.g);
  s.blit(PLAYER_SCENE, 30, 105);

  // --- the Meadow Herb -----------------------------------------------------
  // Frozen working reference, unchanged, in the canonical lower-right area on
  // grass beside the path. Its salience is silhouette, palette and contrast.
  s.blit(HERB, 77, 143);

  // --- gather card ---------------------------------------------------------
  // Scene-fitted card, floating just above the node.
  s.blit(SCENE_GATHER_CARD, 62, 112);

  drawHud(s);
  return s;
}

// ---------------------------------------------------------------- HUD
function drawHud(s) {
  // Top strip.
  for (let y = 0; y < HUD_TOP_H; y++) for (let x = 0; x < W; x++) s.set(x, y, L.x);
  for (let x = 0; x < W; x++) { s.set(x, 0, L.y); s.set(x, HUD_TOP_H, L.k); }

  drawText(s, "Haven's Rest", 4, 4, L.z);
  drawMask(s, BOOT_MASK, 87, 4, L.v);
  drawText(s, '1,240', 97, 4, L.z);
  s.set(121, 5, L.v); s.set(122, 5, L.v);
  s.set(121, 6, L.v); s.set(122, 6, L.v);

  // Bottom strip.
  for (let y = HUD_BOT_Y; y < H; y++) for (let x = 0; x < W; x++) s.set(x, y, L.x);
  for (let x = 0; x < W; x++) { s.set(x, HUD_BOT_Y - 1, L.k); s.set(x, HUD_BOT_Y, L.y); }

  // Six evenly spaced icon-only tabs; the leftmost is active.
  const CENTRES = [11, 32, 53, 75, 96, 117];
  // Active plate first, so the active icon sits on it.
  for (let y = HUD_BOT_Y + 1; y < H - 1; y++) {
    for (let x = CENTRES[0] - 8; x <= CENTRES[0] + 8; x++) s.set(x, y, L.y);
  }
  for (let x = CENTRES[0] - 8; x <= CENTRES[0] + 8; x++) s.set(x, H - 2, L.a);
  for (let y = HUD_BOT_Y + 1; y < H - 1; y++) s.set(CENTRES[0] + 8, y, L.a);

  CENTRES.forEach((cx, k) => {
    drawMask(s, TAB_MASKS[k], cx - 4, HUD_BOT_Y + 2, k === 0 ? L.z : L.u);
  });
}

module.exports = { buildScene, W, H, textWidth };
