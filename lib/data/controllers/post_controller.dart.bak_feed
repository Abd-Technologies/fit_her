import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
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
  getAllPosts({bool approved = true}) {
    allPostsLoad.value = false;
    homeRepo
        .getAllPosts(
      approved: approved,
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
    )
        .then((response) {
      if (response.statusCode == 200) {
        ApiResponse<PostList> model = ApiResponse.fromJson(response.body, PostList.fromJson);
        postsList.value = List<Post>.from(model.data!.posts.map((x) => Post.fromJson(x.toJson())));
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
  likePost(int postId) {
    likeLoad.value = false;
    homeRepo
        .likePost(
      accessToken: sharedPreferences.getString(Constants.accessToken) ?? "",
      postId: postId,
      userId: sharedPreferences.getString(Constants.userId) ?? "0",
    )
        .then((response) {
      if (response.statusCode == 200) {
        var data = jsonDecode(response.bodyString ?? "");
        if (data["status"] == "1") {
          // Update locally
          final post = postsList.firstWhereOrNull((p) => p.id == postId);
          if (post != null) {
            if ("Like removed" == data["message"]) {
              post.isLiked.value = false;
            } else {
              post.isLiked.value = true;
              postsList.refresh();
            }
            //  post.likesCount = data["data"]["likesCount"];
          }
        } else {
          CustomToast.failToast(msg: data["message"]);
        }
        likeLoad.value = true;
      } else {
        CustomToast.failToast(msg: "Something went wrong");
      }
    });
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
