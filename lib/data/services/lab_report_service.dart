
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabValue {
  final String marker;
  final double value;
  final String unit;
  final DateTime at;

  LabValue({
    required this.marker,
    required this.value,
    required this.unit,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'marker': marker,
        'value': value,
        'unit': unit,
        'at': at.toIso8601String(),
      };

  factory LabValue.fromJson(Map<String, dynamic> json) => LabValue(
        marker: json['marker']?.toString() ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit']?.toString() ?? '',
        at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// 3NH7 — lab report upload parse stub for fixed markers.
class LabReportService extends GetxService {
  static const _key = 'd23_lab_values_v1';
  static const markers = ['TSH', 'Vitamin D', 'Iron', 'Ferritin', 'HbA1c', 'Fasting glucose'];

  final SharedPreferences prefs;

  LabReportService({required this.prefs});

  final RxList<LabValue> values = <LabValue>[].obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        values.assignAll(
          (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => LabValue.fromJson(Map<String, dynamic>.from(e))),
        );
      } catch (_) {}
    }
  }

  Future<void> addSampleParse({
    required String marker,
    required double value,
    required String unit,
  }) async {
    values.add(LabValue(
      marker: marker,
      value: value,
      unit: unit,
      at: DateTime.now(),
    ));
    await prefs.setString(
      _key,
      jsonEncode(values.map((e) => e.toJson()).toList()),
    );
  }

  String explanation(LabValue v) {
    return 'pending_doctor_review: ${v.marker} reading ${v.value} ${v.unit}. '
        'Shown against a general reference only — not a diagnosis.';
  }

  List<LabValue> trendFor(String marker) =>
      values.where((v) => v.marker == marker).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
}
