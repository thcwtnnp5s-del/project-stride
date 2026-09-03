# EPO03 — PROD-UI-INVENTORY ledger

Cap **60 generations**. One row per submitted job: what was asked, tool, job
id, the tool's own cost line, verdict, reason. Family total is the sum of the
cost lines (`PRODUCTION_RULES.md` §1) — never a balance delta (M-17).

## Rolls

| # | Asked for | Tool | Job id | Cost line | Verdict | Reason |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | **No job submitted.** See below. |

**Family total: 0 generations of 60.**

## Why zero

The kit contract's §8 lists **thirteen landed rows**, and the two this screen
is made of are among them:

- `KitFrame.insetWell` (`kit/inset_well.png`, 61², inset **15**) — the window
  the figure stands in.
- `KitFrame.slotWell` (`kit/slot_well.png`, 32² at ×2, inset **8**) — the
  well cut into the leather. One well per equipment slot in the case, and one
  per pocket in the pack.
- `KitTile.ruleChart` (8 × 4 at ×2, **8** dp) — the rule the pack's groups sit
  under.
- `PanelSurface.leather` and `PanelSurface.oilcloth` — the case and the pack's
  canvas, both shipped grains.

`KitTile.pocketRule` and `KitTile.caseStrap` did **not** land: NAV's ledger
records `pocket_rule` / `case_strap` / `rail_strap` coming back as "a blue-grey
checkerboard, an unreadably dark smear and grey rubble" and kept their
fallbacks. Their fallbacks are finished work — a reserved run of the declared
thickness with the hairline the pack already draws — so the pocket rules and
the case/pack seam are built against the names, spend the declared 12 dp and
32 dp today, and gain material the day either row lands without reflowing.
Re-rolling a family NAV has already measured and rejected at the kit's expense
would spend this cap on a known boundary (`PRODUCTION_RULES.md` §2a).

The one thing the screen needed that no raster provides — the **class shadow**
in an empty well — is a deterministic recolour of a shipped item sprite
(`RULES.md` A-2, the `49c91f9` precedent), not an authoring job: the slot's
representative sprite drawn through a `ColorFilter` at the well's own value.
Zero generations, and it cannot drift from the item set.
