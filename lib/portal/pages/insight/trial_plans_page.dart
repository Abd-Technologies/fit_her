import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// "Plans waiting / failed" (Oct 2026): free-trial women whose answers
/// are saved but whose AI starter plan hasn't been made yet. The server
/// retries quietly on its own; Retry starts it again right now. She gets
/// "Your starter plan is ready 🌱" as soon as it's made.
class TrialPlansPage extends StatefulWidget {
  const TrialPlansPage({super.key});

  @override
  State<TrialPlansPage> createState() => _TrialPlansPageState();
}

class _TrialPlansPageState extends State<TrialPlansPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/trial-plans/waiting');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['items'] is List) {
      list = (d['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load plans", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _retry(Map<String, dynamic> it) async {
    final id = (it['userId'] as num).toInt();
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/trial-plans/$id/retry', {});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(PortalApi.msg(b, 'Making her plan again'), sub: 'She gets a notification when it is ready.');
      // Give the AI a moment, then refresh the list.
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) _load();
      });
    } else {
      portalToast("Couldn't retry", sub: PortalApi.msg(b), error: true);
    }
  }

  static String _waited(dynamic since) {
    final t = DateTime.tryParse('$since');
    if (t == null) return '';
    final m = DateTime.now().difference(t.toLocal()).inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    if (h < 24) return '$h h ${m % 60} min';
    return '${h ~/ 24} days';
  }

  Widget _card(Map<String, dynamic> it) {
    final id = (it['userId'] as num).toInt();
    final status = '${it['status']}';
    final attempts = (it['attempts'] as num?)?.toInt() ?? 0;
    final (label, color) = switch (status) {
      'making' => ('Making now', PT.green),
      'failed' => ('Failed $attempts times', PT.red),
      'retrying' => ('Retrying · $attempts failed', PT.amber),
      _ => ('Waiting', PT.amber),
    };
    final name = '${it['name'] ?? ''}'.trim();
    final err = it['lastError'];
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name.isEmpty ? 'Client $id' : name,
                style: PT.t(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
          StatusChip(label, color: color),
        ]),
        const SizedBox(height: 4),
        Text('Waiting ${_waited(it['waitingSince'])}', style: PT.t(12.5, c: PT.sage)),
        if (it['email'] != null) SelectableText('${it['email']}', style: PT.t(12, c: PT.sage)),
        if (it['phone'] != null) SelectableText('Phone ${it['phone']}', style: PT.t(12, c: PT.sage)),
        if (err != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFDF3DF), borderRadius: BorderRadius.circular(10)),
            child: Text('Last error: $err', style: PT.t(12, c: PT.amber), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          const Spacer(),
          if (_busy.contains(id) || status == 'making')
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else
            ElevatedButton(
              style: portalPrimary(),
              onPressed: () => _retry(it),
              child: const Text('Retry'),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final failed = items.where((e) => e['status'] == 'failed').toList();
    final waiting = items.where((e) => e['status'] != 'failed').toList();
    Widget section(String title, List<Map<String, dynamic>> list, Color c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${list.length})', style: PT.t(14, w: FontWeight.w700, c: c)),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 14, children: list.map(_card).toList()),
            const SizedBox(height: 26),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Plans waiting / failed',
        sub: 'Free-trial women whose starter meal plan the AI has not made yet. The server retries on its own; '
            'Retry starts it again now. She gets a notification as soon as her plan is ready.',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load plans",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.check_circle_outline_rounded, title: 'Every trial woman has her plan')
                    : SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (failed.isNotEmpty) section('Failed', failed, PT.red),
                          if (waiting.isNotEmpty) section('Waiting', waiting, PT.ink),
                        ]),
                      ),
      ),
    ]);
  }
}
