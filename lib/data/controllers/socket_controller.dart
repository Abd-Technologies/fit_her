import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/paid_home_controller/paid_home_controller.dart';
import 'package:fitness_zone_2/data/controllers/post_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/helper/notification_services.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/get_clients_diet.dart';
import '../models/get_user_plan/get_workout_user_plan_details.dart';
import '../models/post_model.dart';
import '../models/upcoming_class_slot.dart';
import 'auth_controller/auth_controller.dart';
import 'socket_time_block.dart';

class SocketController extends GetxController {
  // Last class notice shown from the live connection (see slotUpdate).
  static const String _kLastSlotNotice = 'socket_last_slot_notice';
  final Map<String, DateTime> _recentLikeEvents = {};
  IO.Socket? socket;

  HomeController homeController = Get.find();

  // The socket opens bound to whoever was logged in at the time
  // (onConnect emits "getSlot" with that user's id — see socketInit below)
  // and nothing ever closed it on logout. Get.delete now calls this
  // automatically, so logging out actually drops the connection instead of
  // leaving it open and receiving/emitting events for a signed-out account.
  @override
  void onClose() {
    socket?.disconnect();
    socket = null;
    super.onClose();
  }

  void joinCommunity() {
    debugPrint('SocketController.joinCommunity');
    socket?.emit("joinCommunity");
  }

  void leaveCommunity() {
    debugPrint('SocketController.leaveCommunity');
    socket?.emit("leaveCommunity");
  }

  void joinPost(int postId) {
    debugPrint('SocketController.joinPost $postId');
    socket?.emit("joinPost", postId);
  }

  void leavePost(int postId) {
    debugPrint('SocketController.leavePost $postId');
    socket?.emit("leavePost", postId);
  }

  socketInit() {
    // Uses Constants.baseUrl so dev builds hit local server and prod
    // builds hit backend.thefither.com — previously hardcoded to prod.
    socket = IO.io(Constants.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 2000,
    });

    socket?.connect();
    socket?.onConnect((c) {
      debugPrint('SocketController.onConnect ${socket?.id}');
      socket?.emit("getSlot", {"id": Get.find<AuthController>().logInUser?.id});
    });
    socket?.onConnectError((error) {
      debugPrint('SocketController.onConnectError $error');
    });
    socket?.onError((error) {
      debugPrint('SocketController.onError $error');
    });
    socket?.onDisconnect((reason) {
      debugPrint('SocketController.onDisconnect $reason');
    });
    socket?.on("slotUpdate", (message) {
      if (message == null) return;

      // Defensive: a missing/null trainer used to throw here and skip the
      // whole update (the screen then never refreshed).
      final UpcomingClassSlot upcomingClassSlot;
      try {
        final rawTrainer = message["trainer"] == null
            ? null
            : jsonDecode(message["trainer"].toString());
        upcomingClassSlot = UpcomingClassSlot(
          upcomingSlot: Slot.fromJson(jsonDecode(message["upcomingSlot"])),
          trainer: rawTrainer is Map<String, dynamic>
              ? ClientUser.fromJson(rawTrainer)
              : null,
        );
      } catch (e) {
        debugPrint('[socket] slotUpdate parse failed: $e');
        _silentRefreshSchedule();
        return;
      }

      // Always update UI so she can see the class on screen
      homeController.upComingClassNotifier.value = upcomingClassSlot;

      // Only fire a local notification if the slot falls in her preferred
      // time block, AND only when something really changed (Oct 2026):
      // the server answers every (re)connect with the current slot, so the
      // same "class confirmed" notification used to pop up on every app
      // open / network reconnect. The last one shown is remembered on the
      // phone (class + status + today), so each change notifies once.
      final slot = upcomingClassSlot.upcomingSlot;
      final now = DateTime.now();
      final changeKey =
          '${slot?.id}|${slot?.status}|${now.year}-${now.month}-${now.day}';
      final prefs = Get.find<AuthController>().sharedPreferences;
      final lastKey = prefs.getString(_kLastSlotNotice);
      final isChange = lastKey != null && lastKey != changeKey;
      prefs.setString(_kLastSlotNotice, changeKey);
      if (isChange && slot != null && _isInPreferredTimeBlock(slot.start)) {
        final notifServices = Get.find<NotificationServices>();
        // Reuse the existing addNotification-style local push via RemoteMessage-like data.
        // Since we're coming from socket (not FCM), we show a local notification directly.
        notifServices.showLocalNotification(
          title: _titleForStatus(upcomingClassSlot.upcomingSlot?.status),
          body: _bodyForStatus(upcomingClassSlot.upcomingSlot?.status),
        );
      }

      // Instantly refresh the new home dashboard (comingUp tiles) and the
      // workout schedule screen so status changes (Confirmed, Cancelled,
      // In Progress) appear immediately without waiting for the 30s heartbeat.
      // Both calls are silent — no loading spinner, no error toast.
      _silentRefreshSchedule();
    });

    socket?.on("newPost", (message) {
      debugPrint('SocketController.newPost $message');
      if (message != null) {
        var post = Post.fromJson(message);
        if (post.approved) {
          final postController = Get.find<PostController>();
          final existing = postController.postsList.firstWhereOrNull((p) => p.id == post.id);
          if (existing == null) {
            postController.postsList.add(post);
            postController.postsList.refresh();
          }
        }
      }
    });

