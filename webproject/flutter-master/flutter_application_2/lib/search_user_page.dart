import 'package:flutter/material.dart';
import 'dart:convert';
import 'services/firestore_service.dart';
import 'profile_page.dart';

class SearchUserPage extends StatefulWidget {
  final String currentUser;
  const SearchUserPage({super.key, required this.currentUser});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  TextEditingController ctrl = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool loading = false;

  // 動態搜尋，每次內容改變即查詢
  Future<void> search([String? keyword]) async {
    setState(() => loading = true);
    final value = keyword ?? ctrl.text.trim();
    if (value.isEmpty) {
      setState(() {
        results = [];
        loading = false;
      });
      return;
    }
    try {
      final res = await FirestoreService.instance.searchUsers(value);
      setState(() {
        results = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: ctrl,
          autofocus: true,
          onChanged: search, // <<<<<關鍵，改這裡
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "搜尋用戶...",
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => search(ctrl.text),
          ),
        ],
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: results
                  .map(
                    (u) => ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(u['avatar_url'] ?? ""),
                      ),
                      title: Text(
                        u['username'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(
                              username: u['username'],
                              currentUser: widget.currentUser,
                              avatarUrl:
                                  u['avatar_url'] ??
                                  "https://i.pravatar.cc/150?u=retro_profile",
                            ),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
