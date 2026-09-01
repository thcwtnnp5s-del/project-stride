# 0030 — Visual / Audio / World Overhaul 01: the budget reopens, and what that does not buy

**Status:** Approved — **owner ruling, 2026-09-01**
**Date:** 2026-09-01
**Owner:** Project owner (explicit, in writing, opening
VISUAL_AUDIO_WORLD_OVERHAUL_01)
**Amends:** `DECISIONS/0029` § "What this decision does NOT authorize" (first
bullet) · `DECISIONS/0005_AUDIO_SOURCING.md` § Permitted sources
**Resolves:** `JOURNAL/OPEN_QUESTIONS.md` **Q-14** (visible-equipment priority)
**Related:** `RULES.md` A-1, A-2, A-3, A-4, G-3, G-5, G-8, P-4, P-5, P-6 ·
`MILESTONES/VISUAL_AUDIO_WORLD_OVERHAUL_01.md`

---

## Context

Three separate Wave 0 auditors independently reported the same blocking
condition: **the repository's canon forbids the work the owner has just
commissioned.** That is exactly the state `RULES.md` G-3 says must be stopped at
and asked about rather than inferred past, and exactly the state `G-5` says must
be resolved in a repository document rather than in a conversation.

Two clauses were in the way, and both were correct when written.

**`DECISIONS/0029` closed generation.** Its first "does NOT authorize" bullet
reads *"No PixelLab generation in this workstream. The remaining balance is
**exactly 25** and it is the atlas emergency reserve."* That was true on
2026-08-31. It was a statement about a balance, not a position on interface art
— 0029's entire purpose was to *permit* PixelLab to author interface art, and it
shipped a per-asset production queue explicitly designed to run after the cycle
reset.

**`DECISIONS/0005` never named the provider that actually shipped.** It permits
ElevenLabs, original or generated assets, and properly licensed CC0, and forbids
paid libraries without explicit owner approval. Every audio asset now shipping
was generated on Stability AI's paid tier, accepted through
`MILESTONES/AUDIO_PRESENTATION_01.md`, and **never recorded as an amendment**.
The practice and the record had drifted apart, which is the condition `RULES.md`
G-7 exists to prevent.

## Decision

### 1. PixelLab generation is authorized for this workstream

Balance verified live at the opening of this workstream, per precondition P-0 of
`GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` — a remembered figure has been
wrong three times in this project's history and is never sufficient:

```
credits: $0.00
generations_remaining: 10000
generations_used: 0
generations_total: 10000
subscription: active (Tier 3: Pixel Architect)
generations_reset: 2026-10-01
```

The owner's ruling, in their own terms: *"PIXELLAB IS NO LONGER A SCARCE
RESOURCE FOR THIS WORKSTREAM. Use it responsibly, but do not behave as if every
generation is precious."*

**The atlas emergency reserve is dissolved as a concept.** It existed because 25
generations could fund exactly one inpaint correction. At 10,000 the reserve is
not a meaningful constraint and no longer gates anything.

**What this does not change.** Every craft and semantic rule in 0029 stands
unamended, and `PIXELLAB_UI_PRODUCTION_PLAN.md` § 11 "DO NOT AUTHOR" is
unaffected in full. A larger budget buys more rolls; it does not buy a
relaxation of what may be drawn. The scarce resource named in that plan's own
headline was never generations — *"Blind review rounds are"* — and that is still
true and is now the binding constraint on this workstream's pace.

### 2. Audio generation is reopened in direction, and blocked in practice

The owner's ruling: *"Audio is now OPEN. The owner wants a major audio
upgrade."*

**`0005` is amended to name Stability AI** as a permitted generated-audio
source, recording the practice that has been shipping since
AUDIO_PRESENTATION_01 rather than inventing a new one. ElevenLabs remains
permitted for custom SFX. The owner's standing instruction — *"Stable accepted
provider direction remains preferred. Do not provider-hop casually"* — is
recorded as the tie-breaker when both could serve.

Everything else in `0005` is untouched and remains absolute: **no asset
extracted from WalkScape, Melvor Idle, Old School RuneScape or New World, ever**;
a manifest row per shipped asset, with provenance, or it is a QA defect; audio
referenced by asset ID only, never by filename.

