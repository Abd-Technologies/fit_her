import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Phase C primitive — weight trend chart with cycle-phase background tints
/// and a dashed forward-projection line. The headline visual on the
/// Progress hub.
///
/// Inputs map 1:1 to the `/users/progress/weight` response shape:
///   • [history]         → solid line, "today" dot at the last point
///   • [phaseSegments]   → background tinting via RangeAreaSeries (one
///                         band per phase). Skip when null/empty for users
///                         without cycle data — the chart renders cleanly
///                         with a flat white background.
///   • [projection]      → dashed line, no markers
///
/// The widget is purely presentational: takes typed records, no controller
/// dependency, fits inside any [Container] with finite size.
///
/// Why Syncfusion: `syncfusion_flutter_charts: ^27.1.51` is already in
/// pubspec.yaml. The brief explicitly requires it. The phase tinting
/// approach uses one [RangeAreaSeries] per phase (instead of one big
/// stacked range) so each band gets its own colour without alpha math.

class WeightPoint {
  /// Calendar date for the X axis. Use UTC dates (matches the backend's
  /// DATEONLY columns).
  final DateTime date;

  /// Weight in kg.
  final double weightKg;

  const WeightPoint({required this.date, required this.weightKg});
}

class PhaseSegment {
  /// Backend's phase string: 'menstrual' | 'follicular' | 'ovulatory' | 'luteal'.
  /// Anything else falls back to a neutral grey band.
  final String phase;
  final DateTime start;
  final DateTime end;

  const PhaseSegment({
    required this.phase,
    required this.start,
    required this.end,
  });
}

class PhaseSegmentedChart extends StatelessWidget {
  final List<WeightPoint> history;
  final List<PhaseSegment> phaseSegments;

  /// Optional dashed forward-projection line. Pass `null` or `[]` to skip.
  final List<WeightPoint>? projection;

  /// Y-axis bounds. If null, Syncfusion auto-fits with a small margin.
  /// Pass explicit values when consistency across period switches matters
  /// (so the chart doesn't "jump" as min/max swing).
  final double? minWeightKg;
  final double? maxWeightKg;

  /// Colour of the actual-weight line.
  final Color lineColor;

  /// Colour of the dashed projection line.
  final Color projectionColor;

  /// Y-axis tick / gridline colour.
  final Color gridColor;

  /// Optional alpha for phase background bands. Default 0.10 keeps the
  /// chart legible on top.
  final double phaseBandOpacity;

  /// Chart height in logical px.
  final double height;

  const PhaseSegmentedChart({
    Key? key,
    required this.history,
    this.phaseSegments = const [],
    this.projection,
    this.minWeightKg,
    this.maxWeightKg,
    this.lineColor = const Color(0xFF6DC55A),
    this.projectionColor = const Color(0xFF9AB09A),
    this.gridColor = const Color(0xFFE5E7EB),
    this.phaseBandOpacity = 0.10,
    // Phase 2 §6.B #11 — dropped from 220 → 130. HTML reference is
    // 90 but Flutter's Syncfusion has wider plot-area margins than a
    // raw SVG, so 90 reads cramped on real devices. 130 is the
    // minimum that keeps the line + Today dot legible without
    // overpowering the rest of the screen.
    this.height = 130,
  }) : super(key: key);

  // Phase → tint colour map. Values mirror PhaseTheme.accent on the rest
  // of the codebase; alpha is layered at render time.
  static const Map<String, Color> _phaseColors = {
    'menstrual': Color(0xFFFF8A8A),
    'follicular': Color(0xFF6DC55A),
    'ovulatory': Color(0xFF5ECFB0),
    'luteal': Color(0xFFFAC775),
  };

  Color _bandColorFor(String phase) {
    final base = _phaseColors[phase.toLowerCase()] ?? const Color(0xFF9AB09A);
    return base.withOpacity(phaseBandOpacity);
  }

