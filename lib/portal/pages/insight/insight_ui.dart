import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';

/// Shared bits for the Insight pages (growth, metrics, reports).

/// GET with a longer timeout (growth numbers can take a while).
Future<Map<String, dynamic>> insightGet(String path,
    {Map<String, dynamic>? query, Duration timeout = const Duration(seconds: 45)}) async {
  final s = Get.find<PortalSession>();
  s.touch();
  final r = await Get.find<ApiProvider>().getData(path, query: query, headers: s.headers, timeout: timeout);
  final b = r.body;
  return b is Map ? Map<String, dynamic>.from(b) : {'status': '0', 'message': 'Could not reach the server.'};
}

List<Map<String, dynamic>> iList(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

Map<String, dynamic> iMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

num iNum(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

String iN(dynamic v, {String suffix = ''}) => v == null ? '–' : '$v$suffix';

String iMoney(dynamic v) {
  if (v is! num) return '–';
  final n = v.toDouble();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k';
  return n.toStringAsFixed(0);
}

String iDate(dynamic iso, {bool time = false}) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '${iso ?? ''}';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final base = '${d.day} ${m[d.month - 1]} ${d.year}';
  if (!time) return base;
  return '$base, ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

/// One number tile.
class Kpi {
  const Kpi(this.label, this.value, {this.sub, this.change});
  final String label;
  final String value;
  final String? sub;
  final dynamic change;
}

/// Grid of number tiles that fills the width.
Widget kpiGrid(List<Kpi> items, {double minTile = 190}) => LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minTile).floor().clamp(1, items.isEmpty ? 1 : items.length);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((k) {
          final ch = k.change is num ? k.change as num : null;
          return Container(
            width: w,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: PT.card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.label, style: PT.t(12, c: PT.sage)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Flexible(child: Text(k.value, style: PT.t(24, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                if (ch != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${ch >= 0 ? '▲' : '▼'} ${ch.abs()}%',
                        style: PT.t(11.5, w: FontWeight.w600, c: ch >= 0 ? PT.greenDark : PT.red)),
                  ),
                ],
              ]),
              if (k.sub != null) Text(k.sub!, style: PT.t(11.5, c: PT.sage), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          );
        }).toList(),
      );
    });

/// White card with a small caps title.
class InsightSection extends StatelessWidget {
  const InsightSection({super.key, required this.title, required this.child, this.note, this.trailing});
  final String title;
  final Widget child;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: PT.t(11.5, w: FontWeight.w700, c: PT.sage).copyWith(letterSpacing: .6)),
            ),
            if (trailing != null) trailing!,
          ]),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note!, style: PT.t(11.5, c: PT.sage))),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

/// Amber info strip.
class InsightNote extends StatelessWidget {
  const InsightNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFDF3DF), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: PT.t(12.5, c: const Color(0xFF7A4E0E), h: 1.4)),
      );
}

/// Label on the left, value on the right.
class InsightRow extends StatelessWidget {
  const InsightRow({super.key, required this.title, this.sub, required this.value, this.valueColor = PT.ink, this.onTap});
  final String title;
  final String? sub;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F3EC)))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: PT.t(13.5, w: FontWeight.w500)),
                if (sub != null && sub!.isNotEmpty) Text(sub!, style: PT.t(11.5, c: PT.sage)),
              ]),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right, style: PT.t(13.5, w: FontWeight.w600, c: valueColor)),
            ),
          ]),
        ),
      );
}

/// Label + value with a progress bar under it.
class InsightBar extends StatelessWidget {
  const InsightBar(this.label, this.value, this.fraction, {super.key});
  final String label;
  final String value;
  final num fraction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: PT.t(13))),
            Text(value, style: PT.t(13, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: const Color(0xFFEDF0EA),
              valueColor: const AlwaysStoppedAnimation(PT.green),
            ),
          ),
        ]),
      );
}

/// Puts cards in two columns when there is room, else one.
Widget insightColumns(List<Widget> items, {double breakAt = 900, double gap = 16}) =>
    LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakAt || items.length < 2) {
        return Column(children: [
          for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
        ]);
      }
      final left = <Widget>[];
      final right = <Widget>[];
      for (var i = 0; i < items.length; i++) {
        final col = i.isEven ? left : right;
        if (col.isNotEmpty) col.add(SizedBox(height: gap));
        col.add(items[i]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: left)),
        SizedBox(width: gap),
        Expanded(child: Column(children: right)),
      ]);
    });

