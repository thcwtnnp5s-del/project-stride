/// "No revert to base clothes", as code (FMPO02, `ART-05_equipment_brief.md`
/// §5.3).
///
/// The owner's device found Inventory showing the Bronze Chestplate while
/// Adventure, the mine, the grove and the fight showed the shirt. This test
/// walks every equippable armour × every weapon × every tool the content pack
/// has and asserts that **every** context the Traveler is drawn in resolves
/// to art of the armour's own body class. A tool tier may degrade (a bronze
/// head on a training pick is a smaller lie than the shirt); the body never.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/ambient_scene.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/traveler_art.dart';

EquippedVisualFact _fact(String id) =>
    EquippedVisualFact(itemId: id, tier: 1, toolKind: 'none');

/// The body token every packaged strip of that class carries in its path.
String _token(String bodyClass) => switch (bodyClass) {
  'armor.plate' => 'traveler_plate',
  'armor.jerkin' => 'traveler_jerkin',
  'armor.coat' => 'traveler_coat',
  'armor.warden' => 'traveler_warden',
  _ => 'base',
};

void main() {
  final List<String> armours = <String>[
    for (final MapEntry<String, String> e in TravelerArt.variantOfItem.entries)
      if (e.value.startsWith('armor.')) e.key,
  ];
  final List<String?> weapons = <String?>[
    null,
    for (final MapEntry<String, String> e in TravelerArt.variantOfItem.entries)
      if (e.value.startsWith('weapon.')) e.key,
  ];
  final List<String?> tools = <String?>[
    null,
    for (final MapEntry<String, String> e in TravelerArt.variantOfItem.entries)
      if (e.value.startsWith('tool.')) e.key,
  ];

  test('every equippable item in the content pack has an authored class', () {
    // EPO03, DIR-08 failure 3. `waywarden_tunic` drew the white shirt in all
    // ten contexts for a whole round, and nothing failed: an item with no row
    // resolves to the base body by construction, so "not yet authored" and
    // "deliberately the base figure" were the same silence. This closes that
    // as code — the table must answer for every `category: equipment` id the
    // content pack ships, and an item that arrives without a decision fails
    // here rather than quietly wearing the starting clothes.
    //
    // Read from `items.json` itself, not from a hand-kept list, because a
    // second list is exactly what drifts.
    final Map<String, dynamic> pack =
        jsonDecode(File('assets/content/v1/items.json').readAsStringSync())
            as Map<String, dynamic>;
    final List<String> equippable = <String>[
      for (final dynamic e in pack['entries'] as List<dynamic>)
        if ((e as Map<String, dynamic>)['category'] == 'equipment')
          e['id'] as String,
    ];
    expect(equippable.length, greaterThanOrEqualTo(23));
    for (final String id in equippable) {
      expect(
        TravelerArt.variantOfItem.containsKey(id),
        isTrue,
        reason:
            '$id is equippable and has no authored variant class, so it '
            'draws the base figure without anyone having decided that',
      );
    }
  });

  test('every loadout can brace', () {
    // EPO03, DIR-08 failure 4. `CombatantArt.brace` is nullable and the
    // choreography holds the idle when it is missing, so the one loadout
    // without a brace track — base body + training sword, which is what every
    // new player fights in — showed no braced figure at all when the player
    // pressed Brace. Nothing failed, because nothing asked.
    for (final String? weapon in weapons) {
      for (final String? armour in <String?>[null, ...armours]) {
        final EquipmentVisualState v = EquipmentVisualState(
          armor: armour == null ? null : _fact(armour),
          weapon: weapon == null ? null : _fact(weapon),
        );
        expect(
          TravelerArt.combatantFor(v).brace,
          isNotNull,
          reason:
              '${armour ?? 'no armour'} + ${weapon ?? 'nothing'} cannot '
              'brace',
        );
      }
    }
  });

  test('every armour fights, rests, walks and works in its own class', () {
    expect(armours, isNotEmpty);
    for (final String armour in armours) {
      final String body = TravelerArt.variantOfItem[armour]!;
      final String token = _token(body);

      for (final String? weapon in weapons) {
        final EquipmentVisualState v = EquipmentVisualState(
          armor: _fact(armour),
          weapon: weapon == null ? null : _fact(weapon),
        );
        final String idle = TravelerArt.combatantFor(v).idle.frame(0);
        expect(
          idle,
          contains(token),
          reason: '$armour + ${weapon ?? 'nothing'} fights as $idle',
        );
        // And the weapon the set holds is the weapon class equipped.
        final String held = TravelerArt.weaponClassOf(v).split('.').last;
        expect(idle, contains('_${held}_'), reason: '$armour holds $held');
      }

      final EquipmentVisualState bare = EquipmentVisualState(
        armor: _fact(armour),
      );
      expect(
        TravelerArt.figureFor(bare),
        isNot(contains('traveler_south.png')),
      );
      expect(TravelerArt.walkWestFor(bare).first, contains(token));
      expect(TravelerArt.restFrameFor(bare), contains(token));
      final AmbientSceneSet idles = TravelerArt.idleScenesFor(
        bare,
        base: AmbientAssets.scenes,
      );
      expect(idles.scenes, isNotEmpty);
      for (final AmbientScene s in idles.scenes) {
        final String f = s.traveler.frames.first;
        expect(
          f.contains(token) || !f.contains('traveler_'),
          isTrue,
          reason: '$armour idles in ${s.id} drawn from $f',
        );
      }

      for (final String? tool in tools) {
        final EquipmentVisualState v = EquipmentVisualState(
          armor: _fact(armour),
          tool: tool == null ? null : _fact(tool),
        );
        for (final String skill in <String>[
          'skill.mining',
          'skill.woodcutting',
          'skill.foraging',
        ]) {
          final GatherStrip? strip = TravelerArt.gatherStripFor(skill, v);
          expect(
            strip,
            isNotNull,
            reason:
                '$armour + ${tool ?? 'no tool'} at $skill falls to the base loop',
          );
          expect(
            strip!.frames.first,
            contains(token),
            reason: '$armour works $skill as ${strip.frames.first}',
          );
        }
      }
    }
  });

  test('every armour smiths and cooks in its own class', () {
    // FINAL-03 blocker 1: Craft drew the base body while every other stage
    // wore the armour. The craft loop has no tool axis (the hammer and the
    // spoon are the station's), so the body alone must resolve it.
    for (final String armour in armours) {
      final String token = _token(TravelerArt.variantOfItem[armour]!);
      final EquipmentVisualState v = EquipmentVisualState(armor: _fact(armour));
      for (final String skill in <String>['skill.smithing', 'skill.cooking']) {
        final GatherStrip? loop = TravelerArt.craftLoopFor(skill, v);
        expect(loop, isNotNull, reason: '$armour at $skill falls to the base');
        expect(loop!.frames.first, contains(token));
        // Ping-pong: 7 down, 5 back, the strike at the turn — the base
        // loop's own shape, so the cue lands on the same contact.
        expect(loop.frames.length, AmbientAssets.activityLoopFor(skill).length);
        expect(loop.strikeFrame, AmbientAssets.strikeFrameFor(skill));
        expect(loop.canvasWidth, AmbientAssets.activityCanvasFor(skill));
      }
    }
    expect(
      TravelerArt.craftLoopFor('skill.smithing', EquipmentVisualState.none),
      isNull,
    );
  });

  test('the base body with a bronze tool holds a bronze tool', () {
    for (final (String skill, String tool) in <(String, String)>[
      ('skill.mining', 'item.bronze_pickaxe'),
      ('skill.woodcutting', 'item.bronze_axe'),
    ]) {
      final GatherStrip? strip = TravelerArt.gatherStripFor(
        skill,
        EquipmentVisualState(tool: _fact(tool)),
      );
      expect(strip, isNotNull, reason: '$tool on the base body');
      expect(strip!.frames.first, contains('bronze'));
    }
  });

  test('an empty loadout is the base everywhere, unchanged', () {
    const EquipmentVisualState none = EquipmentVisualState.none;
    expect(TravelerArt.figureFor(none), endsWith('traveler_south.png'));
    expect(TravelerArt.restFrameFor(none), isNull);
    expect(TravelerArt.walkWestFor(none), TravelerArt.travelerWalkWestFrames);
    expect(TravelerArt.gatherStripFor('skill.mining', none), isNull);
    expect(TravelerArt.gatherStripFor('skill.foraging', none), isNull);
    expect(
      TravelerArt.idleScenesFor(none, base: AmbientAssets.scenes),
      same(AmbientAssets.scenes),
    );
  });
}
