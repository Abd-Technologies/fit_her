import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/consultation_module/booking/upcoming_consultation_card.dart';
import '../../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/models/consultation/upcoming_appointment.dart';
import '../../helper/consult_presence.dart';
import '../../helper/meeting_link.dart';
import '../../values/constants.dart';
import '../toasts.dart';

/// Home: a slim banner for her consultation (Nov 2026).
///
/// Shows only when there is something to know or do:
///   today / tomorrow        "Consultation today · 3:30 PM"      → Diet tab
///   10 min before           "Starts at 3:30 PM"                 → Diet tab
///   dietitian started       "Dr Asma is ready for you" Join now → Meet
///   dietitian 5+ min late   "Running a little late"             → Diet tab
///   over, not rated         "How was your session?" Rate        → rating
///   cancelled by dietitian  "Your session was canceled"         → Diet tab
///   she missed it           "You missed your session"           → Diet tab
/// Hidden otherwise (more than a day away, on hold, nothing booked).
/// Same data as the Diet tab card (ConsultationController), so they agree;
/// times are already in her own time zone (the model converts them).
class ConsultationHomeBanner extends StatefulWidget {
  const ConsultationHomeBanner({super.key, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0)});
  final EdgeInsets padding;

  @override
  State<ConsultationHomeBanner> createState() => _ConsultationHomeBannerState();
}

enum _Kind { upcoming, soon, live, late, rate, canceled, missed }

class _Look {
  final IconData icon;
  final Color bg;
  final Color border;
  final Color fg;
  const _Look(this.icon, this.bg, this.border, this.fg);
}

class _ConsultationHomeBannerState extends State<ConsultationHomeBanner> {
  static const _ink = Color(0xFF1A3A22);
  static const _green = Color(0xFF3E8E4A);
  Timer? _tick;

  ConsultationController? get _ctrl =>
      Get.isRegistered<ConsultationController>() ? Get.find<ConsultationController>() : null;

