import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<List<double>> keypoints; // [y, x, score] normalized 0..1
  final Size sourceSize; // Video dimensions
  final bool isMirrored;
  
  PosePainter(this.keypoints, this.sourceSize, {this.isMirrored = false});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate the destination rectangle where the video is actually drawn
    //    because standard HtmlElementView with object-fit: contain centers the video.
    final FittedSizes fittedSizes = applyBoxFit(BoxFit.contain, sourceSize, size);
    final Size destSize = fittedSizes.destination;
    
    // 2. Calculate offsets to center the drawing area
    final double dx = (size.width - destSize.width) / 2;
    final double dy = (size.height - destSize.height) / 2;

    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    final pointPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    
    // Helper to map normalized coordinates to screen
    Offset mapPoint(double normY, double normX) {
      double x = normX;
      double y = normY;
      
      if (isMirrored) {
        x = 1.0 - x;
      }
      
      return Offset(
        x * destSize.width + dx,
        y * destSize.height + dy
      );
    }

    // Draw points
    for (var kp in keypoints) {
      if (kp[2] > 0.3) {
        // kp is [y, x, score]
        canvas.drawCircle(mapPoint(kp[0], kp[1]), 4, pointPaint);
      }
    }
    
    // Edges
    final edges = [
      [0, 1], [0, 2], [1, 3], [2, 4], [0, 5], [0, 6], [5, 6], [5, 7], [7, 9], [6, 8], [8, 10], [5, 11], [6, 12], [11, 12], [11, 13], [13, 15], [12, 14], [14, 16]
    ];
    
    for (var edge in edges) {
      if (edge[0] >= keypoints.length || edge[1] >= keypoints.length) continue;
      
      final p1 = keypoints[edge[0]];
      final p2 = keypoints[edge[1]];
      if (p1[2] > 0.3 && p2[2] > 0.3) {
        canvas.drawLine(
          mapPoint(p1[0], p1[1]),
          mapPoint(p2[0], p2[1]),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
