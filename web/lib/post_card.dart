import 'package:flutter/material.dart';
import 'dart:convert';
import 'services/firestore_service.dart';
import 'package:flutter/services.dart';

class PostCard extends StatefulWidget {
  final String username;
  final String avatarUrl;
  final String? imageUrl;
  final String postId; // 🚨 Changed to String to match Firestore ID
  final String currentUser;
  final String caption;
  final List<Map<String, String>>? sections;

  const PostCard({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.caption,
    required this.postId,
    required this.currentUser,
    this.imageUrl,
    this.sections,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  int likeCount = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchLikeStatus();
  }

  Future<void> fetchLikeStatus() async {
    try {
      final data = await FirestoreService.instance.getPostLikeStatus(widget.postId, widget.currentUser);
      setState(() {
        likeCount = data['like_count'];
        isLiked = data['is_liked'];
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleLike() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final data = await FirestoreService.instance.toggleLikePost(widget.postId, widget.currentUser);
      setState(() {
        likeCount = data['like_count'];
        isLiked = data['status'] == "liked";
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void copyPostLink() async {
    // 定義分享連結格式 (使用 Post ID)
    final link = "Post ID: ${widget.postId}";
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('連結已複製：$link'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 【輔助方法】確保圖片 URL 帶有隨機參數，繞過舊快取
  String _getUniqueUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    // 添加一個隨機時間戳參數，防止瀏覽器或 Flutter 內部使用舊的破圖快取
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    // 預先處理圖片 URL (應用快取繞過)
    final displayImageUrl = _getUniqueUrl(widget.imageUrl);

    // 處理圖片載入失敗的 Widget
    final imageLoadErrorWidget = Center(
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          // 【診斷點】載入失敗時，我們在 Console 中尋找錯誤。
          child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用戶資訊頭
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundImage: NetworkImage(widget.avatarUrl),
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.more_horiz,
                      color: Colors.white30,
                      size: 23,
                    ),
                  ],
                ),

                // 多段故事格式 (保持不變)
                if (widget.sections != null && widget.sections!.isNotEmpty)
                  ...widget.sections!.asMap().entries.map((entry) {
                    final i = entry.key;
                    final sec = entry.value;
                    final sectionImageUrl = _getUniqueUrl(sec['imageUrl']);

                    return Container(
                      height: 86,
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        image: sectionImageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(sectionImageUrl),
                                fit: BoxFit.cover,
                                colorFilter: i == 1
                                    ? ColorFilter.mode(
                                        Colors.red.withValues(alpha: 0.35),
                                        BlendMode.multiply,
                                      )
                                    : ColorFilter.mode(
                                        Colors.black.withValues(alpha: 0.33),
                                        BlendMode.darken,
                                      ),
                              )
                            : null,
                        color: Colors.grey[850],
                      ),
                      child: Center(
                        child: Text(
                          sec['text'] ?? "",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 5, color: Colors.black),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),

                // 傳統單圖貼文情境
                if (displayImageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 6,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        displayImageUrl, // 使用帶有時間戳的 URL
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        // 【關鍵診斷點】
                        errorBuilder: (ctx, err, stack) {
                          // 診斷輸出，請檢查此訊息在 Console 中是否出現
                          // debugPrint('Image Load Failed for URL: $displayImageUrl Error: $err');
                          return imageLoadErrorWidget;
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 7),

                // Caption
                if (widget.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      widget.caption,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),

                // 按讚與分享
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 7, bottom: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: toggleLike,
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white54,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$likeCount 次讚",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // 複製連結按鈕（分享）
                      IconButton(
                        tooltip: "複製貼文連結",
                        icon: const Icon(Icons.link, color: Colors.white70),
                        onPressed: copyPostLink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
