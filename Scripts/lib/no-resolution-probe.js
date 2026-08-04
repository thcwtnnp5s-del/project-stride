#!/usr/bin/env node
// Executable evidence that parsing a document carrying the approved Apple
// external identifier resolves nothing.
//
// The allowlist permits:
//
//   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
//                          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
//
// That URL is **metadata**. If the parser ever fetched it, a build guard would
// depend on apple.com being reachable, CI would fail offline, and a document
// under someone else's control could point a resolver anywhere — which is XXE
// with extra steps.
//
// "xmldom does not do network I/O" is a claim about someone else's code. This
// makes it a measurement.
//
// ## Why this must be its own process
//
// An earlier version loaded xmldom at the top and installed probes afterwards.
// That proves less than it appears to: a module already in `require.cache` can
// have done anything it liked before the probes existed. So this script runs
// as a fresh process, asserts the parser is **not yet cached**, installs the
// probes, and only then loads it.
//
// ## Ordering
//
//   1. fixture text into memory (no parser loaded yet)
//   2. assert xmlq.js and @xmldom/xmldom are absent from require.cache
//   3. install probes
//   4. load the parser THROUGH the probes
//   5. parse
//   6. assert every counter is zero
//
// `--prove-detection` demonstrates the counters work, by deliberately tripping
// both a blocked `require` and a blocked call. Without it, "all zero" is
// equally consistent with "the probes were never wired up".
'use strict';

const fs = require('fs');
const path = require('path');
const Module = require('module');

const XMLDOM_DIR = path.join(__dirname, '..', 'tooling', 'node_modules', '@xmldom', 'xmldom');
const XMLQ = path.join(__dirname, 'xmlq.js');

// --- step 1: the fixture, before any parser exists in this process ---------
const APPLE_DOCTYPE_DOC = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.healthkit</key>
  <true/>
  <key>NSHealthShareUsageDescription</key>
  <string>Stride reads your step count.</string>
</dict>
</plist>
`;

// --- step 2: prove the process is cold ------------------------------------
const cached = Object.keys(require.cache).filter(
  (k) => k.includes('xmldom') || k.endsWith(`${path.sep}xmlq.js`),
);
if (cached.length > 0) {
  console.error('no-resolution-probe: the parser was ALREADY LOADED before probing:');
  for (const c of cached) console.error(`  ${c}`);
  console.error('  This probe proves nothing unless it runs in a fresh process.');
  process.exit(2);
}

// --- step 3: probes --------------------------------------------------------
const hits = Object.create(null);
const note = (what) => {
  hits[what] = (hits[what] || 0) + 1;
};

const NETWORK_MODULES = ['http', 'https', 'net', 'tls', 'dns', 'dns/promises', 'child_process', 'undici'];

function poison(name, members) {
  let mod;
  try {
    mod = require(name);
  } catch (_) {
    return;
  }
  for (const m of members) {
    if (typeof mod[m] !== 'function') continue;
    mod[m] = function poisoned() {
      note(`${name}.${m}`);
      throw new Error(`no-resolution-probe: ${name}.${m} was called`);
    };
  }
}

poison('http', ['get', 'request']);
poison('https', ['get', 'request']);
poison('net', ['connect', 'createConnection']);
poison('tls', ['connect']);
poison('dns', ['lookup', 'resolve', 'resolve4', 'resolve6']);
poison('child_process', ['exec', 'execSync', 'spawn', 'spawnSync', 'execFile', 'execFileSync']);

if (typeof globalThis.fetch === 'function') {
  globalThis.fetch = function poisonedFetch() {
    note('globalThis.fetch');
    throw new Error('no-resolution-probe: fetch was called');
  };
}

// A late `require` of a network module would sidestep the poisoning above, so
// the loader itself is watched. Module loading for the parser's OWN files is
// expected and not counted.
const originalLoad = Module._load;
Module._load = function guardedLoad(request) {
  if (NETWORK_MODULES.includes(request)) note(`require(${request})`);
  return originalLoad.apply(this, arguments);
};

// Filesystem reads are counted only while PARSING. Loading the parser's source
// is a legitimate read and is not the thing under test — Node's loader uses
// internal bindings rather than these exported functions, but the flag makes
// the intent explicit rather than relying on that.
let watchingFs = false;
const fsOriginals = {};
for (const m of ['readFileSync', 'readFile', 'openSync', 'open', 'createReadStream']) {
  if (typeof fs[m] !== 'function') continue;
  fsOriginals[m] = fs[m];
  fs[m] = function watchedFs(...args) {
    if (watchingFs) {
      note(`fs.${m}(${String(args[0]).slice(0, 60)})`);
      throw new Error(`no-resolution-probe: fs.${m} was called during parse`);
    }
    return fsOriginals[m].apply(this, args);
  };
}

// --- step 4: load the parser THROUGH the probes ---------------------------
let DOMParser;
try {
  ({ DOMParser } = require(XMLDOM_DIR));
  // The query layer too, so its own module-level work is under observation.
  require(XMLQ);
} catch (e) {
  console.error(`no-resolution-probe: could not load the parser: ${e.message}`);
  console.error('  Run: bash Scripts/bootstrap-tooling.sh');
  process.exit(2);
}

// --- step 5: parse ---------------------------------------------------------
let parsed = false;
let parseError = null;
watchingFs = true;
try {
  if (process.argv.includes('--prove-detection')) {
    try {
      require('https').get('https://www.apple.com/DTDs/PropertyList-1.0.dtd');
    } catch (_) {
      // Expected: the poisoned function counts, then throws.
    }
  }
  const doc = new DOMParser({ onError: () => {} }).parseFromString(APPLE_DOCTYPE_DOC, 'text/xml');
  parsed = !!(doc && doc.documentElement);
} catch (e) {
  parseError = e;
}
watchingFs = false;

// --- step 6: restore and report -------------------------------------------
Module._load = originalLoad;
for (const [m, fn] of Object.entries(fsOriginals)) fs[m] = fn;

const counts = Object.entries(hits);
if (parseError && counts.length === 0) {
  console.error(`no-resolution-probe: parsing threw: ${parseError.message}`);
  process.exit(2);
}
if (counts.length > 0) {
  console.error('no-resolution-probe: EXTERNAL RESOLUTION ATTEMPTED');
  for (const [k, n] of counts) console.error(`  ${k} x${n}`);
  process.exit(1);
}
if (!parsed) {
  console.error('no-resolution-probe: the document did not parse');
  process.exit(2);
}

console.log(
  'no-resolution-probe: OK -- cold process, probes installed BEFORE the parser ' +
    'was loaded, Apple external identifier parsed, nothing resolved ' +
    '(Module._load, http, https, net, tls, dns, fetch, child_process, fs all silent)',
);
