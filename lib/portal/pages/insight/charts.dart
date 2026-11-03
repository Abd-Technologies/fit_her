import 'package:flutter/material.dart';

import '../../portal_theme.dart';

/// Dashboard chart kit: colours, number formats and small CustomPainter
/// charts (line, bar, stacked week bars, sparkline, horizontal bars),
/// plus the KPI tile, card and table used on the Dashboard.

/// Chart colours (colour-blind safe). Text never uses series colours.
class DC {
  DC._();
  static const s1 = Color(0xFF3F8F3A);
  static const s2 = Color(0xFF2A78D6);
  static const s3 = Color(0xFFEB6834);
  static const grid = Color(0xFFEDF2EA);
  static const good = Color(0xFF2F8A3A);
  static const warn = Color(0xFFB26B12);
  static const bad = Color(0xFFC24A4A);
  static const wash2 = Color(0xFFEAF7E4);
  static const goodBg = Color(0xFFE7F4E4);
  static const warnBg = Color(0xFFFDF1DE);
  static const badBg = Color(0xFFFBEAEA);
}

const _tnum = [FontFeature.tabularFigures()];

/// Text style with tabular figures (numbers line up).
TextStyle tStyle(double size, {FontWeight w = FontWeight.w400, Color c = PT.ink, double? h}) =>
    PT.t(size, w: w, c: c, h: h).copyWith(fontFeatures: _tnum);

// ── number / date formats ─────────────────────────────────────────────

String _group(int v) {
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}

String _trim(String s) => s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;

/// 12,400 · 13.5 (one decimal only when needed).
String fmtNum(dynamic v) {
  if (v is! num) return '–';
  if (v == v.roundToDouble()) return _group(v.round());
  return v.toStringAsFixed(1);
}

/// PKR: 1.64M · 245k · 12,400.
String fmtPkr(dynamic v) {
  if (v is! num) return '–';
  final n = v.toDouble();
  final a = n.abs();
  if (a >= 1000000) return '${_trim((n / 1000000).toStringAsFixed(2))}M';
  if (a >= 100000) return '${(n / 1000).round()}k';
  return _group(n.round());
}

/// Short axis label: 1.2M · 45k · 4.5k · 120.
String fmtAxis(num v) {
  final a = v.abs();
  if (a >= 1000000) return '${_trim((v / 1000000).toStringAsFixed(1))}M';
  if (a >= 10000) return '${(v / 1000).round()}k';
  if (a >= 1000) return '${_trim((v / 1000).toStringAsFixed(1))}k';
  if (v == v.roundToDouble()) return '${v.round()}';
  return v.toStringAsFixed(1);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "2026-09-20" → "20 Sep".
String shortDate(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return ymd;
  return '${d.day} ${_months[d.month - 1]}';
}

/// "2026-09-20" → "Sun, 20 Sep".
String longDate(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return ymd;
  return '${_wd[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// Round the top of the scale up to a tidy number (4 grid steps).
double niceMax(double v) {
  if (v <= 0) return 1;
  final raw = v / 4;
  double mag = 1;
  if (raw >= 1) {
    while (mag * 10 <= raw) {
      mag *= 10;
    }
  } else {
    while (mag > raw && mag > 0.0001) {
      mag /= 10;
    }
  }
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m == 2.5 && mag < 10) continue;
    if (m * mag >= raw) return m * mag * 4;
  }
  return mag * 40;
}

List<int> _labelIdx(int n, int k) {
  if (n <= k) return [for (var i = 0; i < n; i++) i];
  final out = <int>{};
  for (var j = 0; j < k; j++) {
    out.add((j * (n - 1) / (k - 1)).round());
  }
  return out.toList();
}

