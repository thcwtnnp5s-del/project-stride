# EPO03 — requests to PROD-WORLD-LIFE

`assets/content/v1/atlas/atlas_layout.json`: PROD-WORLD-LIFE owns `overlays`;
PROD-WORLD-LANDMARKS owns `props` and `landmarks`. Everything below is an
`overlays` edit, so it is LIFE's to make. If LIFE finishes before these land,
LANDMARKS places them itself after re-reading the file.

---

## 2026-09-02 · PROD-WORLD-LANDMARKS · four overlay rows for the three landmarks

**What.** Add the four rows below to `overlays`, and remove the three rows they
supersede in slot. Net **+1** overlay — DIR-03's arithmetic, and DIR-04 already
frees `overlay_lantern` and both breath slots on LIFE's own kill list, so the
40-slot budget is not exceeded (R-9 needs no raise).

**Why.** The three fantasy landmarks stopped being props this round. The fairy
castle, the storm house and the ice tower are painted INTO the atlas as regions
(`E/out/atlas/manifest_landmarks.json`), which is also why they now survive
overview zoom, where props are hidden. The motion that sits on the painting is
these four overlays. All four sprites are **packaged and on disk** under
`assets/art/v1/env/` (LANDMARKS' own block in `package-art.js`, header
"EPO03 LANDMARKS"); `--check` and the palette guard are green on them.

**Remove these three rows** (their files stay packaged until the producer
retires the emitters at closeout — nothing else references them):

```jsonc
{"asset":"env/overlay_fairy_motes","x":1752,"y":2544, ... }        // five toned discs (D0033 §6 / Q-28)
{"asset":"env/overlay_storm_lightning","x":1164,"y":4908, ... }    // a 6 %-duty bolt over nothing
{"asset":"env/overlay_ice_beacon","x":2664,"y":588, ... }          // sat on a pedestal that no longer exists
```

**Add these four rows, verbatim** (schema v5 fields only; `x,y` are the sprite
TOP-LEFT in world px = atlas x 6):

```json
{"asset":"env/overlay_fae_court","x":1800,"y":2400,"width":112,"height":80,"frames":16,"frameMillis":220,"playLoops":3,"intervalMillis":14000,"drift":{"x":0,"y":0},"opacity":1}
```
```json
{"asset":"env/overlay_storm_rain","x":1020,"y":5136,"width":96,"height":96,"frames":8,"frameMillis":120,"playLoops":6,"intervalMillis":9000,"drift":{"x":0,"y":0},"opacity":0.55}
```
```json
{"asset":"env/overlay_storm_strike","x":1068,"y":4848,"width":80,"height":96,"frames":8,"frameMillis":100,"playLoops":1,"intervalMillis":11000,"drift":{"x":0,"y":0},"opacity":1}
```
```json
{"asset":"env/overlay_ice_beacon_sweep","x":2520,"y":696,"width":96,"height":96,"frames":10,"frameMillis":260,"playLoops":2,"intervalMillis":9000,"drift":{"x":0,"y":0},"opacity":1}
```

**Order.** `overlay_storm_rain` must sit **before** `overlay_storm_strike` in
the array: overlays paint in JSON array order and the strike's ground flash has
to land on top of the rain, not under it.

**Note on the beacon's name.** It is `overlay_ice_beacon_sweep`, not
`overlay_ice_beacon`. The old beacon is 48 x 80 x 7 f and the new one is
96 x 96 x 10 f; re-emitting the old path at a new canvas would have failed
`atlas_layout_test` the instant it landed, hours before the team that owns the
row could swap it. A new path keeps the tree green in both directions.

**Placement evidence** (composited onto the shipped atlas at exactly these
coordinates, before the rows exist):
`GAME_BIBLE/ART/exploration/EPO03/review/landmarks/PLACEMENT_f4_*.png`.

**Two rows are dated.** `overlay_storm_rain` and `overlay_storm_strike` sit on
terrain LANDMARKS has not painted yet (L2 waits for PROD-WORLD-SOUTH's region
over y 816-992; L1 waits for PROD-WORLD-WEST's core face). The coordinates are
DIR-03's and will not move — the paint underneath them is what is still coming.
