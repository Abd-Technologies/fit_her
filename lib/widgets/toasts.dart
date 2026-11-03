import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../values/values.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../data/controllers/auth_controller/auth_controller.dart';

/// All in-app messages (535 calls) go through here.
/// Look: a dark glass pill that slides down from the top, icon + short
/// message + optional action, like the cycle banners. One at a time,
/// the same text never stacks, swipe up or tap to close.
/// Raw server texts ("Login Successfully!") are turned into friendly
/// ones in [_friendly], so the server doesn't need to change.
class CustomToast {
  static showDownLoadToast(BuildContext context,
      {required String message, required String filePath}) {
    FToast fToast = FToast();
    fToast.init(context);
    fToast.showToast(
      toastDuration: Duration(seconds: 5),
      child: ToastWidget(message: message, filePath: filePath),
      gravity: ToastGravity.BOTTOM,
    );
  }

  /// Something failed. Old colour / position arguments are ignored.
  static failToast({Color? bgcolor, Color? textColor, dynamic msg, len, gravity}) =>
      _show(FhToastKind.error, msg);

  static successToast({Color? bgcolor, Color? textColor, dynamic msg, len, gravity}) =>
      _show(FhToastKind.success, msg);

  static noInternetToast({Color? bgcolor, Color? textColor, len, gravity}) =>
      FhToast.show(FhToastKind.warning, "You're offline",
          sub: 'Check your internet and try again');

  /// Neutral news, optionally with a shortcut ("Join →").
  static infoToast(String title, {String? sub, String? action, VoidCallback? onAction}) =>
      FhToast.show(FhToastKind.info, title, sub: sub, action: action, onAction: onAction);

  /// Needs her attention ("Please select a date").
  static warnToast(String title, {String? sub, String? action, VoidCallback? onAction}) =>
      FhToast.show(FhToastKind.warning, title, sub: sub, action: action, onAction: onAction);

  static void _show(FhToastKind kind, dynamic msg) {
    final f = _friendly(kind, msg == null ? '' : '$msg');
    FhToast.show(f.kind, f.title, sub: f.sub);
  }
}

class _Friendly {
  final FhToastKind kind;
  final String title;
  final String? sub;
  const _Friendly(this.kind, this.title, [this.sub]);
}

String _firstName() {
  try {
    if (Get.isRegistered<AuthController>()) {
      final n = (Get.find<AuthController>().logInUser?.firstName ?? '').trim();
      return n.isEmpty ? '' : n.split(' ').first;
    }
  } catch (_) {}
  return '';
}