void _text(Canvas c, String s, Offset at, {TextAlign align = TextAlign.left, double size = 11, Color color = PT.sage}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Poppins', fontSize: size, color: color, fontFeatures: _tnum),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  var dx = at.dx;
  if (align == TextAlign.right) {
    dx -= tp.width;
  } else if (align == TextAlign.center) {
    dx -= tp.width / 2;
  }
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

/// Recessive horizontal grid with y labels on the left.
void _grid(Canvas c, Size size, EdgeInsets m, double max) {
  final h = size.height - m.top - m.bottom;
  final p = Paint()
    ..color = DC.grid
    ..strokeWidth = 1;
  for (var k = 0; k <= 4; k++) {
    final v = max * k / 4;
    final y = m.top + h - (v / max) * h;
    c.drawLine(Offset(m.left, y), Offset(size.width - m.right, y), p);
    _text(c, fmtAxis(v), Offset(m.left - 8, y), align: TextAlign.right);
  }
}

// ── shared bits ──────────────────────────────────────────────────────

/// "No data yet for this period" placeholder.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty({super.key, this.height = 200, this.text = 'No data yet for this period'});
  final double height;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.insights_outlined, size: 26, color: PT.line),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: PT.t(12.5, c: PT.sage)),
          ]),
        ),
      );
}

/// Hover box used by every chart.
class ChartTip extends StatelessWidget {
  const ChartTip({super.key, required this.title, required this.rows});
  final String title;
  final List<(Color?, String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PT.line),
          boxShadow: const [BoxShadow(color: Color(0x1F1A3A22), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(12, w: FontWeight.w700)),
          const SizedBox(height: 2),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (r.$1 != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: r.$1, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(r.$2, style: PT.t(12, c: PT.sage)),
                const SizedBox(width: 14),
                Text(r.$3, style: tStyle(12, w: FontWeight.w600)),
              ]),
            ),
        ]),
      );
}

/// Puts the tip next to x (flips to the left on the right half).
Widget _tipAt(double x, double width, Widget tip) => x > width / 2
    ? Positioned(right: width - x + 12, top: 4, child: IgnorePointer(child: tip))
    : Positioned(left: x + 12, top: 4, child: IgnorePointer(child: tip));

/// Small colour key.
class ChartLegend extends StatelessWidget {
  const ChartLegend(this.items, {super.key});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 4, children: [
        for (final i in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: i.$2, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 6),
            Text(i.$1, style: PT.t(12, c: PT.sage)),
          ]),
      ]);
}

