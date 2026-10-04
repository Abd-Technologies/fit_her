import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/post_controller.dart';
import '../../../data/models/post_model.dart';
import '../../../values/constants.dart';
import 'create_post_screen.dart';

// ── FitHer Feed design tokens (same palette as signup / trial) ─────────
const kFeedInk = Color(0xFF163220);
const kFeedSoft = Color(0xFF6F8B7A);
const kFeedMuted = Color(0xFF9AB09A);
const kFeedGreen = Color(0xFF6DC55A);
const kFeedDeep = Color(0xFF3F9B35);
const kFeedMint = Color(0xFFEAF7E4);
const kFeedMintSoft = Color(0xFFF4FAF1);
const kFeedBorder = Color(0xFFD8EDD4);
const kFeedField = Color(0xFFF6F8F5);
const kFeedHeart = Color(0xFFE0566B);
const kFeedPhotoBg = Color(0xFFF4EFE8);

TextStyle feedText(double size,
        {FontWeight weight = FontWeight.w400,
        Color color = kFeedInk,
        double? height}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: size.sp,
      fontWeight: weight,
      color: color,
      height: height,
    );

/// Post image paths are stored relative; old rows may hold http:// URLs.
String feedImageUrl(String raw) {
  var path = raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    try {
      path = Uri.parse(raw).path;
    } catch (_) {}
  }
  return '${Constants.baseUrl}/${path.replaceFirst(RegExp(r'^/'), '')}';
}

/// "Just now", "20m", "2h", then "14 May".
String feedTime(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = t.toLocal();
  return '${l.day} ${m[l.month - 1]}';
}

/// Round initial avatar. Staff get a green one with a small tick; members
/// get a soft colour picked from their name so the feed isn't all one tone.
class FeedAvatar extends StatelessWidget {
  final FeedAuthor author;
  final double size;
  const FeedAvatar({super.key, required this.author, this.size = 34});

  static const _tints = [
    [Color(0xFFFCE1EC), Color(0xFFC2185B)],
    [Color(0xFFECE6FA), Color(0xFF6A4FB3)],
    [Color(0xFFFFE9D6), Color(0xFFC4551F)],
    [Color(0xFFE1F0FA), Color(0xFF2E7DAF)],
  ];

  @override
  Widget build(BuildContext context) {
    final t = _tints[author.name.hashCode.abs() % _tints.length];
    final bg = author.isStaff ? kFeedDeep : t[0];
    final fg = author.isStaff ? Colors.white : t[1];
    final img = author.image;
    return SizedBox(
      width: size.w,
      height: size.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size.w,
            height: size.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: img != null
                ? CachedNetworkImage(
                    imageUrl: feedImageUrl(img),
                    width: size.w,
                    height: size.w,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initial(fg),
                  )
                : _initial(fg),
          ),
          if (author.isStaff)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: (size * 0.38).w,
                height: (size * 0.38).w,
                decoration: BoxDecoration(
                  color: kFeedGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(Icons.check_rounded, size: (size * 0.26).sp, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initial(Color fg) => Text(
        author.initial,
        style: feedText(size * 0.4, weight: FontWeight.w700, color: fg),
      );
}

/// "Trainer" / "Member" chip next to the name.
class FeedRoleChip extends StatelessWidget {
  final FeedAuthor author;
  const FeedRoleChip({super.key, required this.author});

  @override
  Widget build(BuildContext context) {
    final staff = author.isStaff;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: staff ? kFeedMint : kFeedField,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        author.roleLabel,
        style: feedText(9, weight: FontWeight.w600, color: staff ? kFeedDeep : kFeedSoft),
      ),
    );
  }
}

/// Name, role chip, time and the "..." menu.
class FeedPostHeader extends StatelessWidget {
  final Post post;
  final double avatar;
  final VoidCallback? onMore;
  const FeedPostHeader({super.key, required this.post, this.avatar = 34, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FeedAvatar(author: post.author, size: avatar),
        SizedBox(width: 10.w),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6.w,
            runSpacing: 2.h,
            children: [
              Text(post.author.name, style: feedText(13, weight: FontWeight.w700)),
              FeedRoleChip(author: post.author),
              Text('· ${feedTime(post.createdAt)}', style: feedText(10.5, color: kFeedMuted)),
            ],
          ),
        ),
        if (onMore != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMore,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(Icons.more_horiz_rounded, color: kFeedSoft, size: 20.sp),
            ),
          ),
      ],
    );
  }
}

