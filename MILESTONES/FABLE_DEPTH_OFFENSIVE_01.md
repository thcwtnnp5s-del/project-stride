# Fable Depth Offensive 01 — the depth pass

**Branch:** `fable-depth-offensive-01` (from `game-feel-character-presentation-01`
@ `a32e206`). **Status:** built, reviewed, awaiting the owner's physical-device
acceptance. Nothing merges without the owner's verdict.
**Decision:** `DECISIONS/0028_DEPTH_OFFENSIVE_SCOPE.md` (experimental, revert
clause). **Thesis:** `MILESTONES/FABLE_DEPTH_OFFENSIVE_01_THESIS.md` (frozen
before implementation; the diagnosis, the twelve improvements, the rejections,
the deferrals).

## 1. The method

The owner's brief — the largest autonomous gameplay expansion attempted — ran
as five agent waves with main Fable owning synthesis and implementation:

- **Wave 0 (6 foundation agents):** canon constraints, architecture map,
  persistence risk table, the full content graph with its orphans and dead
  levels, four player-state personas, the zero-new-art menu.
- **Wave 1 (20 designers):** nineteen specialist proposals plus the Ruthless
  Editor, who cut roughly three offensives' worth of design to one game
  (traveler_tunic had six competing successors; four endgame sinks competed;
  eleven engine fields were proposed and two survived).
- **Wave 2 (5-director council):** systems, RPG, economy, product, and
  architecture lenses; the disagreements (restore the WC node, keep the
  Charter, defer the Five-Hearth Blade, engine-verified cost corrections)
  are adjudicated in the thesis.
- **Wave 3 (5 build planners):** exact insertion points, the complete content
  spec with final numbers, the test plan, the UI plan, the two real
  performance risks.
- **Wave 4 (4 playtest agents + 5 engine play-proofs):** fresh sequencing,
  the owner-install test, anti-grind arithmetic, dead-content recount.
- **Wave 5 (5 adversarial reviewers):** verdicts in §8.

## 2. What shipped (the twelve, as landed)

1. **Rails:** `requiresProject` on projects, `requiresKnownEnemy` on enemies
   (value = the base species' id; engine authority + projection mirror;
   hidden until the base is Seen, shown-locked until Known), the L-1
   entry-key validator (nothing that opens a location may be consumed — by
   recipe, contract, or project stage), the one-time character-XP band test
   (2,900–3,200, armed), `RejectionCode.enemyNotKnown` /
   `projectNotAvailable`.
2. **The Veteran Hunts** (`DECISIONS/0028`; enemy pin 9 → 13): Old Grey
   (Woods, 48/13/4 flurry), the Foreman of the Broken Gallery (Stonefall,
   60/15/5 guarded), the Rimeclaw Matriarch (Frostmere, 52/14/5 flurry),
   the Guardian Awakened (Hollow, 72/14/5 guarded boss). Each is its
   species' art at new stats, gated on Known, with one one-time regional
   hunt contract (`class: regional` + `bountyEnemy` — the only shape whose
   character XP is one-time). Compressed study (1/2), knownXp 25,
   `encountersPerVisit` 1, signature roll shipped **off**.
