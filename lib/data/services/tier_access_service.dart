import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../values/constants.dart';
import '../controllers/auth_controller/auth_controller.dart';
import 'remote_config_service.dart';

enum AppTier { free, active, plus, unlimited }

/// X4 + D2/D3 — tier counters and checks (Free | Active | Plus | Unlimited).
class TierAccessService extends GetxService {
  static const _photoCountKey = 'd1_meal_photo_count_month';
  static const _photoMonthKey = 'd1_meal_photo_month';
  static const _upgradeShownKey = 'd1_upgrade_shown_session';
  static const _tierOverrideKey = 'd23_tier_override_v1';
  static const _nutritionistDayKey = 'd23_nutritionist_day';
  static const _nutritionistDayCountKey = 'd23_nutritionist_day_count';
  static const _nutritionistMonthKey = 'd23_nutritionist_month';
  static const _nutritionistMonthCountKey = 'd23_nutritionist_month_count';

  final SharedPreferences prefs;

  TierAccessService({required this.prefs});

  final RxInt photoUsedThisMonth = 0.obs;
  final RxBool upgradeShownThisSession = false.obs;
  final Rx<AppTier> tier = AppTier.free.obs;

  @override
  void onInit() {
    super.onInit();
    _ensureMonth();
    photoUsedThisMonth.value = prefs.getInt(_photoCountKey) ?? 0;
    refreshTier();
  }

  void refreshTier() {
    tier.value = resolveTier();
  }

  AppTier resolveTier() {
    final override = prefs.getString(_tierOverrideKey);
    if (override != null) {
      return _parseTier(override) ?? AppTier.free;
    }
    final planHint =
        (prefs.getString('d23_plan_title_hint') ?? '').toLowerCase();
    if (planHint.contains('unlimited')) return AppTier.unlimited;
    if (planHint.contains('plus')) return AppTier.plus;
    try {
      final auth = Get.find<AuthController>();
      if (auth.isPaid.value || auth.logInUser?.status == true) {
        // Paid without plus/unlimited → Active (live classes / recorded subset).
        return AppTier.active;
      }
    } catch (_) {
      if (prefs.getString(Constants.packageState) == 'true') {
        return AppTier.active;
      }
    }
    return AppTier.free;
  }

  /// QA / founder override (cleared on logout if desired).
  Future<void> setTierOverride(AppTier? value) async {
    if (value == null) {
      await prefs.remove(_tierOverrideKey);
    } else {
      await prefs.setString(_tierOverrideKey, value.name);
    }
    refreshTier();
  }

  Map<String, dynamic> get _ents {
    try {
      return Get.find<RemoteConfigService>().entitlementsFor(tier.value.name);
    } catch (_) {
      return const {};
    }
  }

  RemoteConfigService? get _remote {
    try {
      return Get.find<RemoteConfigService>();
    } catch (_) {
      return null;
    }
  }

  bool get isPlus =>
      tier.value == AppTier.plus || tier.value == AppTier.unlimited;

  bool get isUnlimited => tier.value == AppTier.unlimited;

  bool get isActiveOrAbove => tier.value != AppTier.free;

  bool get canAccessGuidedWorkouts =>
      _ents['guidedWorkouts'] == true || isPlus;

  bool get canAccessNutritionist =>
      _ents['nutritionist'] == true || isUnlimited;

  bool get canAccessReports => _ents['reports'] == true || isPlus;

  /// none | subset | full
  String get libraryAccess {
    final v = _ents['libraryAccess']?.toString();
    if (v != null && v.isNotEmpty) return v;
    if (isUnlimited) return 'full';
    if (isActiveOrAbove) return 'subset';
    return 'none';
  }

  bool canOpenLibraryClass(String classId) {
    final access = libraryAccess;
    if (access == 'full') return true;
    if (access == 'none') return false;
    final allowed = _remote?.libraryActiveClassIds ?? const <String>[];
    return allowed.contains(classId);
  }

