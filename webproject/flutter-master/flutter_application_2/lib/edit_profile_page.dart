import 'package:flutter/material.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'services/firestore_service.dart';
import 'package:flutter/services.dart'; // 用於輸入格式化
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final String username;
  final String displayName;
  final String avatarUrl;
  // 🚨 新增：接收初始的身高和體重
  final double initialHeight;
  final double initialWeight;

  const EditProfilePage({
    super.key,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.initialHeight = 0.0,
    this.initialWeight = 0.0,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _displayNameController;
  late TextEditingController _avatarUrlController;
  // 🚨 新增：身高體重控制器
  late TextEditingController _heightController;

  late TextEditingController _weightController;

  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  // final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.displayName);
    _avatarUrlController = TextEditingController(text: widget.avatarUrl);

    // 🚨 初始化控制器：只在數據大於 0 時顯示數值
    _heightController = TextEditingController(
      text: widget.initialHeight > 0
          ? widget.initialHeight.toStringAsFixed(0)
          : '',
    );
    _weightController = TextEditingController(
      text: widget.initialWeight > 0
          ? widget.initialWeight.toStringAsFixed(1)
          : '',
    );
  }

  // 釋放控制器 (單一且正確的定義)
  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // 🚨 儲存身高和體重數據的 API 呼叫
  Future<bool> _saveHealthStats(String username) async {
    // 確保空字串被視為 0.0
    final heightValue = double.tryParse(_heightController.text) ?? 0.0;
    final weightValue = double.tryParse(_weightController.text) ?? 0.0;

    try {
      await FirestoreService.instance.syncUserData(
        height: heightValue.toString(),
        weight: weightValue.toString(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = '圖片選擇失敗';
      if (e.toString().contains('Could not load Blob')) {
        errorMessage =
            '瀏覽器無法讀取此圖片 (Blob Error)。\n請嘗試其他圖片，或改用 Windows/Android 版本執行。';
      } else {
        errorMessage = '錯誤: $e';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('圖片錯誤', style: TextStyle(color: Colors.red)),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('確定'),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null && _imageBytes == null) return null;

    try {
      Uint8List data;
      if (_imageBytes != null) {
        data = _imageBytes!;
      } else {
        data = await _imageFile!.readAsBytes();
      }
      
      return await FirestoreService.instance.uploadUserImage(widget.username, data);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('上傳失敗', style: TextStyle(color: Colors.red)),
            content: Text('錯誤詳細資訊:\n$e\n\n請檢查網路連線。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('確定'),
              ),
            ],
          ),
        );
      }
      setState(() {
        _errorMessage = '圖片上傳失敗: $e';
      });
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newDisplayName = _displayNameController.text.trim();
    String newAvatarUrl = _avatarUrlController.text.trim();

    // 如果有新圖片，先上傳
    if (_imageFile != null) {
      final uploadedUrl = await _uploadImage();
      if (uploadedUrl != null) {
        newAvatarUrl = uploadedUrl;
        // 同步更新 Firestore (如果需要)
        // await _firebaseService.saveUserImageToFirestore(widget.username, newAvatarUrl);
      }
    }

    try {
      // 1. 儲存基本資料
      await FirestoreService.instance.syncUserData(
        nickname: newDisplayName,
        avatarUrl: newAvatarUrl,
      );

      // 2. 儲存身高體重數據
      final statsSuccess = await _saveHealthStats(widget.username);

      if (!mounted) return;

      if (statsSuccess) {
        // 成功，返回上一頁並傳遞成功標誌 (true)
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = '儲存失敗。';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '網路錯誤或伺服器無回應: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🚨 原本重複定義的 dispose() 已移除

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("編輯個人資料", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.cyanAccent),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!) as ImageProvider
                          : NetworkImage(_avatarUrlController.text),
                      onBackgroundImageError: (e, s) {},
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 基本資料編輯
            const Text(
              "基本資料",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Divider(color: Colors.white24),

            // 顯示名稱
            TextField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '顯示名稱',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 頭像 URL
            TextField(
              controller: _avatarUrlController,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}), // 觸發頭像預覽更新
              decoration: InputDecoration(
                labelText: '頭像 URL',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 身體數據編輯
            const Text(
              "身體數據",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),

            // 身高
            TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '身高 (cm)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 體重
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '體重 (kg)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
            const SizedBox(height: 30),

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
