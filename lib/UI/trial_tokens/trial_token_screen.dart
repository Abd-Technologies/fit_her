import 'package:fitness_zone_2/data/controllers/trial_token_controller.dart';
import 'package:fitness_zone_2/values/my_colors.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Trial length from the server (TRIAL_DAYS), 3 until it loads.
int get _trialDays => Get.isRegistered<HomeController>()
    ? Get.find<HomeController>().trialDays.value
    : 3;

// ─── Design tokens (match app green palette) ────────────────────────────────
const _kGreen      = Color(0xFF8AD167);
const _kDark       = Color(0xFF163220);
const _kSurface    = Color(0xFFF5EEEE);
const _kCard       = Colors.white;
const _kSubText    = Color(0xFF6F8B7A);

/// Sales-rep panel for generating and managing Fit Her trial deep links.
///
/// Usage: navigate to this screen from CustomerSupportScreen.
/// Requires [TrialTokenController] to be registered in GetX (lazy-put in
/// CustomerSupportScreen.onTap or in the app's binding).
class TrialTokenScreen extends StatelessWidget {
  const TrialTokenScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lazily register the controller when this screen mounts.
    final ctrl = Get.put(TrialTokenController());

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: HelpingWidgets().appBarWidget(
        () => Get.back(),
        text: 'Trial Links',
      ),
      body: Column(
        children: [
          // ── Create button bar ────────────────────────────────────────────
          _CreateBar(ctrl: ctrl),

          // ── Token list ───────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value && ctrl.tokens.isEmpty) {
                return const Center(child: FhLoader());
              }
              if (ctrl.tokens.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off, size: 48.sp, color: _kSubText),
                      SizedBox(height: 12.h),
                      Text(
                        'No trial links yet.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          color: _kSubText,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Tap "Create Link" to generate one.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.sp,
                          color: _kSubText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: _kGreen,
                onRefresh: ctrl.loadMyTokens,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  itemCount: ctrl.tokens.length,
                  itemBuilder: (_, i) => _TokenCard(
                    token: ctrl.tokens[i],
                    ctrl:  ctrl,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Create bar ──────────────────────────────────────────────────────────────

class _CreateBar extends StatelessWidget {
  const _CreateBar({required this.ctrl});
  final TrialTokenController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Obx(() => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 13.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        onPressed: ctrl.isCreating.value
            ? null
            : () => _showCreateSheet(context, ctrl),
        icon: ctrl.isCreating.value
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_link),
        label: Text(
          ctrl.isCreating.value ? 'Creating…' : 'Create Trial Link',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      )),
    );
  }

  void _showCreateSheet(BuildContext context, TrialTokenController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTrialTokenSheet(ctrl: ctrl),
    );
  }
}

// ─── Create bottom sheet ─────────────────────────────────────────────────────

class _CreateTrialTokenSheet extends StatefulWidget {
  const _CreateTrialTokenSheet({required this.ctrl});
  final TrialTokenController ctrl;

  @override
  State<_CreateTrialTokenSheet> createState() => _CreateTrialTokenSheetState();
}

class _CreateTrialTokenSheetState extends State<_CreateTrialTokenSheet> {
  final _phoneCtrl = TextEditingController();
  int _expiryDays  = 7;

  static const _expiryOptions = [3, 7, 14, 30];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navBottom = MediaQuery.of(context).padding.bottom;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        20.h,
        20.w,
        24.h + (bottom > 0 ? bottom : navBottom),
      ),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          Text(
            'New Trial Link',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Fill in the details (all optional) and tap Create.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              color: _kSubText,
            ),
          ),
          SizedBox(height: 20.h),

          // Phone number (optional)
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))],
            decoration: InputDecoration(
              labelText: 'Phone number (optional)',
              labelStyle: const TextStyle(fontFamily: 'Poppins', color: _kSubText),
              prefixIcon: const Icon(Icons.phone_outlined, color: _kGreen),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),

          // Expiry selector
          Text(
            'Link expires in',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: _expiryOptions.map((days) {
              final selected = _expiryDays == days;
              return ChoiceChip(
                label: Text('$days days'),
                selected: selected,
                onSelected: (_) => setState(() => _expiryDays = days),
                selectedColor: _kGreen,
                backgroundColor: const Color(0xFFF0F0F0),
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: selected ? Colors.white : _kDark,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),

          // Create button
          Obx(() => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            onPressed: widget.ctrl.isCreating.value ? null : _onCreate,
            child: widget.ctrl.isCreating.value
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Create Link',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          )),
        ],
      ),
    );
  }

  Future<void> _onCreate() async {
    final phone = _phoneCtrl.text.trim();
    await widget.ctrl.createToken(
      phone:         phone.isEmpty ? null : phone,
      expiresInDays: _expiryDays,
    );

    if (!mounted) return;
    Get.back(); // close sheet

    // If creation succeeded, auto-open the share sheet for the new link
    final created = widget.ctrl.lastCreated.value;
    if (created != null) {
      _showShareSheet(context, created);
    }
  }

  void _showShareSheet(BuildContext context, TrialTokenModel token) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(token: token),
    );
  }
}

