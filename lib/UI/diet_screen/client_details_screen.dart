import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/client_consultation_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/generate_plan_screen.dart';
import 'package:fitness_zone_2/UI/diet_screen/dietitian_v2/user_plan_history_screen.dart';
import 'package:fitness_zone_2/data/controllers/diet_contoller/diet_controller.dart';
import 'package:fitness_zone_2/data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import 'package:fitness_zone_2/data/models/diet_appointments.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_bar_widget.dart';

// ── Shared v2 design tokens ─────────────────────────────────────────────
// Same palette as dietitian_home_screen.dart / clients_screen.dart /
// today_sessions_screen.dart.
const Color _kBg = Color(0xFFE8F4E0);
const Color _kInk = Color(0xFF163220);
const Color _kInkSoft = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kAccentBg = Color(0xFFEAF7E4);
const Color _kBorder = Color(0xFFD8EDD4);
const Color _kAlert = Color(0xFFE07B7B);

// Meal-log status colours. Validated as a set (adjacent pairs pass CVD +
// contrast on white); followed/skipped are also told apart by shape and
// icon (filled ✓ vs hollow ✕), never colour alone.
const Color _kFollowed = Color(0xFF3F9E3A);
const Color _kSwapped = Color(0xFF4C7BD9);
const Color _kSkipped = Color(0xFFD9605F);
const Color _kNotLogged = Color(0xFFEEF2EC);

/// The dietitian's client profile: who she is, her upcoming session
/// (join / complete / cancel), quick actions, and — new — how actively
/// she has logged her meals over the last 7 days (real data, replacing
/// the old placeholder chart and placeholder notes).
class ClientDetailsScreen extends StatelessWidget {
  ClientDetailsScreen({
    super.key,
    required this.clientUser,
    this.slotDiet,
    this.planId,
    this.appointmentId,
    this.status,
    this.appointmentDate,
  });

  final ClientUser clientUser;
  final SlotDiet? slotDiet;
  final int? planId;
  final int? appointmentId;
  final String? status;

  /// Day of the session this profile was opened from (optional — older
  /// call sites don't pass it, and the card then shows the time only).
  final DateTime? appointmentDate;

  String get _fullName =>
      '${clientUser.firstName} ${clientUser.lastName}'.trim();

  String get _initials {
    final parts = [clientUser.firstName.trim(), clientUser.lastName.trim()]
        .where((p) => p.isNotEmpty);
    final s = parts.map((p) => p.characters.first.toUpperCase()).join();
    return s.isEmpty ? '?' : s;
  }

