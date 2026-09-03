// EPO03 WORLDLIFE — composite the layout at a WALL CLOCK, not at frame 0.
//
// `worldlife-composite.js` blits every overlay's first frame at its `x,y`.
// A v6 path overlay has no `x,y` at all: the line says where it is, and where
// it is depends on the second. A sheet that drew those at the origin would
// prove nothing about the patrol, which is exactly the "verified against an
// atlas that no longer exists" failure in a different coordinate.
//
// So this reimplements the Dart position arithmetic (atlas_layout.dart's
// `AtlasOverlayPath`) in JS and renders the shipped layout at several
// instants, followers included. It always reads the atlas and the layout at
// HEAD-of-disk and the sprites from the PACKAGED tree, so a stale asset shows
// up as a missing file rather than as a passing sheet.
//
// Usage: node life-patrol-proof.js <outPrefix> <seconds...>
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const SCALE = 6;
const ART = path.join(REPO, 'assets', 'art', 'v1');
const layout = JSON.parse(fs.readFileSync(
  path.join(REPO, 'assets', 'content', 'v1', 'atlas', 'atlas_layout.json'), 'utf8'));

const prefix = process.argv[2] || 'PATROL';
const instants = process.argv.slice(3).map(Number);
if (!instants.length) instants.push(0, 42, 85);

const missing = [];
function frame(asset, index) {
  const file = path.join(ART, `${asset}_f${index}.png`);
  if (!fs.existsSync(file)) {
    const bare = path.join(ART, `${asset}.png`);
    if (!fs.existsSync(bare)) { missing.push(`${asset}_f${index}`); return null; }
    return png.load(bare);
  }
  return png.load(file);
}

const dist = (a, b) => Math.hypot(b[0] - a[0], b[1] - a[1]);

function measure(p) {
  const cum = [0];
  let total = 0;
  for (let i = 1; i < p.points.length; i++) {
    total += dist(p.points[i - 1], p.points[i]);
    cum.push(total);
  }
  if ((p.mode || 'loop') === 'loop') {
    total += dist(p.points.at(-1), p.points[0]);
    cum.push(total);
  }
  return cum;
}

function foot(p, ms) {
  if (ms === 0) return [p.points[0][0], p.points[0][1], 1];
  const cum = measure(p);
  const L = cum.at(-1);
  const t = (ms + (p.phaseMillis || 0)) / 1000;
  let s = p.speed * t;
  if ((p.mode || 'loop') === 'loop') {
    s = ((s % L) + L) % L;
  } else {
    const span = 2 * L;
    s = ((s % span) + span) % span;
    if (s > L) s = span - s;
  }
  for (let i = 1; i < cum.length; i++) {
    if (s <= cum[i] || i === cum.length - 1) {
      const a = p.points[i - 1];
      const b = i < p.points.length ? p.points[i] : p.points[0];
      const seg = cum[i] - cum[i - 1];
      const f = seg <= 0 ? 0 : Math.min(1, Math.max(0, (s - cum[i - 1]) / seg));
      return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, b[0] - a[0]];
    }
  }
  return [p.points[0][0], p.points[0][1], 1];
}

function breathPhase(o, ms) {
  const p = o.path;
  if (!p || !o.breath || !(p.breathAt || []).length || ms === 0) return null;
  const cum = measure(p);
  const L = cum.at(-1);
  const pingpong = p.mode === 'pingpong';
  const cycle = (pingpong ? 2 : 1) * L / p.speed * 1000;
  const lap = L / p.speed * 1000;
  const dur = o.breath.frames * o.breath.frameMillis;
  const clock = ms + (p.phaseMillis || 0);
  for (const k of p.breathAt) {
    const at = cum[k] / p.speed * 1000;
    for (const c of (pingpong ? [at, 2 * lap - at] : [at])) {
      const since = (((clock - c) % cycle) + cycle) % cycle;
      if (since < dur) return Math.floor(since / o.breath.frameMillis) % o.breath.frames;
    }
  }
  return null;
}

function fade(r, opacity) {
  if (opacity >= 1) return r;
  const out = new png.Raster(r.width, r.height);
  out.data.set(r.data);
  for (let i = 3; i < out.data.length; i += 4) {
    out.data[i] = Math.round(out.data[i] * opacity);
  }
  return out;
}

function mirror(r) {
  const out = new png.Raster(r.width, r.height);
  for (let y = 0; y < r.height; y++) {
    for (let x = 0; x < r.width; x++) {
      const s = ((y * r.width) + (r.width - 1 - x)) * 4;
      const d = ((y * r.width) + x) * 4;
      for (let c = 0; c < 4; c++) out.data[d + c] = r.data[s + c];
    }
  }
  return out;
}

