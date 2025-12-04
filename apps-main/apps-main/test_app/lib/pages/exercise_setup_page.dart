// lib/pages/exercise_setup_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import '../models/plan_item_model.dart';
import '../services/auth_service.dart'; // 確保有這行
import '../utils/exercise_guide_helper.dart';
import './training_session_page.dart';

class ExerciseSetupPage extends StatefulWidget {
  final Exercise exercise;
  final BodyPart bodyPart;
  final bool enableAi;

  const ExerciseSetupPage({
    super.key,
    required this.exercise,
    required this.bodyPart,
    this.enableAi = false,
  });
  @override
  State<ExerciseSetupPage> createState() => _ExerciseSetupPageState();
}

class _ExerciseSetupPageState extends State<ExerciseSetupPage> {
  int _sets = 3;
  int _restMinutes = 1;
  int _restSeconds = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          if (widget.enableAi) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                  if (ExerciseGuideHelper.getGuideImage(widget.exercise.name) != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        ExerciseGuideHelper.getGuideImage(widget.exercise.name)!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported, color: Colors.white54, size: 50),
                                SizedBox(height: 8),
                                Text('圖片載入失敗', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 60),
                          SizedBox(height: 16),
                          Text(
                            '請參考下方說明架設相機',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: const Text(
                          '請將手機放置於側面，確保全身入鏡以獲得最佳分析效果。',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          Text('訓練參數', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Text('訓練組數：', style: TextStyle(fontSize: 16)),
              const Spacer(),
              Text('$_sets 組', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          _buildPicker(
            itemCount: 20,
            onSelectedItemChanged: (index) {
              setState(() {
                _sets = index + 1;
              });
            },
            initialItem: _sets - 1,
          ),
          const SizedBox(height: 16),
          const Text('休息時間：', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: _buildPicker(
                  itemCount: 10,
                  onSelectedItemChanged: (index) => setState(() => _restMinutes = index),
                  initialItem: _restMinutes,
                  suffix: '分',
                ),
              ),
              Expanded(
                child: _buildPicker(
                  itemCount: 6,
                  onSelectedItemChanged: (index) => setState(() => _restSeconds = index * 10),
                  initialItem: _restSeconds ~/ 10,
                  isSeconds: true,
                  suffix: '秒',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_restMinutes == 0 && _restSeconds == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('休息時間不能為 0 秒，請重新設定！'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final tempPlanItem = PlanItem(
                  dayOfWeek: 0, 
                  exerciseName: widget.exercise.name,
                  sets: _sets.toString(),
                  weight: '', 
                );

                // 取得當前 User Email
                final currentUserEmail = AuthService.instance.currentUser?.email ?? 'unknown';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainingSessionPage(
                      currentItem: tempPlanItem,
                      remainingItems: [],
                      bodyPart: widget.bodyPart,
                      account: currentUserEmail, // 傳入帳號
                      enableAi: widget.enableAi,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('開始訓練', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required int initialItem,
    String suffix = '',
    bool isSeconds = false,
  }) {
    return SizedBox(
      height: 120,
      child: CupertinoPicker(
        itemExtent: 40,
        scrollController: FixedExtentScrollController(initialItem: initialItem),
        onSelectedItemChanged: onSelectedItemChanged,
        children: List<Widget>.generate(itemCount, (int index) {
          final value = isSeconds ? index * 10 : index + (suffix == '分' ? 0 : 1);
          return Center(child: Text('$value $suffix'));
        }),
      ),
    );
  }
}