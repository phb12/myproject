import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'models/workout_log_model.dart';
import 'models/exercise_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// 保持顏色映射不變，用於日曆標記
const Map<String, Color> muscleColorMap = {
  "胸": Colors.redAccent,
  "背": Colors.blueAccent,
  "腿": Colors.greenAccent,
  "肩": Colors.orangeAccent,
  "手臂": Colors.purpleAccent,
  "核心": Colors.tealAccent,
  "其他": Colors.white24,
};

// 保持部位查找邏輯不變
String? getMuscleOfRecord(String record) {
  try {
    final recJson = json.decode(record);
    // 優先使用後端直接判斷的 'part' 欄位
    final part = recJson['part'] ?? '';
    if (part.isNotEmpty) return part;

    // 否則 fallback 到 exercise 名稱判斷
    final exercise = recJson['exercise'] ?? '';
    for (final part in muscleColorMap.keys) {
      if (exercise.startsWith(part)) return part;
    }
    return null;
  } catch (_) {
    // 如果 record 不是合法的 JSON (可能是手動輸入的舊格式)
    for (final part in muscleColorMap.keys) {
      if (record.startsWith(part)) return part;
    }
    return null;
  }
}

class TrainingRecordPage extends StatefulWidget {
  final String username;
  const TrainingRecordPage({super.key, required this.username});

  @override
  State<TrainingRecordPage> createState() => _TrainingRecordPageState();
}