/// White card: bold title, short note, optional legend / control on the right.
class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.title, this.note, this.trailing, required this.child});
  final String title;
  final String? note;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(title, style: PT.t(14.5, w: FontWeight.w700)),
                  if (note != null) Text(note!, style: PT.t(12, c: PT.sage)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

// ── series ───────────────────────────────────────────────────────────

class ChartSeries {
  const ChartSeries(this.name, this.values, this.color, {this.area = false});
  final String name;
  final List<num> values;
  final Color color;
  final bool area;

  ChartSeries fit(int n) =>
      ChartSeries(name, [for (var i = 0; i < n; i++) i < values.length ? values[i] : 0], color, area: area);
}

double _maxOf(Iterable<num> v) {
  double m = 0;
  for (final x in v) {
    if (x > m) m = x.toDouble();
  }
  return m;
}

// ── line chart with crosshair ────────────────────────────────────────

const _lineM = EdgeInsets.fromLTRB(44, 10, 12, 26);

/// 1–2 daily series; thin lines, light area, end dot, crosshair tooltip.
class LineTrendChart extends StatefulWidget {
  const LineTrendChart({super.key, required this.dates, required this.series, this.height = 240, this.money = false});
  final List<String> dates;
  final List<ChartSeries> series;
  final double height;
  final bool money;

  @override
  State<LineTrendChart> createState() => _LineTrendChartState();
}

class _LineTrendChartState extends State<LineTrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final n = widget.dates.length;
    final series = [for (final s in widget.series) s.fit(n)];
    double maxV = 0;
    for (final s in series) {
      final m = _maxOf(s.values);
      if (m > maxV) maxV = m;
    }
    if (n == 0 || maxV <= 0) return ChartEmpty(height: widget.height);
    final max = niceMax(maxV);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final plotW = width - _lineM.left - _lineM.right;
      double xOf(int i) => _lineM.left + (n <= 1 ? plotW / 2 : i * plotW / (n - 1));
      int idxAt(double dx) {
        if (n <= 1) return 0;
        final i = ((dx - _lineM.left) / (plotW / (n - 1))).round();
        return i < 0 ? 0 : (i > n - 1 ? n - 1 : i);
      }

      void pick(int? i) {
        if (i != _hover) setState(() => _hover = i);
      }

      final h = _hover;
      return SizedBox(
        height: widget.height,
        child: MouseRegion(
          onHover: (e) => pick(idxAt(e.localPosition.dx)),
          onExit: (_) => pick(null),
          child: GestureDetector(
            onTapDown: (d) => pick(idxAt(d.localPosition.dx)),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LinePainter(series: series, dates: widget.dates, max: max, hover: h),
                ),
              ),
              if (h != null && h < n)
                _tipAt(
                  xOf(h),
                  width,
                  ChartTip(title: longDate(widget.dates[h]), rows: [
                    for (final s in series)
                      (s.color, s.name, widget.money ? 'PKR ${fmtNum(s.values[h])}' : fmtNum(s.values[h])),
                  ]),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.series, required this.dates, required this.max, required this.hover});
  final List<ChartSeries> series;
  final List<String> dates;
  final double max;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    const m = _lineM;
    final n = dates.length;
    final w = size.width - m.left - m.right;
    final h = size.height - m.top - m.bottom;
    double x(int i) => m.left + (n <= 1 ? w / 2 : i * w / (n - 1));
    double y(num v) => m.top + h - (v / max) * h;
    _grid(canvas, size, m, max);
    for (final i in _labelIdx(n, 5)) {
      _text(canvas, shortDate(dates[i]), Offset(x(i), size.height - 9), align: TextAlign.center);
    }
    for (final s in series) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        if (i == 0) {
          path.moveTo(x(i), y(s.values[i]));
        } else {
          path.lineTo(x(i), y(s.values[i]));
        }
      }
      if (s.area && n > 1) {
        final a = Path.from(path)
          ..lineTo(x(n - 1), y(0))
          ..lineTo(x(0), y(0))
          ..close();
        canvas.drawPath(a, Paint()..color = s.color.withValues(alpha: 0.08));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      _dot(canvas, Offset(x(n - 1), y(s.values[n - 1])), s.color, 4);
    }
    final hv = hover;
    if (hv != null && hv < n) {
      final xx = x(hv);
      final dash = Paint()
        ..color = PT.sage
        ..strokeWidth = 1;
      for (var yy = m.top; yy < size.height - m.bottom; yy += 6) {
        final end = (yy + 3) > size.height - m.bottom ? size.height - m.bottom : yy + 3;
        canvas.drawLine(Offset(xx, yy), Offset(xx, end), dash);
      }
      for (final s in series) {
        _dot(canvas, Offset(xx, y(s.values[hv])), s.color, 4.5);
      }
    }
  }

  void _dot(Canvas c, Offset at, Color color, double r) {
    c.drawCircle(at, r, Paint()..color = color);
    c.drawCircle(
      at,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

// ── bar chart with per-bar tooltip ───────────────────────────────────

const _barM = EdgeInsets.fromLTRB(44, 10, 8, 26);

class BarTrendChart extends StatefulWidget {
  const BarTrendChart({
    super.key,
    required this.labels,
    required this.values,
    this.tipLabels,
    this.name = 'Value',
    this.color = DC.s1,
    this.height = 240,
    this.money = false,
  });
  final List<String> labels;
  final List<String>? tipLabels;
  final List<num> values;
  final String name;
  final Color color;
  final double height;
  final bool money;

  @override
  State<BarTrendChart> createState() => _BarTrendChartState();
}

class _BarTrendChartState extends State<BarTrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final n = widget.labels.length;
    final values = [for (var i = 0; i < n; i++) i < widget.values.length ? widget.values[i] : 0];
    final maxV = _maxOf(values);
    if (n == 0 || maxV <= 0) return ChartEmpty(height: widget.height);
    final max = niceMax(maxV);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final bw = (width - _barM.left - _barM.right) / n;
      int idxAt(double dx) {
        final i = ((dx - _barM.left) / bw).floor();
        return i < 0 ? 0 : (i > n - 1 ? n - 1 : i);
      }

      void pick(int? i) {
        if (i != _hover) setState(() => _hover = i);
      }

      final h = _hover;
      final tips = widget.tipLabels;
      return SizedBox(
        height: widget.height,
        child: MouseRegion(
          onHover: (e) => pick(idxAt(e.localPosition.dx)),
          onExit: (_) => pick(null),
          child: GestureDetector(
            onTapDown: (d) => pick(idxAt(d.localPosition.dx)),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BarPainter(values: values, labels: widget.labels, max: max, color: widget.color, hover: h),
                ),
              ),
              if (h != null && h < n)
                _tipAt(
                  _barM.left + (h + 0.5) * bw,
                  width,
                  ChartTip(
                    title: tips != null && h < tips.length ? tips[h] : widget.labels[h],
                    rows: [
                      (null, widget.name, widget.money ? 'PKR ${fmtNum(values[h])}' : fmtNum(values[h])),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.values, required this.labels, required this.max, required this.color, required this.hover});
  final List<num> values;
  final List<String> labels;
  final double max;
  final Color color;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    const m = _barM;
    final n = values.length;
    final h = size.height - m.top - m.bottom;
    final base = m.top + h;
    final bw = (size.width - m.left - m.right) / n;
    _grid(canvas, size, m, max);
    final barW = n <= 12 ? bw * 0.56 : (bw > 6 ? bw - 2 : (bw > 2 ? bw - 1 : bw));
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final top = base - (v / max) * h;
      final bx = m.left + i * bw + (bw - barW) / 2;
      var r = 4.0;
      if (base - top < r) r = base - top;
      if (barW / 2 < r) r = barW / 2;
      final paint = Paint()..color = (hover == null || hover == i) ? color : color.withValues(alpha: 0.45);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(bx, top, bx + barW, base),
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
        ),
        paint,
      );
    }
    final step = n <= 8 ? 1 : (n / 5).ceil();
    for (var i = 0; i < n; i += step) {
      _text(canvas, labels[i], Offset(m.left + (i + 0.5) * bw, size.height - 9), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

// ── stacked week bars (3 series) ─────────────────────────────────────

const _stackM = EdgeInsets.fromLTRB(44, 10, 12, 26);

class StackedWeekBars extends StatefulWidget {
  const StackedWeekBars({
    super.key,
    required this.weeks,
    required this.data,
    this.keys = const ['New', 'Renewal', 'Upgrade'],
    this.colors = const [DC.s1, DC.s2, DC.s3],
    this.height = 240,
    this.money = true,
    this.showLegend = false,
  });

  /// Week start dates (YYYY-MM-DD).
  final List<String> weeks;

  /// One list per week, in the order of [keys].
  final List<List<num>> data;
  final List<String> keys;
  final List<Color> colors;
  final double height;
  final bool money;
  final bool showLegend;

  @override
  State<StackedWeekBars> createState() => _StackedWeekBarsState();
}

class _StackedWeekBarsState extends State<StackedWeekBars> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final n = widget.weeks.length;
    final k = widget.keys.length;
    final data = [
      for (var i = 0; i < n; i++)
        [for (var j = 0; j < k; j++) i < widget.data.length && j < widget.data[i].length ? widget.data[i][j] : 0],
    ];
    double maxV = 0;
    for (final w in data) {
      final t = w.fold<double>(0, (a, b) => a + b.toDouble());
      if (t > maxV) maxV = t;
    }
    if (n == 0 || maxV <= 0) return ChartEmpty(height: widget.height);
    final max = niceMax(maxV);
    String f(num v) => widget.money ? 'PKR ${fmtNum(v)}' : fmtNum(v);
    final chart = LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final bw = (width - _stackM.left - _stackM.right) / n;
      int idxAt(double dx) {
        final i = ((dx - _stackM.left) / bw).floor();
        return i < 0 ? 0 : (i > n - 1 ? n - 1 : i);
      }

      void pick(int? i) {
        if (i != _hover) setState(() => _hover = i);
      }

      final h = _hover;
      return SizedBox(
        height: widget.height,
        child: MouseRegion(
          onHover: (e) => pick(idxAt(e.localPosition.dx)),
          onExit: (_) => pick(null),
          child: GestureDetector(
            onTapDown: (d) => pick(idxAt(d.localPosition.dx)),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StackPainter(
                    data: data,
                    labels: [for (final w in widget.weeks) shortDate(w)],
                    colors: widget.colors,
                    max: max,
                    hover: h,
                  ),
                ),
              ),
              if (h != null && h < n)
                _tipAt(
                  _stackM.left + (h + 0.5) * bw,
                  width,
                  ChartTip(title: 'Week of ${shortDate(widget.weeks[h])}', rows: [
                    for (var j = 0; j < k; j++)
                      (j < widget.colors.length ? widget.colors[j] : DC.s1, widget.keys[j], f(data[h][j])),
                    (null, 'Total', f(data[h].fold<num>(0, (a, b) => a + b))),
                  ]),
                ),
            ]),
          ),
        ),
      );
    });
    if (!widget.showLegend) return chart;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChartLegend([
        for (var j = 0; j < k; j++) (widget.keys[j], j < widget.colors.length ? widget.colors[j] : DC.s1),
      ]),
      const SizedBox(height: 8),
      chart,
    ]);
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter({required this.data, required this.labels, required this.colors, required this.max, required this.hover});
  final List<List<num>> data;
  final List<String> labels;
  final List<Color> colors;
  final double max;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    const m = _stackM;
    final n = data.length;
    final h = size.height - m.top - m.bottom;
    final base = m.top + h;
    final bw = (size.width - m.left - m.right) / n;
    _grid(canvas, size, m, max);
    var barW = bw * 0.5;
    if (barW > 64) barW = 64;
    for (var i = 0; i < n; i++) {
      final bx = m.left + i * bw + (bw - barW) / 2;
      var lastNonZero = -1;
      for (var j = 0; j < data[i].length; j++) {
        if (data[i][j] > 0) lastNonZero = j;
      }
      double acc = 0;
      for (var j = 0; j < data[i].length; j++) {
        final v = data[i][j].toDouble();
        if (v <= 0) continue;
        final bot = base - (acc / max) * h;
        final top = base - ((acc + v) / max) * h;
        acc += v;
        final c = j < colors.length ? colors[j] : DC.s1;
        final paint = Paint()..color = (hover == null || hover == i) ? c : c.withValues(alpha: 0.45);
        final isTop = j == lastNonZero;
        // 2px white gap between segments.
        final segBot = j == 0 ? bot : bot - 2;
        if (segBot <= top) continue;
        if (isTop) {
          var r = 4.0;
          if (segBot - top < r) r = segBot - top;
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTRB(bx, top, bx + barW, segBot),
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
            ),
            paint,
          );
        } else {
          canvas.drawRect(Rect.fromLTRB(bx, top, bx + barW, segBot), paint);
        }
      }
    }
    final step = n <= 8 ? 1 : (n / 6).ceil();
    for (var i = 0; i < n; i += step) {
      _text(canvas, labels[i], Offset(m.left + (i + 0.5) * bw, size.height - 9), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _StackPainter old) => true;
}

