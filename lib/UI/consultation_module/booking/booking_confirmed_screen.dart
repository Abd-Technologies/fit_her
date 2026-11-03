import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../widgets/toasts.dart';
import 'book_consultation_sheet.dart';

/// "You're booked!" page shown right after a consultation is booked.
///
/// Bookings are confirmed automatically (the dietitian opened the slot,
/// so there's no "waiting for her to confirm" step). Reschedule stays
/// open until 24 hours before the session (backend bookingPolicy); we
/// re-check the live status before opening it.
class BookingConfirmedScreen extends StatefulWidget {
  final int? appointmentId;
  final int dietitianId;
  final String? dietitianName;
  final int userId;
  final int userPlanId;
  final String kind; // initial | followup
  final DateTime start; // local date and time of the call
  final String timeLabel; // e.g. 5:00 PM
  final String? note;
  final bool wasReschedule;
  // A live workout class at the same time (see helper/classClash.js).
  final Map<String, dynamic>? classClash;

  const BookingConfirmedScreen({
    Key? key,
    required this.appointmentId,
    required this.dietitianId,
    required this.userId,
    required this.userPlanId,
    required this.kind,
    required this.start,
    required this.timeLabel,
    this.dietitianName,
    this.note,
    this.wasReschedule = false,
    this.classClash,
  }) : super(key: key);

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

// App's existing V2 palette (same tokens as the other popups/screens).
const _bg = Color(0xFFE8F4E0); // V2 mint page bg
const _ink = Color(0xFF1A3A22); // V2 title/ink
const _muted = Color(0xFF7A8C78); // V2 muted text
const _green = Color(0xFF6DC55A); // V2 brand green
const _line = Color(0xFFD8EDD4); // V2 border
const _iconBg = Color(0xFFEAF7E4); // V2 accent tint
const _peach = Color(0xFFEAF7E4); // avatar: V2 accent tint (was peach)
const _peachInk = Color(0xFF1A3A22); // avatar letter: V2 ink

TextStyle _t(double size, FontWeight w, Color c) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c);

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> {
  bool _checking = false;

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  bool get _hasName => widget.dietitianName?.trim().isNotEmpty ?? false;
  String get _name =>
      _hasName ? widget.dietitianName!.trim() : 'Your nutritionist';
  bool get _within24h => DateTime.now()
      .isAfter(widget.start.subtract(const Duration(hours: 24)));

  String get _first {
    if (!_hasName) return 'Your nutritionist';
    final parts = widget.dietitianName!
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => !RegExp(r'^(dr|dr\.)$', caseSensitive: false).hasMatch(p))
        .toList();
    return parts.isEmpty ? widget.dietitianName!.trim() : parts.first;
  }

  String get _day {
    final d = widget.start;
    return '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';
  }

  String get _topic {
    final n = (widget.note ?? '').toLowerCase();
    for (final c in const ['Meal plan', 'Healthy snacks', 'Eating out']) {
      if (n.contains(c.toLowerCase())) return c;
    }
    return widget.kind == 'followup' ? 'Follow-up' : 'Diet plan';
  }

  void _home() => Get.until((route) => route.isFirst);

  Future<void> _addToCalendar() async {
    String f(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        'T${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}00';
    final end = widget.start.add(const Duration(minutes: 30));
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'FitHer consultation with $_name',
      'dates': '${f(widget.start)}/${f(end)}',
      'details': 'Video call in the FitHer app. Open the app a few minutes early and tap Join.',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) CustomToast.failToast(msg: 'Could not open your calendar.');
  }

  Future<void> _reschedule() async {
    if (_checking) return;
    ConsultationController ctrl;
    try {
      ctrl = Get.find<ConsultationController>();
    } catch (_) {
      return;
    }
    setState(() => _checking = true);
    await ctrl.loadUpcomingAppointment();
    if (!mounted) return;
    setState(() => _checking = false);
    final appt = ctrl.upcomingAppointment.value;
    final tooLate =
        DateTime.now().isAfter(widget.start.subtract(const Duration(hours: 24)));
    if (appt == null ||
        (appt.status != 'pending' && appt.status != 'confirmed') ||
        tooLate) {
      CustomToast.failToast(
          msg: "Your session is less than 24 hours away, so the time can't be changed.");
      return;
    }
    await Get.off<dynamic>(
      () => BookConsultationSheet(
        popupVariable: 'POPUP_RESCHEDULE_CONSULTATION',
        dietitianId: widget.dietitianId,
        dietitianName: widget.dietitianName,
        userId: widget.userId,
        userPlanId: widget.userPlanId,
        kind: widget.kind,
        rescheduleAppointmentId: appt.id,
      ),
      transition: Transition.downToUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                children: [
                  Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD8EDD4),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 34),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.wasReschedule ? 'Time changed!' : "You're booked!",
                    textAlign: TextAlign.center,
                    style: _t(22, FontWeight.w700, _ink),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$_first is looking forward to talking with you.',
                      textAlign: TextAlign.center,
                      style: _t(12.5, FontWeight.w400, _muted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailsCard(),
                  if (_clashNote() != null) ...[
                    const SizedBox(height: 12),
                    _clashNote()!,
                  ],
                  const SizedBox(height: 16),
                  _infoBox(),
                ],
              ),
            ),
            _bottom(),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    color: _peach, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: _hasName
                    ? Text(_name[0].toUpperCase(),
                        style: _t(16, FontWeight.w700, _peachInk))
                    : const Icon(Icons.person_rounded,
                        color: _peachInk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(14, FontWeight.w700, _ink)),
                    Text('Nutritionist',
                        style: _t(11, FontWeight.w400, _muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(Icons.calendar_today_outlined, 'Day', _day),
          _row(Icons.access_time_rounded, 'Time', '${widget.timeLabel} · 30 min'),
          _row(Icons.videocam_outlined, 'Where', 'Video call in the app'),
          _row(Icons.description_outlined, 'Topic', _topic, last: true),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _green),
          ),
          const SizedBox(width: 12),
          Text(label, style: _t(12, FontWeight.w400, _muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12.5, FontWeight.w700, _ink)),
          ),
        ],
      ),
    );
  }

  /// "A live class runs at the same time" note: information only, shown
  /// just when a workout class overlaps the consultation.
  Widget? _clashNote() {
    final c = widget.classClash;
    if (c == null || c['clashClass'] is! Map) return null;
    String text(dynamic m) {
      if (m is! Map) return '';
      final t = '${m['time'] ?? ''}'.trim();
      final ty = '${m['type'] ?? ''}'.trim();
      return '$t $ty'.trim();
    }
    final clash = c['clashClass'] as Map;
    final after = text(c['joinAfter']);
    final next = text(c['nextClass']);
    final parts = <String>[
      if (after.isNotEmpty) 'Join after your consultation · $after',
      if (next.isNotEmpty) 'Next class · $next',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D9A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏃‍♀️ A live class runs at the same time',
              style: _t(13, FontWeight.w700, const Color(0xFF8A5A06))),
          const SizedBox(height: 4),
          Text(
            '${(clash['type'] ?? 'A class').toString().trim().isEmpty ? 'A class' : clash['type']} '
            'is on at ${clash['time'] ?? ''} while you\'re with $_first. '
            '${parts.isEmpty ? 'You can catch a class tomorrow.' : 'No problem, you can still work out today:'}',
            style: _t(12.5, FontWeight.w400, const Color(0xFF5C4210)),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(parts.join('  ·  '),
                style: _t(12.5, FontWeight.w700, _ink)),
          ],
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // White on the mint page, like the details card above it.
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 18, color: Color(0xFF6DC55A)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: _t(11.5, FontWeight.w400, const Color(0xFF1A3A22)),
                children: _within24h
                    ? [
                        TextSpan(text: "You're all set with $_first. "),
                        TextSpan(
                          text: "This session is less than 24 hours away, so "
                              "the time can't be changed.",
                          style: _t(11.5, FontWeight.w700,
                              const Color(0xFF1A3A22)),
                        ),
                        const TextSpan(
                            text: ' Your Join button appears in the Diet tab.'),
                      ]
                    : [
                        TextSpan(
                            text: "You're all set with $_first. Need a different time? "),
                        TextSpan(
                          text: 'You can change it until 24 hours before.',
                          style: _t(11.5, FontWeight.w700,
                              const Color(0xFF1A3A22)),
                        ),
                        const TextSpan(
                            text: ' Your Join button appears in the Diet tab.'),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _home,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Back to home',
                  style: _t(14, FontWeight.w700, Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _outline(
                  icon: Icons.event_available_outlined,
                  label: 'Add to calendar',
                  color: _green,
                  onTap: _addToCalendar,
                ),
              ),
              if (widget.appointmentId != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _outline(
                    label: _checking ? 'Checking…' : 'Reschedule',
                    color: _ink,
                    onTap: _reschedule,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _outline({
    IconData? icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, FontWeight.w600, color)),
            ),
          ],
        ),
      ),
    );
  }
}
