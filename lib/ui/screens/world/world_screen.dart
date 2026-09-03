/// Where the player is, where they can go, and what the journey costs — as a
/// World Atlas: a pannable window onto the region, with the places on it as
/// real targets, and one panel beneath that says what a tap means.
///
/// ## What changed in Phase 2, and why the change was allowed
///
/// This screen used to carry a written prohibition, and it is worth preserving
/// the shape of it because it is the argument that had to be answered before a
/// button could appear here:
///
/// > It answers "where am I?" and "where can I eventually go?". It does not
/// > answer "how do I get there", because nothing in `stride_core` can. …
/// > **Nothing on this screen is a control.** … A `Travel` button here would be
/// > the most convincing lie in the demo: the map draws the roads, the content
/// > pack supplies real costs, and the player has real banked steps to spend.
/// > Every part of the illusion is present except the system.
///
/// **The system now exists.** `TravelTo` spends banked steps, moves the player
/// atomically, and is refused when the route, the requirements or the balance
/// do not allow it (`DECISIONS/0017`). So the affordance is no longer an
/// illusion, and the prohibition has been satisfied rather than overridden.
///
/// The distinction that mattered then still holds now: **a control may exist
/// here only because a command exists behind it.** The one button on this
/// screen dispatches `SessionController.travel`, and when it is disabled the
/// panel says which of the engine's own refusals it is anticipating. Nothing is
/// computed here that the engine does not also check.
///
/// ## What changed in the Transformation Build, and what did not
///
/// The map used to be a picture with no hit testing, and the controls were rows
/// in a card above it. It is now an **atlas**: the same art, at ×2, on a
/// surface the player pans and pinches, with every place a tappable target
/// (`atlas/`). Tapping a place *selects* it; the panel under the viewport
/// describes it and — only for a place with a road from here — offers the
/// journey. The information is what the rows carried: name, terrain, resources,
/// price, and the refusal reasons in the engine's order.
///
/// **Still not a joystick.** Travel is strategic menu travel powered by real
/// steps. There is no free roam, no avatar token on the map, nothing that can
/// be dragged but the camera, and no figure that walks. The current location is
/// marked by a pulsing ring — a caption in the shape of a circle — and the
/// player moves only when the engine says they did.
///
/// ## The current location is marked by weight, not by teal
///
/// `ART_DIRECTION.md` **L-16** reserves the accent for *"walking, steps, and
/// banked-step quantity — nothing else, anywhere, ever"*, and a place name is
/// none of those. Independent Visual QA once read a teal place name in a card
/// under a map as *a travel button to Haven's Rest* — the single affordance
/// this screen exists to refuse, arriving through a colour. So the current
/// place is heavier and brighter, never teal, on the map label and in the
/// panel alike. Whether it should have a colour of its own remains the owner's
/// question (`JOURNAL/OPEN_QUESTIONS.md` Q-04).
///
/// ## When there is no atlas
///
/// The layout is presentation data read at startup
/// (`lib/runtime/atlas_layout.dart`). If it is missing or does not cover the
/// content pack, the session says so and this screen shows the pre-atlas
/// presentation — the travel card, the region list, the map as a picture — with
/// the problems printed on it in debug. Nothing about travel depends on the
/// atlas existing.
library;

import 'dart:async' show scheduleMicrotask;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/panel_skin.dart' show KitFrame, KitMark;
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/atlas_assets.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';
import 'atlas/atlas_layout.dart';
import 'atlas/atlas_place_info.dart';
import 'atlas/atlas_selection_panel.dart';
import 'atlas/atlas_viewport.dart';

