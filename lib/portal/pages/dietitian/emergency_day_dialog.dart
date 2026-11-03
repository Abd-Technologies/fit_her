import 'dart:async';

import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Dietitian "Emergency: cancel my day" on the web portal (Oct 2026).
/// Same calls and rules as the app's EmergencyDaySheet
/// (partner_backend/helper/emergencyDay.js): today or tomorrow,
/// not-started sessions only, 2 a month on her own (3rd → admin approval),
/// 2-minute undo before clients are told.
/// Returns true when something was cancelled, so the page can reload.
Future<bool> showEmergencyDayDialog(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _EmergencyDayDialog(),
  );
  return r ?? false;
}

class _EmergencyDayDialog extends StatefulWidget {
  const _EmergencyDayDialog();

  @override
  State<_EmergencyDayDialog> createState() => _EmergencyDayDialogState();
}

class _EmergencyDayDialogState extends State<_EmergencyDayDialog> {
  static const _reasons = <String, String>{
    'sick': 'Sick',
    'family': 'Family emergency',
    'tech': 'Internet / power problem',
    'other': 'Other',
  };

  String _day = 'today';
  String? _reason;
  final _note = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  Map<String, dynamic>? _preview;
  String? _error;

  int? _requestId;
  DateTime? _applyAt;
  Timer? _tick;
  bool _done = false;
  String? _doneText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get('/emergency-day/preview', query: {'day': _day});
    if (PortalApi.ok(b) && b['data'] is Map) {
      _preview = Map<String, dynamic>.from(b['data'] as Map);
    } else {
      _preview = null;
      _error = PortalApi.msg(b, "Couldn't load.");
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _sessions => ((_preview?['sessions'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  bool get _needsApproval => _preview?['needsApproval'] == true;
  Map? get _existing => _preview?['existing'] is Map ? _preview!['existing'] as Map : null;

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);
    final b = await PortalApi.post('/emergency-day', {'day': _day, 'reason': _reason, 'note': _note.text.trim()});
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      final req = b['data'] is Map ? (b['data'] as Map)['request'] : null;
      if (req is Map && req['status'] == 'scheduled') {
        _requestId = req['id'] is num ? (req['id'] as num).toInt() : null;
        _applyAt = DateTime.tryParse('${req['applyAt']}')?.toLocal() ?? DateTime.now().add(const Duration(minutes: 2));
        _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      } else {
        _done = true;
        _doneText = PortalApi.msg(b, 'Sent to the admin.');
      }
    } else {
      portalToast("Couldn't send", sub: PortalApi.msg(b), error: true);
    }
    setState(() => _sending = false);
  }

  void _onTick() {
    if (!mounted) return;
    if (_applyAt != null && !DateTime.now().isBefore(_applyAt!)) {
      _tick?.cancel();
      _done = true;
      _doneText = 'Done. Your sessions are cancelled and your clients are being told. Take care.';
    }
    setState(() {});
  }

  Future<void> _undo() async {
    if (_requestId == null) return;
    final b = await PortalApi.post('/emergency-day/$_requestId/undo', <String, dynamic>{});
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      _tick?.cancel();
      portalToast(PortalApi.msg(b, 'Undone. Nothing was cancelled.'));
      Navigator.of(context).pop(false);
    } else {
      portalToast("Couldn't undo", sub: PortalApi.msg(b), error: true);
    }
  }

  Widget _box(String text, {bool red = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (red ? PT.red : PT.amber).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: PT.t(12.5, w: FontWeight.w500, c: red ? PT.red : PT.amber, h: 1.45)),
      );

  String _s(int n) => '$n session${n == 1 ? '' : 's'}';

  Widget _body() {
    if (_done) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(_doneText ?? '', style: PT.t(14, h: 1.5)),
        const SizedBox(height: 16),
        ElevatedButton(style: portalPrimary(), onPressed: () => Navigator.of(context).pop(true), child: const Text('OK')),
      ]);
    }
    if (_applyAt != null) {
      final left = _applyAt!.difference(DateTime.now());
      final s = left.isNegative ? 0 : left.inSeconds;
      final mmss = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Cancelling ${_s(_sessions.length)} in $mmss', style: PT.t(16, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text("Your clients aren't told yet. Click Undo if this was a mistake.", style: PT.t(13, c: PT.sage, h: 1.45)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _undo, child: const Text('Undo')),
      ]);
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    final list = _sessions;
    final times = list
        .map((e) => [e['time'], e['client']].where((v) => v != null && '$v'.isNotEmpty).join(' '))
        .where((e) => e.isNotEmpty)
        .join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        for (final d in const ['today', 'tomorrow']) ...[
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(d == 'today' ? 'Today' : 'Tomorrow', textAlign: TextAlign.center, style: PT.t(13, w: FontWeight.w600)),
              ),
              selected: _day == d,
              onSelected: (_) {
                if (_day == d) return;
                _day = d;
                _load();
              },
            ),
          ),
          if (d == 'today') const SizedBox(width: 10),
        ],
      ]),
      const SizedBox(height: 14),
      if (_error != null)
        _box(_error!, red: true)
      else if (_existing != null)
        _box(_existing!['status'] == 'awaiting_approval'
            ? "This day is already waiting for the admin's approval."
            : 'This day is already cancelled.')
      else if (list.isEmpty)
        _box('You have no sessions to cancel on this day.')
      else ...[
        Text('${_s(list.length)}: $times', style: PT.t(14.5, w: FontWeight.w700, h: 1.4)),
        const SizedBox(height: 4),
        Text("Sessions you've already started aren't touched. Each client gets 3 free days "
            '(1 day if her session is more than 24 hours away) and is asked to book a new time with you.',
            style: PT.t(12, c: PT.sage, h: 1.45)),
        if (_needsApproval) ...[
          const SizedBox(height: 10),
          _box("You've used your ${_preview?['freePerMonth'] ?? 2} emergency days this month. "
              "This one goes to the admin for approval first; your clients aren't told until then."),
        ],
        const SizedBox(height: 14),
        Text('Reason (only the admin sees it)', style: PT.t(13, w: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _reasons.entries)
            ChoiceChip(
              label: Text(e.value, style: PT.t(12.5)),
              selected: _reason == e.key,
              onSelected: (_) => setState(() => _reason = e.key),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 250,
          minLines: 1,
          maxLines: 3,
          style: PT.t(13),
          decoration: InputDecoration(
            hintText: 'Note for the admin (optional)',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: PT.red,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _sending || _reason == null ? null : _send,
          child: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_needsApproval ? 'Ask admin to cancel ${_s(list.length)}' : 'Cancel ${_s(list.length)}'),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final counting = _applyAt != null && !_done;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 10, 0),
      title: Row(children: [
        Expanded(child: Text('Emergency: cancel my day', style: PT.t(17, w: FontWeight.w700))),
        // No close while the 2-minute undo is running: Undo or wait.
        if (!counting)
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(_done),
            icon: const Icon(Icons.close_rounded),
          ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, minWidth: 360),
        child: SingleChildScrollView(child: _body()),
      ),
    );
  }
}
