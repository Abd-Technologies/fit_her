import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import '../../../widgets/payment_accounts/payment_accounts_card.dart';
import '../../../widgets/toasts.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin → Payment accounts. Where clients pay; payment slips are approved
/// automatically only when they show one of the ACTIVE accounts here.
class PaymentAccountsScreen extends StatefulWidget {
  const PaymentAccountsScreen({super.key});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _green = Color(0xFF4C6A4B);
const _lime = Color(0xFF8AD167);
const _line = Color(0xFFE3E8DE);
TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: 1.35);

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen> {
  List<PaymentAccountItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await fetchPaymentAccounts(admin: true);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<bool> _save(Map<String, dynamic> body, {int? id}) async {
    try {
      final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      final r = await Get.find<ApiProvider>().postData(
        id == null ? '/admin/payment-accounts' : '/admin/payment-accounts/$id',
        body: body,
        headers: {'accessToken': token},
      );
      final b = r.body;
      if (b is Map && b['status'] == '1') {
        FhToast.show(FhToastKind.success, '${b['message'] ?? 'Saved'}');
        await _load();
        return true;
      }
      CustomToast.failToast(msg: b is Map ? b['message'] : null);
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't save. Please try again.");
    }
    return false;
  }

  Future<void> _edit([PaymentAccountItem? a]) async {
    await Get.bottomSheet(_AccountForm(account: a, onSave: (body) => _save(body, id: a?.id)),
        isScrollControlled: true, backgroundColor: Colors.transparent);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <PaymentAccountItem>[];
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text('Payment accounts', style: _t(17, w: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _lime,
        foregroundColor: _ink,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text('Add account', style: _t(14, w: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  Text(
                    'Clients see the active accounts when they upload a slip. A slip is approved automatically only when it shows one of them, a transaction or reference ID, and a date within 4 days.',
                    style: _t(12.5, c: _soft),
                  ),
                  const SizedBox(height: 12),
                  if (_items == null)
                    TextButton(onPressed: _load, child: const Text('Couldn\'t load. Try again'))
                  else if (items.isEmpty)
                    Text('No accounts yet.', style: _t(13, c: _soft)),
                  for (final a in items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      decoration: BoxDecoration(
                        color: a.active ? Colors.white : const Color(0xFFF1F3EE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _edit(a),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.provider, style: _t(11.5, w: FontWeight.w700, c: _green)),
                              Text(a.title, style: _t(14, w: FontWeight.w600)),
                              Text(a.number, style: _t(13)),
                              if (a.iban != null) Text('IBAN ${a.iban}', style: _t(12, c: _soft)),
                              Text(a.active ? 'Active · tap to edit' : 'Off · not shown, slips not matched',
                                  style: _t(11, c: _soft)),
                            ]),
                          ),
                        ),
                        Switch(
                          value: a.active,
                          activeColor: _green,
                          onChanged: (v) => _save({'active': v}, id: a.id),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.account, required this.onSave});
  final PaymentAccountItem? account;
  final Future<bool> Function(Map<String, dynamic>) onSave;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late String _kind = widget.account?.kind ?? 'wallet';
  late final _provider = TextEditingController(text: widget.account?.provider ?? '');
  late final _title = TextEditingController(text: widget.account?.title ?? '');
  late final _number = TextEditingController(text: widget.account?.number ?? '');
  late final _iban = TextEditingController(text: widget.account?.iban ?? '');
  late final _branch = TextEditingController(text: widget.account?.branch ?? '');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_provider, _title, _number, _iban, _branch]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, {String? hint, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Future<void> _submit() async {
    if (_provider.text.trim().isEmpty || _title.text.trim().isEmpty || _number.text.trim().isEmpty) {
      CustomToast.warnToast('Please fill provider, title and number');
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.onSave({
      'kind': _kind,
      'provider': _provider.text.trim(),
      'title': _title.text.trim(),
      'number': _number.text.trim(),
      'iban': _iban.text.trim(),
      'branch': _branch.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.account == null ? 'Add account' : 'Edit account', style: _t(17, w: FontWeight.w700)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'wallet', label: Text('Mobile wallet')),
                  ButtonSegment(value: 'bank', label: Text('Bank')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              _field('Provider', _provider, hint: _kind == 'bank' ? 'Soneri Bank' : 'JazzCash / EasyPaisa'),
              _field('Account title (as on slips)', _title, hint: 'Fit Her (Private) Limited'),
              _field(_kind == 'bank' ? 'Account number' : 'Mobile number', _number,
                  hint: _kind == 'bank' ? '120014636405' : '03XXXXXXXXX', type: TextInputType.number),
              if (_kind == 'bank') ...[
                _field('IBAN', _iban, hint: 'PK60SONE…'),
                _field('Branch (optional)', _branch),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: _ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Save', style: _t(15, w: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
