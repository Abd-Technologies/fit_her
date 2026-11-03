import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';
import 'plan_editor.dart';

/// Every AI draft plan this dietitian made that is still waiting for her
/// review (app: DraftsDashboardScreen → PlanReviewEditScreen).
class DietDraftsPage extends StatefulWidget {
  const DietDraftsPage({super.key});

  @override
  State<DietDraftsPage> createState() => _DietDraftsPageState();
}

class _DietDraftsPageState extends State<DietDraftsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
  int? _selId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get('/admin/diet-plan/drafts');
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      final list = dpList(dpMap(b['data'])['plans']);
      setState(() {
        _items = list;
        _loading = false;
        if (_selId != null && !list.any((e) => dpInt(e['id']) == _selId)) _selId = null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = PortalApi.msg(b, "Couldn't load your drafts.");
      });
      if (_items != null) portalToast("Couldn't refresh drafts", sub: _error, error: true);
    }
  }

  Widget _tile(Map<String, dynamic> p, bool sel) {
    final id = dpInt(p['id']);
    final name = dpUserName(p['User'], 'Client #${p['userId'] ?? '?'}');
    final img = '${dpMap(p['User'])['image'] ?? dpMap(p['User'])['profileImage'] ?? ''}'.trim();
    final url = img.isEmpty ? null : PortalApi.file(img);
    final avg = dpAvgKcal(p);
    final made = portalAgo(p['createdAt']);
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: PT.wash,
              foregroundImage: url == null ? null : NetworkImage(url),
              onForegroundImageError: url == null ? null : (_, __) {},
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: PT.t(13.5, w: FontWeight.w700, c: PT.greenDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: PT.t(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${dpInt(p['planDays']) ?? 0} days · ${dpInt(p['mealsPerDay']) ?? 0} meals a day'
                  '${avg > 0 ? ' · ${dpKcal(avg)} kcal' : ''}',
                  style: PT.t(12, c: PT.sage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const StatusChip('Draft', color: PT.amber),
              if (made.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(made, style: PT.t(11, c: PT.sage)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, int? selId) => Container(
        decoration: PT.card(),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          children: items.map((p) => _tile(p, dpInt(p['id']) == selId)).toList(),
        ),
      );

  Widget _editor(Map<String, dynamic> p, {VoidCallback? onBack}) {
    final id = dpInt(p['id']) ?? 0;
    return DietPlanEditor(
      key: ValueKey('dp_draft_$id'),
      planId: id,
      clientName: dpUserName(p['User'], ''),
      onBack: onBack,
      backLabel: 'Back to drafts',
      onChanged: _load,
    );
  }

  Widget _body() {
    if (_loading && _items == null) return const Center(child: CircularProgressIndicator(color: PT.green));
    if (_items == null) {
      return PortalEmpty(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your drafts",
        sub: _error,
        action: ElevatedButton(style: portalPrimary(), onPressed: _load, child: const Text('Try again')),
      );
    }
    final items = _items!;
    if (items.isEmpty) {
      return PortalEmpty(
        icon: Icons.restaurant_menu_rounded,
        title: 'All caught up',
        sub: "No drafts waiting for review. Make a new plan for a client when you're ready.",
        action: ElevatedButton.icon(
          style: portalPrimary(),
          onPressed: () => portalGo('d_generate'),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Generate new plan'),
        ),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 900) {
        final sel = items.firstWhere((e) => dpInt(e['id']) == _selId, orElse: () => items.first);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 340, child: _list(items, dpInt(sel['id']))),
          const SizedBox(width: 16),
          Expanded(child: _editor(sel)),
        ]);
      }
      final open = items.where((e) => dpInt(e['id']) == _selId).toList();
      if (open.isNotEmpty) return _editor(open.first, onBack: () => setState(() => _selId = null));
      return _list(items, null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _items?.length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Drafts to review',
        sub: 'AI plans you made that are waiting for your check. Open one, fix any meal, '
            'then activate it so your client can see it.',
        actions: [
          if (n > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: StatusChip('$n pending', color: PT.amber),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PT.green))
                : const Icon(Icons.refresh_rounded, color: PT.sage),
          ),
          IconButton(
            tooltip: 'Generate a new plan',
            onPressed: () => portalGo('d_generate'),
            icon: const Icon(Icons.auto_awesome_rounded, color: PT.green),
          ),
        ],
      ),
      Expanded(child: _body()),
    ]);
  }
}
