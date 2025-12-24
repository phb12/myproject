// 訓練結束總結頁面，展示本次訓練成果。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_log_model.dart';
import '../models/set_log_model.dart'; // 【新增】導入 SetLog 模型
import '../services/database_helper.dart'; // 【新增】導入資料庫服務

// 【修改】將頁面改為 StatefulWidget
class TrainingSummaryPage extends StatefulWidget {
  final WorkoutLog log;
  const TrainingSummaryPage({super.key, required this.log});

  @override
  State<TrainingSummaryPage> createState() => _TrainingSummaryPageState();
}

class _TrainingSummaryPageState extends State<TrainingSummaryPage> {
  // 【新增】用來管理非同步讀取 SetLog 的 Future
  late Future<List<SetLog>> _setLogsFuture;

  @override
  void initState() {
    super.initState();
    // 在頁面初始化時，根據傳入的 WorkoutLog 的 id，去資料庫讀取對應的 SetLog 列表
    if (widget.log.id != null) {
      _setLogsFuture = DatabaseHelper.instance.getSetLogsForWorkout(widget.log.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(widget.log.completedAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練總結'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text('做得好！', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('你已完成 ${widget.log.exerciseName}', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
              const SizedBox(height: 40),

              // 【修改】將 Card 的內容改為使用 FutureBuilder
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildSummaryRow('完成時間：', formattedDate),

                      const SizedBox(height: 8),
                      // [NEW] Stats
                      _buildSummaryRow('消耗熱量：', '${widget.log.calories.toStringAsFixed(1)} kcal'),
                      const SizedBox(height: 8),
                      _buildSummaryRow('平均心率：', '${widget.log.avgHeartRate} bpm'),
                      const SizedBox(height: 8),
                      _buildSummaryRow('最高心率：', '${widget.log.maxHeartRate} bpm'),
                      const Divider(height: 24),
                      // 使用 FutureBuilder 來顯示 SetLog 列表
                      FutureBuilder<List<SetLog>>(
                        future: _setLogsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('找不到詳細的組數紀錄'));
                          }

                          final setLogs = snapshot.data!;

                          // 使用 ListView 來顯示每一組的數據
                          return ListView.separated(
                            // 讓 ListView 不會和外層的 Column 搶滾動
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: setLogs.length,
                            itemBuilder: (context, index) {
                              final setLog = setLogs[index];
                              return _buildSetRow(setLog);
                            },
                            // 每個項目之間的分隔線
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('返回主選單', style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
  
  // 【新增】一個 Helper 方法來建立每一組的顯示 UI
  Widget _buildSetRow(SetLog setLog) {
    return Row(
      children: [
        Text(
          '第 ${setLog.setNumber} 組:',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
        ),
        const Spacer(),
        Text(
          '${setLog.weight} kg',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        const Text('x', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(width: 4),
        Text(
          '${setLog.reps} 次',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 這個方法可以保留，也可以用上面的新方法取代
  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}