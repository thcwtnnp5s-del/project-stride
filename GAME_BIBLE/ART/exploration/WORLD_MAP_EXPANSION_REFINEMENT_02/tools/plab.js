// plab — direct MCP JSON-RPC client for the PixelLab endpoint.
//
// ## Why this exists
//
// The interactive MCP transport corrupts large inline base64 image arguments
// ('+' becomes whitespace in transit, and the server does not percent-decode),
// so any call that needs a real local image as input — edit_image,
// animate_image, inpaint_image, style/reference images for create_image_pro —
// cannot be made through it. WORLD_MAP_POLISH_03 §E records the same finding
// and the same fix: speak to the same endpoint with the same bearer token from
// a client we control, where base64 survives intact. That helper was never
// committed (recorded as a tooling gap); this one is.
//
// ## Credentials
//
// The bearer token is read at runtime from the user's own Claude config
// (~/.claude.json), from the pixellab MCP server entry's Authorization
// header — the exact credential the interactive session already uses. It is
// never printed, logged, or written anywhere by this script.
//
// ## Usage
//
//   node plab.js call <tool_name> <args.json> [--out result.json]
//   node plab.js image <job_id> <out_prefix>        # poll + save frames as PNG
//
// In <args.json>, any string value of the form "@file:relative/or/abs.png"
// is replaced with the file's clean base64 before sending.
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const ENDPOINT = 'https://api.pixellab.ai/mcp';

function token() {
  const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.claude.json'), 'utf8'));
  const entries = [];
  if (cfg.mcpServers && cfg.mcpServers.pixellab) entries.push(cfg.mcpServers.pixellab);
  for (const p of Object.values(cfg.projects ?? {})) {
    if (p.mcpServers && p.mcpServers.pixellab) entries.push(p.mcpServers.pixellab);
  }
  for (const e of entries) {
    const h = e.headers ?? {};
    for (const [k, v] of Object.entries(h)) {
      if (k.toLowerCase() === 'authorization' && v) return v;
    }
  }
  throw new Error('no pixellab Authorization header found in ~/.claude.json');
}

async function rpc(auth, sessionId, body) {
  const headers = {
    'content-type': 'application/json',
    accept: 'application/json, text/event-stream',
    authorization: auth,
  };
  if (sessionId) headers['mcp-session-id'] = sessionId;
  const res = await fetch(ENDPOINT, { method: 'POST', headers, body: JSON.stringify(body) });
  const sid = res.headers.get('mcp-session-id') ?? sessionId;
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 500)}`);
  let payload = text;
  if (text.startsWith('event:') || text.includes('\ndata:') || text.startsWith('data:')) {
    // SSE framing: take the last data: line, which carries the response.
    const datas = text.split('\n').filter((l) => l.startsWith('data:'));
    payload = datas[datas.length - 1].slice(5).trim();
  }
  return { sid, msg: payload ? JSON.parse(payload) : null };
}

async function session(auth) {
  const init = await rpc(auth, null, {
    jsonrpc: '2.0',
    id: 0,
    method: 'initialize',
    params: {
      protocolVersion: '2025-03-26',
      capabilities: {},
      clientInfo: { name: 'plab', version: '1.0' },
    },
  });
  if (init.msg && init.msg.error) throw new Error('initialize: ' + JSON.stringify(init.msg.error));
  await rpc(auth, init.sid, { jsonrpc: '2.0', method: 'notifications/initialized' });
  return init.sid;
}

function inlineFiles(value) {
  if (typeof value === 'string') {
    if (value.startsWith('@file:')) {
      return fs.readFileSync(value.slice(6)).toString('base64');
    }
    return value;
  }
  if (Array.isArray(value)) return value.map(inlineFiles);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = inlineFiles(v);
    return out;
  }
  return value;
}

async function callTool(name, args) {
  const auth = token();
  const sid = await session(auth);
  const { msg } = await rpc(auth, sid, {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: { name, arguments: args },
  });
  if (!msg) throw new Error('empty response');
  if (msg.error) throw new Error('tool error: ' + JSON.stringify(msg.error));
  return msg.result;
}

function textOf(result) {
  const parts = (result.content ?? []).filter((c) => c.type === 'text').map((c) => c.text);
  return parts.join('\n');
}

async function main() {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === 'call') {
    const [name, argsFile] = rest;
    const outIdx = rest.indexOf('--out');
    const args = inlineFiles(JSON.parse(fs.readFileSync(argsFile, 'utf8')));
    // The pro tool takes reference_images as a JSON-encoded string; authoring
    // it as a real array keeps @file inlining working, so restringify here.
    if (Array.isArray(args.reference_images)) {
      args.reference_images = JSON.stringify(args.reference_images);
    }
    const result = await callTool(name, args);
    const rendered = JSON.stringify(result, null, 2);
    if (outIdx !== -1) fs.writeFileSync(rest[outIdx + 1], rendered);
    // Print text content only (job ids, status); image payloads go to --out.
    process.stdout.write(textOf(result) || rendered.slice(0, 2000));
    return;
  }
  if (mode === 'image') {
    const [jobId, prefix] = rest;
    const result = await callTool('get_image', { job_id: jobId });
    const text = textOf(result);
    let n = 0;
    for (const c of result.content ?? []) {
      if (c.type === 'image' && c.data) {
        fs.writeFileSync(`${prefix}_f${n}.png`, Buffer.from(c.data, 'base64'));
        n += 1;
      }
    }
    // Long animations return only the first few frames inline; the rest sit
    // behind no-auth download URLs. Fetch whatever the text names beyond n.
    const m = text.match(/frames:\s*(\d+)[\s\S]*?download:\s*(https:\S+\?index=)0/);
    if (m) {
      const total = Number(m[1]);
      for (let i = n; i < total; i++) {
        const res = await fetch(`${m[2]}${i}`);
        if (!res.ok) throw new Error(`frame ${i}: HTTP ${res.status}`);
        fs.writeFileSync(`${prefix}_f${i}.png`, Buffer.from(await res.arrayBuffer()));
        n += 1;
      }
    }
    process.stdout.write(`${text}\nsaved ${n} frame(s) to ${prefix}_f*.png\n`);
    return;
  }
  throw new Error('usage: plab.js call <tool> <args.json> [--out r.json] | plab.js image <job_id> <prefix>');
}

main().catch((e) => {
  process.stderr.write(String(e && e.message ? e.message : e) + '\n');
  process.exit(1);
});