const dir = path.join(ROOT, 'review', 'life');
fs.mkdirSync(dir, { recursive: true });

for (const seconds of instants) {
  const ms = Math.round(seconds * 1000);
  const atlas = png.load(path.join(ART, 'world', 'atlas_base.png'));
  for (const p of layout.props || []) {
    const r = frame(p.asset, 0);
    if (r) png.blit(atlas, r, Math.round(p.x / SCALE) - (p.anchorX || 0),
      Math.round(p.y / SCALE) - (p.anchorY || 0));
  }
  const report = [];
  for (const o of layout.overlays) {
    const cycle = o.frames * o.frameMillis * (o.playLoops || 1) + (o.intervalMillis || 0);
    const inCycle = ms % cycle;
    if ((o.intervalMillis || 0) > 0 && inCycle < o.intervalMillis && !o.path) continue;
    const inPlay = (o.intervalMillis || 0) > 0 ? Math.max(0, inCycle - o.intervalMillis) : ms;
    const index = Math.floor(inPlay / o.frameMillis) % o.frames;

    let x;
    let y;
    let flip = false;
    if (o.path) {
      const [fx, fy, dx] = foot(o.path, ms);
      const bob = ms === 0 || !o.path.bob ? 0
        : o.path.bob.amplitude * Math.sin(2 * Math.PI * ms / o.path.bob.periodMillis);
      x = fx - o.width * SCALE / 2;
      y = fy + bob - o.height * SCALE;
      if (o.path.flip && dx !== 0) {
        flip = (o.faces || 'east') === 'east' ? dx < 0 : dx > 0;
      }
    } else if (o.travel) {
      x = o.x + o.travel.x * (inPlay / 1000);
      y = o.y + o.travel.y * (inPlay / 1000);
    } else {
      x = o.x + (o.drift ? o.drift.x : 0) * (ms / 1000);
      y = o.y + (o.drift ? o.drift.y : 0) * (ms / 1000);
    }
    const ax = Math.round(x / SCALE);
    const ay = Math.round(y / SCALE);

    // Followers are composed on the host, then the whole group mirrors — the
    // same order the renderer uses, which is what makes the plume leave the
    // jaw in both directions.
    // The group is padded SYMMETRICALLY around the host, so mirroring the
    // padded raster mirrors about the host's centre — which is exactly what
    // `Transform.flip` on the renderer's Stack does, and what keeps a plume
    // 88 px along a 96 px body pointing out of the jaw in both directions.
    // The padding also has to be generous: the renderer's Stack is
    // `Clip.none`, so a follower that reaches past the host is drawn, and a
    // proof sheet that clipped it would under-report the plume.
    const PAD = 160;
    const group = new png.Raster(o.width + 2 * PAD, o.height + 2 * PAD);
    const bIndex = breathPhase(o, ms);
    if (o.cloud) {
      const c = frame(o.cloud.asset, Math.floor(ms / o.cloud.frameMillis) % o.cloud.frames);
      // The compositor multiplier the renderer applies. A storm at 1.0 buries
      // the drake it belongs to, so a sheet that ignored opacity would be
      // reviewing a different picture from the one the phone draws.
      if (c) png.blit(group, fade(c, o.cloud.opacity === undefined ? 1 : o.cloud.opacity),
        PAD + o.cloud.offset.x, PAD + o.cloud.offset.y);
    }
    const body = frame(o.asset, index);
    if (body) png.blit(group, body, PAD, PAD);
    if (bIndex !== null && o.breath) {
      const b = frame(o.breath.asset, bIndex);
      if (b) png.blit(group, b, PAD + o.breath.offset.x, PAD + o.breath.offset.y);
    }
    png.blit(atlas, flip ? mirror(group) : group, ax - PAD, ay - PAD);
    report.push(`  ${o.asset.padEnd(30)} atlas ${ax},${ay}`
      + `${o.path ? ' path' : ''}${flip ? ' flipped' : ''}`
      + `${bIndex !== null ? ` BREATH f${bIndex}` : ''}`);
  }
  png.save(path.join(dir, `${prefix}_t${seconds}_x1.png`), atlas);
  console.log(`t = ${seconds}s — ${report.length} overlays drawn`);
  for (const line of report) console.log(line);
}
if (missing.length) console.log(`MISSING: ${[...new Set(missing)].join(', ')}`);
