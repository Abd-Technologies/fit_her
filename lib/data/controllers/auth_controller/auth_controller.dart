import '../../../widgets/trial_moments/trial_moments.dart';
import '../../../helper/consult_presence.dart';
import 'dart:convert';
import '../consultation_controller/consultation_controller.dart';
import '../../../UI/auth_module/sign_up_screen/life_stage_gate.dart';
import '../../../UI/auth_module/sign_up_screen/sign_up_screen_questions.dart';
import '../../../helper/signup_progress.dart';
import 'dart:io';
import 'package:fitness_zone_2/UI/auth_module/login/login.dart';
import 'package:fitness_zone_2/UI/auth_module/result_screen.dart';
import 'package:fitness_zone_2/UI/auth_module/sign_up_screen/signup_screen_user.dart';
import 'package:fitness_zone_2/UI/auth_module/walt_through/walk_through_screenn.dart';
import 'package:fitness_zone_2/UI/auth_module/time_preference_screen.dart';
import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'package:fitness_zone_2/widgets/new_home/trial_cta_card.dart';
import 'package:fitness_zone_2/UI/free_trail/trial_onboarding_screen.dart' show savedTrialOnboardingStep;
import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/api_provider/chat_api_provider.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_contoller/diet_controller.dart';
import 'package:fitness_zone_2/data/controllers/progress_controller/progress_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/data/controllers/motivation_controller/motivation_controller.dart';
import 'package:fitness_zone_2/data/controllers/plan_controller/plan_controller.dart';
import 'package:fitness_zone_2/data/controllers/rating_controller/rating_controller.dart';
import 'package:fitness_zone_2/data/controllers/post_controller.dart';
import 'package:fitness_zone_2/data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import 'package:fitness_zone_2/data/controllers/paid_home_controller/paid_home_controller.dart';
import 'package:fitness_zone_2/data/controllers/consultation_controller/consultation_controller.dart';
import 'package:fitness_zone_2/data/controllers/meal_log_controller/meal_log_controller.dart';
import 'package:fitness_zone_2/data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_plan_admin_controller/diet_plan_admin_controller.dart';
import 'package:fitness_zone_2/data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import 'package:fitness_zone_2/data/controllers/day7_review_controller/day7_review_controller.dart';
import 'package:fitness_zone_2/data/controllers/zoom_controller.dart';
import 'package:fitness_zone_2/data/controllers/socket_controller.dart';
import 'package:fitness_zone_2/data/controllers/progress_v2/progress_controller_v2.dart';
import 'package:fitness_zone_2/data/controllers/trial_token_controller.dart';
import 'package:fitness_zone_2/data/controllers/call_controller/chat_controller.dart';
import 'package:fitness_zone_2/UI/chat/chat_controller.dart';
import 'package:fitness_zone_2/data/models/get_all_dietitian_users/get_all_dietitian_users.dart';
import 'package:fitness_zone_2/data/models/login_response_model/login_response_model.dart';
import 'package:get/get.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helper/get_di.dart';
import '../../../helper/notification_services.dart';
import '../../../helper/analytics_helper.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../../GetServices/CheckConnectionService.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../Repos/auth_repo/auth_repo.dart';
import '../../services/timezone_sync_service.dart';
import '../../models/api_response/api_response_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fAuth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/get_all_users/get_all_users_based_on_type.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';
import '../../services/notification_scheduler.dart';

