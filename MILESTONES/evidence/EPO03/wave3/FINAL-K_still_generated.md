# FINAL-K — Does this still look AI-generated?

**Reviewer:** FINAL-K (adversarial, built none of this)
**Branch:** fable5-executive-production-overhaul-03
**Date:** 2026-09-03
**PixelLab generations spent:** 0

Method: read the pixels only. Screens judged at their native 393×852. The atlas
(1024×1024, displayed ×2) judged in 197×426 atlas-pixel crops — one crop is one
phone viewport — cut with `Scripts/art/png.js` and inspected at ×2. No
documentation, ledger, or intent was consulted before forming a verdict.

`assets/art/v1/world/atlas_base.png` and
`GAME_BIBLE/ART/exploration/EPO03/review/producer/atlas_all_territories.png`
are byte-identical (md5 `00399c7d…`), so the review image is the shipping image.

---

## Ranked surviving tells

### 1. BLOCKER — The west territory is drawn by a different, weaker hand than the centre
`assets/art/v1/world/atlas_base.png`, viewport crop x=20 y=260 (197×426).

Put this crop beside the Haven's Rest crop (x=300 y=480) and they are not the
same game. Haven's forest is dense, black-outlined, clustered canopy with
internal light logic. The west is pale flat olive ground carrying almost no
texture, populated by a single three-lobe tree stamp with two trunk legs,
repeated identically at least fifteen times at two scales, plus a grey boulder
blob repeated at four scales with the same highlight in the same relative
position every time. Between them run several long, flat, horizontal
tan/olive bars lying on the grass that resolve as nothing at all — not logs,
not ridges, not hedgerows — the classic unreadable smear a generator leaves and
a human deletes. This is the owner's exact sentence: "some areas feel authored,
others feel patched." It is still true, and it is the largest region a player
walks through early.

### 2. BLOCKER — The ocean is a flat tint with a repeated ornament sprinkled on it
`assets/art/v1/world/atlas_base.png`, viewport crop x=700 y=420.

Roughly 30% of the world's area is one unmodulated teal. There is no current, no
depth banding away from the shore ring, no swell, no reef, no colour temperature
change from the ice north to the volcanic east. The only thing on it is a 5px
white dash — one sprite, one orientation, repeated some dozens of times at even
visual density, carrying zero information. At phone scale a viewport of open
water is a solid rectangle with confetti on it. That is a flat tint pretending
to be a material, and a repeated ornament used as filler, in one image.

### 3. BLOCKER — Repeated identical dark cards are still the dominant screen unit
`test/goldens/phase1_adventure.png`, `phase2_skills.png`,
`phase1_inventory.png`, `phase2_craft.png`,
`GAME_BIBLE/ART/exploration/EPO03/review/device/craft/v3_craft_book.png`.

The owner's complaint was "too many repeated dark cards." Count what a player
scrolls past: two identical gather cards (identical rounded rect, identical
icon-left / title / grey subtitle / cost-right arrangement, identical thin
tapered orange rule above each); five skill rows in `phase2_skills` at exactly
equal height, each icon-left / three "Level N opens …" lines / right-aligned
"LV 1" / identical XP strip beneath, differentiated **only by the hue of the
title word** — a colour token swapped five times is not five authored panels;
six identical recipe tiles in the craft book laid out 2-up on a perfect grid.
The rhythm never varies. An authored page varies: one entry gets more room
because it matters more. Here every entry is the same height because a builder
loop emitted it. This reads as a component library in a brown costume.

### 4. BLOCKER — `combat_victory.png` is an empty screen with an ornamental band
`test/goldens/combat_victory.png`.

The top ~60% of the viewport is flat near-black. Across the top runs a strip of
one diamond/chevron glyph repeated edge to edge, unbroken, at fixed pitch —
literally the definition of decoration that carries no information and no human
would draw it perfectly uniform for 393px. Below it, the reward panel is a
rounded rect with a hairline, ALL-CAPS grey micro-labels ("VICTORY",
"EXPERIENCE", "REWARDS") and a centred flat-tint "Continue" button. That is a
mobile app modal, not a moment of triumph in an RPG. The single genuinely good
thing on the screen — the wolf pelt icon — is 32px in the corner.

### 5. BLOCKER — Twin mirrored towers flanking the volcano
`assets/art/v1/world/atlas_base.png`, viewport crop x=560 y=200.

Two watchtowers sit on the volcano's left and right shoulder at near-identical
height, near-identical size, near-identical silhouette — the same stamp placed
twice for balance. Nothing in the terrain motivates either. Symmetry no human
would draw, on the single most photographed landmark in the world. The lava
compounds it: eight or nine branches of uniform width radiating evenly down all
faces of the cone, evenly spaced, all reaching the water. Real lava picks one or
two channels.

### 6. DEBT — The panel background texture visibly tiles at phone scale
`test/goldens/phase1_inventory.png`, `combat_stage.png`, `phase2_skills.png`.

