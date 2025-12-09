import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class DeadliftAnalyzer extends ExerciseAnalyzer {
  @override
  Map<String, dynamic> analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? angle = getAverageAngle(keypoints, 5, 11, 13, 6, 12, 14);
    if (angle != null) {
      if (angle < 120) {
        feedback = "屁股夾緊，不過度骨盆前傾";
        color = Colors.green;
      } else if (angle > 160) {
        feedback = "背部打直，屁股夾緊";
        color = Colors.white;
      } else {
        feedback = "背部打直，屁股向後推，收緊核心";
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
