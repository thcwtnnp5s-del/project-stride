# Playable Phase 2 — physical device acceptance

**Branch:** `playable-phase-2-multiregion` · **Base:** `3dd892d` (approved UI baseline)
**Status:** awaiting the owner's hardware run. **The milestone is not closed until this passes.**

---

## Before you start

**The first launch on your phone performs a one-time migration** that re-bases
the playable economy to zero (`DECISIONS/0016`). It runs once, automatically, on
the save already on the device. Nothing is deleted and the historical figures
stay reportable — but this is the run where the ~459,000 banked steps stop being
spendable, and **that is the headline thing to verify.**

If you want the old save preserved, copy it off the device before launching.

You will need: about **2,000 walked steps** for the first half, and about
**8,000 across the whole script** if you take the full vertical loop at the end.
The loop can be spread over two days; nothing expires.

---

## Install

Exactly as Phase 1 — free Personal Team, direct Xcode install. Nothing about
signing or provisioning changed.

**On the Mac:**

```bash
cd ProjectStride
git fetch origin
git checkout playable-phase-2-multiregion
flutter clean
flutter pub get
```

Then, with the iPhone plugged in and unlocked:

```bash
flutter devices
```

```bash
flutter build ios --profile
```

Open `ios/Runner.xcworkspace` in Xcode, select your iPhone as the destination,
confirm **Signing & Capabilities → Team** is your Personal Team, and press Run.

**Profile, not debug** — iOS will not launch a JIT debug build from the Home
Screen, which is how Phase 1 was run and how this must be run too.

After the first install, quit Xcode and **launch from the Home Screen**. Several
checks below are about cold launches and are meaningless from a debugger.

---

## Part A — the cutover (do this first, and only once)

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **1** | Launch from the Home Screen for the first time on this branch | The app opens normally. No error, no "new game", no refusal screen. | ☐ |
| **2** | Read **BANKED STEPS** in the header | **0** — or a small number if you walked between installing and launching. **Not 459,043.** | ☐ |
| **3** | Open **Character** | `TOTAL WALKED` still shows the **full historical figure** (~459,000+). The history is intact; it is simply not spendable. | ☐ |
| **4** | Open **Adventure**, try to gather at Meadow Patch | The button is **disabled** and says how many more steps are needed. A 90-step gather is unaffordable at 0. | ☐ |
| **5** | Force-quit and relaunch from the Home Screen | Banked steps are **still 0** (or whatever you have walked since). **The reset does not happen again.** | ☐ |
| **6** | Force-quit and relaunch a third time | Same. Still not reset, still not restored. | ☐ |

> **If step 2 shows a large number, stop and report it.** That is the one
> failure this milestone exists to prevent, and nothing below matters until it
> is understood.

> **If step 5 shows 0 after you had banked steps**, stop and report that too —
> it would mean the migration is running on every launch.

---

## Part B — earning, and not double-earning

Go for a walk. **About 1,500–2,000 steps** is enough for this part.

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **7** | Open the app from the Home Screen | The banked figure **rises on its own**, without you tapping anything. This is the new startup sync. | ☐ |
| **8** | Watch the very first frame as it opens | It shows your **real** balance. There is no flash of `0` and no spinner. | ☐ |
| **9** | Tap **Sync steps** immediately after | It grants **nothing further** — the startup sync already took them. A "no new steps" style result, not a second helping. | ☐ |
| **10** | Tap **Sync steps** once more | Still nothing. Two consecutive syncs never grant twice. | ☐ |
| **11** | Turn off Health permission for Stride in iOS Settings, relaunch | The game still **loads and plays**. Your banked steps and inventory are intact; only syncing is unavailable, and the app says so calmly rather than refusing to start. Turn the permission back on afterwards. | ☐ |

---

## Part C — travel

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **12** | Open **World** | A **Travel from here** card is the first thing you see, above the map — you should not have to scroll to find it. | ☐ |
| **13** | Read the two destinations | **Whispering Woods 600** and **Stonefall Mine 800**. Each says its terrain and how many resources are there. | ☐ |
| **14** | Look for Frostmere in the list below the map | It is in **This region** but has **no Travel button** — there is no road to it from Haven's Rest. | ☐ |
| **15** | With fewer than 600 banked, look at the Whispering Woods row | The button is **disabled** and says *"Walk N more steps"*, with N correct. | ☐ |
| **16** | With 600+ banked, tap **Travel** to Whispering Woods | You arrive. Exactly **600** steps are deducted — check the header before and after. | ☐ |
| **17** | Look at the header eyebrow | It now reads **WHISPERING WOODS**. | ☐ |
| **18** | Open **Adventure** | The picture is a **forest**, not Haven's Rest. | ☐ |
| **19** | Force-quit, relaunch from the Home Screen | You are **still at Whispering Woods**. Location persists. | ☐ |
| **20** | Open **World** and travel back to Haven's Rest | It costs **600 again**. Travel is never free, even on a road you have walked. | ☐ |

---

## Part D — the five skills

