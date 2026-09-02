/// The Traveler fights with the weapon he is actually holding (VAWO01).
///
/// The base combat set bakes one generic pale-steel sword into all 28 of its
/// frames. Before this round that set was drawn for *every* loadout, so a
/// Traveler with an empty weapon slot still swung a blade he did not own — the
/// interface contradicting durable state, which is the class of defect
/// `RULES.md` A-1 and the milestone's honesty rule both exist to prevent.
///
/// These tests hold the property that makes the fix real rather than
/// decorative: **a variant may never reach back into the base's art.** A
/// single shared frame would put the sword in an unarmed Traveler's hand for
/// as long as that frame is on screen, and the round would have bought
/// nothing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

/// Every frame path a set can draw, across all of its tracks.
Set<String> _framesOf(CombatantArt a) => <String>{
  ...a.idle.track.frames,
  ...a.attack.track.frames,
  ...?a.heavy?.track.frames,
  ...?a.hit?.track.frames,
  ...?a.defeat?.track.frames,
  ...?a.stagger?.track.frames,
};

void main() {
  final Map<String, CombatantArt> variants = <String, CombatantArt>{
    'unarmed': CombatAssets.travelerUnarmed,
    'bronze': CombatAssets.travelerBronze,
  };

  test('every frame a variant declares is on disk', () {
    for (final MapEntry<String, CombatantArt> v in variants.entries) {
      for (final String frame in _framesOf(v.value)) {
        expect(
          File(frame).existsSync(),
          isTrue,
          reason: '${v.key} declares $frame, which is not packaged',
        );
      }
    }
  });

  test('no variant shares a frame with the sword-baked base set', () {
    final Set<String> base = _framesOf(CombatAssets.traveler);
    expect(base, isNotEmpty);
    for (final MapEntry<String, CombatantArt> v in variants.entries) {
      expect(
        _framesOf(v.value).intersection(base),
        isEmpty,
        reason:
            'the ${v.key} set draws a base frame, and every base frame has the '
            'generic steel sword baked into it',
      );
    }
  });

  test('every variant owns its defeat, rather than borrowing the base', () {
    // The Traveler's defeat-as-retreat strip holds on a downed-but-alive pose
    // the camera lingers on (`RULES.md` P-7). The base's version has the
    // generic steel sword baked into it, so a variant that borrowed it would
    // hand the blade back at exactly the moment the player is looking hardest.
    // The `no variant shares a frame with the base` test above is what makes
    // that impossible; this one makes sure the answer was "author your own"
    // rather than "go without" — dropping the kneel would be a quiet
    // downgrade in game feel for the most common loadouts.
    for (final MapEntry<String, CombatantArt> v in variants.entries) {
      expect(v.value.stagger, isNotNull, reason: '${v.key} has no defeat');
      expect(v.value.hit, isNotNull, reason: '${v.key} has no flinch');
      expect(
        v.value.stagger!.frameCount,
        CombatAssets.traveler.stagger!.frameCount,
        reason: '${v.key} defeats on a different beat from the base',
      );
      expect(v.value.stagger!.duration, CombatAssets.traveler.stagger!.duration);
    }
  });

  test('the blow lands on a frame the strip actually has', () {
    for (final MapEntry<String, CombatantArt> v in variants.entries) {
      expect(v.value.strikeFrame, greaterThanOrEqualTo(0));
      expect(
        v.value.strikeFrame,
        lessThan(v.value.attack.frameCount),
        reason: '${v.key} lands its blow past the end of its attack',
      );
    }
  });

  test('the stage precaches the set it will draw, not the base', () {
    final ContentId enemy = ContentId.unchecked('enemy.forest_wolf');
    final ContentId location = ContentId.unchecked('location.havens_rest');
    final Set<String> base = _framesOf(CombatAssets.traveler);

    for (final MapEntry<String, CombatantArt> v in variants.entries) {
      final Set<String> cached = CombatAssets.framesFor(
        enemy,
        location,
        traveler: v.value,
      ).toSet();
      // Decoding the wrong strips would let the gear flicker in on the first
      // painted frame, which is the defect this round must not introduce.
      expect(
        cached.containsAll(_framesOf(v.value)),
        isTrue,
        reason: '${v.key} would decode its own art late',
      );
      expect(
        cached.intersection(base),
        isEmpty,
        reason: '${v.key} still precaches the base sword frames',
      );
    }
  });
}
