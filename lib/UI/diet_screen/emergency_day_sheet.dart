import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/diet_contoller/diet_controller.dart';
import '../../values/constants.dart';
import '../../widgets/toasts.dart';

/// Dietitian "Emergency: cancel my day" (Oct 2026).
/// Server rules in partner_backend/helper/emergencyDay.js: today or
/// tomorrow, not-started sessions only, 2 a month on her own (3rd → admin
/// approval), 2-minute undo before clients are told.
class EmergencyDaySheet extends StatefulWidget {
  const EmergencyDaySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmergencyDaySheet(),
    );
  }

  @override
  State<EmergencyDaySheet> createState() => _EmergencyDaySheetState();
}

class _EmergencyDaySheetState extends State<EmergencyDaySheet> {
  static const _ink = Color(0xFF1A3A22);
  static const _muted = Color(0xFF6F8B7A);
  static const _red = Color(0xFFC24A4A);
  static const _redWash = Color(0xFFFDECEC);
  static const _amber = Color(0xFF8A5A06);
  static const _amberWash = Color(0xFFFFF4E0);
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

  // After she confirms (2-minute undo window).
  int? _requestId;
  DateTime? _applyAt;
  Timer? _tick;
  bool _done = false;
  String? _doneText;

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  ApiProvider get _api => Get.find<ApiProvider>();

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
    try {
      final r = await _api.getData('/emergency-day/preview',
          query: {'day': _day}, headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map) {
        _preview = Map<String, dynamic>.from(b['data']);
      } else {
        _error = b is Map ? '${b['message']}' : 'Could not load.';
      }
    } catch (_) {
      _error = 'Could not load. Check your internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _sessions =>
      ((_preview?['sessions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  bool get _needsApproval => _preview?['needsApproval'] == true;
  Map? get _existing => _preview?['existing'] is Map ? _preview!['existing'] as Map : null;

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);
    try {
      final r = await _api.postData('/emergency-day',
          body: {'day': _day, 'reason': _reason, 'note': _note.text.trim()},
          headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        final req = b['data'] is Map ? b['data']['request'] : null;
        if (req is Map && req['status'] == 'scheduled') {
          _requestId = req['id'] is num ? (req['id'] as num).toInt() : null;
          _applyAt = DateTime.tryParse('${req['applyAt']}')?.toLocal() ??
              DateTime.now().add(const Duration(minutes: 2));
          _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
        } else {
          _done = true;
          _doneText = '${b['message']}';
        }
      } else {
        CustomToast.failToast(msg: b is Map ? '${b['message']}' : 'Could not send.');
      }
    } catch (_) {
      CustomToast.failToast(msg: 'Could not send. Check your internet.');
    }
    if (mounted) setState(() => _sending = false);
  }

  void _onTick() {
    if (!mounted) return;
    if (_applyAt != null && !DateTime.now().isBefore(_applyAt!)) {
      _tick?.cancel();
      _done = true;
      _doneText = 'Done. Your sessions are cancelled and your clients are being told. Take care.';
      if (Get.isRegistered<DietController>()) {
        Get.find<DietController>().getAppointmentsOfDiets();
      }
    }
    setState(() {});
  }

  Future<void> _undo() async {
    if (_requestId == null) return;
    try {
      final r = await _api.postData('/emergency-day/$_requestId/undo',
          body: {}, headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        _tick?.cancel();
        CustomToast.successToast(msg: '${b['message']}');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      CustomToast.failToast(msg: b is Map ? '${b['message']}' : 'Could not undo.');
    } catch (_) {
      CustomToast.failToast(msg: 'Could not undo. Check your internet.');
    }
  }

  TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: h);

  Widget _box(String text, {bool red = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: red ? _redWash : _amberWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: _t(12, w: FontWeight.w500, c: red ? _red : _amber, h: 1.45)),
      );

  Widget _body() {
    if (_done) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_doneText ?? '', style: _t(14, h: 1.5)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('OK', style: _t(14, w: FontWeight.w700, c: Colors.white)),
        ),
      ]);
    }
    if (_applyAt != null) {
      final left = _applyAt!.difference(DateTime.now());
      final s = left.isNegative ? 0 : left.inSeconds;
      final mmss = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Cancelling ${_sessions.length} session${_sessions.length == 1 ? '' : 's'} in $mmss',
            style: _t(16, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text("Your clients aren't told yet. Tap Undo if this was a mistake.", style: _t(13, c: _muted, h: 1.45)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _undo,
          style: OutlinedButton.styleFrom(
              foregroundColor: _ink, side: const BorderSide(color: _ink),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Undo', style: _t(14, w: FontWeight.w700)),
        ),
      ]);
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    final list = _sessions;
    final times = list.map((e) => '${e['time'] ?? ''}').where((e) => e.isNotEmpty).join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final d in const ['today', 'tomorrow']) ...[
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(d == 'today' ? 'Today' : 'Tomorrow', textAlign: TextAlign.center, style: _t(13, w: FontWeight.w600)),
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
      if (_error != null) _box(_error!, red: true)
      else if (_existing != null)
        _box(_existing!['status'] == 'awaiting_approval'
            ? 'This day is already waiting for the admin\'s approval.'
            : 'This day is already cancelled.')
      else if (list.isEmpty)
        _box('You have no sessions to cancel on this day.')
      else ...[
        Text('${list.length} session${list.length == 1 ? '' : 's'}: $times', style: _t(15, w: FontWeight.w700, h: 1.4)),
        const SizedBox(height: 4),
        Text("Sessions you've already started aren't touched. Each client gets 3 free days "
            '(1 day if her session is more than 24 hours away) and is asked to book a new time with you.',
            style: _t(12, c: _muted, h: 1.45)),
        if (_needsApproval) ...[
          const SizedBox(height: 10),
          _box("You've used your ${_preview?['freePerMonth'] ?? 2} emergency days this month. "
              "This one goes to the admin for approval first; your clients aren't told until then."),
        ],
        const SizedBox(height: 14),
        Text('Reason (only the admin sees it)', style: _t(13, w: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _reasons.entries)
            ChoiceChip(
              label: Text(e.value, style: _t(12.5)),
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
          style: _t(13),
          decoration: InputDecoration(
            hintText: 'Note for the admin (optional)',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _sending || _reason == null ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  _needsApproval
                      ? 'Ask admin to cancel ${list.length} session${list.length == 1 ? '' : 's'}'
                      : 'Cancel ${list.length} session${list.length == 1 ? '' : 's'}',
                  style: _t(14, w: FontWeight.w700, c: Colors.white)),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFDDE5DA), borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 14),
            Text('Emergency: cancel my day', style: _t(18, w: FontWeight.w800)),
            const SizedBox(height: 14),
            _body(),
          ]),
        ),
      ),
    );
  }
}
