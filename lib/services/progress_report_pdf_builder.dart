// Phase D7 — Pure-Dart PDF page builder for the Progress hub report.
//
// Split out from `progress_report_pdf_service.dart` so the smoke test
// (test/progress_pdf_smoke.dart) can exercise the builders without
// importing path_provider (which transitively pulls in Flutter and
// breaks `dart run`).
//
// The service composes this builder with platform-specific concerns
// (file write via path_provider). Keep this file free of any Flutter
// imports — only `dart:typed_data`, the `pdf` package, and our own
// model classes.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/progress_v2/measurement_entry.dart';
import '../data/models/progress_v2/progress_models.dart';

class ProgressReportPdfBuilder {
  final PdfColor primary;
  final PdfColor textPrimary;
  final PdfColor textMuted;
  final PdfColor borderColor;

  const ProgressReportPdfBuilder({
    this.primary = const PdfColor.fromInt(0xFF6DC55A),
    this.textPrimary = const PdfColor.fromInt(0xFF163220),
    this.textMuted = const PdfColor.fromInt(0xFF6F8B7A),
    this.borderColor = const PdfColor.fromInt(0xFFD8EDD4),
  });

  /// Build a complete `pw.Document` ready for `.save()` to bytes.
  pw.Document buildDocument({
    required ProgressSummary summary,
    required WeightTrend weight,
    required HydrationData hydration,
    required SymptomsData symptoms,
    required InsightsHubData insights,
    String? userFullName,
    List<MeasurementEntry> measurements = const [],
  }) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => buildPage1(
        summary: summary,
        weight: weight,
        hydration: hydration,
        insights: insights,
        userFullName: userFullName,
        measurements: measurements,
      ),
    ));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => buildPage2(symptoms: symptoms),
    ));
    return doc;
  }

  // ───────── Page 1: clinical summary ────────────────────────────────────

  List<pw.Widget> buildPage1({
    required ProgressSummary summary,
    required WeightTrend weight,
    required HydrationData hydration,
    required InsightsHubData insights,
    String? userFullName,
    List<MeasurementEntry> measurements = const [],
  }) {
    final periodLabel = _formatPeriodLabel(summary.window.period);
    final headerName = userFullName ?? summary.user?.firstName ?? 'Patient';
    final periodLine = (summary.window.periodStart != null && summary.window.periodEnd != null)
        ? '${summary.window.periodStart}  to  ${summary.window.periodEnd}'
        : periodLabel;

    return [
      _header(name: headerName, periodLabel: periodLabel),
      pw.SizedBox(height: 8),
      pw.Text(periodLine, style: pw.TextStyle(fontSize: 10, color: textMuted)),
      pw.SizedBox(height: 18),

      _sectionTitle('Cycle context'),
      _kvRow([
        ['Phase', summary.cycle?.phase ?? '-'],
        ['Cycle day', '${summary.cycle?.cycleDay ?? '-'}'],
        ['Avg cycle length', '${summary.cycle?.averageCycleLength ?? '-'} days'],
      ]),
      pw.SizedBox(height: 14),

      _sectionTitle('Goal & pace'),
      _kvRow([
        ['Goal', summary.goal?.label ?? '-'],
        ['Status', summary.goal?.paceStatus ?? '-'],
        if ((summary.goal?.paceMessage ?? '').isNotEmpty)
          ['Pace', summary.goal!.paceMessage!],
        ['Current change', _formatKg(summary.goal?.currentDeltaKg)],
        ['Target change', _formatKg(summary.goal?.targetDeltaKg)],
      ]),
      pw.SizedBox(height: 14),

      _sectionTitle('Weight'),
      _kvRow([
        ['Current', weight.currentWeightKg == null ? '-' : '${weight.currentWeightKg!.toStringAsFixed(1)} kg'],
        ['Period delta', _formatKg(weight.deltaKg, suffixKg: true)],
        ['Direction', weight.direction ?? '-'],
        ['Datapoints', '${weight.history.length}'],
      ]),
      pw.SizedBox(height: 14),

      // Weekly check-in measurements (Oct 2026).
      ..._measurementsSection(measurements),

      _sectionTitle('Hydration'),
      _kvRow([
        ['Average', '${hydration.averageL?.toStringAsFixed(1) ?? '-'} L / day'],
        ['Target', '${hydration.targetL?.toStringAsFixed(1) ?? '-'} L'],
        ['Days logged', '${hydration.daysLogged ?? 0}'],
        if ((hydration.phaseTip?.tip ?? '').isNotEmpty)
          ['Phase tip', _c(hydration.phaseTip!.tip)],
      ]),
      pw.SizedBox(height: 14),

      _sectionTitle('Activity & sleep'),
      _kvRow([
        ['Classes attended', '${summary.stats?.classesAttended ?? 0}'],
        ['Streak', '${summary.stats?.streakDays ?? 0} days'],
        ['Avg sleep', '${summary.stats?.avgSleepHours?.toStringAsFixed(1) ?? '-'} h'],
        ['Avg energy', '${summary.stats?.avgEnergyScore?.toStringAsFixed(1) ?? '-'} / 10'],
      ]),
      pw.SizedBox(height: 18),

      _sectionTitle('Top patterns this period'),
      if (insights.insights.isEmpty)
        pw.Text('No patterns yet - collecting data.',
            style: pw.TextStyle(fontSize: 10, color: textMuted)),
      ...insights.insights.take(3).map((i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_c(i.headline),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: textPrimary,
                    )),
                if ((i.subtitle ?? '').isNotEmpty)
                  pw.Text(_c(i.subtitle),
                      style: pw.TextStyle(fontSize: 9, color: textMuted)),
                if ((i.body ?? '').isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(_c(i.body),
                        style: pw.TextStyle(fontSize: 10, color: textPrimary)),
                  ),
              ],
            ),
          )),

      if (insights.honestyBanner != null) ...[
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEDF5EA),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(_c(insights.honestyBanner),
              style: pw.TextStyle(fontSize: 9, color: textMuted)),
        ),
      ],
    ];
  }

  // ───────── Page 2: symptom log ─────────────────────────────────────────

  List<pw.Widget> buildPage2({required SymptomsData symptoms}) {
    final headers = ['Symptom', 'Intensity', 'Change vs prev period', 'Direction', 'Datapoints'];

    return [
      pw.Text('Symptom report',
          style: pw.TextStyle(
              fontSize: 18, fontWeight: pw.FontWeight.bold, color: textPrimary)),
      pw.SizedBox(height: 4),
      pw.Text('Based on ${symptoms.basedOnCheckIns ?? 0} check-ins this period',
          style: pw.TextStyle(fontSize: 10, color: textMuted)),
      pw.SizedBox(height: 18),

      _sectionTitle('Symptom snapshot'),
      pw.Table(
        border: pw.TableBorder.all(color: borderColor),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1.4),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(1.6),
          4: pw.FlexColumnWidth(1.4),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDF5EA)),
            children: headers
                .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...symptoms.symptoms.map((s) {
            final intensity = s.intensityPct == null ? '-' : '${s.intensityPct}%';
            final delta = s.deltaPct == null
                ? '-'
                : '${s.deltaPct! > 0 ? '+' : ''}${s.deltaPct}%';
            final direction = s.direction ?? (s.notEnoughData ? 'not enough data' : '-');
            return pw.TableRow(
              children: [
                _td(s.label),
                _td(intensity),
                _td(delta),
                _td(direction),
                _td(s.notEnoughData ? '< 5' : 'sufficient'),
              ],
            );
          }),
        ],
      ),
      pw.SizedBox(height: 18),

      _sectionTitle('Notes for clinician'),
      pw.Text(
        'This report summarises self-reported symptom check-ins for the '
        'period above. Severity is on a 0-10 scale; "Change vs prev period" '
        'compares the current period\'s mean to the immediately preceding '
        'period of equal length. "Not enough data" indicates fewer than 5 '
        'logged datapoints in either window.',
        style: pw.TextStyle(fontSize: 9, color: textMuted),
      ),
    ];
  }

  // ───────── Body measurements (weekly check-in) ─────────────────────────

  static const _measures = <List<String>>[
    ['waistCm', 'Waist'],
    ['hipsCm', 'Hips'],
    ['chestCm', 'Chest'],
    ['armsCm', 'Arms'],
    ['thighsCm', 'Thighs'],
  ];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _feel = {1: 'Hard', 2: 'Okay', 3: 'Good', 4: 'Great'};

  // Plain "-" for empty cells: the PDF's built-in font has no long dash.
  String _num(double? v, String unit) {
    if (v == null) return '-';
    final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return unit.isEmpty ? t : '$t $unit';
  }

  String _date(DateTime? d) {
    if (d == null) return '-';
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  /// "Body measurements": first vs latest for each measure, then the last
  /// 8 entries. Oldest-first list in, as the history endpoint sends it.
  List<pw.Widget> _measurementsSection(List<MeasurementEntry> entries) {
    final summaryRows = <pw.TableRow>[];
    for (final m in _measures) {
      final withValue = entries.where((e) => e.cm(m[0]) != null).toList();
      if (withValue.isEmpty) continue;
      final first = withValue.first.cm(m[0])!;
      final last = withValue.last.cm(m[0])!;
      final diff = last - first;
      final change = withValue.length < 2
          ? 'first entry'
          : (diff.abs() < 0.05 ? 'no change' : '${diff > 0 ? '+' : '-'}${_num(diff.abs(), 'cm')}');
      summaryRows.add(pw.TableRow(children: [
        _td(m[1]),
        _td('${_num(first, 'cm')}  (${_date(withValue.first.date)})'),
        _td('${_num(last, 'cm')}  (${_date(withValue.last.date)})'),
        _td(change),
      ]));
    }

    pw.TableRow head(List<String> cells) => pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDF5EA)),
          children: cells
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        );

    final recent = entries.reversed.take(8).toList();
    return [
      _sectionTitle('Body measurements'),
      if (summaryRows.isEmpty)
        pw.Text('No body measurements logged yet.', style: pw.TextStyle(fontSize: 10, color: textMuted))
      else
        pw.Table(
          border: pw.TableBorder.all(color: borderColor),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(2.2),
            3: pw.FlexColumnWidth(1.4),
          },
          children: [head(['Measure', 'First', 'Latest', 'Change']), ...summaryRows],
        ),
      if (recent.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text('Recent check-ins', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textPrimary)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor),
          children: [
            head(['Date', 'Weight', 'Waist', 'Hips', 'Chest', 'Arms', 'Thighs', 'Week']),
            ...recent.map((e) => pw.TableRow(children: [
                  _td(_date(e.date)),
                  _td(_num(e.weightKg, 'kg')),
                  _td(_num(e.waistCm, '')),
                  _td(_num(e.hipsCm, '')),
                  _td(_num(e.chestCm, '')),
                  _td(_num(e.armsCm, '')),
                  _td(_num(e.thighsCm, '')),
                  _td(_feel[e.weekRating] ?? '-'),
                ])),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Measurements in cm. "Week" is how she rated the week in her check-in.',
            style: pw.TextStyle(fontSize: 8, color: textMuted)),
      ],
      pw.SizedBox(height: 14),
    ];
  }

  // ───────── shared widget helpers ───────────────────────────────────────

  /// Text from the server (tips, insights) can hold characters the PDF's
  /// built-in font can't draw (they showed as empty boxes): swap them.
  String _c(String? t) => (t ?? '')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2192', 'to')
      .replaceAll('\u0394', 'change ')
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"');

  pw.Widget _header({required String name, required String periodLabel}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('FitHer Progress Report',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: textPrimary)),
            pw.Text(name,
                style: pw.TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Text(
            periodLabel,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: textPrimary),
      ),
    );
  }

  pw.Widget _kvRow(List<List<String>> rows) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Column(
        children: rows
            .map((row) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 120,
                        child: pw.Text(row[0],
                            style: pw.TextStyle(fontSize: 10, color: textMuted)),
                      ),
                      pw.Expanded(
                        child: pw.Text(row[1],
                            style: pw.TextStyle(
                                fontSize: 10, color: textPrimary)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  pw.Widget _td(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: textPrimary)),
    );
  }

  String _formatPeriodLabel(String period) {
    switch (period) {
      case 'week':
        return 'Last week';
      case '3month':
        return 'Last 3 months';
      case '6month':
        return 'Last 6 months';
      case 'year':
        return 'Last year';
      case 'month':
      default:
        return 'This month';
    }
  }

  String _formatKg(double? kg, {bool suffixKg = false}) {
    if (kg == null) return '-';
    final sign = kg > 0 ? '+' : '';
    final abs = kg.abs().toStringAsFixed(1);
    final prefix = kg < 0 ? '-' : sign;
    return '$prefix$abs${suffixKg ? ' kg' : ' kg'}';
  }
}
