// Regenerates broken fixtures from production content with a single mutation.
//
// Minimal by construction: a fixture that restates its whole production file
// cannot cascade into unrelated reference errors, and cannot drift out of sync
// with the content it is meant to break.

const fs = require('fs');

const CONTENT = 'assets/content/v1/';
const OUT = 'packages/stride_core/test/fixtures/';

const load = (f) => JSON.parse(fs.readFileSync(CONTENT + f, 'utf8'));
const write = (name, data) =>
  fs.writeFileSync(OUT + name, JSON.stringify(data, null, 2) + '\n');
const find = (bundle, id) => bundle.entries.find((e) => e.id === id);

// --- resource_nodes: unknown skill reference ------------------------------
{
  const b = load('resource_nodes.json');
  find(b, 'resource_node.oak_stand').skill = 'skill.lumberjacking';
  write('unknown_skill_reference.json', b);
}

// --- recipes: unknown item reference --------------------------------------
{
  const b = load('recipes.json');
  find(b, 'recipe.bronze_sword').ingredients[0].item = 'item.bronze_ingots';
  write('unknown_item_reference.json', b);
}

// --- recipes: missing required ingredient field ---------------------------
{
  const b = load('recipes.json');
  delete find(b, 'recipe.oak_handle').ingredients[0].item;
  write('missing_ingredient_reference.json', b);
}

// --- recipes: prohibited self-reference ------------------------------------
{
  const b = load('recipes.json');
  find(b, 'recipe.bronze_ingot').ingredients.push({
    item: 'item.bronze_ingot',
    quantity: 1,
  });
  write('prohibited_self_reference.json', b);
}

// --- locations: self connection --------------------------------------------
{
  const b = load('locations.json');
  find(b, 'location.havens_rest').connections.push({
    to: 'location.havens_rest',
    stepCost: 100,
  });
  write('self_connected_location.json', b);
}

// --- enemies: unknown location reference ------------------------------------
{
  const b = load('enemies.json');
  find(b, 'enemy.forest_wolf').location = 'location.whispering_wood';
  write('unknown_location_reference.json', b);
}

// --- enemies: missing required field ----------------------------------------
{
  const b = load('enemies.json');
  delete find(b, 'enemy.forest_wolf').health;
  write('missing_required_field.json', b);
}

// --- enemies: invalid numerical range ---------------------------------------
{
  const b = load('enemies.json');
  const wolf = find(b, 'enemy.forest_wolf');
  wolf.health = 0;
  wolf.drops[0].chancePercent = 250;
  write('invalid_numerical_range.json', b);
}

// --- skills: duplicate ID ----------------------------------------------------
{
  const b = load('skills.json');
  const dup = JSON.parse(JSON.stringify(b.entries[0]));
  dup.displayName = 'Woodcutting (duplicate)';
  b.entries.push(dup);
  write('duplicate_id.json', b);
}

// --- skills: broken XP curve -------------------------------------------------
{
  const b = load('skills.json');
  const skill = find(b, 'skill.woodcutting');
  skill.xpThresholds = [...skill.xpThresholds];
  skill.xpThresholds[5] = skill.xpThresholds[4]; // plateau: level 6 == level 5
  write('broken_xp_curve.json', b);
}

// --- items: unknown field ----------------------------------------------------
{
  const b = load('items.json');
  find(b, 'item.oak_log').stackible = true; // typo for "stackable"
  write('unknown_field.json', b);
}

// --- items: missing required rarity ------------------------------------------
{
  const b = load('items.json');
  delete find(b, 'item.oak_log').rarity;
  write('missing_rarity.json', b);
}

// --- items: unknown rarity value ---------------------------------------------
{
  const b = load('items.json');
  find(b, 'item.bronze_sword').rarity = 'mythic';
  write('unknown_rarity.json', b);
}

// --- enemies: encountersPerVisit below the minimum ---------------------------
{
  const b = load('enemies.json');
  // Zero would ship an enemy that appears at a location and can never be
  // fought there — a card with no fight behind it.
  find(b, 'enemy.forest_wolf').encountersPerVisit = 0;
  write('invalid_encounters_per_visit.json', b);
}

// --- items: production content using a QA-only value -------------------------
{
  const b = load('items.json');
  find(b, 'item.copper_ore').qaOnly = true;
  write('production_uses_qa_value.json', b);
}

// --- resource_nodes: unreachable tool bootstrap ------------------------------
{
  const b = load('resource_nodes.json');
  // Every axe good enough for oak is itself crafted from oak.
  find(b, 'resource_node.oak_stand').minimumToolTier = 1;
  write('unreachable_tool_bootstrap.json', b);
}

// --- profiles: QA marked release safe ----------------------------------------
{
  const b = load('profiles.json');
  find(b, 'profile.accelerated_qa').releaseSafe = true;
  write('qa_profile_marked_release_safe.json', b);
}

// --- standalone: whole-file failures -----------------------------------------
// These reject the entire file, so they are added alongside production content
// rather than replacing any of it.
write('unsupported_schema_version.json', {
  schemaVersion: 99,
  standalone: true,
  kind: 'items',
  entries: [
    {
      id: 'item.future_thing',
      displayName: 'Future Thing',
      category: 'material',
      rarity: 'common',
    },
  ],
});

write('malformed_schema_version.json', {
  standalone: true,
  kind: 'items',
  entries: [
    {
      id: 'item.undated_thing',
      displayName: 'Undated Thing',
      category: 'material',
      rarity: 'common',
    },
  ],
});

write('invalid_id_syntax.json', {
  schemaVersion: 1,
  standalone: true,
  kind: 'items',
  entries: [
    {
      id: 'Item.Bad_Thing',
      displayName: 'Bad Thing',
      category: 'material',
      rarity: 'common',
    },
  ],
});

console.log('regenerated fixtures');
