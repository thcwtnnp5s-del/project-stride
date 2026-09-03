# EPO03 — ITEMS ledger (PROD-ITEMS)

Cap **200 generations**. Brief `MILESTONES/evidence/EPO03/wave1/DIR-09_item_art.md`.
Method: fetch → x2 sheet beside collision partners on `#1e1e1e` → Read by eye →
verdict. The IoU metric is triage; the sheet read is the verdict (M-04).

Every row's tool is `create_image_pixen` 48x48, `no_background`,
PIXELLAB_STYLE_SPEC_01 §7.2 clause verbatim, **cost 1** each, unless stated.

## Batch 1 — 13 regenerations × 3 rolls = 39 generations

Submitted by the previous PROD-ITEMS instance before the session-limit outage;
job ids recovered from `E/raw/items/fetch_*.txt` and the candidates were already
downloaded, so **nothing in this batch was re-rolled**.

### Group 1 — the four brown vests (DIR-09 #1)

| Asset | Job id | Verdict | Reason (read at x2 on `#1e1e1e`) |
|---|---|---|---|
| `wolfhide_jerkin` s1101 | 709cb286-6313-4969-93f8-3c000a5b398e | REJECT | cream/tan shaggy body — collides with `tuskbound_jerkin`'s tan |
| `wolfhide_jerkin` s1102 | d1d517e9-0a05-4cb1-bcf1-625e53a23651 | **ACCEPT** | silver-grey shaggy fur mass, orange lacing, wide irregular fur outline. The only candidate that is actually grey, which is the differentiator DIR-09 named |
| `wolfhide_jerkin` s1103 | ea249e2b-a153-4365-9013-bf77cadfd1e1 | REJECT | pale cream, too light and too near s1101 |
| `tuskbound_jerkin` s1201 | f838e6cb-17ae-4f38-bd68-1d08e20c3bf5 | REJECT | tusks sit low and small; the tell is back under 6 px |
| `tuskbound_jerkin` s1202 | 2ed80a3f-6cac-4f03-bcef-a8de06926a38 | REJECT | tusks form an X but only at the collar — reads as stitching |
| `tuskbound_jerkin` s1203 | 80e2fd50-f082-4bc8-ac5f-4a38342ea599 | **ACCEPT** | warm tan, two big white tusks crossing the full chest; legible at x2 and unmistakable |
| `frostlined_jerkin` s1301 | 93e34018-f04a-4769-a542-fd9925ab88ac | REJECT | brown with white fur — this IS the wolfhide collision, restated |
| `frostlined_jerkin` s1302 | 7aaee5d8-ea52-4bfd-b2e5-2218296b192e | **ACCEPT** | smooth sleeveless blue-grey tank, pale trim. Chosen over s1303 for the silhouette: narrow and smooth against wolfhide's wide shaggy outline, so the pair separates in greyscale, not only in hue |
| `frostlined_jerkin` s1303 | 35404b95-0471-416a-b40b-7e32f6cba50a | REJECT | blue-grey with a cream fur ruff — matches the DIR-09 colour note but the pale ruff re-collides with the wolfhide silhouette |
| `bearhide_coat` s1401 | 6d156470-90ee-442f-b9a5-1da9e54da0d1 | REJECT | grey-brown; not the near-black the group needs |
| `bearhide_coat` s1402 | 0f6a444d-ac1d-4e1f-b86f-9a924256816e | REJECT | dusty rose/mauve with a gold buckle — off-family, and brighter than the vests it must sit under |
| `bearhide_coat` s1403 | adf563b1-5755-4f29-a9a6-eeb9e49ae2f8 | **ACCEPT** | near-black hooded coat, brown belt, hem well below the vest line — the two differentiators DIR-09 asked for, in one silhouette |

**Group 1 verdict: CLOSED.** Sheet `review/items/after_vests_x2.png`. Four vests,
four colour masses, two hem lengths, nameable unlabelled.

### Group 7 — the two coats that drew a person (DIR-09 #7)

| Asset | Job id | Verdict | Reason |
|---|---|---|---|
| `clawguard_coat` s1701 | 39208c9c-e5bc-4bc7-bae7-4d6406208019 | REJECT | garment-only and correct, but mid-brown with a hood collar — re-collides with `bearhide_coat` |
| `clawguard_coat` s1702 | 0394019f-d782-497d-82c6-8ac839a0c619 | REJECT | rust/orange, narrow; claws small |
| `clawguard_coat` s1703 | a7223d5e-0f3a-4cfd-80cc-a92549d6c0f8 | **ACCEPT** | dark brown coat, cream claw plates flaring off both shoulders, gold belt, no head. The claw spikes change the outline, which is what the shipped icon never had |
| `frostwarden_coat` s1801 | bf4b91fa-b018-446c-a946-b28d2f4e6dcf | **ACCEPT** | slim pale blue-white long coat, standing hood collar, belt. No hands, no legs, no face |
| `frostwarden_coat` s1802 | a6b6143d-a7a1-4eb9-9815-572f439a9690 | REJECT | reads as a boiler suit with legs — the person defect, restated |
| `frostwarden_coat` s1803 | 4fc93212-16c7-49e6-b018-1755b32405a2 | REJECT | purple and red chromatic fringing along the hem |

**Group 7 verdict: CLOSED.** No armour icon shows a face; nothing reads emissive.

### Group 2 — the five ivory curves (DIR-09 #2)

