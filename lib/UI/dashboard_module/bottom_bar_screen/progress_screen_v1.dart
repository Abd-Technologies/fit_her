import 'dart:io';

import 'package:fitness_zone_2/UI/dashboard_module/measurement_screen/measurement_screen.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/helper/analytics_helper.dart';
import 'package:fitness_zone_2/helper/private_file_url.dart';
import 'package:fitness_zone_2/data/controllers/progress_controller/progress_controller.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../helper/permissions.dart';
import '../../../values/my_colors.dart';

/// Phase D1 — renamed from `ProgressScreen`. Class kept under the new
/// name so `bottom_bar_screen.dart` can route to V1 vs V2 by class name.
/// Functionally identical to the pre-rebuild screen — Weekly Progress +
/// Photo Library tabs. Users with `useNewProgressHub == false` continue to
/// land here. The new hub is `ProgressScreenV2`.
class ProgressScreenV1 extends StatelessWidget {
  ProgressScreenV1({super.key});
  final List<String> images = [
    MyImgs.before,
    MyImgs.after,
  ];
  AuthController authController = Get.find();
  ProgressController progressController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          // leadingWidth: 70.w,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: MyColors.primaryGradient1),
          title: Text(
            "Progress",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 20.sp,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 10.h),
            indicatorColor: MyColors.primaryGradient1,
            labelColor: MyColors.black,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle:
                textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(
                text: "Weekly Progress",
              ),
              Tab(
                text: "Photo Library",
              ),

            ],
          ),
        ),
        body: TabBarView(children: [

          authController.logInUser!.status
              ? _WeeklyProgressWithTracking(child: MeasureMentScreen())

          // ListView.separated(
          //         shrinkWrap: true,
          //         padding:
          //             EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
          //         itemCount: 5, // Number of stars (you can make this dynamic)
          //         itemBuilder: (context, index) {
          //           return Container(
          //             height: 185.h,
          //             width: double.maxFinite,
          //             decoration: BoxDecoration(
          //               color: Colors.white,
          //               borderRadius: BorderRadius.circular(25),
          //             ),
          //             child: Column(
          //               children: [
          //                 Row(
          //                   crossAxisAlignment: CrossAxisAlignment.end,
          //                   children: [
          //                     const CircleAvatar(
          //                       radius: 20,
          //
          //                       backgroundImage: AssetImage(MyImgs
          //                           .profilePicture1), // Replace with your image asset
          //                     ),
          //                     SizedBox(
          //                       width: 10.w,
          //                     ),
          //                     Column(
          //                       crossAxisAlignment: CrossAxisAlignment.start,
          //                       children: [
          //                         Text(
          //                           "Fatima Almas",
          //                           style: textTheme.bodyMedium!
          //                               .copyWith(fontWeight: FontWeight.w500),
          //                         ),
          //                         Row(
          //                           children: List.generate(5, (index) {
          //                             return Icon(
          //                               index < 4
          //                                   ? Icons.star
          //                                   : Icons
          //                                       .star_border, // 4 filled stars and 1 empty star
          //                               color: Colors.amber,
          //                               size: 14,
          //                             );
          //                           }),
          //                         ),
          //                       ],
          //                     ),
          //                   ],
          //                 ),
          //                 SizedBox(
          //                   height: 20.h,
          //                 ),
          //                 Expanded(
          //                   child: Text(
          //                     "Working with Fit Her has been a transformative experience. Their innovative health and wellness app, designed with user-centric features like workout schedules and diet consultations, truly stands out. The team's attention to detail and commitment to improving user experience is evident in every aspect of the app.",
          //                     style: textTheme.titleLarge!
          //                         .copyWith(fontWeight: FontWeight.w500),
          //                   ),
          //                 ),
          //                 SizedBox(
          //                   height: 20.h,
          //                 ),
          //                 Divider(
          //                   height: 2.h,
          //                   color: Color(0xffE2E1E1),
          //                 )
          //               ],
          //             ),
          //           );
          //         },
          //         separatorBuilder: (BuildContext context, int index) {
          //           return SizedBox(
          //             height: 25.h,
          //           );
          //         },
          //       )
              : HelpingWidgets().notSubscribed(),
          authController.logInUser!.status
              ? Obx(() => progressController.imagesProgressOfUser.value
                  ? GetBuilder<ProgressController>(builder: (con) {
                      return GridView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 10.h),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2 items per row
                          mainAxisSpacing: 30.h,
                          crossAxisSpacing: 20.w,
                          childAspectRatio:
                              0.8, // Adjust the aspect ratio to your needs
                        ),
                        itemCount: progressController.progressImagesList
                            .length, // Number of items in the grid
                        itemBuilder: (context, index) {
                          if (progressController.progressImagesList[index] ==
                                  null ||
                              progressController.progressImagesList[index]
                                  is File) {
                            var imagePath =
                                progressController.progressImagesList[index];
                            return GestureDetector(
                              onTap: () {
                                selectMediaBottomSheet(
                                    _getFromGallery,
                                    _getFromCamera,
                                    context,
                                    index ==
                                        (progressController
                                                .progressImagesList.length -
                                            2),
                                    progressController);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.4),
                                  image: imagePath == null
                                      ? null
                                      : DecorationImage(
                                          image: FileImage(
                                            imagePath,
                                          ),
                                          fit: BoxFit.cover),
                                  borderRadius: BorderRadius.circular(10),
                                  // color: Colors.blueAccent,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add,
                                    size: 30,
                                  ),
                                ),
                              ),
                            );
                          }

                          String? imagePath = progressController.progressImagesList[index];

                          return Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                // color: Colors.blueAccent,
                                boxShadow: [
                                  BoxShadow(
                                      offset: const Offset(0, 4),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                      color: Colors.black.withOpacity(0.25))
                                ],
                                image: DecorationImage(
                                    image: NetworkImage(
                                      privateFileUrl(imagePath!),
                                    ),
                                    fit: BoxFit.cover)),
                            // child: Center(
                            //   child:
                            // ),
                          );
                        },
                      );
                    })
                  : const CircularProgress())
              : HelpingWidgets().notSubscribed(),

        ]),
        bottomNavigationBar: GetBuilder<ProgressController>(builder: (con) {
          var length = con.progressImagesList.length;
          return con.progressImagesList[length - 2] == null ||
                  con.progressImagesList[length - 1] == null
              ? SizedBox()
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CustomButton(
                      text: 'Update Progress',
                      onPressed: () {
                        con.addProgressImages();
                      },
                    ),
                  ),
                );
        }),
      ),
    );
  }
}

