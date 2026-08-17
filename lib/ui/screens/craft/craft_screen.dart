/// The Craft screen — every recipe, and the truth about each one.
///
/// ## The rule this screen is built around
///
/// **A disabled recipe must say why it is disabled.** A grid of grey cards is a
/// wall; a grid of grey cards each saying "needs Smithing 4" or "2 more Copper
/// Ore" is a plan. The player walks toward the second one.
///
/// So every recipe in the content pack is listed, not only the craftable ones.
/// Hiding the rest would answer "what can I do now" and never "what am I
/// working towards", and the second question is what makes a walk feel aimed.
///
/// ## Crafting costs no steps
///
/// `GAME_BIBLE/SYSTEMS/04` — the steps were already spent gathering, and
/// charging again would make this screen a toll booth in front of a reward the
/// player has already walked for. The consequence is worth knowing while reading
/// this file: **this is the one screen whose primary action still works at a
/// zero balance**, which is the game's answer to a week nobody could walk
/// (`Q-01`).
///
/// No figure here is computed from a `RecipeDefinition`. `RecipeOption` carries
/// profile-scaled values from `StrideSession`, and the engine re-validates
/// everything on tap (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';
import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class CraftScreen extends StatelessWidget {
  const CraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final StrideSession session = controller.session;
    final List<RecipeOption> recipes = session.recipeOptions;
    final int ready = recipes.where((RecipeOption r) => r.canCraft).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (session.isStale) ...<Widget>[
          StaleBanner(busy: controller.busy, onReload: controller.reload),
          SizedBox(height: StrideSpace.cardGap),
        ],
        _ReadyLine(ready: ready, total: recipes.length),
        SizedBox(height: StrideSpace.cardGap),
        if (recipes.isEmpty)
          const SectionCard(
            child: AdaptiveText(
              'This content pack defines no recipes.',
              style: StrideType.body,
            ),
          ),
        for (final RecipeOption recipe in recipes) ...<Widget>[
          _RecipeCard(recipe: recipe),
          SizedBox(height: StrideSpace.cardGap),
        ],
      ],
    );
  }
}

class _ReadyLine extends StatelessWidget {
  const _ReadyLine({required this.ready, required this.total});

  final int ready;
  final int total;

  @override
  Widget build(BuildContext context) => AdaptiveText(
    ready == 0
        ? 'Nothing can be made yet — $total recipes known'
        : '$ready of $total can be made now',
    style: StrideType.sub,
    color: ready == 0 ? StrideColors.textMuted : StrideColors.textSecondary,
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);

