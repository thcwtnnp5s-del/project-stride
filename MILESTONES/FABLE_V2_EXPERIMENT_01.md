# FABLE V2 EXPERIMENT 01 — Autonomous Game-Director Pass

```
STATUS: EXPERIMENTAL — branch `fable-v2-experiment`, never auto-merged.
Nothing in this document amends canon. Where an experiment touches a
canonical concept, the canonical document is cited and left unchanged;
graduation happens only after the owner plays the build and rules.
```

**Started:** 2026-08-27, from `5ffba67` (playable-phase-2-multiregion tip,
in sync with origin). **Owner brief:** one serious sprint of creative
ownership — make the game more fun to play, connect the systems, and put the
already-paid-for PixelLab art to work. Production atlas image frozen; health,
economy, persistence and anti-FOMO invariants untouchable.

---

## 1. Design thesis

Nine audit passes (product loop, travel/world, skills/gathering,
items/crafting, combat/encounters, goals/boards, mobile UX, game feel,
architecture) and a full PixelLab asset inventory converge on one sentence:

> **Stride's systems are sound and honest, but the game hides its own
> reasons.** The engine already computes why a destination matters, what a
> skill level buys, what an item is for, and what a fight will do next — and
> almost none of it reaches the player. Meanwhile roughly half of an entire
> accepted art pack (REGIONAL_CONTENT_PACK_01) sits unintegrated, and that
> pack happens to contain exactly the content the progression audit says is
> missing: the second weapon beat, the armoured fight, the reasons to
> revisit.

### What is weakest (found, not assumed)

1. **The World screen answers "what is there", never "why go".** Board
   state, contract readiness, tracked goals, gather eligibility — all
   already projected by `StrideSession`, none surfaced on the map.
2. **Progression is invisible or false.** Skill unlock lines omit
   contract/project/tool gates (and are therefore wrong); bonus-yield
   levels look dead; the gather button can enable for a node the engine
   then refuses (`unlockedByProject` ignored by eligibility).
3. **The reward ceiling is a dead row.** All six signature drops and the
   boss's 100%-drop Hollow Sigil have no surface, no use, no acknowledgment.
4. **One weapon upgrade exists in the whole game** (Training → Bronze
   Sword), against enemies hitting 9–11.
5. **Travel — the loop walking most directly buys — is the only loop that
   never uses the reward layer.** Discovery rents half a sentence;
   the banked-step figure teleports; the biggest spend in the game is
   confirmed by sub-touch-target utility buttons.
6. **The content arc ends at a cliff** with rumors pointing at paint,
   no post-project follow-ons, and a project-less enemy region (Woods).

### What is strong and stays

The step-sync opportunity banner; the three-slot goal tracker with live
projections; community projects and cross-region contract webs; the
anti-pressure discipline (nothing expires, defeat is retreat); the reward
layer grammar; the honest travel confirmation; the audio layer.

### What V2 fundamentally improves

Six improvements, chosen because they reinforce each other — the content
gives the map something to say, the map gives the walk a reason, the
combat slice gives the new enemy a decision, the item detail gives the new
materials a story:

- **V2-A · World 2.0 — the command center.** Board summaries,
  "you carry something wanted here", gather-eligibility verdicts,
  tracked-Journey marker and state, affordability in the folded strip,
  development state, location vignettes in the inspector, cheapest-route
  correctness (Dijkstra), a primary Set-out button, and tab-state
  preservation so the map camera survives a bag check.
- **V2-B · Progression made visible and truthful.** Unlock lines that name
  their real gates, the next few unlocks (not one), bonus-yield milestones
  surfaced, and the eligibility bugs fixed.
- **V2-C · The Verge content pack (data-driven).** The RCP01-designed gear
  tier integrated: Bronze Longsword, Bearhide Coat, Hornbound Bronze Axe,
  Gloom Silk; the Scree Crawler as Stonefall's armoured second fight; three
  mid-ladder nodes (Deep Tin Seam, Silkstrand Thicket, Old-Growth
  Frostpine); the Hollow Sigil turn-in; a Woods project (Ranger
  Watchtower); post-project follow-on orders; the healing inversion fixed.
- **V2-D · Items with purpose.** Material/consumable detail (used-in,
  gathered-at, healing), trophy presentation for signatures and the Sigil,
  "makes possible" on material recipes, equip stat deltas.
