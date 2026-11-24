# Changelog

All notable changes to Velatus are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-11-24

The "it should feel like a normal app" release. Everything here came from using
the 0.3.0 build on a real phone.

### Fixed

- Dragging one block of a multi-selection no longer drags the whole set. The
  block under your finger moves; the others stay put and stay selected.
- A corner dragged past the opposite corner now flips the box into that
  quadrant instead of collapsing it into a line and shoving it around. The
  anchor is captured once when the drag starts, and the press point — not the
  position after the touch slop — is what decides which handle you grabbed.
- Exporting and then closing the editor no longer asks "leave without
  exporting?". Editing afterwards arms the warning again.
- The leave-confirmation dialog uses a smaller title and secondary body text.
- The app opens with the tool and parameters you used last: brush or box,
  mosaic / blur / solid, size, strength, corner radius and colour.

### Added

- Traditional Chinese, Spanish and French. The language picker is a dialog with
  every language written in its own words.
- The in-app icon is now the same artwork as the launcher icon.

### Changed

- Settings: Privacy moved to the bottom, where a statement belongs, and the
  language row opens a picker instead of listing five radios.
- "Follow system" is now just "System", which fits in every language.
- Copy is written for people rather than for a spec: 落地 is 确认, and the
  "no account" lines are gone — there is nothing to announce.

## [0.3.0] — 2026-11-24

The "pick what to hide" release.

### Added

- A scan pass that proposes text, chat avatars and QR codes as candidate boxes.
  Nothing is applied until you confirm, and the boxes stay editable afterwards.
- Multi-selection: tap to add, tap again to remove, and restyle the whole set at
  once.
- In-app update check with a download and an Android install prompt, plus
  mirrors for networks where GitHub is slow.

### Changed

- Rectangle and rounded rectangle merged into one box tool with a radius slider;
  they were the same geometry with a different corner.
- Re-running a scan replaces the previous detection instead of stacking another
  layer on top of it.
- The tool dock is a fixed two-row height in every state.
- Blur reaches a genuinely strong setting, and the canvas can zoom further out.
- Per-ABI APKs: the download went from 86 MB to 33 MB with no feature removed.

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
