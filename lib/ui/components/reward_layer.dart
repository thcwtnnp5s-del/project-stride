/// The reward layer: a reveal **above** the surface that earned it
/// (PLAYABLE_POLISH_01 §3–§4).
///
/// ## Why a layer
///
/// The one reward language (`reward_beat.dart`) made every result the same
/// shape, and the owner's device then found the shape in the wrong place: a
/// contract handed in printed its payoff *inside* the board, between the job
/// rows; a victory stacked its rewards in the card under the stage; an
/// equipment craft wrote itself into the recipe detail. Each was a beat, and
/// each still read as "text embedded in the page" — the management surface
/// and the payoff on one plane.
///
/// This file is the second plane. The underlying screen stays where it is,
/// dimmed; the result rises over it in its own framed panel, resolves its
/// beats top to bottom once, and holds until the player acknowledges it.
/// The board is the ledger; this is the moment.
///
/// ## Tiering, kept
///
/// MINOR results never come here — a single gather, a component craft, an
/// ordinary bounty tick resolve inline on their own timers, because a layer
/// for every small thing is a nag. MEDIUM and MAJOR results do, and are held
/// (`RULES.md` P-6: nothing loops, nothing bursts, nothing waits to be
/// opened — the beats are laid out at full size from the first frame; only
/// the panel's rise and the beats' settle animate, once, fast).
///
/// ## Transient by contract
///
/// The layer is built from a **report snapshot** and owns nothing durable.
/// Dismissing it runs the caller's acknowledgement (the controller clears
/// its report) and nothing else; a relaunch has no layer to restore
/// (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'data_display.dart';
import 'reward_beat.dart';

/// Raises [beats] over the current route and holds them until the player
/// taps [continueLabel]. Resolves when the layer is gone; [onContinue] runs
/// exactly once, before the pop.
///
/// The scrim and the panel are one route, so the Back gesture and the
/// button do the same thing and a second call stacks a second layer rather
/// than replacing the first — a craft that also levels up is two payoffs and
/// is presented as one panel by the caller, never as two routes.
Future<void> showRewardLayer(
  BuildContext context, {
  required RewardTier tier,
  required List<Widget> beats,
  Color? accent,
  String continueLabel = 'Continue',
  VoidCallback? onContinue,
  Widget? trailing,
}) {
  final bool reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Reward',
    barrierColor: RewardLayer.scrim,
    transitionDuration: reduced ? Duration.zero : RewardLayer.rise,
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
        RewardLayer(
          tier: tier,
          accent: accent,
          continueLabel: continueLabel,
          trailing: trailing,
          onContinue: () {
            onContinue?.call();
            Navigator.of(ctx).pop();
          },
          beats: beats,
        ),
    transitionBuilder:
        (
          BuildContext ctx,
          Animation<double> a,
          Animation<double> b,
          Widget child,
        ) {
          final CurvedAnimation curve = CurvedAnimation(
            parent: a,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
  );
}

/// A hairline above a beat that follows another, so the layer reads as one
/// sheet of facts rather than a stack of boxes.
class _Ruled extends StatelessWidget {
  const _Ruled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Container(height: 1, color: StrideColors.separator),
      const SizedBox(height: StrideSpace.s10),
      child,
    ],
  );
}

/// The panel itself, route-free, so a test or a golden can lay it out
/// without a Navigator.
class RewardLayer extends StatelessWidget {
  const RewardLayer({
    super.key,
    required this.tier,
    required this.beats,
    required this.onContinue,
    this.accent,
    this.continueLabel = 'Continue',
    this.trailing,
  });

  /// Decides the frame weight and the eyebrow rule: MEDIUM a 1 px frame,
  /// MAJOR 2 px and a heavier rule. MINOR is accepted and drawn as MEDIUM —
  /// a caller that raised a layer decided it mattered.
  final RewardTier tier;

  /// The result, top to bottom. Built by the caller from its report.
  final List<Widget> beats;

  /// The frame's colour: a rarity's accent, a skill's hue, the step accent.
  /// Null is the default border — a result with no colour of its own.
  final Color? accent;

  final String continueLabel;
  final VoidCallback onContinue;

  /// A second control beside Continue — `Equip`, for a finished piece of
  /// gear. Secondary placement: the layer's one job is to be acknowledged.
  final Widget? trailing;

  /// The dim over the surface beneath. Dark enough that the panel is the
  /// only thing lit; light enough that the place is still there behind it.
  static const Color scrim = Color(0xB30E0C0A);

  /// The panel's rise. Shorter than a beat, so the first beat is already
  /// settling as the frame arrives.
  static const Duration rise = Duration(milliseconds: 220);

