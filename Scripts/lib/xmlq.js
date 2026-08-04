#!/usr/bin/env node
// Semantic queries over the structured files the build guards inspect.
//
// ## Why this exists
//
// Three guard defects in this repository were one mistake: matching structured
// files with `grep` and removing comments with `sed`.
//
//   - the entitlements check matched the file's own prose about the
//     background-delivery key and failed a correct configuration
//   - the manifest check matched its own note saying `tools:overrideLibrary`
//     is deliberately absent
//   - the first "fix" dropped only lines STARTING with `<!--`, so every body
//     line of a multi-line comment survived
//
// A comment is a lexical construct. Removing it correctly is parsing, and
// half-parsing with a regex fails in the direction that makes a guard pass
// while the tree is wrong.
//
// ## Why xmldom, and not a parser written here
//
// An earlier version of this file hand-rolled a parser. That only moved the
// place where a guard can be silently wrong: a security decision resting on
// 120 lines of bespoke tokenizer is not obviously better than one resting on a
// regex. `@xmldom/xmldom` is pinned exactly in `Scripts/tooling/package.json`,
// has **zero transitive dependencies**, and is MIT.
//
// Node rather than Python `plistlib` for one reason: this development machine
// has no Python — `python` and `python3` both resolve to the Windows Store
// stub — and `Scripts/verify.sh` must run locally, not only in CI.
//
// ## Namespaces
//
// Attributes are resolved by **namespace URI and local name**, never by
// literal prefix text. `tools:overrideLibrary` and `t:overrideLibrary` are the
// same attribute if both prefixes bind to the Android tools namespace, and a
// guard that matched the string `tools:` would miss the second.
//
// ## Usage
//
//   xmlq.js <file> keys                       plist: top-level dict keys, in order
//   xmlq.js <file> has-key <key>              exit 0 if present exactly once
//   xmlq.js <file> string-for <key>           plist: the <string> for a key
//   xmlq.js <file> dupe-keys                  plist: keys appearing more than once
//   xmlq.js <file> parses                     document is readable; prints root name
//   xmlq.js <file> attr-ns <ns> <local> [el]  every element carrying that attribute
//                                             (<ns> is a URI or the alias
//                                             `android` / `android-tools`;
//                                             [el] narrows to one element)
//   xmlq.js <file> elements <localName>       every element with that local name
//
// Every mode exits 2 on a parse error, so malformed input fails closed. Every
// exit 2 also names its cause on stderr as `STRIDE_XMLQ[<reason>]`, one of
// `invalid_document`, `invalid_invocation` or `internal_failure` — see the exit
// contract below for why a guard is only allowed to act on the first.
'use strict';

const fs = require('fs');
const path = require('path');

const TOOLING = path.join(__dirname, '..', 'tooling', 'node_modules');
let DOMParser;
try {
  ({ DOMParser } = require(path.join(TOOLING, '@xmldom', 'xmldom')));
} catch (_) {
  try {
    ({ DOMParser } = require('@xmldom/xmldom'));
  } catch (_e) {
    // The reason token is written literally here, not via `dieInternal`. This
    // runs at module load, before the `const` reason tokens below have
    // initialised, so calling the helper would raise a ReferenceError from the
    // temporal dead zone and replace a clear diagnostic with a stack trace.
    console.error(
      'STRIDE_XMLQ[internal_failure] xmlq: @xmldom/xmldom is not installed.\n' +
        '  cd Scripts/tooling && npm ci',
    );
    process.exit(2);
  }
}

const ANDROID_TOOLS_NS = 'http://schemas.android.com/tools';
const ANDROID_NS = 'http://schemas.android.com/apk/res/android';

// Short names callers may use instead of a full URI. Resolution is always by
// URI; these exist so a guard does not have to embed the URI at every call
// site and get one of them subtly wrong.
const NS_ALIASES = {
  'android-tools': ANDROID_TOOLS_NS,
  android: ANDROID_NS,
};

// ---------------------------------------------------------------------------
// Exit contract — every caller depends on this being three-valued
// ---------------------------------------------------------------------------
//
//   0  valid document, query matched
//   1  valid document, query did NOT match
//   2  malformed document, invalid invocation, parser warning or error,
//      or any internal failure
//
// **Exit 2 must never be read as "the forbidden value is absent."** That was a
// live defect: xmldom throws on fatal errors rather than only calling
// `onError`, so an unparseable manifest crashed Node with exit 1 — which a
// caller testing `-ne 0` treats as a clean absence.
const EXIT_MATCH = 0;
const EXIT_NO_MATCH = 1;
const EXIT_ERROR = 2;