// ── sparkline ────────────────────────────────────────────────────────

class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.color = DC.s1, this.height = 30});
  final List<num> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: values.length < 2 ? null : CustomPaint(painter: _SparkPainter(values, color)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<num> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    double mx = values.first.toDouble();
    double mn = mx;
    for (final v in values) {
      if (v > mx) mx = v.toDouble();
      if (v < mn) mn = v.toDouble();
    }
    final range = (mx - mn) == 0 ? 1.0 : mx - mn;
    final w = size.width - 4;
    Offset p(int i) => Offset(i * w / (n - 1), size.height - 3 - ((values[i] - mn) / range) * (size.height - 6));
    final line = Path()..moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(p(i).dx, p(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(p(n - 1).dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(p(n - 1), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}

// ── KPI tile + grid ──────────────────────────────────────────────────

/// Label, big value, ▲/▼ change (or a short note) and an optional sparkline.
/// Every tile keeps the same height so a row lines up.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.showChange = false,
    this.change,
    this.changeNote,
    this.goodWhenUp = true,
    this.spark,
    this.sparkColor = DC.s1,
  });
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final bool showChange;
  final num? change;
  final String? changeNote;
  final bool goodWhenUp;
  final List<num>? spark;
  final Color sparkColor;

  @override
  Widget build(BuildContext context) {
    final ch = change;
    InlineSpan? changeSpan;
    if (showChange) {
      if (ch == null) {
        changeSpan = TextSpan(text: '—', style: tStyle(11.5, w: FontWeight.w600, c: PT.sage));
      } else {
        final up = ch >= 0;
        final good = goodWhenUp ? up : !up;
        changeSpan = TextSpan(
          text: '${up ? '▲' : '▼'} ${fmtNum(ch.abs())}%',
          style: tStyle(11.5, w: FontWeight.w600, c: good ? DC.good : DC.bad),
        );
      }
    }
    final note = showChange ? (changeNote ?? sub) : sub;
    final sp = spark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PT.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(12, c: PT.sage)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tStyle(24, w: FontWeight.w700, h: 1.25)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(children: [
            if (changeSpan != null) changeSpan,
            if (changeSpan != null && note != null) const TextSpan(text: '  '),
            if (note != null) TextSpan(text: note, style: PT.t(11.5, c: subColor ?? PT.sage)),
            if (changeSpan == null && note == null) const TextSpan(text: ' '),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PT.t(11.5, c: PT.sage),
        ),
        const SizedBox(height: 6),
        sp == null || sp.length < 2 ? const SizedBox(height: 30) : Sparkline(sp, color: sparkColor),
      ]),
    );
  }
}

