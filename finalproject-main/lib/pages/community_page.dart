// lib/pages/community_page.dart

/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import './create_post_page.dart';
import './community_profile_page.dart';

class CommunityPage extends StatefulWidget {
  final String account;
  const CommunityPage({super.key, required this.account});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late DateTime _selectedDate;
  // 【核心修正 1】宣告一個 Stream 變數
  late Stream<QuerySnapshot> _postsStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    
    // 【核心修正 1】在初始化時就建立 Stream，避免畫面刷新時重複連線
    _postsStream = FirestoreService.instance.getPostsStream();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final String currentWeekNumber = DateFormat('w').format(now);
    final List<String> weekDayNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('社群'),
        backgroundColor: Colors.black,
        leading: null, 
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityProfilePage(account: widget.account)));
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header 區塊
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 $currentWeekNumber 週', 
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildAddPostCard(context),
                      const SizedBox(width: 8),
                      
                      ...List.generate(7, (index) {
                        final date = startOfWeek.add(Duration(days: index));
                        final dateOnly = DateTime(date.year, date.month, date.day);
                        final isFuture = dateOnly.isAfter(today);
                        final isSelected = _isSameDay(date, _selectedDate);
                        
                        return GestureDetector(
                          onTap: isFuture ? null : () => setState(() => _selectedDate = dateOnly),
                          child: Opacity(
                            opacity: isFuture ? 0.3 : 1.0,
                            child: _buildDateCard(
                              DateFormat('M月 d日').format(date),
                              weekDayNames[index],
                              isSelected
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Feed 區塊
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postsStream, // 【核心修正 1】使用變數，而不是函數呼叫
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('發生錯誤'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allDocs = snapshot.data?.docs ?? [];
                
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final Timestamp? ts = data['timestamp'];
                  if (ts == null) return false;
                  return _isSameDay(ts.toDate(), _selectedDate);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          '${DateFormat('M月d日').format(_selectedDate)} 沒有貼文',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildPostCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAddPostCard(BuildContext context) {
    return Container(
      width: 80, height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())),
        borderRadius: BorderRadius.circular(10),
        child: const Center(child: Icon(Icons.add, size: 30, color: Colors.white)),
      ),
    );
  }

  Widget _buildDateCard(String dateStr, String dayStr, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        width: 80, height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade800 : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Colors.white24, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dateStr, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            Text(dayStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> data) {
    final userName = data['authorName'] ?? '未知使用者';
    final title = data['title'] ?? '無標題';
    final content = data['content'] ?? '';
    final imageUrl = data['imageUrl'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white70)),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          // 【核心修正 2】增強圖片顯示邏輯，防止紅屏錯誤
          if (imageUrl != null && imageUrl.isNotEmpty)
            imageUrl.startsWith('http') 
            ? Image.network( // 處理舊資料的網址
                imageUrl,
                width: double.infinity, height: 250, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 250, color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
              )
            : Image.memory( // 處理新資料的 Base64
                base64Decode(imageUrl),
                width: double.infinity, height: 250, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 250, color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
              )
          else
            Container(
              width: double.infinity, height: 250, color: Colors.grey[900],
              child: const Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 60)),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(content),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.favorite_border, size: 20, color: Colors.grey),
                SizedBox(width: 4),
                Text('0', style: TextStyle(color: Colors.grey)),
                SizedBox(width: 24),
                Icon(Icons.comment_outlined, size: 20, color: Colors.grey),
                SizedBox(width: 4),
                Text('0', style: TextStyle(color: Colors.grey)),
                Spacer(),
                Icon(Icons.bookmark_border, color: Colors.grey),
              ],
            ),
          )
        ],
      ),
    );
  }
}*/