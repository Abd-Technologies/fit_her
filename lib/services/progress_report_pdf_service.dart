import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';

import '../data/models/progress_v2/measurement_entry.dart';
import '../data/models/progress_v2/progress_models.dart';
import 'progress_report_pdf_builder.dart';

/// Phase D7 — On-device PDF builder for the Progress hub's "Download PDF"
/// button. Two pages: clinical summary on page 1, day-by-day check-in log
/// on page 2. Designed so a doctor can scan it in 60 seconds.
///
/// Uses the existing `pdf: ^3.11.3` package (already in pubspec). Pattern
/// matches `lib/UI/plans_module/generate_pdf.dart`.
///
/// Why on-device: brief v2 §0 descopes the server-side report endpoint.
/// Doing it client-side avoids a backend round-trip and keeps the user's
/// data on their phone — privacy-friendly default.
///
/// Layering: this file owns the platform-specific concerns (path_provider
/// + dart:io). The pure-Dart page layout lives in
/// [ProgressReportPdfBuilder] so the smoke test can exercise it without
/// pulling in Flutter.
class ProgressReportPdfService {
  /// Default branding. Pass overrides to swap to a clinical-neutral palette
  /// in case product wants the PDF to look less consumer-facing later.
  final PdfColor primary;
  final PdfColor textPrimary;
  final PdfColor textMuted;
  final PdfColor borderColor;

  ProgressReportPdfService({
    this.primary = const PdfColor.fromInt(0xFF6DC55A),
    this.textPrimary = const PdfColor.fromInt(0xFF163220),
    this.textMuted = const PdfColor.fromInt(0xFF6F8B7A),
    this.borderColor = const PdfColor.fromInt(0xFFD8EDD4),
  });

  ProgressReportPdfBuilder get _builder => ProgressReportPdfBuilder(
        primary: primary,
        textPrimary: textPrimary,
        textMuted: textMuted,
        borderColor: borderColor,
      );

  /// Generate the PDF and persist it to the app's documents directory.
  /// Returns `(file, bytes, pageCount)` so the caller can pick whichever
  /// fits their share-sheet API.
  Future<ProgressReportPdfResult> generate({
    required ProgressSummary summary,
    required WeightTrend weight,
    required HydrationData hydration,
    required SymptomsData symptoms,
    required InsightsHubData insights,
    String? userFullName,
    // Weekly check-in measurements (WeeklyCheckinSheet.loadHistory()).
    List<MeasurementEntry> measurements = const [],
  }) async {
    final doc = _builder.buildDocument(
      summary: summary,
      weight: weight,
      hydration: hydration,
      symptoms: symptoms,
      insights: insights,
      userFullName: userFullName,
      measurements: measurements,
    );

    final bytes = await doc.save();

    // App documents directory — same convention as generate_pdf.dart.
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'fither_progress_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    // ignore: avoid_print
    print('[ProgressReportPdfService] wrote ${bytes.length} bytes to ${file.path}');
    return ProgressReportPdfResult(file: file, bytes: bytes, pageCount: 2);
  }
}

/// Result bundle from [ProgressReportPdfService.generate].
class ProgressReportPdfResult {
  final File file;
  final Uint8List bytes;
  final int pageCount;
  const ProgressReportPdfResult({
    required this.file,
    required this.bytes,
    required this.pageCount,
  });
}
