import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Finds chat avatars with plain image processing — no model, no plugin.
///
/// The layout of a chat screenshot is a strong prior: a status bar, an app bar,
/// message bubbles, an input box — and avatars that only ever sit in the left
/// or right margin, all at the same size. The detector uses that prior in four
/// stages:
///
///  1. **Adaptive pre-processing.** The dominant page colour is estimated once
///     from a colour histogram; every pixel is then turned into its distance
///     from that colour and a binary foreground map. Integral images of
///     luminance, chroma, a 2-tap central-difference gradient, colour distance
///     and foreground make every later window query O(1). A quiet-row scan also
///     finds the flat status/app/input strips, so the seed sweep skips them.
///  2. **Shape by projection.** A disc, a square and a rounded square all give
///     one long connected run covering most of their bounding box; a line of
///     text gives a comb. Corner occupancy tells the three apart — all three
///     are accepted.
///  3. **Regularity in the frequency domain.** Chat avatars repeat down a
///     column. The pitch comes from the gaps, is cross-checked with a
///     single-bin DFT (Goertzel), and positions bracketed by two confirmed
///     avatars are re-tested.
///  4. **Seed-driven reinforcement.** Once one high-confidence avatar exists,
///     stop treating every position as an independent guess. Its size, its
///     margin, a 4×4 colour signature and the *mirrored* margin on the other
///     side become a template, and the whole image is swept along those two
///     columns. This is what recovers an avatar that appears only once — the
///     outgoing one on the right — which no repetition rule can ever find.
///  5. **Column geometry.** Avatars in one column are stamped with the same
///     left edge and the same side length. The median of each column replaces
///     every individual measurement, both before the sweep (a steadier seed
///     and mirrored margin) and on the way out (no cropped or drifting box).
///
/// Cost stays O(pixels) plus a small O(candidates²) for clustering; the column
/// pass is O(candidates log candidates) over a dozen boxes. Everything runs in
/// a background isolate.
class AvatarDetector {
  const AvatarDetector._();

  /// Longest side of the bitmap the detector works on.
  static const int analysisSide = 640;

  /// Colour distance from the page background that counts as "content".
  /// A white chat bubble is ~51 units from the usual light grey page, so 60
  /// keeps bubbles as background while coloured avatars (hundreds of units)
  /// stay firmly foreground.
  static const double foregroundThreshold = 60.0;

  /// Second, gentler threshold used *only* along the confirmed avatar columns.
  /// A white or line-art avatar can be as little as ~57 colour units from a
  /// light grey page, below [foregroundThreshold]. A white bubble is the same
  /// distance away, which is why this map is never consulted in the middle of
  /// the image — there it would light every bubble up.
  static const double lowContrastThreshold = 35.0;

  static List<Rect> find(Uint8List rgba, int width, int height) {
    if (width < 48 || height < 48) return const <Rect>[];
    final p = _Pyramid(rgba, width, height);
    final coarse = _coarse(p);
    if (coarse.isEmpty) return const <Rect>[];

    final verified = <_Box>[];
    for (final box in coarse) {
      final checked = _verify(p, box.rect, 1.0);
      if (checked != null) verified.add(checked);
    }
    if (verified.isEmpty) return const <Rect>[];

    // Pixel-space boxes, so the reinforcement pass can reuse the same
    // integral images instead of re-decoding anything.
    final clustered = _regularizeBoxes(p, verified);
    if (clustered.isEmpty) return const <Rect>[];
    // Only a marginal box is confident enough to be a template. The clustered
    // set can still contain a "regular column" in the middle of the bubbles;
    // its median x would drag the mirrored anchor away from the real margin.
    // Aligning the column *before* the sweep means the seed size and the
    // mirrored margin are a column consensus rather than one lucky window.
    final seeds = _alignColumns(p, _marginal(p, clustered));
    if (seeds.isEmpty) return const <Rect>[];
    for (final found in _reinforce(p, seeds)) {
      _add(seeds, found);
    }
    // The sweep can still produce a slightly different size or x for a pale
    // avatar. The column prior is stronger than any single window: enforce it
    // once more on the way out so every box in a column is identical.
    return _finish(p, _alignColumns(p, seeds));
  }

  // ------------------------------------------------------------------ sweep

