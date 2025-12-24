import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class BenchPressAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? angle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10);
    
    if (angle != null) {
      if (angle < 90) {
        feedback = "底部位置";
        color = Colors.green;
      } else if (angle > 170) {
        feedback = "手肘微收，不要鎖死";
        color = Colors.red;
        problemKeypoints.addAll([7, 8]); 
      } else if (angle > 160) {
        feedback = "推起吐氣";
        color = Colors.white;
      } else {
        feedback = "肩胛骨鎖定，核心收緊，挺胸";
        color = Colors.yellow;
      }
    }
    
    return AnalysisResult(
      feedback: feedback,
      color: color,
      problemKeypoints: problemKeypoints,
      angles: angles,
    );
  }
}
