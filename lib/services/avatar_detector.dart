import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Finds chat avatars with plain image processing — no model, no plugin.
///
/// The old detector asked for "a busy square inside a perfectly flat ring" and
/// then demanded one filled blob. That misses exactly the avatars people use:
/// a smooth gradient with a letter, a square photo, or a rounded square with a
/// light border. It also made "busy enough" an absolute threshold, which is
/// why a 720 px screenshot found fewer avatars than a 480 px one — resizing
/// softens the very gradients it was counting.
///
/// Three classical signals replace it:
///
///  1. **Integral images** of luminance, chroma and a 2-tap central-difference
///     gradient (a cheap Sobel). A sliding window then costs a fixed handful
///     of integer lookups, whatever its size.
///  2. **Shape by projection.** For each surviving window, subtract the local
///     background colour and look at the row/column histograms of what is
///     left. A disc, a square and a rounded square all produce one long
///     connected run covering most of the window; a line of text produces
///     several short runs and a much lower fill. Corner occupancy tells the
///     three shapes apart — and all three are accepted.
///  3. **Regularity in the frequency domain.** Chat avatars repeat down a
///     column (or along a row in a member grid). The pitch comes from the
///     gaps, is cross-checked with a single-bin DFT (Goertzel) of the column's
///     vertical signal, and is used to re-test positions the coarse pass
///     missed. This is what fixes recall.
///
/// Cost is O(pixels) for the integral images and the sweep, plus a small
/// O(candidates²) for clustering. Everything runs in a background isolate.
class AvatarDetector {
  const AvatarDetector._();

  /// Longest side of the bitmap the detector works on.
  ///
  /// Slightly smaller than the old 720: the new cues (colour contrast and
  /// projections) do not need the extra pixels, and the saved work pays for
  /// the shape and rhythm passes so the whole scan stays in the same 10–30 ms
  /// range as before.
  static const int analysisSide = 640;

  static List<Rect> find(Uint8List rgba, int width, int height) {
    if (width < 48 || height < 48) return const <Rect>[];
    final pyramid = _Pyramid(rgba, width, height);
    final coarse = _coarse(pyramid);
    if (coarse.isEmpty) return const <Rect>[];

    final verified = <_Box>[];
    for (final box in coarse) {
      final checked = _verify(pyramid, box.rect, 1.0);
      if (checked != null) verified.add(checked);
    }
    if (verified.isEmpty) return const <Rect>[];
    return _regularize(pyramid, verified);
  }

  // ------------------------------------------------------------------ sweep

