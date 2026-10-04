// Support tickets ("Report an issue"): model + API calls + unread badge.
// Endpoints live in partner_backend routes/FrontSite/appIssue.js.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../values/constants.dart';

class SupportMessage {
  final String sender; // user | admin | crm
  final String? senderName;
  final String? body;
  final String? imageUrl;
  final DateTime? createdAt;

  const SupportMessage({
    required this.sender,
    this.senderName,
    this.body,
    this.imageUrl,
    this.createdAt,
  });

  bool get isUser => sender == 'user';

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        sender: (j['sender'] ?? 'user').toString(),
        senderName: j['senderName']?.toString(),
        body: j['body']?.toString(),
        imageUrl: j['imageUrl']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

class SupportTicket {
  final int id;
  final String category;
  final String? message;
  final String? imageUrl;
  final String status; // received | in_review | resolved
  final DateTime? dueAt;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final bool userUnread;
  final String? feedback;
  final SupportMessage? lastReply;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.category,
    required this.status,
    this.message,
    this.imageUrl,
    this.dueAt,
    this.resolvedAt,
    this.createdAt,
    this.userUnread = false,
    this.feedback,
    this.lastReply,
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => DateTime.tryParse(j[k]?.toString() ?? '')?.toLocal();
    final raw = j['messages'];
    final lr = j['lastReply'];
    return SupportTicket(
      id: (j['id'] as num).toInt(),
      category: (j['category'] ?? 'OTHER').toString(),
      message: j['message']?.toString(),
      imageUrl: j['imageUrl']?.toString(),
      status: (j['status'] ?? 'received').toString(),
      dueAt: d('dueAt'),
      resolvedAt: d('resolvedAt'),
      createdAt: d('createdAt'),
      userUnread: j['userUnread'] == true,
      feedback: j['feedback']?.toString(),
      lastReply: lr is Map
          ? SupportMessage.fromJson({...Map<String, dynamic>.from(lr), 'sender': 'admin'})
          : null,
      messages: raw is List
          ? raw
              .whereType<Map>()
              .map((m) => SupportMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
    );
  }
}

/// Friendly labels for categories (same order as the tiles).
const supportCategories = <String, String>{
  'APP_ISSUE': 'App not working',
  'CLASS': 'Live class',
  'PAYMENT': 'Payment',
  'PLAN': 'Meal plan',
  'ACCOUNT': 'Account',
  'OTHER': 'Something else',
};

const supportCategoryIcons = <String, IconData>{
  'APP_ISSUE': Icons.bug_report_outlined,
  'CLASS': Icons.videocam_outlined,
  'PAYMENT': Icons.credit_card_outlined,
  'PLAN': Icons.receipt_long_outlined,
  'ACCOUNT': Icons.person_outline_rounded,
  'OTHER': Icons.more_horiz_rounded,
};

String supportCategoryLabel(String code) => supportCategories[code] ?? 'Something else';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Fri 2 Oct"
String supportDay(DateTime? d) =>
    d == null ? '' : '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

/// "27 Sep"
String supportShortDate(DateTime? d) => d == null ? '' : '${d.day} ${_mo[d.month - 1]}';

class SupportApi {
  /// Unread staff replies. Drives the badge on the profile menu row.
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Constants.accessToken) ?? '';
  }

  static Uri _u(String path) => Uri.parse('${Constants.baseUrl}/users/app-issue$path');

  static Map<String, dynamic>? _ok(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['status']?.toString() == '1') {
        final data = d['data'];
        return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      }
    } catch (_) {}
    return null;
  }

  static String? errorOf(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map) return d['message']?.toString();
    } catch (_) {}
    return null;
  }

  /// Creates a ticket. Returns the ticket, or throws with a friendly message.
  static Future<SupportTicket> create({
    required String category,
    required String message,
    File? image,
  }) async {
    final req = http.MultipartRequest('POST', _u(''));
    req.headers['accessToken'] = await _token();
    req.fields['message'] = message;
    req.fields['category'] = category;
    if (image != null) {
      req.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    final resp = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 40)));
    final data = _ok(resp);
    if (data == null || data['ticket'] is! Map) {
      throw errorOf(resp) ?? 'Could not send. Please try again.';
    }
    return SupportTicket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map));
  }

  static Future<List<SupportTicket>> mine() async {
    final r = await http
        .get(_u('/mine'), headers: {'accessToken': await _token()})
        .timeout(const Duration(seconds: 20));
    final data = _ok(r);
    if (data == null) return const [];
    unread.value = (data['unread'] as num?)?.toInt() ?? 0;
    final list = data['tickets'];
    return list is List
        ? list
            .whereType<Map>()
            .map((m) => SupportTicket.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : const [];
  }

  static Future<void> refreshUnread() async {
    try {
      final r = await http
          .get(_u('/unread-count'), headers: {'accessToken': await _token()})
          .timeout(const Duration(seconds: 15));
      final data = _ok(r);
      if (data != null) unread.value = (data['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  static Future<SupportTicket?> get(int id) async {
    final r = await http
        .get(_u('/$id'), headers: {'accessToken': await _token()})
        .timeout(const Duration(seconds: 20));
    final data = _ok(r);
    if (data == null || data['ticket'] is! Map) return null;
    return SupportTicket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map));
  }

  static Future<SupportTicket?> reply(int id, String message) async {
    final req = http.MultipartRequest('POST', _u('/$id/reply'));
    req.headers['accessToken'] = await _token();
    req.fields['message'] = message;
    final resp = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 30)));
    final data = _ok(resp);
    if (data == null || data['ticket'] is! Map) return null;
    return SupportTicket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map));
  }

  static Future<bool> feedback(int id, bool solved) async {
    final r = await http
        .post(_u('/$id/feedback'),
            headers: {
              'accessToken': await _token(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'solved': solved}))
        .timeout(const Duration(seconds: 20));
    return _ok(r) != null;
  }
}

/// Small red count shown on the "Report an issue" menu row.
class SupportUnreadBadge extends StatefulWidget {
  const SupportUnreadBadge({super.key});

  @override
  State<SupportUnreadBadge> createState() => _SupportUnreadBadgeState();
}

class _SupportUnreadBadgeState extends State<SupportUnreadBadge> {
  @override
  void initState() {
    super.initState();
    SupportApi.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SupportApi.unread,
      builder: (_, n, __) {
        if (n <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE05C5C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