- **V2-E · Combat: one decision (Brace) + knowledge that matters.**
  Q-06's own named candidate, delivered for device evaluation: Brace halves
  the telegraphed hit; knowledge tiers gate a truthful intent line; each
  enemy gets an authored tell line. No engine rebuild, no schema change.
- **V2-F · Game feel.** Discovery beat on first visits, arrival beat,
  banked-steps count-up, ready-to-deliver lines at the moment they become
  true, fault strings translated to sentences, the new-player empty-state
  nudge.

### What is explicitly NOT built

Bank caps, combat energy, road encounters, dungeons, pet gameplay, D20 /
roll-spread changes (Q-09 is owner-pending), a bestiary screen (deferred —
trophy labeling covers the near need), new regions, background health sync,
new PixelLab generation (zero spend), any atlas-image edit, atlas prop
placement (the accepted props were palette-conformed against a retired
base; re-checking them is atlas-adjacent work this sprint freezes), and the
failed/withheld assets (Weaver, Adit Bat, second character, tavern).

## 2. Rules and mistakes governing this pass

RULES: P-1..P-10 (esp. P-4/P-5 no wall-clock/FOMO, P-7 defeat costs no
possessions, P-9 tracking never escrows, P-10 no load-bearing RNG),
H-1..H-7 (health/ledger untouched), E-1 (core purity), E-2 (UI reads
projections only), E-5 (content is data), E-6 (walk the loop), G-1
(proportional verification), G-3 (unresolved stays unresolved), G-4 (never
weaken a guard), G-8 (explicit staging), A-1/A-2 (PixelLab authors, code
only transforms), A-3/A-4 (atlas frozen and protected).

MISTAKES applied: M-01 (no verification campaign), M-06/M-07/M-11 (play
the loop, look at evidence renders), M-08 (explicit paths), M-12/M-14/M-15
(no atlas work at all), M-13 (blind staging — not needed this pass; no new
generation).

## 3. Save and schema position

**State stays v9.** Brace resolves inside one command (no EncounterState
field); knowledge, contracts, projects, rumors and tracked goals are
already generic over content ids, so the new content rides the existing
`progress` structures. Content files stay schemaVersion 1 (additive
entries). No migration, no fixture change, existing saves load unchanged.

## 4. Asset integration ledger

See `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` (written this pass) for
the full audit. Integrated here: RCP01 gear/material icons (longsword,
bearhide coat, hornbound axe, gloom silk), the Scree Crawler idle+attack
sets, the five accepted vignette variants (World inspector), node scenery
derivations for the three new nodes (A-2 copies of shipped scenery).
Deliberately deferred with reasons: atlas props, fauna pack, walk cycle
(see inventory). Zero new generations.

## 5. Implementation record

Commits, on `fable-v2-experiment` over `5ffba67`:

1. `70434ed` — **Brace** (Q-06's candidate, `DECISIONS/0027`): CombatBrace
   command, CombatBraced event, halved-reply arithmetic pinned from the
   events' own rolls; `tellLine` content field; no state-shape change.
2. `041e3d4` — **The Verge content pack + asset recovery**: the gear tier,
   the Scree Crawler, three mid-ladder nodes, the Sigil contract, the
   Ranger Watchtower, post-project orders, P-10 backstops, the healing
   inversion fix; RCP01 icons/vignettes/crawler frames integrated and the
   pack's packaging sources tracked (fixing the latent clean-checkout
   `--check` failure the untracked boar/ram/salamander/bear sources had
   carried since EPL01). Proven by play: `verge_tier_loop_test` — 35,730
   steps, 5.1 ordinary days, to the Bronze Longsword.
3. `dd848e5` — **Combat surface**: the knowledge-gated intent line
   (Studied finally pays) and the Brace button; stage plays the stance as
   a planted idle beat (A-1: no invented art).
4. `e0c3d01` — **World command center, progression truth, item purpose,
   game feel**: board summary + carry-wanted on the inspector; vignette
   variants as destination previews; tracked-Journey toggle; Dijkstra;
   primary Set out; IndexedStack shell; truthful unlock gates + next-three
   unlocks + bonus milestones; eligibility project-gate/tier fixes; item
   purpose blocks; "makes possible" at the bench; DISCOVERED beat;
   banked count-up; equip stat story; fault sentences; empty-goal nudge.
5. `c4259c7` — cheapest-route regression pin, the destination-inspector
   evidence capture (M-06), details scroll into view.

**Save:** v9 unchanged, no migration, existing saves load as-is.
**Content:** schema 1, additive; enemy count 8 → 9 under `DECISIONS/0027`.
**PixelLab generations: zero.** Audio: zero new assets (the discovery beat
is deliberately silent; region music continues).

