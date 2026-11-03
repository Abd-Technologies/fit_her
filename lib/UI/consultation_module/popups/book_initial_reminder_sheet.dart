import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../../data/models/consultation/dietitian_availability.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';

/// `POPUP_BOOK_INITIAL_REMINDER` — fires on every dashboard reload while
/// the user hasn't booked their initial consultation. "Remind me
/// tomorrow" explicitly snoozes it for a day (server-side); the plain
/// "x" close does NOT suppress it — it'll be back next reload.
/// dismissCount (bumped by the generic dismiss endpoint, if anything
/// still calls it) still trips a one-time BOOKING_REMINDER_5X staff
/// escalation at 5, but that no longer stops the popup from resurfacing.
///
/// "Pick a time" deliberately does NOT call completePopup — it only
/// navigates to the booking flow. Tapping the button isn't "done", an
/// actual booked Appointment is; helper/popupEligibility.js's
/// evalBookInitialReminder retires this popup server-side once a real
/// Appointment exists. Completing it here on tap used to retire the
/// active row on the spot, and the very next dashboard evaluate pass
/// just created a brand new eligible one — the popup reappeared
/// instantly after every tap, in a tight complete → recreate loop.
///
/// Layout: dietitian avatar + "Your dietitian is waiting" eyebrow +
/// title + own close button, a short explainer, a 3-up "what to expect"
/// card, the dietitian's next free slot, then the two actions. The
/// dietitian's initial and the next free slot are loaded live from the
/// same availability endpoint BookConsultationSheet uses; if either
/// can't be loaded the sheet still works, it just hides that detail.
class BookInitialReminderSheet extends StatefulWidget {
  static const String variable = 'POPUP_BOOK_INITIAL_REMINDER';

  /// Opens the actual booking sheet (`BookConsultationSheet.show(...)`).
  /// Not imported here to keep file dependencies tight.
  final VoidCallback onBookNow;

  const BookInitialReminderSheet({Key? key, required this.onBookNow})
      : super(key: key);

  static Future<void> show({required VoidCallback onBookNow}) {
    return V2BottomSheet.show(
      showHeader: false, // this sheet draws its own header + close
      child: BookInitialReminderSheet(onBookNow: onBookNow),
    );
  }

  @override
  State<BookInitialReminderSheet> createState() =>
      _BookInitialReminderSheetState();
}

class _BookInitialReminderSheetState extends State<BookInitialReminderSheet> {
  // App's existing V2 palette (same tokens as V2BottomSheet, V2 buttons
  // and the paid-home cards) — not new colours.
  static const Color _ink = Color(0xFF1A3A22); // V2 sheet title colour
  static const Color _body = Color(0xFF7A8C78); // V2 muted text
  static const Color _inkSoft = Color(0xFF7A8C78); // V2 muted text/icons
  static const Color _green = Color(0xFF6DC55A); // V2 brand green
  static const Color _slotBg = Color(0xFFEAF7E4); // V2 accent tint
  static const Color _cardBorder = Color(0xFFD8EDD4); // V2 card border
  static const Color _avatarBg = Color(0xFFE8F4E0); // V2 mint page bg
  static const Color _avatarInk = Color(0xFF1A3A22);
  static const Color _closeBg = Color(0xFFEAF7E4);

  String? _dietitianName;
  String? _nextSlotLabel;
  bool _loadingSlot = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  // ── Data ──────────────────────────────────────────────────────────────

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Minutes after midnight for "13:30", "13:30:00" or "1:30 PM".
  /// Same parsing as BookConsultationSheet so both show the same slot.
  static int? _minutes(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?\s*$')
        .firstMatch(raw);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return h * 60 + min;
  }

  static String _time12(int mins) {
    final h24 = mins ~/ 60;
    final m = mins % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
  }