| Asset | Job id | Verdict | Reason |
|---|---|---|---|
| `great_tusk` s2101 | 59cffcf7-69a2-4b71-a788-1794a6fcfd6a | REJECT | pair is there but small — 24.9% fill, below the group's floor |
| `great_tusk` s2102 | e8305d92-c582-4a39-84cc-72b9fd29d0ac | **ACCEPT** | large symmetric bound pair, brown cord at the centre; 53.8% fill. Reads as two tusks, which is what separates it from `boar_tusk`'s one |
| `great_tusk` s2103 | 6318e338-8e9d-4ee0-a96b-de73bcff74dc | REJECT | horn mounted on a barrel — invents a prop the family does not have |
| `pristine_wolf_fang` s2201 | 6176fca8-b849-4916-a746-4a09a99b16f2 | REJECT | 14.5% fill, dark cord; nearly invisible on the tile |
| `pristine_wolf_fang` s2202 | 02027ac8-0e98-41fd-b0c0-63220c88ce03 | HOLD | correct read (tooth on a cord loop, no longer a tusk) but 17.3% fill — under the 20% floor criterion 5 sets. Re-rolled in batch 2 |
| `pristine_wolf_fang` s2203 | 4b511bd4-f1f4-4b97-84a4-b66503df6aa8 | HOLD | tooth on a V necklace, 19.4%; the cord strands are thin and dark and drop out |
| `pristine_horn` s2301 | 148cab64-55de-4f87-b2d3-163fa450f879 | REJECT | correct drawing, but a stray light-grey cast shadow runs diagonally behind it |
| `pristine_horn` s2302 | 25bab217-bbe3-4e1d-a2e3-2c9df9f67f0c | **ACCEPT** | ridged spiral corner to corner on a brass ferrule, clean alpha; 22.0% fill against the shipped 12% |
| `pristine_horn` s2303 | f4fc7716-b09b-4499-a8a3-d40723df77ab | REJECT | maroon ferrule, 20.1% — dimmer and thinner than s2302 |

**Group 2 verdict: OPEN** on `pristine_wolf_fang` only; tusk and horn closed.

### Group 3 — the two dark stews (DIR-09 #3)

| Asset | Job id | Verdict | Reason |
|---|---|---|---|
| `hearty_stew` s3101 | 4e6f8d02-a478-4343-ba6c-8f93dace7a3b | **ACCEPT** | pale wooden bowl, heaped orange-brown, wooden ladle standing in it. Leaves the dark iron pot to `expedition_stew`, so the pair stops going dark-on-dark |
| `hearty_stew` s3102 | 30784418-546a-43d3-a92e-ad93a4958e7f | REJECT | dark maroon vessel with oversized steam blobs — reads as a cauldron, i.e. as `expedition_stew` |
| `hearty_stew` s3103 | 98ad3c4e-9d00-4688-89e2-34a27c9de91a | REJECT | golden dumplings read as a different dish, not as stew |

**Group 3 verdict: CLOSED** for the collision. Steam is absent from both stews;
carried as debt, not softened.

### Group 5 — the epic longsword (DIR-09 #5)

| Asset | Job id | Verdict | Reason |
|---|---|---|---|
| `bronze_longsword` s5101 | 2eb31b7b-a942-410e-9485-09bc3531a884 | **ACCEPT** | corner-to-corner warm bronze blade, wide guard, long grip, round pommel; 23.8% fill against the shipped 12%. Now the largest blade in the game, which is the family rule the shipped icon broke |
| `bronze_longsword` s5102 | 27cbc9e9-b46f-4216-a9ec-a2aafd9980e9 | REJECT | thinner and duller; 20.4% barely clears the floor |
| `bronze_longsword` s5103 | fea0891d-d380-4e59-aa03-09a08de21886 | REJECT | reads gold, not bronze — the exact defect `49c91f9` ("bronze is not gold") already settled |

**Group 5 verdict: CLOSED.**

### Group 6 — the two bronze pick heads (DIR-09 #6)

| Asset | Job id | Verdict | Reason |
|---|---|---|---|
| `hornpoint_pickaxe` s6201 | 0b09a550-0b98-4803-935e-e1064dfa92ae | **ACCEPT** | big pale bone pick, two curved points, wooden haft; 38.2% fill against the shipped 17%. No bronze tool can be confused with it |
| `hornpoint_pickaxe` s6202 | 5aab4e1e-2a1f-4c62-bcea-c965bf62bb41 | REJECT | dull bone, stray grey line beside the beak |
| `hornpoint_pickaxe` s6203 | 44231854-eea3-4b38-aa61-3b8641bb88d8 | REJECT | pale knob head reads as a mallet, not a pick |
| `reinforced_pickaxe` s6101 | efcaf69a-806c-4b06-9d1a-44b232f734f6 | REJECT | flat double wedge on a vertical haft — reads as a hammer; loses the pickaxe |
| `reinforced_pickaxe` s6102 | 33085341-7507-4d74-ba0c-318c44622d0d | REJECT | purple collar, off-palette; gold horns read as tusks |
| `reinforced_pickaxe` s6103 | 337c2e8d-d541-4a1d-b5e0-d3666b2f8439 | REJECT | grey spiked star — reads as a mace |

All three `reinforced_pickaxe` rolls lose the tool's identity to gain the strap.
The shipped icon is the better pickaxe; the cheap route is to add the grey
steel strap and rivets to it by edit rather than replace it. Batch 2.

**Group 6 verdict: half CLOSED** (`hornpoint_pickaxe`); `reinforced_pickaxe` open.

**Batch 1 cost: 39 generations** (13 assets × 3 rolls, `create_image_pixen`, 1 each).
Accepted 11, rejected 26, held 2. Running total **39 / 200**.