### Deliberately deferred (each with its reason on the record)

- **Fauna beats, atlas props, walk cycle, 8-direction stills, canvas
  backpack, full-scene recrops, WRD01 landmarks** — see
  `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` §3.
- **A bestiary/journal screen** — trophy labeling in the item purpose
  block covers the near need; a collection surface is its own design.
- **Character-tab regrouping (UX audit S4)** — the current arrangement is
  owner-accepted from device passes; relitigating presentation the owner
  ruled on is not an experiment's call. Recommendation stands in the audit.
- **Ready-transition lines mid-play (feel audit F6), ordinary-arrival
  beat (F2), newly-affordable marker pulse (F4), tracked-goal marker on
  the map itself** — bounded out; the sync banner and the panel state
  carry the near need.
- **Signature-drop sinks** — D0023 §5 frames signatures as trophies; a
  sink is the rule owner's question (now `JOURNAL/OPEN_QUESTIONS.md`
  Q-12). V2 labels them honestly instead.

---

# ITERATION 02 — Health forensics + freshness pass

**Started:** 2026-08-27, from `e6142a8`, on the owner's verdict that Pass 01
is directionally successful and everything ships forward. Brace's
downgrade caveat is owner-accepted; the atlas image stays frozen.

## Iteration 02 thesis

1. **Health hypothesis — confirmed by forensics:** the Oura/Stride gap
   (3,121 vs 5,732) is Q-08's per-origin overlap by design, not a replay
   bug. The adapter reads per-source statistics and never Apple's merge;
   the ledger sums origins (H-1); Oura's app shows one origin's share.
   Reproduction pinned in `multi_origin_overlap_test.dart` and
   `sync_diagnostics_test.dart`.
2. **Missing evidence:** the on-device split. Provided by the new
   read-only **Sync details** card (Step Tracker): today per pseudonymous
   source, last-sync read/credited, lifetime ledger. H-7 honored — labels
   are positional, no identity ever shown. **Outcome B** of the P0 brief:
   no accounting change is justified yet; the next device test decides
   Q-08 on evidence. Grant semantics remain the owner's decision.
3. **Visual direction:** *dark fantasy travel journal, rich biome color,
   warm reward light* — a token extension of the existing palette (region
   inks/deeps per place, `danger` for combat threat, `rewardLight`
   replacing the off-canon teal victory frame, `positiveReady` readiness,
   ember primary-button treatment), landed structurally on Adventure,
   Skills, Craft, Combat, World and Character.
4. **Major changes selected:** (a) the visual system above; (b) travel as
   an event — a walk-cycle journey card on Set out, arrival flow, haptic
   punctuation; (c) ambient life — fauna beats at four locations plus a
   cat-crossing beat, from already-accepted art; (d) a game-feel kit —
   haptics behind one gated seam with a settings toggle, animated XP
   bars, tappable opportunity rows with count-up, encounter entrance,
   bonus-yield acknowledgment, READY-flip settle, banner-lifetime marker
   pulse; (e) gameplay — deterministic rotation eligibility (rotation
   stops *dealing* project-gated orders into slots; 5b records the two
   paths the filter does not reach) with the project card
   advertising what completion opens, graduated loot intelligence
   (Studied buys frequency words, Known buys exact odds), bonus-yield
   milestones lighting the dead skill levels plus the Hornbound Axe's
   missing +15%, and the tracked-Journey marker on the atlas;
   (f) the health diagnostics card.
5. **Deliberately deferred:** Q-08 semantics (owner); the merged-total
   adapter query (Swift change, its own decision); broth-pair
   supersession mechanism (the dominance is asymptotic — with two herbs
   the base broth is the only option; a generic `supersededBy` belongs to
   a pass that needs it); Stonefall fauna (the 16 px bat reads as a moth
   — withheld verdict respected); atlas props and everything
   atlas-adjacent; ordinary-arrival reward beat (F2, still bounded out);
   the cat-crossing beat (a *crossing* needs a layer that translates over
   time, and the ambient system deliberately has no moving layers —
   inventing one mid-sprint is scope; the packaged cat_walk frames wait
   for it).
6. **Found and fixed in passing (PERF-A):** `IndexedStack` never disables
   offstage tickers — the Pass-01 shell change left a hidden World tab
   driving its 30-overlay ticker at 120 Hz forever and a hidden Adventure
   still firing audio cues. One `TickerMode` wrap per child restores every
   documented assumption; the stale comments it exposed are corrected.

