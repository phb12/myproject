// lib/pages/device_connection_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/health_service.dart';

class DeviceConnectionPage extends StatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> {
  int _heartRate = 0;
  bool _isSyncing = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 開始同步心率
  Future<void> _syncHealthData() async {
    setState(() => _isSyncing = true);
    
    // 1. 請求權限
    final hasPermission = await HealthService.instance.requestPermissions();
    
    if (hasPermission) {
      // 2. 如果有權限，開始每 5 秒讀取一次 (模擬即時監控)
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        // Widen search to 24 hours to ensure we can verify *any* connection, 
        // as Watch sync might have delay.
        final hr = await HealthService.instance.fetchHeartRate(lookBackMinutes: 1440);
        if (mounted) {
          setState(() {
            _heartRate = hr;
          });
        }
      });
      
      // 立即讀取一次
      final hr = await HealthService.instance.fetchHeartRate(lookBackMinutes: 1440);
      if (mounted) {
        setState(() {
          _heartRate = hr;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法獲取健康權限，請至設定開啟')),
        );
      }
    }

    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('連接健康裝置'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 心率大圖示
            Icon(
              Icons.favorite,
              size: 100,
              color: _heartRate > 0 ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 24),
            
            // 心率數值
            Text(
              _heartRate > 0 ? '$_heartRate BPM' : '--',
              style: const TextStyle(
                fontSize: 48, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('即時心率 (Apple Watch)', style: TextStyle(color: Colors.grey)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(
                '注意：若手錶未開啟「體能訓練」模式，數據更新可能會有數分鐘延遲。請在手錶上開啟任一運動模式以獲得即時更新。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 連接按鈕
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncHealthData,
              icon: _isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : (_heartRate > 0 ? const Icon(Icons.check_circle, color: Colors.white) : const Icon(Icons.link)),
              label: Text(_isSyncing ? '連接中...' : (_heartRate > 0 ? 'Apple Health 已連結' : '連接 Apple Health')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: _heartRate > 0 ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}