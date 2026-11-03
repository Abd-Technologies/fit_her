import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_zone_2/UI/chat/chat_home_screen.dart';
import 'package:fitness_zone_2/UI/chat/widgets/chat_room.dart';
import 'package:fitness_zone_2/UI/diet_screen/client_details_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/clients_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/drafts_dashboard_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/plans_to_deliver_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/flagged_reviews_screen.dart';
import 'package:fitness_zone_2/UI/admin_module/admin_v2/admin_escalations_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/slots_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/today_sessions_screen.dart';
import 'package:fitness_zone_2/UI/class_feedback/class_feedback_screens.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_contoller/diet_controller.dart';
import 'package:fitness_zone_2/data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fitness_zone_2/widgets/review_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../UI/dashboard_module/profile_screen/profile_screen_user.dart';
import '../values/my_colors.dart';
import '../values/my_imgs.dart';
import 'app_bar_widget.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/widgets/anim/live_dot.dart';

// ── Shared v2 design tokens ────────────────────────────────────────────
// Reused verbatim from flagged_reviews_screen.dart / client_consultation_
// screen.dart / the pre-existing "Drafts to Review" card below, so this
// home screen finally reads as part of the same app as the rest of the
// dietitian_v2 module instead of the old bright-green admin-panel look.
const Color _kBg = Color(0xFFE8F4E0); // cream page background
const Color _kInk = Color(0xFF163220); // headings
const Color _kInkSoft = Color(0xFF6F8B7A); // secondary text
const Color _kAccent = Color(0xFF6DC55A); // accent green
const Color _kAccentBg = Color(0xFFEAF7E4); // accent icon chip background
const Color _kBorder = Color(0xFFD8EDD4); // card border
const Color _kAlert = Color(0xFFE24B4A); // flagged/urgent accent

/// Dietitian-facing home. Redesigned to be warm and legible instead of
/// a bright-green admin panel: a cream background, soft cards, and a
/// "Flagged reviews" entry point (previously nowhere in the dietitian's
/// navigation at all — see lib/docs/diet_system_full_audit.md and the
/// Dietitian Command Center audit) sitting right next to Drafts to
/// Review, since both are things she can otherwise easily forget to
/// check.
class DietitianProfileScreen extends StatefulWidget {
  const DietitianProfileScreen({Key? key}) : super(key: key);

  @override
  State<DietitianProfileScreen> createState() =>
      _DietitianProfileScreenState();
}

class _DietitianProfileScreenState extends State<DietitianProfileScreen> {
  AuthController authController = Get.find();
  DietController dietController = Get.find();
  late final DietitianDashboardController _dashboardController =
      Get.find<DietitianDashboardController>();

  int? _flaggedCount;

