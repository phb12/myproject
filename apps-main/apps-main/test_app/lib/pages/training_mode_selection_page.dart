// lib/pages/training_mode_selection_page.dart

import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import './exercise_setup_page.dart';
import './video_analysis_page.dart';

class TrainingModeSelectionPage extends StatelessWidget {
  final Exercise exercise;
  final BodyPart bodyPart;

  const TrainingModeSelectionPage({
    super.key,
    required this.exercise,
    required this.bodyPart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇訓練模式'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '您想要如何進行 ${exercise.name}？',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

              // 選項 1：即時辨識
            _buildModeCard(
              context,
              title: '即時動作辨識',
              description: '使用相機即時分析您的動作準確度。',
              icon: Icons.camera_alt_outlined,
              color: Colors.purple.shade400,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseSetupPage(
                      exercise: exercise,
                      bodyPart: bodyPart,
                      enableAi: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 選項 2：影片錄製
            _buildModeCard(
              context,
              title: '影片錄製分析',
              description: '錄製您的訓練過程並上傳分析。',
              icon: Icons.videocam_outlined,
              color: Colors.orange.shade400,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoAnalysisPage(
                      exercise: exercise,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 選項 3：直接開始 (原本流程)
            _buildModeCard(
              context,
              title: '直接開始訓練',
              description: '結束後記錄重量與次數。',
              icon: Icons.edit_note,
              color: Colors.blue.shade400,
              onTap: () {
                // 跳轉到原本的設定頁面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseSetupPage(
                      exercise: exercise,
                      bodyPart: bodyPart,
                      enableAi: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}