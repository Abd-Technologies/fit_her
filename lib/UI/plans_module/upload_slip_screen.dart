import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/helper/permissions.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';

/// Dedicated "upload payment slip" screen — the manual-payment branch of
/// the new SelectPaymentMode picker. Wave 0 (P-01): picker errors stay
/// inside the card (never a toast while the picker is open), Submit shows
/// a loading state, and success explains next steps.
class UploadSlipScreen extends StatefulWidget {
  const UploadSlipScreen({
    super.key,
    required this.planId,
    required this.durationId,
    required this.price,
  });

  final String planId;
  final String price;
  final int durationId;

  @override
  State<UploadSlipScreen> createState() => _UploadSlipScreenState();
}

class _UploadSlipScreenState extends State<UploadSlipScreen> {
  final HomeController homeController = Get.find();

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);
  static const _kError = Color(0xFFB42318);
  static const _kErrorBg = Color(0xFFFEECEC);

  String? _inlineError;
  bool _picking = false;
  bool _uploading = false;
  String _statusLine = 'Not uploaded yet';

  @override
  void dispose() {
    // Clear any half-picked image when leaving so a later visit starts clean.
    if (!_uploading) {
      homeController.planPicture = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Status: $_statusLine',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GetBuilder<HomeController>(builder: (cont) {
                  final picked = cont.planPicture;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _picking || _uploading
                        ? null
                        : () => _selectMediaBottomSheet(context),
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _inlineError != null
                              ? _kError.withOpacity(0.55)
                              : _kCardBorder,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kTextPrimary.withOpacity(0.06),
                            offset: const Offset(0, 6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: picked != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    File(picked.path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                if (_picking)
                                  Container(
                                    color: Colors.black26,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_picking)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: CircularProgressIndicator(
                                      color: _kAccent,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 72,
                                    height: 72,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
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
                                Text(
                                  _picking
                                      ? 'Opening camera / gallery…'
                                      : 'Tap to upload slip',
                                  style: const TextStyle(
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
              if (_inlineError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kErrorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kError.withOpacity(0.25)),
                  ),
                  child: Text(
                    _inlineError!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kError,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _uploading || _picking ? null : _onSubmit,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _uploading || _picking ? 0.7 : 1,
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
                    child: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
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
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _uploading ? null : () => Get.back(),
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

  Future<void> _onSubmit() async {
    if (homeController.planPicture == null) {
      setState(() {
        _inlineError =
            'Please choose a camera or gallery photo before uploading.';
      });
      return;
    }
    setState(() {
      _inlineError = null;
      _uploading = true;
      _statusLine = 'Sending…';
    });
    final success = await homeController.addPlanBuyImage(
      widget.planId,
      widget.durationId,
      widget.price,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (success) {
      setState(() => _statusLine = 'Sent · Under review');
      HelpingWidgets.showCustomDialog(context, () {
        Get.back();
        Get.back(); // close upload screen
        Get.back(); // close payment-method picker
      },
          "Successfully Uploaded!",
          "Our team is reviewing your payment. Status: Sent → Under review → "
              "Active. You will get a confirmation when your plan turns on.",
          MyImgs.logo,
          buttonText: "OK");
    } else {
      setState(() {
        _statusLine = 'Upload failed — try again';
        _inlineError =
            'We could not upload your slip. Check your connection and try again.';
      });
    }
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
                  onTap: () async {
                    await Get.back();
                    if (!mounted) return;
                    await _pickFrom(ImageSource.camera);
                  },
                ),
                _sourceTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () async {
                    await Get.back();
                    if (!mounted) return;
                    await _pickFrom(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      isDismissible: !_picking,
      enableDrag: !_picking,
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

  Future<void> _pickFrom(ImageSource source) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _inlineError = null;
    });

    try {
      final granted = source == ImageSource.camera
          ? await PermissionOfPhotos().getFromCamera(context)
          : await PermissionOfPhotos().getFromGallery(context);
      if (!granted) {
        if (mounted) {
          setState(() {
            _picking = false;
            _inlineError = source == ImageSource.camera
                ? 'Camera permission is required to take a slip photo.'
                : 'Gallery permission is required to pick a slip photo.';
          });
        }
        return;
      }

      // Let the permission UI settle before opening the system picker so
      // we never race a toast/error against the still-open camera UI.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) {
        // User dismissed the picker with no image — show inline error only
        // after the picker is gone (Wave 0 P-01).
        if (mounted) {
          setState(() {
            _picking = false;
            if (homeController.planPicture == null) {
              _inlineError = 'No image selected. Tap the card to try again.';
            }
          });
        }
        return;
      }

      final dir = Directory.systemTemp;
      final targetPath =
          "${dir.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
      final compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 60,
      );
      if (compressed == null) {
        if (mounted) {
          setState(() {
            _picking = false;
            _inlineError = 'Could not process that image. Please try another.';
          });
        }
        return;
      }

      homeController.planPicture = XFile(compressed.path);
      homeController.update();
      Get.find<AuthController>().i++;
      Get.find<AuthController>().update();

      if (mounted) {
        setState(() {
          _picking = false;
          _inlineError = null;
          _statusLine = 'Photo ready · tap Upload';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _picking = false;
          _inlineError = 'Something went wrong opening the picker. Try again.';
        });
      }
    }
  }
}
