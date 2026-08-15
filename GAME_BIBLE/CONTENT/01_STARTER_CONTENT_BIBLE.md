# Starter Content Bible

## Haven’s Rest

Frontier settlement and starting hub.

Functions:

- Tutorial and onboarding
- Granting the player's starting equipment
- Crafting
- Equipment management
- NPC services for onboarding, quests, lore, and atmosphere — **no merchants, no buying or selling in Milestone 01**
- Access to nearby destinations

## Whispering Woods

Functions:

- Woodcutting
- Foraging
- Tutorial combat
- Forest atmosphere

Enemy:

- Forest Wolf

## Stonefall Mine

Functions:

- Mining
- Ore progression
- Cave combat

Enemy:

- Cave Goblin

## Forgotten Hollow

Functions:

- First challenge zone
- First mini-boss
- Proof of preparation and progression

Boss:

- Hollow Guardian

## Initial skill cap

Level 20 for the vertical slice.

## Starting equipment — granted at Haven's Rest onboarding

- Training Sword
- Training Axe
- Training Pickaxe
- Traveler armor set

These are granted, not crafted. The grant deliberately breaks the bootstrap circle in which gathering needs tools, tools need Smithing, Smithing needs ore, and ore needs a pickaxe.

The Traveler armor set is **not craftable** in Milestone 01 — there is no leather or cloth production skill in the slice, and none will be added for it.

**"Traveler armor set" is the starter equipment-slot and set classification. Visually it is ordinary travel clothing, not protective armor.** The visible starter clothing is the oat/sand tunic family, slate/brown trousers, a belt, and wrapped boots. The player must not read as armored, plated, a soldier, a knight, or a bulky fighter. The word *armor* here names a gameplay slot; it is not a visual instruction, and an artist must not interpret it as plate or defensive styling (`GAME_BIBLE/ART/ART_DIRECTION.md` L-1, `PIXEL_ART_CRAFT_SPEC.md` CR-42).

### Owned equipment is not the same as visible carry

The player owns and can use the Training Sword, the Training Axe and the Training Pickaxe. **The default Traveler visual loadout does not show all three at once.**

The default visible state of the character is:

| Where | What |
|---|---|
| Back | small canvas backpack |
| Character's left hip | sheathed Training Sword |
| Hands | empty |

The Training Axe and Training Pickaxe are **owned, equippable, activity-state tools** — not passive default-body clutter. They may become visibly equipped later when the relevant visual or gameplay state calls for them: conceptually, the axe in a woodcutting state and the pickaxe in a mining state. **Neither is lashed to the backpack or the body by default, and no additional tool slot is added to the current silhouette.**

Final animation and hand pose for those equipped states are **not defined** and are deliberately left open.

This distinction exists so that ownership inventory never becomes simultaneous visible-carry inventory. The visual read contract that implements it is `GAME_BIBLE/ART/CHARACTER_READ_SPEC_01.md`.

## First crafted upgrade tier — Bronze

- Bronze Sword
- Bronze Axe
- Bronze Pickaxe
- Bronze armor pieces

Bronze is the player's first *earned* equipment, produced through Mining → Smithing. Reaching it is the proof that the loop works.

## Consumables

- Basic healing food (Foraging → Cooking)

The first 20 levels should create attachment, understanding, and anticipation rather than exhaustion.

See `DECISIONS/0004_MILESTONE_01_SCOPE.md`.
