import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// AI-approved slips the admin must confirm within 48 h (money really arrived).
class PaymentChecksPage extends StatefulWidget {
  const PaymentChecksPage({super.key});

  @override
  State<PaymentChecksPage> createState() => _PaymentChecksPageState();
}

class _PaymentChecksPageState extends State<PaymentChecksPage> {
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
    final b = await PortalApi.get('/admin/payment-checks');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['items'] is List) {
      list = (d['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load payments", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> it, String result) async {
    final id = (it['id'] as num).toInt();
    if (result == 'not_received') {
      final sure = await portalConfirm(
        context,
        title: 'Money not received?',
        body: "${it['name']}'s plan will be paused now. She sees the free app with a red banner and can send proof.",
        yes: 'Pause plan',
        danger: true,
      );
      if (!sure) return;
    }
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/payment-checks/$id', {'result': result});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(result == 'received' ? 'Payment confirmed' : 'Plan paused', sub: PortalApi.msg(b));
      _load();
    } else {
      portalToast("Couldn't save", sub: PortalApi.msg(b), error: true);
    }
  }

  Widget _card(Map<String, dynamic> it) {
    final id = (it['id'] as num).toInt();
    final status = '${it['status']}';
    final paused = status == 'held' || status == 'not_received';
    final acc = it['account'] is Map ? Map<String, dynamic>.from(it['account']) : null;
    final hoursLeft = it['hoursLeft'];
    final chip = paused
        ? (status == 'not_received' ? 'Paused · not received' : 'Paused · not confirmed in 48 h')
        : 'Confirm within ${hoursLeft ?? '?'} h';
    final chipColor = paused ? PT.red : ((hoursLeft is num && hoursLeft <= 8) ? PT.amber : PT.green);
    // DirectPay payments have no slip: the admin checks the DirectPay merchant portal.
    final isDirectPay = '${it['method']}' == 'directpay';
    final imgPath = '${it['image'] ?? ''}';
    final img = imgPath.isEmpty ? null : PortalApi.privateFile(imgPath);

    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${it['name']}', style: PT.t(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          StatusChip(chip, color: chipColor),
        ]),
        if (it['plan'] != null) Text('${it['plan']}', style: PT.t(12, c: PT.sage)),
        const SizedBox(height: 10),
        Text('PKR ${it['amount'] ?? '—'}',
            style: PT.t(22, w: FontWeight.w700).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        if (isDirectPay) ...[
          SelectableText('DirectPay · ref ${it['reference'] ?? '—'}', style: PT.t(12.5, w: FontWeight.w600)),
          Text('Check it in the DirectPay merchant portal.', style: PT.t(12, c: PT.sage)),
        ] else ...[
          Text(acc == null ? 'Account: not matched' : 'To ${acc['title']} · ${acc['provider']} …${acc['last4']}',
              style: PT.t(12.5)),
          SelectableText('Ref ${it['reference'] ?? '—'} · Slip date ${it['slipDate'] ?? '—'}', style: PT.t(12.5, c: PT.sage)),
        ],
        if (it['phone'] != null) SelectableText('Phone ${it['phone']}', style: PT.t(12, c: PT.sage)),
        if (it['userProof'] != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFDF3DF), borderRadius: BorderRadius.circular(10)),
            child: Text('Her proof: ${it['userProof']}', style: PT.t(12.5, w: FontWeight.w600, c: PT.amber)),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (img != null)
            TextButton.icon(
              onPressed: () => portalShowImage(context, img),
              icon: const Icon(Icons.receipt_long_outlined, size: 17),
              label: const Text('View slip'),
            ),
          const Spacer(),
          if (_busy.contains(id))
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (status != 'not_received')
              TextButton(
                onPressed: () => _decide(it, 'not_received'),
                child: Text('Not received', style: PT.t(13, w: FontWeight.w600, c: PT.red)),
              ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: portalPrimary(),
              onPressed: () => _decide(it, 'received'),
              child: const Text('Received'),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> list, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${list.length})', style: PT.t(14, w: FontWeight.w700, c: c)),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 14, children: list.map(_card).toList()),
          const SizedBox(height: 26),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final toConfirm = items.where((e) => e['status'] == 'pending').toList();
    final paused = items.where((e) => e['status'] != 'pending').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Confirm payments',
        sub: 'The AI approved these slips and started the plans. Check each amount arrived in JazzCash / EasyPaisa / '
            'the bank app, then click Received. Not confirmed in 48 hours → the plan pauses.',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load payments",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.verified_rounded, title: 'All payments confirmed')
                    : SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (toConfirm.isNotEmpty) _section('To confirm', toConfirm, PT.ink),
                          if (paused.isNotEmpty) _section('Paused', paused, PT.red),
                        ]),
                      ),
      ),
    ]);
  }
}
