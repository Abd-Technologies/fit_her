import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/controllers/workout_controller/work_out_controller.dart';
import '../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../data/models/upcoming_class_slot.dart';
import '../firebase_options.dart';
import '../main.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../values/constants.dart';
import '../UI/diet_screen/dietitian_v2/plans_to_deliver_screen.dart';
import '../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import '../UI/free_trail/trial_summary_screen.dart';
import '../values/my_imgs.dart';
import '../widgets/app_bar_widget.dart';
import 'notification_message_classifier.dart' as classifier;

class NotificationMessage {
  final int? serverId;
  final String title;
  final String body;
  final String? id; // message.messageId
  final String? sentAt;
  final String? readAt;

  NotificationMessage({
    required this.title,
    required this.body,
    this.id,
    this.serverId,
    this.sentAt,
    this.readAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'title': title,
      'body': body,
      'sentAt': sentAt,
      'readAt': readAt,
    };
  }

  // Create from JSON
  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      serverId: json['serverId'] ?? json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      id: json['id'] ?? '',
      sentAt: json['sentAt'] ?? json['createdAt'],
      readAt: json['readAt'],
    );
  }

  // Create a NotificationMessage from RemoteMessage
  factory NotificationMessage.fromRemoteMessage(RemoteMessage message) {
    return NotificationMessage(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      id: message.messageId?.hashCode.toString() ?? '',
    );
  }

  factory NotificationMessage.fromServer(Map<String, dynamic> json) {
    return NotificationMessage(
      serverId: json['id'],
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      sentAt: json['sentAt'] ?? json['createdAt'],
      readAt: json['readAt'],
    );
  }
}

