# Visible equipment round 01 — record

```
STATUS: ARMOUR ACCEPTED AND SHIPPED · COMBAT WEAPON VARIANTS DEFERRED
Date: 2026-09-01 · ~160 generations (5 character states + 9 animation tracks)
Authority: DECISIONS/0030 § 3 (Q-14 closed by owner ruling)
Evidence: MILESTONES/evidence/VAWO01/wave0/FOUNDATION_G_EQUIPMENT.md
```

## What shipped

Three coarse armour classes as full standing figures, and the Character screen
now draws **what the player is wearing** instead of a fixed bust.

| Class | Items it serves | Figure |
|---|---|---|
| base | `traveler_tunic`, `waywarden_tunic` | the Traveler |
| `armor.plate` | `bronze_chestplate`, `scalewarmed_chestplate` | bronze breastplate |
| `armor.jerkin` | `wolfhide_jerkin`, `tuskbound_jerkin`, `frostlined_jerkin` | fur-trimmed jerkin |
| `armor.coat` | `bearhide_coat`, `clawguard_coat`, `frostwarden_coat` | long belted coat |

**Identity was verified before a single state was ordered.** The canonical
PixelLab character `c82b7da5-…` and the shipped `sprite/traveler_south.png` were
rendered side by side and are the same individual — so `create_character_state`
produces *variants*, not lookalikes, and the face, proportions, pack and scarf
carry over while only the garment changes.

**Zero new persisted state.** `equipmentVisualState` is a getter over
`equipment.bySlot`; the tables are presentation-layer `const` maps keyed by item
id. State stays **v9**. `visible_equipment_test.dart` pins that, and pins that
an unmapped item degrades to the base Traveler rather than to a hole.

## What did NOT ship, and why

**Combat weapon variants.** Two states were authored — Guard Unarmed and Guard
Bronze Sword — and both read correctly as stills. The stills are kept in
`review/equip/combat_states_x4.png`: side by side with the shipped combat idle
they show exactly the fix the owner asked for, a Traveler with raised fists and
no weapon beside a Traveler holding a bronze blade rather than the baked steel
one.

**The animation tracks are what failed, and the reason is worth keeping.**

> **PixelLab's template animations discard held props.** `fight-stance-idle-8-frames`
> and `taking-punch` returned the Bronze Sword state **bare-handed** — the
> template imposes a skeleton and re-renders the figure into it, and a sword
> that is not part of the base pose does not survive that. Only the v3 custom
> attack (`swinging a sword downward`) kept the blade.

So a bronze loadout would have flickered between armed and unarmed *within a
single round* — idle unarmed, attack armed, flinch unarmed. That is worse than
the defect it was meant to fix, and `CombatantArt` requires all four tracks, so
a partial set is not an option.

Secondary finding: the templates also drift identity. `taking-punch` washed the
green vest out almost entirely and shifted the scarf from red to orange.

**What the next round needs**, so it is not re-derived:

1. **v3 mode only** for every weapon track, never template, with the weapon
   named in the action description on each one (*"…while holding the bronze
   sword"*).
2. A **per-frame weapon-presence check** before acceptance — the failure here
   was invisible until the frames were laid out side by side.
3. An **A-2 palette conform** onto the shipped Traveler ramp to pull back the
   value drift the animator introduces.
4. Budget ~8 tracks per weapon class, and expect re-rolls.

**Consequence, stated plainly: the unarmed player still sees a baked steel
sword in combat.** That contradiction is unchanged by this round.

## Not attempted

Tools are already visible in the work loops — the shipped mining and
woodcutting animations carry a baked generic pick and axe — so "an axe during
woodcutting, a pick during mining" is met generically today. Making them
*item-specific* is a lower-value round than the two above and was not started.
