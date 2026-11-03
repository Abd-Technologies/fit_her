import 'package:get/get.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../../values/constants.dart';
import '../../api_provider/api_provider.dart';

class AuthRepo extends GetxService {
  ApiProvider apiProvider;

  AuthRepo({
    required this.apiProvider,
  });

  Future<Response> signUpUserRepo({required Map<String, dynamic> body}) async {
    return await apiProvider.postData(Constants.signupPath, body: body);
  }

  Future<Response> loginUserRepo({
    required String email,
    required String password,
    required String deviceToken,
    required String userType,
  }) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();

    var body = {
      "email": email,
      "password": password,
      "userType": userType,
      "deviceToken": deviceToken,
      "timeZone": currentTimeZone,
    };

    return await apiProvider.postData(Constants.loginPath, body: body);
  }

  Future<Response> googleSignIn({
    required String email,
    required String deviceToken,
    required String userType,
  }) async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();

    var body = {
      "email": email,
      "deviceToken": deviceToken,
      "userType": userType,
      "timeZone": currentTimeZone,
    };

    return await apiProvider.postData(Constants.socialLogin, body: body);
  }

  Future<Response> getSubUserBasedOnUserTypes(
      {required String accessToken, required String userType}) async {
    return await apiProvider.getData(
        "${Constants.getUsersOnUserType}/$userType",
        headers: {"accessToken": accessToken});
  }

  Future<Response> logoutUserRepo({
    required String deviceToken,
    String? accessToken,
  }) async {
    var body = {
      "deviceToken": deviceToken,
    };

    // The server logs her out everywhere using the login token (Oct 2026).
    return await apiProvider.postData(Constants.logout,
        body: body, headers: {"accessToken": accessToken ?? ""});
  }

  Future<Response> getNotifications({
    required String accessToken,
    int limit = 50,
    int offset = 0,
  }) async {
    return await apiProvider.getData(
      Constants.notifications,
      query: {
        "limit": limit.toString(),
        "offset": offset.toString(),
      },
      headers: {"accessToken": accessToken},
    );
  }

  Future<Response> markNotificationsRead({
    required String accessToken,
    bool markAll = true,
    List<int>? notificationIds,
  }) async {
    return await apiProvider.postData(
      Constants.markNotificationsRead,
      body: {
        "markAll": markAll,
        if (notificationIds != null) "notificationIds": notificationIds,
      },
      headers: {"accessToken": accessToken},
    );
  }

  /// Bell item swiped away: hide it on the server so it doesn't come back.
  Future<Response> hideNotifications({
    required String accessToken,
    required List<int> notificationIds,
  }) async {
    return await apiProvider.postData(
      Constants.hideNotifications,
      body: {"notificationIds": notificationIds},
      headers: {"accessToken": accessToken},
    );
  }

  Future<Response> loginGuestRepo({
    required String email,
    required String name,
    required String phone,
    required String result,
  }) async {
    var body = {
      "email": email,
      "name": name,
      "phone": phone,
      "result": result,
    };

    return await apiProvider.postData(Constants.guestLogin, body: body);
  }

  Future<Response> forgotPasswordRepo({required String email}) async {
    var body = {
      "email": email,
    };

    return await apiProvider.postData(Constants.forgotPassword, body: body);
  }

  Future<Response> verifyOtpRepo(
      {required String email, required String otp}) async {
    var body = {
      "email": email,
      "otp": otp,
    };

    return await apiProvider.postData(Constants.verifyOtp, body: body);
  }

  Future<Response> resetPasswordRepo({
    required String email,
    required String password,
    required String otp,
  }) async {
    var body = {
      "email": email,
      "password": password,
      "otp": otp,
    };

    return await apiProvider.postData(Constants.resetPassword, body: body);
  }

  Future<Response> dietitianLogin({
    required String email,
    required String password,
  }) async {
    var body = {
      "email": email,
      "password": password,
    };

    return await apiProvider.postData(Constants.dietitianLogin, body: body);
  }

  Future<Response> trainerLogin({
    required String email,
    required String password,
  }) async {
    var body = {
      "email": email,
      "password": password,
    };

    return await apiProvider.postData(Constants.trainerLogin, body: body);
  }

  // Future<Response> verifyEmailRepo(
  //     {required String otp,
  //     required String userId,
  //     required String deviceToken}) async {
  //   return await apiProvider.postData(Constants.verifyEmailPath,
  //       body: {"OTP": otp, "userId": userId, "deviceToken": deviceToken});
  // }

  // // TODO: implement This function
  // Future<Response> changePasswordRepo({
  //   required String email,
  //   required String password,
  //   required String otp,
  //   required String forgetRequestId,
  // }) async {
  //   return await apiProvider.postData(Constants.changePasswordPath, body: {
  //     "userId": email,
  //     "password": password,
  //     "OTP": otp,
  //     "forgetRequestId": forgetRequestId
  //   });
  // }

  // Future<Response> forgotPasswordRepo({required String email}) async {
  //   return await apiProvider.postData(Constants.forgotPasswordPath, body: {
  //     "email": email,
  //   });
  // }

  Future<Response> resendOtpRepo(
      {required String email, required String userId}) async {
    return await apiProvider.postData(Constants.resendOtpPath,
        body: {"email": email, "userId": userId});
  }

  Future logout({required String accessToken}) async {
    return await apiProvider
        .postData(Constants.logout, body: {"accessToken": accessToken});
  }

  Future deleteUser({required String id, String? accessToken}) async {
    // The server now needs the login token (own account, or an admin).
    return await apiProvider.postData(Constants.deleteUser,
        body: {"userId": id}, headers: {"accessToken": accessToken ?? ""});
  }

  // checkSessionRepo({required String accessToken, required bool isGuest}) async {
  //   return await apiProvider.postData(Constants.sessionPath,
  //       headers: {"accessToken": accessToken}, body: {"guestUser": isGuest});
  // }

  resendForgetOtpRepo({required String email}) async {
    return await apiProvider
        .postData(Constants.resendOtpPath, body: {"email": email});
  }

  getHomeData({required String accessToken}) async {
    return await apiProvider
        .getData(Constants.home, headers: {"accessToken": accessToken});
  }

  getDietitianUsers({required String accessToken}) async {
    return await apiProvider.postData(Constants.getDietitianUsers,
        headers: {"accessToken": accessToken}, body: {});
  }

  getUserPlan({required String accessToken}) async {
    return await apiProvider.postData(Constants.getUserPlan,
        headers: {"accessToken": accessToken}, body: {});
  }
}
