import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'training_session_page.dart';
import 'training_schedule_page.dart';
import 'statistics_summary.dart';
import 'main_page.dart'; // 引入 TrainingScheduleProgressCard 和 TrainingScheduleProgressCardState
import 'statistics_chart.dart'; // 假設 StatisticsPieChart 在這裡

class DashboardPage extends StatefulWidget {
  final String username;
  const DashboardPage({super.key, required this.username});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 數據狀態
  Map<String, int> trainingStats = {};
  List<dynamic> _todayInitialExercises = []; // 🚨 儲存今日的模板課表
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

      final results = await Future.wait([
        initialExercisesFuture,
        statsResultFuture,
      ]);

      setState(() {
        _todayInitialExercises = results[0] as List<dynamic>; // 🚨 儲存今日課表
        trainingStats = results[1] as Map<String, int>;
        isLoading = false;
      });

      // 確保進度卡片也重新載入 (它會再次呼叫模板 API)
      _scheduleCardKey.currentState?.reloadSchedule();
    } catch (e) {
      setState(() {
        error = "儀表板載入失敗: ${e.toString()}";
        isLoading = false;
      });
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
            '歡迎回來, ${widget.username}!',
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
