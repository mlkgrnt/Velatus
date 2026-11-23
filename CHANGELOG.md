# Changelog

All notable changes to Velatus are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
