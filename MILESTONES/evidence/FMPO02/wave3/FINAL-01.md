# FINAL-01 — UI Director adversarial review, FMPO02 wave 3

1. BLOCKER — Reserved teal leaks into decoration. `board/board_layer.png`: the
   "Order Delivered" result modal has a full teal glow border, not a step
   context. `v3_inventory_purpose.png`: the selected material card (Meadow
   Herb) carries a teal top/left edge as a selection cue. Rule is explicit:
   teal (#58D6C0) is reserved for steps only. Fix: recolor both to the
   existing amber/gold accent already used for LEVEL UP and READY states;
   teal should appear nowhere but the steps glyph and counter.

2. BLOCKER — Universal equipment claim is unverified by any real screen. Every
   full-chrome device screen in this save (adventure.png, v3_adventure.png,
   stage/*.png, gather results, world screens) shows only base/Training gear
   because no bronze piece is equipped in the reviewed save. The only
   bronze-tier evidence is `combat/gear_bronze_idle.png` and
   `gear_bronze_swing.png` — placeholder test-harness renders (blank stat
   blocks, dead black lower two-thirds), not production screens with header,
   nav, and card chrome. Owner's complaint #4 ("Inventory shows Bronze, but
   Adventure/gathering/combat still show white shirt + vest") cannot be
   called fixed without an in-context screen of a bronze-equipped Traveler on
   Adventure or a gather stage. Fix: capture one real Adventure/gather/combat
   screen with Bronze Chestplate + Bronze Sword equipped before claiming this
   closed.

3. BLOCKER — Skills tab regressed against its own BEFORE. Compare
   `pair_adventure_skills.png` (cols 3–4, 4d9a81f) to `device/skills.png` and
   `v3_skills.png`: before, each skill row carried an XP bar and a 3-line
   roadmap preview inline, filling the screen. After, the list is 5 bare
   icon+name+level rows over roughly 55% of pure empty black — no scroll
   content, no roadmap. The "next unlock" the round claims only exists on the
   drill-in (`v3_skill_foraging_detail.png`), reached by an extra tap. This
   is a hierarchy and information-density regression, not a fix. Fix: restore
   an inline progress bar + single "Next: <unlock>" line per skill row on the
   list itself.

4. SHOULD-FIX — World location-inspector sheet wastes ~45% of screen height
   as pure dead black beneath the Travel/Set-as-Journey buttons. Repeats
   identically on `v3_world_hollow_inspector.png` (Forgotten Hollow) and
   `world_inspector_destination.png` (Stonefall Mine) — a systemic sizing
   bug, not a one-off. Fix: size the sheet to its content and anchor to the
   bottom safe area instead of stretching to fill the viewport.

5. SHOULD-FIX — Combat command area leaves 130–150dp of dead black below the
   2×2 grid down to the nav bar (`combat_wolf_slash.png`,
   `combat_wolf_turn2.png`). The round fixed owner complaint #8 (giant lower
   frame) but overcorrected into empty space; the BEFORE screen
   (`pair_combat_wolf_slash.png`) at least filled that band with a 4-row
   list. Fix: grow the stage art to fill the freed height, or add the
   "narration strip" the round claims but which is absent from these
   screens.

6. SHOULD-FIX — Command-button framing is inconsistent turn-to-turn on the
   same card. `combat_wolf_slash.png` (turn 1): Attack/Brace/Eat/Retreat all
   flat/unframed. `combat_wolf_turn2.png` (turn 2): Attack and Brace gain a
   full bronze nine-patch frame with corner rivets while Eat/Retreat stay
   flat. This both violates "one framed element per screen" (competes with
   the hero-plate frame) and gives inconsistent tap affordance for the same
   control across turns. Fix: signal "available this turn" with a fill/glow
   change, not a second frame family.

7. SHOULD-FIX — Boss telegraph band overlaps HP totals. All three guardian
   screens (`combat/combat_guardian_idle.png`, `_heavy.png`, `_struck.png`)
   render at a visibly shorter canvas than every other device screen, and a
   yellow/red hazard-stripe band bisects the "40/40" / HP text, making both
   numbers unreadable. Fix: move the telegraph stripe below the HP row, and
   confirm boss encounters render at the same 393×852 frame as wolf combat.

8. NOTE — Notice Board "closed" state (`board/board_closed.png`) shows every
   list entry's icon as a flat black square (Herbal Supplies, Carpenter's
   Request, Kitchen Stores…), while the identical list in `board_open.png`
   and `board_layer.png` shows full art in the same slots. If this is a real
   reachable state rather than a capture artifact it reads as broken art.
   Fix: confirm whether players ever see this state; if so it needs icons or
   a proper loading skeleton, not blank tiles.

9. NOTE — Result toasts overlap the list beneath them rather than being
   clearly separated: `gfcp_mining_result.png` cuts off the "Deep Tin Seam"
   reward and the row below it; `v2_gather_result.png` cuts the "Mill
   Garden" heading mid-word. Reads as a z-order accident. Fix: dim/scrim the
   list under an active result toast so the cut text doesn't look like a
   bug.

10. NOTE — Adventure's "Current Goals" row (`adventure.png`, `v3_adventure.png`)
    shows two cards side by side with the second hard-cropped at the screen
    edge and no peek sliver or scroll dot. Fix: add a partial-card reveal or
    a scroll indicator so players know there's more to swipe to.

11. NOTE — Inventory's claimed 5-column materials grid is unverified: with
    only Meadow Herb ×3 owned, `inventory.png` shows one card in a mostly
    empty band before Equipment starts. Confirm the grid wraps compactly at
    low item counts rather than reserving fixed 5-slot rows, or new players
    open Inventory to a near-blank screen.

**Verdict:** Not ready — two rule violations (teal leak, unverified universal
equipment) and a genuine information-hierarchy regression on Skills must be
fixed before this can be called an improvement over 4d9a81f.