  void _openForm() => Get.to(() => ClientConsultationScreen(
        userId: clientUser.id,
        clientName: _fullName,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: HelpingWidgets().appBarWidget(
        () => Get.back(),
        text: 'Client',
        backGroundColor: _kBg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _profileCard(),
          if (slotDiet != null || appointmentId != null) ...[
            const SizedBox(height: 12),
            _sessionCard(context),
          ],
          const SizedBox(height: 12),
          _actionsRow(),
          const SizedBox(height: 12),
          _MealActivityCard(userId: clientUser.id),
        ],
      ),
    );
  }

  // ── Who she is ───────────────────────────────────────────────────────
  Widget _profileCard() {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kAccentBg,
              shape: BoxShape.circle,
              border: Border.all(color: _kAccent.withOpacity(0.4), width: 1.5),
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName.isEmpty ? 'Client' : _fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clientUser.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: _kInkSoft,
                  ),
                ),
                if (clientUser.phone != null &&
                    clientUser.phone!.trim().isNotEmpty)
                  Text(
                    clientUser.phone!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: _kInkSoft,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Her session (only when opened from an appointment) ───────────────
  Widget _sessionCard(BuildContext context) {
    final dc = Get.find<DietController>();
    final time = slotDiet == null
        ? ''
        : '${slotDiet!.start ?? ''} – ${slotDiet!.end ?? ''}';
    String dayLabel = '';
    final d = appointmentDate;
    if (d != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
      dayLabel = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Tomorrow'
              : DateFormat('EEE, MMM d').format(d);
    }
    final when = [dayLabel, time].where((s) => s.trim().isNotEmpty).join(' · ');
    final isPending = status == 'pending';
    final isClosed = status == 'completed' ||
        status == 'canceled' ||
        status == 'canceledByUser';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available_outlined,
                    size: 19, color: _kAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consultation',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _kInk,
                      ),
                    ),
                    if (when.isNotEmpty)
                      Text(
                        when,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          color: _kInkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          if (!isClosed) ...[
            const SizedBox(height: 12),
            _PrimaryButton(
              icon: Icons.videocam_rounded,
              label: 'Join call',
              onTap: () => dc.openMeetLink(slotDiet?.dietitionLink),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isPending) ...[
                  Expanded(
                    child: _OutlineButton(
                      icon: Icons.check_circle_outline,
                      label: 'Confirm',
                      onTap: () => dc.updateAppointmentStatus(
                          appointmentId ?? 0, 'confirmed',
                          isFromAppointment: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.done_all_rounded,
                    label: 'Completed',
                    onTap: () => dc.updateAppointmentStatus(
                        appointmentId ?? 0, 'completed',
                        isFromAppointment: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    color: _kAlert,
                    onTap: () => _confirmCancel(context, dc),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, DietController dc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cancel this consultation?',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _kInk),
        ),
        content: const Text(
          "She'll be told it was cancelled and can book a new time.",
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kInkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it',
                style: TextStyle(fontFamily: 'Poppins', color: _kInk)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _kAlert,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      dc.updateAppointmentStatus(appointmentId ?? 0, 'canceled',
          isFromAppointment: true);
    }
  }

  // ── Generate Plan / Plan History / Health form ───────────────────────
  Widget _actionsRow() {
    return Row(
      children: [
        if (planId != null) ...[
          Expanded(
            child: _ActionTile(
              icon: Icons.auto_awesome,
              label: 'Generate plan',
              accent: true,
              onTap: () => Get.to(() => GeneratePlanScreen(
                    userId: clientUser.id,
                    userPlanId: planId!,
                    userDisplayName: _fullName,
                  )),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _ActionTile(
            icon: Icons.history_rounded,
            label: 'Plan history',
            onTap: () => Get.to(() => UserPlanHistoryScreen(
                  userId: clientUser.id,
                  userDisplayName: _fullName,
                )),
          ),
        ),
        const SizedBox(width: 10),
        // Her real health form, Day-7 reviews, progress and private notes
        // (replaces the old placeholder "Notes & history" block).
        Expanded(
          child: _ActionTile(
            icon: Icons.assignment_outlined,
            label: 'Health form\n& notes',
            onTap: _openForm,
          ),
        ),
      ],
    );
  }
}

// ─── Meal logging, last 7 days ──────────────────────────────────────────

class _MealActivityCard extends StatefulWidget {
  final int userId;
  const _MealActivityCard({required this.userId});

  @override
  State<_MealActivityCard> createState() => _MealActivityCardState();
}

class _MealActivityCardState extends State<_MealActivityCard> {
  List<Map<String, dynamic>>? _days;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    List<Map<String, dynamic>>? data;
    try {
      data = await Get.find<DietitianDashboardController>()
          .loadClientMealActivity(widget.userId);
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    setState(() {
      _days = data;
      _failed = data == null;
      _loading = false;
    });
  }

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Meal logging · last 7 days',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _kAccent),
                ),
              ),
            )
          else if (_failed)
            _message(
              "Couldn't load her meal logs.",
              action: TextButton(
                onPressed: _load,
                child: const Text('Try again',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: _kAccent,
                        fontWeight: FontWeight.w700)),
              ),
            )
          else
            ..._content(),
        ],
      ),
    );
  }

  Widget _message(String text, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, color: _kInkSoft),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  List<Widget> _content() {
    final days = _days ?? const [];
    final planned = days.fold<int>(0, (s, d) => s + _int(d['planned']));
    final followed = days.fold<int>(0, (s, d) => s + _int(d['followed']));
    final swapped = days.fold<int>(0, (s, d) => s + _int(d['alternative']));
    final skipped = days.fold<int>(0, (s, d) => s + _int(d['skipped']));
    final logged = followed + swapped + skipped;
    final activeDays = days.where((d) => _int(d['logged']) > 0).length;
    final planDays = days.where((d) => _int(d['planned']) > 0).length;

    if (planned == 0 && logged == 0) {
      return [
        _message(
            'No meal plan was active this week, so there is nothing to log yet. '
            'Logging starts once her plan is delivered.'),
      ];
    }

    final pct = planned == 0 ? null : (logged * 100 / planned).round().clamp(0, 100);
    final pctColor = pct == null
        ? _kInkSoft
        : pct >= 70
            ? _kFollowed
            : pct >= 40
                ? const Color(0xFFB7791F)
                : _kSkipped;

    return [
      // Headline: logged vs planned + rate.
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$logged',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 30,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 3),
            child: Text(
              planned > 0 ? 'of $planned meals logged' : 'meals logged',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: _kInkSoft),
            ),
          ),
          const Spacer(),
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: pctColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$pct%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        planDays > 0
            ? 'Logged on $activeDays of $planDays plan days'
            : 'Logged on $activeDays days',
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12, color: _kInkSoft),
      ),
      const SizedBox(height: 14),
      // One column per day, one dot per planned meal.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days) Expanded(child: _DayColumn(day: d)),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _LegendItem(kind: _DotKind.followed, label: 'Followed $followed'),
          _LegendItem(kind: _DotKind.swapped, label: 'Swapped $swapped'),
          _LegendItem(kind: _DotKind.skipped, label: 'Skipped $skipped'),
          const _LegendItem(kind: _DotKind.notLogged, label: 'Not logged'),
        ],
      ),
    ];
  }
}

