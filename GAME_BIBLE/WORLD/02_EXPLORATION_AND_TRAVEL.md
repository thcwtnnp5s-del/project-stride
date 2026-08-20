# Exploration and Travel

Real-world movement becomes fantasy-world travel and expedition progress.

Travel should:

- Require a clear destination
- Communicate remaining progress
- Create anticipation
- Unlock meaningful activity
- Respect delayed player return

Exploration may reveal:

- Locations
- Resources
- Encounters
- Lore
- Rare events
- Hidden routes

Travel should feel like adventure, not a loading bar.

---

## As implemented — Exploration & Progression Loop 01

The aspirations above are now concrete systems; the canonical design is
`GAME_BIBLE/SYSTEMS/09_EXPLORATION_PROGRESSION_LOOP.md` (§8, discovery and
the atlas) with the decisions in `DECISIONS/0023`:

- **A clear destination** — the Journey goal slot, set from the atlas.
- **Remaining progress** — the tracker's live projection of route cost
  against banked steps ("READY" when affordable); never an escrow.
- **Anticipation** — the travel confirmation (destination, route, cost,
  projected bank) and the arrival trace on the atlas.
- **Meaningful unlock** — boards, projects, nodes and enemies are all
  location-bound; rumors turn contract and project completions into named
  places on the map before they are reachable.
- **Respect for delayed return** — the step-sync banner says what the walk
  just made possible, and holds until dismissed.

Discovery is three tiers — visual-only terrain, rumored landmarks, and
discovered (visited) places — with no fog of war. The playable cluster is
deliberately a fraction of the painted continent.
