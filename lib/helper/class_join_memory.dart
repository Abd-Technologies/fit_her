import 'package:get/get.dart';

import '../data/controllers/auth_controller/auth_controller.dart';

/// Remembers on this phone that she joined a class today, so the button
/// says "Rejoin" straight away when she comes back (the server also sends
/// `joinedToday` on the next home refresh — this just covers the gap).
class ClassJoinMemory {
  ClassJoinMemory._();

  static String _key(Object slotId) {
    final d = DateTime.now();
    return 'class_joined_${slotId}_${d.year}-${d.month}-${d.day}';
  }

  static void markJoined(Object? slotId) {
    if (slotId == null || '$slotId'.isEmpty) return;
    try {
      Get.find<AuthController>().sharedPreferences.setBool(_key(slotId), true);
    } catch (_) {}
  }

  static bool joinedToday(Object? slotId) {
    if (slotId == null) return false;
    try {
      return Get.find<AuthController>().sharedPreferences.getBool(_key(slotId)) ?? false;
    } catch (_) {
      return false;
    }
  }
}
