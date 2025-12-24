import 'dart:math';
import 'package:flutter/material.dart';

class AnalysisResult {
  final String feedback;
  final Color color;
  final Set<int> problemKeypoints;
  final Map<String, double> angles;

  AnalysisResult({
    required this.feedback,
    required this.color,
    this.problemKeypoints = const {},
    this.angles = const {},
  });
}

abstract class ExerciseAnalyzer {
  AnalysisResult analyze(List<List<double>> keypoints);

  // Helper methods for subclasses
  
  double calculateAngle(List<double> a, List<double> b, List<double> c) {
    final radians = atan2(c[0] - b[0], c[1] - b[1]) - atan2(a[0] - b[0], a[1] - b[1]);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  }

  double? getAngle(List<List<double>> keypoints, int idx1, int idx2, int idx3) {
    if (idx1 >= keypoints.length || idx2 >= keypoints.length || idx3 >= keypoints.length) return null;
    if (keypoints[idx1][2] > 0.2 && keypoints[idx2][2] > 0.2 && keypoints[idx3][2] > 0.2) {
      return calculateAngle(keypoints[idx1], keypoints[idx2], keypoints[idx3]);
    }
    return null;
  }

  double? getAverageAngle(List<List<double>> keypoints, int left1, int left2, int left3, int right1, int right2, int right3) {
    double? left = getAngle(keypoints, left1, left2, left3);
    double? right = getAngle(keypoints, right1, right2, right3);
    if (left != null && right != null) return (left + right) / 2;
    return left ?? right;
  }
  
  double? getKeypointY(List<List<double>> keypoints, int idx) {
    if (idx >= keypoints.length) return null;
    if (keypoints[idx][2] > 0.2) return keypoints[idx][0]; // y is index 0
    return null;
  }
}
