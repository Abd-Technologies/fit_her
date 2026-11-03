import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// App update rules per platform.
///   Latest version  -> users below it see "New update available" (once a day).
///   Minimum version -> users below it MUST update (no "Later").
/// Same calls as the app: GET /users/app-version, POST /admin/app-version,
/// GET /admin/app-version/audience, POST /admin/app-version/notify.
class AppVersionPage extends StatefulWidget {
  const AppVersionPage({super.key});

  @override
  State<AppVersionPage> createState() => _AppVersionPageState();
}

const _kPlatforms = ['android', 'ios'];
const _kKeys = ['latestVersion', 'minimumVersion', 'storeUrl', 'message'];

class _AppVersionPageState extends State<AppVersionPage> {
  final Map<String, Map<String, TextEditingController>> _c = {
    for (final p in _kPlatforms) p: {for (final k in _kKeys) k: TextEditingController()}
  };
  final Map<String, String> _msg = {};
  final Map<String, bool> _msgOk = {};
  final Set<String> _saving = {};
  bool _loading = true;
  bool _loaded = false;
  Map<String, dynamic>? _aud;
  bool _sending = false;
  String? _notifyMsg;
  bool _notifyOk = false;

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
    setState(() => _loading = true);
    final b = await PortalApi.get('/users/app-version');
    final data = b['data'];
    var ok = false;
    if (PortalApi.ok(b) && data is Map) {
      ok = true;
      for (final p in _kPlatforms) {
        final row = data[p];
        if (row is! Map) continue;
        for (final k in _kKeys) {
          final v = row[k];
          _c[p]![k]!.text = v == null ? '' : '$v';
        }
      }
    } else {
      portalToast("Couldn't load the app versions", sub: PortalApi.msg(b), error: true);
    }
    await _loadAudience();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loaded = _loaded || ok;
    });
  }

  Future<void> _loadAudience() async {
    final b = await PortalApi.get('/admin/app-version/audience');
    if (PortalApi.ok(b) && b['data'] is Map) {
      _aud = Map<String, dynamic>.from(b['data'] as Map);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save(String p) async {
    setState(() {
      _saving.add(p);
      _msg.remove(p);
    });
    final b = await PortalApi.post('/admin/app-version', {
      'platform': p,
      for (final e in _c[p]!.entries) e.key: e.value.text.trim(),
    });
    if (!mounted) return;
    final ok = PortalApi.ok(b);
    _msgOk[p] = ok;
    _msg[p] = ok ? 'Saved' : PortalApi.msg(b, "Couldn't save");
    if (ok) portalToast('${p == 'ios' ? 'iPhone' : 'Android'} version saved');
    await _loadAudience();
    if (mounted) setState(() => _saving.remove(p));
  }

  Future<void> _notify() async {
    final n = _aud?['count'] ?? 0;
    final go = await portalConfirm(context,
        title: 'Send update notification?',
        body: '$n user(s) on an older version will get a message asking them to update. '
            'This can only be sent once per version.',
        yes: 'Send');
    if (!go) return;
    setState(() {
      _sending = true;
      _notifyMsg = null;
    });
    final b = await PortalApi.post('/admin/app-version/notify', {});
    _notifyOk = PortalApi.ok(b);
    _notifyMsg = PortalApi.msg(b, "Couldn't send.");
    if (_notifyOk) portalToast('Update notice sent', sub: _notifyMsg);
    await _loadAudience();
    if (mounted) setState(() => _sending = false);
  }

  Widget _msgLine(String? m, bool ok) => m == null
      ? const SizedBox.shrink()
      : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, size: 15, color: ok ? PT.greenDark : PT.red),
          const SizedBox(width: 6),
          Flexible(child: Text(m, style: PT.t(12.5, c: ok ? PT.greenDark : PT.red))),
        ]);

  Widget _field(String p, String key, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey('appver_${p}_$key'),
          controller: _c[p]![key],
          style: PT.t(13.5),
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  Widget _card(String p, String title, IconData icon) {
    final busy = _saving.contains(p);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(icon, size: 20, color: PT.green),
          const SizedBox(width: 8),
          Text(title, style: PT.t(15.5, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(p, 'latestVersion', 'Latest version', '13.1.0')),
          const SizedBox(width: 10),
          Expanded(child: _field(p, 'minimumVersion', 'Minimum version', '13.0.0')),
        ]),
        _field(p, 'storeUrl', 'Store link',
            p == 'ios' ? 'https://apps.apple.com/app/id…' : 'https://play.google.com/store/apps/details?id=…'),
        _field(p, 'message', 'Message (optional)', 'Shown in the popup'),
        Row(children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: _msgLine(_msg[p], _msgOk[p] ?? false))),
          const SizedBox(width: 10),
          ElevatedButton(
            style: portalPrimary(),
            onPressed: busy ? null : () => _save(p),
            child: Text(busy ? 'Saving…' : 'Save'),
          ),
        ]),
      ]),
    );
  }

  Widget _notifyCard() {
    final a = _aud;
    final hasLatest = a?['hasLatest'] == true;
    final sent = a?['alreadySent'] == true;
    final n = (a?['count'] as num?)?.toInt() ?? 0;
    final req = (a?['required'] as num?)?.toInt() ?? 0;
    final can = a != null && hasLatest && !sent && n > 0 && !_sending;
    final text = a == null
        ? "Couldn't check who is on an old version."
        : !hasLatest
            ? 'Set a Latest version first.'
            : sent
                ? 'Already sent for this version. Set a new Latest version to send again.'
                : n == 0
                    ? 'Everyone is already up to date.'
                    : '$n user(s) will get it${req > 0 ? ' ($req must update)' : ''}. '
                        'Users who never opened a new version count as old.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.campaign_outlined, size: 20, color: PT.green),
          const SizedBox(width: 8),
          Expanded(child: Text('Tell users to update', style: PT.t(15.5, w: FontWeight.w700))),
          if (a != null && hasLatest && !sent && n > 0) StatusChip('$n on an old version', color: PT.amber),
        ]),
        const SizedBox(height: 8),
        Text(text, style: PT.t(12.5, c: PT.sage, h: 1.45)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: _msgLine(_notifyMsg, _notifyOk))),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: can ? _notify : null,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(_sending ? 'Sending…' : (n > 0 && !sent ? 'Send to $n users' : 'Send notification')),
          ),
        ]),
      ]),
    );
  }

  Widget _help() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works', style: PT.t(13, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Latest: users below this version see "New update available" (once a day).\n'
            'Minimum: users below this version must update to keep using the app.\n'
            'Versions look like 13.1.0. Store links must start with https://',
            style: PT.t(12.5, c: PT.sage, h: 1.5),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'App version',
        sub: 'Ask people to update the Fit Her app, or make them update before they can keep using it.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && !_loaded
            ? const Center(child: CircularProgressIndicator())
            : !_loaded
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the app versions",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : ListView(children: [
                    _help(),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, c) {
                      final android = _card('android', 'Android', Icons.android_rounded);
                      final ios = _card('ios', 'iPhone', Icons.phone_iphone_rounded);
                      if (c.maxWidth < 760) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          android,
                          const SizedBox(height: 14),
                          ios,
                        ]);
                      }
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: android),
                        const SizedBox(width: 14),
                        Expanded(child: ios),
                      ]);
                    }),
                    const SizedBox(height: 14),
                    _notifyCard(),
                  ]),
      ),
    ]);
  }
}