// ---------------------------------------------------------------------------
// Exit 2 has a REASON, and the reason changes what a guard is allowed to do
// ---------------------------------------------------------------------------
//
// Exit 2 is one code covering three unrelated events, and a guard needs to tell
// them apart:
//
//   invalid_document    the file was found, read, and is not a valid document
//                       under this repository's policy — malformed, a rejected
//                       doctype or entity, two roots, not the plist shape the
//                       query requires. The guard LOOKED and the tree is wrong.
//
//   invalid_invocation  the guard asked a question that cannot be asked — no
//                       mode, an unknown mode, a path that does not exist. The
//                       guard did not look at anything.
//
//   internal_failure    the dependency is missing, or something threw that has
//                       no other classification. The guard could not look.
//
// Only `invalid_document` may become a policy REJECTION (guard exit 1). The
// other two are infrastructure (guard exit 2) and must never satisfy a
// mutation test — otherwise deleting a file, breaking Node, or renaming a mode
// would each read as "the guard correctly rejected the violation", which is the
// exact over-determination that left three checks in this repository dead for
// their entire existence while their self-test read green.
//
// The reason is emitted as a machine-readable token on stderr. Callers match
// the token, never the prose.
const XMLQ_INVALID_DOCUMENT = 'invalid_document';
const XMLQ_INVALID_INVOCATION = 'invalid_invocation';
const XMLQ_INTERNAL_FAILURE = 'internal_failure';

function bail(reason, msg) {
  console.error(`STRIDE_XMLQ[${reason}] xmlq: ${msg}`);
  process.exit(EXIT_ERROR);
}

/** The document was read and is not valid. The only reason a guard may
 *  translate into a named policy rejection. */
function die(msg) {
  bail(XMLQ_INVALID_DOCUMENT, msg);
}

/** The question could not be asked: bad usage, unknown mode, absent file. */
function dieInvocation(msg) {
  bail(XMLQ_INVALID_INVOCATION, msg);
}

/** Anything else that stops xmlq answering. Never a policy statement. */
function dieInternal(msg) {
  bail(XMLQ_INTERNAL_FAILURE, msg);
}

/**
 * Lexical pre-scan for constructs the parser would accept but we will not.
 *
 * Done on raw text, skipping comments and CDATA, because a DOCTYPE is consumed
 * during parsing and an internal subset is not reliably exposed afterwards.
 *
 * A bare `<!DOCTYPE plist PUBLIC "..." "...">` is ALLOWED. That is the header
 * Apple's tooling writes into every plist and entitlements file, it declares no
 * entities, and xmldom performs no network access so the external identifier is
 * inert. Rejecting it outright would fail on correct, tool-generated files —
 * and Xcode re-adds it whenever the file is edited through its UI, so the guard
 * would break on a routine edit. That is the false-positive class this whole
 * parsing effort exists to remove.
 *
 * What IS rejected is the part that carries risk: an internal subset (`[ ... ]`)
 * and any ENTITY declaration. Those are the XXE and entity-expansion vectors.
 */
function prescan(text, file) {
  let i = 0;
  let doctypes = 0;
  let sawRootStart = false;
  const n = text.length;
  while (i < n) {
    if (text.startsWith('<!--', i)) {
      const e = text.indexOf('-->', i + 4);
      if (e === -1) die(`${file}: unterminated comment`);
      i = e + 3;
      continue;
    }
    if (text.startsWith('<![CDATA[', i)) {
      const e = text.indexOf(']]>', i + 9);
      if (e === -1) die(`${file}: unterminated CDATA`);
      i = e + 3;
      continue;
    }
    // Covers general (`<!ENTITY x ...>`) and parameter (`<!ENTITY % x ...>`)
    // declarations alike — the token is the same and both are refused.
    if (text.startsWith('<!ENTITY', i)) {
      die(
        `${file}: ENTITY declaration. Entity expansion is the XXE and ` +
          `billion-laughs vector, and nothing in this repository needs one.`,
      );
    }
    if (text.startsWith('<!DOCTYPE', i)) {
      doctypes++;
      let j = i + 9;
      while (j < n) {
        const c = text[j];
        if (c === '[') {
          die(
            `${file}: DOCTYPE with an internal subset. An internal subset may ` +
              `declare entities; only the exact Apple plist declaration is ` +
              `accepted, and it has none.`,
          );
        }
        if (c === '>') break;
        if (c === '"' || c === "'") {
          const close = text.indexOf(c, j + 1);
          if (close === -1) die(`${file}: unterminated DOCTYPE literal`);
          j = close + 1;
          continue;
        }
        j++;
      }
      if (j >= n) die(`${file}: unterminated DOCTYPE`);
      // Position: a DOCTYPE must precede the root element.
      if (sawRootStart) die(`${file}: DOCTYPE appears after the root element`);
      i = j + 1;
      continue;
    }
    if (text[i] === '<' && /[A-Za-z_]/.test(text[i + 1] || '')) sawRootStart = true;
    i++;
  }

  if (doctypes > 1) die(`${file}: ${doctypes} DOCTYPE declarations; at most one is valid`);
  return doctypes;
}