class AuthController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  AuthRepo authRepo;
  NotificationServices notificationServices;
  ChatApiProvider chatApiProvider;
  CheckConnectionService connectionService = CheckConnectionService();
  AuthController({required this.sharedPreferences, required this.authRepo, required this.notificationServices, required this.chatApiProvider});

  ///Generating unique id
  var uuid = const Uuid();
  var showDot = false.obs;
  var isLoggingIn = false.obs;

  ///TextEditing Controller for Adding User
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailNameController = TextEditingController();
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  ///payment controller
  TextEditingController cardHolderName = TextEditingController();
  TextEditingController cardNumber = TextEditingController();
  TextEditingController expiryDate = TextEditingController();
  TextEditingController cvc = TextEditingController();

  ///Edit controller
  TextEditingController editFirstName = TextEditingController();
  TextEditingController editLastName = TextEditingController();
  TextEditingController editEmail = TextEditingController();
  TextEditingController editAge = TextEditingController();
  TextEditingController editWeight = TextEditingController();
  TextEditingController editHeight = TextEditingController();
  TextEditingController editBmi = TextEditingController();
  var mainGoal = ''.obs;
  var healthConditions = ''.obs;

  ///countryCode
  var countryCode = Constants.countryCode;
  List<String> addTeamMember = ["Dietition", "Trainer", "Gynecologist", "Psychiatrist", "Customer_Support_Representative", "Admin"];

  ///Sign in User
  TextEditingController loginUserPhone = TextEditingController();
  TextEditingController loginUserPassword = TextEditingController();

  ///Update user
  TextEditingController dateExtendController = TextEditingController();

  String daysDurationValue = "";
  String monthDurationValue = "";
  var selectCustomerSupport = 0.obs;

  bool daysSelected = false;
  bool monthSelected = false;
  var getUsersBasedOnUserTypeLoad = false.obs;

  ///User Model
  LoginModel? logInUser;

  var loginAsA = Constants.user.obs;

  /// Local-only "trial activated" flag, flipped by tapping Start 3-day free
  /// trial on the unpaid home. Drives the activated variants of LIVE row,
  /// locked tiles, insight card, and CTA banner. Persisted in prefs so a
  /// cold start keeps the activated state; cleared on logout.
  /// See [Constants.trialActivatedKey].
  late final RxBool trialActivated = RxBool(sharedPreferences.getBool(Constants.trialActivatedKey) ?? false);

  /// Flip the local trial flag on. Called by `TrialCtaCard` after the
  /// "Trial activated" dialog is acknowledged.
  void activateTrial() {
    trialActivated.value = true;
    sharedPreferences.setBool(Constants.trialActivatedKey, true);
  }

  /// Reactive mirror of `logInUser?.status`. Plain `LoginModel.status` is a
  /// non-observable bool, so home_screen.dart's `Obx` can't rebuild off it
  /// when payment auto-approval flips the user from unpaid → paid. Read
  /// this inside the home routing Obx so the screen swaps to
  /// `PaidHomeScreenV2` the instant `markPaid()` fires.
  var isPaid = false.obs;

  /// Promote the in-memory user to a paid state after the backend confirms
  /// auto-approval (`userPlanActivated == true` in the slip-upload
  /// response). Also persists `useNewPaidHome=true` so a cold start lands
  /// on the new V2 paid home rather than the legacy `UserHomeScreen`.
  void markPaid() {
    final u = logInUser;
    if (u == null) return;
    // Already marked paid: nothing to re-read. Without this, the plans
    // reload below called markPaid() again (HomeController.getUserHomeFunc
    // sees a paid plan), which reloaded again... an endless loop of
    // dashboard + /trial/me + userHome calls (Oct 2026).
    final already = u.status == true && isPaid.value;
    u.status = true;
    u.useNewPaidHome = true;
    sharedPreferences.setBool(Constants.useNewPaidHomeKey, true);
    isPaid.value = true;
    if (already) return;
    // Oct 2026: re-read her trial (the server marks it converted on
    // payment) so the "N-day free trial" cards go away without logout.
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      home.getMyTrialJourney();
      // Oct 2026: also re-read her plans. Home picks the paid home only
      // when it sees a real (paid) plan; with the old list it kept
      // showing the free home until she logged out and in again.
      home.getUserHomeFunc(silent: true, forceRefresh: true);
    }
    try {
      if (Get.isRegistered<PaidHomeController>()) {
        Get.find<PaidHomeController>().refreshDashboard();
      }
    } catch (_) {}
  }

  /// Mirrors [markPaid] for the opposite direction: after a successful
  /// self-service plan cancellation, the backend flips User.status=false
  /// (see planFreezeController.cancelPlan) so the *next* login shows the
  /// unpaid home — but without this, the user would keep seeing the full
  /// paid app until then, directly contradicting the cancel dialog's "This
  /// ends your access right away". Called right after the cancel API call
  /// succeeds so HomeScreen's Obx (which already watches isPaid.value)
  /// swaps to UnpaidHomeScreenV2 immediately, same screen, no re-login.
  void markUnpaid() {
    final u = logInUser;
    if (u == null) return;
    u.status = false;
    isPaid.value = false;
  }

  List<String> packageState = [
    "Start",
    "Pause",
  ];
  List<String> screenShot = [
    "Yes",
    "No",
  ];
  List<String> recording = [
    "Yes",
    "No",
  ];
  List<String> memberDesignation = [
    "Trainer",
    "Dietitian",
  ];

  ///get All users
  GetDietitianUsers getDietitianUsers = GetDietitianUsers(result: []);
  GetUsersBasedOnUserType? getUsersBasedOnUserTypeModel;

  var memerDesig = "Trainer";

  List<XFile> mealImages = [];
  int i = 0;

  /// getting days function
  int gettingDays() {
    if (daysSelected) {
      return int.parse(daysDurationValue.split(" ").first);
    } else {
      return int.parse(monthDurationValue.split(" ").first) * 30;
    }
  }

  ///Listerner
  ///
  ValueNotifier<List<dynamic>?> sharedPrefNotifier = ValueNotifier<List<dynamic>?>(null);

  final fAuth.FirebaseAuth _auth = fAuth.FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);

  ///Clear sign up Controllers
  clearSignUpController() {
    firstNameController.clear();
    lastNameController.clear();
    emailNameController.clear();
    phoneNumberController.clear();
    passwordController.clear();
  }

  @override
  onInit() {
    initNotifications();
    super.onInit();
  }

  addLocalStorage(LoginModel model, String password) {
    sharedPreferences.setString(Constants.accessToken, model.accessToken);
    sharedPreferences.setString(Constants.userId, model.id.toString());
    // Mixpanel identity — every login path funnels through addLocalStorage,
    // so this single call ties all future events to the real backend user
    // instead of an anonymous per-install id.
    AnalyticsHelper.setUserId(model.id.toString());
    // Who she is in Mixpanel (no names): every chart can be split by these.
    AnalyticsHelper.setProfile({
      'user_type': loginAsA.value.toLowerCase(),
      'plan_state': model.status ? 'paid' : 'none',
    });
    sharedPreferences.setString(Constants.email, model.email.toString());
    sharedPreferences.setString(Constants.password, password);
    sharedPreferences.setString(Constants.loginAsa, loginAsA.value);

    // Seed the reactive paid-state mirror from the freshly-loaded user.
    // Every login path funnels through here, so this single line keeps
    // [isPaid] in sync with `logInUser.status` on each sign-in.
    isPaid.value = model.status;

    sharedPreferences.setBool(Constants.isGuest, false);
    // Persist Option-C feature flags so the router can honor them on cold
    // start before a fresh login response is available.
    sharedPreferences.setBool(Constants.useNewPaidHomeKey, model.useNewPaidHome);
    sharedPreferences.setBool(Constants.useNewUnpaidHomeKey, model.useNewUnpaidHome);
    sharedPreferences.setBool(Constants.useNewProgressHubKey, model.useNewProgressHub);
    if (model.phone.isNotEmpty) {
      sharedPreferences.setString(Constants.userMobileNumber, model.phone);
    }
    if ((model.mainGoal ?? '').isNotEmpty) {
      sharedPreferences.setString('cached_main_goal', model.mainGoal!);
    }
    if ((model.healthConditions ?? '').isNotEmpty) {
      sharedPreferences.setString('cached_health_conditions', model.healthConditions!);
    }
    sharedPreferences.setString(Constants.userTimeZoneKey, model.timeZone);
    // Kick the sync service. Idempotent — safe to call after every
    // login (Email/Password, Google, Apple, etc.).
    // Nov 2026: consultation leave time (helper/consult_presence.dart).
    if (loginAsA.value == Constants.user) ConsultPresence.instance.start();
    try {
      Get.find<TimezoneSyncService>().start();
    } catch (_) {
      // DI not ready (cold-start race) — service will be wired up the
      // next time addLocalStorage runs.
    }
  }

  /// Her user id as text. Falls back to the saved id while `logInUser` is
  /// still loading after a cold start (Nov 2026: the feed loaded first,
  /// her own likes looked like someone else's and were counted twice).
  String get myId {
    final id = logInUser?.id;
    if (id != null) return '$id';
    return sharedPreferences.getString(Constants.userId) ?? '';
  }

  /// Phase F.3 — IANA zone the dietitian set on `User.timeZone`. In-memory
  /// `logInUser` is the authoritative source while logged in; the
  /// SharedPreferences fallback covers the cold-start window before
  /// `logInUser` rehydrates from a fresh login.
  String get userTimeZone {
    final inMem = logInUser?.timeZone;
    if (inMem != null && inMem.isNotEmpty) return inMem;
    final cached = sharedPreferences.getString(Constants.userTimeZoneKey);
    if (cached != null && cached.isNotEmpty) return cached;
    return 'Asia/Karachi';
  }

  /// Phase F.3 — called by TimezoneSyncService when the device drifts.
  /// Updates the in-memory model + the cached SharedPreferences value
  /// in lockstep so the rest of the app sees the new zone instantly.
  void setUserTimeZoneLocal(String tzName) {
    if (logInUser != null) logInUser!.timeZone = tzName;
    sharedPreferences.setString(Constants.userTimeZoneKey, tzName);
  }

  login({String? userType, String? email, String? password, bool showLoading = true}) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        isLoggingIn.value = true;
        if (showLoading) {
          Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        }
        if (userType != null) {
          loginAsA.value = userType;
        }
        await authRepo
            .loginUserRepo(
          email: email ?? loginUserPhone.text.removeAllWhitespace,
          password: password ?? loginUserPassword.text,
          deviceToken: sharedPreferences.getString(Constants.deviceToken) ?? "",
          userType: loginAsA.value,
        )
            .then((response) async {
          if (showLoading) {
            Get.back();
          }
          isLoggingIn.value = false;
          print('AuthController.login ${response}}');
          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              // Only a login she typed (not the silent re-login on app start).
              if (email == null) AnalyticsHelper.loginFailed('email', '${response.body["message"] ?? 'refused'}');
              CustomToast.failToast(msg: response.body["message"]);
              if (email != null) {
                Get.offAll(() => const WalkThroughScreen());
              }
            } else if (response.body["status"] != "0") {
              ApiResponse<LoginModel> model = ApiResponse.fromJson(response.body, LoginModel.fromJson);
              debugPrint(model.data!.accessToken.toString());
              if (model.status == "1") {
                logInUser = model.data;

                addLocalStorage(logInUser!, password ?? loginUserPassword.text);
                if (email == null) AnalyticsHelper.loginCompleted('email', userType: loginAsA.value.toLowerCase());
                final trialStarted = await Get.find<HomeController>().startTrialFromSavedToken();

                if (loginAsA.value == Constants.trainer) {
                  //  Get.find<HomeController>().getTrainerHomeFunc();
                } else if (loginAsA.value == Constants.dietitian) {
                  //   Get.find<HomeController>().getDietHomeFunc();
                } else if (loginAsA.value == Constants.admin) {
                  // Get.find<HomeController>().getTrialPlanDetails();
                } else if (loginAsA.value == Constants.user) {
                  if (!logInUser!.status) {
                    Get.find<HomeController>().getPlansUser();
                  } else {
                    Get.find<HomeController>().getUserHomeFunc();
                  }
                }

                loginUserPhone.clear();
                loginUserPassword.clear();
                updateUserDetails();
                if (trialStarted && loginAsA.value == Constants.user) {
                  enterTrialOnboarding(); // consolidated: -> diet quick-intake -> AI plan -> workout onboarding
                }
              }
            }
          } else {
            isLoggingIn.value = false;
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  signInUsingGoogle(String userEmail, String name, String signedFrom, {String? userType, bool fromLocal = false, bool? showLoading}) {
    final bool shouldShowLoading = showLoading ?? !fromLocal;
    if (shouldShowLoading) {
      Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
    }
    connectionService.checkConnection().then((value) async {
      if (!value) {
        if (shouldShowLoading) {
          Get.back();
        }

        CustomToast.noInternetToast();
        // Get.back();
      } else {
        authRepo
            .googleSignIn(
          email: userEmail,
          deviceToken: sharedPreferences.getString(Constants.deviceToken) ?? "",
          userType: userType ?? loginAsA.value,
        )
            .then((response) async {
          Get.log("login api response :${response.body}");
          if (shouldShowLoading) {
            Get.back();
          }
          // Remember Google / Apple so a new account's sign-up says how.
          if (signedFrom == 'google' || signedFrom == 'apple') {
            sharedPreferences.setString('last_social_provider', signedFrom);
          }
          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              if (!fromLocal) AnalyticsHelper.loginFailed(signedFrom, '${response.body["message"] ?? 'refused'}');
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              if (response.body["status"] == "1") {
                ApiResponse<LoginModel> model = ApiResponse.fromJson(response.body, LoginModel.fromJson);
                debugPrint(model.data!.accessToken.toString());
                logInUser = model.data;

                addLocalStorage(logInUser!, signedFrom);
                if (!fromLocal) AnalyticsHelper.loginCompleted(signedFrom, userType: loginAsA.value.toLowerCase());
                final trialStarted = await Get.find<HomeController>().startTrialFromSavedToken();

                if (loginAsA.value == Constants.user) {
                  if (!logInUser!.status) {
                    Get.find<HomeController>().getPlansUser();
                  } else {
                    Get.find<HomeController>().getUserHomeFunc();
                  }
                }

                loginUserPhone.clear();
                loginUserPassword.clear();
                updateUserDetails();
                if (trialStarted && loginAsA.value == Constants.user) {
                  enterTrialOnboarding(); // consolidated: -> diet quick-intake -> AI plan -> workout onboarding
                }
              } else if (response.body["status"] == "2") {
                print('AuthController.signInUsingGoogle}');
                emailNameController.text = userEmail;
                firstNameController.text = name.split(" ").first;
                lastNameController.text = name.split(" ").last;
                if (fromLocal) {
                  Get.find<AuthController>().loginUserPhone.text = userEmail;
                  Get.offAll(() => Login());
                } else {
                  Get.to(() => SignUpNewUser(
                        isSocial: true,
                      ));
                }
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  /// Loads the paid Home dashboard while the splash is still showing, so
  /// Home opens already drawn. Never blocks for more than 4 s and never
  /// throws: on a timeout the fetch keeps going and Home shows it on arrival.
  Future<void> _preloadPaidHome() async {
    try {
      final c = Get.find<PaidHomeController>();
      if (c.dashboard.value != null) return;
      await c.loadDashboard().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  getUsersBasedOnUserType(String userType, {bool addNull = false}) {
    getUsersBasedOnUserTypeLoad.value = false;
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        authRepo
            .getSubUserBasedOnUserTypes(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          userType: userType,
        )
            .then((response) async {
          // Get.back();
          if (response.body["status"] == "0") {
            CustomToast.failToast(msg: response.body["message"]);
          } else if (response.body["status"] != "0") {
            ApiResponse<GetUsersBasedOnUserType> model = ApiResponse.fromJson(response.body, GetUsersBasedOnUserType.fromJson);
            if (model.status == "1") {
              getUsersBasedOnUserTypeModel = model.data!;
              if (addNull) {
                getUsersBasedOnUserTypeModel?.users.insert(0, UserTypeData(id: 0, firstName: "Select", lastName: "..", email: "", phone: ""));
              } else {
                if (getUsersBasedOnUserTypeModel!.users.isNotEmpty) {
                  selectCustomerSupport.value = getUsersBasedOnUserTypeModel!.users[0].id;
                }
              }
              getUsersBasedOnUserTypeLoad.value = true;
            }
          }
        });
      }
    });
  }

  Future<void> showEmailsDialog({bool isFromResortScreen = false}) async {
    // Get.dialog(Center(child: CircularProgressIndicator()),
    //     barrierDismissible: false);
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        // Get.back();

        CustomToast.noInternetToast();
      } else {
        try {
          final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
          if (googleSignInAccount != null) {
            final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
            final fAuth.AuthCredential credential = fAuth.GoogleAuthProvider.credential(
              accessToken: googleSignInAuthentication.accessToken,
              idToken: googleSignInAuthentication.idToken,
            );

            final fAuth.UserCredential authResult = await _auth.signInWithCredential(credential);
            final fAuth.User? user = authResult.user;
            if (user != null) {
              signInUsingGoogle(
                user.email ?? "",
                user.displayName ?? "",
                "google",
              );
            }
          }
        } catch (error) {
          //Get.back();
          print("Error during Google Sign-In: $error");
        }
      }
    });
  }

  void handleappleLogin() async {
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        final appleAuthProvider = fAuth.AppleAuthProvider();
        appleAuthProvider.addScope("email");
        appleAuthProvider.addScope("name");

        var authCredentials = await _auth.signInWithProvider(appleAuthProvider);
        final fAuth.User? user = authCredentials.user;
        print("User :   $user");
        if (user != null) {
          if (Platform.isIOS) {
            if (user.email == null) {
              if (user.providerData.isNotEmpty) {
                signInUsingGoogle(user.providerData[0].email ?? "", user.displayName ?? "", "apple");
              } else {
                signInUsingGoogle(user.email ?? "", user.displayName ?? "", "apple");
              }
            } else {
              signInUsingGoogle(user.email ?? "", user.displayName ?? "", "apple");
            }
          } else {
            signInUsingGoogle(user.email ?? "", user.displayName ?? "", "apple");
          }
        } else {
          CustomToast.failToast(msg: "Something went wrong");
        }
      }
    });
  }

  initNotifications() {
    var list = sharedPreferences.getString(Constants.notificationList);
    List<NotificationMessage> notificationMessages = [];

    // Oct 2026: one bad saved item must never crash the app on start —
    // skip what can't be read (the server list refills the bell anyway).
    if (list != null) {
      try {
        final list2 = jsonDecode(list);
        if (list2 is List) {
          for (final item in list2) {
            try {
              if (item is Map) {
                notificationMessages.add(
                    NotificationMessage.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (e) {
              debugPrint('[bell] skipped a saved item: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[bell] saved list unreadable, starting empty: $e');
      }
    }
    sharedPrefNotifier.value = notificationMessages;
    fetchNotifications();
  }

  Future<void> fetchNotifications({bool markRead = false}) async {
    final accessToken = sharedPreferences.getString(Constants.accessToken);
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      final response = await authRepo.getNotifications(accessToken: accessToken);
      if (response.statusCode == 200 && response.body["status"] == "1") {
        final raw = response.body["data"]?["notifications"];
        if (raw is List) {
          final notificationMessages = raw
              .map((item) => NotificationMessage.fromServer(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
          sharedPrefNotifier.value = notificationMessages;
          sharedPreferences.setString(
            Constants.notificationList,
            jsonEncode(notificationMessages.map((msg) => msg.toJson()).toList()),
          );
        }
      }

      if (markRead) {
        await authRepo.markNotificationsRead(accessToken: accessToken);
        sharedPreferences.setBool("showDotHome", false);
        Get.find<HomeController>().showDotHome.value = false;
      }
    } catch (e) {
      debugPrint("fetchNotifications failed: $e");
    }
  }

  updateUserDetails({bool updateFields = true}) async {
    // Firestore update is best-effort — a failure (offline, permission) must
    // NOT prevent navigation or the user gets stuck on the login screen.
    try {
      await FirebaseFirestore.instance.collection("users").doc(logInUser!.id.toString()).set({
        "id": logInUser!.id.toString(),
        "name": logInUser!.firstName,
        "time": Timestamp.now(),
        "remoteId": 0,
        "newMessageArrived": false,
        "days": "",
        "deviceToken": sharedPreferences.getString(Constants.deviceToken)
      });
    } catch (e) {
      debugPrint("updateUserDetails: Firestore write failed (non-fatal): $e");
    }
    // var userMap1 = await FirebaseFirestore.instance
    //     .collection("users")
    //     .doc(logInUser!.adminId.toString())
    //     .get();§§§
    // userMap = userMap1.data()!;
    // String roomId = (logInUser!.id.toString().hashCode +
    //         logInUser!.adminId.toString().hashCode)
    //     .toString();
    editFirstName.text = logInUser?.firstName ?? "";
    editLastName.text = logInUser?.lastName ?? "";
    editEmail.text = logInUser?.email ?? "";

    if (updateFields) {
      editBmi.text = logInUser?.bmiResult ?? "";
      editAge.text = logInUser?.age ?? "";
      editWeight.text = logInUser?.weight ?? "";
      editHeight.text = logInUser?.height ?? "";
      final goal = (logInUser?.mainGoal != null && logInUser!.mainGoal!.isNotEmpty)
          ? logInUser!.mainGoal!
          : (sharedPreferences.getString('cached_main_goal') ?? "");
      mainGoal.value = goal;
      final conditions = (logInUser?.healthConditions != null && logInUser!.healthConditions!.isNotEmpty)
          ? logInUser!.healthConditions!
          : (sharedPreferences.getString('cached_health_conditions') ?? "");
      healthConditions.value = conditions;
    }
    Get.find<HomeController>().getUserHomeFunc();
    // Time-preference onboarding is only relevant for regular Users —
    // trainers, dietitians, admins, and specialists go straight to home.
    final isRegularUser = logInUser?.userType == 'User';

    // Life stage gate (signup step 5). Pregnant women, and new mothers
    // still inside their recovery time, see a Coming soon screen instead
    // of the app. A new mother whose time is up (or anyone who stopped
    // at that step) continues signup from the start, with her answers
    // prefilled. Rules live on the backend: helper/lifeStage.js.
    // Paid clients are never locked out here: if a paying client tells
    // us she's pregnant, her dietitian handles it.
    if (isRegularUser && !(logInUser?.status ?? false)) {
      final ls = await Get.find<ConsultationController>().getLifeStage();
      final access = ls?['access'];
      if (access == 'pregnant' || access == 'waiting') {
        Get.offAll(() => LifeStageComingSoonScreen(data: ls!));
        return;
      }
      // baby_check: past her due date + waiting time, ask again at step 5.
      if (access == 'needs_details' ||
          access == 'needs_clearance' ||
          access == 'baby_check') {
        restartSignupFlow();
        return;
      }
    }

    // Sign-up questions not finished (closed the app, lost internet, or
    // signed up on another phone): open them again where she stopped,
    // her saved answers filled in. Paid clients are covered by their
    // health form, so they are never sent back here.
    if (isRegularUser &&
        !(logInUser?.status ?? false) &&
        !SignupProgress.isDone(logInUser, sharedPreferences)) {
      Get.offAll(() => const SignUpScreenQuestions(),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic);
      return;
    }

    // Primary gate: explicit done flag written by TimePreferenceScreen._save()
    // on any completion path (select + go, skip, or Android back).
    // This survives logout because all clear() paths preserve it.
    var prefDone = sharedPreferences.getString(Constants.timePreferenceDone) == 'true';

    if (isRegularUser && !prefDone) {
      // Device flag missing (fresh install, new device, or pre-fix logout).
      // Check backend as fallback: if the user previously saved preferences
      // on any device, restore the value locally and skip the screen.
      try {
        final token = sharedPreferences.getString(Constants.accessToken) ?? '';
        final response = await Get.find<ApiProvider>().getData(
          '/users/notification_preferences',
          headers: {'accessToken': token},
        );
        final data = response.body?['data'];
        if (data != null && data['updatedAt'] != data['createdAt']) {
          // Backend confirms user saved preferences before → seed local flags.
          sharedPreferences.setString(Constants.timeBlock, data['timeBlock'] ?? 'all');
          sharedPreferences.setString(Constants.timePreferenceDone, 'true');
          prefDone = true;
        }
      } catch (_) {
        // Offline / error — fall through and show the screen.
      }
    }

    // Deep-link trial token check — signup path.
    // login() and signInUsingGoogle() already call startTrialFromSavedToken().
    // updateUserDetails() is the signup completion path and never did — so a
    // user who tapped a rep's trial link, got redirected to WalkThrough, then
    // created an account would land on UnpaidHome and still see the manual
    // "Start free trial" button. This consumes the saved token here instead.
    bool trialStarted = false;
    if (isRegularUser) {
      trialStarted = await Get.find<HomeController>().startTrialFromSavedToken();
    }

    if (isRegularUser && !prefDone) {
      // Pass onCompleted so TimePreferenceScreen calls us back instead of
      // navigating to BottomBarScreen itself — we need to push TrialJourneyScreen
      // on top after BottomBarScreen mounts if the trial was auto-started.
      Get.offAll(() => TimePreferenceScreen(
            onCompleted: (_) {
              // Smooth hand-off from splash/login to home.
      Get.offAll(
        () => BottomBarScreen(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
              if (trialStarted) {
                enterTrialOnboarding(); // consolidated: -> diet quick-intake -> AI plan -> workout onboarding
              }
            },
          ),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic);
    } else {
      // App start (still on the splash): fetch her Home dashboard first so
      // the splash fades straight into a drawn Home, not into the loading
      // skeleton (Oct 2026). Capped at 4 s; Home loads it itself if not.
      if (isRegularUser && (logInUser?.status ?? false) && Get.currentRoute == '/') {
        await _preloadPaidHome();
      }
      // Smooth hand-off from splash/login to home.
      Get.offAll(
        () => BottomBarScreen(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
      if (trialStarted) {
        // Push TrialJourneyScreen on top of BottomBarScreen so the user can
        // navigate back to home if needed. Small delay for BottomBarScreen mount.
        await Future.delayed(const Duration(milliseconds: 300));
        enterTrialOnboarding(); // consolidated: -> diet quick-intake -> AI plan -> workout onboarding
      } else if (isRegularUser &&
          !(logInUser?.status ?? false) &&
          !trialActivated.value &&
          savedTrialOnboardingStep() > 0) {
        // She closed the app halfway through the trial form: take her
        // back to the screen she was on (answers are saved). Oct 2026.
        await Future.delayed(const Duration(milliseconds: 300));
        enterTrialOnboarding();
      }
    }
  }

  /// Logout wipes the phone's saved data, but "already shown once"
  /// markers must survive it, or one-time pop-ups come back after every
  /// log-out / log-in (e.g. "Welcome to Fit Her, plan active" showed again
  /// days after payment, Oct 2026). The markers carry her user / plan id,
  /// so another account on the same phone still gets its own.
  static const List<String> _keepOnLogout = [
    'welcome_plan_', // PlanWelcomeMoment, per paid plan
    'trial_welcome_done_', // TrialWelcomeSheet, per user
    'target_ask_after_weighin_', // target weight question, per user
    'profile_card_seen_', // "Finish your profile" seen, per user
    'profile_complete_shown_', // "Profile complete 🎉" shown, per user
    'plan_intro_seen_', // "Your plan just got personal", per user
  ];

  Future<void> _clearPrefsKeepingOnceMarkers() async {
    final keep = <String, Object>{};
    for (final k in sharedPreferences.getKeys()) {
      if (_keepOnLogout.any(k.startsWith)) {
        final v = sharedPreferences.get(k);
        if (v != null) keep[k] = v;
      }
    }
    await sharedPreferences.clear();
    for (final e in keep.entries) {
      final v = e.value;
      if (v is bool) {
        await sharedPreferences.setBool(e.key, v);
      } else if (v is String) {
        await sharedPreferences.setString(e.key, v);
      } else if (v is int) {
        await sharedPreferences.setInt(e.key, v);
      }
    }
  }

  guestLogin(String result) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        // Get.back();
      } else {
        Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
        await authRepo
            .loginGuestRepo(
          email: emailNameController.text,
          name: firstNameController.text,
          phone: phoneNumberController.text,
          result: result,
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(msg: response.body["message"]);
            } else if (response.body["status"] != "0") {
              if (response.body["status"] == "1") {
                emailNameController.clear();
                phoneNumberController.clear();
                firstNameController.clear();
                Get.offAll(() => ResultScreen(result: result));
              }
            }
          } else {
            CustomToast.failToast(msg: response.body["message"]);
          }
        });
      }
    });
  }

  Future<bool> forgotPassword(String email) async {
    bool isSuccess = false;
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        isSuccess = false;
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await authRepo
            .forgotPasswordRepo(
          email: email.trim().toLowerCase(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(
                  msg: response.body["message"] ?? "Failed to send OTP");
              isSuccess = false;
            } else if (response.body["status"] == "1") {
              AnalyticsHelper.passwordReset('requested');
              isSuccess = true;
            }
          } else {
            CustomToast.failToast(
                msg: response.body["message"] ?? "Server error");
            isSuccess = false;
          }
        });
      }
    });
    return isSuccess;
  }

  Future<bool> verifyOtp({required String email, required String otp}) async {
    bool isValid = false;
    await connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
        isValid = false;
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await authRepo
            .verifyOtpRepo(
          email: email.trim().toLowerCase(),
          otp: otp.trim(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "1") {
              AnalyticsHelper.passwordReset('otp_verified');
              isValid = true;
            } else {
              CustomToast.failToast(
                  msg: response.body["message"] ?? "Invalid OTP code");
              isValid = false;
            }
          } else {
            CustomToast.failToast(
                msg: response.body["message"] ?? "Server error");
            isValid = false;
          }
        });
      }
    });
    return isValid;
  }

  void resetPassword({
    required String email,
    required String password,
    required String otp,
  }) {
    connectionService.checkConnection().then((value) async {
      if (!value) {
        CustomToast.noInternetToast();
      } else {
        Get.dialog(const Center(child: FhLoader()),
            barrierDismissible: false);
        await authRepo
            .resetPasswordRepo(
          email: email.trim().toLowerCase(),
          password: password,
          otp: otp.trim(),
        )
            .then((response) async {
          Get.back();

          if (response.statusCode == 200) {
            if (response.body["status"] == "0") {
              CustomToast.failToast(
                  msg: response.body["message"] ?? "Failed to reset password");
            } else if (response.body["status"] == "1") {
              AnalyticsHelper.passwordReset('done');
              Get.offAll(() => Login());
              CustomToast.successToast(
                  msg: response.body["message"] ??
                      "Password updated successfully!");
            }
          } else {
            CustomToast.failToast(
                msg: response.body["message"] ?? "Server error");
          }
        });
      }
    });
  }

  /// [serverId]: the bell item's id on the server, so it is hidden there
  /// too and doesn't come back on the next refresh (Oct 2026).
  void removeItem(int index, {int? serverId}) {
    if (serverId != null) {
      final token = sharedPreferences.getString(Constants.accessToken) ?? '';
      if (token.isNotEmpty) {
        authRepo
            .hideNotifications(accessToken: token, notificationIds: [serverId])
            .catchError((e) {
          debugPrint('hideNotifications failed: $e');
          return Response<dynamic>();
        });
      }
    }
    // Update the list by removing the item at the given index
    if (sharedPrefNotifier.value != null) {
      var list = sharedPreferences.getString(Constants.notificationList);

      // Create a new list if none exists
      List<NotificationMessage> notificationMessages = [];

      // If the list already exists in SharedPreferences
      if (list != null) {
        // Decode the existing list
        var list2 = jsonDecode(list);

        // Convert each item back to NotificationMessage and add to notificationMessages list
        notificationMessages = List<NotificationMessage>.from(list2.map((item) => NotificationMessage.fromJson(item)));
      }

      notificationMessages.removeAt(index);
      sharedPrefNotifier.value = notificationMessages;
      sharedPreferences.setString(Constants.notificationList, jsonEncode(notificationMessages));
    }
  }

  Future<void> markAllNotificationsRead() async {
    final accessToken = sharedPreferences.getString(Constants.accessToken);
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      await authRepo.markNotificationsRead(accessToken: accessToken);
      sharedPreferences.setBool("showDotHome", false);
      Get.find<HomeController>().showDotHome.value = false;
    } catch (e) {
      debugPrint("markAllNotificationsRead failed: $e");
    }
  }

  // Logout used to only clear SharedPreferences and reset a couple of this
  // controller's own fields — every other controller kept its old in-memory
  // state (fenix:true just means GetX *can* rebuild it later, not that it
  // ever did on logout). On a shared/family device, signing into a second
  // account right after could briefly — or in a few places indefinitely —
  // show the previous user's plan, workout, diet, or chat data.
  //
  // force:true is required on every one of these: several of these
  // controllers implement GetxService, which GetX treats as permanent by
  // default, so a plain Get.delete() would silently do nothing. fenix:true
  // (set in get_di.dart for everything except the ad-hoc ones below) means
  // the very next Get.find<T>() rebuilds a clean instance from scratch —
  // nothing needs to be re-registered by hand.
  //
  // Each deletion is wrapped individually so one unexpected failure can't
  // block logout itself or skip cleaning up the rest.
  void _disposePerUserControllers() {
    for (final delete in <void Function()>[
      () => Get.delete<HomeController>(force: true),
      // Nov 2026: kept "permanent", so the last user's trial moment could
      // show for the next one.
      () => Get.delete<TrialMomentController>(force: true),
      () => Get.delete<DietController>(force: true),
      () => Get.delete<ProgressController>(force: true),
      () => Get.delete<WorkOutController>(force: true),
      () => Get.delete<MotivationController>(force: true),
      () => Get.delete<PlanController>(force: true),
      () => Get.delete<RatingController>(force: true),
      () => Get.delete<PostController>(force: true),
      () => Get.delete<CycleThemeController>(force: true),
      () => Get.delete<PaidHomeController>(force: true),
      () => Get.delete<ConsultationController>(force: true),
      () => Get.delete<MealLogController>(force: true),
      () => Get.delete<DietitianDashboardController>(force: true),
      () => Get.delete<DietPlanAdminController>(force: true),
      () => Get.delete<DietPlanUserController>(force: true),
      () => Get.delete<Day7ReviewController>(force: true),
      () => Get.delete<TimezoneSyncService>(force: true),
      () => Get.delete<ZoomMeetingGetxController>(force: true),
      // Ad-hoc Get.put sites outside get_di.dart — not fenix, but each is
      // re-created by its own screen's initState/build the next time it's
      // opened, which normal navigation after Get.offAll below will do.
      () => Get.delete<SocketController>(force: true),
      () => Get.delete<ProgressControllerV2>(tag: 'progress_v2', force: true),
      () => Get.delete<TrialTokenController>(force: true),
      () => Get.delete<CallController>(force: true),
      () => Get.delete<AudioController>(force: true),
    ]) {
      try {
        delete();
      } catch (e) {
        debugPrint('logout: controller cleanup skipped: $e');
      }
    }
  }

  logout() async {
    var token = sharedPreferences.getString(Constants.deviceToken);
    if (token != null) {
      connectionService.checkConnection().then((value) async {
        if (!value) {
          CustomToast.noInternetToast();
        } else {
          Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
          await authRepo
              .logoutUserRepo(
                  deviceToken: token,
                  accessToken: sharedPreferences.getString(Constants.accessToken))
              .then((response) async {
            Get.back();
            if (response.statusCode == 200) {
              if (response.body["status"] == "0") {
                CustomToast.failToast(msg: response.body["message"]);
              } else if (response.body["status"] != "0") {
                if (response.body["status"] == "1") {
                  CustomToast.successToast(msg: response.body["message"]);
                  // Mixpanel: forget her, the next person on this phone is new.
                  AnalyticsHelper.logout();
                  // Preserve time-preference keys across logout — device-level
                  // settings; wiping them re-triggers onboarding every login.
                  final savedTimeBlock = sharedPreferences.getString(Constants.timeBlock);
                  final savedPrefDone = sharedPreferences.getString(Constants.timePreferenceDone);
                  // Logged out: stop her daily nudge on this phone (it repeats by itself).
                  await NotificationScheduler.cancelAll();
                  await _clearPrefsKeepingOnceMarkers();
                  if (savedTimeBlock != null) {
                    sharedPreferences.setString(Constants.timeBlock, savedTimeBlock);
                  }
                  if (savedPrefDone != null) {
                    sharedPreferences.setString(Constants.timePreferenceDone, savedPrefDone);
                  }
                  trialActivated.value = false;
                  isPaid.value = false;
                  logInUser = null;
                  _disposePerUserControllers();
                  Get.offAll(() => Login());
                  NotificationServices().getDeviceToken();
                  await init();
                  if (await googleSignIn.isSignedIn()) {
                    googleSignIn.signOut();
                  }
                  loginAsA.value = Constants.user;
                }
              }
            } else {
              CustomToast.failToast(msg: response.body["message"]);
            }
          });
        }
      });
    } else {
      // No push token on this phone: still end the login on the server
      // (fire and forget — she is logged out locally either way).
      final accessToken = sharedPreferences.getString(Constants.accessToken);
      if (accessToken != null && accessToken.isNotEmpty) {
        authRepo.logoutUserRepo(deviceToken: '', accessToken: accessToken);
      }
      CustomToast.failToast(msg: "Successfully Logout");
      final savedTimeBlock = sharedPreferences.getString(Constants.timeBlock);
      final savedPrefDone = sharedPreferences.getString(Constants.timePreferenceDone);
      // Logged out: stop her daily nudge on this phone (it repeats by itself).
      await NotificationScheduler.cancelAll();
      await _clearPrefsKeepingOnceMarkers();
      if (savedTimeBlock != null) {
        sharedPreferences.setString(Constants.timeBlock, savedTimeBlock);
      }
      if (savedPrefDone != null) {
        sharedPreferences.setString(Constants.timePreferenceDone, savedPrefDone);
      }
      trialActivated.value = false;
      isPaid.value = false;
      logInUser = null;
      _disposePerUserControllers();
      await init();
      loginAsA.value = Constants.user;
      Get.offAll(() => Login());
    }
  }

  /// Nov 2026: the server ended this login (logged out on another phone,
  /// password changed). Sign out on this phone only (no server call, the
  /// token is already dead) and show the login screen. Runs once even when
  /// several requests fail at the same time.
  bool _signingOut = false;
  Future<void> signOutLocally({String message = 'Please log in again'}) async {
    if (_signingOut) return;
    final token = sharedPreferences.getString(Constants.accessToken) ?? '';
    if (token.isEmpty) return; // already logged out
    _signingOut = true;
    try {
      final savedTimeBlock = sharedPreferences.getString(Constants.timeBlock);
      final savedPrefDone = sharedPreferences.getString(Constants.timePreferenceDone);
      await NotificationScheduler.cancelAll();
      await _clearPrefsKeepingOnceMarkers();
      if (savedTimeBlock != null) sharedPreferences.setString(Constants.timeBlock, savedTimeBlock);
      if (savedPrefDone != null) sharedPreferences.setString(Constants.timePreferenceDone, savedPrefDone);
      trialActivated.value = false;
      isPaid.value = false;
      logInUser = null;
      _disposePerUserControllers();
      await init();
      loginAsA.value = Constants.user;
      Get.offAll(() => Login());
      Future.delayed(const Duration(milliseconds: 400), () => CustomToast.failToast(msg: message));
    } catch (e) {
      debugPrint('signOutLocally: $e');
    } finally {
      _signingOut = false;
    }
  }

  deleteUser({String? id}) {
    var token = sharedPreferences.getString(Constants.accessToken);
    if (token != null) {
      connectionService.checkConnection().then((value) async {
        if (!value) {
          CustomToast.noInternetToast();
        } else {
          Get.dialog(const Center(child: FhLoader()), barrierDismissible: false);
          await authRepo.deleteUser(
                  id: id ?? sharedPreferences.getString(Constants.userId) ?? "",
                  accessToken: sharedPreferences.getString(Constants.accessToken)).then((response) async {
            Get.back();
            if (response.statusCode == 200) {
              if (response.body["status"] == "0") {
                CustomToast.failToast(msg: response.body["message"]);
              } else if (response.body["status"] != "0") {
                if (response.body["status"] == "1") {
                  final savedTimeBlock = sharedPreferences.getString(Constants.timeBlock);
                  final savedPrefDone = sharedPreferences.getString(Constants.timePreferenceDone);
                  // Logged out: stop her daily nudge on this phone (it repeats by itself).
                  await NotificationScheduler.cancelAll();
                  await _clearPrefsKeepingOnceMarkers();
                  if (savedTimeBlock != null) {
                    sharedPreferences.setString(Constants.timeBlock, savedTimeBlock);
                  }
                  if (savedPrefDone != null) {
                    sharedPreferences.setString(Constants.timePreferenceDone, savedPrefDone);
                  }
                  trialActivated.value = false;
                  isPaid.value = false;
                  Get.offAll(() => const WalkThroughScreen());
                }
              }
            } else {
              CustomToast.failToast(msg: response.body["message"]);
            }
          });
        }
      });
    } else {
      CustomToast.failToast(msg: "You are not Logged in.");
    }
  }

  var homeDataLoad = false.obs;

  sendMessageNotifications(Map<String, dynamic> body) async {
    await chatApiProvider.postData(body: body);
  }
}
