import 'dart:io';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../data/controllers/post_controller.dart';
import '../../../helper/permissions.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';

/// Mirrors `_canPostFreely` in feed_screen.dart — kept duplicated rather
/// than extracted so each file in the posts_module stays self-contained
/// and the gating change in one doesn't surprise callers of the other.
/// Trainers and dietitians bypass the paywall; everyone else still gates
/// on `hasActivePackage`. Backend role literals: 'Trainer', 'Dietition'.
bool _canPostFreely() {
  final type = Get.find<AuthController>().logInUser?.userType;
  if (type == Constants.trainer || type == Constants.dietitian) return true;
  return Get.find<HomeController>().hasActivePackage;
}

// V2 design tokens — mirrors lib/docs/newdesign.md §2 / feed_screen.dart.
const _kCream = Color(0xFFEAF7E4);
const _kCardBorder = Color(0xFFD8EDD4);
const _kTextPrimary = Color(0xFF163220);
const _kTextSecondary = Color(0xFF6F8B7A);
const _kSage = Color(0xFF9AB09A);
const _kAccent = Color(0xFF6DC55A);
const _kShadowTint = Color(0xFF163220);

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final controller = Get.find<PostController>();
  final TextEditingController content = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.postImageFile = null;
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _composeCard(),
                      SizedBox(height: 14.h),
                      _imageSection(),
                      SizedBox(height: 24.h),
                      _publishButton(),
                    ],
                  ),
                ),
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
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 8.h),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _kTextPrimary, size: 22),
            onPressed: () => Get.back(),
          ),
          const Spacer(),
          const Text(
            'NEW POST',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kSage,
              letterSpacing: 0.84,
            ),
          ),
          const Spacer(),
          // Trailing balance for the back button so the title stays centred.
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─── Compose card (text input + char count) ────────────────────────────

  Widget _composeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kShadowTint.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextFormField(
            controller: content,
            maxLength: 1000,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: _kTextPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: "What's on your mind? Share your thoughts…",
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                color: _kSage,
                fontSize: 13.sp,
              ),
              border: InputBorder.none,
              counterText: '', // hide the default counter; custom one below
              contentPadding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: content,
            builder: (_, value, __) => Padding(
              padding: EdgeInsets.only(right: 14.w, bottom: 10.h),
              child: Text(
                "${value.text.length}/1000",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: _kSage,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image section (picker placeholder OR preview with remove button) ──

  Widget _imageSection() {
    return GetBuilder<PostController>(builder: (ctrl) {
      if (ctrl.postImageFile != null) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kShadowTint.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.file(
                  ctrl.postImageFile!,
                  height: 260.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ctrl.postImageFile = null;
                      ctrl.update();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kShadowTint.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            _showMediaSheet(context, _getFromGallery, _getFromCamera),
        child: Container(
          height: 160.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 22.sp,
                  color: _kAccent,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Add a photo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: _kTextPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Tap to choose from camera or gallery',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: _kTextSecondary,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── Publish button ────────────────────────────────────────────────────

  Widget _publishButton() {
    return Obx(() {
      // `createPostLoad` is true when idle, false while submitting (matches
      // the previous file's inverted convention — preserved verbatim).
      final isSubmitting = !controller.createPostLoad.value;
      return SizedBox(
        width: double.infinity,
        height: 50.h,
        child: isSubmitting
            ? const Center(
                child: CircularProgressIndicator(color: _kAccent))
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onPublishTap,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Publish',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
      );
    });
  }

  Future<void> _onPublishTap() async {
    if (!_canPostFreely()) {
      CustomToast.failToast(
          msg:
              "You need an active package to create posts. Please subscribe to a plan first.");
      return;
    }
    if (content.text.isEmpty && controller.postImageFile == null) {
      CustomToast.failToast(
          msg: "You need to add content and image to create a post.");
      return;
    }
    final post = await controller.createPost(text: content.text);
    if (post == null) return;
    // Only show the moderation popup when the backend actually held the post
    // for admin review (regular paid user posting an image). Trainers,
    // dietitians and text-only posts are auto-approved → just close.
    if (post.approved) {
      Get.back();
      return;
    }
    HelpingWidgets.showCustomDialog(
      context,
      () {
        Get.back();
        Get.back();
      },
      "Wait for Approval!",
      "Your post will be displayed once approved by Admin.",
      MyImgs.doneTick,
      buttonText: "Got it!",
    );
  }

  // ─── Media picker bottom sheet ─────────────────────────────────────────

  void _showMediaSheet(
      BuildContext context, Function gallery, Function camera) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            20.w, 14.h, 20.w, 22.h + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kSage.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 14.h),
            const Text(
              'ADD PHOTO FROM',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kSage,
                letterSpacing: 0.77,
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mediaOption(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera',
                  onTap: () {
                    Get.back();
                    camera(context);
                  },
                ),
                _mediaOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Get.back();
                    gallery(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _mediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24.sp, color: _kAccent),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Camera / gallery (UNCHANGED — preserves existing flows) ──────────

  Future<void> _getFromCamera(BuildContext context) async {
    PermissionOfPhotos().getFromCamera(context).then((value) async {
      if (value) {
        final pickedFile =
            await ImagePicker().pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          var imagePath = pickedFile.path;
          final dir1 = Directory.systemTemp;
          final targetPath1 =
              "${dir1.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
          var compressedFile1 = await FlutterImageCompress.compressAndGetFile(
              imagePath, targetPath1,
              quality: 60);
          controller.postImageFile = File(compressedFile1!.path);
          controller.update();
          Get.find<AuthController>().i++;
        }
      } else {
        print(value);
      }
    });
  }

  Future<void> _getFromGallery(BuildContext context) async {
    PermissionOfPhotos().getFromGallery(context).then((value) async {
      if (value) {
        final pickedFile =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          var imagePath = pickedFile.path;
          final dir1 = Directory.systemTemp;
          final targetPath1 =
              "${dir1.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
          var compressedFile1 = await FlutterImageCompress.compressAndGetFile(
              imagePath, targetPath1,
              quality: 60);
          controller.postImageFile = File(compressedFile1!.path);
          controller.update();
          Get.find<AuthController>().i++;
        }
      } else {
        print(value);
      }
    });
  }
}
