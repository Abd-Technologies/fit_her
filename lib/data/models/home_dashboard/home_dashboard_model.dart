import '../consultation/pending_popup.dart';

/// Model for GET /users/home/dashboard (PaidHomeScreenV2 data layer).
/// Every nested subobject is independently nullable because the backend
/// degrades per-subobject on failure (Promise.allSettled-style tolerance)
/// and because Phase A intentionally leaves some subobjects always-null
/// (nutrition, unreadNotifications).
class HomeDashboardModel {
  final UserInfo? user;
  final CycleInfo? cycle;
  final GoalInfo? goal;
  final LiveClass? live;
  final List<ComingUpClass> comingUp;
  final Insight? insight;
  final TodayCheckin? todayCheckin;
  final Hydration? hydration;
  final SleepInfo? sleep;
  final StatsInfo? stats;
  final CycleCard? cycleCard;
  final NutritionInfo? nutrition;
  final SocialInfo? social;
  final int? unreadNotifications;
  // Consultation flow — server-computed list of popups the client should
  // surface. Sorted by priority server-side; client shows the first one
  // and re-fetches after dismiss/complete (Phase 2D orchestrator).
  final List<PendingPopup> pendingPopups;

  const HomeDashboardModel({
    this.user,
    this.cycle,
    this.goal,
    this.live,
    this.comingUp = const [],
    this.insight,
    this.todayCheckin,
    this.hydration,
    this.sleep,
    this.stats,
    this.cycleCard,
    this.nutrition,
    this.social,
    this.unreadNotifications,
    this.pendingPopups = const [],
  });

  /// Safe initial state before first fetch. All nested refs null, comingUp [].
  factory HomeDashboardModel.empty() => const HomeDashboardModel();

  /// Expects the `data` block of the response envelope, not the envelope
  /// itself. Repo extracts `body['data']` and passes it here.
  factory HomeDashboardModel.fromJson(Map<String, dynamic> json) {
    return HomeDashboardModel(
      user: _parseObject(json['user'], UserInfo.fromJson),
      cycle: _parseObject(json['cycle'], CycleInfo.fromJson),
      goal: _parseObject(json['goal'], GoalInfo.fromJson),
      live: _parseObject(json['live'], LiveClass.fromJson),
      comingUp: _parseList(json['comingUp'], ComingUpClass.fromJson),
      insight: _parseObject(json['insight'], Insight.fromJson),
      todayCheckin:
          _parseObject(json['todayCheckin'], TodayCheckin.fromJson),
      hydration: _parseObject(json['hydration'], Hydration.fromJson),
      sleep: _parseObject(json['sleep'], SleepInfo.fromJson),
      stats: _parseObject(json['stats'], StatsInfo.fromJson),
      cycleCard: _parseObject(json['cycleCard'], CycleCard.fromJson),
      nutrition: _parseObject(json['nutrition'], NutritionInfo.fromJson),
      social: _parseObject(json['social'], SocialInfo.fromJson),
      unreadNotifications: _toInt(json['unreadNotifications']),
      pendingPopups: _parseList(json['pendingPopups'], PendingPopup.fromJson),
    );
  }
}

// ─────────── nested classes ─────────────────────────────────────────────

class UserInfo {
  final String? firstName;
  final String? initial;
  // Signup goal category (Lose weight / Build strength & tone / etc.),
  // set by GoalScreen and re-settable from the PaidHero "Set goal →"
  // chip. Null means the user never picked one. Distinct from
  // GoalInfo.deltaKg below — that's numeric weight-tracking progress,
  // not this category.
  final String? mainGoal;

  const UserInfo({this.firstName, this.initial, this.mainGoal});

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        firstName: json['firstName'] as String?,
        initial: json['initial'] as String?,
        mainGoal: json['mainGoal'] as String?,
      );
}

class CycleInfo {
  final bool? dataProvided;
  final int? cycleDay;
  final String? phase;
  final String? phaseLabel;
  final int? periodInDays;
  final int? averageCycleLength;
  /// Real cycles the hormonal engine has learned from (Oct 2026).
  final int cyclesLearned;

  const CycleInfo({
    this.dataProvided,
    this.cycleDay,
    this.phase,
    this.phaseLabel,
    this.periodInDays,
    this.averageCycleLength,
    this.cyclesLearned = 0,
  });

  factory CycleInfo.fromJson(Map<String, dynamic> json) => CycleInfo(
        dataProvided: json['dataProvided'] as bool?,
        cycleDay: _toInt(json['cycleDay']),
        phase: json['phase'] as String?,
        phaseLabel: json['phaseLabel'] as String?,
        periodInDays: _toInt(json['periodInDays']),
        averageCycleLength: _toInt(json['averageCycleLength']),
        cyclesLearned: _toInt(json['cyclesLearned']) ?? 0,
      );
}

