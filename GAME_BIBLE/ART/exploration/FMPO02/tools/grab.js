// grab.js — download all frames of a PixelLab job. node grab.js <jobid> <n> <outdir/prefix>
'use strict';
const { execFileSync } = require('child_process');
const path = require('path');
const [job, nS, prefix] = process.argv.slice(2);
const n = Number(nS);
const lines = [];
for (let i = 0; i < n; i++) {
  const url = n === 1
    ? `https://api.pixellab.ai/mcp/images/${job}/download`
    : `https://api.pixellab.ai/mcp/images/${job}/download?index=${i}`;
  lines.push(`${url} ${prefix}${i}.png`);
}
require('fs').writeFileSync(path.join(require('os').tmpdir(), 'grab.txt'), lines.join('\n'));
execFileSync(process.execPath, [path.resolve(__dirname, 'fetch.js'), '--list', path.join(require('os').tmpdir(), 'grab.txt')], { stdio: 'inherit' });
