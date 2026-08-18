# TRANSFORMATION_01 — stream E: Traveler ambient scenes + orange cat

```
STATUS: round record · presentation-only idle art · NOT CANON
Author: stream E (PixelLab production). QA VERDICT lines are left blank for Visual QA (M-04).
```

Date 2026-08-17/18. Governed by `../ART_DIRECTION_BRIEF.md` (§4 tone), `PIXELLAB_STYLE_SPEC_01.md`,
`RULES.md` A-1/A-2. Nothing here grants resources or XP or implies a pet system; the cat is a
companion sprite, nothing more (`FRESH_CHAT_HANDOFF_2026_08_17.md` §16).

## 0. Spend

Nominal PixelLab generations issued by this stream, from the tool's own cost lines:

| What | Calls | Gens |
|---|---|---|
| Traveler `animate_character` v3, 64px, south (18) + east (1) + one 96×64 combined | 19 | 19 |
| Cat `create_character` standard, quadruped `cat`, 24px, 4 dir | 1 | 1 |
| Cat template anims (`walk-6-frames` ×3 dirs, `sitting` south, `sitting` east) | 5 | 5 |
| Cat `animate_character` v3, east (sit-idle, roll, bat-yarn, stretch, sleep, sleep-breathe w/ custom start) | 6 | 6 |
| `create_image_pixen` (yarn ×2, campfire, a 24px cat that was not used) | 4 | 4 |
| `animate_image` (campfire flicker) | 1 | 1 |
| `create_map_object` (a 32px sitting cat, too big — not used) | 1 | 1 |
| **Total** | **37** | **37** (budget 220) |

`get_balance` went 1119 → 828 during the session, but the account is shared with the other
streams running concurrently, so that delta is not this stream's spend. Budget from the
per-call cost lines above (the STABILIZATION_01 lesson: budget from the quoted figure).

## 1. Method

- Every Traveler scene: `animate_character(c82b7da5…, mode="v3", frame_count=8|10, keep_first_frame=true, directions=["south"])`.
  Frame 0 of every result is the south idle rotation, so the rest pose is exact. Output canvas is
  88×88 (character 64 + 40 %); the figure sits at (27..58, 13..74), i.e. the shipped 64×64
  south sprite offset by (12,12). Packaging crops at that offset, so the anchor matches
  `sprite/traveler_south.png` exactly (feet on row 62).
- v3 frames arrive with ~46 colours against the reference's 31 (D-8 drift, mean distance ~21).
  Packaging **remaps every generated pixel to the nearest reference-palette colour** when the
  distance is ≤ 48 (allowed by A-2: palette/index remap); colours further away (the pale
  pick head, the flask) are kept. Result: every Traveler scene ships in exactly the 31 idle
  colours (`ambient_sheet_x8.png` shows no shading loss; `qa/_remap_check.png` is a before/after).
