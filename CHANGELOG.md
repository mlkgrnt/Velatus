# Changelog

All notable changes to Velatus are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-11-24

The "one block, one object" release. Feedback from the first build reshaped how
the editor works rather than just polishing it.

### Changed

- Masks are the unit of work. The layer panel is gone; tap any mask to select
  it, drag to move it, and pull a corner to resize it. Everything a layer panel
  used to offer — delete, restyle, re-strength — is one tap away from the block
  itself.
- Mosaic and blur are now sampled through the mask path with an image shader
  instead of an offscreen `dstIn` layer. A brush stroke stays round, a rectangle
  stays a rectangle, and the strength slider no longer changes how much of the
  photo is covered.
- The bottom bar is two layers: tools on top, one context row underneath. The
  brush size and strength are stacked sliders, so the colour swatches finally
  fit on a phone.
- The home screen shows the three selling points as one divided card on phones
  instead of three stacked boxes.
- Offline OCR is Chinese + Latin only. The Devanagari and Japanese models are
  no longer pulled in.

### Added

- Rounded-rectangle tool.
- Custom colour picker (HSV pad plus hue strip) on top of the fixed swatches.
- Corner handles for resizing a selected mask, including brush strokes.
- "Check for updates" and "Source code" entries in Settings. Both open the
  system browser, so the app still ships without a network permission.
- Delete / Escape shortcuts in the editor.

### Removed

- Ellipse and lasso tools. Both were rarely the right shape for a redaction and
  they made selection ambiguous.
- The layer panel, its visibility toggles and the layer reordering UI.
- Devanagari OCR.

## [0.1.0] — 2026-11-24

First public build.

### Added

- Non-destructive mask objects with mosaic, Gaussian blur, and solid styles.
- Brush, rectangle, ellipse, and lasso selection tools.
- Layer panel with per-mask visibility, deletion, and one-tap clearing.
- Undo/redo history (60 steps) and hold-to-compare with the original.
- Pinch, wheel, and double-tap zoom; middle-drag panning on desktop.
- Offline Chinese + Latin text detection on Android (ML Kit bundled model),
  with one-tap batch coverage.
- JPEG and PNG export at full source resolution, with EXIF stripped.
- Save to gallery on Android and a native save dialog on Windows.
- Material 3 interface with light/dark themes, English and Simplified Chinese.
- Recent files list that survives restarts.
- GitHub Actions CI for analyze, test, Android, and Windows builds.
