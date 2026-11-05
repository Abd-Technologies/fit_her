import '../../../widgets/weekly_checkin/weekly_checkin_sheet.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../values/constants.dart';

import '../../../helper/app_update_checker.dart';
import '../../../helper/notification_services.dart';
import '../../free_trail/trial_summary_screen.dart';
import '../../../widgets/trial_moments/trial_moments.dart';
import '../../plans_module/all_plans.dart';
import '../../pre_consultation/pre_consultation_form_screen.dart';
import '../bottom_bar_screen/bottom_bar_screen.dart';
import '../../../screens/paid_home_screen_v2.dart';
import '../../diet_screen/today_sessions_screen.dart';
import '../../../data/controllers/diet_contoller/diet_controller.dart';

/// Notifications inbox (Oct 2026 redesign).
///
/// Grouped TODAY / EARLIER. Each card: category tile + CATEGORY · time,
/// bold title, body, an optional action link, red dot while unread.
/// Category, icon and action come from the push `type` the server saved
/// (UserNotification.type). Swipe left to remove.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

const _page = Color(0xFFEFF5EB);
const _ink = Color(0xFF1E2A1F);
const _soft = Color(0xFF6B7468);
const _line = Color(0xFFDDE8D6);
const _green = Color(0xFF3E8E4A);
const _dot = Color(0xFFE5484D);

class _Kind {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  const _Kind(this.label, this.icon, this.fg, this.bg);
}

const _class = _Kind('CLASS', Icons.self_improvement_rounded, Color(0xFF3E8E4A), Color(0xFFE6F3E0));
const _classAlert = _Kind('CLASS UPDATE', Icons.error_outline_rounded, Color(0xFFC77B1A), Color(0xFFFDF1E2));
const _plan = _Kind('YOUR PLAN', Icons.card_giftcard_rounded, Color(0xFFB4612A), Color(0xFFFCEEE6));
const _diet = _Kind('DIET', Icons.restaurant_menu_rounded, Color(0xFF3E8E4A), Color(0xFFE6F3E0));
const _consult = _Kind('CONSULTATION', Icons.video_call_outlined, Color(0xFF2E7D8C), Color(0xFFE3F2F4));
const _news = _Kind('NEW', Icons.auto_awesome_outlined, Color(0xFF3E8E4A), Color(0xFFE6F3E0));
const _support = _Kind('SUPPORT', Icons.support_agent_rounded, Color(0xFF7A5CC2), Color(0xFFF0ECFA));
const _app = _Kind('APP UPDATE', Icons.campaign_outlined, Color(0xFF3A6EA5), Color(0xFFE8F0F8));
const _general = _Kind('FIT HER', Icons.notifications_none_rounded, Color(0xFF3E8E4A), Color(0xFFE6F3E0));

class _NotificationScreenState extends State<NotificationScreen> {
  final AuthController authController = Get.find();

  @override
  void initState() {
    super.initState();
    // Loads the list first (unread dots show for this visit), then marks
    // everything read on the server.
    authController.fetchNotifications(markRead: true);
  }

  // ── Category / action from the push type ────────────────────────────
  _Kind _kindOf(NotificationMessage n) {
    final t = (n.type ?? '').trim();
    final title = n.title.toLowerCase();
    // Consultation pushes first: "Appointment Canceled" contains "cancel"
    // and used to show as a class alert with "See the schedule" (Oct 2026).
    if (t.startsWith('appointment') || t.startsWith('booking') || t.contains('consult') || t == 'clientWaiting' ||
        (t.isEmpty && title.contains('appointment'))) {
      return _consult;
    }
    if (t == 'trainerCancelled' || title.contains('class cancel')) return _classAlert;
    if (const {
      'classPrep', 'classStart', 'upcomingClass', 'classLinkAdded', 'trainerLinkAdded',
      'trialClassReminder', 'missedRecovery', 'trainerClassReminder',
    }.contains(t)) {
      return _class;
    }
    if (t == 'preConsultReminder') return _plan;
    if (t.startsWith('diet') || title.contains('diet')) return _diet;
    if (t.startsWith('appointment') || t.startsWith('booking') || t.contains('consult')) return _consult;
    if (const {
      'planActivated', 'paymentApproved', 'paymentRejected', 'planExpiring', 'planPaused',
      'planResumed', 'trialOfferReminder',
    }.contains(t) || t.startsWith('trial')) {
      return _plan;
    }
    if (t == 'appUpdate') return _app;
    if (t == 'support_reply') return _support;
    if (t == 'announcement') return _news;
    return _general;
  }

