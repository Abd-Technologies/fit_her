import 'dart:convert';
import 'home_controller/home_controller.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'auth_controller/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../values/constants.dart';
import '../../../widgets/toasts.dart';
import '../Repos/home_repo/home_repo.dart';
import '../models/api_response/api_response_model.dart';
import '../models/post_model.dart';

class PostController extends GetxController implements GetxService {
  SharedPreferences sharedPreferences;
  HomeRepo homeRepo;

  PostController({required this.sharedPreferences, required this.homeRepo});

  /// Rx Variables
  var allPostsLoad = false.obs;
  var createPostLoad = true.obs; // true = idle, false = creating post
  var approvePostLoad = false.obs;
  var deletePostLoad = false.obs;
  var replySendLoad = false.obs;
  var likeLoad = false.obs;

  var postsList = <Post>[].obs;
  File? postImageFile;

  /// ================================
  /// 🔹 GET ALL POSTS (with replies & likes)
  /// ================================
  getAllPosts({bool approved = true, bool silent = false}) {
    if (!silent) allPostsLoad.value = false;
    homeRepo
        .getAllPosts(
      approved: approved,
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
    )
        .then((response) {
      if (response.statusCode == 200) {
        ApiResponse<PostList> model = ApiResponse.fromJson(response.body, PostList.fromJson);
        // Use the parsed posts as they are: re-parsing through toJson()
        // lost the author's role, photo and who liked what.
        postsList.value = List<Post>.from(model.data!.posts);
        allPostsLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Failed to fetch posts");
      }
    });
  }

