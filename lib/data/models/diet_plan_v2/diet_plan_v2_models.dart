// Models for the Phase C/D structured-diet-plan API.
//
// Naming: `*V2` suffix to avoid colliding with the legacy `Plan`/
// `DurationPlan`/`UserPlan` models in lib/data/models/get_user_plan/
// (those drive the price card / paywall flow). These V2 models drive
// the AI-generated diet plan flow specifically.
//
// Wire shape — backend response envelope (always):
//   { "status": "1", "message": "...", "data": { dietPlan: {...} | plans: [...] | meal+day } }
// Repos extract `data` and pass the inner payload to *.fromJson here.

/// Status lifecycle: draft → active → completed | cancelled.
enum DietPlanStatusV2 { draft, active, completed, cancelled }

DietPlanStatusV2 dietPlanStatusFromString(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'active':
      return DietPlanStatusV2.active;
    case 'completed':
      return DietPlanStatusV2.completed;
    case 'cancelled':
      return DietPlanStatusV2.cancelled;
    case 'draft':
    default:
      return DietPlanStatusV2.draft;
  }
}

String dietPlanStatusToString(DietPlanStatusV2 s) {
  switch (s) {
    case DietPlanStatusV2.draft:
      return 'draft';
    case DietPlanStatusV2.active:
      return 'active';
    case DietPlanStatusV2.completed:
      return 'completed';
    case DietPlanStatusV2.cancelled:
      return 'cancelled';
  }
}

/// Backend ENUM (services/ai/constants/mealTemplates.js VALID_MEAL_TYPES).
enum MealTypeV2 {
  breakfast,
  midMorning,
  lunch,
  afternoonSnack,
  eveningSnack,
  dinner,
}

extension MealTypeV2X on MealTypeV2 {
  /// Snake_case wire format used by the backend ENUM.
  String get wire {
    switch (this) {
      case MealTypeV2.breakfast:
        return 'breakfast';
      case MealTypeV2.midMorning:
        return 'mid_morning';
      case MealTypeV2.lunch:
        return 'lunch';
      case MealTypeV2.afternoonSnack:
        return 'afternoon_snack';
      case MealTypeV2.eveningSnack:
        return 'evening_snack';
      case MealTypeV2.dinner:
        return 'dinner';
    }
  }

  /// Human label for UI rendering. Internal-only — translation happens
  /// in the screen layer if/when we localise.
  String get label {
    switch (this) {
      case MealTypeV2.breakfast:
        return 'Breakfast';
      case MealTypeV2.midMorning:
        return 'Mid-morning';
      case MealTypeV2.lunch:
        return 'Lunch';
      case MealTypeV2.afternoonSnack:
        return 'Afternoon snack';
      case MealTypeV2.eveningSnack:
        return 'Evening snack';
      case MealTypeV2.dinner:
        return 'Dinner';
    }
  }
}

/// Tolerant parse from the snake_case wire format. Falls back to
/// `breakfast` on null / unknown so a backend addition can't crash the
/// client — the validator and the prompt are the source of truth for
/// "which types are legal for this user", not the model.
MealTypeV2 mealTypeFromString(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'breakfast':
      return MealTypeV2.breakfast;
    case 'mid_morning':
      return MealTypeV2.midMorning;
    case 'lunch':
      return MealTypeV2.lunch;
    case 'afternoon_snack':
      return MealTypeV2.afternoonSnack;
    case 'evening_snack':
      return MealTypeV2.eveningSnack;
    case 'dinner':
      return MealTypeV2.dinner;
    default:
      return MealTypeV2.breakfast;
  }
}

/// One meal inside a [DietPlanDayV2]. `time` is a wall-clock string
/// "HH:MM" — DO NOT parse to DateTime (timezone-naive by design;
/// backend stores it as STRING per CLAUDE.md timezone rules).
class DietPlanMealV2 {
  final int? id;
  final int? dietPlanDayId;
  final MealTypeV2 mealType;
  final String time;
  final String foodName;
  final int calories;
  final String? notes;

  const DietPlanMealV2({
    this.id,
    this.dietPlanDayId,
    required this.mealType,
    required this.time,
    required this.foodName,
    required this.calories,
    this.notes,
  });