The mottled dark-brown fill behind every panel repeats on a short, regular pitch
that is legible on a 393px-wide screen — most obvious in `combat_stage.png`,
where the empty combat-log field is a large uniform rectangle of the repeat with
nothing on it, and in the header band of `phase2_skills.png`. A texture whose
period you can count is wallpaper, not material.

### 7. DEBT — Four identical corner brackets, rotated
`test/goldens/combat_stage.png` (stage frame), `phase2_craft.png` (recipe card).

Both frames use one corner ornament rotated 90° four times, in perfect
registration. Correct, cheap, and instantly readable as programmatic. An
authored frame has a heavier bottom, or wear on the corner a thumb touches.

### 8. DEBT — Repeated seal/rosette badge as the craft book's only visual event
`GAME_BIBLE/ART/exploration/EPO03/review/device/craft/v3_craft_book.png`.

The same red wax rosette appears on all six tiles, same size, same rotation,
differing only in the digit inside it. It is doing the job of a two-character
text label while occupying a third of each tile. Decoration that carries no
information beyond what the number already carries.

### 9. DEBT — Repeated pillar milestone markers down the skill rail
`GAME_BIBLE/ART/exploration/EPO03/review/device/skills/v3_skill_mining_detail.png`.

The LV2–LV5 rail markers are the same small stone-cairn sprite repeated four
times unchanged; only the LV1 marker (the figure) differs. A progression track
whose stations are identical does not communicate progression. The XP bar above
is a flat outlined empty rounded rect — a Material progress bar.

### 10. DEBT — Flat tints standing in for materials on every action control
`test/goldens/combat_stage.png` (Attack / Brace / Eat), `phase2_craft.png`
("Craft"), `combat_victory.png` ("Continue").

Solid red, solid blue, solid green, each with a 1px lighter border and a centred
label. No bevel, no wear, no material identity, no relationship to the wood,
stone or iron that the rest of the frame claims to be made of. These are
Bootstrap buttons with a fantasy typeface on top. The green "Craft" button in
particular is the single largest flat colour field on that screen.

### 11. DEBT — Ornamental hairline rules as universal section filler
`test/goldens/phase1_adventure.png`, `phase1_inventory.png`,
`phase1_character.png`.

Every section header is followed by the same tapered orange hairline at the same
inset, and every list row is separated by the same one. It is one asset used
eight-plus times per screen to signal "a heading happened." Compare it against
`phase1_character.png`'s level track — a hairline with three identical circular
nodes on it, at level 1 of an unstated maximum, telling the player nothing.

### 12. DEBT — Every island in the archipelago is the same island
`assets/art/v1/world/atlas_base.png`, crop x=700 y=420.

Six islets, each a rounded blob with a uniform-width sand ring — an outline
stroke, not a beach — and the same two-or-three-lobe bush cluster centred on it.
The sand ring is constant width regardless of which side faces the prevailing
water. No inlet, no spit, no rock, no variation in shore treatment.

### 13. DEBT — Farm parcels are flat lozenges with one squiggle texture
`assets/art/v1/world/atlas_base.png`, crop x=300 y=480.

The four wheat fields around Haven's Rest are flat yellow polygons with the same
short diagonal stroke pattern inside each, at the same density and the same
angle in all four. Real fields have furrow direction that follows the slope, and
different crops in different parcels. And the flower clumps scattered across the
meadow below are one yellow-dot cluster stamped roughly ten times unchanged.

---

## What has actually improved (stated so the ranking is honest)

The centre of the map — Haven's Rest, its forest, the braided river delta, the
volcano cone itself — is genuinely authored: the canopy has internal structure,
the river braids irregularly, the settlement's palisade is not symmetric, the
ice-to-rock transition at the volcano's north face is real drawing. The combat
stage backdrop, the cookfire scene in `craft_stage.png`, the character portrait,
and the item icons (wolf pelt, herb bundle, cooking pot) are the strongest
assets in the build and would not, on their own, be read as generated.

## Verdict paragraph

**Partly answered.** The charge has been answered where an artist clearly stood
in front of a single canvas and drew — the map's centre, the combat backdrop,
the cookfire, the icons. It has not been answered anywhere the work was
*assembled* rather than drawn. The two failure modes the owner named survive
intact and in force: the interface is still a component library in a brown
costume (five identical skill rows differentiated by a hue token, two identical
gather cards, six identical recipe tiles, one hairline rule used eight times a
screen, flat-tint buttons, a victory screen that is an empty rectangle with a
repeating chevron band across the top), and the world is still visibly patched
(the west territory's stamped trees, repeated boulders and unreadable horizontal
smears are a different and weaker hand than the forest two viewports east; the
ocean is a flat tint with confetti; the volcano wears the same tower twice).
A player who scrolls the skills screen or opens the craft book will see the loop
that generated it, and a player who walks west will see the seam. The centre of
this build is good enough that the edges now look worse by comparison, not
better. Five BLOCKERs stand.
