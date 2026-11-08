import 'package:flutter/material.dart';

import '../portal_theme.dart';
import '../pages/money/payment_accounts_page.dart';
import '../pages/money/payment_checks_page.dart';
import '../pages/money/slips_page.dart';
import '../pages/plans/countries_page.dart';
import '../pages/plans/durations_page.dart';
import '../pages/plans/trial_days_page.dart';
import '../pages/plans/packages_page.dart';
import '../pages/insight/dashboard_page.dart';
import '../pages/insight/consult_day_page.dart';
import '../pages/insight/escalations_page.dart';
import '../pages/insight/journey_page.dart';
import '../pages/insight/trial_plans_page.dart';
import '../pages/talk/support_tickets_page.dart';
import '../pages/insight/pcos_users_page.dart';
import '../pages/insight/weekly_reports_page.dart';
import '../pages/insight/meal_tracker_page.dart';
import '../pages/content/posts_review_page.dart';
import '../pages/content/class_feedback_page.dart';
import '../pages/content/consult_ratings_page.dart';
import '../pages/dietitian/ratings_page.dart';
import '../pages/content/announcements_page.dart';
import '../pages/content/testimonials_page.dart';
import '../pages/team/team_page.dart';
import '../pages/team/trainer_slots_page.dart';
import '../pages/team/zoom_room_page.dart';
import '../pages/team/emergency_days_page.dart';
import '../pages/team/app_version_page.dart';
import '../pages/talk/chat_page.dart';
import '../pages/dietitian/home_page.dart';
import '../pages/dietitian/today_page.dart';
import '../pages/dietitian/slots_page.dart';
import '../pages/dietitian/clients_page.dart';
import '../pages/dietitian/client_detail.dart';
import '../pages/dietitian/flagged_page.dart';
import '../pages/dietitian/deliver_page.dart';
import '../pages/dietitian/drafts_page.dart';
import '../pages/dietitian/generate_page.dart';
import '../pages/trainer/trainer_classes_page.dart';
import '../pages/trainer/trainer_ratings_page.dart';
import '../pages/shared/staff_profile_page.dart';
import '../pages/shared/community_page.dart';
import 'portal_menu.dart';

/// Screen for each menu key. Screens not built yet show their phase.
/// (Each phase adds its screens here.)
Widget portalPageFor(PortalMenuItem item) {
  switch (item.key) {
    case 'slips':
      return const SlipsPage();
    case 'payment_checks':
      return const PaymentChecksPage();
    case 'payment_accounts':
      return const PaymentAccountsPage();
    case 'packages':
      return const PackagesPage();
    case 'add_package':
      return const AddPackagePage();
    case 'durations':
      return const DurationsPage();
    case 'trial_days':
      return const TrialDaysPage();
    case 'countries':
      return const CountriesPage();
    case 'dashboard':
      return const DashboardPage();
    case 'journey':
      return const JourneyPage();
    case 'consult_day':
      return const ConsultDayPage();
    case 'escalations':
      return const EscalationsPage();
    case 'trial_plans':
      return const TrialPlansPage();
    case 'support_tickets':
      return const SupportTicketsPage();
    case 'pcos_users':
      return const PcosUsersPage();
    case 'weekly_reports':
      return const WeeklyReportsPage();
    case 'meal_tracker':
      return const MealTrackerPage();
    case 'posts':
      return const PostsReviewPage();
    case 'class_feedback':
      return const ClassFeedbackPage();
    case 'consult_ratings':
      return const ConsultRatingsPage();
    case 'd_ratings':
      return const DietitianRatingsPage();
    case 'announcements':
      return const AnnouncementsPage();
    case 'testimonials':
      return const TestimonialsPage();
    case 'team':
      return const TeamPage();
    case 'trainer_slots':
      return const TrainerSlotsPage();
    case 'emergency_days':
      return const EmergencyDaysPage();
    case 'zoom_room':
      return const ZoomRoomPage();
    case 'app_version':
      return const AppVersionPage();
    case 'chat':
      return const ChatPage();
    case 'd_home':
      return const DietitianHomePage();
    case 'd_clients':
      return const ClientsPage();
    case 'd_today':
      return const TodaySessionsPage();
    case 'd_slots':
      return const DietitianSlotsPage();
    case 'd_deliver':
      return const DietDeliverPage();
    case 'd_drafts':
      return const DietDraftsPage();
    case 'd_generate':
      {
        // "Generate plan" from a client's panel: preselect her.
        final picked = dietitianSelectedClient.value;
        if (picked != null) {
          generateForClient.value = picked;
          dietitianSelectedClient.value = null;
        }
        return const DietGeneratePage();
      }
    case 'd_flagged':
      return const FlaggedPage();
    case 'd_alerts':
      return const EscalationsPage(
          title: 'Client alerts',
          sub: 'Missed sessions, plan delays and medical worries about your clients. Sort it out, then resolve it.');
    case 't_home':
      return const TrainerClassesPage();
    case 't_ratings':
      return const TrainerRatingsPage();
    case 'profile':
      return const StaffProfilePage();
    case 'community':
      return const CommunityPage();
    default:
      return _ComingSoon(item: item);
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.item});
  final PortalMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: PT.card(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14)),
            child: Icon(item.icon, color: PT.green, size: 26),
          ),
          const SizedBox(height: 14),
          Text(item.label, style: PT.t(18, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('This screen comes in Phase ${item.phase}. Until then, use the Fit Her mobile app.',
              textAlign: TextAlign.center, style: PT.t(13, c: PT.sage, h: 1.45)),
        ]),
      ),
    );
  }
}
