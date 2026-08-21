/// The Goal Board — the one-press planning surface
/// (PRESENTATION_WORLD_REWARD_FEEL_01 §8, §10–§11).
///
/// ## Why a pushed full-screen route
///
/// The owner's device finding was that Adventure permanently exposed the
/// whole job-board management UI — goals, boards, repeated Track / Deliver /
/// Accept stacks — and asked for "a single obvious button such as Goal
/// Board". A full-screen route gives the board the room the cards were
/// fighting Adventure for, keeps the location's fiction (Notice Board /
/// Ranger Requests / Mine Ledger / Expedition Ledger) as the screen's own
/// title, and costs Adventure a 48 dp button.
///
/// ## The scope re-wrap
///
/// `SessionScope` / `ActivityScope` sit under `MaterialApp.home`, so a pushed
/// route is outside them. [open] re-wraps the pushed screen in the same
/// long-lived controllers taken from the pushing context — the same pattern
/// the dev harness uses with its constructor argument, kept as scopes here so
/// every existing card works unchanged.
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/screen_header.dart';
import '../../components/surfaces.dart';
import '../../state/activity_controller.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'board_card.dart';
import 'goal_tracker_card.dart';

class GoalBoardScreen extends StatelessWidget {
  const GoalBoardScreen({super.key});

  /// Pushes the board, re-wrapped in the pushing context's controllers.
  static Future<void> open(BuildContext context) {
    final SessionController session = SessionScope.read(context);
    final ActivityController activity = ActivityScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScope(
          controller: session,
          child: ActivityScope(
            controller: activity,
            child: const GoalBoardScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final BoardView? board = s.boardHere;
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);

    return ColoredBox(
      color: StrideColors.surfaceGround,
      child: Column(
        children: <Widget>[
          SizedBox(height: inset.top),
          ScreenHeader(
            eyebrow: s.locationName,
            // The location's own fiction is the screen's identity (§11): the
            // player opens Haven's Notice Board, not a generic quest log.
            title: board?.boardName ?? 'Goal Board',
            trailing: Semantics(
              button: true,
              label: 'Close the Goal Board',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(StrideSpace.s8),
                  child: Text(
                    'CLOSE',
                    style: StrideType.microLabel.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                StrideSpace.screenGutter,
                StrideSpace.s12,
                StrideSpace.screenGutter,
                StrideSpace.s16 + inset.bottom,
              ),
              children: <Widget>[
                // WHAT I AM WORKING TOWARDS — the full three-slot tracker,
                // with its material breakdowns and clear controls.
                const GoalTrackerCard(),
                const SizedBox(height: StrideSpace.cardGap),

                // WHAT THIS PLACE ASKS FOR — the board, in this location's
                // fiction. Absent where the place keeps none.
                if (board != null)
                  const LocationBoardCard()
                else
                  SectionCard(
                    child: Text(
                      'No one posts work at this place. Boards hang in '
                      'settlements and worksites.',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
