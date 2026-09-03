# EPO03 — PROD-WORLD-LIFE ledger

Cap **200 generations**. One row per submitted job; the cost column is the
tool's own line. Rejected rolls are output, and their reason is here.

## Task 1 — the landmark overlay rows (0 generations)

No PixelLab call. The four sprites were generated and packaged by
PROD-WORLD-LANDMARKS (`REQUESTS_LIFE.md`); LIFE only placed the `overlays`
rows it owns and dropped the three rows they supersede.

## Task 2 — the v6 behaviour system (0 generations)

Dart and JSON only.

## Task 3 — the dragons

| # | Asked | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | red plume 96x48, tongued cone, no body | create_image_pixen | `fa2dfe0d-0123-4e2e-b8b3-217de8bbf9fa` | ~1 generation | **ACCEPT (cropped, mirrored)** | The cone itself is exactly the brief — hard-edged, white-hot core, ember tail — but it widens WEST and ends in a rocket nozzle. Cropped to x 0–60 and mirrored (A-2), the nozzle is gone and the root is at the jaw. `review/life/breath_r1_x4.png` |
| 2 | red plume, spearhead flare | create_image_pixen | `9eb19231-96e6-4de9-a136-5061044d14b5` | ~1 generation | REJECT | Drew a firework on a stick: a solid object emitting the flame, which is the "no body" rule broken in one roll. `rejected/life/REJECTS_x5.png` |
| 3 | blue bolt 96x56, forked violet-white | create_image_pixen | `8223fd74-220e-479f-9d93-4827ee3b56ee` | ~1 generation | **ACCEPT** | A clean left-to-right fork with branch prongs and sparks, no creature, no teal. |
| 4 | storm cloud 112x48, ragged grey-violet | create_image_pixen | `9287fcb1-31f1-4cb2-afa9-da8bf191433e` | ~1 generation | REJECT | Grey, compact, no weather in it — a cloud, not a storm. |
| 5 | red plume, rounded fan | create_image_pixen | `b8cde601-dcc1-44b5-99cf-0d54965ab9c6` | ~1 generation | REJECT | A bare branch throwing a fireball. Same failure as #2 — the tool keeps attaching an emitter to a breath. |
| 6 | blue bolt, two-prong arc | create_image_pixen | `4b88dc21-9408-4f28-a4b6-29d7810acc23` | ~1 generation | REJECT | Drew a lizard made of lightning. "No animal" in the prompt is not a constraint the model honours; a third roll would not have fixed it. |
| 7 | storm cloud, slate lobes | create_image_pixen | `9c7c5ad1-1b03-4e34-92c6-9e482f3f6501` | ~1 generation | **ACCEPT** | Slate and violet, wide and flat, rain streaks under it. Reads as weather at map scale and keys to the drake. |
| 8 | animate the red cone, 8 f | animate_image | `adf427ee-263d-4b11-ab97-efa95998a39b` | ~1 generation | **ACCEPT (re-ordered)** | Nine good frames, but the sequence only ever decays. Played `[7,5,3,0,1,2,4,6]` so the plume grows, peaks and dies. Selection and order only (A-2). |
| 9 | animate the bolt: charge, strike, fade | animate_image | `24292b81-be4a-4728-bf73-8008095db791` | ~1 generation | **ACCEPT (re-ordered)** | The charge, the strike and the fade are all in the nine frames, in the wrong order. Played `[6,4,5,7,0,1,2,8]`: crackle, crackle, forming, STRIKE, full fork, decay, decay, sparks. |
| 10 | animate the storm cloud, 6 f | animate_image | `d4957e1e-81ec-4bdb-b591-412ca83a8a94` | ~1 generation | **ACCEPT** | Billow plus falling rain, silhouette stable across the loop. Frames 0–5. |

Two further deterministic passes on the accepted frames, both A-2, neither a
generation: the plume and bolt frames are **registered** so every frame's ink
starts at x = 0 (`animate_image` let the root wander up to 24 px, which on a
96 px body is the difference between fire leaving the jaw and fire floating in
front of the nose), and `overlay_wolfpair` is **box-reduced 2:1** to 28 x 22,
because it was drawn at twice the scale of the deer it shares ground with.

## Task 4 — the roster

| # | Asked | Tool | Job id | Cost | Verdict | Reason |
|---|---|---|---|---|---|---|
| 11 | mule train 24x24, two laden mules + drover | create_image_pixen | `2f4b6bb6-c446-4537-a2b9-e8558eec3bb7` | ~1 generation | **ACCEPT** | Three figures in single file, legible at map scale, never a lone walking figure (R-4). |
| 12 | fairy 24x24, winged silhouette, no face | create_image_pixen | `6316f45f-d2da-427e-9b66-60bc1a869246` | ~1 generation | REJECT | A moth on an **opaque brown box** — `no_background` failed outright, and DIR-04 forbids a fairy that reads as a square. |
| 13 | gulls 24x24 in flight | create_image_pixen | `18663351-7af6-4d63-b553-a63d704de4b7` | ~1 generation | **ACCEPT** | One clean gull, wings spread, transparent. One is enough: the loops carry different phases. |
| 14 | ptarmigan 16x16 on snow | create_image_pixen | `79f5f796-112e-4912-a85b-68b6d67770d8` | ~1 generation | **ACCEPT** | Plump, white, a dark eye — visible on snow without shouting. |
| 15 | ship 32x32, single mast, wake | create_image_pixen | `bb8855d2-01f7-4191-9828-141c3ecbb904` | ~1 generation | **ACCEPT** | The re-roll DIR-04 asked for: the shipped ship was 15 x 20 at one frame. |
| 16 | fairy, six-pixel body, empty air | create_image_pixen | `2e74ba44-ecac-453f-926f-4bdb8a196fa9` | ~1 generation | REJECT | A cherub with a solid gold halo and a large blue eye. A face, which the brief forbids by name. |
| 17 | fairy, winged sprite of light | create_image_pixen | `233d29c5-f014-4522-8f15-ebb92ea24df7` | ~1 generation | REJECT | An orange spiked shape; no wing, no glow, wrong key. **Three-failure stop on fairies** — see the report. |
| 18 | animate the mule train, 6 f | animate_image | `3e36ec92-5c72-405a-bc76-bfa19fec99f3` | ~1 generation | **ACCEPT** | Plodding walk, packs swaying, silhouette stable. Frames 0–5. |
| 19 | animate the gull, 4 f | animate_image | `e1639f35-f997-4f40-a036-19c1274ec0f2` | ~1 generation | **ACCEPT** | A full wingbeat cycle. |
| 20 | animate the ptarmigan, 4 f | animate_image | `cb6328f0-fe23-4d1b-a548-6424ebbecd7c` | ~1 generation | **ACCEPT** | A small hop and peck — subtle, which is what a snow bird should be. |
| 21 | animate the ship, 4 f | animate_image | `f3717dcf-a0c4-4b18-a75d-f274cb114396` | ~1 generation | **ACCEPT** | Rides a swell, wake breaking. |

## Total

Requested **21** · accepted **14** · rejected **7** · **family total ≈ 21
generations** of a 200 cap.

Rejected rolls: `rejected/life/REJECTS_x5.png`.
Accepted assets: `out/life/` (8 families, 52 frames, `manifest.json`).
Placement proofs: `review/life/LIFE_t{0,18,43,87}_x1.png`,
`dragons_x3.png`, `roster_placed_x3.png`.