/// Raw message → friendly words and the right type.
_Friendly _friendly(FhToastKind kind, String raw) {
  final text = raw.trim();
  final k = text.toLowerCase().replaceAll(RegExp(r'[!.]+$'), '').trim();

  if (k.isEmpty) {
    return kind == FhToastKind.success
        ? const _Friendly(FhToastKind.success, 'Done')
        : const _Friendly(FhToastKind.error, 'Something went wrong', 'Please try again in a moment');
  }

  // Exact server / app texts.
  switch (k) {
    case 'login successfully':
    case 'logged in successfully':
      final n = _firstName();
      return _Friendly(FhToastKind.success, n.isEmpty ? 'Welcome back' : 'Welcome back, $n');
    case 'successfully updated':
    case 'updated successfully':
    case 'update successfully':
    case 'saved successfully':
      return const _Friendly(FhToastKind.success, 'Saved');
    case 'successfully logout':
    case 'logout successfully':
      return const _Friendly(FhToastKind.success, 'Logged out');
    case 'incorrect username or password':
    case 'invalid password':
    case 'incorrect password':
      return const _Friendly(FhToastKind.error, 'Email or password is wrong', 'Try again or reset your password');
    case 'user not exist':
    case 'user not found':
      return const _Friendly(FhToastKind.error, 'No account found', 'Check the email or sign up');
    case 'email already exist':
    case 'email already exists':
      return const _Friendly(FhToastKind.error, 'This email is already signed up', 'Log in instead');
    case 'phone no. already exists':
    case 'phone already exists':
      return const _Friendly(FhToastKind.error, 'This phone number is already in use');
    case 'something wrong happened':
    case 'something went wrong':
    case 'something went wrong. please try again later':
    case 'please try again later':
      return const _Friendly(FhToastKind.error, 'Something went wrong', 'Please try again in a moment');
    case 'check your internet connection':
    case 'no internet connection':
      return const _Friendly(FhToastKind.warning, "You're offline", 'Check your internet and try again');
    case 'link copied':
      return const _Friendly(FhToastKind.success, 'Link copied');
    case 'reminder send successfully':
    case 'reminder sent successfully':
      return const _Friendly(FhToastKind.success, 'Reminder sent');
    case 'please select pdf first':
      return const _Friendly(FhToastKind.warning, 'Please choose a PDF first');
    case 'dietitian does not add link yet':
      return const _Friendly(FhToastKind.info, "Your dietitian hasn't added the link yet",
          "You'll get a notice when it's ready");
    case 'your account is frozen please unfreeze first':
      return const _Friendly(FhToastKind.warning, 'Your plan is paused', 'Unfreeze it to continue');
    case 'you are not logged in':
    case 'please log in to continue':
      return const _Friendly(FhToastKind.warning, 'Please log in to continue');
    case 'coming soon! stay tuned':
      return const _Friendly(FhToastKind.info, 'Coming soon', 'Stay tuned');
  }

  if (RegExp(r'registered successfully$').hasMatch(k)) {
    return const _Friendly(FhToastKind.success, 'Account created', 'A few quick questions next');
  }
  // Session ended on the server side.
  if (k.contains('jwt') || k.contains('invalid token') || k.contains('token expired')) {
    return const _Friendly(FhToastKind.warning, 'Please log in again', 'Your session has ended');
  }
  // Technical errors must never reach her screen.
  if (k.contains('sequelize') ||
      k.contains('undefined') ||
      k.contains('cannot read') ||
      k.contains('exception') ||
      k.contains('econn') ||
      k.contains('socketexception') ||
      k.contains('null check') ||
      k.startsWith('error:') ||
      k.contains('<html')) {
    return const _Friendly(FhToastKind.error, 'Something went wrong', 'Please try again in a moment');
  }

  // "Please pick a date" is a nudge, not an error (amber, whichever
  // toast the screen used).
  final t = kind != FhToastKind.success && k.startsWith('please ')
      ? FhToastKind.warning
      : (kind == FhToastKind.success && k.startsWith('please ') ? FhToastKind.warning : kind);
  return _Friendly(t, text);
}

enum FhToastKind { success, error, warning, info }

/// The toast itself: shown on the app's top overlay.
class FhToast {
  FhToast._();

  static OverlayEntry? _entry;
  static GlobalKey<_FhToastViewState>? _viewKey;
  static String? _lastText;
  static DateTime? _lastAt;

  static void show(FhToastKind kind, String title,
      {String? sub, String? action, VoidCallback? onAction, Duration? duration}) {
    final sig = '$kind|$title|$sub';
    final now = DateTime.now();
    // Same message again within 2 s (e.g. a list of failed calls): skip.
    if (_lastText == sig && _lastAt != null && now.difference(_lastAt!).inMilliseconds < 2000) return;
    _lastText = sig;
    _lastAt = now;

    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) {
      // App not drawn yet: plain system toast as a fallback.
      Fluttertoast.showToast(msg: sub == null ? title : '$title\n$sub', gravity: ToastGravity.TOP);
      return;
    }

    if (kind == FhToastKind.error) HapticFeedback.lightImpact();

