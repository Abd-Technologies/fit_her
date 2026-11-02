
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3P2 — language preference scaffold (en | ur | ur_Latn).
class LocalePrefService extends GetxService {
  static const _key = 'd23_locale_v1';

  final SharedPreferences prefs;

  LocalePrefService({required this.prefs});

  final RxString localeCode = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    localeCode.value = prefs.getString(_key) ?? 'en';
  }

  Future<void> setLocale(String code) async {
    localeCode.value = code;
    await prefs.setString(_key, code);
  }

  String t(String en, {String? ur, String? romanUr}) {
    switch (localeCode.value) {
      case 'ur':
        return ur ?? en;
      case 'ur_Latn':
        return romanUr ?? en;
      default:
        return en;
    }
  }
}
