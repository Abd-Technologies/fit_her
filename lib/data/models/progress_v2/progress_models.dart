// Phase D — Progress Hub data models.
//
// One file per concern would be over-engineered for v1. All six endpoint
// payloads live here together with shared parsing helpers.
//
// Each top-level class has:
//   * a const default constructor with safe nulls
//   * `.empty()` factory for "no data yet" controller initial state
//   * `.fromJson(Map)` that consumes the response body's `data` block
//
// Shapes mirror the Phase B brief §4.3 sample exactly. Field names are
// camelCase end-to-end (controller and JSON match) — period_start and
// period_end are the only snake_case keys we accept, matching the backend.

// ───────── shared envelope ──────────────────────────────────────────────

class PeriodWindow {
  final String period;
  final String? periodStart;
  final String? periodEnd;
  final String? previousPeriodStart;
  final String? previousPeriodEnd;

  const PeriodWindow({
    this.period = 'month',
    this.periodStart,
    this.periodEnd,
    this.previousPeriodStart,
    this.previousPeriodEnd,
  });

  factory PeriodWindow.fromJson(Map<String, dynamic> json) => PeriodWindow(
        period: (json['period'] as String?) ?? 'month',
        periodStart: json['period_start'] as String?,
        periodEnd: json['period_end'] as String?,
        previousPeriodStart: json['previous_period_start'] as String?,
        previousPeriodEnd: json['previous_period_end'] as String?,
      );
}

// ───────── /summary ─────────────────────────────────────────────────────

class ProgressSummary {
  final PeriodWindow window;
  final SummaryUser? user;
  final SummaryCycle? cycle;
  final SummaryGoal? goal;
  final SummaryStats? stats;

  const ProgressSummary({
    this.window = const PeriodWindow(),
    this.user,
    this.cycle,
    this.goal,
    this.stats,
  });

  factory ProgressSummary.empty() => const ProgressSummary();

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      window: PeriodWindow.fromJson(json),
      user: _parseObject(json['user'], SummaryUser.fromJson),
      cycle: _parseObject(json['cycle'], SummaryCycle.fromJson),
      goal: _parseObject(json['goal'], SummaryGoal.fromJson),
      stats: _parseObject(json['stats'], SummaryStats.fromJson),
    );
  }
}

class SummaryUser {
  final String? firstName;
  final String? image;
  const SummaryUser({this.firstName, this.image});
  factory SummaryUser.fromJson(Map<String, dynamic> json) => SummaryUser(
        firstName: json['firstName'] as String?,
        image: json['image'] as String?,
      );
}

class SummaryCycle {
  final String? phase;
  final int? cycleDay;
  final int? averageCycleLength;
  final bool? hasData;

  const SummaryCycle({this.phase, this.cycleDay, this.averageCycleLength, this.hasData});

  factory SummaryCycle.fromJson(Map<String, dynamic> json) => SummaryCycle(
        phase: json['phase'] as String?,
        cycleDay: _toInt(json['cycleDay']),
        averageCycleLength: _toInt(json['averageCycleLength']),
        hasData: json['hasData'] as bool?,
      );
}

class SummaryGoal {
  final String? label;
  final String? type;
  final double? targetValueKg;
  final double? startValueKg;
  final double? currentValueKg;
  final double? targetDeltaKg;
  final double? currentDeltaKg;
  final String? targetDate;
  final String? startDate;
  final double? progressPct;
  final String? paceStatus;
  final String? paceMessage;
  final int? weeksAhead;
  final bool? hasGoalRow;

  const SummaryGoal({
    this.label,
    this.type,
    this.targetValueKg,
    this.startValueKg,
    this.currentValueKg,
    this.targetDeltaKg,
    this.currentDeltaKg,
    this.targetDate,
    this.startDate,
    this.progressPct,
    this.paceStatus,
    this.paceMessage,
    this.weeksAhead,
    this.hasGoalRow,
  });

