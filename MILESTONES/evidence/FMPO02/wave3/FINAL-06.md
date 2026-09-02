# FINAL-06 — Game-feel / reward director adversarial review

1. **BLOCKER — the reserved teal is worn by reward frames, repeatedly, not
   just on the board.** `GAME_BIBLE/ART/exploration/FMPO02/review/device/board/board_layer.png`
   shows "ORDER DELIVERED / Herbal Supplies" inside a full teal-bordered
   reward layer panel. This is not a one-off render glitch — it is
   `lib/ui/screens/adventure/board_card.dart:726`
   (`rewardInkOf(ContractClass.localNeed) => StrideColors.accentSteps`),
   and the same file reuses `StrideColors.accentSteps` as the reward-layer
   `accent` at line 112 (Project Complete / Stage Complete beats, also
   `:332`, `:345`). A third site does the same thing for the character's own
   level-up: `lib/ui/components/reward_beat.dart:250`
   (`LevelUpCard`: `skill == null ? StrideColors.accentSteps : ...` — a
   *Traveler* level-up, the one level-up every player sees earliest, frames
   itself in step-teal). `lib/ui/theme/stride_colors.dart` documents the
   opposite rule at the exact same time: line 127 says "**None of them is
   `accentSteps`**. L-16 reserves teal for walking, steps and banked
   quantity," and lines 191–194 record that this project already once
   caught and fixed "the teal victory frames" by moving reward accents onto
   `rewardLightInk` (amber). These three call sites are that regression
   again, now in three places instead of one. Fix: change `rewardInkOf`'s
   `localNeed` case, `board_card.dart:112`, and `LevelUpCard`'s
   `skill == null` branch to `StrideColors.rewardLightInk` (or another
   non-teal ink — a contract/order-specific hue would also read fine), and
   add a guard to `test/combat_ui_test.dart` or a new reward test mirroring
   `test/rarity_ui_test.dart:265-279` (`isNot(StrideColors.accentSteps)`)
   for every `RewardBeat`/`RewardLayer`/`LevelUpCard` accent — the rarity
   table already has this exact regression test; the reward system does
   not, which is how the same mistake shipped twice.

2. **SHOULD-FIX — the Brace beat is held for less time than any other beat
   in the round, undercutting the one deliberate, thought-out action in
   combat.** `lib/ui/screens/combat/combat_choreography.dart:176` sets
   `_bracedHold = Duration(milliseconds: 350)`, the floor used whenever a
   loadout's brace track is shorter than that (`:252-254`) or absent
   (falls back to a held idle). Compare `_afterBlow` (400 ms, an ordinary
   struck beat) and `_lostSettle` (500 ms, a retreat). Attack and struck
   beats also add real animation/impact-effect duration on top of their
   floor; Brace does not. The result: the one moment a player consciously
   traded offense for defense reads shorter on screen than either an
   ordinary hit landing or a retreat. Fix: raise `_bracedHold` to at least
   `_afterBlow`'s 400 ms, or better, give it its own constant ≥ the
   struck-beat floor so a deliberate defensive choice never resolves faster
   than an incidental one.

3. **NOTE — no device evidence shows the Brace beat actually playing.** None
   of the 41 renders in `review/device/` (including
   `review/device/combat/*`) capture the stage mid-`BracedBeat` — only
   idle/heavy/struck/swing states for the Hollow Guardian and the wolf
   fight's Attack/Brace *button* states (`combat_wolf_turn2.png`). The
   council cannot verify the held brace pose (crossed forearms / sword
   across body per `GAME_BIBLE/ART/exploration/FMPO02/review/equip/brace_all_x2.png`)
   composites correctly, holds on its last frame as `combat_choreography.dart:246-248`
   claims, or reads as distinct from idle for loadouts that lack a brace
   track. Capture one device render of a resolved Brace round before this
   ships.

4. **NOTE — the narration strip's contrast guard proves the wrong thing is
   safe, not that the shipped thing is.** `test/combat_ui_test.dart:567-641`
   rigorously proves the *rejected* `narration_strip.png` asset fails AA
   (2.90:1 on the rows text crosses) and is why `_CombatLog`
   (`lib/ui/screens/combat/combat_screen.dart:407`) keeps
   `StrideColors.surfaceGround.withValues(alpha: 0.72)` instead. No test
   measures that shipped translucent fill's own contrast against
   `textPrimary` composited over the *brightest* combat backdrop in the
   set (open-sky/snow/fire encounters use lighter grounds than the forest
   screens in evidence). At alpha 0.72 over a near-white ground the
   composite would sit near 2.6:1 — below AA. The forest/cave screens
   reviewed (`combat_wolf_turn2.png`, `combat_guardian_*.png`) read fine
   because those backdrops are dark; nothing here shows that holds
   everywhere the strip appears. Fix: extend the existing test with the
   same measurement technique against `surfaceGround@0.72` composited over
   the actual encounter backdrops, not just the rejected asset.

5. **PASS — material escalation exists and is not a casino tell.**
   `gfcp_bonus_yield.png` (device) shows the "notable" tier correctly: a
   warm parchment-toned fill, bronze corner brackets
   (`lib/ui/components/activity_result.dart:249-256`, `RewardArt.ornamentCorner`),
   and a static, low-alpha `rewardGlow` (`0x29E0A63F`, no animation
   controller drives it) — no pulse, no flash, no count-up. `RewardLayer`
   and `RewardBeat` similarly resolve once via `StaggeredReveal`
   (`reward_beat.dart:298-378`) and hold still; `Curves.easeOutBack` is
   explicitly avoided (`reward_layer.dart:132-134`) because its overshoot
   "reads as a jackpot ding." Ordinary (non-notable) results
   (`gfcp_mining_result.png`, `gfcp_woodcut_result.png`, `v2_gather_result.png`)
   correctly show no escalation at all. No count-up anywhere in the reward
   path itself (the only count-up in the app is the banked-steps header
   stat, `lib/ui/components/screen_header.dart:232-237`, which is outside
   reward surfaces and is the one thing allowed to be teal).

6. **PASS — haptic tiers are present, floored, and payoff-exempted
   correctly.** `lib/audio/audio_controller.dart:458-513`: light/medium/heavy
   with per-strength rate floors (120/400/1200 ms) and a `payoff: true`
   bypass so a reward layer's own haptic can never be swallowed by a
   preceding combat hit inside the floor window — `reward_layer.dart:79-83`
   uses it correctly (heavy for MAJOR, medium for MEDIUM). Minor activity
   results fire no haptic; a card's promotion to "notable" fires exactly one
   light tap (`activity_result.dart:418-424`), never repeated on merge. No
   missing or duplicated tier found.

**Verdict: FMPO02 wave 3 reward system does not ship as-is — the reserved
teal is worn by reward-layer frames in three confirmed, code-documented
regressions (Order Delivered, Project/Stage Complete, Traveler Level-Up)
against the project's own explicit rule and prior fix; everything else
about the reward language (tiering, material escalation, no casino motion,
haptics) is sound and should be kept once the teal is corrected.**
