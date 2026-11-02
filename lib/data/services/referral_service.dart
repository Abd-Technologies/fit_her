
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../helper/analytics_helper.dart';
import '../analytics/analytics_events.dart';

/// 2P6 — referral invite code/link + pending reward.
class ReferralService extends GetxService {
  static const _key = 'd23_referral_v1';

  final SharedPreferences prefs;

  ReferralService({required this.prefs});

  final RxString code = ''.obs;
  final RxInt pendingRewards = 0.obs;
  final RxInt friendsJoined = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        code.value = m['code']?.toString() ?? '';
        pendingRewards.value = (m['pending'] as num?)?.toInt() ?? 0;
        friendsJoined.value = (m['joined'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    if (code.value.isEmpty) {
      code.value = 'FH${const Uuid().v4().substring(0, 6).toUpperCase()}';
      _persist();
    }
  }

  String get inviteLink => 'https://fither.app/invite/${code.value}';

  Future<void> _persist() async {
    await prefs.setString(
      _key,
      jsonEncode({
        'code': code.value,
        'pending': pendingRewards.value,
        'joined': friendsJoined.value,
      }),
    );
  }

  Future<void> markShared() async {
    await AnalyticsHelper.track(AnalyticsEvents.referralShared);
  }

  /// Local stub when a friend supposedly joins.
  Future<void> simulateFriendJoined() async {
    friendsJoined.value++;
    pendingRewards.value++;
    await _persist();
  }
}
