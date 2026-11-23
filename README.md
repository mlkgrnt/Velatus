# Velatus · 隐格

**Cover what should stay private.**
A local-first redaction tool for screenshots and photos — Android and Windows, built with Flutter and Material 3.

[中文说明](README.zh-CN.md)

---

Most mosaic apps treat a redaction as a brush stroke burned into pixels: the
moment you lift your finger, the only way back is undo. Velatus treats every
patch as an **editable object** — change its strength, hide it, delete it, or
come back to it later. And because the preview and the export share one
renderer, what you see is exactly what gets written to disk.

## What it looks like

<p align="center">
  <img src="docs/screenshots/home_light.png" alt="Velatus home screen" width="100%">
</p>

| Phone | Desktop |
|---|---|
| <img src="docs/screenshots/editor_mobile.png" alt="Editor on a phone" width="300"> | <img src="docs/screenshots/editor_desktop.png" alt="Editor on a desktop" width="620"> |

The mobile shot has a blur patch over a phone number and a mosaic band over an
address; the desktop shot adds a solid bar. Every one of them is still a layer
you can select, re-strength or delete.

## Why another one

- **Nothing leaves the device.** The release build asks for no network
  permission at all. There is no account, no analytics, no cloud sync.
- **Masks are objects, not pixels.** Mosaic, blur, and solid patches stay
  separate layers with their own strength and geometry.
- **Text detection is offline.** Android uses ML Kit's bundled Chinese + Latin
  model to find text blocks and cover them in one tap.
- **EXIF is stripped by design.** Exports are re-encoded from raw pixels, so
  GPS coordinates, device model, and timestamps never make it into the file.
- **Same output at any resolution.** Mask sizes are stored relative to the
  image, so the 4K export matches the preview instead of turning into soup.
- **Comfortable on both screens.** A bottom tool dock on phones, a persistent
  layer panel on desktop, mouse-wheel zoom and keyboard shortcuts on Windows.

## Features

| | |
|---|---|
| Mask styles | Mosaic, Gaussian blur, solid color |
| Shapes | Brush, rectangle, ellipse, freehand lasso |
| Text detection | One-tap detection and batch coverage (Android, offline) |
| Editing | Undo/redo, per-mask hide, delete, clear all, hold-to-compare |
| Canvas | Pinch zoom, wheel zoom, double-tap zoom, middle-drag pan |
| Export | JPEG (quality 60–100) or PNG, gallery or file picker |
| Privacy | No network permission, no backup, EXIF removed |
| Interface | Material 3, light/dark, English and 简体中文 |

## Install

### Android

Download the APK from [Releases](../../releases) and install it. Android 7.0
(API 24) or newer. The first launch of text detection may take a second while
ML Kit loads its bundled model.

### Windows

Download the zip from Releases, unpack it, and run `velatus.exe`.
Windows 10 or newer.

### Build from source

```bash
flutter pub get
flutter run -d android      # or: flutter run -d windows
flutter build apk --release
flutter build windows --release
```

Requirements: Flutter 3.50+, Android SDK 36, JDK 21. Windows builds need
Visual Studio 2022 with the Desktop development with C++ workload and the
Windows 10/11 SDK.

Release APKs are signed with the debug key committed at
`android/app/debug.keystore`. That is the standard, public Android debug key —
it exists so a sideloaded build can be upgraded in place instead of failing with
a signature mismatch. Generate a private key before publishing to a store.

## How it works

Velatus keeps two copies of the image: a preview capped at 2400 px for
interaction, and the original file for export. On export it re-decodes the
source at full resolution, replays the same `CustomPainter` into an offscreen
`Picture`, and encodes the result. Mosaic blocks are produced by shrinking the
source into a tiny offscreen texture and drawing it back with nearest-neighbour
filtering, which is both fast and resolution-independent. Blur uses
`ImageFilter.blur` with a sigma derived from the image's shorter side.

Because nothing is ever written back into the original bitmap, masks remain
fully reversible until the moment you export.

### Project layout

```
lib/
  domain/        mask geometry and hit testing
  services/      image loading, rendering, export, OCR, persistence
  features/
    home/        import screen and recent files
    editor/      canvas, controller, tool dock, layers, export sheet
    settings/    theme, language, privacy
  l10n/          ARB sources and generated localizations
```

## Privacy

Velatus has no servers. The Android release manifest explicitly removes the
`INTERNET` permission, so even an accidental network call would fail. Backups
are disabled. Export re-encodes pixels and therefore drops all EXIF metadata,
including GPS.

Verify it yourself:

```bash
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

## Roadmap

- [ ] Project files (`.velatus`) so a session can be reopened
- [ ] Batch processing with reusable mask templates
- [ ] OCR on Windows through a bundled Tesseract model
- [ ] More languages (the ARB structure is ready)
- [ ] Crop and rotate

## Contributing

Issues and pull requests are welcome. Run `flutter analyze` and `flutter test`
before sending a patch; both are enforced in CI.

The images in `docs/screenshots/` are golden files, not hand-made mockups:

```bash
flutter test --update-goldens tool/screenshots_test.dart
```

They are rendered by the real widgets at 430×932 and 1280×860, which means an
unintended visual change shows up as a diff instead of slipping through.

## License

MIT. See [LICENSE](LICENSE).

Velatus is Latin for "covered". The Chinese name 隐格 means "the grid that
hides".