  /// Combined date range for both history and projection so the X axis
  /// shows the entire span without truncating either series.
  DateTime _xMin() {
    final candidates = [
      ...history.map((p) => p.date),
      ...?projection?.map((p) => p.date),
      ...phaseSegments.map((s) => s.start),
    ];
    if (candidates.isEmpty) return DateTime.now().subtract(const Duration(days: 7));
    return candidates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime _xMax() {
    final candidates = [
      ...history.map((p) => p.date),
      ...?projection?.map((p) => p.date),
      ...phaseSegments.map((s) => s.end),
    ];
    if (candidates.isEmpty) return DateTime.now();
    return candidates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// One [RangeAreaSeries] per phase segment. We treat each segment as a
  /// rectangle that spans [start, end] on X and the full Y range; we pin
  /// the upper bound at a value far above the data so the band fills the
  /// chart vertically. The lower bound is correspondingly far below.
  ///
  /// Pinning the bounds in data-space (rather than using an annotation
  /// layer) lets the bands respect the chart's actual plot area without
  /// us having to measure pixels.
  List<CartesianSeries<_BandPoint, DateTime>> _bandSeries(double yMin, double yMax) {
    final lo = yMin - (yMax - yMin); // generous below-floor
    final hi = yMax + (yMax - yMin); // generous above-ceiling
    final series = <CartesianSeries<_BandPoint, DateTime>>[];
    for (var i = 0; i < phaseSegments.length; i++) {
      final s = phaseSegments[i];
      // Two endpoints per band — RangeAreaSeries draws a filled trapezoid
      // between (start, lo..hi) and (end, lo..hi).
      final data = <_BandPoint>[
        _BandPoint(s.start, lo, hi),
        _BandPoint(s.end, lo, hi),
      ];
      series.add(
        RangeAreaSeries<_BandPoint, DateTime>(
          // No series animation (Oct 2026): Syncfusion's fade-in threw
          // "A disposed RenderObject was mutated" when the chart left the
          // screen mid-animation (Progress tab rebuilds). Small chart, no loss.
          animationDuration: 0,
          name: 'phase_${s.phase}_$i',
          dataSource: data,
          xValueMapper: (p, _) => p.x,
          highValueMapper: (p, _) => p.high,
          lowValueMapper: (p, _) => p.low,
          color: _bandColorFor(s.phase),
          borderColor: Colors.transparent,
          isVisibleInLegend: false,
          // Excluding from tooltip — bands are decorative, not data.
          enableTooltip: false,
        ),
      );
    }
    return series;
  }

  @override
  Widget build(BuildContext context) {
    final hasHistory = history.isNotEmpty;
    final hasProjection = projection != null && projection!.isNotEmpty;

    // Y bounds — explicit values always win; otherwise compute from data.
    double resolvedMin;
    double resolvedMax;
    if (minWeightKg != null && maxWeightKg != null) {
      resolvedMin = minWeightKg!;
      resolvedMax = maxWeightKg!;
    } else {
      final allWeights = [
        ...history.map((p) => p.weightKg),
        ...?projection?.map((p) => p.weightKg),
      ];
      if (allWeights.isEmpty) {
        resolvedMin = 0;
        resolvedMax = 100;
      } else {
        final lo = allWeights.reduce((a, b) => a < b ? a : b);
        final hi = allWeights.reduce((a, b) => a > b ? a : b);
        // 5% padding on each side so points don't sit on the axis edge.
        final pad = (hi - lo).abs() * 0.1 + 0.5;
        resolvedMin = lo - pad;
        resolvedMax = hi + pad;
      }
    }

    // Phase 2 §6.A #7 — hide chart axes + gridlines per HTML reference
    // (lines 153-175 are an SVG with no axes, no gridlines). The chart
    // reads as a magazine-style sparkline rather than a data dashboard.
    final dateAxis = DateTimeAxis(
      minimum: _xMin(),
      maximum: _xMax(),
      isVisible: false,
      majorGridLines: const MajorGridLines(width: 0),
      intervalType: DateTimeIntervalType.auto,
    );

    final yAxis = NumericAxis(
      minimum: resolvedMin,
      maximum: resolvedMax,
      isVisible: false,
      majorGridLines: const MajorGridLines(width: 0),
      axisLine: const AxisLine(width: 0),
      labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF6F8B7A)),
      labelFormat: '{value} kg',
    );

    return SizedBox(
      height: height,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        primaryXAxis: dateAxis,
        primaryYAxis: yAxis,
        // Tooltip on data points only. Bands suppress their own.
        tooltipBehavior: TooltipBehavior(enable: hasHistory),
        series: <CartesianSeries>[
          // 1. Background phase bands (rendered first so they sit behind).
          ..._bandSeries(resolvedMin, resolvedMax),
          // 2. Actual weight line.
          if (hasHistory)
            LineSeries<WeightPoint, DateTime>(
          // No series animation (Oct 2026): Syncfusion's fade-in threw
          // "A disposed RenderObject was mutated" when the chart left the
          // screen mid-animation (Progress tab rebuilds). Small chart, no loss.
          animationDuration: 0,
              name: 'weight',
              dataSource: history,
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.weightKg,
              color: lineColor,
              width: 2.5,
              markerSettings: const MarkerSettings(
                isVisible: true,
                width: 6,
                height: 6,
                shape: DataMarkerType.circle,
              ),
            ),
          // 3. Today dot — emphasised marker on the most recent point.
          if (hasHistory)
            ScatterSeries<WeightPoint, DateTime>(
          // No series animation (Oct 2026): Syncfusion's fade-in threw
          // "A disposed RenderObject was mutated" when the chart left the
          // screen mid-animation (Progress tab rebuilds). Small chart, no loss.
          animationDuration: 0,
              name: 'today',
              dataSource: [history.last],
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.weightKg,
              color: lineColor,
              markerSettings: MarkerSettings(
                isVisible: true,
                width: 11,
                height: 11,
                shape: DataMarkerType.circle,
                borderColor: Colors.white,
                borderWidth: 3,
                color: lineColor,
              ),
              isVisibleInLegend: false,
              enableTooltip: false,
            ),
          // 4. Dashed projection line.
          if (hasProjection)
            LineSeries<WeightPoint, DateTime>(
          // No series animation (Oct 2026): Syncfusion's fade-in threw
          // "A disposed RenderObject was mutated" when the chart left the
          // screen mid-animation (Progress tab rebuilds). Small chart, no loss.
          animationDuration: 0,
              name: 'projection',
              dataSource: projection!,
              xValueMapper: (p, _) => p.date,
              yValueMapper: (p, _) => p.weightKg,
              color: projectionColor,
              width: 2,
              dashArray: const <double>[5, 4],
              markerSettings: const MarkerSettings(isVisible: false),
              isVisibleInLegend: false,
            ),
        ],
      ),
    );
  }
}

/// Internal data point for the [RangeAreaSeries] phase bands.
class _BandPoint {
  final DateTime x;
  final double low;
  final double high;
  const _BandPoint(this.x, this.low, this.high);
}