/// Grey placeholder tile while numbers load.
class KpiSkeleton extends StatelessWidget {
  const KpiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: const Color(0xFFF0F3EC), borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PT.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        bar(80, 12),
        const SizedBox(height: 10),
        bar(60, 24),
        const SizedBox(height: 10),
        bar(100, 11),
        const SizedBox(height: 10),
        bar(double.infinity, 30),
      ]),
    );
  }
}

/// 6 → 3 → 2 columns as the width shrinks.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        var cols = w >= 1000 ? 6 : (w >= 620 ? 3 : 2);
        if (tiles.length < cols) cols = tiles.length;
        if (cols < 1) cols = 1;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(child: i + j < tiles.length ? tiles[i + j] : const SizedBox()),
            ],
          ]));
        }
        return Column(children: [
          for (var r = 0; r < rows.length; r++) ...[if (r > 0) const SizedBox(height: 12), rows[r]],
        ]);
      });
}

// ── horizontal bars / funnel ─────────────────────────────────────────

class HBar {
  const HBar(this.label, this.value, {this.note, this.color, this.text});
  final String label;
  final num value;

  /// Small grey text after the number (e.g. "24%").
  final String? note;
  final Color? color;

  /// Shown instead of the number.
  final String? text;
}

/// One labelled bar.
class HBarRow extends StatelessWidget {
  const HBarRow({super.key, required this.bar, required this.max, this.labelWidth = 150, this.numWidth = 96, this.money = false});
  final HBar bar;
  final num max;
  final double labelWidth;
  final double numWidth;
  final bool money;

