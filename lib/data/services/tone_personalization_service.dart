
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3NH4 — tone/style personalization (calm | high_energy). Variants only.
class TonePersonalizationService extends GetxService {
  static const _key = 'd23_tone_v1';

  final SharedPreferences prefs;

  TonePersonalizationService({required this.prefs});

  final RxString tone = 'calm'.obs;

  @override
  void onInit() {
    super.onInit();
    tone.value = prefs.getString(_key) ?? 'calm';
  }

  Future<void> setTone(String value) async {
    tone.value = value;
    await prefs.setString(_key, value);
  }

  String rewrite(String calmText, {String? highEnergy}) {
    if (tone.value == 'high_energy') {
      return highEnergy ?? '$calmText Let\'s go — you\'ve got this today.';
    }
    return calmText;
  }
}
