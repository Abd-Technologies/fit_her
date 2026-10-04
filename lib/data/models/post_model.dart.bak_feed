import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:get/get.dart';

/// Reply Model (for WhatsApp-like chat replies)
class Reply {
  final int id;
  final int postId;
  final int userId;
  final String message;
  final int? replyToId;
  final DateTime createdAt;
  final ClientUser? user;

  Reply({
    required this.id,
    required this.postId,
    required this.userId,
    required this.message,
    this.replyToId,
    required this.createdAt,
    this.user,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'],
      postId: json['postId'],
      userId: json['userId'],
      message: json['text'] ?? '',
      replyToId: json['replyToId'],
      createdAt: DateTime.parse(json['createdAt']),
      user: json['User'] == null ? null : ClientUser.fromJson(json['User']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'text': message,
      'replyToId': replyToId,
      'createdAt': createdAt.toIso8601String(),
      'User': user?.toJson(),
    };
  }
}

class Like {
  final int userId;
  Like({required this.userId});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(userId: json['userId']);
  }
}

/// Post Model
/// Post Model
class Post {
  final int id;
  final String? imageUrl;
  final String text;
  final bool isPost;
  final bool approved;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final ClientUser? user;
  final List<Like> likes;

  /// New reactive fields
  RxInt likesCount;
  RxBool isLiked;
  RxList<Reply> replies; // reactive list

  Post({
    required this.id,
    this.imageUrl,
    required this.text,
    required this.isPost,
    required this.approved,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.user,
    required this.likes,
    RxInt? likesCount,
    RxBool? isLiked,
    RxList<Reply>? replies,
  })  : likesCount = likesCount ?? 0.obs,
        isLiked = isLiked ?? false.obs,
        replies = replies ?? <Reply>[].obs; // RxList initialized

  factory Post.fromJson(Map<String, dynamic> json) {
    print('Post.fromJson');
    // Use only Post-level createdAt (never User.createdAt) for grouping/display
    final postCreatedAt = json['createdAt'] ?? json['created_at'];
    final postUpdatedAt = json['updatedAt'] ?? json['updated_at'];
    return Post(
      id: json['id'],
      imageUrl: json['imageUrl'],
      text: json['text'] ?? '',
      isPost: json['isPost'] ?? false,
      approved: json['approved'] ?? false,
      createdAt: postCreatedAt != null ? DateTime.parse(postCreatedAt.toString()) : DateTime.now(),
      updatedAt: postUpdatedAt != null ? DateTime.parse(postUpdatedAt.toString()) : DateTime.now(),
      userId: json['userId'].toString(),
      likes: json['likes'] == null ? [] : (json['likes'] as List).map((e) => Like.fromJson(e)).toList(),
      user: json['User'] == null ? null : ClientUser.fromJson(json['User']),
      likesCount: RxInt(json['likeCount'] ?? 0),
      isLiked: RxBool(json['isLiked'] ?? false),
      replies: json['messages'] == null
          ? <Reply>[].obs
          : (json['messages'] as List).map((e) => Reply.fromJson(e)).toList().obs, // convert List<Reply> to RxList<Reply>
    );
  }

  Map<String, dynamic> toJson() {
    print('Post.toJson ${replies.value.length}');
    return {
      'id': id,
      'imageUrl': imageUrl,
      'text': text,
      'isPost': isPost,
      'approved': approved,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'User': user?.toJson(),
      'likesCount': likesCount.value,
      'isLiked': likes.any((like) => like.userId == Get.find<AuthController>().logInUser?.id),
      'messages': replies.map((e) => e.toJson()).toList(),
    };
  }
}

/// Wrapper Model for API responses
class PostList extends Serializable {
  final List<Post> posts;

  PostList({required this.posts});

  factory PostList.fromJson(Map<String, dynamic> json) {
    return PostList(
      posts: (json['posts'] as List).map((e) => Post.fromJson(e)).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((e) => e.toJson()).toList(),
    };
  }
}
