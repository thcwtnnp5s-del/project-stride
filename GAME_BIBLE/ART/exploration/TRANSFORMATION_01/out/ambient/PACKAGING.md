# out/ambient — PACKAGING

Source (this folder) → shipped path (proposed; the integration lead adds the emit lines in Scripts/art/package-art.js) → display size.
All frames are RGBA8 PNG, zero semi-transparent pixels, no contact shadow. Baseline = lowest opaque row (0-indexed): place every asset so its baseline sits on the shared ground row. Rest pose: Traveler scenes start from the south idle rotation (frame 0), except traveler_pushups_side (east idle).

| source | frames | shipped path | native | display | fps | loop | baseline |
|---|---|---|---|---|---|---|---|
| out/ambient/traveler_stretch_f{0..5}.png | 6 | assets/art/v1/ambient/traveler_stretch_f{i}.png | 80x80 | x2 (Adventure stage) | 6 | pingpong | 70 |
| out/ambient/traveler_drink_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_drink_f{i}.png | 64x64 | x2 (Adventure stage) | 8 | loop | 62 |
| out/ambient/traveler_eat_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_eat_f{i}.png | 64x64 | x2 (Adventure stage) | 8 | pingpong | 62 |
| out/ambient/traveler_pack_check_f{0..5}.png | 6 | assets/art/v1/ambient/traveler_pack_check_f{i}.png | 64x64 | x2 (Adventure stage) | 6 | pingpong | 62 |
| out/ambient/traveler_axe_inspect_f{0..6}.png | 7 | assets/art/v1/ambient/traveler_axe_inspect_f{i}.png | 64x64 | x2 (Adventure stage) | 6 | pingpong | 62 |
| out/ambient/traveler_pick_inspect_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_pick_inspect_f{i}.png | 80x80 | x2 (Adventure stage) | 7 | loop | 70 |
| out/ambient/traveler_head_scratch_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_head_scratch_f{i}.png | 64x64 | x2 (Adventure stage) | 8 | loop | 62 |
| out/ambient/traveler_wipe_brow_f{0..6}.png | 7 | assets/art/v1/ambient/traveler_wipe_brow_f{i}.png | 64x64 | x2 (Adventure stage) | 7 | loop | 62 |
| out/ambient/traveler_sit_ground_f{0..10}.png | 11 | assets/art/v1/ambient/traveler_sit_ground_f{i}.png | 64x64 | x2 (Adventure stage) | 6 | pingpong | 62 |
| out/ambient/traveler_pushups_side_f{0..10}.png | 11 | assets/art/v1/ambient/traveler_pushups_side_f{i}.png | 80x80 | x2 (Adventure stage) | 6 | pingpong | 70 |
| out/ambient/traveler_dangle_string_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_dangle_string_f{i}.png | 64x64 | x2 (Adventure stage) | 7 | pingpong | 62 |
| out/ambient/traveler_read_f{0..8}.png | 9 | assets/art/v1/ambient/traveler_read_f{i}.png | 64x64 | x2 (Adventure stage) | 6 | pingpong | 62 |
| out/ambient/traveler_crouch_pet_f{0..10}.png | 11 | assets/art/v1/ambient/traveler_crouch_pet_f{i}.png | 64x64 | x2 (Adventure stage) | 7 | loop | 63 |
| out/ambient/pair_pet_cat_f{0..10}.png | 11 | assets/art/v1/ambient/pair_pet_cat_f{i}.png | 96x64 | x2 (Adventure stage) | 7 | loop | 62 |
| out/ambient/cat_stand_f{0..0}.png | 1 | assets/art/v1/ambient/cat_stand_f{i}.png | 40x40 | x2 (Adventure stage) | 0 | static | 27 |
| out/ambient/cat_walk_f{0..5}.png | 6 | assets/art/v1/ambient/cat_walk_f{i}.png | 40x40 | x2 (Adventure stage) | 8 | loop | 27 |
| out/ambient/cat_walk_west_f{0..5}.png | 6 | assets/art/v1/ambient/cat_walk_west_f{i}.png | 40x40 | x2 (Adventure stage) | 8 | loop | 27 |
| out/ambient/cat_sit_down_f{0..7}.png | 8 | assets/art/v1/ambient/cat_sit_down_f{i}.png | 40x40 | x2 (Adventure stage) | 6 | pingpong | 27 |
| out/ambient/cat_settle_f{0..6}.png | 7 | assets/art/v1/ambient/cat_settle_f{i}.png | 40x40 | x2 (Adventure stage) | 5 | pingpong | 27 |
| out/ambient/cat_lie_rest_f{0..3}.png | 4 | assets/art/v1/ambient/cat_lie_rest_f{i}.png | 40x40 | x2 (Adventure stage) | 3 | loop | 27 |
| out/ambient/cat_roll_f{0..8}.png | 9 | assets/art/v1/ambient/cat_roll_f{i}.png | 40x40 | x2 (Adventure stage) | 7 | pingpong | 27 |
| out/ambient/cat_bat_yarn_f{0..7}.png | 8 | assets/art/v1/ambient/cat_bat_yarn_f{i}.png | 40x40 | x2 (Adventure stage) | 8 | loop | 27 |
| out/ambient/cat_stretch_f{0..6}.png | 7 | assets/art/v1/ambient/cat_stretch_f{i}.png | 40x40 | x2 (Adventure stage) | 6 | pingpong | 27 |
| out/ambient/prop_fire_f{0..3}.png | 4 | assets/art/v1/ambient/prop_fire_f{i}.png | 32x32 | x2 (Adventure stage) | 6 | loop | 28 |
| out/ambient/prop_yarn_f{0..0}.png | 1 | assets/art/v1/ambient/prop_yarn_f{i}.png | 16x16 | x2 (Adventure stage) | 0 | static | 12 |

`manifest.json` in this folder is the playback contract for stream D: `{id, frames, fps, loop (loop|pingpong|static), canvas (n, or [w,h]), baseline, note?}`.

Canvas note: Traveler scenes are 64x64 with the figure at the same anchor as the shipped sprite/traveler_south.png (feet row 62). Three scenes (stretch, pick_inspect, pushups_side) needed 80x80 because a limb or tool leaves the 64 box; they are the same 88-px source cropped 8 px further out on every side, so centring the 80 canvas on the same point as the 64 canvas (offset -8,-8) puts the figure in exactly the same place (feet row 70 = 62+8). pair_pet_cat is a single 96x64 sprite (Traveler at x32..95, feet row 62). Cat assets are all 40x40, feet row 27; a cat placed with baseline 27 on the Traveler baseline row is knee-height. prop_fire is 32x32 baseline 28; prop_yarn is 16x16 baseline 12.

Joint scenes are meant to be composited at runtime: traveler_dangle_string + cat_bat_yarn (cat under the string end, viewer-left), traveler_crouch_pet + cat_sit_down f7 held (cat under the hand, viewer-left), traveler_sit_ground + cat_lie_rest / cat_settle, prop_fire beside traveler_sit_ground. See qa/ambient_context_x2.png.
