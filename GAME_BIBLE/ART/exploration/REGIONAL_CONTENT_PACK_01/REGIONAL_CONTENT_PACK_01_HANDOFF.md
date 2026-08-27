# REGIONAL_CONTENT_PACK_01 — Handoff

```
STATUS: self-contained content-production package · NOT CANON · NOT INTEGRATED · NOT COMMITTED
Produced by an isolated parallel support workstream on 2026-08-19.
Owner action: review, then decide what (if anything) the post-World-&-Reward-Depth milestone integrates.
```

## 0. Read this first — the concurrency warning

This package was produced against **HEAD `dc8f6f6`** on branch `playable-phase-2-multiregion`
("Domain: per-visit encounters, Frost Lynx, authored rarity, state v5") **while the World & Reward
Depth 01 session was running concurrently** and owned: combat recurrence, rarity architecture,
reward/victory UI, inventory rarity presentation, atlas architecture, the location inspector, the
ambient animation runtime, the reading-scene correction, and the save/schema changes for those.

> **Re-read the current repository HEAD before integrating anything here.** The primary session may
> have changed `enemies.json` / `items.json` / `recipes.json` fields, the `Rarity` enum or table, the
> `LocationKind` rule, `atlas_layout.json` (schema v2: landmarks, kindMarkers, tiles), the combat
> stage's frame/anchor contract, `Scripts/art/package-art.js`, or the vignette slot since this pack was
> produced. Every id in this pack is a **proposal**, every figure a **placeholder**, and every asset is
> judged on the day it is integrated, not on the day it was made.

This workstream **did not touch**: `lib/`, `packages/stride_core/`, save codecs/migrations, any
content JSON, `atlas_layout.json`, inventory/combat/Adventure UI, rarity definitions, iOS scripts,
HealthKit, or the active milestone docs. Nothing was written outside
`GAME_BIBLE/ART/exploration/REGIONAL_CONTENT_PACK_01/`. Nothing is staged or committed; no branch or
worktree was created (the owner reviews first — §7).

## 1. What this pack is

A regional-depth content package for the five existing regions — Haven's Rest, Whispering Woods,
Forgotten Hollow, Stonefall Mine, Frostmere — that deepens the world rather than adding systems:

| Part | Where | Contents |
|---|---|---|
| Art direction | `ART_DIRECTION_BRIEF.md` | one coherent language before fan-out (inherited from PE01 / TRANSFORMATION_01 / WRD01) |
| Design proposals | `CONTENT_PROPOSALS.md` | 7 enemy candidates (+1 concept), 5 materials, 4 gear items, the content graph, 2 future locations, fauna intent |
| A. Enemy candidates | `enemies/` + `out/enemies/` | 7 stage sets (idle · attack · defeat where it read), ctx plates, round record |
| B. Material icons | `materials/` + `out/materials/` | 5 icons (48×48) |
| C. Gear icons | `gear/` + `out/gear/` | 4 icons (48×48) |
| D. World assets | `world/` + `out/world/` | 12 atlas props / landmark cutouts |
| E. Vignettes | `vignettes/` + `out/vignettes/` | 5 location vignette variants (384×176) |
| F. Ambient fauna | `fauna/` + `out/fauna/` | 6 fauna at concept + stage scale, 5 loops |
| G. Integration manifest | `INTEGRATION_MANIFEST.md` + `out/<family>/manifest.json` | id · files · dims · anim meta · use · deps · readiness |
| QA | `qa/` | ×1/×2/×8 sheets, ctx plates, blind staging sets, three independent Visual QA passes (`QA_PASS_A/B/C.md`) + a re-roll pass (`QA_PASS_D.md`) |
| Tools | `tools/` | `dl.js`, `fetch_anim.js`, `fetch_img_anim.js`, `sheet.js`, `stage.js`, `package.js`, `accept.json`, `_stage_key.json` — node, using `Scripts/art/png.js` read-only |

## 2. PixelLab generations used