  static List<_Box> _coarse(_Pyramid p) {
    final w = p.width;
    final h = p.height;
    final short = math.min(w, h);
    final sizes = <int>{
      // 20 px windows were the source of most false positives: a bold glyph
      // cluster is exactly that size. On a 640 px analysis bitmap a real chat
      // avatar is 30–55 px, so starting here costs no recall and saves a sweep.
      for (final fraction in const [0.08, 0.095, 0.115, 0.135, 0.16])
        math.max(14, (short * fraction).round()),
    };

    final out = <_Box>[];
    for (final size in sizes) {
      final step = math.max(3, size ~/ 4);
      final ring = math.max(2, size ~/ 8);
      // Avatars line up in the left or right margin. Restricting the sweep is
      // what keeps this pass cheap; the middle of a screenshot is content.
      for (final strip in <(int, int)>[
        (0, math.max(0, (w * 0.42).round() - size)),
        ((w * 0.58).round(), math.max(0, w - size)),
      ]) {
        if (strip.$2 <= strip.$1) continue;
        for (var y = ring; y + size + ring <= h; y += step) {
          for (var x = strip.$1; x <= strip.$2; x += step) {
            final ox0 = math.max(0, x - ring);
            final oy0 = math.max(0, y - ring);
            final ox1 = math.min(w, x + size + ring);
            final oy1 = math.min(h, y + size + ring);
            final inner = size * size;
            final outer = (ox1 - ox0) * (oy1 - oy0);
            final band = outer - inner;
            if (band < 8) continue;

            final iL = p.sum(p.iiLum, x, y, x + size, y + size);
            final iC = p.sum(p.iiChroma, x, y, x + size, y + size);
            final iE = p.sum(p.iiEdge, x, y, x + size, y + size);
            final oL = p.sum(p.iiLum, ox0, oy0, ox1, oy1);
            final oC = p.sum(p.iiChroma, ox0, oy0, ox1, oy1);
            final oE = p.sum(p.iiEdge, ox0, oy0, ox1, oy1);

            final inLum = iL / inner;
            final ringLum = (oL - iL) / band;
            final inChroma = iC / inner;
            final ringChroma = (oC - iC) / band;
            final inEdge = iE / inner;
            final ringEdge = (oE - iE) / band;

            // Colour distance carries the smooth-gradient case: a gradient
            // avatar has almost no internal gradient, but it is strongly
            // coloured against a grey chat background. Edge density carries
            // the photo case. Either is enough to look closer.
            final contrast =
                (inLum - ringLum).abs() +
                (inChroma - ringChroma).abs() * 0.6;
            final texture = inEdge - ringEdge;
            if (contrast < 14 && texture < 3) continue;
            if (inEdge + 1 < ringEdge * 0.8 && contrast < 20) continue;

            final score =
                contrast * 0.8 +
                math.min(40.0, math.max(0.0, texture)) * 1.1;
            out.add(
              _Box(
                Rect.fromLTWH(
                  x.toDouble(),
                  y.toDouble(),
                  size.toDouble(),
                  size.toDouble(),
                ),
                score,
              ),
            );
          }
        }
      }
    }
    if (out.isEmpty) return const <_Box>[];

    // Bucket by position *before* taking the best scores. Bold text outscores
    // a quiet gradient avatar, so a plain global top-N used to spend every
    // slot in one corner of the screenshot and lose the avatars elsewhere.
    final cell = math.max(20, (short * 0.12).round());
    final buckets = <String, List<_Box>>{};
    for (final box in out) {
      final key = '${box.rect.left ~/ cell}_${box.rect.top ~/ cell}';
      (buckets[key] ??= <_Box>[]).add(box);
    }
    final ranked = <_Box>[];
    for (final bucket in buckets.values) {
      bucket.sort((a, b) => b.score.compareTo(a.score));
      for (var i = 0; i < math.min(3, bucket.length); i++) {
        ranked.add(bucket[i]);
      }
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));

