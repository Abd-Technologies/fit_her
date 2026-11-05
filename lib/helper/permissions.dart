import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionOfPhotos {
  Future<bool> getFromGallery(BuildContext context) async {
    Permission platform;
    if (Platform.isIOS) {
      platform = Permission.photos;
    } else {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+: image_picker opens the system photo picker, which needs
        // no permission. We no longer declare READ_MEDIA_IMAGES (Play policy).
        return true;
      }
      platform = Permission.storage;
    }

    var stauts = await platform.status;
    await platform.request();
    Get.log("status  $stauts ");
    if (await platform.status.isDenied) {
      // Permission.systemAlertWindow.isPermanentlyDenied;
      if (Platform.isIOS) {
        await platform.request();
      } else {
        showDeleteDialog(context,
            "Fit Her app requires access to the gallery to upload pictures");
      }

      return false;
    } else if (await platform.status.isPermanentlyDenied) {
      if (Platform.isIOS) {
        showDialog(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
                  title: Text("Settings"),
                  content: Text(
                      "Fit Her want to access camera open settings and give permission"),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      child: Text("Not now"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoDialogAction(
                      onPressed: () => openAppSettings(),
                      child: Text("iOS Settings"),
                    )
                  ],
                ));
      } else {
        showDeleteDialog(context,
            "Fit her app requires access to the gallery to upload pictures");
      }

      return false;
    } else if (await platform.isGranted) {
      return true;
    } else if (await platform.isLimited) {
      return true;
    }

    return false;
  }

  Future<bool> getFromCamera(BuildContext context) async {
    //var status = await Permission.camera.status;
    var status = await Permission.camera.status; //
    await Permission.camera.request();
    if (await Permission.camera.status.isDenied) {
      if (Platform.isIOS) {
        await Permission.camera.request();
      } else {
        showDeleteDialog(context,
            "Fit Her app requires access to the camera to upload pictures");
        return false;
      }
    }
    if (await Permission.camera.status.isPermanentlyDenied) {
      if (Platform.isIOS) {
        showDialog(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
                  title: Text("Settings"),
                  content: Text(
                      "Fit Her want to access camera open settings and give permission"),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      child: Text("Not now"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoDialogAction(
                      child: Text("iOS Settings"),
                      onPressed: openAppSettings,
                    )
                  ],
                ));
      } else {
        showDeleteDialog(context,
            "Fit Her app requires access to the camera to capture pictures");
      }

      return false;
    } else if (await Permission.camera.isGranted ||
        await Permission.camera.isLimited) {
      return true;
    }

    return false;
  }
}
// String getCountryCode()  {
//   // DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//   // if (Platform.isAndroid) {
//   //   AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//   //   print('Android Device: ${androidInfo}');
//   //   return 'PK';
//   // } else if (Platform.isIOS) {
//   //   IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//   //   print('iOS Device: ${iosInfo.utsname.machine}');
//   //
//   //   return "PK";
//   // } else {
//   //   return 'PK';
//   // } // Returns 'US', 'IN', etc.
//  return "";
//
// }

Future<String> getTimezoneOffset() async {
  DateTime now = DateTime.now();
  // Duration offset = now.timeZoneOffset;
  final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
  print("utc $currentTimeZone");
  return currentTimeZone;
}

int covertToTimeStamp(String timeString) {
  DateTime now = DateTime.now();

  // Extract time and AM/PM
  var time = timeString.split(" ").first;
  var amPM = timeString.split(" ").last;

  int hour = int.parse(time.split(":").first);
  int minute = int.parse(time.split(":").last);

  // Handle AM/PM conversion properly
  if (amPM == "PM" && hour != 12) {
    hour += 12; // Convert PM hours to 24-hour format
  } else if (amPM == "AM" && hour == 12) {
    hour = 0; // Midnight case
  }

  DateTime combinedDateTime =
      DateTime(now.year, now.month, now.day, hour, minute);

  // Check if we need to move to the next day (crossing midnight)
  if (amPM == "AM" && now.hour >= 12) {
    combinedDateTime = combinedDateTime.add(Duration(days: 1));
  }

  Timestamp timestamp = Timestamp.fromDate(combinedDateTime);
  return timestamp.millisecondsSinceEpoch;
}
// int covertToTimeStamp(String timeString) {
//   // Step 1: Parse the time string into a DateTime object
//   DateTime now = DateTime.now();
//   //  DateTime parsedTime = DateFormat.jm().parse("7:00 AM");
//   var time = timeString.split(" ").first;
//   var amPM = timeString.split(" ").last;
//
//   print("${time}  ${amPM}");
//   DateTime combinedDateTime = DateTime(
//       now.year,
//       now.month,
//       now.day,
//       amPM == "AM"
//           ? int.parse(time.split(":").first)
//           : (int.parse(time.split(":").first) + 12),
//       int.parse(
//         time.split(":").last,
//       ));
//
//   Timestamp timestamp = Timestamp.fromDate(combinedDateTime);
//   return timestamp.millisecondsSinceEpoch;
// }

Future<String> getCountryCode() async {
  Map<String, String> timezoneToCountry = {
    // India Time Zones
    "Asia/Kolkata": "India",
    "Asia/Calcutta": "India", // Historical name

    // Pakistan Time Zone
    "Asia/Karachi": "Pakistan",

    // Saudi Arabia Time Zones
    "Asia/Riyadh": "Saudi Arabia",
    "Asia/Jeddah": "Saudi Arabia", // Alternative for Riyadh

    // United Arab Emirates (UAE) Time Zones
    "Asia/Dubai": "United Arab Emirates",
    "Asia/Abu_Dhabi": "United Arab Emirates",

    // Oman Time Zone
    "Asia/Muscat": "Oman",

    // Kuwait Time Zone
    "Asia/Kuwait": "Kuwait",

    // Bahrain Time Zone
    "Asia/Bahrain": "Bahrain",

    // Qatar Time Zone
    "Asia/Qatar": "Qatar",

    // United Kingdom (UK) Time Zones
    "Europe/London": "United Kingdom (UK)",
    "Europe/Belfast": "United Kingdom (UK)", // Northern Ireland
    "Europe/Guernsey": "United Kingdom (UK)",
    "Europe/Isle_of_Man": "United Kingdom (UK)",
    "Europe/Jersey": "United Kingdom (UK)"
  };

  String timezone = await getTimezoneOffset();
  String? countries = timezoneToCountry[timezone];
  print("-----$countries");
  return countries ?? "default";
}

showDeleteDialog(BuildContext context, String text) {
  // set up the buttons
  Widget cancelButton = GestureDetector(
    onTap: () {
      Navigator.pop(context);
    },
    child: const Text(
      "Not now",
      style: TextStyle(fontSize: 12),
    ),
  );
  Widget continueButton = GestureDetector(
    onTap: () async {
      openAppSettings();
    },
    child: Text("Open settings".tr,
        style: const TextStyle(fontStyle: FontStyle.normal, fontSize: 12)),
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    actionsPadding: const EdgeInsets.only(right: 15, bottom: 15),
    // shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.all(Radius.circular(36.0))),
    title: Text(
      "Settings".tr,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
    content: Text(
      text.tr,
      style: const TextStyle(fontWeight: FontWeight.w400),
    ),
    actions: [
      cancelButton,
      continueButton,
    ],
  );

  // show the dialog
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      });
}
