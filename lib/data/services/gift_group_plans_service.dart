
import 'package:get/get.dart';

/// 3P4 / 3P5 — gift subscription + group plans stubs.
class GiftGroupPlansService extends GetxService {
  final RxList<Map<String, String>> giftOrders = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> groupPlans = <Map<String, String>>[
    {'id': 'corp_1', 'name': 'Workplace wellness (stub)', 'seats': '50'},
    {'id': 'uni_1', 'name': 'University cohort (stub)', 'seats': '200'},
  ].obs;

  Future<void> giftPlan({
    required String recipientPhone,
    required String plan,
  }) async {
    giftOrders.add({
      'recipient': recipientPhone,
      'plan': plan,
      'status': 'pending_payment_stub',
      'at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> joinGroupStub(String groupId) async {
    return 'joined_pending:$groupId';
  }
}
