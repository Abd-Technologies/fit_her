import '../models/food_prefs/food_preferences.dart';

/// 2NH2 — phase-aware meal score (rules only, no live AI).
class PhaseFoodScore {
  final String tag; // green|amber|neutral
  final String reason;

  const PhaseFoodScore({required this.tag, required this.reason});
}

class PhaseFoodScoringService {
  static const _guides = <String, Map<String, String>>{
    'menstrual': {
      'iron': 'Iron-rich foods support recovery after your period.',
      'comfort': 'Warm, easy meals are a gentle fit this phase.',
    },
    'follicular': {
      'protein': 'Steady protein helps energy as estrogen rises.',
      'fresh': 'Fresh, lighter meals often sit well now.',
    },
    'ovulatory': {
      'fibre': 'Fibre-rich plates support hormone clearance.',
      'hydration': 'Hydrating foods pair well with peak energy.',
    },
    'luteal': {
      'carbs': 'Steady carbs can help with luteal cravings.',
      'magnesium': 'Magnesium-friendly foods may ease tension.',
    },
  };

  PhaseFoodScore score({
    required String foodName,
    required String? phase,
    FoodPreferences? prefs,
  }) {
    final name = foodName.toLowerCase();
    if (prefs != null && prefs.isAllergyBlocked(name)) {
      return const PhaseFoodScore(
        tag: 'amber',
        reason: 'Contains something on your allergy list — skip or swap.',
      );
    }
    final p = (phase ?? 'follicular').toLowerCase();
    final guide = _guides[p] ?? _guides['follicular']!;

    if (p == 'menstrual' &&
        (name.contains('spinach') ||
            name.contains('lentil') ||
            name.contains('beef') ||
            name.contains('date'))) {
      return PhaseFoodScore(tag: 'green', reason: guide['iron']!);
    }
    if (p == 'luteal' &&
        (name.contains('rice') ||
            name.contains('oat') ||
            name.contains('potato') ||
            name.contains('banana'))) {
      return PhaseFoodScore(tag: 'green', reason: guide['carbs']!);
    }
    if (p == 'follicular' &&
        (name.contains('egg') ||
            name.contains('chicken') ||
            name.contains('dal') ||
            name.contains('yogurt'))) {
      return PhaseFoodScore(tag: 'green', reason: guide['protein']!);
    }
    if (name.contains('fried') ||
        name.contains('pakora') ||
        name.contains('samosa') ||
        name.contains('sweet')) {
      return PhaseFoodScore(
        tag: 'amber',
        reason: guide.values.last,
      );
    }
    return PhaseFoodScore(
      tag: 'neutral',
      reason: guide.values.first,
    );
  }
}