class GoalInfo {
  final double? targetWeightKg;
  // 'lose' | 'gain' | null. Only meaningful when the signup mainGoal
  // (UserInfo.mainGoal) doesn't already say which way weight should
  // move — 'Lose weight' implies this on its own. See
  // save_target_weight's backend doc comment for the full contract.
  final String? weightGoalDirection;
  final double? currentWeightKg;
  final double? startingWeightKg;
  final double? deltaKg;
  final double? lostKg;
  final int? streakDays;
  final int? daysSinceLastWeighIn;
  final bool? isWeighInDue;

  const GoalInfo({
    this.targetWeightKg,
    this.weightGoalDirection,
    this.currentWeightKg,
    this.startingWeightKg,
    this.deltaKg,
    this.lostKg,
    this.streakDays,
    this.daysSinceLastWeighIn,
    this.isWeighInDue,
  });

  factory GoalInfo.fromJson(Map<String, dynamic> json) => GoalInfo(
        targetWeightKg: _toDouble(json['targetWeightKg']),
        weightGoalDirection: json['weightGoalDirection'] as String?,
        currentWeightKg: _toDouble(json['currentWeightKg']),
        startingWeightKg: _toDouble(json['startingWeightKg']),
        deltaKg: _toDouble(json['deltaKg']),
        lostKg: _toDouble(json['lostKg']),
        streakDays: _toInt(json['streakDays']),
        daysSinceLastWeighIn: _toInt(json['daysSinceLastWeighIn']),
        isWeighInDue: json['isWeighInDue'] as bool?,
      );
}

class LiveClass {
  final int? slotId;
  final String? classType;
  /// Alias used by analytics / presence logging.
  String? get type => classType;
  final String? trainerName;
  final int? durationMinutes;
  final int? caloriesEstimate;
  /// Class intensity set by the trainer/admin (Slot.level), e.g. "Medium".
  final String? level;
  final int? participantCount;
  final int? elapsedMinutes;
  final String? startedAtUtc;
  final String? status;
  final String? trainerLink;
  // Pass-through wall-clock strings (e.g. "12:00 PM"). Identical to what
  // workout_plan_details surfaces. UI displays these directly — no parsing.
  final String? start;
  final String? end;
  /// App-side only: 0 = today, 1 = tomorrow (set when a Coming Up class
  /// is shown in the big card as "Up next").
  final int dayOffset;
  /// Server: she already joined this class today → button says "Rejoin".
  final bool joinedToday;

  const LiveClass({
    this.slotId,
    this.classType,
    this.trainerName,
    this.durationMinutes,
    this.caloriesEstimate,
    this.level,
    this.participantCount,
    this.elapsedMinutes,
    this.startedAtUtc,
    this.status,
    this.trainerLink,
    this.start,
    this.end,
    this.dayOffset = 0,
    this.joinedToday = false,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) => LiveClass(
        slotId: _toInt(json['slotId']),
        classType: json['classType'] as String?,
        trainerName: json['trainerName'] as String?,
        durationMinutes: _toInt(json['durationMinutes']),
        caloriesEstimate: _toInt(json['caloriesEstimate']),
        level: json['level']?.toString(),
        participantCount: _toInt(json['participantCount']),
        elapsedMinutes: _toInt(json['elapsedMinutes']),
        startedAtUtc: json['startedAtUtc'] as String?,
        status: json['status'] as String?,
        trainerLink: json['trainerLink'] as String?,
        start: json['start'] as String?,
        end: json['end'] as String?,
        joinedToday: json['joinedToday'] == true,
      );
}

class ComingUpClass {
  final int? id;
  final String? classType;
  final String? weekday;
  final String? startTimeUtc;
  final int? durationMinutes;
  final int? dayOffset;
  // Pass-through wall-clock strings (e.g. "12:00 PM"). Identical to what
  // workout_plan_details surfaces. UI displays these directly — no parsing.
  final String? start;
  final String? end;
  final String? trainerName;
  // Added so the home screen can run the same resolveSlotUIState() the
  // Workout Schedule screen uses (see lib/utils/slot_ui_state.dart) --
  // without these two, comingUp entries can't tell "starting soon" from
  // "trainer already went live" from a plain future class.
  final String? status;
  final String? trainerLink;
  final String? level;

  const ComingUpClass({
    this.id,
    this.classType,
    this.weekday,
    this.startTimeUtc,
    this.durationMinutes,
    this.dayOffset,
    this.start,
    this.end,
    this.trainerName,
    this.status,
    this.trainerLink,
    this.level,
  });