## Iteration 02 implementation record

Seven commits on top of `e6142a8`, in order:

1. **`8e18fd9` — Health forensics and diagnostics.** Q-08 overlap pinned
   by 5 tests (`multi_origin_overlap_test.dart` cases incl. the phone
   1500+1500 / watch 1450+1450 reproduction and the late-batch watermark
   case; `sync_diagnostics_test.dart` double-sync-adds-zero). New
   `SyncDiagnosticsView` projection (per-origin today/retained under the
   same local-day policy the history uses; totals; epoch retirements;
   cursor presence) and the Step Tracker's collapsed-by-default **Sync
   details** card. Outcome B: diagnostics sufficient; no semantics
   touched.
2. **`4707a2e` — TickerMode P0.** Per-tab `TickerMode` wraps in the
   shell; hidden tabs stop ticking and cueing; stale comments corrected.
3. **`efa29ad` — Visual foundations.** The V2 token section in
   `StrideColors`; region-tinted headers app-wide; ember primary button
   with 90 ms press dip; `SectionCard` wash primitive; Skills washes +
   icon plates + eased XP bar; craft readiness colors; combat danger ink
   and warm reward light (two L-16 drifts repaired, three teal-selection
   drifts moved to brass); **Sound & feel** haptics switch persisted with
   audio settings; `AudioController`'s one gated haptic seam.
