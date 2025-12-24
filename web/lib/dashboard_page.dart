import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'training_session_page.dart';
import 'training_schedule_page.dart';
import 'statistics_summary.dart';
import 'statistics_chart.dart'; // 假設 StatisticsPieChart 在這裡

class DashboardPage extends StatefulWidget {
  final String username;
  final String? displayName; // 🚨 接收外部傳入的暱稱

  const DashboardPage({
    super.key,
    required this.username,
    this.displayName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 數據狀態
  Map<String, int> trainingStats = {};
  List<dynamic> _todayInitialExercises = []; // 🚨 儲存今日的模板課表
  String? _fetchedNickname; // 🚨 內部獲取的暱稱 (如果外部沒傳)
  bool isLoading = true;
  String? error;

  // GlobalKey 用於呼叫進度卡片的 reloadSchedule 方法
  final GlobalKey<TrainingScheduleProgressCardState> _scheduleCardKey =
      GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // --- 輔助方法：獲取今日模板 ---
  Future<List<dynamic>> _fetchTodayInitialExercises() async {
    try {
      final data = await FirestoreService.instance.getTrainingTemplate(widget.username);
      List rawSchedule = [];
      if (data['schedule'] is List) {
        rawSchedule = data['schedule'];
      }
      final todayIndex = (DateTime.now().weekday - 1) % 7;

      if (rawSchedule.length > todayIndex) {
        return rawSchedule[todayIndex]['plans'] ?? [];
      }
    } catch (e) {
      // print("Error fetching template: $e");
    }
    return [];
  }

  // --- 數據獲取：載入主儀表板數據 ---
  Future<void> _fetchDashboardData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // 1. 獲取今日課表並儲存 (用於開始訓練按鈕)
      final initialExercisesFuture = _fetchTodayInitialExercises();
      // 2. 獲取統計數據
      final statsResultFuture = _fetchTrainingParts();
      // 3. 獲取使用者資料 (暱稱)
      final userProfileFuture = FirestoreService.instance.getUserDataByUid(widget.username);

      final results = await Future.wait([
        initialExercisesFuture,
        statsResultFuture,
        userProfileFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _todayInitialExercises = results[0] as List<dynamic>; // 🚨 儲存今日課表
        trainingStats = results[1] as Map<String, int>;
        
        // 設定暱稱
        final userProfile = results[2] as Map<String, dynamic>?;
        if (userProfile != null && userProfile.containsKey('nickname')) {
          _fetchedNickname = userProfile['nickname'];
        }
        
        isLoading = false;
      });

      // 確保進度卡片也重新載入 (它會再次呼叫模板 API)
      _scheduleCardKey.currentState?.reloadSchedule();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "儀表板載入失敗: ${e.toString()}";
          isLoading = false;
        });
      }
    }
  }

  // 獲取統計數據的輔助函式 (傳遞給 StatisticsSummary)
  Future<Map<String, dynamic>> _fetchSummaryStats(
    String startDate,
    String endDate,
  ) async {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    return await FirestoreService.instance.getUserStats(widget.username, start, end);
  }

  // 獲取訓練部位統計 (Pie Chart)
  Future<Map<String, int>> _fetchTrainingParts() async {
    return await FirestoreService.instance.getTrainingPartsStats(widget.username);
  }

  // 導航到課表編輯頁面
  void _navigateToSchedulePage() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => TrainingSchedulePage(username: widget.username),
          ),
        )
        .then((_) {
          _fetchDashboardData();
        });
  }

  // 構建訓練部位時長佔比卡片 (Pie Chart)
  Widget _buildTrainingPartsCard() {
    final hasStatsData = trainingStats.values.fold(0, (x, y) => x + y) != 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '訓練部位時長佔比',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          if (hasStatsData)
            SizedBox(
              height: 260,
              // 恢復圓餅圖的調用
              child: StatisticsPieChart(parts: trainingStats),
            )
          else
            const Text(
              "暫無訓練資料",
              style: TextStyle(fontSize: 20, color: Colors.white54),
            ),

          const SizedBox(height: 30),

          // 開始訓練按鈕 (導航到訓練執行頁面)
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingSessionPage(
                    username: widget.username,
                    // 🚨 修正：傳遞今天獲取到的初始課表
                    initialExercises: _todayInitialExercises,
                  ),
                ),
              ).then((_) => _fetchDashboardData()); // 訓練完成後重新整理 Dashboard
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.cyanAccent, width: 2),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 36),
            ),
            child: const Text(
              "開始訓練",
              style: TextStyle(
                fontSize: 20,
                color: Colors.cyanAccent,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 主體佈局 (整合所有組件)
  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Text(
          "❌ 載入錯誤: $error",
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      );
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歡迎標語
          Text(
            '歡迎回來, ${widget.displayName?.isNotEmpty == true ? widget.displayName : (_fetchedNickname ?? widget.username)}!',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),

          // 1. 合併後的「今日計畫/進度」卡片 (它會讀取模板中的當日課表)
          TrainingScheduleProgressCard(
            key: _scheduleCardKey,
            username: widget.username,
            onEditCallback: _navigateToSchedulePage,
          ),

          const SizedBox(height: 30),

          // 2. 成就總覽和趨勢切換
          StatisticsSummary(
            username: widget.username,
            fetchSummaryStats: _fetchSummaryStats,
          ),

          const SizedBox(height: 30),

          // 3. 訓練部位時長佔比餅圖
          _buildTrainingPartsCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------
// 🚨 修正類別名稱：TrainingScheduleProgressCardState
// ----------------------------------------------------------------------------------

class TrainingScheduleProgressCard extends StatefulWidget {
  final String username;
  final VoidCallback onEditCallback;

  const TrainingScheduleProgressCard({
    required this.username,
    required this.onEditCallback,
    super.key,
  });

  @override
  State<TrainingScheduleProgressCard> createState() =>
      TrainingScheduleProgressCardState();
}

class TrainingScheduleProgressCardState
    extends State<TrainingScheduleProgressCard> {
  // 結構：[{'id': 'action_name', 'name': '胸-臥推', 'sets': '3', 'is_completed': false}, ...]
  List<Map<String, dynamic>> _dailySchedule = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDailySchedule();
  }

  // 公開方法供 DashboardPage 調用
  void reloadSchedule() {
    _fetchDailySchedule();
  }

  // 💡 修正邏輯：直接從模板 API 獲取當天的排程，並與完成狀態合併。
  Future<void> _fetchDailySchedule() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 1. 獲取模板排程 (七天)
      final templateData = await FirestoreService.instance.getTrainingTemplate(widget.username);

      // 2. 獲取當日完成狀態
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final completedIds = await FirestoreService.instance.getDailyCompletion(widget.username, todayStr);

      // --- 數據處理 ---
      List rawSchedule = [];
      if (templateData['schedule'] is List) {
        rawSchedule = templateData['schedule'];
      }
      final completedItems = completedIds.toSet();

      final todayIndex = (DateTime.now().weekday - 1) % 7;
      List<Map<String, dynamic>> todayPlans = [];

      if (rawSchedule.length > todayIndex) {
        final List plans = rawSchedule[todayIndex]['plans'] ?? [];

        todayPlans = plans.whereType<Map<String, dynamic>>().map((plan) {
          final actionName = plan['action'] as String? ?? '未知動作';

          // 每個課表項目必須有唯一的 ID，這裡使用 actionName 作為 ID
          final itemId = actionName;

          return {
            'id': itemId,
            'name': actionName,
            'sets': plan['sets'] as String? ?? '0',
            'is_completed': completedItems.contains(itemId),
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _dailySchedule = todayPlans;
        });
      }

    } catch (e) {
      // 網路錯誤或 API 不存在
      if (mounted) {
        setState(() {
          _error = '網路錯誤或 API 連線失敗: $e';
          _dailySchedule = _getMockDailySchedule();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getMockDailySchedule() {
    // 💡 模擬數據 (與您的截圖匹配)
    return [
      {'id': '胸-臥推', 'name': '胸-臥推', 'sets': '3', 'is_completed': false},
      {'id': '肩-推舉', 'name': '肩-推舉', 'sets': '4', 'is_completed': true},
      {'id': '手臂-二頭彎舉', 'name': '手臂-二頭彎舉', 'sets': '3', 'is_completed': false},
    ];
  }

  Future<void> _updateCompletionStatus(
    String itemId,
    bool isCompleted,
    int index,
  ) async {
    if (_dailySchedule.isEmpty) return;

    final bool originalState = _dailySchedule[index]['is_completed'];
    setState(() {
      _dailySchedule[index]['is_completed'] = isCompleted;
    });

    try {
      // 🚨 呼叫 Firestore 更新完成狀態
      await FirestoreService.instance.setDailyCompletion(
        widget.username,
        DateTime.now().toIso8601String().substring(0, 10),
        itemId,
        isCompleted,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('網路錯誤: $e')));
      setState(() {
        _dailySchedule[index]['is_completed'] = originalState; // 回滾
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
        ),
      );
    }

    if (_error != null && _dailySchedule.isEmpty) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
          
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              '載入錯誤: $_error',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    final totalItems = _dailySchedule.length;
    final completedItems = _dailySchedule
        .where((item) => item['is_completed'])
        .length;

    if (_dailySchedule.isEmpty) {
      return Card(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              '本日無訓練項目，請去「課表」頁面設置。',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日計畫: $completedItems/$totalItems',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: widget.onEditCallback,
                  child: const Text(
                    '編輯排程',
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white.withValues(alpha: 0.1)),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailySchedule.length,
              itemBuilder: (context, index) {
                final item = _dailySchedule[index];
                final itemId = item['id'] as String;
                final itemName = item['name'] as String;
                final sets = item['sets'] as String? ?? '-';
                final isCompleted = item['is_completed'] as bool;

                return InkWell(
                  onTap: () {
                    _updateCompletionStatus(itemId, !isCompleted, index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? Colors.cyanAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              itemName,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? Colors.white38
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$sets 組',
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.white38
                                : Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
}
