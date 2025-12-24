// lib/pages/friend_search_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import './community_profile_page.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    // 呼叫 Service 搜尋
    final results = await FirestoreService.instance.searchUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 黑色風格
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '搜尋暱稱或 Email...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    '沒有找到使用者',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final nickname = user['nickname'] ?? '未設定暱稱';
                    final email = user['email'] ?? '';
                    final hometown = user['hometown'] ?? '未知地區';
                    // 使用 email 作為唯一識別，傳遞給個人頁面
                    final account = user['email'] as String; 
                    final uid = user['uid'] as String?;

                    return ListTile(
                      leading: FutureBuilder<String?>(
                        future: (uid != null) ? FirestoreService.instance.getUserAvatar(uid) : Future.value(null),
                        builder: (context, snapshot) {
                          final avatarBase64 = snapshot.data;
                          return CircleAvatar(
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                                ? MemoryImage(base64Decode(avatarBase64))
                                : null,
                            child: (avatarBase64 == null || avatarBase64.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          );
                        },
                      ),
                      title: Text(nickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('$email\n$hometown', style: TextStyle(color: Colors.grey.shade400)),
                      isThreeLine: true,
                      onTap: () {
                        // 點擊後跳轉到對方的個人頁面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommunityProfilePage(
                              account: account, // 傳入對方的帳號
                              targetUid: uid,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}