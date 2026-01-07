import 'package:flutter/material.dart';

// 負責在 Canvas 上繪製骨架的畫筆
class PosePainter extends CustomPainter {
  final List<List<double>> keypoints; // 關鍵點列表 [[y, x, score], ...]
  final Set<int> problemKeypoints; // 標記為錯誤的關鍵點 (將繪製成紅色)
  final double scaleX; // X 軸縮放
  final double scaleY; // Y 軸縮放
  final bool isFrontCamera; // 是否為前鏡頭 (需要水平翻轉)

  PosePainter({
    required this.keypoints,
    this.problemKeypoints = const {},
    required this.scaleX,
    required this.scaleY,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    final problemPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 6.0
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // MoveNet Thunder 關鍵點映射表 (參考用)
    // MoveNet Thunder Keypoints Map
    // ... (comments)

    // 繪製關鍵點
    // Draw Keypoints
    for (int i = 0; i < keypoints.length; i++) {
      var kp = keypoints[i];
      double y = kp[0];
      double x = kp[1];
      
      // 鏡像翻轉處理 (前鏡頭)
      if (isFrontCamera) {
        x = 1.0 - x;
      }

      double score = kp[2];

      // 僅繪製信心分數大於 0.2 的關鍵點
      if (score > 0.2) {
        canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          problemKeypoints.contains(i) ? 6 : 4,
          problemKeypoints.contains(i) ? problemPaint : paint,
        );
      }
    }

    // 繪製骨架連線
    // Draw Skeleton Connections
    final connections = [
      [0, 1], [0, 2], [1, 3], [2, 4], // Head
      [5, 6], // Shoulders
      [5, 7], [7, 9], // Left Arm
      [6, 8], [8, 10], // Right Arm
      [5, 11], [6, 12], // Torso
      [11, 12], // Hips
      [11, 13], [13, 15], // Left Leg
      [12, 14], [14, 16], // Right Leg
    ];

    for (var connection in connections) {
      var kp1 = keypoints[connection[0]];
      var kp2 = keypoints[connection[1]];

      // 僅當兩端點信心分數皆足夠時才繪製連線
      if (kp1[2] > 0.2 && kp2[2] > 0.2) {
        double x1 = kp1[1];
        double x2 = kp2[1];

        if (isFrontCamera) {
          x1 = 1.0 - x1;
          x2 = 1.0 - x2;
        }

        canvas.drawLine(
          Offset(x1 * size.width, kp1[0] * size.height),
          Offset(x2 * size.width, kp2[0] * size.height),
          linePaint,
        );
      }
    }
    
  }

  // 決定是否需要重繪 (當關鍵點數據變更時)
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.keypoints != keypoints || oldDelegate.problemKeypoints != problemKeypoints;
  }
}
