import 'dart:convert';

import 'services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'side_nav.dart';
import 'dashboard_page.dart';
import 'training_record_page.dart';
import 'training_schedule_page.dart';
import 'web_pose_page.dart';
import 'profile_page.dart' as import_profile;

class MainPage extends StatefulWidget {
  final String username;
  const MainPage({super.key, required this.username});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  String? lastCheckDate;
  String avatarUrl = "https://i.pravatar.cc/100?u=default"; // 🚨 預設頭像
  int friendRequestCount = 0; // 🚨 好友申請計數

  int unreadCount = 0; // 🚨 未讀通知計數

  // 0: 儀表板, 1: 課表, 2: 探索(SearchUserPage), 3: 運動紀錄
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    avatarUrl = "https://i.pravatar.cc/100?u=${widget.username}"; // 初始化
    _fetchUserProfile(); // 🚨 獲取最新頭像
    _fetchFriendRequests(); // 🚨 獲取好友申請數量
    _fetchUnreadNotifications(); // 🚨 獲取未讀通知數量
    pages = [
      DashboardPage(username: widget.username),
      TrainingSchedulePage(username: widget.username),
      const Center(
        child: Text("透過側邊欄搜尋按鈕進入 '探索頁'", style: TextStyle(color: Colors.white)),
      ),
      TrainingRecordPage(username: widget.username),
      const WebPosePage(),
    ];
    _checkTodayTrainingAndRemind();
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final count = await FirestoreService.instance.getUnreadNotificationCount(widget.username);
      if (mounted) {
        setState(() {
          unreadCount = count;
        });
      }
    } catch (e) {
      // print("Error fetching unread notifications: $e");
    }
  }

  Future<void> _fetchFriendRequests() async {
    try {
      final requests = await FirestoreService.instance.getFriendRequests(widget.username);
      if (mounted) {
        setState(() {
          friendRequestCount = requests.length;
        });
      }
    } catch (e) {
      // print("Error fetching friend requests: $e");
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final data = await FirestoreService.instance.getUserDataByUid(widget.username);
      if (mounted && data != null) {
        setState(() {
          final url = data['avatar_url'] ?? avatarUrl;
          avatarUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";
        });
      }
    } catch (e) {
      // print("Error fetching profile: $e");
    }
  }

  void onNavTap(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _checkTodayTrainingAndRemind() async {
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    if (lastCheckDate == todayStr) return;
    lastCheckDate = todayStr;

    try {
      final hasTraining = await FirestoreService.instance.checkTodayTraining(widget.username);
      if (!hasTraining) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                '每日打卡提醒',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                '你今天還沒運動打卡，記得訓練！',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    '知道了',
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      // print("Error checking training: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = pages[selectedIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          SideNav(
            avatarUrl: avatarUrl, // 🚨 使用狀態變數
            onTap: onNavTap,
            selectedIndex: selectedIndex,
            username: widget.username,
            unreadCount: unreadCount, // 🚨 傳遞未讀通知計數
            friendRequestCount: friendRequestCount, // 🚨 傳遞好友申請計數
            onProfileTap: () async {
              // 🚨 處理個人頁面導航與頭像更新
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => import_profile.ProfilePage(
                    username: widget.username,
                    currentUser: widget.username,
                    avatarUrl: avatarUrl,
                  ),
                ),
              );
              // 返回後重新獲取頭像
              _fetchUserProfile();
            },
            onNotificationClosed: () {
              // 🚨 通知頁面關閉後刷新未讀計數
              _fetchUnreadNotifications();
            },
            onFriendListClosed: () {
              // 🚨 好友頁面關閉後刷新好友申請計數
              _fetchFriendRequests();
            },
          ),
          Expanded(child: currentPage),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------
// 🚨 修正類別名稱：TrainingScheduleProgressCardState
// ----------------------------------------------------------------------------------

class TrainingScheduleProgressCard extends StatefulWidget {
  final String username;
  final VoidCallback onEditCallback;

  const TrainingScheduleProgressCard({
    required this.username,
    required this.onEditCallback,
    super.key,
  });

  @override
  State<TrainingScheduleProgressCard> createState() =>
      TrainingScheduleProgressCardState();
}

