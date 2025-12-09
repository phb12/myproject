import 'package:flutter/material.dart';
import 'exercise_analyzer.dart';

class LateralRaiseAnalyzer extends ExerciseAnalyzer {
  @override
  Map<String, dynamic> analyze(List<List<double>> keypoints) {
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double? shoulderAbductionAngle = getAverageAngle(keypoints, 11, 5, 7, 12, 6, 8); 
    double? elbowAngle = getAverageAngle(keypoints, 5, 7, 9, 6, 8, 10);
    
    double? leftWristY = getKeypointY(keypoints, 9);
    double? rightWristY = getKeypointY(keypoints, 10);
    double? leftShoulderY = getKeypointY(keypoints, 5);
    double? rightShoulderY = getKeypointY(keypoints, 6);
    
    double? wristYPosition;
    if (leftWristY != null && rightWristY != null) {
      wristYPosition = (leftWristY + rightWristY) / 2;
    }
    
    double? shoulderYPosition;
    if (leftShoulderY != null && rightShoulderY != null) {
      shoulderYPosition = (leftShoulderY + rightShoulderY) / 2;
    }
    
    const double MIN_ELBOW_BEND = 140; 
    const double MAX_ELBOW_BEND = 175; 
    
    if (elbowAngle != null && (elbowAngle < MIN_ELBOW_BEND || elbowAngle > MAX_ELBOW_BEND)) {
        feedback = "保持手肘微彎，不要太直或太彎";
        color = Colors.orange;
        problemKeypoints.addAll([7, 8]); 
    }
    else if (shoulderAbductionAngle != null && shoulderYPosition != null && wristYPosition != null) {
        const double TOP_ANGLE = 95; 
        const double BOTTOM_ANGLE = 20; 
        const double MAX_LIFT_HEIGHT_DIFF = 0.05; 
        
        if (shoulderAbductionAngle < BOTTOM_ANGLE) {
            feedback = "完全放下！保持張力，準備提起";
            color = Colors.blue; 
        } 
        else if (shoulderAbductionAngle > TOP_ANGLE) { 
            if ((shoulderYPosition - wristYPosition) > MAX_LIFT_HEIGHT_DIFF) {
                feedback = "抬太高了！手腕不要超過肩膀高度";
                color = Colors.red;
                problemKeypoints.addAll([5, 6, 9, 10]); 
            } else {
                feedback = "完美！保持頂峰收縮，緩慢放下";
                color = Colors.green;
            }
        } 
        else {
            feedback = "持續發力，專注三角肌中束";
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