// The ONLY doctype this repository accepts, and only in a plist.
//
// Compared as parsed `DocumentType` fields, not as text, so whitespace and
// quote style are irrelevant — the thing being authorised is the declaration's
// identity, not its formatting.
const APPLE_PLIST_DOCTYPE = {
  name: 'plist',
  publicId: '-//Apple//DTD PLIST 1.0//EN',
  systemId: 'http://www.apple.com/DTDs/PropertyList-1.0.dtd',
};

/**
 * Enforces the doctype policy against the PARSED declaration.
 *
 * plist / entitlements: no doctype, or exactly the Apple one above.
 * AndroidManifest.xml and everything else: no doctype at all.
 *
 * The accepted Apple declaration is **metadata only**. It is never resolved:
 * xmldom does no I/O for external identifiers, and
 * `check-guard-parsers.sh` proves no network or filesystem resolution is
 * attempted by hooking `http`, `https`, `net` and `dns` around a parse.
 */
function enforceDoctype(doc, file, lexicalCount) {
  const dt = doc.doctype;
  const rootName = doc.documentElement.localName;

  // xmldom 0.9.x hands back publicId and systemId with their delimiting quotes
  // still attached. Those delimiters are formatting; the identifier is what is
  // being authorised.
  //
  // Deliberately NARROW. It removes at most ONE matching outer pair and then
  // stops:
  //
  //   * it never strips repeatedly, so `""x""` becomes `"x"` and fails the
  //     comparison rather than quietly resolving to `x`
  //   * mismatched delimiters are an error, not something to normalise away
  //   * nothing inside the identifier is touched, so ` -//Apple//...` with a
  //     leading space is REJECTED rather than trimmed into a match
  //
  // A lenient normaliser here would accept identifiers that are not the Apple
  // one, which is the entire thing this allowlist exists to prevent.
  const unquoteOnce = (raw, label) => {
    if (raw == null) return null;
    const s = String(raw);
    const isQuote = (c) => c === '"' || c === "'";
    const first = s[0];
    const last = s[s.length - 1];
    if (!isQuote(first) && !isQuote(last)) return s; // already bare
    if (s.length < 2 || !isQuote(first) || !isQuote(last) || first !== last) {
      die(`${file}: DOCTYPE ${label} has mismatched quote delimiters: ${s}`);
    }
    return s.slice(1, -1);
  };
  const publicId = unquoteOnce(dt && dt.publicId, 'publicId');
  const systemId = unquoteOnce(dt && dt.systemId, 'systemId');

  if (!dt) {
    // The lexical scan and the parser must agree. If they do not, something
    // was consumed that the DOM does not show, and guessing is not an option.
    if (lexicalCount > 0) {
      die(`${file}: a DOCTYPE was present but the parser did not expose it`);
    }
    return;
  }

  if (rootName !== 'plist') {
    die(
      `${file}: DOCTYPE declarations are not accepted here (root <${rootName}>). ` +
        `Only an Apple plist declaration is allowed, and only in a plist.`,
    );
  }

  if (dt.internalSubset) {
    die(`${file}: DOCTYPE carries an internal subset`);
  }
  if (dt.name !== APPLE_PLIST_DOCTYPE.name) {
    die(`${file}: DOCTYPE name is "${dt.name}", expected "${APPLE_PLIST_DOCTYPE.name}"`);
  }
  if (!publicId) {
    die(
      `${file}: SYSTEM-only DOCTYPE. Only the Apple PUBLIC declaration is ` +
        `accepted; a bare SYSTEM identifier is not.`,
    );
  }
  if (publicId !== APPLE_PLIST_DOCTYPE.publicId) {
    die(`${file}: DOCTYPE publicId is "${publicId}", not the Apple plist identifier`);
  }
  if (systemId !== APPLE_PLIST_DOCTYPE.systemId) {
    die(`${file}: DOCTYPE systemId is "${systemId}", not the Apple plist DTD URL`);
  }
}

