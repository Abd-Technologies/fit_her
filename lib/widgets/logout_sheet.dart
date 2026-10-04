import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/controllers/auth_controller/auth_controller.dart';

/// "Log out of FitHer?" bottom sheet. Used by both profile screens.
/// Log out calls the same AuthController.logout() as before.
class LogoutSheet extends StatefulWidget {
  const LogoutSheet({Key? key}) : super(key: key);

  static Future<void> show() {
    return Get.bottomSheet<void>(
      const LogoutSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<LogoutSheet> createState() => _LogoutSheetState();
}

const _ink = Color(0xFF163220);
const _muted = Color(0xFF7D8B80);
const _red = Color(0xFFDC4B47);

TextStyle _t(double size, FontWeight w, Color c) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c);

class _LogoutSheetState extends State<LogoutSheet> {
  bool _busy = false;

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Get.find<AuthController>().logout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8EDD4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFDECEA),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFFADAD7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: _red, size: 24),
            ),
          ),
          const SizedBox(height: 14),
          Text('Log out of FitHer?', style: _t(18, FontWeight.w700, _ink)),
          const SizedBox(height: 8),
          Text(
            "You'll need to sign in again to join classes\nand see your plan.",
            textAlign: TextAlign.center,
            style: _t(12.5, FontWeight.w400, _muted).copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_outlined,
                    size: 15, color: Color(0xFF4AA877)),
                const SizedBox(width: 6),
                Text('Your progress and logs are saved',
                    style: _t(11, FontWeight.w600, const Color(0xFF4AA877))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _logout,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _red,
                disabledBackgroundColor: _red.withOpacity(0.7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Log out',
                      style: _t(14, FontWeight.w700, Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _busy ? null : () => Get.back<void>(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE3E7E1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Cancel', style: _t(14, FontWeight.w600, _ink)),
            ),
          ),
        ],
      ),
    );
  }
}
