import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/post_controller.dart';
import 'package:fitness_zone_2/data/controllers/socket_controller.dart';
import 'package:fitness_zone_2/data/models/post_model.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../UI/plans_module/all_plans.dart';
import '../../../values/constants.dart';
import 'create_post_screen.dart';

/// Paywall gate for community posting. Trainers and dietitians (the
/// platform's professionals) post freely regardless of `hasActivePackage`
/// because they're paid contributors, not subscribers. Everyone else
/// (regular users + admin/specialists) follows the existing
/// `hasActivePackage` rule. Backend role literals per CLAUDE.md:
/// 'Trainer' and 'Dietition' (typo preserved by the backend).
bool _canPostFreely() {
  final type = Get.find<AuthController>().logInUser?.userType;
  if (type == Constants.trainer || type == Constants.dietitian) return true;
  return Get.find<HomeController>().hasActivePackage;
}

// V2 design tokens — palette mirrors lib/docs/newdesign.md §2.
const _kCream = Color(0xFFEAF7E4);
const _kCardBorder = Color(0xFFD8EDD4);
const _kTextPrimary = Color(0xFF163220);
const _kTextSecondary = Color(0xFF6F8B7A);
const _kSage = Color(0xFF9AB09A);
const _kAccent = Color(0xFF6DC55A);
const _kLikedRose = Color(0xFFE07B7B);
const _kShadowTint = Color(0xFF163220);

class FeedScreen extends StatefulWidget {
  FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PostController controller = Get.find();
  final SocketController socketController = Get.find();

  @override
  void initState() {
    super.initState();
    controller.getAllPosts();
    socketController.joinCommunity();
    // Newest-first display via List.reversed in `_feed()` — no scroll-to-bottom
    // dance any more. The previous version's auto-scroll-to-bottom was a
    // chat metaphor that hid the most recent posts on a screen that's
    // semantically a feed. Newest at top is the standard expectation.
  }

  @override
  void dispose() {
    socketController.leaveCommunity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kCream,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Obx(() {
                  if (!controller.allPostsLoad.value) {
                    return const Center(child: CircularProgress());
                  }
                  if (controller.postsList.isEmpty) {
                    return _emptyState();
                  }
                  return RefreshIndicator(
                    onRefresh: () async => controller.getAllPosts(),
                    color: _kAccent,
                    child: _list(),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'COMMUNITY',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: _kSage,
                  letterSpacing: 0.7,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'FitHer Feed',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          _composeButton(),
        ],
      ),
    );
  }