/** Parses, or exits 2. Fails closed — a file we cannot read is not a pass. */
function parse(file) {
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch (e) {
    // INVOCATION, not document. A file that is not there is not a malformed
    // file: nothing was read, so nothing can be said about its validity. If
    // this were classified as a document problem, deleting a tracked plist
    // would read to a guard as "the plist is invalid, reject" — and a mutation
    // test could then be satisfied by the copy being incomplete.
    dieInvocation(`cannot read ${file}: ${e.message}`);
  }
  // Strip a UTF-8 BOM. xmldom treats it as content and the document then has
  // no root element, which would look like "malformed" for a valid file.
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);

  const lexicalDoctypes = prescan(text, file);

  // xmldom reports badness two ways, and both must land on exit 2.
  //
  // `onError` is called for recoverable problems; a FATAL one is *thrown* as a
  // ParseError. Handling only the callback let a malformed manifest crash Node
  // with a stack trace and exit 1 — which a caller checking `-ne 0` would treat
  // as "the attribute is absent". Found by this file's own parser suite, which
  // is the argument for having one.
  const problems = [];
  let doc;
  try {
    doc = new DOMParser({
      onError: (level, msg) => {
        // EVERY level, warnings included.
        //
        // A warning means xmldom recovered from something — an unbound prefix,
        // a duplicate attribute, stray content. Recovery is a guess, and a
        // guard that acts on a guessed document is deciding security policy
        // from a parser's best effort. Nothing in this repository's manifests
        // or plists should produce one, so a warning is a defect in the file.
        problems.push(`${level}: ${msg}`);
      },
    }).parseFromString(text, 'text/xml');
  } catch (e) {
    die(`${file} is not well-formed: ${e.message}`);
  }

  if (problems.length > 0) {
    die(`${file} is not well-formed:\n  ${problems.join('\n  ')}`);
  }
  if (!doc || !doc.documentElement) die(`${file} has no root element`);

  // Exactly one root, and nothing of substance beside it. xmldom will happily
  // hand back a document with two element children of the node tree; a guard
  // that queried it would be querying whichever one the parser preferred.
  let roots = 0;
  for (let c = doc.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1) roots++;
    // Text outside the root is content the document should not have. Comments
    // (8), processing instructions (7) and the doctype (10) are fine.
    else if (c.nodeType === 3 && c.nodeValue && c.nodeValue.trim() !== '') {
      die(`${file}: unexpected content outside the root element`);
    }
  }
  if (roots !== 1) die(`${file}: expected exactly one root element, found ${roots}`);

  enforceDoctype(doc, file, lexicalDoctypes);

  return doc;
}

function* walk(node) {
  yield node;
  for (let c = node.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1) yield* walk(c);
  }
}

/** Element children only — comments, text and PIs are not structure. */
function elementChildren(node) {
  const out = [];
  for (let c = node.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1) out.push(c);
  }
  return out;
}

function textOfRaw(el) {
  let s = "";
  for (let c = el.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 3 || c.nodeType === 4) s += c.nodeValue;
  }
  return s;
}

function textOf(el) {
  let s = '';
  for (let c = el.firstChild; c; c = c.nextSibling) {
    // Text and CDATA. A comment contributes nothing, which is the point.
    if (c.nodeType === 3 || c.nodeType === 4) s += c.nodeValue;
  }
  return s.trim();
}

/**
 * The TOP-LEVEL dict of an Apple plist, as an ordered list of [key, valueEl].
 *
 * Top-level only, deliberately. A key nested inside a child dict or array must
 * not satisfy a required top-level key — that is the difference between an
 * entitlement the system grants and a string sitting decoratively inside
 * another structure.
 */