  int get freePhotoCap => _remote?.mealPhotoCapFree ?? 30;

  bool get canLogMealPhoto {
    if (_ents['mealPhotoUnlimited'] == true || isPlus) return true;
    _ensureMonth();
    return photoUsedThisMonth.value < freePhotoCap;
  }

  int get photosRemaining {
    if (_ents['mealPhotoUnlimited'] == true || isPlus) return 9999;
    _ensureMonth();
    return (freePhotoCap - photoUsedThisMonth.value).clamp(0, freePhotoCap);
  }

  Future<void> recordMealPhoto() async {
    if (_ents['mealPhotoUnlimited'] == true || isPlus) return;
    _ensureMonth();
    final next = photoUsedThisMonth.value + 1;
    photoUsedThisMonth.value = next;
    await prefs.setInt(_photoCountKey, next);
  }

  bool get canSendNutritionistMessage {
    if (!canAccessNutritionist) return false;
    _ensureNutritionistWindows();
    final dayCap = _remote?.nutritionistDailyCap ?? 10;
    final monthCap = _remote?.nutritionistMonthlyCap ?? 100;
    final dayCount = prefs.getInt(_nutritionistDayCountKey) ?? 0;
    final monthCount = prefs.getInt(_nutritionistMonthCountKey) ?? 0;
    return dayCount < dayCap && monthCount < monthCap;
  }

  Future<void> recordNutritionistMessage() async {
    _ensureNutritionistWindows();
    final day = (prefs.getInt(_nutritionistDayCountKey) ?? 0) + 1;
    final month = (prefs.getInt(_nutritionistMonthCountKey) ?? 0) + 1;
    await prefs.setInt(_nutritionistDayCountKey, day);
    await prefs.setInt(_nutritionistMonthCountKey, month);
  }

  bool meetsGate(String gate) {
    switch (gate.toLowerCase()) {
      case 'free':
        return true;
      case 'active':
        return isActiveOrAbove;
      case 'plus':
        return isPlus;
      case 'unlimited':
        return isUnlimited;
      default:
        return isPlus;
    }
  }

  bool get canDownloadDoctorPdf =>
      meetsGate(_remote?.doctorPdfGate ?? 'plus');

  bool get canViewMonthlyReport =>
      meetsGate(_remote?.monthlyReportGate ?? 'plus');

  /// 1P9 — show upgrade at most once per session for a given reason.
  bool shouldShowUpgrade(String reason) {
    final key = '$_upgradeShownKey:$reason';
    if (prefs.getBool(key) == true) return false;
    prefs.setBool(key, true);
    upgradeShownThisSession.value = true;
    return true;
  }

  void clearSessionUpgradeFlags() {
    final keys = prefs.getKeys().where((k) => k.startsWith(_upgradeShownKey));
    for (final k in keys.toList()) {
      prefs.remove(k);
    }
    upgradeShownThisSession.value = false;
  }

  void _ensureMonth() {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month}';
    final stored = prefs.getString(_photoMonthKey);
    if (stored != stamp) {
      prefs.setString(_photoMonthKey, stamp);
      prefs.setInt(_photoCountKey, 0);
      photoUsedThisMonth.value = 0;
    }
  }

  void _ensureNutritionistWindows() {
    final now = DateTime.now();
    final dayStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthStamp = '${now.year}-${now.month}';
    if (prefs.getString(_nutritionistDayKey) != dayStamp) {
      prefs.setString(_nutritionistDayKey, dayStamp);
      prefs.setInt(_nutritionistDayCountKey, 0);
    }
    if (prefs.getString(_nutritionistMonthKey) != monthStamp) {
      prefs.setString(_nutritionistMonthKey, monthStamp);
      prefs.setInt(_nutritionistMonthCountKey, 0);
    }
  }

  static AppTier? _parseTier(String raw) {
    for (final t in AppTier.values) {
      if (t.name == raw) return t;
    }
    return null;
  }
}