  /// ================================
  /// 🔹 CREATE POST
  /// Returns the created Post on success (use `.approved` to decide whether
  /// to show the "wait for admin approval" popup), or null on failure.
  /// ================================
  Future<Post?> createPost({required String text, bool isPost = true}) async {
    createPostLoad.value = false;
    Post? returnValue;
    await homeRepo
        .createPost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      text: text,
      isPost: isPost,
      file: postImageFile,
      userId: sharedPreferences.getString(Constants.userId) ?? "0",
    )
        .then((response) {
      // Backend returns 201 on successful create (other handlers return 200).
      // Treat any 2xx as a candidate success and let the body's `status` field
      // decide — otherwise a fresh post triggers a "Something went wrong"
      // toast despite the row + image having been saved.
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        var res = jsonDecode(response.bodyString ?? "");
        if (res["status"] == "1") {
          CustomToast.successToast(msg: res["message"]);
          postImageFile = null;
          final postJson = res["data"]?["post"];
          if (postJson is Map<String, dynamic>) {
            returnValue = Post.fromJson(postJson);
          }

          // var addedPost = Post.fromJson(res["data"]["post"]);
          // var user = Get.find<AuthController>().logInUser;
          // ClientUser clientUser = ClientUser(
          //     id: user?.id ?? 0,
          //     firstName: user?.firstName ?? "",
          //     lastName: "",
          //     email: user?.email ?? "",
          //     phone: null,
          //     experience: "",
          //     bmiResult: null,
          //     supporter: null);
          //
          // var newPost = Post(
          //     id: addedPost.id,
          //     text: addedPost.text,
          //     isPost: isPost,
          //     approved: approved,
          //     createdAt: addedPost.createdAt,
          //     updatedAt: addedPost.updatedAt,
          //     user: clientUser,
          //     likes: []);
          // print('PostController.createPost ${addedPost}');
          // print('PostController.createPost ll ${postsList.length}');
          // postsList.value = [...postsList, newPost];
          // print('PostController.createPost ${postsList.length}');

          // getAllPosts(approved: approved);
        } else {
          CustomToast.failToast(msg: res["message"]);
        }
        createPostLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Something went wrong");
      }
    });
    return returnValue;
  }

  /// ================================
  /// 🔹 DELETE POST
  /// ================================
  deletePost(int postId) {
    deletePostLoad.value = false;
    homeRepo
        .deletePost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
    )
        .then((response) {
      if (response.statusCode == 200) {
        ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
        if (model.status == "1") {
          CustomToast.successToast(msg: model.message);
          postsList.removeWhere((p) => p.id == postId);
        } else {
          CustomToast.failToast(msg: model.message);
        }
        deletePostLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Something went wrong");
      }
    });
  }

  /// ================================
  /// 🔹 APPROVE / UNAPPROVE POST
  /// ================================
  approvePost(int postId, {bool approved = true}) {
    approvePostLoad.value = false;
    homeRepo
        .approvePost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
      approved: approved,
    )
        .then((response) {
      if (response.statusCode == 200) {
        ApiResponse model = ApiResponse.fromJson(response.body, (p0) {});
        if (model.status == "1") {
          CustomToast.successToast(msg: approved ? "Post approved" : "Post unapproved");
          postsList.removeWhere((p) => p.id == postId);
          postsList.refresh();
        } else {
          CustomToast.failToast(msg: model.message);
        }
        approvePostLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Something went wrong");
      }
    });
  }

  /// ================================
  /// 🔹 LIKE / UNLIKE POST
  /// ================================
  // Oct 2026: likes are instant and double-taps can't flicker.
  // Each tap flips the heart at once and records what she wants; only one
  // request per post runs at a time, and when it returns we send one more
  // only if the server ended up different from her last tap.
  final Set<int> _likeBusy = {};
  final Map<int, bool> _likeWanted = {};

  void _setLiked(Post post, bool liked) {
    if (post.isLiked.value == liked) return;
    post.isLiked.value = liked;
    post.likesCount.value =
        (post.likesCount.value + (liked ? 1 : -1)).clamp(0, 1 << 30);
  }

  /// [target] = the exact post on screen (post screen opened from a push
  /// may not be in the feed list yet).
  likePost(int postId, {Post? target}) {
    final post = target ?? postsList.firstWhereOrNull((p) => p.id == postId);
    if (post == null) return;
    _setLiked(post, !post.isLiked.value);
    _likeWanted[postId] = post.isLiked.value;
    if (_likeBusy.contains(postId)) return; // the running request will catch up
    _syncLike(post, before: !post.isLiked.value);
  }

  Future<void> _syncLike(Post post, {required bool before}) async {
    final id = post.id;
    _likeBusy.add(id);
    likeLoad.value = false;
    try {
      // At most a few rounds (each round = one toggle on the server).
      for (var round = 0; round < 3; round++) {
        final response = await homeRepo.likePost(
          accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
          postId: id,
          userId: sharedPreferences.getString(Constants.userId) ?? "0",
        );
        bool? serverLiked;
        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.bodyString ?? "");
            if (data["status"] == "1") {
              serverLiked = "Like removed" != data["message"];
            } else {
              CustomToast.failToast(msg: data["message"]);
            }
          } catch (_) {}
        }
        if (serverLiked == null) {
          // Failed: back to how it was before her taps.
          _setLiked(post, before);
          if (response.statusCode != 200) {
            CustomToast.failToast(msg: "Couldn't update like. Try again.");
          }
          return;
        }
        final wanted = _likeWanted[id] ?? serverLiked;
        if (serverLiked == wanted) {
          _setLiked(post, serverLiked);
          return;
        }
        // She tapped again while this was on its way: send one more.
      }
    } finally {
      _likeBusy.remove(id);
      _likeWanted.remove(id);
      likeLoad.value = true;
    }
  }

  /// ================================
  /// 🔹 SEND A REPLY (WhatsApp-style)
  /// ================================
  sendReply({
    required int postId,
    required String message,
    int? parentReplyId,
  }) {
    replySendLoad.value = false;
    homeRepo
        .sendReply(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
      userId: sharedPreferences.getString(Constants.userId) ?? "0",
      message: message,
      replyToId: parentReplyId,
    )
        .then((response) {
      // Backend returns 201 on successful create — accept any 2xx and let
      // the body's `status` field decide. Strict == 200 incorrectly surfaced
      // "Something went wrong" even though the reply was actually saved.
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        var res = jsonDecode(response.bodyString ?? "");
        if (res["status"] == "1") {
          CustomToast.successToast(msg: "Message sent");
        } else {
          CustomToast.failToast(msg: res["message"]);
        }
        replySendLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Something went wrong");
      }
    });
  }

  // ── FitHer Feed helpers ──────────────────────────────────────────

  int? get myId => int.tryParse(sharedPreferences.getString(Constants.userId) ?? '');

  /// Same rule as the server: staff always, members with a paid plan.
  /// Trial and free users can read and like only.
  bool get canPost {
    final auth = Get.find<AuthController>();
    final type = auth.logInUser?.userType;
    if (type != null && type != 'User') return true;
    // Real paid package only — free trial (running or ended) can like but
    // not post/comment. The account "status" flag alone isn't enough: it
    // can be on during and after a trial. Same rule as the server.
    if (Get.isRegistered<HomeController>()) {
      final real = Get.find<HomeController>().hasRealPlan;
      if (real != null) return real;
    }
    return auth.logInUser?.status == true;
  }

  /// Sends a reply and adds it to the post at once. Returns true on success.
  Future<bool> sendReplyNow({required int postId, required String message}) async {
    // Oct 2026: her reply shows at once ("Sending…"), then is swapped for
    // the saved one; removed again if it couldn't be sent.
    final post = postsList.firstWhereOrNull((p) => p.id == postId);
    Reply? temp;
    if (post != null) {
      final me = Get.find<AuthController>().logInUser;
      final name = '${me?.firstName ?? ''} ${me?.lastName ?? ''}'.trim();
      temp = Reply(
        id: -DateTime.now().millisecondsSinceEpoch,
        postId: postId,
        userId: me?.id ?? 0,
        message: message,
        createdAt: DateTime.now(),
        author: FeedAuthor(
          id: me?.id,
          name: name.isEmpty ? 'Me' : name,
          userType: me?.userType,
        ),
        pending: true,
      );
      post.replies.add(temp);
    }
    void dropTemp() {
      if (post != null && temp != null) post.replies.removeWhere((x) => x.id == temp!.id);
    }
    replySendLoad.value = false;
    final response = await homeRepo.sendReply(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
      userId: sharedPreferences.getString(Constants.userId) ?? "0",
      message: message,
    );
    replySendLoad.value = true;
    final code = response.statusCode ?? 0;
    try {
      final res = jsonDecode(response.bodyString ?? "");
      if (code >= 200 && code < 300 && res["status"] == "1") {
        final r = res["data"]?["reply"];
        if (r is Map<String, dynamic> && post != null) {
          final reply = Reply.fromJson(r);
          final i = temp == null ? -1 : post.replies.indexWhere((x) => x.id == temp!.id);
          if (post.replies.any((x) => x.id == reply.id)) {
            dropTemp(); // the live update already added it
          } else if (i >= 0) {
            post.replies[i] = reply;
          } else {
            post.replies.add(reply);
          }
        } else {
          dropTemp();
        }
        return true;
      }
      dropTemp();
      CustomToast.failToast(msg: res["message"] ?? "Couldn't send. Try again.");
    } catch (_) {
      dropTemp();
      CustomToast.failToast(msg: "Couldn't send. Try again.");
    }
    return false;
  }

  /// Deletes a post. Returns true on success.
  Future<bool> deletePostNow(int postId) async {
    final response = await homeRepo.deletePost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
    );
    try {
      final res = response.body is Map ? response.body : jsonDecode(response.bodyString ?? "");
      if (response.statusCode == 200 && res["status"] == "1") {
        postsList.removeWhere((p) => p.id == postId);
        return true;
      }
      CustomToast.failToast(msg: res["message"] ?? "Couldn't delete. Try again.");
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't delete. Try again.");
    }
    return false;
  }

  /// Edits own post: new text, a new photo, or remove the photo.
  Future<bool> editPost({
    required int postId,
    required String text,
    File? newImage,
    bool removeImage = false,
  }) async {
    createPostLoad.value = false;
    final response = await homeRepo.editPost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
      text: text,
      file: newImage,
      removeImage: removeImage,
    );
    createPostLoad.value = true;
    try {
      final res = jsonDecode(response.bodyString ?? "");
      if ((response.statusCode ?? 0) < 300 && res["status"] == "1") {
        final j = res["data"]?["post"];
        if (j is Map<String, dynamic>) {
          final updated = Post.fromJson(j);
          final i = postsList.indexWhere((p) => p.id == postId);
          if (!updated.approved) {
            postsList.removeWhere((p) => p.id == postId);
          } else if (i >= 0) {
            postsList[i] = updated;
          }
          postsList.refresh();
        }
        CustomToast.successToast(msg: res["message"] ?? "Post updated");
        return true;
      }
      CustomToast.failToast(msg: res["message"] ?? "Couldn't update. Try again.");
    } catch (_) {
      CustomToast.failToast(msg: "Couldn't update. Try again.");
    }
    return false;
  }

  /// Upload image locally
  uploadImage(File file) {
    postImageFile = file;
    update();
  }

  @override
  void onInit() {
    super.onInit();
  }
}