class TrainingScheduleProgressCardState
    extends State<TrainingScheduleProgressCard> {
  // 結構：[{'id': 'action_name', 'name': '胸-臥推', 'sets': '3', 'is_completed': false}, ...]
  List<Map<String, dynamic>> _dailySchedule = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDailySchedule();
  }

  // 公開方法供 DashboardPage 調用
  void reloadSchedule() {
    _fetchDailySchedule();
  }

  // 💡 修正邏輯：直接從模板 API 獲取當天的排程，並與完成狀態合併。
  Future<void> _fetchDailySchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 1. 獲取模板排程 (七天)
      final templateData = await FirestoreService.instance.getTrainingTemplate(widget.username);

      // 2. 獲取當日完成狀態
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final completedIds = await FirestoreService.instance.getDailyCompletion(widget.username, todayStr);

      // --- 數據處理 ---
      List rawSchedule = [];
      if (templateData['schedule'] is List) {
        rawSchedule = templateData['schedule'];
      }
      final completedItems = completedIds.toSet();

      final todayIndex = (DateTime.now().weekday - 1) % 7;
      List<Map<String, dynamic>> todayPlans = [];

      if (rawSchedule.length > todayIndex) {
        final List plans = rawSchedule[todayIndex]['plans'] ?? [];

        todayPlans = plans.whereType<Map<String, dynamic>>().map((plan) {
          final actionName = plan['action'] as String? ?? '未知動作';

          // 每個課表項目必須有唯一的 ID，這裡使用 actionName 作為 ID
          final itemId = actionName;

          return {
            'id': itemId,
            'name': actionName,
            'sets': plan['sets'] as String? ?? '0',
            'is_completed': completedItems.contains(itemId),
          };
        }).toList();
      }

      setState(() {
        _dailySchedule = todayPlans;
      });

    } catch (e) {
      // 網路錯誤或 API 不存在
      setState(() {
        _error = '網路錯誤或 API 連線失敗: $e';
        _dailySchedule = _getMockDailySchedule();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockDailySchedule() {
    // 💡 模擬數據 (與您的截圖匹配)
    return [
      {'id': '胸-臥推', 'name': '胸-臥推', 'sets': '3', 'is_completed': false},
      {'id': '肩-推舉', 'name': '肩-推舉', 'sets': '4', 'is_completed': true},
      {'id': '手臂-二頭彎舉', 'name': '手臂-二頭彎舉', 'sets': '3', 'is_completed': false},
    ];
  }

  Future<void> _updateCompletionStatus(
    String itemId,
    bool isCompleted,
    int index,
  ) async {
    if (_dailySchedule.isEmpty) return;

    final bool originalState = _dailySchedule[index]['is_completed'];
    setState(() {
      _dailySchedule[index]['is_completed'] = isCompleted;
    });

    try {
      // 🚨 呼叫 Firestore 更新完成狀態
      await FirestoreService.instance.setDailyCompletion(
        widget.username,
        DateTime.now().toIso8601String().substring(0, 10),
        itemId,
        isCompleted,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('網路錯誤: $e')));
      setState(() {
        _dailySchedule[index]['is_completed'] = originalState; // 回滾
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
        ),
      );
    }

    if (_error != null && _dailySchedule.isEmpty) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              '載入錯誤: $_error',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    final totalItems = _dailySchedule.length;
    final completedItems = _dailySchedule
        .where((item) => item['is_completed'])
        .length;

    if (_dailySchedule.isEmpty) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              '本日無訓練項目，請去「課表」頁面設置。',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日計畫: $completedItems/$totalItems',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: widget.onEditCallback,
                  child: const Text(
                    '編輯排程',
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white.withValues(alpha: 0.1)),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailySchedule.length,
              itemBuilder: (context, index) {
                final item = _dailySchedule[index];
                final itemId = item['id'] as String;
                final itemName = item['name'] as String;
                final sets = item['sets'] as String? ?? '-';
                final isCompleted = item['is_completed'] as bool;

                return InkWell(
                  onTap: () {
                    _updateCompletionStatus(itemId, !isCompleted, index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? Colors.cyanAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              itemName,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? Colors.white38
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$sets 組',
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.white38
                                : Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