  /// Accent pill when the user has an active package; locked sage pill with
  /// a lock icon otherwise. Tap on the locked variant surfaces the same
  /// toast that gated the previous version.
  Widget _composeButton() {
    final hasPackage = _canPostFreely();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onComposeTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: hasPackage ? _kAccent : _kSage.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: hasPackage
              ? null
              : Border.all(color: _kSage.withOpacity(0.35), width: 1),
          boxShadow: hasPackage
              ? [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPackage ? Icons.add_rounded : Icons.lock_outline_rounded,
              color: hasPackage ? Colors.white : _kSage,
              size: 16.sp,
            ),
            SizedBox(width: 5.w),
            Text(
              hasPackage ? 'New Post' : 'Locked',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: hasPackage ? Colors.white : _kSage,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onComposeTap() {
    if (!_canPostFreely()) {
      // Locked → navigate to the plans/subscribe screen instead of the
      // dead-end toast. `OurPlansScreen` is the canonical paywall used by
      // recommended_slots, free-trial flows, and the in-AppBar upgrade CTA.
      Get.to(() => OurPlansScreen());
      return;
    }
    Get.to(() => const CreatePostScreen());
  }

  // ─── Upgrade banner + stats strip (above the list) ─────────────────────

  Widget _upgradeBanner() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.to(() => OurPlansScreen()),
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kCardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: _kShadowTint.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  color: _kAccent,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_outline_rounded, color: _kAccent, size: 16.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'COMMUNITY ACCESS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _kSage,
                                  letterSpacing: 0.63,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Unlock posting & replies',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withOpacity(0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsStrip(int postsToday, int activeMembers) {
    if (postsToday == 0) return const SizedBox.shrink();
    final postsLabel = '$postsToday post${postsToday == 1 ? '' : 's'} today';
    final membersLabel = activeMembers > 0
        ? '$activeMembers active member${activeMembers == 1 ? '' : 's'}'
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 10.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kCardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _kShadowTint.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt_rounded, color: _kAccent, size: 11.sp),
                ),
                SizedBox(width: 6.w),
                Text(
                  membersLabel == null
                      ? postsLabel
                      : '$postsLabel · $membersLabel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── List + empty state ────────────────────────────────────────────────

  Widget _list() {
    final hasPackage = _canPostFreely();
    final posts = controller.postsList.reversed.toList();
    final today = DateTime.now();
    bool isToday(DateTime c) =>
        c.year == today.year && c.month == today.month && c.day == today.day;
    final todaysPosts =
        controller.postsList.where((p) => isToday(p.createdAt)).toList();
    final postsToday = todaysPosts.length;
    final activeMembers = todaysPosts
        .map((p) => p.user?.id)
        .where((id) => id != null)
        .toSet()
        .length;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
      itemCount: posts.length + 1, // +1 for the header strip
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 14.h),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasPackage)
                Padding(
                  padding: EdgeInsets.zero,
                  child: _upgradeBanner(),
                ),
              if (postsToday > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0),
                  child: _statsStrip(postsToday, activeMembers),
                ),
            ],
          );
        }
        final post = posts[i - 1];
        return _PostCard(
          post: post,
          onLike: () => controller.likePost(post.id),
          onReplyTap: () => _showRepliesSheet(post),
        );
      },
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: _kShadowTint.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_outlined,
                  size: 28.sp,
                  color: _kAccent,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Be the first to share your fitness journey, tips, or questions with the community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  color: _kTextSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Replies bottom sheet ──────────────────────────────────────────────

  void _showRepliesSheet(Post post) {
    final replyController = TextEditingController();
    socketController.joinPost(post.id);

    void send() {
      final text = replyController.text.trim();
      if (text.isEmpty) return;
      if (!_canPostFreely()) {
        CustomToast.failToast(
          msg:
              "You need an active package to reply. Please subscribe to a plan first.",
        );
        return;
      }
      controller.sendReply(postId: post.id, message: text);
      replyController.clear();
    }

    Get.bottomSheet(
      Builder(
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final bottomInset = mediaQuery.viewInsets.bottom;
          final bottomPadding = mediaQuery.padding.bottom;
          return Container(
            height: mediaQuery.size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: _kShadowTint.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kSage.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 12.h),
                  child: Row(
                    children: [
                      const Text(
                        'REPLIES',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kSage,
                          letterSpacing: 0.77,
                        ),
                      ),
                      const Spacer(),
                      Obx(() => Text(
                            '${post.replies.length}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kTextSecondary,
                            ),
                          )),
                    ],
                  ),
                ),
                Container(height: 1, color: _kCardBorder),
                Expanded(
                  child: Obx(() {
                    final replies = post.replies;
                    if (replies.isEmpty) return _repliesEmpty();
                    return ListView.separated(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      itemCount: replies.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, i) => _replyTile(replies[i]),
                    );
                  }),
                ),
                _replyInput(
                  replyController,
                  send,
                  bottomPadding: bottomInset > 0
                      ? bottomInset + 8.h
                      : bottomPadding + 12.h,
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
    ).whenComplete(() {
      socketController.leavePost(post.id);
      replyController.dispose();
    });
  }

  Widget _repliesEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 40.sp, color: _kSage.withOpacity(0.6)),
            SizedBox(height: 10.h),
            Text(
              'No replies yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Be the first to reply.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replyTile(Reply r) {
    final initial =
        (r.user?.firstName ?? 'U').isEmpty ? 'U' : r.user!.firstName[0].toUpperCase();
    final name = (r.user?.firstName ?? 'Unknown').trim();
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kShadowTint.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatarCircle(initial: initial, size: 34),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'Unknown' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                          color: _kTextPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(r.createdAt),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.sp,
                        color: _kSage,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  r.message,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5.sp,
                    color: _kTextPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyInput(TextEditingController controller, VoidCallback onSend,
      {double? bottomPadding}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16.w, 8.h, 16.w, bottomPadding ?? 12.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kCardBorder, width: 1),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a reply…',
                  hintStyle:
                      TextStyle(fontFamily: 'Poppins', color: _kSage, fontSize: 13.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 10.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSend,
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 18.sp),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Time format ───────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────

Widget _avatarCircle({required String initial, double size = 40}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: _kCardBorder, width: 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF6DC55A),
          Color(0xFF4FA83D),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: _kShadowTint.withOpacity(0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      initial,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

// Normalises a post image URL so old http:// rows still render. Strips
// any scheme+host and re-prepends the current Constants.baseUrl. Works
// for both absolute (http/https) and already-relative paths.
String _normalisePostImageUrl(String raw) {
  String path = raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    try {
      path = Uri.parse(raw).path;
    } catch (_) {
      path = raw;
    }
  }
  final cleanPath = path.replaceFirst(RegExp(r'^/'), '');
  return '${Constants.baseUrl}/$cleanPath';
}

void _showFullImage(BuildContext context, String imageUrl) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16.w),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: _normalisePostImageUrl(imageUrl),
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Post card (styled to match V2 bottombar screens theme) ───────────────

