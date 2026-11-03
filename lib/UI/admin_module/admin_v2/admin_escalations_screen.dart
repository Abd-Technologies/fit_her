import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import '../../../data/models/consultation/escalation_ticket.dart';
import '../../../widgets/toasts.dart';

/// Phase 4 — admin escalations queue. Filterable by status (open /
/// acknowledged / resolved) and trigger. Tap a tile to expand and see
/// the payload + Resolve button.
class AdminEscalationsScreen extends StatefulWidget {
  /// Same screen for admin (all tickets) and a dietitian (the server
  /// only returns tickets about her own clients); only the title differs.
  final String title;
  const AdminEscalationsScreen({Key? key, this.title = 'Escalations'})
      : super(key: key);

  @override
  State<AdminEscalationsScreen> createState() =>
      _AdminEscalationsScreenState();
}

class _AdminEscalationsScreenState extends State<AdminEscalationsScreen> {
  late final DietitianDashboardController _ctrl;
  bool _loading = true;
  List<EscalationTicket> _tickets = const [];

  String _statusFilter = 'open';
  String? _triggerFilter;

  static const _statusOptions = [
    ('open', 'Open'),
    ('acknowledged', 'Ack'),
    ('resolved', 'Resolved'),
  ];

  static const _triggerOptions = [
    (null, 'All'),
    ('PLAN_DELAYED', 'Plan delayed'),
    ('CONSULT_NO_SHOW', 'No-show'),
    ('CONSULT_CLIENT_NO_SHOW', 'Client missed'),
    ('INACTIVITY', 'Inactivity'),
    ('MEDICAL', 'Medical'),
    ('REVIEW_FLAG', 'Review flag'),
    ('BOOKING_REMINDER_5X', 'Booking 5×'),
    ('SYSTEM_ISSUE', 'System'),
    ('DIET_CHECKIN_HELP', 'Needs help (diet)'),
    ('DIETITIAN_EMERGENCY_DAY', 'Emergency day'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DietitianDashboardController>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _ctrl.loadEscalations(
      status: _statusFilter,
      trigger: _triggerFilter,
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      _tickets = list;
      _loading = false;
    });
  }

  Future<void> _resolve(EscalationTicket t) async {
    final note = await _promptResolutionNote();
    if (note == null) return; // cancelled
    final ok = await _ctrl.resolveEscalation(
      ticketId: t.id ?? 0,
      resolutionNote: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    if (ok) {
      CustomToast.successToast(msg: 'Resolved');
      _load();
    }
  }

  /// Booking-locked client (second missed session): unlock her booking
  /// and close the ticket in one step.
  Future<void> _unlock(EscalationTicket t) async {
    final planId = int.tryParse('${t.payload?['userPlanId'] ?? ''}');
    if (planId == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock booking?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'She will be able to book her own sessions again, and her one free '
          'late change on this package is given back.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unlock')),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await _ctrl.resetBookingPass(planId);
    if (!ok || !mounted) return;
    await _ctrl.resolveEscalation(
      ticketId: t.id ?? 0,
      resolutionNote: 'Booking unlocked.',
    );
    if (!mounted) return;
    CustomToast.successToast(msg: 'Booking unlocked');
    _load();
  }

