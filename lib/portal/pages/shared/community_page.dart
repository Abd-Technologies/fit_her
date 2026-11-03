import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Community feed for trainers and dietitians (app: FeedScreen,
/// PostDetailScreen, CreatePostScreen). Staff can always post and reply.
/// Read, like, reply, write a text post, edit or delete your own post.
/// Adding photos stays in the mobile app.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  static const int _max = 500;

  List<Map<String, dynamic>>? _posts;
  bool _loading = true;
  final _newCtrl = TextEditingController();
  bool _posting = false;

  final Set<int> _open = {}; // posts with replies shown
  final Map<int, TextEditingController> _replyCtrls = {};
  final Set<int> _sending = {};
  final Set<int> _liking = {};

  PortalSession get _s => Get.find<PortalSession>();
  String get _myId => '${_s.userId ?? 0}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  static int _id(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  /// Like state the same way the app works it out.
  void _prep(Map<String, dynamic> p) {
    final likes = _list(p['likes']);
    p['messages'] = _list(p['messages']);
    p['_liked'] = p['isLiked'] == true || likes.any((l) => '${l['userId']}' == _myId);
    p['_likes'] = p['likeCount'] is num ? (p['likeCount'] as num).toInt() : likes.length;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final b = await PortalApi.get('${Constants.getAllPosts}true');
    List<Map<String, dynamic>>? posts;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['posts'] is List) {
      // Newest first. The server sends oldest first.
      posts = _list(d['posts']).where((p) => p['approved'] == true && p['isPost'] == true).toList().reversed.toList();
      for (final p in posts) {
        _prep(p);
      }
    } else if (!silent) {
      portalToast("Couldn't load the feed", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _posts = posts ?? _posts;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final r = await Get.find<ApiProvider>().deleteData(path, headers: _s.headers);
      final b = r.body;
      if (b is Map) return Map<String, dynamic>.from(b);
    } catch (_) {}
    return {'status': '0', 'message': "Couldn't reach the server."};
  }

  // ---------- author ----------

  static Map<String, dynamic> _user(dynamic u) => u is Map ? Map<String, dynamic>.from(u) : <String, dynamic>{};

  static String _name(Map<String, dynamic> u) {
    String part(dynamic v) => v == null ? '' : '$v'.trim();
    final n = [part(u['firstName']), part(u['lastName'])].where((e) => e.isNotEmpty).join(' ');
    return n.isEmpty ? 'Member' : n;
  }

  static String _role(dynamic t) {
    switch ('${t ?? ''}') {
      case 'Trainer':
        return 'Trainer';
      case 'Dietition':
        return 'Dietitian';
      case 'Gynecologist':
        return 'Gynaecologist';
      case 'Psychiatrist':
        return 'Psychiatrist';
      case 'Admin':
        return 'FitHer team';
    }
    return 'Member';
  }

  Widget _avatar(Map<String, dynamic> u, double r) {
    final name = _name(u);
    final img = '${u['image'] ?? ''}'.trim();
    final url = img.isEmpty || img == 'null' ? null : PortalApi.file(img);
    return CircleAvatar(
      radius: r,
      backgroundColor: const Color(0xFFEAF7E4),
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(name.substring(0, 1).toUpperCase(), style: PT.t(r * 0.8, w: FontWeight.w700, c: PT.greenDark)),
    );
  }

  Widget _who(Map<String, dynamic> u, dynamic createdAt, {double size = 13.5}) {
    final staff = u['userType'] != null && '${u['userType']}' != 'User';
    return Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(_name(u), style: PT.t(size, w: FontWeight.w700)),
      StatusChip(_role(u['userType']), color: staff ? PT.green : PT.sage),
      Text('· ${portalAgo(createdAt)}', style: PT.t(11.5, c: PT.sage)),
    ]);
  }

  // ---------- actions ----------

  Future<void> _share() async {
    final text = _newCtrl.text.trim();
    if (text.isEmpty || _posting) {
      if (text.isEmpty) portalToast('Please write something first', error: true);
      return;
    }
    setState(() => _posting = true);
    final b = await PortalApi.post(Constants.createPost, {'text': text, 'isPost': true, 'userId': _myId});
    if (!mounted) return;
    setState(() => _posting = false);
    if (PortalApi.ok(b)) {
      _newCtrl.clear();
      final d = b['data'];
      final post = d is Map ? d['post'] : null;
      if (post is Map && post['approved'] == false) {
        portalToast('Thanks!', sub: 'Your post will show once our team has had a quick look.');
      } else {
        portalToast('Post shared', sub: PortalApi.msg(b, 'It is now in the community feed.'));
        _load(silent: true);
      }
    } else {
      portalToast("Couldn't share the post", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _like(Map<String, dynamic> p) async {
    final id = _id(p['id']);
    if (_liking.contains(id)) return;
    // Optimistic: flip the heart at once, undo if the call fails.
    final before = p['_liked'] == true;
    setState(() {
      _liking.add(id);
      p['_liked'] = !before;
      p['_likes'] = ((p['_likes'] as int) + (before ? -1 : 1)).clamp(0, 1 << 30);
    });
    final b = await PortalApi.post(Constants.likePost, {'postId': '$id', 'userId': _myId});
    if (!mounted) return;
    setState(() {
      _liking.remove(id);
      if (PortalApi.ok(b)) {
        // Trust the server on the final state.
        final liked = PortalApi.msg(b) != 'Like removed';
        if ((p['_liked'] == true) != liked) {
          p['_liked'] = liked;
          p['_likes'] = ((p['_likes'] as int) + (liked ? 1 : -1)).clamp(0, 1 << 30);
        }
      } else {
        p['_liked'] = before;
        p['_likes'] = ((p['_likes'] as int) + (before ? 1 : -1)).clamp(0, 1 << 30);
      }
    });
    if (!PortalApi.ok(b)) portalToast("Couldn't update like", sub: PortalApi.msg(b, 'Please try again.'), error: true);
  }

  TextEditingController _replyCtrl(int id) => _replyCtrls.putIfAbsent(id, () => TextEditingController());

  Future<void> _reply(Map<String, dynamic> p) async {
    final id = _id(p['id']);
    final ctl = _replyCtrl(id);
    final text = ctl.text.trim();
    if (text.isEmpty || _sending.contains(id)) return;
    setState(() => _sending.add(id));
    final b = await PortalApi.post(Constants.sendReply, {'postId': '$id', 'userId': _myId, 'text': text});
    if (!mounted) return;
    setState(() {
      _sending.remove(id);
      if (PortalApi.ok(b)) {
        ctl.clear();
        final d = b['data'];
        final r = d is Map ? d['reply'] : null;
        final list = p['messages'] as List<Map<String, dynamic>>;
        if (r is Map) {
          final reply = Map<String, dynamic>.from(r);
          if (!list.any((x) => _id(x['id']) == _id(reply['id']))) list.add(reply);
        }
      }
    });
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't send", sub: PortalApi.msg(b, 'Please try again.'), error: true);
    } else if ((b['data'] is! Map) || (b['data'] as Map)['reply'] is! Map) {
      _load(silent: true);
    }
  }

  void _replyTo(int postId, Map<String, dynamic> u) {
    final first = _name(u).split(' ').first;
    final ctl = _replyCtrl(postId);
    ctl.text = '@$first ';
    ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
    setState(() => _open.add(postId));
  }

  Future<void> _deletePost(Map<String, dynamic> p) async {
    final id = _id(p['id']);
    final sure = await portalConfirm(context,
        title: 'Delete this post?', body: "This can't be undone.", yes: 'Delete post', danger: true);
    if (!sure) return;
    final b = await _delete('${Constants.deletePost}/$id');
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      portalToast('Post deleted');
      setState(() => _posts?.removeWhere((e) => _id(e['id']) == id));
    } else {
      portalToast("Couldn't delete", sub: PortalApi.msg(b, 'Please try again.'), error: true);
    }
  }

  Future<void> _editPost(Map<String, dynamic> p) async {
    final id = _id(p['id']);
    final ctl = TextEditingController(text: p['text'] == null ? '' : '${p['text']}');
    final hasImage = '${p['imageUrl'] ?? ''}'.trim().isNotEmpty && '${p['imageUrl']}' != 'null';
    var removeImage = false;
    var saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        Future<void> save() async {
          final text = ctl.text.trim();
          if (text.isEmpty && (!hasImage || removeImage)) {
            portalToast('Please write something first', error: true);
            return;
          }
          setD(() => saving = true);
          final b = await PortalApi.post('/posts/edit/$id', {'text': text, 'removeImage': removeImage.toString()});
          setD(() => saving = false);
          if (PortalApi.ok(b)) {
            final d = b['data'];
            final j = d is Map ? d['post'] : null;
            if (mounted) {
              setState(() {
                if (j is Map && j['approved'] == false) {
                  _posts?.removeWhere((e) => _id(e['id']) == id);
                } else {
                  p['text'] = j is Map ? j['text'] : text;
                  if (j is Map) {
                    p['imageUrl'] = j['imageUrl'];
                  } else if (removeImage) {
                    p['imageUrl'] = null;
                  }
                }
              });
            }
            portalToast(PortalApi.msg(b, 'Post updated'));
            if (c.mounted) Navigator.pop(c);
          } else {
            portalToast("Couldn't update", sub: PortalApi.msg(b, 'Please try again.'), error: true);
          }
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Edit post', style: PT.t(17, w: FontWeight.w700)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                key: const ValueKey('community_edit_text'),
                controller: ctl,
                minLines: 4,
                maxLines: 8,
                maxLength: _max,
                decoration: const InputDecoration(hintText: 'Write your post'),
              ),
              if (hasImage)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: removeImage,
                  onChanged: saving ? null : (v) => setD(() => removeImage = v == true),
                  title: Text('Remove the photo', style: PT.t(13)),
                ),
              const SizedBox(height: 4),
              mobileOnlyNote('Changing the photo'),
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
                  : const Text('Save'),
            ),
          ],
        );
      }),
    );
    ctl.dispose();
  }

  // ---------- pieces ----------

  Widget _composer() {
    final me = <String, dynamic>{
      'firstName': '${_s.user.value?['firstName'] ?? ''}',
      'lastName': '${_s.user.value?['lastName'] ?? ''}',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(me, 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('community_new_text'),
              controller: _newCtrl,
              minLines: 2,
              maxLines: 6,
              maxLength: _max,
              decoration: const InputDecoration(hintText: 'Share a meal, a win or a question…'),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: mobileOnlyNote('Adding a photo')),
            ElevatedButton(
              style: portalPrimary(),
              onPressed: _posting ? null : _share,
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post'),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final id = _id(p['id']);
    final u = _user(p['User']);
    final mine = '${u['id'] ?? p['userId']}' == _myId;
    final admin = _s.role == PortalRole.admin;
    final text = '${p['text'] ?? ''}'.trim();
    final imgPath = '${p['imageUrl'] ?? ''}'.trim();
    final img = imgPath.isEmpty || imgPath == 'null' ? null : PortalApi.file(imgPath);
    final replies = p['messages'] as List<Map<String, dynamic>>;
    final open = _open.contains(id);
    final liked = p['_liked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(u, 18),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: _who(u, p['createdAt']))),
          if (mine || admin)
            PopupMenuButton<String>(
              tooltip: mine ? 'Your post' : 'Post options',
              icon: const Icon(Icons.more_horiz_rounded, color: PT.sage),
              onSelected: (v) {
                if (v == 'edit') _editPost(p);
                if (v == 'delete') _deletePost(p);
              },
              itemBuilder: (_) => [
                if (mine) const PopupMenuItem(value: 'edit', child: Text('Edit post')),
                const PopupMenuItem(value: 'delete', child: Text('Delete post', style: TextStyle(color: PT.red))),
              ],
            ),
        ]),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 10),
          SelectableText(text, style: PT.t(13.5, h: 1.5)),
        ],
        if (img != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => portalShowImage(context, img),
              child: Container(
                color: const Color(0xFFF1F4EE),
                constraints: const BoxConstraints(maxHeight: 380),
                width: double.infinity,
                child: Image.network(
                  img,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: 140,
                    child: Center(child: Text("Couldn't load the photo", style: PT.t(12.5, c: PT.sage))),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
            onPressed: () => _like(p),
            icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18, color: liked ? const Color(0xFFD9534F) : PT.sage),
            label: Text('${p['_likes'] ?? 0}', style: PT.t(12.5, w: FontWeight.w600, c: PT.sage)),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () => setState(() => open ? _open.remove(id) : _open.add(id)),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: PT.sage),
            label: Text(
              replies.isEmpty ? 'Reply' : '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
              style: PT.t(12.5, w: FontWeight.w600, c: PT.sage),
            ),
          ),
        ]),
        if (!open && replies.isNotEmpty) _replyPeek(id, replies.first),
        if (open) _replies(p, id, replies),
      ]),
    );
  }

  Widget _replyPeek(int postId, Map<String, dynamic> r) {
    final u = _user(r['User']);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _open.add(postId)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(u, 11),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name(u), style: PT.t(12, w: FontWeight.w700)),
              Text('${r['text'] ?? ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(12, c: PT.sage, h: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _replies(Map<String, dynamic> p, int id, List<Map<String, dynamic>> replies) {
    final ctl = _replyCtrl(id);
    final busy = _sending.contains(id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (replies.isEmpty) Text('No replies yet. Be the first to reply.', style: PT.t(12.5, c: PT.sage)),
        for (final r in replies)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _avatar(_user(r['User']), 13),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _who(_user(r['User']), r['createdAt'], size: 12.5),
                  const SizedBox(height: 2),
                  SelectableText('${r['text'] ?? ''}', style: PT.t(12.5, h: 1.45)),
                ]),
              ),
              TextButton(
                onPressed: () => _replyTo(id, _user(r['User'])),
                child: Text('Reply', style: PT.t(11.5, w: FontWeight.w600, c: PT.sage)),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: TextField(
              key: ValueKey('community_reply_$id'),
              controller: ctl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Write a reply…'),
              onSubmitted: (_) => _reply(p),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send',
            onPressed: busy ? null : () => _reply(p),
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: PT.green),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts ?? const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Community',
        sub: 'The FitHer feed clients see in the app. Like, reply and share posts. New posts show after you refresh.',
        actions: [
          IconButton(
              tooltip: 'Refresh', onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _posts == null
            ? const Center(child: CircularProgressIndicator())
            : _posts == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the feed",
                    action: TextButton(onPressed: () => _load(), child: const Text('Try again')),
                  )
                : SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _composer(),
                          const SizedBox(height: 16),
                          if (posts.isEmpty)
                            const PortalEmpty(
                              icon: Icons.forum_outlined,
                              title: 'No posts yet',
                              sub: 'Be the first to share a meal or a win.',
                            )
                          else
                            for (final p in posts) _postCard(p),
                        ]),
                      ),
                    ),
                  ),
      ),
    ]);
  }
}
