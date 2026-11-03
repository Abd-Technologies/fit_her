import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';

/// Phase 4 — admin metrics dashboard. Renders Section 15 fields from
/// `GET /admin/metrics/overview`. Pull-to-refresh re-fetches. Each
/// subobject is independently nullable; the UI renders an empty state
/// for each missing block rather than failing the whole screen.
class AdminMetricsScreen extends StatefulWidget {
  const AdminMetricsScreen({Key? key}) : super(key: key);

  @override
  State<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends State<AdminMetricsScreen> {
  late final DietitianDashboardController _ctrl;
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DietitianDashboardController>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _ctrl.loadMetricsOverview();
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A3A22)),
        title: const Text(
          'Metrics',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A3A22),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
              ),
            )
          : _data == null
              ? _ErrorState(onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFF6DC55A),
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ActiveUsersBlock(
                          map: _readMap('activeUsersByPlanType')),
                      const SizedBox(height: 12),
                      _ConsultationsBlock(
                          consultations: _readMap('consultations')),
                      const SizedBox(height: 12),
                      _PendingDeliveryBlock(
                          map: _readMap('plansPendingDelivery')),
                      const SizedBox(height: 12),
                      _ComplianceBlock(
                          dailyLog: _readMap('dailyLogComplianceToday'),
                          workout: _readMap('workoutAttendanceWeek')),
                      const SizedBox(height: 12),
                      _EscalationsBlock(
                          map: _readMap('escalationsByTrigger')),
                      const SizedBox(height: 12),
                      _SlaPerDietitianBlock(
                          list: _readList('slaBreachPerDietitian')),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Map<String, dynamic>? _readMap(String key) {
    final v = _data?[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  List<dynamic>? _readList(String key) {
    final v = _data?[key];
    return v is List ? v : null;
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load metrics.",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF7A8C78),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Blocks ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8C78),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  final String value;
  final String? caption;
  const _BigNumber({
    required this.value,
    this.caption,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A3A22),
            letterSpacing: -0.6,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Color(0xFF9AB09A),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveUsersBlock extends StatelessWidget {
  final Map<String, dynamic>? map;
  const _ActiveUsersBlock({required this.map});
  @override
  Widget build(BuildContext context) {
    if (map == null || map!.isEmpty) {
      return const _Card(title: 'Active users by plan', child: Text('—'));
    }
    final entries = map!.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return _Card(
      title: 'Active users by plan',
      child: Column(
        children: entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF1A3A22),
                          ),
                        ),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A3A22),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ConsultationsBlock extends StatelessWidget {
  final Map<String, dynamic>? consultations;
  const _ConsultationsBlock({required this.consultations});
  @override
  Widget build(BuildContext context) {
    final today = consultations?['today'] is Map
        ? Map<String, dynamic>.from(consultations!['today'] as Map)
        : null;
    final week = consultations?['thisWeek'] is Map
        ? Map<String, dynamic>.from(consultations!['thisWeek'] as Map)
        : null;
    return _Card(
      title: 'Consultations',
      child: Row(
        children: [
          Expanded(
            child: _MiniCounts(
              label: 'Today',
              counts: today,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniCounts(
              label: 'This week',
              counts: week,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCounts extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? counts;
  const _MiniCounts({required this.label, required this.counts});
  int _read(String k) {
    final v = counts?[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FDF2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8C78),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          _BigNumber(
            value: '${_read('booked')}',
            caption: 'booked',
          ),
          const SizedBox(height: 6),
          _StatLine(label: 'Completed', value: _read('completed')),
          _StatLine(label: 'In progress', value: _read('in_progress')),
          _StatLine(
            label: 'No-show',
            value: _read('no_show'),
            tone: _read('no_show') > 0 ? _LineTone.warn : _LineTone.muted,
          ),
          _StatLine(label: 'Cancelled', value: _read('cancelled')),
        ],
      ),
    );
  }
}

enum _LineTone { muted, warn }

class _StatLine extends StatelessWidget {
  final String label;
  final int value;
  final _LineTone tone;
  const _StatLine({
    required this.label,
    required this.value,
    this.tone = _LineTone.muted,
  });
  @override
  Widget build(BuildContext context) {
    final color = tone == _LineTone.warn
        ? const Color(0xFFE24B4A)
        : const Color(0xFF1A3A22);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Color(0xFF7A8C78),
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingDeliveryBlock extends StatelessWidget {
  final Map<String, dynamic>? map;
  const _PendingDeliveryBlock({required this.map});
  @override
  Widget build(BuildContext context) {
    final pending = map?['count'] is int ? map!['count'] as int : 0;
    final breach = map?['day3Breach'] is int ? map!['day3Breach'] as int : 0;
    return _Card(
      title: 'Plans pending delivery',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _BigNumber(value: '$pending', caption: 'awaiting PDF'),
          ),
          if (breach > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCDB8)),
              ),
              child: Text(
                '$breach past Day 3',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE24B4A),
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComplianceBlock extends StatelessWidget {
  final Map<String, dynamic>? dailyLog;
  final Map<String, dynamic>? workout;
  const _ComplianceBlock({required this.dailyLog, required this.workout});

  int _readPct(Map<String, dynamic>? m) {
    if (m == null) return 0;
    final v = m['ratePct'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final logPct = _readPct(dailyLog);
    final workoutPct = _readPct(workout);
    return Row(
      children: [
        Expanded(
          child: _Card(
            title: 'Daily log compliance',
            child: _BigNumber(
              value: '$logPct%',
              caption:
                  'today · ${dailyLog?['loggedToday'] ?? 0}/${dailyLog?['totalActive'] ?? 0}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Card(
            title: 'Workout attendance',
            child: _BigNumber(
              value: '$workoutPct%',
              caption:
                  'this week · ${workout?['attendedThisWeek'] ?? 0}/${workout?['totalActive'] ?? 0}',
            ),
          ),
        ),
      ],
    );
  }
}

class _EscalationsBlock extends StatelessWidget {
  final Map<String, dynamic>? map;
  const _EscalationsBlock({required this.map});

  static const _triggerLabels = {
    'PLAN_DELAYED': 'Plan delayed',
    'CONSULT_NO_SHOW': 'No-show',
    'INACTIVITY': 'Inactivity',
    'MEDICAL': 'Medical',
    'REVIEW_FLAG': 'Review flag',
    'BOOKING_REMINDER_5X': 'Booking 5×',
    'SYSTEM_ISSUE': 'System',
    'DIET_CHECKIN_HELP': 'Needs help (diet)',
  };

  @override
  Widget build(BuildContext context) {
    if (map == null || map!.isEmpty) {
      return const _Card(title: 'Escalations', child: Text('—'));
    }
    final rows = map!.entries.map((e) {
      final byStatus =
          e.value is Map ? Map<String, dynamic>.from(e.value as Map) : {};
      final open = byStatus['open'] is int ? byStatus['open'] as int : 0;
      final ack = byStatus['acknowledged'] is int
          ? byStatus['acknowledged'] as int
          : 0;
      final resolved = byStatus['resolved'] is int
          ? byStatus['resolved'] as int
          : 0;
      return MapEntry(e.key, [open, ack, resolved]);
    }).toList()
      ..sort((a, b) => b.value[0].compareTo(a.value[0]));

    return _Card(
      title: 'Escalations by trigger',
      child: Column(
        children: rows
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _triggerLabels[e.key] ?? e.key,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF1A3A22),
                          ),
                        ),
                      ),
                      _MiniBadge(label: '${e.value[0]} open',
                          tone: e.value[0] > 0 ? _LineTone.warn : _LineTone.muted),
                      const SizedBox(width: 4),
                      _MiniBadge(label: '${e.value[2]}', tone: _LineTone.muted),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final _LineTone tone;
  const _MiniBadge({required this.label, required this.tone});
  @override
  Widget build(BuildContext context) {
    final fg = tone == _LineTone.warn
        ? const Color(0xFFE24B4A)
        : const Color(0xFF7A8C78);
    final bg = tone == _LineTone.warn
        ? const Color(0xFFFFF1EE)
        : const Color(0xFFEEEEEE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
          color: fg,
        ),
      ),
    );
  }
}

class _SlaPerDietitianBlock extends StatelessWidget {
  final List<dynamic>? list;
  const _SlaPerDietitianBlock({required this.list});
  @override
  Widget build(BuildContext context) {
    if (list == null || list!.isEmpty) {
      return const _Card(
        title: 'SLA breaches per dietitian',
        child: Text('No open breaches'),
      );
    }
    final rows = list!
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList()
      ..sort((a, b) =>
          (b['openCount'] ?? 0).compareTo(a['openCount'] ?? 0));
    return _Card(
      title: 'SLA breaches per dietitian',
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r['dietitianName']?.toString() ??
                              '#${r['dietitianId']}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF1A3A22),
                          ),
                        ),
                      ),
                      Text(
                        '${r['openCount'] ?? 0}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE24B4A),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
