import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/helper/permissions.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/anim/check_draw.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:fitness_zone_2/values/my_colors.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';

/// Dedicated "upload payment slip" screen — the manual-payment branch of
/// the new SelectPaymentMode picker. Pick image (camera/gallery) → upload
/// → review-pending dialog. Lifts the slip-upload UI out of the old
/// combined picker screen so each method has a clean surface.
class UploadSlipScreen extends StatelessWidget {
  UploadSlipScreen({
    super.key,
    required this.planId,
    required this.durationId,
    required this.price,
  });

  final String planId;
  final String price;
  final int durationId;

  final HomeController homeController = Get.find();

  // Opens Camera / Gallery by itself once, right after the screen comes in
  // (Oct 2026), so she can go straight on. (Holder: this is a stateless
  // widget, so the "already opened" flag lives in a final list.)
  final List<bool> _autoOpened = [false];

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!_autoOpened[0] && homeController.planPicture == null) {
      _autoOpened[0] = true;
      // Wait for the page slide to finish, then show Camera / Gallery.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (context.mounted && homeController.planPicture == null) {
          _selectMediaBottomSheet(context);
        }
      });
    }
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: HelpingWidgets().appBarWidget(() {
        homeController.planPicture = null;
        homeController.update();
        Get.back();
      }, text: "Upload Slip"),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            children: [
              const Text(
                'Upload your payment receipt',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Snap or pick a clear photo of your transfer / deposit slip. '
                'Our team verifies it within a few hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _kSage,
                  height: 1.5,
                ),
              ),
              // Fit Her accounts are NOT shown in the app for now (Google Play
              // payments policy). Re-enable with: PaymentAccountsCard(price: price)
              const SizedBox(height: 20),
              Expanded(
                child: GetBuilder<HomeController>(builder: (cont) {
                  final picked = cont.planPicture;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectMediaBottomSheet(context),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kCardBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _kTextPrimary.withOpacity(0.06),
                            offset: const Offset(0, 6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: picked != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                File(picked.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _kIconWashBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: SvgPicture.asset(MyImgs.upload),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tap to upload slip',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'JPG or PNG, up to 5 MB',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: _kSage,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (homeController.planPicture == null) {
                    CustomToast.failToast(msg: "Please select an image first");
                    return;
                  }
                  final success = await homeController.addPlanBuyImage(
                      planId, durationId, price);
                  if (success) {
                    if (!context.mounted) return;
                    _showUploadedDialog(context);
                  }
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withOpacity(0.32),
                        offset: const Offset(0, 6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Upload payment slip',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.back(),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kSage,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectMediaBottomSheet(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera',
                  onTap: () {
                    Get.back();
                    _getFromCamera(context);
                  },
                ),
                _sourceTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Get.back();
                    _getFromGallery(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kIconWashBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: _kAccent),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Preserved verbatim from SelectPaymentMode — same compress + XFile
  // assignment so HomeController.addPlanBuyImage gets the same shape it
  // had before.
  Future<void> _getFromCamera(BuildContext context) async {
    final granted =
        await PermissionOfPhotos().getFromCamera(context);
    if (!granted) return;
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    final dir = Directory.systemTemp;
    final targetPath =
        "${dir.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
    final compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path, targetPath,
        quality: 60);
    if (compressed == null) return;
    homeController.planPicture = XFile(compressed.path);
    homeController.update();
    Get.find<AuthController>().i++;
    Get.find<AuthController>().update();
  }

  Future<void> _getFromGallery(BuildContext context) async {
    final granted =
        await PermissionOfPhotos().getFromGallery(context);
    if (!granted) return;
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final dir = Directory.systemTemp;
    final targetPath =
        "${dir.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
    final compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path, targetPath,
        quality: 60);
    if (compressed == null) return;
    homeController.planPicture = XFile(compressed.path);
    homeController.update();
    Get.find<AuthController>().i++;
    Get.find<AuthController>().update();
  }

  /// "Successfully Uploaded!" box with a self-drawing tick. OK goes back
  /// to the same screen as before (below the payment-method picker), but
  /// in ONE transition instead of three pops one after another.
  void _showUploadedDialog(BuildContext screenContext) {
    final textTheme = Theme.of(screenContext).textTheme;
    // Oct 2026: the AI verified the slip and her plan is already on.
    final auto = Get.find<HomeController>().lastSlipAutoApproved.value;
    showDialog(
      context: screenContext,
      builder: (dialogContext) => Dialog(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FhCheckDraw(76, _kAccent),
              const SizedBox(height: 14),
              Text(
                auto ? "Payment verified 🎉" : "Successfully Uploaded!",
                style: textTheme.bodyMedium!.copyWith(
                    color: MyColors.black, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                auto
                    ? "Welcome to Fit Her! Your plan is active now."
                    : "Our team is reviewing your payment, and you will "
                        "receive a confirmation shortly. Please wait "
                        "for approval.",
                style: textTheme.titleLarge!.copyWith(
                    fontSize: 13,
                    color: MyColors.black.withOpacity(0.5),
                    fontWeight: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: auto ? "Let's start" : "OK",
                      // Plan active: "Let's start" goes to her (paid) home.
                      onPressed: () => auto
                          ? Get.offAll(() => BottomBarScreen(index: 0))
                          : _closeToOrigin(screenContext, dialogContext),
                      height: 40,
                      fontSize: 14,
                      roundCorner: 25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Same destination as the old Get.back() x3 (dialog, this screen,
  /// payment-method picker), but the picker is removed silently first so
  /// she sees a single smooth move back.
  void _closeToOrigin(BuildContext screenContext, BuildContext dialogContext) {
    final dialogNav = Navigator.maybeOf(dialogContext);
    if (dialogNav == null || !screenContext.mounted) {
      Get.back();
      Get.back(); // close upload screen
      Get.back(); // close payment-method picker
      return;
    }
    dialogNav.pop(); // close the dialog
    final nav = Navigator.maybeOf(screenContext);
    final route = ModalRoute.of(screenContext);
    if (nav == null || route == null || !route.isActive) {
      Get.back(); // close upload screen
      Get.back(); // close payment-method picker
      return;
    }
    try {
      nav.removeRouteBelow(route); // payment-method picker, no animation
    } catch (_) {
      Get.back(); // close upload screen
      Get.back(); // close payment-method picker
      return;
    }
    nav.pop(); // this screen: the one visible transition
  }
}
