import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';

/// Admin (Oct 2026): a dietitian's 3rd+ emergency day this month waits
/// here. Approve → her sessions that day are cancelled and clients told
/// (free days, rebook). Reject → sessions stay as booked, she is told.
class EmergencyDayRequestsScreen extends StatefulWidget {
  const EmergencyDayRequestsScreen({super.key});

  @override
  State<EmergencyDayRequestsScreen> createState() => _EmergencyDayRequestsScreenState();
}

class _EmergencyDayRequestsScreenState extends State<EmergencyDayRequestsScreen> {
  static const _ink = Color(0xFF1F2A1E);
  static const _muted = Color(0xFF66705F);
  static const _green = Color(0xFF4C6A4B);
  static const _red = Color(0xFFC24A4A);
  static const _border = Color(0xFFE3E8DF);

  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  final Set<int> _busy = {};

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  ApiProvider get _api => Get.find<ApiProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getData('/emergency-day/awaiting', headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map && b['data']['items'] is List) {
        _items = (b['data']['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (b is Map) {
        CustomToast.failToast(msg: '${b['message']}');
      }
    } catch (_) {
      CustomToast.failToast(msg: 'Could not load. Check your internet.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _decide(int id, bool approve) async {
    setState(() => _busy.add(id));
    try {
      final r = await _api.postData('/emergency-day/$id/decide',
          body: {'approve': approve}, headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        CustomToast.successToast(msg: '${b['message']}');
        await _load();
      } else {
        CustomToast.failToast(msg: b is Map ? '${b['message']}' : 'Could not save.');
      }
    } catch (_) {
      CustomToast.failToast(msg: 'Could not save. Check your internet.');
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: 1.45);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text('Emergency days', style: _t(17, w: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Text('A dietitian gets 2 emergency days a month on her own. Later ones wait here. '
                      'Approve: her sessions that day are cancelled, clients get free days and rebook. '
                      'Reject: sessions stay as booked.',
                      style: _t(12.5, c: _muted)),
                  const SizedBox(height: 14),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('Nothing waiting.', style: _t(14, c: _muted))),
                    ),
                  for (final it in _items) _card(it),
                ],
              ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> it) {
    final id = (it['id'] as num).toInt();
    final day = DateTime.tryParse('${it['day']}');
    final busy = _busy.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${it['dietitian']}', style: _t(15, w: FontWeight.w700)),
        Text(
          '${day != null ? DateFormat('EEE d MMM').format(day) : it['day']} · ${it['sessions']} session(s) · ${it['reason']}',
          style: _t(13),
        ),
        if ((it['note'] ?? '').toString().trim().isNotEmpty) Text('"${it['note']}"', style: _t(12.5, c: _muted)),
        Text('Emergency day ${it['monthCount']} this month', style: _t(12, c: _red, w: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => _decide(id, false),
              style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : () => _decide(id, true),
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Approve'),
            ),
          ),
        ]),
      ]),
    );
  }
}