**The practical position, stated so nobody plans around a capability that is not
there:** `STABILITY_API_KEY` and `ELEVENLABS_API_KEY` are both **unset** in this
environment, verified in bash and PowerShell user scope. No credential file
exists in the repository. **No new audio can be generated in this workstream
until the owner supplies a key.** This is a blocker on new generation only, and
it blocks a minority of the audio work — see § 4.

`OD-06` stands unchanged and is reaffirmed: the owner's GitHub audio resources
are not recoverable from the repository, three searches have confirmed it, and
**a URL for them may not be guessed by name.** They must be resent.

### 3. Visible equipment is P0 — Q-14 is resolved

`Q-14` asked whether visible equipment was worth its production cost and where
it ranked. The owner has answered directly and it is no longer open:

> MAKE THE TRAVELER ACTUALLY WEAR THEIR EQUIPMENT. MAKE THE SWORD THEY EQUIP
> APPEAR IN THEIR HAND. MAKE ARMOR CHANGE THEIR SILHOUETTE.

Recorded as **P0**, at minimum for the weapon and chest/armour slots, with the
tool slot strongly preferred. `Q-15` (Slash/Crush/Pierce, 300–700 generations)
was downstream of Q-14 and **remains open and out of scope** — it is a combat
systems question, and this is a presentation workstream (§ 5).

**This requires no save migration and no new persisted state.** The projection
seam already exists and already ships inert:
`StrideSession.equipmentVisualState` reads `equipment.bySlot` on demand and
holds nothing, and `TravelerArt` is the resolver with three empty tables —
the same architecture as `PanelSkins.authored`. Tier, rarity and tool kind are
content lookups from the item id, never stored. Landing gear art is table rows
plus packaged strips. Any design that would persist an art key, a variant id or
a cosmetic override is **refused under this decision**, because it converts a
free change into a schema-v10 migration for no player-visible gain.

### 4. What the credential blocker does and does not stop

Recorded because the honest split is large and a reader could otherwise conclude
that audio is simply blocked.

**Blocked** — new sound files, and only that.

**Not blocked, and forming the majority of the audio work:** the cue tables,
priority bands, the voice cap, the music duck, `setCombat`, `fallbackTo`
resolution chains and trigger wiring at the ~20 named sites. None of these
requires a sound file, because `AudioController.fileFor()` already returns
`String?` and an unresolved cue is silent rather than fatal — the indirection
`0005` established for exactly this reason. Also unblocked: the **40+
already-paid-for candidate files** sitting unshipped in `AUDIO/evaluation/`
with full provenance, never re-auditioned against the current mix.

An event wired to a silent cue is not a defect under this decision. It is the
designed state, and it is what makes a later key drop in as a manifest row.

## What this decision does NOT authorize

- **No gameplay-systems expansion.** The owner's instruction is explicit —
  *"DO NOT OVERBUILD GAMEPLAY SYSTEMS … Depth Offensive already added gameplay.
  Now make it feel better."* No talent trees, no combat redesign, no daily
  systems, no new economy architecture, no quest systems. `Q-15` stays closed to
  this workstream.
- **No Health change of any kind.** Zero semantic changes to granted-step
  accounting, cursor or watermark semantics, source accounting, the economy
  epoch, replay protection, save atomicity, single-writer or CAS expectations,
  or foreground-only sync. `RULES.md` H-1 through H-7 are untouched, and this
  workstream reaches nothing under `packages/stride_health`.
- **No save migration.** All six planned change families were audited as
  migration-free. If one becomes genuinely necessary it needs its own decision,
  not an implementation note.
- **No relaxation of the atlas protections.** `RULES.md` A-4's protected
  interior, the 20 px rim-band rule and the 15 byte-enforced landmark goldens
  all stand. The owner's authorization to recompose *weak, non-protected* areas
  is an authorization about the ~70% that is fair game, not a licence to touch
  the core. `A-3` still decides every boundary, and a seam metric is still
  triage rather than acceptance.
- **No answer to `Q-13`.** The lime-band identity question gates the southern
  atlas zone and is the owner's to settle. It stays `UNRESOLVED`, and the zone
  it gates is deferred rather than guessed at (`G-3`).
- **No blind staging.** `G-8` binds this workstream with unusual force: the
  working tree currently holds ~25 untracked exploration directories including
  `WALKSCAPE_REFERENCE_SET/`, the third-party imagery whose accidental
  publication required a history rewrite (`M-08`). Paths are named, every time.