    final kept = <_Box>[];
    for (final candidate in ranked) {
      if (kept.length >= 160) break;
      var clash = false;
      for (final other in kept) {
        final overlap = candidate.rect.intersect(other.rect);
        if (overlap.isEmpty) continue;
        final ratio =
            (overlap.width * overlap.height) /
            math.min(
              candidate.rect.width * candidate.rect.height,
              other.rect.width * other.rect.height,
            );
        if (ratio > 0.35) {
          clash = true;
          break;
        }
      }
      if (!clash) kept.add(candidate);
    }
    return kept;
  }

  // ------------------------------------------------------------------ shape

  /// Confirms one window really contains an avatar rather than a bit of text.
  ///
  /// The foreground map and distance integral image come from the adaptive
  /// pre-processing pass, so the expensive per-pixel colour work happens once
  /// for the whole image rather than once per candidate. [strictness] below 1
  /// is only used for positions whose location is already strong evidence.
  static _Box? _verify(
    _Pyramid p,
    Rect rect,
    double strictness, {
    bool lowContrast = false,
  }) {
    final w = p.width;
    final h = p.height;
    final x0 = rect.left.round();
    final y0 = rect.top.round();
    final size = rect.width.round();
    if (size < 10 || x0 < 0 || y0 < 0 || x0 + size > w || y0 + size > h) {
      return null;
    }

    final foreground = lowContrast ? p.foregroundLow : p.foreground;
    final area = size * size;
    final covered = p.sum(
      lowContrast ? p.iiForegroundLow : p.iiForeground,
      x0,
      y0,
      x0 + size,
      y0 + size,
    );
    final coverage = covered / area;
    final meanDistance =
        p.sum(p.iiDistance, x0, y0, x0 + size, y0 + size) / area;
    // In the normal channel coverage 1.0 means the window is entirely inside
    // one flat patch and has to be rejected. Along a confirmed avatar column
    // it is exactly what a white or line-art avatar looks like, so the gentle
    // channel accepts it — but demands a real, measurable colour difference
    // from the page so plain background cannot sneak through.
    final minCoverage = lowContrast ? 0.15 : 0.50 * strictness;
    final maxCoverage = lowContrast ? 1.001 : 0.995;
    final minDistance = lowContrast ? 25.0 : 55.0 * strictness;
    if (coverage < minCoverage || coverage > maxCoverage) return null;
    if (meanDistance < minDistance) return null;
    // A pale line-art avatar has almost no solid fill — only strokes, which
    // cover ~20 % of the box — but its gradient density is 30–47 where a flat
    // background or a plain white bubble is 0. That is the signal that makes
    // low-contrast avatars separable instead of just "lower the threshold".
    final edgeDensity =
        p.sum(p.iiEdge, x0, y0, x0 + size, y0 + size) / area;
    if (lowContrast && edgeDensity < 12) return null;

    final rows = Int32List(size);
    final cols = Int32List(size);
    var minX = size, maxX = -1, minY = size, maxY = -1;
    for (var y = 0; y < size; y++) {
      final row = (y0 + y) * w + x0;
      for (var x = 0; x < size; x++) {
        if (foreground[row + x] == 0) continue;
        rows[y]++;
        cols[x]++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return null;

    final blobWidth = maxX - minX + 1;
    final blobHeight = maxY - minY + 1;
    if (blobWidth < size * 0.6 || blobHeight < size * 0.6) return null;
    final aspect = blobWidth / blobHeight;
    if (aspect < 0.7 || aspect > 1.43) return null;
    // A solid object fills most of its bounding box; a comb of glyph strokes
    // leaves holes everywhere.
    final fill = covered / (blobWidth * blobHeight);
    // Sparse strokes are expected in the low-contrast channel; the solid-fill
    // test only makes sense for the normal one.
    if (!lowContrast && fill < 0.62) return null;

    // One connected run in both projections: a disc, a square and a rounded
    // square all satisfy it. Text gives a comb of short runs instead.
    final rowSpan = _mainSpan(rows, size);
    final colSpan = _mainSpan(cols, size);
    if (rowSpan < 0.68 || colSpan < 0.68) return null;

    final corner = _cornerFill(p, x0, y0, size, foreground);
    // Roughly pi/4 for a disc, ~0.9 for a rounded square, ~1 for a square.
    // All three are valid; this only prefers a window that looks like one of
    // them over a ragged patch of content.
    final shapeFit = math.min(
      math.min((coverage - 0.78).abs(), (coverage - 0.88).abs()),
      (coverage - 0.98).abs(),
    );
    // A sparse stroke drawing has a coverage near 0.2, which no solid-shape
    // template fits; the gradient test above replaces it in that channel.
    if (!lowContrast && shapeFit > 0.27) return null;

    final score =
        meanDistance * 0.25 +
        (rowSpan + colSpan) * 12 +
        (lowContrast
            ? edgeDensity * 0.5
            : math.max(0.0, 1 - shapeFit) * 18) +
        corner * 3;
    // Avatars are never rectangles. The tight bounding box of a disc or of a
    // line drawing is almost always a little wider than tall, so snap the
    // result to a square: centre it on the object but keep the sweep window's
    // side length. That guarantees a square, keeps a pale avatar's
    // low-contrast border inside the box, and makes column clustering far more
    // stable because every box has exactly the same size.
    final cx = x0 + (minX + maxX + 1) / 2;
    final cy = y0 + (minY + maxY + 1) / 2;
    final left = (cx - size / 2).round().clamp(0, w - size);
    final top = (cy - size / 2).round().clamp(0, h - size);
    return _Box(
      Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        size.toDouble(),
        size.toDouble(),
      ),
      score,
      corner: corner,
    );
  }

  static double _mainSpan(Int32List counts, int size) {
    final cutoff = math.max(1, (size * 0.12).round());
    var best = 0;
    var run = 0;
    for (var i = 0; i < size; i++) {
      if (counts[i] >= cutoff) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best / size;
  }

  static double _cornerFill(
    _Pyramid p,
    int x0,
    int y0,
    int size,
    Uint8List foreground,
  ) {
    final side = math.max(2, size ~/ 5);
    var hit = 0;
    var total = 0;
    for (final (cx, cy) in <(int, int)>[
      (0, 0),
      (size - side, 0),
      (0, size - side),
      (size - side, size - side),
    ]) {
      for (var y = 0; y < side; y++) {
        final row = (y0 + cy + y) * p.width + x0 + cx;
        for (var x = 0; x < side; x++) {
          total++;
          hit += foreground[row + x];
        }
      }
    }
    return total == 0 ? 0 : hit / total;
  }

  // -------------------------------------------------------- reinforcement

  /// Uses one confirmed avatar as a template for the rest of the screenshot.
  ///
  /// A chat UI mirrors its margins: if avatars start at x, outgoing ones start
  /// at `width - x - size`. That is why a single outgoing avatar on the right
  /// can be found without any repetition at all. We also take a 4×4 colour
  /// signature from the best seed — the same person's avatar often appears
  /// several times in one conversation, and those positions deserve a slightly
  /// gentler shape test.
  ///
  /// The sweep is cheap: integral-image prefilters reject almost every window
  /// before the full projection check runs.
  static List<_Box> _reinforce(_Pyramid p, List<_Box> seeds) {
    if (seeds.isEmpty) return const <_Box>[];
    final sizes = seeds.map((b) => b.rect.width).toList()..sort();
    final size = sizes[sizes.length ~/ 2].round();
    if (size < 12) return const <_Box>[];

    double median(List<double> values) {
      values.sort();
      return values[values.length ~/ 2];
    }

    final lefts = <double>[];
    final rights = <double>[];
    for (final seed in seeds) {
      (seed.rect.center.dx < p.width * 0.5 ? lefts : rights)
          .add(seed.rect.left);
    }
    double? left = lefts.isEmpty ? null : median(lefts);
    double? right = rights.isEmpty ? null : median(rights);
    // The mirrored margin is the whole point: chat avatars are symmetric.
    if (left != null && right == null) {
      right = p.width - left - size;
    } else if (right != null && left == null) {
      left = p.width - right - size;
    }
    final anchors = <double>[
      for (final value in [left, right])
        if (value != null && value >= 0 && value + size <= p.width) value,
    ];
    if (anchors.isEmpty) return const <_Box>[];
    if (anchors.length == 2 && (anchors[0] - anchors[1]).abs() < size * 0.3) {
      anchors.removeLast();
    }

    var best = seeds.first;
    for (final seed in seeds) {
      if (seed.score > best.score) best = seed;
    }
    final template = _signature(p, best.rect, size);
    final bx = best.rect.left.round();
    final by = best.rect.top.round();
    final templateArea = size * size;
    final templateLum =
        p.sum(p.iiLum, bx, by, bx + size, by + size) / templateArea / 255.0;
    final templateChroma =
        p.sum(p.iiChroma, bx, by, bx + size, by + size) /
        templateArea /
        510.0;

    final found = <_Box>[];
    // A quarter of the avatar is plenty: the shape check tightens every box
    // onto the object anyway, so a denser sweep only buys duplicate work.
    final step = math.max(3, size ~/ 4);
    final yStart = math.max(0, p.contentTop - size);
    final yEnd = math.min(p.height, p.contentBottom + size);
    for (final anchor in anchors) {
      // A few pixels of horizontal slack absorbs the antialiased edge and the
      // difference between a round and a square avatar's bounding box.
      for (final dx in const [-3, 0, 3]) {
        final x = (anchor + dx).round();
        if (x < 0 || x + size > p.width) continue;
        for (var y = yStart; y + size <= yEnd; y += step) {
          final rect = Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            size.toDouble(),
            size.toDouble(),
          );
          final area = size * size;
          final highCoverage =
              p.sum(p.iiForeground, x, y, x + size, y + size) / area;
          final lowCoverage =
              p.sum(p.iiForegroundLow, x, y, x + size, y + size) / area;
          // The gentle map is allowed to see sparse strokes: a line drawing
          // only covers ~20 % of its box. The O(1) gradient gate below does
          // the real work of rejecting flat strips and white bubbles.
          if (highCoverage < 0.48 && lowCoverage < 0.15) continue;
          final mean =
              p.sum(p.iiDistance, x, y, x + size, y + size) / area;
          if (mean < 25) continue;

          // Strict check first. Most positions pass or fail here, so the
          // 4×4 signature is only computed for the handful that need a second
          // chance — that is what keeps the whole sweep in the same 10–20 ms
          // class as the original detector.
          final checked = _verify(p, rect, 1.0);
          if (checked != null) {
            _add(found, checked);
            continue;
          }
          // Only the extreme margins may use the gentle map. A white bubble is
          // the same distance from the page as a white avatar, so consulting
          // it anywhere near the middle would light every bubble up.
          final centre = (x + size / 2) / p.width;
          // Only the centred offset needs the gentle channel: the anchor is
          // already taken from a confirmed avatar, so the ±3 px variants would
          // just repeat the same expensive projection test three times.
          if (dx == 0 && (centre < 0.14 || centre > 0.86)) {
            // One O(1) lookup first: flat strips have no strokes at all, so
            // they never need the full low-contrast shape check.
            final edge =
                p.sum(p.iiEdge, x, y, x + size, y + size) / area;
            if (edge >= 12) {
              final pale = _verify(p, rect, 1.0, lowContrast: true);
              if (pale != null) {
                _add(found, pale);
                continue;
              }
            }
          }
          // Two cheap lookups gate the expensive signature: a different
          // person's avatar almost never matches the seed's overall colour.
          final lum = p.sum(p.iiLum, x, y, x + size, y + size) / area / 255.0;
          final chroma =
              p.sum(p.iiChroma, x, y, x + size, y + size) / area / 510.0;
          if ((lum - templateLum).abs() +
              (chroma - templateChroma).abs() >
              0.18) {
            continue;
          }
          if (_signatureDistance(template, _signature(p, rect, size)) < 0.12) {
            final relaxed = _verify(p, rect, 0.85);
            if (relaxed != null) _add(found, relaxed);
          }
        }
      }
    }
    return found;
  }

  /// Boxes far enough into a margin to be trusted as templates.
  static List<_Box> _marginal(_Pyramid p, List<_Box> boxes) {
    final out = <_Box>[];
    for (final box in boxes) {
      final centre = (box.rect.left + box.rect.width / 2) / p.width;
      if (centre > 0.18 && centre < 0.82) continue;
      out.add(box);
    }
    return out;
  }

  // ------------------------------------------------------- column geometry

  /// Enforces the strongest chat-layout prior: every avatar in one column has
  /// the *same* left edge and the *same* side length.
  ///
  /// A single window is a noisy measurement — a pale edge, a clipped blob or
  /// a different sweep size can leave it a few pixels short or off-centre.
  /// The median over its column is not. Restoring that shared geometry is what
  /// turns "we read the avatar but did not box it fully" into a complete box.
  /// It also feeds the reinforcement pass: a consensus seed gives a much more
  /// accurate mirrored margin than any one lucky window.
  ///
  /// Pure bookkeeping over the handful of boxes already found. No image scan,
  /// no extra [_verify], so the cost is invisible next to the integral passes.
  static List<_Box> _alignColumns(_Pyramid p, List<_Box> boxes) {
    if (boxes.length < 2) return boxes;

    double median(List<double> values) {
      values.sort();
      return values[values.length ~/ 2];
    }

    // A "regular column" of text in the middle of the bubbles must never vote
    // on an avatar's geometry. Keep those boxes exactly as they were.
    final marginal = <_Box>[];
    final untouched = <_Box>[];
    for (final box in boxes) {
      final centre = (box.rect.left + box.rect.width / 2) / p.width;
      (centre < 0.18 || centre > 0.82 ? marginal : untouched).add(box);
    }
    if (marginal.length < 2) return boxes;

    final sorted = [...marginal]
      ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
    final columns = <List<_Box>>[];
    for (final box in sorted) {
      if (columns.isEmpty) {
        columns.add([box]);
        continue;
      }
      // Compare with the group's *first* box: comparing with the last one
      // would let a chain of slightly drifting x values walk a column away.
      final head = columns.last.first;
      final slack = math.max(6.0, head.rect.width * 0.35);
      if ((box.rect.left - head.rect.left).abs() <= slack) {
        columns.last.add(box);
      } else {
        columns.add([box]);
      }
    }

    final out = <_Box>[...untouched];
    for (final column in columns) {
      if (column.length < 2) {
        out.addAll(column);
        continue;
      }
      final left = median([for (final b in column) b.rect.left]).round();
      final rawSize = median([for (final b in column) b.rect.width]).round();
      final size = rawSize.clamp(10, math.min(p.width, p.height)).toInt();
      final x = left.clamp(0, p.width - size).toInt();
      for (final box in column) {
        // The row position is real evidence; only the horizontal geometry and
        // the side length come from the column consensus.
        final cy = box.rect.top + box.rect.height / 2;
        final top = (cy - size / 2)
            .round()
            .clamp(0, math.max(0, p.height - size))
            .toInt();
        out.add(
          _Box(
            Rect.fromLTWH(
              x.toDouble(),
              top.toDouble(),
              size.toDouble(),
              size.toDouble(),
            ),
            box.score,
            corner: box.corner,
          ),
        );
      }
    }
    return out;
  }

  /// A 4×4 grid of mean luminance and chroma, normalised to 0..1.
  /// Sixteen integral-image lookups — cheap enough to run at every sweep
  /// position, and discriminative enough to recognise the same avatar again.
  static Float64List _signature(_Pyramid p, Rect rect, int size) {
    final x0 = rect.left.round();
    final y0 = rect.top.round();
    final cell = math.max(2, size ~/ 4);
    final out = Float64List(32);
    var k = 0;
    for (var gy = 0; gy < 4; gy++) {
      for (var gx = 0; gx < 4; gx++) {
        final cx0 = x0 + gx * cell;
        final cy0 = y0 + gy * cell;
        final cx1 = gx == 3 ? x0 + size : math.min(x0 + size, cx0 + cell);
        final cy1 = gy == 3 ? y0 + size : math.min(y0 + size, cy0 + cell);
        final area = math.max(1, (cx1 - cx0) * (cy1 - cy0));
        out[k++] =
            p.sum(p.iiLum, cx0, cy0, cx1, cy1) / area / 255.0;
        out[k++] =
            p.sum(p.iiChroma, cx0, cy0, cx1, cy1) / area / 510.0;
      }
    }
    return out;
  }

  static double _signatureDistance(Float64List a, Float64List b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum / a.length;
  }

  // --------------------------------------------------------------- rhythm

  static List<_Box> _regularizeBoxes(_Pyramid p, List<_Box> boxes) {
    final accepted = <_Box>[];
    for (final group in _cluster(boxes, vertical: true)) {
      // A bright outgoing bubble changes the local contrast enough that the
      // same avatar can be boxed a few pixels differently down a column.
      if (group.length < 2 || !_sameSize(group, 0.32)) continue;
      final sorted = [...group]
        ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
      _grow(p, accepted, sorted, vertical: true);
    }
    for (final group in _cluster(boxes, vertical: false)) {
      // A horizontal row is weaker evidence than a chat column: a line of text
      // lines up too. Only a real grid counts as a row of avatars.
      if (!_regularRow(group)) continue;
      final sorted = [...group]
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      _grow(p, accepted, sorted, vertical: false);
    }
    return accepted;
  }

  /// Marginal filter, normalisation and overlap removal — shared by the
  /// clustered boxes and the seed-driven ones so both obey the same rules.
  static List<Rect> _finish(_Pyramid p, List<_Box> boxes) {
    final result = <Rect>[];
    for (final box in boxes) {
      // Chat avatars live in the left or right margin. A "regular column" in
      // the middle band is almost always a column of text.
      final centre = (box.rect.left + box.rect.width / 2) / p.width;
      if (centre > 0.18 && centre < 0.82) continue;
      final r = Rect.fromLTRB(
        (box.rect.left / p.width).clamp(0.0, 1.0),
        (box.rect.top / p.height).clamp(0.0, 1.0),
        (box.rect.right / p.width).clamp(0.0, 1.0),
        (box.rect.bottom / p.height).clamp(0.0, 1.0),
      );
      var duplicate = false;
      for (final other in result) {
        final overlap = other.intersect(r);
        if (overlap.isEmpty) continue;
        final ratio =
            (overlap.width * overlap.height) /
            math.min(other.width * other.height, r.width * r.height);
        // A pale avatar can be found at two nearby sweep positions. Merge
        // them here rather than leaving two overlapping squares; real avatars
        // are at least a box apart, so this never joins two different ones.
        if (ratio > 0.35) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) result.add(r);
    }
    result.sort((a, b) => a.top.compareTo(b.top));
    return result;
  }

  static bool _sameSize(List<_Box> group, double tolerance) {
    var smallest = double.infinity;
    var largest = 0.0;
    for (final box in group) {
      smallest = math.min(smallest, box.rect.width);
      largest = math.max(largest, box.rect.width);
    }
    return (largest - smallest) / largest <= tolerance;
  }

  static bool _regularRow(List<_Box> group) {
    if (group.length < 3 || !_sameSize(group, 0.14)) return false;
    var lowCorner = double.infinity;
    var highCorner = -double.infinity;
    for (final box in group) {
      lowCorner = math.min(lowCorner, box.corner);
      highCorner = math.max(highCorner, box.corner);
    }
    if (highCorner - lowCorner > 0.35) return false;

    final sorted = [...group]
      ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
    final gaps = <double>[
      for (var i = 1; i < sorted.length; i++)
        sorted[i].rect.left - sorted[i - 1].rect.left,
    ];
    var total = 0.0;
    for (final gap in gaps) {
      total += gap;
    }
    final mean = total / gaps.length;
    for (final gap in gaps) {
      if ((gap - mean).abs() > mean * 0.2) return false;
    }
    return true;
  }

  static List<List<_Box>> _cluster(List<_Box> boxes, {required bool vertical}) {
    final sorted = [...boxes]
      ..sort(
        (a, b) => vertical
            ? a.rect.left.compareTo(b.rect.left)
            : a.rect.top.compareTo(b.rect.top),
      );
    final groups = <List<_Box>>[];
    for (final box in sorted) {
      var placed = false;
      for (final group in groups) {
        final head = group.first;
        final aligns = vertical
            ? (box.rect.left - head.rect.left).abs() < head.rect.width * 0.4
            : (box.rect.top - head.rect.top).abs() < head.rect.height * 0.4;
        final sameSize =
            (box.rect.width - head.rect.width).abs() < head.rect.width * 0.3;
        if (aligns && sameSize) {
          group.add(box);
          placed = true;
          break;
        }
      }
      if (!placed) groups.add([box]);
    }
    return groups;
  }

  static void _grow(
    _Pyramid p,
    List<_Box> accepted,
    List<_Box> sorted, {
    required bool vertical,
  }) {
    for (final box in sorted) {
      _add(accepted, box);
    }
    double coord(_Box b) => vertical ? b.rect.top : b.rect.left;
    final size = sorted.first.rect.width;
    final gaps = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final gap = coord(sorted[i]) - coord(sorted[i - 1]);
      if (gap >= size * 0.85 && gap <= size * 14) gaps.add(gap);
    }
    if (gaps.isEmpty) return;
    gaps.sort();
    final pitch = gaps.first;
    final confirmed = !vertical || _hasRhythm(p, sorted.first.rect, pitch);
    if (!confirmed) return;

    final x = sorted.first.rect.left;
    final y = sorted.first.rect.top;
    void probe(double at, double strictness) {
      final rect = vertical
          ? Rect.fromLTWH(x, at, size, size)
          : Rect.fromLTWH(at, y, size, size);
      final found = _verify(p, rect, strictness);
      if (found != null) _add(accepted, found);
    }

    // Interpolate between two confirmed neighbours. Deliberately no
    // extrapolation past the ends: predicting a message that is not there is
    // the easiest way to invent an avatar.
    for (var i = 1; i < sorted.length; i++) {
      final start = coord(sorted[i - 1]);
      final gap = coord(sorted[i]) - start;
      final steps = (gap / pitch).round();
      if (steps < 2 || steps > 6) continue;
      for (var k = 1; k < steps; k++) {
        probe(start + k * gap / steps, 0.8);
      }
    }
  }

  static void _add(List<_Box> list, _Box box) {
    for (final other in list) {
      final overlap = other.rect.intersect(box.rect);
      if (overlap.isEmpty) continue;
      final ratio =
          (overlap.width * overlap.height) /
          math.min(
            other.rect.width * other.rect.height,
            box.rect.width * box.rect.height,
          );
      if (ratio > 0.55) return;
    }
    list.add(box);
  }

  /// Cross-checks the pitch with a single-bin DFT of the column's vertical
  /// signal. Goertzel gives the power at one period in O(height) — no FFT, no
  /// zero padding. If the guessed pitch is not louder than a nearby off-pitch,
  /// the gaps were a coincidence.
  static bool _hasRhythm(_Pyramid p, Rect first, double pitch) {
    final w = p.width;
    final h = p.height;
    final x = first.left.round();
    final size = first.width.round();
    if (x < 0 || size < 8 || x + size > w || pitch < 4) return false;

    final signal = Float64List(h);
    var average = 0.0;
    for (var row = 0; row < h; row++) {
      var sum = 0.0;
      var squares = 0.0;
      for (var xx = x; xx < x + size; xx++) {
        final l = p.lum[row * w + xx].toDouble();
        sum += l;
        squares += l * l;
      }
      final mean = sum / size;
      final variance = math.sqrt(
        math.max(0.0, squares / size - mean * mean),
      );
      signal[row] = variance;
      average += variance;
    }
    average /= h;
    for (var i = 0; i < h; i++) {
      signal[i] -= average;
    }
    final atPitch = _goertzel(signal, pitch);
    final atOffPitch = _goertzel(signal, pitch * 1.53);
    return atPitch > atOffPitch * 1.05;
  }

  /// Power of a real signal at one period — one bin of a DFT.
  static double _goertzel(Float64List signal, double period) {
    final coeff = 2 * math.cos(2 * math.pi / period);
    var previous = 0.0;
    var beforeThat = 0.0;
    for (final value in signal) {
      final current = value + coeff * previous - beforeThat;
      beforeThat = previous;
      previous = current;
    }
    return previous * previous +
        beforeThat * beforeThat -
        coeff * previous * beforeThat;
  }
}

