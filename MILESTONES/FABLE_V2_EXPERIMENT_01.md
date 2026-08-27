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
   pulse; (e) gameplay — deterministic rotation eligibility (a
   project-gated order never freezes a slot) with the project card
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
   atlas-adjacent; ordinary-arrival reward beat (F2, still bounded out).
6. **Found and fixed in passing (PERF-A):** `IndexedStack` never disables
   offstage tickers — the Pass-01 shell change left a hidden World tab
   driving its 30-overlay ticker at 120 Hz forever and a hidden Adventure
   still firing audio cues. One `TickerMode` wrap per child restores every
   documented assumption; the stale comments it exposed are corrected.

## 5b. Known issues, on the record

- **Herb Broth (pair) strictly dominates the base broth** from Cooking 4
  (better broth-per-herb and XP-per-herb) and both stay listed: the only
  retirement mechanism is project-based (`retiredByProject`), and inventing
  a retire-by-level mechanism mid-sprint was scope. One row of menu noise;
  a future pass can generalize retirement.
- **A project-gated deck order can occupy a rotation slot before its
  project completes**, showing as an unavailable order with its reason — a
  pre-existing pattern (Haven's mill-gated commission shipped this way and
  was device-accepted), but V2 adds three more such orders and Whispering
  Woods has only two slots, so the freeze is more visible there. It reads
  as an advertisement for the project; whether that is charm or clog is an
  owner call from the device.
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

