import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../data/models/consultation/dietitian_availability.dart';
import 'booking_confirmed_screen.dart';

/// Full page "Book a session" screen (design v2).
///
/// Reused by:
///   • POPUP_BOOK_INITIAL_CONSULTATION   (kind = "initial")
///   • POPUP_BOOK_FOLLOWUP_CONSULTATION  (kind = "followup")
///   • Reschedule from the Diet tab card
///   • Talk to an expert card on the paid home
///
/// Same inputs and same booking logic as the old bottom sheet. Only the
/// look changed, plus an optional note that is saved on the appointment.
class BookConsultationSheet extends StatefulWidget {
  final String popupVariable;
  final int dietitianId;
  final String? dietitianName;
  final int userId;
  final int userPlanId;
  final String kind; // "initial" | "followup"
  final int? rescheduleAppointmentId;

  const BookConsultationSheet({
    Key? key,
    required this.popupVariable,
    required this.dietitianId,
    required this.userId,
    required this.userPlanId,
    required this.kind,
    this.dietitianName,
    this.rescheduleAppointmentId,
  }) : super(key: key);

  static Future<void> show({
    required String popupVariable,
    required int dietitianId,
    String? dietitianName,
    required int userId,
    required int userPlanId,
    required String kind,
    int? rescheduleAppointmentId,
  }) async {
    await Get.to<dynamic>(
      () => BookConsultationSheet(
        popupVariable: popupVariable,
        dietitianId: dietitianId,
        dietitianName: dietitianName,
        userId: userId,
        userPlanId: userPlanId,
        kind: kind,
        rescheduleAppointmentId: rescheduleAppointmentId,
      ),
      transition: Transition.downToUp,
    );
  }

  @override
  State<BookConsultationSheet> createState() => _BookConsultationSheetState();
}

// ── Colours ────────────────────────────────────────────────────────────
const _bg = Color(0xFFF8F6F0);
const _ink = Color(0xFF163220);
const _muted = Color(0xFF8A968C);
const _line = Color(0xFFE9E5DA);
const _dark = Color(0xFF123B2A);
const _green = Color(0xFF3F9B5F);
const _mint = Color(0xFFEAF6EE);
const _mintBorder = Color(0xFF9FD3B0);
const _peach = Color(0xFFFDE9DC);
const _peachInk = Color(0xFF9A4A1E);
const _chip = Color(0xFFEFECE4);
const _confirm = Color(0xFF6DC55A);

TextStyle _t(double size, FontWeight w, Color c) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c);

class _BookConsultationSheetState extends State<BookConsultationSheet> {
  ConsultationController? _ctrl;
  String? _initError;
  bool _loading = true;
  bool _booking = false;
  bool _booked = false;

  /// Bookable slots grouped by date (YYYY-MM-DD), sorted by time.
  final Map<String, List<DietitianAvailabilitySlot>> _byDate = {};
  List<DateTime> _days = [];
  int _weekStart = 0; // index into _days of the first visible day
  String? _day; // selected date
  DietitianAvailabilitySlot? _selected;
  DietitianAvailabilitySlot? _soonest;
  bool _failed = false;
  String? _fetchedName; // from the availability call

  /// Name passed by the caller, else the assigned dietitian's name from the server.
  String? get _dn {
    final w = widget.dietitianName?.trim() ?? '';
    return w.isNotEmpty ? w : _fetchedName;
  }

  final _note = TextEditingController();
  static const _noteChips = ['Meal plan', 'Healthy snacks', 'Eating out'];

  String get _name {
    final n = _dn?.trim() ?? '';
    return n.isEmpty ? 'Your nutritionist' : n;
  }

  String get _firstName {
    final n = _dn?.trim() ?? '';
    return n.isEmpty ? 'your nutritionist' : n.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    try {
      _ctrl = Get.find<ConsultationController>();
    } catch (e) {
      _initError = 'Could not load this page. Please close and try again.';
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Minutes after midnight for "13:30", "13:30:00" or "1:30 PM".
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

  static String _label(String? raw) {
    final mins = _minutes(raw);
    if (mins == null) return raw ?? '';
    final h24 = mins ~/ 60;
    final m = mins % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _load() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 20));
    final data = await ctrl.loadAvailability(
      dietitianId: widget.dietitianId,
      from: _iso(start),
      to: _iso(end),
    );
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    _fetchedName = data.dietitianName;
    final nowMins = today.hour * 60 + today.minute;
    final todayIso = _iso(start);
    _byDate.clear();
    for (final s in data.slots) {
      if (!s.available) continue;
      if (s.date == todayIso) {
        final m = _minutes(s.start);
        // Hide times that have already passed today (15 min buffer).
        if (m != null && m <= nowMins + 15) continue;
      }
      _byDate.putIfAbsent(s.date, () => []).add(s);
    }
    for (final list in _byDate.values) {
      list.sort((a, b) =>
          (_minutes(a.start) ?? 0).compareTo(_minutes(b.start) ?? 0));
    }

    _days = List.generate(21, (i) => start.add(Duration(days: i)));

    String? firstDay;
    for (final d in _days) {
      if (_byDate.containsKey(_iso(d))) {
        firstDay = _iso(d);
        break;
      }
    }
    _soonest = firstDay == null ? null : _byDate[firstDay]!.first;

    setState(() {
      _loading = false;
      _day = firstDay ?? todayIso;
      _selected = null;
      final idx = _days.indexWhere((d) => _iso(d) == _day);
      _weekStart = idx < 0 ? 0 : (idx ~/ 7) * 7;
    });
  }

