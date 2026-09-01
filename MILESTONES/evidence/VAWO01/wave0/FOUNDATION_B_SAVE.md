# VAWO01 Wave 0 — FOUNDATION-B: Save / Persistence Surface Map

**Role:** Save / Persistence Guardian
**Date:** 2026-09-01
**Branch surveyed:** `presentation-combat-evolution-01` (HEAD `6d41bce`)
**Mode:** read-and-report. No file in the repository was modified except this one.

**Owner constraint being served:** preserve existing saves, prefer **no**
migration, **zero** change to Health / step accounting semantics.

---

## 0. Headline answers

| Question | Answer |
|---|---|
| Current save **state version** | **9**, at `packages/stride_core/lib/src/engine/state_version.dart:40` |
| Current save **format (envelope/framing) version** | **1**, at `packages/stride_core/lib/src/save/save_codec.dart:37` |
| Current **content schema version** (authored content, *not* saves) | **1**, at `packages/stride_core/lib/src/content/schema_version.dart:26` |
| Equipped-item persisted fields | `GameState.equipment.bySlot` → JSON `equipment: {"weapon"\|"armor"\|"tool": "<item id>"}` — `save_codec.dart:174-179` |
| Can visible equipment be a pure projection? | **Yes, definitively — and the projection already exists and is already tested.** See §5 |
| Audio settings in the save? | **No.** They are a separate unversioned JSON sidecar. See §6 |
| Migrations to date | **8 steps**, v1→v9, `packages/stride_core/lib/src/engine/state_migrations.dart:113-221` |

---

## 1. Where persistence lives

There are **three** independent durable surfaces. Only the first is the save.

### 1.1 The game save (transactional, single-writer, versioned)

| Concern | File |
|---|---|
| Encoding / decoding / framing | `packages/stride_core/lib/src/save/save_codec.dart` (1409 lines) |
| Transaction protocol, slot selection, CAS, recovery | `packages/stride_core/lib/src/save/save_repository.dart` (1093 lines) |
| Journal record shape | `packages/stride_core/lib/src/save/journal_record.dart` |
| Event wire codec | `packages/stride_core/lib/src/save/event_codec.dart` |
| Outcomes / diagnoses | `packages/stride_core/lib/src/save/save_outcomes.dart` |
| Whole-state canonical comparison | `packages/stride_core/lib/src/save/durable_state.dart` |
| CRC | `packages/stride_core/lib/src/save/crc32c.dart` |
| Full reset | `packages/stride_core/lib/src/save/reset.dart` |
| Storage ports (bytes only) | `packages/stride_core/lib/src/ports/save_store.dart` |
| Cross-process lock port | `packages/stride_core/lib/src/ports/transaction_lock.dart` |
| Filesystem implementations | `packages/stride_storage/lib/src/file_storage.dart`, `file_lock.dart` |
| State shape | `packages/stride_core/lib/src/engine/game_state.dart` |
| Version constant | `packages/stride_core/lib/src/engine/state_version.dart` |
| Migration table | `packages/stride_core/lib/src/engine/state_migrations.dart` |
| Migration driver | `packages/stride_core/lib/src/bootstrap/bootstrap.dart` |

Save directory on device: `<application support>/project_stride/` —
`lib/runtime/runtime_bootstrap.dart:223` with
`StorageLayout.directoryName = 'project_stride'` at
`packages/stride_storage/lib/src/file_storage.dart:53`.

### 1.2 Preference / presentation sidecars (non-transactional, unversioned)

Both are plain JSON files written temp-then-rename in the application support
directory, **beside** — never inside — the save directory.

| Sidecar | File | Path | Keys |
|---|---|---|---|
| Audio + haptics preferences | `lib/audio/audio_settings_store.dart:25-64` | `<support>/audio_settings.json` (`:32`) | see §6 |
| First-craft presentation memory | `lib/ui/state/craft_memory.dart:32-90` | `<support>/craft_memory.json` (`:47`) | `crafted` (list of ContentId strings) |

`craft_memory.dart:5-12` explicitly names `AudioSettingsStore` as the pattern
it copies, and `audio_settings.dart:1-8` states the rationale in the source:
volumes stay out of the save so there is **no schema change, no migration, and
no way for an audio slider to enter the single-writer commit path**
(`DECISIONS/0013`).

**This is the sanctioned seam for VAWO01's new presentation preferences.**

### 1.3 The secure identity vault

`lib/runtime/identity_vault.dart`, `packages/stride_secure_store/` — Keychain
(iOS) / app-private file (Android) holding the origin pseudonymization salt.
Security identity, not preferences. Off limits to a presentation workstream:
a changed salt re-keys every step origin and would re-grant the whole live
retention window (`save_codec.dart:100-107`).

---

## 2. Save schema version — exact definition

```
packages/stride_core/lib/src/engine/state_version.dart:40
  static const StateVersion current = StateVersion(9);

packages/stride_core/lib/src/engine/state_version.dart:50
  static const StateVersion minimumSupported = StateVersion(1);
```

`StateVersion.migrationRequired(version)` at `state_version.dart:61-62` is
**the only durable signal** that a migration step has not yet run on a save.
There is deliberately no boolean beside it.

Two *other* version numbers exist and must not be confused with it:

- **`SaveFormatVersion`** (`save_codec.dart:34-39`) — framing/envelope only:
  magic, length, CRC. `current = 1`, `minimumSupported = 1`. Unchanged since
  the beginning.
- **`SchemaVersion`** (`content/schema_version.dart:23-26`) — the version of
  **authored content bundles** (`items.json`, `locations.json`, …), not saves.
  `current = 1`, `minimumSupported = 1`. Its own doc comment says so
  explicitly at `schema_version.dart:14-15`.

The version history table is maintained in prose at
`state_version.dart:21-32`.

---

## 3. How migrations are performed today

### 3.1 Two mechanisms, deliberately different shapes

**Decoding is a fan-in of direct decoders — never a chain.** A v1 save is read
by `V1StateDecoder` straight into the current `GameState` shape. There is no
v1→v2→v3 JSON transformation. `StateCodecs._decoders` at
`save_codec.dart:606-616` lists nine decoders (`V1StateDecoder` …
`V9StateDecoder`, defined `save_codec.dart:637-851`); `decoderFor` at
`save_codec.dart:618-624`.

**Encoding is single-version.** There is exactly one encoder,
`encodeGameState` at `save_codec.dart:162-209`, and it only ever writes the
current version. Old formats are never written.

The decoders share one parameterised shape function `_decodeStateShape`
(`save_codec.dart:905`), keyed by four small enums that name what differs
between versions: `_CombatShape` (`:852`), `_QueueShape` (`:867`),
`_LoopShape` (`:878`), `_EpochShape` (`:890`).

**Meaning applied after decoding IS a chain** — that is `StateMigrations`.

### 3.2 The migration table

`packages/stride_core/lib/src/engine/state_migrations.dart:113-221`. Each
`StateMigrationStep` (`:34-99`) declares, in code:

- `rebasesEconomy` (`:55`) — **false unless a decision says otherwise**. This
  is the field that stops a format bump from being a balance reset by
  accident.
- `afterFirstReconcile` (`:75`) — defer past the first foreground health sync.
- `clearsStaleTrackedContract` (`:92`) — the table's one progress repair.
- `decision` (`:79`) — the authorising `DECISIONS/` document.

