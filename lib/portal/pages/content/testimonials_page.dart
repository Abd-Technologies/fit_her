import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Testimonial pictures shown to clients (app: Add Testimonials tile,
/// MyDailyMeal with isTestimonials). A testimonial is only a photo, so
/// adding one is done in the mobile app. Here the team can see them all.
class TestimonialsPage extends StatefulWidget {
  const TestimonialsPage({super.key});

  @override
  State<TestimonialsPage> createState() => _TestimonialsPageState();
}

class _TestimonialsPageState extends State<TestimonialsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/get_testimonials');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is List) {
      list = d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      list.sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    } else {
      portalToast("Couldn't load testimonials", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list ?? _items;
      _loading = false;
    });
  }

  Widget _tile(Map<String, dynamic> t) {
    final path = '${t['image'] ?? ''}'.trim();
    final url = path.isEmpty ? null : PortalApi.file(path);
    final on = t['status'] == true || '${t['status']}' == '1';
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Container(
            color: const Color(0xFFF1F4EE),
            child: url == null
                ? Center(child: Text('No picture', style: PT.t(12.5, c: PT.sage)))
                : InkWell(
                    onTap: () => portalShowImage(context, url),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Center(child: Text("Couldn't load the picture", style: PT.t(12, c: PT.sage))),
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(
                portalAgo(t['createdAt']).isEmpty ? 'Testimonial' : 'Added ${portalAgo(t['createdAt'])}',
                style: PT.t(12, c: PT.sage),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusChip(on ? 'Showing' : 'Hidden', color: on ? PT.green : PT.sage),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Testimonials',
        sub: 'Pictures of happy client reviews that show in the app. Click a picture to see it full size.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${items.length} pictures')),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: mobileOnlyNote('Adding a testimonial (it is a photo)'),
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load testimonials",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(
                        icon: Icons.format_quote_rounded,
                        title: 'No testimonials yet',
                        sub: 'Add one from the mobile app and it shows up here.')
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _tile(items[i]),
                      ),
      ),
    ]);
  }
}
