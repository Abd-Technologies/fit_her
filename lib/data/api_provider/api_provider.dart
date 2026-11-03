import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../values/constants.dart';

// MultipartFile.fromPath defaults to application/octet-stream when no
// contentType is supplied — which the backend's image fileFilter (multer)
// rejects with "Only image files (jpg, png, webp, gif) are allowed". Map
// the extension to a real image MIME so multipart parts arrive correctly
// labelled.
MediaType _mediaTypeForPath(String filePath) {
  final lower = filePath.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot >= 0 ? lower.substring(dot + 1) : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'gif':
      return MediaType('image', 'gif');
    case 'heic':
      return MediaType('image', 'heic');
    case 'heif':
      return MediaType('image', 'heif');
    default:
      return MediaType('application', 'octet-stream');
  }
}

class ApiProvider extends GetxService {
  final String baseUrl = Constants.baseUrl;

  /// Login renewal (Oct 2026): when the login token is getting old the
  /// server sends a fresh one in the `x-new-token` response header. The app
  /// (helper/get_di.dart) and the staff portal (portal/main_portal.dart) set
  /// this to save it. Nothing else changes for callers.
  static void Function(String token)? onNewToken;

  /// Staff portal only (the app leaves it null): called when a reply says
  /// the login token is missing / expired / revoked.
  static void Function()? onAuthInvalid;
  static const authInvalidMessages = {'Invalid accessToken!', 'User not loggedIn!'};
  /// The message of the reply that called [onAuthInvalid] (Nov 2026: the
  /// app only signs out on "Invalid accessToken!", a dead login).
  static String lastAuthInvalidMessage = '';

  static void _checkAuthInvalid(dynamic body) {
    final cb = onAuthInvalid;
    if (cb == null || body is! Map) return;
    if ('${body['status']}' == '0' && authInvalidMessages.contains('${body['message']}')) {
      lastAuthInvalidMessage = '${body['message']}';
      try {
        cb();
      } catch (e) {
        debugPrint('====> onAuthInvalid failed: $e');
      }
    }
  }

  static void _checkNewToken(Map<String, String>? headers) {
    final t = headers?['x-new-token'];
    final cb = onNewToken;
    if (t == null || t.isEmpty || cb == null) return;
    try {
      cb(t);
    } catch (e) {
      debugPrint('====> onNewToken failed: $e');
    }
  }

  // Every plain JSON call below (postData/putData/patchData/getData/
  // deleteData) used to await http.* with no timeout and no try/catch, so a
  // hung request never resolved and a thrown exception (no signal, DNS
  // failure, etc.) skipped straight past every caller's loading-flag reset
  // and Get.back() — a stuck spinner with no error shown. These now always
  // resolve to a Response, the same defensive shape setFormData already
  // used successfully for uploads, so every existing caller's normal
  // "statusCode != 200 -> show message" handling now also covers a hang or
  // a network error, with zero changes needed at each call site.
  Response<dynamic> _networkFailureResponse(String url, Object error, {bool isTimeout = false}) {
    final message = isTimeout
        ? 'Request timed out. Please check your connection and try again.'
        : 'Something went wrong. Please check your connection and try again.';
    debugPrint('====> API ${isTimeout ? "Timeout" : "Error"}: [$baseUrl$url] $error');
    return Response(
      statusCode: isTimeout ? 408 : 503,
      bodyString: message,
      body: {"status": "0", "message": message},
    );
  }

