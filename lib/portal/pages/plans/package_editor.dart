import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'plans_data.dart';

/// Add or edit a package. [plan] = a plan from /admin/get_plans (edit), or null (add).
class PackageEditor extends StatefulWidget {
  const PackageEditor({super.key, this.plan, this.onDone, this.onCancel});
  final Map<String, dynamic>? plan;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  @override
  State<PackageEditor> createState() => _PackageEditorState();
}

class _PackageEditorState extends State<PackageEditor> {
  bool get _isEdit => widget.plan != null;
  late final _title = TextEditingController(text: '${widget.plan?['title'] ?? ''}');
  late final _short = TextEditingController(text: '${widget.plan?['shortDescription'] ?? ''}');
  late final _long = TextEditingController(text: '${widget.plan?['longDescription'] ?? ''}');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _subs = [];
  List<Map<String, dynamic>> _dietitians = [];
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _durations = [];
  int? _catId;
  int? _subId;
  int? _dietitianId;

  /// "countryId:durationId" → amount box.
  final Map<String, TextEditingController> _price = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in [_title, _short, _long, ..._price.values]) {
      c.dispose();
    }
    super.dispose();
  }

  static int? _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

  Future<void> _init() async {
    final r = await Future.wait([
      PlansData.categories(),
      PlansData.countries(),
      PlansData.durations(),
      PlansData.dietitians(),
    ]);
    if (!mounted) return;
    if (r[0] == null || r[1] == null || r[2] == null) {
      setState(() {
        _loading = false;
        _error = "Couldn't load categories, countries or durations. Please refresh.";
      });
      return;
    }
    _cats = r[0]!;
    _countries = r[1]!;
    _durations = r[2]!;
    _dietitians = r[3] ?? [];
    final p = widget.plan;
    _catId = _int(p?['catId']) ?? (_cats.isEmpty ? null : _int(_cats.first['id']));
    if (p != null) {
      for (final c in (p['countries'] as List? ?? const [])) {
        if (c is! Map) continue;
        for (final d in (c['duration'] as List? ?? const [])) {
          if (d is! Map) continue;
          _box(c['id'], d['id']).text = '${d['priceAmount'] ?? ''}';
        }
      }
    }
    await _loadSubs(prefer: _int(p?['subId']));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSubs({int? prefer}) async {
    if (_catId == null) return;
    final s = await PlansData.subCategories(_catId);
    if (!mounted) return;
    setState(() {
      _subs = s;
      _subId = s.any((e) => _int(e['id']) == prefer) ? prefer : (s.isEmpty ? null : _int(s.first['id']));
    });
  }

  TextEditingController _box(dynamic countryId, dynamic durationId) =>
      _price.putIfAbsent('$countryId:$durationId', () => TextEditingController());

  bool get _isWorkout {
    final c = _cats.where((e) => _int(e['id']) == _catId).firstOrNull;
    return '${c?['title'] ?? ''}'.trim().toLowerCase() == 'workout';
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _short.text.trim().isEmpty || _long.text.trim().isEmpty) {
      setState(() => _error = 'Please fill the package name and both descriptions.');
      return;
    }
    final countriesList = <Map<String, dynamic>>[];
    for (final c in _countries) {
      final list = <Map<String, dynamic>>[];
      for (final d in _durations) {
        final v = _price['${c['id']}:${d['id']}']?.text.trim() ?? '';
        if (v.isNotEmpty) list.add({'id': _int(d['id']), 'amount': v});
      }
      if (list.isNotEmpty) countriesList.add({'id': _int(c['id']), 'durationList': list});
    }
    if (countriesList.isEmpty) {
      setState(() => _error = 'Add at least one price (a country and a duration).');
      return;
    }
    if (!_isEdit && !_isWorkout && _dietitianId == null) {
      setState(() => _error = 'Please choose the dietitian for this package.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      if (_isEdit) 'id': '${widget.plan!['id']}',
      'title': _title.text.trim(),
      'shortDescription': _short.text.trim(),
      'longDescription': _long.text.trim(),
      'CategoryId': '$_catId',
      'subCategoryId': '${_subId ?? ''}',
      if (!_isEdit && !_isWorkout) 'dietitianId': '$_dietitianId',
      'countriesList': countriesList,
    };
    final b = await PortalApi.post(_isEdit ? '/admin/update_plan' : '/admin/add_plan', body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast(_isEdit ? 'Package saved' : 'Package added', sub: _title.text.trim());
      widget.onDone?.call();
    } else {
      setState(() => _error = PortalApi.msg(b));
    }
  }

  Widget _section(String title, String? sub, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(15, w: FontWeight.w700)),
          if (sub != null) Text(sub, style: PT.t(12.5, c: PT.sage)),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _dropdown(String id, String label, int? value, List<Map<String, dynamic>> items, String Function(Map) text,
          ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        key: ValueKey('$id-${items.length}'),
        value: items.any((e) => _int(e['id']) == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        style: PT.t(13.5),
        items: items.map((e) => DropdownMenuItem(value: _int(e['id']), child: Text(text(e)))).toList(),
        onChanged: onChanged,
      );

  Widget _priceGrid() {
    if (_countries.isEmpty || _durations.isEmpty) {
      return Text('Add a country and a time duration first (in the Plans menu).', style: PT.t(13, c: PT.amber));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(130),
        columnWidths: const {0: FixedColumnWidth(170)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text('COUNTRY', style: PT.t(11.5, w: FontWeight.w700, c: PT.sage))),
            ..._durations.map((d) => Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${d['duration']}'.toUpperCase(), style: PT.t(11.5, w: FontWeight.w700, c: PT.sage)),
                )),
          ]),
          ..._countries.map((c) => TableRow(children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('${c['name']}', style: PT.t(13, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                ..._durations.map((d) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: TextField(
                        key: ValueKey('price_${c['id']}_${d['id']}'),
                        controller: _box(c['id'], d['id']),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        style: PT.t(13),
                        decoration: InputDecoration(
                          hintText: '—',
                          prefixText: (c['currency'] ?? '').toString().isEmpty ? null : '${c['currency']} ',
                        ),
                      ),
                    )),
              ])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: _isEdit ? 'Edit package' : 'Add package',
        sub: _isEdit ? '${widget.plan!['title']}' : 'A new package clients can buy.',
        actions: [
          if (widget.onCancel != null)
            TextButton.icon(
              onPressed: _saving ? null : widget.onCancel,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to packages'),
            ),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Column(children: [
            _section(
              'About the package',
              null,
              Column(children: [
                TextField(
                  key: const ValueKey('pkg_title'),
                  controller: _title,
                  style: PT.t(13.5),
                  decoration: const InputDecoration(labelText: 'Package name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('pkg_short'),
                  controller: _short,
                  style: PT.t(13.5),
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Short description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('pkg_long'),
                  controller: _long,
                  style: PT.t(13.5),
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Long description'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _dropdown('pkg_cat', 'Category', _catId, _cats, (e) => '${e['title']}', (v) {
                      setState(() => _catId = v);
                      _loadSubs();
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown('pkg_sub', 'Sub-category', _subId, _subs, (e) => '${e['title']}',
                        (v) => setState(() => _subId = v)),
                  ),
                ]),
                if (!_isEdit && !_isWorkout) ...[
                  const SizedBox(height: 12),
                  _dropdown(
                    'pkg_dietitian',
                    'Dietitian for this package',
                    _dietitianId,
                    _dietitians,
                    (e) => '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim(),
                    (v) => setState(() => _dietitianId = v),
                  ),
                ],
              ]),
            ),
            _section(
              'Prices',
              'Type a price for each country and length you sell. Leave a box empty if you don\'t sell that one.',
              _priceGrid(),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        if (_error != null) Expanded(child: Text(_error!, style: PT.t(13, c: PT.red))) else const Spacer(),
        ElevatedButton.icon(
          style: portalPrimary(),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save package' : 'Add package')),
        ),
      ]),
    ]);
  }
}