    return SectionCard(
      padding: EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Identity(recipe: recipe),
          SizedBox(height: StrideSpace.s10),
          _SkillGate(recipe: recipe),
          SizedBox(height: StrideSpace.s10),
          _Ingredients(recipe: recipe),
          SizedBox(height: StrideSpace.s12),
          _CraftControl(recipe: recipe),
          if (controller.lastCraftRecipe == recipe.id &&
              controller.lastCraft != null) ...<Widget>[
            SizedBox(height: StrideSpace.s8),
            _CraftResult(report: controller.lastCraft!),
          ],
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      // The output's own art, so the card is identified by the thing it makes
      // rather than by a generic anvil. `itemFor` never returns null — it falls
      // back to a deliberately non-representational slab.
      InsetWell.square(
        contentSize: 48,
        child: PixelAsset.item(PixelIcons.itemFor(recipe.outputItem)),
      ),
      SizedBox(width: StrideSpace.s10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AdaptiveText(recipe.displayName, style: StrideType.cardTitle),
            // The output line only when it says something the title does not.
            //
            // Nearly every recipe is named after what it makes, so the obvious
            // "Makes {output}" subtitle rendered as *Herb Broth · Makes Herb
            // Broth* — a line of pure repetition under every card, which is
            // noise dressed as information. It earns its place when the batch
            // is larger than one, or when a recipe is ever named differently
            // from its output.
            if (recipe.outputQuantity != 1 ||
                recipe.outputName != recipe.displayName) ...<Widget>[
              SizedBox(height: StrideSpace.s2),
              AdaptiveText(
                recipe.outputQuantity == 1
                    ? 'Makes ${recipe.outputName}'
                    : 'Makes ${recipe.outputQuantity} × ${recipe.outputName}',
                style: StrideType.sub,
                color: StrideColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SkillGate extends StatelessWidget {
  const _SkillGate({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      RequirementGate(label: '${recipe.skillName} ${recipe.requiredLevel}'),
      SizedBox(width: StrideSpace.s8),
      Flexible(
        child: AdaptiveText(
          recipe.skillMet
              ? '+${recipe.experience} XP'
              // The gap, not just the requirement. "You are level 2" is the
              // information that turns a wall into a distance.
              : 'You are ${recipe.skillName} ${recipe.currentLevel}',
          style: StrideType.micro,
          color: recipe.skillMet
              ? StrideColors.textMuted
              : StrideColors.textSecondary,
        ),
      ),
    ],
  );
}

class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (final RecipeIngredientLine line in recipe.ingredients)
        Padding(
          padding: EdgeInsets.only(bottom: StrideSpace.s4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  line.displayName,
                  style: StrideType.sub,
                  color: line.satisfied
                      ? StrideColors.textSecondary
                      : StrideColors.textMuted,
                ),
              ),
              SizedBox(width: StrideSpace.s8),
              // Held over required, always both. Showing only the shortfall
              // would hide how close the player is, and showing only the
              // requirement would hide whether they have any at all.
              AdaptiveText(
                '${line.held} / ${line.required}',
                style: StrideType.itemCount,
                color: line.satisfied
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ],
          ),
        ),
    ],
  );
}

class _CraftControl extends StatelessWidget {
  const _CraftControl({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.read(context);
    final SessionController watched = SessionScope.of(context);
    final bool enabled =
        recipe.canCraft && !watched.busy && watched.session.isReady;

    return StrideButton(
      label: watched.busy ? 'Crafting…' : 'Craft',
      subLabel: _reason(recipe),
      onPressed: enabled ? () => controller.craft(recipe.id) : null,
    );
  }

  /// The one sentence that explains a disabled button.
  ///
  /// The skill gate is named **before** the ingredients, matching the engine's
  /// own refusal order and for the same reason: telling a player they are two
  /// ingots short, when the real answer is that they need four more levels,
  /// sends them mining for a wall they will still hit.
  static String? _reason(RecipeOption recipe) {
    if (!recipe.skillMet) {
      return 'Needs ${recipe.skillName} ${recipe.requiredLevel}';
    }
    final List<RecipeIngredientLine> short = recipe.ingredients
        .where((RecipeIngredientLine i) => !i.satisfied)
        .toList();
    if (short.isEmpty) return null;
    // Every shortfall, not the first. Discovering a second requirement only
    // after satisfying the first is what makes a craft screen feel evasive.
    return 'Needs ${short.map((RecipeIngredientLine i) => '${i.shortfall} more ${i.displayName}').join(', ')}';
  }
}

class _CraftResult extends StatelessWidget {
  const _CraftResult({required this.report});

  final CraftReport report;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: AdaptiveText(
      report.succeeded
          ? 'Made ${report.quantity} × ${report.outputName}  ·  '
                '+${report.experience} ${report.skillName}'
          : _refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  /// Refusals are keyed on the stable wire code, never on the explanation
  /// string — the code is the contract and the sentence is free to change.
  static String _refusalText(CraftReport report) => switch (report.rejection) {
    'insufficient_ingredients' => 'Not enough materials.',
    'skill_level_too_low' => 'Your skill is not high enough yet.',
    'unknown_recipe' => 'That recipe is not in this content pack.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before crafting again.',
    _ => 'That could not be crafted.',
  };
}
