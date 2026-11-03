import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Community posts waiting for review (app: Posts Check / AdminApprovePosts).
/// Approve puts the post in the feed. Reject deletes it.
class PostsReviewPage extends StatefulWidget {
  const PostsReviewPage({super.key});

  @override
  State<PostsReviewPage> createState() => _PostsReviewPageState();
}

class _PostsReviewPageState extends State<PostsReviewPage> {
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
    final b = await PortalApi.get('${Constants.getAllPosts}false');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['posts'] is List) {
      list = (d['posts'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load posts", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list ?? _items;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _send(Future<dynamic> Function(ApiProvider api, Map<String, String> h) fn) async {
    try {
      final r = await fn(Get.find<ApiProvider>(), Get.find<PortalSession>().headers);
      final b = r.body;
      if (b is Map) return Map<String, dynamic>.from(b);
    } catch (_) {}
    return {'status': '0', 'message': "Couldn't reach the server."};
  }

  static String _name(Map<String, dynamic> p) {
    final u = p['User'] is Map ? p['User'] as Map : const {};
    final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    return n.isEmpty ? 'Unknown' : n;
  }

  Future<void> _decide(Map<String, dynamic> p, {required bool reject}) async {
    final id = (p['id'] as num).toInt();
    final name = _name(p);
    final sure = await portalConfirm(
      context,
      title: reject ? 'Reject this post?' : 'Approve this post?',
      body: reject
          ? "The post by $name will be deleted. This can't be undone."
          : 'The post by $name will show in the community feed for everyone.',
      yes: reject ? 'Reject and delete' : 'Approve',
      danger: reject,
    );
    if (!sure) return;
    setState(() => _busy.add(id));
    final b = reject
        ? await _send((api, h) => api.deleteData('${Constants.deletePost}/$id', headers: h))
        : await _send((api, h) => api.putData('${Constants.approvePost}/$id', body: {'approved': true}, headers: h));
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(reject ? 'Post rejected' : 'Post approved', sub: name);
      setState(() => _items?.removeWhere((e) => e['id'] == id));
    } else {
      portalToast("Couldn't save", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _newPost() async {
    final ctl = TextEditingController();
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        Future<void> save() async {
          final text = ctl.text.trim();
          if (text.isEmpty) {
            portalToast('Please write something first', error: true);
            return;
          }
          setD(() => saving = true);
          final b = await PortalApi.post(Constants.createPost, {
            'text': text,
            'isPost': true,
            'userId': '${Get.find<PortalSession>().userId ?? 0}',
          });
          setD(() => saving = false);
          if (PortalApi.ok(b)) {
            portalToast('Post shared', sub: 'It is now in the community feed.');
            if (c.mounted) Navigator.pop(c);
          } else {
            portalToast("Couldn't share the post", sub: PortalApi.msg(b), error: true);
          }
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('New community post', style: PT.t(17, w: FontWeight.w700)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                key: const ValueKey('posts_new_text'),
                controller: ctl,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(hintText: 'Write your post'),
              ),
              const SizedBox(height: 8),
              mobileOnlyNote('Adding a photo to a post'),
              const SizedBox(height: 8),
              Text('Posts from the team go straight to the feed.', style: PT.t(12, c: PT.sage)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(c), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
            ElevatedButton(
              style: portalPrimary(),
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Share post'),
            ),
          ],
        );
      }),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final id = (p['id'] as num).toInt();
    final u = p['User'] is Map ? Map<String, dynamic>.from(p['User']) : <String, dynamic>{};
    final name = _name(p);
    final text = '${p['text'] ?? ''}'.trim();
    final imgPath = '${p['imageUrl'] ?? ''}'.trim();
    final img = imgPath.isEmpty ? null : PortalApi.file(imgPath);
    final avatarPath = '${u['image'] ?? ''}'.trim();
    final avatar = avatarPath.isEmpty ? null : PortalApi.file(avatarPath);
    final role = '${u['userType'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEAF7E4),
            foregroundImage: avatar == null ? null : NetworkImage(avatar),
            child: Text(name.substring(0, 1).toUpperCase(), style: PT.t(14, w: FontWeight.w700, c: PT.greenDark)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: PT.t(13.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(
                [if (role.isNotEmpty && role != 'User') role, if (u['email'] != null) '${u['email']}'].join(' · '),
                style: PT.t(11.5, c: PT.sage),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Text(portalAgo(p['createdAt']), style: PT.t(11.5, c: PT.sage)),
        ]),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 12),
          SelectableText(text, style: PT.t(13.5, h: 1.5)),
        ],
        if (img != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => portalShowImage(context, img),
              child: Container(
                color: const Color(0xFFF1F4EE),
                constraints: const BoxConstraints(maxHeight: 360),
                width: double.infinity,
                child: Image.network(
                  img,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: 160,
                    child: Center(child: Text("Couldn't load the photo", style: PT.t(12.5, c: PT.sage))),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Click the photo to see it full size', style: PT.t(11, c: PT.sage)),
        ],
        if (text.isEmpty && img == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('This post is empty.', style: PT.t(12.5, c: PT.sage)),
          ),
        const SizedBox(height: 14),
        _busy.contains(id)
            ? const Center(
                child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2.4)))
            : Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: portalPrimary(),
                    onPressed: () => _decide(p, reject: false),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: portalDanger(),
                    onPressed: () => _decide(p, reject: true),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
              ]),
      ]),
    );
  }

  Widget _grid(List<Map<String, dynamic>> items) => LayoutBuilder(builder: (c, box) {
        final int cols = (box.maxWidth / 400).floor().clamp(1, 3).toInt();
        final columns = List.generate(cols, (_) => <Widget>[]);
        for (var i = 0; i < items.length; i++) {
          columns[i % cols].add(_card(items[i]));
        }
        return SingleChildScrollView(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cols; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns[i])),
            ],
          ]),
        );
      });

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Posts to check',
        sub: 'Photo posts from clients wait here before they show in the community feed. Approve to publish, or reject to delete.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${items.length} waiting')),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OutlinedButton.icon(
              onPressed: _newPost,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('New post'),
            ),
          ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load posts",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(
                        icon: Icons.task_alt_rounded, title: 'No posts waiting', sub: 'New posts to check show up here.')
                    : _grid(items),
      ),
    ]);
  }
}
