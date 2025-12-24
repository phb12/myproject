import 'package:flutter/material.dart';
import 'dart:async';
import 'services/firestore_service.dart';
import 'models/workout_log_model.dart';
import 'models/exercise_model.dart'; // For BodyPart enum

// -----------------------------------------------------
// 訓練執行頁面 (TrainingSessionPage)
// -----------------------------------------------------

class TrainingSessionPage extends StatefulWidget {
  final String username;
  final List<dynamic> initialExercises;

  const TrainingSessionPage({
    super.key,
    required this.username,
    required this.initialExercises,
  });

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  // 🚨 修正：將硬編碼列表改為動態載入，並使用 FutureBuilder 處理載入狀態
  Map<String, List<String>> muscleGroupExercises = {};
  bool _isDataLoading = true;
  String? _dataError;

  // 狀態變數
  String? selectedMuscleGroup;
  List<String> myExercises = [];
  Map<String, int> setsOfExercise = {};
  Map<String, int> totalSecondsOfThatExercise = {};

  // 單組紀錄 (key: 動作名稱, value: List<Map<String, dynamic>> 每個 Set 的紀錄)
  Map<String, List<Map<String, dynamic>>> setRecords = {};

  // 輸入控制器 (僅用於配置模式的自訂新增)
  final TextEditingController _customExController = TextEditingController();

  int restSeconds = 60;
  bool isStarted = false;
  bool isResting = false;
  int currentExerciseIdx = 0;
  int currentSet = 1;
  int restTimeLeft = 0;
  Timer? restTimer;
  Stopwatch setStopwatch = Stopwatch();
  Timer? setTimer;

  @override
  void initState() {
    super.initState();
    // 🚨 步驟 1: 先載入動作清單，再載入初始課表
    _loadAllData();
  }

  // 🚨 新增：從 API 載入完整的動作清單
  Future<void> _fetchExerciseList() async {
    try {
      final data = await FirestoreService.instance.getAllExercises();
      muscleGroupExercises = data;
    } catch (e) {
      _dataError = "網路錯誤，無法獲取動作清單: $e";
    }
  }

  Future<void> _loadAllData() async {
    await _fetchExerciseList();
    if (_dataError == null) {
      _loadInitialExercises();
    }
    setState(() {
      _isDataLoading = false;
    });
  }

  // 載入預載課表邏輯
  void _loadInitialExercises() {
    if (widget.initialExercises.isNotEmpty && myExercises.isEmpty) {
      _loadPlans(widget.initialExercises);
    }
  }