  Future<Response> postData(String url, {required Map<String, dynamic> body, Map<String, String>? headers, Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('====> API Call: [$baseUrl$url]\n$body  \n $headers');

    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    try {
      var response = await http.post(
        Uri.parse(baseUrl + url),
        headers: defaultHeaders,
        body: jsonEncode(body),
      ).timeout(timeout);
      return await handleData(url, response);
    } on TimeoutException catch (e) {
      return _networkFailureResponse(url, e, isTimeout: true);
    } catch (e) {
      return _networkFailureResponse(url, e);
    }
  }

  Future<Response> putData(String url, {required Map<String, dynamic> body, Map<String, String>? headers, Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('====> API Call: [$baseUrl$url]\n$body  \n $headers');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    try {
      var response = await http.put(Uri.parse(baseUrl + url), body: jsonEncode(body), headers: defaultHeaders ?? {}).timeout(timeout);
      return await handleData(url, response);
    } on TimeoutException catch (e) {
      return _networkFailureResponse(url, e, isTimeout: true);
    } catch (e) {
      return _networkFailureResponse(url, e);
    }
  }

  Future<Response> patchData(String url, {required Map<String, dynamic> body, Map<String, String>? headers, Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('====> API Call: [$baseUrl$url]\n$body  \n $headers');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    try {
      var response = await http.patch(Uri.parse(baseUrl + url), body: jsonEncode(body), headers: defaultHeaders).timeout(timeout);
      return await handleData(url, response);
    } on TimeoutException catch (e) {
      return _networkFailureResponse(url, e, isTimeout: true);
    } catch (e) {
      return _networkFailureResponse(url, e);
    }
  }

  Future<Response<dynamic>> getData(String url, {Map<String, dynamic>? query, Map<String, String>? headers, Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('====> API Call: [$baseUrl$url]\n$query  \n $headers');
    var uri = Uri.parse(baseUrl + url).replace(queryParameters: query);
    try {
      var response = await http.get(uri, headers: headers ?? {}).timeout(timeout);
      return await handleData(url, response);
    } on TimeoutException catch (e) {
      return _networkFailureResponse(url, e, isTimeout: true);
    } catch (e) {
      return _networkFailureResponse(url, e);
    }
  }

  Future<Response<dynamic>> deleteData(String url, {Map<String, dynamic>? query, Map<String, String>? headers, Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('====> API Call: [$baseUrl$url]\n$query  \n $headers');
    var uri = Uri.parse(baseUrl + url).replace(queryParameters: query);
    try {
      var response = await http.delete(uri, headers: headers ?? {}).timeout(timeout);
      return await handleData(url, response);
    } on TimeoutException catch (e) {
      return _networkFailureResponse(url, e, isTimeout: true);
    } catch (e) {
      return _networkFailureResponse(url, e);
    }
  }

  Future<Response<dynamic>> handleData(String url, http.Response response) async {
    debugPrint('====> API Response: [${response.statusCode}] $baseUrl$url\n${response.body}');

    dynamic _body;
    try {
      _body = jsonDecode(response.body);
    } catch (e) {
      _body = {};
    }
    _checkNewToken(response.headers);
    _checkAuthInvalid(_body);

    return Response(
      body: _body,
      bodyString: response.body,
      headers: response.headers,
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
    );
  }

  Future<Response> setFormData({
    required String url,
    required Map<String, dynamic> formData,
    bool isProgress = false,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final fullUrl = Uri.parse('$baseUrl$url');
    debugPrint('====> API Call: [$fullUrl]\n$formData\n$headers');

    final request = http.MultipartRequest('POST', fullUrl);

    // Add headers if available
    if (headers != null) {
      request.headers.addAll(headers);
    }

    // Add non-file fields
    formData.forEach((key, value) {
      if (!['image', 'before', 'after'].contains(key)) {
        request.fields[key] = value.toString();
      }
    });

    try {
      // Add files based on the isProgress flag
      if (isProgress) {
        if (formData['before'] != null && formData['after'] != null) {
          final beforePath = formData['before'] as String;
          final afterPath = formData['after'] as String;
          request.files.add(await http.MultipartFile.fromPath(
            'before',
            beforePath,
            contentType: _mediaTypeForPath(beforePath),
          ));
          request.files.add(await http.MultipartFile.fromPath(
            'after',
            afterPath,
            contentType: _mediaTypeForPath(afterPath),
          ));
        } else {
          throw Exception("Missing 'before' or 'after' file for progress upload.");
        }
      } else {
        if (formData['image'] != null) {
          final imagePath = formData['image'] as String;
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            imagePath,
            contentType: _mediaTypeForPath(imagePath),
          ));
        } else {
          throw Exception("Missing 'image' file for upload.");
        }
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      _checkNewToken(response.headers);

      debugPrint('====> API Response: [${response.statusCode}] $fullUrl\n${response.body}');

      return Response(
        statusCode: response.statusCode,
        bodyString: response.body,
      );
    } on TimeoutException {
      debugPrint('====> API Timeout: Request to $fullUrl timed out.');
      return Response(
        statusCode: 408,
        bodyString: 'Request timed out. Please try again.',
      );
    } catch (e, stack) {
      debugPrint('====> API ERROR: $e\n$stack');
      return Response(
        statusCode: 500,
        bodyString: 'Error: ${e.toString()}',
      );
    }
  }
}