/// Wrapper to track weekly progress report view
class _WeeklyProgressWithTracking extends StatefulWidget {
  final Widget child;

  const _WeeklyProgressWithTracking({required this.child});

  @override
  State<_WeeklyProgressWithTracking> createState() =>
      _WeeklyProgressWithTrackingState();
}

class _WeeklyProgressWithTrackingState extends State<_WeeklyProgressWithTracking> {
  @override
  void initState() {
    super.initState();
    AnalyticsHelper.trackWeeklyProgressReport();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

selectMediaBottomSheet(Function gallery, Function camera, BuildContext context,
    bool isBefore, ProgressController progressController) {
  final bottomInset = MediaQuery.of(context).padding.bottom;
  Get.bottomSheet(Container(
    height: 150 + bottomInset,
    padding: EdgeInsets.only(bottom: bottomInset),
    color: MyColors.bodyBackground,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.photo_camera,
                size: 30,
              ),
              onPressed: () {
                Get.back();
                camera(context, isBefore, progressController);
              },
            ),
            Text("From Camera".tr)
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.photo,
                size: 30,
              ),
              onPressed: () {
                Get.back();
                gallery(context, isBefore, progressController);
              },
            ),
            Text("From Gallery".tr)
          ],
        ),
      ],
    ),
  ));
}

/// Get from Camera
_getFromCamera(BuildContext context, bool isBefore,
    ProgressController progressController) async {
  PermissionOfPhotos().getFromCamera(context).then((value) async {
    if (value) {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        print("Picked File: ${pickedFile.path}");
        var imagePath = pickedFile.path;
        // Get.find<AuthController>().image = File(imagePath);
        // Get.find<AuthController>().update();

        var imageName = imagePath.split("/").last;
        print("Image Name: $imageName");
        final dir1 = Directory.systemTemp;
        final targetPath1 =
            "${dir1.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
        var compressedFile1 = await FlutterImageCompress.compressAndGetFile(
            imagePath, targetPath1,
            quality: 60);

        File file = File(compressedFile1!.path);
        var index = isBefore
            ? progressController.progressImagesList.length - 2
            : progressController.progressImagesList.length - 1;
        progressController.progressImagesList[index] = file;
        progressController.update();

        Get.find<AuthController>().i++;
      }
    } else {
      print(value);
    }
  });
}

_getFromGallery(BuildContext context, bool isBefore,
    ProgressController progressController) async {
  PermissionOfPhotos().getFromGallery(context).then((value) async {
    if (value) {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        print("Picked File: ${pickedFile.path}");
        var imagePath = pickedFile.path;
        // Get.find<AuthController>().image = File(imagePath);
        // Get.find<AuthController>().update();

        var imageName = imagePath.split("/").last;
        print("Image Name: $imageName");
        final dir1 = Directory.systemTemp;
        final targetPath1 =
            "${dir1.absolute.path}/dp${Get.find<AuthController>().i}.jpg";
        var compressedFile1 = await FlutterImageCompress.compressAndGetFile(
            imagePath, targetPath1,
            quality: 60);
        File file = File(compressedFile1!.path);
        var index = isBefore
            ? progressController.progressImagesList.length - 2
            : progressController.progressImagesList.length - 1;
        progressController.progressImagesList[index] = file;
        progressController.update();

        Get.find<AuthController>().i++;
        Get.find<AuthController>().update();
      }
    } else {
      print(value);
    }
  });
}
