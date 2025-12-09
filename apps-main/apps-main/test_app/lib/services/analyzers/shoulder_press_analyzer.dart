import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class ShoulderPressAnalyzer extends ExerciseAnalyzer {
  @override
  Map<String, dynamic> analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? angle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10);
    if (angle != null) {
      if (angle > 160) {
        feedback = "推起伸直";
        color = Colors.green; 
      } else if (angle < 90) {
        feedback = "核心收緊";
        color = Colors.white;
      } else {
        feedback = "不要過度挺腰";
        color = Colors.yellow;
      }
    }

    return {
      'feedback': feedback,
      'color': color,
      'problemKeypoints': problemKeypoints,
      'angles': angles,
    };
  }
}
