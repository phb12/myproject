import 'package:flutter/material.dart';
import 'dart:convert';
import 'services/firestore_service.dart';

class NotificationPage extends StatefulWidget {
  final String currentUser;
  const NotificationPage({super.key, required this.currentUser});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() => loading = true);
    try {
      final notifs = await FirestoreService.instance.getNotifications(widget.currentUser);
      setState(() {
        notifications = notifs;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> markAsRead(String id) async {
    await FirestoreService.instance.markNotificationRead(id);
    await fetchNotifications();
  }

  Future<void> deleteReadNotifications() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確定要刪除全部已讀通知？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (result == true) {
      await FirestoreService.instance.deleteReadNotifications(widget.currentUser);
      await fetchNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('通知中心', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: "刪除全部已讀",
            onPressed: deleteReadNotifications,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(
              child: Text(
                "目前沒有通知",
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
            )
          : ListView(
              children: notifications.map((n) {
                final isUnread = n['status'] == 0;
                final content = n['content'] as String;
                final userEnd = content.indexOf(' ');
                String user = '', action = content;
                if (userEnd > 0) {
                  user = content.substring(0, userEnd);
                  action = content.substring(userEnd);
                }
                return ListTile(
                  onTap: isUnread ? () => markAsRead(n['id'].toString()) : null,
                  leading: Icon(
                    Icons.notifications,
                    color: isUnread ? Colors.amber : Colors.white30,
                    size: 30,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: user,
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: action,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    n['created_at']
                        .toString()
                        .substring(0, 19)
                        .replaceFirst('T', ' '),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  tileColor: Colors.transparent,
                );
              }).toList(),
            ),
    );
  }
}
