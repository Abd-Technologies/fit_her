import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'plans_data.dart';

/// Countries a package can be priced for.
class CountriesPage extends StatefulWidget {
  const CountriesPage({super.key});

  @override
  State<CountriesPage> createState() => _CountriesPageState();
}

class _CountriesPageState extends State<CountriesPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final l = await PlansData.countries();
    if (l == null) portalToast("Couldn't load countries", error: true);
    if (!mounted) return;
    setState(() {
      _items = l;
      _loading = false;
    });
  }

  void _pick() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: 520,
        borderRadius: BorderRadius.circular(18),
        inputDecoration: const InputDecoration(labelText: 'Search country', prefixIcon: Icon(Icons.search)),
      ),
      onSelect: _add,
    );
  }

  Future<void> _add(Country c) async {
    if ((_items ?? []).any((e) => '${e['name']}'.toLowerCase() == c.name.toLowerCase())) {
      portalToast('Already added', sub: c.name, error: true);
      return;
    }
    setState(() => _saving = true);
    final b = await PortalApi.post('/country', {'code': c.countryCode, 'name': c.name});
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast('Country added', sub: '${c.name} · now set its prices in Packages');
      _load();
    } else {
      portalToast("Couldn't add", sub: PortalApi.msg(b), error: true);
    }
  }

  String _flag(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c.length != 2) return '🌍';
    return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Countries',
        sub: 'Countries a package can have a price for. Clients see the price for their own country.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_saving ? 'Adding…' : 'Add country'),
          ),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load countries",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.public_outlined, title: 'No countries yet')
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: items
                              .map((c) => Container(
                                    width: 240,
                                    padding: const EdgeInsets.all(14),
                                    decoration: PT.card(),
                                    child: Row(children: [
                                      Text(_flag(c['code']?.toString()), style: const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('${c['name'] ?? ''}',
                                              style: PT.t(14, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                          Text(
                                            [c['code'], c['currency']]
                                                .where((v) => v != null && '$v'.isNotEmpty)
                                                .join(' · '),
                                            style: PT.t(12, c: PT.sage),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ))
                              .toList(),
                        ),
                      ),
      ),
    ]);
  }
}
