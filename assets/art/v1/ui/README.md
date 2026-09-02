# `assets/art/v1/ui/` — screen-specific chrome, packaged

Declared as a **directory** in `pubspec.yaml` (EPO03, requested by
UI-INVENTORY). Every file here is written by a screen team's own block in
`Scripts/art/package-art.js` and is named `<team>_<name>.png` — flat, no
subdirectories — so one emitter owns one path and `--check` guards the
contents. Do not hand-copy a file into this tree: `--check` reports it as
`unexpected:` and CI fails.

**This is not the shared kit.** Interface chrome every screen uses — frames,
surfaces, bands, buttons, edges, the nav — lives in the hand-maintained
`assets/ui/v1/` tree, is declared file by file, and belongs to PROD-UI-NAV
(`MILESTONES/evidence/EPO03/wave2/KIT_CONTRACT.md`). A file here is chrome
**one screen** draws.

This README exists so the directory exists before its first asset lands: a
`pubspec.yaml` directory entry that does not resolve is a hard build error,
and git does not track an empty directory. The `--check` sweep skips `.md`.