class _TrainingRecordPageState extends State<TrainingRecordPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _records = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _fetchMonthRecords(_focusedDay);
  }

  DateTime clearTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // 一次抓一整月 (邏輯保持不變)
  // 一次抓一整月 (邏輯保持不變)
  Future<void> _fetchMonthRecords(DateTime month) async {
    // 雖然函式名稱是 fetchMonth，但我們從 Firestore 抓取所有紀錄後在本地篩選
    // 這樣可以減少讀取次數 (如果量不大) 或者應該在 Service 實作範圍查詢
    // 這裡為了簡化，我們抓取所有備份的紀錄 (fetchBackedUpWorkoutLogs 已經實作)
    
    try {
      final allLogs = await FirestoreService.instance.fetchBackedUpWorkoutLogs(widget.username);
      
      Map<DateTime, List<Map<String, dynamic>>> monthMap = {};
      
      for (final log in allLogs) {
        // log 是 WorkoutLog 物件
        final d = log.completedAt;
        // 篩選月份
        if (d.year == month.year && d.month == month.month) {
            final key = clearTime(d);
            monthMap.putIfAbsent(key, () => []);
            
            final recordMap = {
              'exercise': log.exerciseName,
              'total_sets': log.totalSets,
              'total_duration': log.duration,
              'sets_detail': log.setsDetail,
              'part': log.bodyPart.name, // Enum name
            };
            
            monthMap[key]!.add({'id': log.id, 'record': recordMap});
        }
      }
      
      setState(() {
        _records = monthMap;
      });
    } catch (e) {
      // print("Error fetching records: $e");
    }
  }

  // 輔助函式：新增紀錄
  Future<void> _addRecord(DateTime day, Map<String, dynamic> recordMap) async {
    String? part;
    final exercise = recordMap['exercise'] ?? '';
    for (final p in muscleColorMap.keys) {
      if (exercise.toString().startsWith(p)) {
        part = p;
        break;
      }
    }
    if (part != null) recordMap['part'] = part;

    // 建立 WorkoutLog 物件
    // 注意：BodyPart enum 需要匹配。這裡簡單映射或預設
    BodyPart bodyPartEnum = BodyPart.other;
    // 簡單映射邏輯 (可擴充)
    if (part == '胸') bodyPartEnum = BodyPart.chest;
    else if (part == '背') bodyPartEnum = BodyPart.back;
    else if (part == '腿') bodyPartEnum = BodyPart.legs;
    else if (part == '肩') bodyPartEnum = BodyPart.shoulders;
    else if (part == '手臂') bodyPartEnum = BodyPart.arms;
    else if (part == '核心') bodyPartEnum = BodyPart.core;

    final log = WorkoutLog(
      exerciseName: exercise,
      totalSets: recordMap['total_sets'] ?? 0,
      completedAt: day, // 使用選定的日期
      bodyPart: bodyPartEnum,
      account: widget.username, // 這裡應該是 uid
      duration: recordMap['total_duration'] ?? 0,
    );

    try {
      await FirestoreService.instance.saveWorkoutLog(log);
      await _fetchMonthRecords(_focusedDay);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('新增失敗: $e')));
    }
  }

  // 輔助函式：刪除單筆紀錄
  Future<void> _deleteRecord(DateTime day, String id) async { // ID 改為 String
    try {
      await FirestoreService.instance.deleteWorkoutLog(id);
      await _fetchMonthRecords(_focusedDay);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
    }
  }

  // 輔助函式：刪除當日所有紀錄
  Future<void> _deleteAllRecords(DateTime day) async {
    try {
      await FirestoreService.instance.deleteWorkoutLogsByDate(widget.username, day);
      await _fetchMonthRecords(_focusedDay);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
    }
  }

  // 輔助函式：將秒數轉換為可讀格式
  String _formatDuration(dynamic seconds) {
    if (seconds == null) return 'N/A';
    final int sec = seconds is int
        ? seconds
        : int.tryParse(seconds.toString()) ?? 0;

    if (sec >= 3600) {
      return '${(sec / 3600).toStringAsFixed(1)} hr';
    } else if (sec >= 60) {
      return '${(sec / 60).toStringAsFixed(0)} min';
    } else {
      return '$sec sec';
    }
  }

  // 💡 修正輔助函式：解析 Set 詳情，找出最大重量和次數
  String _getSetsSummary(Map recordMap) {
    final List setDetails = recordMap['sets_detail'] ?? [];
    final int totalSets = recordMap['total_sets'] ?? 0;
    final int durationSecs = recordMap['total_duration'] ?? 0;

    String durationString = _formatDuration(durationSecs);

    if (setDetails.isEmpty) {
      // 處理沒有詳細組數紀錄的項目 (如手動輸入)
      return '$totalSets 組 | $durationString';
    }

    // 計算最大重量和最大次數
    double maxWeight = 0.0;
    int maxReps = 0;
    int completedSets = 0;

    for (var s in setDetails) {
      final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
      final reps = (s['reps'] as num?)?.toInt() ?? 0;

      if (weight > 0 || reps > 0) {
        completedSets++;
      }
      if (weight > maxWeight) maxWeight = weight;
      if (reps > maxReps) maxReps = reps;
    }

    // 輸出格式：[完成組數]/[總組數] | [Max Weight] kg x [Max Reps] | [總時長]
    return '$completedSets/$totalSets 組 | ${maxWeight.toStringAsFixed(1)} kg x $maxReps 次 | $durationString';
  }

  // 獲取 TableCalendar 的事件列表
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _records[clearTime(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = clearTime(_selectedDay ?? DateTime.now());
    // 🚨 修正：確保 dayRecords 獲取的是 Map 而不是 String
    final dayRecords = _records[selectedDay] ?? [];

    // 💡 風格優化：Scaffold 主背景
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("訓練紀錄", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. 日曆 (TableCalendar)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[900], // 日曆背景
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TableCalendar(
              locale: 'zh_CN', // 設置中文區域，如果需要的話
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => clearTime(day) == selectedDay,
              onDaySelected: (selectedDayTmp, focusedDay) {
                setState(() {
                  _selectedDay = clearTime(selectedDayTmp);
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _fetchMonthRecords(focusedDay);
                setState(() => _focusedDay = focusedDay);
              },
              // 獲取事件 (訓練紀錄)
              eventLoader: _getEventsForDay,

              // 💡 風格優化：日曆外觀主題
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.grey),
                weekendStyle: TextStyle(color: Colors.redAccent),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.white70),
                outsideTextStyle: const TextStyle(color: Colors.grey),
                selectedDecoration: const BoxDecoration(
                  color: Colors.cyanAccent,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                // 訓練標記圓點 (多色)
                markerBuilder: (context, date, events) {
                  // 🚨 修正：確保 events 是 Map<String, dynamic> 的列表
                  final List<Map<String, dynamic>> eventList = events
                      .whereType<Map<String, dynamic>>()
                      .toList();

                  final muscleSet = <String>{};
                  for (final e in eventList) {
                    // 這裡的 e['record'] 已經是 Map
                    final recordMap = e['record'];
                    final recordString = recordMap['exercise'] as String? ?? '';
                    final m = getMuscleOfRecord(recordString);
                    if (m != null) muscleSet.add(m);
                  }

                  if (muscleSet.isEmpty) return null;

                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: muscleSet
                          .take(4) // 最多顯示 4 個點
                          .map(
                            (m) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: muscleColorMap[m] ?? Colors.white24,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. 紀錄列表標題與操作
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${selectedDay.year}-${selectedDay.month}-${selectedDay.day} 的訓練紀錄 (${dayRecords.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                // 全部刪除按鈕
                if (dayRecords.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            "全部刪除？",
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            "確定要刪除當日所有訓練紀錄嗎？",
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                "取消",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text("全部刪除"),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await _deleteAllRecords(selectedDay);
                      }
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      "全部刪除",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. 訓練紀錄列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: dayRecords.length,
              itemBuilder: (context, index) {
                final rec = dayRecords[index];
                final recordMap = rec['record'] as Map? ?? {};
                final id = rec['id'];

                final String name = recordMap['exercise'] ?? '未知動作';

                // 🚨 修正：使用 _getSetsSummary 獲取詳細的組數和重量信息
                final String setsSummary = _getSetsSummary(recordMap);
                final String part =
                    recordMap['part'] ?? getMuscleOfRecord(name) ?? '未知';

                final Color partColor = muscleColorMap[part] ?? Colors.white24;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: partColor, width: 4),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 12, right: 8),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 🚨 修正：顯示詳細的組數、重量和次數總結
                    subtitle: Text(
                      setsSummary,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    leading: Icon(Icons.circle, color: partColor, size: 10),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text(
                              "刪除這項訓練？",
                              style: TextStyle(color: Colors.white),
                            ),
                            content: Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(
                                  "取消",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text("刪除"),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && id != null) {
                          await _deleteRecord(selectedDay, id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. 加入訓練紀錄按鈕
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                String exercise = '';
                String sets = '0';
                String duration = '0';
                final formKey = GlobalKey<FormState>();

                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      "新增訓練紀錄",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            autofocus: true,
                            onChanged: (v) => exercise = v,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: '訓練內容(部位-動作)',
                              labelStyle: TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? '必須輸入訓練內容' : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            onChanged: (v) => sets = v,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: '組數',
                              labelStyle: TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                (v == null || int.tryParse(v) == null)
                                ? '必須是數字'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            onChanged: (v) => duration = v,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: '總時長(秒)',
                              labelStyle: TextStyle(color: Colors.grey),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                (v == null || int.tryParse(v) == null)
                                ? '必須是數字'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text(
                          "取消",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            // 🚨 修正：確保 sets_detail 傳遞空列表，因為這裡沒有輸入 PR/Reps
                            Navigator.pop(ctx, {
                              'exercise': exercise,
                              'total_sets': int.tryParse(sets) ?? 0,
                              'total_duration':
                                  int.tryParse(duration) ??
                                  0, // 使用 total_duration
                              'sets_detail': [],
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("新增"),
                      ),
                    ],
                  ),
                );
                if (result != null &&
                    result['exercise'].toString().trim().isNotEmpty) {
                  await _addRecord(selectedDay, result);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                "加入訓練紀錄",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
