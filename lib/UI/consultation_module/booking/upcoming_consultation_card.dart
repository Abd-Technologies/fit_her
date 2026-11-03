import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/api_provider/api_provider.dart';
import '../../../values/constants.dart';
import '../../../data/models/consultation/upcoming_appointment.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/v2/v2_buttons.dart';
import 'book_consultation_sheet.dart';
import '../../../helper/meeting_link.dart';
import '../../../helper/popup_manager.dart';
import '../../../helper/consult_presence.dart';
import '../../support/report_issue_screen.dart';

const Color _kHeroDark = Color(0xFF163220);
const Color _kSage = Color(0xFF9AB09A);
const Color _kBodyMuted = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kPendingTint = Color(0xFFB8790A);
const Color _kPendingBg = Color(0xFFFAC775);

// Join Meeting button stages.
const Color _kGreyBtn = Color(0xFFC9D6CE);
const Color _kGreyBtnText = Color(0xFF6F8B7A);
const Color _kYellowBtn = Color(0xFFFFC940);
const Color _kYellowBtnText = Color(0xFF6B4E00);
const Color _kGreenBtn = _kAccent;

// "Missed session" card — a soft coral, distinct from the amber
// "waiting on her" notice and the green "all done" success state.
const Color _kMissedTint = Color(0xFFC0392B);
const Color _kMissedBg = Color(0xFFF6D9D6);

/// How long before the scheduled start time the one-time "be on time"
/// caution popup fires.

/// How often the card polls the server while a booking is confirmed or
/// in progress — the dietitian can add a link, hit Start, or the
/// auto-end cron can mark it completed at any moment, all server-side,
/// so this is a real refetch (not just a UI rebuild off cached data).
const Duration _kPollInterval = Duration(seconds: 20);

/// "Your booked consultation" card. Shown at the top of the Diet tab
/// whenever `ConsultationController.upcomingAppointment` is non-null.
///
/// Flow: while `pending`, Reschedule/Cancel as before. Once the
/// dietitian confirms, Reschedule is replaced by a 4-stage "Join
/// Meeting" button — grey (no link yet) -> yellow (link's in, waiting
/// for her to start) -> green (session is live, tap to join) -> a
/// post-completion "your plan will be delivered in 2 working days"
/// state. A one-time caution popup fires ~15 minutes before the
/// scheduled start so she doesn't get caught off guard.
///
/// Self-contained and reactive off the controller: the caller just
/// drops `const UpcomingConsultationCard()` into the tree and calls
/// `ConsultationController.loadUpcomingAppointment()` once (e.g. on tab
/// build + pull-to-refresh) — this widget renders nothing until that
/// resolves to a non-null booking.
class UpcomingConsultationCard extends StatefulWidget {
  const UpcomingConsultationCard({super.key});

  @override
  State<UpcomingConsultationCard> createState() =>
      _UpcomingConsultationCardState();
}