An assertion at `:42` requires `to == from + 1`.

### 3.3 Existing migrations — the complete list

| Step | Rebases economy | Other effect | Decision | Table line |
|---:|---|---|---|---|
| 1 → 2 | **yes** | Phase 2 economy cutover; Phase 1 balance retired | `DECISIONS/0016` | `:116-121` |
| 2 → 3 | **yes** (`afterFirstReconcile`) | Transformation playtest epoch | `DECISIONS/0018` | `:129-135` |
| 3 → 4 | no | format bump: `encounter`, `world.drivenOff` | `DECISIONS/0020` | `:140-145` |
| 4 → 5 | no | reshape: `drivenOff` set → `visitVictories` counts | `DECISIONS/0021` | `:158-163` |
| 5 → 6 | no | format bump: `activityQueue` | `DECISIONS/0022` | `:170-175` |
| 6 → 7 | no | format bump: `player.hp`, `progress`, `encounter.playerFrostGuard` | `DECISIONS/0023` | `:184-189` |
| 7 → 8 | no | **no shape change**; clears a stale Contract tracker | `DECISIONS/0024` | `:203-209` |
| 8 → 9 | no | format bump: `steps.epoch.walkedAtStart` | `DECISIONS/0025` | `:215-220` |

Six of the eight are `rebasesEconomy: false` and commit **the version bump with
an empty event list**. That is the precedent for a pure format bump: cheap,
but not free — each one required a new decoder, a new frozen fixture, a new
generator tool, and a new test group (§8).

### 3.4 The driver

`applyStateMigrationPath` — `packages/stride_core/lib/src/bootstrap/bootstrap.dart:344-398`.
Order is: **format first** (`state.migratedToCurrentVersion()` at `:355`,
defined `game_state.dart:792-806`), **meaning second** (walk the steps,
issuing `EstablishEconomyEpoch` only where `rebasesEconomy` is true, `:361-372`).

`StateMigrations.pathFrom` at `state_migrations.dart:238-245` computes the
path; `defersPastFirstReconcile` (`:229`) and `repairsTrackedContract`
(`:224`) query it. When any step on the path defers,
`BootstrapCoordinator` commits **nothing** at bootstrap and hands the whole
path back as a `PendingStateMigration` (`bootstrap.dart:448-470`,
`:971`) so the migration stays one commit.

Path contiguity — first step starts at `minimumSupported`, last ends at
`current`, no gaps — is **asserted by test**, not trusted:
`packages/stride_core/test/transformation_epoch_test.dart` group 0
(`state_migrations.dart:110-112`). **Bumping `StateVersion.current` without
adding a step fails a test rather than a device.**

---

## 4. The persisted field inventory

### 4.1 Top-level save envelope

`SaveEnvelope` — `save_codec.dart:55-110`; encoded by `encodeSnapshot`
(`save_codec.dart:491`), decoded by `decodeEnvelope` (`:531`).

| Field | Line | Note |
|---|---|---|
| `saveFormatVersion` | `:70` | framing |
| `gameStateVersion` | `:71` | the number in §2 |
| `contentSchemaVersion` | `:72` | |
| `balanceProfileId` | `:77` | **authoritative** — governs how the save loads regardless of app default |
| `saveId` | `:82` | opaque lineage id, minted by the app |
| `snapshotGeneration` | `:85` | monotonic, +1 per snapshot write; selects the live slot |
| `lastAppliedTransaction` | `:88` | journal transaction absorbed |
| `eventSequence` | `:92` | mirrors `state.eventSequence` |
| `commitComplete` | `:99` | written last within the payload |
| `originSaltFingerprint` | `:107` | **health-critical** — see §7 |

Framing: magic `'stride.save'` (`:401`), header `{m, f, len, crc}`
(`frame`, `:408-417`). Length in the frame so truncation is distinguishable
from corruption without parsing.

### 4.2 `GameState` — the complete persisted tree

Declared `game_state.dart:682-806`. Encoded `save_codec.dart:162-209`.

| JSON key | Dart | Encode | Decl | Since |
|---|---|---|---|---|
| `stateVersion` | `GameState.stateVersion` | `:163` | `game_state.dart:703` | v1 |
| `profileId` | `GameState.profileId` | `:164` | `:706` | v1 |
| `contentPackVersion` | `GameState.contentPackVersion` | `:165` | `:709` | v1 |
| `eventSequence` | `GameState.eventSequence` | `:166` | `~:741` | v1 |
| `player.level` | `PlayerState.level` | `:168` | `game_state.dart:73` | v1 |
| `player.experience` | `PlayerState.experience` | `:169` | `:74` | v1 |
| `player.hp` | `PlayerState.hp` | `:171` | `:82` | **v7** |
| `inventory` | `Inventory.counts` | `:173` | `game_state.dart:107-151` | v1 |
| **`equipment`** | **`Equipment.bySlot`** | **`:174-179`** | **`game_state.dart:153-183`** | **v1** |
| `skills` | `SkillProgress.experienceBySkill` | `:180` | `game_state.dart:188` | v1 |
| `world.currentLocation` | `WorldState.currentLocation` | `:182` | `game_state.dart:230` | v1 |
| `world.unlockedLocations` | `WorldState.unlockedLocations` | `:183-185` | `:231` | v1 |
| `world.visitVictories` | `WorldState.visitVictories` | `:191-195` | `:247` | **v5** |
| `steps` | `StepLedger` | `:197` | see §7 | v1 |
| `encounter` | `EncounterState?` | `:201` / `_encodeEncounter :273-290` | `game_state.dart:717` | **v4** |
| `activityQueue` | `ActivityQueueState?` | `:205` / `_encodeActivityQueue :262-271` | `game_state.dart:727` | **v6** |
| `progress` | `ProgressState` | `:208` / `_encodeProgress :211-260` | `game_state.dart:734` | **v7** |

**Player appearance:** `PlayerState` is `{level, experience, hp}` and nothing
else (`game_state.dart:61-99`). A repo-wide grep for
`appearance|cosmetic|skinTone|hairColor|avatar|portraitId` finds **no
persisted appearance field anywhere** — every hit is prose or a UI-local
name. **There is no character-appearance persistence today.**

### 4.3 Equipment — the exact shape

```dart
// packages/stride_core/lib/src/save/save_codec.dart:174-179
'equipment': <String, Object?>{
  for (final MapEntry<EquipmentSlot, ContentId> e in _sortedByKeyName(
    state.equipment.bySlot,
  ))
    e.key.name: e.value.value,
},
```

- Slot enum: `enum EquipmentSlot { weapon, armor, tool }` —
  `packages/stride_core/lib/src/content/definitions.dart:85`
- Sort for canonical bytes: `_sortedByKeyName`, `save_codec.dart:304-312`
- Decode: `save_codec.dart:969` (read), `:1066-1076` (slot resolution;
  an unknown slot name is a hard `SaveCodecException` at `:1070`),
  `:1112` (construction)
- Class: `Equipment` — `game_state.dart:153-183`;
  `bySlot` (`:160`), `inSlot` (`:162`), `equipping` (`:166`),
  `clearing` (`:169`)
- Content side: `ItemDefinition.slot` — `definitions.dart:176`, parsed
  `:244-250`; `ItemCategory.equipment` — `definitions.dart:7`