  Future<void> _book() async {
    final ctrl = _ctrl;
    final s = _selected;
    if (s == null || ctrl == null || _booking) return;
    setState(() => _booking = true);
    final outcome = await ctrl.bookConsultation(
      date: s.date,
      userId: widget.userId,
      dietitianId: widget.dietitianId,
      timeSlotId: s.slotDietId ?? 0,
      userPlanId: widget.userPlanId,
      kind: widget.kind,
      note: _note.text,
    );
    final ok = outcome.ok;
    // Backend updates an existing active booking with the same dietitian
    // in place. Only a different id means an old row is left to cancel.
    if (ok &&
        widget.rescheduleAppointmentId != null &&
        outcome.appointmentId != widget.rescheduleAppointmentId) {
      await ctrl.cancelAppointment(widget.rescheduleAppointmentId!);
    }
    if (!mounted) return;
    setState(() => _booking = false);
    if (ok) {
      _booked = true;
      await ctrl.completePopup(widget.popupVariable, metadata: {
        'date': s.date,
        'slotDietId': s.slotDietId,
      });
      final day = DateTime.tryParse(s.date) ?? DateTime.now();
      final mins = _minutes(s.start) ?? 0;
      Get.off<dynamic>(
        () => BookingConfirmedScreen(
          appointmentId: outcome.appointmentId ?? widget.rescheduleAppointmentId,
          dietitianId: widget.dietitianId,
          dietitianName: _dn,
          userId: widget.userId,
          userPlanId: widget.userPlanId,
          kind: widget.kind,
          start: DateTime(day.year, day.month, day.day, mins ~/ 60, mins % 60),
          timeLabel: _label(s.start),
          note: _note.text,
          wasReschedule: widget.rescheduleAppointmentId != null,
        ),
        transition: Transition.fadeIn,
      );
    }
  }

  // PopScope below marks the popup dismissed when she leaves without booking.
  void _close() => Get.back<dynamic>();