// The screen is **map-first, and the sheet is a stop rather than a state.**
//
// The owner named this screen twice: *"the bottom World information sheet
// currently obscures too much map — fix this; map must remain the hero"*, and
// *"fix viewed-location vs selected-location confusion"*. Both are answered
// here, in geometry and in vocabulary.
//
// **Geometry.** The panel used to open at `(body × 0.34).clamp(220, 360)` —
// 247 dp on a 727 dp body, so 480 dp of map, 66 % — and **every marker tap
// re-expanded it**, so the one gesture a player makes to look at the world
// was also the gesture that covered a third of it. The sheet now has three
// stops ([_SheetStop]) and opens at the smallest of them. A marker tap never
// raises the sheet; a tap on the map drops it to peek.
//
// This matters more than it did when the design was written: the terrain
// underneath is largely new. The whole south coast was repainted, the
// forest's west face opened into bays and copses, and the fairy glade, the
// storm house and the ice bastion are painted *into* the terrain rather than
// placed as props — so unlike props they survive the overview zoom. Every dp
// of sheet removed here reveals work that did not exist before.
//
// **Vocabulary.** Three states used to share one word and one panel: where
// the player stands, what they tapped, and what the camera happened to be
// pointing at. They now have three words, three markers and three homes —
// *You are here* (the pulse and bullseye, said in the peek's status line),
// the selected place's own name with *Reached* / *Not yet reached* beside it
// (the ivory ring, the sheet at every stop), and *Journey set* (the gold
// ring, the Journey slot). **The fourth — what the camera is looking at — is
// never named**, because naming it was the confusion. It appears only as
// [_ContextStrip], a 22 dp strip at the map's top edge that exists solely
// while the selected or the here marker has been panned off-screen, and says
// which way they lie.
//
// **What did not change, and must not.** Travel is a strategic, explicit
// player command with its cost on it. `Set out · N steps` is still the only
// dispatch, the peek's compact `Travel` only *arms* that confirm at the half
// stop, and nothing on this screen auto-travels.

/// The World sheet's three stops (DIR-15 §1), measured on a 393 × 852 phone
/// whose body is 727 dp (852 − a 61 dp header − a 64 dp nav bar):
///
/// | Stop | Sheet | Map visible | Share of body |
/// |---|---|---|---|
/// | [peek] | 64 (+ a 24 dp translucent fade the map shows through) | **663** | **91 %** |
/// | [half] | 262 | **465** | **64 %** |
/// | [full] | 509 | **218** | **30 %** |
///
/// Peek is the opening state *and* the resting state. Half is the decision —
/// the inspector's head, the priced travel confirm, the Journey slot. Full is
/// the reading — the whole inspector.
enum _SheetStop { peek, half, full }

/// 64 dp: a grip and one row. The floor, never the ceiling — the row grows
/// under Dynamic Type rather than clipping (D-01).
const double _sheetPeekHeight = 64;

/// The translucent ramp above the sheet. It is **not** part of the sheet's
/// height and it does not count against the map: the painting reads through
/// it, and pointer events in it fall through to the atlas.
const double _sheetFadeHeight = 24;

/// The grip strip inside the sheet's own top edge.
const double _sheetGripHeight = 12;

const double _sheetHalfFraction = 0.36;
const double _sheetHalfMin = 232;
const double _sheetHalfMax = 300;
const double _sheetFullFraction = 0.70;

/// Above this, a drag is a fling and moves exactly one stop; below it, the
/// sheet snaps to whichever stop it was left nearest.
const double _sheetFlingVelocity = 300;

/// The contextual strip at the map's top edge. Chrome, not content: it exists
/// only while something the player has named is off-screen.
const double _stripHeight = 22;

/// The kind glyph in the peek's well, at ×1 — `atlas_layout.json` authors
/// every kind marker at 20 × 20.
const double _peekGlyphSize = 20;

/// The sheet, and its grip, by name — so a test measures the thing the player
/// drags rather than whichever `ListView` happens to be inside it. The map's
/// visible height is `window.height − getRect(worldSheetKey).height`, and that
/// is the figure this screen is judged on.
const Key worldSheetKey = ValueKey<String>('world-sheet');
const Key worldSheetGripKey = ValueKey<String>('world-sheet-grip');

/// The contextual strip, by name. Absent from the tree entirely when nothing
/// the player named is off-screen — its absence is the assertion.
const Key worldContextStripKey = ValueKey<String>('world-context-strip');

double _sheetHeightFor(_SheetStop stop, double body) => switch (stop) {
  _SheetStop.peek => _sheetPeekHeight,
  _SheetStop.half => (body * _sheetHalfFraction).clamp(
    _sheetHalfMin,
    _sheetHalfMax,
  ),
  _SheetStop.full => body * _sheetFullFraction,
};

/// What [_ContextStrip] has to say, or nothing. A record, so an unchanged
/// camera compares equal and costs no rebuild.
typedef _StripState = ({
  String? selected,
  _Way selectedWay,
  bool hereOff,
  _Way hereWay,
});

const _StripState _noStrip = (
  selected: null,
  selectedWay: _Way.left,
  hereOff: false,
  hereWay: _Way.left,
);

