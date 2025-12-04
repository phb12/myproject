import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'services/firestore_service.dart';

// --- 動作資料模型 (保持不變) ---
class Exercise {
  final String id;
  final String name;
  final String part; // 訓練部位
  final IconData icon;

  Exercise({
    required this.id,
    required this.name,
    required this.part,
    required this.icon,
  });
}

// 定義回調函數的類型
typedef OnAddPlanCallback = void Function(String actionName, String sets);

// -----------------------------------------------------
// --- 動作選擇器對話框 Widget ---
// -----------------------------------------------------
class TrainingSelectionDialog extends StatefulWidget {
  final OnAddPlanCallback onAddPlan;
  final String currentDay;

  const TrainingSelectionDialog({
    super.key,
    required this.onAddPlan,
    required this.currentDay,
  });

  @override
  State<TrainingSelectionDialog> createState() =>
      _TrainingSelectionDialogState();
}

class _TrainingSelectionDialogState extends State<TrainingSelectionDialog> {
  // 狀態
  bool _isLoading = true;
  String? _error;
  List<Exercise> _allExercises = []; // 🚨 儲存從 API 轉換後的 Exercise 列表

  late List<String> parts;
  String? _selectedPart;

  // 用於儲存每個動作的組數 (key: Exercise.name, value: sets)
  final Map<String, int> _setCountMap = {};

  @override
  void initState() {
    super.initState();
    // 🚨 初始數據載入
    _loadAllExercises();
  }

  // 輔助函數：根據部位名稱返回一個圖標
  IconData _getIconForPart(String part) {
    if (part.contains('胸')) return Icons.fitness_center;
    if (part.contains('背')) return Icons.rowing;
    if (part.contains('腿') || part.contains('臀')) return Icons.accessibility;
    if (part.contains('肩')) return Icons.accessibility_new;
    if (part.contains('手')) return Icons.sports_handball;
    if (part.contains('核') || part.contains('腹')) {
      return Icons.sports_gymnastics;
    }
    if (part.contains('三頭')) return Icons.electric_bolt;
    return Icons.run_circle;
  }

  // 🚨 步驟 1: 從 API 獲取動作清單並轉換
  Future<void> _loadAllExercises() async {
    try {
      final data = await FirestoreService.instance.getAllExercises();

      List<Exercise> loadedExercises = [];

      data.forEach((partName, exerciseList) {
        if (exerciseList is List) {
          for (var actionName in exerciseList) {
            if (actionName is String) {
              loadedExercises.add(
                Exercise(
                  id: actionName, // 🚨 使用名稱作為 ID
                  name: actionName,
                  part: partName,
                  icon: _getIconForPart(partName),
                ),
              );
            }
          }
        }
      });

      // 設置狀態
      setState(() {
        _allExercises = loadedExercises;

        // 1. 設置 parts 列表
        parts = _allExercises.map((e) => e.part).toSet().toList()..sort();

        // 2. 預設選中第一個部位
        _selectedPart = parts.firstWhere(
          (p) => p == '胸', // 預設選中胸部
          orElse: () => parts.first,
        );

        // 3. 初始化組數為 3
        for (var ex in _allExercises) {
          _setCountMap[ex.name] = 3;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "網路錯誤或 API 連線失敗: $e";
        _isLoading = false;
      });
    }
  }

  // 💡 優化：處理組數增減
  void _adjustSets(String exerciseName, int delta) {
    setState(() {
      int currentSets = _setCountMap[exerciseName] ?? 3;
      int newSets = currentSets + delta;
      if (newSets >= 1 && newSets <= 10) {
        // 限制組數在 1 到 10
        _setCountMap[exerciseName] = newSets;
      }
    });
  }

  // 【新增】執行加入動作
  void _addPlan(Exercise exercise) {
    final sets = _setCountMap[exercise.name]?.toString() ?? '3';

    // 呼叫回調函式，並關閉整個對話框
    widget.onAddPlan(exercise.name, sets);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        backgroundColor: Colors.black,
        content: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    if (_error != null) {
      return AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Text(
          "錯誤: $_error",
          style: const TextStyle(color: Colors.redAccent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    // 過濾出目前選中部位的動作
    final filteredExercises = _allExercises
        .where((e) => e.part == _selectedPart)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent, // 透明背景以顯示 Glassmorphism
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 800, // 增加寬度
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.9), // 深色半透明背景
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // 標題列
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '選擇 ${widget.currentDay} 動作',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // 左側：部位篩選器列表
                  Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border(
                        right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: parts.length,
                      itemBuilder: (context, index) {
                        final part = parts[index];
                        final isSelected = _selectedPart == part;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPart = part;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.cyanAccent.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: isSelected
                                  ? const Border(
                                      left: BorderSide(
                                        color: Colors.cyanAccent,
                                        width: 4,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Text(
                              part,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 右側：動作清單和加入按鈕
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = filteredExercises[index];
                        final sets = _setCountMap[exercise.name] ?? 3;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    exercise.icon,
                                    color: Colors.cyanAccent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 動作名稱和部位
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        exercise.part,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 組數調整器
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: sets > 1
                                            ? () =>
                                                  _adjustSets(exercise.name, -1)
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.remove,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        child: Text(
                                          '$sets 組',
                                          style: const TextStyle(
                                            color: Colors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: sets < 10
                                            ? () =>
                                                  _adjustSets(exercise.name, 1)
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // 一鍵加入按鈕
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _addPlan(exercise),
                                  child: const Text(
                                    '加入',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
