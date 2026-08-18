/// The only place an atlas asset path string appears.
///
/// `atlas_layout.json` names art by **key** — `world/region_map`,
/// `world/landmark_havens_rest`, `env/cloud_a` — and this table turns a key
/// into a path under the packaged art root. The layout therefore never carries
/// a path, `PixelIcons` never carries the atlas, and moving the art is one
/// edit here rather than one per JSON entry.
///
/// ## The contract the art stream fills
///
/// Every file is a PNG under `assets/art/v1/`, packaged by
/// `Scripts/art/package-art.js` and declared file by file in `pubspec.yaml`
/// (the integration lead adds those lines; nothing here does). Native sizes are
/// declared in the layout, beside the key, and drawn at `AtlasLayout.scale`
/// nearest-neighbour — so a mismatch between the JSON size and the PNG header
/// is a packaging fault that `PixelAsset` makes visible in debug.
///
/// - **Base tiles** — key `world/<name>` → `assets/art/v1/world/<name>.png`.
///   One image today (`world/region_map`, 384 × 640); a grid of tiles later,
///   each with its own `x, y, width, height` in native pixels.
/// - **Landmarks** — key `world/landmark_<slug>` →
///   `assets/art/v1/world/landmark_<slug>.png`. 48–96 px square, transparent
///   background, with the anchor pixel recorded in the layout.
/// - **Overlay frame sequences** — key `env/<name>` →
///   `assets/art/v1/env/<name>_f0.png … _f<n-1>.png`. 32–96 px, transparent,
///   4–8 loop frames, all the same size.
library;

abstract final class AtlasAssets {
  const AtlasAssets._();

  /// Packaged game art. Same root as `PixelIcons._art`, restated here rather
  /// than shared so the two tables stay independently editable.
  static const String _art = 'assets/art/v1';

  /// The path of a single-image asset named by [key].
  static String pathFor(String key) => '$_art/$key.png';

  /// The path of frame [index] of the sequence named by [key].
  static String framePath(String key, int index) => '$_art/${key}_f$index.png';

  /// Every frame of the sequence named by [key], in order.
  static List<String> framePaths(String key, int count) => <String>[
    for (int i = 0; i < count; i++) framePath(key, i),
  ];
}
