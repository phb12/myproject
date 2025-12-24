import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class TricepExtensionAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? elbowAngle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10);
    double? upperArmAngle = getAverageAngle(keypoints, 11, 5, 7, 12, 6, 8); 
    
    const double MAX_UPPER_ARM_MOVE = 30;

    if (upperArmAngle != null && upperArmAngle > MAX_UPPER_ARM_MOVE) {
        feedback = "上臂移動代償！將手肘鎖定在身體兩側";
        color = Colors.red;
        problemKeypoints.addAll([5, 6, 7, 8]); 
    }
    else if (elbowAngle != null) {
        const double PEAK_CONTRACTION_ANGLE = 170; 
        const double BOTTOM_STRETCH_ANGLE = 90;    
        
        if (elbowAngle > PEAK_CONTRACTION_ANGLE) {
            feedback = "完美收縮！感受三頭肌鎖緊";
            color = Colors.green;
        } 
        else if (elbowAngle < BOTTOM_STRETCH_ANGLE) { 
            feedback = "保持張力不要完全休息";
            color = Colors.yellow;
        } 
        else {
            feedback = "保持張力，有力下壓";
            color = Colors.white;
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
