import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/v2/v2_buttons.dart';
import 'package:intl/intl.dart';

import '../../data/controllers/diet_contoller/diet_controller.dart';
import '../../data/models/diet_appointments.dart' as diet_models;
import '../../widgets/circular_progress.dart';
import '../../widgets/toasts.dart';
import 'client_details_screen.dart';
import 'dietitian_v2/client_consultation_screen.dart';
import 'dietitian_v2/plans_to_deliver_screen.dart';
import 'emergency_day_sheet.dart';

/// The native equivalent of the "Start a session" card in the standalone
/// dietitian-link-tool.html web page — reachable now by tapping the
/// "Consultations today" tile on the dashboard, instead of needing a
/// separate browser tool. Lists every upcoming, still-relevant booking
/// (not only today's — a session can be started whenever it makes
/// sense, not just on its exact calendar day) and lets her flip a
/// confirmed one to "In Progress" so the client's Join Meeting button
/// turns green, without leaving the app.
class TodaySessionsScreen extends StatelessWidget {
  TodaySessionsScreen({super.key});
  final DietController dietController = Get.find();

  List<diet_models.Appointment> _upcomingAppointments() {
    final appts = dietController.dietAppointmentsModel?.appointments ?? [];
    final filtered = appts
        .where((a) =>
            a.status != 'canceled' &&
            a.status != 'canceledByUser' &&
            a.status != 'completed')
        .toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(
        () {
          Get.back();
        },
        text: "Your Consultations",
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              "Start any confirmed session whenever it's time — the client's "
              "Join Meeting button turns green as soon as you do.",
              style: textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: Colors.black.withOpacity(0.4)),
            ),
            const SizedBox(height: 10),
            // Oct 2026: cancel all of today's / tomorrow's sessions at once.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => EmergencyDaySheet.show(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC24A4A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFFFDECEC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.emergency_outlined, size: 18),
                label: const Text('Emergency: cancel my day',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                if (!dietController.appointmentLoad.value) {
                  return CircularProgress();
                }
                final error = dietController.appointmentError.value;
                if (error != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 36, color: Color(0xFF7A8C78)),
                        const SizedBox(height: 10),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium!.copyWith(
                              color: const Color(0xFF1A3A22)),
                        ),
                        const SizedBox(height: 14),
                        V2PrimaryButton(
                          label: 'Try again',
                          fullWidth: false,
                          onPressed: dietController.getAppointmentsOfDiets,
                        ),
                      ],
                    ),
                  );
                }
                final upcomingAppts = _upcomingAppointments();
                // Nov 2026: finished calls of the last 2 days.
                final finished = dietController.recentFinished;
                final toConfirm = finished.where(_needsJoinAnswer).toList();
                if (upcomingAppts.isEmpty && finished.isEmpty) {
                  return Center(
                    child: Text(
                      "No upcoming consultations yet.",
                      style: textTheme.bodyMedium!.copyWith(
                          color: Colors.black.withOpacity(0.4)),
                    ),
                  );
                }
                // Grouped by day: the date is shown ONCE as a section
                // header ("Today · Sat, Oct 3"), and each card under it
                // only shows its time — repeating the date on every
                // card read as confusing.
                final children = <Widget>[];
                for (final a in toConfirm) {
                  children.add(Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JoinAnswerCard(appointment: a),
                  ));
                }
                if (upcomingAppts.isEmpty) {
                  children.add(Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text("No upcoming consultations.",
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium!.copyWith(color: Colors.black.withOpacity(0.4))),
                  ));
                }
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                DateTime? currentDay;
                for (final appt in upcomingAppts) {
                  final d = DateTime(
                      appt.date.year, appt.date.month, appt.date.day);
                  if (currentDay == null || d != currentDay) {
                    currentDay = d;
                    final diff = d.difference(today).inDays;
                    final pretty = DateFormat('EEE, MMM d').format(d);
                    final label = diff == 0
                        ? 'Today · $pretty'
                        : diff == 1
                            ? 'Tomorrow · $pretty'
                            : pretty;
                    final count = upcomingAppts
                        .where((a) =>
                            a.date.year == d.year &&
                            a.date.month == d.month &&
                            a.date.day == d.day)
                        .length;
                    children.add(_DayHeader(
                      label: label,
                      count: count,
                      isToday: diff == 0,
                      first: children.isEmpty,
                    ));
                  }
                  children.add(Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionRow(appointment: appt),
                  ));
                }
                if (finished.isNotEmpty) {
                  children.add(_DayHeader(
                    label: 'Finished · last 2 days',
                    count: finished.length,
                    isToday: false,
                    first: children.isEmpty,
                  ));
                  for (final a in finished) {
                    children.add(Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FinishedRow(appointment: a),
                    ));
                  }
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: children,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final diet_models.Appointment appointment;
  const _SessionRow({required this.appointment});

  // App's V2 palette.
  static const Color _ink = Color(0xFF1A3A22);
  static const Color _muted = Color(0xFF7A8C78);
  static const Color _accent = Color(0xFF6DC55A);
  static const Color _accentBg = Color(0xFFEAF7E4);
  static const Color _border = Color(0xFFD8EDD4);
  static const Color _danger = Color(0xFFE07B7B);
  static const Color _amber = Color(0xFF8A5A06);

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  /// Which consultation this is for her — from the server's count of her
  /// earlier completed consultations; falls back to `kind` on an older
  /// backend.
  int? get _number {
    final n = appointment.consultNumber;
    if (n != null && n > 0) return n;
    return appointment.kind == 'followup' ? null : 1;
  }

  @override
  Widget build(BuildContext context) {
    final DietController dietController = Get.find();
    final first = appointment.clientUser?.firstName.trim() ?? '';
    final last = appointment.clientUser?.lastName.trim() ?? '';
    final fullName = '$first $last'.trim();
    final clientName = fullName.isEmpty ? 'Client' : fullName;
    final initials = [first, last]
        .where((p) => p.isNotEmpty)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    final timeRange = appointment.slotDiet == null
        ? ''
        : "${appointment.slotDiet!.start ?? '?'} – ${appointment.slotDiet!.end ?? '?'}";
    final now = DateTime.now();
    final apptDate = appointment.date;
    final isToday = apptDate.year == now.year &&
        apptDate.month == now.month &&
        apptDate.day == now.day;
    final dateLabel =
        isToday ? 'Today' : DateFormat('EEE, MMM d').format(apptDate);
    final status = appointment.status;
    final isConfirmed = status == 'confirmed';
    final isLive = status == 'In Progress';
    // Start only opens 10 minutes before the session (server enforces
    // the same rule), so the client's button never turns green early.
    // appointment.date is only the session DAY; the start time is the
    // slot's start ("04:00 PM").
    DateTime sessionStartAt = appointment.date.toLocal();
    try {
      final startStr = appointment.slotDiet?.start?.toString().trim();
      if (startStr != null && startStr.isNotEmpty) {
        // Day is stored as UTC midnight: read the calendar day in UTC.
        final d = appointment.date.toUtc();
        final t = DateFormat('h:mm a').parse(startStr);
        sessionStartAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      }
    } catch (_) {}
    final startOpensAt =
        sessionStartAt.subtract(const Duration(minutes: 10));
    final tooEarlyToStart = DateTime.now().isBefore(startOpensAt);
    // ...and closes when the slot ends (server enforces this too).
    DateTime? sessionEndsAt;
    try {
      final endStr = appointment.slotDiet?.end?.toString().trim();
      if (endStr != null && endStr.isNotEmpty) {
        final local = appointment.date.toUtc(); // calendar day (UTC midnight)
        final t = DateFormat('h:mm a').parse(endStr);
        sessionEndsAt =
            DateTime(local.year, local.month, local.day, t.hour, t.minute);
      }
    } catch (_) {
      sessionEndsAt = null;
    }
    final tooLateToStart =
        sessionEndsAt != null && DateTime.now().isAfter(sessionEndsAt);
    void onStart() {
      if (sessionEndsAt != null && DateTime.now().isAfter(sessionEndsAt)) {
        CustomToast.failToast(
            msg: "This session's time has passed, so it can't be started. "
                "If the client didn't join, use the ⋯ menu.");
        return;
      }
      if (DateTime.now().isBefore(startOpensAt)) {
        CustomToast.failToast(
            msg: 'You can start this session from '
                '${DateFormat('h:mm a').format(startOpensAt)} '
                '(10 minutes before).');
        return;
      }
      dietController.startAppointmentSession(appointment.id);
    }
    final note = appointment.message.trim();
    final hasNote = note.isNotEmpty && note != 'N/A';
    final n = _number;
    final consultLabel = n == null
        ? 'Follow-up consultation'
        : n == 1
            ? '1st consultation · New client'
            : '${_ordinal(n)} consultation · Follow-up';

    // Her client profile — the same screen the dietitian opens from the
    // home appointments list (details, Generate Plan, plan history).
    // Falls back to the health-form screen if the booking came back
    // without client details.
    void openProfile() {
      final cu = appointment.clientUser;
      if (cu != null) {
        Get.to(() => ClientDetailsScreen(
              clientUser: cu,
              slotDiet: appointment.slotDiet,
              appointmentId: appointment.id,
              status: appointment.status,
              appointmentDate: appointment.date,
              planId: appointment.planId,
            ));
      } else {
        Get.to(() => ClientConsultationScreen(
              userId: appointment.userId,
              clientName: clientName,
            ));
      }
    }

    // Her pre-consultation health form (editable during the call — it
    // feeds the AI plan), Day-7 reviews, progress and private notes.
    void openForm() => Get.to(() => ClientConsultationScreen(
          userId: appointment.userId,
          clientName: clientName,
        ));
    void openCall() =>
        dietController.openMeetLink(appointment.resolvedMeetLink);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Who + when + which consultation (tap → her profile) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: openProfile,
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: initials.isEmpty
                      ? const Icon(Icons.person_rounded, color: _ink, size: 22)
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeRange.isEmpty ? dateLabel : timeRange,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: n == 1
                              ? _accent.withOpacity(0.16)
                              : const Color(0xFFEDEFF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          consultLabel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: n == 1
                                ? const Color(0xFF2F7A22)
                                : const Color(0xFF4A5578),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: status),
                  if (isConfirmed || isLive)
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) {
                        if (v == 'completed') {
                          _markCompleted(dietController, appointment);
                        } else if (v == 'noshow') {
                          _confirmClientNoShow(context, dietController, appointment);
                        } else if (v == 'form') {
                          openForm();
                        }
                      },
                      itemBuilder: (_) => [
                        if (isConfirmed)
                          const PopupMenuItem(
                            value: 'completed',
                            child: _MenuRow(
                                icon: Icons.done_all_rounded,
                                label: 'Mark completed',
                                color: _ink),
                          ),
                        const PopupMenuItem(
                          value: 'noshow',
                          child: _MenuRow(
                              icon: Icons.person_off_outlined,
                              label: "Client didn't join",
                              color: _amber),
                        ),
                        const PopupMenuItem(
                          value: 'form',
                          child: _MenuRow(
                              icon: Icons.assignment_outlined,
                              label: 'Health form',
                              color: _ink),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),

          // ── What she wrote when booking ──
          if (hasNote) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"$note"',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Nov 2026: is the client there? (from her Join tap in the app)
          if (_liveLine(appointment) != null) ...[
            const SizedBox(height: 10),
            _infoBox(_liveLine(appointment)!,
                warm: isConfirmed && appointment.clientJoinTapAt != null),
          ],

          const SizedBox(height: 12),

          // ── Main action ──
          if (isConfirmed)
            // One tap: marks the session live (client's Join button turns
            // green + she gets a push) AND opens the Meet call.
            _PrimaryAction(
              icon: tooLateToStart
                  ? Icons.history_rounded
                  : tooEarlyToStart
                      ? Icons.schedule_rounded
                      : Icons.play_arrow_rounded,
              label: tooLateToStart
                  ? 'Session time has passed'
                  : tooEarlyToStart
                      ? 'Start opens at ${DateFormat('h:mm a').format(startOpensAt)}'
                      : 'Start session & join call',
              muted: tooEarlyToStart || tooLateToStart,
              onTap: onStart,
            )
          else if (isLive)
            _PrimaryAction(
              icon: Icons.videocam_rounded,
              label: 'Live now · Rejoin call',
              onTap: openCall,
            )
          else
            Text(
              status == 'pending'
                  ? 'Booked'
                  : status == 'completed'
                      ? 'Completed'
                      : status,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                color: _muted,
              ),
            ),

          // ── Two equal secondary actions ──
          if (isConfirmed || isLive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SecondaryAction(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: openProfile,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isLive
                      ? _SecondaryAction(
                          // Nov 2026: this tap is her "ended" time.
                          icon: Icons.call_end_rounded,
                          label: 'End session',
                          onTap: () => _markCompleted(dietController, appointment),
                        )
                      // Before the start there is no separate "Join call":
                      // joining Meet without tapping Start left the client
                      // stuck on a yellow button with no notification.
                      : _SecondaryAction(
                          icon: Icons.assignment_outlined,
                          label: 'Health form',
                          onTap: openForm,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondaryAction(
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    color: _danger,
                    onTap: () => _confirmCancel(context, dietController, appointment),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ends the consultation, then points the dietitian straight at the
/// next step: her plan is now due within 48 hours.
Future<void> _markCompleted(
  DietController dietController,
  diet_models.Appointment appointment,
) async {
  final ok = await dietController.setAppointmentStatusInline(
      appointment.id, 'completed');
  if (!ok) return;
  dietController.clientsOfDietFunc();
  final goNow = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('Consultation completed'),
      content: const Text(
        'Her plan is now due within 2 working days. Want to create it now?',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<bool>(result: false),
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: () => Get.back<bool>(result: true),
          child: const Text('Create plan'),
        ),
      ],
    ),
  );
  if (goNow == true) {
    Get.to(() => const PlansToDeliverScreen());
  }
}

Future<void> _confirmClientNoShow(
  BuildContext context,
  DietController dietController,
  diet_models.Appointment appointment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Client didn't join?"),
      content: const Text(
        "We'll cancel this session without using up her consultation and ask her to book a new time. You can do this 10 minutes after the start time.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep waiting'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text("Yes, she didn't join",
              style: TextStyle(color: Color(0xFF8A5A06))),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await dietController.reportClientNoShow(appointment.id);
  }
}