  factory SummaryGoal.fromJson(Map<String, dynamic> json) => SummaryGoal(
        label: json['label'] as String?,
        type: json['type'] as String?,
        targetValueKg: _toDouble(json['targetValueKg']),
        startValueKg: _toDouble(json['startValueKg']),
        currentValueKg: _toDouble(json['currentValueKg']),
        targetDeltaKg: _toDouble(json['targetDeltaKg']),
        currentDeltaKg: _toDouble(json['currentDeltaKg']),
        targetDate: json['targetDate'] as String?,
        startDate: json['startDate'] as String?,
        progressPct: _toDouble(json['progressPct']),
        paceStatus: json['paceStatus'] as String?,
        paceMessage: json['paceMessage'] as String?,
        weeksAhead: _toInt(json['weeksAhead']),
        hasGoalRow: json['hasGoalRow'] as bool?,
      );
}

class SummaryStats {
  final int? classesAttended;
  final int? streakDays;
  final double? avgSleepHours;
  final double? avgEnergyScore;

  const SummaryStats({this.classesAttended, this.streakDays, this.avgSleepHours, this.avgEnergyScore});

  factory SummaryStats.fromJson(Map<String, dynamic> json) => SummaryStats(
        classesAttended: _toInt(json['classesAttended']),
        streakDays: _toInt(json['streakDays']),
        avgSleepHours: _toDouble(json['avgSleepHours']),
        avgEnergyScore: _toDouble(json['avgEnergyScore']),
      );
}

// ───────── /weight ──────────────────────────────────────────────────────

class WeightTrend {
  final PeriodWindow window;
  final double? currentWeightKg;
  final double? deltaKg;
  final String? direction;
  final List<WeightHistoryPoint> history;
  final List<PhaseSegmentJson> phaseSegments;
  final List<WeightProjectionPoint> projection;
  /// All time (Oct 2026): her first weigh-in date and how many she logged.
  /// Null / 0 from an older server.
  final String? firstWeighInDate;
  final int weighIns;

  const WeightTrend({
    this.window = const PeriodWindow(),
    this.currentWeightKg,
    this.deltaKg,
    this.direction,
    this.history = const [],
    this.phaseSegments = const [],
    this.projection = const [],
    this.firstWeighInDate,
    this.weighIns = 0,
  });

  factory WeightTrend.empty() => const WeightTrend();

  factory WeightTrend.fromJson(Map<String, dynamic> json) => WeightTrend(
        window: PeriodWindow.fromJson(json),
        currentWeightKg: _toDouble(json['currentWeightKg']),
        deltaKg: _toDouble(json['deltaKg']),
        direction: json['direction'] as String?,
        history: _parseList(json['history'], WeightHistoryPoint.fromJson),
        phaseSegments: _parseList(json['phaseSegments'], PhaseSegmentJson.fromJson),
        projection: _parseList(json['projection'], WeightProjectionPoint.fromJson),
        firstWeighInDate: json['firstWeighInDate']?.toString(),
        weighIns: (json['weighIns'] is num) ? (json['weighIns'] as num).toInt() : 0,
      );
}

class WeightHistoryPoint {
  final String? date;
  final double? weightKg;
  final String? phase;
  const WeightHistoryPoint({this.date, this.weightKg, this.phase});
  factory WeightHistoryPoint.fromJson(Map<String, dynamic> json) => WeightHistoryPoint(
        date: json['date'] as String?,
        weightKg: _toDouble(json['weightKg']),
        phase: json['phase'] as String?,
      );
}

class PhaseSegmentJson {
  final String? phase;
  final String? start;
  final String? end;
  const PhaseSegmentJson({this.phase, this.start, this.end});
  factory PhaseSegmentJson.fromJson(Map<String, dynamic> json) => PhaseSegmentJson(
        phase: json['phase'] as String?,
        start: json['start'] as String?,
        end: json['end'] as String?,
      );
}