  @override
  void initState() {
    super.initState();
    _loadFlaggedCount();
    // These two used to only load when she tapped into Requests/Clients
    // — meaning the home screen itself had no idea whether she had a
    // consultation today or a plan to deliver. Guarded so this doesn't
    // re-fetch if something else already populated them.
    // After the first frame: these flip observable state that Obx
    // widgets on this screen watch (doing it mid-build can crash).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!dietController.appointmentLoad.value) {
        dietController.getAppointmentsOfDiets();
      }
      if (!dietController.clientDataLoad.value) {
        dietController.clientsOfDietFunc();
      }
    });
  }

  Future<void> _loadFlaggedCount() async {
    // Best-effort — loadReviews already swallows its own errors and
    // returns an empty list, so there's nothing else to guard here.
    // Once the flagResolvedAt migration is live on the server, this
    // count naturally excludes reviews she's already dealt with.
    final reviews =
        await _dashboardController.loadReviews(flagged: true, limit: 100);
    if (!mounted) return;
    setState(() => _flaggedCount = reviews.length);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: HelpingWidgets().appBarWidget(
        null,
        text: 'My Dashboard',
        backGroundColor: _kBg,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          dietController.getAppointmentsOfDiets();
          dietController.clientsOfDietFunc();
          await _loadFlaggedCount();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Greeting ────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _kAccentBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco_outlined, color: _kAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting, ${authController.logInUser!.firstName}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Here's what needs you today",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _kInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Today — the three things she actually asked to see at
            // a glance: who she's meeting today, whose plan is owed,
            // and what's waiting in her messages. Everything below this
            // (quick actions, flagged/drafts cards, the full
            // appointments list) is still here for depth; this is the
            // "did I forget anything" snapshot.
            Obx(() {
              // Reading these two .obs flags (rather than just the plain
              // model fields below) is what makes this block rebuild once
              // the initState fetches above actually land — dietAppointmentsModel
              // and getDietClientsModel themselves are plain fields, not
              // observable, so without this the tiles would freeze at
              // "0" from the very first frame.
              // ignore: unused_local_variable
              final loadedGate = dietController.appointmentLoad.value &&
                  dietController.clientDataLoad.value;
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              // Rolling week: today + the next 6 days.
              final weekEnd = todayStart.add(const Duration(days: 7));
              final appts = dietController.dietAppointmentsModel?.appointments ?? [];
              final weekAppts = appts.where((a) {
                final d = a.date;
                return !d.isBefore(todayStart) &&
                    d.isBefore(weekEnd) &&
                    a.status != 'canceled' &&
                    a.status != 'canceledByUser';
              }).toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              final todayCount = weekAppts.where((a) =>
                  a.date.year == now.year &&
                  a.date.month == now.month &&
                  a.date.day == now.day).length;

              final clients = dietController.getDietClientsModel?.cliets ?? [];
              // planPipeline is computed separately from the status badge,
              // so a client owed a plan still counts here even if she also
              // has a follow-up today or a flagged review. Falls back to the
              // status badge for an older backend that doesn't send it.
              final hasPipeline = clients.any((c) => c.planPipeline != null);
              final plansDue = hasPipeline
                  ? clients.where((c) => c.planPipeline?.owed == true).toList()
                  : clients
                      .where((c) => c.status == 'PLAN_OVERDUE' || c.status == 'AWAITING_PLAN')
                      .toList();
              final overdueCount = hasPipeline
                  ? clients.where((c) => c.planPipeline?.overdue == true).length
                  : clients.where((c) => c.status == 'PLAN_OVERDUE').length;

              // "Next: Sara, Mon 6:00 PM" — her very next session this
              // week, plus how many of the week's are today.
              const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              String consultSubtitle;
              if (weekAppts.isEmpty) {
                consultSubtitle = 'Nothing booked this week';
              } else {
                final next = weekAppts.first;
                final isToday = next.date.year == now.year &&
                    next.date.month == now.month &&
                    next.date.day == now.day;
                final dayLabel = isToday ? 'Today' : wd[next.date.weekday - 1];
                consultSubtitle =
                    "Next: ${next.clientUser?.firstName ?? 'Client'}, $dayLabel ${next.slotDiet?.start ?? ''}"
                    "${todayCount > 0 ? ' · $todayCount today' : ''}";
              }
              final plansSubtitle = plansDue.isEmpty
                  ? 'Nothing owed right now'
                  : overdueCount > 0
                      ? '$overdueCount overdue'
                      : 'Due within 2 days';

              return IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.event_available_outlined,
                      accent: _kAccent,
                      accentBg: _kAccentBg,
                      count: '${weekAppts.length}',
                      label: 'Consultations this week',
                      subtitle: consultSubtitle,
                      onTap: () => Get.to(() => TodaySessionsScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.assignment_late_outlined,
                      accent: overdueCount > 0 ? _kAlert : const Color(0xFFC77B2B),
                      accentBg: overdueCount > 0
                          ? const Color(0xFFFBEAEA)
                          : const Color(0xFFFBEBD8),
                      count: '${plansDue.length}',
                      label: 'Plans to deliver',
                      subtitle: plansSubtitle,
                      onTap: () => Get.to(() => const PlansToDeliverScreen()),
                    ),
                  ),
                ],
                ),
              );
            }),
            // Nov 2026: her consultation ratings (anonymous).
            const DietitianRatingsTile(),
            const SizedBox(height: 10),
            const _RecentMessagesCard(),
            const SizedBox(height: 20),

            // ── Quick actions ───────────────────────────────────────
            Row(
              children: [
                // "Requests" removed: bookings confirm automatically now.
                // Alerts = missed sessions, plan delays, medical concerns
                // about HER clients (server scopes the list to her).
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.notification_important_outlined,
                    label: 'Alerts',
                    onTap: () => Get.to(() =>
                        const AdminEscalationsScreen(title: 'Client alerts')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.group_outlined,
                    label: 'Clients',
                    onTap: () {
                      dietController.clientsOfDietFunc();
                      Get.to(() => ClientsScreen());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.edit_calendar_outlined,
                    label: 'Slots',
                    onTap: () {
                      dietController.getDietTimes();
                      Get.to(() => SlotsScreen());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Flagged reviews — safety-critical, so it sits above
            // everything else. Badge shows the live count once known;
            // hidden entirely while nothing is flagged so the screen
            // doesn't nag her when there's genuinely nothing to do.
            _FeatureCard(
              icon: Icons.flag_outlined,
              iconColor: _kAlert,
              iconBg: const Color(0xFFFBEAEA),
              borderColor:
                  (_flaggedCount ?? 0) > 0 ? _kAlert : _kBorder,
              title: 'Flagged reviews',
              subtitle: (_flaggedCount == null)
                  ? 'Checking for check-ins that need attention…'
                  : (_flaggedCount == 0)
                      ? 'Nothing flagged right now'
                      : 'Client check-ins that tripped a safety threshold',
              badgeText:
                  (_flaggedCount != null && _flaggedCount! > 0)
                      ? '$_flaggedCount'
                      : null,
              badgeColor: _kAlert,
              onTap: () => Get.to(() => const FlaggedReviewsScreen()),
            ),
            const SizedBox(height: 10),

            // Phase E.2 — entry into the AI diet-plan workflow. Kept in
            // its original style; folded into the rest of this redesign
            // rather than replaced.
            _FeatureCard(
              icon: Icons.assignment_outlined,
              iconColor: _kAccent,
              iconBg: _kAccentBg,
              borderColor: _kBorder,
              title: 'Drafts to review',
              subtitle: 'AI-generated diet plans pending your review',
              onTap: () => Get.to(() => const DraftsDashboardScreen()),
            ),
            const SizedBox(height: 24),

            // ── Appointments ────────────────────────────────────────
            const Text(
              'Your appointments',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            Obx(() => dietController.appointmentLoad.value
                ? (dietController
                        .dietAppointmentsModel!.appointments.isEmpty
                    ? const _EmptyAppointments()
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          var appointMent = dietController
                              .dietAppointmentsModel!.appointments[index];

                          return AppointmentCard(
                              onTap: () {
                                if (appointMent.clientUser != null) {
                                  Get.to(() => ClientDetailsScreen(
                                      status: appointMent.status,
                                      clientUser: appointMent.clientUser!,
                                      slotDiet: appointMent.slotDiet,
                                      appointmentId: appointMent.id,
                                      appointmentDate: appointMent.date,
                                      planId: appointMent.planId));
                                }
                              },
                              name: [
                                appointMent.clientUser?.firstName ?? '',
                                appointMent.clientUser?.lastName ?? '',
                              ].where((s) => s.trim().isNotEmpty).join(' '),
                              status: appointMent.status,
                              kind: appointMent.kind,
                              date: appointMent.date,
                              timeRange: (appointMent.slotDiet?.start == null &&
                                      appointMent.slotDiet?.end == null)
                                  ? null
                                  : '${appointMent.slotDiet?.start ?? '?'} – ${appointMent.slotDiet?.end ?? '?'}',
                              message: appointMent.message);
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 10);
                        },
                        itemCount: dietController
                            .dietAppointmentsModel!.appointments.length))
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgress()),
                  ))
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData? icon;
  final String? svgIcon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    this.icon,
    this.svgIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: _kInk.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kAccentBg,
                shape: BoxShape.circle,
              ),
              child: svgIcon != null
                  ? SvgPicture.asset(svgIcon!,
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                          _kAccent, BlendMode.srcIn))
                  : Icon(icon, color: _kAccent, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: _kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String count;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.count,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: _kInk.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                Text(
                  count,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: _kInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: _kInkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent-conversations preview. Reuses the exact Firestore shape
/// ChatHomeScreen already reads (`users/{myId}/myusers`, ordered by
/// `time` desc, `newMessageArrived` as the unread signal) — no new
/// schema, just a smaller, home-screen-sized window onto it so
/// "what messages have I gotten" doesn't require leaving the home
/// screen to find out.
class _RecentMessagesCard extends StatelessWidget {
  const _RecentMessagesCard();

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final myId = authController.logInUser?.id.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: _kInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Get.to(() => ChatHomeScreen()),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _kAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (myId == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'Sign-in issue — can\'t load messages',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kInkSoft),
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(myId)
                  .collection('myusers')
                  .orderBy('time', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: SizedBox(
                      height: 24,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      'No messages yet',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kInkSoft),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? 'Client').toString();
                    final unread = data['newMessageArrived'] == true;
                    final otherId = (data['id'] ?? doc.id).toString();
                    final roomId =
                        (myId.hashCode + otherId.hashCode).toString();
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      leading: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: unread ? _kAlert : Colors.transparent,
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          color: _kInk,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF9AB09A), size: 18),
                      onTap: () => Get.to(() => ChatRoom(
                            chatRoomId: roomId,
                            userMap: data,
                          )),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color borderColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: _kInkSoft,
          ),
        ),
        trailing: badgeText != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9AB09A)),
                ],
              )
            : const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF9AB09A)),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, color: _kInkSoft, size: 28),
          SizedBox(height: 8),
          Text(
            'No appointments right now',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

// Was a bare ListTile with one mashed "date time – time" string and a
// status word in the same color it always got by coincidence (In
// Progress fell through getStatusColorAndIcon's switch to the pending/
// orange case, so a LIVE session read as "pending"). Rebuilt with the
// date and time as their own labeled row, the client's booking reason
// surfaced when she gave one, an Initial/Follow-up tag, and a status
// pill with its own correct color set (including a real LIVE state) —
// same visual language as TodaySessionsScreen's card so the two
// appointment surfaces read as one app.
class AppointmentCard extends StatelessWidget {
  final String name;
  final DateTime? date;
  final String? timeRange;
  final String? status;
  final String? kind;
  final String? message;
  final Function()? onTap;

  const AppointmentCard({
    required this.name,
    this.date,
    this.timeRange,
    this.onTap,
    this.status,
    this.kind,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is also reused by SlotsScreen as a plain "day name"
    // row with nothing but a name + onTap — status is the signal that
    // this call site is an actual appointment, so the kind subtitle and
    // status pill only render then, and that unrelated screen keeps
    // looking exactly as it did before this card got richer.
    final isAppointment = status != null;
    // Backend leaves `kind` null on legacy rows and treats null the
    // same as 'initial' everywhere it queries by kind — mirrored here.
    final isFollowUp = kind == 'followup';
    final trimmedMessage = message?.trim() ?? '';
    final hasMessage = trimmedMessage.isNotEmpty &&
        trimmedMessage.toUpperCase() != 'N/A';
    final hasDateTime = date != null ||
        (timeRange != null && timeRange!.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.trim().isEmpty ? 'Client' : name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: _kInk,
                        ),
                      ),
                      if (isAppointment) ...[
                        const SizedBox(height: 3),
                        Text(
                          isFollowUp
                              ? 'Follow-up consultation'
                              : 'Initial consultation',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _kInkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isAppointment) _StatusPill(status: status),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9AB09A)),
              ],
            ),
            if (hasDateTime) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (date != null) ...[
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: _kInkSoft),
                    const SizedBox(width: 5),
                    Text(
                      HelpingWidgets.formatDateWithMonthName(date!),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _kInk,
                      ),
                    ),
                  ],
                  if (timeRange != null && timeRange!.trim().isNotEmpty) ...[
                    SizedBox(width: date != null ? 12 : 0),
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: _kInkSoft),
                    const SizedBox(width: 5),
                    Text(
                      timeRange!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _kInk,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (hasMessage) ...[
              const SizedBox(height: 8),
              Text(
                '"$trimmedMessage"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: _kInkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small colored status pill. Rebuilt as its own thing rather than
/// reusing HelpingWidgets.getStatusColorAndIcon, which has no case for
/// "In Progress" and silently falls back to the pending/orange look —
/// exactly the state a dietitian most needs to see called out clearly.
class _StatusPill extends StatelessWidget {
  final String? status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status ?? '';
    final isLive = s == 'In Progress';
    final isConfirmed = s == 'confirmed';
    final isCompleted = s == 'completed';
    final isCanceled = s == 'canceled' || s == 'canceledByUser';

    final Color fg = isLive
        ? const Color(0xFF2F8A3A)
        : isConfirmed
            ? _kAccent
            : isCompleted
                ? _kInkSoft
                : isCanceled
                    ? _kAlert
                    : const Color(0xFFC08A25); // pending / anything else

    final String label = isLive
        ? 'LIVE'
        : s.isEmpty
            ? '—'
            : (s == 'canceledByUser' ? 'CANCELED' : s.toUpperCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Live session: small breathing dot (off with "reduce motion").
        if (isLive) ...[FhLiveDot(size: 5, color: fg), const SizedBox(width: 5)],
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.4,
          ),
        ),
      ]),
    );
  }
}