enum _DotKind { followed, swapped, skipped, notLogged }

class _DayColumn extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayColumn({required this.day});

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${day['date']}');
    final now = DateTime.now();
    final isToday = date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final planned = _int(day['planned']);
    final f = _int(day['followed']);
    final a = _int(day['alternative']);
    final s = _int(day['skipped']);
    final logged = f + a + s;
    final slots = planned > logged ? planned : logged;

    final dots = <_DotKind>[
      for (var i = 0; i < f; i++) _DotKind.followed,
      for (var i = 0; i < a; i++) _DotKind.swapped,
      for (var i = 0; i < s; i++) _DotKind.skipped,
      for (var i = logged; i < slots; i++) _DotKind.notLogged,
    ];

    return Column(
      children: [
        Text(
          date == null ? '' : DateFormat('E').format(date).substring(0, 2),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? _kAccent : _kInkSoft,
          ),
        ),
        const SizedBox(height: 6),
        if (dots.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('–',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: _kInkSoft)),
          )
        else
          for (final k in dots)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _Dot(kind: k),
            ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final _DotKind kind;
  const _Dot({required this.kind});

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      _DotKind.followed => _circle(
          fill: _kFollowed, icon: Icons.check_rounded, iconColor: Colors.white),
      _DotKind.swapped => _circle(
          fill: _kSwapped,
          icon: Icons.swap_horiz_rounded,
          iconColor: Colors.white),
      _DotKind.skipped => _circle(
          fill: Colors.white,
          border: _kSkipped,
          icon: Icons.close_rounded,
          iconColor: _kSkipped),
      _DotKind.notLogged => _circle(fill: _kNotLogged, border: _kBorder),
    };
  }

  Widget _circle({
    required Color fill,
    Color? border,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
      child: icon == null ? null : Icon(icon, size: 11, color: iconColor),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _DotKind kind;
  final String label;
  const _LegendItem({required this.kind, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(kind: kind),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11.5, color: _kInk),
        ),
      ],
    );
  }
}

// ─── Local widgets ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kInk.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String? status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status ?? '';
    final isLive = s == 'In Progress';
    final isConfirmed = s == 'confirmed';
    final isDone = s == 'completed';
    final bg = isLive
        ? const Color(0xFFE24B4A).withOpacity(0.12)
        : (isConfirmed || isDone)
            ? _kAccent.withOpacity(0.16)
            : Colors.black.withOpacity(0.06);
    final fg = isLive
        ? const Color(0xFFE24B4A)
        : (isConfirmed || isDone)
            ? const Color(0xFF2F7A22)
            : _kInkSoft;
    final label = isLive
        ? '● LIVE'
        : s.isEmpty
            ? '—'
            : (s == 'canceledByUser' ? 'CANCELED' : s.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _kInk,
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
              color: color == _kInk ? _kBorder : color.withOpacity(0.45)),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: accent ? _kInk : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent ? _kInk : _kBorder),
          boxShadow: [
            BoxShadow(
              color: _kInk.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kAccent, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                height: 1.25,
                color: accent ? Colors.white : _kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