/// Post photo, soft rounded, tap to see it full screen.
class FeedPostImage extends StatelessWidget {
  final String url;
  const FeedPostImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final full = feedImageUrl(url);
    return GestureDetector(
      onTap: () => Get.to(() => _FullImage(url: full), fullscreenDialog: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: kFeedPhotoBg,
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: 320.h, minHeight: 140.h),
          child: CachedNetworkImage(
            imageUrl: full,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, __) => SizedBox(height: 180.h),
            errorWidget: (_, __, ___) => SizedBox(
              height: 140.h,
              child: Icon(Icons.image_not_supported_outlined, color: kFeedMuted, size: 28.sp),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullImage extends StatelessWidget {
  final String url;
  const _FullImage({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
      ),
    );
  }
}

/// Heart + count. Everyone can like, trial users too.
class FeedLikeButton extends StatelessWidget {
  final Post post;
  final bool large;
  const FeedLikeButton({super.key, required this.post, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final on = post.isLiked.value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Get.find<PostController>().likePost(post.id),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: (large ? 18 : 16).sp,
                color: on ? kFeedHeart : kFeedSoft,
              ),
              SizedBox(width: 4.w),
              Text('${post.likesCount.value}',
                  style: feedText(large ? 12 : 11, weight: FontWeight.w600, color: kFeedSoft)),
            ],
          ),
        ),
      );
    });
  }
}

/// True for the post's own author (edit + delete) or an admin (delete).
bool feedCanManage(Post p) {
  final me = Get.find<AuthController>().logInUser;
  if (me == null) return false;
  return '${p.author.id ?? p.userId}' == '${me.id}' || me.userType == 'Admin';
}

/// "Your post" sheet: Edit, Delete, Cancel. Admins on someone else's
/// post only get Delete.
Future<void> showFeedPostOptions(BuildContext context, Post post,
    {VoidCallback? onDeleted}) async {
  final me = Get.find<AuthController>().logInUser;
  final mine = '${post.author.id ?? post.userId}' == '${me?.id}';

  Widget row(IconData icon, Color tint, Color bg, String title, String sub, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18.sp, color: tint),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: feedText(13.5, weight: FontWeight.w700, color: tint == kFeedDeep ? kFeedInk : tint)),
                    Text(sub, style: feedText(11, color: kFeedSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    barrierColor: kFeedInk.withOpacity(0.35),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(color: kFeedBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: 16.h),
            Text(mine ? 'Your post' : 'Post options', style: feedText(15, weight: FontWeight.w800)),
            SizedBox(height: 8.h),
            if (mine)
              row(Icons.edit_outlined, kFeedDeep, kFeedMint, 'Edit post', 'Fix a typo or change the photo', () {
                Navigator.pop(ctx);
                Get.to(() => CreatePostScreen(editing: post));
              }),
            row(Icons.delete_outline_rounded, const Color(0xFFD64545), const Color(0xFFFDECEC),
                'Delete post', "This can't be undone", () async {
              Navigator.pop(ctx);
              final ok = await Get.find<PostController>().deletePostNow(post.id);
              if (ok) onDeleted?.call();
            }),
            SizedBox(height: 12.h),
            SizedBox(
              height: 48.h,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kFeedBorder, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Cancel', style: feedText(14, weight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// White background with the two soft mint circles, like signup.
class FeedBackground extends StatelessWidget {
  final Widget child;
  const FeedBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60.h,
          right: -70.w,
          child: Container(
            width: 230.w,
            height: 230.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: kFeedMint.withOpacity(0.6)),
          ),
        ),
        Positioned(
          bottom: 160.h,
          left: -60.w,
          child: Container(
            width: 170.w,
            height: 170.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: kFeedMint.withOpacity(0.35)),
          ),
        ),
        child,
      ],
    );
  }
}
