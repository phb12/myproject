// lib/pages/workout_history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/workout_log_model.dart';
import '../models/exercise_model.dart';
import '../services/database_helper.dart';

class WorkoutHistoryPage extends StatefulWidget {
  final String account;
  const WorkoutHistoryPage({super.key, required this.account});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  late Future<List<WorkoutLog>> _logsFuture;
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _refreshLogs();
  }
  
  Future<void> _refreshLogs() async {
    setState(() {
      // 【核心修正】這裡必須傳入 widget.account，只讀取這個人的資料
      _logsFuture = DatabaseHelper.instance.getWorkoutLogs(widget.account);
    });
  }

  List<WorkoutLog> _getLogsForDay(DateTime day, List<WorkoutLog> allLogs) {
    return allLogs.where((log) => isSameDay(log.completedAt, day)).toList();
  }

  Color _getColorForBodyPart(BodyPart part) {
    switch (part) {
      case BodyPart.chest: return Colors.blue.shade400;
      case BodyPart.legs: return Colors.orange.shade400;
      case BodyPart.shoulders: return Colors.purple.shade400;
      case BodyPart.abs: return Colors.cyan.shade400;
      case BodyPart.biceps: return Colors.red.shade300;
      case BodyPart.triceps: return Colors.red.shade500;
      case BodyPart.back: return Colors.green.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練日曆'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<WorkoutLog>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('讀取資料時發生錯誤: ${snapshot.error}'));
          }

          final allLogs = snapshot.data ?? [];
          final selectedLogs = _getLogsForDay(_selectedDay!, allLogs);

          return RefreshIndicator(
            onRefresh: _refreshLogs, 
            child: ListView.builder(
              itemCount: selectedLogs.isEmpty ? 3 : selectedLogs.length + 2, // +3 for Cal, Summary, EmptyMsg
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    // ... Calendar properties ...
                    margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                    clipBehavior: Clip.antiAlias, 
                    child: Column(
                      children: [
                        TableCalendar<WorkoutLog>(
                          headerStyle: const HeaderStyle(formatButtonVisible: false),
                          locale: 'zh_TW',
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          eventLoader: (day) => _getLogsForDay(day, allLogs),
                          onDaySelected: (selectedDay, focusedDay) {
                            if (!isSameDay(_selectedDay, selectedDay)) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            }
                          },
                          onHeaderTapped: (focusedDay) async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: focusedDay,
                              firstDate: DateTime.utc(2020, 1, 1),
                              lastDate: DateTime.utc(2030, 12, 31),
                              locale: const Locale('zh', 'TW'),
                            );
                            if (picked != null) {
                              setState(() {
                                _focusedDay = picked;
                                _selectedDay = picked;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isNotEmpty) {
                                final colors = events.map((log) => _getColorForBodyPart(log.bodyPart)).toSet().toList();
                                return Positioned(bottom: 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: colors.map((color) => Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color))).toList()));
                              }
                              return null;
                            },
                          ),
                        ),
                        _buildLegend(),
                      ],
                    ),
                  );
                }

                // [NEW] Index 1: Daily Summary Row
                if (index == 1) {
                  return _buildDailySummaryRow(selectedLogs);
                }

                if (selectedLogs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: Text('這天沒有訓練紀錄')),
                  );
                }
                
                // Adjust index for list items (index 0=Cal, 1=Summary, 2=EmptyMsg or Log[0])
                if (index == 2 && selectedLogs.isEmpty) {
                   return const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: Text('這天沒有訓練紀錄')),
                  );
                }

                // Normal Log Item
                final logIndex = index - 2;
                if (logIndex < 0 || logIndex >= selectedLogs.length) return const SizedBox(); 
                final log = selectedLogs[logIndex];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorForBodyPart(log.bodyPart),
                        child: Text('${log.totalSets}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(log.exerciseName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('完成於: ${DateFormat('HH:mm').format(log.completedAt)}'),
                          if (log.calories > 0)
                            Text(
                              '心率: ${log.avgHeartRate} avg / ${log.maxHeartRate} max',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(name),
      ],
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: BodyPart.values.map((part) {
          return _buildLegendItem(_getColorForBodyPart(part), part.displayName);
        }).toList(),
      ),
    );
  }


  // [NEW] Build the summary row widget
  Widget _buildDailySummaryRow(List<WorkoutLog> logs) {
    double totalCalories = 0;
    for (var log in logs) {
      totalCalories += log.calories;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: const Icon(Icons.local_fire_department, color: Colors.orange),
        title: const Text('今日消耗熱量', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${totalCalories.toStringAsFixed(1)} kcal',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
          ],
        ),
        onTap: () => _showCalorieBreakdown(logs),
      ),
    );
  }

  void _showCalorieBreakdown(List<WorkoutLog> logs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text('熱量消耗明細', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      title: Text(log.exerciseName),
                      subtitle: Text(DateFormat('HH:mm').format(log.completedAt)),
                      trailing: Text(
                        '${log.calories.toStringAsFixed(1)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}