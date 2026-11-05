import 'package:fitness_zone_2/widgets/weekly_checkin/weekly_checkin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

WeeklyCheckinState st(Map<String, dynamic> extra) => WeeklyCheckinState.fromJson({
      'due': true,
      'checkinDay': 7,
      'planType': 'combined',
      'checkinsDone': 1,
      'start': {'date': '2026-10-01T00:00:00Z', 'weightKg': 70},
      'last': {'date': '2026-10-16T00:00:00Z', 'weightKg': 69.4, 'waistCm': 82, 'hipsCm': 101},
      ...extra,
    });

Future<void> pump(WidgetTester t, WeeklyCheckinState s, {bool logOnly = false}) async {
  await t.binding.setSurfaceSize(const Size(600, 3000));
  await t.pumpWidget(GetMaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: WeeklyCheckinSheet(state: s, result: WeeklyCheckinResult(), logOnly: logOnly),
      ),
    ),
  ));
  await t.pump();
}

void main() {
  testWidgets('week 1, both plans', (t) async {
    await pump(t, st({'label': 'week1', 'checkinsDone': 0, 'sections': {'diet': true, 'workout': true}}));
    expect(find.text('🥗 Your diet plan'), findsOneWidget);
    expect(find.text('🏋️ Your workouts'), findsOneWidget);
    expect(find.text('START · FROM SIGN-UP'), findsOneWidget);
    expect(find.text('Save check-in'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('weekly, core only', (t) async {
    await pump(t, st({'label': 'weekly', 'checkinDay': 21, 'sections': {}}));
    expect(find.text('🥗 Your diet plan'), findsNothing);
    expect(find.text('LAST TIME'), findsOneWidget);
    expect(find.text('Since you started'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('halfway, diet only', (t) async {
    await pump(t, st({'label': 'halfway', 'checkinDay': 14, 'planType': 'diet', 'sections': {'diet': true, 'milestone': 'halfway'}}));
    expect(find.text('🏋️ Your workouts'), findsNothing);
    expect(find.text('⭐ Halfway check'), findsOneWidget);
    expect(find.text('Save & book my follow-up'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('end of package', (t) async {
    await pump(t, st({'label': 'end', 'checkinDay': 28, 'endOfPackage': true, 'sections': {'diet': true, 'workout': true, 'milestone': 'end'}}));
    expect(find.text('Save & see renewal plans'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('log measurements only', (t) async {
    await pump(t, WeeklyCheckinState.fromJson({
      'due': false, 'reason': 'no_plan', 'checkinsDone': 0,
      'last': {'date': '2026-10-16T00:00:00Z', 'weightKg': 69.4, 'waistCm': 82},
    }), logOnly: true);
    expect(find.text('Save measurements'), findsOneWidget);
    expect(find.text('How was your week?'), findsNothing);
    expect(find.text('LAST TIME'), findsOneWidget);
    expect(find.text('TODAY · CHANGE WHAT MOVED'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test('labels', () {
    final s = st({'label': 'weekly', 'checkinDay': 21});
    expect(s.cardTitle, "Log this week's weight");
    expect(s.cardSubtitle, startsWith('Last time 69.4 kg'));
  });
}
