import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin: app update rules per platform (see fitHer Flows › App update).
///   Latest version  → users below it get "New update available" (once a day).
///   Minimum version → users below it MUST update (no "Later").
class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({super.key});

  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  final _c = {
    for (final p in ['android', 'ios'])
      p: {
        'latestVersion': TextEditingController(),
        'minimumVersion': TextEditingController(),
        'storeUrl': TextEditingController(),
        'message': TextEditingController(),
      }
  };
  final Map<String, String> _msg = {};
  final Set<String> _saving = {};
  bool _loading = true;
  String _thisApp = '';
  // "Notify users to update" push
  Map<String, dynamic>? _aud;
  bool _sending = false;
  String? _notifyMsg;

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
    for (final m in _c.values) {
      for (final t in m.values) {
        t.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _thisApp = (await PackageInfo.fromPlatform()).version;
      final r = await _api.getData(Constants.appVersion);
      final data = r.body is Map ? r.body['data'] : null;
      if (data is Map) {
        for (final p in ['android', 'ios']) {
          final row = data[p];
          if (row is! Map) continue;
          for (final k in _c[p]!.keys) {
            _c[p]![k]!.text = '${row[k] ?? ''}';
          }
        }
      }
    } catch (_) {}
    await _loadAudience();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAudience() async {
    try {
      final r = await _api.getData(Constants.adminAppVersionAudience, headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1' && r.body['data'] is Map) {
        _aud = Map<String, dynamic>.from(r.body['data']);
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _notify() async {
    final n = _aud?['count'] ?? 0;
    final go = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Send update notification?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
      content: Text(
        '$n user(s) on an older version will get a push asking them to update. '
        'This can only be sent once per version.',
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, height: 1.45),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4C6A4B))),
        ),
      ],
    ));
    if (go != true) return;
    setState(() {
      _sending = true;
      _notifyMsg = null;
    });
    try {
      final r = await _api.postData(Constants.adminAppVersionNotify, body: {}, headers: {'accessToken': _token});
      _notifyMsg = r.body is Map
          ? (r.body['status'] == '1' ? '✓ ${r.body['message']}' : '${r.body['message']}')
          : 'Could not send.';
    } catch (_) {
      _notifyMsg = 'Could not send. Check your internet.';
    }
    await _loadAudience();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _save(String p) async {
    setState(() {
      _saving.add(p);
      _msg.remove(p);
    });
    try {
      final r = await _api.postData(Constants.adminAppVersion,
          body: {
            'platform': p,
            for (final e in _c[p]!.entries) e.key: e.value.text.trim(),
          },
          headers: {'accessToken': _token});
      _msg[p] = r.body is Map && r.body['status'] == '1'
          ? '✓ Saved'
          : (r.body is Map ? '${r.body['message']}' : 'Could not save');
      await _loadAudience();
    } catch (_) {
      _msg[p] = 'Could not save. Check your internet.';
    }
    if (mounted) setState(() => _saving.remove(p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2A1E),
        title: const Text('App Version', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text(
                  'This phone runs Fit Her $_thisApp.\n'
                  'Latest → users below it see "New update available" (once a day).\n'
                  'Minimum → users below it must update to keep using the app.',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5, color: Color(0xFF66705F)),
                ),
                const SizedBox(height: 16),
                _card('android', 'Android'),
                _card('ios', 'iPhone'),
                _notifyCard(),
              ],
            ),
    );
  }

  Widget _notifyCard() {
    final a = _aud;
    final hasLatest = a?['hasLatest'] == true;
    final sent = a?['alreadySent'] == true;
    final n = a?['count'] ?? 0;
    final req = a?['required'] ?? 0;
    final can = hasLatest && !sent && n > 0 && !_sending;
    final ok = _notifyMsg?.startsWith('✓') == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Notify users to update',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        Text(
          !hasLatest
              ? 'Set a Latest version first.'
              : sent
                  ? 'Already sent for this version. Set a new Latest version to send again.'
                  : n == 0
                      ? 'Everyone is already up to date.'
                      : '$n user(s) will get it${req > 0 ? ' ($req must update)' : ''}. '
                          'Users who never opened a new version count as old.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.45, color: Color(0xFF66705F)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: can ? _notify : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8AD167),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_sending ? 'Sending…' : (n > 0 && !sent ? 'Send to $n users' : 'Send notification'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (_notifyMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_notifyMsg!,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: ok ? const Color(0xFF4C6A4B) : const Color(0xFFC2412D))),
          ),
      ]),
    );
  }

  Widget _field(String p, String key, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _c[p]![key],
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _card(String p, String title) {
    final msg = _msg[p];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(p, 'latestVersion', 'Latest version', '13.1.0')),
          const SizedBox(width: 10),
          Expanded(child: _field(p, 'minimumVersion', 'Minimum version', '13.0.0')),
        ]),
        _field(p, 'storeUrl', 'Store link', p == 'ios' ? 'https://apps.apple.com/app/id…' : 'https://play.google.com/store/apps/details?id=…'),
        _field(p, 'message', 'Message (optional)', 'Shown in the popup'),
        Row(children: [
          if (msg != null)
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: msg.startsWith('✓') ? const Color(0xFF4C6A4B) : const Color(0xFFC2412D))),
            )
          else
            const Spacer(),
          ElevatedButton(
            onPressed: _saving.contains(p) ? null : () => _save(p),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8AD167),
              foregroundColor: const Color(0xFF1F2A1E),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_saving.contains(p) ? 'Saving…' : 'Save', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
