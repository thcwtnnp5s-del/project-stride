# VAWO01 — Weapon Round 01

**Date:** 2026-09-02
**Generations:** 3 (2 accepted, 1 rejected and re-rolled). Running VAWO01
total 200 of 10,000.
**Owner instruction served:** *"unequipped = no sword… The current baked
generic steel sword while unarmed is not acceptable for the final build"* and
*"if the all-track matrix is too large, solve the smallest coherent supported
set that eliminates the lie."*

---

## 1. The lie

Every shipped combat track bakes one generic pale-steel sword into the figure.
`TravelerArt.combatantFor` returned that set for **every** loadout, so a
Traveler who had equipped no weapon still fought with a blade he did not own —
the interface contradicting durable state.

## 2. What was authored

Two complete combatant sets, four tracks each, all PixelLab v3 on the canonical
Stride Traveler (`c82b7da5-…`, PIXELLAB_PROOF_01) — the same individual the
shipped sprite is a rotation of, so these are variants rather than lookalikes.

| Set | State | idle | attack | hit | stagger |
|---|---|---:|---:|---:|---:|
| unarmed | `bc5f632b-…` Guard Unarmed | 8 | 7 | 7 | 9 |
| bronze | `2108c61a-…` Guard Bronze Sword | 9 | 7 | 5 | 9 |

The unarmed idle is a *template* animation; the other seven strips are v3.
Template animations discard held props, which is why every weapon-bearing track
had to be v3 with the blade named explicitly in the prompt
(`EQUIPMENT_ROUND_RECORD_01.md`).

## 3. Coverage — why two sets is complete, not a compromise

The game has four weapons. They map without a gap:

| Item | Class | Art |
|---|---|---|
| *(nothing equipped)* | `weapon.unarmed` | authored, empty hands |
| `item.training_sword` | *(deliberately unmapped)* | the base set — whose baked blade **is** a plain steel training sword |
| `item.bronze_sword` | `weapon.bronze` | authored |
| `item.bronze_longsword` | `weapon.bronze` | authored |
| `item.fanghilt_sword` | `weapon.bronze` | authored |

So the owner's escape hatch was not needed: the smallest coherent set turned out
to cover every weapon in the game. `item.training_sword` has no row because the
base is already honest for it — an absence that is a decision, not a gap.

**An empty slot is a value, not a miss.** `combatantFor` returns the unarmed set
for `weapon == null` *before* consulting the class table. Only an *equipped*
item with no authored class falls through to the base, which keeps `RULES.md`
E-5 intact: a content pack that ships a weapon before its art still draws a
Traveler with a sword, never a hole.

## 4. Rejections

Three strips were rejected rather than shipped:

| Strip | Defect | Resolution |
|---|---|---|
| `vawo_bronze_hit_v3` (7f) | Sword gone at f6, green artifact | Re-rolled as `v3b` (5f), blade in all 5 |
| `vawo_bronze_stagger_v3` (9f) | Blade turns **serrated** across f6–f8 — the weapon becoming a different object mid-strip | Re-rolled as `v3b` with the sword held clear of the ground; clean tapered blade in all 9 |
| `vawo_bronze_idle` (template) | Came back bare-handed | Re-rolled as v3 |

## 5. Deterministic preparation (`RULES.md` A-2)

- **Crop.** v3 returns an 88 × 88 square. Every v3 frame is cropped to
  `(4, 12, 80, 64)`, putting the standing baseline on row 62 — the anchor row
  every shipped Traveler track already uses. Verified lossless: the union
  opaque box across all 44 v3 frames is x 9..77, y 12..75, wholly inside the
  window. The template `unarmed_idle` is native 80 × 64 standing on row 63 and
  declares its own anchor row; `CombatTrack` carries anchor per track, so the
  two coexist without the figure shifting.
- **Key.** `bronze_attack` f5 arrived with 136 px of detached artifact — a
  green tuft at knee height plus four specks — beside an 1147 px figure.
  Removed by flooding the component containing the standing foot and keying
  everything else to zero. Nothing was drawn: the bronze census over f3–f6
  reads 78 / 77 / 82 / 80, so the blade is untouched.

## 6. The guard that keeps it honest

`package-art.js` asserts **every variant frame is a single connected
component**. Across all 52 frames the blade is always joined to the hand, so a
frame arriving in two pieces is either a detached weapon or a floating
artifact — both the defect the owner named ("do not ship flickering/ghost
gear"). It is a ghost-gear check, not a style rule.

`test/combat_gear_variant_test.dart` holds five properties: every declared
frame exists; **no variant shares a frame with the sword-baked base set**;
every variant owns its own defeat on the base's beat; the blow lands inside the
attack; and the stage precaches the *resolved* set rather than the base —
without which the gear would decode late and visibly flicker in.

## 7. Why each variant needed its own defeat

The Traveler's defeat-as-retreat strip holds on a downed-but-alive pose the
camera lingers on (`RULES.md` P-7). Borrowing the base's would have handed the
steel blade back at exactly the moment the player looks hardest. Going without
one was worse still — the choreography's documented fallback holds the flinch,
which is a quiet downgrade in game feel for the most common loadouts. So both
sets were given their own nine-frame kneel on the base's tempo.

## 8. Device-size evidence

`review/equip/device/gear_matrix.png` — the same fight at 393 × 852 in three
loadouts (unarmed / training / bronze), at rest and mid-swing. Empty hands read
as empty hands; the pale steel and the warm bronze are distinguishable at 2×.
Rendered by `test/combat_gear_evidence_test.dart`, which is gated on
`COMBAT_EVIDENCE_DIR` and asserts nothing a golden would (`RULES.md` A-3: the
blind device read decides).

## 9. Tool visibility (P1) — verified, no work needed

The owner asked whether mining shows the correct pick family and woodcutting the
correct axe family. Rendered `review/equip/work_tools_x4.png`: `activity_woodcut`
swings a broad-bladed axe, `activity_mine` swings a two-point pickaxe, and
foraging kneels bare-handed. All three are correct. **No generations spent.**
