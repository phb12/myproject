import 'package:flutter/material.dart';
import '../exercise_analyzer.dart';

class SquatAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? kneeAngle = getAverageAngle(keypoints, 11, 13, 15, 12, 14, 16);
    double? hipAngle = getAverageAngle(keypoints, 5, 11, 13, 6, 12, 14);
    
    if (kneeAngle != null) angles['knee'] = kneeAngle;
    if (hipAngle != null) angles['hip'] = hipAngle;

    if (kneeAngle != null && hipAngle != null) {
      if (hipAngle > 165) {
         feedback = "屁股向前推 (夾緊)";
         color = Colors.white;
      } else {
         if (kneeAngle < 30) {
           feedback = "太深了 (小心)";
           color = Colors.red;
           problemKeypoints.addAll([13, 14]); 
         } else if (kneeAngle < 100) {
           feedback = "完美全蹲";
           color = Colors.green;
         } else if (kneeAngle < 130) {
           feedback = "再蹲低一點";
           color = Colors.yellow;
         } else {
           feedback = "屁股向後坐";
           color = Colors.white;
         }
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
