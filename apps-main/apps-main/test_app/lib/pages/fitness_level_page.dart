// lib/pages/fitness_level_page.dart

import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../main.dart'; // 為了跳轉到 MainAppShell

class FitnessLevelPage extends StatefulWidget {
  final String account;
  const FitnessLevelPage({super.key, required this.account});

  @override
  State<FitnessLevelPage> createState() => _FitnessLevelPageState();
}

class _FitnessLevelPageState extends State<FitnessLevelPage> {
  FitnessLevel? _selectedLevel;

  Future<void> _saveAndContinue() async {
    if (_selectedLevel == null) return;

    User? currentUser = await DatabaseHelper.instance.getUserByAccount(widget.account);
    if (currentUser != null) {
      final updatedUser = currentUser.copyWith(
        fitnessLevel: _selectedLevel!.name, // 將 enum 轉換為字串 'light', 'medium', 'heavy'
      );
      await DatabaseHelper.instance.updateUser(updatedUser);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainAppShell(account: widget.account),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text('選擇您的健身強度', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('這將幫助我們為您提供個人化的建議', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              _buildLevelCard(
                level: FitnessLevel.light,
                title: '輕度',
                subtitle: '居家訓練，維持活動',
                icon: Icons.home_work_outlined,
              ),
              const SizedBox(height: 16),
              _buildLevelCard(
                level: FitnessLevel.medium,
                title: '中度',
                subtitle: '規律上健身房，提升體態',
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 16),
              _buildLevelCard(
                level: FitnessLevel.heavy,
                title: '重度',
                subtitle: '科學化訓練，追求極限',
                icon: Icons.local_fire_department,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedLevel != null ? _saveAndContinue : null, // 如果未選擇，按鈕禁用
                child: const Text('完成並開始'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard({
    required FitnessLevel level,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedLevel == level;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      color: isSelected ? primaryColor.withOpacity(0.2) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: primaryColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedLevel = level),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: isSelected ? primaryColor : null),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}