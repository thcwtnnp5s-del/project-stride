# Decision: Milestone 01 Scope Clarifications

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner

## Context

The initialization audit found five scope ambiguities where the Game Bible and the milestone definition disagreed or left a dependency unresolved. Raised as **C-04**, **C-05**, **C-06**, **C-07**, and **G-10** in `STUDIO_INITIALIZATION_REPORT.md`.

## Decisions

### 1. No currency or merchant economy in Milestone 01

Every resource comes from movement. Every item comes from crafting. There is no currency, no shop, no prices, and no merchant inventory in the vertical slice.

**NPCs may still exist** for onboarding, quests, lore, and atmosphere. They simply do not buy or sell.

*Reasoning:* a shop is a short-circuit around the exact loop the slice exists to validate. Deferred to Milestone 02.

### 2. Traveler armor is granted starting equipment

The Traveler armor set is given during Haven's Rest onboarding and is **not craftable**. This resolves the missing leather/cloth production skill without adding a sixth skill.

The craftable armor path in Milestone 01 is Smithing → Bronze.

### 3. Starting equipment resolves the tool bootstrap

The player begins with:

- Training Sword
- Training Axe
- Training Pickaxe
- Traveler armor set

**Bronze equipment is the first crafted upgrade tier.**

*Reasoning:* gathering required tools, tools required Smithing, Smithing required ore, and ore required a pickaxe. The starting grant breaks the circle explicitly rather than leaving it to implementation.

### 4. Milestone 01 has exactly five skills

Woodcutting, Mining, Foraging, Smithing, Cooking. "General Crafting" from `GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md` is a Milestone 02 concern. No combat skills (see `0003_COMBAT_MODEL.md`).

### 5. Six navigation tabs; Combat is a modal

Navigation is Adventure, Character, Skills, Inventory, Craft, World — as defined in `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`. Combat is a full-screen modal presented from Adventure or World, dismissible only by resolving or retreating.

This reconciles the six-destination navigation with the milestone's seven-screen list.

### 6. Expedition is not a Milestone 01 system

Travel and gathering cover the slice. **Expedition** remains a deferred concept in the glossary and backlog only, and must not appear in code, content schemas, or UI.

The same applies to **Adventure Momentum** and **Profession**: Milestone 02+ vocabulary, explicitly out of scope, not to be partially implemented.

## Consequences

- The Milestone 01 content set is now frozen: 4 locations, 5 skills, 3 enemies, 6 tabs + 1 modal, 0 currencies, 0 merchants.
- Any addition requires a new decision record. This is the primary defence against risk **R-05** (content scope creep).
- Onboarding at Haven's Rest carries real design weight: it grants starting equipment and teaches the loop.

## Follow-up

- Update `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`, `GAME_BIBLE/SYSTEMS/03_SKILL_SYSTEM_FRAMEWORK.md`, `GAME_BIBLE/SYSTEMS/05_ECONOMY_AND_RESOURCE_MODEL.md`, `PROJECT_KERNEL/08_GLOSSARY.md`, and `MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md`.
