# Changelog

All notable changes to Velatus are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.4] — 2026-11-24

### Fixed

- **Every avatar box is a square in pixel space.** The shape check used to
  return the tight bounding box of the foreground blob; for a disc or a line
  drawing that is nearly always slightly wider than tall. Boxes are now
  centred on the object but keep the sweep window's side length, which also
  keeps a pale avatar's low-contrast border inside the mask. Overlapping
  squares from nearby sweep positions are merged at output time.

### Changed

- **Low-contrast avatars are recoverable.** On a reported real screenshot the
  pale line-art avatars were only ~42–57 colour units from the page, below the
  foreground threshold of 60, so the main map saw nothing but a few strokes.
  Gradient density is the useful signal there: a line drawing measures 30–47
  where a flat background and a plain white bubble measure 0. A second,
  gentler foreground map (threshold 35) and its integral image are built in
  the same linear pre-processing pass, and consulted **only along the two
  confirmed avatar columns** — a white bubble is the same distance from the
  page as a white avatar, so using it near the middle would light every
  bubble up. On that 1440×1708 screenshot the left column went from 0 of 7
  avatars to all 7; together with the 2 outgoing ones the detector returns 9
  square boxes.
- The 360×640 benchmark stays at 13–15 ms (original flood-fill detector:
  14.5 ms). The larger 540×640 real screenshot takes ~36 ms because the
  gentle channel adds one more pass; it still runs once in a background
  isolate.

### Added

- Regression tests asserting square boxes in pixel space and a pale line-art
  avatar column. Full suite: 92 tests.

## [0.4.3] — 2026-11-24

### Changed

- Avatar detection now uses the layout of a chat screenshot as a prior. Once
  one marginal avatar is confirmed, its size, its margin, the **mirrored**
  margin on the other side and a 4×4 colour signature become a template, and
  the whole image is swept along those two columns. A lone outgoing avatar —
  which no repetition rule could ever find — is now recovered: the project's
  synthetic chat went from 3 to **5 avatars** (all of them), still with no
  false positives.
- Added an adaptive pre-processing pass: the dominant page colour is estimated
  once, every pixel is normalised into a foreground/distance map, and five
  summed-area tables (luminance, chroma, gradient, colour distance,
  foreground) make every window query O(1). Quiet-row analysis also finds the
  flat status/app/input strips so the seed sweep skips them.
- The seed sweep is gated so it stays fast: a strict shape check runs first,
  and the 4×4 signature is only computed when the whole-window colour is
  already close to the template. Despite the extra sweep the pass measures
  **14.0 ms** on a 360×640 image — slightly faster than the original 14.5 ms
  detector.

### Added

- Regression tests for a single outgoing avatar on the mirrored margin and for
  flat status/input bars. Full suite: 91 tests.

## [0.4.2] — 2026-11-24

### Changed

- Avatar detection was rebuilt with classical image processing. Integral
  images of luminance, chroma and a 2-tap gradient replace the old "busy square
  on a perfectly flat ring" test; a projection and compactness check now
  accepts square, rounded-square and round avatars, including smooth gradients
  and photos. A single-bin DFT (Goertzel) cross-checks the repeating pitch of a
  chat column and re-tests positions the coarse sweep missed. On the synthetic
  chat screenshot this went from 0 detected avatars to 3 with no false
  positives, and the pass got slightly faster (14.5 ms → ~12.5 ms at 360 × 640).
  The dominant page colour is estimated once from a colour histogram, so white
  or green bubbles no longer get mistaken for avatars.
- The eye in the editor is a real comparison control now: tap to pin the
  original, tap again to return, hold to peek at the other side. It shows a
  visible badge and drops out of the original view on the first canvas touch,
  because outlines and handles are hidden in that view.
- Mosaic and blur strength can go all the way to **0**. At that end the mask
  leaves the pixels untouched and allocates no offscreen texture — important
  at export resolution — while the region stays editable.

### Added

- Regression coverage for circular, square, rounded-square, photo-textured and
  green-bubble avatars, plus a timing assertion keeping the detector in the
  same speed class. Full suite: 89 tests.

## [0.4.1] — 2026-11-24

### Changed

- Exports start at quality 100. There is no reason to throw away detail at the
  very last step; the slider is still there if a smaller file matters more.
- The export sheet remembers JPEG/PNG, quality and the destination (gallery or
  Downloads on Android). On desktop the save dialog reopens in the folder where
  the last image landed.

### Added

- Windows ships as one portable exe as well as the plain zip. A tiny launcher
  with the release folder embedded unpacks once into `%LOCALAPPDATA%\Velatus\<version>`
  and then runs velatus.exe; no installer, no admin rights. Flutter itself
  cannot be statically linked into a single PE, so this is the honest way to
  get a one-file download.
- A README in five languages: Simplified Chinese, Traditional Chinese, English,
  Spanish and French.

### Fixed

- Parameter sliders work before the first mask is drawn. The setters used to
  notify the UI only from inside the "apply to selection" helpers, so with an
  empty document the controller changed while the thumb stood still.
- Two sliders no longer move together. Each has a stable key, so switching
  between brush width, corner radius and solid colour no longer recycles one
  Slider's State — including its cached drag value — into a different parameter.
- A stored preset outside the slider ranges is clamped when read back, so the
  first drag does not jump. The preset is a JSON preference, not a database.
- Picking a solid colour now refreshes the swatch even with nothing selected.

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