/// Adaptive pre-processing over the downscaled preview.
///
/// Everything the later passes need is computed in three linear scans: the
/// dominant page colour, a foreground/distances map normalised against it, and
/// five summed-area tables. A window query is then four integer lookups no
/// matter how large the window is.
class _Pyramid {
  _Pyramid(this.rgba, this.width, this.height)
    : stride = width + 1,
      lum = Uint8List(width * height),
      foreground = Uint8List(width * height),
      foregroundLow = Uint8List(width * height),
      iiLum = Int32List((width + 1) * (height + 1)),
      iiChroma = Int32List((width + 1) * (height + 1)),
      iiEdge = Int32List((width + 1) * (height + 1)),
      iiDistance = Int32List((width + 1) * (height + 1)),
      iiForeground = Int32List((width + 1) * (height + 1)),
      iiForegroundLow = Int32List((width + 1) * (height + 1)) {
    final count = width * height;
    final chroma = Uint16List(count);
    final distance = Uint16List(count);

    // Pass 1: luminance, chroma and a coarse colour histogram. 4096 bins =
    // 4 bits per channel. A chat screenshot is mostly one flat background, so
    // its bin is the reliable reference for the whole image.
    final bins = Int32List(4096);
    final sumR = Int32List(4096);
    final sumG = Int32List(4096);
    final sumB = Int32List(4096);
    for (var i = 0, p = 0; i < count; i++, p += 4) {
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      lum[i] = (r * 77 + g * 150 + b * 29) >> 8;
      chroma[i] = (r - g).abs() + (g - b).abs();
      final bin = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      bins[bin]++;
      sumR[bin] += r;
      sumG[bin] += g;
      sumB[bin] += b;
    }
    var dominant = 0;
    for (var i = 1; i < bins.length; i++) {
      if (bins[i] > bins[dominant]) dominant = i;
    }
    final hits = bins[dominant];
    backgroundR = hits == 0 ? 246 : sumR[dominant] ~/ hits;
    backgroundG = hits == 0 ? 246 : sumG[dominant] ~/ hits;
    backgroundB = hits == 0 ? 246 : sumB[dominant] ~/ hits;

    // Pass 2: adaptive normalisation. Express every pixel by its distance
    // from the page colour and threshold it once. This is what makes a smooth
    // gradient or a pale photo look like a solid object to the shape checks.
    for (var i = 0, p = 0; i < count; i++, p += 4) {
      final d =
          (rgba[p] - backgroundR).abs() +
          (rgba[p + 1] - backgroundG).abs() +
          (rgba[p + 2] - backgroundB).abs();
      distance[i] = d;
      foreground[i] = d > AvatarDetector.foregroundThreshold ? 1 : 0;
      foregroundLow[i] = d > AvatarDetector.lowContrastThreshold ? 1 : 0;
    }

    // Pass 3: all five integral images in one sweep, plus a per-row count of
    // foreground pixels used to locate the flat chrome strips.
    final rowHits = Int32List(height);
    for (var y = 0; y < height; y++) {
      var rowLum = 0;
      var rowChroma = 0;
      var rowEdge = 0;
      var rowDistance = 0;
      var rowForeground = 0;
      var rowForegroundLow = 0;
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        rowLum += lum[i];
        rowChroma += chroma[i];
        rowDistance += distance[i];
        rowForeground += foreground[i];
        rowForegroundLow += foregroundLow[i];
        final left = x > 0 ? lum[i - 1] : lum[i];
        final right = x < width - 1 ? lum[i + 1] : lum[i];
        final up = y > 0 ? lum[i - width] : lum[i];
        final down = y < height - 1 ? lum[i + width] : lum[i];
        rowEdge += (right - left).abs() + (down - up).abs();
        final at = (y + 1) * stride + x + 1;
        final above = y * stride + x + 1;
        iiLum[at] = iiLum[above] + rowLum;
        iiChroma[at] = iiChroma[above] + rowChroma;
        iiEdge[at] = iiEdge[above] + rowEdge;
        iiDistance[at] = iiDistance[above] + rowDistance;
        iiForeground[at] = iiForeground[above] + rowForeground;
        iiForegroundLow[at] = iiForegroundLow[above] + rowForegroundLow;
      }
      rowHits[y] = rowForeground;
    }