**Nothing else about equipment is persisted.** No variant id, no art key, no
appearance data, no layer order. The save holds *slot → item id*, full stop.

### 4.4 Combat state

`EncounterState`, encoded `save_codec.dart:273-290`, keys:
`enemy`, `location`, `seed`, `turn`, `playerHp`, `playerMaxHp`,
`playerAttack`, `playerDefence`, `enemyHp`, `enemyMaxHp`, `telegraph`,
`playerFrostGuard` (v7, `:289`). Explicit `null` when no fight is on —
never an absent key (`:198-200`).

### 4.5 Activity state

`ActivityQueueState`, encoded `save_codec.dart:262-271`, keys:
`node`, `requested`, `completed`, `durationMillis`, `anchorEpochMillis`.
Explicit `null` when no queue runs. Class `game_state.dart:339`.
This is `RULES.md` P-4's one named exception (wall-clock anchored).

### 4.6 Progression state

`ProgressState`, encoded `save_codec.dart:211-260`, decoded `:1146`. Keys:
`enemyVictories`, `acceptedContracts`, `bountyProgress`,
`contractCompletions`, `localSlots`, `localNext`, `projects`
(`{id, stage, contributed}`), `completedProjects`, `revealedRumors`,
`tracked` (`{journey, pursuit, contract}`). Class `game_state.dart:519`;
`TrackedGoals` `:426`; `ProjectProgressState` `:481`.

### 4.7 World / atlas discovery state

**The only persisted world-discovery field is `world.unlockedLocations`** — a
sorted set of location `ContentId`s (`save_codec.dart:183-185`,
`game_state.dart:231`), plus `world.currentLocation` (`:230`).

`world.visitVictories` (`game_state.dart:247`) is per-visit, **emptied by
every move** (`movingTo`, `game_state.dart:~325`), and is not a discovery
record.

The atlas itself — `assets/content/v1/atlas/atlas_layout.json`
(`lib/runtime/atlas_layout.dart:37`) — is **authored content, not save
state**. Atlas ambient creature overlays are pure clock projections:
`visibleAt(Duration)` / `frameIndexAt(Duration)` at
`lib/runtime/atlas_layout.dart:319-338` derive everything from elapsed time
with no stored cursor. **No creature state is persisted anywhere.**

### 4.8 Settings

**Nothing.** A grep for `volume|haptic|mute|settings|prefs|preference` across
`packages/stride_core/lib/` finds no such field in the save model — only
prose (`save_repository.dart:29`, `events.dart:19`). Settings live in the
sidecar (§6).

---

## 5. Visible equipment — can it be a pure projection?

## **Yes. Definitively. And the projection already exists, already ships, and is already tested.**

### 5.1 The fields that already carry it

Everything a renderer needs is already persisted:

| Need | Already-persisted source | Reference |
|---|---|---|
| What is worn, per slot | `GameState.equipment.bySlot` → JSON `equipment` | `save_codec.dart:174-179` |
| Which slots exist | `EquipmentSlot {weapon, armor, tool}` | `definitions.dart:85` |
| Item identity | `ContentId` value string | `save_codec.dart:178` |
| Tier / tool kind / rarity / power | **content**, resolved from the id at read time | `ItemDefinition` in `definitions.dart` |