  @override
  void initState() {
    super.initState();
    final c = _ctrl;
    if (c != null && c.upcomingAppointment.value == null) c.loadUpcomingAppointment();
    // Time-based states (soon / late) change without new data.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final a = _ctrl?.upcomingAppointment.value;
      // Around the call, ask the server too (started / late / ended).
      if (a != null && (a.status == 'confirmed' || a.status == 'In Progress')) {
        final st = _start(a);
        if (st != null && DateTime.now().isAfter(st.subtract(const Duration(minutes: 15)))) {
          _ctrl?.loadUpcomingAppointment();
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static DateTime? _start(UpcomingAppointment a) {
    final s = a.slotStart?.trim();
    if (s == null || s.isEmpty || a.date.trim().isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd h:mm a').parse('${a.date} $s');
    } catch (_) {
      return null;
    }
  }

  String get _who {
    final n = _ctrl?.upcomingAppointment.value?.dietitianName?.trim() ?? '';
    return n.isEmpty ? 'your dietitian' : n;
  }

  String _dayWord(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return DateFormat('EEE d MMM').format(d);
  }

  _Kind? _kindFor(UpcomingAppointment a) {
    if (a.paymentHold) return null;
    if (a.status == 'canceled') {
      if (a.dietitianCanceled || a.noShow) return _Kind.canceled;
      if (a.clientNoShow) return _Kind.missed;
      return null;
    }
    if (a.status == 'completed') {
      return (a.askReview && !a.reviewed) ? _Kind.rate : null;
    }
    if (a.status == 'In Progress') return _Kind.live;
    if (a.status != 'confirmed') return null;
    final st = _start(a);
    if (st == null) return null;
    final now = DateTime.now();
    if (a.dietitianLate || now.isAfter(st.add(const Duration(minutes: 5)))) return _Kind.late;
    if (!now.isBefore(st.subtract(const Duration(minutes: 10)))) return _Kind.soon;
    if (st.difference(now) > const Duration(hours: 36)) return null;
    final day = _dayWord(st);
    return (day == 'today' || day == 'tomorrow') ? _Kind.upcoming : null;
  }

  void _openDietTab() => Get.offAll<dynamic>(() => BottomBarScreen(index: 2));

  Future<void> _join(UpcomingAppointment a) async {
    // Same as the Diet tab card's Join: save the tap, open Meet, and
    // remember it so her return to Fit Her is her "left" time.
    try {
      final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      unawaited(Get.find<ApiProvider>().postData(
        '/appointment/${a.id}/join-tap',
        body: const <String, dynamic>{},
        headers: {'accessToken': token},
      ));
    } catch (_) {}
    final link = a.dietitionLink?.trim() ?? '';
    if (link.isEmpty) {
      CustomToast.failToast(msg: 'Your session has started, but the meeting link is missing. Please contact us.');
      return;
    }
    if (!await openMeetingLink(link)) {
      CustomToast.failToast(msg: "Couldn't open the meeting link.");
      return;
    }
    ConsultPresence.instance.openedMeet(a.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    if (c == null) return const SizedBox.shrink();
    return Obx(() {
      final a = c.upcomingAppointment.value;
      if (a == null) return const SizedBox.shrink();
      final kind = _kindFor(a);
      if (kind == null) return const SizedBox.shrink();
      final st = _start(a);
      final time = a.slotStart ?? '';

      late _Look look;
      late String title;
      late String sub;
      String? action;
      VoidCallback onTap = _openDietTab;

      switch (kind) {
        case _Kind.upcoming:
          look = const _Look(Icons.event_available_rounded, Color(0xFFF2F8EE), Color(0xFFD8EDD4), _ink);
          title = 'Consultation ${st == null ? 'soon' : _dayWord(st)} · $time';
          sub = 'Video call with $_who';
          break;
        case _Kind.soon:
          look = const _Look(Icons.videocam_rounded, Color(0xFFEAF7E4), Color(0xFFB9DFA9), _ink);
          title = 'Your consultation starts at $time';
          sub = 'Join opens when $_who starts the call';
          action = 'Open';
          break;
        case _Kind.live:
          look = const _Look(Icons.videocam_rounded, Color(0xFF3E8E4A), Color(0xFF3E8E4A), Colors.white);
          title = '$_who is ready for you';
          sub = 'Your consultation has started';
          action = 'Join now';
          onTap = () => _join(a);
          break;
        case _Kind.late:
          look = const _Look(Icons.hourglass_top_rounded, Color(0xFFFFF4DE), Color(0xFFF1DDB0), Color(0xFF8A5A06));
          title = '$_who is running a little late';
          sub = "Hang on, she'll start soon";
          break;
        case _Kind.rate:
          look = const _Look(Icons.star_rounded, Color(0xFFFFF8E6), Color(0xFFF5DFA6), _ink);
          title = 'How was your session with $_who?';
          sub = 'It takes 10 seconds and helps us look after you';
          action = 'Rate';
          onTap = () => SessionRatingPopup.openNow();
          break;
        case _Kind.canceled:
          look = const _Look(Icons.event_busy_rounded, Color(0xFFFCEDEC), Color(0xFFF3CFCB), Color(0xFFB2423A));
          title = 'Your session was canceled';
          sub = a.noShowBonusDays > 0
              ? '${a.noShowBonusDays} free days added · pick a new time'
              : 'Pick a new time, it’s free';
          action = 'Rebook';
          break;
        case _Kind.missed:
          look = const _Look(Icons.event_busy_rounded, Color(0xFFFCEDEC), Color(0xFFF3CFCB), Color(0xFFB2423A));
          title = 'You missed your session';
          sub = a.bookingLocked ? 'Our team will help you book a new time' : 'Book a new time that suits you';
          action = a.bookingLocked ? null : 'Rebook';
          break;
      }

      final live = kind == _Kind.live;
      return Padding(
        padding: widget.padding,
        child: Material(
          color: look.bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: look.border),
              ),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: live ? Colors.white.withOpacity(0.18) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(look.icon, size: 18, color: live ? Colors.white : look.fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: look.fg)),
                    const SizedBox(height: 1),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: live ? Colors.white.withOpacity(0.85) : look.fg.withOpacity(0.75))),
                  ]),
                ),
                const SizedBox(width: 8),
                if (action != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: live ? Colors.white : (kind == _Kind.canceled || kind == _Kind.missed ? look.fg : _green),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(action,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: live ? _green : Colors.white)),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: look.fg.withOpacity(0.6)),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
