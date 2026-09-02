# ITEMS_report — PROD-ITEMS (FMPO02 Wave 2)

## Accepted (12), in `GAME_BIBLE/ART/exploration/FMPO02/out/items/`

| File | Item id | What changed |
|---|---|---|
| `icon_hearty_stew_48.png` | `item.hearty_stew` | bowl+spoon → iron pot, chunky brown stew (mid-tier vessel per §2) |
| `icon_goblin_toothed_axe_48.png` | `item.goblin_toothed_axe` | toothed disc/fan → a jagged-edge iron axe head on a diagonal haft, reads as an axe |
| `icon_tinbraced_pickaxe_48.png` | `item.tinbraced_pickaxe` | grey pick head now shows a visible tin-band ring at the head/haft joint; clears its two shipped collisions |
| `icon_clawguard_coat_48.png` | `item.clawguard_coat` | cinched-cape silhouette with pale claw-guard shoulder plates, distinct from `bearhide_coat`'s rounded blob shape |
| `icon_lynx_pelt_48.png` | `item.lynx_pelt` | tawny spread pelt with a dark spot pattern and tufted ears — pattern-separated from `wolf_pelt`, not hue-separated |
| `icon_pristine_horn_48.png` | `item.pristine_horn` | straight ridged spiral (unicorn/narwhal register) instead of a coiled loop — shape-separated from `ram_horn`'s anchor coil |
| `icon_scalewarmed_chestplate_48.png` | `item.scalewarmed_chestplate` | deeper red scale texture; measured COLLISION with `bronze_chestplate` resolved to WATCH |
| `icon_bronze_longsword_48.png` | `item.bronze_longsword` | bone grip/pommel proportions redrawn; measured COLLISION with `bronze_sword` resolved to PASS |
| `icon_fanghilt_sword_48.png` | `item.fanghilt_sword` | fang cross-guard redrawn shorter/wider; measured COLLISION with both bronze swords resolved to PASS |
| `icon_reclaim_axe_48.png` | `item.reclaim_bronze_axe` (recipe icon) | new — wooden crate, faint pale axe stamped on the inside of the open lid |
| `icon_reclaim_pickaxe_48.png` | `item.reclaim_bronze_pickaxe` (recipe icon) | new — same crate, faint pale pickaxe stamp |
| `icon_reclaim_chestplate_48.png` | `item.reclaim_bronze_chestplate` (recipe icon) | new — same crate, faint pale chestplate stamp |

## Exact `emit` mapping for the integrator

```
item.hearty_stew              -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_hearty_stew_48.png
item.goblin_toothed_axe       -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_goblin_toothed_axe_48.png
item.tinbraced_pickaxe        -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_tinbraced_pickaxe_48.png
item.clawguard_coat           -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_clawguard_coat_48.png
item.lynx_pelt                -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_lynx_pelt_48.png
item.pristine_horn            -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_pristine_horn_48.png
item.scalewarmed_chestplate   -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_scalewarmed_chestplate_48.png
item.bronze_longsword         -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_bronze_longsword_48.png
item.fanghilt_sword           -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_fanghilt_sword_48.png
```

Recipe-level icons (net-new path, per ART-07 §3 — `PixelIcons.recipeIconFor(recipe)`
does not exist yet; Technical Director must add it ahead of the `itemFor(outputItem)`
fallback in `craft_screen.dart`. Not implemented here; art only):

```
recipe.reclaim_bronze_axe        -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_reclaim_axe_48.png
recipe.reclaim_bronze_pickaxe    -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_reclaim_pickaxe_48.png
recipe.reclaim_bronze_chestplate -> GAME_BIBLE/ART/exploration/FMPO02/out/items/icon_reclaim_chestplate_48.png
```

All 12: 48×48, `no_background=true`, zero partial-alpha pixels (verified by
`tools/finalize-items.js` — every file passed the binary-alpha and exact-canvas check).

