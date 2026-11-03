import 'dart:convert';
import '../data/controllers/consultation_controller/consultation_controller.dart';
import '../UI/consultation_module/booking/upcoming_consultation_card.dart';
import '../data/controllers/diet_contoller/diet_controller.dart';
import '../UI/diet_screen/today_sessions_screen.dart';

import 'app_update_checker.dart';
import 'analytics_helper.dart';
import '../UI/auth_module/pcos/generic_screening_intro.dart';
import '../UI/auth_module/pcos/pcos_config.dart';
import '../UI/auth_module/pcos/thyroid_config.dart';
import '../UI/auth_module/pcos/menopause_config.dart';
import '../UI/auth_module/pcos/postpartum_config.dart';
import '../UI/auth_module/pcos/endometriosis_config.dart';
import '../UI/diet_screen/dietitian_v2/client_consultation_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_provider/api_provider.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import 'signup_progress.dart';
import '../UI/admin_module/payment_checks/payment_checks_screen.dart';
import '../UI/dashboard_module/get_all_new_user_images/get_new_user_images.dart';
import '../UI/admin_module/emergency_days/emergency_day_requests_screen.dart';
import '../UI/auth_module/sign_up_screen/sign_up_screen_questions.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
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
import '../widgets/announcement_popup.dart';
import '../UI/dashboard_module/bottom_bar_screen/Help_Screen.dart';
import '../UI/plans_module/all_plans.dart';
import '../widgets/trial_moments/trial_moments.dart';
import 'notification_message_classifier.dart' as classifier;
import '../UI/support/support_ticket_screen.dart';
import '../UI/pre_consultation/pre_consultation_form_screen.dart';
import '../UI/consultation_module/popup_orchestrator.dart';
import '../widgets/weekly_checkin/weekly_checkin_sheet.dart';
import 'popup_manager.dart';

class NotificationMessage {
  final int? serverId;
  final String title;
  final String body;
  final String? id; // message.messageId
  final String? sentAt;
  final String? readAt;
  /// Push type (classPrep, trainerCancelled, planExpiring…) — drives the
  /// category, icon and action on the notifications screen.
  final String? type;
  final Map<String, dynamic>? data;

  NotificationMessage({
    required this.title,
    required this.body,
    this.id,
    this.serverId,
    this.sentAt,
    this.readAt,
    this.type,
    this.data,
  });

