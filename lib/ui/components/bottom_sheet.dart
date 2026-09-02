/// A sheet that rises from the foot of a screen, hand-rolled.
///
/// ## Why detail moved off the list and into this
///
/// The Craft screen's recipes are 2-column tiles now
/// (`ART-12_ux_brief.md` §1). Inline expansion inside a 2-column grid
/// displaces the tile's row partner and shoves half the list off screen, and
/// that scroll-hunt is precisely what made the screen read as a database. A
/// tile therefore opens a sheet: the list stays exactly where the player left
/// it, and the detail is one thing, in one place, over everything.
///
/// ## Why it is not a Material `showModalBottomSheet`
///
/// Stride ships no stock Material widget anywhere — no `Card`, no `Chip`, no
/// `ListTile`, no `Icons.*` (`panel_skin.dart` records the audit). A Material
/// sheet would arrive with Material's radius, Material's elevation shadow,
/// Material's scrim and Material's drag physics, which is four decisions this
/// product has already made differently. So this is `Stack` +
/// `GestureDetector` + `AnimatedSlide`, and nothing else.
///
/// ## Motion
///
/// One rise, once, fast, and `Duration.zero` under
/// `MediaQuery.disableAnimationsOf` — the convention every animated widget in
/// this product follows. Nothing loops and nothing waits to be opened
/// (`RULES.md` P-6).
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';

/// Raises [child] over whatever the sheet is stacked on top of.
///
/// Renders nothing at all when [open] is false, so a closed sheet costs no
/// hit region and no semantics node. Place it as the **last** child of a
/// `Stack` that fills the screen.
class StrideSheet extends StatelessWidget {
  const StrideSheet({
    super.key,
    required this.open,
    required this.onDismiss,
    required this.child,
    this.label,
  });

  final bool open;

  /// Run by the scrim tap, the grab area's tap, and the back gesture. The
  /// caller owns the state; this widget owns none.
  final VoidCallback onDismiss;

  final Widget child;

  /// What a screen reader calls this sheet.
  final String? label;

  /// The share of the screen the sheet may take. Above this the content
  /// scrolls inside it — the surface underneath must stay visible, or the
  /// sheet has become a page and should have been one.
  static const double maxFraction = 0.7;

  /// The grab area: the strip at the sheet's head that is a dismiss control
  /// as well as a handle, so the gesture and the tap agree.
  static const double grabArea = 56;

  static const Duration rise = Duration(milliseconds: 180);

  /// Dark enough that the sheet is the lit thing, light enough that the list
  /// beneath is still legibly there — the reward layer's own reasoning at a
  /// lighter weight, because a sheet is a detour and not an interruption.
  static const Color scrim = Color(0x9914120F);

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final double maxHeight = MediaQuery.sizeOf(context).height * maxFraction;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Positioned.fill(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: label != null,
        label: label,
        child: Stack(
          children: <Widget>[
            // The scrim is the dismiss control and the interaction block in
            // one: opaque hit behaviour means nothing under it is reachable
            // while the sheet is up.
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: const ColoredBox(color: scrim),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Rise(
                duration: reduced ? Duration.zero : rise,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: DecoratedBox(
                    // The screen's own ground, with one hairline at the top
                    // edge and nothing else. A second border here would put
                    // two edges around the one card inside — the "eleven
                    // unrelated borders" failure `panel_skin.dart` names.
                    decoration: const BoxDecoration(
                      color: StrideColors.surfaceGround,
                      border: Border(
                        top: BorderSide(color: StrideColors.borderDefault),
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onDismiss,
                          child: const SizedBox(
                            height: grabArea,
                            child: Center(child: _Grip()),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              StrideSpace.screenGutter,
                              0,
                              StrideSpace.screenGutter,
                              // The sheet's own content ends above the home
                              // indicator, never under it.
                              bottomInset + StrideSpace.s16,
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 4,
    decoration: const BoxDecoration(
      color: StrideColors.borderDefault,
      borderRadius: StrideRadius.gate,
    ),
  );
}

/// One slide up, on mount, and never again.
///
/// `AnimatedSlide` animates a *change* of offset, so a widget built already
/// in place never moves. This starts one frame low and settles — which is the
/// whole animation, and is `Duration.zero` when the platform asks for no
/// motion.
class _Rise extends StatefulWidget {
  const _Rise({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> {
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion does not get a zero-length animation, it gets no
    // animation: the sheet is simply there, on the first frame.
    if (widget.duration == Duration.zero) return widget.child;
    return AnimatedSlide(
      offset: _settled ? Offset.zero : const Offset(0, 1),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
  }
}
