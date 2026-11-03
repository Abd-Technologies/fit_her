import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'plans_data.dart';

/// Plan lengths (e.g. "30 days") that packages can be priced for.
class DurationsPage extends StatefulWidget {
  const DurationsPage({super.key});

  @override
  State<DurationsPage> createState() => _DurationsPageState();
}

class _DurationsPageState extends State<DurationsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  bool _saving = false;
  final _days = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final l = await PlansData.durations();
    if (l == null) portalToast("Couldn't load durations", error: true);
    if (!mounted) return;
    setState(() {
      _items = l;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final n = int.tryParse(_days.text.trim());
    if (n == null || n <= 0) {
      portalToast('Type the number of days', sub: 'For example 30', error: true);
      return;
    }
    final text = '$n days';
    if ((_items ?? []).any((d) => '${d['duration']}'.trim().toLowerCase() == text)) {
      portalToast('Already added', sub: text, error: true);
      return;
    }
    setState(() => _saving = true);
    final b = await PortalApi.post('/duration/create', {'duration': text, 'countryId': null});
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      _days.clear();
      portalToast('Duration added', sub: text);
      _load();
    } else {
      portalToast("Couldn't add", sub: PortalApi.msg(b), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Time durations',
        sub: 'Plan lengths you can set a price for in a package. Add one here, then set its price in Packages.',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: PT.card(),
        child: Row(children: [
          SizedBox(
            width: 200,
            child: TextField(
              key: const ValueKey('duration_days'),
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              onSubmitted: (_) => _add(),
              style: PT.t(13.5),
              decoration: const InputDecoration(labelText: 'Number of days', hintText: '30', suffixText: 'days'),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_saving ? 'Adding…' : 'Add duration'),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load durations",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.timelapse_outlined, title: 'No durations yet')
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: items
                              .map((d) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: PT.card(),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.timelapse_outlined, size: 18, color: PT.green),
                                      const SizedBox(width: 8),
                                      Text('${d['duration'] ?? ''}', style: PT.t(14, w: FontWeight.w600)),
                                    ]),
                                  ))
                              .toList(),
                        ),
                      ),
      ),
    ]);
  }
}