class _UpcomingConsultationCardState extends State<UpcomingConsultationCard> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _onTick());
    // Also run one check right away in case the app was opened already
    // inside the 15-minute caution window.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTick());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final ctrl = Get.find<ConsultationController>();
    final appt = ctrl.upcomingAppointment.value;
    if (appt == null) return;
    if (appt.paymentHold) return; // on hold: no join/caution prompts
    if (appt.status == 'confirmed' || appt.status == 'In Progress') {
      ctrl.loadUpcomingAppointment();
    }
    // (Oct 2026) The "Your session is coming up" dialog was removed: the
    // 15-min push and this card's countdown + Join button already cover it.
  }

  /// Combines `appt.date` ("2026-09-16") + `appt.slotStart` ("3:30 PM")
  /// into a real local DateTime. Wall-clock strings, same as everywhere
  /// else in this flow — assumes the device's local time is the
  /// consultation's timezone, which holds for this app's user base.
  DateTime? _scheduledStart(UpcomingAppointment appt) {
    final start = appt.slotStart?.trim();
    if (appt.date.trim().isEmpty || start == null || start.isEmpty) {
      return null;
    }
    try {
      return DateFormat('yyyy-MM-dd h:mm a').parse('${appt.date} $start');
    } catch (_) {
      return null;
    }
  }

  /// Consultation change policy (backend helper/bookingPolicy.js):
  /// she can reschedule or cancel freely until 24 hours before the
  /// session. Inside 24 hours the time is locked: the card switches to
  /// the Join Meeting flow, and Cancel only shows while her one free late
  /// change for this package is still unused. The server enforces the
  /// same rules.
  static const Duration _kRescheduleCutoff = Duration(hours: 24);

  /// Session length (the booking screen says "30 min · video call") and
  /// the no-show cut-off: not started 10 min after the start → cancelled.
  static const Duration _kSessionLength = Duration(minutes: 30);
  static const Duration _kNoShowAfter = Duration(minutes: 10);
  static const Duration _kOpensBefore = Duration(minutes: 10);

  DateTime? _cutoff(UpcomingAppointment appt) =>
      _scheduledStart(appt)?.add(_kNoShowAfter);

  static String _fmt(DateTime t) => DateFormat('h:mm a').format(t);

  /// 10 min before the start → the 10-min cut-off.
  bool _inStartWindow(UpcomingAppointment appt) {
    final start = _scheduledStart(appt);
    if (start == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start.subtract(_kOpensBefore)) &&
        now.isBefore(start.add(_kNoShowAfter));
  }

  bool _isLate(UpcomingAppointment appt) {
    final start = _scheduledStart(appt);
    if (start == null) return false;
    return !DateTime.now().isBefore(start.subtract(_kRescheduleCutoff));
  }

  bool _canReschedule(UpcomingAppointment appt) {
    if (appt.status != 'confirmed' && appt.status != 'pending') return false;
    final start = _scheduledStart(appt);
    if (start == null) return appt.canModify; // legacy pending, unknown time
    return DateTime.now().isBefore(start.subtract(_kRescheduleCutoff));
  }


  @override
  /// On hold: her payment isn't confirmed yet (Oct 2026). Keeps her time;
  /// no Join / Reschedule until our team confirms it.
  Widget _holdCard(UpcomingAppointment appt) {
    final time = (appt.slotStart ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kPendingBg.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.pause_circle_outline_rounded,
                  color: _kPendingTint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONSULTATION ON HOLD',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kPendingTint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_friendlyDate(appt.date)}${time.isEmpty ? '' : ' · $time'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kHeroDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "We're confirming your payment. Your time is kept and the call goes ahead as soon as it's confirmed.",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.45,
                      color: _kBodyMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    final ctrl = Get.find<ConsultationController>();
    return Obx(() {
      final appt = ctrl.upcomingAppointment.value;
      if (appt == null) return const SizedBox.shrink();
      if (appt.paymentHold) return _holdCard(appt);
      final isCompleted = appt.status == 'completed';
      // Nov 2026: plan delivered and session rated: nothing left to show.
      if (isCompleted && appt.planDelivered && appt.reviewed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      (appt.noShow || appt.clientNoShow || appt.dietitianCanceled || appt.expired)
                          ? Icons.event_busy_rounded
                          : (isCompleted
                              ? Icons.task_alt_rounded
                              : Icons.event_available_rounded),
                      color: _kAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.dietitianCanceled
                              ? 'SESSION CANCELED'
                              : (appt.noShow || appt.clientNoShow)
                              ? 'SESSION MISSED'
                              : (appt.expired
                                  ? 'BOOKING EXPIRED'
                                  : (isCompleted
                                      ? 'CONSULTATION COMPLETE'
                                      : (appt.kind == 'followup'
                                          ? 'FOLLOW-UP CONSULTATION'
                                          : 'CONSULTATION BOOKED'))),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kSage,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _friendlyDate(appt.date),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _kBodyMuted,
                          ),
                        ),
                        if (_formatTimeRange(appt).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              _formatTimeRange(appt),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kHeroDark,
                              ),
                            ),
                          ),
                        if (appt.dietitianName != null &&
                            appt.dietitianName!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'with ${appt.dietitianName}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: _kBodyMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    status: appt.status,
                    noShow: appt.noShow || appt.clientNoShow || appt.dietitianCanceled,
                    canceled: appt.dietitianCanceled,
                    expired: appt.expired,
                  ),
                ],
              ),
              if (appt.expired) ...[
                const SizedBox(height: 14),
                _ExpiredCard(
                  onRebook: () => _onRebookAfterNoShow(context, ctrl, appt),
                ),
              ] else if (appt.noShow || appt.dietitianCanceled) ...[
                const SizedBox(height: 14),
                _NoShowCard(
                  canceled: appt.dietitianCanceled,
                  bonusDays: appt.noShowBonusDays,
                  onRebook: () => _onRebookAfterNoShow(context, ctrl, appt),
                ),
              ] else if (appt.clientNoShow) ...[
                const SizedBox(height: 14),
                _ClientMissedCard(
                  locked: appt.bookingLocked,
                  onRebook: () => _onRebookAfterNoShow(context, ctrl, appt),
                ),
              ] else if (isCompleted) ...[
                if (!appt.reviewed) ...[
                  const SizedBox(height: 14),
                  _RateSessionCard(
                    key: ValueKey('rate_${appt.id}'),
                    appointmentId: appt.id,
                    dietitianName: appt.dietitianName,
                  ),
                ],
                const SizedBox(height: 14),
                // Nov 2026: plan already sent: say so instead of "will be
                // delivered in 2 working days".
                appt.planDelivered ? const _PlanDeliveredNote() : _DeliveryTimeline(),
              ] else if (_canReschedule(appt)) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: V2SecondaryButton(
                        label: 'Reschedule',
                        onPressed: () => _onReschedule(context, ctrl, appt),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: V2GhostButton(
                        label: 'Cancel',
                        onPressed: () => _onCancel(context, ctrl, appt),
                      ),
                    ),
                  ],
                ),
              ] else if (appt.status == 'confirmed' ||
                  appt.status == 'In Progress') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _JoinMeetingButton(
                        appt: appt,
                        opensAt: _scheduledStart(appt)?.subtract(_kOpensBefore),
                        onTap: () => _onJoinMeetingTap(context, appt),
                      ),
                    ),
                    if (appt.status == 'confirmed') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        // Inside 24h she can cancel only while her one
                        // free late change is unused; otherwise point her
                        // to support instead of a button the server will
                        // refuse.
                        child: appt.lateChangeAvailable
                            ? V2GhostButton(
                                label: 'Cancel',
                                onPressed: () => _onCancel(context, ctrl, appt),
                              )
                            : V2GhostButton(
                                label: 'Need help?',
                                onPressed: () =>
                                    Get.to(() => const ReportIssueScreen()),
                              ),
                      ),
                    ],
                  ],
                ),
                if (appt.status == 'confirmed' && _inStartWindow(appt)) ...[
                  // Oct 2026: from 10 min before the start until the 10-min
                  // cut-off, say what happens if the dietitian doesn't start
                  // (the server cancels it then: helper/dietitianLateCheck.js).
                  const SizedBox(height: 8),
                  // 5 min late (Oct 2026): she's told the dietitian is late.
                  Text(
                    (appt.dietitianLate
                            ? 'Your dietitian is running a little late, hang on. '
                            : 'The button turns green as soon as your dietitian starts. ') +
                        "If she hasn't started by ${_fmt(_cutoff(appt)!)}, we cancel "
                        'it for free, add 3 days to your package and you can book '
                        'a new time.',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: _kHeroDark,
                    ),
                  ),
                ] else if (appt.status == 'confirmed' && _isLate(appt)) ...[
                  const SizedBox(height: 8),
                  Text(
                    appt.lateChangeAvailable
                        ? "Less than 24 hours to go, so the time can't be changed. "
                            'You can still cancel once on this package.'
                        : "Less than 24 hours to go, so the time can't be changed. "
                            "You've used your free late change on this package.",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      height: 1.4,
                      color: _kBodyMuted,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    });
  }

  /// "2026-09-16" -> "Today" / "Tomorrow" / "Wed, Sep 16" (adds the year
  /// only when it isn't the current one) — a single friendly line instead
  /// of the raw ISO date, which used to wrap mid-word inside the card's
  /// narrow column.
  String _friendlyDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    final pattern = parsed.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, yyyy';
    return DateFormat(pattern).format(parsed);
  }

  /// "3:30 PM" + "4:30 PM" -> "3:30 – 4:30 PM" (drops the repeated AM/PM
  /// when both ends share it) so the time range reads as one short line
  /// instead of "3:30 PM–4:30 PM" running into the date above it.
  String _formatTimeRange(UpcomingAppointment appt) {
    final start = appt.slotStart;
    // Oct 2026: her SESSION (start + 30 min), not the dietitian's whole
    // free slot (was "5:04 – 7:00 PM" for a 30-min call).
    final startAt = _scheduledStart(appt);
    final end = startAt != null
        ? _fmt(startAt.add(_kSessionLength))
        : appt.slotEnd;
    if (start == null || start.trim().isEmpty) return '';
    if (end == null || end.trim().isEmpty) return start.trim();
    final suffix = RegExp(r'^(.*?)\s*(AM|PM)$', caseSensitive: false);
    final startMatch = suffix.firstMatch(start.trim());
    final endMatch = suffix.firstMatch(end.trim());
    if (startMatch != null &&
        endMatch != null &&
        startMatch.group(2)!.toUpperCase() == endMatch.group(2)!.toUpperCase()) {
      return '${startMatch.group(1)} – ${end.trim()}';
    }
    return '${start.trim()} – ${end.trim()}';
  }

  Future<void> _onReschedule(
    BuildContext context,
    ConsultationController ctrl,
    UpcomingAppointment appt,
  ) async {
    await BookConsultationSheet.show(
      popupVariable: 'POPUP_RESCHEDULE_CONSULTATION',
      dietitianId: appt.dietitianId,
      dietitianName: appt.dietitianName,
      userId: appt.userId,
      userPlanId: appt.userPlanId,
      kind: appt.kind ?? 'initial',
      rescheduleAppointmentId: appt.id,
    );
    // Whichever way the sheet was dismissed — booked a new slot, or the
    // user backed out — reload so the card reflects the true server
    // state rather than assuming success.
    await ctrl.loadUpcomingAppointment();
  }

  Future<void> _onCancel(
    BuildContext context,
    ConsultationController ctrl,
    UpcomingAppointment appt,
  ) async {
    final hasName =
        appt.dietitianName != null && appt.dietitianName!.trim().isNotEmpty;
    final time = _formatTimeRange(appt);
    final when = time.isEmpty
        ? _friendlyDate(appt.date)
        : '${_friendlyDate(appt.date)} · $time';
    final canReschedule = _canReschedule(appt);
    final late = _isLate(appt);

    // Same visual language as the app's other V2 dialogs (trial start,
    // locked feature): white rounded card, tinted icon badge, Poppins,
    // V2 buttons. "Keep my booking" is the primary action on purpose —
    // cancelling is the destructive choice, so it's the quieter one.
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07B7B).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_busy_rounded,
                      size: 26, color: Color(0xFFE07B7B)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cancel your consultation?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A22),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "You'll need to pick a new time to get your meal plan started.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF7A8C78),
                ),
              ),
              if (late) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "It's less than 24 hours before your session, so this "
                    'uses your one free late change for this package.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF8A5A06),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // The booking being cancelled, so there's no doubt which one.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7E4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8EDD4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 17, color: Color(0xFF6DC55A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            when,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A3A22),
                            ),
                          ),
                          if (hasName)
                            Text(
                              'with ${appt.dietitianName!.trim()}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF7A8C78),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              V2PrimaryButton(
                label: 'Keep my booking',
                onPressed: () => Navigator.of(ctx).pop(null),
              ),
              if (canReschedule) ...[
                const SizedBox(height: 8),
                V2SecondaryButton(
                  label: 'Pick a different time',
                  onPressed: () => Navigator.of(ctx).pop('reschedule'),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text(
                  'Yes, cancel it',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE07B7B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'reschedule') {
      if (context.mounted) await _onReschedule(context, ctrl, appt);
      return;
    }
    if (choice != 'cancel') return;
    final ok = await ctrl.cancelAppointment(appt.id);
    if (ok) {
      // Oct 2026: tell her the next step (the Book card shows again).
      CustomToast.successToast(
          msg: 'Consultation canceled. Tap "Book" to pick a new time.');
    }
  }

  /// Attendance from taps (Oct 2026): tells the server she tapped Join
  /// (first tap kept), from 15 min before the call. Works for every
  /// dietitian; the dietitian sees "Client is waiting". Fire and forget.
  void _recordJoinTap(UpcomingAppointment appt) {
    final start = _scheduledStart(appt);
    if (start != null && DateTime.now().isBefore(start.subtract(const Duration(minutes: 15)))) return;
    () async {
      try {
        final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
        await Get.find<ApiProvider>().postData(
          '/appointment/${appt.id}/join-tap',
          body: const <String, dynamic>{},
          headers: {'accessToken': token},
        );
      } catch (_) {}
    }();
  }

  Future<void> _onJoinMeetingTap(
      BuildContext context, UpcomingAppointment appt) async {
    _recordJoinTap(appt);
    final hasLink = appt.dietitionLink != null &&
        appt.dietitionLink!.trim().isNotEmpty;
    final isLive = appt.status == 'In Progress';

    if (isLive && hasLink) {
      if (!await openMeetingLink(appt.dietitionLink)) {
        CustomToast.failToast(msg: "Couldn't open the meeting link.");
        return;
      }
      // Nov 2026: when she comes back to Fit Her, that's her "left" time.
      ConsultPresence.instance.openedMeet(appt.id);
      return;
    }
    if (isLive && !hasLink) {
      CustomToast.failToast(
          msg: "Your session has started, but the meeting link is missing. "
              "Please contact us.");
      return;
    }

    // Not yet joinable — grey or yellow. Give a short, specific reason
    // instead of just not responding to the tap.
    final message = hasLink
        ? "Your dietitian hasn't started the session yet — this will "
            "turn green the moment she does. Tap it then to join."
        : "Your dietitian hasn't shared the meeting link yet — check "
            "back closer to your session time.";
    CustomToast.failToast(
      bgcolor: _kHeroDark,
      textColor: Colors.white,
      msg: message,
    );
  }

  /// This is a fresh booking, not a reschedule — the missed appointment
  /// is already resolved (canceled) server-side, so there's nothing to
  /// reschedule against. Reuses the same sheet the normal "book a
  /// consultation" flow uses, just without `rescheduleAppointmentId`.
  Future<void> _onRebookAfterNoShow(
    BuildContext context,
    ConsultationController ctrl,
    UpcomingAppointment appt,
  ) async {
    await BookConsultationSheet.show(
      popupVariable: appt.kind == 'followup'
          ? 'POPUP_BOOK_FOLLOWUP_CONSULTATION'
          : 'POPUP_BOOK_INITIAL_CONSULTATION',
      dietitianId: appt.dietitianId,
      dietitianName: appt.dietitianName,
      userId: appt.userId,
      userPlanId: appt.userPlanId,
      kind: appt.kind ?? 'initial',
    );
    await ctrl.loadUpcomingAppointment();
  }
}