  /// Server ids are numbers; a saved item may hold one as a number or as
  /// text. Anything else (e.g. a push's message id) → null. Oct 2026 fix:
  /// a text id here crashed the app on start ("String is not int?").
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static String? _asStr(dynamic v) => v?.toString();

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.trim().startsWith('{')) {
      try {
        final d = jsonDecode(v);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      // Saved too (Oct 2026): without it every reloaded item had id '' and
      // the "already in the bell" check never matched (duplicates).
      'id': id,
      'serverId': serverId,
      'title': title,
      'body': body,
      'sentAt': sentAt,
      'readAt': readAt,
      'type': type,
      'data': data,
    };
  }

  // Create from JSON
  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      // Saved items keep serverId; very old ones only had the server id
      // in 'id'. A push's own id is text, so it never becomes serverId.
      serverId: _asInt(json['serverId']) ?? _asInt(json['id']),
      title: _asStr(json['title']) ?? '',
      body: _asStr(json['body']) ?? '',
      id: _asStr(json['id']) ?? '',
      sentAt: _asStr(json['sentAt'] ?? json['createdAt']),
      readAt: _asStr(json['readAt']),
      type: json['type']?.toString(),
      data: _asMap(json['data']),
    );
  }

  // Create a NotificationMessage from RemoteMessage
  factory NotificationMessage.fromRemoteMessage(RemoteMessage message) {
    return NotificationMessage(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      id: message.messageId?.hashCode.toString() ?? '',
      type: message.data['type']?.toString(),
      sentAt: DateTime.now().toIso8601String(),
    );
  }

  factory NotificationMessage.fromServer(Map<String, dynamic> json) {
    return NotificationMessage(
      // From the server the id is always the row id (number or "123").
      serverId: _asInt(json['id']) ?? int.tryParse('${json['id']}'),
      id: json['id']?.toString(),
      title: _asStr(json['title']) ?? '',
      body: _asStr(json['body']) ?? '',
      sentAt: _asStr(json['sentAt'] ?? json['createdAt']),
      readAt: _asStr(json['readAt']),
      type: json['type']?.toString(),
      data: _asMap(json['data']),
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

  /// "Your starter plan is ready 🌱": the plan the AI made in the
  /// background is on the server now. Clear "being prepared" and load it.
  void _onTrialPlanReady() {
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().setTrialPlanPending(false);
      }
      if (Get.isRegistered<DietPlanUserController>()) {
        Get.find<DietPlanUserController>().loadActivePlan(refresh: true);
      }
    } catch (_) {}
  }

  /// Initializes Firebase messaging and local notification settings.
  void firebaseInit(BuildContext context) {
    // Listen for foreground notifications

    FirebaseMessaging.onMessage.listen((message) {
      // Nov 2026: a consultation push (cancelled, started, late, booked…)
      // while the app is open: refresh her consultation card now, instead
      // of only after the next 20-second check or a manual refresh.
      _refreshConsultation(message);
      // Her starter plan was made in the background: show it right away.
      if (message.data['type'] == 'trialPlanReady') _onTrialPlanReady();
      _handleForegroundMessage(message, context);
      onNotificationGet(message, context);
    });

    // Handle background and terminated state interactions
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _refreshConsultation(message);
      AnalyticsHelper.pushOpened(message.data['type']?.toString());
      handleNotificationTap(message, context);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        AnalyticsHelper.pushOpened(message.data['type']?.toString(), coldStart: true);
        handleNotificationTap(message, context);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _storeAndSyncDeviceToken(token);
    });
  }

  static void _refreshConsultation(RemoteMessage message) {
    try {
      final t = message.data['type']?.toString() ?? '';
      // Nov 2026: her plan was sent or changed: show the new one now.
      if ((t == 'dietPlanUpdated' || t == 'dietPlanReady') && Get.isRegistered<DietPlanUserController>()) {
        Get.find<DietPlanUserController>().loadActivePlan(refresh: true);
      }
      if (!_consultTypes.contains(t) && t != 'bookingUpdated') return;
      if (Get.isRegistered<ConsultationController>()) {
        Get.find<ConsultationController>().loadUpcomingAppointment();
      }
    } catch (_) {}
  }

  /// On launch: no permission box. Just save her device token if she
  /// already allowed notifications. Asking is done by
  /// widgets/notification_permission_sheet.dart (our sheet first).
  Future<void> syncTokenIfAllowed() async {
    try {
      final s = await messaging.getNotificationSettings();
      if (s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional) {
        await getDeviceToken();
      }
    } catch (_) {}
  }

  /// Request notification permissions for iOS
  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // Mixpanel: permission result, sent once per change (not every launch).
    try {
      final granted = settings.authorizationStatus != AuthorizationStatus.denied;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('mp_notif_permission') != granted) {
        await prefs.setBool('mp_notif_permission', granted);
        AnalyticsHelper.notificationPermission(granted);
        AnalyticsHelper.setProfile({'push_enabled': granted});
      }
    } catch (_) {}
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User denied notification permissions.');
    } else {
      await getDeviceToken();
    }
  }

  /// Kept for old callers: the setup now happens once, at app start.
  Future<void> initLocalNotifications(
          RemoteMessage message, BuildContext context) =>
      ensureLocalNotifications();

  // ── Phone notifications: set up ONCE at app start (Oct 2026) ─────────
  // Before, the plugin was set up again on every push that arrived while
  // the app was open, and each time the tap action was tied to THAT push,
  // so tapping any phone notification opened the screen of the last push.
  // Now: one setup at start; each notification carries its own push data
  // in `payload`, and a tap routes from that.
  static const String channelId = 'high_importance_channel';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  static Future<void>? _localSetup;

  /// Sets up phone notifications once (safe to call many times).
  static Future<void> ensureLocalNotifications() =>
      _localSetup ??= _setUpLocalNotifications();

  static Future<void> _setUpLocalNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Asking is done by our own "Turn on notifications" sheet.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      // Create the Android channel now, so pushes that arrive while the
      // app is closed get a banner (they used to land in "Miscellaneous").
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      // The app was opened by tapping one of our phone notifications.
      final launch = await plugin.getNotificationAppLaunchDetails();
      final r = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && r != null) {
        Future.delayed(const Duration(milliseconds: 1500), () => _onLocalTap(r));
      }
    } catch (e) {
      debugPrint('[notifications] local setup failed: $e');
    }
  }

  /// Payload saved with a phone notification shown for a push.
  static String payloadFor(RemoteMessage message) => jsonEncode({
        'data': message.data,
        'title': message.notification?.title,
        'body': message.notification?.body,
      });

  /// She tapped one of our phone notifications: route like a push tap.
  /// No payload (daily nudge, class reminder from the live connection)
  /// = the app just opens.
  static void _onLocalTap(NotificationResponse response) {
    final p = response.payload;
    if (p == null || p.isEmpty) return;
    try {
      final m = jsonDecode(p);
      if (m is! Map) return;
      final data = (m['data'] is Map)
          ? (m['data'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : <String, String>{};
      final message = RemoteMessage(
        data: data,
        notification: RemoteNotification(
          title: m['title']?.toString(),
          body: m['body']?.toString(),
        ),
      );
      final ctx = Get.context;
      if (ctx == null) return;
      final services = Get.isRegistered<NotificationServices>()
          ? Get.find<NotificationServices>()
          : NotificationServices();
      services.handleNotificationTap(message, ctx);
    } catch (e) {
      debugPrint('[notifications] tap failed: $e');
    }
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

    await ensureLocalNotifications();
    await _flutterLocalNotificationsPlugin.show(
      message.messageId.hashCode,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
      // Her tap opens the screen for THIS push (see _onLocalTap).
      payload: payloadFor(message),
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

      ensureLocalNotifications();
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
        // Saved, then shown through the pop-up manager (no BuildContext,
        // so it can't crash on a closed screen like the old dialog did).
        AnnouncementPopup.save(
                message.notification?.title, message.notification?.body)
            .then((_) => AnnouncementPopup.maybeShow());
      }
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
      // (A second showNotification for the same message was here: same
      // condition as above, so the sound could play twice. Removed Oct 2026.)
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
    // Never log the token itself.
    debugPrint("device token received");

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

  /// Runs [go] once Home is on screen (Oct 2026). A tap on a push while the
  /// app was closed used to open the sheet after a fixed 1.5 s, and the
  /// splash → Home hand-off (often slower) then closed it again, so the
  /// tap "did nothing". Waits up to 15 s for Home, then a short settle.
  static void whenHomeReady(VoidCallback go) {
    Future<void>(() async {
      for (var i = 0; i < 50; i++) {
        final home = PopupManager.homeRoute;
        if (home != null && home.isActive) break;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      await Future.delayed(const Duration(milliseconds: 600));
      go();
    });
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
    // Support replied to her report: open that ticket.
    // Monthly "check your PCOS signs" → open that condition's check.
    // "Your health form is waiting": open the form itself.
    if (message.data["type"] == "preConsultReminder") {
      whenHomeReady(() => PreConsultationFormScreen.openIfNeeded());
      return;
    }

    // Weekly check-in push (Sunday 7 pm): open this week's check-in.
    if (message.data["type"] == "weeklyCheckin") {
      whenHomeReady(() => WeeklyCheckinSheet.open());
      return;
    }

    // Day 7 / 15 / 30, follow-up, renew push: open that pop-up itself.
    if (message.data["type"] == "popupReminder") {
      final variable = message.data["popupVariable"]?.toString() ?? '';
      whenHomeReady(() => openPendingPopupFromPush(variable));
      return;
    }

    if (message.data["type"] == "symptomCheckReminder") {
      final cond = message.data["condition"]?.toString() ?? 'PCOS';
      final config = {
            'PCOS': pcosConfig,
            'Thyroid': thyroidConfig,
            'Menopause': menopauseConfig,
            'Postpartum': postpartumConfig,
            'Endometriosis': endometriosisConfig,
          }[cond] ??
          pcosConfig;
      Future.delayed(const Duration(milliseconds: 1500), () {
        Get.to(() => GenericScreeningIntro(config: config));
      });
      return;
    }

    // Admin: "N payments to confirm" / "Payment proof sent".
    if (message.data["type"] == "paymentCheck") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        Get.to(() => const PaymentChecksScreen());
      });
      return;
    }

    // Admin (Oct 2026): a dietitian's emergency day waiting for approval.
    if (message.data["trigger"] == "DIETITIAN_EMERGENCY_DAY") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        Get.to(() => const EmergencyDayRequestsScreen());
      });
      return;
    }

    // Admin (Oct 2026): a slip the AI could not approve → approval list.
    if (message.data["type"] == "paymentApprovalRequest") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().getAllImagesPlan();
        }
        Get.to(() => AllNewUserImages());
      });
      return;
    }

    // "Finish setting up Fit Her": the app start already reopens the
    // questions; if she was elsewhere in the app, take her there.
    if (message.data["type"] == "finishSignup") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        final auth = Get.find<AuthController>();
        if (!SignupProgress.isDone(auth.logInUser, auth.sharedPreferences) &&
            Get.currentRoute != '/SignUpScreenQuestions') {
          Get.offAll(() => const SignUpScreenQuestions());
        }
      });
      return;
    }

    // Dietitian: "Ayesha's PCOS check" → her client profile.
    if (message.data["type"] == "clientScreening") {
      final uid = int.tryParse(message.data["userId"]?.toString() ?? "");
      if (uid != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          Get.to(() => ClientConsultationScreen(userId: uid));
        });
      }
      return;
    }

    if (message.data["type"] == "support_reply") {
      final id = int.tryParse(message.data["ticketId"]?.toString() ?? "");
      if (id != null) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          Get.to(() => SupportTicketScreen(ticketId: id));
        });
      }
      return;
    }

    if (message.data["type"] == "trialPlanReady") {
      _onTrialPlanReady();
      Future.delayed(const Duration(milliseconds: 1200), () {
        Get.offAll(() => BottomBarScreen(index: 2));
      });
      return;
    }

    // Free-trial moment (Day 3 / 4 / last day / ended): open its sheet.
    if (message.data["type"] == "trialMoment") {
      final kind = '${message.data["kind"] ?? ''}';
      Future.delayed(const Duration(milliseconds: 1500), () {
        TrialMomentController.ensure().openFromPush(kind);
      });
      return;
    }

    if (message.data["type"] == "trialOfferReminder" ||
        message.data["type"] == "trialLastDay") {
      Future.delayed(const Duration(milliseconds: 1200), () {
        Get.to(() => const TrialSummaryScreen());
      });
      return;
    }

    // "Please update" push → show the update sheet / screen right away.
    if (message.data["type"] == "appUpdate") {
      Future.delayed(const Duration(milliseconds: 1500), () {
        AppUpdateChecker.check(fromPush: true);
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

    // Oct 2026: these taps used to just open the app.
    _routeTap(message);
  }

  // Push types → the screen they are about (taps on the pushes above that
  // had no route). Tabs are the client's tabs (0 Home, 1 Workout, 2 Diet);
  // staff accounts have other tabs, so they only get the chat route.
  static const Set<String> _classTypes = {
    'classPrep', 'classStart', 'upcomingClass', 'classLinkAdded',
    'trainerLinkAdded', 'trainerCancelled', 'missedRecovery',
  };
  static const Set<String> _classTitles = {
    'Upcoming Class', 'Trainer has Joined', 'Class Reminder', 'Class Cancelled',
    'Missed Session', 'Class Link Added', 'Class link Added', 'Trainer link Added',
  };
  static const Set<String> _dietTypes = {
    'dietPlanReady', 'dietPlanAdded', 'dietPlanUpdated',
  };
  static const Set<String> _consultTypes = {
    'appointmentConfirmed', 'appointmentCanceled', 'appointmentCanceledByUser',
    'appointmentNoShowCanceled', 'appointmentClientNoShow',
    'appointmentUnconfirmedExpired', 'appointmentStarted',
    'consultationReminder', 'bookingAdded', 'bookingPending',
    'appointmentDietitianLate', 'consultationReview',
  };

  static const Set<String> _dietitianConsultTypes = {
    'bookingAdded', 'bookingUpdated', 'bookingMovedAway', 'appointmentCanceledByUser',
    'consultationReminder', 'appointmentLate', 'appointmentNoShowCanceled', 'clientWaiting',
  };

  void _routeTap(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    final title = message.notification?.title ?? '';
    final role = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().loginAsA.value
        : Constants.user;
    final isClient = role == Constants.user;
    void later(VoidCallback go) =>
        Future.delayed(const Duration(milliseconds: 1200), go);

    if (type == 'chat' || title == 'A new message arrived') {
      // Staff: the Chat tab. Clients: the Help section (chat with admin
      // or her dietitian).
      later(() => isClient
          ? Get.to(() => HelpScreen())
          : Get.offAll(() => BottomBarScreen(index: 1)));
      return;
    }
    if (_isAnnouncement(message)) {
      // Her tap: show it now (saved just above), not on a later app open.
      later(() => AnnouncementPopup.maybeShow(fromTap: true));
      return;
    }
    // Nov 2026: dietitian consultation pushes (new booking, moved,
    // cancelled, 15-min reminder, client waiting, running late, auto-
    // cancelled) open her sessions list. They used to open nothing.
    if (!isClient && role == Constants.dietitian && _dietitianConsultTypes.contains(type)) {
      later(() {
        if (Get.isRegistered<DietController>()) {
          Get.find<DietController>().getAppointmentsOfDiets();
        }
        Get.to(() => TodaySessionsScreen());
      });
      return;
    }
    if (!isClient) return;
    // Nov 2026: "How was your session?" → show the rating card again even
    // if she tapped "Not now" on it before.
    // Nov 2026: open the rating sheet itself, not just the Diet tab.
    if (type == 'consultationReview') {
      later(() => SessionRatingPopup.openNow());
      return;
    }
    if (_classTypes.contains(type) || _classTitles.contains(title)) {
      later(() => Get.offAll(() => BottomBarScreen(index: 1))); // Workout
      return;
    }
    // Diet plan and consultations (the consultation card is on the Diet tab).
    if (_dietTypes.contains(type) || _consultTypes.contains(type) ||
        title == 'Your Diet Plan is Ready' || title == 'Diet Plan Added' ||
        title == 'Diet Plan Updated') {
      later(() => Get.offAll(() => BottomBarScreen(index: 2))); // Diet
      return;
    }
    // Oct 2026: slip rejected → plans, to upload a new slip.
    if (type == 'planExpiring' || type == 'paymentRejected') {
      later(() => Get.to(() => OurPlansScreen()));
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
      // Newest first, like the list from the server.
      notificationMessages.insert(0, newMessage);
      authController.sharedPrefNotifier.value = notificationMessages;
      sharedPreferences.setString(
        Constants.notificationList,
        jsonEncode(notificationMessages.map((msg) => msg.toJson()).toList()),
      );
    }
  }
}