const vapidKey =
    "BDWl3SA7SiHCyDYKJSWH_e6kgFg_EcvJvoWhUAvqH-6wLK14vBIO5INqVNnmkXq8_ZiArqUsJ7iBHEqaKM_hXEU";

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Delegate to notification_message_classifier.dart's pure functions —
  // shared with main.dart's firebaseMessagingBackgroundHandler so the
  // foreground and background/terminated paths can never drift apart.
  // Kept as thin wrappers so every existing call site below is unchanged.
  bool _isAnnouncement(RemoteMessage message) =>
      classifier.isAnnouncementMessage(message);

  bool _isClassUpdate(RemoteMessage message) =>
      classifier.isClassUpdateMessage(message);

  bool _hasClassPayload(RemoteMessage message) =>
      classifier.hasClassPayload(message);

  /// Initializes Firebase messaging and local notification settings.
  void firebaseInit(BuildContext context) {
    // Listen for foreground notifications

    FirebaseMessaging.onMessage.listen((message) {
      _handleForegroundMessage(message, context);
      onNotificationGet(message, context);
    });

    // Handle background and terminated state interactions
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleNotificationTap(message, context);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        handleNotificationTap(message, context);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _storeAndSyncDeviceToken(token);
    });
  }

  /// Request notification permissions for iOS
  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('User denied notification permissions.');
    } else {
      await getDeviceToken();
    }
  }

  /// Initializes local notifications for Android and iOS.
  Future<void> initLocalNotifications(
      RemoteMessage message, BuildContext context) async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    InitializationSettings settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) =>
          handleNotificationTap(message, context),
    );
  }

  /// Show a local notification from socket events (not FCM).
  /// Used by SocketController to fire notifications filtered by timeBlock.
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF, // unique id
      title,
      body,
      platformDetails,
    );
  }

  /// Display a notification when the app is in the foreground.
  Future<void> showNotification(RemoteMessage message) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher', // Update with your launcher icon
    );

    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.messageId.hashCode,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
    );
  }

  /// Foreground message handler for displaying notifications and updating UI.
  void _handleForegroundMessage(RemoteMessage message, BuildContext context) {
    if (message.notification != null) {
      UpcomingClassSlot? upcomingClassSlot;
      AuthController authController = Get.find();
      var sharedPreferences = authController.sharedPreferences;

      if (classifier.isDietPlanMessage(message)) {
        final dietEnabled =
            sharedPreferences.getBool('pref_dietUpdates') ?? true;
        if (!dietEnabled) {
          // User turned off Diet Plan Updates in notification settings
          return;
        }
      }

      initLocalNotifications(message, context);
      if (_isClassUpdate(message) && _hasClassPayload(message)) {
        upcomingClassSlot = UpcomingClassSlot(
            upcomingSlot:
                Slot.fromJson(jsonDecode(message.data["upcomingSlot"])),
            trainer: ClientUser.fromJson(jsonDecode(message.data["trainer"])));

        if (Get.find<HomeController>().upComingClassNotifier.value == null ||
            message.notification?.title == "Upcoming Class") {
          sharedPreferences.setString(
              Constants.upcomingSlot, jsonEncode(upcomingClassSlot.toJson()));

          Get.find<HomeController>().upComingClassNotifier.value =
              upcomingClassSlot;
        } else {
          if (Get.find<HomeController>()
                  .upComingClassNotifier
                  .value
                  ?.upcomingSlot
                  ?.id ==
              upcomingClassSlot.upcomingSlot?.id) {
            sharedPreferences.setString(
                Constants.upcomingSlot, jsonEncode(upcomingClassSlot.toJson()));

            Get.find<HomeController>().upComingClassNotifier.value =
                upcomingClassSlot;
          }
        }
      }
      if (message.notification?.title != "Upcoming Class") {
        if (upcomingClassSlot?.upcomingSlot?.status != "Confirmed") {
          addNotification(message);
          showNotification(message);
        }
      }
      if (_isAnnouncement(message)) {
        print('NotificationServices._handleForegroundMessage test');
        HelpingWidgets.showCustomDialog(context, () {
          Get.back();
          authController.sharedPreferences
              .remove(Constants.announcementNotification);
        }, message.notification?.title ?? "", message.notification?.body ?? "",
            MyImgs.logo,
            buttonText: "Ok, Got It");
        addAnnouncementPopUp(message);
      }
      print(
          'NotificationServices._handleForegroundMessage $upcomingClassSlot}');
      if (message.notification?.title == "Trainer has Joined") {
        if (selectedPlan != "") {
          Get.find<WorkOutController>().getDietPlanDetailsFunc(selectedPlan);
          addNotification(message);
        }
      } else if (message.notification?.title == "Congratulations!" ||
          message.data["type"] == "planActivated" ||
          message.data["type"] == "paymentApproved") {
        if (Get.isRegistered<AuthController>()) {
          Get.find<AuthController>().markPaid();
        }
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().getUserHomeFunc(isFromFree: true);
        }
        addNotification(message);
      }
      if (upcomingClassSlot?.upcomingSlot?.status != "Confirmed") {
        if (message.notification?.title != "Upcoming Class") {
          showNotification(message);
        }
      }
    }
  }

  addAnnouncementPopUp(RemoteMessage message) {
    AuthController authController = Get.find();
    var sharedPreferences = authController.sharedPreferences;
    var announcement = {
      "title": message.notification?.title,
      "body": message.notification?.body,
      "date": DateTime.now().toString()
    };
    sharedPreferences.setString(
        Constants.announcementNotification, jsonEncode(announcement));
  }

  static String? deviceToken;
  void onNotificationGet(RemoteMessage message, BuildContext context) {}
  Future<String?> getDeviceToken() async {
    FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.web) {
      await _firebaseMessaging.deleteToken();
    }
    if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.web) {
      deviceToken = await _firebaseMessaging.getToken(
        vapidKey: vapidKey,
      );
    } else {
      deviceToken = await _firebaseMessaging.getToken();
    }
    await _storeAndSyncDeviceToken(deviceToken);
    print("device toke $deviceToken");

    // await FirebaseMessaging.instance.getToken().then((token) {
    //   if (token != null) {
    //     deviceToken = token;
    //     print("device Token: $token");
    //     sharedPreferences.setString(Constants.deviceToken, deviceToken!);
    //   }
    // }).catchError((onError) {
    //   print("the error is $onError");
    // });
    return deviceToken;
  }

  Future<void> _storeAndSyncDeviceToken(String? token) async {
    if (token == null || token.isEmpty) return;

    deviceToken = token;
    AuthController authController = Get.find();
    var sharedPreferences = authController.sharedPreferences;
    await sharedPreferences.setString(Constants.deviceToken, token);

    final accessToken = sharedPreferences.getString(Constants.accessToken);
    if (accessToken == null || accessToken.isEmpty) return;
    if (!Get.isRegistered<ApiProvider>()) return;

    try {
      await Get.find<ApiProvider>().postData(
        Constants.updateDeviceToken,
        body: {"deviceToken": token},
        headers: {"accessToken": accessToken},
      );
    } catch (e) {
      debugPrint("Device token sync failed: $e");
    }
  }

  /// Handles notification tap interactions and navigates to appropriate screens.
  void handleNotificationTap(
      RemoteMessage message, BuildContext context) async {
    NotificationServices noti = Get.find();

    // "Plan due in 24h / 36h" reminder: take the dietitian straight to
    // Plans to deliver. Admins get the same push type at 36h but have no
    // client list of their own, so they just land on their dashboard.
    // Short delay so a cold start finishes routing to the home screen
    // first; otherwise this screen would get replaced by it.
    // Trial class reminder ("starts soon" / "it's live"): open the live
    // class schedule (Workout tab) so she can join in one tap.
    // Last-day offer reminder: open her trial summary + offer.
    if (message.data["type"] == "trialOfferReminder") {
      Future.delayed(const Duration(milliseconds: 1200), () {
        Get.to(() => const TrialSummaryScreen());
      });
      return;
    }

    if (message.data["type"] == "trialClassReminder") {
      Future.delayed(const Duration(milliseconds: 1200), () {
        Get.offAll(() => BottomBarScreen(index: 1));
      });
      return;
    }

    if (message.data["type"] == "planDeliveryReminder") {
      final isDietitian = Get.isRegistered<AuthController>() &&
          Get.find<AuthController>().loginAsA.value == Constants.dietitian;
      if (isDietitian) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          Get.to(() => const PlansToDeliverScreen());
        });
      }
      return;
    }

    if (_isAnnouncement(message)) {
      var sharedPreferences = await SharedPreferences.getInstance();
      var announcement = {
        "title": message.notification?.title,
        "body": message.notification?.body,
        "date": DateTime.now().toString()
      };
      sharedPreferences.setString(
          Constants.announcementNotification, jsonEncode(announcement));
      ();
      noti.addNotification(message);
    }
    UpcomingClassSlot? upcomingClassSlot;

    if (_isClassUpdate(message) && _hasClassPayload(message)) {
      upcomingClassSlot = UpcomingClassSlot(
          upcomingSlot: Slot.fromJson(jsonDecode(message.data["upcomingSlot"])),
          trainer: ClientUser.fromJson(jsonDecode(message.data["trainer"])));
      if (Get.find<HomeController>().upComingClassNotifier.value == null ||
          message.notification?.title == "Upcoming Class") {
        Get.find<HomeController>().upComingClassNotifier.value =
            upcomingClassSlot;
      } else {
        Get.find<HomeController>().upComingClassNotifier.value =
            upcomingClassSlot;
      }
    }
    if (message.notification?.title == "Congratulations!" ||
        message.data["type"] == "planActivated" ||
        message.data["type"] == "paymentApproved") {
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().markPaid();
      }
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().getUserHomeFunc(isFromFree: true);
      }
      noti.addNotification(message);
    }
  }

  addNotification(RemoteMessage message) {
    AuthController authController = Get.find();
    var sharedPreferences = authController.sharedPreferences;

    if (message.notification?.title == "A new message arrived") {
      sharedPreferences.setBool("showDot", true);
      Get.find<AuthController>().showDot.value = true;
    } else {
      sharedPreferences.setBool("showDotHome", true);
      Get.find<HomeController>().showDotHome.value = true;
    }

    var list = sharedPreferences.getString(Constants.notificationList);
    List<NotificationMessage> notificationMessages = [];

    if (list != null) {
      var list2 = jsonDecode(list);
      notificationMessages = List<NotificationMessage>.from(
        list2.map((item) => NotificationMessage.fromJson(item)),
      );
    }

    var newMessage = NotificationMessage.fromRemoteMessage(message);

    bool alreadyExists =
        notificationMessages.any((msg) => msg.id == newMessage.id);

    if (!alreadyExists) {
      notificationMessages.add(newMessage);
      authController.sharedPrefNotifier.value = notificationMessages;
      sharedPreferences.setString(
        Constants.notificationList,
        jsonEncode(notificationMessages.map((msg) => msg.toJson()).toList()),
      );
    }
  }
}
