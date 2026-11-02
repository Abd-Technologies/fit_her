/// 2NH8 — period flow / spotting per day.
class PeriodFlowLog {
  final String id;
  final String date; // yyyy-MM-dd
  final String flow; // spotting|light|medium|heavy
  final bool clots;
  final int? pain; // 1–10
  final String? cyclePhase;
  final DateTime updatedAt;

  const PeriodFlowLog({
    required this.id,
    required this.date,
    required this.flow,
    this.clots = false,
    this.pain,
    this.cyclePhase,
    required this.updatedAt,
  });

  static const flowOptions = ['spotting', 'light', 'medium', 'heavy'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'flow': flow,
        'clots': clots,
        'pain': pain,
        'cyclePhase': cyclePhase,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PeriodFlowLog.fromJson(Map<String, dynamic> json) {
    return PeriodFlowLog(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      flow: json['flow']?.toString() ?? 'light',
      clots: json['clots'] == true,
      pain: json['pain'] as int?,
      cyclePhase: json['cyclePhase']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Grouped period record from consecutive bleeding days.
class PeriodRecord {
  final String startDate;
  final String endDate;
  final int lengthDays;
  final String heaviness; // light|medium|heavy
  final List<PeriodFlowLog> days;

  const PeriodRecord({
    required this.startDate,
    required this.endDate,
    required this.lengthDays,
    required this.heaviness,
    required this.days,
  });
}