  static const List<String> _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dayLabel(DateTime day, DateTime today) {
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_wd[day.weekday - 1]} ${day.day} ${_mo[day.month - 1]}';
  }

  Future<void> _loadDetails() async {
    try {
      final dietCtrl = Get.find<DietPlanUserController>();
      await dietCtrl.loadBookingContext();
      final dietitianId = dietCtrl.bookingContext.value?.dietitianId;
      if (dietitianId == null) {
        if (mounted) setState(() => _loadingSlot = false);
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final data = await Get.find<ConsultationController>().loadAvailability(
        dietitianId: dietitianId,
        from: _iso(today),
        to: _iso(today.add(const Duration(days: 20))),
      );
      if (!mounted) return;
      if (data == null) {
        setState(() => _loadingSlot = false);
        return;
      }

      // Earliest bookable slot, skipping times that already passed
      // today (same 15-minute buffer BookConsultationSheet uses).
      final nowMins = now.hour * 60 + now.minute;
      final todayIso = _iso(today);
      DietitianAvailabilitySlot? best;
      int? bestMins;
      DateTime? bestDay;
      for (final s in data.slots) {
        if (!s.available) continue;
        final mins = _minutes(s.start);
        if (mins == null) continue;
        if (s.date == todayIso && mins <= nowMins + 15) continue;
        final day = DateTime.tryParse(s.date);
        if (day == null) continue;
        final d = DateTime(day.year, day.month, day.day);
        if (bestDay == null ||
            d.isBefore(bestDay) ||
            (d == bestDay && mins < bestMins!)) {
          best = s;
          bestMins = mins;
          bestDay = d;
        }
      }

      setState(() {
        _dietitianName = data.dietitianName;
        _nextSlotLabel = best == null
            ? null
            : '${_dayLabel(bestDay!, today)}, ${_time12(bestMins!)}';
        _loadingSlot = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSlot = false);
    }
  }

  String? get _firstName {
    final n = _dietitianName?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  String? get _initial {
    final n = _dietitianName?.trim();
    if (n == null || n.isEmpty) return null;
    return n.characters.first.toUpperCase();
  }

  // ── Actions ───────────────────────────────────────────────────────────

  void _pickTime() {
    // Do NOT completePopup here — see doc comment above. Just close and
    // hand off to the booking flow; the server retires this popup once
    // an Appointment actually exists.
    Get.back<dynamic>();
    widget.onBookNow();
  }

  void _remindTomorrow() {
    Get.find<ConsultationController>()
        .snoozePopup(BookInitialReminderSheet.variable, days: 1);
    Get.back<dynamic>();
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        const SizedBox(height: 18),
        const Text(
          "Your goals, your body, your food: let's build a plan that's truly yours.",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.6,
            color: _body,
          ),
        ),
        const SizedBox(height: 18),
        _expectCard(),
        if (_loadingSlot || _nextSlotLabel != null) ...[
          const SizedBox(height: 14),
          _slotRow(),
        ],
        const SizedBox(height: 18),
        // Existing V2 buttons, same as every other popup.
        V2PrimaryButton(label: 'Pick a time', onPressed: _pickTime),
        const SizedBox(height: 8),
        V2GhostButton(label: 'Remind me tomorrow', onPressed: _remindTomorrow),
      ],
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _avatarBg,
                  shape: BoxShape.circle,
                ),
                child: _initial != null
                    ? Text(
                        _initial!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _avatarInk,
                        ),
                      )
                    : const Icon(Icons.person_rounded,
                        size: 26, color: _avatarInk),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      size: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Her dietitian's first name once loaded; generic until then.
                  _firstName != null
                      ? '$_firstName is waiting for you'
                      : 'Your dietitian is waiting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Book your first consultation',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Get.back<dynamic>(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _closeBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: _inkSoft),
          ),
        ),
      ],
    );
  }

  Widget _expectCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ExpectItem(icon: Icons.schedule_rounded, label: 'About\n20 minutes')),
          Expanded(child: _ExpectItem(icon: Icons.videocam_outlined, label: 'Video call\nin the app')),
          Expanded(child: _ExpectItem(icon: Icons.restaurant_menu_rounded, label: 'Your own\nmeal plan')),
        ],
      ),
    );
  }

  Widget _slotRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _slotBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 17, color: _green),
          const SizedBox(width: 10),
          const Text(
            'Next free slot',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _inkSoft,
            ),
          ),
          const Spacer(),
          if (_loadingSlot)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
            )
          else
            Text(
              _nextSlotLabel ?? '',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpectItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ExpectItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7E4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF6DC55A)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: Color(0xFF1A3A22),
          ),
        ),
      ],
    );
  }
}
