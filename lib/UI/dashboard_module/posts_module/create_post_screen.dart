import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/post_controller.dart';
import '../../../data/models/post_model.dart';
import '../../../helper/permissions.dart';
import '../../../widgets/toasts.dart';
import 'feed_widgets.dart';

/// Create a post, or edit one of her own ([editing]).
/// Old screen kept as create_post_screen.dart.bak_feed.
class CreatePostScreen extends StatefulWidget {
  final Post? editing;

  /// Open the camera straight away (camera button on the feed composer).
  final bool openCamera;

  const CreatePostScreen({super.key, this.editing, this.openCamera = false});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _max = 500;
  final PostController controller = Get.find();
  final TextEditingController _text = TextEditingController();

  File? _newImage;
  String? _oldImageUrl; // editing: the photo already on the post
  bool _busy = false;

  bool get _editing => widget.editing != null;
  bool get _hasImage => _newImage != null || _oldImageUrl != null;
  bool get _canSend => !_busy && (_text.text.trim().isNotEmpty || _hasImage);

  @override
  void initState() {
    super.initState();
    controller.postImageFile = null;
    final e = widget.editing;
    if (e != null) {
      _text.text = e.text;
      _oldImageUrl = (e.imageUrl?.isNotEmpty ?? false) ? e.imageUrl : null;
    }
    _text.addListener(() => setState(() {}));
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(ImageSource.camera));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final perm = source == ImageSource.camera
        ? await PermissionOfPhotos().getFromCamera(context)
        : await PermissionOfPhotos().getFromGallery(context);
    if (!perm) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final auth = Get.find<AuthController>();
    final target = '${Directory.systemTemp.absolute.path}/post${auth.i}.jpg';
    auth.i++;
    final compressed = await FlutterImageCompress.compressAndGetFile(picked.path, target, quality: 60);
    if (!mounted) return;
    setState(() => _newImage = File(compressed?.path ?? picked.path));
  }

  void _removeImage() => setState(() {
        _newImage = null;
        _oldImageUrl = null;
      });

  Future<void> _submit() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final text = _text.text.trim();

    if (_editing) {
      final hadImage = widget.editing!.imageUrl?.isNotEmpty ?? false;
      final ok = await controller.editPost(
        postId: widget.editing!.id,
        text: text,
        newImage: _newImage,
        removeImage: hadImage && _newImage == null && _oldImageUrl == null,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) Get.back();
      return;
    }

    controller.postImageFile = _newImage;
    final post = await controller.createPost(text: text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (post == null) return;
    // Members' photo posts are checked by the team before they show.
    if (!post.approved) {
      CustomToast.successToast(msg: "Thanks! Your post will show once our team has had a quick look.");
    } else {
      controller.getAllPosts(silent: true);
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final u = Get.find<AuthController>().logInUser;
    final n = (u?.firstName ?? '').trim();
    final me = FeedAuthor(id: u?.id, name: n.isEmpty ? 'Me' : n, userType: u?.userType);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FeedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: close, title, Post
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kFeedBorder, width: 1.5),
                        ),
                        child: Icon(Icons.close_rounded, size: 18.sp, color: kFeedInk),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(_editing ? 'Edit post' : 'Create post',
                            style: feedText(16, weight: FontWeight.w700)),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
                        decoration: BoxDecoration(
                          color: _canSend ? kFeedGreen : kFeedGreen.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_editing ? 'Save' : 'Post',
                                style: feedText(13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                  children: [
                    Row(
                      children: [
                        FeedAvatar(author: me, size: 36),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.name, style: feedText(13.5, weight: FontWeight.w700)),
                            SizedBox(height: 3.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: kFeedMint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 10.sp, color: kFeedDeep),
                                  SizedBox(width: 4.w),
                                  Text('FitHer members only',
                                      style: feedText(9.5, weight: FontWeight.w600, color: kFeedDeep)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _text,
                      autofocus: !widget.openCamera && !_editing,
                      minLines: 4,
                      maxLines: null,
                      maxLength: _max,
                      textCapitalization: TextCapitalization.sentences,
                      style: feedText(14, height: 1.5),
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: 'Share a meal, a win or a question…',
                        hintStyle: feedText(14, color: kFeedMuted),
                      ),
                    ),
                    if (_hasImage) ...[
                      SizedBox(height: 8.h),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: kFeedPhotoBg,
                              width: double.infinity,
                              constraints: BoxConstraints(maxHeight: 300.h),
                              child: _newImage != null
                                  ? Image.file(_newImage!, fit: BoxFit.cover, width: double.infinity)
                                  : FeedPostImage(url: _oldImageUrl!),
                            ),
                          ),
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                width: 30.w,
                                height: 30.w,
                                decoration: BoxDecoration(
                                  color: kFeedInk.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close_rounded, size: 16.sp, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 14.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: kFeedMintSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 16.sp, color: kFeedDeep),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Only FitHer members can see your post. Keep it kind and supportive.',
                              style: feedText(11.5, color: kFeedSoft, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom bar: Photo, Camera, counter
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: kFeedBorder.withOpacity(0.7))),
                ),
                child: Row(
                  children: [
                    _chip(Icons.photo_outlined, 'Photo', const Color(0xFFFDEDEA), const Color(0xFFD9534F),
                        () => _pick(ImageSource.gallery)),
                    SizedBox(width: 8.w),
                    _chip(Icons.photo_camera_outlined, 'Camera', const Color(0xFFECE6FA), const Color(0xFF6A4FB3),
                        () => _pick(ImageSource.camera)),
                    const Spacer(),
                    Text('${_text.text.length} / $_max', style: feedText(11, color: kFeedSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 15.sp, color: fg),
              SizedBox(width: 6.w),
              Text(label, style: feedText(12, weight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      );
}
