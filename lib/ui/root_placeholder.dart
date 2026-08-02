import 'package:flutter/material.dart';
import 'package:stride_core/stride_core.dart';

/// Proves the app launches and links `stride_core`.
///
/// Deliberately plain. This is not a design, not a draft of the Adventure
/// screen, and not a preview of the visual identity — that work is P-01 and
/// P-02, and starting it here would put UI decisions ahead of the review that
/// owns them.
class RootPlaceholder extends StatelessWidget {
  const RootPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Project Stride', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Foundation skeleton — M-2',
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Reading a value from stride_core proves the app actually links
            // the package rather than merely declaring it.
            Text(
              'stride_core ${StrideCore.version}',
              style: text.bodySmall?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
