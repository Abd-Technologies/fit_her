
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2P7 — community streak visibility (demo count until API).
class CommunityStreakService extends GetxService {
  final SharedPreferences prefs;

  CommunityStreakService({required this.prefs});

  final RxInt membersLoggedToday = 128.obs;
  final RxInt membersTrainedToday = 86.obs;

  void refreshDemo() {
    // Stable-ish demo numbers from day-of-year.
    final day = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    membersLoggedToday.value = 100 + (day % 40);
    membersTrainedToday.value = 70 + (day % 30);
  }
}
