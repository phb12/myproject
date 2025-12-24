import 'package:flutter/material.dart';

import 'dart:convert';
import 'services/firestore_service.dart';
import 'edit_profile_page.dart';

import 'post_detail_page.dart';
import 'package:collection/collection.dart';
import 'training_schedule_page.dart';

// 定義關係狀態的類型
enum RelationshipStatus {
  self,
  friend,
  requestSent, // 我發送給對方
  requestReceived, // 對方發送給我
  stranger,
  loading,
  error,
}

class ProfilePage extends StatefulWidget {
  final String username;
  final String currentUser;
  final String avatarUrl;
  const ProfilePage({
    super.key,
    required this.username,
    required this.currentUser,
    this.avatarUrl = "https://i.pravatar.cc/150?u=retro_profile",
  });
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int? weekCount;
  String? createdAt;
  DateTime? registerDate;
  String displayName = "";
  String avatarUrl = "";
  Map<DateTime, List<Map<String, dynamic>>> postsByDay = {};

  // 🚨 新增：身高體重狀態
  double height = 0.0; // cm
  double weight = 0.0; // kg
  int friendCount = 0; // 🚨 新增：好友數量

  // 🎯 新增的關係狀態變數
  RelationshipStatus relationStatus = RelationshipStatus.loading;
  String? friendRequestId; // 🚨 修改為 String? 以適應 Firestore ID

  @override
  void initState() {
    super.initState();
    avatarUrl = widget.avatarUrl;
    fetchProfile();
    checkRelation();
  }

  // 🚨 新增輔助函數：計算 BMI
  String _calculateBmi() {
    if (height <= 0 || weight <= 0) {
      return 'N/A';
    }
    // BMI = 體重 (kg) / [身高 (m)]^2
    final heightInMeters = height / 100.0;
    final bmi = weight / (heightInMeters * heightInMeters);
    return bmi.toStringAsFixed(1);
  }

  // --- API 呼叫：個人資料與貼文 ---

  Future<void> fetchProfile() async {
    try {
      final data = await FirestoreService.instance.getUserDataByUid(widget.username);
      
      if (!mounted) return;

      if (data != null) {
        createdAt = data['created_at'];
        displayName = data['display_name'] ?? data['nickname'] ?? widget.username;
        avatarUrl = data['avatar_url'] ?? widget.avatarUrl;

        // 🚨 獲取身高體重數據
        height = (data['height'] as num?)?.toDouble() ?? 0.0;
        weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        
        // 🚨 獲取好友數量
        friendCount = await FirestoreService.instance.getFriendCount(widget.username);

        if (createdAt != null) {
          final registered = DateTime.tryParse(createdAt!) ?? DateTime.now();
          setState(() {
            weekCount = ((DateTime.now().difference(registered).inDays) / 7)
                .ceil()
                .clamp(1, 999);
            registerDate = registered;
          });
          await _fetchPostsBatch();
        } else {
          setState(() => registerDate = null);
        }
      }
    } catch (_) {
      if (mounted) setState(() => weekCount = null);
    }
  }

