# FINAL-05 — Encounter / Creature Director, adversarial pass on FMPO02 wave 3

1. **BLOCKER** — `GAME_BIBLE/ART/exploration/FMPO02/review/device/combat/combat_guardian_idle.png`,
   `combat_guardian_heavy.png`, `combat_guardian_struck.png` (361×368, against the wolf pair's
   full 393×852). All three bake in Flutter's own yellow/black overflow hazard-stripe with red
   ruler ticks, painted directly across the HP row — "40/40" and "60/60" are clipped mid-glyph
   above the stripe. The Hollow Guardian — the game's one boss fight — cannot lay out its own
   combat screen on a real 393×852 canvas without a `RenderFlex` overflow. Fix: reproduce the
   boss combat layout at 393×852 and find what's pushing the column over budget (likely the 96-tall
   guardian figure plus the BOSS ribbon plus the command grid stacked in one non-scrolling column);
   this blocks device acceptance of the single fight the round calls out as `heavy`/`struck` states.

2. **SHOULD-FIX** — `lib/ui/icons/encounter_card.dart` `_idleContentRows` (~L497–507). The map
   measures `wolf_idle`(29), `goblin_idle`(39), `lynx_idle`(30), `guardian_idle`(73) and the four
   unremarked species, but omits all four Veteran Hunt idle ids. `_contentRows` falls back to
   `footprint.bottom + 1` for anything unmapped — the file's own doc calls this "taller than the
   truth, never shorter." Measured: `old_grey` falls back to 41 rows → 94dp band vs the wolf's true
   76dp (+24%); `gallery_foreman` falls back to 47 → 106dp vs the goblin's 90dp; `rimeclaw_matriarch`
   falls back to 41 → 94dp vs the lynx's clamped 76dp (the worst case — a 24% taller box for a
   same-canvas creature). `guardian_awakened`'s fallback (84 → 180) happens to clamp to the shared
   152 cap, so it alone is unaffected. Net: three of four elites partially reopen "a small wolf in a
   giant blank rectangle" on their own encounter card — the exact defect `_EnemyStage` exists to
   fix — while their base species does not. Fix: run the same `png.bounds` pass `package-art.js`
   already does over the four elite idle strips and add their true rows to the map.

3. **SHOULD-FIX** — `assets/art/v1/combat/habitat_snowbank.png` and `habitat_cave_shadow.png`
   read as scenes, not the "flat ground plane" `encounter_habitat.dart`'s own doc mandates ("no
   horizon, no sky, no midground prop, nothing above the creature's headroom line... a plate that
   acquires any of those has become the full battle background the owner ruled out"). Snowbank is
   a full row of pine trees with an implied horizon and an ember glow at their bases — a vertical
   backdrop, not a floor. Cave_shadow is a stacked-boulder wall face with a mounted lantern — a
   wall a creature stands in front of, not ground it stands on. Contrast `habitat_rocky_ledge.png`,
   a genuine flat shelf with a log lying on it, which reads correctly. Fix: re-crop or re-author
   both to ground-only strips (packed snow + one ridge with trees cropped above headroom; basalt
   floor slabs rather than a wall face) so all five plates match their own written spec.
   The salamander/cave split itself checks out: `EncounterHabitat.byEnemy['enemy.salamander'] →
   caveShadow` is consulted before `byPlace`, `enabled` includes `cave_shadow`, and `enemies.json`
   confirms the salamander lives at `location.stonefall_mine` — the override is wired correctly,
   it is only the art inside `cave_shadow` that fails the plate's own rule.

4. **NOTE** — `lib/ui/icons/encounter_habitat.dart` L35–42 vs L120–126: the doc comment
   ("Why nothing renders yet") states "`[enabled]` is empty... nothing renders yet," but the code
   nine lines later populates `enabled` with all five slugs — the plates are live. Not a runtime
   bug, but a stale comment contradicting its own file that will mislead the next session into
   thinking the switch is still off. Fix: update the comment to say the five plates shipped.

5. **NOTE** — the "ram2" fork: `GAME_BIBLE/ART/exploration/FMPO02/review/enemies/
   ram_insurance_compare_x4.png` and `ram_insurance_idle_x4.png` show a second ram candidate
   (darker, richer horn curl) generated alongside the shipped one. `assets/art/v1/combat/
   ram_idle_f0.png` still matches the original round-1 ram — the left half of the comparison.
   `grep -r "ram_insurance\|ram2" GAME_BIBLE/ART/exploration/FMPO02` returns nothing: no report
   records why ram2 was rolled or why it wasn't adopted, unlike Old Grey and the Frost Lynx, whose
   library doc comments spell out exactly why a redesign did or didn't ship. Generations were
   spent with no resulting decision on record. Fix: adopt ram2 with the same rationale the other
   redesigns got, or record the rejection in `ENEMIES_report.md` and note the spend was a dead end.

6. **NOTE** — `crawler_defeat_v2_x4.png` is visually indistinguishable frame-for-frame from the
   shipped `crawler_defeat_x4.png`, confirming `combat_assets.dart`'s own candid comment that "two
   rolls looked the same." Not a new defect — the weakest defeat read in the roster stayed weak
   after a second round bought it nothing — flagged only so the spend isn't mistaken for a fix.

**Verdict:** Do not accept — the boss fight cannot render without painting Flutter's own overflow
warning over its HP text, and the elite band-height regression re-opens the wave's own headline fix
for three of four Veteran Hunts; everything else here is a should-fix or a record-keeping gap, not
a gate.
