import 'dart:convert';

/// Mirrors the backend PreConsultationProfile model. One profile per user;
/// persists across plan renewals. The dietitian-only `dietitianComments`
/// field is intentionally omitted here — it's stripped from the user-side
/// payload by the backend controller (see preConsultationController.toWire).
class PreConsultationProfile {
  final int? id;
  final int? userId;

  // Required fields (locked Decision 7).
  final String? goals;
  final String? allergies;
  final String? pregnancyMenstrualStatus;
  final List<dynamic>? dietaryPreferences;
  final String? medicalConditions;

  // Optional fields.
  final String? familyHistory;
  final Map<String, dynamic>? lifestyle;
  final String? fastingHabits;
  final String? surgeries;
  final String? currentMedications;

  // Workout-only / combined plan extension (Decision 10).
  final Map<String, dynamic>? workoutSection;

  // Form auto-save state (Decision 5).
  final Map<String, dynamic>? stepsCompleted;
  final bool isComplete;

  final DateTime? lastUserUpdate;
  final DateTime? lastDietitianEdit;

  /// 3 to 6. Drives the meal template the AI plan uses.
  final int? mealsPerDay;

  /// Where the answers came from: 'trial' (filled during the free trial,
  /// a paying client must confirm them once), 'user_confirmed',
  /// 'dietitian', or null for the normal paid flow.
  final String? intakeSource;

  bool get isFromTrial => (intakeSource ?? '').startsWith('trial');

  const PreConsultationProfile({
    this.id,
    this.userId,
    this.goals,
    this.allergies,
    this.pregnancyMenstrualStatus,
    this.dietaryPreferences,
    this.medicalConditions,
    this.familyHistory,
    this.lifestyle,
    this.fastingHabits,
    this.surgeries,
    this.currentMedications,
    this.workoutSection,
    this.stepsCompleted,
    this.isComplete = false,
    this.lastUserUpdate,
    this.lastDietitianEdit,
    this.mealsPerDay,
    this.intakeSource,
  });

  factory PreConsultationProfile.fromJson(Map<String, dynamic> json) {
    return PreConsultationProfile(
      id: json['id'] is int ? json['id'] as int : null,
      userId: json['userId'] is int ? json['userId'] as int : null,
      goals: json['goals'] as String?,
      allergies: json['allergies'] as String?,
      pregnancyMenstrualStatus: json['pregnancyMenstrualStatus'] as String?,
      dietaryPreferences: _asList(json['dietaryPreferences']),
      medicalConditions: json['medicalConditions'] as String?,
      familyHistory: json['familyHistory'] as String?,
      lifestyle: _asMap(json['lifestyle']),
      fastingHabits: json['fastingHabits'] as String?,
      surgeries: json['surgeries'] as String?,
      currentMedications: json['currentMedications'] as String?,
      workoutSection: _asMap(json['workoutSection']),
      stepsCompleted: _asMap(json['stepsCompleted']),
      isComplete: json['isComplete'] == true || json['isComplete'] == 1,
      lastUserUpdate: _asDate(json['lastUserUpdate']),
      lastDietitianEdit: _asDate(json['lastDietitianEdit']),
      mealsPerDay: json['mealsPerDay'] is int
          ? json['mealsPerDay'] as int
          : int.tryParse('${json['mealsPerDay'] ?? ''}'),
      intakeSource: json['intakeSource'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (goals != null) 'goals': goals,
        if (allergies != null) 'allergies': allergies,
        if (pregnancyMenstrualStatus != null)
          'pregnancyMenstrualStatus': pregnancyMenstrualStatus,
        if (dietaryPreferences != null) 'dietaryPreferences': dietaryPreferences,
        if (medicalConditions != null) 'medicalConditions': medicalConditions,
        if (familyHistory != null) 'familyHistory': familyHistory,
        if (lifestyle != null) 'lifestyle': lifestyle,
        if (fastingHabits != null) 'fastingHabits': fastingHabits,
        if (surgeries != null) 'surgeries': surgeries,
        if (currentMedications != null) 'currentMedications': currentMedications,
        if (workoutSection != null) 'workoutSection': workoutSection,
      };
}

// JSON columns can arrive as real JSON OR as a JSON-encoded string
// (MariaDB). Accept both, and never throw — a hard cast here used to
// crash parsing and leave the dietitian's form screen stuck loading.
Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final v = jsonDecode(raw);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
  }
  return null;
}

List<dynamic>? _asList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final v = jsonDecode(raw);
      if (v is List) return v;
    } catch (_) {}
  }
  return null;
}

DateTime? _asDate(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
