import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../UI/plans_module/all_plans.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/post_controller.dart';
import '../../../data/controllers/socket_controller.dart';
import '../../../data/models/post_model.dart';
import 'feed_widgets.dart';

/// One post with all its replies. Members with a plan and staff can reply;
/// trial users see the replies and a "unlock with a plan" bar instead of
/// the reply box.
class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostController controller = Get.find();
  final SocketController socket = Get.find();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    socket.joinPost(widget.postId);
  }

  @override
  void dispose() {
    socket.leavePost(widget.postId);
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Post? get _post => controller.postsList.firstWhereOrNull((p) => p.id == widget.postId);

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await controller.sendReplyNow(postId: widget.postId, message: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _input.clear();
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 150));
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  /// "Reply" under a reply: start the message with her name.
  void _replyTo(Reply r) {
    if (!controller.canPost) return;
    final first = r.author.name.split(' ').first;
    _input.text = '@$first ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: kFeedBorder, width: 1.5),
          ),
          child: Icon(icon, size: 18.sp, color: kFeedInk),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FeedBackground(
        child: SafeArea(
          child: Obx(() {
            final post = _post;
            final canPost = controller.canPost;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                  child: Row(
                    children: [
                      _circleButton(Icons.arrow_back_ios_new_rounded, () => Get.back()),
                      Expanded(
                        child: Center(child: Text('Post', style: feedText(16, weight: FontWeight.w700))),
                      ),
                      if (post != null && feedCanManage(post))
                        _circleButton(Icons.more_horiz_rounded,
                            () => showFeedPostOptions(context, post, onDeleted: () => Get.back()))
                      else
                        SizedBox(width: 38.w),
                    ],
                  ),
                ),
                Expanded(
                  child: post == null
                      ? Center(child: Text('This post is no longer available', style: feedText(13, color: kFeedSoft)))
                      : ListView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                          children: [
                            FeedPostHeader(post: post, avatar: 38),
                            if (post.text.trim().isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              Text(post.text, style: feedText(14, height: 1.55)),
                            ],
                            if (post.imageUrl?.isNotEmpty ?? false) ...[
                              SizedBox(height: 12.h),
                              FeedPostImage(url: post.imageUrl!),
                            ],
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                FeedLikeButton(post: post, large: true),
                                SizedBox(width: 18.w),
                                Icon(Icons.chat_bubble_outline_rounded, size: 16.sp, color: kFeedSoft),
                                SizedBox(width: 4.w),
                                Text(
                                  '${post.replies.length} ${post.replies.length == 1 ? 'reply' : 'replies'}',
                                  style: feedText(12, weight: FontWeight.w600, color: kFeedSoft),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Divider(height: 1, color: kFeedBorder.withOpacity(0.8)),
                            ),
                            Text('Replies', style: feedText(14, weight: FontWeight.w700)),
                            SizedBox(height: 10.h),
                            if (post.replies.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                child: Center(
                                  child: Text(
                                    canPost ? 'No replies yet. Say something kind.' : 'No replies yet.',
                                    style: feedText(12, color: kFeedSoft),
                                  ),
                                ),
                              )
                            else
                              ...post.replies.map((r) => _replyCard(r, canPost)),
                          ],
                        ),
                ),
                if (post != null) (canPost ? _inputBar() : _lockedBar()),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _replyCard(Reply r, bool canPost) {
    final staff = r.author.isStaff;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedAvatar(author: r.author, size: 30),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: staff ? kFeedMintSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: staff ? const Color(0xFFC9E8BF) : kFeedBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6.w,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(r.author.name, style: feedText(12, weight: FontWeight.w700)),
                          FeedRoleChip(author: r.author),
                          Text('· ${feedTime(r.createdAt)}', style: feedText(10, color: kFeedMuted)),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(r.message, style: feedText(12.5, height: 1.45)),
                    ],
                  ),
                ),
                if (canPost)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _replyTo(r),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 6.h, 12.w, 2.h),
                      child: Text('Reply', style: feedText(11, weight: FontWeight.w600, color: kFeedSoft)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final u = Get.find<AuthController>().logInUser;
    final n = (u?.firstName ?? '').trim();
    final me = FeedAuthor(id: u?.id, name: n.isEmpty ? 'Me' : n, userType: u?.userType);
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kFeedBorder.withOpacity(0.7))),
      ),
      child: Row(
        children: [
          FeedAvatar(author: me, size: 30),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              style: feedText(13),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Write a reply…',
                hintStyle: feedText(13, color: kFeedMuted),
                isDense: true,
                filled: true,
                fillColor: kFeedField,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: kFeedBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: kFeedBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: kFeedGreen),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(color: kFeedGreen, shape: BoxShape.circle),
              child: _sending
                  ? Padding(
                      padding: EdgeInsets.all(12.w),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.send_rounded, size: 18.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: kFeedMintSoft,
        border: Border(top: BorderSide(color: kFeedBorder.withOpacity(0.7))),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16.sp, color: kFeedSoft),
          SizedBox(width: 8.w),
          Expanded(
            child: Text('Replies unlock with a plan. You can still like posts.',
                style: feedText(11.5, color: kFeedSoft, height: 1.4)),
          ),
          SizedBox(width: 8.w),
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
    );
  }
}
