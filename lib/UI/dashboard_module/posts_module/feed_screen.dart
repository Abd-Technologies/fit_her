import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../UI/plans_module/all_plans.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/post_controller.dart';
import '../../../data/controllers/socket_controller.dart';
import '../../../data/models/post_model.dart';
import '../../../widgets/circular_progress.dart';
import '../home_screen/notification_screen.dart';
import 'create_post_screen.dart';
import 'feed_widgets.dart';
import 'post_detail_screen.dart';

/// FitHer Feed (design direction C).
///
/// Members with a plan and staff can post and reply. Trial and free users
/// can read and like; the composer shows what posting unlocks.
/// Old screen kept as feed_screen.dart.bak_feed.
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
        backgroundColor: Colors.white,
        body: FeedBackground(
          child: SafeArea(
            child: Obx(() {
              final loading = !controller.allPostsLoad.value;
              // Newest first. The server sends oldest first.
              final posts = controller.postsList
                  .where((p) => p.approved && p.isPost)
                  .toList()
                  .reversed
                  .toList();
              return RefreshIndicator(
                color: kFeedGreen,
                onRefresh: () async => controller.getAllPosts(silent: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                  children: [
                    _header(),
                    SizedBox(height: 14.h),
                    controller.canPost ? _composer() : _lockedComposer(),
                    SizedBox(height: 8.h),
                    if (loading)
                      Padding(
                        padding: EdgeInsets.only(top: 60.h),
                        child: const Center(child: CircularProgress()),
                      )
                    else if (posts.isEmpty)
                      _empty()
                    else
                      for (int i = 0; i < posts.length; i++) ...[
                        _FeedPostTile(post: posts[i]),
                        if (i < posts.length - 1)
                          Divider(height: 1, thickness: 1, color: kFeedBorder.withOpacity(0.7)),
                      ],
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: kFeedMint, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: const BoxDecoration(color: kFeedGreen, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 5.w),
                    Text('Community', style: feedText(10.5, weight: FontWeight.w600, color: const Color(0xFF5A7A56))),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'FitHer ', style: feedText(22, weight: FontWeight.w800)),
                  TextSpan(text: 'Feed', style: feedText(22, weight: FontWeight.w800, color: kFeedGreen)),
                ]),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Get.to(() => const NotificationScreen()),
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kFeedBorder, width: 1.5),
            ),
            child: Icon(Icons.notifications_none_rounded, size: 20.sp, color: kFeedInk),
          ),
        ),
      ],
    );
  }

  FeedAuthor get _me {
    final u = Get.find<AuthController>().logInUser;
    final n = (u?.firstName ?? '').trim();
    return FeedAuthor(id: u?.id, name: n.isEmpty ? 'Me' : n, userType: u?.userType);
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kFeedBorder),
      ),
      child: Row(
        children: [
          FeedAvatar(author: _me, size: 30),
          SizedBox(width: 8.w),
          Expanded(
            child: GestureDetector(
              onTap: () => Get.to(() => const CreatePostScreen()),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(color: kFeedField, borderRadius: BorderRadius.circular(12)),
                child: Text('Share a meal, a win or a question…',
                    style: feedText(12, color: kFeedSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => Get.to(() => const CreatePostScreen(openCamera: true)),
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(color: const Color(0xFFFDEDEA), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.photo_camera_outlined, size: 18.sp, color: const Color(0xFFD9534F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedComposer() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: kFeedMintSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kFeedBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FeedAvatar(author: _me, size: 30),
              SizedBox(width: 8.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kFeedBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14.sp, color: kFeedMuted),
                      SizedBox(width: 6.w),
                      Text('Share with the community', style: feedText(12, color: kFeedMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'You can read and like posts. ', style: feedText(11, color: kFeedSoft, height: 1.4)),
                    TextSpan(
                        text: 'Posting and replies unlock with a plan.',
                        style: feedText(11, weight: FontWeight.w700, height: 1.4)),
                  ]),
                ),
              ),
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: () => Get.to(() => OurPlansScreen()),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                  decoration: BoxDecoration(color: kFeedGreen, borderRadius: BorderRadius.circular(12)),
                  child: Text('See plans', style: feedText(12, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: EdgeInsets.only(top: 60.h),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: const BoxDecoration(color: kFeedMint, shape: BoxShape.circle),
            child: Icon(Icons.forum_outlined, color: kFeedDeep, size: 28.sp),
          ),
          SizedBox(height: 12.h),
          Text('No posts yet', style: feedText(15, weight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text(
            controller.canPost ? 'Be the first to share a meal or a win.' : 'Posts from the community will show here.',
            style: feedText(12, color: kFeedSoft),
          ),
        ],
      ),
    );
  }
}

/// One post in the feed: header, text, photo, like and reply counts, and
/// a peek at the first reply.
class _FeedPostTile extends StatelessWidget {
  final Post post;
  const _FeedPostTile({required this.post});

  void _open() => Get.to(() => PostDetailScreen(postId: post.id));

  @override
  Widget build(BuildContext context) {
    final canPost = Get.find<PostController>().canPost;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedPostHeader(
              post: post,
              onMore: feedCanManage(post) ? () => showFeedPostOptions(context, post) : null,
            ),
            Padding(
              padding: EdgeInsets.only(left: 44.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.text.trim().isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(post.text, style: feedText(13, height: 1.5)),
                  ],
                  if (post.imageUrl?.isNotEmpty ?? false) ...[
                    SizedBox(height: 10.h),
                    FeedPostImage(url: post.imageUrl!),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      FeedLikeButton(post: post),
                      SizedBox(width: 18.w),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _open,
                        child: Obx(() => Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 15.sp, color: kFeedSoft),
                                SizedBox(width: 4.w),
                                Text('${post.replies.length}',
                                    style: feedText(11, weight: FontWeight.w600, color: kFeedSoft)),
                                if (!canPost) ...[
                                  SizedBox(width: 3.w),
                                  Icon(Icons.lock_outline_rounded, size: 11.sp, color: kFeedMuted),
                                ],
                              ],
                            )),
                      ),
                    ],
                  ),
                  Obx(() {
                    if (post.replies.isEmpty) return const SizedBox.shrink();
                    final r = post.replies.first;
                    return Container(
                      margin: EdgeInsets.only(top: 8.h),
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: kFeedMintSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FeedAvatar(author: r.author, size: 22),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.author.name, style: feedText(11.5, weight: FontWeight.w700)),
                                Text(r.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: feedText(11.5, color: kFeedSoft, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
