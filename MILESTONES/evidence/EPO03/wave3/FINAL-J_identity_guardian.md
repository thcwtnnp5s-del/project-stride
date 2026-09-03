# FINAL-J — Identity Guardian, EPO03 close

**Branch:** `fable5-executive-production-overhaul-03` · **Base:** `59c4723`
**Date:** 2026-09-03 · **Generations spent:** 0
**Question:** did a presentation round quietly change the game?

**Verdict: IDENTITY INTACT.** No violation. No guard script or test
assertion was weakened; every moved assertion was re-anchored to moved
presentation at equal or greater strength.

---

## 1. The absolute locks — PASS

`git diff 59c4723..HEAD --stat -- packages/` returns **nothing**. The entire
engine — health accounting, granted-step monotonicity, the forward-only
cursor, source accounting, the economy epoch, replay protection, save
atomicity, single-writer/CAS, crafting step cost, defeat/retreat resolution —
is byte-identical to the base. `packages/stride_health/` and `lib/health/`
are likewise untouched, so foreground/manual sync and the no-background-Health
rule cannot have moved.

- **Save state version: v9, unchanged.** `packages/stride_core/lib/src/save/save_codec.dart:839`
  still reads `int get version => 9`, in a file with no diff. EPO03 saves are
  interchangeable with base saves.
- **Content JSON:** exactly one file changed, `assets/content/v1/atlas/atlas_layout.json`
  — a *presentation* layout file. Every other content pack (items, recipes,
  nodes, enemies, routes) is untouched.
- **Within the atlas layout**, gameplay-bearing collections are identical in
  count: `locations` 5 to 5, `landmarks` 23 to 23, `routes` 5 to 5. Only
  decoration moved: `props` 6 to 3, `overlays` 40 to 39. `schemaVersion`
  5 to 6, and `lib/runtime/atlas_layout.dart:1000` gates the new keys behind
  that version with a throw, in the same additive ladder as versions 2-5.
- **`lib/runtime/` diff is confined to `atlas_layout.dart`.** No `lib/state/`
  or `lib/services/` change at all.

Nothing about what the player owns, can make, can fight or can walk to
changed this round.

## 2. Strategic travel — PASS

Travel is still one explicit, priced command.

- The only dispatch on the World screen is `controller.travel(option.id)`
  (`lib/ui/screens/world/world_screen.dart:1160`) and
  `controller.travelJourney(legs)` behind the confirmation in
  `lib/ui/screens/world/atlas/atlas_selection_panel.dart:150`. Both sit under
  `Set out` — the confirm step, which prints the cost ("Set out · N steps",
  `atlas_selection_panel.dart:726,746`).
- **The peek's compact Travel only arms.** `world_screen.dart:580-583` does
  nothing but `_stop = _SheetStop.half; _travelArmed = true;`. It raises the
  sheet and opens the confirmation; it does not travel.
- `_TravelControls.armed` is handled as an **edge, not a state**
  (`atlas_selection_panel.dart:698`):
  `if (!oldWidget.armed && widget.armed && widget.open) _confirming = true;`
  — so a player who Cancels is not re-armed by the next rebuild.
  `_travelArmed` is cleared on arrival, on return to peek, and on selection
  change (lines 271, 326, 451, 606).
- Cost invalidation survives: a changed `way.totalCost` still collapses the
  confirmation (`didUpdateWidget`, unchanged from base).
- Nothing auto-travels. The screen's own header comment states the invariant
  and the code keeps it.

## 3. No pressure — PASS

- A keyword sweep of every added line under `lib/` for
  `streak|expire|countdown|daily|timeLeft|urgen|decay|multiplier|limited time|purchase|iap`
  returns **zero hits**. No FOMO, no streaks, no decay, no monetization
  entered the round.
- Nothing counts up. The tally slip states final figures on ruled lines;
  `test/screen_evidence_test.dart` now asserts the stated figure literally
  (`find.text('+${drives.lastAction!.bonusYield}')`), which a counting
  animation would fail.
- Nothing loops. `lib/ui/components/activity_result.dart`'s `_life` controller
  is a single `forward()` to expiry; `lib/ui/components/reward_beat.dart`'s
  `_clock` is a one-shot stagger. Neither `repeat()` nor `Timer.periodic`
  appears in any of the three files.
- **Reduce Motion leaves them fully static.** `reward_beat.dart:384` sets
  `_clock.value = 1` — every beat at full presence, immediately.
  `activity_result.dart:783` gives the card "full presence for the whole
  life"; `lib/ui/components/reward_layer.dart:68` likewise. Information never
  depends on motion.
- **M-16 satisfied: motion does not silence audio or haptics.** In
  `reward_layer.dart` the tier haptic (`hapticHeavy`/`hapticMedium`,
  `payoff: true`) and the `SemanticsService.sendAnnouncement` are issued
  *before and outside* the `reduced` branch, so a Reduce Motion player keeps
  the tap and the announcement. `activity_result.dart`'s promotion haptic
  fires in `_consider`, gated on the Sound & feel toggle only — the correct
  single owner. The two settings remain independent.
