import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// 使用您提供的顏色映射 (只包含主要部位)
const Map<String, Color> partColors = {
  "胸": Colors.red,
  "背": Colors.blue,
  "腿": Colors.green,
  "肩": Colors.orange,
  "手臂": Colors.purple,
  "核心": Colors.teal,
  "其他": Colors.grey, // 確保有一個默認顏色
};

// 輔助函數：將秒數轉換為分鐘或小時的顯示格式
String formatDuration(int seconds) {
  if (seconds >= 3600) {
    double hours = seconds / 3600;
    return '${hours.toStringAsFixed(1)} 小時';
  } else if (seconds >= 60) {
    int minutes = seconds ~/ 60;
    return '$minutes 分鐘';
  } else {
    return '$seconds 秒';
  }
}

class StatisticsPieChart extends StatefulWidget {
  final Map<String, int> parts; // 接收的可能是 [動作名: 時長] 的 Map

  const StatisticsPieChart({super.key, required this.parts});

  @override
  State<StatisticsPieChart> createState() => _StatisticsPieChartState();
}

class _StatisticsPieChartState extends State<StatisticsPieChart> {
  int touchedIndex = -1; // 追蹤被觸摸的區塊索引

  // 💡 關鍵輔助函式：將動作名映射到主要部位名
  String _mapActionToMainPart(String actionName) {
    // 優先檢查完整的部位名稱
    if (actionName.contains("胸部")) return "胸";
    if (actionName.contains("背部")) return "背";
    if (actionName.contains("腿部")) return "腿";
    if (actionName.contains("肩部")) return "肩";
    if (actionName.contains("手臂")) return "手臂";
    if (actionName.contains("核心")) return "核心";
    if (actionName.contains("腹部")) return "核心"; // 腹部也歸類到核心
    if (actionName.contains("臀部")) return "腿"; // 臀部歸類到腿
    if (actionName.contains("三頭")) return "手臂"; // 三頭歸類到手臂

    // 接著檢查單字開頭 (例如: "胸-臥推" -> "胸")
    for (final mainPart in partColors.keys) {
      if (actionName.startsWith(mainPart) && mainPart != '其他') {
        return mainPart;
      }
    }
    // 預設將無法匹配的項目歸類為 '其他'
    return '其他';
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 步驟 1：處理原始數據，將具體動作彙總到主要部位
    Map<String, int> groupedParts = {};
    int totalDuration = 0;

    widget.parts.forEach((actionName, duration) {
      // 確保 duration 是有效的正數
      if (duration > 0) {
        final mainPart = _mapActionToMainPart(actionName);
        groupedParts[mainPart] = (groupedParts[mainPart] ?? 0) + duration;
        totalDuration += duration;
      }
    });

    // 刪除 '其他' 數據，除非它真的有時長 (可選，但讓圖更乾淨)
    if (groupedParts['其他'] == 0) {
      groupedParts.remove('其他');
    }

    if (totalDuration == 0) {
      return const Center(
        child: Text(
          "無效的訓練數據",
          style: TextStyle(color: Colors.white),
        ), // 改為黑色，避免在白背景下消失
      );
    }

    // 獲取數據鍵 (部位名稱列表)
    final List<String> partNames = groupedParts.keys.toList();

    // 🚨 步驟 2：生成 PieChart 區塊
    final List<PieChartSectionData> sections = partNames.asMap().entries.map((
      entry,
    ) {
      final int index = entry.key;
      final String partName = entry.value;
      final int duration = groupedParts[partName]!; // 使用彙總後的數據

      final bool isTouched = index == touchedIndex;
      final double radius = isTouched ? 90 : 80;
      final double percentage = (duration / totalDuration) * 100;
      final Color color = partColors[partName] ?? partColors['其他']!;

      return PieChartSectionData(
        color: color,
        value: duration.toDouble(), // 值必須是 double
        title:
            percentage >
                3.0 // 只有超過 3% 才顯示百分比，避免擁擠
            ? '${percentage.toStringAsFixed(1)}%'
            : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: isTouched ? Colors.black : Colors.white,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 2),
          ],
        ),
        badgeWidget: isTouched ? _buildBadge(partName, duration, color) : null,
        badgePositionPercentageOffset: 1.1,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 4,
                centerSpaceRadius: 0,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 24), // 增加間距
          // 🚨 步驟 3：圖例說明強制顯示所有主要部位 (即使為零)
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            // 💡 迭代 partColors 的鍵 (即所有的主要部位名稱)
            children: partColors.keys.where((p) => p != '其他').map((partKey) {
              final duration = groupedParts[partKey] ?? 0;
              return _buildIndicator(
                partKey,
                partColors[partKey]!,
                duration, // 傳入實際時長
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 輔助組件：圖例
  Widget _buildIndicator(String title, Color color, int durationSeconds) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          // 顯示時長，如果為 0 則顯示 (0 秒)
          '$title (${formatDuration(durationSeconds)})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // 輔助組件：觸摸時的詳細徽章
  Widget _buildBadge(String title, int durationSeconds, Color color) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          '$title: ${formatDuration(durationSeconds)}', // 徽章顯示完整時長
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
