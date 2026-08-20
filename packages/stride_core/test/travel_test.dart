// TravelTo — the command that makes distance cost walking.
//
// `OD-02` named the absence of this command as the first of two dependencies
// blocking a geographic world: a map whose whole point is that places are far
// apart needs a system that can cross the distance, or it is describing lengths
// nothing can traverse.
//
// The properties that matter are the ones a UI could otherwise get wrong:
// adjacency comes from content and cannot be fabricated by naming two places;
// the spend and the move are one fact; and a refused journey costs nothing.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId havensRest = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId stonefall = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');

/// A fresh game with [steps] banked and nothing else changed.
GameEngine engineWith(int steps) {
  final GameEngine engine = newEngine();
  if (steps > 0) {
    engine.execute(GrantSyntheticSteps(steps: steps, reason: 'test'));
  }
  return engine;
}

void main() {
  group('1 — a legal journey', () {
    test('spends exactly the connection cost and arrives', () {
      final GameEngine engine = engineWith(2000);

      final EngineResult result = engine.execute(TravelTo(destination: woods));

      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
      expect(engine.state.world.currentLocation, woods);
      expect(
        engine.state.steps.banked,
        1500,
        reason: '2,000 − 500. Exactly the cost, not approximately.',
      );
      expect(engine.state.steps.totalSpent, 500);
    });

    test('arriving is what opens a place', () {
      final GameEngine engine = engineWith(2000);
      expect(engine.state.world.isUnlocked(woods), isFalse);

      engine.execute(TravelTo(destination: woods));

      expect(engine.state.world.isUnlocked(woods), isTrue);
    });

    test('the first arrival is marked, and later ones are not', () {
      final GameEngine engine = engineWith(4000);

      final EngineResult first = engine.execute(TravelTo(destination: woods));
      engine.execute(TravelTo(destination: havensRest));
      final EngineResult again = engine.execute(TravelTo(destination: woods));

      expect((first.events.single as LocationTravelled).firstVisit, isTrue);
      expect((again.events.single as LocationTravelled).firstVisit, isFalse);
    });

    test('returning is not free — every journey charges', () {
      // The property that keeps the geography meaningful past the first hour.
      final GameEngine engine = engineWith(2000);

      engine.execute(TravelTo(destination: woods));
      engine.execute(TravelTo(destination: havensRest));

      expect(engine.state.steps.banked, 1000, reason: '2,000 − 500 − 500');
      expect(engine.state.world.currentLocation, havensRest);
    });

    test('the spend and the move are one event', () {
      // Not two. A journal killed between two records leaves the first durable,
      // and a player whose steps went without them arriving has lost the walk.
      final GameEngine engine = engineWith(2000);

      final EngineResult result = engine.execute(TravelTo(destination: woods));

      expect(result.events, hasLength(1));
      final LocationTravelled event = result.events.single as LocationTravelled;
      expect(event.from, havensRest);
      expect(event.location, woods);
      expect(event.stepsSpent, 500);
    });
  });

  group('2 — refusals, and the order they come in', () {
    test('an unknown destination is refused', () {
      final EngineResult result = engineWith(9999).execute(
        TravelTo(destination: ContentId.unchecked('location.atlantis')),
      );

      expect(result.rejection!.code, RejectionCode.unknownLocation);
    });

    test('travelling to where you already are is refused', () {
      final EngineResult result = engineWith(
        9999,
      ).execute(TravelTo(destination: havensRest));

      expect(result.rejection!.code, RejectionCode.alreadyAtLocation);
    });

    test('a place with no route from here is refused as route_not_found', () {
      // Frostmere is reached through the mining district or not at all. There
      // is deliberately no Haven's Rest → Frostmere edge.
      final EngineResult result = engineWith(
        99999,
      ).execute(TravelTo(destination: frostmere));

      expect(
        result.rejection!.code,
        RejectionCode.routeNotFound,
        reason:
            'not locationLocked: the answer is a different first leg, not more '
            'progression, and the two refusals must not be conflated',
      );
      expect(result.rejection!.explanation, contains("Haven's Rest"));
      expect(result.rejection!.explanation, contains('Frostmere'));
    });

    test('adjacency cannot be fabricated by naming two real places', () {
      // The whole reason adjacency lives in content: a caller that could name
      // any two locations could walk the world in one step.
      final GameEngine engine = engineWith(99999);
      engine.execute(TravelTo(destination: stonefall));

      final EngineResult result = engine.execute(TravelTo(destination: hollow));

      expect(result.rejection!.code, RejectionCode.routeNotFound);
      expect(engine.state.world.currentLocation, stonefall);
    });

    test('an unmet entry requirement is named, not hidden behind cost', () {
      final GameEngine engine = engineWith(99999);
      engine.execute(TravelTo(destination: woods));

      final EngineResult result = engine.execute(TravelTo(destination: hollow));

      expect(result.rejection!.code, RejectionCode.entryRequirementUnmet);
      expect(
        result.rejection!.explanation,
        contains('Bronze Sword'),
        reason: 'the refusal must name the thing the player has to go and make',
      );
    });

    test('the requirement is checked before the cost', () {
      // Telling a player they cannot afford Forgotten Hollow, when the real
      // answer is that it needs a Bronze Sword, sends them walking towards a
      // wall they will still hit. Same rule as GatherResource.
      final GameEngine engine = engineWith(700);
      engine.execute(TravelTo(destination: woods));
      expect(engine.state.steps.banked, 200, reason: 'and 2,400 is needed');

      final EngineResult result = engine.execute(TravelTo(destination: hollow));

      expect(result.rejection!.code, RejectionCode.entryRequirementUnmet);
    });

    test('holding the required item opens the route', () {
      final GameEngine engine = engineWith(99999);
      engine.execute(TravelTo(destination: woods));
      // Granted directly rather than crafted: this test is about the gate, and
      // routing it through the whole Mining → Smithing chain would make a
      // failure here ambiguous.
      engine.execute(
        const GrantSyntheticSteps(steps: 1, reason: 'sequence filler'),
      );
      final GameEngine armed = GameEngine(
        registry: engine.registry,
        state: engine.state.copyWith(
          inventory: engine.state.inventory.adding(bronzeSword, 1),
        ),
      );

      final EngineResult result = armed.execute(TravelTo(destination: hollow));

      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
      expect(armed.state.world.currentLocation, hollow);
    });

    test('an unaffordable journey is refused, and quotes both figures', () {
      final EngineResult result = engineWith(
        100,
      ).execute(TravelTo(destination: woods));

      expect(result.rejection!.code, RejectionCode.insufficientSteps);
      expect(result.rejection!.explanation, contains('500'));
      expect(result.rejection!.explanation, contains('100'));
    });
  });

  group('3 — a refused journey costs nothing at all', () {
    test('no step is spent and the player has not moved', () {
      final GameEngine engine = engineWith(100);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(TravelTo(destination: woods));

      expect(result.isRejected, isTrue);
      expect(
        identical(engine.state, before),
        isTrue,
        reason:
            'the same object, not an equal one — proof that nothing was even '
            'rebuilt, so nothing could have been partially applied',
      );
      expect(engine.state.steps.banked, 100);
      expect(engine.state.world.currentLocation, havensRest);
    });

    test('every refusal path leaves the state identical', () {
      for (final TravelTo attempt in <TravelTo>[
        TravelTo(destination: ContentId.unchecked('location.atlantis')),
        TravelTo(destination: havensRest),
        TravelTo(destination: frostmere),
        TravelTo(destination: hollow),
      ]) {
        final GameEngine engine = engineWith(10);
        final GameState before = engine.state;

        expect(engine.execute(attempt).isRejected, isTrue, reason: '$attempt');
        expect(identical(engine.state, before), isTrue, reason: '$attempt');
      }
    });
  });

  group('4 — travel persists', () {
    test('the location and the spend survive a save round trip', () {
      final GameEngine engine = engineWith(2000);
      engine.execute(TravelTo(destination: woods));

      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'travel-0001',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;

      expect(reloaded.world.currentLocation, woods);
      expect(reloaded.world.isUnlocked(woods), isTrue);
      expect(reloaded.steps.banked, 1500);
    });

    test('the event survives the journal codec', () {
      // The decoder side of `event_codec` is a string switch with a
      // `default: return null`, so it is *not* compiler-enforced. A new event
      // encoded and not decoded makes every journal line containing it
      // undecodable, which presents as a torn tail on a real device.
      final GameEngine engine = engineWith(2000);
      final EngineResult result = engine.execute(TravelTo(destination: woods));

      final GameEvent? round = decodeEvent(encodeEvent(result.events.single));

      expect(round, isA<LocationTravelled>());
      final LocationTravelled decoded = round! as LocationTravelled;
      expect(decoded.from, havensRest);
      expect(decoded.location, woods);
      expect(decoded.stepsSpent, 500);
      expect(decoded.firstVisit, isTrue);
    });

    test('a corrupt negative spend is refused rather than replayed', () {
      // A negative spend from disk would drive totalSpent above totalGranted
      // and StepLedger throws — turning one corrupt record into a launch that
      // cannot start. Refusing the record is recoverable.
      final Map<String, Object?> encoded = encodeEvent(
        LocationTravelled(
          sequence: 0,
          from: havensRest,
          location: woods,
          stepsSpent: 600,
          firstVisit: true,
        ),
      );
      encoded['stepsSpent'] = -600;

      expect(decodeEvent(encoded), isNull);
    });
  });

  group('5 — the free move is not reachable from a surface', () {
    test('EnterLocation is internal, and TravelTo is the player’s route', () {
      // Asserted here as well as in the classification table, because this is
      // the property a World screen would break: offering the free move would
      // hand out unlimited travel in a game whose central claim is that
      // distance costs walking.
      expect(EnterLocation(location: woods).isPlayerFacing, isFalse);
      expect(TravelTo(destination: woods).isPlayerFacing, isTrue);
    });
  });
}