    _removeNow();
    final key = GlobalKey<_FhToastViewState>();
    final long = (title.length + (sub?.length ?? 0)) > 70;
    final d = duration ??
        Duration(
            milliseconds: (kind == FhToastKind.success || kind == FhToastKind.info ? 3000 : 4000) +
                (long ? 1500 : 0));
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FhToastView(
        key: key,
        kind: kind,
        title: title,
        sub: sub,
        action: action,
        onAction: onAction,
        duration: d,
        onGone: () {
          if (identical(_entry, entry)) {
            _entry = null;
            _viewKey = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    _viewKey = key;
    overlay.insert(entry);
  }

  /// Close the current toast (animated).
  static void hide() => _viewKey?.currentState?.dismiss();

  static void _removeNow() {
    final e = _entry;
    _entry = null;
    _viewKey = null;
    if (e != null && e.mounted) e.remove();
  }
}

const Color _kBrandGreen = Color(0xFF6DC55A);
const Color _kBrandInk = Color(0xFF163220);
const Color _kBrandSub = Color(0xFF5A7A56);
const Color _kBrandWash = Color(0xFFEAF7E4);
const Color _kBrandLine = Color(0xFFD8EDD4);

class _FhToastStyle {
  final Color color;
  final IconData icon;
  const _FhToastStyle(this.color, this.icon);

  static _FhToastStyle of(FhToastKind k) {
    switch (k) {
      // One Fit Her look for every toast (white card, brand green); only
      // the icon tells the type apart.
      case FhToastKind.success:
        return const _FhToastStyle(_kBrandGreen, Icons.check_rounded);
      case FhToastKind.error:
        return const _FhToastStyle(_kBrandGreen, Icons.error_outline_rounded);
      case FhToastKind.warning:
        return const _FhToastStyle(_kBrandGreen, Icons.info_outline_rounded);
      case FhToastKind.info:
        return const _FhToastStyle(_kBrandGreen, Icons.notifications_none_rounded);
    }
  }
}

class _FhToastView extends StatefulWidget {
  final FhToastKind kind;
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  const _FhToastView({
    super.key,
    required this.kind,
    required this.title,
    this.sub,
    this.action,
    this.onAction,
    required this.duration,
    required this.onGone,
  });

  @override
  State<_FhToastView> createState() => _FhToastViewState();
}

class _FhToastViewState extends State<_FhToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, -1.3), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn));
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _c.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = _FhToastStyle.of(widget.kind);
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _c,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: dismiss,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) dismiss();
              },
              child: Semantics(
                liveRegion: true,
                label: widget.sub == null ? widget.title : '${widget.title}. ${widget.sub}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBrandLine),
                        boxShadow: const [
                          BoxShadow(color: Color(0x1F163220), blurRadius: 18, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: _kBrandWash,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(st.icon, size: 17, color: st.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: widget.sub == null ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: _kBrandInk,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (widget.sub != null && widget.sub!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.sub!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: _kBrandSub,
                                      fontSize: 12,
                                      height: 1.35,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.action != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                widget.onAction?.call();
                                dismiss();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                child: Text(
                                  widget.action!,
                                  style: TextStyle(
                                    color: st.color,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToastWidget extends StatelessWidget {
  final String message;
  final String filePath;

  const ToastWidget({super.key, required this.message, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        color: Colors.black,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Download File",
              style: TextStyle(color: Colors.white, fontSize: 12.0)),
          SizedBox(
            width: 50.0,
          ),
          GestureDetector(
            onTap: () {
              try {
                print("path  $filePath");
                OpenFilex.open(filePath).then((result) {
                  // Handle the result if needed
                }).catchError((error, stackTrace) {
                  print("Error: $error");
                  print("Stack Trace: $stackTrace");
                });
              } catch (e) {
                print("error of opening---- $e");
              }
            },
            child: Text(
              "Open",
              style: TextStyle(
                color: Colors.white,
                decorationColor: Colors.white,
                decoration: TextDecoration.underline,
                fontSize: 10.0,
              ),
            ),
          ),
          SizedBox(
            width: 12.0,
          ),
          GestureDetector(
            onTap: () {
              Share.shareXFiles([XFile(filePath)], text: 'P45');
            },
            child: Text(
              "Share",
              style: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                fontSize: 10.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}