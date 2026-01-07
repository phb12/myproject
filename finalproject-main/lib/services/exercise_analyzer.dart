import 'dart:math';
import 'package:flutter/material.dart';

// 健身動作分析結果
class AnalysisResult {
  final String feedback; // 動作回饋建議
  final Color color; // 回饋顏色 (綠色正確，黃/紅需改進)
  final Set<int> problemKeypoints; // 有問題的關鍵點索引 (用於繪製標記)
  final Map<String, double> angles; // 計算出的角度資訊 (用於顯示或除錯)

  AnalysisResult({
    required this.feedback,
    required this.color,
    this.problemKeypoints = const {},
    this.angles = const {},
  });
}

// 運動分析器基類 (所有具體運動分析器應繼承此類別)
abstract class ExerciseAnalyzer {
  AnalysisResult analyze(List<List<double>> keypoints);

  // 子類別常用的輔助方法
  // Helper methods for subclasses
  
  // 計算三點形成的角度 (b 為頂點)
  double calculateAngle(List<double> a, List<double> b, List<double> c) {
    final radians = atan2(c[0] - b[0], c[1] - b[1]) - atan2(a[0] - b[0], a[1] - b[1]);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  }

  // 獲取角度 (若任何關鍵點信心分數過低則返回 null)
  double? getAngle(List<List<double>> keypoints, int idx1, int idx2, int idx3) {
    if (idx1 >= keypoints.length || idx2 >= keypoints.length || idx3 >= keypoints.length) return null;
    if (keypoints[idx1][2] > 0.2 && keypoints[idx2][2] > 0.2 && keypoints[idx3][2] > 0.2) {
      return calculateAngle(keypoints[idx1], keypoints[idx2], keypoints[idx3]);
    }
    return null;
  }

  // 獲取平均角度 (左右側)
  double? getAverageAngle(List<List<double>> keypoints, int left1, int left2, int left3, int right1, int right2, int right3) {
    double? left = getAngle(keypoints, left1, left2, left3);
    double? right = getAngle(keypoints, right1, right2, right3);
    if (left != null && right != null) return (left + right) / 2;
    return left ?? right;
  }
  
  // 獲取關鍵點 Y 座標 (有用於檢查高度關係)
  double? getKeypointY(List<List<double>> keypoints, int idx) {
    if (idx >= keypoints.length) return null;
    if (keypoints[idx][2] > 0.2) return keypoints[idx][0]; // y is index 0
    return null;
  }
}