  factory ComingUpClass.fromJson(Map<String, dynamic> json) => ComingUpClass(
        id: _toInt(json['id']),
        classType: json['classType'] as String?,
        weekday: json['weekday'] as String?,
        startTimeUtc: json['startTimeUtc'] as String?,
        durationMinutes: _toInt(json['durationMinutes']),
        dayOffset: _toInt(json['dayOffset']),
        start: json['start'] as String?,
        end: json['end'] as String?,
        trainerName: json['trainerName'] as String?,
        status: json['status'] as String?,
        trainerLink: json['trainerLink'] as String?,
        level: json['level']?.toString(),
      );
}

class Insight {
  final String? source;
  final String? text;
  final String? accentHex;

  const Insight({this.source, this.text, this.accentHex});

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        source: json['source'] as String?,
        text: json['text'] as String?,
        accentHex: json['accentHex'] as String?,
      );
}

class TodayCheckin {
  final String? date;
  final int? moodLevel;
  final double? sleepHours;
  // Phase A always returns an empty array. Kept as dynamic list so future
  // symptom-schema work doesn't require a model migration here.
  final List<dynamic> symptoms;

  const TodayCheckin({
    this.date,
    this.moodLevel,
    this.sleepHours,
    this.symptoms = const [],
  });

  factory TodayCheckin.fromJson(Map<String, dynamic> json) => TodayCheckin(
        date: json['date'] as String?,
        moodLevel: _toInt(json['moodLevel']),
        sleepHours: _toDouble(json['sleepHours']),
        symptoms: (json['symptoms'] as List?) ?? const [],
      );
}

class Hydration {
  final String? date;
  final int? consumedMl;
  final int? targetMl;
  final int? remainingMl;

  const Hydration({
    this.date,
    this.consumedMl,
    this.targetMl,
    this.remainingMl,
  });

  factory Hydration.fromJson(Map<String, dynamic> json) => Hydration(
        date: json['date'] as String?,
        consumedMl: _toInt(json['consumedMl']),
        targetMl: _toInt(json['targetMl']),
        remainingMl: _toInt(json['remainingMl']),
      );
}

class SleepInfo {
  final double? hoursToday;
  final int? targetHours;
  final double? weekDeltaHours;

  const SleepInfo({this.hoursToday, this.targetHours, this.weekDeltaHours});

  factory SleepInfo.fromJson(Map<String, dynamic> json) => SleepInfo(
        hoursToday: _toDouble(json['hoursToday']),
        targetHours: _toInt(json['targetHours']),
        weekDeltaHours: _toDouble(json['weekDeltaHours']),
      );
}

class StatsInfo {
  final int? workoutsThisWeek;
  final double? weightDeltaKgThisWeek;
  final int? caloriesRemaining;
  final int? dailyKcalBudget;

  const StatsInfo({
    this.workoutsThisWeek,
    this.weightDeltaKgThisWeek,
    this.caloriesRemaining,
    this.dailyKcalBudget,
  });

  factory StatsInfo.fromJson(Map<String, dynamic> json) => StatsInfo(
        workoutsThisWeek: _toInt(json['workoutsThisWeek']),
        weightDeltaKgThisWeek: _toDouble(json['weightDeltaKgThisWeek']),
        caloriesRemaining: _toInt(json['caloriesRemaining']),
        dailyKcalBudget: _toInt(json['dailyKcalBudget']),
      );
}

class CycleCard {
  final int? cycleDay;
  final String? phase;
  final int? periodInDays;

  const CycleCard({this.cycleDay, this.phase, this.periodInDays});

  factory CycleCard.fromJson(Map<String, dynamic> json) => CycleCard(
        cycleDay: _toInt(json['cycleDay']),
        phase: json['phase'] as String?,
        periodInDays: _toInt(json['periodInDays']),
      );
}

class NutritionInfo {
  final int? compliancePct;
  final String? nextMealLabel;

  const NutritionInfo({this.compliancePct, this.nextMealLabel});

  factory NutritionInfo.fromJson(Map<String, dynamic> json) => NutritionInfo(
        compliancePct: _toInt(json['compliancePct']),
        nextMealLabel: json['nextMealLabel'] as String?,
      );
}

class SocialInfo {
  final int? womenJoinedToday;

  const SocialInfo({this.womenJoinedToday});

  factory SocialInfo.fromJson(Map<String, dynamic> json) => SocialInfo(
        womenJoinedToday: _toInt(json['womenJoinedToday']),
      );
}

// ─────────── parsing helpers ───────────────────────────────────────────

T? _parseObject<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! Map) return null;
  try {
    return fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return null;
  }
}

List<T> _parseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) {
      try {
        out.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed item; don't fail the whole list.
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
