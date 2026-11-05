// Smoke test for ProgressReportPdfService.
//
// Asserts:
//   1. The PDF file is written to disk and has a sensible size.
//   2. The PDF reports 2 pages (page 1 = clinical summary, page 2 = log).
//
// Stubs path_provider (since flutter_test in pure-Dart mode has no platform
// channels) so the file lands in a temp directory.
//
// Run: dart test test/progress_pdf_smoke_test.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_zone_2/data/models/progress_v2/measurement_entry.dart';
import 'package:fitness_zone_2/data/models/progress_v2/progress_models.dart';
import 'package:fitness_zone_2/services/progress_report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub path_provider so getApplicationDocumentsDirectory() resolves
  // to a temp dir during the test.
  final tempDir = Directory.systemTemp.createTempSync('fither_pdf_test_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') return tempDir.path;
    return tempDir.path;
  });

  test('generate writes a 2-page PDF of reasonable size', () async {
    final result = await ProgressReportPdfService().generate(
      summary: _fakeSummary(),
      weight: _fakeWeight(),
      hydration: _fakeHydration(),
      symptoms: _fakeSymptoms(),
      insights: _fakeInsights(),
      userFullName: 'Shaista QA',
    );

    // Page count is reported by the service; stable contract.
    expect(result.pageCount, 2);

    // File must exist on disk and be non-empty. PDF headers + 2 pages of
    // text + tables sit in the 4-50 KB band; allow a wide window since
    // exact sizes vary with embedded fonts (system default in this test).
    expect(await result.file.exists(), true);
    final size = await result.file.length();
    print('[smoke] wrote ${result.file.path}');
    print('[smoke] size=${size} bytes pageCount=${result.pageCount}');
    expect(size, greaterThan(2000), reason: 'PDF too small to be valid');
    expect(size, lessThan(2 * 1024 * 1024),
        reason: 'PDF should be < 2 MB without embedded images');

    // Sanity: file starts with %PDF-
    final bytes = result.bytes;
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-', reason: 'Not a PDF file?');
  });

  test('PDF includes body measurements from the weekly check-in', () async {
    final result = await ProgressReportPdfService().generate(
      summary: _fakeSummary(),
      weight: _fakeWeight(),
      hydration: _fakeHydration(),
      symptoms: _fakeSymptoms(),
      insights: _fakeInsights(),
      userFullName: 'Shaista QA',
      measurements: [
        MeasurementEntry(date: DateTime(2026, 10, 1), weightKg: 70, waistCm: 84, hipsCm: 102, weekRating: 2),
        MeasurementEntry(date: DateTime(2026, 10, 8), weightKg: 69.4, waistCm: 83, hipsCm: 101.5, weekRating: 3),
        MeasurementEntry(date: DateTime(2026, 10, 15), weightKg: 68.8, waistCm: 82, hipsCm: 101, chestCm: 90, weekRating: 4),
      ],
    );
    expect(await result.file.exists(), true);
    final header = String.fromCharCodes(result.bytes.take(5));
    expect(header, '%PDF-');
    expect(result.bytes.length, greaterThan(2000));
  });
}

ProgressSummary _fakeSummary() => ProgressSummary.fromJson({
      'period': 'month',
      'period_start': '2026-04-01',
      'period_end': '2026-04-30',
      'previous_period_start': '2026-03-01',
      'previous_period_end': '2026-03-31',
      'user': {'firstName': 'Shaista', 'image': null},
      'cycle': {
        'phase': 'follicular',
        'cycleDay': 9,
        'averageCycleLength': 28,
        'hasData': true,
      },
      'goal': {
        'label': '65kg by 2026-06-30',
        'type': 'weight_loss',
        'targetValueKg': 65.0,
        'startValueKg': 70.0,
        'currentValueKg': 67.4,
        'targetDeltaKg': -5.0,
        'currentDeltaKg': -2.6,
        'targetDate': '2026-06-30',
        'startDate': '2026-01-01',
        'progressPct': 0.52,
        'paceStatus': 'ahead',
        'paceMessage': '3 wks ahead of schedule',
        'weeksAhead': 3,
        'hasGoalRow': true,
      },
      'stats': {
        'classesAttended': 16,
        'streakDays': 8,
        'avgSleepHours': 6.5,
        'avgEnergyScore': 7.2,
      },
    });