You will need to travel for these. Roughly **3,000 steps** covers Part D.

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **21** | At Haven's Rest, gather **Meadow Patch** | −90 steps, **×2 Meadow Herb**, **+10 Foraging XP**. **Foraging works.** | ☐ |
| **22** | Open **Skills** | Five skills, each with a level, a bar, XP into the level, and what the next level opens. Foraging shows **20 / 100 XP** after two gathers. | ☐ |
| **23** | Travel to Whispering Woods, open **Adventure** | **Two** activities: Oak Stand and Duskcap Grove — not one, and not Meadow Patch. | ☐ |
| **24** | Try **Oak Stand** without the axe equipped | Refused, and it says a tool is needed. | ☐ |
| **25** | Equip the **Training Axe** in Inventory, then chop | −120 steps, **Oak Log**, **+12 Woodcutting XP**. **Woodcutting works.** | ☐ |
| **26** | Try **Duskcap Grove** at Foraging 1 | Refused: it needs **Foraging 3**. A level gate you can see. | ☐ |
| **27** | Travel to Stonefall Mine, equip the **Training Pickaxe**, mine **Copper Seam** | −140 steps, **Copper Ore**, **+14 Mining XP**. **Mining works.** | ☐ |
| **28** | Try **Tin Seam** at Mining 1 | Refused: needs **Mining 3**. Keep mining copper until you reach it, then mine tin. | ☐ |

---

## Part E — crafting

**Crafting costs no steps.** You can do all of this at a zero balance.

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **29** | Open **Craft** | Every recipe is listed — eleven of them — with the craftable ones first. | ☐ |
| **30** | Look at a recipe you cannot make | It says **why**: either *"Needs Smithing N"* or *"Needs 2 more Copper Ore"*, naming every shortfall rather than the first. | ☐ |
| **31** | With 2 Copper + 1 Tin, craft **Bronze Ingot** | Succeeds at **Smithing 1**. Ore becomes metal on your first visit to the forge. **Smithing works.** | ☐ |
| **32** | Check Inventory | Exactly **2 Copper and 1 Tin gone**, exactly **1 Bronze Ingot** added. Not more, not less. | ☐ |
| **33** | With 3 Meadow Herb, craft **Herb Broth** | Succeeds, consumes exactly 3, grants 1, **+12 Cooking XP**. **Cooking works.** | ☐ |
| **34** | Craft **Oak Handle** (2 Oak Log), then keep smelting to **Smithing 2** | The Skills screen bar moves as you craft. | ☐ |
| **35** | At Smithing 2, craft a **Bronze Axe** | Succeeds. **This is the first thing you have earned rather than been given.** | ☐ |
| **36** | Force-quit, relaunch | The Bronze Axe is still in your inventory. Crafting persists. | ☐ |

---

## Part F — the full vertical loop

The milestone's headline claim, in one sitting or spread over two days. Budget
about **8,000 steps** in total from a standing start.

> **WALK → SYNC → TRAVEL → GATHER → PROCESS → CRAFT → LEVEL → TRAVEL AGAIN**

| # | Step | Expected | Pass? |
|---:|---|---|---|
| **37** | Walk, open the app, watch the steps arrive | Sync. | ☐ |
| **38** | Forage at Haven's Rest, travel to the Woods, chop oak | Gather, in two places. | ☐ |
| **39** | Travel to Stonefall, mine copper and tin | Gather, in a third. | ☐ |
| **40** | Craft ingots, a handle, and a **Bronze Axe** | Process, then create. | ☐ |
| **41** | Equip the Bronze Axe | A crafted tool in hand. | ☐ |
| **42** | Travel to **Frostmere** (1,500 from Stonefall) | The alpine region. Snow, a frozen tarn, conifers. | ☐ |
| **43** | Open **Adventure** at Frostmere | **Rimefrost Hollow** and **Frostpine Stand** — activities that exist nowhere else. | ☐ |
| **44** | Try **Frostpine Stand** | It needs **Woodcutting 8** *and* the tier-1 axe you just made. If you are not level 8 yet, it says so — that is the gate working, not a fault. | ☐ |
| **45** | Force-quit, relaunch, check everything | Location, inventory, skills, banked steps: all intact. | ☐ |

---

## What to report

For each ☐, a tick or a sentence. The ones that matter most, in order:

1. **Step 2** — did the playable balance start at zero?
2. **Step 5** — did it stay zero on relaunch, rather than resetting again?
3. **Step 3** — is your walking history still visible?
4. **Steps 9 and 10** — did repeat syncs grant nothing?
5. **Step 16** — did travel spend exactly the quoted cost?
6. **Step 32** — did crafting consume exactly the quoted ingredients?

And, separately from any checkbox:

> **Does it feel like a game now?**
>
> That is the question this milestone was actually for, and no test in the
> repository can answer it. Where does it drag? Where did you want to do
> something the app would not let you? What did you expect to happen and not
> find?

---

## Known limitations, so they are not reported as defects

- **The five skill icons and the turquoise step glyph are still the temporary
  art.** A replacement round was generated against a written specification and
  **failed independent blind QA** — at icon size the axe and the pickaxe read as
  the same object. It was not shipped. `GAME_BIBLE/ART/exploration/
  SKILL_ICONS_OD04/ROUND_01_RESULT.md`.
- **The region map is Phase 1's.** It shows four locations; the world now has
  five, and Frostmere is not drawn on it. The map is not wrong about what it
  shows, it is incomplete. New map art was deliberately deferred rather than
  rushed.
- **No combat.** Enemies exist in content and nothing fights them. Unchanged
  from Phase 1 and not part of this milestone.
- **All balance figures are provisional.** Travel costs, gather costs and skill
  gates are chosen so a week of walking is testable, not because they are right.
- **Crafting works anywhere**, not only at Haven's Rest. Defensible in fiction
  either way; no canon requires a workshop, and gating it would make the Craft
  tab lie on four screens out of five.
- **Forgotten Hollow needs a Bronze Sword** (3 ingots + 1 handle, Smithing 3).
  It is reachable but is the deepest thing in the slice; do not expect to see it
  in a first session.