4. **`0e07aa2` — The feel kit.** Haptic call sites (reward layer
   tier-switched at the layer itself so no caller doubles it; granting
   sync only when steps banked, both buttons; Set out; Start Combat;
   heavy blow at segment start, silent on skip; watched gather strike —
   the queue loop deliberately silent; equip success click). The
   opportunity banner as a moment: reward wash, staggered reveal per
   granting sync, banked count-up (reduced-motion prints flat), each row
   a door — journey rows front the World tab through the new `ShellTabs`
   handle, pursuit/contract rows open the Goal Board. Entrances/settles
   with explicit reduced-motion branches: fight entrance (stage then
   controls, once per fight), travel result line, equip stat settle,
   READY pill. F4 repaired: the you-are-here pulse wears warm arrival ink
   exactly while the journey result line stands. `ActionReport.bonusYield`
   (committed quantity vs the session's own profile-scaled `yieldOf`) and
   the "+N extra — your craft at work" line in strip and layer.
5. **`d8a9287` — Gameplay depth.** Engine: rotation skips
   project-gated candidates (fallback to old behaviour when every
   candidate is gated; replay-safe — slots were always recorded on the
   event; new engine test cycles Haven's deck twice then stands the mill).
   `DropPreview.chancePercent` with knowledge-graduated display (nothing
   below Studied; "usually/often/rarely" at Studied; exact % at Known;
   zero-chance stays silent — widget-tested). Content only: nine
   bonus-yield milestones (Duskcap 5, Tin 5, Deep Tin 6, Hardened 7,
   Rimefrost 7, Frostpine 6, Old-Growth 9, Silkstrand 8, Hollow Thicket
   12, all 10 %) and the Hornbound Bronze Axe's
   `toolBonusYieldPercent: 15`. The tracked Journey's gold ring on the
   atlas (`goalActive`'s first use there; absent at the current place;
   widget-tested). `ProjectView.opens` + the project card's "Opens:" line
   (joined over the same gates the engine refuses with).
6. **`bca48dc` — Asset integration.** RCP01's four accepted fauna stills
   composed into every solo ambient scene per region via
   `AmbientAssets.scenesFor(vignette)` (hare/Haven, songbird/Woods,
   crow/Hollow, ptarmigan/Frostmere; Stonefall empty by QA verdict;
   `pet_cat` excluded by the soloScenes predicate); composition test
   extended to hold fauna variants to the same three geometry rules. The
   Traveler's six-frame west walk packaged (trav_zip source; east
   rejected — vest vanishes f0–f1; mirroring is PixelLab's call) and the
   **travel transition card**: ~1.3 s over the destination's alt
   vignette on committed arrivals, one-shot ticker (the s01a
   foreground-only guard rejected the Timer draft and held), tap to
   dismiss, Reduce Motion skips, precache race-bounded. Both source trees
   tracked so `--check` passes from a clean checkout.
7. **`cd098e9` — Screen evidence.** The harness's Iteration 02 run: 11
   captures at 393×852 from one real session (fresh Adventure, World,
   journey ring, sync banner, gather beat, Sync details open, Skills,
   travel card mid-play, discovery layer, arrival, Woods-tinted header),
   all reviewed.

**Game-journey simulation:** 25 commands through the production engine
(sync → herbs → Herbal Supplies → track Woods → travel → wolf (7
rounds, HP 40→13) → logs → plank → home (safe-arrival heal 13→40) →
mill contribution → refusals for a node/enemy not present, each with its
sentence → forage to 200 XP). Every spend exact, every refusal truthful,
no defect surfaced.

**Verification at closeout:** stride_core 707, stride_health 143,
stride_storage 108 (five known lock probes still environment-bound),
app 713 + 3 evidence, analyze clean, package-art `--check` 830 files
clean, goldens byte-stable except where reviewed, guards (core purity,
origin privacy, single-writer, UI boundary, source safety, dependency
policy, rulekit, guard parsers) all OK.

## 5b. Known issues, on the record

- **Herb Broth (pair) strictly dominates the base broth** from Cooking 4
  (better broth-per-herb and XP-per-herb) and both stay listed: the only
  retirement mechanism is project-based (`retiredByProject`), and inventing
  a retire-by-level mechanism mid-sprint was scope. One row of menu noise;
  a future pass can generalize retirement.
- **A project-gated deck order can still occupy a slot on two paths the
  Iteration 02 rotation filter does not reach** (the filter governs
  *deals* only): (a) a virgin board's opening window is the deck's first
  `boardSlots` entries, unfiltered — today every gated order is authored
  outside its window, and the new content-guard test in
  `progression_loop_test.dart` ("no project-gated order sits inside any
  virgin board window") now pins that as a rule; (b) **the owner's
  existing on-device save**, whose recorded slots may already hold a
  gated order dealt under the old rules — rotation replaces only a
  completed contract's own slot, and a gated order cannot be completed,
  so it sits until its project stands. On that save it reads as an
  advertisement for the project; whether that is charm or clog is an
  owner call from the device. Fresh playtests never see it.
- **The three Verge nodes reuse their neighbours' scenery byte-for-byte**
  (A-2 copies), so two rows at one location can show identical thumbnails
  distinguished by name and level. Honest placeholder; distinct authored
  node art is a recorded future PixelLab round.
- **The discovery layer fires only from the atlas travel path** — today the
  only travel path; a future second one must call it too or first visits
  there go unacknowledged.
- **stride_storage: five cross-process lock probes time out on this
  development machine** (pre-existing, recorded since v2.14; the package is
  untouched by this experiment).

## 6. Device acceptance checklist (iPhone, Release via
`Scripts/ios/build-release-device.sh`)

Existing save expected to load with **banked steps, lifetime figures,
inventory, equipment, XP, location, goals and encounter state intact** —
nothing here migrates anything.

> ⚠️ **One-way while evaluating combat:** a braced round writes a
> `CombatBraced` journal event the accepted build has never heard of. Going
> *back* to the `playable-phase-2-multiregion` build after bracing makes the
> older build read the journal from that line on as a torn tail and **quietly
> discard everything committed after the first brace** (it repairs to the
> snapshot + prefix; nothing corrupts, but progress from that point is
> lost). Evaluate the experiment to a verdict before reinstalling the
> accepted build — or simply don't Brace in a session you intend to carry
> back.

> Also watch, not just check: **scrolling and tab-switch smoothness.** The
> shell now keeps all six screens alive so the map camera survives a bag
> check; the cost on real hardware (memory, rebuild time per sync) is
> exactly what tests cannot measure. If the World tab janks on sync, say so.

1. **World**: select each place — the panel shows Work counts, development
   word, gather verdicts; a reached destination shows its variant picture;
   the folded strip mutes an unaffordable cost and quotes the shortfall;
   "Set as Journey" reads "Journey set — clear" once tracked; the travel
   confirm's Set out is the big button.
2. **Tab flow**: World → Inventory → World; the camera and selection must
   survive the round trip.
3. **First visit** (any place not yet reached on the save, or a fresh
   playtest): the DISCOVERED layer rises with the place's picture.
4. **Skills**: each card lists its next unlocks with real gates ("+ a
   contract at…", "+ a tier-1 pickaxe"); the +10% yield milestones show.
5. **Stonefall**: the Scree Crawler stands on the encounter card and
   fights (idle + attack; victory holds the hit pose — no defeat track,
   by QA verdict); at Mining <4 the Deep Tin Seam row explains its gap.
   **Judge the crawler's identity read** — the pack accepted it READY WITH
   NOTE against a "rock with legs" risk; if it reads as rubble, its
   correction round is already recommended in the pack record. Know going
   in: against a Bronze Sword it is a deliberate slog (≈12 low-risk
   rounds) — it is authored as the **Longsword's showcase** (6 rounds with
   real bite); with a Training Sword it is a wall, and retreat is free.
   The Crawler Cull bounty pays the visit either way.
6. **Combat**: the intent line appears once an enemy is Seen and deepens
   at Studied — a guarded creature's authored tell shows **only on its
   telegraph turn**, plain rounds say so plainly; Brace halves the
   telegraphed heavy (watch the guardian or salamander). **Also brace once
   against a steady enemy** (goblin, ram): it should feel like a
   deliberately wasted round, which is the Q-06 evidence the owner is
   collecting — is a situational second action worth its button?
7. **Craft**: Herb Broth (pair) at Cooking 4; the Verge recipes appear at
   Smithing 5–6 with the RCP icons; a material recipe says what it makes
   possible.
8. **Inventory**: tap a material — the purpose block opens and scrolls
   into view; a signature drop says it is a keepsake; equipping a weapon
   says "ATK a → b".
9. **Boards**: The Scholar's Interest at Haven once the Sigil is held
   (shows, never consumes); Feed the Forge in the Mine deck; Bear Watch
   among the Woods bounties; the Ranger Watchtower project accepts
   contributions.
10. **Header**: a sync counts the banked figure up rather than teleporting;
    sync faults (if any) read as sentences.

### Iteration 02 checklist — HEALTH (the P0, decided on this evidence)

Take these together, within a minute of each other:

1. **Oura app screenshot** — today's step figure.
2. **Apple Health app** — today's step total at the same timestamp, and
   open its *Sources* list for steps (note how many contribute).
3. **Stride** — the header's banked figure and Character → Step Tracker's
   today figure.
4. **Source diagnostic** — Step Tracker → Sync details → SHOW. Read the
   per-source rows: with Oura + iPhone active there should be **two
   sources**, and their today figures should sum to Stride's today.
   Compare each against the Health app's own per-source numbers — the
   labels are anonymous by design (H-7); identify them by matching the
   figures against the Sources list from item 2. **The letters are
   positional, not stable identities:** if a new step-writing app ever
   joins, "Source A" can silently name a different physical source than
   it did last session — always re-identify by figures, never by
   remembered letter.
5. **Double-sync adds zero** — tap Sync steps twice with no walking in
   between: the second sync must say "No new steps to bank" (or "No new
   steps since the last check"), the banked figure must not move, and
   "Credited, lifetime" must stay put. "Syncs committed" counts
   **committed checkpoints**, not taps: it rises when a sync commits one
   and a no-change read may legitimately leave it unchanged — either
   behaviour is correct and neither is a fault. The defect signals are
   the banked or credited figures moving.
6. **No unexpected jumps** — after the pair of syncs, the banked figure
   equals what it was plus the first sync's banked line, exactly.

If the two-source split matches Health's per-source numbers, the 1.84×
observation is Q-08's per-origin overlap working as documented, and the
question of *whether Stride should credit both sources* goes to the
owner as the Q-08 decision — with real numbers attached.

### Iteration 02 checklist — UI (first-minute freshness)

7. **First minute, unprompted:** open the app and just look. Expected to
   land without hunting: the header wearing the region's color; the ember
   primary buttons; the Skills tab's five trade atmospheres; a granting
   sync's banner counting up with its opportunity rows; the animated XP
   bar on Skills. Say which (if any) did NOT register.
8. **Adventure** — region-tinted header; ember Goal Board button; a
   gather's result strip (with "+1 extra" if a bonus procs at Meadow
   Patch ≥ Foraging 2).
9. **Character** — Sound & feel card has the Vibration switch; Step
   Tracker reachable; Sync details opens/closes.
10. **Skills** — washes, icon plates, XP bar eases on a gain.
11. **Inventory** — equip: the "ATK a → b" line settles in; the click
    haptic fires (if vibration on).
12. **Craft** — a craftable row wears the moss edge; selection is brass,
    not teal.
13. **World** — tracked Journey's gold ring; warm arrival pulse while the
    arrival line stands; region header changes after travel.
14. **Combat** — enemy HP in rust, player in parchment; intent line in
    danger ink on telegraph turns; victory layer in warm gold, not teal.

### Iteration 02 checklist — GAME FEEL (ten moments)

With Vibration ON, each of these should register as one clean beat, and
none should fire twice or loop:

15. **Sync** that banks — one light tap + the banner's count-up.
16. **Travel** — Set out: one light tap at the commit.
17. **Arrival** — the walk card plays ~1.3 s (tap dismisses early); with
    Reduce Motion ON it must not appear at all.
18. **Gather** (watched, single) — light tap at the strike; the strip's
    beat reveals.
19. **Skill-up** — the level-up layer rises with a medium buzz (heavy if
    it is a MAJOR moment).
20. **Craft** — an equipment craft's reward layer: medium buzz, warm
    light.
21. **Equip** — the selection click + the stat line settling.
22. **Discovery** — first visit: the DISCOVERED layer with its picture.
23. **Combat** — Start Combat medium; the heavy blow lands heavy exactly
    when it lands on screen; no haptic per ordinary swing.
24. **Goal progress** — a job flipping READY lands its pill with a small
    settle; the banner's journey row actually fronts the World tab when
    tapped.

### Iteration 02 checklist — PERFORMANCE

25. **World tab switching** — Adventure ↔ World ↔ Inventory round trips:
    no jank on entry, and (the TickerMode fix's point) leaving World
    parked should NOT warm the phone or drop frames elsewhere.
26. **Map camera preservation** — pan somewhere, visit the bag, return:
    camera and selection exactly where they were.
27. **Scrolling** — the Goal Board and Inventory at full content: smooth.
28. **Animation smoothness** — the walk card, the fauna stills' scene
    entrances, the XP bar ease, the count-up: all clean at device
    refresh; nothing stutters while a sync commits.


---

# ITERATION 03 — Depth: professions, crafting, goals

**Started:** 2026-08-27, from `63ae0c3`, on the owner's positive device
verdict on Iteration 02's presentation direction and the explicit brief:
double down on GAME DEPTH — more to understand, pursue, unlock, gather,
craft, equip, complete, plan, revisit, level.

## Iteration 03 design thesis

**1. What is shallow about profession progression.** 19 of the 60
level-slots (levels 1–12 × 5 skills) are dead and *visibly* dead — the
Skills screen honestly shows where each ladder ends. Smithing stops at 6,
Cooking at 7, Mining at 5 (bonuses to 7), Woodcutting has a genuine early
cliff (levels 2–4 are one node ground ~52 times). The XP thresholds
themselves are sound; the cliffs are purpose-cliffs.

**2. What is shallow about Craft.** The screen is an honest vertical list:
readiness is scannable (Iteration 02) but not *organized* — no
ready-first ordering, no "one ingredient away", no "where do I get the
missing material", no chain navigation, no goal relevance. It answers
"can I?" and not "what should I plan?"

**3. Dead or underused items.** All six signature drops (Pristine Wolf
Fang, Great Tusk, Goblin Toolhead, Ember Core, Frost Claw, Pristine Horn)
have zero consumers and zero reactions — the Known tier's headline reveal
pays nothing (Q-12). Three of four starting items are permanent fossils
(the Reinforced Pickaxe consumed the fourth). boar_hide and heat_scale
never touch a recipe; gloom_silk and boar_tusk have one lifetime use
each; hearty_stew — the Cooking capstone — has zero external demand while
level-1 broth has eight sinks and the best heal-per-step in the game.
`recipe.pine_plank` at 110 XP is a smithing-XP dominance bug (~2.2× any
alternative per step).

**4. Dead skill levels.** Foraging 9/11; Woodcutting 2/4/8/10–12;
Mining 8–12; Smithing 7–12; Cooking 2/5/8–12.

**5. Regions needing progression purpose.** Forgotten Hollow above all:
no board, no project, no development state — one boss kill and two forage
nodes behind a 4,800-step round trip, dead after the Longsword. Frostmere
and Haven lack the lift's "project deepens the terrain" payoff; the Woods
cap Woodcutting at a level-1 node; Stonefall needs its trophies to matter
at the forge, not new terrain.

**6. The 4–7 major depth improvements implemented.**
(a) **The Skill Detail roadmap** — tap a Skills card → a per-profession
roadmap of every level with content, past/current/next/future, each
unlock joined to what it yields, what that feeds, and what still gates it.
Entirely derived from content projections; survives future packs.
(b) **The Craft planner** — readiness-first organization (READY → ONE
INGREDIENT AWAY → MISSING MATERIALS → LOCKED), missing-ingredient
sourcing ("Gloom Silk → Silkstrand Thicket, Forgotten Hollow · dropped by
…"), chain navigation (an ingredient that is itself crafted links to its
recipe), and goal relevance — the recipe list becomes a progression
planner.
(c) **The signature Masterwork set** — six strictly optional gear
variants, each reforging an existing piece around one signature drop
(Fang-Hilted Sword, Tuskbound Jerkin, Goblin-Toothed Axe, Scale-Warmed
Chestplate, Clawguard Coat, Hornpoint Pickaxe). Every base capability
keeps its deterministic path (P-10); every variant consumes its base item
(so the byte-copied icon never sits beside its donor); three genuine
equip decisions appear (gatherer-identity armor that survives upgrading,
early-10% vs later-15% tools, a three-way alpine loadout). This is the
experiment's answer to Q-12, recorded below.
(d) **The Forgotten Hollow expedition layer** — the Field Ledger board
(2 slots, 4 local needs + a Guardian bounty), the Hollow Field Camp
project (3 stages, materials from four regions), development
Untamed → Charted, safe-after-camp, and the camp-gated Veiled Silkstrand
(Foraging 8, silk ×2). The Hollow becomes the dangerous mastery-foraging
region you *tame*, not a one-and-done trophy stop.
(e) **The food ladder repair** — the Mill retires base Herb Broth in
favour of the pair (they never coexist; dominance ends), the skewer is
re-costed, and two new cooked-item-as-ingredient recipes extend Cooking
to 9 (Traveler's Ration at 4, Expedition Stew at 9 — the first recipes
that consume other cooked food, giving broth and stew downstream lives).
(f) **Regional depth nodes** — Heartwood Oak (Woods, WC 4: kills the
early cliff), Old Workings (Stonefall, Mining 8, lift-gated: mined scrap,
the lift's second payoff), Sheltered Frost Meadow (Frostmere, F 7,
shelter-gated: blossom ×2), Mill Garden (Haven, F 7, mill-gated: the
start region visibly blooms from the player's own project).
(g) **Goal chains** — 8 new contracts and the camp project wire the above
together: gear-as-proof (The Smith's Measure shows the Longsword),
show-don't-consume trophy goals (A Hunter's Token), the Hollow chain
(silk → crates → camp → stores), and a post-lift pine sink (Gallery
Props).

**7. How they connect.** One loop, stated once: walking powers travel to
region-specific nodes and enemies → gathering and fighting fill skills
and bags → skills unlock deeper nodes and recipes the roadmap *shows in
advance* → crafting turns materials (now including trophies) into
capability the planner *organizes* → contracts and the camp project spend
that capability and permanently open more terrain → the new terrain is
the next thing the roadmap shows. Every new item has ≥2 relationships;
every region keeps a revisit engine.

**8. Content added.** 8 items (6 Masterwork gear + 2 foods), 8 recipes,
5 nodes, 8 contracts, 1 project, 4 content edits (broth/handle
retirement, skewer re-cost, pine-plank XP 110→40, Hollow location
fields). Zero engine changes for content; zero new PixelLab generations —
all icons and plates are recorded A-2 byte-copies of items/plates the new
things consume or deepen.

**9. Deliberately deferred.** The Iron tier (its ore/ingot icons would be
pixel-identical twins of copper/bronze in the same bag — it waits for an
icon round and its own decision note; Mining 8 gets Old Workings
instead, Smithing 8+ stays honestly open); the meat/hunting cooking line
(game meat needs from-scratch icons); the Tusk Spear (same); a bestiary
surface (Q-12 option 1 — presentation, another pass); retire-by-level
engine mechanism (the project pattern covered the only real case);
gloomshade moss and any new gathered material (icon-blocked); a sixth
enemy/location/skill (frozen counts).

**Q-12, addressed on the experiment's terms:** D0023 §5 framed signatures
as trophies-never-ingredients and D0027 authorized no sinks; the owner's
Iteration 03 brief explicitly asks for dead materials to gain purpose and
names "special drop: equipment + contract" as a desired item
relationship. The experiment therefore ships **strictly optional
consumption** — every Masterwork is a sidegrade/variant of gear obtainable
deterministically, no contract *consumes* a signature (A Hunter's Token
shows one, `requiresOwned`), and P-10 holds everywhere. This is evidence
for the owner's Q-12 verdict, not its pre-emption: if the owner rules for
pure trophies, the six recipes revert cleanly and the items go with them.
