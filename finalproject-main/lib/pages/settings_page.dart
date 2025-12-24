// lib/pages/settings_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/workout_log_model.dart';
import '../models/weight_log_model.dart';
import '../services/database_helper.dart';
import '../services/firestore_service.dart';
import './profile_page.dart';
import './device_connection_page.dart';
import './login_page.dart';
import '../services/health_service.dart';
import 'package:health/health.dart';


class SettingsPage extends StatefulWidget {
  final String account;
  const SettingsPage({super.key, required this.account});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  @override
  void initState() {
    super.initState();
  }

  // 【修改】移除所有提醒相關的邏輯

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    final logs = await DatabaseHelper.instance.getWorkoutLogs(widget.account);
    if (!mounted) return;
    
    if (logs.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('沒有任何訓練紀錄可以匯出')));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(['完成時間', '動作名稱', '總組數', '訓練部位']);
    
    for (var log in logs) {
      rows.add([
        log.completedAt.toIso8601String(), 
        log.exerciseName, 
        log.totalSets, 
        log.bodyPart.name
      ]);
    }
    
    final csvContent = const ListToCsvConverter().convert(rows);
    const fileName = 'workout_logs.csv';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsString(csvContent);
      await Share.shareXFiles([XFile(path)], text: '我的訓練紀錄 (CSV)');
      
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('匯出成功！')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('匯出失敗: $e')));
    }
  }

 Future<void> _restoreDataFromCloud() async {
    final messenger = ScaffoldMessenger.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('還原雲端資料'),
        content: const Text('將從雲端下載資料並合併到本機。\n系統會自動過濾重複的資料。'),
        actions: [
          TextButton(child: const Text('取消'), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text('開始還原'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    try {
      // 1. 讀取雲端資料
      final workoutData = await FirestoreService.instance.fetchBackedUpWorkoutLogs();
      final weightData = await FirestoreService.instance.fetchBackedUpWeightLogs();

      if (workoutData.isEmpty && weightData.isEmpty) {
        if (mounted) messenger.showSnackBar(const SnackBar(content: Text('雲端沒有備份資料')));
        return;
      }

      // 2. 讀取本地現有資料 (用來比對)
      final existingWorkouts = await DatabaseHelper.instance.getWorkoutLogs(widget.account);
      final existingWeights = await DatabaseHelper.instance.getWeightLogs(widget.account);

      int count = 0;

      // 3. 還原訓練紀錄 (過濾重複)
      for (var data in workoutData) {
        final newLog = WorkoutLog.fromMap(data);
        
        // 檢查是否已存在相同的紀錄 (比對時間和動作名稱)
        final isDuplicate = existingWorkouts.any((log) => 
            log.completedAt.isAtSameMomentAs(newLog.completedAt) && 
            log.exerciseName == newLog.exerciseName
        );

        if (!isDuplicate) {
          data.remove('id'); 
          data['account'] = widget.account; // 確保歸屬正確

        await DatabaseHelper.instance.insertWorkoutLog(
            WorkoutLog.fromMap(data),
            syncToCloud: false, 
          );
          count++;
        }
      }
      
      // 4. 還原體重紀錄 (過濾重複)
      for (var data in weightData) {
        final newLog = WeightLog.fromMap(data);

        data.remove('id');
        data['account'] = widget.account;
        
        

        final isDuplicate = existingWeights.any((log) => 
            log.createdAt.isAtSameMomentAs(newLog.createdAt) && 
            log.weight == newLog.weight
        );

        if (!isDuplicate) {
          data.remove('id');
          data['account'] = widget.account;

         await DatabaseHelper.instance.insertWeightLog(
            WeightLog.fromMap(data),
            syncToCloud: false,
          );
          count++;
        }
      }

      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('還原完成，新增了 $count 筆資料！'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('還原失敗: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showClearDataConfirmationDialog() async {
    return showDialog<void>(
      context: context, 
      builder: (BuildContext dialogContext) => AlertDialog(
        titlePadding: EdgeInsets.zero, 
        contentPadding: EdgeInsets.zero, 
        actionsPadding: EdgeInsets.zero, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)), 
        content: SizedBox(
          width: 270, 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0), 
                child: Column(
                  children: [
                    Text('確認清除', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), 
                    SizedBox(height: 4), 
                    Text('此操作將永久刪除本地的所有訓練紀錄。', textAlign: TextAlign.center, style: TextStyle(fontSize: 13))
                  ]
                )
              ), 
              const Divider(height: 1), 
              _buildDialogButton(
                text: '全部清除', 
                color: Colors.red.shade400, 
                isBold: true, 
                onPressed: () async { 
                  final navigator = Navigator.of(dialogContext); 
                  final messenger = ScaffoldMessenger.of(context); 
                  await DatabaseHelper.instance.deleteAllWorkoutLogs(widget.account); 
                  if (!mounted) return; 
                  navigator.pop(); 
                  messenger.showSnackBar(const SnackBar(content: Text('所有訓練紀錄已成功清除'), backgroundColor: Colors.green)); 
                }
              ), 
              const Divider(height: 1), 
              _buildDialogButton(text: '取消', onPressed: () => Navigator.of(dialogContext).pop())
            ]
          )
        )
      )
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context, 
      builder: (BuildContext dialogContext) => AlertDialog(
        titlePadding: EdgeInsets.zero, 
        contentPadding: EdgeInsets.zero, 
        actionsPadding: EdgeInsets.zero, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)), 
        content: SizedBox(
          width: 270, 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0), 
                child: Text('是否確認登出？', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ), 
              const Divider(height: 1), 
              _buildDialogButton(
                text: '登出', 
                color: Colors.red.shade400, 
                isBold: true, 
                onPressed: () { 
                  Navigator.of(dialogContext).pop(); 
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (Route<dynamic> route) => false); 
                }
              ), 
              const Divider(height: 1), 
              _buildDialogButton(text: '稍後再說', color: Theme.of(context).colorScheme.primary, onPressed: () => Navigator.of(dialogContext).pop())
            ]
          )
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            _buildSettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('個人資料修改'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage(account: widget.account)),
                    );
                  },
                ),
              ],
            ),
            // 【修改】移除了體重提醒區塊
            
            const SizedBox(height: 24),
            _buildSettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: const Text('心率連線測試'),
                  subtitle: const Text('測試 Apple Health 數據讀取'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceConnectionPage())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.red),
                  title: const Text('Apple Health 健康'),
                  subtitle: const Text('自動同步 Apple Watch 心率'),
                  trailing: const Icon(Icons.check_circle_outline, size: 16), // Dynamic icon in logic below would be better but simple for now
                  onTap: () async {
                    // Check logic
                    bool success = await HealthService.instance.requestPermissions();
                    if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Apple Health 已連結！' : '連結失敗，請檢查權限'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],

            ),
            const SizedBox(height: 24),
            _buildSettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.import_export),
                  title: const Text('匯出訓練紀錄 (CSV)'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _exportData, 
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, color: Colors.blue),
                  title: const Text('從雲端還原資料'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _restoreDataFromCloud,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('清除所有訓練紀錄', style: TextStyle(color: Colors.red.shade400)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showClearDataConfirmationDialog,
                ),
              ],
            ),
            const Spacer(),
            _buildSettingsGroup(
              children: [
                ListTile(
                  title: Center(child: Text('登出', style: TextStyle(color: Colors.red.shade400, fontSize: 17))),
                  onTap: _showLogoutConfirmationDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Card(clipBehavior: Clip.antiAlias, child: Column(children: children));
  }

  Widget _buildDialogButton({required String text, required VoidCallback onPressed, Color? color, bool isBold = false}) {
    return SizedBox(width: double.infinity, height: 50, child: TextButton(onPressed: onPressed, child: Text(text, style: TextStyle(fontSize: 17, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))));
  }
}