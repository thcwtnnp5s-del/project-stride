# FMPO02 Wave 2 — production rules for every PROD lead

You have direct PixelLab MCP access. You are spending the owner's budget. Read
MILESTONES/evidence/FMPO02/wave1/BRIEF_CONTEXT.md, ART-01_executive_doctrine.md §3 (binding
consistency rules), and your family's brief before the first generation.

## Workspace
- Round dir: GAME_BIBLE/ART/exploration/FMPO02/
  - raw/<family>/...    untracked candidate dumps (download EVERYTHING you keep here)
  - out/<family>/...    selected, packaging-ready files (exact canvas, keyed, cropped)
  - review/<family>/... contact sheets you looked at
  - rejected/<family>/  rejected candidates WITH a one-line reason in the ledger
- Tools (node): tools/fetch.js <url> <out>  · tools/crop.js in x y w h out ·
  tools/sheet.js out scale cols bg frames...  · Scripts/art/png.js (load/save/crop/scale/blit/bounds)
- Write scripts to tools/ and run them with `node`; do not inline multi-line node -e.
- Images reachable by PixelLab: its own result URLs (get_image download URLs, character rotation/animation URLs) and https://raw.githubusercontent.com/thcwtnnp5s-del/project-stride/fable5-mega-production-overhaul-02/<repo path> for anything committed and pushed on this branch. Inline base64 only under ~5 KB.

## Ledger (mandatory)
Append to GAME_BIBLE/ART/exploration/FMPO02/ledger/<FAMILY>.md one row per job:
`| job/id | tool | canvas | cost | ACCEPT/REJECT/RE-ROLL | reason |`
Sum requested / accepted / rejected at the bottom. Call get_balance at start and end and record both.

## Looking (mandatory)
Never accept from a thumbnail. Download, build a contact sheet at ×2–×4 on `#14120F`, and Read it. For a sequence, one sheet with all frames bottom-aligned. For icons, a grid in-context on the inventory well colour `#14120F` at ×1 AND ×2. Reject anything that fails the ART-01 §3 rules: one sun upper-left, selective local-hue outline on subjects, none on backdrops, ≤4 values per material, no partial alpha, no reserved teal (#58D6C0 ±10), bronze reads reddish-copper never gold, no coins/timers/locks/meters/text in any raster.

## Cost discipline
- pixen (1 gen) is the default for stills; 3–4 candidates per subject, pick one.
- edit_image_pixen (1 gen) before any 20–40 gen edit_image/inpaint. Use pro tools only where the brief says so.
- Never exceed your family cap. Stop at 40% and Read a device-scale sheet of what you have before spending the rest (ART-01 R3).
- A batch that fails twice is recorded and left; do not chase.

## Output contract
Final message ≤80 lines: what was accepted (paths in out/), what was rejected and why, what the integrator must do (exact emit lines / table rows / canvas & anchor facts), balance start→end, and any UNRESOLVED question. Also write it to MILESTONES/evidence/FMPO02/wave2/<FAMILY>_report.md.
