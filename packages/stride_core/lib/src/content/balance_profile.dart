import 'package:meta/meta.dart';

import 'content_id.dart';
import 'json_reader.dart';

/// A numerical overlay on top of base content.
///
/// ## Base content plus profile
///
/// The content files define *what exists and how it connects*. A profile scales
/// *how long things take*. That split is what keeps the QA profile safe: it has
/// no vocabulary for adding an item, changing a reference, or rewiring the
/// progression graph, because those live in a layer it cannot reach.
///
/// A profile may change only the four multipliers below, and may not introduce
/// or rename anything. Enforced by [read], which rejects unknown fields, and by
/// the validator, which rejects a profile referencing content IDs.
///
/// See `DECISIONS/0007_PROGRESSION_PACING.md`.
@immutable
final class BalanceProfile {
  const BalanceProfile({
    required this.id,
    required this.displayName,
    required this.releaseSafe,
    required this.stepCostPercent,
    required this.xpPercent,
    required this.yieldPercent,
    required this.enemyHealthPercent,
  });

  final ContentId id;
  final String displayName;

  /// Whether this profile may ship.
  ///
  /// The mechanical safeguard against a release build defaulting to accelerated
  /// pacing. `production` is the only profile that sets it.
  final bool releaseSafe;

  /// Percentage applied to every step cost. 100 is unchanged; 10 makes
  /// everything ten times faster to reach.
  final int stepCostPercent;

  final int xpPercent;
  final int yieldPercent;
  final int enemyHealthPercent;

  /// The ID every release build must use.
  static final ContentId productionId = ContentId.unchecked(
    'profile.production',
  );

  /// The accelerated QA profile. Never ships.
  static final ContentId acceleratedQaId = ContentId.unchecked(
    'profile.accelerated_qa',
  );

  int applyStepCost(int base) => _scale(base, stepCostPercent, minimum: 1);
  int applyXp(int base) => _scale(base, xpPercent);
  int applyYield(int base) => _scale(base, yieldPercent, minimum: 1);
  int applyEnemyHealth(int base) =>
      _scale(base, enemyHealthPercent, minimum: 1);

  /// Integer-only scaling. Deterministic across every platform, which floating
  /// point would not be.
  static int _scale(int base, int percent, {int minimum = 0}) {
    final int scaled = (base * percent) ~/ 100;
    return scaled < minimum ? minimum : scaled;
  }

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'releaseSafe',
    'stepCostPercent',
    'xpPercent',
    'yieldPercent',
    'enemyHealthPercent',
  };

  static BalanceProfile? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final BalanceProfile profile = BalanceProfile(
      id: reader.requireId('id', ContentNamespace.profile),
      displayName: reader.requireString('displayName'),
      releaseSafe: reader.optionalBool('releaseSafe'),
      stepCostPercent: reader.requireInt('stepCostPercent', min: 1, max: 10000),
      xpPercent: reader.requireInt('xpPercent', min: 1, max: 10000),
      yieldPercent: reader.requireInt('yieldPercent', min: 1, max: 10000),
      enemyHealthPercent: reader.requireInt(
        'enemyHealthPercent',
        min: 1,
        max: 10000,
      ),
    );
    return reader.isComplete ? profile : null;
  }
}

/// Guards against shipping accelerated pacing.
///
/// ## Why this is not just a comment
///
/// The accelerated profile makes the game roughly ten times faster. Shipping it
/// by accident would not crash, would not fail a test that did not look for it,
/// and would quietly destroy the pacing the whole balance decision exists to
/// establish. It would most likely be noticed by a player wondering why level 20
/// took four days.
///
/// So the check is mechanical and runs at load: a release build asking for a
/// profile that is not [BalanceProfile.releaseSafe] throws.
final class ReleaseSafety {
  const ReleaseSafety._();

  /// True in a Dart/Flutter release build.
  ///
  /// `dart.vm.product` is set by the compiler, not by the app, so this cannot
  /// be forgotten or misconfigured in a build script.
  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Overrides [isReleaseBuild], for tests that need to simulate a release.
  static bool? _simulatedRelease;

  static bool get treatAsRelease => _simulatedRelease ?? isReleaseBuild;

  /// Test seam. Production code never calls this.
  static void simulateRelease(bool? value) => _simulatedRelease = value;

  /// Throws when a release build selects a profile that must not ship.
  static void assertSelectable(BalanceProfile profile) {
    if (treatAsRelease && !profile.releaseSafe) {
      throw StateError(
        'Refusing to load balance profile "${profile.id}" in a release build.\n'
        'It is not marked releaseSafe, which means it changes pacing for QA and '
        'must never reach a player.\n'
        'Fix: load "${BalanceProfile.productionId}" in release builds, or set '
        'releaseSafe on the profile if it is genuinely shippable.',
      );
    }
  }
}
