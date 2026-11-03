import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../portal_session.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Staff chat. Same Firestore data as the app's ChatHomeScreen / ChatRoom:
///   users/{myId}/myusers/{otherId}  -> conversation list (name, time, newMessageArrived, deviceToken)
///   chatRoom/{roomId}/allMessages     -> messages (sendBy, name, message, time)
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

/// The app builds roomId as (myId.hashCode + otherId.hashCode).toString()
/// on the phone (Dart VM). String.hashCode is different on the web, so the
/// VM hash is re-done here by hand.
int _vmStringHash(String s, {int bits = 30}) {
  const m = 0xFFFFFFFF;
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h + c) & m;
    h = (h + ((h << 10) & m)) & m;
    h = (h ^ (h >> 6)) & m;
  }
  h = (h + ((h << 3) & m)) & m;
  h = (h ^ (h >> 11)) & m;
  h = (h + ((h << 15) & m)) & m;
  if (bits < 32) h = h & ((1 << bits) - 1);
  return h == 0 ? 1 : h;
}

/// Room ids to try, most likely first.
List<String> _roomCandidates(String a, String b) {
  final out = <String>[
    (_vmStringHash(a) + _vmStringHash(b)).toString(),
    (_vmStringHash(a, bits: 32) + _vmStringHash(b, bits: 32)).toString(),
    (a.hashCode + b.hashCode).toString(), // made by a web build of the app
  ];
  return out.toSet().toList();
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _msgTime(dynamic v) {
  final d = _toDate(v)?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  final hm = '${_two(d.hour)}:${_two(d.minute)}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
  return '${_two(d.day)}/${_two(d.month)}/${d.year} $hm';
}

class _ChatPageState extends State<ChatPage> {
  final _session = Get.find<PortalSession>();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _search = TextEditingController();
  final Map<String, Future<String>> _rooms = {};
  String? _selId;
  Map<String, dynamic>? _selData;
  bool _sending = false;
  String _filter = '';
  String? _clearing;

  bool get _ready => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String get _myId => '${_session.userId ?? ''}';

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _myUsers(String uid) =>
      _fs.collection('users').doc(uid).collection('myusers');

  CollectionReference<Map<String, dynamic>> _messages(String room) =>
      _fs.collection(Constants.chatRoom).doc(room).collection(Constants.allMessages);

  /// Finds the room that already has messages; else the app's (VM) id.
  Future<String> _roomFor(String otherId) => _rooms.putIfAbsent(otherId, () async {
        // 1. The room id the app saved on this conversation (exact).
        try {
          final saved = '${(await _myUsers(_myId).doc(otherId).get()).data()?['roomId'] ?? ''}'.trim();
          if (saved.isNotEmpty) return saved;
        } catch (_) {}
        // 2. Older conversations: rebuild the phone app's id.
        final c = _roomCandidates(_myId, otherId);
        for (final id in c) {
          try {
            final q = await _messages(id).limit(1).get();
            if (q.docs.isNotEmpty) return id;
          } catch (_) {}
        }
        return c.first;
      });

  /// Same as the app's updateUnread(): clear my unread dot for this person.
  Future<void> _markRead(String otherId) async {
    if (_clearing == otherId) return;
    _clearing = otherId;
    try {
      await _myUsers(_myId).doc(otherId).update({'newMessageArrived': false});
    } catch (_) {}
    _clearing = null;
  }

  void _open(String otherId, Map<String, dynamic> data) {
    setState(() {
      _selId = otherId;
      _selData = data;
      _input.clear();
    });
    _markRead(otherId);
    _inputFocus.requestFocus();
  }

  /// Same as the app's updateCollection(): add the person to the list, or
  /// just flip the unread flag if they are already there.
  Future<void> _upsert({
    required String ownerId,
    required String otherId,
    required String name,
    required bool unread,
    required String deviceToken,
    required String roomId,
  }) async {
    final ref = _myUsers(ownerId).doc(otherId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({'newMessageArrived': unread, 'roomId': roomId});
    } else {
      await ref.set({
        'id': otherId,
        'name': name,
        'time': Timestamp.now(),
        'remoteId': 0,
        'days': '',
        'newMessageArrived': unread,
        'deviceToken': deviceToken,
        'roomId': roomId,
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final otherId = _selId;
    final other = _selData;
    if (text.isEmpty || otherId == null || other == null || _sending) return;
    if (_myId.isEmpty) {
      portalToast("Couldn't send", sub: 'Please log in again.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final room = await _roomFor(otherId);
      await _messages(room).add({
        'sendBy': _session.userId,
        'name': _session.name,
        'message': text,
        'time': Timestamp.now(),
      });
      _input.clear();
      // My device token (if the app saved one) so the client can reach me.
      var myToken = '';
      try {
        final me = await _fs.collection('users').doc(_myId).get();
        myToken = '${me.data()?['deviceToken'] ?? ''}';
      } catch (_) {}
      await Future.wait([
        _upsert(
          ownerId: otherId,
          otherId: _myId,
          name: _session.name,
          unread: true,
          deviceToken: myToken,
          roomId: room,
        ),
        _upsert(
          ownerId: _myId,
          otherId: otherId,
          name: '${other['name'] ?? ''}',
          unread: false,
          deviceToken: '${other['deviceToken'] ?? ''}',
          roomId: room,
        ),
      ]);
      // Push to her phone, sent by the server.
      PortalApi.post('/users/chat/notify', {'toUserId': otherId, 'text': text});
    } catch (e) {
      portalToast("Couldn't send", sub: 'Please try again.', error: true);
    }
    if (mounted) {
      setState(() => _sending = false);
      _inputFocus.requestFocus();
    }
  }

  // ---------- left: conversation list ----------

  Widget _lastLine(String otherId, Map<String, dynamic> data) {
    final stored = data['lastMessage'];
    if (stored is String && stored.isNotEmpty) {
      return Text(stored, maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(12, c: PT.sage));
    }
    return FutureBuilder<String>(
      future: _roomFor(otherId),
      builder: (c, room) {
        if (!room.hasData) return Text(' ', style: PT.t(12, c: PT.sage));
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messages(room.data!).orderBy('time', descending: true).limit(1).snapshots(),
          builder: (c, s) {
            final d = s.data?.docs;
            final msg = d == null || d.isEmpty ? '' : '${d.first.data()['message'] ?? ''}';
            return Text(msg.isEmpty ? 'No messages yet' : msg,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(12, c: PT.sage));
          },
        );
      },
    );
  }

  Widget _tile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final otherId = '${data['id'] ?? doc.id}';
    final name = '${data['name'] ?? ''}'.trim();
    final unread = data['newMessageArrived'] == true && otherId != _selId;
    final sel = otherId == _selId;
    final t = _toDate(data['time']);
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => _open(otherId, data),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: PT.wash,
              child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: PT.t(14, w: FontWeight.w700, c: PT.greenDark)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Client $otherId' : name,
                    style: PT.t(13.5, w: unread ? FontWeight.w700 : FontWeight.w600), overflow: TextOverflow.ellipsis),
                _lastLine(otherId, data),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(t == null ? '' : portalAgo(t.toIso8601String()), style: PT.t(11, c: PT.sage)),
              const SizedBox(height: 4),
              unread
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: PT.green, shape: BoxShape.circle),
                    )
                  : const SizedBox(height: 10),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _list() {
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search by name',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        const Divider(height: 1, color: PT.line),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myUsers(_myId).orderBy('time', descending: true).snapshots(),
            builder: (c, s) {
              if (s.hasError) {
                return const PortalEmpty(
                    icon: Icons.cloud_off_outlined, title: "Couldn't load chats", sub: 'Check your connection.');
              }
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              // Keep the open conversation read, like the app does when the room opens.
              final selDoc = docs.where((d) => '${d.data()['id'] ?? d.id}' == _selId).firstOrNull;
              if (selDoc != null && selDoc.data()['newMessageArrived'] == true) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(_selId!));
              }
              final shown = _filter.isEmpty
                  ? docs
                  : docs.where((d) => '${d.data()['name'] ?? ''}'.toLowerCase().contains(_filter)).toList();
              if (docs.isEmpty) {
                return const PortalEmpty(
                    icon: Icons.chat_bubble_outline, title: 'No chats yet', sub: 'Clients who message you show up here.');
              }
              if (shown.isEmpty) {
                return Center(child: Text('No one matches', style: PT.t(13, c: PT.sage)));
              }
              return ListView.builder(
                itemCount: shown.length,
                itemBuilder: (c, i) => _tile(shown[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ---------- right: messages ----------

  Widget _bubble(Map<String, dynamic> m) {
    final mine = '${m['sendBy']}' == _myId;
    final fg = mine ? Colors.white : PT.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? PT.green : const Color(0xFFF1F4EE),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 2),
              bottomRight: Radius.circular(mine ? 2 : 14),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${m['name'] ?? ''} (${m['sendBy'] ?? ''})',
                    style: PT.t(11.5, w: FontWeight.w700, c: PT.greenDark)),
              ),
            SelectableText('${m['message'] ?? ''}', style: PT.t(14, c: fg, h: 1.35)),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(_msgTime(m['time']), style: PT.t(10, c: mine ? Colors.white70 : PT.sage)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Focus(
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent &&
                    (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write a message. Enter to send, Shift+Enter for a new line',
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
          ),
        ]),
        const SizedBox(height: 8),
        mobileOnlyNote('Sending photos or files'),
      ]),
    );
  }

  Widget _room() {
    final otherId = _selId;
    final data = _selData;
    if (otherId == null || data == null) {
      return Container(
        decoration: PT.card(),
        child: const PortalEmpty(
            icon: Icons.forum_outlined, title: 'Pick a chat', sub: 'Choose a person on the left to read and reply.'),
      );
    }
    final name = '${data['name'] ?? ''}'.trim();
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            Expanded(child: Text(name.isEmpty ? 'Client $otherId' : name, style: PT.t(16, w: FontWeight.w700))),
            Text('ID $otherId', style: PT.t(12, c: PT.sage)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<String>(
            key: ValueKey('room-$otherId'),
            future: _roomFor(otherId),
            builder: (c, room) {
              if (!room.hasData) return const Center(child: CircularProgressIndicator());
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messages(room.data!).orderBy('time', descending: true).snapshots(),
                builder: (c, s) {
                  if (s.hasError) {
                    return const PortalEmpty(icon: Icons.cloud_off_outlined, title: "Couldn't load messages");
                  }
                  if (!s.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = s.data!.docs;
                  if (docs.isEmpty) {
                    return const PortalEmpty(
                        icon: Icons.chat_bubble_outline, title: 'No messages yet', sub: 'Say hello below.');
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (c, i) => _bubble(docs[i].data()),
                  );
                },
              );
            },
          ),
        ),
        _composer(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
        title: 'Chat',
        sub: 'Your conversations with clients. Same chats as in the Fit Her app.',
      ),
      Expanded(
        child: !_ready
            ? const PortalEmpty(
                icon: Icons.cloud_off_outlined,
                title: 'Chat is not connected',
                sub: 'Firebase did not start. Please reload the page.',
              )
            : _myId.isEmpty
                ? const PortalEmpty(icon: Icons.lock_outline, title: 'Please log in again')
                : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: wide ? 330 : 270, child: _list()),
                    const SizedBox(width: 18),
                    Expanded(child: _room()),
                  ]),
      ),
    ]);
  }
}
