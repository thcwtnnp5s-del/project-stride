/// The audio settings, on the Character tab (AUDIO_PRESENTATION_01).
///
/// Three controls and no more — the integration brief's "do not expose
/// excessive settings complexity": sound on/off, music volume, effects
/// volume. Ambience has a bus and a stored volume but no content and
/// therefore **no control**; a slider for silence would be a promise the
/// build does not keep.
///
/// Volumes step in tenths through the − / + pair rather than a `Slider`:
/// every control in this product is a discrete pixel-styled tap target
/// (`StrideButton`), the screens deliberately import `widgets` and not
/// `material`, and ten steps is the whole resolution a phone speaker's
/// volume choice needs.
///
/// Everything here reads and writes [AudioController] through `AudioScope`
/// — presentation preferences, persisted by the controller's own store,
/// nowhere near the game save (`RULES.md` E-2 has no subject here: no game
/// state exists on this block).
///
/// ## A footnote, not a card (EPO03, `DIR-05`)
///
/// It was a [SectionCard]: a dark rounded rectangle holding three
/// preferences, at the same weight as the figures the sheet is actually
/// about. It is now a **footnote on the folio** — a [KitRule] title and three
/// lines on the page's own ground. Nothing it controls changed.
library;

import 'package:flutter/widgets.dart';

import '../../components/data_display.dart';
import '../../components/surfaces.dart';
import '../../state/audio_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class AudioBlock extends StatelessWidget {
  const AudioBlock({super.key});

  @override
  Widget build(BuildContext context) {
    // `of`, subscribing: the percentages and the toggle label re-render as
    // the controller notifies.
    final AudioScope scope = context
        .dependOnInheritedWidgetOfExactType<AudioScope>()!;
    final settings = scope.notifier!.settings;
    final bool on = settings.enabled;

    final bool haptics = settings.hapticsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const KitRule(title: 'Sound & feel'),
        const SizedBox(height: StrideSpace.rhythmRow),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                on ? 'Sound is on' : 'Sound is off',
                style: StrideType.sub.copyWith(
                  color: on ? StrideColors.textPrimary : StrideColors.textMuted,
                ),
                maxLines: 1,
              ),
            ),
            StrideButton.secondary(
              label: on ? 'Turn off' : 'Turn on',
              onPressed: () => AudioScope.read(context).setEnabled(!on),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.s10),
        _VolumeRow(
          label: 'MUSIC',
          value: settings.musicVolume,
          enabled: on,
          onChanged: (double v) => AudioScope.read(context).setMusicVolume(v),
        ),
        const SizedBox(height: StrideSpace.s6),
        _VolumeRow(
          label: 'EFFECTS',
          value: settings.sfxVolume,
          enabled: on,
          onChanged: (double v) => AudioScope.read(context).setSfxVolume(v),
        ),
        const SizedBox(height: StrideSpace.s10),
        // Haptic punctuation (Fable V2 Iteration 02): its own switch,
        // independent of the sound master — a silent commute still wants
        // the tap of a level-up, and vice versa.
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                haptics ? 'Vibration is on' : 'Vibration is off',
                style: StrideType.sub.copyWith(
                  color: haptics
                      ? StrideColors.textPrimary
                      : StrideColors.textMuted,
                ),
                maxLines: 1,
              ),
            ),
            StrideButton.secondary(
              label: haptics ? 'Turn off' : 'Turn on',
              onPressed: () =>
                  AudioScope.read(context).setHapticsEnabled(!haptics),
            ),
          ],
        ),
      ],
    );
  }
}

/// One bus: its name, its level in tenths, and the pair that moves it.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Tenths, presented as a percentage. Rounding keeps a stored 0.55 (the
    // first-launch music default) stepping to 0.5/0.6 rather than sticking.
    final int tenths = (value * 10).round().clamp(0, 10);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: StrideType.microLabel.copyWith(
              color: enabled
                  ? StrideColors.textSecondary
                  : StrideColors.textMuted,
            ),
            maxLines: 1,
          ),
        ),
        StrideButton.secondary(
          label: '−',
          onPressed: enabled && tenths > 0
              ? () => onChanged((tenths - 1) / 10)
              : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${tenths * 10}%',
            textAlign: TextAlign.center,
            style: StrideType.sub.copyWith(
              color: enabled
                  ? StrideColors.textPrimary
                  : StrideColors.textMuted,
            ),
            maxLines: 1,
          ),
        ),
        StrideButton.secondary(
          label: '+',
          onPressed: enabled && tenths < 10
              ? () => onChanged((tenths + 1) / 10)
              : null,
        ),
      ],
    );
  }
}
