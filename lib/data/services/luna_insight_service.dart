import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../controllers/daily_log_controller/daily_log_controller.dart';
import 'behavior_signal_service.dart';
import 'tone_personalization_service.dart';

/// Five-part Luna card model (1NH12). Built from local logs / templates —
/// never a live LLM call on open.
class LunaCard {
  final String phase;
  final String feel;
  final String foodTip;
  final String movementTip;
  final String sleepNote;
  final DateTime builtAt;
  final bool fromServer;

  const LunaCard({
    required this.phase,
    required this.feel,
    required this.foodTip,
    required this.movementTip,
    required this.sleepNote,
    required this.builtAt,
    this.fromServer = false,
  });

  Map<String, dynamic> toJson() => {
        'phase': phase,
        'feel': feel,
        'foodTip': foodTip,
        'movementTip': movementTip,
        'sleepNote': sleepNote,
        'builtAt': builtAt.toIso8601String(),
        'fromServer': fromServer,
      };

  factory LunaCard.fromJson(Map<String, dynamic> json) {
    return LunaCard(
      phase: json['phase']?.toString() ?? '',
      feel: json['feel']?.toString() ?? '',
      foodTip: json['foodTip']?.toString() ?? '',
      movementTip: json['movementTip']?.toString() ?? '',
      sleepNote: json['sleepNote']?.toString() ?? '',
      builtAt: DateTime.tryParse(json['builtAt']?.toString() ?? '') ??
          DateTime.now(),
      fromServer: json['fromServer'] == true,
    );
  }
}

class LunaInsightService extends GetxService {
  static const _cacheKey = 'd1_luna_card_v1';
  static const _phaseMsgKey = 'd1_phase_msg_idx';

  final SharedPreferences prefs;

  LunaInsightService({required this.prefs});

  final Rxn<LunaCard> todayCard = Rxn<LunaCard>();

  static const _phaseMessages = <String, List<String>>{
    'menstrual': [
      'Your body is resetting — gentle movement and warm meals help today.',
      'Rest is productive. Keep water close and keep expectations soft.',
      'Iron-rich foods support you in this phase. Listen to your energy.',
    ],
    'follicular': [
      'Energy is rising — a good day to try something new.',
      'Your focus often sharpens here. Plan the week while you feel clear.',
      'Lean into strength; recovery still matters between sessions.',
    ],
    'ovulation': [
      'Peak energy window — use it for your hardest workout if you feel ready.',
      'Connection and confidence often rise now. Trust your pace.',
      'Stay hydrated; higher activity needs more water today.',
    ],
    'luteal': [
      'Slow the pace — shorter sessions and steady carbs help.',
      'Mood may dip; a short walk and early sleep make a difference.',
      'Cravings are common. Pair sweets with protein when you can.',
    ],
  };

  @override
  void onInit() {
    super.onInit();
    refreshCard();
  }

  String _phaseName() {
    try {
      return Get.find<CycleThemeController>().phase.value.name;
    } catch (_) {
      return 'follicular';
    }
  }

  /// Free tier rotating phase message (1NH14). Stable for the calendar day.
  String freePhaseMessage() {
    final phase = _phaseName();
    final list = _phaseMessages[phase] ?? _phaseMessages['follicular']!;
    final dayKey =
        DateTime.now().toIso8601String().substring(0, 10);
    final cacheKey = '$_phaseMsgKey:$phase:$dayKey';
    final cached = prefs.getInt(cacheKey);
    if (cached != null) return list[cached % list.length];
    final idx = dayKey.hashCode.abs() % list.length;
    prefs.setInt(cacheKey, idx);
    return list[idx];
  }

