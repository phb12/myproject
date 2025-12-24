import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<List<double>> keypoints;
  final Set<int> problemKeypoints;
  final double scaleX;
  final double scaleY;
  final bool isFrontCamera;

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

    // MoveNet Thunder Keypoints Map
    // ... (comments)

    // Draw Keypoints
    for (int i = 0; i < keypoints.length; i++) {
      var kp = keypoints[i];
      double y = kp[0];
      double x = kp[1];
      
      if (isFrontCamera) {
        x = 1.0 - x;
      }

      double score = kp[2];

      if (score > 0.2) {
        canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          problemKeypoints.contains(i) ? 6 : 4,
          problemKeypoints.contains(i) ? problemPaint : paint,
        );
      }
    }

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

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.keypoints != keypoints || oldDelegate.problemKeypoints != problemKeypoints;
  }
}
