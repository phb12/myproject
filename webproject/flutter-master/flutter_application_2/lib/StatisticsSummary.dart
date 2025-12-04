import 'package:flutter/material.dart';
import 'dart:async';
// 雖然您換成了 CustomPaint，但可能保留了 fl_chart 的 import

// 定義週期選項
enum TimePeriod { week, month }

// 傳遞一個回調函式來更新 Dashboard 的數據
typedef FetchStatsCallback =
    Future<Map<String, dynamic>> Function(String, String);

class StatisticsSummary extends StatefulWidget {
  final String username;
  final FetchStatsCallback fetchSummaryStats;

  const StatisticsSummary({
    super.key,
    required this.username,
    required this.fetchSummaryStats,
  });

  @override
  State<StatisticsSummary> createState() => _StatisticsSummaryState();
}

class _StatisticsSummaryState extends State<StatisticsSummary> {
  // 狀態
  TimePeriod _selectedPeriod = TimePeriod.week;
  bool _isLoading = false;

  // 數據
  int totalDays = 0;
  int totalDuration = 0; // 分鐘
  int totalCalories = 0; // 🚨 新增：總熱量 (大卡)
  Map<String, int> dailyDurations = {}; // {日期: 分鐘數}

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // 🚨 新增：估算熱量消耗的簡化邏輯 (7 大卡/分鐘)
  int _estimateCalories(int totalDurationMinutes) {
    const double caloriesPerMinute = 7.0;
    return (totalDurationMinutes * caloriesPerMinute).round();
  }

  // 根據選擇的週期重新載入數據
  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      totalDays = 0;
      totalDuration = 0;
      totalCalories = 0; // 🚨 重置熱量
      dailyDurations = {};
    });

    final now = DateTime.now();
    DateTime startDate;

    if (_selectedPeriod == TimePeriod.week) {
      startDate = now.subtract(const Duration(days: 6));
    } else {
      // 30天
      startDate = now.subtract(const Duration(days: 29));
    }

    final startDateStr = startDate.toIso8601String().substring(0, 10);
    final endDateStr = now.toIso8601String().substring(0, 10);

    try {
      final summaryData = await widget.fetchSummaryStats(
        startDateStr,
        endDateStr,
      );

      if (!mounted) return;
      setState(() {
        totalDays = summaryData['total_days'] ?? 0;
        totalDuration = summaryData['total_duration_minutes'] ?? 0;

        // 🚨 計算熱量
        totalCalories = _estimateCalories(totalDuration);

        // 確保 Map 的值被正確轉換為 int
        dailyDurations =
            (summaryData['daily_durations'] as Map<String, dynamic>)
                .cast<String, int>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        print("Error loading summary stats: $e");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 核心成就數據 (簡潔總覽)
          const Text(
            '訓練總結',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('訓練天數', '$totalDays 天', Colors.blue),
              _buildStatItem('總時長', '$totalDuration 分鐘', Colors.redAccent),
              _buildStatItem(
                '熱量消耗',
                '$totalCalories 大卡',
                Colors.orange,
              ), // 🚨 新增熱量顯示
            ],
          ),
          const Divider(height: 30),

          // 2. 成長曲線標題與切換器
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '每日時長趨勢',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              // 💡 切換按鈕
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IntrinsicWidth(
                  child: Row(
                    children: [
                      _buildPeriodButton(TimePeriod.week, '7 天'),
                      _buildPeriodButton(TimePeriod.month, '30 天'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. 趨勢圖表顯示區
          SizedBox(
            height: 150,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : dailyDurations.isEmpty || totalDuration == 0
                ? const Center(
                    // 🚨 判斷條件增加 totalDuration == 0 以涵蓋所有數據皆為零的情況
                    child: Text(
                      "該週期訓練時長皆為零。",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _buildGrowthChart(),
          ),
        ],
      ),
    );
  }

  // 輔助函式：切換按鈕 (保持不變)
  Widget _buildPeriodButton(TimePeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return TextButton(
      onPressed: () {
        if (!isSelected) {
          setState(() {
            _selectedPeriod = period;
          });
          _loadStats();
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: isSelected ? Colors.cyanAccent : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(60, 30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // 輔助函式：統計項目顯示 (保持不變)
  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }

  // 🚨 繪製圖表邏輯 (CustomPaint，保持不變)
  Widget _buildGrowthChart() {
    // ... 繪圖邏輯保持不變
    final sortedDates = dailyDurations.keys.toList()..sort();
    final numDays = _selectedPeriod == TimePeriod.week ? 7 : 30;

    final List<double> values = [];
    final List<String> dateLabels = [];

    final now = DateTime.now();
    DateTime startDate = _selectedPeriod == TimePeriod.week
        ? now.subtract(const Duration(days: 6))
        : now.subtract(const Duration(days: 29));

    double maxValue = 0;

    for (int i = 0; i < numDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);

      final duration = dailyDurations[dateStr]?.toDouble() ?? 0.0;

      values.add(duration);

      if (i == 0 ||
          i == numDays - 1 ||
          (_selectedPeriod == TimePeriod.week && i == 3) ||
          (_selectedPeriod == TimePeriod.month && i % 10 == 0)) {
        final monthDay = dateStr.substring(5).replaceFirst('-', '/');
        dateLabels.add(monthDay);
      } else {
        dateLabels.add('');
      }

      if (duration > maxValue) {
        maxValue = duration;
      }
    }

    if (maxValue == 0) {
      return const Center(
        child: Text("該週期訓練時長皆為零。", style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: 30.0,
        right: 10,
        bottom: 20,
        top: 10,
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: LineChartPainter(values, maxValue),
              child: Container(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dateLabels.map((label) {
              return Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------
// LineChartPainter 類別 (保持不變，因為它是 CustomPaint 的核心)
// -----------------------------------------------------

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;

  LineChartPainter(this.data, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final double width = size.width;
    final double height = size.height;
    final double stepX = width / (data.length - 1);

    final Paint linePaint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final Path path = Path();

    final Paint areaPaint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = height - (data[i] / maxValue) * height;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final areaPath = Path.from(path);
    areaPath.lineTo(points.last.dx, height);
    areaPath.lineTo(points.first.dx, height);
    areaPath.close();

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, linePaint);

    final Paint dotPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;

    for (final point in points) {
      if ((height - point.dy) > 0) {
        canvas.drawCircle(point, 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}