  /// Prefer cached/server-shaped payload; else build from local logs.
  LunaCard refreshCard({String? serverInsightText}) {
    final phase = _phaseName();
    if (serverInsightText != null && serverInsightText.trim().isNotEmpty) {
      final card = _fromServerText(phase, serverInsightText.trim());
      todayCard.value = card;
      _cache(card);
      return card;
    }

    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final card = LunaCard.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        final sameDay = card.builtAt.day == DateTime.now().day &&
            card.builtAt.month == DateTime.now().month;
        if (sameDay && card.phase == phase) {
          todayCard.value = card;
          return card;
        }
      } catch (_) {}
    }

    final card = _buildFromLogs(phase);
    todayCard.value = card;
    _cache(card);
    return card;
  }

  LunaCard _fromServerText(String phase, String text) {
    final parts = text.split(RegExp(r'\n+|(?<=[.!?])\s+'));
    String pick(int i, String fallback) =>
        i < parts.length && parts[i].trim().isNotEmpty
            ? parts[i].trim()
            : fallback;
    return _withTone(LunaCard(
      phase: 'You are in your $phase phase.',
      feel: pick(0, _feelFallback(phase)),
      foodTip: pick(1, _foodFallback(phase)),
      movementTip: pick(2, _moveFallback(phase)),
      sleepNote: pick(3, _sleepFallback()),
      builtAt: DateTime.now(),
      fromServer: true,
    ));
  }

  LunaCard _buildFromLogs(String phase) {
    int? mood;
    int? energy;
    int? stress;
    double? sleep;
    if (Get.isRegistered<DailyLogController>()) {
      final c = Get.find<DailyLogController>().todayCheckin.value;
      mood = c?.mood;
      energy = c?.energy;
      stress = c?.stress;
      sleep = c?.sleepHours;
    }

    String preferred = 'food';
    if (Get.isRegistered<BehaviorSignalService>()) {
      preferred =
          Get.find<BehaviorSignalService>().preferredInsightType() ?? 'food';
    }

    final feel = mood != null || energy != null
        ? _feelFromLogs(mood, energy, stress)
        : _feelFallback(phase);

    return _withTone(LunaCard(
      phase: 'You are in your $phase phase today.',
      feel: feel,
      foodTip: preferred == 'food'
          ? _foodFallback(phase)
          : _foodFallback(phase),
      movementTip: _moveFallback(phase, energy: energy),
      sleepNote: sleep != null
          ? 'You logged ${sleep.toStringAsFixed(1)}h sleep — aim for a steady bedtime tonight.'
          : _sleepFallback(),
      builtAt: DateTime.now(),
    ));
  }

  /// 3NH4 — swap wording by preferred tone without extra AI cost.
  LunaCard _withTone(LunaCard card) {
    if (!Get.isRegistered<TonePersonalizationService>()) return card;
    final tone = Get.find<TonePersonalizationService>();
    String t(String calm) => tone.rewrite(calm);
    return LunaCard(
      phase: t(card.phase),
      feel: t(card.feel),
      foodTip: t(card.foodTip),
      movementTip: t(card.movementTip),
      sleepNote: t(card.sleepNote),
      builtAt: card.builtAt,
      fromServer: card.fromServer,
    );
  }

  String _feelFromLogs(int? mood, int? energy, int? stress) {
    if ((stress ?? 0) >= 4) {
      return 'Stress is running high. Keep today simple and protective.';
    }
    if ((energy ?? 3) <= 2) {
      return 'Energy is low — favour gentle movement and warm food.';
    }
    if ((mood ?? 3) >= 4) {
      return 'Mood looks steady. A good day to stay consistent.';
    }
    return 'How you feel today tracks with your recent logs — stay kind to yourself.';
  }

  String _feelFallback(String phase) {
    switch (phase) {
      case 'menstrual':
        return 'You may feel quieter and more sensitive today.';
      case 'ovulation':
        return 'You may feel more energetic and social today.';
      case 'luteal':
        return 'You may feel slower or more easily tired today.';
      default:
        return 'Energy often builds in this phase.';
    }
  }

  String _foodFallback(String phase) {
    switch (phase) {
      case 'menstrual':
        return 'Food tip: warm daal and iron-rich greens support this phase.';
      case 'luteal':
        return 'Food tip: steady carbs (roti + daal) help with cravings.';
      case 'ovulation':
        return 'Food tip: colourful salads and lean protein keep you sharp.';
      default:
        return 'Food tip: balanced plates with protein at each meal.';
    }
  }

  String _moveFallback(String phase, {int? energy}) {
    if ((energy ?? 3) <= 2) {
      return 'Movement: a short walk or stretch is enough today.';
    }
    switch (phase) {
      case 'menstrual':
        return 'Movement: keep intensity gentle; mobility over load.';
      case 'ovulation':
        return 'Movement: you can push a little harder if you feel ready.';
      case 'luteal':
        return 'Movement: moderate effort; shorter sessions win.';
      default:
        return 'Movement: build strength steadily this phase.';
    }
  }

  String _sleepFallback() =>
      'Sleep: a wind-down hour without screens helps tonight.';

  void _cache(LunaCard card) {
    prefs.setString(_cacheKey, jsonEncode(card.toJson()));
  }

  /// First-week messages (1P12) when logs are thin.
  String firstWeekMessage(int dayIndex) {
    const pack = [
      'Welcome — start with a 30-second check-in today.',
      'Day 2: log water once; it unlocks better tips.',
      'Day 3: note how you slept; Luna uses it tomorrow.',
      'Day 4: try logging one symptom if you feel it.',
      'Day 5: a short walk counts — mark it when you can.',
      'Day 6: notice one food that left you feeling good.',
      'Day 7: you are building a picture of your body. Keep going.',
    ];
    return pack[dayIndex.clamp(0, pack.length - 1)];
  }

  // ignore: unused_element
  int _rand(int max) => Random().nextInt(max);
}
