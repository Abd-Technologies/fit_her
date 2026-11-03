import 'package:flutter/material.dart';
import 'package:fitness_zone_2/helper/private_file_url.dart';
import 'package:get/get.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin → Confirm payments. Slips the AI approved: check the money is in
/// the JazzCash / EasyPaisa / bank app, then tap Received. Not confirmed
/// within 48 h → her plan pauses. Not received → pauses now.
class PaymentChecksScreen extends StatefulWidget {
  const PaymentChecksScreen({super.key});

  @override
  State<PaymentChecksScreen> createState() => _PaymentChecksScreenState();
}

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _green = Color(0xFF4E9F3D);
const _amber = Color(0xFFC77B2B);
const _red = Color(0xFFC24A4A);
const _line = Color(0xFFE3E8DE);
TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: 1.35);

class _PaymentChecksScreenState extends State<PaymentChecksScreen> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  final Set<int> _busy = {};

  String get _token => Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>>? items;
    try {
      final r = await Get.find<ApiProvider>().getData('/admin/payment-checks', headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map && b['data']['items'] is List) {
        items = (b['data']['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (b is Map) {
        CustomToast.failToast(msg: b['message']);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> it, String result) async {
    final id = (it['id'] as num).toInt();
    if (result == 'not_received') {
      final go = await Get.dialog<bool>(AlertDialog(
        title: Text('Money not received?', style: _t(16, w: FontWeight.w700)),
        content: Text('${it['name']}\'s plan will be paused now. She can send proof from the app.', style: _t(13)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Pause plan', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ));
      if (go != true) return;
    }
    setState(() => _busy.add(id));
    try {
      final r = await Get.find<ApiProvider>()
          .postData('/admin/payment-checks/$id', body: {'result': result}, headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        FhToast.show(result == 'received' ? FhToastKind.success : FhToastKind.warning, '${b['message']}');
        await _load();
      } else {
        CustomToast.failToast(msg: b is Map ? b['message'] : null);
      }
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't save. Please try again.");
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  void _showSlip(String? image) {
    if (image == null || image.isEmpty) return;
    Get.dialog(Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(child: Image.network(privateFileUrl(image), fit: BoxFit.contain)),
    ));
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
    final chipColor = paused ? _red : ((hoursLeft is num && hoursLeft <= 8) ? _amber : _green);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${it['name']}', style: _t(15, w: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(chip, style: _t(11, w: FontWeight.w600, c: chipColor)),
          ),
        ]),
        if (it['plan'] != null) Text('${it['plan']}', style: _t(12, c: _soft)),
        const SizedBox(height: 8),
        Text('PKR ${it['amount'] ?? '—'}', style: _t(20, w: FontWeight.w700)),
        // DirectPay payments have no slip: check the DirectPay merchant portal.
        if ('${it['method']}' == 'directpay') ...[
          Text('DirectPay · ref ${it['reference'] ?? '—'}', style: _t(12.5, w: FontWeight.w600)),
          Text('Check it in the DirectPay merchant portal.', style: _t(12, c: _soft)),
        ] else ...[
          Text(
            acc == null ? 'Account: not matched' : 'To ${acc['title']} · ${acc['provider']} …${acc['last4']}',
            style: _t(12.5),
          ),
          Text('Ref ${it['reference'] ?? '—'} · Slip date ${it['slipDate'] ?? '—'}', style: _t(12.5, c: _soft)),
        ],
        if (it['phone'] != null) Text('Phone ${it['phone']}', style: _t(12, c: _soft)),
        if (it['userProof'] != null) ...[
          const SizedBox(height: 6),
          Text('Her proof: ${it['userProof']}', style: _t(12.5, w: FontWeight.w600, c: _amber)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if ('${it['image'] ?? ''}'.isNotEmpty)
            TextButton(onPressed: () => _showSlip(it['image']?.toString()), child: const Text('View slip')),
          const Spacer(),
          if (!_busy.contains(id) && status != 'not_received')
            TextButton(
              onPressed: () => _decide(it, 'not_received'),
              child: Text('Not received', style: _t(13, w: FontWeight.w600, c: _red)),
            ),
          const SizedBox(width: 6),
          _busy.contains(id)
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _decide(it, 'received'),
                  child: Text('Received', style: _t(13, w: FontWeight.w600, c: Colors.white)),
                ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final toConfirm = items.where((e) => e['status'] == 'pending').toList();
    final paused = items.where((e) => e['status'] != 'pending').toList();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text('Confirm payments', style: _t(17, w: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Text(
                    'The AI approved these slips and started the plans. Check each amount arrived in the JazzCash / EasyPaisa / bank app, then tap Received. Not confirmed in 48 hours → the plan pauses.',
                    style: _t(12.5, c: _soft),
                  ),
                  const SizedBox(height: 12),
                  if (_items == null)
                    TextButton(onPressed: _load, child: const Text("Couldn't load. Try again"))
                  else if (items.isEmpty)
                    Text('All payments confirmed ✓', style: _t(14, w: FontWeight.w600, c: _green)),
                  if (toConfirm.isNotEmpty) ...[
                    Text('To confirm (${toConfirm.length})', style: _t(13, w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...toConfirm.map(_card),
                  ],
                  if (paused.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Paused (${paused.length})', style: _t(13, w: FontWeight.w700, c: _red)),
                    const SizedBox(height: 8),
                    ...paused.map(_card),
                  ],
                ],
              ),
            ),
    );
  }
}
