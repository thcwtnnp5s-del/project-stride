// WMER02 placement sweep: every overlay's emitted box — at origin and, for
// travelling overlays, at the travel endpoint — against location hit
// circles, landmark/rumor glyph points and route polyline points. Reports
// any intersection or near graze (<24 world px). Read-only.
'use strict';
const path = require('path');
const j = require(path.join(__dirname, '..', '..', '..', '..', '..', 'assets', 'content', 'v1', 'atlas', 'atlas_layout.json'));

const boxes = [];
for (const o of j.overlays) {
  const w = o.width * j.scale;
  const h = o.height * j.scale;
  boxes.push({ id: o.asset, x: o.x, y: o.y, w, h, phase: 'origin' });
  if (o.travel && (o.travel.x || o.travel.y)) {
    const activeMs = o.frames * o.frameMillis * (o.playLoops ?? 1);
    const dx = (o.travel.x * activeMs) / 1000;
    const dy = (o.travel.y * activeMs) / 1000;
    boxes.push({ id: o.asset, x: o.x + dx, y: o.y + dy, w, h, phase: 'endpoint' });
  }
}

const points = [];
for (const l of j.locations) points.push({ id: l.id, x: l.x, y: l.y, r: l.hitRadius });
for (const l of j.landmarks) points.push({ id: l.id, x: l.x, y: l.y, r: 60 });
for (const r of j.rumors) points.push({ id: r.id, x: r.x, y: r.y, r: 60 });
for (const r of j.routes) for (const [x, y] of r.points) points.push({ id: `route ${r.from}->${r.to}`, x, y, r: 20 });

const MARGIN = 24;
let findings = 0;
for (const b of boxes) {
  for (const p of points) {
    const cx = Math.max(b.x, Math.min(p.x, b.x + b.w));
    const cy = Math.max(b.y, Math.min(p.y, b.y + b.h));
    const d = Math.hypot(p.x - cx, p.y - cy);
    if (d < p.r + MARGIN) {
      findings += 1;
      const kind = d < p.r ? 'INTERSECTS' : 'grazes';
      console.log(`${b.id} (${b.phase}) ${kind} ${p.id} — clearance ${(d - p.r).toFixed(0)} world px`);
    }
  }
  if (b.x < 0 || b.y < 0 || b.x + b.w > j.world.width || b.y + b.h > j.world.height) {
    findings += 1;
    console.log(`${b.id} (${b.phase}) leaves the world: ${b.x},${b.y} ${b.w}x${b.h}`);
  }
}
console.log(findings ? `${findings} finding(s)` : 'clean: no overlay box touches a hit circle, glyph or route point');
