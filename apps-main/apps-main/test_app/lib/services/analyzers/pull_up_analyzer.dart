import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class PullUpAnalyzer extends ExerciseAnalyzer {
  @override
  Map<String, dynamic> analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? elbowAngle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10); 
    double? trunkAngle = getAverageAngle(keypoints, 5, 11, 13, 6, 12, 14); 
    
    if (trunkAngle != null && trunkAngle < 140) {
        feedback = "身體晃動或腰部反弓！收緊核心和臀部";
        color = Colors.red;
        problemKeypoints.addAll([11, 12]); 
    } 
    else if (elbowAngle != null) {
        const double FULL_EXTENSION_ANGLE = 175; 
        
        if (elbowAngle > FULL_EXTENSION_ANGLE) {
            feedback = "完全放鬆肩胛！有力向上拉";
            color = Colors.blue; 
        } 
        else {
        feedback = "背部啟動發力";
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
