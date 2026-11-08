import 'package:flutter/material.dart';

import '../portal_session.dart';

/// One menu entry. [phase] = when its screen is built (see the plan).
class PortalMenuItem {
  final String key;
  final String label;
  final IconData icon;
  final int phase;
  final String? group;
  const PortalMenuItem(this.key, this.label, this.icon, this.phase, {this.group});
}

/// Every staff screen from the app, per role (Staff Portal plan).
List<PortalMenuItem> portalMenuFor(PortalRole role) {
  switch (role) {
    case PortalRole.admin:
      return const [
        PortalMenuItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined, 2, group: 'Insight'),
        PortalMenuItem('journey', 'User journey', Icons.route_outlined, 2, group: 'Insight'),
        PortalMenuItem('consult_day', 'Consultations by day', Icons.today_outlined, 2, group: 'Insight'),
        PortalMenuItem('escalations', 'Escalations', Icons.report_gmailerrorred_outlined, 2, group: 'Insight'),
        PortalMenuItem('trial_plans', 'Plans waiting / failed', Icons.hourglass_top_outlined, 2, group: 'Insight'),
        PortalMenuItem('pcos_users', 'PCOS assessment users', Icons.biotech_outlined, 2, group: 'Insight'),
        PortalMenuItem('weekly_reports', 'Weekly reports', Icons.straighten_outlined, 2, group: 'Insight'),
        PortalMenuItem('meal_tracker', 'Meal plan tracker', Icons.restaurant_menu_outlined, 2, group: 'Insight'),
        PortalMenuItem('slips', 'Slips to approve', Icons.receipt_long_outlined, 1, group: 'Money'),
        PortalMenuItem('payment_checks', 'Confirm payments', Icons.verified_outlined, 1, group: 'Money'),
        PortalMenuItem('payment_accounts', 'Payment accounts', Icons.account_balance_outlined, 1, group: 'Money'),
        PortalMenuItem('users', 'All users', Icons.people_outline, 1, group: 'Users'),
        PortalMenuItem('new_users', 'New users', Icons.person_add_alt_outlined, 1, group: 'Users'),
        PortalMenuItem('add_user', 'Add user', Icons.person_add_outlined, 1, group: 'Users'),
        PortalMenuItem('free_trial', 'Start free trial', Icons.card_giftcard_outlined, 1, group: 'Users'),
        PortalMenuItem('trial_days', 'Free trial length', Icons.hourglass_bottom_outlined, 1, group: 'Users'),
        PortalMenuItem('packages', 'Packages', Icons.inventory_2_outlined, 1, group: 'Plans'),
        PortalMenuItem('add_package', 'Add package', Icons.add_box_outlined, 1, group: 'Plans'),
        PortalMenuItem('durations', 'Time durations', Icons.timelapse_outlined, 1, group: 'Plans'),
        PortalMenuItem('countries', 'Countries', Icons.public_outlined, 1, group: 'Plans'),
        PortalMenuItem('posts', 'Posts check', Icons.forum_outlined, 2, group: 'Content'),
        PortalMenuItem('class_feedback', 'Class feedback', Icons.star_outline, 2, group: 'Content'),
        PortalMenuItem('consult_ratings', 'Consultation ratings', Icons.reviews_outlined, 2, group: 'Content'),
        PortalMenuItem('announcements', 'Announcements', Icons.campaign_outlined, 2, group: 'Content'),
        PortalMenuItem('testimonials', 'Testimonials', Icons.format_quote_outlined, 2, group: 'Content'),
        PortalMenuItem('team', 'Team members', Icons.badge_outlined, 2, group: 'Team'),
        PortalMenuItem('trainer_slots', 'Trainer slots', Icons.event_note_outlined, 2, group: 'Team'),
        PortalMenuItem('emergency_days', 'Emergency days', Icons.event_busy_outlined, 2, group: 'Team'),
        PortalMenuItem('zoom_room', 'Class Zoom room', Icons.videocam_outlined, 2, group: 'Team'),
        PortalMenuItem('app_version', 'App version', Icons.system_update_outlined, 2, group: 'Team'),
        PortalMenuItem('chat', 'Chat', Icons.chat_bubble_outline, 2, group: 'Talk'),
        PortalMenuItem('support_tickets', 'Support tickets', Icons.support_agent_outlined, 2, group: 'Talk'),
      ];
    case PortalRole.dietitian:
      return const [
        PortalMenuItem('d_home', 'Home', Icons.home_outlined, 3),
        PortalMenuItem('d_clients', 'Clients', Icons.people_outline, 3),
        PortalMenuItem('d_today', "Today's sessions", Icons.today_outlined, 3),
        PortalMenuItem('d_slots', 'Slots & availability', Icons.event_available_outlined, 3),
        PortalMenuItem('d_deliver', 'Plans to deliver', Icons.assignment_turned_in_outlined, 3),
        PortalMenuItem('d_drafts', 'Drafts', Icons.edit_note_outlined, 3),
        PortalMenuItem('d_generate', 'Generate AI plan', Icons.auto_awesome_outlined, 3),
        PortalMenuItem('d_flagged', 'Flagged Day 7 reviews', Icons.flag_outlined, 3),
        PortalMenuItem('d_ratings', 'My ratings', Icons.star_outline, 3),
        PortalMenuItem('d_alerts', 'Client alerts', Icons.notification_important_outlined, 3),
        PortalMenuItem('chat', 'Chat', Icons.chat_bubble_outline, 3),
        PortalMenuItem('community', 'Community', Icons.groups_outlined, 3),
        PortalMenuItem('profile', 'Profile', Icons.person_outline, 3),
      ];
    case PortalRole.trainer:
      return const [
        PortalMenuItem('t_home', 'My classes', Icons.fitness_center_outlined, 4),
        PortalMenuItem('t_ratings', 'Ratings & feedback', Icons.star_outline, 4),
        PortalMenuItem('chat', 'Chat', Icons.chat_bubble_outline, 4),
        PortalMenuItem('community', 'Community', Icons.groups_outlined, 4),
        PortalMenuItem('profile', 'Profile', Icons.person_outline, 4),
      ];
  }
}