  Future<void> _fetchPostsBatch() async {
    if (registerDate == null) return;

    // 使用 FirestoreService 獲取貼文
    // 這裡我們獲取該用戶的所有貼文，然後在前端進行日期分組
    // 如果資料量大，應該在 Service 實作分頁或日期範圍查詢
    final snapshot = await FirestoreService.instance.getUserPostsStream(widget.username).first;
    
    if (!mounted) return;

    final posts = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      // 轉換 timestamp 為 date 字串 (YYYY-MM-DD) 以符合 UI 邏輯
      if (data['timestamp'] != null) {
        final ts = (data['timestamp'] as dynamic).toDate();
        data['date'] = "${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}";
      }
      // 確保 image_url 欄位存在 (Model 使用 imageUrl)
      if (data['imageUrl'] != null) {
        data['image_url'] = data['imageUrl'];
      }
      // 確保 caption 欄位存在
      if (data['content'] != null) {
        data['caption'] = data['content'];
      }
      return data;
    }).toList();

    Map<DateTime, List<Map<String, dynamic>>> map = {};
    for (final post in posts) {
      if (post['date'] != null) {
        final date = DateTime.parse(post['date']);
        map.putIfAbsent(date, () => []);
        map[date]!.add(post);
      }
    }
    setState(() => postsByDay = map);
  }

  // --- API 呼叫：關係檢查 (核心優化) ---

  Future<void> checkRelation() async {
    setState(() {
      relationStatus = RelationshipStatus.loading;
      friendRequestId = null;
    });

    final result = await FirestoreService.instance.getRelationshipStatus(widget.currentUser, widget.username);

    if (!mounted) return;

    final statusString = result['status'] as String;
    RelationshipStatus newStatus;
    if (statusString == 'self') {
      newStatus = RelationshipStatus.self;
    } else if (statusString == 'friend') {
      newStatus = RelationshipStatus.friend;
    } else if (statusString == 'request_sent') {
      newStatus = RelationshipStatus.requestSent;
    } else if (statusString == 'request_received') {
      newStatus = RelationshipStatus.requestReceived;
      friendRequestId = result['request_id'] as String?; 
      // 注意：Firestore ID 是字串，但這裡 friendRequestId 定義為 int?
      // 我們需要修改 friendRequestId 的型別，或者暫時不存 ID (如果是字串)
      // 由於 dealFriendRequest 需要 ID，我們應該將 friendRequestId 改為 String?
      // 但為了最小化變更，我們暫時假設 ID 可以 parse (如果 legacy 是 int)，但 Firestore ID 是字串。
      // **CRITICAL**: 必須修改 friendRequestId 為 String?。
      // 這裡先不改定義，而是將其轉為 null，因為 dealFriendRequest 需要 ID。
      // 我們稍後會修改 friendRequestId 的定義。
    } else {
      newStatus = RelationshipStatus.stranger;
    }

    setState(() {
      relationStatus = newStatus;
    });
  }

  // --- API 呼叫：社交動作 (保持不變) ---

  Future<void> sendFriendRequest() async {
    if (relationStatus != RelationshipStatus.stranger) return;
    setState(() => relationStatus = RelationshipStatus.loading);

    await FirestoreService.instance.sendFriendRequest(widget.currentUser, widget.username);

    if (!mounted) return;
    setState(() {
      relationStatus = RelationshipStatus.requestSent;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已發送好友申請，等待對方審核')));
  }

  Future<void> dealFriendRequest(String action) async {
    // 注意：這裡我們假設 friendRequestId 已經被正確設置 (雖然型別可能是 int，但我們需要 String)
    // 由於我們無法輕易更改 friendRequestId 的型別 (定義在 State 中)，
    // 我們需要確保 checkRelation 中獲取的 ID 能被處理。
    // 如果 Firestore ID 是字串，我們需要修改 friendRequestId 定義。
    // 為了避免編譯錯誤，我們這裡先假設 friendRequestId 是 int (舊代碼)，但我們需要它是 String。
    // 解決方案：我們將在下面修改 friendRequestId 的定義。
    if (relationStatus != RelationshipStatus.requestReceived ||
        friendRequestId == null) {
      return;
    }
    setState(() => relationStatus = RelationshipStatus.loading);

    final int status = action == 'accept' ? 1 : 2;
    await FirestoreService.instance.dealFriendRequest(friendRequestId!, status);

    if (!mounted) return;

    if (action == 'accept') {
      setState(() => relationStatus = RelationshipStatus.friend);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已接受 $displayName 的好友請求')));
      fetchProfile();
    } else {
      setState(() => relationStatus = RelationshipStatus.stranger);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已拒絕好友請求')));
    }
  }

  Future<void> _deletePost(DateTime date, Map post) async {
    final postId = post['id'];
    if (postId != null) {
      await FirestoreService.instance.deletePost(postId.toString());
      if (!mounted) return;
      await _fetchPostsBatch();
    }
  }

  // 修正：編輯後回傳值，需在編輯頁面處理身高體重
  Future<void> _createPostFlow() async {
    if (relationStatus != RelationshipStatus.self) return;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: registerDate ?? DateTime.now(),
      lastDate: DateTime.now(),
      helpText: "選擇發文日期",
      locale: const Locale("zh"),
    );
    if (selectedDate != null) {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PostEditPage(
            username: widget.username,
            initialDate: selectedDate, // 🚨 傳遞選中的日期
          ),
        ),
      );
      if (result != null && result == true) {
        // 🚨 如果發布成功 (result == true)，重新獲取貼文
        await _fetchPostsBatch();
      }
    }
  }

  Future<void> _showMonthlyReview() async {
    // 顯示載入中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      ),
    );

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthEnd = currentMonthStart.subtract(const Duration(days: 1));
    final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);

    final startStr =
        "${lastMonthStart.year}-${lastMonthStart.month.toString().padLeft(2, '0')}-${lastMonthStart.day.toString().padLeft(2, '0')}";
    final endStr =
        "${lastMonthEnd.year}-${lastMonthEnd.month.toString().padLeft(2, '0')}-${lastMonthEnd.day.toString().padLeft(2, '0')}";

    // 1. 計算貼文數據
    final normalizedLastMonthStart = DateTime(
      lastMonthStart.year,
      lastMonthStart.month,
      lastMonthStart.day,
    );
    final normalizedLastMonthEnd = DateTime(
      lastMonthEnd.year,
      lastMonthEnd.month,
      lastMonthEnd.day,
    );

    final postsLastMonth = postsByDay.entries
        .where((entry) {
          final date = entry.key;
          return date.isAfter(
                normalizedLastMonthStart.subtract(const Duration(days: 1)),
              ) &&
              date.isBefore(
                normalizedLastMonthEnd.add(const Duration(days: 1)),
              );
        })
        .map((entry) => entry.value)
        .expand((posts) => posts)
        .toList();

    final totalPosts = postsLastMonth.length;
    final postsWithImage = postsLastMonth
        .where((post) => (post['image_url']?.isNotEmpty ?? false))
        .length;

    // 2. 獲取訓練數據
    int trainingDays = 0;
    int totalDurationMinutes = 0;
    try {
      final stats = await FirestoreService.instance.getUserStats(widget.username, lastMonthStart, lastMonthEnd);
      trainingDays = stats['total_days'] ?? 0;
      totalDurationMinutes = stats['total_duration_minutes'] ?? 0;
    } catch (e) {
      // print("Error fetching monthly stats: $e");
    }

    if (!mounted) return;
    Navigator.pop(context); // 關閉載入視窗

    // 3. 構建回顧內容
    String reviewTitle = "${lastMonthStart.month}月回顧 📅";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          reviewTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 貼文統計
            _buildReviewItem(
              icon: Icons.article,
              color: Colors.blueAccent,
              label: "發布貼文",
              value: "$totalPosts 篇",
              subValue: "($postsWithImage 篇含圖片)",
            ),
            const SizedBox(height: 16),
            // 訓練天數
            _buildReviewItem(
              icon: Icons.calendar_today,
              color: Colors.greenAccent,
              label: "訓練天數",
              value: "$trainingDays 天",
            ),
            const SizedBox(height: 16),
            // 訓練時長
            _buildReviewItem(
              icon: Icons.timer,
              color: Colors.orangeAccent,
              label: "總訓練時長",
              value: "${(totalDurationMinutes / 60).toStringAsFixed(1)} 小時",
              subValue: "($totalDurationMinutes 分鐘)",
            ),
            const SizedBox(height: 24),
            const Text(
              "繼續保持這個節奏！🚀",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "太棒了",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? subValue,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subValue != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      subValue,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _twDate(DateTime d) => "${d.month}月${d.day}日";

  // 🚨 新增：顯示貼文詳情 (PageView)
  void _showPostDetails(List<Map<String, dynamic>> posts, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允許全螢幕
      enableDrag: false, // 🚨 禁用垂直拖曳以避免與 PageView 衝突
      backgroundColor: Colors.black,
      builder: (ctx) {
        // 🚨 使用 StatefulBuilder 來管理 PageController 和按鈕狀態
        return StatefulBuilder(
          builder: (context, setModalState) {
            final PageController pageController = PageController(
              viewportFraction: 0.9,
            );

            return SafeArea(
              child: Column(
                children: [
                  // 頂部導航欄
                  AppBar(
                    backgroundColor: Colors.black,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    title: Text(
                      "${_twDate(date)} (${posts.length} 則)",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  // 貼文內容 (PageView + Arrows)
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PageView.builder(
                          itemCount: posts.length,
                          controller: pageController,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  // 圖片區域
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.black,
                                        child:
                                            (post['image_url'] ?? '').isNotEmpty
                                            ? Image.network(
                                                post['image_url'],
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (context, err, stack) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons.broken_image,
                                                            color:
                                                                Colors.white24,
                                                            size: 50,
                                                          ),
                                                        ),
                                              )
                                            : const Center(
                                                child: Text(
                                                  "無圖片",
                                                  style: TextStyle(
                                                    color: Colors.white38,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  // 底部：文字與操作
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "第 ${index + 1}/${posts.length} 則",
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          post['caption'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        if (relationStatus ==
                                            RelationshipStatus.self)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text(
                                                          "刪除貼文",
                                                        ),
                                                        content: const Text(
                                                          "確定要刪除這篇貼文嗎？",
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              "取消",
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              "刪除",
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                if (confirm == true) {
                                                  await _deletePost(date, post);
                                                  if (!context.mounted) return;
                                                  Navigator.pop(ctx); // 關閉詳情頁
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                              label: const Text(
                                                "刪除",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // 🚨 左箭頭 (上一頁)
                        Positioned(
                          left: 10,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            onPressed: () {
                              pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                        // 🚨 右箭頭 (下一頁)
                        Positioned(
                          right: 10,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20), // 底部留白
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _weekGrid(String weekTitle, List<DateTime> dayDates) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          weekTitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 6),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: dayDates.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final date = dayDates[index];
          final hasPosts = postsByDay[date]?.isNotEmpty ?? false;

          final postWithImage = postsByDay[date]?.firstWhereOrNull(
            (post) => (post['image_url'] ?? '').isNotEmpty,
          );

          Widget content;
          if (postWithImage != null) {
            content = Image.network(
              postWithImage['image_url'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, err, stack) => const Icon(
                Icons.photo_size_select_actual,
                color: Colors.white30,
                size: 28,
              ),
            );
          } else if (hasPosts) {
            content = const Icon(
              Icons.check_circle,
              color: Colors.cyanAccent,
              size: 28,
            );
          } else {
            content = Icon(
              Icons.circle_outlined,
              color: Colors.white.withValues(alpha: 0.1),
              size: 28,
            );
          }

          return InkWell(
            onTap: hasPosts
                ? () => _showPostDetails(postsByDay[date]!, date)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: hasPosts
                    ? Colors.cyanAccent.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPosts
                      ? Colors.cyanAccent.withValues(alpha: 0.3)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: content,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    child: Text(
                      "${date.day}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            offset: const Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: Text(
                      "週${'一二三四五六日'[date.weekday - 1]}",
                      style: TextStyle(
                        color: hasPosts ? Colors.yellowAccent : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            offset: const Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
    ],
  );

  List<Widget> _weekSectionsByRegister(DateTime registerDate) {
    final now = DateTime.now();
    final weeks = <Widget>[];
    var startOfWeek = registerDate.subtract(
      Duration(days: registerDate.weekday - 1),
    );
    int weekIndex = 1;
    while (startOfWeek.isBefore(now)) {
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final weekEnd = endOfWeek.isAfter(now) ? now : endOfWeek;

      final currentDayDates = List.generate(7, (i) {
        final d = startOfWeek.add(Duration(days: i));
        return d.isAfter(now.add(const Duration(days: 1))) ? null : d;
      }).whereType<DateTime>().toList();

      if (currentDayDates.isNotEmpty) {
        weeks.add(
          _weekGrid(
            "第 $weekIndex 週 (${_twDate(startOfWeek)} ~ ${_twDate(weekEnd)})",
            currentDayDates,
          ),
        );
        weeks.add(const SizedBox(height: 24));
      }

      startOfWeek = endOfWeek.add(const Duration(days: 1));
      weekIndex++;
    }
    return weeks.reversed.toList();
  }

  // --- 頁面建構：非好友拒絕/加好友頁面 (重構) ---

  Widget _friendDeniedView() {
    // 根據關係狀態顯示不同的按鈕
    Widget actionButton;
    String statusText;

    switch (relationStatus) {
      case RelationshipStatus.loading:
      case RelationshipStatus.error:
        actionButton = const CircularProgressIndicator(color: Colors.white);
        statusText = "正在檢查關係...";
        break;
      case RelationshipStatus.requestSent:
        actionButton = OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey, width: 2),
            foregroundColor: Colors.grey,
            shape: const StadiumBorder(),
            minimumSize: const Size(220, 53),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          child: const Text("已申請，等待對方確認"),
        );
        statusText = "已發送申請";
        break;
      case RelationshipStatus.requestReceived:
        actionButton = Column(
          children: [
            ElevatedButton(
              onPressed: () => dealFriendRequest('accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
                minimumSize: const Size(220, 53),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              child: const Text("接受好友請求"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => dealFriendRequest('reject'),
              child: const Text(
                "拒絕請求",
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          ],
        );
        statusText = "您有新的請求";
        break;
      case RelationshipStatus.stranger:
      default:
        actionButton = OutlinedButton(
          onPressed: sendFriendRequest,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.black,
            side: const BorderSide(color: Colors.white, width: 2),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            minimumSize: const Size(220, 53),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          child: const Text("添加朋友"),
        );
        statusText = "僅限朋友";
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.username,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(avatarUrl),
              onBackgroundImageError: (e, s) {},
            ),
            const SizedBox(height: 28),
            const Icon(Icons.group, color: Colors.white, size: 52),
            const SizedBox(height: 18),
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "只有 $displayName 的朋友可以看到他們的貼文。",
              style: const TextStyle(fontSize: 17, color: Colors.white54),
            ),
            const SizedBox(height: 31),
            actionButton,
          ],
        ),
      ),
    );
  }

  // 🚨 重構：緊湊型身體數據列
  Widget _buildHealthStatsRow() {
    final bmi = _calculateBmi();
    // 判斷 BMI 狀態顏色
    Color bmiColor = Colors.grey;
    if (double.tryParse(bmi) != null) {
      final v = double.parse(bmi);
      if (v < 18.5) {
        bmiColor = Colors.orangeAccent;
      } else if (v < 24) {
        bmiColor = Colors.greenAccent;
      } else if (v < 27) {
        bmiColor = Colors.yellowAccent;
      } else {
        bmiColor = Colors.redAccent;
      }
    }

    if (height <= 0 &&
        weight <= 0 &&
        relationStatus != RelationshipStatus.self) {
      return const SizedBox.shrink();
    }

    Widget statItem(String label, String value, Color color) {
      return Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          statItem("身高", "${height.toStringAsFixed(0)} cm", Colors.white),
          Container(width: 1, height: 30, color: Colors.white24),
          statItem("體重", "$weight kg", Colors.white),
          Container(width: 1, height: 30, color: Colors.white24),
          statItem("BMI", bmi, bmiColor),
        ],
      ),
    );
  }

  // 🚨 新增：個人資料頭部 (Instagram 風格)
  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 頭像
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(avatarUrl),
              onBackgroundImageError: (e, s) {},
            ),
            const SizedBox(width: 20),
            // 數據統計
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn("週數", "${weekCount ?? '-'}"),
                  _buildStatColumn(
                    "貼文",
                    "${postsByDay.values.fold(0, (p, c) => p + c.length)}",
                  ),
                  _buildStatColumn("好友", "$friendCount"),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 顯示名稱
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (registerDate != null)
          Text(
            "加入於 ${_twDate(registerDate!)}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 16),
        // 編輯/追蹤按鈕
        if (relationStatus == RelationshipStatus.self)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfilePage(
                      username: widget.username,
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      initialHeight: height,
                      initialWeight: weight,
                    ),
                  ),
                );
                if (result == true) {
                  fetchProfile();
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundColor: Colors.white,
              ),
              child: const Text("編輯個人檔案"),
            ),
          ),
        if (relationStatus == RelationshipStatus.friend)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // 🚨 導航到課表頁面 (唯讀模式)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainingSchedulePage(
                      username: widget.username,
                      currentUser: widget.currentUser, // 🚨 傳遞當前用戶
                      canEdit: false, // 設定為不可編輯
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.cyanAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundColor: Colors.cyanAccent,
              ),
              child: const Text("查看課表"),
            ),
          ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  // --- 主頁面建構 (根據關係狀態決定渲染) ---

  @override
  Widget build(BuildContext context) {
    if (relationStatus == RelationshipStatus.loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    if (relationStatus != RelationshipStatus.self &&
        relationStatus != RelationshipStatus.friend) {
      return _friendDeniedView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          displayName.isNotEmpty ? displayName : widget.username,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (relationStatus == RelationshipStatus.self)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _showMonthlyReview,
              tooltip: "月度回顧",
            ),
        ],
      ),
      // 🚨 新增：懸浮按鈕 (FAB) 用於發文
      floatingActionButton: relationStatus == RelationshipStatus.self
          ? FloatingActionButton(
              onPressed: _createPostFlow,
              backgroundColor: Colors.cyanAccent,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchProfile();
          await checkRelation();
        },
        color: Colors.cyanAccent,
        backgroundColor: Colors.grey[900],
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 個人資料頭部
              _buildProfileHeader(),
              const SizedBox(height: 20),

              // 2. 身體數據 (緊湊版)
              _buildHealthStatsRow(),
              const SizedBox(height: 10),

              // 3. 貼文列表 (按週分組)
              if (registerDate != null)
                ..._weekSectionsByRegister(registerDate!)
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),
                ),

              // 底部留白，避免被 FAB 遮擋
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
