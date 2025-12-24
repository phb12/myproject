// lib/pages/community_profile_page.dart

import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // 新增圖片選擇
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../services/firestore_service.dart';
import './friend_search_page.dart';
import './create_post_page.dart'; 
import './post_detail_page.dart'; // 【新增】導入貼文詳情頁面

class CommunityProfilePage extends StatefulWidget {
  final String account;
  final String? targetUid; // 支援查看他人檔案

  const CommunityProfilePage({
    super.key, 
    required this.account,
    this.targetUid, 
  });

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  User? _displayUser; 
  bool _isMe = false; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIdentity();
    _loadDisplayUserData();
  }

  void _checkIdentity() {
    final currentUserUid = FirestoreService.instance.getCurrentUserUid();
    if (widget.targetUid != null) {
      _isMe = widget.targetUid == currentUserUid;
    } else {
      final currentUserEmail = fbAuth.FirebaseAuth.instance.currentUser?.email;
      _isMe = (currentUserEmail != null && currentUserEmail == widget.account);
    }
  }

  Future<void> _loadDisplayUserData() async {
    if (_isMe) {
      final user = await DatabaseHelper.instance.getUserByAccount(widget.account);
      if (mounted && user != null) {
        
        // 【新增】從 avatars 集合讀取最新大頭貼
        final currentUserUid = FirestoreService.instance.getCurrentUserUid();
        String? avatarBase64;
        if (currentUserUid != null) {
           avatarBase64 = await FirestoreService.instance.getUserAvatar(currentUserUid);
        }

        final displayUser = avatarBase64 != null 
            ? user.copyWith(photoUrl: avatarBase64) 
            : user;

        setState(() {
          _displayUser = displayUser;
          _isLoading = false;
        });

        // 【新增】若暱稱為空，自動彈出填寫視窗
        if (_displayUser?.nickname == null || _displayUser!.nickname!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _editProfile(title: '歡迎加入社群！請先設定暱稱');
          });
        }
        return;
      }
    }
    
    if (widget.targetUid != null) {
      final cloudData = await FirestoreService.instance.getUserDataByUid(widget.targetUid!);
      
      // 【新增】從 avatars 集合讀取用大頭貼
      final avatarBase64 = await FirestoreService.instance.getUserAvatar(widget.targetUid!);

      if (mounted && cloudData != null) {
         setState(() {
           _displayUser = User(
             account: cloudData['email'] ?? widget.account,
             password: '', height: '', weight: '', age: '', bmi: '',
             nickname: cloudData['nickname'],
             hometown: cloudData['hometown'],
             photoUrl: avatarBase64 ?? cloudData['photoUrl'], // 優先使用獨立集合的頭像
           );
           _isLoading = false;
         });
         return;
      }
    }

    final cloudDataList = await FirestoreService.instance.searchUsers(widget.account);
    if (mounted) {
      if (cloudDataList.isNotEmpty) {
         final data = cloudDataList.first;
         setState(() {
           _displayUser = User(
             account: data['email'] ?? widget.account,
             password: '', height: '', weight: '', age: '', bmi: '',
             nickname: data['nickname'],
             hometown: data['hometown'],
           );
           _isLoading = false;
         });
      } else {
        setState(() {
           _displayUser = User(
             account: widget.account,
             password: '', height: '', weight: '', age: '', bmi: '',
             nickname: '未知使用者',
           );
           _isLoading = false;
        });
      }
    }
  }

  Future<void> _editProfile({String title = '編輯個人資料'}) async {
    if (!_isMe || _displayUser == null) return;
    
    final nicknameController = TextEditingController(text: _displayUser!.nickname ?? '');
    String? newPhotoBase64 = _displayUser!.photoUrl; // 暫存圖片 Base64
    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 大頭貼編輯區
                  GestureDetector(
                    onTap: () async {
                      try {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery, 
                          maxWidth: 400, 
                          imageQuality: 70
                        );
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          final base64String = base64Encode(bytes);
                          setStateDialog(() {
                            newPhotoBase64 = base64String;
                          });
                        }
                      } catch (e) {
                        debugPrint('Error picking image: $e');
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: (newPhotoBase64 != null && newPhotoBase64!.isNotEmpty)
                              ? MemoryImage(base64Decode(newPhotoBase64!))
                              : null,
                          child: (newPhotoBase64 == null || newPhotoBase64!.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white54)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 暱稱輸入框
                  TextFormField(
                    controller: nicknameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '暱稱',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    final newNickname = nicknameController.text.trim();
                    
                    Navigator.pop(dialogContext); // 先關閉視窗

                    // 更新邏輯
                    final updatedUser = _displayUser!.copyWith(
                      nickname: newNickname.isEmpty ? _displayUser!.nickname : newNickname,
                      photoUrl: newPhotoBase64,
                    );

                    // 1. 更新本地
                    await DatabaseHelper.instance.updateUser(updatedUser);
                    // 2. 更新雲端
                    await FirestoreService.instance.updateUser(updatedUser);

                    // 3. 更新畫面
                    if (mounted) {
                      setState(() {
                        _displayUser = updatedUser;
                      });
                    }
                  },
                  child: const Text('儲存', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _editHometown() async {
    if (!_isMe || _displayUser == null) return;
    final hometownController = TextEditingController(text: _displayUser!.hometown ?? '');
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('設定家鄉', style: TextStyle(color: Colors.white)),
        content: TextFormField(
          controller: hometownController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: '家鄉', labelStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(child: const Text('取消'), onPressed: () => Navigator.pop(dialogContext)),
          TextButton(
            child: const Text('儲存'),
            onPressed: () async {
              final updatedUser = _displayUser!.copyWith(hometown: hometownController.text);
              await DatabaseHelper.instance.updateUser(updatedUser);
              await FirestoreService.instance.syncUserData(hometown: hometownController.text);
              _loadDisplayUserData();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRealWeekHistory() {
    // 如果不是本人，可以顯示歷史貼文，只要有 UID
    final uidToFetch = widget.targetUid ?? FirestoreService.instance.getCurrentUserUid();

    if (uidToFetch == null) return const SizedBox();

    int getWeekNumber(DateTime date) {
      final dayOfYear = int.parse(DateFormat("D").format(date));
      return ((dayOfYear - date.weekday + 10) / 7).floor();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance.getUserPostsStream(uidToFetch),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('載入錯誤', style: TextStyle(color: Colors.grey));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('尚未上傳任何貼文', style: TextStyle(color: Colors.grey))),
          );
        }

        Map<DateTime, List<Map<String, dynamic>>> groupedPosts = {};
        for (var doc in docs) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['postId'] = doc.id; // Inject ID
          final Timestamp? ts = data['timestamp'];
          if (ts == null) continue;
          final date = ts.toDate();
          final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
          if (!groupedPosts.containsKey(startOfWeek)) {
            groupedPosts[startOfWeek] = [];
          }
          groupedPosts[startOfWeek]!.add(data);
        }

        final sortedWeeks = groupedPosts.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          children: sortedWeeks.map((startOfWeek) {
            final endOfWeek = startOfWeek.add(const Duration(days: 6));
            final weekPosts = groupedPosts[startOfWeek]!;
            final weekNumber = getWeekNumber(startOfWeek);

            return Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('第 $weekNumber 週', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('${DateFormat('M/d').format(startOfWeek)} - ${DateFormat('M/d').format(endOfWeek)}', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: weekPosts.map((post) {
                      final imageBase64 = post['imageUrl'] as String?;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(postData: post),
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: (imageBase64 != null && imageBase64.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(imageBase64),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.error, color: Colors.white24),
                                  ),
                                )
                              : const Center(child: Icon(Icons.text_fields, color: Colors.white24)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) { 
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userAccount = widget.account;
    final defaultNickname = userAccount.split('@').first;
    final displayName = _displayUser?.nickname != null && _displayUser!.nickname!.isNotEmpty 
                            ? _displayUser!.nickname! 
                            : defaultNickname; 

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('個人檔案', style: TextStyle(color: Colors.white)),
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop())
            : null,
        automaticallyImplyLeading: false,
        
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendSearchPage()),
              );
            },
            tooltip: '搜尋好友',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _isMe ? _editProfile : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          overflow: TextOverflow.ellipsis, 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$userAccount', 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300, 
                      shape: BoxShape.circle,
                      image: (_displayUser?.photoUrl != null && _displayUser!.photoUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(_displayUser!.photoUrl!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_displayUser?.photoUrl == null || _displayUser!.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const Row(children: [
               Icon(Icons.calendar_today, size: 16, color: Colors.white),
               SizedBox(width: 8),
               Text('發佈紀錄', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            
            GestureDetector(
              onTap: _isMe ? _editHometown : null,
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _displayUser?.hometown != null && _displayUser!.hometown!.isNotEmpty 
                      ? '家鄉 : ${_displayUser!.hometown}' 
                      : (_isMe ? '家鄉 : +新增' : '家鄉 : 未設定'), 
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)
                ),
              ]),
            ),
            
            const SizedBox(height: 32),
            const Text('已上傳貼文歷史', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            
            _buildRealWeekHistory(),

            const SizedBox(height: 50),
          ],
        ),
      ),
      // 【新增】右下角浮動按鈕：發文 (僅限本人)
      floatingActionButton: _isMe ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }
}