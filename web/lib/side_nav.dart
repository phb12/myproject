import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'search_user_page.dart';
import 'notification_page.dart';
import 'friend_list_page.dart';
// 新增課表功能頁

class SideNav extends StatefulWidget {
  final String avatarUrl;
  final void Function(int) onTap;
  final int selectedIndex;
  final String displayName; // 顯示名稱
  final String username;
  final int unreadCount;
  final int friendRequestCount;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationClosed;
  final VoidCallback? onFriendListClosed;

  const SideNav({
    super.key,
    required this.avatarUrl,
    required this.onTap,
    required this.selectedIndex,
    required this.username,
    this.displayName = "", // 默認空
    this.unreadCount = 0,
    this.friendRequestCount = 0,
    this.onProfileTap,
    this.onNotificationClosed,
    this.onFriendListClosed,
  });

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  bool _isExpanded = false; // 控制側邊欄展開狀態



  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isExpanded ? 200 : 70, // 展開寬度 200, 收縮寬度 70
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // 1. 首頁 (Dashboard) - Index 0
            _buildNavItem(
              icon: Icons.home,
              label: "首頁",
              isSelected: widget.selectedIndex == 0,
              onTap: () => widget.onTap(0),
            ),

            // 2. 課表 (Schedule) - Index 1
            _buildNavItem(
              icon: Icons.calendar_today,
              label: "課表",
              isSelected: widget.selectedIndex == 1,
              onTap: () => widget.onTap(1),
            ),

            // 3. 運動紀錄 (Training Record) - Index 3
            _buildNavItem(
              icon: Icons.fitness_center,
              label: "運動紀錄",
              isSelected: widget.selectedIndex == 3,
              onTap: () => widget.onTap(3),
            ),

            // 4. 影片分析 (Video Analysis) - Index 4
            _buildNavItem(
              icon: Icons.video_library,
              label: "影片分析",
              isSelected: widget.selectedIndex == 4,
              onTap: () => widget.onTap(4),
            ),

            // 5. 搜尋 (Search) - Index 2 (作為獨立功能)
            _buildNavItem(
              icon: Icons.search,
              label: "搜尋",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchUserPage(currentUser: widget.username),
                  ),
                );
              },
            ),

            // 6. 好友管理
            _buildNavItem(
              icon: Icons.person_add,
              label: "好友管理",
              badgeCount: widget.friendRequestCount,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FriendListPage(currentUser: widget.username),
                  ),
                );
                widget.onFriendListClosed?.call();
              },
            ),

            // 8. 通知 (Notification)
            _buildNavItem(
              icon: Icons.notifications,
              label: "通知",
              badgeCount: widget.unreadCount,
              iconColor: widget.unreadCount > 0 ? Colors.amber : Colors.white,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationPage(currentUser: widget.username),
                  ),
                );
                widget.onNotificationClosed?.call();
              },
            ),

            const Spacer(),

            // 個人選單
            _buildProfileSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isSelected = false,
    int badgeCount = 0,
    Color iconColor = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56, // 固定行高
          child: Row(
            children: [
              // 圖示區域 (固定寬度)
              SizedBox(
                width: 70,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? Colors.blueAccent : iconColor,
                        size: 24,
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -5,
                          top: -5,
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
                              '$badgeCount',
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
                ),
              ),
              // 文字標籤區域 (展開時顯示)
              if (_isExpanded)
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        offset: const Offset(0, -10),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'profile', child: Text('個人檔案')),
          const PopupMenuItem(value: 'logout', child: Text('登出')),
        ],
        onSelected: (value) async {
          if (value == 'profile') {
            if (widget.onProfileTap != null) {
              widget.onProfileTap!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => ProfilePage(
                    username: widget.username,
                    currentUser: widget.username,
                    avatarUrl: widget.avatarUrl,
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
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              SizedBox(
                width: 70,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    child: ClipOval(
                      child: Image.network(
                        widget.avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, color: Colors.white);
                        },
                      ),
                    ),
                  ),
              ),
              if (_isExpanded)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName.isNotEmpty ? widget.displayName : widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        "檢視個人檔案",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
