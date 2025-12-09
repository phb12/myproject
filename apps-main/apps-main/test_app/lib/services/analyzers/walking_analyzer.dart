import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class WalkingAnalyzer extends ExerciseAnalyzer {
  @override
  Map<String, dynamic> analyze(List<List<double>> keypoints) {
    // Current MVP: Simple feedback.
    // Future: Implement step counting or gait analysis.
    String feedback = "正在走路...";
    Color color = Colors.green;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    return {
      'feedback': feedback,
      'color': color,
      'problemKeypoints': problemKeypoints,
      'angles': angles,
    };
  }
}