  Future<String?> _promptResolutionNote() async {
    final ctrl = TextEditingController();
    final res = await Get.dialog<String?>(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Resolve ticket',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3A22),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Resolution note (optional)',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF9AB09A),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5FDF2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFC8DEC4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFC8DEC4)),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back<String?>(result: null),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF7A8C78)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Get.back<String?>(result: ctrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6DC55A),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Resolve',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A3A22)),
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A3A22),
          ),
        ),
      ),
      body: Column(
        children: [
          _Filters(
            statusFilter: _statusFilter,
            triggerFilter: _triggerFilter,
            onStatusChange: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            onTriggerChange: (v) {
              setState(() => _triggerFilter = v);
              _load();
            },
            statusOptions: _statusOptions,
            triggerOptions: _triggerOptions,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
                    ),
                  )
                : _tickets.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No tickets in this view.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF7A8C78),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF6DC55A),
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _tickets.length,
                          itemBuilder: (_, i) {
                            final t = _tickets[i];
                            final canUnlock = t.status != 'resolved' &&
                                t.trigger == 'CONSULT_CLIENT_NO_SHOW' &&
                                t.payload?['bookingLocked'] == true &&
                                t.payload?['userPlanId'] != null;
                            return _TicketTile(
                              ticket: t,
                              onResolve: t.status == 'resolved'
                                  ? null
                                  : () => _resolve(t),
                              onUnlock: canUnlock ? () => _unlock(t) : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String statusFilter;
  final String? triggerFilter;
  final ValueChanged<String> onStatusChange;
  final ValueChanged<String?> onTriggerChange;
  final List<(String, String)> statusOptions;
  final List<(String?, String)> triggerOptions;
  const _Filters({
    required this.statusFilter,
    required this.triggerFilter,
    required this.onStatusChange,
    required this.onTriggerChange,
    required this.statusOptions,
    required this.triggerOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: statusOptions.length,
              itemBuilder: (_, i) {
                final o = statusOptions[i];
                final on = statusFilter == o.$1;
                return _Pill(
                  label: o.$2,
                  selected: on,
                  onTap: () => onStatusChange(o.$1),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: triggerOptions.length,
              itemBuilder: (_, i) {
                final o = triggerOptions[i];
                final on = triggerFilter == o.$1;
                return _Pill(
                  label: o.$2,
                  selected: on,
                  tone: _Tone.subtle,
                  onTap: () => onTriggerChange(o.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { primary, subtle }

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _Tone tone;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone = _Tone.primary,
  });
  @override
  Widget build(BuildContext context) {
    final selBg = tone == _Tone.primary
        ? const Color(0xFF1A3A22)
        : const Color(0xFF6DC55A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selBg : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? selBg : const Color(0xFFC8DEC4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF1A3A22),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// Google Meet check for the session this ticket is about, so a
/// disputed no-show can be settled: who actually joined the call.
class _AttendanceBox extends StatelessWidget {
  final Map<String, dynamic> attendance;
  const _AttendanceBox({required this.attendance});

  String _who(String label, dynamic v) => v == true
      ? '$label joined'
      : v == false
          ? "$label didn't join"
          : '$label: unknown';

  @override
  Widget build(BuildContext context) {
    final checked = attendance['checked'] == true;
    final people = (attendance['participants'] is List)
        ? (attendance['participants'] as List)
            .whereType<Map>()
            .map((p) => '${p['name'] ?? '?'}')
            .toList()
        : <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attendance['source'] == 'google' ? 'Attendance · Google Meet' : 'Attendance',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3A22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            checked
                ? '${_who('Dietitian', attendance['dietitianJoined'])} · '
                    '${_who('Client', attendance['clientJoined'])}'
                : 'Not checked yet (no Meet link, or the check has not run).',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: Color(0xFF1A3A22),
            ),
          ),
          // Oct 2026: how it was decided (Google or app taps), with times.
          if ('${attendance['summary'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${attendance['summary']}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF3E8E36)),
            ),
          ],
          if (people.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'In the call: ${people.join(', ')}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Color(0xFF7A8C78),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final EscalationTicket ticket;
  final VoidCallback? onResolve;
  // Only for booking-locked clients: unlock booking + close ticket.
  final VoidCallback? onUnlock;
  const _TicketTile(
      {required this.ticket, required this.onResolve, this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final highSeverity = ticket.severity == 'high';
    final color = highSeverity
        ? const Color(0xFFE24B4A)
        : const Color(0xFF1A3A22);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: highSeverity
            ? Border.all(color: const Color(0xFFE24B4A), width: 1.5)
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.id ?? '?'} · ${ticket.trigger ?? '—'}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              _SeverityChip(severity: ticket.severity ?? 'medium'),
            ],
          ),
          subtitle: Text(
            'User #${ticket.userId ?? '?'}'
            '${ticket.dietitianId != null ? ' · Diet #${ticket.dietitianId}' : ''}'
            ' · ${ticket.status ?? 'open'}'
            '${ticket.openedAt != null ? ' · ${_shortTs(ticket.openedAt!)}' : ''}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Color(0xFF7A8C78),
            ),
          ),
          children: [
            if (ticket.payload != null && ticket.payload!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FDF2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _prettyJson(ticket.payload!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF1A3A22),
                    height: 1.4,
                  ),
                ),
              ),
            if (ticket.attendance != null) ...[
              const SizedBox(height: 8),
              _AttendanceBox(attendance: ticket.attendance!),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notified: ${ticket.notifiedDietitian ? 'D' : '—'}'
                    '/${ticket.notifiedAdmin ? 'A' : '—'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Color(0xFF9AB09A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (onUnlock != null) ...[
                  OutlinedButton(
                    onPressed: onUnlock,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A3A22),
                      side: const BorderSide(color: Color(0xFF6DC55A)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Unlock booking',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onResolve != null)
                  ElevatedButton(
                    onPressed: onResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6DC55A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Resolve',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (ticket.resolutionNote != null) ...[
              const SizedBox(height: 8),
              Text(
                'Resolution: ${ticket.resolutionNote}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF7A8C78),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _prettyJson(Map<String, dynamic> m) {
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  static String _shortTs(DateTime dt) {
    final local = dt.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.hour}:$mm';
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});
  @override
  Widget build(BuildContext context) {
    final palette = switch (severity) {
      'high' => (const Color(0xFFFFF1EE), const Color(0xFFE24B4A)),
      'low' => (const Color(0xFFEEEEEE), const Color(0xFF7A8C78)),
      _ => (const Color(0xFFFDEFD0), const Color(0xFF8A6515)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: palette.$2,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