The item id is the whole key. Tier, tool kind, rarity and power are **content
lookups from a reloadable registry**, never stored in the save — a deliberate
rule stated at `game_state.dart:100-106` ("state is the thin, serializable,
long-lived half; content is the fat, reloadable half"). This is exactly why
an art round can change what an item looks like without touching a byte of
any save.

### 5.2 The projection, as built

`StrideSession.equipmentVisualState` —
`lib/runtime/stride_session.dart:4258-4280`:

```dart
EquippedVisualFact? factFor(EquipmentSlot slot) {
  final ContentId? worn = active.state.equipment.bySlot[slot];   // :4265
  if (worn == null) return null;
  final ItemDefinition? def = content.items[worn];               // :4267
  return EquippedVisualFact(
    itemId: worn.value, tier: def?.tier ?? 0,
    toolKind: (def?.toolKind ?? ToolKind.none).name,
  );
}
```

- `EquippedVisualFact` — `lib/runtime/stride_session.dart:311`
- `EquipmentVisualState` — `lib/runtime/stride_session.dart:336`
- `EquippedSummary` (the Character-screen list) —
  `lib/runtime/stride_session.dart:284`, built `:4231-4246`

Its own doc comment (`:4248-4257`) records the design: read on demand,
**holding nothing** (`RULES.md` E-2), and carrying **facts, not art keys**,
so an art round changes no session code.

### 5.3 The resolver seam, shipped inert

`lib/ui/icons/traveler_art.dart` — `TravelerArt`, `:45`. Three tables, all
currently empty by design:

- `variantOfItem` (item id → coarse variant class) — `:61`
- `combatVariants` (weapon class → `CombatantArt`) — `:69`
- `walkWestVariants` (armor class → 6-frame walk) — `:73`

Resolution is total, base-strip-floored: `combatantFor` (`:80-82`),
`walkWestFor` (`:86-88`). The header (`:26-31`) states the intended landing
path: **a PixelLab gear round packages strips through `package-art.js` and
adds rows to the two tables — no rendering-surface code changes.**

Consumers already wired: `lib/ui/screens/combat/combat_stage.dart:86,93`;
`lib/ui/screens/world/travel_transition.dart:50,71`.

### 5.4 The proof

`test/equipment_visual_test.dart`:

- `:42` — "the projection derives from the engine's own equipped state"
- `:64` — "changing equipment changes the value; an unchanged loadout is equal"
- `:77` — "the resolver is total, and inert while the tables are empty"
- `:108-121` — **"reading the projection commits nothing"** — reads
  `equipmentVisualState` three times and asserts `equipment.bySlot` is
  byte-identical afterwards.

### 5.5 Verdict

Visible equipment for VAWO01 is **art packaging plus two table rows**. It
touches:

- `TravelerArt.variantOfItem` / `.combatVariants` / `.walkWestVariants`
- new PNG strips under `assets/art/v1/…` via `Scripts/art/package-art.js`

It touches **zero** persisted state, **zero** codec code, and **zero**
migration machinery.

**The one caveat, already recorded upstream, not a save concern:** the first
weapon round *must* include an **unarmed** set, because the current baked art
draws a generic sword even with an empty weapon slot (`traveler_art.dart:66-68`).
That is an art-completeness obligation, not a persistence one.

---

## 6. Audio and accessibility settings — exact keys

### 6.1 What persists

Model `lib/audio/audio_settings.dart`; store
`lib/audio/audio_settings_store.dart`. File
`<application support>/audio_settings.json` (`audio_settings_store.dart:32`).

| JSON key | Field decl | Type | Default | Default const |
|---|---|---|---|---|
| `enabled` | `audio_settings.dart:36` | bool | `true` | inline `:18` |
| `musicVolume` | `:38` | double | `0.55` | `defaultMusicVolume` `:30` |
| `sfxVolume` | `:39` | double | `0.9` | `defaultSfxVolume` `:31` |
| `ambienceVolume` | `:40` | double | `0.7` | `defaultAmbienceVolume` `:32` |
| `hapticsEnabled` | `:46` | bool | `true` | inline `:22` |

- `toJson` — `audio_settings.dart:62-68`
- `fromJson` — `:74-82`, **tolerant**: a missing or malformed field takes its
  default and never throws
- Volumes clamped `0.0–1.0` — `_clamp` `:87`, `_readVolume` `:84-85`
- `load()` — `audio_settings_store.dart:39-50` (corrupt → `const AudioSettings()`)
- `save()` — `:56-64` (`.tmp` + `flush:true` + `rename`; failures swallowed)
- Debounced write — `AudioController._scheduleSave`
  `lib/audio/audio_controller.dart:433-441`, `_saveDebounce = 400ms` at `:62`;
  flushed in `dispose()` `:483-487`
- Setters: `setEnabled` `:278-300`, `setMusicVolume` `:302-310`,
  `setSfxVolume` `:312-316`, `setHapticsEnabled` `:318-323`
- Haptic gate: `_admitHaptic` `lib/audio/audio_controller.dart:368`
- UI: `lib/ui/screens/character/audio_block.dart` (Character tab,
  "Sound & feel"; vibration toggle `:96-107`)

Notes:
- There is **no separate master-volume key**. `enabled` is the master switch
  and the only mute concept (`audio_settings.dart:34-36`).
- `ambienceVolume` persists but has **no UI control** yet
  (`audio_settings.dart:12-15`, `audio_block.dart:5-7`) — a free slot VAWO01's
  new ambience work can use with no format change.
- **Not versioned.** No `version` / `schemaVersion` field. Compatibility comes
  from tolerant per-field decode; unknown keys are ignored, missing keys take
  defaults. Asserted at `test/audio/audio_controller_test.dart:363-378`.

### 6.2 What does NOT persist

**Accessibility preferences are not persisted at all.** They are read live
from the OS every build:

- Reduce motion — `MediaQuery.disableAnimationsOf(context)`, the project-wide
  convention. Call sites include
  `lib/ui/screens/world/travel_transition.dart:73`,
  `lib/ui/components/ambient_stage.dart:608`,
  `lib/ui/components/ambient_player.dart:255`,
  `lib/ui/screens/world/atlas/atlas_viewport.dart:277`,
  `lib/ui/screens/world/atlas/atlas_layers.dart:1531`,
  `lib/ui/screens/adventure/encounter_card.dart:484`,
  `lib/ui/screens/craft/craft_screen.dart:152`,
  `lib/ui/components/reward_layer.dart:65`,
  `lib/ui/components/reward_beat.dart:324`,
  `lib/ui/components/screen_header.dart:165`,
  `lib/ui/screens/adventure/board_card.dart:618` and `:1220`,
  `lib/ui/screens/skills/skills_screen.dart:201`,
  `lib/ui/components/activity_result.dart:344`
- Text size — `MediaQuery.textScalerOf(context)`, e.g.
  `lib/ui/components/adaptive_text.dart:112`,
  `lib/ui/components/data_display.dart:147`
- High contrast, colour-blind mode: **do not exist in the codebase**
- Theme / skin preference: **not persisted anywhere**. `strideTheme()` is a
  static constructor with no persisted input (`lib/ui/stride_app.dart:189`,
  `lib/ui/theme/stride_theme.dart`). `lib/ui/components/panel_skin.dart` is a
  visual-variant enum, not a stored preference.

`shared_preferences` is **not a dependency** (absent from `pubspec.yaml` and
`pubspec.lock`). There is no `NSUserDefaults` / `SharedPreferences` layer in
this project at all.

### 6.3 Guardrails on any new settings work

Adding a platform preferences API would trip existing CI guards:

- `Scripts/check-origin-privacy.sh:187` — bans
  `UserDefaults|NSUserDefaults|SharedPreferences|getSharedPreferences|preferencesDataStore|androidx\.datastore|openFileOutput|FileManager\.default\.createFile|SecItemAdd|SecItemCopyMatching`
  in scanned native sources
- `test/s01a_ios_readiness_test.dart:209` — shipping Swift sources must
  contain no `UserDefaults` / `NSUserDefaults` / `FileManager` / `SecItemAdd`
  / `writeToFile`
- `test/ambient_player_test.dart:382` — `'SharedPreferences'` is among strings
  forbidden in ambient presentation files

**The sanctioned pattern for new preferences is another JSON sidecar in the
application support directory, following `AudioSettingsStore`.**

---

## 7. Health / step accounting — ABSOLUTELY OFF LIMITS

Every field below is inside `GameState.steps` and therefore inside the same
bytes as the save. **Nothing in VAWO01 has any reason to read, write, reshape
or re-encode any of it.**

Canonical type files:
`packages/stride_core/lib/src/steps/step_ledger.dart` (ledger types),
`sync_batch.dart` (slice / cursor / batch types),
`step_origin_key.dart` (origin key + salt fingerprint),
`completeness.dart` (completeness assertions),
`reconciliation.dart` (the reconciler).

### 7.1 The ledger's persisted fields

Encoder: `encodeStepLedger` — `packages/stride_core/lib/src/save/save_codec.dart:319-371`.
Decoder: `_decodeLedger` — `save_codec.dart:1256-1399`.
Class: `StepLedger` — `packages/stride_core/lib/src/steps/step_ledger.dart:350-586`.
Envelope path: `state.steps` (`save_codec.dart:197`).

| JSON key | Dart field | Encode | Decode | Decl |
|---|---|---|---|---|
| `totalObserved` | `StepLedger.totalObserved` | `save_codec.dart:320` | `:1367` | `step_ledger.dart:417` |
| **`totalGranted`** | `StepLedger.totalGranted` | `:321` | `:1368` | `step_ledger.dart:420` |
| `totalSpent` | `StepLedger.totalSpent` | `:322` | `:1369` | `step_ledger.dart:423` |
| `grantedBeforeWatermark` | `StepLedger.grantedBeforeWatermark` | `:340` | `:1372` | `step_ledger.dart:434` |
| `correctionsObserved` | `StepLedger.correctionsObserved` | `:341` | `:1373` | `step_ledger.dart:442` |
| `unreachableGapEvents` | `StepLedger.unreachableGapEvents` | `:342` | `:1374` | `step_ledger.dart:445` |
| `lateDiscardedSlices` | `StepLedger.lateDiscardedSlices` | `:343` | `:1375` | `step_ledger.dart:451` |
| `sourceState` | `StepLedger.sourceState` (enum **name**) | `:344` | `:1376-1380` | `step_ledger.dart:438` |
| **`grantedSlices`** | `StepLedger.grantedSlices` | `:370` / `_encodeSlices :376-396` | `:1297-1321` | `step_ledger.dart:429` |

`SourceState` is written as `.name` (`save_codec.dart:344`, read back by
`_enumByName` at `:1401-1406`), so its **member names are the wire format**:
`unknown, available, permissionUnavailable, serviceUnavailable,
transientlyUnavailable, originKeyingUnconfigured` — `step_ledger.dart:10-36`.
**Renaming a member breaks every existing save.**

In-type invariants live in the `StepLedger` constructor body,
`step_ledger.dart:367-397`: totals non-negative (`:367`),
`totalSpent <= totalGranted` (`:370`), `epoch.grantedAtStart <= totalGranted`
(`:379`), `epoch.spentAtStart <= totalSpent` (`:385`),
`spentThisEpoch <= grantedThisEpoch` (`:391`). `spending` refuses rather than
clamps (`:534-537`).

### 7.2 Economy epoch — `steps.epoch`

Encoded `save_codec.dart:334-339`. Class `EconomyEpoch` —
`packages/stride_core/lib/src/steps/step_ledger.dart:227`.

| JSON key | Dart | Encode | Decode | Decl |
|---|---|---|---|---|
| `establishedAtStateVersion` (v3) | `EconomyEpoch.establishedAtStateVersion` | `:335` | `:1348-1351`, `:1357-1360` | `step_ledger.dart:265` |
| `grantedAtStart` (v2) | `EconomyEpoch.grantedAtStart` | `:336` | `:1329`, `:1346`, `:1355` | `step_ledger.dart:253` |
| `spentAtStart` (v2) | `EconomyEpoch.spentAtStart` | `:337` | `:1330`, `:1347`, `:1357` | `step_ledger.dart:256` |
| **`walkedAtStart`** (v9) | `EconomyEpoch.walkedAtStart` | `:338` | `:1361` | `step_ledger.dart:276` |

Version dispatch: `enum _EpochShape { absent, marksOnly,
withEstablishedVersion, withWalkedBaseline }` — `save_codec.dart:890-902`.
v1 → origin; a v2 non-origin mark decodes as `establishedAtStateVersion: 2`
(`save_codec.dart:1339-1341`); a v8 absent `walkedAtStart` means 0.

`EconomyEpoch.origin()` = `(0, 0, 0, 0)` — `step_ledger.dart:246-250`;
`isOrigin` `:280-284`; asserts `:233-243` (marks non-negative,
`walkedAtStart <= grantedAtStart`).

Derived, never stored: `retiredSteps` (`step_ledger.dart:295`),
`grantedThisEpoch` (`:457`), `spentThisEpoch` (`:460`),
`walkedSinceBaseline` (`:465`), `banked` (`:477`),
`grantedAheadOfObserved` (`:483`). Retired totals appear in events only:
`EconomyEpochEstablished.newlyRetiredSteps` (`events.dart:425-427`),
`PlaytestReset.retiredBanked` (`events.dart:111-113`).

### 7.3 Sync checkpoint — cursor and watermarks

Encoded `save_codec.dart:345-362`. Class `SyncCheckpoint` —
`packages/stride_core/lib/src/steps/step_ledger.dart:105-164`.

| JSON key | Dart | Encode | Decode | Decl |
|---|---|---|---|---|
| **`cursor`** (base64 of `cursor.bytes`, or `null`) | `SyncCheckpoint.cursor` | `save_codec.dart:346-348` | `:1268-1276` | `step_ledger.dart:120` |
| **`watermarkMillis`** (nullable) | `SyncCheckpoint.watermarkMillis` | `:349` | `:1384` | `step_ledger.dart:129` |
| **`originWatermarks`** (list of `{o,w}`, **omitted when empty**) | `SyncCheckpoint.originWatermarks` | `:355-360` | `:1278-1295` | `step_ledger.dart:140` |
| `syncCount` | `SyncCheckpoint.syncCount` | `:361` | `:1385` | `step_ledger.dart:143` |

Two load-bearing subtleties:

- `originWatermarks` is **conditionally omitted when empty** so pre-per-origin
  saves stay byte-identical — the frozen v1 fixture depends on that
  (`save_codec.dart:350-354`; decoder tolerates absence at `:1280`).
  **Do not make this key unconditional.**
- **`watermarkMillis` is diagnostic only.** Settlement is decided *per origin*:
  `StepLedger.isSettled` — `step_ledger.dart:493-498`. The scalar is
  deliberately excluded from that decision.

Cursor ordering (H-3): `StepCheckpointAuthorized` is **always the last event of
a reconcile batch** — emitted `game_engine.dart:1163-1169`, applied
`event_reducer.dart:126-137`, and that reducer branch explicitly carries
`originWatermarks` forward (`event_reducer.dart:131-133`); dropping them would
unsettle every origin. `SyncCursor` is an opaque `Uint8List`, copied on
construct and on read — `sync_batch.dart:154-181`.

### 7.4 Recovery — `steps.recovery`

Encoded `save_codec.dart:363-369`: `phase`, `windowStartMillis`,
`windowEndMillis`, `truncated`, `attempts`. Class `RecoveryState` —
`step_ledger.dart:54-75`.

### 7.4b Source accounting and origin attribution

**There is no per-source cumulative total field.** Attribution exists *only*
through `grantedSlices` keyed by `(origin, bucket)` and through
`checkpoint.originWatermarks`. `totalGranted` and `grantedBeforeWatermark`
are deliberately origin-independent
(`packages/stride_health/lib/src/origin_pseudonymizer.dart:143-144`).

- Origin key type: `StepOriginKey` —
  `packages/stride_core/lib/src/steps/step_origin_key.dart:93-156`. Value is
  **16 lowercase hex characters, or the reserved literal `unknown`**
  (`:112`, `:118`; `validate` `:127-138`). No separator character is
  representable — that is what makes the structural slice encoding safe.
- The key appears as JSON `"o"` in `grantedSlices` (`save_codec.dart:390`),
  in `checkpoint.originWatermarks` (`:359`), and in the journal event
  `StepObservationReconciled` (`event_codec.dart:198`, `:209`).
- **`originSaltFingerprint`** is envelope-level, a **sibling of `state`**, and
  **omitted when null** — `save_codec.dart:516`, decoded `:575-577`. Computed
  by `OriginSaltPolicy.fingerprint` (`step_origin_key.dart:35-55`, FNV-1a over
  `"SALT" || salt`, 16 hex). **The salt itself is never in the save.**
  Fail-closed comparison: `SaveRepository._checkSalt`
  (`save_repository.dart:538-556`) → `LoadRefusal.originKeyReset`
  (`save_outcomes.dart:120`) → `BootstrapBlockReason.originIdentityMismatch`
  (`bootstrap.dart:1046`).
- Phone/watch dedup is HealthKit's, not hand-rolled:
  `options: [.cumulativeSum, .separateBySource]` at
  `packages/stride_health/ios/stride_health/Sources/stride_health/HealthKitStepStore.swift:642`;
  sources deduped by `bundleIdentifier` (`:668-672`), then every origin crossed
  with every kept bucket so a deleted bucket emits an explicit `steps: 0`
  (`:589-597`). Keying reads `HKSource.bundleIdentifier` only — never `.name`,
  `.model`, or `.localIdentifier` (`HealthKitAdapter.swift:21-33`, `:43-70`).
  Android counterpart: `.../kotlin/com/projectstride/stride_health/OriginKeying.kt:64-80`.
  Reference spec both natives must match byte-for-byte:
  `packages/stride_health/lib/src/origin_pseudonymizer.dart:40-99`,
  `originKeyingAlgorithmVersion = 1` at `:107`.

### 7.5 Replay protection / idempotency

| Mechanism | Where |
|---|---|
| `grantedSlices` keyed by `ObservationKey` = **structural** `{o, s, e, g}`, never a composite string | `save_codec.dart:373-396` |
| Why structural: a split key re-grants a window; a merged one under-grants a real second device | `save_codec.dart:10-15` |
| `ObservationKey.toString()` is **diagnostic-only and forbidden as a serialized form** | `sync_batch.dart:100-105` |
| `eventSequence` — monotonic event identity, mirrored at envelope level; reducer asserts the match | `save_codec.dart:166`, `:90-92`; `event_reducer.dart:67-71` |
| `lastAppliedTransaction` — journal transaction absorbed by the snapshot | `save_codec.dart:88` |
| `snapshotGeneration` — monotonic, selects the live slot | `save_codec.dart:85` |
| `originSaltFingerprint` — a changed salt re-keys every origin and would re-grant the whole retention window | `save_codec.dart:100-107` |
| `commitComplete` — written last within the payload | `save_codec.dart:94-99` |
| Journal line = `<crc32c-hex-8> <canonical-json>\n`, body `{f, saveId, tx, eventSeqBefore, eventSeqAfter, events}`; `tx` counts **commits, not events** | `journal_record.dart:31-84` |

**The actual idempotency mechanism is arithmetic, not a dedup key.** Slices
carry absolute figures, so `StepReconciler._apply`
(`reconciliation.dart:379-453`) resolves a replay by subtraction:
`delta == 0` → exact replay, nothing happens (`:431`); `delta < 0` →
downward correction, `corrections++`, granted untouched (`:424-430`); a
settled slice → `lateDiscarded++`, never granted (`:408-415`).

**Name asymmetry that must not be "tidied":** the save calls the slice list
`grantedSlices`; the journal event calls it **`slices`**
(`event_codec.dart:204`).

### 7.6 The invariants and where they are enforced

`SaveRepository`'s seven protocol invariants are stated at
`packages/stride_core/lib/src/save/save_repository.dart:12-30`:

> P1 a grant the engine accepted is never lost · P2 a batch is never granted
> twice · P3 retrying an old cursor is safe · **P4 the durable cursor never
> leads the durable granted state** · P5 snapshot corruption is recoverable
> from the journal · P6 replay is deterministic · P7 compaction cannot remove
> the only durable record of a grant

P4 holds **structurally**: `SyncCheckpoint.cursor` lives inside `StepLedger`
inside `GameState`, and the whole batch is one journal record — **the cursor
and the grant that authorised it are the same bytes**
(`save_repository.dart:21-26`).

> **"This is why a native adapter must never persist a cursor of its own. A
> cached anchor in `NSUserDefaults` or `SharedPreferences` decouples the two."**
> — `save_repository.dart:28-31`

**This sentence is the direct constraint on VAWO01's settings work.** A new
sidecar for presentation preferences is fine. A sidecar that caches anything
health-derived is not.

`RULES.md` invariants that govern this territory:

| Rule | `RULES.md` line | Text (abridged) |
|---|---|---|
| P-3 | `:40` | Real-world steps are the progression input |
| P-4 | `:44-45` | No wall-clock progression masquerading as walking; progression is step-clocked |
| P-5 | `:56` | Absence is never punished — nothing decays or expires; expressly unamended by the economy epochs (`:60-70`) |
| P-9 | `:89` | Goal tracking never reserves, escrows, or auto-spends steps |
| H-1 | `:110-113` | Observed, granted, spent and banked are four distinct concepts |
| H-2 | `:115-131` | Granted is monotonic; there is no clawback. Only a named migration step, `0019`, or the `0025` reset may move the epoch mark |
| H-3 | `:132-137` | A candidate cursor becomes durable only after safe reconciliation and save commit. **No adapter may cache, advance, or persist one** |
| H-4 | `:139` | A cursor may be offered only where the delivery contract permits it |
| H-5 | `:145` | Foreground health sync only |
| H-6 | `:151` | First-party native health adapters |
| H-7 | `:156-159` | Health data privacy is structural — **no source name, salt, origin-key byte or cursor content is ever logged, displayed, or persisted** |
| E-1 | `:166` | `stride_core` is pure Dart |
| E-2 | `:172-178` | UI must not become an alternate source of durable game state |
| E-3 | `:181-184` | Single-writer persistence |
| E-4 | `:188-191` | Under-settle rather than over-settle |
| G-4 | `:224` | Never weaken an invariant to make a test pass |

Supporting doc: `TECHNICAL/STEP_LEDGER_PRIVACY.md` — field-by-field
justification `:52-67`, `grantedSlices` `:91`, compaction-requires-an-assertion
`:124-128`, and the health-reset shape at `:185` (clear `checkpoint`,
`grantedSlices`, `recovery`, `sourceState`, `totalObserved`; **keep**
`totalGranted`, `totalSpent`, `grantedBeforeWatermark`).

### 7.7 Guards that will catch a violation

| Guard | Enforces |
|---|---|
| `Scripts/check-single-writer.sh` | E-3 — enumerates approved (file, symbol) pairs; everything else is rejected. Has a `--self-test` with five injections |
| `Scripts/check-step-model.sh` | One step-ingestion model. Named rules at `:453-745`, including `rule_single_ingest_entry_point`, `rule_settling_construction_sites` (`:643`), `rule_signature_allowed_files` (`:682`), `rule_no_signature_capture` (`:719`) |
| `Scripts/check-origin-privacy.sh` | H-7 — rules at `:325-635`, including `rule_no_native_durable_store`, `rule_no_platform_value_sink`, `rule_no_native_identity_minting`; the native-persistence-API ban is at `:187` |
| `Scripts/check-core-purity.sh` | E-1 — no Flutter, `dart:io`, clock, or randomness in `stride_core` |
| `Scripts/check-ui-boundary.sh` | E-2 |
| `Scripts/check-backup-exclusions.sh` | Save and salt excluded from device backup |
| `Scripts/check-ios-target.sh` | H-5 — foreground-only HealthKit |
| `Scripts/check-source-safety.sh` | A converted guard is inert when sourced (guard-of-guards) |

Adapter-level guards worth knowing, all in `packages/stride_health/`:
`cursor_authorization.dart:136-180` is the single, total, pure decision on
whether a candidate cursor may enter a `SyncResponse` (matrix documented
`:29-64`); `platform_step_source.dart:481-524` is **the only site in the
program that constructs `CompleteThrough` or `RecoveryCompleteThrough`**;
`origin_gateway.dart:70-139` validates origin decode and observation scope.

Bucket and retention constants that bound the slice map:
`TimeBucket.minimumWidthMillis` = 1 hour (`sync_batch.dart:44`, enforced
`reconciliation.dart:360-377` and `origin_gateway.dart:98`);
`defaultRetentionMillis` = 7 days (`reconciliation.dart:203`) with a hard
`minimumRetentionMillis` floor of 48 h (`:210`, enforced `:186-195`);
compaction folds aged slices into `grantedBeforeWatermark` via `_compact`
(`reconciliation.dart:465-512`).

### 7.8 The slice shape as it actually sits on disk

`_encodeSlices` sorts by origin, then `startMillis`, then `endMillis`
(`save_codec.dart:378-386`); `canonicalJson` then sorts the object keys
alphabetically, so each entry lands as **`e, g, o, s`**. From the frozen
fixture `packages/stride_core/test/fixtures/save/v9_baseline.save`:

```json
"grantedSlices":[{"e":1750007200000,"g":137,"o":"0f1e2d3c4b5a6978","s":1750003600000}, ...]
```

A malformed `"o"` throws reporting **length only, never the value**
(`save_codec.dart:1304-1310`) — H-7 applies to error messages too.

### 7.9 Two incidental observations (recorded, not actioned)

Neither is a VAWO01 concern; both are noted so a future reader does not
mistake them for defects introduced by this workstream.

1. `event_reducer.dart:103-111` — the `EconomyEpochEstablished` branch
   constructs `EconomyEpoch` without `walkedAtStart`, so it defaults to `0`
   and clears any prior walked baseline. That **matches the documented
   intent** (`step_ledger.dart:267-276`: "`0` for every epoch a migration or a
   new-game baseline sets"), but it is implicit rather than named. The only
   branch that sets `walkedAtStart` is `_playtestReset`
   (`event_reducer.dart:258`).
2. `save_codec.dart:1352` — a `case _EpochShape.withWalkedBaseline:` collapsed
   onto the preceding line inside the `switch`, plus a stray blank line at
   `:1363`. Cosmetic; the dispatch is correct. Worth knowing because that
   switch is the single point where epoch decoding diverges by version and is
   easy to misread.

---

## 8. Single-writer / CAS expectations

### 8.1 Three layers, none sufficient alone

1. **In-isolate future queue** — `SaveRepository._writer`,
   `save_repository.dart:~128`. Stops one isolate interleaving its own awaits.
   Per-instance, so it says nothing about a second instance.
2. **OS-level exclusive lock** — `TransactionLock` port,
   `packages/stride_core/lib/src/ports/transaction_lock.dart:66-72`;
   implementation `packages/stride_storage/lib/src/file_lock.dart`. Must be a
   **real** `RandomAccessFile.lock(FileLock.exclusive)` — never a sentinel
   file, whose existence check races and survives a process kill
   (`transaction_lock.dart:22-31`). Held across the **entire** transaction,
   not just the append (`save_repository.dart:103-109`).
3. **Compare-and-swap** — `CommitExpectation`,
   `save_repository.dart:52-67`: `{expectedSnapshotGeneration,
   expectedLastAppliedTransaction}`. Verified at `save_repository.dart:721-725`;
   bounded retry `maxCommitRetries = 3` (`:113-119`), exhaustion returns
   `CommitRefusal.conflictRetryLimitExhausted` (`:748-756`).

`UncontendedLock` (`transaction_lock.dart:81-87`) is **for in-memory tests
only** — the doc comment says using it on a real filesystem restores the
cross-instance race the port exists to close.

### 8.2 Commit order

`SaveRepository.commit` — `save_repository.dart:687-717`. Order, from
`:695-699`:

1. CAS against durable state
2. Append the journal record and wait for durability — **the commit point**
3. The caller may now publish, and only now release the cursor
4. Write the snapshot to the **older** slot, leaving the live one untouched
5. Compact, floored at the older of two verified slots

Reset-in-progress is refused before anything is written
(`save_repository.dart:731-742`).

### 8.3 The equal-generation divergence check

Two slots at the same generation are compared with
`canonicalDurableGameState` (`packages/stride_core/lib/src/save/durable_state.dart:59-60`)
— the exact bytes a save file carries, **complete by construction**. It
replaced a hand-written `GameState.signature` that omitted
`checkpoint.cursor` and `checkpoint.originWatermarks` and reduced granted
slices to a count; the omission let divergent slots compare equal and an
arbitrary one be chosen (`durable_state.dart:14-26`,
`game_state.dart:842-860`).

**Consequence for VAWO01:** any new field added to `GameState` joins this
comparison the moment it is persisted, with no second list to maintain — and
a `GameState` field that is *not* persisted fails the codec's own coverage
guard. There is no way to add durable state quietly.

### 8.4 What E-3 forbids

> "No background isolate, callback, worker, or platform entry point may
> instantiate `SaveRepository`, construct filesystem persistence stores, or
> touch the save directory directly."
> — `RULES.md:181-184`, `DECISIONS/0013`

The sidecar stores (§1.2) are compliant precisely because they write **beside**
the save directory, never inside it (`craft_memory.dart:5-12`).

---

## 9. Save-related tests, and how to run them

### 9.1 The suites

**`packages/stride_core/test/` (pure Dart, no Flutter, no emulator):**

| File | Covers |
|---|---|
| `save_migration_test.dart` | **The migration boundary.** Frozen fixtures, decode fidelity, per-version round trips, version-floor and future-version refusals. Groups: fixture intact `:369`; A decode `:410`; B v1 `:443`; B2 v2 `:496`; B3 v3 `:545`; B4 v4 `:595`; B5 v5 `:675`; B6 v6 `:739`; B7 v7 `:796`; B8 v8 repair `:844`; C below floor `:1046`; D from the future `:1116`; B9 v9 `:1147` |
| `save_protocol_test.dart` | Canonical encoding `:17`; commit & slot selection `:105`; **compare-and-swap `:209`**; origin salt `:344`; origin watermarks survive a reload `:440`; salt fingerprint survives a real commit `:521` |
| `save_corruption_test.dart` | Truncation, digest failure, torn tails |
| `save_fault_matrix_test.dart` | Systematic fault injection across the protocol |
| `save_privacy_test.dart` / `save_diagnostics_privacy_test.dart` | H-7 — what may and may not appear in a signature or diagnosis |
| `equal_generation_divergence_test.dart` | §8.3 |
| `broken_fixtures_test.dart` | Malformed artifact handling |
| `phase2_migration_bootstrap_test.dart` | The bootstrap migration path |
| `transformation_epoch_test.dart` | **Group 0 asserts migration-table contiguity** — the test that fails if `StateVersion.current` moves without a step |
| `economy_epoch_cutover_test.dart` | `DECISIONS/0016` |
| `playtest_reset_test.dart` | `DECISIONS/0025` |
| `step_ledger_invariants_test.dart` | H-1/H-2: banked = granted − spent `:33`; spent never exceeds granted `:52`; idempotence `:229`; state safety `:264`; bounded retention `:323` |
| `migration_support.dart`, `save_support.dart` | Shared harnesses |

Frozen fixtures: `packages/stride_core/test/fixtures/save/v1_baseline.save`
… `v9_baseline.save`. **Never regenerated** — the policy is stated in the
header of `save_migration_test.dart:20-28`: regenerating deletes the only
evidence of a save written by a build that no longer exists.

Generators (run once per version, then frozen):
`packages/stride_core/tool/generate_v2_baseline.dart` …
`generate_v9_baseline.dart`.

**`packages/stride_storage/test/`:** `concurrency_test.dart`,
`conformance_filesystem_test.dart`, `restart_integration_test.dart`,
`linux_lock_semantics_test.dart`, `closure_probes_test.dart`,
`critic_probes_test.dart`.

**Root `test/` (Flutter):** `equipment_visual_test.dart` (§5.4),
`test/audio/audio_controller_test.dart` (settings persistence, tolerant
decode `:363-378`), `new_game_baseline_test.dart`,
`deferred_epoch_session_test.dart`, `playtest_reset_session_test.dart`,
`startup_sync_test.dart`, `s01a_vertical_slice_test.dart`,
`per_write_exclusion_diagnostic_test.dart`.

### 9.2 Commands

Toolchain note: Flutter and the JDK are not on PATH on this machine; export
both first.

```bash
# The save/persistence core — fastest, no Flutter, no emulator
cd packages/stride_core && dart pub get && dart analyze --fatal-infos && dart test

# Just the migration boundary
cd packages/stride_core && dart test test/save_migration_test.dart

# The protocol, CAS, corruption
cd packages/stride_core && dart test test/save_protocol_test.dart test/save_corruption_test.dart test/save_fault_matrix_test.dart

# Real filesystem, real locks -- serialized on purpose
cd packages/stride_storage && dart pub get && dart analyze --fatal-infos && dart test -j 1

# App-layer projections and settings
flutter test test/equipment_visual_test.dart test/audio/audio_controller_test.dart

# Everything, including the guards
./Scripts/verify.sh            # skips absent toolchains
./Scripts/verify.sh --strict   # CI mode; fails on an absent toolchain
```

`Scripts/verify.sh` step references: core analyze+test `:217-218`; storage
`:220-227`; workspace analyze `:233`; Flutter tests `:236-237`; single-writer
guard `:178`; step-model guard `:186`; origin privacy `:197`.

Golden tests are **excluded from CI by design** (`dart_test.yaml` header) —
Flutter's text rasterization is not identical across platforms, so a Linux
runner's red build would report the renderer, not the change.

**Known state:** CI is currently RED on a pre-existing `craft_memory`
violation unrelated to this survey; local figures are the reliable ones.

---

## 10. VERDICT

### 10.1 Changes that require **NO** save migration

| Change | Why | Where it lands |
|---|---|---|
| **Visible equipment rendering** | Every input is already persisted (`equipment.bySlot`) or is a content lookup. The projection `StrideSession.equipmentVisualState` (`lib/runtime/stride_session.dart:4258-4280`) already exists, holds nothing, and is proven to commit nothing (`test/equipment_visual_test.dart:108-121`). The `TravelerArt` resolver seam (`lib/ui/icons/traveler_art.dart:45-88`) ships inert and is filled by adding table rows plus packaged art. | Two const tables + `Scripts/art/package-art.js` output. **Zero** save code. |
| **New audio settings** (ambience slider, new buses, per-cue toggles) | Settings are a separate unversioned sidecar `<support>/audio_settings.json` with a **tolerant per-field decoder** (`lib/audio/audio_settings.dart:74-82`). A new key is additive by construction: old files take the default, new files are ignored by an older build. `ambienceVolume` (`:40`) already persists with no UI attached. | `lib/audio/audio_settings.dart` + `audio_controller.dart` setters + `audio_block.dart`. |
| **New UI theme / skin preferences** | Nothing theme-related is persisted today. A new preference follows the sanctioned pattern: another JSON sidecar in application support, or a new key in `audio_settings.json` if it belongs to "Sound & feel". `panel_skin.dart` is an enum, not stored state. | Sidecar, or a new tolerant key. **Never** `SharedPreferences` — three CI guards ban it (§6.3). |
| **Gathering scene variants** | Purely presentational. The gathering activity's durable state is `activityQueue` = `{node, requested, completed, durationMillis, anchorEpochMillis}` (`save_codec.dart:262-271`). A scene variant is derived from `node` + content + the clock. | UI + art. |
| **World map creature life** | Atlas creature overlays are pure clock projections — `visibleAt(Duration)` / `frameIndexAt(Duration)` at `lib/runtime/atlas_layout.dart:319-338`. The atlas layout is authored content (`assets/content/v1/atlas/atlas_layout.json`, `atlas_layout.dart:37`), not save state. | `atlas_layout.json` + art. |
| **Reward / XP presentation** | The figures already persist (`player.level`, `player.experience`, `inventory`, `skills`, `progress.*`). Presentation reads them. The `ActivityResult` / `RewardBeat` / `RewardLayer` components already sit on a read-only session projection. | UI only. |

**All six of the owner's named VAWO01 changes are migration-free.**

### 10.2 Changes that **WOULD** require a migration

None is required by the workstream as scoped. Each of these is a trap to
avoid, listed so the implementation team can recognise one before it is built.

| Change | Why it forces `StateVersion.current` → 10 | Cost |
|---|---|---|
| **Persisting a chosen cosmetic / appearance / outfit override** distinct from the equipped item id | `PlayerState` is `{level, experience, hp}` (`game_state.dart:61-99`). A new field on `GameState` **must** be encoded — a `GameState` field the codec does not persist fails the codec's own coverage guard (`durable_state.dart:30-37`). | New decoder `V10StateDecoder`, new `generate_v10_baseline.dart`, new frozen `v10_baseline.save`, new step in `state_migrations.dart` with `rebasesEconomy: false`, new `save_migration_test.dart` group, and a contiguity assertion update. |
| **Persisting equipment appearance layers / variant ids in the save** | Same reason. It also duplicates content: variant class is derived from item id via `TravelerArt.variantOfItem` (`traveler_art.dart:61`), and a stored variant would carry a stale copy of it into the next content pack — exactly the failure `game_state.dart:100-106` forbids. | As above, **plus** a permanent content-drift liability. |
| **Persisting per-creature world-map state** (a discovered/seen set, spawn cursors, per-creature timers) | `WorldState` holds `{currentLocation, unlockedLocations, visitVictories}` (`game_state.dart:230-247`) and nothing else. A "seen creatures" set is a new durable collection. | As above. Note `visitVictories` is emptied by every move and is **not** a discovery record — do not repurpose it. |
| **Persisting gathering-scene variant selection** rather than deriving it | `ActivityQueueState` (`game_state.dart:339`) has five fields, all mechanical. A stored scene id is new durable state. | As above. |
| **Persisting reward-presentation history** (which rewards have been shown, first-time flags) | Not derivable from durable state — the journal compacts. But `CraftMemory` (`lib/ui/state/craft_memory.dart`) already established the correct answer for exactly this problem: a **presentation sidecar**, not the save. Follow it. | Migration if put in the save; **zero** if put in a sidecar. |
| **Any change to a step-ledger, checkpoint, or epoch field** (§7) | Would change the shape the frozen fixtures pin and would touch `RULES.md` H-1/H-2/H-3/H-7 territory. | Out of scope for VAWO01 under the owner's constraint. **Do not.** |

### 10.3 Rules that must be repeated to the implementation team

1. **A `GameState` field cannot be added quietly.** The codec's coverage guard
   and `canonicalDurableGameState` (`durable_state.dart:59-60`) make an
   unpersisted new field a test failure. If you find yourself adding a field
   to `GameState`, you are writing a migration — stop and escalate.
2. **The frozen fixtures are never regenerated** to make a suite green
   (`save_migration_test.dart:20-28`).
3. **No sidecar may cache anything health-derived** — especially not a cursor
   or an anchor (`save_repository.dart:28-31`, `RULES.md` H-3).
4. **No `SharedPreferences` / `NSUserDefaults`.** Three CI guards ban it
   (§6.3); the sanctioned pattern is a JSON sidecar beside the save directory.
5. **A presentation sidecar must never make a lifetime factual claim.** It can
   be lost to a reinstall, so a wrong emphasis is a shrug and a wrong sentence
   would be a lie — the reasoning is written out at
   `lib/ui/state/craft_memory.dart:14-22`.
6. **`RULES.md` A-1 applies to the gear art**: PixelLab makes the strips.
   Render base, never fake — no code-tinted blades, no icon pasted into a hand
   (`traveler_art.dart:23-25`).
7. **The first weapon variant round must ship an unarmed set** — the current
   baked art draws a generic sword even with an empty weapon slot
   (`traveler_art.dart:66-68`). Presentation debt, not save debt, but it
   becomes visible the moment gear art lands.