/// The 4th "state" isn't drawn by this widget at all — once
/// `appt.status == 'completed'`, the button row is replaced entirely by
/// `_DeliveryTimeline` in the parent's build method.
class _JoinMeetingButton extends StatelessWidget {
  final UpcomingAppointment appt;
  final VoidCallback onTap;

  /// When the dietitian can start (10 min before): before then the grey
  /// button says "Opens at …" so it doesn't look broken. Oct 2026.
  final DateTime? opensAt;

  const _JoinMeetingButton({required this.appt, required this.onTap, this.opensAt});

  @override
  Widget build(BuildContext context) {
    final hasLink =
        appt.dietitionLink != null && appt.dietitionLink!.trim().isNotEmpty;
    final isLive = appt.status == 'In Progress';

    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;

    if (isLive) {
      bg = _kGreenBtn;
      fg = Colors.white;
      label = 'Join Meeting';
      icon = Icons.videocam_rounded;
    } else if (hasLink) {
      bg = _kYellowBtn;
      fg = _kYellowBtnText;
      label = 'Join Meeting';
      icon = Icons.hourglass_top_rounded;
    } else {
      bg = _kGreyBtn;
      fg = _kGreyBtnText;
      label = 'Join Meeting';
      icon = Icons.videocam_off_rounded;
    }
    // Not live yet: say when it opens, or that it waits for her.
    var shown = label;
    if (!isLive && opensAt != null) {
      shown = DateTime.now().isBefore(opensAt!)
          ? 'Opens at ${DateFormat('h:mm a').format(opensAt!)}'
          : 'Waiting for dietitian';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                shown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the button row when `appt.noShow` is true. The
/// server decided the dietitian never joined (Meet attendance, or the
/// 24h fallback), already canceled the session and added free days to
/// her package. She is never asked to report it; this card just tells
/// her what happened and what to do next.
class _NoShowCard extends StatelessWidget {
  final int bonusDays;
  // True when the dietitian cancelled (rather than missed) the session.
  final bool canceled;
  final VoidCallback onRebook;
  const _NoShowCard(
      {required this.onRebook, this.bonusDays = 0, this.canceled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kMissedBg.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMissedTint.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_busy_rounded,
                  color: _kMissedTint, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canceled
                          ? 'Your dietitian had to cancel this session'
                          : "Your dietitian couldn't join, so we canceled this session",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kMissedTint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bonusDays > 0
                          ? "We've added $bonusDays free days to your package. "
                              'Pick a new time that suits you, at no cost.'
                          : 'Pick a new time that suits you, at no cost.',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: _kBodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: V2SecondaryButton(
              label: 'Pick a new time',
              onPressed: onRebook,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when SHE missed the session (`appt.clientNoShow`). The server
/// already canceled it. First miss on the package: it used her one free
/// late change, and she can pick a new time. Second miss: self-booking
/// is locked and our team books with her, so we point her to support.
class _ClientMissedCard extends StatelessWidget {
  final bool locked;
  final VoidCallback onRebook;
  const _ClientMissedCard({required this.locked, required this.onRebook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kMissedBg.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMissedTint.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_busy_rounded,
                  color: _kMissedTint, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You missed this session',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kMissedTint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? "This is the second missed session on your package, "
                              'so our team will book your next one with you.'
                          : 'This used your one free late change for this '
                              "package. Let's find you a new time.",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: _kBodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: locked
                ? V2SecondaryButton(
                    label: 'Contact us',
                    onPressed: () =>
                        Get.to<dynamic>(() => const ReportIssueScreen()),
                  )
                : V2SecondaryButton(
                    label: 'Pick a new time',
                    onPressed: onRebook,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the button row when `appt.expired` is true — the
/// dietitian never confirmed the booking at all before its scheduled
/// time passed, it's already been auto-canceled server-side, and this
/// tells the client plainly to book a new time instead of leaving a
/// "PENDING" card sitting there forever with a dead Reschedule/Cancel
/// row and no explanation.
class _ExpiredCard extends StatelessWidget {
  final VoidCallback onRebook;
  const _ExpiredCard({required this.onRebook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kMissedBg.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMissedTint.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event_busy_rounded,
                  color: _kMissedTint, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your dietitian didn't confirm this booking in time",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kMissedTint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "It's been canceled — book a new time whenever "
                      "works for you, free of charge.",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: _kBodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: V2SecondaryButton(
              label: 'Reschedule — it\'s free',
              onPressed: onRebook,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the button row once `status == 'completed'` — the
/// short window the backend keeps returning a just-finished appointment
/// for, purely so this message has somewhere to land instead of the
/// card just vanishing the instant the session ends.
/// "How was your session?" — shown on a completed consultation until she
/// rates it or taps "Not now" (remembered per session on this phone).
/// Tap a star, optionally pick quick tags / add a note, then Send.
/// Saved via POST /appointment/:id/review (one rating per session).
class _RateSessionCard extends StatefulWidget {
  final int appointmentId;
  final String? dietitianName;
  /// Nov 2026: called after she sends or taps "Not now" (the pop-up closes).
  final VoidCallback? onDone;
  const _RateSessionCard(
      {super.key, required this.appointmentId, this.dietitianName, this.onDone});

  @override
  State<_RateSessionCard> createState() => _RateSessionCardState();
}

class _RateSessionCardState extends State<_RateSessionCard> {
  static const _goodTags = [
    'Listened to me',
    'Clear advice',
    'Felt personal',
    'On time',
  ];
  static const _badTags = [
    'Felt rushed',
    'Advice unclear',
    'Started late',
    'Call problems',
  ];

  int _stars = 0;
  final Set<String> _tags = <String>{};
  final TextEditingController _note = TextEditingController();
  bool _sending = false;
  bool _hidden = false;

  String get _skipKey => 'session_rating_skipped_${widget.appointmentId}';

  String get _first {
    final parts = (widget.dietitianName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !RegExp(r'^dr\.?$', caseSensitive: false).hasMatch(p))
        .toList();
    return parts.isEmpty ? 'your dietitian' : parts.first;
  }

  @override
  void initState() {
    super.initState();
    // Nov 2026: an old permanent "Not now" no longer hides it.
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_skipKey));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // Nov 2026: the rating matters, so "Not now" only hides it for now. It
  // comes back the next time she opens the Diet tab, until she rates it
  // (or the 2 days to rate it are over).
  Future<void> _skip() async {
    setState(() => _hidden = true);
    widget.onDone?.call();
  }

  Future<void> _send() async {
    if (_stars == 0 || _sending) return;
    setState(() => _sending = true);
    final note = _note.text.trim();
    final parts = <String>[
      if (_tags.isNotEmpty) _tags.join(', '),
      if (note.isNotEmpty) note,
    ];
    final ok = await Get.find<ConsultationController>().rateConsultation(
      appointmentId: widget.appointmentId,
      rating: _stars,
      comment: parts.isEmpty ? null : parts.join(' | '),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      CustomToast.successToast(msg: 'Thank you! Your feedback helps us.');
      widget.onDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final tags = _stars >= 4 ? _goodTags : _badTags;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'How was your session with $_first?',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kHeroDark,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _skip,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _kBodyMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              final on = n <= _stars;
              return GestureDetector(
                onTap: () => setState(() {
                  // Tags differ for good vs. poor ratings; clear on switch.
                  if ((n >= 4) != (_stars >= 4)) _tags.clear();
                  _stars = n;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    on ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: on ? _kYellowBtn : _kSage,
                  ),
                ),
              );
            }),
          ),
          if (_stars > 0) ...[
            const SizedBox(height: 10),
            Text(
              _stars >= 4 ? 'What went well?' : 'What could be better?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _kBodyMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) {
                final on = _tags.contains(t);
                return GestureDetector(
                  onTap: () => setState(() => on ? _tags.remove(t) : _tags.add(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: on ? _kAccent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? _kAccent : _kCardBorder),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : _kHeroDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, color: _kHeroDark),
              decoration: InputDecoration(
                hintText: 'Anything else? (optional)',
                hintStyle: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: _kSage),
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCardBorder),
                ),
              ),
            ),
            const SizedBox(height: 10),
            V2PrimaryButton(
              label: 'Send',
              busy: _sending,
              onPressed: _send,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanDeliveredNote extends StatelessWidget {
  const _PlanDeliveredNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9DFA9)),
      ),
      child: const Row(children: [
        Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF3E8E4A)),
        SizedBox(width: 10),
        Expanded(
          child: Text('Your plan is ready. Your meals are below.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1A3A22))),
        ),
      ]),
    );
  }
}

class _DeliveryTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _kAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your plan will be delivered in 2 working days',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kHeroDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TimelineStep(
            label: 'Session completed',
            done: true,
            isLast: false,
          ),
          _TimelineStep(
            label: "Dietitian prepares your plan",
            done: false,
            isLast: false,
          ),
          _TimelineStep(
            label: 'Plan delivered to you',
            done: false,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.done,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? _kAccent : _kAccent.withOpacity(0.25),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: _kAccent.withOpacity(0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                color: done ? _kHeroDark : _kBodyMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool noShow;
  final bool expired;
  /// Nov 2026: the DIETITIAN cancelled it: "CANCELED", not "MISSED"
  /// (she didn't miss anything).
  final bool canceled;
  const _StatusPill({
    required this.status,
    this.noShow = false,
    this.expired = false,
    this.canceled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isLive = status == 'In Progress';
    final isCompleted = status == 'completed';
    final bg = (noShow || expired)
        ? _kMissedBg
        : (isPending ? _kPendingBg : _kAccent);
    final fg = (noShow || expired)
        ? _kMissedTint
        : (isPending ? _kPendingTint : _kAccent);
    final label = canceled
        ? 'CANCELED'
        : noShow
        ? 'MISSED'
        : (expired
            ? 'EXPIRED'
            : (isPending
                ? 'PENDING'
                : (isLive ? 'LIVE' : (isCompleted ? 'DONE' : 'CONFIRMED'))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kHeroDark.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}


/// Nov 2026: "How was your session?" as a pop-up the next time she opens
/// the app after a consultation she was in (not only on the Diet tab).
/// Once per session; never when rated, skipped ("Not now") or she missed it.
class SessionRatingPopup {
  SessionRatingPopup._();
  static bool _busy = false;

  /// She tapped the "How was your session?" push: open the rating now.
  static Future<void> openNow() async {
    try {
      if (!Get.isRegistered<ConsultationController>()) return;
      final ctrl = Get.find<ConsultationController>();
      await ctrl.loadUpcomingAppointment();
      final appt = ctrl.upcomingAppointment.value;
      if (appt == null || appt.status != 'completed' || appt.reviewed) return;
      await PopupManager.runNow('session_rating_push_${appt.id}', () => _sheet(appt.id, appt.dietitianName));
    } catch (_) {}
  }

  static Future<void> _sheet(int id, String? dietitianName) async {
    final context = Get.context;
    if (context == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
            ),
            _RateSessionCard(
              appointmentId: id,
              dietitianName: dietitianName,
              onDone: () {
                if (Navigator.of(sheet).canPop()) Navigator.of(sheet).pop();
              },
            ),
          ]),
        ),
      ),
    );
  }

  static Future<void> maybeShow() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!Get.isRegistered<ConsultationController>()) return;
      final ctrl = Get.find<ConsultationController>();
      await ctrl.loadUpcomingAppointment();
      final appt = ctrl.upcomingAppointment.value;
      if (appt == null || appt.status != 'completed' || appt.reviewed || !appt.askReview) return;
      // Nov 2026: the rating matters. Asked at most twice (the second time
      // at least 12 h after the first), ahead of the other pop-ups.
      final prefs = await SharedPreferences.getInstance();
      final countKey = 'session_rating_popup_n_${appt.id}';
      final atKey = 'session_rating_popup_at_${appt.id}';
      final asked = prefs.getInt(countKey) ?? 0;
      final lastAt = prefs.getInt(atKey) ?? 0;
      if (asked >= 2) return;
      if (asked == 1 &&
          DateTime.now().millisecondsSinceEpoch - lastAt < const Duration(hours: 12).inMilliseconds) {
        return;
      }
      await PopupManager.run(
        'session_rating_${appt.id}',
        rank: PopupRank.classRating,
        urgent: true,
        show: () async {
          await prefs.setInt(countKey, asked + 1);
          await prefs.setInt(atKey, DateTime.now().millisecondsSinceEpoch);
          final context = Get.context;
          if (context == null) return;
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (sheet) => Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
                  ),
                  _RateSessionCard(
                    appointmentId: appt.id,
                    dietitianName: appt.dietitianName,
                    onDone: () {
                      if (Navigator.of(sheet).canPop()) Navigator.of(sheet).pop();
                    },
                  ),
                ]),
              ),
            ),
          );
        },
      );
    } catch (_) {
    } finally {
      _busy = false;
    }
  }
}