- A hidden tab's card **waits** rather than expiring (`activity_result.dart`,
  `TickerMode`), which is the anti-pressure behaviour rather than a timer.

## 4. G-3 discipline — PASS

- **Q-29** (what a chapter of the recipe book is called) is recorded
  **UNRESOLVED** with the owner named (Systems Designer with Creative
  Director), an explicit note that naming progression tiers "is a systems and
  fiction decision with consequences past this screen", and the observation
  that a screen inventing the vocabulary in passing is exactly what G-3
  forbids. **It shipped with level ranges only** — the honest, non-committal
  string — and the entry records that the fix costs one line in each of two
  places. This is the correct behaviour, not a workaround.
- **Q-30** (what is on the combat page between rounds) is recorded
  **UNRESOLVED**, explicitly "recorded rather than guessed (`RULES.md` G-3)",
  targeted at Creative Director / Lead Game Designer "before anyone fills it".
- **Q-11 / ART-09** was *closed* rather than answered unilaterally, and closed
  on measurement: both competing specs were for a nine-patch that provably
  could not be cut from any of the four rasters ("corner blocks and edge runs
  are entirely empty"). The superseded spec is named as superseded, and the
  unwired assets are pinned by an assertion in `test/combat_ui_test.dart` so
  they cannot drift back. That is a resolution by evidence, not by preference.
- **Q-13, Q-18, Q-25, Q-28** are marked resolved to `DECISIONS/0033`. These
  were resolved by an **explicit written owner instruction**, which
  `CLAUDE.md` "When instructions conflict" ranks above `DECISIONS/` and
  `GAME_BIBLE/`. Recording it in an ADR is precisely what converts an owner
  instruction into a decision rather than an inference. No team decided
  anything that was the owner's to decide.

### `DECISIONS/0033` is an accurate record — and protection was re-baselined, not weakened

The ADR quotes the owner directive verbatim ("THE MAP MAY BE REPAINTED. THE
REGIONS MAY BE RECOMPOSED.", "some older terrain should not be protected
merely because it exists"), names what it amends (`0030`'s frozen-core
bullet), and states the mechanism. Checked against `Scripts/art/package-art.js`:

| ADR claim | Code | Verdict |
|---|---|---|
| `PROT` / `band` not edited | no `PROT` constant appears among the diff's deletions | **holds** |
| `keepRepair` not edited | no `keepRepair` line in the diff at all | **holds** |
| golden comparison not edited | comparison retained; a mask touching an undeclared golden **throws** (`reauthorizes unknown golden`, `mask touches golden … but`) | **holds — and tightened** |
| drift throw not edited | the throw is unchanged; only its *bounds* moved | **holds** |
| new pixels become the protected interior | `approved` becomes `let` and is **re-taken** (`approved = base.clone()`) as the block's last statement | **holds** |

Two changes make the guard *stronger* than the base, not weaker:

1. **`claimed` (`const claimed = new Uint8Array(1024 * 1024)`).** Every pixel
   the EPO03 block wrote is marked, and `protDepth` returns `PROT.band + 1`
   for a claimed pixel **anywhere on the canvas** — so the sage pass, the
   drift guard and any layer inserted later cannot repaint the new approved
   state. Base protection stopped at the (256..768)-squared core; claimed
   pixels are now hard core outside it too.
2. **The drift guard walks the whole canvas.** The only deleted lines are the
   loop bounds — `for (let y = PROT.y0; y < PROT.y1; y++)` and
   `for (let x = PROT.x0; x < PROT.x1; x++)` — replaced by a full 1024-squared
   walk. The *tolerance* was not touched. A narrower loop replaced by a wider
   one over the same throw is a strengthening.

Every EPO03 region is also forced through gates that did not exist before:
missing file throws, `status` must be accepted, duplicate ids throw, salt must
match, dimensions must match, and an undeclared golden collision throws. The
one intentional exemption — "No protDepth / keepRepair clip: this layer IS the
new approved state" — is the re-baseline itself, executed before the snapshot
is re-taken, exactly as the ADR describes.

*One documentation nit, not a violation:* the ADR describes compositing
"before the line that reads `const approved = base.clone();`", whereas the
implementation composites after it and **re-takes** the snapshot. Same
guarantee, cleaner mechanism; the ADR's prose is one revision behind its own
code. Worth a one-line amendment, nothing more.

## 5. Guards — PASS. Nothing weakened.

Every assertion that moved, moved because the presentation moved, and each was
re-anchored at equal or greater strength.

**`test/visible_equipment_test.dart` — strengthened.** The headline change
looks like a loosening and is the opposite: `expect(figureFor(waywarden_tunic), _base)`
became `isNot(_base)`. The old line asserted the *bug* — the Waywarden tunic
silently drawing the base white shirt in all ten contexts. EPO03 gave it a
body, and the new assertion guards the fix. The hardcoded `hasLength(3)` became
`hasLength(classCount)` where `classCount = TravelerArt.armorFigures.length` —
this still asserts the real claim (no two armour classes share a picture) and
is now roster-derived, and the exact roster is pinned three lines below as
`{'armor.plate','armor.jerkin','armor.coat','armor.warden'}`. A class added
without art still fails. The family check gained a case
(`e.value == TravelerArt.baseBody`) for the newly explicit base row.

**`test/gather_prerequisite_gate_test.dart` — equal strength, redirected.**
The 0.55-opacity check became `isEmpty` *plus* a new `findsNWidgets(3)` on
`ColorFiltered`. The count of locked entries and the "only the sketch changes
weight" claim both survive; the mechanism changed from dim to pencil remap
because `DIR-05` names "Locked = dim" as a phone-visible failure and names the
replacement by title. Assertion count went up, not down.

**`test/craft_planner_test.dart` — updated.** Two census strings became one
(`'23 recipes'` + `'0 ready'` to `'23 · 0 ready'`) — same facts, one line. The
locked ledger became the recipe book, so
`expect(find.text('Bronze Sword'), findsNothing)` inverted to `findsOneWidget`
— the round made every locked recipe visible by name, which is *more*
information, and the new
`expect(find.textContaining('more at Smithing'), findsNothing)` pins that no
row restates a gate. The `ensureVisible` / `dragUntilVisible` additions are
scroll plumbing for a longer page, not relaxations.

**`test/step_tracker_test.dart` — strengthened by addition only.** Zero
deletions. `ensureVisible` and `dragUntilVisible` were added because the folio
is longer than the card it replaced; every prior assertion (`Sync steps`,
`Synced`, `Lifetime credited`) is retained. The comment states the rule
explicitly: "What would NOT be acceptable is dropping the assertions because
the page grew." They were not dropped.

**`test/rarity_ui_test.dart` — updated.** One comment reworded and a
`scrollUntilVisible` added; `expect(find.text('unarmed'), findsOneWidget)` and
`expect(clippedLines(tester), isEmpty)` both survive intact.

**`test/combat_ui_test.dart` — rebuilt with the screen, safety floors kept.**
Many geometric assertions were deleted (`attackSize.width, 163.5`, plate native
sizes, the old 56 dp cell) because the rail was rebuilt. The non-negotiables
all re-appear on the additions side:
`expect(attackPlate.width, greaterThanOrEqualTo(44))`, Retreat's own hit region
`greaterThanOrEqualTo(44)`, the rail budget
`expect(rail, 120, reason: '12 welt + 64 plates + 44 Retreat')`, contrast floors
(`greaterThanOrEqualTo(3.0)`), and `Nothing to eat` with its disabled Eat. In
the source, `lib/ui/screens/combat/combat_screen.dart:798-800` keeps
`_retreatHit = 44` with the comment "44 is the accessibility floor and is not
negotiable". **The defeat/retreat identity is intact and asserted in words**:
`expect(find.text('Retreat — nothing is lost'), findsOneWidget)`, and
`combat_screen.dart:517-518` still renders "You retreat to …. Nothing was
lost." for both `LostBeat` and `RetreatedBeat`. Losing still costs nothing.

**`test/screen_evidence_test.dart` — strengthened.**
`find.textContaining('bonus yield')` became `find.text('Bonus yield')` **plus**
an assertion on the figure itself, with the stated reason "Both halves, or the
assertion would pass on a slip that had lost the number." `'Herb Broth ×1'`
became a `find.descendant` scoped to `ActivityResultCard` — narrower *scope*,
because the recipe behind the slip names the broth too; a substring match
replaced by a scoped exact match is a tightening. The slip drops a `×1`
multiplier by design ("one of a thing does not need to be counted at you"),
which is an anti-pressure improvement.

**Guard scripts:** the only assertion-bearing deletions in `package-art.js` are
the drift loop's two bounds lines, replaced by a wider walk. Every other
deletion is a source-path expression swapped for a round-aware one. No throw
was removed, no tolerance loosened.

---

## Summary

| Area | Verdict |
|---|---|
| 1. Absolute locks | **PASS** — `packages/` diff empty; save v9; no gameplay content changed |
| 2. Strategic travel | **PASS** — peek Travel arms only; `Set out` is the sole priced dispatch |
| 3. No pressure | **PASS** — nothing counts, flashes or loops; Reduce Motion static; M-16 held |
| 4. G-3 discipline | **PASS** — Q-29/Q-30 recorded unresolved; 0033 records an owner ruling accurately |
| 5. Guards | **PASS** — nothing weakened; the atlas guard is materially stronger |

A round of this size normally erodes something. This one did not. The single
follow-up worth raising is cosmetic: `DECISIONS/0033` section 2 describes the
`approved` snapshot mechanism one revision behind the code that implements it.