- Zero semi-transparent pixels arrived in any frame; the alpha quantiser (threshold 128) never fired.
- The cat is a PixelLab **character** (`4a7e4acd-3a3c-45ba-b140-36641d48ab6c`, "Stride Orange
  Cat", quadruped template `cat`, 24 px → 36 canvas). Its side view is the good one (17 px tall,
  rust-orange, one dark outline, flat shading — matches the Traveler's scarf tone). The
  front view is a 10 px wide stick and is not used. All cat assets ship on one 40×40 canvas
  (template frames padded 36→40 by +2,+2; v3 frames are 40 native), feet on row 27, palette
  remapped to the east rotation's 37 colours the same way.
- Tools: `tools/fetch_char.js` (frame download), `tools/inspect.js` (bounds/alpha/colour +
  ×1/×2/×8 sheets), `tools/palcheck.js`, `tools/palstep.js` (D-8), `tools/package.js`
  (crop/quantise/remap → `out/ambient/`, `manifest.json`, `qa/ambient_sheet_x{1,2,8}.png`),
  `tools/context.js` (`qa/ambient_context_x2.png`). Later fetches used the character zip
  (`/mcp/characters/<id>/download`, 423 while jobs pend) — far cheaper than `get_character`.

## 2. Accepted (`out/ambient/`, manifest.json is the contract)

Baseline = lowest opaque row. Traveler 64-canvas scenes: row 62 in every frame unless noted.

| id | src anim (group) | frames kept | fps | loop | canvas | baseline | notes |
|---|---|---|---|---|---|---|---|
| traveler_stretch | amb_stretch (8889d389) | 0–5 of 9 | 6 | pingpong | 80 | 70 | arms overhead; source 6–8 are arms-out holds; frame 3 spans 67 px → 80 canvas |
| traveler_drink | amb_drink (6b4ec9d6) | 0–8 | 8 | loop | 64 | 62 | flask up, drink, down; f8 ≈ idle |
| traveler_eat | amb_eat (3f2b0168) | 0–8 | 8 | pingpong | 64 | 62 | bowl in hand, hand to mouth |
| traveler_pack_check | amb_pack_check (72667ada) | 0–5 of 11 | 6 | pingpong | 64 | 62 | swings pack to front, looks in; 6–10 dropped (pack became a slatted crate) |
| traveler_axe_inspect | amb_axe_wipe (d308e823) | 0–6 of 9 | 6 | pingpong | 64 | 62 | axe held level, looked over; the cloth never appeared → renamed "inspect" |
| traveler_pick_inspect | amb_pick_inspect (6e18d27d) | 0–8 | 7 | loop | 80 | 70 | pick raised, head tapped, lowered; head is pale blue-grey steel (5 off-palette colours kept) |
| traveler_head_scratch | amb_look_around (7c220f96) | 0–8 | 8 | loop | 64 | 62 | hand to back of head, looks about |
| traveler_wipe_brow | amb_wipe_brow (676e0855) | 0,1,2,3,6,7,8 | 7 | loop | 64 | 62 | source 4–5 dropped: a 3-px white "sweat" fleck by the head reads as an emote |
| traveler_sit_ground | amb_sit_ground (3a281cce) | 0–10 | 6 | pingpong | 64 | 62 | sits cross-legged, holds, rises |
| traveler_pushups_side | amb_pushups_side (55ad82b9) | 0–10 | 6 | pingpong | 80 | 70 (69 in f4–5) | **east-facing**; frame 0 is the east idle. Plank spans 62 px → 80 canvas |
| traveler_dangle_string | amb_dangle_string (96f8b228) | 0–8 | 7 | pingpong | 64 | 62 | arm out, dark string bobbing; string end ≈ (0–3, 42–50) for the cat |
| traveler_read | amb_read2 (58f716af) | 0–8 | 6 | pingpong | 64 | 62 | **MARGINAL** — head bowed over a small pale thing in both hands; the book is 3–4 px |
| traveler_crouch_pet | amb_crouch_pet (02fd58c3) | 0–10 | 7 | loop | 64 | 62 (63 in f6) | **joint use only** — crouches, one hand to ≈ (14–18, 56–60); alone it could read as gathering |
| pair_pet_cat | amb_pet_cat_combined (4630297e) | 0–10 | 7 | loop | 96×64 | 62 | one combined sprite: Traveler leans down and reaches to the cat, cat looks up; start frame composed from idle + cat_sit_down f7 at (12,37); cat drifts ≈ 2 px left; not palette-remapped |
| cat_stand | east rotation | 1 | – | static | 40 | 27 | |
| cat_walk | cat_walk east (cdcf1902) | 0–5 | 8 | loop | 40 | 27 (26 in 3 frames) | template `walk-6-frames`, faces right |
| cat_walk_west | cat_walk west | 0–5 | 8 | loop | 40 | 27 | generated west, not mirrored |
| cat_sit_down | cat_sitting_east (fe2cb5dd) | 0–7 | 6 | pingpong | 40 | 27 | template `sitting`: stand → sits on haunches (f7 = seated hold) |
| cat_settle | cat_sit_idle_v3 (78f6940c) | 0–6 | 5 | pingpong | 40 | 27 | asked for sit-with-tail-flick, got stand → lie down; kept as "settle" |
| cat_lie_rest | cat_sleep_breathe_v3 (ea94eca4) | 1–4 | 3 | loop | 40 | 27 | custom start = cat_settle f6; chains after cat_settle; eye stays open (resting, not asleep) |
| cat_roll | cat_roll_v3 (5d0da186) | 0–8 | 7 | pingpong | 40 | 27 (26 late) | onto side, onto back, paws up |
| cat_bat_yarn | cat_bat_yarn_v3 (3ee21b1f) | 1–8 of 9 | 8 | loop | 40 | 27 | red yarn ball baked into the frames; f0 (no ball) dropped |
| cat_stretch | cat_stretch_v3 (c9cedcff) | 0–6 | 6 | pingpong | 40 | 27 | **MARGINAL** — late frames read long / pounce-like |
| prop_fire | pixen 8e2babee → animate_image b3411dbd | 0–3 | 6 | loop | 32 | 28 | three logs, low flame; 32×32 not 24×32 (pixen needs a square canvas below 32) |
| prop_yarn | pixen 979c166c (seed 7) | 1 | – | static | 16 | 12 | matte red ball, loose strand |

Ambient scene count: **13 Traveler scenes** (11 solo + 2 joint) + **9 cat actions** + 2 props.

## 3. Rejected / not used

| Candidate | Why |
|---|---|
| amb_read (1ebccc7f) | no book at all — hands fiddling at the chest |
| amb_sit_rest (ec334d39) | "sit on pack" came out as a squat with the pack still on; too close to a gather crouch |
| amb_pushups (80141ab4, south) | from the front it is a kneel with hands down — reads as gathering; the east re-roll replaced it |
| amb_warm_hands (239f15c5) | hands clasped low in front; without a fire it reads as fidgeting. Could be composited over prop_fire — left for QA/D to judge, not shipped |
| amb_doze (4480d950) | almost no motion; reads as breathing idle |
| cat_sitting south (c0be02bb), cat_walk south | the front-view cat is a 10-px stick |
| cat_sleep_v3 (8e89ed40) | 4 frames only got the cat lying down, no sleep loop → replaced by cat_lie_rest |
| map-object cat 7d770a43 (32×32) | 30 px tall — waist height on the Traveler |
| pixen cat 63ac6edf (24×24) | right size, poor face |
| pixen yarn fa5aa25e | glossy gem look |

Nothing was hand-drawn or pixel-edited. Trimming, cropping, alpha quantising (never needed) and
nearest-colour palette remap only.

## 4. Prompts (verbatim action descriptions)

- stretch: "standing in place, slowly raising both arms straight overhead in a long stretch, arching the back slightly, then lowering the arms back to the sides"
- sit_rest: "sitting down on the ground on the backpack, resting, knees up, elbows on knees, breathing slowly, then standing back up"
- read: "standing, holding a small open book in both hands at chest height, head tilted down reading, turning a page, then closing the book and lowering hands"
- read2: "standing, holding a small pale open book with light cream pages in both hands in front of the chest, head bowed reading it, one hand lifting to turn a page, then reading again"
- eat: "standing, lifting a small wooden bowl in one hand and eating from it with the other hand, spoon to mouth twice, then lowering the bowl"
- drink: "standing, raising a small leather flask to the mouth with one hand, tipping the head back to drink, then lowering the flask back down to the side"
- pack_check (10 f): "swinging the backpack off one shoulder to the front, opening the top flap and looking inside, rummaging with one hand, then closing it and shrugging it back on"
- axe_wipe: "standing, holding a small hand axe by the handle in one hand, wiping the axe head slowly with a cloth held in the other hand, inspecting the edge, then lowering the axe"
- pick_inspect: "standing, holding a pickaxe upright with the head at chest height, tapping and inspecting the pickaxe head with the other hand, turning it slightly to look at it, then resting the pickaxe down"
- pushups (10 f, south): "dropping down into a push-up position facing the viewer, doing two slow push-ups, lowering and raising the body, then getting back up to standing"
- pushups_side (10 f, east): "going down onto hands and toes in a push-up plank position seen from the side, then doing slow push-ups: lowering the chest toward the ground and pushing back up, twice"
- look_around: "standing, scratching the back of the head with one hand while slowly turning the head to look left, then right, then facing forward again and lowering the hand"
- wipe_brow: "standing, wiping the forehead with the back of one forearm in a slow tired motion, head tilting slightly, then letting the arm drop back to the side and exhaling"
- warm_hands: "standing, both hands held out low in front at hip height, palms down and open, warming them over something low on the ground, slowly rubbing the palms together, then holding them out again"
- doze: "standing, dozing off on his feet: eyes closing, head slowly nodding forward and drooping, shoulders sagging, then jerking the head back up awake, blinking, then nodding off again"
- crouch_pet (10 f): "bending the knees to crouch down low, reaching one hand down and forward to gently pat and stroke something small at ground level in front of him, stroking twice, then standing back up"
- sit_ground (10 f): "lowering himself to sit down cross-legged on the ground facing the viewer, hands resting on knees, sitting still and breathing slowly, then standing back up"
- dangle_string: "standing, one arm extended out to the side and slightly forward at waist height, holding a piece of string dangling from the fingers, gently bobbing the hand up and down to swing the string, other hand on hip"
- pet_cat_combined (10 f, custom 96×64 start): "the man bends his knees and crouches down low beside the small cat, reaches one hand down and gently strokes the cat's back twice while the cat sits still and lifts its head, then he stands back up"
- cat character: "small orange tabby cat, white chest and muzzle and paws, darker orange stripes on back and tail, dark brown single outline, flat matte shading in a few clear steps, light from upper left, pixel art game sprite" (standard, quadruped cat, size 24, low top-down, flat shading, single colour outline, low detail, 4 dir)
- cat sit_idle (6 f): "cat sitting down on its haunches seen from the side, sitting still, tail slowly flicking side to side on the ground, ears twitching once"
- cat roll: "cat lying down and rolling over playfully onto its back, paws in the air, wriggling, then rolling back onto its side"
- cat bat_yarn: "cat crouched low, batting playfully at a small red ball of yarn on the ground in front of it with one front paw, the ball rolling a little, paw swatting twice"
- cat stretch (6 f): "cat doing a long stretch: front legs extended forward and low, chest down, rear end raised high, then standing back up normally"
- cat sleep (4 f): "cat lying curled up asleep in a ball on its side, tail wrapped around, only the flank rising and falling slowly with breathing"
- cat sleep_breathe (4 f, custom start = sit_idle f6): "cat lying down asleep, staying in the same lying pose, eyes closed, only the flank and belly gently rising and falling with slow breathing, tail tip twitching once"
- campfire (pixen 32): "small campfire: three short logs crossed on the ground with a low warm orange-yellow flame rising from the centre, few embers, single dark outline, flat matte shading in a few clear steps, light from the upper left, pixel art game sprite, object centred and filling most of the frame"; animate_image: "small campfire flame flickering gently in place, logs stay still, seamless idle loop"
- yarn (pixen 16, seed 7): "small ball of red wool yarn, matte, wound strands visible as a few curved lines, one loose end of yarn trailing to the right, single dark outline, flat shading in two steps, no shine, light from the upper left, pixel art game sprite"

## 5. QA material

- `qa/ambient_sheet_x1.png`, `_x2.png` (verdict scale), `_x8.png` (inspection) — one row per accepted asset, in manifest order.
- `qa/ambient_context_x2.png` — six Traveler + cat (+ fire) pairings on a shared baseline, ×2, plain ground.
- Per-candidate ×1/×2/×8 strips are in `candidates/<name>/_sheet_x*.png` (untracked).

## 6. AUTHOR ASSESSMENT

What I believe holds at ×2: drink, eat, stretch, head_scratch, wipe_brow, pack_check (first six
frames), pick_inspect, sit_ground, pushups_side, dangle_string, and the pair_pet_cat sequence all
read as what they are without a caption. The cat reads as a small orange cat at knee height in
every pairing; walk, sit_down, roll and bat_yarn read as those actions. The palette remap makes
every Traveler frame use the idle's 31 colours, so D-8 stepping cannot occur within a scene.

What I doubt: traveler_read (a 3-px book), cat_stretch (late frames look like a lunge),
cat_lie_rest (open eye — it rests, it does not sleep), and axe_inspect (no cloth; the axe is
just held and looked at). traveler_crouch_pet alone looks like a gather crouch and must only be
shown with the cat under the hand. The pack still fades from the front in several scenes (D-7,
known). Three scenes are on an 80 canvas and one on 96×64; D needs the manifest's `canvas`
and `baseline` rather than assuming 64. Baseline drift is ≤ 1 px everywhere (pushups_side
f4–5, crouch_pet f6, cat walk/roll frames).

Not attempted: warming hands at the fire as a distinct pose (the roll came out as clasped
hands), a proper sitting-on-haunches cat idle from the side (the template `sitting` transition
covers it), and any south-east/south-west variants.

QA VERDICT (Visual QA, from neutral staging):

## QA VERDICT (independent Visual QA, 2026-08-17)

Evidence limits: qa/ambient_sheet_x8.png could not be opened (tool size cap);
ambient_sheet_x2.png was viewable only below x2; candidate folder names
(amb_pick_inspect etc.) leaked via directory listing before viewing; the task
prompt named "Traveler + cat". Verdicts rest on ambient_context_x2.png (true
x2) and on the row sheet where noted. Palette stepping and 1-px baseline
drift: CANNOT VERIFY at the resolution available.

- traveler_drink, traveler_eat: PASS-WITH-NOTE — each reads "hand to mouth";
  the two are not separable from each other at play scale.
- traveler_pack_check: PASS.
- traveler_axe_inspect: FAIL (MAJOR B) — pale axe head reads as a sheet of
  paper/map held at the chest.
- traveler_pick_inspect: FAIL (MAJOR B) — pick raised over the shoulder reads
  "about to mine"; an idle that looks like the gather action.
- traveler_stretch: PASS-WITH-NOTE (MAJOR B) — peak frames read as
  cheer/celebration at true x2 in context.
- traveler_head_scratch, traveler_wipe_brow: PASS-WITH-NOTE — both "hand to
  head", not separable from each other.
- traveler_sit_ground: PASS (with fire and cat reads as resting).
- traveler_pushups_side: PASS-WITH-NOTE (MAJOR B) — prone frames carry a
  collapsed/knocked-down read.
- traveler_dangle_string: PASS.
- traveler_read: FAIL — no book perceptible at x2; reads as fidgeting.
- traveler_crouch_pet: PASS only in joint use; alone reads as gathering.
- pair_pet_cat: PASS.
- cat_stand/walk/walk_west/sit_down/settle/lie_rest/roll/bat_yarn: PASS —
  reads as a small orange (salmon-leaning) tabby at knee height.
- cat_stretch: PASS-WITH-NOTE — late frames read pounce.
- prop_fire, prop_yarn: PASS. Nothing reads as a meter, heart or emote except
  the stretch peak noted above.

QA VERDICT (ambient): FAIL — axe_inspect, pick_inspect and read do not read
as intended at play scale; stretch and pushups carry emote/collapse reads.

### Lead's disposition (2026-08-17)
- axe_inspect, pick_inspect, read: WITHHELD from the rotation
  (`lib/ui/icons/ambient_assets.dart`); frames stay packaged for a correction
  round. crouch_pet is joint-use only in the table (cat layer always present).
- stretch, pushups: kept, with the cat beside them; recorded as GAMEPLAY/DESIGN
  notes for the owner's device read. wipe_brow is kept; head_scratch has the
  cat rolling beside it so the two "hand to head" scenes differ in the whole.
- Re-staging at a readable ×2/×8 with opaque names is owed before the next
  ambient round.
