// Project Stride - Code Render 01
// The standard visual output set, emitted from one place.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Not part of the app build, not referenced
// by any Flutter, Dart, Kotlin, Swift, or CI target.
//
// WHY THIS EXISTS
//
// Every exploration renderer already shares one scaler -- Surface.scale in
// surface.js -- so there was never duplicated scaling logic to consolidate.
// What was missing is that each render.js picked a single SCALE constant and
// wrote only that view. The result, found by VISUAL_STUDIO_BASELINE_AUDIT_01,
// was fifteen x8 files, three natives and NO x2 anywhere in the repository, so
// three Traveler passes were reviewed exclusively at the scale that flatters
// everything (PIXEL_ART_CRAFT_SPEC.md CR-41, MISTAKES.md M-04).
//
// This file is deliberately two small functions over the existing Surface. It
// is not a rendering framework and must not grow into one: no scene graph, no
// asset registry, no config format, no manifest. If a future task needs
// something structurally different, it writes its own renderer and keeps this
// one small.
//
// The standard output set is canonical in PIXEL_ART_CRAFT_SPEC.md section 8.1.
// This module implements views 1, 2, 3 and 5. View 4 (TRUE IN-CONTEXT) cannot
// live here, because compositing an asset into its real scene is scene
// knowledge, not tooling -- pass the composited Surface in as `context` and it
// is emitted at native and x2, which is what that view requires. An x8 crop is
// not a context view and this module offers no way to produce one.

'use strict';
const fs = require('fs');
const path = require('path');
const { Surface } = require('./surface');

// Collapse every non-transparent pixel to one ink index.
//
// The silhouette view answers the single question no other view can: is this a
// person carrying something? Interior colour, shading and detail cannot answer
// it and reliably disguise it (CR-20). Index 0 stays transparent.
function silhouette(surf, inkIndex) {
  const out = new Surface(surf.w, surf.h);
  for (let i = 0; i < surf.px.length; i++) out.px[i] = surf.px[i] === 0 ? 0 : inkIndex;
  return out;
}

// Write the standard output set for one asset.
//
//   outDir   directory to write into (created if absent)
//   name     base filename, no extension and no scale suffix
//   surf     the asset at native scale
//   palette  the palette to encode against
//   opts.context      Surface -- the asset composited into its real scene, at
//                     the real scale relationship. Emitted at native and x2.
//   opts.silhouetteInk  palette index; when present, emits the x2 silhouette.
//                     Required for major character design and rebuild work.
//
// Returns the list of files written, so a caller can report its own output set
// honestly rather than describing it.
function writeReviewSet(outDir, name, surf, palette, opts = {}) {
  fs.mkdirSync(outDir, { recursive: true });
  const written = [];
  const put = (suffix, s) => {
    const file = path.join(outDir, `${name}${suffix}.png`);
    fs.writeFileSync(file, s.png(palette));
    written.push(path.basename(file));
  };

  put('', surf);                 // 1. NATIVE
  put('_x2', surf.scale(2));     // 2. x2 PLAY-SCALE PROXY -- the verdict view
  put('_x8', surf.scale(8));     // 3. x8 INSPECTION -- never verdict scale

  if (opts.context) {            // 4. TRUE IN-CONTEXT, at native and x2
    put('_context', opts.context);
    put('_context_x2', opts.context.scale(2));
  }

  if (opts.silhouetteInk !== undefined) {   // 5. SILHOUETTE-ONLY
    put('_silhouette_x2', silhouette(surf, opts.silhouetteInk).scale(2));
  }

  return written;
}

module.exports = { silhouette, writeReviewSet };