Future<void> _confirmCancel(
  BuildContext context,
  DietController dietController,
  diet_models.Appointment appointment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this consultation?'),
      content: const Text(
        "This cancels the session for the client. They'll need to book a new time if they still want one.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cancel it', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await dietController.setAppointmentStatusInline(appointment.id, 'canceled');
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // Muted = not available yet (e.g. too early to start): soft mint
  // fill with dark text instead of the solid green call-to-action.
  final bool muted;
  const _PrimaryAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.muted = false});

  @override
  Widget build(BuildContext context) {
    final fg = muted ? const Color(0xFF1A3A22) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? const Color(0xFFEAF7E4) : const Color(0xFF6DC55A),
          borderRadius: BorderRadius.circular(14),
          border: muted ? Border.all(color: const Color(0xFFD8EDD4)) : null,
          boxShadow: muted
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF6DC55A).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1A3A22),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color == const Color(0xFF1A3A22)
                  ? const Color(0xFFD8EDD4)
                  : color.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isToday;
  final bool first;
  const _DayHeader({
    required this.label,
    required this.count,
    required this.isToday,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 10, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF6DC55A) : const Color(0xFFC8DEC4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3A22),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 session' : '$count sessions',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF7A8C78),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuRow(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'In Progress';
    final isConfirmed = status == 'confirmed';
    final bg = isLive
        ? const Color(0xFFE24B4A).withOpacity(0.12)
        : isConfirmed
            ? const Color(0xFF6DC55A).withOpacity(0.16)
            : Colors.black.withOpacity(0.06);
    final fg = isLive
        ? const Color(0xFFE24B4A)
        : isConfirmed
            ? const Color(0xFF2F7A22)
            : Colors.black.withOpacity(0.5);
    final label = isLive ? '● LIVE' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}


