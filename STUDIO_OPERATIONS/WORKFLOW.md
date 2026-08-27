# Development Workflow

## Discovery
Define the problem and desired player outcome.

## Design
Create a feature specification and system interactions.

## Review
Run specialist, critic, creative, technical, and QA review.

## Implementation
Build only approved scope.

## Validation
Test functionality, UX, balance, performance, and alignment.

## Integration
Update the Game Bible, decisions, project state, and milestone records.

## World-atlas repairs (owner directive, 2026-08-26)

Atlas repair work follows a **strict single-defect visual loop** —
author → validate → render → inspect → adjust:

1. Identify ONE device-visible defect and map it to exact atlas coordinates.
2. Make ONE minimal correction, masked to its transition band
   (`RULES.md` A-4: the protected interior is enforced in the pipeline).
3. Recompose the actual production atlas (`node Scripts/art/package-art.js`).
4. Render and review: full-atlas context, the defect close-up, ALL affected
   repair-perimeter edges and corners, and a representative iPhone-scale
   viewport (a round's `make_review.js` is the pattern).
5. Accept or reject that individual repair before starting another. A repair
   that introduces a new visible patch or perimeter is rejected immediately —
   never built upon.

Never batch unreviewed terrain corrections. The physical iPhone is the final
visual authority (`MISTAKES.md` M-14, M-15).