class _PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onReplyTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onReplyTap,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;
  static const int _readMoreThreshold = 220;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final shouldTruncate = !_expanded && p.text.length > _readMoreThreshold;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kShadowTint.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(p),
                if (p.text.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(
                    shouldTruncate
                        ? '${p.text.substring(0, _readMoreThreshold)}…'
                        : p.text,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w400,
                      color: _kTextPrimary,
                      height: 1.55,
                    ),
                  ),
                  if (p.text.length > _readMoreThreshold)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded ? 'Show less ↑' : 'Read more ↓',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: _kAccent,
                          ),
                        ),
                      ),
                    ),
                ],
                if (p.imageUrl?.isNotEmpty ?? false) ...[
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () => _showFullImage(context, p.imageUrl!),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kCardBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: CachedNetworkImage(
                          imageUrl: _normalisePostImageUrl(p.imageUrl!),
                          placeholder: (_, __) => Container(
                            height: 200.h,
                            color: _kCream,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: _kAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 200.h,
                            color: _kCream,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 36.sp,
                              color: _kSage,
                            ),
                          ),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Subtle divider from V2 design system
          Container(height: 1, color: const Color(0xFFF0F6EE)),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
            child: Row(
              children: [
                Obx(() => _ActionPill(
                      icon: p.isLiked.value
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${p.likesCount.value}',
                      active: p.isLiked.value,
                      activeColor: _kLikedRose,
                      onTap: widget.onLike,
                    )),
                SizedBox(width: 8.w),
                Obx(() => _ActionPill(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: p.replies.isEmpty
                          ? 'Reply'
                          : '${p.replies.length} ${p.replies.length == 1 ? "reply" : "replies"}',
                      active: false,
                      activeColor: _kAccent,
                      onTap: widget.onReplyTap,
                    )),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onReplyTap,
                  child: Text(
                    'Join Discussion →',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Post p) {
    final initial = p.user?.firstName.isNotEmpty == true
        ? p.user!.firstName[0].toUpperCase()
        : 'U';
    final fullName = p.user != null
        ? '${p.user?.firstName ?? ''} ${p.user?.lastName ?? ''}'.trim()
        : 'Community Member';
    final role = _roleLabelFor(p.user?.userType);

    return Row(
      children: [
        _avatarCircle(initial: initial, size: 40),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fullName.isEmpty ? 'Community Member' : fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5.sp,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                  if (role != null) ...[
                    SizedBox(width: 6.w),
                    _RoleBadge(label: role),
                  ],
                ],
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11.sp,
                    color: _kSage,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _formatTime(p.createdAt),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _kSage,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' · FitHer Member',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _kSage.withOpacity(0.7),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Maps backend userType to display label.
String? _roleLabelFor(String? userType) {
  switch (userType) {
    case 'Trainer':
      return 'TRAINER';
    case 'Dietition':
      return 'DIETITIAN';
    default:
      return null;
  }
}

// ─── Role badge (TRAINER / DIETITIAN with verification check) ──────────────

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kAccent.withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 10.sp,
            color: _kAccent,
          ),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: _kAccent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action pill button (Likes & Comments matching V2 chips) ───────────────

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withOpacity(0.10)
              : const Color(0xFFF5FBF2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? activeColor.withOpacity(0.35)
                : const Color(0xFFD8EDD4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15.sp,
              color: active ? activeColor : _kTextSecondary,
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? activeColor : _kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