  static List<_Box> _coarse(_Pyramid p) {
    final w = p.width;
    final h = p.height;
    final short = math.min(w, h);
    // A phone screenshot spends roughly 6–12 % of its width on an avatar; the
    // extra scales cover tablets, contact lists and avatars inside forwards.
    final sizes = <int>{
      // 20 px windows were the source of most false positives: a bold glyph
      // cluster is exactly that size. On a 640 px analysis bitmap a real chat
      // avatar is 30–55 px, so starting here costs no recall and saves a whole
      // sweep.
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
    // Two winners per cell keep the sweep cheap but spatially fair.
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
  /// [strictness] below 1 is only used when re-testing a position predicted by
  /// a confirmed rhythm; those get a slightly gentler threshold because their
  /// location is already strong evidence.
  static _Box? _verify(_Pyramid p, Rect rect, double strictness) {
    final w = p.width;
    final h = p.height;
    final rgba = p.rgba;
    final x0 = rect.left.round();
    final y0 = rect.top.round();
    final size = rect.width.round();
    if (size < 10 || x0 < 0 || y0 < 0 || x0 + size > w || y0 + size > h) {
      return null;
    }
    // The dominant page colour is the reference, not a thin local ring. A ring
    // can be polluted by the bubble or a text line, which drags the reference
    // into the middle and makes the entire bubble look like "content". A chat
    // bubble is only ~20 units from the page colour, so it stays background;
    // an avatar is far away from it.
    final br = p.backgroundR;
    final bg = p.backgroundG;
    final bb = p.backgroundB;
    // A white chat bubble is ~51 colour units away from the usual light grey
    // page (#EDEDF0), and ~23 from a whiter one. Both must stay "background",
    // otherwise the bubble itself becomes a solid square "avatar". Coloured
    // avatars are hundreds of units away, so 60 still catches every one of
    // them; the gentler settings are only for rhythm-predicted positions.
    final threshold = 30.0 + 30.0 * strictness;
    final rows = Int32List(size);
    final cols = Int32List(size);
    var covered = 0;
    var distanceSum = 0;
    var minX = size, maxX = -1, minY = size, maxY = -1;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = ((y0 + y) * w + x0 + x) * 4;
        final distance =
            (rgba[i] - br).abs() +
            (rgba[i + 1] - bg).abs() +
            (rgba[i + 2] - bb).abs();
        distanceSum += distance;
        if (distance > threshold) {
          rows[y]++;
          cols[x]++;
          covered++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    final area = size * size;
    final coverage = covered / area;
    final meanDistance = distanceSum / area;
    // Coverage 1.0 means the window is entirely inside one flat patch — no
    // boundary to locate. It is exactly what a white bubble looks like when
    // its ring is polluted by the text around it, so it has to be rejected;
    // the spatial buckets above make sure a correctly sized window survives.
    if (coverage < 0.50 * strictness || coverage > 0.995) return null;
    if (meanDistance < 55 * strictness) return null;
    if (maxX < 0) return null;

    final blobWidth = maxX - minX + 1;
    final blobHeight = maxY - minY + 1;
    if (blobWidth < size * 0.6 || blobHeight < size * 0.6) return null;
    final aspect = blobWidth / blobHeight;
    if (aspect < 0.7 || aspect > 1.43) return null;
    // A solid object fills most of its bounding box; a comb of glyph strokes
    // leaves holes everywhere. This compactness test is what separates text
    // from an avatar when both happen to fit the same window.
    final fill = covered / (blobWidth * blobHeight);
    if (fill < 0.62) return null;

    // One connected run in both projections: a disc, a square and a rounded
    // square all satisfy it. Text gives a comb of short runs instead.
    final rowSpan = _mainSpan(rows, size);
    final colSpan = _mainSpan(cols, size);
    if (rowSpan < 0.68 || colSpan < 0.68) return null;

    final corner = _cornerFill(rgba, w, x0, y0, size, br, bg, bb, threshold);
    // Roughly pi/4 for a disc, ~0.9 for a rounded square, ~1 for a square.
    // The three shapes are deliberately all valid; this only prefers a window
    // that looks like one of them over a ragged patch of content.
    final shapeFit = math.min(
      math.min((coverage - 0.78).abs(), (coverage - 0.88).abs()),
      (coverage - 0.98).abs(),
    );
    if (shapeFit > 0.27) return null;

    final score =
        meanDistance * 0.25 +
        (rowSpan + colSpan) * 12 +
        (1 - shapeFit) * 18 +
        corner * 3;
    // Tighten the box onto the object, so the mask covers the avatar and not
    // a lot of empty background around it.
    const pad = 1;
    return _Box(
      Rect.fromLTWH(
        (x0 + minX - pad).toDouble(),
        (y0 + minY - pad).toDouble(),
        (blobWidth + 2 * pad).toDouble(),
        (blobHeight + 2 * pad).toDouble(),
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
    Uint8List rgba,
    int w,
    int x0,
    int y0,
    int size,
    int br,
    int bg,
    int bb,
    double threshold,
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
        for (var x = 0; x < side; x++) {
          final i = ((y0 + cy + y) * w + x0 + cx + x) * 4;
          final distance =
              (rgba[i] - br).abs() +
              (rgba[i + 1] - bg).abs() +
              (rgba[i + 2] - bb).abs();
          total++;
          if (distance > threshold) hit++;
        }
      }
    }
    return total == 0 ? 0 : hit / total;
  }

  // --------------------------------------------------------------- rhythm

  static List<Rect> _regularize(_Pyramid p, List<_Box> boxes) {
    final accepted = <_Box>[];
    for (final group in _cluster(boxes, vertical: true)) {
      // A bright outgoing bubble changes the local contrast enough that the
      // same avatar can be boxed a few pixels differently down a column, so
      // the size tolerance here is deliberately looser than for a grid row.
      if (group.length < 2 || !_sameSize(group, 0.32)) continue;
      final sorted = [...group]
        ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
      _grow(p, accepted, sorted, vertical: true);
    }
    for (final group in _cluster(boxes, vertical: false)) {
      // A horizontal row is much weaker evidence than a chat column: a line of
      // text lines up too. Only a real grid — same size, same shape, evenly
      // spaced — counts as a row of avatars.
      if (!_regularRow(group)) continue;
      final sorted = [...group]
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      _grow(p, accepted, sorted, vertical: false);
    }
    if (accepted.isEmpty) return const <Rect>[];

    final result = <Rect>[];
    for (final box in accepted) {
      // Chat avatars live in the left or right margin. A "regular column" in
      // the middle band is almost always a column of text; the sweep already
      // favours the margins, and this keeps its predictions honest too.
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
            math.min(
              other.width * other.height,
              r.width * r.height,
            );
        if (ratio > 0.55) {
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
    // One shape, not a mixture: a row of avatars is all discs or all squares.
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
    // A missed avatar makes one gap twice as long as the real pitch, so the
    // smallest gap is the most reliable estimate.
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

    // Interpolate between two confirmed neighbours: this recovers the avatar
    // whose own contrast was too low for the coarse sweep.
    for (var i = 1; i < sorted.length; i++) {
      final start = coord(sorted[i - 1]);
      final gap = coord(sorted[i]) - start;
      final steps = (gap / pitch).round();
      if (steps < 2 || steps > 6) continue;
      for (var k = 1; k < steps; k++) {
        probe(start + k * gap / steps, 0.8);
      }
    }
    // Deliberately no extrapolation past the ends of the column. Predicting a
    // message that is not there is the easiest way to invent an avatar; only
    // positions bracketed by two confirmed neighbours are worth re-testing.
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
  /// signal.
  ///
  /// Goertzel gives the power at one period in O(height) — no FFT, no zero
  /// padding, and no harmonic bookkeeping. The signal is the local luminance
  /// spread per row inside the column, which spikes where an avatar sits. If
  /// the guessed pitch is not actually louder than a nearby off-pitch, the
  /// gaps were a coincidence and we keep the boxes we already have without
  /// inventing any more.
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

/// Three summed-area tables over the downscaled preview.
class _Pyramid {
  _Pyramid(this.rgba, this.width, this.height)
    : stride = width + 1,
      lum = Uint8List(width * height),
      iiLum = Int32List((width + 1) * (height + 1)),
      iiChroma = Int32List((width + 1) * (height + 1)),
      iiEdge = Int32List((width + 1) * (height + 1)) {
    final count = width * height;
    final chroma = Uint16List(count);
    // A chat screenshot is mostly one flat background colour. Estimating it
    // once from a coarse colour histogram is both cheaper and far steadier
    // than sampling a thin ring around every candidate: a ring can be polluted
    // by the bubble or the text beside the avatar, which then makes the whole
    // window look like "content". 4096 bins = 4 bits per channel.
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

    for (var y = 0; y < height; y++) {
      var rowLum = 0;
      var rowChroma = 0;
      var rowEdge = 0;
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        rowLum += lum[i];
        rowChroma += chroma[i];
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
      }
    }
  }

  final Uint8List rgba;
  final int width;
  final int height;
  final int stride;
  late final int backgroundR;
  late final int backgroundG;
  late final int backgroundB;
  final Uint8List lum;
  final Int32List iiLum;
  final Int32List iiChroma;
  final Int32List iiEdge;

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