// ── Nov 2026: attendance (join / leave times from the app) ─────────────

String? _hm(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
  return d == null ? null : DateFormat('h:mm a').format(d);
}

Map<String, dynamic> _part(diet_models.Appointment a, String key) {
  final at = a.attendance;
  final v = at == null ? null : at[key];
  return v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
}

/// Finished call where we don't know if she came: no Join tap, not marked
/// missed, not answered yet, not checked by Google.
bool _needsJoinAnswer(diet_models.Appointment a) =>
    a.status == 'completed' &&
    a.clientJoinTapAt == null &&
    a.clientNoShowAt == null &&
    a.attendanceFlag != 'dietitian_confirmed' &&
    a.attendanceSource != 'google';

/// Line on an upcoming / live card.
String? _liveLine(diet_models.Appointment a) {
  final tapped = _hm(a.clientJoinTapAt);
  if (a.status == 'confirmed') {
    return tapped == null ? null : 'Client is waiting · tapped Join at $tapped';
  }
  if (a.status == 'In Progress') {
    return tapped == null ? "Client hasn't tapped Join in the app yet" : 'Client joined at $tapped';
  }
  return null;
}

/// Times for a finished call.
String _finishedText(diet_models.Appointment a) {
  final c = _part(a, 'client');
  final d = _part(a, 'dietitian');
  final dStart = _hm(d['startedAt']);
  final dEnd = _hm(d['endedAt']);
  final you = [
    if (dStart != null) 'You: started $dStart',
    if (dEnd != null) 'ended $dEnd${d['endedHow'] == 'auto' ? ' (auto)' : ''}',
  ].join(' · ');
  final cJoin = _hm(c['joinedAt']);
  final cLeft = _hm(c['leftAt']);
  final mins = c['minutes'];
  final joins = c['joins'] is num ? (c['joins'] as num).toInt() : 0;
  String client;
  if (cJoin != null) {
    client = 'Client: joined $cJoin';
    if (joins > 1) client += ' ($joins times)';
    if (cLeft != null) client += ' · left ${c['leftHow'] == 'app' ? 'about' : 'by'} $cLeft';
    if (mins is num) client += ' · about ${mins.toInt()} min';
  } else if (c['minutesFrom'] == 'dietitian' && mins is num) {
    client = 'Client: about ${mins.toInt()} min (your answer)';
  } else if (a.clientNoShowAt != null) {
    client = "Client: didn't join";
  } else {
    client = "Client: didn't tap Join in the app";
  }
  final google = a.attendanceSource == 'google';
  return [if (you.isNotEmpty) you, client, if (!google) 'Times from the app, close but not exact.'].join('\n');
}