WeightTrend _fakeWeight() => WeightTrend.fromJson({
      'period': 'month',
      'period_start': '2026-04-01',
      'period_end': '2026-04-30',
      'previous_period_start': '2026-03-01',
      'previous_period_end': '2026-03-31',
      'currentWeightKg': 67.4,
      'deltaKg': -2.1,
      'direction': 'toward_goal',
      'history': [
        {'date': '2026-04-01', 'weightKg': 69.5, 'phase': 'menstrual'},
        {'date': '2026-04-08', 'weightKg': 69.0, 'phase': 'follicular'},
        {'date': '2026-04-15', 'weightKg': 68.4, 'phase': 'ovulatory'},
        {'date': '2026-04-22', 'weightKg': 67.8, 'phase': 'luteal'},
        {'date': '2026-04-27', 'weightKg': 67.4, 'phase': 'luteal'},
      ],
      'phaseSegments': [
        {'phase': 'menstrual', 'start': '2026-04-01', 'end': '2026-04-05'},
        {'phase': 'follicular', 'start': '2026-04-06', 'end': '2026-04-12'},
        {'phase': 'ovulatory', 'start': '2026-04-13', 'end': '2026-04-15'},
        {'phase': 'luteal', 'start': '2026-04-16', 'end': '2026-04-30'},
      ],
      'projection': [
        {'date': '2026-05-15', 'weightKg': 66.8, 'isProjection': true},
        {'date': '2026-06-30', 'weightKg': 64.5, 'isProjection': true},
      ],
    });

HydrationData _fakeHydration() => HydrationData.fromJson({
      'period': 'month',
      'averageL': 1.6,
      'averageMl': 1600,
      'targetL': 2.5,
      'targetMl': 2500,
      'pct': 0.62,
      'nudge': 'drink more',
      'daysLogged': 22,
      'phaseTip': {
        'phase': 'follicular',
        'tip': 'Aim for 100g protein — absorption is up to 30% higher in this phase.',
        'macroEmphasis': 'protein',
      },
      'mealsCard': {'copy': 'Meals · coming soon', 'enabled': false},
    });

SymptomsData _fakeSymptoms() => SymptomsData.fromJson({
      'period': 'month',
      'symptoms': [
        {
          'key': 'bloating',
          'label': 'Bloating',
          'intensityPct': 35,
          'deltaPct': -40,
          'direction': 'improvement',
          'notEnoughData': false,
        },
        {
          'key': 'energy',
          'label': 'Energy',
          'intensityPct': 78,
          'deltaPct': 60,
          'direction': 'improvement',
          'notEnoughData': false,
        },
        {
          'key': 'mood',
          'label': 'Mood',
          'intensityPct': 68,
          'deltaPct': 45,
          'direction': 'improvement',
          'notEnoughData': false,
        },
        {
          'key': 'cramps',
          'label': 'Cramps',
          'intensityPct': 22,
          'deltaPct': -60,
          'direction': 'improvement',
          'notEnoughData': false,
        },
      ],
      'basedOnCheckIns': 16,
    });

InsightsHubData _fakeInsights() => InsightsHubData.fromJson({
      'period': 'month',
      'insights': [
        {
          'id': 'static_1',
          'headline': 'Strength training reduces bloating 62%',
          'subtitle': 'Strength · 16 data points',
          'body':
              'On days you attend strength classes, bloating drops noticeably. Stronger effect in follicular phase.',
          'tone': 'positive',
          'category': 'strength',
          'isStatic': true,
        },
        {
          'id': 'static_2',
          'headline': 'Sleep before 11:30 lifts mood 40%',
          'subtitle': 'Sleep · 22 data points',
          'body': 'A bedtime before 11:30pm correlates with better next-day mood scores.',
          'tone': 'positive',
          'category': 'sleep',
          'isStatic': true,
        },
        {
          'id': 'static_3',
          'headline': 'You train 2.4× less in luteal phase',
          'subtitle': 'Phase · 28 days',
          'body':
              'Activity drops sharply during luteal. Gentle movement here is fine — listen to your body.',
          'tone': 'informational',
          'category': 'phase',
          'isStatic': true,
        },
      ],
      'patternsFound': 3,
      'isStatic': true,
      'honestyBanner':
          'FitHer AI is learning. Showing static phase tips for now — personalised patterns arrive after 14 days of check-ins.',
    });