/// Which edge of the visible map an off-screen marker lies past. Four, not
/// two: on a tall phone over a taller world, most of what leaves the window
/// leaves through the top or the foot, and a chip pointing right at a place
/// lying south is worse than no chip at all.
enum _Way { left, right, up, down }

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  /// The place the player tapped. Null means "the current location", which
  /// is what the sheet shows until a tap and again after every journey — so
  /// arriving somewhere shows *here*, not the place that was here.
  ContentId? _selected;

  /// Which stop the sheet rests at. **Peek is the opening move**: the map is
  /// the hero, and the sheet rises only when the player asks it to.
  _SheetStop _stop = _SheetStop.peek;

  /// Whether the player has panned or pinched the atlas this app run — the
  /// moment the how-to-look-around hint stops earning its row.
  bool _hasPanned = false;

  /// Set by the peek's compact `Travel`, which raises the sheet to half with
  /// the confirmation already asked. It is an edge, not a mode: the confirm
  /// still has to be answered, and `Set out · N steps` is still the only
  /// dispatch.
  bool _travelArmed = false;

  /// The sheet's height mid-drag, before it snaps. Null at rest.
  double? _dragHeight;

  /// Where the atlas camera is, read from the viewport after each pointer
  /// event. Read-only: moving the camera from here needs an addition to
  /// `atlas_viewport.dart`, which this team does not own (requested in
  /// `MILESTONES/evidence/EPO03/wave2/REQUESTS_NAV.md`, 2026-09-02).
  final GlobalKey<AtlasViewportState> _viewportKey =
      GlobalKey<AtlasViewportState>();

  _StripState _strip = _noStrip;

  // Carried from build so the pointer callbacks can recompute the strip
  // without asking the session again.
  /// The current location as of the last build — the edge that says a journey
  /// completed.
  ContentId? _lastCurrent;

  AtlasScene? _scene;
  AtlasNode? _selectedNode;
  int _selectedCost = 0;
  double _sheetHeight = _sheetPeekHeight;

  void _goTo(_SheetStop stop) {
    setState(() {
      _stop = stop;
      _dragHeight = null;
      if (stop == _SheetStop.peek) _travelArmed = false;
    });
  }

  /// A tap on the map — anywhere that is not a marker — drops the sheet to
  /// peek. Looking at the world is the gesture that clears the words off it.
  ///
  /// **Recognised at the pointer, not in the arena, and applied one microtask
  /// late.** A `GestureDetector` wrapped around the viewport cannot see this
  /// tap: `AtlasViewport`'s own scale recogniser is deeper in the tree, so it
  /// is first into the gesture arena and wins the sweep on any tap no marker
  /// claimed. A [Listener] sees every pointer regardless of the arena — but it
  /// sees them *before* the sweep, so it cannot yet know whether a marker took
  /// this one. Hence the microtask: [_onSelect] runs during the sweep and
  /// cancels the pending drop, so a marker tap selects without collapsing the
  /// sheet the player deliberately raised, and a tap on open country collapses
  /// it.
  Offset? _downAt;
  int _pointers = 0;
  bool _tapPending = false;

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    _downAt = _pointers == 1 ? event.position : null;
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    _syncStrip();
    final Offset? down = _downAt;
    _downAt = null;
    if (down == null) return;
    if ((event.position - down).distance > kTouchSlop) return;
    _tapPending = true;
    scheduleMicrotask(() {
      if (!_tapPending || !mounted) return;
      _tapPending = false;
      if (_stop == _SheetStop.peek && _dragHeight == null) return;
      _goTo(_SheetStop.peek);
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    _downAt = null;
  }

  /// A marker tap **updates the sheet and never raises it**; a sheet already
  /// at full comes down to half, because a new question deserves a fresh
  /// answer at the size the player last chose to read at.
  void _onSelect(ContentId id) {
    // A marker claimed this tap, so it is not a tap on the map.
    _tapPending = false;
    setState(() {
      _selected = id;
      _travelArmed = false;
      _dragHeight = null;
      if (_stop == _SheetStop.full) _stop = _SheetStop.half;
    });
  }

  void _onDragUpdate(DragUpdateDetails d, double body) {
    final double from = _dragHeight ?? _sheetHeightFor(_stop, body);
    setState(
      () => _dragHeight = (from - d.delta.dy).clamp(
        _sheetPeekHeight,
        _sheetHeightFor(_SheetStop.full, body),
      ),
    );
  }

  void _onDragEnd(DragEndDetails d, double body) {
    final double velocity = d.velocity.pixelsPerSecond.dy;
    final double height = _dragHeight ?? _sheetHeightFor(_stop, body);
    if (velocity.abs() > _sheetFlingVelocity) {
      const List<_SheetStop> order = _SheetStop.values;
      final int at = order.indexOf(_stop);
      _goTo(order[(at + (velocity < 0 ? 1 : -1)).clamp(0, order.length - 1)]);
      return;
    }
    _SheetStop nearest = _SheetStop.peek;
    double best = double.infinity;
    for (final _SheetStop stop in _SheetStop.values) {
      final double gap = (_sheetHeightFor(stop, body) - height).abs();
      if (gap < best) {
        best = gap;
        nearest = stop;
      }
    }
    _goTo(nearest);
  }

  /// Recomputes what the contextual strip says. It only calls `setState` when
  /// the answer actually changed — a pan that keeps both markers on screen
  /// costs one record comparison per pointer event.
  void _syncStrip() {
    final _StripState next = _readStrip();
    if (next == _strip) return;
    if (mounted) setState(() => _strip = next);
  }

  _StripState _readStrip() {
    final AtlasViewportState? viewport = _viewportKey.currentState;
    final AtlasScene? scene = _scene;
    final AtlasNode? selected = _selectedNode;
    if (viewport == null || scene == null || selected == null) return _noStrip;
    final RenderObject? object = _viewportKey.currentContext
        ?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return _noStrip;

    final Size window = object.size;
    // The map the player can actually see: the window above the sheet. A
    // marker behind the sheet is off-screen for this purpose, which is the
    // honest answer — it cannot be looked at.
    final double visible = (window.height - _sheetHeight).clamp(
      0.0,
      window.height,
    );
    final Offset camera = viewport.camera;
    final double zoom = viewport.zoom;

    ({bool off, _Way way}) locate(AtlasNode node) {
      final double x = (node.x - camera.dx) * zoom;
      final double y = (node.y - camera.dy) * zoom;
      final bool off = x < 0 || x > window.width || y < 0 || y > visible;
      // Whichever edge it left through, sides tested first: a place off the
      // side reads as a compass direction, where a place off the foot is as
      // often simply behind the sheet.
      final _Way way = x < 0
          ? _Way.left
          : x > window.width
          ? _Way.right
          : y < 0
          ? _Way.up
          : _Way.down;
      return (off: off, way: way);
    }

    final AtlasNode here = scene.current;
    final ({bool off, _Way way}) hereAt = locate(here);
    if (selected.id == here.id) {
      return (
        selected: null,
        selectedWay: _Way.left,
        hereOff: hereAt.off,
        hereWay: hereAt.way,
      );
    }
    final ({bool off, _Way way}) selectedAt = locate(selected);
    final String cost = _selectedCost > 0
        ? ' · ${formatSteps(_selectedCost)}'
        : '';
    return (
      selected: selectedAt.off ? '${selected.place.displayName}$cost' : null,
      selectedWay: selectedAt.way,
      hereOff: hereAt.off,
      hereWay: hereAt.way,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final AtlasScene? scene = AtlasScene.build(s);

    if (scene == null) return _ListFallback(problems: s.atlasLayoutProblems);

    // **Arrival returns the screen to the map.** Wherever the journey was
    // dispatched from — the sheet's own `Set out`, or the Adventure tracker's
    // door into this tab — landing somewhere new drops the sheet to peek on
    // *here*, because the first thing a player wants after a walk is to look
    // at where they have arrived. Written during build rather than through
    // `setState`, because it is a correction to the frame being built and a
    // `setState` here would schedule a second one for the same answer.
    final ContentId arrivedAt = scene.current.id;
    if (_lastCurrent != null && _lastCurrent != arrivedAt) {
      _selected = null;
      _stop = _SheetStop.peek;
      _dragHeight = null;
      _travelArmed = false;
    }
    _lastCurrent = arrivedAt;

    final AtlasNode selected =
        (_selected == null ? null : scene.nodeFor(_selected!)) ?? scene.current;

    // Resolved once per build, for every place on the surface, through the one
    // adapter this stream reads place detail with. The marker layer wants a
    // kind per node; nothing below it asks the session anything.
    final Map<ContentId, AtlasPlaceKind> kinds = <ContentId, AtlasPlaceKind>{
      for (final AtlasNode node in scene.nodes)
        node.id: AtlasPlaceInfo.kindOf(s, node.place),
    };
    // The preview: the roads the selected journey would use. Null for *here*
    // and for a place no chain of roads reaches, and nothing highlights then.
    final AtlasWay? way = scene.routeSummary(selected.id);

    _scene = scene;
    _selectedNode = selected;
    _selectedCost = way?.totalCost ?? 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double body = constraints.maxHeight;
        final double resting = _sheetHeightFor(_stop, body);
        final double height = _dragHeight ?? resting;
        _sheetHeight = height;
        // The camera centres the selection in the map *above* the sheet. At
        // peek that is very nearly the whole body, which is the point.
        final double bottomInset = resting.clamp(0.0, body);
        final bool stripShown = _strip.selected != null || _strip.hereOff;

        return Stack(
          children: <Widget>[
            // The atlas fills the whole area and continues behind the sheet.
            Positioned.fill(
              child: Listener(
                // Raw pointer events, so this never enters the gesture arena
                // the viewport's pan and pinch are decided in. It reads the
                // camera afterwards and recognises the map tap itself; it
                // never competes for the gesture.
                onPointerDown: _onPointerDown,
                onPointerMove: (_) => _syncStrip(),
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: AtlasViewport(
                  key: _viewportKey,
                  scene: scene,
                  selected: selected.id,
                  kinds: kinds,
                  way: way,
                  bottomInset: bottomInset,
                  // The pulse wears the warm arrival ink for as long as the
                  // journey's result line stands in the sheet (F4) — the
                  // same held report, so the two cannot disagree.
                  arrivalStanding: c.lastJourney?.succeeded ?? false,
                  // The walked legs, for the trace's multi-leg course —
                  // only a committed journey's, so a refused walk draws
                  // nothing new.
                  travelLegPlaces: c.lastJourney?.succeeded == true
                      ? c.lastJourney!.legPlaces
                      : null,
                  // The tracked Journey's destination wears its gold ring —
                  // read from the same goal projection the tracker card
                  // renders, so the map and the card cannot disagree.
                  journey: s.trackedGoals.journey?.destination,
                  onExplored: () {
                    if (!_hasPanned) setState(() => _hasPanned = true);
                    _syncStrip();
                  },
                  onSelect: _onSelect,
                ),
              ),
            ),

            // The strip, at the map's own top edge, only while something the
            // player named is off-screen. It never names the camera.
            if (stripShown)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _stripHeight,
                child: _ContextStrip(key: worldContextStripKey, state: _strip),
              ),

            // The translucent ramp above the sheet: pointer-transparent, so a
            // drag that begins in it pans the atlas.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: height,
              height: _sheetFadeHeight,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x0014120F), Color(0x9914120F)],
                    ),
                  ),
                ),
              ),
            ),

            // The sheet itself.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: 0,
              height: height,
              child: _WorldSheet(
                key: worldSheetKey,
                onGripTap: () => _goTo(
                  _stop == _SheetStop.peek ? _SheetStop.half : _SheetStop.peek,
                ),
                onDragUpdate: (DragUpdateDetails d) => _onDragUpdate(d, body),
                onDragEnd: (DragEndDetails d) => _onDragEnd(d, body),
                child: _stop == _SheetStop.peek && _dragHeight == null
                    ? _PeekRow(
                        scene: scene,
                        selected: selected,
                        way: way,
                        onTravel: () => setState(() {
                          _stop = _SheetStop.half;
                          _travelArmed = true;
                        }),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          StrideSpace.screenGutter,
                          StrideSpace.s4,
                          StrideSpace.screenGutter,
                          StrideSpace.s16,
                        ),
                        children: <Widget>[
                          if (s.isStale) ...<Widget>[
                            StaleBanner(busy: c.busy, onReload: c.reload),
                            const SizedBox(height: StrideSpace.s10),
                          ],
                          AtlasSelectionPanel(
                            scene: scene,
                            selected: selected,
                            bare: true,
                            // Half is the decision; full is the reading.
                            compact: _stop == _SheetStop.half,
                            travelArmed: _travelArmed,
                            onTravelled: () => setState(() {
                              _selected = null;
                              _travelArmed = false;
                              _stop = _SheetStop.peek;
                            }),
                          ),
                          // The pan/pinch tutorial line earns its place
                          // exactly once; after the first pan or pinch it
                          // stops renting a row (Fable V2 UX audit S8). It
                          // rents one only at the full stop, where there is
                          // room for a hint.
                          if (!_hasPanned &&
                              _stop == _SheetStop.full) ...<Widget>[
                            const SizedBox(height: StrideSpace.s8),
                            Text(
                              'Drag to look around; pinch to look closer. '
                              'Faint names are landmarks, not destinations.',
                              style: StrideType.micro.copyWith(
                                color: StrideColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The 22 dp strip at the map's top edge that says where an off-screen marker
/// lies — and **never** names the camera.
///
/// "Viewed location" was a fourth state with no word, no marker and no home,
/// and it was the confusion the owner asked to be fixed. It is not named here
/// either: the strip says *Whispering Woods · 1,000* with a caret pointing the
/// way, or *You are here* with one, and disappears the moment the marker it is
/// about comes back into the window.
///
/// The carets are drawn, not typed: a triangle from a painter renders the same
/// on every device and in the evidence harness, where a geometric-shapes
/// codepoint would depend on a fallback font.
///
/// **Not yet a control.** DIR-15 has these chips recentre the camera on tap.
/// `AtlasViewport` publishes no way to move its camera and belongs to no one
/// team this round; the addition is requested in `REQUESTS_NAV.md`
/// (2026-09-02). Until it lands the strip is a locator, which is the half of
/// its job that answers the owner's question.
class _ContextStrip extends StatelessWidget {
  const _ContextStrip({super.key, required this.state});

  final _StripState state;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xA014120F)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s10),
      child: Row(
        children: <Widget>[
          if (state.selected case final String label)
            Flexible(
              child: _StripChip(label: label, way: state.selectedWay),
            ),
          const Spacer(),
          if (state.hereOff)
            _StripChip(label: 'You are here', way: state.hereWay),
        ],
      ),
    ),
  );
}

class _StripChip extends StatelessWidget {
  const _StripChip({required this.label, required this.way});

  final String label;
  final _Way way;

  /// The caret leads the label when the place lies left or up and follows it
  /// when it lies right or down, so the chip reads outward — toward the thing
  /// it is about.
  bool get _leads => way == _Way.left || way == _Way.up;

  @override
  Widget build(BuildContext context) {
    final bool vertical = way == _Way.up || way == _Way.down;
    final Widget caret = CustomPaint(
      size: vertical ? const Size(10, 6) : const Size(6, 10),
      painter: _CaretPainter(way: way),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_leads) ...<Widget>[caret, const SizedBox(width: StrideSpace.s4)],
        Flexible(
          child: Text(
            label,
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!_leads) ...<Widget>[const SizedBox(width: StrideSpace.s4), caret],
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.way});

  final _Way way;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    switch (way) {
      case _Way.left:
        path
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height);
      case _Way.right:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height);
      case _Way.up:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height);
      case _Way.down:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = StrideColors.textSecondary);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.way != way;
}