  factory DietPlanMealV2.fromJson(Map<String, dynamic> json) {
    return DietPlanMealV2(
      id: _toInt(json['id']),
      dietPlanDayId: _toInt(json['dietPlanDayId']),
      mealType: mealTypeFromString(json['mealType']?.toString()),
      time: (json['time'] ?? '').toString(),
      foodName: (json['foodName'] ?? '').toString(),
      calories: _toInt(json['calories']) ?? 0,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (dietPlanDayId != null) 'dietPlanDayId': dietPlanDayId,
        'mealType': mealType.wire,
        'time': time,
        'foodName': foodName,
        'calories': calories,
        if (notes != null) 'notes': notes,
      };

  /// Immutable update — returns a copy with the given fields replaced.
  /// `notes` uses an explicit "did caller pass it?" flag so a caller can
  /// clear the field by passing `clearNotes: true` (passing `null` is
  /// ambiguous between "leave alone" and "set to null").
  DietPlanMealV2 copyWith({
    int? id,
    int? dietPlanDayId,
    MealTypeV2? mealType,
    String? time,
    String? foodName,
    int? calories,
    String? notes,
    bool clearNotes = false,
  }) {
    return DietPlanMealV2(
      id: id ?? this.id,
      dietPlanDayId: dietPlanDayId ?? this.dietPlanDayId,
      mealType: mealType ?? this.mealType,
      time: time ?? this.time,
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// One day inside a [DietPlanV2]. `dayNumber` is 1-based.
class DietPlanDayV2 {
  final int? id;
  final int? dietPlanId;
  final int dayNumber;
  final int totalCalories;
  final List<DietPlanMealV2> meals;

  const DietPlanDayV2({
    this.id,
    this.dietPlanId,
    required this.dayNumber,
    required this.totalCalories,
    required this.meals,
  });

  factory DietPlanDayV2.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['DietPlanMeals'] ?? json['meals'] ?? const [];
    final meals = rawMeals is List
        ? rawMeals
            .whereType<Map>()
            .map((m) => DietPlanMealV2.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <DietPlanMealV2>[];
    return DietPlanDayV2(
      id: _toInt(json['id']),
      dietPlanId: _toInt(json['dietPlanId']),
      dayNumber: _toInt(json['dayNumber']) ?? 0,
      totalCalories: _toInt(json['totalCalories']) ?? 0,
      meals: meals,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (dietPlanId != null) 'dietPlanId': dietPlanId,
        'dayNumber': dayNumber,
        'totalCalories': totalCalories,
        'meals': meals.map((m) => m.toJson()).toList(),
      };

  DietPlanDayV2 copyWith({
    int? id,
    int? dietPlanId,
    int? dayNumber,
    int? totalCalories,
    List<DietPlanMealV2>? meals,
  }) {
    return DietPlanDayV2(
      id: id ?? this.id,
      dietPlanId: dietPlanId ?? this.dietPlanId,
      dayNumber: dayNumber ?? this.dayNumber,
      totalCalories: totalCalories ?? this.totalCalories,
      meals: meals ?? this.meals,
    );
  }
}

/// Header for one structured diet plan. Sequelize emits child arrays as
/// `DietPlanDays` (capitalised, model-name pluralised); we accept the
/// lowercase `days` alias too in case the backend ever flips it.
///
/// `userFirstName` / `userLastName` / `userProfileImage` come from the
/// dietitian-side `listDraftsForDietitian` join (Phase D) — backend
/// emits the nested user under the Sequelize alias `User`. The user-
/// side `getMyActivePlan` endpoint doesn't include the join, so these
/// stay null for that response shape.
class DietPlanV2 {
  final int id;
  final int? userId;
  final int? userPlanId;
  final int? dietitianId;
  final int? aiGenerationLogId;
  final int planDays;
  final int mealsPerDay;
  final DietPlanStatusV2 status;
  final String? summary;
  /// Nov 2026: the dietitian's note to her, shown at the top of her plan.
  final String? clientNote;
  final DateTime? activatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final List<DietPlanDayV2> days;
  final String? userFirstName;
  final String? userLastName;
  final String? userProfileImage;

  const DietPlanV2({
    required this.id,
    this.userId,
    this.userPlanId,
    this.dietitianId,
    this.aiGenerationLogId,
    required this.planDays,
    required this.mealsPerDay,
    required this.status,
    this.summary,
    this.clientNote,
    this.activatedAt,
    this.completedAt,
    this.cancelledAt,
    this.createdAt,
    this.days = const [],
    this.userFirstName,
    this.userLastName,
    this.userProfileImage,
  });

  /// Convenience for screens — empty string if neither name is set.
  String get userDisplayName {
    final first = (userFirstName ?? '').trim();
    final last = (userLastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return '';
    return [first, last].where((s) => s.isNotEmpty).join(' ');
  }

  factory DietPlanV2.fromJson(Map<String, dynamic> json) {
    final rawDays = json['DietPlanDays'] ?? json['days'] ?? const [];
    final days = rawDays is List
        ? rawDays
            .whereType<Map>()
            .map((d) => DietPlanDayV2.fromJson(Map<String, dynamic>.from(d)))
            .toList()
        : <DietPlanDayV2>[];

    // Sequelize emits the nested user under its model name `User`
    // (capitalised). Accept lowercase `user` for forward-compat. The
    // backend User model column is `image` (NOT `profileImage`); accept
    // both keys so a future rename can't crash the client.
    final rawUser = json['User'] ?? json['user'];
    String? firstName;
    String? lastName;
    String? profileImage;
    if (rawUser is Map) {
      firstName = rawUser['firstName']?.toString();
      lastName = rawUser['lastName']?.toString();
      profileImage =
          (rawUser['profileImage'] ?? rawUser['image'])?.toString();
    }

    return DietPlanV2(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['userId']),
      userPlanId: _toInt(json['userPlanId']),
      dietitianId: _toInt(json['dietitianId']),
      aiGenerationLogId: _toInt(json['aiGenerationLogId']),
      planDays: _toInt(json['planDays']) ?? 0,
      mealsPerDay: _toInt(json['mealsPerDay']) ?? 0,
      status: dietPlanStatusFromString(json['status']?.toString()),
      summary: json['summary']?.toString(),
      clientNote: (json['clientNote']?.toString().trim().isNotEmpty ?? false) ? json['clientNote'].toString().trim() : null,
      activatedAt: _toDate(json['activatedAt']),
      completedAt: _toDate(json['completedAt']),
      cancelledAt: _toDate(json['cancelledAt']),
      createdAt: _toDate(json['createdAt']),
      days: days,
      userFirstName: firstName,
      userLastName: lastName,
      userProfileImage: profileImage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (userId != null) 'userId': userId,
        if (userPlanId != null) 'userPlanId': userPlanId,
        if (dietitianId != null) 'dietitianId': dietitianId,
        if (aiGenerationLogId != null) 'aiGenerationLogId': aiGenerationLogId,
        'planDays': planDays,
        'mealsPerDay': mealsPerDay,
        'status': dietPlanStatusToString(status),
        if (summary != null) 'summary': summary,
        if (activatedAt != null) 'activatedAt': activatedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
      };

  /// Immutable update. Used by the controller to splice in a freshly-
  /// edited day (with new totalCalories) without touching the rest of
  /// the plan tree.
  DietPlanV2 copyWith({
    int? id,
    int? userId,
    int? userPlanId,
    int? dietitianId,
    int? aiGenerationLogId,
    int? planDays,
    int? mealsPerDay,
    DietPlanStatusV2? status,
    String? summary,
    String? clientNote,
    DateTime? activatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    List<DietPlanDayV2>? days,
    String? userFirstName,
    String? userLastName,
    String? userProfileImage,
  }) {
    return DietPlanV2(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userPlanId: userPlanId ?? this.userPlanId,
      dietitianId: dietitianId ?? this.dietitianId,
      aiGenerationLogId: aiGenerationLogId ?? this.aiGenerationLogId,
      planDays: planDays ?? this.planDays,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      clientNote: clientNote ?? this.clientNote,
      activatedAt: activatedAt ?? this.activatedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      days: days ?? this.days,
      userFirstName: userFirstName ?? this.userFirstName,
      userLastName: userLastName ?? this.userLastName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
    );
  }
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
