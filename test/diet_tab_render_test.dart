import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import 'package:fitness_zone_2/data/Repos/diet_plan_v2/diet_plan_user_repository.dart';
import 'package:fitness_zone_2/data/models/diet_plan_v2/diet_plan_v2_models.dart';
import 'package:fitness_zone_2/widgets/new_home/phase_theme.dart';
import 'package:fitness_zone_2/widgets/v2/v2_diet_hero.dart';
import 'package:fitness_zone_2/widgets/v2/v2_today_meals_section.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

class FakeAuth extends GetxController implements AuthController {
  @override
  String get userTimeZone => 'Asia/Karachi';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class FakeRepo implements DietPlanUserRepository {
  @override
  dynamic noSuchMethod(Invocation i) => Future.value(null);
}

final shot = GlobalKey();

Map<String, dynamic> meal(int id, String type, String time, String name, int kcal) =>
    {'id': id, 'mealType': type, 'time': time, 'foodName': name, 'calories': kcal, 'notes': 'A wholesome choice for energy.'};

Future<void> pump(WidgetTester t, int planDays, int dayOffset, {PhaseTheme phase = PhaseTheme.menstrual, BookingContextV2? ctx}) async {
  Get.find<CycleThemeController>().theme.value = phase;
  final days = [
    for (var d = 1; d <= planDays; d++)
      {
        'dayNumber': d,
        'totalCalories': 1720,
        'meals': [
          meal(d * 10 + 1, 'breakfast', '08:00', 'Oats Porridge with Milk, Berries, and Chia Seeds', 380),
          meal(d * 10 + 2, 'mid_morning', '11:00', 'Greek yogurt with walnuts', 180),
          meal(d * 10 + 3, 'lunch', '13:30', 'Chicken and lentil rice bowl', 520),
          meal(d * 10 + 4, 'afternoon_snack', '16:30', 'Apple with peanut butter', 160),
          meal(d * 10 + 5, 'dinner', '19:30', 'Grilled fish with vegetables', 480),
        ],
      }
  ];
  final plan = DietPlanV2.fromJson({
    'id': 1,
    'planDays': planDays,
    'status': 'active',
    'activatedAt': DateTime.now().subtract(Duration(days: dayOffset)).toIso8601String(),
    'days': days,
  });
  final ctrl = DietPlanUserController(repo: FakeRepo(), auth: FakeAuth());
  Get.put<DietPlanUserController>(ctrl);
  ctrl.activePlan.value = plan;
  if (ctx != null) ctrl.bookingContext.value = ctx;
  t.view.physicalSize = const Size(414, 1600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ScreenUtilInit(
    designSize: const Size(414, 1600),
    builder: (_, __) => GetMaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF3F8EF),
        body: SingleChildScrollView(
          child: RepaintBoundary(key: shot, child: Column(children: const [V2DietHero(todayCard: true), V2TodayMealsSection(compact: true)])),
        ),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = CycleThemeController(prefs: prefs);
    Get.put(c);
    c.theme.value = PhaseTheme.menstrual;
  });
  tearDown(() => Get.delete<DietPlanUserController>(force: true));

  testWidgets('paid: today card, no ending card, no strip, no summary', (t) async {
    await pump(t, 3, 1);
    expect(find.textContaining('0 of 5', findRichText: true), findsOneWidget);
    expect(find.textContaining('2 of 3', findRichText: true), findsOneWidget);
    expect(find.text('Your plan ends tomorrow'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('only one meal card open; tapping another opens it', (t) async {
    await pump(t, 3, 1);
    expect(find.text('Log this meal'), findsOneWidget);
    await t.tap(find.text('Dinner'));
    await t.pump();
    expect(find.text('Log this meal'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('plan starting tomorrow says when, not "complete"', (t) async {
    await pump(t, 3, -1);
    expect(find.textContaining('Your plan starts on'), findsOneWidget);
    expect(find.textContaining('complete'), findsNothing);
    expect(t.takeException(), isNull);
  });

  BookingContextV2 ctxOf(String step, {int endsInDays = 15, DateTime? opens}) => BookingContextV2(
        userId: 1, userPlanId: 1, dietitianId: 2, nextStep: step,
        packageEndsOn: DateTime.now().add(Duration(days: endsInDays)), halfwayOpensOn: opens);

  testWidgets('15-day plan ended, package running: repeats from Day 1 + book follow-up', (t) async {
    await pump(t, 15, 17, ctx: ctxOf('book_followup'));
    expect(find.text('Keep going with your plan 🔁'), findsOneWidget);
    expect(find.text('Book follow-up'), findsOneWidget);
    expect(find.textContaining('3 of 15', findRichText: true), findsOneWidget);
    expect(find.text('Log this meal'), findsOneWidget);
    expect(t.takeException(), isNull);
    await expectLater(find.byKey(shot), matchesGoldenFile('goldens/diet_repeat.png'));
  });

  testWidgets('check-in not open yet: shows the date, no button', (t) async {
    await pump(t, 15, 15, ctx: ctxOf('day15_checkin', opens: DateTime.now().add(const Duration(days: 2))));
    expect(find.textContaining('Your check-in opens on'), findsOneWidget);
    expect(find.text('Do my check-in'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('renew far from package end: no renew button', (t) async {
    await pump(t, 15, 20, ctx: ctxOf('renew', endsInDays: 10));
    expect(find.text('Renew my plan'), findsNothing);
    expect(find.textContaining("You've had both consultations"), findsOneWidget);
  });

  testWidgets('renew near package end: renew button', (t) async {
    await pump(t, 15, 20, ctx: ctxOf('renew', endsInDays: 3));
    expect(find.text('Renew my plan'), findsOneWidget);
  });

  testWidgets('last day of plan: heads-up strip', (t) async {
    await pump(t, 15, 14, ctx: ctxOf('book_followup'));
    expect(find.text('Your plan ends today'), findsOneWidget);
    expect(find.text('Book follow-up'), findsOneWidget);
  });

  testWidgets('package ended: plan-complete card, no repeat', (t) async {
    await pump(t, 15, 17, ctx: BookingContextV2(userId: 1, userPlanId: 1, dietitianId: 2, nextStep: 'renew', planEnded: true));
    expect(find.text('PLAN COMPLETED'), findsOneWidget);
    expect(find.text('Keep going with your plan 🔁'), findsNothing);
  });

  testWidgets('30-day plan, day 12 (scrolling day picker)', (t) async {
    await pump(t, 30, 11);
    expect(find.textContaining('12 of 30', findRichText: true), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('future day shows Coming up', (t) async {
    await pump(t, 3, 1);
    Get.find<DietPlanUserController>().selectDay(3);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Coming up'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final ph in [PhaseTheme.menstrual, PhaseTheme.follicular, PhaseTheme.ovulatory, PhaseTheme.luteal]) {
    testWidgets('golden ${ph.phaseLabel}', (t) async {
      await pump(t, 3, 1, phase: ph);
      await expectLater(find.byKey(shot), matchesGoldenFile('goldens/diet_${ph.phaseLabel}.png'));
    });
  }
}
