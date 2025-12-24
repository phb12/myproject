// lib/pages/create_post_page.dart

import 'dart:convert'; // 【新增】用於轉碼
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        
        // 【核心修正：強制縮小圖片】
        // 透過限制最大長寬，確保圖片轉成文字後不會超過 1MB
        maxWidth: 800,   
        maxHeight: 800,  
        imageQuality: 70, // 品質設為 70% (兼顧清晰度與大小)
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選取圖片失敗: $e')),
      );
    }
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('標題和內容不能為空')));
      return;
    }

    setState(() => _isSubmitting = true);

  try {
      String? imageBase64;
      
      if (_selectedImage != null) {
        List<int> imageBytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
        
        // 雙重保險：如果縮小後還是超過 1MB (極少見)，則阻止上傳並提示
        // Firestore 限制約 1,048,576 bytes
        if (imageBase64.length > 1000000) {
          throw Exception('圖片檔案過大，請換一張圖片');
        }
      }

      // 傳送 Base64 字串給 Firestore
      await FirestoreService.instance.addPost(
        title: title,
        content: content,
        imageBase64: imageBase64,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('發布成功！'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      // 顯示更友善的錯誤訊息
      String errorMessage = e.toString();
      if (errorMessage.contains('invalid-argument') || errorMessage.contains('payload is too large')) {
        errorMessage = '圖片太大無法上傳，請換一張';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('發布失敗: $errorMessage'), backgroundColor: Colors.red));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立貼文'),
        actions: [
          _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _submitPost,
                  tooltip: '發布',
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                  image: _selectedImage != null 
                      ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _selectedImage == null 
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 50),
                          SizedBox(height: 8),
                          Text('點擊上傳圖片', style: TextStyle(color: Colors.white54)),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '標題', hintText: '分享您的訓練成果...'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(labelText: '內容', hintText: '分享更多細節...', border: OutlineInputBorder()),
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}