Widget _infoBox(String text, {bool warm = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: warm ? const Color(0xFFFFF4DE) : const Color(0xFFF6F8F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warm ? Icons.person_pin_circle_rounded : Icons.schedule_rounded,
            size: 16, color: warm ? const Color(0xFF8A5A06) : const Color(0xFF1A3A22)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  height: 1.45,
                  color: warm ? const Color(0xFF8A5A06) : const Color(0xFF1A3A22))),
        ),
      ]),
    );

String _clientName(diet_models.Appointment a) {
  final n = '${a.clientUser?.firstName.trim() ?? ''} ${a.clientUser?.lastName.trim() ?? ''}'.trim();
  return n.isEmpty ? 'Client' : n;
}

String _whenLabel(diet_models.Appointment a) {
  final day = DateFormat('EEE d MMM').format(DateTime.utc(a.date.year, a.date.month, a.date.day));
  final range = a.slotDiet == null ? '' : ' · ${a.slotDiet!.start ?? '?'} – ${a.slotDiet!.end ?? '?'}';
  return '$day$range';
}

class _FinishedRow extends StatelessWidget {
  final diet_models.Appointment appointment;
  const _FinishedRow({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_clientName(appointment),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1A3A22))),
        const SizedBox(height: 2),
        Text(_whenLabel(appointment),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF7A8C78))),
        const SizedBox(height: 8),
        _infoBox(_finishedText(appointment)),
      ]),
    );
  }
}

/// "Did she join?" after a call with no Join tap: Yes + about how long, or No.
class _JoinAnswerCard extends StatelessWidget {
  final diet_models.Appointment appointment;
  const _JoinAnswerCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final DietController c = Get.find();
    final first = _clientName(appointment).split(' ').first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1DDB0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Did $first join your call?',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1A3A22))),
        const SizedBox(height: 2),
        Text("${_whenLabel(appointment)} · she didn't tap Join in the app",
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF7A8C78))),
        const SizedBox(height: 10),
        const Text('Yes, for about:',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF7A8C78))),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in const [10, 20, 30, 45])
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A3A22),
                side: const BorderSide(color: Color(0xFF6DC55A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => c.confirmClientJoined(appointment.id, m),
              child: Text('$m min', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () async {
            await c.reportClientNoShow(appointment.id);
            c.getAppointmentsOfDiets();
          },
          child: const Text("No, she didn't join",
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Color(0xFF8A5A06))),
        ),
      ]),
    );
  }
}
