# ART-10 — Reward & Progression Language, beyond the first ten marks

Base: `RewardArt` (10 assets, VAWO01, `REWARD_ROUND_RECORD_01.md`), wired into
`activity_result.dart`, `reward_beat.dart`, `reward_layer.dart`, `board_card.dart`.

## 1. Full mark/plate/seal list

| Mark | Canvas | Status | Placement (file → widget) |
|---|---|---|---|
| `mark_exp` | 24² beside type | placed | `activity_result.dart` → `_MarkedLine` (XP line) |
| `mark_bonus_yield` | 24² beside type | placed | same, bonus line |
| `plate_level_up` | 48² standalone | placed | `reward_beat.dart` → `LevelUpCard.icon` |
| `seal_contract` | 48² standalone | placed | `board_card.dart` → `RewardLayer.emblem`, contract close |
| `seal_project` | 48² standalone | placed | `board_card.dart` → `RewardLayer.emblem`, project complete |
| `ornament_corner` | 32² ornament | placed | `activity_result.dart` → `_Bracket` |
| `mark_skill_xp` | 24² beside type | **unplaced** | `skills_screen.dart` → `SkillProgressCaption`, the per-skill bar's own "+N to next" caption, distinct from `mark_exp`'s run XP |
| `mark_knowledge` | 24² beside type | **unplaced** | `bestiary_screen.dart` → the `Studied`/`Seen` progress line (~L173–183, `KnowledgeTier`) — this **is** enemy-knowledge advancement |
| `badge_milestone` | 48² standalone | **unplaced** | `skill_detail_screen.dart` → `_UnlockRow`/`_LevelBand` where `unlock.kind == SkillUnlockKind.milestone` (bonus-yield-at-level rows, `stride_session.dart` L5538) |
| `marker_profession` | 48² standalone | **unplaced, no owner ask covers it** | candidate: `skills_screen.dart` `SkillHeaderRow` crest, for a whole-roadmap event. Don't force a placement — record `UNRESOLVED` if unnamed this round |

**New, completing the owner's twelve-item language** (the placed/unplaced
marks above already answer EXP, skill XP, level up, milestone, bonus yield,
enemy knowledge, contract, project):

| New mark | Canvas | Covers | Placement |
|---|---|---|---|
| `mark_rare_drop` | 24² beside type | "rare drop," inline, parallel to `mark_bonus_yield` | `activity_result.dart` `_MarkedLine`, shown when output rarity ≥ Rare, its own line above XP |
| `seal_signature` | **96×48 banner** | "signature drop" — a one-of-a-kind item, not a rarity tier | `RewardLayer.emblem`, `RewardTier.major` only |
| `seal_masterwork` | **96×48 banner** | Masterwork completion — the ceiling of craft quality | `RewardLayer.emblem`, `RewardTier.major` only |

**"Craft completion" gets no new asset** — the record's notable escalation
(rarity ink + bracket) already is that language (Bronze Sword vs. Herb Broth).
A mark per craft repeats "eleven unrelated borders" (§7) one family later.
Masterwork is the exception: a ceiling, not a tier, and one of only two marks
on the wider banner — level-up/milestone/contract/project stay 48² since they
happen often enough that a banner would cheapen fast.

**Estimate:** regenerate all 13 marks (10 existing + 3 new) as one
style-locked batch rather than bolt 3 onto a 13-generation-old round —
cross-round drift is what killed the frame batch (§7, 3 rounds, 0 accepted).
13 × 4 candidates × ~2.3 avg rounds-to-accept ≈ **~120 generations**, matching
the owner's figure. Cheaper fallback: 3 new marks only, against the existing
set as reference (~16 gens) — visible seam risk, not recommended.

## 2. Pixen prompt structures

Icon-canvas marks (24²/48²) use the standing icon clause verbatim
(`PIXELLAB_STYLE_SPEC_01.md` §7.2):

> `<noun phrase>, standing upright, front-on: <construction clause — parts and
> how they attach> — pixel art game item icon, single dark outline all the way
> around the object, flat matte shading in a few clear steps, light from the
> upper left, warm earthy limited palette, no glow, no emissive light, no
> bright white specular, no cast shadow, no ground, no text, no coin, no lock,
> no hourglass or clock, object centred and filling most of the frame`

Banner marks (96×48) swap the presentation clause for a wide, centred one —
`laid centred on a wide plate, the mark spanning the full width with clear
margin top and bottom` — construction and style clauses unchanged. Bronze
reads bronze, never gold; no `#58D6C0` (steps-only); no
coin/timer/lock/durability/cooldown iconography in any new mark.

## 3. Card & layer presentation upgrades

**Rarity-inked plate surface.** `PanelSkin.surfacePath`/`surfaceNative` exist
but `PixelFrame` still doesn't render them (record §7). Don't author a tile
per rarity — one neutral, seamless, low-contrast ART-02 tile (32²), drawn
under the card body only when `notable`, tinted by `RarityStyle.accent` at
~12–15% alpha via `ColorFiltered`. Contrast-check text over it at the largest
supported text scale. One asset, one filter, gated on the flag
`ActivityResultCard` already computes.

**Seal ornament for completions.** `RewardLayer.emblem` is hardcoded to 48×48
(`reward_layer.dart` ~L259–264). Add an optional `emblemSize` (default 48×48;
banners pass 96×48) so the new seals share the slot the existing ones use —
one parameter, no new widget.

**Settle animation, ≤400ms, one ease, nothing loops.** No new motion system:
the emblem is already `StaggeredReveal`'s first child (fade + 8dp rise,
`Curves.easeOutCubic`, 260ms). Add a matching scale `0.94 → 1.0` on the same
curve and clock — never `easeOutBack` (its overshoot reads as a jackpot
"ding"). Stays inside the 260ms beat, inherits Reduce Motion for free.

**Haptics, already correct once tiers are assigned right:** rare drop rides
the existing notable-flip `hapticLight()` in `_ActivityResultHostState`
(extend `ActivityResult.notable`); contract/project/level-up keep
`hapticMedium(payoff: true)`; masterwork/signature drop classify as
`RewardTier.major` for `hapticHeavy(payoff: true)` — calls that already fire.
No new `audio_controller.dart` code.

## 4. Level-up presentation

Keep `plate_level_up` at 48². Extract `activity_result.dart`'s private
`_Bracket` (rotated `ornament_corner`, two corners) into a shared widget so
`LevelUpCard` can wear it too. Default ink is bronze; when `unlocked`
contains an Uncommon-or-better recipe or item, tint the bracket with that
rarity's `RarityStyle.accent` instead — the same material-not-motion rule the
record already proved, applied to the one beat that didn't get it.

## 5. What NOT to do

- No spinning reel, radial jackpot burst, confetti, or particles.
- No number that counts up — figures are stated once, at final value.
- No looping shimmer, pulse, or glow on any mark, in or out of the layer.
- No per-rarity redraw of `ornament_corner` or the surface tile — one asset,
  tinted, never five materials (the §7 frame-batch failure, repeated).
- No coin, timer, hourglass, lock, or cooldown iconography anywhere here.
- No `#58D6C0` on any reward mark (steps-only), no banner outside masterwork/signature.
- No sound this session (`STABILITY_API_KEY` unset) — leave a hook, don't fake one.
- No wiring `marker_profession` to a guessed surface — record `UNRESOLVED`.
