import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'search_user_page.dart';
import 'notification_page.dart';
import 'friend_list_page.dart';
// 新增課表功能頁

class SideNav extends StatelessWidget {
  final String avatarUrl;
  final void Function(int) onTap;
  final int selectedIndex;
  final String username; // 當前帳號
  final int unreadCount;

  const SideNav({
    super.key,
    required this.avatarUrl,
    required this.onTap,
    required this.selectedIndex,
    required this.username,
    this.unreadCount = 0,
    this.friendRequestCount = 0, // 🚨 新增好友申請計數
    this.onProfileTap, // 🚨 新增回調
    this.onNotificationClosed, // 🚨 新增回調
    this.onFriendListClosed, // 🚨 新增回調
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationClosed; // 🚨 新增：通知頁面關閉後的回調
  final VoidCallback? onFriendListClosed; // 🚨 新增：好友頁面關閉後的回調
  final int friendRequestCount; // 🚨 新增變數

  @override
  Widget build(BuildContext context) {
    // 修正後的索引 (原 index 3: 社群 已移除)
    // index 0: 儀表板
    // index 1: 課表
    // index 2: 探索 (SearchUserPage)
    // index 3: 運動紀錄 (原 index 4)
    List<IconData> icons = [
      Icons.home, // 0: Dashboard
      Icons.calendar_today, // 1: 課表
      Icons.search, // 2: 探索 (SearchUserPage)
      Icons.fitness_center, // 3: 運動紀錄
      Icons.analytics, // 4: AI 分析
    ];

    List<String> tooltips = ["首頁", "課表", "搜尋", "運動紀錄", "AI 分析"];

    return Container(
      width: 64,
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 主功能選單
          for (int i = 0; i < icons.length; i++)
            IconButton(
              icon: Icon(
                icons[i],
                color: i == selectedIndex ? Colors.blueAccent : Colors.white,
              ),
              tooltip: tooltips[i],
              onPressed: () {
                // 索引 2 對應到 '搜尋' (SearchUserPage)
                if (i == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchUserPage(currentUser: username),
                    ),
                  );
                } else {
                  // 導航到 Dashboard(0), 課表(1), 運動紀錄(3)
                  onTap(i);
                }
              },
            ),
          // 好友管理
          // 好友管理
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: "好友管理",
                color: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendListPage(currentUser: username),
                    ),
                  );
                  // 🚨 返回後觸發回調以刷新計數
                  onFriendListClosed?.call();
                },
              ),
              if (friendRequestCount > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$friendRequestCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // 通知鈴鐺
          // 通知鈴鐺
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: unreadCount > 0 ? Colors.amber : Colors.white,
                  size: 32,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationPage(currentUser: username),
                    ),
                  );
                  // 🚨 返回後觸發回調以刷新計數
                  onNotificationClosed?.call();
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // 🚨 新增：影片傳送按鈕 (暫無功能)
          IconButton(
            icon: const Icon(Icons.video_library, color: Colors.white),
            tooltip: "傳送影片",
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("影片功能即將推出！")));
            },
          ),
          const Spacer(),
          // 個人選單
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundImage: NetworkImage(avatarUrl),
              radius: 20,
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('個人檔案')),
              const PopupMenuItem(value: 'logout', child: Text('登出')),
            ],
            onSelected: (value) async {
              if (value == 'profile') {
                if (onProfileTap != null) {
                  onProfileTap!();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ProfilePage(
                        username: username,
                        currentUser: username,
                        avatarUrl: avatarUrl,
                      ),
                    ),
                  );
                }
              } else if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('確定要登出嗎？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('登出'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginPage()),
                    (route) => false,
                  );
                }
              }
            },
            offset: const Offset(0, -10),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
