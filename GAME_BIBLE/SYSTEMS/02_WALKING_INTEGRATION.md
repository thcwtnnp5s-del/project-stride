# Walking Integration

## Design goal

The player should think:

> My walk mattered.

## Initial source

Apple Health / HealthKit step count.

## Core requirements

- Read historical step count with permission
- Reconcile newly earned steps
- Never double-count consumed steps
- Support delayed syncing
- Work offline after data is available
- Clearly explain permissions and privacy
- Avoid shaming or pressure

## Gameplay outputs

Steps may advance:

- Travel
- Selected gathering activities
- Exploration
- Adventure preparation

Expeditions are deferred to Milestone 02 and are not a distinct system in the vertical slice.

Exact conversion rates must be balanced through testing rather than assumed.

## Steps gate rate, never access

> **Steps govern the rate at which new opportunities are created, but previously earned opportunities remain available indefinitely.**

Steps determine how *fast* the player progresses. They never determine what the player may *open, see, or attempt*.

With no new steps at all, the player can still craft from owned resources, manage inventory and equipment, review goals and skills and lore and discoveries, fight previously unlocked encounters, retry bosses while they hold the supplies, spend banked movement progress, and plan.

What they cannot do is gain new travel, gathering, resources, or skill progression from the passage of time.

**Nothing decays or expires.** Not banked steps, not partial progress, not resources, not XP, not discoveries. There is no upkeep, no spoilage, and no countdown anywhere in Project Stride. See `DECISIONS/0008_STEPLESS_WEEK.md`.

Every screen, every recipe the player has materials for, and every encounter the player is prepared for is available at zero available steps. Nothing is ever "locked until you walk." This is the boundary that keeps step spending from becoming an energy system, which `PROJECT_KERNEL/06_ANTI_FEATURES.md` forbids.

## Step-clocked, not time-clocked

Activity progress is a function of consumed steps only. Wall-clock time may be displayed — "last synced", "you were away for three days" — but is never an input to progression. See `DECISIONS/0001_PROGRESSION_CLOCK.md`.