function topLevelPairs(doc) {
  const root = doc.documentElement;
  // DOCUMENT, not invocation. These modes are only ever pointed at a tracked
  // plist or entitlements file, and such a file whose root is not <plist>, or
  // which has no single top-level <dict>, is an invalid document — a guard is
  // right to reject the tree for it. The mode being wrong for the file is a
  // question `parses` exists to answer without a schema opinion; the Android
  // guard asking a plist mode about a manifest is the defect that produced
  // that separation, and it no longer calls one.
  if (root.localName !== 'plist') {
    die(`not a plist (root is <${root.localName}>)`);
  }
  const dicts = elementChildren(root).filter((e) => e.localName === 'dict');
  if (dicts.length !== 1) {
    die(`plist root must contain exactly one <dict>, found ${dicts.length}`);
  }
  const kids = elementChildren(dicts[0]);
  const pairs = [];
  for (let i = 0; i < kids.length; i++) {
    if (kids[i].localName !== 'key') continue;
    pairs.push([textOf(kids[i]), kids[i + 1] || null]);
  }
  return pairs;
}

function main() {
  const [file, mode, a, b, c] = process.argv.slice(2);
  if (!file || !mode) {
    dieInvocation('usage: xmlq.js <file> <mode> [args]');
  }
  const doc = parse(file);

  switch (mode) {
    // Parseability ONLY. No schema opinion, no root-element opinion.
    //
    // `xmlq_parses` used to ask for `keys`, which is a plist mode: handed an
    // Android manifest it answered "not a plist" — exit 2, the same code as
    // "malformed" — and every caller reported three well-formed manifests as
    // unreadable XML. The bug is instructive rather than embarrassing: it is
    // exactly the collapse the tri-state contract exists to prevent, made by
    // the helper written to enforce it. A question about whether a document
    // can be read has to be asked without also asking what kind of document it
    // is.
    case 'parses': {
      console.log(doc.documentElement ? doc.documentElement.nodeName : '');
      process.exit(doc.documentElement ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    case 'keys': {
      for (const [k] of topLevelPairs(doc)) console.log(k);
      process.exit(topLevelPairs(doc).length > 0 ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    case 'dupe-keys': {
      const seen = new Map();
      for (const [k] of topLevelPairs(doc)) seen.set(k, (seen.get(k) || 0) + 1);
      for (const [k, n] of seen) if (n > 1) console.log(`${k}\t${n}`);
      break;
    }
    case 'has-key': {
      const hits = topLevelPairs(doc).filter(([k]) => k === a);
      // Exactly once. A duplicated security-sensitive key means two values are
      // present and which one applies is a parser detail, not a decision.
      process.exit(hits.length === 1 ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    // Typed requirements. Presence is not the property that matters.
    //
    // `NSHealthShareUsageDescription` present as an empty string still
    // terminates the app at the authorization call, and
    // `com.apple.developer.healthkit` present as the STRING "true" is not a
    // granted entitlement — it is a string. A guard that only asked "is the
    // key there" would pass both.
    case 'require-string': {
      const hits = topLevelPairs(doc).filter(([k]) => k === a);
      if (hits.length === 0) {
        console.error(`xmlq: ${file}: ${a} is absent from the top-level dict`);
        process.exit(EXIT_NO_MATCH);
      }
      if (hits.length > 1) {
        die(`${file}: ${a} is declared ${hits.length} times; which value applies is a parser detail`);
      }
      const v = hits[0][1];
      if (!v || v.localName !== 'string') {
        console.error(`xmlq: ${file}: ${a} is <${v ? v.localName : 'nothing'}>, expected <string>`);
        process.exit(EXIT_NO_MATCH);
      }
      // Non-empty AFTER trimming. A usage description of "   " satisfies a
      // length check and is, to iOS and to the player reading the permission
      // sheet, blank.
      //
      // Only the emptiness TEST trims. The value printed is the author's text
      // exactly as written — this guard decides whether a purpose string
      // exists, not what it should say.
      const raw = textOfRaw(v);
      if (raw.trim() === '') {
        console.error(
          `xmlq: ${file}: ${a} is empty or whitespace-only. iOS shows this ` +
            `string on the permission sheet; blank is not a purpose.`,
        );
        process.exit(EXIT_NO_MATCH);
      }
      console.log(raw);
      process.exit(EXIT_MATCH);
      break;
    }
    case 'require-true': {
      const hits = topLevelPairs(doc).filter(([k]) => k === a);
      if (hits.length === 0) {
        console.error(`xmlq: ${file}: ${a} is absent from the top-level dict`);
        process.exit(EXIT_NO_MATCH);
      }
      if (hits.length > 1) {
        die(`${file}: ${a} is declared ${hits.length} times`);
      }
      const v = hits[0][1];
      if (!v || v.localName !== 'true') {
        console.error(
          `xmlq: ${file}: ${a} is <${v ? v.localName : 'nothing'}>, expected <true/>. ` +
            `A <string>true</string> is not a granted entitlement.`,
        );
        process.exit(EXIT_NO_MATCH);
      }
      process.exit(EXIT_MATCH);
      break;
    }
    // The <string> members of a top-level <array>, one per line.
    //
    // Needed because orientations are an array, and the guard must read their
    // VALUES. An `elements string` sweep returns element names and would have
    // reported zero landscape entries no matter what the file said — a check
    // that could not fail, caught by this guard's own self-test.
    case 'array-strings': {
      const hit = topLevelPairs(doc).find(([k]) => k === a);
      if (!hit || !hit[1]) process.exit(EXIT_NO_MATCH);
      const arr = hit[1];
      if (arr.localName !== 'array') {
        console.error(`xmlq: ${file}: ${a} is <${arr.localName}>, expected <array>`);
        process.exit(EXIT_NO_MATCH);
      }
      let n = 0;
      for (let c = arr.firstChild; c; c = c.nextSibling) {
        if (c.nodeType === 1 && c.localName === 'string') {
          n++;
          console.log(textOf(c));
        }
      }
      process.exit(n > 0 ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    case 'string-for': {
      const hit = topLevelPairs(doc).find(([k]) => k === a);
      if (!hit || !hit[1]) process.exit(EXIT_NO_MATCH);
      console.log(hit[1].localName === 'string' ? textOf(hit[1]) : `<${hit[1].localName}>`);
      break;
    }
    // <file> attr-ns <ns-or-alias> <local-name> [element-local-name]
    //
    // The optional third argument narrows to one element type. Without it the
    // check-android-target guard could not ask "is minSdkVersion declared on
    // <uses-sdk>" without also matching it anywhere else — and the workaround
    // it reached for instead was a mode named `attr` that does not exist in
    // this file at all. Three checks called it, every call exited 2 into
    // `|| true`, and all three had been dead since they were written.
    case "attr-ns": {
      let matched = 0;
      // Resolved by namespace URI + local name. Never by prefix text: a file
      // may bind the tools namespace to any prefix it likes.
      const ns = NS_ALIASES[a] || a;
      const wantEl = c || null;
      for (const el of walk(doc.documentElement)) {
        if (!el.attributes) continue;
        if (wantEl && el.localName !== wantEl) continue;
        for (let i = 0; i < el.attributes.length; i++) {
          const at = el.attributes.item(i);
          if (at.localName === b && at.namespaceURI === ns) {
            matched++;
            console.log(`${el.localName}\t${at.localName}\t${at.value}`);
          }
        }
      }
      // Three-valued, like every other mode: 0 found, 1 not found. A caller
      // that only inspected stdout could not tell "no match" from "the parser
      // gave up", which is the distinction the whole contract exists for.
      process.exit(matched > 0 ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    case 'elements': {
      let matched = 0;
      for (const el of walk(doc.documentElement)) {
        if (el.localName !== a) continue;
        matched++;
        const named = el.getAttribute ? el.getAttribute('android:name') || '' : '';
        console.log(`${el.localName}\t${named}`);
      }
      process.exit(matched > 0 ? EXIT_MATCH : EXIT_NO_MATCH);
      break;
    }
    default:
      // A mode that does not exist is INVOCATION. Three checks in
      // check-android-target.sh called a mode named `attr` that has never been
      // in this file; every call exited 2 into `|| true` and all three were
      // dead from the day they were written. Classifying this as a document
      // problem would let a guard translate a typo into a policy rejection —
      // and a mutation test would then pass on the typo.
      dieInvocation(`unknown mode ${mode}`);
  }
}

if (require.main === module) {
  // Nothing may escape as an unclassified crash. An uncaught throw exits Node
  // with code 1, which is the caller's "valid document, no match" — the exact
  // inversion the tri-state contract exists to prevent, and one this file has
  // already suffered once when xmldom threw on a fatal parse error.
  try {
    main();
  } catch (e) {
    dieInternal(`unhandled failure: ${(e && e.stack) || e}`);
  }
}

module.exports = {
  parse,
  topLevelPairs,
  walk,
  textOf,
  ANDROID_TOOLS_NS,
  XMLQ_INVALID_DOCUMENT,
  XMLQ_INVALID_INVOCATION,
  XMLQ_INTERNAL_FAILURE,
};
