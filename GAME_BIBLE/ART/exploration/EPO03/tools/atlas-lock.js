// EPO03 — a file lock so package-art.js builds (which write 1,779 files under
// assets/ and read them back) are serialized across the world teams working
// in parallel. Previews (compose-preview.js) never need it.
//
//   node atlas-lock.js acquire <team>   waits (2 s poll, 5 min max) then holds
//   node atlas-lock.js release <team>   only the holder may release
//   node atlas-lock.js status
//   node atlas-lock.js break            a lock older than 10 min is stale
'use strict';
const fs = require('fs');
const path = require('path');
const LOCK = path.join(__dirname, '..', '.atlas.lock');
const [cmd, team] = process.argv.slice(2);
const STALE_MS = 10 * 60 * 1000;

function read() {
  try { return JSON.parse(fs.readFileSync(LOCK, 'utf8')); } catch (e) { return null; }
}
function sleep(ms) { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms); }

if (cmd === 'status') {
  const l = read();
  console.log(l ? `held by ${l.team} since ${l.at}` : 'free');
} else if (cmd === 'break') {
  const l = read();
  if (!l) { console.log('free'); process.exit(0); }
  if (Date.now() - Date.parse(l.at) < STALE_MS) {
    console.error(`lock held by ${l.team} for under 10 min — not stale; ask them to release`);
    process.exit(1);
  }
  fs.unlinkSync(LOCK); console.log(`broke stale lock held by ${l.team}`);
} else if (cmd === 'acquire') {
  if (!team) { console.error('usage: acquire <team>'); process.exit(2); }
  const deadline = Date.now() + 5 * 60 * 1000;
  for (;;) {
    try {
      fs.writeFileSync(LOCK, JSON.stringify({ team, at: new Date().toISOString() }), { flag: 'wx' });
      console.log(`lock acquired by ${team}`);
      process.exit(0);
    } catch (e) {
      const l = read();
      if (l && Date.now() - Date.parse(l.at) > STALE_MS) {
        try { fs.unlinkSync(LOCK); } catch (_) { /* raced */ }
        continue;
      }
      if (Date.now() > deadline) {
        console.error(`gave up after 5 min; lock held by ${l ? l.team : '?'}`);
        process.exit(1);
      }
      sleep(2000);
    }
  }
} else if (cmd === 'release') {
  const l = read();
  if (!l) { console.log('already free'); process.exit(0); }
  if (l.team !== team) { console.error(`lock is held by ${l.team}, not ${team}`); process.exit(1); }
  fs.unlinkSync(LOCK); console.log(`released by ${team}`);
} else {
  console.error('usage: node atlas-lock.js acquire|release <team> | status | break');
  process.exit(2);
}
