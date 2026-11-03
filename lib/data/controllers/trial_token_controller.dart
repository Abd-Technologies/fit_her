import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a single TrialToken row returned from the backend.
class TrialTokenModel {
  final int id;
  final String token;
  final String deepLink;
  final String? phone;
  final String? email;
  final String status; // issued | used | expired | revoked
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  const TrialTokenModel({
    required this.id,
    required this.token,
    required this.deepLink,
    this.phone,
    this.email,
    required this.status,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
  });

  factory TrialTokenModel.fromJson(Map<String, dynamic> json) {
    return TrialTokenModel(
      id:        json['id']       as int,
      token:     json['token']    as String,
      deepLink:  json['deepLink'] as String,
      phone:     json['phone']    as String?,
      email:     json['email']    as String?,
      status:    json['status']   as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      usedAt:    json['usedAt'] != null
          ? DateTime.tryParse(json['usedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isActive  => status == 'issued';
  bool get isUsed    => status == 'used';
  bool get isExpired => status == 'expired';
  bool get isRevoked => status == 'revoked';
}

/// GetX controller for the sales rep trial-token panel.
///
/// Responsibilities:
///   - [createToken]   — POST /admin/create-trial-token
///   - [loadMyTokens]  — GET  /admin/my-trial-tokens
///   - [revokeToken]   — DELETE /admin/revoke-trial-token/:token
///
/// Used by [TrialTokenScreen].
class TrialTokenController extends GetxController {
  final ApiProvider _api = ApiProvider();
  late final SharedPreferences _prefs;

  // ── Reactive state ──────────────────────────────────────────────────────────

  final RxList<TrialTokenModel> tokens    = <TrialTokenModel>[].obs;
  final RxBool isLoading                  = false.obs;
  final RxBool isCreating                 = false.obs;

  /// The last token just created — held so the screen can show the share sheet.
  final Rx<TrialTokenModel?> lastCreated  = Rx<TrialTokenModel?>(null);

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _prefs = Get.find<SharedPreferences>();
    loadMyTokens();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String get _accessToken =>
      _prefs.getString(Constants.accessToken) ?? '';

  // ── API calls ────────────────────────────────────────────────────────────────

  /// Creates a new trial token and prepends it to [tokens].
  /// [phone] and [expiresInDays] are optional.
  Future<void> createToken({
    String? phone,
    String? email,
    int expiresInDays = 7,
  }) async {
    if (isCreating.value) return;
    isCreating.value = true;

    try {
      final response = await _api.postData(
        Constants.trialTokenCreate,
        body: {
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          'expiresInDays': expiresInDays,
        },
        headers: {'accessToken': _accessToken},
      );

      if (response.statusCode == 200 && response.body['status'] == '1') {
        final created = TrialTokenModel.fromJson(
          response.body['data'] as Map<String, dynamic>,
        );
        tokens.insert(0, created);
        lastCreated.value = created;
      } else {
        CustomToast.failToast(
          msg: response.body['message'] as String? ?? 'Failed to create link',
        );
      }
    } catch (e) {
      CustomToast.failToast(msg: 'Network error — please try again');
    } finally {
      isCreating.value = false;
    }
  }

  /// Loads (or refreshes) this rep's token list from the backend.
  Future<void> loadMyTokens() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final response = await _api.getData(
        Constants.trialTokenList,
        headers: {'accessToken': _accessToken},
      );

      if (response.statusCode == 200 && response.body['status'] == '1') {
        final data = response.body['data'] as Map<String, dynamic>;
        final list = (data['tokens'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(TrialTokenModel.fromJson)
            .toList();
        tokens.assignAll(list);
        // Trial length set by admin: keeps "your N-day trial" in the
        // share message right on staff phones too.
        final days = int.tryParse('${data['trialDays'] ?? ''}');
        if (days != null && days > 0 && Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().trialDays.value = days;
        }
      } else {
        CustomToast.failToast(
          msg: response.body['message'] as String? ?? 'Failed to load tokens',
        );
      }
    } catch (e) {
      CustomToast.failToast(msg: 'Network error — please try again');
    } finally {
      isLoading.value = false;
    }
  }

  /// Revokes a token by its string value. Removes it from the local list
  /// and updates status so the UI reflects the change immediately.
  Future<void> revokeToken(String token) async {
    try {
      final response = await _api.deleteData(
        '${Constants.trialTokenRevoke}/$token',
        headers: {'accessToken': _accessToken},
      );

      if (response.statusCode == 200 && response.body['status'] == '1') {
        final idx = tokens.indexWhere((t) => t.token == token);
        if (idx != -1) {
          final updated = TrialTokenModel.fromJson(
            response.body['data'] as Map<String, dynamic>,
          );
          tokens[idx] = updated;
          tokens.refresh();
        }
        CustomToast.successToast(msg: 'Link revoked');
      } else {
        CustomToast.failToast(
          msg: response.body['message'] as String? ?? 'Failed to revoke link',
        );
      }
    } catch (e) {
      CustomToast.failToast(msg: 'Network error — please try again');
    }
  }
}
