import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/models/api_response/api_response_model.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:get/get.dart';

/// Author details read straight from the raw "User" json, null safe.
/// Used by the FitHer Feed (role chip, photo) without depending on
/// ClientUser's required fields.
class FeedAuthor {
  final int? id;
  final String name;
  final String? userType;
  final String? image;
  const FeedAuthor({this.id, required this.name, this.userType, this.image});

  static FeedAuthor fromJson(dynamic u) {
    if (u is! Map) return const FeedAuthor(name: 'Member');
    final first = (u['firstName'] ?? '').toString().trim();
    final last = (u['lastName'] ?? '').toString().trim();
    final full = [first, last].where((e) => e.isNotEmpty).join(' ');
    final img = u['image']?.toString();
    return FeedAuthor(
      id: u['id'] is int ? u['id'] as int : int.tryParse('${u['id']}'),
      name: full.isEmpty ? 'Member' : full,
      userType: u['userType']?.toString(),
      image: (img == null || img.isEmpty || img == 'null') ? null : img,
    );
  }

  /// Staff (trainers, dietitians, doctors, admin) show a green avatar tick
  /// and their role; everyone else is a Member.
  bool get isStaff => userType != null && userType != 'User';

  String get roleLabel {
    switch (userType) {
      case 'Trainer':
        return 'Trainer';
      case 'Dietition':
        return 'Dietitian';
      case 'Gynecologist':
        return 'Gynaecologist';
      case 'Psychiatrist':
        return 'Psychiatrist';
      case 'Admin':
        return 'FitHer team';
      default:
        return 'Member';
    }
  }

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

/// Reply Model (for WhatsApp-like chat replies)
class Reply {
  final int id;
  final int postId;
  final int userId;
  final String message;
  final int? replyToId;
  final DateTime createdAt;
  final ClientUser? user;
  final FeedAuthor author;

  Reply({
    required this.id,
    required this.postId,
    required this.userId,
    required this.message,
    this.replyToId,
    required this.createdAt,
    this.user,
    this.author = const FeedAuthor(name: 'Member'),
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'],
      postId: json['postId'],
      userId: json['userId'],
      message: json['text'] ?? '',
      replyToId: json['replyToId'],
      createdAt: DateTime.parse(json['createdAt']),
      user: _safeUser(json['User']),
      author: FeedAuthor.fromJson(json['User']),
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
  final FeedAuthor author;

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
    this.author = const FeedAuthor(name: 'Member'),
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
      user: _safeUser(json['User']),
      author: FeedAuthor.fromJson(json['User']),
      likesCount: RxInt(json['likeCount'] ??
          (json['likes'] is List ? (json['likes'] as List).length : 0)),
      // The server sends the list of userIds who liked; work out whether
      // this user is one of them.
      isLiked: RxBool(json['isLiked'] ??
          (json['likes'] is List &&
              (json['likes'] as List).any((l) =>
                  l is Map &&
                  '${l['userId']}' ==
                      '${Get.find<AuthController>().logInUser?.id}'))),
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

/// ClientUser.fromJson needs every field; never let one missing field
/// break the whole feed.
ClientUser? _safeUser(dynamic u) {
  if (u is! Map<String, dynamic>) return null;
  try {
    return ClientUser.fromJson({
      ...u,
      'firstName': u['firstName'] ?? '',
      'lastName': u['lastName'] ?? '',
      'email': u['email'] ?? '',
    });
  } catch (_) {
    return null;
  }
}
