# DIR-07 — Skills / Progression UI (EPO03 Wave 1)

Producer: SKILLS. Files: `lib/ui/screens/skills/skill_detail_screen.dart`,
`skills_screen.dart`. The overview (five spines on buckram) is GOOD and
stays; the detail becomes a **vertical journey line**. Zero generations here.

## TOP FAILURES

1. **Two `SectionCard()` rectangles on flat `surfaceCard`** (`:143`, `:170`),
   every unlock a third rounded box (`_UnlockRow` `:586-603`) — a settings
   list.
2. **No sense of position.** `LV 1 · NOW` is a chip; nothing says *passed /
   here / next / far*.
3. **Nothing illustrated.** Site, item, region, trade: no picture; XP is an
   8 dp bar in a card.

## WHAT TO REPLACE

**Ground and header.** No cards. `buckram` full-bleed behind the `ListView`
(the overview's grain — the push reads as turning the page). Order: trade
band (existing 384×48) → **TradeGauge**: 64² hero emblem in an `InsetWell`,
name in skill hue, an authored *gauge frame* (nine-patch, edges tiled) whose
window the existing `ProgressRule` fills in Flutter; the XP caption and
`1 of 14 unlocks open` sit on the ground beneath. `_NextBlock` dies — the
overview carries those lines; the *next* node answers it here.

**The journey line.** An inked road, 32 dp wide at the gutter, from the
gauge to the road's end: `_TrackPainter` paints a **tiled** 16×64 strip
(never stretched, last tile clipped); Flutter places a joint at each
milestone's y. Milestones hang right, **unboxed**: level badge + joint, then
entries. Four joint states told apart by *shape*: *reached* — a driven
waystone with an ink tick; *current* — a lit lantern cairn, the one node with
a backplate (nine-patch, warm rim) and a skill-hue numeral; *next* — a
bronze-rimmed unlit waystone captioned `120 XP away` (`xpAway`); *far* — a
faded stake. **No padlock (L-17), no coin disc (L-16/17), no teal.** Entry =
48 dp well + name + one-line effect (`detailLines[0]`) + gate mark (24² seal)
with `Also needs …`. Well: recipe → item icon 48²; milestone →
`badge_milestone`; site → its **region mark** 48² on the region deep. Unlocks
sharing a level share one badge and joint, each tied to the track by a 16 dp
**spur**. Tap keeps today's expand grammar; an expanded site adds its 96²
node vignette (`PixelIcons.nodeFor`). Empty-level runs compress to a
**fold** — the track sinks into a 48 dp painted fold, `LV 7–9 · nothing yet`
beside it. Behind the player the last two reached levels stay visible;
earlier ones fold into `LV 1–5 · 9 passed` (tap unfolds). An **end cap**
closes the road at `contentHorizon` with the existing horizon line.

**Numerals.** L-18: raster carries no number or state. A badge is a neutral
stone plate with `LV n` in `StrideType.numericValue` over it — two plates
(worn / lit). State is redundant in type, ink and Semantics, so the
frame-removal test passes.

**Dart.** Dies: `_NextBlock`, `_Ladder`, `_LevelBand`, `_UnlockRow`, both
`SectionCard`s, `SkillHeaderRow`/`SkillProgressBar` on this route. New:
`TradeGauge`; `JourneyTrack` (Column over `CustomPaint`) with its
milestone / badge / joint / entry / fold / end widgets; `TrackArt` registry.
Adapter `JourneyModel.from(SkillRoadmap)` → `List<Stop>` (milestone | fold |
end): `_Ladder`'s grouping as a pure, tested function.
**No new content.** Two passthroughs on `SkillUnlock`: `subject` (`node.id` /
output item) and `wherePlace` (host id; `_hostOf` returns the definition) —
ids the projection already holds. If GOV-05 gives `stride_session.dart`
another owner, file the REQUEST.

## WHAT TO KEEP

Overview **as-is, zero touches**. Trade bands, `badge_milestone`, item and
node art, `InsetWell`, `ProgressRule`, `buckram`, expand/Track behaviour,
every projection cap; `SkillProgressBar` stays defined for the spine.

## PRODUCTION FAMILY

Style source: `assets/ui/v1/{frame,surface,band}`, `skill_*.png`,
`assets/art/v1/location/`. Tool `create_image_pixen` (`no_background` for
marks), `edit_image_pixen` for fixes. Chrome → `assets/ui/v1/track/` (NAV
adds it to `CHROME` and the seam walker; the lit joint needs the L* ceiling
waived there); marks and emblems → `assets/art/v1/`.

| Asset | Canvas | Count |
|---|---|---|
| track strip (tiled vertical, period 8) | 16×64 | 1 |
| joints: reached / current / next / far | 24² ×2 | 4 |
| spur, fold, start cap, end cap | 8², 16×48, 16×24, 16×24 | 4 |
| current-node backplate (nine-patch, corner 8) | 48² | 1 |
| level badge plate: worn, lit | 28×20 | 2 |
| gauge frame (nine-patch, edges tiled) | 48×24 | 1 |
| region marks: Haven's Rest, Whispering Woods, Stonefall Mine, Frostmere, Forgotten Hollow | 48² | 5 |
| gate mark (seal, no lock) | 24² | 1 |
| skill emblems, hero size | 64² | 5 |

**24 shipped stills.** No partial alpha; glow as dithered opaque steps.

## PIXELLAB BUDGET

Unit cost 1 per pixen call (GOV-04). 24 × 3 candidates = 72, ~15 edits,
contingency → **cap 100**, expected ≈80.

## PHONE-SCALE SUCCESS CRITERIA

- 393×852 first screen: band, emblem + gauge, the lit current node and the
  next node with its XP-away — no scrolling to find "where am I".
- Zero rounded dark cards; one continuous seamless track, gauge to end cap.
- Four joint states tell apart at arm's length in greyscale.
- Entries ≥44 dp; numerals legible at scale 1.0 and 1.4; 320 dp wraps, never
  ellipsises; reduced motion: no glow pulse.
- No padlock, coin, timer or teal (L-15/16/17/19).
- Frame-removal test passes; `v3_skill_*_detail` evidence regenerated and
  inspected; a detail golden added.
