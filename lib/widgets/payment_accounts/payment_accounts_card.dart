import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import '../toasts.dart';

/// One Fit Her account she can pay into (admin manages the list).
class PaymentAccountItem {
  final int id;
  final String kind; // wallet | bank
  final String provider;
  final String title;
  final String number;
  final String? iban;
  final String? branch;
  final String? swift;
  final String? note;
  final bool active;
  final int sortOrder;

  PaymentAccountItem({
    required this.id,
    required this.kind,
    required this.provider,
    required this.title,
    required this.number,
    this.iban,
    this.branch,
    this.swift,
    this.note,
    this.active = true,
    this.sortOrder = 0,
  });

  bool get isBank => kind == 'bank';

  factory PaymentAccountItem.fromJson(Map<String, dynamic> j) => PaymentAccountItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        kind: '${j['kind'] ?? 'wallet'}',
        provider: '${j['provider'] ?? ''}',
        title: '${j['title'] ?? ''}',
        number: '${j['number'] ?? ''}',
        iban: _s(j['iban']),
        branch: _s(j['branch']),
        swift: _s(j['swift']),
        note: _s(j['note']),
        active: j['active'] != false,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  static String? _s(dynamic v) => v == null || '$v'.trim().isEmpty ? null : '$v';
}

/// Loads accounts. [admin] = every account (admin screen), else active ones.
Future<List<PaymentAccountItem>?> fetchPaymentAccounts({bool admin = false}) async {
  try {
    final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
    final r = await Get.find<ApiProvider>()
        .getData(admin ? '/admin/payment-accounts' : '/users/payment-accounts', headers: {'accessToken': token});
    final b = r.body;
    if (b is Map && b['status'] == '1' && b['data'] is Map && b['data']['accounts'] is List) {
      return (b['data']['accounts'] as List)
          .whereType<Map>()
          .map((e) => PaymentAccountItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  } catch (_) {}
  return null;
}

/// "Pay into one of these" card on the Upload slip screen.
class PaymentAccountsCard extends StatefulWidget {
  const PaymentAccountsCard({super.key, required this.price});
  final String price;

  @override
  State<PaymentAccountsCard> createState() => _PaymentAccountsCardState();
}

class _PaymentAccountsCardState extends State<PaymentAccountsCard> {
  static const _ink = Color(0xFF1A3A22);
  static const _sage = Color(0xFF7A8C78);
  static const _accent = Color(0xFF6DC55A);
  static const _line = Color(0xFFE3ECDD);

  List<PaymentAccountItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await fetchPaymentAccounts();
    if (mounted) setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    FhToast.show(FhToastKind.success, '$label copied', sub: value);
  }

  TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: 1.35);

  Widget _copyRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label  ', style: _t(11.5, c: _sage)),
              TextSpan(text: value, style: _t(13, w: FontWeight.w600)),
            ])),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _copy(label, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Copy', style: _t(12, w: FontWeight.w600, c: _accent)),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final items = _items ?? const <PaymentAccountItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pay PKR ${widget.price} to one of these', style: _t(14, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Your plan starts right away when the slip shows our account, the transaction ID and today\'s date.',
              style: _t(11.5, c: _sage)),
          for (final a in items) ...[
            const Divider(height: 18, color: _line),
            Text(a.provider, style: _t(11, w: FontWeight.w700, c: _accent)),
            Text(a.title, style: _t(13, w: FontWeight.w600)),
            _copyRow(a.isBank ? 'Account' : 'Number', a.number),
            if (a.iban != null) _copyRow('IBAN', a.iban!),
            if (a.branch != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(a.branch!, style: _t(11, c: _sage))),
          ],
        ]),
      ),
    );
  }
}
