# Agent Orchestration

## Leadership

- Creative Director
- Technical Director
- Lead Game Designer

## Specialists

- Systems Designer
- Combat Designer
- World Designer
- UX Designer
- Audio Director

## Review

- QA Director
- Critic Agent

## Required flow

```text
Brief
Specialist proposals
Cross-agent review
Critic challenge
Creative and technical approval
Implementation
QA
Documentation
```

Agents may propose changes but may not silently redefine the Kernel.

---

## Visual Studio

A separate roster for visual production. It exists because visual work fails in a
way design work does not: an author can make a defensible, technically correct
change and report it as a fix while a viewer sees no difference at all.

### The perceptual law

> **A technically correct pixel change is not a successful visual change unless
> the intended improvement is perceptible at target viewing scale.**
>
> Source intent gets no credit. Not a variable name, not a comment, not an
> author's report, not a pixel count, not a passing assertion.

Craft consequences are canonical in `GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md`
(CR-41). The cost that earned it is recorded in `MISTAKES.md` M-04.

### Roster

| Role | Status | Tools |
|---|---|---|
| **Visual Director / Orchestrator** | the main session, not an agent | — |
| **Character Visual Designer** | **INSTALLED** — `AGENTS/character_visual_designer.md` | `Read, Grep, Glob, Write` |
| **Character Pixel Artist** | **INSTALLED** — `AGENTS/character_pixel_artist.md` | `Read, Grep, Glob, Write, Edit, Bash` |
| **Environment Pixel Artist** | **INSTALLED** — `AGENTS/environment_pixel_artist.md` | `Read, Grep, Glob, Write, Edit, Bash` |
| **UI Pixel Designer** | **INSTALLED** — `AGENTS/ui_pixel_designer.md` | `Read, Grep, Glob, Write, Edit, Bash` |
| **Visual QA / Perceptual Critic** | **INSTALLED** — `AGENTS/visual_qa.md` | **`Read, Grep, Glob` — read-only** |

**No further visual roles.** When sheet production, animation or colour scripting
become real work, they extend an existing charter rather than opening a sixth seat.

The four specialists were installed only after Visual QA demonstrated, in a
deliberate smoke test, that a fresh read-only subagent can genuinely inspect a
staged render and critique it independently — the load-bearing unproven assumption
of the whole model. It was tested before it was trusted, and its first act was to
overturn the authoring agent's own `READY` assessment.

**New `.claude/agents/` definitions register at session start.** A newly created
specialist is not reliably spawnable in the session that created it, so the first
real use of a new agent belongs to a fresh session. Do not work around this by
pasting charters inline — an inline charter tests the prompt, not the installation.

### The READ SPEC

Character work runs through one artifact the implementer cannot edit. The designer
writes it before any pixel moves; the orchestrator approves it; it is **frozen** the
moment the artist starts; and Visual QA tests against it rather than against the
change list.

**Every item is phrased as something a stranger can answer from the render alone**,
with its expected answer recorded beside it and withheld from QA until the blind
phase is complete. "What is on the character's back?" is a spec item. "The pack uses
a soft trapezoid" is an implementation note. "The figure feels grounded" cannot
fail, and a spec item that cannot fail is not one.

**Only the orchestrator decides** canonical art-direction interpretation, which
experiment is running, immutable scene constraints, the accepted character
concept, the approved equipment inventory, palette policy, which corrections a
specialist is authorised to make, whether an asset is shown to the owner, and
whether work is committed. **The orchestrator must not be the only visual critic.**

### Required flow

```text
Orchestrator      immutable brief + frozen constraints
Designer          READ SPEC, where a character is involved
Orchestrator      approves the read spec -> FROZEN
Specialist        authors
Render            native + x2 play-scale proxy + x8 + in-context
Orchestrator      stages qa_inbox/ under NEUTRAL, NON-ORDINAL names
Visual QA         blind read -> delta -> reveal -> compliance
Visual QA         findings + severity + category + QA VERDICT
Orchestrator      accepts/rejects findings; escalates every category D
Same specialist   ONE correction pass on accepted BLOCKER + MAJOR
Visual QA         re-checks accepted items only
Orchestrator      if blockers survive: one more pass, or STOP AND REPORT FAILURE
Owner             receives output, both assessments, and any surviving blocker
```

### Neutral staging

Blind review is enforced by staging, not by good intentions. Renders are copied
to a scratch inbox under names that carry no subject, no version and no verdict:

```
qa_inbox/asset_K_native.png  asset_K_x2.png  asset_K_x8.png  asset_K_context.png
qa_inbox/asset_R_native.png  ...              assignment randomised in code
```

**Version labels must be NON-ORDINAL** — `K`/`R`, `P`/`V`, `M`/`Q`, or opaque
identifiers. Never `A`/`B`, never `1`/`2`, never `before`/`after`. The first smoke
test used `A`/`B` and the critic reported unprompted that the ordering carried a
weak "B is the revision" pull, and that its blind preference had landed on `B`. The
version key is written **outside** the inbox, so the agent cannot reach it by
listing its own input directory.

A path such as `TRAVELER_REFINE_03/compare_r03f_corrected_x8.png` leaks the
subject, the version and which half is the answer. Source comments leak more.
**If staging is skipped, that round's QA is worthless and is discarded rather
than trusted.**

### Target scale

Every visual review inspects **native → ×2 play-scale proxy → ×8 → in-context**.
The ×2 proxy is mandatory in the standard render set. **×8 is inspection scale,
never verdict scale** — it flatters everything.

### Severity and category

**BLOCKER** — a viewer misidentifies an object, or sees something that is not
there; the finding must name what a player would call it instead. Must not reach
owner review. · **MAJOR** — read survives but is materially harmed; one
correction pass. · **MINOR** — polish; may reach owner review. · **NOTE** — taste
or future idea; never auto-fixed.

Categories: **A** objective craft · **B** perceptual/semantic · **C** taste ·
**D** canon/direction. A and B may block. C is reported. **D is escalated to the
orchestrator; QA never decides it.**

### Separate verdicts — no self-certification

Every visual task ends with **two lines**:

```text
AUTHOR ASSESSMENT: ...
QA VERDICT: PASS / FAIL ...
```

**The author never writes the QA verdict, and the orchestrator never writes it on
QA's behalf.** No visual task may end with a graduation decision authored by the
agent that made the pixels.

**Owner feedback supersedes every internal judgement, including a QA PASS.**

### Worktrees

Not used for visual work at present. QA is read-only, so isolation buys nothing;
and the character, environment and UI domains still share the palette, the scene
module and the surface library, so their inputs are not frozen. Revisit only once
the base scene and palette are locked.
