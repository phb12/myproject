import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class PushUpAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? armAngle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10);
    double? bodyAngle = getAverageAngle(keypoints, 5, 11, 15, 6, 12, 16);
    if (armAngle != null) angles['elbow'] = armAngle;
    if (bodyAngle != null) angles['hip'] = bodyAngle;
    const double LOCKOUT_ANGLE = 170; 
    const double DEPTH_ANGLE = 90;    

    if (bodyAngle != null && bodyAngle < 150) {
       feedback = "腰部塌陷！收緊核心";
       color = Colors.red;
       problemKeypoints.addAll([11, 12]);
    } else if (armAngle != null && armAngle > LOCKOUT_ANGLE) {
      feedback = "回到頂端，準備下一次！";
      color = Colors.blue; 
    } else if (armAngle != null) {
      if (armAngle < DEPTH_ANGLE) {
        feedback = "完美深度！有力推起";
        color = Colors.green;
      } else if (armAngle > 160) {
        feedback = "身體呈直線";
        color = Colors.white;
      } else {
        feedback = "繼續下放，胸口貼地";
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
