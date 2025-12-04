// lib/services/health_service.dart

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final HealthService instance = HealthService._internal();
  HealthService._internal();

  // 建立 Health 工廠實體
  // 注意：不同版本的套件寫法可能略有不同，這是 v10+ 的標準寫法
  // 如果您的套件版本較舊，可能需要用 HealthFactory
  
  // 定義我們需要的數據類型：心率
  final List<HealthDataType> types = [
    HealthDataType.HEART_RATE,
  ];

  // 1. 請求權限
  Future<bool> requestPermissions() async {
    // 檢查是否支援 HealthKit (只在 iOS 有效)
    // Android 也有 Health Connect，但設定比較複雜，我們先專注 iOS
    bool requested = false;
    try {
      // 請求權限
      requested = await Health().requestAuthorization(types);
    } catch (e) {
      print("權限請求失敗: $e");
    }
    return requested;
  }

  // 2. 讀取最近的心率數據
  Future<int> fetchHeartRate() async {
    try {
      // 檢查是否獲取授權
      bool hasPermissions = await Health().hasPermissions(types) ?? false;
      if (!hasPermissions) {
        final success = await requestPermissions();
        if (!success) return 0;
      }

      final now = DateTime.now();
      // 讀取過去 1 小時的數據
      final yesterday = now.subtract(const Duration(hours: 1));

      // 獲取數據
      List<HealthDataPoint> healthData = await Health().getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: types,
      );

      if (healthData.isNotEmpty) {
        // 清理重複並排序，取最新的一筆
        healthData = Health().removeDuplicates(healthData);
        healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        
        // 回傳數值 (心率通常是 double，我們轉成 int)
        // value 是一個 NumericHealthValue
        final value = healthData.first.value as NumericHealthValue;
        return value.numericValue.toInt();
      }
    } catch (e) {
      print("讀取心率失敗: $e");
    }
    return 0; // 沒讀到或是失敗
  }
}