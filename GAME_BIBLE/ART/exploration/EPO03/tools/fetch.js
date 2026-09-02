// fetch.js — download PixelLab result URLs to disk. Deterministic; no pixels change.
//   node fetch.js <url> <outfile>
//   node fetch.js --list <file-with-"url outfile"-lines>
'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
function get(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('http:') ? http : https;
    mod.get(url, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(get(res.headers.location));
      }
      if (res.statusCode !== 200) return reject(new Error(`${res.statusCode} ${url}`));
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}
async function one(url, out) {
  const bytes = await get(url);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, bytes);
  console.log(`${out}\t${bytes.length}`);
}
(async () => {
  const a = process.argv.slice(2);
  if (a[0] === '--list') {
    const lines = fs.readFileSync(a[1], 'utf8').split(/\r?\n/).filter((l) => l.trim() && !l.startsWith('#'));
    for (const l of lines) { const [u, o] = l.trim().split(/\s+/); await one(u, o); }
  } else {
    await one(a[0], a[1]);
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