    socket?.on("replyWithUser", (message) {
      debugPrint('SocketController.replyWithUser $message');
      if (message != null) {
        final post = Get.find<PostController>().postsList.firstWhereOrNull((p) => p.id == message["postId"]);
        if (post != null) {
          final reply = Reply.fromJson(message);
          final alreadyExists = post.replies.any((r) => r.id == reply.id);
          // RxList: only this post's widgets update (Oct 2026: was a
          // full feed rebuild for every reply anyone wrote).
          if (!alreadyExists) post.replies.add(reply);
        }
      }
    });
    socket?.on("replyCreated", (message) {
      debugPrint('SocketController.replyCreated $message');
      if (message != null) {
        final dynamic postIdValue = message["postId"];
        final int? postId = postIdValue is int ? postIdValue : int.tryParse(postIdValue.toString());
        final replyJson = message["reply"];
        if (postId == null || replyJson == null) {
          return;
        }
        final post = Get.find<PostController>().postsList.firstWhereOrNull((p) => p.id == postId);
        if (post != null) {
          final reply = Reply.fromJson(replyJson);
          final alreadyExists = post.replies.any((r) => r.id == reply.id);
          if (!alreadyExists) post.replies.add(reply);
        }
      }
    });

    socket?.on("toggleLike", (message) {
      if (message is! Map) return;
      final postId = int.tryParse('${message["postId"]}');
      if (postId == null) return;
      final liked = message["like"] == true;
      final who = '${message["userId"]}';
      // Our own likes are already applied on tap (PostController.likePost).
      final me = Get.find<AuthController>().myId;
      if (who.isNotEmpty && who != 'null' && who == me) return;
      // The server sends the same event to the feed room and the post room;
      // count it once.
      final key = '$postId:$who:$liked';
      final now = DateTime.now();
      final last = _recentLikeEvents[key];
      if (last != null && now.difference(last).inMilliseconds < 1500) return;
      _recentLikeEvents[key] = now;
      final pc = Get.find<PostController>();
      final post = pc.postsList.firstWhereOrNull((p) => p.id == postId);
      if (post != null) {
        // likesCount is reactive: only this heart updates.
        if (liked) {
          post.likesCount.value++;
        } else if (post.likesCount.value > 0) {
          post.likesCount.value--;
        }
      }
    });

    socket?.on("postUpdated", (message) {
      if (message is! Map<String, dynamic>) return;
      final pc = Get.find<PostController>();
      final updated = Post.fromJson(message);
      final i = pc.postsList.indexWhere((p) => p.id == updated.id);
      if (i >= 0) {
        pc.postsList[i] = updated;
        pc.postsList.refresh();
      }
    });

    socket?.on("postDeleted", (message) {
      if (message is! Map) return;
      final id = int.tryParse('${message["id"]}');
      if (id == null) return;
      Get.find<PostController>().postsList.removeWhere((p) => p.id == id);
    });
  }

  /// Fires silent data refreshes on every screen that shows slot status.
  /// Called on every incoming [slotUpdate] socket event so Confirmed /
  /// Cancelled / In Progress changes appear instantly without waiting for
  /// the 30-second heartbeat timers in PaidHomeScreenV2 and WorkOutBottomScreen.
  ///
  /// Both calls are best-effort — we swallow errors so a stale controller
  /// (e.g., trainer device that never mounted WorkOutBottomScreen) can't
  /// crash the socket handler.
  void _silentRefreshSchedule() {
    // New home screen — refreshes comingUp slot tiles.
    try {
      Get.find<PaidHomeController>().silentRefresh();
    } catch (_) {}

    // Workout schedule screen — refreshes the full slot tree.
    // planId '0' is the "current plan" sentinel used across the app.
    try {
      Get.find<WorkOutController>().getDietPlanDetailsFunc('0', silent: true);
    } catch (_) {}
  }

  /// Returns true if [slotStart] falls inside the user's preferred time block.
  /// Handles both 24h ("08:00") and 12h ("8:00 AM" / "08:00 PM") formats.
  /// "all" or unset → always true (notify for everything).
  ///
  /// Delegates to socket_time_block.dart's pure `isSlotTimeInPreferredBlock`
  /// so the actual matching logic (and its tests) lives in one shared,
  /// dependency-free place — this wrapper just supplies the timeBlock
  /// preference from SharedPreferences. Every existing call site is
  /// unchanged.
  bool _isInPreferredTimeBlock(String? slotStart) {
    final prefs = Get.find<AuthController>().sharedPreferences;
    final timeBlock = prefs.getString(Constants.timeBlock) ?? 'all';
    return isSlotTimeInPreferredBlock(timeBlock, slotStart);
  }

  String _titleForStatus(String? status) => classReminderTitleForStatus(status);

  String _bodyForStatus(String? status) => classReminderBodyForStatus(status);

  getSlot() {
    socket?.emit("getSlot", {"id": Get.find<AuthController>().logInUser?.id});
  }

  @override
  void onInit() {
    socketInit();
    super.onInit();
  }
}
