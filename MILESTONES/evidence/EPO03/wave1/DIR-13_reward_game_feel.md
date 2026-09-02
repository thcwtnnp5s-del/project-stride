# DIR-13 — Reward / Game Feel (EPO03 Wave 1)

0 generations spent. **Ownership first:** GOV-05 §2 freezes
`activity_result.dart`, `reward_beat.dart`, `reward_layer.dart` under NAV.
The producer lifts the freeze and names REWARDS owner, or this goes via
`REQUESTS_NAV.md`. No save, health, systems or consumer-file change.

## TOP FAILURES

1. **The result card is a toast.** Every activity renders the same
   `surfaceCard` rectangle: 48 px icon, grey micro verb, name ×1, one XP line
   — Copper Ore, Oak Log and Herb Broth are one picture; templated, weightless.
2. **Craft and gather are indistinguishable**; the batch summary only swaps
   the verb — five things made reads as one line.
3. **The level-up is a list row**: a 48² plate beside card-title type in a
   dark card with a 1 px pink rule and a Continue button. A settings dialog.
4. **Notable escalation fights its card**: gold filigree on a rounded app
   card, grain invisible at 393 px, glow reads as a focus ring.
5. **`seal_project` is teal** — reserved for walking (L-16), pre-existing.

## WHAT TO REPLACE

**Result card → tally slip.** A paper nine-patch (`slip_paper`, torn top
edge) replaces the `BoxDecoration`; the hero is the 48² icon at integer ×2 =
96 logical px (A-2); the verb is an inked **stamp** (tinted nine-patch behind
`microLabel`), which makes MINED and FORGED differ across the room; facts on
ruled lines, quantities right-aligned.

**Rarity is material, never area-fill.** Common: paper. Uncommon: existing
`grain_buckram` (cloth) in the margin band. Rare: the `mark_rare_drop` line
plus a 24² wax seal (`seal_rare_wax`, one asset tinted by `RarityStyle.accent`
via `ColorFiltered`) at the top-right corner. Signature: `seal_signature`
(leather) as layer emblem; masterwork: `seal_masterwork` (wood). Notable keeps
`grain_notable_plate`; the bracket leaves the slip.

**Level-up → stamped page.** `LevelUpCard.icon` becomes a 64² inked roundel
(`plate_level_stamp`) holding the existing `skill_*.png` glyph, the numeral in
`cardTitle` type, never baked. A three-rank badge family (`badge_level_r1–r3`,
48²) steps at the milestone levels already in content
(`SkillUnlockKind.milestone`) — no new thresholds. `_Bracket` shared (ART-10 §4).

**First-time discovery.** `firstCraft` exists (`craft_memory.dart`). A 24²
`mark_first_find` (pinned tag) on its own line, ink only, **no lifetime copy**
— the memory can be lost on reinstall.

**Batch → ledger tally.** On `CRAFTING COMPLETE`: ruled rows, static
`glyph_tally` five-bar strokes for ≤10 then a numeral, a foot rule with the
XP sum, the COMPLETE stamp. Nothing counts up.

**Q-20, recommendation only:** craft completion's mark is **art, not
systems** — the verb stamp *is* the mark; no `mark_craft_done`, no report
field; ART-10 reading 1 stands. Q-27 stays open; the wood seal keeps firing
on `CraftSignificance.major` until ruled.

**Micro-choreography** (Reduce Motion → full static presence): *settle* —
the existing 150 ms rise/fade; *seal press* — emblem scale 1.06→1.0, 180 ms
`easeOutCubic` inside the 260 ms `StaggeredReveal` beat, on existing haptics;
*stamp* — opacity 0→1, scale 1.10→1.0, 120 ms, once. Never `easeOutBack`;
nothing loops; nothing moves after 400 ms.

**Dart, widget level.** `ActivityResultCard`: `PanelSkin` slip, hero
`scale: 2`, `_Stamp`, `_WaxSeal`, `_TallyRows`; host, `maxWidth 361`,
hold/fade/merge untouched. `LevelUpCard`: `_LevelStamp` + shared `_Bracket`.
`RewardLayer`: press transform on the emblem child only. Slip and stamp ship
to `assets/ui/v1/frame/` with sidecars (corner 8 band 4 / corner 4 band 2).

## WHAT TO KEEP

Every `RewardArt` mark but `seal_project`; `grain_notable_plate`;
`ActivityResultHost` (snapshot, merge, TickerMode wait, tap-dismiss);
`RewardLayer` tiers, haptics, `emblemSize`; `RarityName`/`RarityBadge`;
`craft_significance.dart`.

## PRODUCTION FAMILY

All `create_image_pixen`, single frame.

| Asset | Canvas | Count | Reference |
|---|---|---|---|
| `slip_paper` nine-patch (corner 8, band 4, ×2) | 64² | 1 | `chassis_64`, `grain_journal_leaf` |
| `stamp_verb` nine-patch (corner 4, band 2) | 96×32 | 1 | `seal_contract` wax |
| `seal_rare_wax` (tinted in code) | 24² | 1 | `mark_rare_drop` |
| `plate_level_stamp` | 64² | 1 | `plate_level_up` |
| `badge_level_r1/r2/r3` | 48² | 3 | `badge_milestone` |
| `mark_first_find` | 24² | 1 | `mark_knowledge` |
| `glyph_tally` | 32×16 | 1 | bitmap font |
| `seal_project` re-roll, non-teal | 48² | 1 | existing set-square |

Nine new, one replaced; `grain_buckram`/`grain_leather` already ship. §7.2
style clause; no teal; zero partial alpha; sheeted ×2/×3 and Read before acceptance.

## PIXELLAB BUDGET

Unit cost **1** (GOV-04). Slip 8 · stamp 8 · wax 6 · plate 8 · badges 20 ·
first-find 6 · tally 4 · re-roll 6 = **66, cap 90**.

## PHONE-SCALE SUCCESS CRITERIA

At 393×852, then the owner's iPhone: slip fill visibly paper, not `#201C17`;
hero 96 px; MINED/CHOPPED/FORGED stamps differ in silhouette; a rare drop
shows sack mark and wax; signature/masterwork show their 96×48 seals centred;
a batch of 5 shows five tally strokes and a foot-rule sum; level-up shows
roundel, glyph, numeral, badge; AA text over paper at scale 1.4;
teal/alpha/ceiling guards green; under Reduce Motion every frame is the final
frame; nothing moves after 400 ms.
