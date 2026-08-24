# Production audio, v1 — AUDIO_PRESENTATION_01

Every file here is a **deterministic technical packaging** of an
owner-accepted generation — gain, trim/fade, and format conversion only,
never a creative alteration. The evaluation originals, their listening
copies, and full per-candidate provenance JSONs (prompt, seed, settings,
request/generation IDs, sha256, credit costs, owner rulings) are preserved
untouched under:

- `AUDIO/evaluation/audio_presentation_01/` (this workstream)
- `AUDIO/evaluation/stable_audio_bakeoff_00/` (the Haven/Frostmere anchors)

Asset IDs, sources, licences and verbatim prompts are canonical in
`AUDIO/AUDIO_ASSET_MANIFEST.md`. Runtime code resolves sounds only through
`lib/audio/audio_cues.dart` asset IDs — nothing references these filenames.

All sources are Stability AI **Stable Audio** generations (stable-audio-3
for music, stable-audio-2.5 for SFX) under Stability's licence for the
account's paid credit tier, generated 2026-08-23/24.

## Music (`music/`, AAC 192 kbps m4a, 150 s each)

Mastering: one uniform **−1.5 dB** gain across all five (they measured a
matched −14.0 LUFS integrated as generated; the uniform gain preserves that
match at −15.5 LUFS and puts every true peak at or under −1.0 dBTP after
AAC encoding).

| File | Accepted source (raw WAV) |
|---|---|
| `music_haven_01.m4a` | `stable_audio_bakeoff_00/round3/raw/HAVEN_R3_PIANO_A2A_3101.wav` |
| `music_whispering_woods_01.m4a` | `audio_presentation_01/music/raw/WOODS_AP1_SA3_5101.wav` |
| `music_stonefall_mine_01.m4a` | `audio_presentation_01/music/raw/STONEFALL_AP1_SA3_5201.wav` — plus a 2 s technical fade-out at 148 s: its generated tail ended ≈−28 dB RMS and would have wrapped abruptly under looping (documented at generation; owner ruled the note stays technical, not a regeneration) |
| `music_frostmere_01.m4a` | `stable_audio_bakeoff_00/round3/raw/FROSTMERE_R3_PIANO_A2A_3201.wav` |
| `music_forgotten_hollow_01.m4a` | `audio_presentation_01/music/raw/HOLLOW_AP1_SA3_5301.wav` |

## SFX (`sfx/`, WAV 44.1 kHz 16-bit stereo — transient clarity, zero decode cost)

Mastering: per-file gain to exactly **−1.0 dBTP** (the raws leave the
provider peak-normalized, mostly *above* full scale).

| File | Accepted source | Packaging |
|---|---|---|
| `sfx_gather_mining_01.wav` | `MINING_AP1_SA25_4102.wav` | −3.1 dB |
| `sfx_gather_woodcutting_01.wav` | `WOOD_AP1_SA25_4203.wav` | −1.2 dB |
| `sfx_gather_foraging_01.wav` | `FORAGE_AP1_SA25_4301.wav` | −4.2 dB; trimmed 2.0 s → 1.6 s with a 120 ms fade — the gesture completes at ≈1.3 s and the rest was silence floor |
| `sfx_craft_smithing_01.wav` | `SMITH_AP1_SA25_4401.wav` | +0.4 dB (the one source generated with headroom already) |
| `sfx_craft_cooking_01.wav` | `COOK_AP1_SA25_4503.wav` | −5.3 dB |

## Budget

≈19 MB total (17.9 music + 1.1 SFX) against the 30 MB provisional audio
budget (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4).