  // 核心：將 List<Map> 載入到 myExercises 和 setsOfExercise
  void _loadPlans(List<dynamic> plans) {
    setState(() {
      // 清空舊數據
      myExercises.clear();
      setsOfExercise.clear();
      totalSecondsOfThatExercise.clear();
      setRecords.clear();

      // 載入新數據
      for (final item in plans) {
        if (item is Map<String, dynamic>) {
          final action = item['action'] as String? ?? '未知動作';
          final setsValue = int.tryParse(item['sets'].toString()) ?? 3;

          if (!myExercises.contains(action)) {
            myExercises.add(action);
            setsOfExercise[action] = setsValue;
            totalSecondsOfThatExercise[action] = 0;
            setRecords[action] = [];
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _customExController.dispose();
    restTimer?.cancel();
    setTimer?.cancel();
    setStopwatch.stop();
    super.dispose();
  }

  // --- 配置模式動作 ---

  void onMuscleGroupTap(String muscle) {
    if (isStarted) return;
    setState(() {
      selectedMuscleGroup = muscle;
      _customExController.clear();
    });
  }

  void addExercise(String ex) {
    if (!myExercises.contains(ex) && !isStarted) {
      setState(() {
        myExercises.add(ex);
        setsOfExercise[ex] = 3;
        totalSecondsOfThatExercise[ex] = 0;
        setRecords[ex] = [];
      });
    }
  }

  void removeExercise(int idx) {
    if (!isStarted && myExercises.isNotEmpty) {
      setState(() {
        String removed = myExercises.removeAt(idx);
        setsOfExercise.remove(removed);
        totalSecondsOfThatExercise.remove(removed);
        setRecords.remove(removed);
      });
    }
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (isStarted) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = myExercises.removeAt(oldIndex);
      myExercises.insert(newIndex, item);
    });
  }

  // 🚨 載入指定課表的邏輯 (保持不變)
  Future<void> _loadTemplateSchedule(int dayIndex) async {
    try {
      final data = await FirestoreService.instance.getTrainingTemplate(widget.username);
      final List rawSchedule = data['schedule'] ?? [];

      if (rawSchedule.length > dayIndex) {
        final dayData = rawSchedule[dayIndex];
        final List plans = dayData['plans'] ?? [];

        // 載入課表
        _loadPlans(plans.cast<dynamic>());

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已載入 ${dayData['day']} 的課表')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('課表數據不完整，無法載入')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('載入課表失敗，請檢查 API 連線')));
      }
    }
  }

  // 🚨 彈出課表選擇對話框 (保持不變)
  void _showLoadTemplateDialog() {
    const List<String> weekDays = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text("選擇載入哪天課表", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: weekDays.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  weekDays[index],
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.cyanAccent,
                  size: 16,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _loadTemplateSchedule(index);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("取消", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // 🚨 新增：單獨的 API 呼叫，用於標記課表項目完成
  Future<void> _markScheduleItemComplete(
    String itemId,
    bool isCompleted,
  ) async {
    await FirestoreService.instance.setDailyCompletion(
      widget.username,
      DateTime.now().toIso8601String().substring(0, 10),
      itemId,
      isCompleted,
    );
  }

  // --- 執行模式動作 (Set 完成與儲存) ---

  void startTraining() {
    if (myExercises.isEmpty || setsOfExercise.isEmpty) return;
    setState(() {
      isStarted = true;
      currentExerciseIdx = 0;
      currentSet = 1;
      isResting = false;
    });
    setStopwatch.reset();
    setStopwatch.start();
    _startSetTimer();
  }

  void _startSetTimer() {
    setTimer?.cancel();
    setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isStarted || isResting) {
        setTimer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  // 🚨 修正 `finishTrainingAndSaveLog`：儲存後導航回上一頁 (Dashboard)
  Future<void> finishTrainingAndSaveLog() async {
    final today = DateTime.now();

    String muscleGroupOf(String ex) {
      // 🚨 修正：使用載入的 muscleGroupExercises 進行判斷
      for (var entry in muscleGroupExercises.entries) {
        if (entry.value.contains(ex)) return entry.key;
      }
      final parts = ex.split('-');
      return parts.isNotEmpty ? parts[0].trim() : "其他";
    }

    // 儲存每項訓練紀錄
    for (var ex in myExercises) {
      final durationSec = totalSecondsOfThatExercise[ex] ?? 0;
      final partName = muscleGroupOf(ex);
      
      // Map part name to BodyPart enum
      BodyPart bodyPart = BodyPart.shoulders;
      try {
        // Simple mapping based on Chinese names
        if (partName.contains('胸')) bodyPart = BodyPart.chest;
        else if (partName.contains('背')) bodyPart = BodyPart.back;
        else if (partName.contains('腿') || partName.contains('臀')) bodyPart = BodyPart.legs;
        else if (partName.contains('肩')) bodyPart = BodyPart.shoulders;
        else if (partName.contains('手')) bodyPart = BodyPart.arms;
        else if (partName.contains('核') || partName.contains('腹')) bodyPart = BodyPart.core;
        else bodyPart = BodyPart.cardio; // Fallback or add cardio to enum if needed
      } catch (e) {}

      final log = WorkoutLog(
        exerciseName: ex,
        totalSets: setsOfExercise[ex] ?? 0,
        completedAt: today,
        bodyPart: bodyPart,
        account: widget.username,
        duration: durationSec,
        setsDetail: setRecords[ex] ?? [],
      );

      await FirestoreService.instance.saveWorkoutLog(log);
    }

    if (mounted) {
      // 導航回上一頁 (Dashboard)，觸發 Dashboard 刷新
      Navigator.pop(context);
    }
  }

  // 🚨 修正 `finishSetOrRest`：檢查是否是該動作的最後一組，如果是，則自動打勾
  void finishSetOrRest() async {
    if (isResting) return;

    setStopwatch.stop();
    setTimer?.cancel();

    final result = await _showSetInputModal();

    if (result != null) {
      final ce = myExercises[currentExerciseIdx];

      // 3a. 儲存 Set 詳情
      setRecords.update(ce, (list) {
        list.add({
          'set': currentSet,
          'duration_sec': setStopwatch.elapsed.inSeconds,
          'weight': result['weight'],
          'reps': result['reps'],
        });
        return list;
      }, ifAbsent: () => []);

      // 3b. 總時長計算
      int elapsedSecs = setStopwatch.elapsed.inSeconds;
      totalSecondsOfThatExercise[ce] =
          (totalSecondsOfThatExercise[ce] ?? 0) + elapsedSecs;

      // 💡 關鍵修正：檢查是否為最後一組
      final nextSet = currentSet + 1;
      final totalSets = setsOfExercise[ce] ?? 3;

      if (nextSet > totalSets) {
        final itemId = ce;
        await _markScheduleItemComplete(itemId, true); // 自動標記該動作完成
      }

      // 3c. 進入休息
      setState(() {
        isResting = true;
        restTimeLeft = restSeconds;
      });

      restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          restTimeLeft--;
          if (restTimeLeft <= 0) {
            restTimer?.cancel();
            nextSetOrExercise();
          }
        });
      });
    } else {
      // 4. 如果用戶取消輸入，則恢復計時
      setStopwatch.start();
      _startSetTimer();
    }
  }

  void nextSetOrExercise() {
    setStopwatch.reset();
    setStopwatch.start();
    _startSetTimer();
    setState(() {
      isResting = false;
      final ce = myExercises[currentExerciseIdx];
      if (currentSet < (setsOfExercise[ce] ?? 3)) {
        currentSet++;
      } else {
        if (currentExerciseIdx < myExercises.length - 1) {
          currentExerciseIdx++;
          currentSet = 1;
        } else {
          isStarted = false;
          setTimer?.cancel();
          setStopwatch.stop();
          finishTrainingAndSaveLog();
        }
      }
    });
  }

  // 🚨 組數/重量輸入模態框 (保持不變)
  Future<Map<String, dynamic>?> _showSetInputModal() async {
    final repsCtrl = TextEditingController(text: '0');
    final weightCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    // 定義輸入框風格
    const inputStyle = TextStyle(color: Colors.white, fontSize: 18);
    InputDecoration inputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.cyanAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      fillColor: Colors.white.withValues(alpha: 0.1),
      filled: true,
      isDense: true,
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "完成 Set",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "第 $currentSet 組已用時 $formattedElapsed",
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                style: inputStyle,
                decoration: inputDecoration("次數 (Reps)"),
                validator: (v) =>
                    (int.tryParse(v ?? '0') ?? 0) <= 0 ? "次數必須大於 0" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: inputStyle,
                decoration: inputDecoration("重量 (kg)"),
                validator: (v) => (double.tryParse(v ?? '0.0') ?? 0.0) <= 0
                    ? "重量必須大於 0"
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null), // 取消，返回 null
            child: const Text(
              "取消並恢復計時",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop({
                  'weight': double.tryParse(weightCtrl.text) ?? 0.0,
                  'reps': int.tryParse(repsCtrl.text) ?? 0,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "確定完成",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Sets Adjuster 和 Formatted Elapsed 保持不變) ...
  Widget setsAdjuster(String ex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: !isStarted && (setsOfExercise[ex]! > 1)
                ? () {
                    setState(() {
                      setsOfExercise[ex] = setsOfExercise[ex]! - 1;
                    });
                  }
                : null,
            child: Icon(
              Icons.remove_circle_outline,
              color: Colors.cyanAccent.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${setsOfExercise[ex] ?? 3} 組",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: !isStarted
                ? () {
                    setState(() {
                      setsOfExercise[ex] = setsOfExercise[ex]! + 1;
                    });
                  }
                : null,
            child: const Icon(
              Icons.add_circle_outline,
              color: Colors.cyanAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String get formattedElapsed {
    final seconds = setStopwatch.elapsed.inSeconds % 60;
    final minutes = setStopwatch.elapsed.inMinutes % 60;
    final hours = setStopwatch.elapsed.inHours;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 修正：在數據載入中，顯示載入指示器
    if (_isDataLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }
    if (_dataError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            '載入錯誤: $_dataError',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // 正常渲染配置頁面
    final currentExercises = selectedMuscleGroup == null
        ? <String>[]
        : (muscleGroupExercises[selectedMuscleGroup!] ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("訓練中", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isStarted
          ? Center(child: _trainingContent())
          : _buildConfigPage(currentExercises),
    );
  }

  Widget _buildConfigPage(List<String> currentExercises) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          // 頂部：休息時間設定
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  "組間休息（秒）",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.cyanAccent,
                    size: 28,
                  ),
                  onPressed: restSeconds > 10
                      ? () => setState(() => restSeconds -= 5)
                      : null,
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    "$restSeconds",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.cyanAccent,
                    size: 28,
                  ),
                  onPressed: () => setState(() => restSeconds += 5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 底部：動作選擇和已選課表
          Expanded(
            child: Row(
              children: <Widget>[
                // 左欄：動作選擇與自訂輸入 (佔比 40%)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            "選擇/新增動作",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          // 載入課表按鈕
                          IconButton(
                            icon: const Icon(
                              Icons.calendar_month,
                              color: Colors.cyanAccent,
                            ),
                            onPressed: _showLoadTemplateDialog,
                            tooltip: "載入已存課表",
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 部位選擇 Chip
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: 8,
                          children: muscleGroupExercises.keys
                              .map(
                                (muscle) => ChoiceChip(
                                  label: Text(
                                    muscle,
                                    style: TextStyle(
                                      color: selectedMuscleGroup == muscle
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  selected: selectedMuscleGroup == muscle,
                                  selectedColor: Colors.cyanAccent,
                                  backgroundColor: Colors.grey[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: selectedMuscleGroup == muscle
                                          ? Colors.cyanAccent
                                          : Colors.white.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  onSelected: (_) => onMuscleGroupTap(muscle),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 預設動作列表
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ListView.builder(
                            itemCount: selectedMuscleGroup != null
                                ? muscleGroupExercises[selectedMuscleGroup!]
                                          ?.length ??
                                      0
                                : 0,
                            itemBuilder: (ctx, idx) {
                              final ex =
                                  muscleGroupExercises[selectedMuscleGroup!]![idx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  ex,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.cyanAccent,
                                  ),
                                  onPressed: () => addExercise(ex),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 自訂新增輸入框 (保持在底部)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _customExController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "自訂新增動作",
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                String txt = _customExController.text.trim();
                                if (txt.isNotEmpty) {
                                  addExercise(txt);
                                  _customExController.clear();
                                }
                              },
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
                              ),
                              child: const Text(
                                "新增",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // 右欄：已選課表調整 (佔比 65%)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.initialExercises.isNotEmpty
                              ? "今日預載課表"
                              : "目前已選訓練",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Expanded(
                          child: myExercises.isEmpty
                              ? Center(
                                  child: Text(
                                    widget.initialExercises.isNotEmpty
                                        ? "預載課表為空，請在左側添加動作。"
                                        : "請在左側選擇動作加入。",
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ReorderableListView(
                                  onReorder: reorderExercises,
                                  children: myExercises
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => Container(
                                          key: ValueKey(entry.value),
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 4,
                                                ),
                                            leading: const Icon(
                                              Icons.drag_indicator,
                                              color: Colors.white38,
                                            ),
                                            title: Text(
                                              entry.value,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                            subtitle: setsAdjuster(entry.value),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  removeExercise(entry.key),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),

                        // 開始訓練按鈕 (保持在底部右側)
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text(
                              "開始訓練",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: startTraining,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 8,
                              shadowColor: Colors.cyanAccent.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingContent() {
    final ce = myExercises.isNotEmpty ? myExercises[currentExerciseIdx] : "";
    final totalSet = setsOfExercise[ce] ?? 0;

    if (!isResting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 頂部進度指示
            Text(
              "目前訓練",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ce,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // 圓形計時器
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.3),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "第 $currentSet / $totalSet 組",
                    style: const TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formattedElapsed,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyanAccent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // 結束按鈕
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: finishSetOrRest, // 點擊時彈出對話框
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 10,
                ),
                child: const Text(
                  "結束這一組",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        color: Colors.redAccent.withValues(alpha: 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.timer, size: 80, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text(
              "組間休息",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "$restTimeLeft",
              style: const TextStyle(
                fontSize: 120,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 200,
              height: 60,
              child: OutlinedButton(
                onPressed: () {
                  restTimer?.cancel();
                  nextSetOrExercise();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "提早結束休息",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