**98 generations** by tool cost lines; **99** by balance delta (365 → 266 — the account is shared
with the concurrent session, so the delta is not proof of this pack's spend alone). Budget was ≤ 130. Breakdown:
`create_character` 5 · `animate_character` 12 · `create_image_pixen` 62 (enemy stills 10, icons 23,
props 17, vignettes 5, fauna 12 — includes every re-roll) · `animate_image` 19.
Per-family detail in each README's Spend table.

Every asset is PixelLab-authored; Claude cropped, alpha-quantised, despeckled (icons only), palette-
remapped to each track's own f0 and assembled sheets (`RULES.md` A-2). Nothing was hand-drawn or
pixel-edited. 0 semi-transparent pixels, 0 teal (`#58d6c0`) hits, 0 clipped frames across every
packaged file (`tools/package.js` log).

## 3. Blind Visual QA — how it was run, and the verdicts

Three independent passes on a neutral staging set (`qa/k4v9/`, opaque shuffled codes, key outside
the folder; `NEUTRAL_STAGING_CHECKLIST.md` A1–A6, B1–B3, C1–C14, D1 followed; D4 known limit — each
reviewer reported what their own context primed). The reviewers' role is read-only, so the
orchestrator saved their returned text verbatim and appended the decode **after** the verdict.
A fourth pass (`QA_PASS_D.md`) blind-read only the re-rolled items.

| Pass | Scope | Verdict (reviewer's line) |
|---|---|---|
| A | 22 enemy tracks + 7 ctx plates | **FAIL** — bat and armoured-bug families carry identity risks (gargoyle / rock-with-legs); three spider rows interchangeable; **the rest of the set holds** |
| B | 10 icons + 17 fauna | **FAIL** — two items unidentifiable (gloom silk, chitin), four more with a plausible wrong read at judging size |
| C | 12 props + 5 vignettes | **FAIL** — deer group unidentifiable; ore cart ambiguous; dark-tile family loses secondary detail; **wide scenes read clearly** |
| D | 5 re-rolls + 2 re-reads | per-item: silk c3 sure · pickaxe c3 "hammer" · ram horn "curled horn" · coat "cloak/robe" · bear_attack2 clear · weaver_attack2 barely · ore cart c2 fairly sure |

A FAIL line is the reviewer's verdict on the *staged set as a whole*; the per-asset dispositions
below are the author's, drawn from the reviewers' per-code findings, and **nothing a reviewer flagged
as unidentifiable or wrong-object is marked READY.**

## 4. Final dispositions (the count is not inflated)

Vocabulary: **ACCEPT** (reads at ×2, no wrong object) · **PASS WITH NOTE** (reads; a recorded caveat)
· **WITHHOLD** (packaged, `status: withheld`, not to be drawn — fixable with another round) ·
**REJECT** (not packaged, or packaged and not to be used; retry reason on record) ·
**CONCEPT-ONLY** (the idea stands, no shippable art).

### A. Enemies

| Candidate | Stills / ctx | idle | attack | defeat | hit | Overall |
|---|---|---|---|---|---|---|
| Bristleback Boar | ACCEPT (boar, hip height, forest) | ACCEPT (barely moving, like the shipped wolf idle) | **ACCEPT** (charge reads clearly) | ACCEPT (note: "lying down vs dead" ambiguity, shared with the shipped wolf_defeat) | — | **READY** |
| Oakback Bear | ACCEPT (large, threatening, shoulder-height) | ACCEPT | round 1 read as a walk/lunge → WITHHELD; round 2 `bear_attack2` **ACCEPT** (Pass D: rear-up / roar / swipe, clear) | ACCEPT (rest-vs-dead note) | — | **READY** |
| Frosthorn Ram | PASS WITH NOTE (white on snow; dark face/legs carry it) | ACCEPT (near-still) | **ACCEPT** (charge reads clearly) | ACCEPT | WITHHELD (a head turn) | **READY WITH NOTE** |
| Mire Salamander | ACCEPT (best contrast of the Hollow scenes) | ACCEPT (minor head jitter) | **ACCEPT** (bite reads clearly; head "pop" to frontal) | ACCEPT (rest-vs-dead note) | — | **READY WITH NOTE** |
| Scree Crawler | PASS WITH NOTE ("rock with legs" risk; face unreadable) | PASS WITH NOTE | **ACCEPT** (bite reads clearly) | WITHHELD | — | **READY WITH NOTE** (idle + attack only; a face/eye correction round recommended) |
| Hollow Weaver | PASS WITH NOTE (dark on dark ground; "spider/bug") | PASS WITH NOTE (near-still) | round 1 indistinguishable from idle → WITHHELD; round 2 "barely" (Pass D) → **WITHHELD** | WITHHELD | — | **CONCEPT-ONLY** (idle only reads; two attack rounds spent) |
| Adit Bat | **REJECT** on identity (reads as gargoyle / small dragon; frontal head reads as an owl) | — | — | — | — | **CONCEPT-ONLY** — rebuild as a PixelLab character, wings open, before any further spend |
| Great Elk | — | — | — | — | — | **CONCEPT-ONLY** by design |

### B / C. Icons

| Icon | Verdict |
|---|---|
| icon_boar_tusk_48 | **ACCEPT** ("claw / tusk / horn", sure) |
| icon_bear_pelt_48 | **ACCEPT** ("bear pelt / hide rug", fairly sure; low value range note) |
| icon_ram_horn_48 | **PASS WITH NOTE** ("coiled horn / curled shell" first; "grub" a real alternative at ×1 — two reviewers agree; owner call) |
| icon_gloom_silk_48 | c2 **REJECT** (unidentifiable: beehive / cocoon); c3 spool-on-a-stick **ACCEPT** (Pass D: "spool of thread", sure) |
| icon_granite_chitin_48 | **REJECT** after four rounds (helmet · seashell · pauldrons · barrel) — **CONCEPT-ONLY**; the noun may need rethinking (a carapace shard does not draw at 48 px) |
| icon_bronze_longsword_48 | **ACCEPT** ("sword", sure; note: close kin of the shipped bronze_sword — set-coherence call) |
| icon_bearhide_coat_48 | **PASS WITH NOTE** ("hooded cloak / cape"; "sack" an alternate at ×1) |
| icon_hornbound_bronze_axe_48 | **ACCEPT** ("hatchet / axe", sure) |
| icon_reinforced_bronze_pickaxe_48 | c2 **REJECT** (first read "polearm"); c3 **REJECT** (first read "hammer", pickaxe the alternative) → **WITHHELD** after three rounds; a future round should start from the shipped bronze_pickaxe via a PixelLab edit, not a fresh noun |

### D. World props

| Prop | Verdict |
|---|---|
| prop_plank_bridge | **ACCEPT** (sure; dark water note; must sit on a river) |
| prop_waystone | **ACCEPT** (sure; purple outline outlier note) |
| prop_ruin_corner | **PASS WITH NOTE** (read as boulders + dead tree, not a ruin — scenery either way) |
| prop_mine_headframe | **ACCEPT** (sure) |
| prop_ore_cart_rails | c1 **REJECT** (raft vs cart); c2 **PASS WITH NOTE** (Pass D: "mine cart", fairly sure; wheels/rails muddled at ×2) |
| prop_elder_oak | **ACCEPT** (sure; bubbly foliage, square plate notes) |
| prop_alpine_hut | **ACCEPT** (sure; grey-on-grey note) |
| prop_cold_camp | **PASS WITH NOTE** (tent / shelter; front objects unreadable) |
| prop_ruined_tower | **ACCEPT** (sure; drew an intact tower; ivy reads as a streak) |
| prop_hamlet_cluster | **ACCEPT** (sure; brighter/saturated outlier; chimney reads as a small tower) |
| prop_charcoal_clamp | **WITHHOLD** — reads "strongly as a usable station (cook/smelt)": an implied interaction the game does not have there (L-17), not a craft fault |
| prop_deer_group | **REJECT** (unidentifiable at ×2; a 40-px three-animal group does not draw) |

Reviewer C's cross-cutting note: the dark-ground prop family is low-contrast at ×2 on the staging
grey; the atlas base is lighter, so judge again **in place** before shipping any of them.

### E. Vignettes

All five **ACCEPT** ("sure" reads, clear fore/mid/distance). Notes: Haven's Rest Ford is a visibly
cuter/brighter hand than the other four (set-coherence call); Stonefall Spoil has black corners
("floating diorama"); Hollow Mere is very dark for daylight phone use; Woods Ring's light shafts
read as a deliberate glow.

### F. Fauna

All 32/24-px stills and all five loops **ACCEPT** (songbird and hare loops "move very little" note);
16-px: butterfly, songbird, hare, crow **ACCEPT** (crow and hare tiny-sprite notes); **bat_16 WITHHOLD**
(reads as a moth at ×2); **ptarmigan_16 PASS WITH NOTE** (hen / white blob), ptarmigan_32 PASS WITH
NOTE (white fowl, species unreadable — acceptable vagueness, L-17).

## 5. Candidate content (design, no implementation)

Full tables, rationale and the content graph are in `CONTENT_PROPOSALS.md`. In one screen:

- **Enemies:** Bristleback Boar + Oakback Bear (Woods), Adit Bat + Scree Crawler (Mine), Mire
  Salamander + Hollow Weaver (Hollow), Frosthorn Ram (Frostmere), Great Elk (concept). Two fights per
  region as a *ladder*; behaviours reuse steady / flurry / guarded; per-visit counts per `DECISIONS/0021`.
- **Materials (5, all Rare, one consumer each):** Boar Tusk, Bear Pelt, Granite Chitin, Gloom Silk,
  Ram Horn. The bat and salamander drop existing items on purpose.
- **Gear (4):** Bronze Longsword (weapon, Epic — needs Woods + Hollow + Mine), Bearhide Coat (armor,
  Epic), Reinforced Bronze Pickaxe (tool tier 2, Epic — the key to Deeper Stonefall), Hornbound Bronze
  Axe (tool tier 2, Epic). No ladder beyond that.
- **Content graph:** enemy → one material → one recipe → one progression step → a reason to go back.
- **Locations (2, not drawn):** the Lower Gallery (Deeper Stonefall, iron seam, tool-gated — eventual
  playable), the Old Ford (a safe waypoint on the Haven–Woods edge — future landmark first).
- **Fauna:** one beat per scene at most; no system behind it.

Rarity words are recorded in proposals and manifests only; nothing encodes them.

## 6. Recommended integration priority (after the primary milestone lands)

1. **Boar + Ram stage sets, Boar Tusk + Ram Horn + Bear Pelt icons** — READY, and they complete the
   two regions that most need a second fight (Woods above the wolf; Frostmere beside the lynx).
   Requires: `enemies.json` entries, two `items.json` entries with the then-current rarity field,
   stage manifest lines, the missing-defeat tolerance already shipped for the guardian is not needed
   (both have defeats).
2. **Salamander + Crawler (idle/attack)** — the Hollow's first normal fight and the Mine's armoured
   fight; the Hollow one needs no new item at all.
3. **Bear** (with `bear_attack2`, which passed Pass D), then
   **Bearhide Coat + Bronze Longsword** once the materials exist.
4. **Vignette variants** — drop-in 384×176 files if the vignette slot is unchanged; judge set
   coherence of the Haven's Rest variant against the shipped palisade scene first.
5. **Props**: bridge, waystone, headframe, alpine hut, elder oak, hamlet, tower — each only with a
   placement decision in the then-current `atlas_layout.json` and an in-place ×2 check (Reviewer C's
   contrast note).
6. **Fauna** — only if the ambient runtime grows a "beat" slot; the 16-px set is the stage-scale one.
7. **Not yet:** the bat (rebuild), the chitin icon (rethink the noun), the weaver (attack must read),
   the two tool upgrades' recipes (no consumer until the Lower Gallery exists), the Old Ford (splits
   an edge the primary session owns), any stat figure.

## 7. Git

Nothing committed, staged, or pushed; no branch or worktree created. If the owner wants the package
preserved in history before review, the staging is explicit and self-contained:

```bash
git add GAME_BIBLE/ART/exploration/REGIONAL_CONTENT_PACK_01
```

(on a clearly named branch, never the active one; never `git add -A` — G-8). `candidates/` holds
every raw PixelLab output including rejected ones and is ~4 MB; the owner may prefer to commit only
`out/`, `qa/*.md`, `qa/*_sheet_*.png`, the READMEs and this handoff.

## 8. What I would tell the next person in one paragraph

The pack's strongest material is the **boar, ram, bear and salamander** sets, the **five vignettes**,
and the **tusk / pelt / horn / sword / axe** icons — all blind-read as what they are at ×2. The honest
failures are the **bat** (identity), the **chitin** icon (four nouns, none of them "chitin"), the
**deer group** (too small to draw), and the animate_image **defeats** for the three non-template
bodies (the generator will not lay them down). The design layer is deliberately small and connected —
every material has exactly one job — and the two future locations are proposals with stated classes,
not drawn. **Re-read HEAD first.**
