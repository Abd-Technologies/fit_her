import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Accounts clients pay into. The slip check only passes slips sent to an
/// active account here. (Not shown in the app for now — Play policy.)
class PaymentAccountsPage extends StatefulWidget {
  const PaymentAccountsPage({super.key});

  @override
  State<PaymentAccountsPage> createState() => _PaymentAccountsPageState();
}

class _PaymentAccountsPageState extends State<PaymentAccountsPage> {
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
    final b = await PortalApi.get('/admin/payment-accounts');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['accounts'] is List) {
      list = (d['accounts'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load accounts", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> a, bool on) async {
    final id = (a['id'] as num).toInt();
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/payment-accounts/$id', {'active': on});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(on ? 'Account turned on' : 'Account turned off', sub: '${a['title']}');
      _load();
    } else {
      portalToast("Couldn't save", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _edit([Map<String, dynamic>? a]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _AccountDialog(account: a));
    if (saved == true) _load();
  }

  Widget _cell(String text, {bool bold = false, Color c = PT.ink}) =>
      SelectableText(text.isEmpty ? '—' : text, style: PT.t(13, w: bold ? FontWeight.w600 : FontWeight.w400, c: c));

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Payment accounts',
        sub: 'Where clients send money. A slip only passes the automatic check when it was sent to an account that is on here.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add account'),
          ),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load accounts",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.account_balance_outlined, title: 'No accounts yet')
                    : SingleChildScrollView(
                        child: Container(
                          decoration: PT.card(),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 900),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(PT.wash),
                                headingTextStyle: PT.t(12, w: FontWeight.w700, c: PT.sage),
                                dataRowMinHeight: 58,
                                dataRowMaxHeight: 72,
                                columns: const [
                                  DataColumn(label: Text('PROVIDER')),
                                  DataColumn(label: Text('ACCOUNT TITLE')),
                                  DataColumn(label: Text('NUMBER')),
                                  DataColumn(label: Text('IBAN / BRANCH')),
                                  DataColumn(label: Text('ON')),
                                  DataColumn(label: Text('')),
                                ],
                                rows: items.map((a) {
                                  final id = (a['id'] as num).toInt();
                                  final on = a['active'] == true;
                                  final bank = a['kind'] == 'bank';
                                  return DataRow(cells: [
                                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(bank ? Icons.account_balance_outlined : Icons.phone_android_outlined,
                                          size: 17, color: on ? PT.green : PT.sage),
                                      const SizedBox(width: 8),
                                      _cell('${a['provider'] ?? ''}', bold: true, c: on ? PT.ink : PT.sage),
                                    ])),
                                    DataCell(_cell('${a['title'] ?? ''}', c: on ? PT.ink : PT.sage)),
                                    DataCell(_cell('${a['number'] ?? ''}', c: on ? PT.ink : PT.sage)),
                                    DataCell(Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _cell(bank ? '${a['iban'] ?? ''}' : '', c: on ? PT.ink : PT.sage),
                                        if (bank && a['branch'] != null) Text('${a['branch']}', style: PT.t(11.5, c: PT.sage)),
                                      ],
                                    )),
                                    DataCell(_busy.contains(id)
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Switch(value: on, activeTrackColor: PT.green, onChanged: (v) => _toggle(a, v))),
                                    DataCell(TextButton.icon(
                                      onPressed: () => _edit(a),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Edit'),
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
      ),
    ]);
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.account});
  final Map<String, dynamic>? account;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late String _kind = '${widget.account?['kind'] ?? 'wallet'}';
  late final _provider = TextEditingController(text: '${widget.account?['provider'] ?? ''}');
  late final _title = TextEditingController(text: '${widget.account?['title'] ?? ''}');
  late final _number = TextEditingController(text: '${widget.account?['number'] ?? ''}');
  late final _iban = TextEditingController(text: '${widget.account?['iban'] ?? ''}');
  late final _branch = TextEditingController(text: '${widget.account?['branch'] ?? ''}');
  late final _swift = TextEditingController(text: '${widget.account?['swift'] ?? ''}');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_provider, _title, _number, _iban, _branch, _swift]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String id, String label, TextEditingController c, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey(id),
          controller: c,
          style: PT.t(13.5),
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  Future<void> _save() async {
    if (_provider.text.trim().isEmpty || _title.text.trim().isEmpty || _number.text.trim().isEmpty) {
      setState(() => _error = 'Please fill provider, account title and number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'kind': _kind,
      'provider': _provider.text.trim(),
      'title': _title.text.trim(),
      'number': _number.text.trim(),
      'iban': _kind == 'bank' ? _iban.text.trim() : '',
      'branch': _kind == 'bank' ? _branch.text.trim() : '',
      'swift': _kind == 'bank' ? _swift.text.trim() : '',
    };
    final id = widget.account?['id'];
    final b = await PortalApi.post(id == null ? '/admin/payment-accounts' : '/admin/payment-accounts/$id', body);
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      portalToast(id == null ? 'Account added' : 'Account saved', sub: _title.text.trim());
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = PortalApi.msg(b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = _kind == 'bank';
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.account == null ? 'Add account' : 'Edit account', style: PT.t(17, w: FontWeight.w700)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'wallet', label: Text('Mobile wallet'), icon: Icon(Icons.phone_android_outlined)),
                ButtonSegment(value: 'bank', label: Text('Bank'), icon: Icon(Icons.account_balance_outlined)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            _field('pa_provider', 'Provider', _provider, hint: bank ? 'Soneri Bank' : 'JazzCash / EasyPaisa'),
            _field('pa_title', 'Account title', _title, hint: bank ? 'Fit Her (Private) Limited' : 'Shaista Khalid'),
            _field('pa_number', bank ? 'Account number' : 'Mobile number', _number, hint: bank ? '120014636405' : '03XXXXXXXXX'),
            if (bank) ...[
              _field('pa_iban', 'IBAN', _iban, hint: 'PK60SONE…'),
              _field('pa_branch', 'Branch', _branch, hint: 'Mall Road Branch, Lahore'),
              _field('pa_swift', 'SWIFT / BIC', _swift, hint: 'SONEPKKA'),
            ],
            if (_error != null) Text(_error!, style: PT.t(12.5, c: PT.red)),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: PT.t(13.5, c: PT.sage)),
        ),
        ElevatedButton(
          style: portalPrimary(),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
