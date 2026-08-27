/// Tab state, header, and body switching.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../../debug/dev_harness.dart';
import '../components/screen_header.dart';
import '../theme/stride_colors.dart';
import '../components/stride_scaffold.dart';
import '../components/stride_tab_bar.dart';
import '../screens/adventure/adventure_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/craft/craft_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/skills/skills_screen.dart';
import '../screens/world/world_screen.dart';
import '../state/session_controller.dart';
import '../state/session_scope.dart';
import 'shell_tabs.dart';
import 'stride_destination.dart';

class StrideShell extends StatefulWidget {
  const StrideShell({super.key});

  @override
  State<StrideShell> createState() => _StrideShellState();
}

class _StrideShellState extends State<StrideShell> {
  StrideDestination _selected = StrideDestination.adventure;

  @override
  Widget build(BuildContext context) {
    // Subscribes: the header's banked figure must refresh on every command.
    final SessionController controller = SessionScope.of(context);

    return StrideScaffold(
      header: GestureDetector(
        // The whole header, not only its glyphs.
        //
        // `GestureDetector` defaults to `HitTestBehavior.deferToChild`, which
        // means it receives a press only where the child actually paints
        // something hit-testable. The header is mostly empty space between a
        // few `Text` runs, so the long-press worked **only if the finger landed
        // on a letter** — found on a device, where three presses in the gap did
        // nothing and one on the title opened the harness.
        //
        // That matters more than a debug affordance usually would, because the
        // acceptance script instructs the owner to "long-press the header". A
        // tester following it would most likely hit dead space, conclude the
        // affordance is not wired, and file a defect that isn't one.
        behavior: HitTestBehavior.opaque,

        // Debug-only access to the dev harness. It is kept, not replaced — it is
        // the instrument that proved the vertical slice on hardware and it
        // reaches paths the product UI deliberately does not expose (synthetic
        // grants, erase, forced reload, raw fault categories).
        //
        // A long-press on the header rather than a seventh tab: DECISIONS/0004
        // fixes the tab set at six, and a visible debug control in a demo build
        // is a control a reviewer will press.
        onLongPress: kDebugMode
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DevHarnessScreen(session: controller.session),
                ),
              )
            : null,
        child: () {
          // The region's biome colour on every screen's header (Fable V2
          // Iteration 02): the eyebrow — the place's name — wears the
          // place's ink, and the bar breathes the region deep. The app now
          // tells you where you are before a word is read, and it changes
          // when you travel.
          final ContentId? here = controller.session.currentLocation;
          return ScreenHeader(
            eyebrow: controller.session.locationName,
            title: _selected.label,
            regionInk: here == null ? null : StrideColors.forRegion(here),
            regionDeep: here == null ? null : StrideColors.forRegionDeep(here),
            trailing: BankedStepsReadout(
              bankedSteps: controller.session.usableEnergy,
            ),
          );
        }(),
      ),
      // An [IndexedStack] rather than a bare switch, so a tab change no
      // longer destroys every screen's ephemeral state (Fable V2 UX audit
      // S2). The planning loop this app is built around — look at the
      // atlas, check the bag or the bench, come back — used to snap the
      // World camera home and drop the selected destination on every hop;
      // now camera, selection, scroll and open detail survive the round
      // trip. The reward and result layers live in session/controller
      // state, which this changes nothing about.
      //
      // **The explicit [TickerMode] wraps are load-bearing** (Iteration 02,
      // PERF-A): `IndexedStack` builds hidden children with
      // `maintainAnimation: true`, so the framework inserts NO TickerMode
      // of its own — without these wraps a visited World tab kept its
      // atlas overlay ticker scheduling 120 Hz frames from any tab, and a
      // hidden Adventure stage kept looping and firing its audio cues,
      // breaking `audio_controller.dart`'s "the beats stop with the
      // screen" contract. The wrap silences tickers offstage while
      // preserving every screen's state, which is the whole bargain.
      //
      // The list is ordered by [StrideDestination.index] and every
      // destination has a screen; a seventh without one is still a compile
      // error — here, at the exhaustive index list.
      // Deliberately non-const children: a const list would short-circuit
      // the child rebuild on a tab switch, so the incoming screen could show
      // the state it was last built with. Fresh instances rebuild every
      // child on every shell build — the *elements* (and so each screen's
      // camera, selection and scroll) are preserved either way.
      // `ShellTabs` hands the screens the same switch the tab bar uses, so
      // a moment that points at another tab (the opportunity banner's
      // journey line) can take the player there instead of describing the
      // way.
      // ignore: prefer_const_constructors
      body: ShellTabs(
        select: (StrideDestination d) => setState(() => _selected = d),
        // ignore: prefer_const_constructors
        child: IndexedStack(
          index: _selected.index,
          children: <Widget>[
            TickerMode(
              enabled: _selected == StrideDestination.adventure,
              // ignore: prefer_const_constructors
              child: AdventureScreen(),
            ),
            TickerMode(
              enabled: _selected == StrideDestination.character,
              // ignore: prefer_const_constructors
              child: CharacterScreen(),
            ),
            TickerMode(
              enabled: _selected == StrideDestination.skills,
              // ignore: prefer_const_constructors
              child: SkillsScreen(),
            ),
            TickerMode(
              enabled: _selected == StrideDestination.inventory,
              // ignore: prefer_const_constructors
              child: InventoryScreen(),
            ),
            TickerMode(
              enabled: _selected == StrideDestination.craft,
              // ignore: prefer_const_constructors
              child: CraftScreen(),
            ),
            TickerMode(
              enabled: _selected == StrideDestination.world,
              // ignore: prefer_const_constructors
              child: WorldScreen(),
            ),
          ],
        ),
      ),
      bottomBar: StrideTabBar(
        selected: _selected,
        onSelect: (StrideDestination d) => setState(() => _selected = d),
      ),
    );
  }
}
