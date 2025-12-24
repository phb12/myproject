import 'package:flutter/material.dart';
import 'dart:convert';
import 'services/firestore_service.dart';

/// 好友管理主頁
class FriendListPage extends StatefulWidget {
  final String currentUser;
  const FriendListPage({super.key, required this.currentUser});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  List<String> friends = [];
  List<String> filteredFriends = [];
  bool loading = false;
  String searchText = "";

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  Future<void> fetchFriends() async {
    setState(() => loading = true);
    try {
      final f = await FirestoreService.instance.getFriends(widget.currentUser);
      setState(() {
        friends = f;
        filterFriends(searchText);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void filterFriends(String query) {
    setState(() {
      searchText = query;
      if (query.trim().isEmpty) {
        filteredFriends = friends;
      } else {
        filteredFriends = friends
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<String> _fetchFriendAvatar(String username) async {
    try {
      final data = await FirestoreService.instance.getUserDataByUid(username);
      if (data != null) {
        final url = data['avatar_url'] ?? "https://i.pravatar.cc/100?u=default";
        return "$url?t=${DateTime.now().millisecondsSinceEpoch}";
      }
    } catch (e) {
      // print("Error fetching avatar for $username: $e");
    }
    return "https://i.pravatar.cc/100?u=default";
  }

  Future<void> deleteFriend(String friendUsername) async {
    // 💡 UX優化：加入確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('解除好友關係？', style: TextStyle(color: Colors.white)),
        content: Text(
          '確定要解除與 $friendUsername 的好友關係嗎？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('確認解除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.instance.deleteFriend(widget.currentUser, friendUsername);
        await fetchFriends();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已解除與 $friendUsername 的好友關係')));
      } catch (e) {
        // Handle error
      }
    }
  }

  /// 待審好友icon按下跳出申請清單
  void showPendingRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900], // 模態框背景色
      builder: (_) => SizedBox(
        height: 530,
        child: FriendRequestListModal(
          currentUser: widget.currentUser,
          onAcceptOrReject: fetchFriends, // 操作後自動刷新好友列表
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 主體背景
      appBar: AppBar(
        title: const Text('好友管理', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.hourglass_top, color: Colors.cyanAccent),
            tooltip: "待處理好友申請",
            onPressed: showPendingRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋列 (黑白風格)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                hintText: '搜尋好友帳號/暱稱',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.cyanAccent,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
              ),
              onChanged: filterFriends,
            ),
          ),

          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : filteredFriends.isEmpty
                ? const Center(
                    child: Text(
                      '沒有符合條件的好友',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredFriends.length,
                    itemBuilder: (ctx, index) {
                      final f = filteredFriends[index];
                      // 💡 列表項目使用深色 ListTile
                      return FutureBuilder<String>(
                        future: _fetchFriendAvatar(f),
                        builder: (context, snapshot) {
                          final avatarUrl =
                              snapshot.data ??
                              "https://i.pravatar.cc/100?u=default";
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ListTile(
                              tileColor: Colors.transparent,
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(avatarUrl),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              title: Text(
                                f,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.redAccent,
                                ),
                                tooltip: "解除好友",
                                onPressed: () => deleteFriend(f),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 下方彈出的待審好友申請列表 (黑白風格)
class FriendRequestListModal extends StatefulWidget {
  final String currentUser;
  final Future<void> Function() onAcceptOrReject;
  const FriendRequestListModal({
    super.key,
    required this.currentUser,
    required this.onAcceptOrReject,
  });

  @override
  State<FriendRequestListModal> createState() => _FriendRequestListModalState();
}

class _FriendRequestListModalState extends State<FriendRequestListModal> {
  List requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    setState(() => loading = true);
    try {
      final reqs = await FirestoreService.instance.getFriendRequests(widget.currentUser);
      setState(() {
        requests = reqs;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> handleRequest(String id, String action, String fromUser) async {
    final int status = action == 'accept' ? 1 : 2;
    await FirestoreService.instance.dealFriendRequest(id, status);
    await fetchRequests();
    await widget.onAcceptOrReject();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'accept' ? '已接受 $fromUser 為好友' : '已拒絕 $fromUser 的申請',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> fetchAvatar(String username) async {
    try {
      final data = await FirestoreService.instance.getUserDataByUid(username);
      if (data != null) {
        final url = data['avatar_url'] ?? "https://i.pravatar.cc/100?u=default";
        return "$url?t=${DateTime.now().millisecondsSinceEpoch}";
      }
    } catch (e) {
      // print("Error fetching avatar for $username: $e");
    }
    return "https://i.pravatar.cc/100?u=default";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // 確保整個模態框內容背景為黑色
      child: Column(
        children: [
          // 模態框標題
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '待處理好友申請',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.2)),

          // 列表內容
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : requests.isEmpty
                ? const Center(
                    child: Text(
                      '沒有待處理好友申請',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    children: requests.map<Widget>((req) {
                      return FutureBuilder<String>(
                        future: fetchAvatar(req['from_user']),
                        builder: (context, snapshot) {
                          final avatarUrl =
                              snapshot.data ??
                              "https://i.pravatar.cc/100?u=default";
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(avatarUrl),
                                radius: 24,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              title: Text(
                                req['from_user'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                '發送於 ${req['created_at'].substring(0, 19).replaceFirst('T', ' ')}',
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                    ),
                                    tooltip: "接受",
                                    onPressed: () => handleRequest(
                                      req['id'],
                                      'accept',
                                      req['from_user'],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: "拒絕",
                                    onPressed: () => handleRequest(
                                      req['id'],
                                      'reject',
                                      req['from_user'],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