  @override
  Widget build(BuildContext context) {
    var f = max <= 0 ? 0.0 : bar.value / max;
    if (f < 0) f = 0;
    if (f > 1) f = 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: labelWidth,
          child: Text(bar.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(12.5, c: PT.sage)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 14,
              color: PT.wash,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: f.toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    color: bar.color ?? DC.s1,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: numWidth,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: bar.text ?? (money ? fmtPkr(bar.value) : fmtNum(bar.value))),
              if (bar.note != null && bar.note!.isNotEmpty)
                TextSpan(text: ' ${bar.note}', style: tStyle(11.5, c: PT.sage)),
            ]),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tStyle(12.5),
          ),
        ),
      ]),
    );
  }
}

/// List of bars. With [drops] it is a funnel: "−X% dropped here" between steps.
class HBarList extends StatelessWidget {
  const HBarList({
    super.key,
    required this.rows,
    this.drops = false,
    this.money = false,
    this.max,
    this.emptyText = 'No data yet for this period',
  });
  final List<HBar> rows;
  final bool drops;
  final bool money;
  final num? max;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final top = max ?? _maxOf(rows.map((r) => r.value));
    if (rows.isEmpty || _maxOf(rows.map((r) => r.value)) <= 0) return ChartEmpty(height: 120, text: emptyText);
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 520;
      final lw = narrow ? 110.0 : 150.0;
      final nw = narrow ? 78.0 : 96.0;
      final out = <Widget>[];
      for (var i = 0; i < rows.length; i++) {
        if (drops && i > 0) {
          final prev = rows[i - 1].value;
          if (prev > 0) {
            final d = ((1 - rows[i].value / prev) * 100).round();
            if (d > 0) {
              out.add(Padding(
                padding: EdgeInsets.only(left: lw + 10),
                child: Text('−$d% dropped here', style: tStyle(11, c: DC.bad)),
              ));
            }
          }
        }
        out.add(HBarRow(bar: rows[i], max: top, labelWidth: lw, numWidth: nw, money: money));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
    });
  }
}

