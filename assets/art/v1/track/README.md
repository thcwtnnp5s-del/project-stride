# `assets/art/v1/track/` — the Skills journey family, packaged

Declared as a **directory** in `pubspec.yaml` (EPO03, requested by
PROD-UI-SKILLS for `DIR-07`). The journey stills — the track strip, its
joints, spur/fold/caps, the backplate, badge plates, the gauge frame, the
region marks, the gate seal and the hero emblems — are emitted by SKILLS'
own block in `Scripts/art/package-art.js`; one emitter owns this path and
`--check` guards its contents. Nothing is hand-copied here.

Consumed through `lib/ui/screens/skills/track_art.dart` (SKILLS' own file),
not through the shared kit registries: `KitFrame.journeyPlate`,
`KitTile.journeyRoad`, `KitMark.journeyWaystone` and the two lanterns in
`MILESTONES/evidence/EPO03/wave2/KIT_CONTRACT.md` are deliberately left
unregistered this round, and NAV spends no generations on them.

This README exists so the directory exists before its first asset lands: a
`pubspec.yaml` directory entry that does not resolve is a hard build error,
and git does not track an empty directory. The `--check` sweep skips `.md`.
