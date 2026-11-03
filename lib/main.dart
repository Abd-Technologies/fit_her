import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitness_zone_2/helper/notification_services.dart';
import 'package:fitness_zone_2/utils/app_clock.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/theme/app_theme.dart';
import 'package:fitness_zone_2/widgets/zoom_meeting_widget.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '/helper/get_di.dart' as di;
import 'helper/notification_message_classifier.dart' as classifier;
import 'UI/auth_module/splash.dart';
import 'data/api_provider/app_link_handler.dart';
import 'data/controllers/auth_controller/auth_controller.dart';
import 'data/controllers/home_controller/home_controller.dart';
import 'data/models/get_clients_diet.dart';
import 'data/models/get_user_plan/get_workout_user_plan_details.dart';
import 'data/models/upcoming_class_slot.dart';
import 'data/services/analytics_service.dart';
import 'widgets/announcement_popup.dart';
import 'firebase_options.dart';
import 'get_food_kcal_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:fitness_zone_2/widgets/anim/fh_page_transition.dart';
// import 'firebase_options.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Lets any screen detect "I've become visible again because a screen
// pushed on top of me was popped" (RouteAware.didPopNext), e.g. the
// paid home screen refreshing freeze/expiry status after the user backs
// out of Profile having just frozen or unfrozen their plan there.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

String selectedPlan = "";
Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();

  WidgetsFlutterBinding.ensureInitialized();
  // Oct 2026 security audit: release builds log nothing. API calls,
  // tokens and health answers were printed with debugPrint / print, which
  // also show up in a release phone's logs (USB / logcat).
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Font flash (FOUT) guard.
  // google_fonts does NOT bundle a font — by default it paints the text in
  // the system fallback, fetches the .ttf from fonts.gstatic.com in the
  // background, then repaints once it lands. That is what made the headline
  // on the welcome / login / diet screens change face a second after the
  // screen appeared (and it also happened on every cold start, because even
  // the on-disk cache is read asynchronously).
  //
  // DM Serif Display and Fraunces are now declared in pubspec.yaml and
  // loaded from the asset bundle before the first frame, so nothing needs
  // fetching. Setting this to false makes google_fonts throw instead of
  // silently going to the network, so a future GoogleFonts.x() call fails
  // loudly in development rather than shipping the flash again.
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  //SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await dotenv.load(fileName: ".env");

  // Phase F.3 — load the IANA database before anything reads
  // tz.getLocation(...). Synchronous + cheap; bundled with the package.
  tz_data.initializeTimeZones();


    await Firebase.initializeApp(options:DefaultFirebaseOptions.currentPlatform);


  await di.init();

  // Sync server time once. Fire-and-forget — we don't want to block app
  // launch on the network, and AppClock falls back to device time
  // until the first response lands.
  // ignore: unawaited_futures
  AppClock.init();

  // Initialize Analytics
  final analyticsService = Get.find<AnalyticsService>();
  await analyticsService.init();

  // Track app open
  await analyticsService.logAppOpen();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await SentryFlutter.init((options) {
    options.dsn =
        'https://a2619a7785d52ef8d6a3e59ef891bcdb@o4510731863916544.ingest.de.sentry.io/4510731866931280';
  },
      // Init your App. runApp must run in the same zone as
      // WidgetsFlutterBinding.ensureInitialized() (top of main), so no
      // runZoned here: it caused the "Zone mismatch" error on start.
      appRunner: () => runApp(const MyApp()));
}

// Push while the app is in the background or closed (Oct 2026 fix).
// On Android this runs in its own isolate: no GetX controllers exist
// there, so the old Get.find() calls crashed it and nothing was saved.
// Now it only writes to SharedPreferences; the app reads them when it
// opens (AnnouncementPopup re-reads from disk). Controllers are updated
// only when they exist (same isolate, e.g. iPhone).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Shared with NotificationServices' foreground handler (via
    // helper/notification_message_classifier.dart).
    final isAnnouncement = classifier.isAnnouncementMessage(message);
    final isClassUpdate = classifier.isClassUpdateMessage(message);
    final hasPayload = classifier.hasClassPayload(message);
    final prefs = await SharedPreferences.getInstance();

    if (isAnnouncement) {
      await AnnouncementPopup.save(
          message.notification?.title, message.notification?.body);
      await _saveToBell(prefs, message);
    }

    if (isClassUpdate && hasPayload) {
      final upcomingClassSlot = UpcomingClassSlot(
          upcomingSlot: Slot.fromJson(jsonDecode(message.data["upcomingSlot"])),
          trainer: ClientUser.fromJson(jsonDecode(message.data["trainer"])));
      final home = Get.isRegistered<HomeController>()
          ? Get.find<HomeController>()
          : null;
      UpcomingClassSlot? current = home?.upComingClassNotifier.value;
      if (home == null) {
        final saved = prefs.getString(Constants.upcomingSlot);
        if (saved != null) {
          try {
            current = UpcomingClassSlot.fromJson(jsonDecode(saved));
          } catch (_) {}
        }
      }
      final replace = current == null ||
          message.notification?.title == "Upcoming Class" ||
          current.upcomingSlot?.id == upcomingClassSlot.upcomingSlot?.id;
      if (replace) {
        await prefs.setString(
            Constants.upcomingSlot, jsonEncode(upcomingClassSlot.toJson()));
        if (home != null) home.upComingClassNotifier.value = upcomingClassSlot;
      }
    }
  } catch (e) {
    debugPrint('[push-background] $e');
  }
}

// Same list the bell screen reads (NotificationServices.addNotification),
// without GetX.
Future<void> _saveToBell(SharedPreferences prefs, RemoteMessage message) async {
  await prefs.setBool("showDotHome", true);
  final raw = prefs.getString(Constants.notificationList);
  final List<NotificationMessage> list = raw == null
      ? []
      : List<NotificationMessage>.from(
          (jsonDecode(raw) as List).map((e) => NotificationMessage.fromJson(e)));
  final msg = NotificationMessage.fromRemoteMessage(message);
  if (list.any((m) => m.id == msg.id)) return;
  list.add(msg);
  await prefs.setString(Constants.notificationList,
      jsonEncode(list.map((m) => m.toJson()).toList()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return GetBuilder<LocalizationController>(builder: (localizeController) {
    return ScreenUtilInit(
      designSize: const Size(414, 896),
      builder: (context, Widget) => GetMaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // One soft fade-and-slide for every screen change (Oct 2026).
        // GetX uses customTransition for routes with no transition of their
        // own. Android only: iPhone keeps its native swipe-back transition.
        customTransition: GetPlatform.isAndroid ? FhPageTransition() : null,
        transitionDuration: const Duration(milliseconds: 280),
        getPages: [
          GetPage<void>(page: () => SplashScreen(), name: '/'),
        ],
        // Phone "large text" setting (Oct 2026): follow it, but only between
        // 0.9x and 1.3x, so cards with a fixed height don't overflow.
        // Oct 2026: Flutter's own clamp widget. The old version re-read the
        // whole MediaQuery here, so this wrapper rebuilt on every frame of
        // the keyboard sliding up (keyboard felt slow).
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        ),
        // home: BuySubscriptions(),
      ),
    );
    // });
  }
}
