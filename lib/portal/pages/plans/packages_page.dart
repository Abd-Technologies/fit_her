import 'package:flutter/material.dart';

import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'package_editor.dart';
import 'plans_data.dart';

/// All packages with their prices. Edit opens the editor in place.
class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  List<Map<String, dynamic>>? _items;
  Map<int, String> _catNames = {};
  bool _loading = true;
  String _q = '';
  Map<String, dynamic>? _editing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await Future.wait([PlansData.plans(), PlansData.categories()]);
    if (r[0] == null) portalToast("Couldn't load packages", error: true);
    if (!mounted) return;
    setState(() {
      _items = r[0];
      _catNames = {for (final c in r[1] ?? const <Map<String, dynamic>>[]) (c['id'] as num).toInt(): '${c['title']}'};
      _loading = false;
    });
  }

  Widget _card(Map<String, dynamic> p) {
    final countries = (p['countries'] as List? ?? const []).whereType<Map>().toList();
    final cat = _catNames[(p['catId'] as num?)?.toInt()];
    return Container(
      width: 420,
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['title'] ?? ''}', style: PT.t(15.5, w: FontWeight.w700)),
              if (cat != null) ...[const SizedBox(height: 4), StatusChip(cat)],
            ]),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _editing = p),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${p['shortDescription'] ?? ''}', style: PT.t(12.5, c: PT.sage, h: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        ...countries.map((c) {
          final durs = (c['duration'] as List? ?? const []).whereType<Map>().toList()
            ..sort((a, b) => PlansData.daysOf(a['days']).compareTo(PlansData.daysOf(b['days'])));
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 100, child: Text('${c['name']}', style: PT.t(12.5, w: FontWeight.w600))),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: durs
                      .map((d) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(8)),
                            child: Text('${d['days']} · ${PlansData.money(d['priceAmount'], c['currency'])}',
                                style: PT.t(12)),
                          ))
                      .toList(),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editing != null) {
      return PackageEditor(
        key: ValueKey('edit-${_editing!['id']}'),
        plan: _editing,
        onCancel: () => setState(() => _editing = null),
        onDone: () {
          setState(() => _editing = null);
          _load();
        },
      );
    }
    final q = _q.trim().toLowerCase();
    final items = (_items ?? const <Map<String, dynamic>>[])
        .where((p) => q.isEmpty || '${p['title']}'.toLowerCase().contains(q))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Packages',
        sub: 'Every package clients can buy, with its price per country and length.',
        actions: [
          SizedBox(
            width: 240,
            child: TextField(
              key: const ValueKey('pkg_search'),
              onChanged: (v) => setState(() => _q = v),
              style: PT.t(13),
              decoration: const InputDecoration(hintText: 'Search packages', prefixIcon: Icon(Icons.search, size: 18)),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load packages",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? PortalEmpty(icon: Icons.inventory_2_outlined, title: q.isEmpty ? 'No packages yet' : 'No match')
                    : SingleChildScrollView(
                        child: Wrap(spacing: 14, runSpacing: 14, children: items.map(_card).toList()),
                      ),
      ),
    ]);
  }
}

/// "Add package" menu item.
class AddPackagePage extends StatefulWidget {
  const AddPackagePage({super.key});

  @override
  State<AddPackagePage> createState() => _AddPackagePageState();
}

class _AddPackagePageState extends State<AddPackagePage> {
  int _round = 0;

  @override
  Widget build(BuildContext context) =>
      PackageEditor(key: ValueKey('add-$_round'), onDone: () => setState(() => _round++));
}
