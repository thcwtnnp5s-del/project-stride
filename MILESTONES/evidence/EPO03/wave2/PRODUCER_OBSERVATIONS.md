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

## Items — a metric was wrong, and the art was not changed to satisfy it

Recorded as the round’s best piece of self-discipline, and as precedent.
PROD-ITEMS wrote an assertion that the epic longsword must carry more pixels
than the bronze sword. It failed — `bronze_sword` carries 585 px to the
epic’s 549, because its blade is *broader*. The team did not touch the icon
to make the number go green. It rewrote the assertion to measure **reach**
(bounding-box diagonal), which is what the eye actually reads, and left the
art alone.

That is `RULES.md` G-4 turned on the team’s own test rather than on someone
else’s guard: a failing assertion is evidence about the assertion as well as
about the thing it measures, and the fix belongs wherever the error is. The
same team also caught its own packaging block re-emitting twenty icons at the
foot of the file, which made `--check` report all twenty stale on a perfectly
synced tree — a false alarm that would have cost the next reader an hour.

## Items — the weakest accepted result, named

`reinforced_pickaxe` is the one icon in the family I would look at first if
the owner disagrees with anything here. Three regeneration rolls drew a
hammer, a mace, and an off-palette horned collar — each lost the tool — so
the team amended the shipped icon by edit instead, and it now separates from
its siblings by the head-to-haft joint rather than by outline. That is a
weaker kind of distinctness than the silhouette changes that fixed the
armour group, and it is honest about being so.

## Items — an evidence gap the team refused to paper over

The Inventory proof render shows the ivory group won in sixty real gather
trips rather than granted, which is the right kind of evidence. Two tusks
are missing from it because the encounter roster fills both slots with the
wolf. The team wrote the fix, could not compile it while another team was
mid-refactor on the same files, and **kept the verified render rather than
committing an unverified one**. That is the correct call; the gap is named
here so it is not mistaken for completeness.
