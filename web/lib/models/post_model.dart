import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String? id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final String imageUrl;
  final DateTime timestamp;
  final int likeCount;
  final int commentCount;

  Post({
    this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.timestamp,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(), // Use server timestamp on write
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map, String id) {
    return Post(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Unknown',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
    );
  }
}
