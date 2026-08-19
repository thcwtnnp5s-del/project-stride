// One deliberately invalid fixture per validation rule.
//
// A validator nobody has watched fail is a validator nobody knows works. Each
// test here breaks exactly one thing and asserts the specific error, so a rule
// that silently stops firing shows up immediately rather than at the moment it
// was needed.
//
// Each fixture replaces one production file and inherits the rest, so fixtures
// stay minimal and cannot drift out of sync with the real content.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

/// Loads a fixture over production content and asserts it fails.
ValidationReport expectRejected(String fixture) {
  final ContentLoadResult result = loadProduction(
    productionWithOverride(fixture),
  );
  expect(
    result.isValid,
    isFalse,
    reason: 'fixture "$fixture" should have been rejected but loaded cleanly',
  );
  return result.report;
}

/// Every error must be actionable: a file, an explanation, and a fix.
void expectActionable(ValidationReport report) {
  for (final ValidationError error in report.errors) {
    expect(error.sourceFile, isNotEmpty, reason: 'error names no file');
    expect(error.explanation, isNotEmpty, reason: 'error explains nothing');
    expect(
      error.suggestion,
      isNotEmpty,
      reason: 'error offers no fix: ${error.explanation}',
    );
  }
}

void main() {
  group('broken fixtures', () {
    test('duplicate ID', () {
      final ValidationReport report = expectRejected('duplicate_id.json');
      expect(
        reports(report, 'duplicate identifier'),
        isTrue,
        reason: report.format(),
      );
      expect(reports(report, 'globally unique'), isTrue);
      expectActionable(report);
    });

    test('invalid ID syntax', () {
      final ValidationReport report = expectRejected('invalid_id_syntax.json');
      expect(reports(report, 'lowercase'), isTrue, reason: report.format());
      expectActionable(report);
    });

    test('unknown item reference', () {
      final ValidationReport report = expectRejected(
        'unknown_item_reference.json',
      );
      expect(
        reports(report, 'item.bronze_ingots'),
        isTrue,
        reason: report.format(),
      );
      expect(reports(report, 'not defined'), isTrue);
      // The suggestion should name the item the author meant.
      expect(reports(report, 'did you mean "item.bronze_ingot"'), isTrue);
      expectActionable(report);
    });

    test('unknown skill reference', () {
      final ValidationReport report = expectRejected(
        'unknown_skill_reference.json',
      );
      expect(
        reports(report, 'skill.lumberjacking'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });

    test('unknown location reference', () {
      final ValidationReport report = expectRejected(
        'unknown_location_reference.json',
      );
      expect(
        reports(report, 'location.whispering_wood'),
        isTrue,
        reason: report.format(),
      );
      expect(
        reports(report, 'did you mean "location.whispering_woods"'),
        isTrue,
      );
      expectActionable(report);
    });

    test('missing recipe ingredient reference', () {
      final ValidationReport report = expectRejected(
        'missing_ingredient_reference.json',
      );
      // Asserting on the specific message, not merely on the word "item" —
      // a loose match would pass against an entirely different failure.
      expect(
        reports(report, 'the required field "item" is missing'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });

    test('unsupported schema version', () {
      final ValidationReport report = expectRejected(
        'unsupported_schema_version.json',
      );
      expect(
        reports(report, 'newer than this build understands'),
        isTrue,
        reason: report.format(),
      );
      // The loader must say it will not guess — silently dropping unknown
      // fields is the failure this rule exists to prevent.
      expect(reports(report, 'silently drop'), isTrue);
      expectActionable(report);
    });

    test('missing or malformed schema version', () {
      final ValidationReport report = expectRejected(
        'malformed_schema_version.json',
      );
      expect(reports(report, 'schemaVersion'), isTrue, reason: report.format());
      expect(reports(report, 'missing'), isTrue);
      expectActionable(report);
    });

    test('missing required field', () {
      final ValidationReport report = expectRejected(
        'missing_required_field.json',
      );
      expect(reports(report, 'health'), isTrue, reason: report.format());
      expectActionable(report);
    });

    test('invalid numerical range', () {
      final ValidationReport report = expectRejected(
        'invalid_numerical_range.json',
      );
      expect(
        reports(report, 'below the allowed minimum'),
        isTrue,
        reason: report.format(),
      );
      expect(reports(report, 'above the allowed maximum'), isTrue);
      expectActionable(report);
    });

    test('prohibited self-reference in a recipe', () {
      final ValidationReport report = expectRejected(
        'prohibited_self_reference.json',
      );
      expect(
        reports(report, 'consumes its own output'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });

    test('location connected to itself', () {
      final ValidationReport report = expectRejected(
        'self_connected_location.json',
      );
      expect(
        reports(report, 'connects to itself'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });

    test('unreachable starter progression chain', () {
      // Every axe good enough for oak is itself crafted from oak.
      final ValidationReport report = expectRejected(
        'unreachable_tool_bootstrap.json',
      );
      expect(reports(report, 'bronze'), isTrue, reason: report.format());
      expect(
        reports(report, BlockReason.resourceBehindItsOwnOutput.name) ||
            reports(report, BlockReason.toolBootstrapDeadlock.name) ||
            reports(report, BlockReason.missingIngredient.name),
        isTrue,
        reason:
            'the block should be diagnosed, not merely reported:\n'
            '${report.format()}',
      );
      expectActionable(report);
    });

    test('production content referencing a QA-only value', () {
      final ValidationReport report = expectRejected(
        'production_uses_qa_value.json',
      );
      expect(reports(report, 'QA-only'), isTrue, reason: report.format());
      expect(reports(report, 'never be reachable'), isTrue);
      expectActionable(report);
    });

    test('QA profile marked release safe', () {
      final ValidationReport report = expectRejected(
        'qa_profile_marked_release_safe.json',
      );
      expect(
        reports(report, 'only the production profile may be releaseSafe'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });

    test('unknown field', () {
      // A typo in an optional field would otherwise be ignored, and the author
      // would disagree with the game forever about whether logs stack.
      final ValidationReport report = expectRejected('unknown_field.json');
      expect(reports(report, 'stackible'), isTrue, reason: report.format());
      expect(reports(report, 'check the spelling'), isTrue);
      expectActionable(report);
    });

    test('missing item rarity', () {
      // `rarity` is required (`DECISIONS/0021` §4). Defaulting it would answer
      // for an author who never asked, and a wrong answer would look exactly
      // like a considered one.
      final ValidationReport report = expectRejected('missing_rarity.json');
      expect(
        reports(report, 'the required field "rarity" is missing'),
        isTrue,
        reason: report.format(),
      );
      expect(reports(report, 'item.oak_log'), isTrue);
      expectActionable(report);
    });

    test('unknown item rarity', () {
      final ValidationReport report = expectRejected('unknown_rarity.json');
      expect(
        reports(report, '"mythic" is not a recognised value'),
        isTrue,
        reason: report.format(),
      );
      // The suggestion must list the ranks, so the fix is in the message.
      for (final Rarity rarity in Rarity.values) {
        expect(
          reports(report, rarity.wireName),
          isTrue,
          reason: '${rarity.wireName} missing from the suggestion',
        );
      }
      expectActionable(report);
    });

    test('encountersPerVisit below one', () {
      // Zero would ship an enemy that stands at a location and can never be
      // fought there (`DECISIONS/0021` §1).
      final ValidationReport report = expectRejected(
        'invalid_encounters_per_visit.json',
      );
      expect(
        reports(report, 'below the allowed minimum of 1'),
        isTrue,
        reason: report.format(),
      );
      expect(reports(report, 'encountersPerVisit'), isTrue);
      expectActionable(report);
    });

    test('broken XP curve', () {
      final ValidationReport report = expectRejected('broken_xp_curve.json');
      expect(
        reports(report, 'strictly increase'),
        isTrue,
        reason: report.format(),
      );
      expectActionable(report);
    });
  });

  group('the validator does not fire spuriously', () {
    test('valid production content produces exactly zero errors', () {
      // Every other test here proves the validator fires. This one proves it
      // does not fire when it should not — a validator that rejected
      // everything would pass the entire fixture suite above.
      final ContentLoadResult result = loadProduction(productionSource);

      expect(result.report.errors, isEmpty, reason: result.report.format());
      expect(result.isValid, isTrue);
    });

    test('each fixture fails narrowly rather than cascading', () {
      // A single broken field should not produce twenty errors. A cascade
      // means the author reads noise to find the one line that matters.
      for (final String fixture in <String>[
        'duplicate_id.json',
        'unknown_skill_reference.json',
        'prohibited_self_reference.json',
        'self_connected_location.json',
        'qa_profile_marked_release_safe.json',
      ]) {
        final ValidationReport report = expectRejected(fixture);
        expect(
          report.errors.length,
          lessThanOrEqualTo(5),
          reason:
              '$fixture cascaded into ${report.errors.length} errors:\n'
              '${report.format()}',
        );
      }
    });
  });

  group('error reporting quality', () {
    test('all practical errors are collected in one pass', () {
      final ValidationReport report = expectRejected(
        'invalid_numerical_range.json',
      );

      // Two problems in one entry: health below minimum and chance above
      // maximum. Stopping at the first would make fixing a bundle a sequence
      // of one-error rebuilds.
      expect(
        report.errors.length,
        greaterThanOrEqualTo(2),
        reason: report.format(),
      );
    });

    test('every error names its source file', () {
      final ValidationReport report = expectRejected('duplicate_id.json');
      for (final ValidationError error in report.errors) {
        expect(error.sourceFile, isNotEmpty);
      }
    });

    test('a formatted report reads as instructions', () {
      final String text = expectRejected(
        'unknown_item_reference.json',
      ).format();

      expect(text, contains('validation error'));
      expect(text, contains('fix:'));
    });
  });
}
