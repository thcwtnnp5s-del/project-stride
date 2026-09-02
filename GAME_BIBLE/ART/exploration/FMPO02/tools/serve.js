// serve.js — read-only static file server for PixelLab reference URLs.
// Serves ONLY the directories listed below; never the repo root.
//   node serve.js <port>
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const ALLOW = {
  '/fmpo02/': path.join(ROOT, 'GAME_BIBLE', 'ART', 'exploration', 'FMPO02'),
  '/vawo01/': path.join(ROOT, 'GAME_BIBLE', 'ART', 'exploration', 'VAWO01'),
  '/art/': path.join(ROOT, 'assets', 'art', 'v1'),
  '/ui/': path.join(ROOT, 'assets', 'ui', 'v1'),
};
const port = Number(process.argv[2] || 8787);
http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const prefix = Object.keys(ALLOW).find((p) => url.startsWith(p));
  if (!prefix) { res.writeHead(404); return res.end('no'); }
  const file = path.normalize(path.join(ALLOW[prefix], url.slice(prefix.length)));
  if (!file.startsWith(ALLOW[prefix]) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); return res.end('no');
  }
  const ext = path.extname(file).toLowerCase();
  const type = ext === '.png' ? 'image/png' : ext === '.jpg' ? 'image/jpeg' : 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`serving on ${port}`));