// ─── Share sheet ─────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.token});
  final TrialTokenModel token;

  @override
  Widget build(BuildContext context) {
    final navBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h + navBottom),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Success icon
          Center(
            child: Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 26)),
            ),
          ),
          SizedBox(height: 12.h),

          Text(
            'Trial link created!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Share this link with the lead. When they tap it, the app '
            'opens directly to their $_trialDays-day trial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              color: _kSubText,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16.h),

          // Link preview box
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: _kGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    token.deepLink,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.sp,
                      color: _kDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: token.deepLink));
                    CustomToast.successToast(msg: 'Link copied!');
                  },
                  child: Icon(Icons.copy, size: 20.sp, color: _kGreen),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Share via WhatsApp / any app
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // WhatsApp green
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 13.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.share),
            onPressed: () => _shareViaWhatsApp(token),
            label: Text(
              'Share via WhatsApp',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Generic share (any app)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kDark,
              side: BorderSide(color: _kGreen.withOpacity(0.5)),
              padding: EdgeInsets.symmetric(vertical: 13.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareGeneric(token),
            label: Text(
              'Share via…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (token.expiresAt.isAfter(DateTime.now())) ...[
            SizedBox(height: 12.h),
            Center(
              child: Text(
                'Expires ${_formatExpiry(token.expiresAt)}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  color: _kSubText.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shareViaWhatsApp(TrialTokenModel token) {
    final msg = _buildShareMessage(token);
    // share_plus opens WhatsApp if installed; falls back to system sheet
    Share.share(msg);
  }

  void _shareGeneric(TrialTokenModel token) {
    Share.share(_buildShareMessage(token));
  }

  String _buildShareMessage(TrialTokenModel token) {
    final greeting = token.phone != null ? 'Hi${token.phone != null ? "" : ""}' : 'Hi';
    return '$greeting 👋\n\n'
        "You've been invited to try Fit Her — Pakistan's first cycle-powered "
        'fitness app, completely free for $_trialDays days! 💚\n\n'
        'Tap the link below to activate your free trial:\n'
        '${token.deepLink}\n\n'
        'If you don\'t have the app yet, the link will take you to the store first.';
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays >= 1) return 'in ${diff.inDays} day${diff.inDays == 1 ? "" : "s"}';
    if (diff.inHours >= 1) return 'in ${diff.inHours} hour${diff.inHours == 1 ? "" : "s"}';
    return 'soon';
  }
}

// ─── Token card ──────────────────────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.token, required this.ctrl});
  final TrialTokenModel token;
  final TrialTokenController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status chip
              _StatusChip(status: token.status),
              const Spacer(),
              // Created time
              Text(
                _timeAgo(token.createdAt),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  color: _kSubText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Phone/email label
          if (token.phone != null || token.email != null)
            Text(
              token.phone ?? token.email ?? '',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),

          SizedBox(height: 6.h),

          // Link (truncated)
          Text(
            token.deepLink,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.sp,
              color: _kSubText,
            ),
          ),

          // Expiry info
          SizedBox(height: 6.h),
          Text(
            token.isUsed
                ? 'Used ${_timeAgo(token.usedAt!)}'
                : token.isExpired
                    ? 'Expired ${_timeAgo(token.expiresAt)}'
                    : token.isRevoked
                        ? 'Revoked'
                        : 'Expires ${_formatExpiry(token.expiresAt)}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.sp,
              color: token.isActive ? _kGreen : _kSubText,
            ),
          ),

          // Action row — only for active (issued) tokens
          if (token.isActive) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                // Copy
                _ActionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  color: _kGreen,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: token.deepLink));
                    CustomToast.successToast(msg: 'Link copied!');
                  },
                ),
                SizedBox(width: 8.w),

                // Share
                _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  color: const Color(0xFF25D366),
                  onTap: () => _openShareSheet(context),
                ),
                SizedBox(width: 8.w),

                // Revoke
                _ActionButton(
                  icon: Icons.block,
                  label: 'Revoke',
                  color: Colors.red.shade400,
                  onTap: () => _confirmRevoke(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(token: token),
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke link?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text(
          'The lead will no longer be able to use this trial link.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Get.back<bool>(result: true);
              ctrl.revokeToken(token.token);
            },
            child: Text('Revoke',
                style: TextStyle(color: Colors.red.shade400,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays >= 1) return 'in ${diff.inDays}d';
    if (diff.inHours >= 1) return 'in ${diff.inHours}h';
    return 'soon';
  }
}

// ─── Status chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'issued':
        bg = _kGreen.withOpacity(0.15);
        fg = _kGreen;
        label = 'Active';
        break;
      case 'used':
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue.shade700;
        label = 'Used ✓';
        break;
      case 'expired':
        bg = Colors.orange.withOpacity(0.12);
        fg = Colors.orange.shade700;
        label = 'Expired';
        break;
      case 'revoked':
        bg = Colors.red.withOpacity(0.10);
        fg = Colors.red.shade400;
        label = 'Revoked';
        break;
      default:
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Action button ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
