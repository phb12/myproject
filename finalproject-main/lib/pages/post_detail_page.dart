
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart'; // 【新增】

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostDetailPage({super.key, required this.postData});

  @override
  Widget build(BuildContext context) {
    final String title = postData['title'] ?? '無標題';
    final String content = postData['content'] ?? '';
    final String authorName = postData['authorName'] ?? '未知作者';
    final String? imageBase64 = postData['imageUrl'];
    final Timestamp? timestamp = postData['timestamp'];
    
    String dateStr = '';
    if (timestamp != null) {
      dateStr = DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate());
    }

    return Scaffold(
      backgroundColor: Colors.black, // Dark mode background
      appBar: AppBar(
        title: const Text('貼文詳情'),
        backgroundColor: Colors.black,
        actions: [
          if (FirestoreService.instance.getCurrentUserUid() == postData['authorId'])
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1E),
                    title: const Text('刪除貼文', style: TextStyle(color: Colors.white)),
                    content: const Text('確定要刪除這篇貼文嗎？此動作無法復原。', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      TextButton(
                        child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
                        onPressed: () async {
                          Navigator.pop(ctx); 
                          if (postData['postId'] != null) {
                            await FirestoreService.instance.deletePost(postData['postId']);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  FutureBuilder<String?>(
                    future: FirestoreService.instance.getUserAvatar(postData['authorId']),
                    builder: (context, snapshot) {
                      final avatarBase64 = snapshot.data;
                      return CircleAvatar(
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                            ? MemoryImage(base64Decode(avatarBase64))
                            : null,
                        child: (avatarBase64 == null || avatarBase64.isEmpty)
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Image
            if (imageBase64 != null && imageBase64.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 500),
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