/// Row of choice pills.
Widget insightPills<T>({required List<(T, String)> options, required T selected, required ValueChanged<T> onTap}) =>
    Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        ChoiceChip(
          label: Text(o.$2),
          selected: o.$1 == selected,
          onSelected: (_) => onTap(o.$1),
          showCheckmark: false,
          labelStyle: PT.t(12.5, w: FontWeight.w600, c: o.$1 == selected ? Colors.white : PT.ink),
          selectedColor: PT.green,
          backgroundColor: Colors.white,
          side: BorderSide(color: o.$1 == selected ? PT.green : PT.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
    ]);

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

/// WhatsApp number in 92xxxxxxxxxx form.
String waNumber(String phone) {
  var n = _digits(phone).replaceAll('+', '');
  if (n.startsWith('0')) n = '92${n.substring(1)}';
  return n;
}

/// WhatsApp + call buttons for a phone number (nothing when empty).
List<Widget> contactButtons(String? phone) {
  final p = _digits('${phone ?? ''}');
  if (p.isEmpty) return const [];
  return [
    IconButton(
      tooltip: 'WhatsApp',
      icon: const Icon(Icons.chat_rounded, color: PT.greenDark, size: 20),
      onPressed: () => launchUrl(Uri.parse('https://wa.me/${waNumber(p)}'), mode: LaunchMode.externalApplication),
    ),
    IconButton(
      tooltip: 'Call',
      icon: const Icon(Icons.call_rounded, color: PT.greenDark, size: 20),
      onPressed: () => launchUrl(Uri.parse('tel:$p')),
    ),
  ];
}

/// A woman to contact: dot, name, detail, phone, WhatsApp / call.
class PersonRow extends StatelessWidget {
  const PersonRow(this.p, {super.key});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final level = '${p['level'] ?? ''}';
    final dot = level == 'high' ? PT.red : (level == 'low' ? PT.sage : PT.amber);
    final phone = '${p['phone'] ?? ''}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F3EC)))),
      child: Row(children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name'] ?? 'Client'}', style: PT.t(13.5, w: FontWeight.w600)),
            Text('${p['detail'] ?? ''}', style: PT.t(12, c: PT.sage)),
          ]),
        ),
        if (phone.isNotEmpty && phone != 'null')
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SelectableText(phone, style: PT.t(12.5, c: PT.sage)),
          ),
        ...contactButtons(phone == 'null' ? '' : phone),
      ]),
    );
  }
}

/// Wide table inside a white card; scrolls both ways when needed.
class InsightTable extends StatefulWidget {
  const InsightTable({super.key, required this.columns, required this.rows, this.numeric = const {}});
  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int> numeric;

  @override
  State<InsightTable> createState() => _InsightTableState();
}

class _InsightTableState extends State<InsightTable> {
  final _v = ScrollController();
  final _h = ScrollController();

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: PT.card(),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, box) {
          return Scrollbar(
            controller: _v,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _v,
              child: Scrollbar(
                controller: _h,
                thumbVisibility: true,
                notificationPredicate: (n) => n.depth == 0,
                child: SingleChildScrollView(
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: box.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(PT.wash),
                      headingRowHeight: 42,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 64,
                      columnSpacing: 26,
                      headingTextStyle: PT.t(12, w: FontWeight.w700, c: PT.sage),
                      dataTextStyle: PT.t(13),
                      columns: [
                        for (var i = 0; i < widget.columns.length; i++)
                          DataColumn(label: Text(widget.columns[i]), numeric: widget.numeric.contains(i)),
                      ],
                      rows: [for (final r in widget.rows) DataRow(cells: [for (final c in r) DataCell(c)])],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

/// Search box used above lists.
Widget insightSearch(String key, String hint, ValueChanged<String> onChanged) => SizedBox(
      width: 340,
      child: TextField(
        key: ValueKey(key),
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded, size: 20)),
      ),
    );
