// lib/pages/profile_page.dart

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../services/firestore_service.dart'; // 【新增】導入 FirestoreService

class ProfilePage extends StatefulWidget {
  final String account;
  const ProfilePage({super.key, required this.account});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  User? _currentUser;
  
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _bmrController = TextEditingController(); 
  final TextEditingController _goalWeightController = TextEditingController();
  
  bool _isLoading = true; // 【新增】加入載入狀態控制

  @override
  void initState() { 
    super.initState(); 
    _loadUserData(); 
  }

  Future<void> _loadUserData() async {
    final user = await DatabaseHelper.instance.getUserByAccount(widget.account);
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false; // 載入完成
        
        if (user != null) {
          _heightController.text = user.height;
          _weightController.text = user.weight;
          _ageController.text = user.age;
          _fatController.text = user.fat ?? '';
          _bmiController.text = user.bmi;
          _bmrController.text = user.bmr ?? '';
          _goalWeightController.text = user.goalWeight ?? '';
        }
      });
    }
  }

  void _calculateMetrics() {
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);
    final a = int.tryParse(_ageController.text);

    if (h != null && w != null && h > 0) {
      final bmi = w / ((h / 100) * (h / 100));
      _bmiController.text = bmi.toStringAsFixed(2);

      // BMR 計算邏輯
      if (a != null && a > 0 && _currentUser?.gender != null) {
        double bmr = 0;
        if (_currentUser!.gender == 'male') {
          bmr = (10 * w) + (6.25 * h) - (5 * a) + 5;
        } else {
          bmr = (10 * w) + (6.25 * h) - (5 * a) - 161;
        }
        _bmrController.text = bmr.toStringAsFixed(2);
      } else {
        _bmrController.text = '';
      }

    } else {
      _bmiController.text = '';
      _bmrController.text = ''; 
    }
    setState(() {});
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      final updatedUser = _currentUser!.copyWith(
        height: _heightController.text,
        weight: _weightController.text,
        age: _ageController.text,
        fat: _fatController.text,
        bmi: _bmiController.text,
        bmr: _bmrController.text,
        goalWeight: _goalWeightController.text,
      );
      
      // 1. 更新本地資料庫
      await DatabaseHelper.instance.updateUser(updatedUser);
      
      // 2. 【新增】同步更新雲端 Firestore
      await FirestoreService.instance.syncUserData(
        height: _heightController.text,
        weight: _weightController.text,
        age: _ageController.text,
        fat: _fatController.text,
        bmi: _bmiController.text,
        bmr: _bmrController.text,
        goalWeight: _goalWeightController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('個人資料已更新並同步！')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料修改'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
            ? const Center(child: Text('找不到使用者資料'))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildLabeledTextField(
                      label: '身高 (cm)',
                      controller: _heightController,
                      onChanged: (_) => _calculateMetrics(), 
                      validator: (v) => v!.isEmpty ? '此欄位不得為空' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildLabeledTextField(
                      label: '體重 (kg)',
                      controller: _weightController,
                      onChanged: (_) => _calculateMetrics(), 
                      validator: (v) => v!.isEmpty ? '此欄位不得為空' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildLabeledTextField(
                      label: '目標體重 (kg) (填選解鎖更多體重趨勢線)',
                      controller: _goalWeightController,
                    ),
                    const SizedBox(height: 24),
                    _buildLabeledTextField(
                      label: '年齡',
                      controller: _ageController,
                      onChanged: (_) => _calculateMetrics(),
                      validator: (v) => v!.isEmpty ? '此欄位不得為空' : null,
                    ),
                    const SizedBox(height: 24),
                    // 選填欄位不需要 validator
                    _buildLabeledTextField(
                      label: '體脂率 (%) (選填)',
                      controller: _fatController,
                      isOptional: true,
                    ),
                    const SizedBox(height: 24),
                    _buildLabeledTextField(
                      label: 'BMI (自動計算)',
                      controller: _bmiController,
                      readOnly: true,
                    ),
                    const SizedBox(height: 24),
                    _buildLabeledTextField(
                      label: 'BMR (基礎代謝率) (自動計算)',
                      controller: _bmrController,
                      readOnly: true,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        child: const Text('儲存變更'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // 您的自訂 Helper 方法，完全保留
  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    bool isOptional = false,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade500, // 微調顏色以適應深色主題
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}