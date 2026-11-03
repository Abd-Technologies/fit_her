import 'dart:convert';

import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import '../../../values/slip_reject_reasons.dart';

/// Slips the automatic check could not approve. Admin approves or rejects.
class SlipsPage extends StatefulWidget {
  const SlipsPage({super.key});

  @override
  State<SlipsPage> createState() => _SlipsPageState();
}

class _SlipsPageState extends State<SlipsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  int? _selId;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/getAllPlanImages');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['data'] is List) {
      list = (d['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load slips", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      if (list != null && !list.any((e) => e['id'] == _selId)) _selId = list.isEmpty ? null : list.first['id'] as int?;
    });
  }

  Future<void> _decide(Map<String, dynamic> it, {required bool reject}) async {
    final id = (it['id'] as num).toInt();
    final name = _name(it);
    // Oct 2026: rejecting asks why (she sees the reason); approving asks to confirm.
    String? reason;
    if (reject) {
      reason = await pickSlipRejectReason(context);
      if (reason == null) return;
    } else {
      final sure = await portalConfirm(
        context,
        title: 'Approve this slip?',
        body: "$name's plan starts now and she gets a welcome message.",
        yes: 'Approve',
      );
      if (!sure) return;
    }
    if (!mounted) return;
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/approvedImage', {
      'planImageId': '$id',
      'rejected': reject,
      if (reason != null) 'reason': reason,
    });
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(reject ? 'Slip rejected' : 'Slip approved', sub: name);
      setState(() {
        final i = _items!.indexWhere((e) => e['id'] == id);
        if (i < 0) return;
        _items!.removeAt(i);
        _selId = _items!.isEmpty ? null : _items![i.clamp(0, _items!.length - 1)]['id'] as int?;
      });
    } else {
      portalToast("Couldn't save", sub: PortalApi.msg(b), error: true);
    }
  }

  static String _name(Map<String, dynamic> it) {
    final u = it['User'] is Map ? it['User'] as Map : const {};
    final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    return n.isEmpty ? 'Client' : n;
  }

  static Map<String, dynamic>? _ocr(Map<String, dynamic> it) {
    final v = it['ocrData'];
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  Widget _listTile(Map<String, dynamic> it) {
    final sel = it['id'] == _selId;
    final plan = it['Plan'] is Map ? '${it['Plan']['title'] ?? ''}' : '';
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selId = it['id'] as int?),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name(it), style: PT.t(13.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(plan.isEmpty ? 'No plan' : plan, style: PT.t(12, c: PT.sage), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(it['price'] == null ? '—' : 'PKR ${it['price']}', style: PT.t(12.5, w: FontWeight.w600)),
              Text(portalAgo(it['createdAt']), style: PT.t(11, c: PT.sage)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(String k, String? v, bool? ok) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            ok == null
                ? Icons.remove_circle_outline
                : (ok ? Icons.check_circle_rounded : Icons.error_outline_rounded),
            size: 17,
            color: ok == null ? PT.sage : (ok ? PT.green : PT.amber),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text(k, style: PT.t(12.5, c: PT.sage))),
          Expanded(
            child: SelectableText(v == null || v.isEmpty ? 'not found' : v, style: PT.t(13, w: FontWeight.w600)),
          ),
        ]),
      );

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: PT.t(12.5, c: PT.sage))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: PT.t(13))),
        ]),
      );

  Widget _detail(Map<String, dynamic> it) {
    final id = (it['id'] as num).toInt();
    final u = it['User'] is Map ? Map<String, dynamic>.from(it['User']) : <String, dynamic>{};
    final sup = u['supporter'] is Map ? u['supporter'] as Map : null;
    final plan = it['Plan'] is Map ? '${it['Plan']['title'] ?? ''}' : '';
    final dur = it['PriceDuration'] is Map ? '${it['PriceDuration']['duration'] ?? ''}' : '';
    final ocr = _ocr(it);
    final checks = ocr?['checks'] is Map ? Map<String, dynamic>.from(ocr!['checks']) : const <String, dynamic>{};
    final acc = ocr?['account'] is Map ? Map<String, dynamic>.from(ocr!['account']) : null;
    final reason = ocr?['approvalReason']?.toString();
    final img = it['image'] == null ? null : PortalApi.privateFile('${it['image']}');

    final slip = Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F4EE), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: img == null
          ? SizedBox(height: 320, child: Center(child: Text('No slip image', style: PT.t(13, c: PT.sage))))
          : InkWell(
              onTap: () => portalShowImage(context, img),
              child: Stack(children: [
                Image.network(img,
                    height: 460,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        SizedBox(height: 320, child: Center(child: Text("Couldn't load the slip", style: PT.t(13, c: PT.sage))))),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.zoom_in, size: 16, color: PT.ink),
                      const SizedBox(width: 4),
                      Text('Open full size', style: PT.t(11.5, w: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
    );

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_name(it), style: PT.t(19, w: FontWeight.w700)),
      Text('Uploaded ${portalAgo(it['createdAt'])}', style: PT.t(12, c: PT.sage)),
      const SizedBox(height: 14),
      _info('Email', '${u['email'] ?? ''}'),
      _info('Phone', '${u['phone'] ?? ''}'),
      _info('Plan', plan),
      _info('Duration', dur),
      _info('Price', it['price'] == null ? '' : 'PKR ${it['price']}'),
      _info('Sales rep', sup == null ? '' : '${sup['firstName'] ?? ''} ${sup['lastName'] ?? ''}'.trim()),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
        child: ocr == null
            ? Text('The slip could not be read automatically. Please check it by eye.', style: PT.t(13, c: PT.amber))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Slip check', style: PT.t(13.5, w: FontWeight.w700)),
                _row('Our account', acc == null ? null : '${acc['title']} · ${acc['provider']} …${acc['last4']}',
                    checks['account'] as bool?),
                _row('Date', ocr['slipDate']?.toString() ?? it['ocrDate']?.toString(), checks['date'] as bool?),
                _row('Reference', it['ocrTransactionId']?.toString(), checks['reference'] as bool?),
                _row('Amount', it['ocrAmount'] == null ? null : 'PKR ${it['ocrAmount']}', checks['amount'] as bool?),
                if (reason != null) ...[
                  const SizedBox(height: 10),
                  Text('Why it waits for you: $reason', style: PT.t(12.5, c: PT.amber, h: 1.4)),
                ],
              ]),
      ),
      const SizedBox(height: 18),
      _busy.contains(id)
          ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2.4))
          : Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: portalPrimary(),
                  onPressed: () => _decide(it, reject: false),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: portalDanger(),
                  onPressed: () => _decide(it, reject: true),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ),
            ]),
    ]);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PT.card(),
      child: LayoutBuilder(builder: (c, box) {
        if (box.maxWidth >= 720) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: slip),
            const SizedBox(width: 22),
            Expanded(flex: 4, child: info),
          ]);
        }
        return Column(children: [slip, const SizedBox(height: 18), info]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final sel = items.where((e) => e['id'] == _selId).firstOrNull;
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Slips to approve',
        sub: "Slips the automatic check couldn't approve. Look at the slip, check the money arrived, then approve or reject.",
        actions: [
          if (_items != null) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${items.length} waiting')),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load slips",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.task_alt_rounded, title: 'No slips waiting', sub: 'New slips show up here.')
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: wide ? 320 : 260,
                          decoration: PT.card(),
                          clipBehavior: Clip.antiAlias,
                          child: ListView(children: items.map(_listTile).toList()),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: sel == null
                              ? const SizedBox()
                              : SingleChildScrollView(child: _detail(sel)),
                        ),
                      ]),
      ),
    ]);
  }
}
