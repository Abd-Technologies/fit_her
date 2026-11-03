import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/dashboard_module/bottom_bar_screen/workout_plans_of_user.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';

/// H-01 Coming Up row. Renders up to 3 phase-tinted tiles in a fixed
/// mint/coral/amber cycle (matches the HTML, NOT phase-driven).
/// When `comingUp` is empty, shows a single muted "No upcoming classes"
/// text in place of the tile row.
///
/// Ticks every 30 s via an internal timer so the "Starts in Xm" countdown
/// badge on today's slots stays accurate without a network call.
class PaidHeroComingUp extends StatefulWidget {
  final List<ComingUpClass> comingUp;
  // Frozen-plan awareness (architecture item #2), same reasoning as
  // PaidHeroLiveSection.isFrozen -- defaults to false so nothing changes
  // for any existing caller that doesn't pass it.
  final bool isFrozen;

  const PaidHeroComingUp({
    Key? key,
    required this.comingUp,
    this.isFrozen = false,
  }) : super(key: key);

  @override
  State<PaidHeroComingUp> createState() => _PaidHeroComingUpState();
}

class _PaidHeroComingUpState extends State<PaidHeroComingUp> {
  Timer? _clockTicker;

  // Fixed palette — H-01 defaults in `new screens/Home_All43_Variants.html`
  // line 133-137. Rotation is mint → coral → amber regardless of phase.
  static const List<_TilePalette> _palettes = [
    _TilePalette(Color(0xFFA8F0C0), 0.07, 0.12, 0.55), // mint
    _TilePalette(Color(0xFFFF8A8A), 0.06, 0.10, 0.60), // coral
    _TilePalette(Color(0xFFFAC775), 0.06, 0.10, 0.60), // amber
  ];

  @override
  void initState() {
    super.initState();
    // Tick every 30 s — local rebuild keeps the countdown accurate
    // without a network round-trip.
    _clockTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFrozen) {
      // Plan is paused. This used to also show "Classes are paused..."
      // text with its own "Unfreeze" link -- but PlanFrozenBanner (the
      // white card right below the hero) already says the plan is paused
      // and now carries its own Unfreeze action too, so having both was
      // saying the same thing twice back-to-back (Shaista flagged this
      // as redundant). This section now just quietly disappears; the
      // disabled "Join" pill up in PaidHeroLiveSection is enough of a
      // contextual signal on its own, and it also removes the leftover
      // empty space a short message block left in its place.
      return const SizedBox.shrink();
    }
    if (widget.comingUp.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
        child: Text(
          'No upcoming classes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
      );
    }

    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Row(
        children: [
          for (int i = 0; i < widget.comingUp.length; i++) ...[
            Expanded(
              child: _Tile(
                item: widget.comingUp[i],
                palette: _palettes[i % _palettes.length],
                now: now,
              ),
            ),
            if (i < widget.comingUp.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _TilePalette {
  final Color base;
  final double bgOpacity;
  final double borderOpacity;
  final double timeOpacity;
  const _TilePalette(
    this.base,
    this.bgOpacity,
    this.borderOpacity,
    this.timeOpacity,
  );
}

class _Tile extends StatelessWidget {
  final ComingUpClass item;
  final _TilePalette palette;
  final DateTime now;

  const _Tile({
    required this.item,
    required this.palette,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    // Nov 2026: today's class the trainer cancelled shows "Cancelled"
    // (it kept counting down "Starts in 5m"). Only today's: the slot row
    // is shared with next week, which is still on.
    final bool cancelledToday =
        (item.status ?? '').trim() == 'Cancelled' && (item.dayOffset ?? 0) == 0;
    final countdown = cancelledToday ? null : _minutesUntilStart(item, now);
    // Show "Starts in Xm" badge when within 20 min of today's class --
    // matches slot_ui_state.dart's _kSoonWindow so this tile and the
    // shared resolver never disagree on when "soon" starts.
    final bool showCountdown = countdown != null && countdown >= 0 && countdown <= 20;
    final displayStr = _resolveDisplay(item, now);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Same screen the bottom-nav dumbbell tab opens (WorkPlansOfUser,
      // see bottom_bar_screen.dart's _userItems -> _widgetOption wiring)
      // -- that's the full workout schedule with every class's details,
      // so tapping any one of these tiles just takes her straight there
      // instead of leaving them decorative. showBackButton: true because
      // this is a real push (Get.to), not a bottom-tab switch -- she
      // needs a way back to Home.
      onTap: () => Get.to(() => WorkPlansOfUser(showBackButton: true)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.base.withOpacity(palette.bgOpacity),
          border: Border.all(
            color: palette.base.withOpacity(palette.borderOpacity),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.classType ?? 'Class',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 4),
            if (cancelledToday) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07B7B).withOpacity(0.22),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFE07B7B).withOpacity(0.5), width: 1),
                ),
                child: const Text(
                  'Cancelled today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF2A7A7)),
                ),
              ),
            ] else if (showCountdown) ...[
              // "Starts in Xm" badge — amber pill matching the workout screen.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAC775).withOpacity(0.22),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFFAC775).withOpacity(0.45),
                    width: 1,
                  ),
                ),
                child: Text(
                  countdown == 0 ? 'Starts now' : 'Starts in ${countdown}m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFAC775),
                  ),
                ),
              ),
            ] else ...[
              Text(
                displayStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.base.withOpacity(palette.timeOpacity),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns minutes until start if the slot is today and in the future,
  /// null otherwise. Returns 0 when the class has just started (now >= start).
  static int? _minutesUntilStart(ComingUpClass item, DateTime now) {
    if (item.dayOffset != 0) return null; // only today
    final raw = (item.start ?? item.startTimeUtc ?? '').trim();
    if (raw.isEmpty) return null;
    final startDt = _parseWallClock(raw, now);
    if (startDt == null) return null;
    final diff = startDt.difference(now).inMinutes;
    if (diff < 0) return null; // already started — live section handles this
    return diff;
  }

  /// Parse a wall-clock string like "06:00 PM" or "18:00" into a DateTime
  /// on today's date. Returns null on parse failure.
  static DateTime? _parseWallClock(String raw, DateTime today) {
    try {
      final upper = raw.toUpperCase().trim();
      int hour, minute;
      if (upper.contains('AM') || upper.contains('PM')) {
        final isPm = upper.contains('PM');
        final timePart =
            upper.replaceAll('AM', '').replaceAll('PM', '').trim();
        final parts = timePart.split(':');
        hour = int.parse(parts[0]);
        minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        final parts = raw.split(':');
        hour = int.parse(parts[0]);
        minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      }
      return DateTime(today.year, today.month, today.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Pass-through display: shows whatever the admin entered for slot.start
  /// (e.g. "12:00 PM"). Same string the workout schedule renders — by
  /// design, the two surfaces always agree. When the slot is not on today's
  /// weekday, we suffix the abbreviated weekday name (e.g. "12:00 PM · Thu").
  /// No timezone math, no UTC parsing.
  static String _resolveDisplay(ComingUpClass item, DateTime now) {
    final raw = (item.start ?? item.startTimeUtc ?? '').trim();
    if (raw.isEmpty) return '—';
    final weekday = item.weekday;
    if (weekday == null || weekday.isEmpty) return raw;
    final todayName = DateFormat('EEEE').format(now);
    if (weekday == todayName) return raw;
    final short = weekday.length >= 3 ? weekday.substring(0, 3) : weekday;
    return '$raw · $short';
  }
}