  /// Widest the panel gets; phones are narrower and take the gutter.
  static const double maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final Color frame = accent ?? StrideColors.borderDefault;
    final bool major = tier == RewardTier.major;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(StrideSpace.screenGutter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            // The dialog route supplies no Material of its own; the app's
            // `MaterialApp.builder` Material sits above the Navigator, so the
            // route inherits the product's resolved text style — family,
            // colour, no underline (MISTAKES.md M-06). **Merge**, never
            // replace: a fresh DefaultTextStyle here drops the inherited font
            // family and every string in the layer falls back to the
            // harness's box glyphs, which is exactly how M-06 first shipped.
            child: DefaultTextStyle.merge(
              style: StrideType.body,
              child: Container(
                decoration: BoxDecoration(
                  color: StrideColors.surfaceCard,
                  borderRadius: StrideRadius.card,
                  border: Border.all(color: frame, width: major ? 2 : 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // One frame, in the result's ink, and nothing else
                    // drawn around the content (finding E): the beats
                    // inside are frameless (`RewardLayerScope`) and are
                    // separated by a hairline rather than boxed.
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          StrideSpace.cardPadding,
                          StrideSpace.cardPadding + StrideSpace.s2,
                          StrideSpace.cardPadding,
                          StrideSpace.cardPadding,
                        ),
                        child: RewardLayerScope(
                          child: StaggeredReveal(
                            gap: StrideSpace.s10,
                            children: <Widget>[
                              for (int i = 0; i < beats.length; i++)
                                i == 0
                                    ? beats[i]
                                    : _Ruled(child: beats[i]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        StrideSpace.cardPadding,
                        0,
                        StrideSpace.cardPadding,
                        StrideSpace.cardPadding,
                      ),
                      child: Row(
                        children: <Widget>[
                          if (trailing case final Widget t) ...<Widget>[
                            Expanded(child: t),
                            const SizedBox(width: StrideSpace.s8),
                          ],
                          Expanded(
                            child: StrideButton(
                              label: continueLabel,
                              onPressed: onContinue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Raises the layer when a **held result appears in state**, for the
/// surfaces whose results arrive through a controller rather than a tap
/// handler — the craft queue, the gather queue, the combat resolution.
///
/// [token] is the result's identity — the report object, or a string of
/// the finished figures for a controller that keeps no report. When it
/// changes to a non-null value (by `==`) the layer is raised once, after
/// the frame that saw it; Continue runs [onDismiss], which is the
/// controller's acknowledgement and clears the token. A rebuild with an
/// equal token raises nothing, and a token that is already showing is never
/// raised twice.
///
/// The child is the surface beneath, untouched; while the token is held the
/// surface should show nothing of the result itself — the layer owns it.
class RewardRaise extends StatefulWidget {
  const RewardRaise({
    super.key,
    required this.token,
    required this.tier,
    required this.beats,
    required this.onDismiss,
    required this.child,
    this.accent,
    this.continueLabel = 'Continue',
    this.trailing,
  });

  final Object? token;
  final RewardTier tier;
  final List<Widget> beats;
  final VoidCallback onDismiss;
  final Widget child;
  final Color? accent;
  final String continueLabel;
  final Widget? trailing;

  @override
  State<RewardRaise> createState() => _RewardRaiseState();
}

class _RewardRaiseState extends State<RewardRaise> {
  Object? _raised;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _consider();
  }

  @override
  void didUpdateWidget(RewardRaise old) {
    super.didUpdateWidget(old);
    _consider();
  }

  void _consider() {
    final Object? token = widget.token;
    if (token == null || token == _raised || _showing) return;
    // No Navigator — a bare harness mounting one screen. The panel is drawn
    // inline beneath the child instead (see build), and nothing is pushed.
    if (Navigator.maybeOf(context) == null) return;
    _raised = token;
    _showing = true;
    // After the frame, never during build: a route push mid-build is a
    // framework assertion, and the frame that saw the result is the one
    // that should draw the surface beneath the scrim.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showing = false;
        return;
      }
      await showRewardLayer(
        context,
        tier: widget.tier,
        beats: widget.beats,
        accent: widget.accent,
        continueLabel: widget.continueLabel,
        trailing: widget.trailing,
        onContinue: widget.onDismiss,
      );
      _showing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // With a Navigator — the product — the child is returned as it is and
    // the panel is a route. Without one (a bare harness) the panel is drawn
    // beneath the child, and the Column is there whether or not a panel is
    // showing: the child's slot in the element tree must never move, since
    // wrapping it only while a panel is up would remount it — and a
    // remounted stage forgets the round it was playing.
    if (Navigator.maybeOf(context) != null) return widget.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        widget.child,
        if (widget.token != null)
          RewardLayer(
            key: ObjectKey(widget.token),
            tier: widget.tier,
            beats: widget.beats,
            accent: widget.accent,
            continueLabel: widget.continueLabel,
            trailing: widget.trailing,
            onContinue: widget.onDismiss,
          ),
      ],
    );
  }
}