- **No reward manipulation.** A larger art budget does not move `P-5` or `P-6`
  one inch. No streaks, no expiring rewards, no decay, no FOMO, no jackpot
  flourish, no casino sparkle, no coin or price or bullion semantics. The
  owner's own framing — *"Rewarding ≠ manipulative"* — matches the anti-features
  document and is treated as binding, not decorative.

## Reasoning

- **The blocking clause was about a number, not a principle.** 0029 spent its
  length arguing that interface art *should* be authored and then recorded that
  it could not be afforded that month. Reading its budget line as a standing
  prohibition would invert the decision's own conclusion.
- **Amending beats exempting, again.** 0029 made this argument about L-18 and it
  applies unchanged here: a one-off "except this workstream" would leave two
  decisions disagreeing about whether generation is permitted, which
  `RULES.md`'s preamble names as how a rule comes to disagree with itself.
- **The provider gap was a live record defect, not a technicality.** Shipped
  assets whose source is not sanctioned by any ADR is precisely the "missing
  manifest entry" failure `0005` classifies as a QA defect. It cost nothing to
  fix and would have cost real time to reconstruct later.
- **Stating the credential blocker in the decision prevents a silent
  substitution.** The failure mode available here is quietly shipping fewer
  sounds and calling the audio work done. Naming the boundary makes the eventual
  report checkable.
- **Resolving Q-14 was not a judgement call.** The owner answered it in
  imperatives. Leaving it open would have blocked the equipment round on a
  question that has been answered.

## Consequences

- `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md`'s preconditions P-0 through
  P-6 become live. **P-1 (`Scripts/art/check-art-palette.js`) and P-4
  (`Scripts/art/check-tile-seam.js`) did not exist and were built under this
  decision**, both landing green on the current tree — P-1 measuring 871 shipped
  PNGs for the first time and confirming exactly one teal file, the allowlisted
  step glyph. P-5's `.gitignore` exceptions are added. P-2, P-3 and the blocking
  `PanelSkin.inset` arithmetic were already satisfied by `6d41bce`.
- `Scripts/art/png.js` gains `loadAny`, a **read-only** decoder for palette and
  greyscale PNGs. The strict `load` that `package-art.js` depends on is
  unchanged. Without it the palette guard could not read 13 of 871 shipped files
  — the hand-maintained nav icons — which is a hole precisely where interface
  art lives. It has no `save` counterpart deliberately: round-tripping a palette
  PNG would launder it into RGBA without anyone deciding to.
- `JOURNAL/OPEN_QUESTIONS.md` — Q-14 moves to closed, citing this decision.
  Q-13, Q-15, Q-16 and Q-17 remain open and are re-stated as such.
- **`Q-16` becomes a prerequisite rather than a note.** Combat reads
  `disableAnimationsOf` nowhere; under Reduce Motion a 2.5 s round collapses to
  ~125 ms, and segment-placed combat cues would arrive nearly simultaneously
  with no voice cap to absorb them. Combat audio must not land before that is
  answered, or `M-16` is repeated with more voices.
- `AUDIO/AUDIO_ASSET_MANIFEST.md` gains a provider column entry for Stability
  AI covering the already-shipped assets.
- **Reversibility is preserved as a property.** The panel-skin registry and the
  `TravelerArt` tables both revert the product to its current appearance by
  emptying a map. That property survived 0029 and must survive this workstream.

## Invariant check

**P-1** mobile-first: unchanged; iPhone remains the verdict surface. **P-3/P-4**:
no progression, clock or step semantics are reached — this workstream is
presentation. **P-5/P-6**: reaffirmed above and constrain the reward art
explicitly. **P-7**: untouched. **H-1…H-7**: untouched; nothing under
`packages/stride_health` is modified. **E-1**: `stride_core` purity unaffected.
**E-2**: art is presentation; no raster carries or derives a game fact.
**E-5**: content stays data. **A-1**: PixelLab authors; Claude directs, selects,
transforms deterministically and integrates. **A-2**: the new `loadAny` reads,
it does not author. **A-3/A-4**: atlas protections stand in full. **G-1**: the
two new guards each answer a named uncovered risk — an unenforced L-16, and a
tiling seam no single-width human review can see. **G-4**: nothing is loosened;
the one self-test that failed was a wrong fixture, corrected against the guard
rather than the guard against the fixture.
