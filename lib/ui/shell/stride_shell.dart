/// Tab state, header, and body switching.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../debug/dev_harness.dart';
import '../components/screen_header.dart';
import '../components/stride_scaffold.dart';
import '../components/stride_tab_bar.dart';
import '../screens/adventure/adventure_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/world/world_screen.dart';
import '../state/session_controller.dart';
import '../state/session_scope.dart';
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
        child: ScreenHeader(
          eyebrow: controller.session.locationName,
          title: _selected.label,
          trailing: BankedStepsReadout(
            bankedSteps: controller.session.usableEnergy,
          ),
        ),
      ),
      body: switch (_selected) {
        StrideDestination.adventure => const AdventureScreen(),
        StrideDestination.character => const CharacterScreen(),
        StrideDestination.inventory => const InventoryScreen(),
        StrideDestination.world => const WorldScreen(),
        // Unreachable: the tab bar refuses taps on a disabled destination, so
        // _selected can only ever hold an enabled one.
        _ => const SizedBox.shrink(),
      },
      bottomBar: StrideTabBar(
        selected: _selected,
        onSelect: (StrideDestination d) => setState(() => _selected = d),
      ),
    );
  }
}