class WeightProjectionPoint {
  final String? date;
  final double? weightKg;
  final bool? isProjection;
  const WeightProjectionPoint({this.date, this.weightKg, this.isProjection});
  factory WeightProjectionPoint.fromJson(Map<String, dynamic> json) => WeightProjectionPoint(
        date: json['date'] as String?,
        weightKg: _toDouble(json['weightKg']),
        isProjection: json['isProjection'] as bool?,
      );
}

// ───────── /glance ──────────────────────────────────────────────────────

class GlanceData {
  final PeriodWindow window;
  final List<GlanceRing> rings;

  const GlanceData({
    this.window = const PeriodWindow(),
    this.rings = const [],
  });

  factory GlanceData.empty() => const GlanceData();

  factory GlanceData.fromJson(Map<String, dynamic> json) => GlanceData(
        window: PeriodWindow.fromJson(json),
        rings: _parseList(json['rings'], GlanceRing.fromJson),
      );
}

class GlanceRing {
  final String key;
  final String label;
  final double? value;
  final double? target;
  final String? unit;
  final double pct;
  final String? nudge;
  final String? statusLabel;

  const GlanceRing({
    required this.key,
    required this.label,
    this.value,
    this.target,
    this.unit,
    this.pct = 0,
    this.nudge,
    this.statusLabel,
  });