## Rejected — see `ledger/ITEMS.md` for every job/reason. Highlights:

- **hearty_stew**: 6 candidates tried across two prompt revisions; every attempt at a
  "no fire" iron pot still rendered a lit flame under the pot (emissive, against the
  style clause). Accepted candidate has no flame. Residual: still measures COLLISION
  against `expedition_stew` (0.798 shape / 0.658 colour) — both are legitimately
  "stew in a metal vessel" by the tier-progression design language in §2, and I could
  not find a candidate in six tries that resolved this without introducing a new
  defect. **Flagging as an open item**, not silently shipping it as solved.
- **clawguard_coat**: 8 candidates across three prompt phrasings (original, "empty
  cloak, no face", "coat" instead of "cloak") all rendered a visible face under the
  hood — the model's strong prior for this hooded+claw-guard combination. Accepted
  candidate is the best-scoring of the original 4 and is stylistically consistent
  with the *currently shipped* clawguard_coat (also a full-figure render, not a
  garment-only icon like `bearhide_coat`/`frostwarden_coat`) — not a new regression,
  but also not fully resolved. **Flagging as an open item.**
- **reclaim crates**: none of the 3 items' 4(+1 retry) candidates avoided a WATCH
  against `bronze_ingot` (best available was 0.79–0.81 shape / 0.51–0.57 colour).
  The three accepted crates also measure COLLISION *against each other*
  (0.96+ shape, 0.75+ colour) — this is by design, not a defect: all three share one
  crate motif on purpose (ART-07 §3), differentiated by the internal ghost-stamp
  content rather than silhouette, the same alias logic already accepted for the
  broth family.

## RE-AUTHOR items where I did NOT replace shipped art (evidence contradicts the brief)

Direct pixel inspection of the currently shipped files (not the ART-07 write-up, which
predates several intervening commits) found three of the nine named RE-AUTHOR defects
already resolved:

| Item | ART-07 said | What's actually shipped now |
|---|---|---|
| `frostwarden_coat` | "warm-brown tone contradicts its own frostGuard stat" | already pale blue-white, full-length coat with a standing collar. WATCH (not COLLISION) against both `bearhide_coat` and `clawguard_coat`. |
| `heat_scale` | "rendered pale blue — reads as ice" | already warm brown/orange. PASS against `frost_claw` (colour intersection 0.213). |
| `frost_claw` | "rendered warm brown — reads as a beast claw" | already pale icy blue. PASS against `heat_scale`. |

Per `RULES.md` G-1 (proportional verification) and the same evidence-based-rescoping
precedent ART-07 itself used for the broth aliases, I left these three unchanged
rather than re-rolling working art. This should be read back into `ART-07_item_brief.md`
the same way GOV-03's stale byte-copy note was corrected there.

## VERIFY items reclassified to REPLACE on hard evidence

`tools/check-item-distinctness.js` (built for this brief's §6, see below) found that
three items ART-07 listed as borderline-KEEP actually **measure as COLLISION** against
their sibling today: `scalewarmed_chestplate` vs `bronze_chestplate` (0.706/0.680),
`bronze_longsword` vs `bronze_sword` (0.641/0.735), and `fanghilt_sword` vs both bronze
swords (0.720/0.714 and 0.575/0.714). All three were replaced (see table above); all
three now measure PASS or WATCH. The other five VERIFY items (`wolf_pelt`,
`hollow_root`, `ram_horn`, `reinforced_pickaxe`, `bearhide_coat`) were confirmed already
distinct or — for `ram_horn`/`reinforced_pickaxe` — load-bearing as the unmoved anchor
the new `pristine_horn`/`tinbraced_pickaxe` differentiate against, so replacing them
would have reintroduced a collision. Kept unchanged.

## §6 QA tool: `tools/check-item-distinctness.js`

Implements the pairwise gate: silhouette IoU on the centroid-aligned alpha mask (flag
>0.55), 16-bin/channel colour-histogram intersection over opaque pixels (flag >0.6),
and a greyscale re-check. **One documented departure from a literal reading of §6.4**:
this codebase's palette guard rejects all partial alpha (`0<a<255` is guard-rejected),
so alpha itself carries no colour and "desaturate, then redo the alpha-only IoU" is a
no-op by construction — it would always equal the colour IoU and auto-fail every
high-colour-intersection pair regardless of actual shape. Instead, "greyscale IoU" here
thresholds each icon's own opaque pixels at its own median luminance into a light/dark
partition and takes the IoU of the two "light" regions (aligned the same way as the
silhouette check) — a real second signal (does the internal value/shading pattern also
line up, not just the outline) rather than a trivial restatement of step 1. This is
flagged in the script's own header comment, not left implicit.

Full pairwise run across every family named in ART-07 §1/§2, before and after this
session's changes, plus the 12 accepted-file validation, is in
`GAME_BIBLE/ART/exploration/FMPO02/ledger/ITEMS.md` and reproducible with:

```
node tools/check-item-distinctness.js                     # against assets/art/v1/item
node tools/check-item-distinctness.js --dir <some/dir>     # against any staged set
```

Flagged pairs found in the **currently shipped** catalogue that are outside this
brief's scope (not touched, flagging for awareness only — G-3, don't smuggle scope):
`wolfhide_jerkin`/`frostlined_jerkin`/`tuskbound_jerkin` (mutually COLLISION),
`meadow_herb`/`duskcap` (COLLISION), `ram_horn`/`great_tusk` (COLLISION),
`great_tusk`/`pristine_wolf_fang` (COLLISION). None of these items are in ART-07's
verdict table; a future brief should cover them.

## What the integrator must do

1. Copy the 9 item-icon files into whatever asset pipeline currently serves
   `assets/art/v1/item/<id>.png` (same 48×48 RGBA8 format, drop-in replacement).
2. The 3 reclaim recipe icons need `PixelIcons.recipeIconFor(recipe)` wired ahead of
   `itemFor(outputItem)` in `craft_screen.dart` (ART-07 §3) — **not done here**, flagged
   to Technical Director per this brief's own scope note. Until that lands, the 3
   reclaim files sit in `out/items/` unused.
3. `tools/check-item-distinctness.js` and `tools/test-candidates.js` are new files
   under `tools/` and `GAME_BIBLE/ART/exploration/FMPO02/tools/` respectively — no
   Dart or `package-art.js` edits were made.

## UNRESOLVED

- `hearty_stew` vs `expedition_stew` still measures COLLISION (0.798/0.658). Six
  generation attempts across two prompt revisions did not resolve it without
  introducing an emissive-flame defect. Needs either a targeted `inpaint_image` pass
  once Tier-appropriate (PIXELLAB_STYLE_SPEC_01 §11/§12) or an owner call on whether
  the two tiers are allowed to read this close given they're adjacent on the same
  vessel-escalation ladder.
- `clawguard_coat` still renders as a full hooded figure with a visible face, matching
  the *currently shipped* icon's register but not the garment-only convention used by
  `bearhide_coat`/`frostwarden_coat`. Silhouette collision is resolved; the rendering
  register is not. Recorded to `JOURNAL/OPEN_QUESTIONS.md`-worthy status — flagging
  here since this session did not have authority to decide whether that stylistic
  inconsistency is acceptable.
- Three of ART-07's nine RE-AUTHOR items (`frostwarden_coat`, `heat_scale`,
  `frost_claw`) appear already fixed by an intervening commit; ART-07 itself should be
  corrected to reflect current pixel evidence, the same way it already corrected
  GOV-03's stale note.

## Balance

Start: 9,551 remaining / 449 used. End: 8,642 remaining / 1,357 used (Tier 3, shared
account — concurrent wave2 families were generating throughout). This family's own
spend: 72 generations against a 140 cap.
