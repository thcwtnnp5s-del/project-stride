# EPO03 — producer's running observations

Things I saw in the accepted work that the teams did not raise themselves.
None of these blocked an acceptance; all of them go to the final council and
to the owner's device checklist, so nothing here is quietly dropped.

## Craft — the wax seals repeat

The recipe book is a real answer to "locked content must not read as
spreadsheet rows": chapters open once with an illustrated rule and state their
gate once, and every locked recipe is a sealed page with an ink silhouette.
**But six sealed pages are visible at once and all six carry the same
saturated red wax seal**, so the page reads as a grid of identical stamps at a
glance. The team rejected four per-trade seals for a defensible reason — the
impression fights the numeral the seal has to carry — and shipped one blank
seal serving every trade, which is why they are identical.

Worth trying before the round closes, cheapest first: vary the seal's *wax
tone* per trade by deterministic remap (the technique is already proven this
round and costs nothing), or vary the seal's rotation per recipe, or desaturate
the seal on chapters below the lit one so only the reachable chapter's seals
carry full colour. Any of the three breaks the grid without a new generation.

## Combat renders still show the old layout

The equipment device renders (`review/device/equip/*`) were captured against
the pre-rebuild combat screen: stage at the top, gauges, then two-thirds of
empty dark page. They prove the *gear*, which is what they were for, but they
are not evidence about combat. When PROD-UI-COMBAT lands, the gear set should
be re-rendered against the new layout before either is shown as final.

## The equipment renders are the right kind of proof

Recorded as a positive: the Waywarden and the longsword were judged on a real
screen at 393×852, not on a sprite sheet. The body reads as a distinct family
(hood, tiered mantle, split skirt) and the blade reads as a longsword (longer,
cross-guard, tip past the front foot) at the size a player actually sees. That
is the standard the other families should be held to.