3. **The Bronze Lineage** (Smithing 7 → 10): fanghilt_sword gains
   `wildernessYieldPercent: 10` (the hunter's blade); **Waywarden's Tunic**
   (S8, rare, 5 power / 15% wilderness — consumes traveler_tunic);
   **Tin-Braced Pickaxe** (S9, rare, tier 2, 25% yield — consumes
   reinforced_pickaxe + tin ×3); **Frostwarden Coat** (S10, epic, 8 power /
   frostGuard 3 — consumes frostlined_jerkin). Each capstone edges its
   masterwork shortcut by one honest step (final-review retune), so the
   trophy stays the shortcut and the craft the summit.
4. **Derived upgrade lineage:** `upgradesTo/From` computed from recipes'
   equipment-consuming edges, cached per content load; surfaced as
   UPGRADES INTO (item purpose), "Later: reforges into …" and
   "Trades away: …" (bench, verbatim-mirror passive sentences).
5. **Cooking, zero-state** (ceiling 9 → 10): forage_broth (C2),
   field_rations (C5), frostbloom_pot (C8), expedition_pot (C10) — all
   conservation batches of existing dishes, repriced into the 0.12 XP cap;
   contracts trail_rations, deep_larder (the standing expedition_stew
   customer), the_far_survey, rangers_field_kit.
6. **Haven's Rest Granary** (rank-2, after the Mill): the standing food
   sink; two repeatable board needs.
7. **Lower Gallery Works** (rank-2, after the Lift): pays the
   lower_gallery rumor; gallery_tin_lode (M6) + collapsed_span (M7) at
   deliberate rate-parity with hardened copper; "Tin for the Works"
   (tin ×3 + scrap, 35 XP).
8. **The Hollow Undercroft chain** (after the Field Camp): barrow_rubbings
   (the sigil's second showing, never consumed) → the Undercroft project →
   undercroft_silkfall (F9) + deep_hollow_thicket (F10, 52 XP = the 0.173
   rate) + the undercroft_roots repeatable — together the Hollow
   destination rate that finally out-earns Mill Garden's stay-home 0.150 —
   → first_descent (consumes expedition_stew; "the Guardian is not done
   growing").
9. **The reclaim trio** (S8): bronze axe/pickaxe/chestplate melt back to
   ingots. **XP zero by final review** — pure material recovery, so the
   craft-reclaim cycle cannot out-earn honest smelting (the 0.30 XP/step
   degenerate meta died in review; axe/pickaxe craft XP trimmed 70 → 60
   into band).
10. **Warded Grove** (WC6, behind the Watchtower — its second dependent;
    council-restored: the wave's biggest bill is planks).
11. **The Provisioner's Charter** (three sequenced Haven regionals; the
    cross-region circuit; +155 one-time character XP).
12. **The information pack:** the roadmap end-cap ("The road runs out
    here — nothing is written above LV n yet"), project "Follows the …"
    lines and locked-head cards, locked-veteran rows (LOCKED, never SPENT —
    final-review fix), and **Field Notes** — the pushed Bestiary route
    (region-grouped, journey costs, knowledge-gated drop reveals, one fact
    line, static rows, no meters).

Character-XP ledger: 1,805 existing + 1,360 new = **3,165** one-time XP of
the 3,650 to character 10 — level 10 by accomplishment, test-enforced.

## 3. Balance record (the binding tables, G-5)

DEPTH-P's adopted rules, now repo canon for future content:
- Away-node rates beat same-skill home options by ≥15% raw; home nodes stay
  ≤0.70× the frontier; project-unlocked nodes may add ~10%.
- Levels 8–15 target ≤13,000 steps (~2 owner-days) each; node XP/step climbs
  0.145 → 0.20 across that band.
- Recipe XP = 0.08–0.10× ingredient gather-steps, hard cap 0.12; repeatable
  contract XP = 0.06–0.09× the ask (per skill); one-time regionals may pay
  character XP 40–80.
- No *required* item above ~20,000 expected steps; RNG-sourced needs carry
  deterministic paths (P-10).
- Rank-2 projects bill 8,000–20,000 steps total, no stage above ~6,000.
- Deliberate exceptions on the record: undercroft_roots at 0.117 (the
  Hollow destination premium is the point); elite per-kill XP capped ≤150.

Key landed rates: gallery nodes 0.137/0.131 (parity-by-design with hardened
copper), deep_hollow_thicket 0.173, warded_grove ~0.14, cooking batches
0.088–0.092.

## 4. Save / health / art / audio impact

**State stays v9.** No migration, no new events, no codec change; the new
gates are content read each command. **Health untouched** (no file under
`steps/` changed). **Zero PixelLab generations** (balance exactly 25 before
and after); eight recorded byte-copies (three gear icons wearing their
consumed donors, five node plates wearing the nodes they deepen — donor
table in `Scripts/art/package-art.js`, provenance at every mapping;
`--check` clean at 851 files). **Zero audio.** The standing content one-way
property applies: once this save acquires any new-pack item, the accepted
build refuses it (fail-closed, nothing deleted) — install is a commitment
to evaluate forward.

## 5. Verification

stride_core **733** (+21: rails 13, veteran proofs 7, gate regression 1 —
counting the armed band test), app **~845** incl. the four
depth-offensive session proofs (the full Seen→Known walk on a provisioned
save, the locked-project mirror, the lineage dedupe, the fresh-save
board/bestiary sweep); `flutter analyze` clean; `Scripts/verify.sh` clean
(one pre-existing ui-boundary diagnostic on GFCP01's `craft_memory.dart`,
unchanged since `830f1a1`, non-blocking); `package-art.js --check` clean;
seven goldens re-recorded and reviewed (the two-button row, the roadmap
lines, the craft census); five engine play-proofs (§6).

## 6. Play-proofs

`packages/stride_core/test/depth_offensive_loop_test.dart` — five
engine-driven walked proofs, every figure read from events (never
recomputed), deterministic per state:

1. **Fresh short loop — 560 gather-steps:** meadow → broth → Herbal
   Supplies complete. The SHORT band holds from minute one.
2. **The install sweep — 0 steps:** on an owner-like save, Granary and
   Lower Gallery accept contributions (a fresh save is refused
   `project_not_available`), Old Grey and the Foreman both offer, and all
   six Smithing 8–10 recipes are gated by level alone. The selection
   principle, proven: the new game is live at install.
3. **The Granary arc — 18,900 steps** from empty bags, walked as an open
   Frostmere→Mine→Woods→Hollow→Haven circuit (the honest from-empty bill;
   a closed loop bottoms at ~22.6k — recorded in the proof), completion
   event exactly once.
4. **The Undercroft chain — 15,650 steps:** the sigil shown and kept,
   both hidden nodes refused `nodeLocked` before and gathered after, the
   finale consuming exactly one crafted expedition_stew.
5. **The Frostwarden road — 10,500 steps** from the staged start: the
   deterministic summit beats the ~50,000-step frost_claw expectation
   five-fold, and no craft consumed a signature.

## 7. Wave 4 findings (all resolved or recorded)

- **Fixed:** the four hunt cards bypassed the Seen gate (visible and
  acceptable while the species was Unseen) — engine + board both gate now,
  regression-proven at both layers.
- **Fixed:** tin_for_the_works 40 → 35 XP (band); expedition_pot 120 → 90 s
  (food-band canon).
- **Recorded deferrals:** WC level 2 (its starter milestone sits at 3;
  moving it is filler), scree_crawler's signature/study content (waits with
  Q-12), Frostmere's rank-2, the elite knownXp landed conservative at 25.

## 8. The five verdicts

- **FINAL-A (skeptical RPG director): INSTALL.** "Substantially deeper,
  gated on things the owner's save has done, at zero art cost." Its two
  required retunes (clone capstones) landed: Frostwarden 8 power,
  Tin-Braced 25%.
- **FINAL-B (economy): FIX FIRST → fixed.** The reclaim degenerate meta
  (0.297 XP/step) killed by zeroing reclaim XP + trimming axe/pickaxe to
  60; hollow_thicket moved to F9 so its deep variant stops strictly
  dominating it. Verified clean otherwise: no cycles, no dead resources,
  real tradeoffs.
- **FINAL-C (identity): CLEAN.** "The branch stayed Project Stride." Every
  P-rule walked; zero signature contact; Q-12 revert-cleanliness holds.
- **FINAL-D (mobile UX): FIX FIRST → fixed.** The collapsed veteran row
  said SPENT (a false rule); it says LOCKED now. Everything else passed at
  393 dp with line budgets verified.
- **FINAL-E (the player): WOULD PLAY.** "Four fights that want my whole
  kit, three ladders that end somewhere, and tomorrow's walk has a name on
  it."

## 9. Known issues and watch items

- The Bestiary's "n of m creatures Known" line is a fact today and a
  completionism seed if anything ever rewards it (FINAL-A/C both flagged;
  watch).
- Full Woods elite sweep pays ~410 character XP per 1,000-step bounce —
  the best repeatable char-XP rate; tempered by food sinks; watch.
- `GearStats.tradeOffLines.take(2)` silently truncates a third lost
  passive; impossible with current content — a constraint on future packs.
- The pre-existing step-model guard `.signature` scan debt and the
  `craft_memory.dart` ui-boundary diagnostic are unchanged, on the record.
- Elite fights are seed-deterministic per state; the brace-or-lose margins
  hold for the proofs' exact walks (the design intent), not for every
  possible HP/gear entry state.

## 10. Owner decision packet (for the acceptance visit)

1. **The device checklist** (§11).
2. **Q-12** (`JOURNAL/OPEN_QUESTIONS.md`): the offensive added zero
   signature sinks; the packet adds two designed-not-shipped *producers* —
   Trophy Commissions (recommended) and the elite 20% roll (off).
3. **Q-06 brace evidence:** against guarded enemies, brace alone never
   converts a loss (≈4–5 net HP per heavy); its value accumulates in
   provisioned fights. The Foreman is tuned to teach exactly that.
4. The Bestiary count line (watch item above) — does it read as fact or
   pressure on the device?

## 11. Physical-iPhone acceptance checklist

1. Install; open Adventure at Haven. The board holds the Granary card
   ("Follows the Restore the Mill") and the Charter; the Goal Board /
   Field Notes buttons share the row comfortably.
2. Open **Field Notes** from Adventure: regions grouped, distances quoted,
   your Known creatures marked; no meter anywhere; close and reopen —
   instant, no animation cost.
3. Skills → any trade → scroll the roadmap to its end: "The road runs out
   here…" reads as honesty, not absence.
4. Inventory → Traveler's Tunic: UPGRADES INTO Waywarden's Tunic; bench
   comparison shows "Later: reforges into …" and, against worn gear with a
   passive, "Trades away: …".
5. Walk to the Woods (wolf Known on your save): **Old Grey** offers with
   its own card; fight it — it should genuinely threaten bronze gear.
   Complete "The Old Grey" and watch the result card.
6. At Stonefall (goblin Known): the **Foreman's** heavy telegraphs — ignore
   one on purpose, then brace one; the difference should be felt. Bring a
   stew.
7. A veteran whose base you *haven't* fully studied (likely the Matriarch
   or the Awakened) shows LOCKED with "Know the … to draw it out" — and
   its hunt contract is absent-or-locked on the board, never acceptable.
8. Contribute to the Granary and the Lower Gallery; complete a stage;
   every completion lands its result card. A locked rank-2 (if any
   remains) shows head-only with its gate.
9. Gather at a new node (Warded Grove or the gallery pair); craft
   forage_broth and field_rations; reclaim a spare bronze tool and see
   ingots return with **no XP line**.
10. The week-scale question the whole pass hangs on: after two or three
    walks, does the game feel like it has **more game** — several things
    you genuinely want to finish — without a single moment of pressure?

Then rule: keep the offensive (0028 graduates with your named changes) or
strike it (the branch reverts whole; the decision and the pin revert with
it).