  /// Action link under the body, or null.
  (String, VoidCallback)? _actionOf(NotificationMessage n) {
    final t = (n.type ?? '').trim();
    final k = _kindOf(n);
    // The tab buttons point at the client's tabs (1 Workout, 2 Diet). Staff
    // accounts have other tabs, so no tab button for them (Oct 2026).
    final isClient = authController.loginAsA.value == Constants.user;
    // Nov 2026: the dietitian's consultation notifications open her sessions.
    if (!isClient && k == _consult && authController.loginAsA.value == Constants.dietitian) {
      return ('Open my sessions', () {
        if (Get.isRegistered<DietController>()) Get.find<DietController>().getAppointmentsOfDiets();
        Get.to(() => TodaySessionsScreen());
      });
    }
    if (!isClient && (k == _class || k == _classAlert || k == _diet)) return null;
    if (k == _class || k == _classAlert) {
      return ('See the schedule', () => Get.offAll(() => BottomBarScreen(index: 1)));
    }
    if (k == _diet) return ('Open my diet', () => Get.offAll(() => BottomBarScreen(index: 2)));
    // Consultations: her booked session card lives on the Diet tab (Oct 2026).
    if (k == _consult && isClient) {
      return ('See my consultation', () => Get.offAll(() => BottomBarScreen(index: 2)));
    }
    if (t == 'preConsultReminder') return ('Fill my form', () => PreConsultationFormScreen.openIfNeeded());
    if (t == 'weeklyCheckin') return ('Do my check-in', () => WeeklyCheckinSheet.open());
    if (t == 'lunaDaily') {
      return ('Log now', () {
        PaidHomeScreenV2.requestInsights();
        Get.offAll(() => BottomBarScreen(index: 0));
      });
    }
    // Trial moments (Day 3, your month, last day, ended): reopen the same
    // sheet the push opened (Nov 2026).
    if (t == 'trialMoment') {
      final kind = '${n.data?['kind'] ?? ''}';
      const labels = {
        'progress': 'See my progress',
        'month': 'See my month',
        'lastDay': 'See my offer',
        'ended': 'See my offer',
      };
      final label = labels[kind];
      if (label == null) return null;
      return (label, () => TrialMomentController.ensure().openFromPush(kind));
    }
    if (t == 'trialOfferReminder') return ('See my offer', () => Get.to(() => const TrialSummaryScreen()));
    if (t == 'trialPlanReady') return ('See my plan', () => Get.offAll(() => BottomBarScreen(index: 2)));
    if (t == 'trialLastDay') return ('See my days', () => Get.to(() => const TrialSummaryScreen()));
    if (t == 'planExpiring') return ('Renew now', () => Get.to(() => OurPlansScreen()));
    if (t == 'appUpdate') return ('Update now', () => AppUpdateChecker.check(fromPush: true));
    return null;
  }

  static DateTime? _when(NotificationMessage n) =>
      n.sentAt == null ? null : DateTime.tryParse(n.sentAt!)?.toLocal();

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24 && t.day == DateTime.now().day) return '${d.inHours}h ago';
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (t.isAfter(yesterday)) return 'Yesterday';
    if (d.inDays < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${m[t.month - 1]}';
  }

  static bool _isToday(DateTime? t) {
    if (t == null) return false;
    final n = DateTime.now();
    return t.year == n.year && t.month == n.month && t.day == n.day;
  }

  // ── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ValueListenableBuilder<List<dynamic>?>(
          valueListenable: authController.sharedPrefNotifier,
          builder: (context, value, _) {
            final list = (value ?? const []).whereType<NotificationMessage>().toList();
            final anyUnread = list.any((n) => n.readAt == null && n.serverId != null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(anyUnread),
                Expanded(child: list.isEmpty ? _empty() : _list(list)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(bool anyUnread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _line),
            ),
            child: const Icon(Icons.chevron_left_rounded, color: _ink, size: 24),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text('Notifications',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
        ),
        if (anyUnread)
          TextButton(
            onPressed: () async {
              await authController.markAllNotificationsRead();
              await authController.fetchNotifications();
            },
            child: const Text('Mark all read',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: _green)),
          ),
      ]),
    );
  }

  Widget _list(List<NotificationMessage> list) {
    final today = <int>[];
    final earlier = <int>[];
    for (var i = 0; i < list.length; i++) {
      (_isToday(_when(list[i])) ? today : earlier).add(i);
    }
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
          child: Text(t,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: _soft)),
        );
    return RefreshIndicator(
      color: _green,
      onRefresh: () => authController.fetchNotifications(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          if (today.isNotEmpty) ...[section('TODAY'), for (final i in today) _card(list, i)],
          if (earlier.isNotEmpty) ...[section('EARLIER'), for (final i in earlier) _card(list, i)],
        ],
      ),
    );
  }

  Widget _card(List<NotificationMessage> list, int index) {
    final n = list[index];
    final k = _kindOf(n);
    final action = _actionOf(n);
    final unread = n.readAt == null && n.serverId != null;
    final ago = _ago(_when(n));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('notif-${n.serverId ?? n.id ?? index}-$index'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => authController.removeItem(index, serverId: n.serverId),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(color: const Color(0xFFFCE3E3), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete_outline_rounded, color: _dot),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action?.$2,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: k.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(k.icon, color: k.fg, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: k.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, letterSpacing: .6, color: k.fg)),
                          if (ago.isNotEmpty)
                            TextSpan(text: '  ·  $ago', style: const TextStyle(color: _soft)),
                        ]),
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: _dot, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(n.title,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink, height: 1.3)),
                  if (n.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _soft, height: 1.45)),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    Text('${action.$1} ›',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: _green)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF8AD167), size: 40),
          ),
          const SizedBox(height: 18),
          const Text("You're all caught up",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text(
            'Class reminders, plan updates and news from Fit Her will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _soft, height: 1.5),
          ),
        ]),
      ),
    );
  }
}