// ── simple table ─────────────────────────────────────────────────────

class DashCol {
  const DashCol(this.label, {this.numeric = false, this.center = false, this.flex = 1, this.width});
  final String label;
  final bool numeric;
  final bool center;
  final double flex;
  final double? width;
}

/// Light table (small caps header, thin row lines). Scrolls sideways when
/// the box is narrower than [minWidth].
class DashTable extends StatelessWidget {
  const DashTable({super.key, required this.columns, required this.rows, this.minWidth = 0});
  final List<DashCol> columns;
  final List<List<Widget>> rows;
  final double minWidth;

  Widget _cell(Widget w, DashCol col, {bool header = false}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: header ? 7 : 9),
        child: Align(
          alignment: col.numeric ? Alignment.centerRight : (col.center ? Alignment.center : Alignment.centerLeft),
          child: w,
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final table = Table(
          columnWidths: <int, TableColumnWidth>{
            for (var i = 0; i < columns.length; i++)
              i: columns[i].width != null ? FixedColumnWidth(columns[i].width!) : FlexColumnWidth(columns[i].flex),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
              children: [
                for (final col in columns)
                  _cell(
                    Text(col.label.toUpperCase(),
                        style: PT.t(11, w: FontWeight.w700, c: PT.sage).copyWith(letterSpacing: .5)),
                    col,
                    header: true,
                  ),
              ],
            ),
            for (final r in rows)
              TableRow(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DC.grid))),
                children: [
                  for (var i = 0; i < columns.length; i++) _cell(i < r.length ? r[i] : const SizedBox(), columns[i]),
                ],
              ),
          ],
        );
        if (minWidth > 0 && c.maxWidth < minWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          );
        }
        return table;
      });
}

/// Table cell text with tabular figures.
Widget cellText(String s, {FontWeight w = FontWeight.w400, Color c = PT.ink}) =>
    Text(s, style: tStyle(12.5, w: w, c: c));
