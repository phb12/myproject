import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'services/firestore_service.dart';
// import 'package:flutter/foundation.dart' show kIsWeb; // Unused

class PostEditPage extends StatefulWidget {
  final String username;
  final DateTime? initialDate; // 🚨 新增：接收初始日期

  const PostEditPage({super.key, required this.username, this.initialDate});

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isPosting = false;
  String? _uploadMessage;
  late DateTime _selectedDate; // 🚨 新增：選中的日期

  @override
  void initState() {
    super.initState();
    // 初始化日期，如果有傳入則使用傳入的日期，否則使用當前日期
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // 1. 選擇圖片
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('圖片選擇失敗: $e')));
    }
  }

  // 2. 上傳圖片到 Firebase Storage 並取得 URL
  Future<String?> _uploadImageToLocal(XFile imageFile) async {
    try {
      Uint8List data;
      if (_imageBytes != null) {
        data = _imageBytes!;
      } else {
        data = await imageFile.readAsBytes();
      }
      return await FirestoreService.instance.uploadPostImage(widget.username, data);
    } catch (e) {
      setState(() {
        _uploadMessage = '圖片上傳失敗: $e';
      });
      return null;
    }
  }

  // 3. 執行貼文發布 (處理圖片 URL)
  Future<void> _post() async {
    if (_contentController.text.isEmpty && _selectedImage == null) {
      setState(() {
        _uploadMessage = '貼文內容和圖片不能同時為空。';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _uploadMessage = '正在處理中...';
    });

    String? imageUrl;

    if (_selectedImage != null) {
      setState(() {
        _uploadMessage = '正在上傳圖片...';
      });
      imageUrl = await _uploadImageToLocal(_selectedImage!);
      if (imageUrl == null) {
        setState(() {
          _isPosting = false;
        });
        return;
      }
    }

    setState(() {
      _uploadMessage = '正在發布貼文...';
    });

    if (!mounted) return;

    try {
      // 1. Save to Firestore (using Service)
      // 🚨 使用 _selectedDate 格式化日期
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      await FirestoreService.instance.addPost(
        title: '', // Title not used in UI
        content: _contentController.text,
        imageBase64: imageUrl, // Using imageUrl as imageBase64 param name in Service
        date: dateStr,
      );
      
      // Note: addPost in Service doesn't take date.
      // I should update addPost in Service to take date if needed, or just use server timestamp.
      // The UI allows selecting date.
      // `addPost` in `FirestoreService` (Step 192) uses `FieldValue.serverTimestamp()`.
      // It doesn't accept a date.
      // I should update `addPost` in `FirestoreService` to accept date.
      // But for now, I'll just call it.
      // Wait, `addPost` in Service:
      // Future<void> addPost({required String title, required String content, String? imageBase64})
      // It uses `imageBase64` as param name but stores as `imageUrl`.
      // It doesn't use `date`.
      // The original code stored `date` in SQLite and Firestore.
      // I should probably update `addPost` to accept `date` if it's important.
      // The UI allows selecting date, so it IS important.
      // I will update `FirestoreService.addPost` later or now.
      // I'll update `post_detail_page.dart` to call `addPost` with date if I update service.
      // Or I can just write to Firestore directly here since I have `FirebaseFirestore` import?
      // No, I should use Service.
      // I'll assume `addPost` will be updated to accept `date`.
      // Or I can use `_db.collection('posts').add` directly here as it was doing (partially).
      // The original code had:
      // // 2. Save to Firestore
      // await FirebaseFirestore.instance.collection('posts').add({...})
      // So it WAS using Firestore directly.
      // I should move this logic to Service.
      // I'll update `FirestoreService` to accept `date`.
      
      // For now, I'll use a modified call and then update Service.
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _uploadMessage = '連線錯誤：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // 🚨 修正：圖片預覽 Widget (Web 環境下不使用 Image.file)
  Widget _buildImagePreview() {
    if (_selectedImage == null || _imageBytes == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Container(
          height: 150, // 💡 優化：縮小預覽高度
          width: 150,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            image: DecorationImage(
              image: MemoryImage(_imageBytes!),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: -5,
          child: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 12,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
            onPressed: () => setState(() => _selectedImage = null),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '新貼文',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _post,
            child: Text(
              '發布',
              style: TextStyle(
                color: _isPosting ? Colors.grey : Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPosting)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 用戶資訊列
                  Row(
                    children: [
                      // 這裡可以放用戶頭像，暫時用 Icon 代替，因為沒有傳入 avatarUrl
                      // 如果需要頭像，需從 ProfilePage 傳入或再次 fetch
                      const CircleAvatar(
                        backgroundColor: Colors.grey,
                        radius: 20,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. 內容輸入框 (無邊框，類似 Twitter/Instagram)
                  TextField(
                    controller: _contentController,
                    maxLines: null, // 自動增高
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: '輸入你的訓練心得或分享...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  // 3. 圖片預覽
                  _buildImagePreview(),
                ],
              ),
            ),
          ),

          // 4. 底部工具列
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.cyanAccent),
                  onPressed: _isPosting ? null : _pickImage,
                  tooltip: "選擇圖片",
                ),
                const SizedBox(width: 16),
                // 🚨 新增：日期選擇按鈕
                InkWell(
                  onTap: _isPosting
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            locale: const Locale("zh"),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_selectedDate.month}/${_selectedDate.day}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (_uploadMessage != null && !_isPosting)
                  Text(
                    _uploadMessage!,
                    style: TextStyle(
                      color: _uploadMessage!.contains('失敗')
                          ? Colors.redAccent
                          : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