  factory GlanceRing.fromJson(Map<String, dynamic> json) => GlanceRing(
        key: (json['key'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        value: _toDouble(json['value']),
        target: _toDouble(json['target']),
        unit: json['unit'] as String?,
        pct: _toDouble(json['pct']) ?? 0,
        nudge: json['nudge'] as String?,
        statusLabel: json['statusLabel'] as String?,
      );
}

// ───────── /hydration ───────────────────────────────────────────────────

class HydrationData {
  final PeriodWindow window;
  final double? averageL;
  final int? averageMl;
  final double? targetL;
  final int? targetMl;
  final double pct;
  final String? nudge;
  final int? daysLogged;
  final HydrationPhaseTip? phaseTip;
  final HydrationMealsCard? mealsCard;

  const HydrationData({
    this.window = const PeriodWindow(),
    this.averageL,
    this.averageMl,
    this.targetL,
    this.targetMl,
    this.pct = 0,
    this.nudge,
    this.daysLogged,
    this.phaseTip,
    this.mealsCard,
  });

  factory HydrationData.empty() => const HydrationData();

  factory HydrationData.fromJson(Map<String, dynamic> json) => HydrationData(
        window: PeriodWindow.fromJson(json),
        averageL: _toDouble(json['averageL']),
        averageMl: _toInt(json['averageMl']),
        targetL: _toDouble(json['targetL']),
        targetMl: _toInt(json['targetMl']),
        pct: _toDouble(json['pct']) ?? 0,
        nudge: json['nudge'] as String?,
        daysLogged: _toInt(json['daysLogged']),
        phaseTip: _parseObject(json['phaseTip'], HydrationPhaseTip.fromJson),
        mealsCard: _parseObject(json['mealsCard'], HydrationMealsCard.fromJson),
      );
}

class HydrationPhaseTip {
  final String? phase;
  final String? tip;
  final String? macroEmphasis;
  const HydrationPhaseTip({this.phase, this.tip, this.macroEmphasis});
  factory HydrationPhaseTip.fromJson(Map<String, dynamic> json) =>
      HydrationPhaseTip(
        phase: json['phase'] as String?,
        tip: json['tip'] as String?,
        macroEmphasis: json['macroEmphasis'] as String?,
      );
}

class HydrationMealsCard {
  final String? copy;
  final bool enabled;
  const HydrationMealsCard({this.copy, this.enabled = false});
  factory HydrationMealsCard.fromJson(Map<String, dynamic> json) =>
      HydrationMealsCard(
        copy: json['copy'] as String?,
        enabled: (json['enabled'] as bool?) ?? false,
      );
}

// ───────── /symptoms ────────────────────────────────────────────────────

class SymptomsData {
  final PeriodWindow window;
  final List<SymptomRow> symptoms;
  final int? basedOnCheckIns;

  const SymptomsData({
    this.window = const PeriodWindow(),
    this.symptoms = const [],
    this.basedOnCheckIns,
  });

  factory SymptomsData.empty() => const SymptomsData();

  factory SymptomsData.fromJson(Map<String, dynamic> json) => SymptomsData(
        window: PeriodWindow.fromJson(json),
        symptoms: _parseList(json['symptoms'], SymptomRow.fromJson),
        basedOnCheckIns: _toInt(json['basedOnCheckIns']),
      );
}

class SymptomRow {
  final String key;
  final String label;
  final int? intensityPct;
  final int? deltaPct;
  final String? direction; // 'improvement' | 'regression' | 'unchanged' | null
  final bool notEnoughData;

  const SymptomRow({
    required this.key,
    required this.label,
    this.intensityPct,
    this.deltaPct,
    this.direction,
    this.notEnoughData = false,
  });

  factory SymptomRow.fromJson(Map<String, dynamic> json) => SymptomRow(
        key: (json['key'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        intensityPct: _toInt(json['intensityPct']),
        deltaPct: _toInt(json['deltaPct']),
        direction: json['direction'] as String?,
        notEnoughData: (json['notEnoughData'] as bool?) ?? false,
      );

  /// Convenience for the trend-bar widget. Maps backend semantics to a
  /// `bool?` for the green/red pill colour. null = neutral grey.
  bool? get isImprovement {
    if (direction == 'improvement') return true;
    if (direction == 'regression') return false;
    return null;
  }
}

// ───────── /insights/hub ────────────────────────────────────────────────

class InsightsHubData {
  final PeriodWindow window;
  final List<InsightItem> insights;
  final int? patternsFound;
  final bool isStatic;
  final String? honestyBanner;

  const InsightsHubData({
    this.window = const PeriodWindow(),
    this.insights = const [],
    this.patternsFound,
    this.isStatic = true,
    this.honestyBanner,
  });

  factory InsightsHubData.empty() => const InsightsHubData();

  factory InsightsHubData.fromJson(Map<String, dynamic> json) => InsightsHubData(
        window: PeriodWindow.fromJson(json),
        insights: _parseList(json['insights'], InsightItem.fromJson),
        patternsFound: _toInt(json['patternsFound']),
        isStatic: (json['isStatic'] as bool?) ?? true,
        honestyBanner: json['honestyBanner'] as String?,
      );
}

class InsightItem {
  final String? id;
  final String? headline;
  final String? subtitle;
  final String? body;
  final String? tone;
  final String? accentHex;
  final String? category;
  final bool isStatic;

  const InsightItem({
    this.id,
    this.headline,
    this.subtitle,
    this.body,
    this.tone,
    this.accentHex,
    this.category,
    this.isStatic = true,
  });

  factory InsightItem.fromJson(Map<String, dynamic> json) => InsightItem(
        id: json['id'] as String?,
        headline: json['headline'] as String?,
        subtitle: json['subtitle'] as String?,
        body: json['body'] as String?,
        tone: json['tone'] as String?,
        accentHex: json['accentHex'] as String?,
        category: json['category'] as String?,
        isStatic: (json['isStatic'] as bool?) ?? true,
      );
}

// ───────── parsing helpers ──────────────────────────────────────────────

T? _parseObject<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! Map) return null;
  try {
    return fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return null;
  }
}

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) {
      try {
        out.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed rows; never poison the whole list.
      }
    }
  }
  return out;
}

int? _toInt(dynamic x) {
  if (x == null) return null;
  if (x is int) return x;
  if (x is num) return x.toInt();
  if (x is String) return int.tryParse(x);
  return null;
}

double? _toDouble(dynamic x) {
  if (x == null) return null;
  if (x is num) return x.toDouble();
  if (x is String) return double.tryParse(x);
  return null;
}
