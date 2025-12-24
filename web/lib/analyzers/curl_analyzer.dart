import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class CurlAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? elbowAngle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10); 
    double? shoulderAngle = getAverageAngle(keypoints, 7, 5, 11, 8, 6, 12); 
    
    const double MAX_SHOULDER_FLARE = 30; 

    if (shoulderAngle != null && shoulderAngle > MAX_SHOULDER_FLARE) {
        feedback = "上臂前移代償！固定手肘，收緊核心";
        color = Colors.red;
        problemKeypoints.addAll([5, 6]); 
    } 
    else if (elbowAngle != null) {
        const double FULL_EXTENSION_ANGLE = 170; 
        const double PEAK_CONTRACTION_ANGLE = 40; 
        
        if (elbowAngle > FULL_EXTENSION_ANGLE) {
            feedback = "完全伸展！準備收縮";
            color = Colors.blue; 
        } 
        else if (elbowAngle < PEAK_CONTRACTION_ANGLE) { 
            feedback = "完美收縮！緩慢放下感受離心";
            color = Colors.green;
        } 
        else {
            feedback = "持續發力，專注二頭肌收縮";
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