  // ── Helpers for text ─────────────────────────────────────────────────

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  String _niceDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1].substring(0, 3)}';
  }

  String _relDay(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return _niceDate(iso);
  }

  String _monthTitle(List<DateTime> week) {
    if (week.isEmpty) return '';
    final a = _mo[week.first.month - 1];
    final b = _mo[week.last.month - 1];
    return a == b ? a : '$a – $b';
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_booking,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_booked) _ctrl?.dismissPopup(widget.popupVariable);
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(child: _body()),
              if (!_loading && !_failed && _initError == null) _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = widget.rescheduleAppointmentId != null
        ? 'Reschedule session'
        : (widget.kind == 'followup' ? 'Book a follow-up' : 'Book a session');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          InkWell(
            onTap: _booking ? null : _close,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _line),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: _ink, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: _t(17, FontWeight.w700, _ink)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_initError != null) {
      return _message(_initError!, null);
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_confirm),
        ),
      );
    }
    if (_failed) {
      return _message("Couldn't load free times.", _load);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _expertCard(),
        const SizedBox(height: 14),
        if (_soonest != null) ...[
          _soonestCard(),
          const SizedBox(height: 18),
        ],
        _calendar(),
        const SizedBox(height: 18),
        _times(),
        const SizedBox(height: 20),
        _noteBox(),
      ],
    );
  }

  Widget _message(String text, VoidCallback? retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: _t(13, FontWeight.w500, _muted)),
            if (retry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: retry,
                child: Text('Try again', style: _t(13, FontWeight.w600, _green)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expertCard() {
    final letter = (_dn?.trim().isNotEmpty ?? false)
        ? _dn!.trim()[0].toUpperCase()
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _peach,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFBD9C4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            alignment: Alignment.center,
            child: letter != null
                ? Text(letter, style: _t(22, FontWeight.w700, _peachInk))
                : const Icon(Icons.person_rounded, color: _peachInk, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(18, FontWeight.w700, _ink)),
                Text('Nutritionist',
                    style: _t(12, FontWeight.w600, _peachInk)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined, size: 14, color: _ink),
                    const SizedBox(width: 4),
                    Text('30 min · video call',
                        style: _t(11, FontWeight.w500, _ink)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soonestCard() {
    final s = _soonest!;
    final who = (_dn?.trim().isNotEmpty ?? false)
        ? ' with $_firstName'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _mintBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SOONEST SLOT',
                    style: _t(9.5, FontWeight.w700, _green)
                        .copyWith(letterSpacing: 0.6)),
                Text('${_relDay(s.date)}, ${_label(s.start)}$who',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(13, FontWeight.w600, _ink)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pick(s),
            child: Text('Pick', style: _t(13, FontWeight.w700, _green)),
          ),
        ],
      ),
    );
  }

  void _pick(DietitianAvailabilitySlot s) {
    final idx = _days.indexWhere((d) => _iso(d) == s.date);
    setState(() {
      _day = s.date;
      _selected = s;
      if (idx >= 0) _weekStart = (idx ~/ 7) * 7;
    });
  }

  Widget _calendar() {
    final end = (_weekStart + 7).clamp(0, _days.length);
    final week = _days.sublist(_weekStart, end);
    final canBack = _weekStart > 0;
    final canNext = _weekStart + 7 < _days.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_monthTitle(week),
                  style: _t(15, FontWeight.w700, _ink)),
            ),
            _arrow(Icons.chevron_left_rounded, canBack,
                () => setState(() => _weekStart -= 7)),
            const SizedBox(width: 8),
            _arrow(Icons.chevron_right_rounded, canNext,
                () => setState(() => _weekStart += 7)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < week.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _dayTile(week[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, bool on, VoidCallback tap) {
    return InkWell(
      onTap: on ? tap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _line),
        ),
        child: Icon(icon, size: 20, color: on ? _ink : _line),
      ),
    );
  }

  Widget _dayTile(DateTime d) {
    final iso = _iso(d);
    final has = _byDate.containsKey(iso);
    final sel = iso == _day;
    final fg = sel ? Colors.white : (has ? _ink : const Color(0xFFBFC4BC));
    return GestureDetector(
      onTap: has
          ? () => setState(() {
                _day = iso;
                if (_selected?.date != iso) _selected = null;
              })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _dark : (has ? Colors.white : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(_wd[d.weekday - 1],
                style: _t(10, FontWeight.w500,
                    sel ? Colors.white70 : fg)),
            const SizedBox(height: 2),
            Text('${d.day}', style: _t(16, FontWeight.w700, fg)),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: has
                    ? (sel ? _confirm : _green)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _times() {
    final list = _day == null ? null : _byDate[_day!];
    if (list == null || list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Text(
          _byDate.isEmpty
              ? 'No free times in the next 3 weeks. Please check back soon.'
              : 'No free times on this day. Pick a day with a green dot.',
          style: _t(12, FontWeight.w500, _muted),
        ),
      );
    }
    final dayName = _wd[DateTime.parse(_day!).weekday - 1];
    final count = list.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count ${count == 1 ? 'time' : 'times'} free on $dayName',
            style: _t(15, FontWeight.w700, _ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in list) _timeChip(s)],
        ),
      ],
    );
  }

  Widget _timeChip(DietitianAvailabilitySlot s) {
    final sel = identical(s, _selected);
    final mins = _minutes(s.start) ?? 0;
    final icon = mins >= 18 * 60
        ? Icons.nightlight_outlined
        : Icons.wb_sunny_outlined;
    return GestureDetector(
      onTap: () => setState(() => _selected = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _dark : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _dark : _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: sel ? Colors.white : _ink),
            const SizedBox(width: 6),
            Text(_label(s.start),
                style: _t(13, FontWeight.w600, sel ? Colors.white : _ink)),
          ],
        ),
      ),
    );
  }

  Widget _noteBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anything $_firstName should know?',
            style: _t(15, FontWeight.w700, _ink)),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: 250,
          style: _t(13, FontWeight.w400, _ink),
          decoration: InputDecoration(
            hintText: 'e.g. I want a simple meal plan I can cook at home',
            hintStyle: _t(12.5, FontWeight.w400, _muted),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8EDD4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _green),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _noteChips)
              GestureDetector(
                onTap: () => _addChip(c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _chip,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(c, style: _t(11.5, FontWeight.w500, _ink)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _addChip(String c) {
    final cur = _note.text.trim();
    if (cur.toLowerCase().contains(c.toLowerCase())) return;
    final next = cur.isEmpty ? c : '$cur, $c';
    _note.text = next.length > 250 ? next.substring(0, 250) : next;
    _note.selection = TextSelection.collapsed(offset: _note.text.length);
    setState(() {});
  }

  Widget _bottomBar() {
    final s = _selected;
    final dayIso = s?.date ?? _day;
    final d = dayIso == null ? null : DateTime.tryParse(dayIso);
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(d == null ? '' : _wd[d.weekday - 1].toUpperCase(),
                    style: _t(9, FontWeight.w700, _green)),
                Text(d == null ? '' : '${d.day}',
                    style: _t(16, FontWeight.w700, _ink)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s == null ? 'Pick a time' : _label(s.start),
                    style: _t(14, FontWeight.w700, _ink)),
                Text(
                  s == null
                      ? 'Choose a time above'
                      : '${_niceDate(s.date)} · 30 min',
                  style: _t(11, FontWeight.w500, _muted),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: s == null || _booking ? null : _book,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _confirm,
                disabledBackgroundColor: const Color(0xFFB5DEC2),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _booking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Confirm',
                      style: _t(14, FontWeight.w700, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
