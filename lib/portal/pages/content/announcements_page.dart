import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Send an announcement to every client (app: Announcements tile,
/// RemindersScreen with isAnnouncement). Also lists the ones sent before.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  // Same limit as the app (server columns are TEXT since Oct 2026).
  static const _max = 500;

  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  List<Map<String, dynamic>>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/getAnnouncement');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['data'] is List) {
      list = (d['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      list.sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    } else {
      portalToast("Couldn't load announcements", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list ?? _items;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      portalToast('Please provide all information', sub: 'Write a title and a message.', error: true);
      return;
    }
    final sure = await portalConfirm(
      context,
      title: 'Send this announcement?',
      body: 'Every client with the app gets "$title" as a notification on her phone. This cannot be taken back.',
      yes: 'Send to everyone',
    );
    if (!sure) return;
    setState(() => _sending = true);
    final b = await PortalApi.post(Constants.addAnnouncement, {'title': title, 'body': body});
    if (!mounted) return;
    setState(() => _sending = false);
    if (PortalApi.ok(b)) {
      portalToast('Announcement sent', sub: PortalApi.msg(b, 'Sent to all clients.'));
      _title.clear();
      _body.clear();
      _load();
    } else {
      portalToast("Couldn't send", sub: PortalApi.msg(b), error: true);
    }
  }

  static String _date(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]} ${d.year}, $h:$mm ${d.hour < 12 ? 'am' : 'pm'}';
  }

  Widget _form() => Container(
        padding: const EdgeInsets.all(20),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New announcement', style: PT.t(16, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Goes to every client as a phone notification.', style: PT.t(12.5, c: PT.sage)),
          const SizedBox(height: 16),
          Text('Title', style: PT.t(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('announce_title'),
            controller: _title,
            maxLength: _max,
            enabled: !_sending,
            decoration: const InputDecoration(hintText: 'For example: New class timings'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('Message', style: PT.t(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('announce_body'),
            controller: _body,
            maxLength: _max,
            minLines: 4,
            maxLines: 8,
            enabled: !_sending,
            decoration: const InputDecoration(hintText: 'What do you want to tell everyone?'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty) ...[
            Text('Preview', style: PT.t(12, c: PT.sage)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notifications_active_outlined, size: 18, color: PT.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_title.text.trim().isEmpty ? 'Title' : _title.text.trim(),
                        style: PT.t(13, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_body.text.trim().isEmpty ? 'Message' : _body.text.trim(),
                        style: PT.t(12.5, c: PT.sage), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send'),
          ),
        ]),
      );

  Widget _past() {
    final items = _items ?? const <Map<String, dynamic>>[];
    Widget child;
    if (_loading && _items == null) {
      child = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    } else if (_items == null) {
      child = PortalEmpty(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load announcements",
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    } else if (items.isEmpty) {
      child = const PortalEmpty(
          icon: Icons.campaign_outlined, title: 'No announcements yet', sub: 'Ones you send show up here.');
    } else {
      child = ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: PT.line),
        itemBuilder: (_, i) {
          final a = items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
                child: const Icon(Icons.campaign_outlined, size: 18, color: PT.greenDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText('${a['title'] ?? ''}', style: PT.t(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  SelectableText('${a['body'] ?? ''}', style: PT.t(13, h: 1.45)),
                  const SizedBox(height: 4),
                  Text(_date(a['createdAt']), style: PT.t(11.5, c: PT.sage)),
                ]),
              ),
            ]),
          );
        },
      );
    }
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            Expanded(child: Text('Sent before', style: PT.t(15, w: FontWeight.w700))),
            if (_items != null) StatusChip('${items.length}'),
          ]),
        ),
        const Divider(height: 1, color: PT.line),
        Expanded(child: child),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Announcements',
        sub: 'Send a message to all clients. They get it as a notification on their phone.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: LayoutBuilder(builder: (c, box) {
          if (box.maxWidth >= 860) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 420, child: SingleChildScrollView(child: _form())),
              const SizedBox(width: 18),
              Expanded(child: _past()),
            ]);
          }
          return ListView(children: [
            _form(),
            const SizedBox(height: 18),
            SizedBox(height: 520, child: _past()),
          ]);
        }),
      ),
    ]);
  }
}