    // The status bar, the app bar and the input box are wide flat strips with
    // almost no foreground. Skipping them removes a whole class of false
    // positives from the seed sweep. Deliberately conservative: never cut more
    // than 12 % off either end.
    final quiet = math.max(2, (width * 0.012).round());
    final topLimit = (height * 0.12).round();
    final bottomLimit = height - topLimit;
    var top = 0;
    while (top < topLimit && rowHits[top] < quiet) {
      top++;
    }
    var bottom = height;
    while (bottom > bottomLimit && rowHits[bottom - 1] < quiet) {
      bottom--;
    }
    contentTop = top;
    contentBottom = bottom;
  }

  final Uint8List rgba;
  final int width;
  final int height;
  final int stride;
  late final int backgroundR;
  late final int backgroundG;
  late final int backgroundB;
  late final int contentTop;
  late final int contentBottom;
  final Uint8List lum;
  final Uint8List foreground;
  final Uint8List foregroundLow;
  final Int32List iiLum;
  final Int32List iiChroma;
  final Int32List iiEdge;
  final Int32List iiDistance;
  final Int32List iiForeground;
  final Int32List iiForegroundLow;

  int sum(Int32List table, int x0, int y0, int x1, int y1) {
    final ax0 = x0.clamp(0, width);
    final ay0 = y0.clamp(0, height);
    final ax1 = x1.clamp(0, width);
    final ay1 = y1.clamp(0, height);
    if (ax1 <= ax0 || ay1 <= ay0) return 0;
    return table[ay1 * stride + ax1] -
        table[ay0 * stride + ax1] -
        table[ay1 * stride + ax0] +
        table[ay0 * stride + ax0];
  }
}

class _Box {
  _Box(this.rect, this.score, {this.corner = 0});

  final Rect rect;
  final double score;
  final double corner;
}