/// The docked sheet: a grip, and whatever the stop asks for beneath it.
///
/// Translucent warm-brown "smoked parchment", never a blur — a
/// [BackdropFilter] over nearest-neighbour pixel art turns the posts to mush
/// and costs a raster every frame. There is **no scrim**: the map is the hero
/// and darkening it to make a sheet legible would be the same mistake in a
/// different currency.
class _WorldSheet extends StatelessWidget {
  const _WorldSheet({
    super.key,
    required this.child,
    required this.onGripTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Widget child;
  final VoidCallback onGripTap;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xC814120F), Color(0xF014120F)],
      ),
      border: Border(top: BorderSide(color: StrideColors.borderDefault)),
    ),
    child: Column(
      children: <Widget>[
        // The grip is the sheet's own control: drag it to any stop, tap it to
        // go up one from peek and all the way down from anywhere else.
        GestureDetector(
          key: worldSheetGripKey,
          behavior: HitTestBehavior.opaque,
          onTap: onGripTap,
          onVerticalDragUpdate: onDragUpdate,
          onVerticalDragEnd: onDragEnd,
          child: SizedBox(
            height: _sheetGripHeight,
            width: double.infinity,
            child: Center(
              child: KitOrnament(
                mark: KitMark.sheetGrip,
                fallback: Container(
                  width: 40,
                  height: 4,
                  color: StrideColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// The peek: one row, 52 dp under the grip, and the map above all of it.
///
/// It carries the whole vocabulary — the kind glyph, the name, `kind ·
/// status`, `Journey set` where it applies — and exactly one control: a
/// compact `Travel` that **arms the priced confirmation at the half stop**.
/// It does not travel. Nothing on this screen travels without `Set out`.
class _PeekRow extends StatelessWidget {
  const _PeekRow({
    required this.scene,
    required this.selected,
    required this.way,
    required this.onTravel,
  });

  final AtlasScene scene;
  final AtlasNode selected;
  final AtlasWay? way;
  final VoidCallback onTravel;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final AtlasPlaceInfo info = AtlasPlaceInfo.from(s, selected.place);
    final int banked = s.usableEnergy;
    final bool here = selected.id == scene.current.id;
    final bool journeyHere = s.trackedGoals.journey?.destination == selected.id;
    final AtlasWay? w = way;
    final bool affordable = w != null && w.totalCost <= banked;
    final bool open =
        w != null &&
        affordable &&
        s.missingEntryRequirementsFor(selected.place.id).isEmpty &&
        !c.busy &&
        s.isReady;

    // Three words that cannot be confused with one another: *You are here*,
    // *Reached* / *Not yet reached* for the selection, *Journey set* for the
    // tracked goal.
    final String status = <String>[
      info.kindWord,
      if (here)
        'You are here'
      else if (info.isUnlocked)
        'Reached'
      else
        'Not yet reached',
      if (journeyHere) 'Journey set',
    ].join(' · ');

    final AtlasLandmark? glyph = scene.layout.markerForKind(
      info.kind.markerKind,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        0,
        StrideSpace.screenGutter,
        StrideSpace.s4,
      ),
      child: Row(
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            KitPlate.well(
              frame: KitFrame.slotWell,
              contentWidth: _peekGlyphSize,
              contentHeight: _peekGlyphSize,
              child: PixelAsset(
                assetPath: AtlasAssets.pathFor(glyph.asset),
                nativeWidth: glyph.width,
                nativeHeight: glyph.height,
                scale: 1,
              ),
            ),
            const SizedBox(width: StrideSpace.s10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText(selected.place.displayName, style: StrideType.sub),
                AdaptiveText(
                  status,
                  style: StrideType.micro,
                  color: StrideColors.textSecondary,
                ),
              ],
            ),
          ),
          if (w != null) ...<Widget>[
            const SizedBox(width: StrideSpace.s8),
            const WalkingGlyph(role: WalkingRole.unit),
            const SizedBox(width: StrideSpace.s4),
            AdaptiveText(
              formatSteps(w.totalCost),
              style: StrideType.itemCount,
              color: affordable
                  ? StrideColors.textPrimary
                  : StrideColors.textMuted,
            ),
            const SizedBox(width: StrideSpace.s8),
            ConstrainedBox(
              // The accessibility floor, and the reach band's own width.
              constraints: const BoxConstraints(minWidth: 88, minHeight: 44),
              child: StrideButton.secondary(
                label: 'Travel',
                onPressed: open ? onTravel : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The pre-atlas presentation, kept whole for the day the layout is absent.
///
/// Every string and every rule here is the panel's; only the shape differs. It
/// is not a second implementation of travel — the rows and the panel share
/// `AtlasSelectionPanel.subtitleFor` and `TravelResultLine`.
class _ListFallback extends StatelessWidget {
  const _ListFallback({required this.problems});

  /// Why the atlas is absent. Rendered in debug only.
  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<RegionPlace> places = s.regionPlaces;

    return ListView(
      // Full-bleed map, gutters re-applied per child. Same reason as Adventure.
      padding: const EdgeInsets.only(bottom: StrideSpace.s16),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.screenGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: StrideSpace.s12),
              if (s.isStale) ...<Widget>[
                StaleBanner(busy: c.busy, onReload: c.reload),
                const SizedBox(height: StrideSpace.cardGap),
              ],
              // A packaging fault, said out loud where a developer will see it
              // and nowhere a player will. Release builds show the list and
              // nothing else.
              if (kDebugMode && problems.isNotEmpty) ...<Widget>[
                SurfaceBlock(
                  child: Text(
                    'World Atlas layout unavailable (debug):\n'
                    '${problems.map((String p) => '· $p').join('\n')}',
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: StrideSpace.cardGap),
              ],
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(label: 'Travel from here'),
                    const SizedBox(height: StrideSpace.s10),
                    if (s.destinations.isEmpty)
                      Text(
                        'No route leads anywhere from here.',
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textMuted,
                        ),
                      ),
                    for (final TravelOption option in s.destinations)
                      _DestinationRow(option: option),
                    if (c.lastJourney != null) ...<Widget>[
                      const SizedBox(height: StrideSpace.s8),
                      TravelResultLine(journey: c.lastJourney!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: StrideSpace.cardGap),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(label: 'This region'),
                    const SizedBox(height: StrideSpace.s10),
                    for (final RegionPlace place in places)
                      _PlaceRow(place: place),
                    const SizedBox(height: StrideSpace.s4),
                    Text(
                      'Every place in the region. Routes run only between '
                      'neighbours, so some are reached by way of another.',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StrideSpace.cardGap),
            ],
          ),
        ),
        // The map as a picture, captioned on its lower edge. Still no hit
        // testing here: in the fallback there is no layout to place a target
        // by, and a caption is what a picture gets.
        PixelScene.regionMap(
          PixelIcons.regionMap,
          overlay: Align(
            alignment: Alignment.bottomLeft,
            child: _CurrentPlaceBar(places: places),
          ),
        ),
      ],
    );
  }
}

/// `YOU ARE HERE · Haven's Rest`, on the map's own lower edge.
///
/// A caption, not a control: no border, no fill that reads as a chip, nothing
/// tappable. Set as a label above a name — the pattern every read-only figure
/// in the app uses — rather than as a pin or a button.
class _CurrentPlaceBar extends StatelessWidget {
  const _CurrentPlaceBar({required this.places});

  final List<RegionPlace> places;

  @override
  Widget build(BuildContext context) {
    RegionPlace? here;
    for (final RegionPlace place in places) {
      if (place.isCurrent) here = place;
    }
    if (here == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s16,
        StrideSpace.screenGutter,
        StrideSpace.s10,
      ),
      // A gradient, not a plate, and three stops rather than two: the map's
      // lower edge is lit canopy, and a two-stop fade reaches only a third of
      // its opacity where the label sits.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x00000000),
            Color(0xC414120F),
            Color(0xF214120F),
          ],
          stops: <double>[0, 0.42, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('YOU ARE HERE', style: StrideType.microLabel, maxLines: 1),
          const SizedBox(height: StrideSpace.s2),
          // `textPrimary`, never teal (L-16): the label above carries the
          // emphasis.
          AdaptiveText(here.displayName, style: StrideType.cardTitle),
        ],
      ),
    );
  }
}

/// One journey the player could set out on, as a row. Fallback only; the
/// atlas panel is the same control in the same words.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.option});

  final TravelOption option;

  @override
  Widget build(BuildContext context) {
    final SessionController watched = SessionScope.of(context);
    final SessionController controller = SessionScope.read(context);
    final int banked = watched.session.usableEnergy;
    final bool enabled =
        option.canTravel && !watched.busy && watched.session.isReady;
    final String? reason = AtlasSelectionPanel.subtitleFor(option, banked);
    final String places = option.resourceCount == 1
        ? '1 resource'
        : '${option.resourceCount} resources';

    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  option.displayName,
                  style: StrideType.itemName,
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              const WalkingGlyph(role: WalkingRole.unit),
              const SizedBox(width: StrideSpace.s4),
              AdaptiveText(
                formatSteps(option.stepCost),
                style: StrideType.itemCount,
                color: option.affordable
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          AdaptiveText(
            reason ??
                (option.isReached
                    ? '${AtlasSelectionPanel.terrainWord(option.terrain)} · '
                          '$places'
                    : 'Not yet reached · '
                          '${AtlasSelectionPanel.terrainWord(option.terrain)} · '
                          '$places'),
            style: StrideType.micro,
            color: StrideColors.textMuted,
          ),
          const SizedBox(height: StrideSpace.s8),
          // Promoted to the commit register: this row's Travel is the same
          // spend the atlas panel's Set out is, and the two read as one
          // action now (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
          StrideButton(
            label: watched.busy ? 'Travelling…' : 'Travel',
            onPressed: enabled ? () => controller.travel(option.id) : null,
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final RegionPlace place;

  @override
  Widget build(BuildContext context) {
    final String detail = <String>[
      if (place.isCurrent)
        'You are here'
      else if (!place.isUnlocked)
        'Not yet reached',
      if (place.isSafe) 'Safe',
      if (place.resourceCount == 1)
        '1 resource'
      else if (place.resourceCount > 1)
        '${place.resourceCount} resources',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  place.displayName,
                  style: StrideType.sub.copyWith(
                    color: StrideColors.textPrimary,
                    // Weight marks the current place, never a hue.
                    fontWeight: place.isCurrent
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: StrideType.micro, maxLines: 2),
              ],
            ),
          ),
          if (place.stepCostFromHere case final int cost) ...<Widget>[
            const SizedBox(width: StrideSpace.s8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Muted, never teal (L-16): this is a distance.
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.iconLabelGap),
                Text(formatSteps(cost), style: StrideType.micro),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
