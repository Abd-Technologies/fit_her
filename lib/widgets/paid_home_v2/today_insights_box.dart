import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/home_dashboard/home_dashboard_model.dart';
import 'next_up_glow.dart';
import 'paid_feel_selector.dart';
import 'paid_sleep_card.dart';
import 'paid_water_card.dart';

/// "Today's insights" box: feeling, water and sleep in one card.
///
/// Until all three are logged the inputs are open inside the box. Then it
/// folds into three small tiles (Mood / Water / Sleep). Tapping a tile
/// opens just that input; "Done", or a moment after she changes it, folds
/// it back. The count on the right shows what's still to do (water counts
/// until her goal is reached).
class TodayInsightsBox extends StatefulWidget {
  final HomeDashboardModel dashboard;

  /// Which input gets the soft "next up" glow while the box is open.
  final bool glowMood;
  final bool glowWater;
  final bool glowSleep;

  /// Key on the water + sleep row (used by the home auto scroll).
  final Key? waterSleepKey;

  const TodayInsightsBox({
    super.key,
    required this.dashboard,
    this.glowMood = false,
    this.glowWater = false,
    this.glowSleep = false,
    this.waterSleepKey,
  });

  @override
  State<TodayInsightsBox> createState() => _TodayInsightsBoxState();
}

enum _Open { none, mood, water, sleep }

class _TodayInsightsBoxState extends State<TodayInsightsBox> {
  static const _ink = Color(0xFF163220);
  static const _soft = Color(0xFF6F8B7A);
  static const _green = Color(0xFF4AA877);
  static const _amber = Color(0xFFC8893A);

  static const _moods = [
    ['😊', 'Great'],
    ['😴', 'Tired'],
    ['😣', 'Sore'],
    ['⚡', 'Energy'],
    ['😤', 'Stress'],
  ];

  _Open _open = _Open.none;
  Timer? _foldTimer;

  @override
  void didUpdateWidget(covariant TodayInsightsBox old) {
    super.didUpdateWidget(old);
    // She changed something in an opened tile: fold back shortly after.
    if (_open != _Open.none && _signature(old.dashboard) != _signature(widget.dashboard)) {
      _foldIn(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _foldTimer?.cancel();
    super.dispose();
  }

  String _signature(HomeDashboardModel d) =>
      '${d.todayCheckin?.moodLevel}|${d.hydration?.consumedMl}|${d.sleep?.hoursToday}';

  void _openTile(_Open which) {
    setState(() => _open = which);
    _foldIn(const Duration(seconds: 10));
  }

  void _foldIn(Duration after) {
    _foldTimer?.cancel();
    _foldTimer = Timer(after, () {
      if (mounted) setState(() => _open = _Open.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dashboard;
    final mood = d.todayCheckin?.moodLevel;
    final moodDone = mood != null && mood >= 1 && mood <= 5;
    final consumed = d.hydration?.consumedMl ?? 0;
    final target = d.hydration?.targetMl ?? 0;
    final waterStarted = consumed > 0;
    final waterGoal = target > 0 && consumed >= target;
    final hours = d.sleep?.hoursToday;
    final sleepDone = hours != null;
    final sleepTarget = d.sleep?.targetHours;

    final allLogged = moodDone && waterStarted && sleepDone;
    final toLog = (moodDone ? 0 : 1) + (waterGoal ? 0 : 1) + (sleepDone ? 0 : 1);

    Widget body;
    if (!allLogged) {
      body = _inputs(d);
    } else {
      switch (_open) {
        case _Open.none:
          body = _tiles(
            mood: mood!,
            consumed: consumed,
            target: target,
            waterGoal: waterGoal,
            hours: hours!,
            sleepTarget: sleepTarget,
          );
          break;
        case _Open.mood:
          body = _edit(PaidFeelSelector(dashboard: d, embedded: true));
          break;
        case _Open.water:
          body = _edit(IntrinsicHeight(
              child: PaidWaterCard(dashboard: d, embedded: true, alwaysShowButtons: true)));
          break;
        case _Open.sleep:
          body = _edit(IntrinsicHeight(
              child: PaidSleepCard(dashboard: d, embedded: true, alwaysShowButtons: true)));
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                "Today's insights",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Text(
                toLog == 0 ? 'All done ✓' : '$toLog to log',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: toLog == 0 ? _green : _amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey('${allLogged}_$_open'), child: body),
            ),
          ),
        ],
      ),
    );
  }

  /// All inputs open (before everything is logged).
  Widget _inputs(HomeDashboardModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NextUpGlow(
          active: widget.glowMood,
          color: const Color(0xFF6DC55A),
          child: PaidFeelSelector(dashboard: d, embedded: true),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          key: widget.waterSleepKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: NextUpGlow(
                  active: widget.glowWater,
                  color: const Color(0xFF5B9BD5),
                  child: PaidWaterCard(dashboard: d, embedded: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NextUpGlow(
                  active: widget.glowSleep,
                  color: const Color(0xFF6D6DC5),
                  child: PaidSleepCard(dashboard: d, embedded: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One input opened from a tile, with "Done" under it.
  Widget _edit(Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _foldIn(Duration.zero),
          child: const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 2),
            child: Center(
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Three small tiles once everything is logged.
  Widget _tiles({
    required int mood,
    required int consumed,
    required int target,
    required bool waterGoal,
    required double hours,
    required int? sleepTarget,
  }) {
    final m = _moods[mood - 1];
    final left = (target - consumed).clamp(0, 100000);
    final rested = sleepTarget == null || hours >= sleepTarget;
    String litres(int ml) => '${(ml / 1000).toStringAsFixed(1)} L';
    String h(double v) => v == v.roundToDouble() ? '${v.toInt()}h' : '${v.toStringAsFixed(1)}h';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              icon: m[0],
              iconBg: const Color(0xFFFDE8E3),
              label: 'Mood',
              value: m[1],
              sub: 'Logged today',
              subColor: _green,
              onTap: () => _openTile(_Open.mood),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              icon: '💧',
              iconBg: const Color(0xFFE3EEFA),
              label: 'Water',
              value: litres(consumed),
              sub: waterGoal ? 'Goal reached' : '${litres(left)} to go',
              subColor: waterGoal ? _green : _amber,
              todo: !waterGoal,
              onTap: () => _openTile(_Open.water),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              icon: '🌙',
              iconBg: const Color(0xFFECE8F8),
              label: 'Sleep',
              value: h(hours),
              sub: rested ? 'Well rested' : 'Try an early night',
              subColor: rested ? _green : _amber,
              onTap: () => _openTile(_Open.sleep),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final bool todo;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.onTap,
    this.todo = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
      decoration: BoxDecoration(
        color: todo ? const Color(0xFFFFF8EE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: todo ? null : Border.all(color: const Color(0xFFE3EFE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Text(icon, style: const TextStyle(fontSize: 10.5, height: 1.0)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF6F8B7A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163220),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w600, color: subColor),
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: todo ? CustomPaint(painter: _DashedBorder(), child: card) : card,
    );
  }
}

/// Soft amber dashed border for the "still to log" tile.
class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1C98E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
