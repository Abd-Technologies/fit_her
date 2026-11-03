// One weigh-in / measurement entry from the weekly check-in (Oct 2026).
// Pure Dart (no Flutter): used by the progress PDF builder too.
// Source: GET /users/weekly-checkin/history (helper/weeklyCheckin.js).
class MeasurementEntry {
  const MeasurementEntry({
    this.date,
    this.weightKg,
    this.waistCm,
    this.hipsCm,
    this.chestCm,
    this.armsCm,
    this.thighsCm,
    this.weekRating,
  });

  final DateTime? date;
  final double? weightKg;
  final double? waistCm;
  final double? hipsCm;
  final double? chestCm;
  final double? armsCm;
  final double? thighsCm;

  /// "How was your week?": 1 Hard, 2 Okay, 3 Good, 4 Great.
  final int? weekRating;

  static double? _d(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  factory MeasurementEntry.fromJson(Map<String, dynamic> j) => MeasurementEntry(
        date: DateTime.tryParse('${j['date'] ?? j['weekDate'] ?? ''}'),
        weightKg: _d(j['weightKg']),
        waistCm: _d(j['waistCm']),
        hipsCm: _d(j['hipsCm']),
        chestCm: _d(j['chestCm']),
        armsCm: _d(j['armsCm']),
        thighsCm: _d(j['thighsCm']),
        weekRating: (j['weekRating'] as num?)?.toInt(),
      );

  /// Measurement value by key: waistCm, hipsCm, chestCm, armsCm, thighsCm.
  double? cm(String key) {
    switch (key) {
      case 'waistCm':
        return waistCm;
      case 'hipsCm':
        return hipsCm;
      case 'chestCm':
        return chestCm;
      case 'armsCm':
        return armsCm;
      case 'thighsCm':
        return thighsCm;
    }
    return null;
  }
}
