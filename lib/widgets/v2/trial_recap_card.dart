import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/free_trail/trial_summary_screen.dart';
import '../../data/controllers/home_controller/home_controller.dart';

/// "Last day of your free trial 🌱" recap on home (Oct 2026).
///
/// Shows what she did on each trial day, from GET /trial/summary?peek=1
/// (peek: reading it here does not start the offer countdown). The days
/// are the server's calendar days, numbered like her starter meal plan,
/// and there are always as many as the admin's trial length.
///
/// Shows only for trial women who haven't upgraded, on their last trial
/// day and after the trial ended. Otherwise shows [fallback] (or nothing).
class TrialRecapCard extends StatefulWidget {
  final Widget? fallback;
  final EdgeInsetsGeometry padding;

  const TrialRecapCard({
    super.key,
    this.fallback,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });

  @override
  State<TrialRecapCard> createState() => _TrialRecapCardState();
}

class _TrialRecapCardState extends State<TrialRecapCard> {
  static const _dark = Color(0xFF163D22);
  static const _dark2 = Color(0xFF21502C);
  static const _green = Color(0xFF6DC55A);

  Map<String, dynamic>? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Get.isRegistered<HomeController>()) {
      setState(() => _loaded = true);
      return;
    }
    final d = await Get.find<HomeController>().loadTrialSummary(peek: true);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loaded = true;
    });
  }

  List<Map<String, dynamic>> get _days {
    final raw = _data?['days'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool get _show {
    final d = _data;
    if (d == null || d['converted'] == true) return false;
    final days = _days;
    if (days.isEmpty) return false;
    // Last calendar trial day is today (or already past), or trial ended.
    return d['ended'] == true || days.last['isFuture'] != true;
  }

  static int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_show) return widget.fallback ?? const SizedBox.shrink();
    final days = _days;
    final n = days.length;
    final ended = _data?['ended'] == true;
    return Padding(
      padding: widget.padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_dark2, _dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ended ? 'Your free trial has ended 🌱' : 'Last day of your free trial 🌱',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Look what you did in $n day${n == 1 ? '' : 's'}. Your plan and progress are saved.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                height: 1.45,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            _tiles(days),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _button(
                    'See my $n day${n == 1 ? '' : 's'}',
                    filled: false,
                    onTap: () => Get.to(() => const TrialSummaryScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _button(
                    'Keep going',
                    filled: true,
                    onTap: () => Get.to(() => const TrialSummaryScreen(jumpToOffer: true)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiles(List<Map<String, dynamic>> days) {
    final tiles = [for (final d in days) _tile(d)];
    if (days.length <= 3) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
    }
    // Longer trials (admin can set up to 14 days): swipe through them.
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: 96, child: tiles[i]),
      ),
    );
  }

  /// One day: emojis for what she did, and a short line.
  Widget _tile(Map<String, dynamic> d) {
    final classes = _n(d['classes']);
    final meals = _n(d['meals']);
    final water = _n(d['waterMl']);
    final sleep = d['sleepHours'];
    final icons = <String>[
      if (classes > 0) '🏋️',
      if (meals > 0) '🍽️',
      if (water > 0) '💧',
      if (sleep != null) '🌙',
    ];
    final parts = <String>[
      if (classes == 1) 'Class',
      if (classes > 1) '$classes classes',
      if (meals > 0) '$meals meal${meals == 1 ? '' : 's'}',
    ];
    String line;
    if (parts.isNotEmpty) {
      line = parts.join(' + ');
    } else if (icons.isNotEmpty) {
      line = water > 0 ? 'Water logged' : 'Sleep logged';
    } else if (d['isFuture'] == true) {
      line = 'Coming up';
    } else if (d['isToday'] == true) {
      line = 'Still time today';
    } else {
      line = 'Rest day';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Day ${_n(d['day'])}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            icons.isEmpty ? '·' : icons.join(' '),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              height: 1.3,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String text, {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _green : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
