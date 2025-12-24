import 'package:flutter/material.dart';
import '../exercise_analyzer.dart';

class CrunchAnalyzer extends ExerciseAnalyzer {
  @override
  AnalysisResult analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? shkAngle = getAverageAngle(keypoints, 5, 11, 13, 6, 12, 14); 
    double? neckAngle = getAngle(keypoints, 0, 5, 11);

    const double PEAK_CRUNCH_ANGLE = 120; 
    const double REST_CRUNCH_ANGLE = 160; 
    const double MAX_NECK_FLEXION = 100; 

    if (neckAngle != null && neckAngle < MAX_NECK_FLEXION) {
        feedback = "避免拉脖子！下巴與胸口保持一個拳頭距離";
        color = Colors.red;
        problemKeypoints.addAll([0, 5]); 
    } 
    else if (shkAngle != null) {
        if (shkAngle < PEAK_CRUNCH_ANGLE) {
            feedback = "完美！腹部用力收緊";
            color = Colors.green;
        } else if (shkAngle > REST_CRUNCH_ANGLE) {
            feedback = "緩慢回到地面，充分伸展腹部";
            color = Colors.blue;
        }
        else {
            feedback = "繼續捲曲，專注腹肌收縮";
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
