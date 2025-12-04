import 'dart:async';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WebPoseService {
  html.Worker? _worker;
  Completer<void>? _loadCompleter;
  
  // Stream controller for results
  final _resultController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get resultStream => _resultController.stream;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    if (_worker != null) return;

    _loadCompleter = Completer<void>();
    
    // Initialize Worker
    _worker = html.Worker('pose_worker.js');
    
    _worker!.onMessage.listen((html.MessageEvent e) {
      final data = e.data;
      final type = data['type'];
      
      if (type == 'loaded') {
        _isLoaded = true;
        _loadCompleter?.complete();
        print('WebPoseService: Models loaded');
      } else if (type == 'error') {
        print('WebPoseService Error: ${data['payload']}');
        if (!_loadCompleter!.isCompleted) {
          _loadCompleter!.completeError(data['payload']);
        }
      } else if (type == 'result') {
        final payload = data['payload'];
        // Analyze the pose result
        final analysis = analyzePose(payload, payload['label']);
        
        _resultController.add({
          'keypoints': payload['keypoints'],
          'label': payload['label'],
          'score': payload['score'],
          'analysis': analysis,
        });
      }
    });

    // Send load command
    _worker!.postMessage({'type': 'load'});
    
    return _loadCompleter!.future;
  }

  void processFrame(html.ImageData imageData) {
    if (!_isLoaded || _worker == null) return;
    
    _worker!.postMessage({
      'type': 'process',
      'payload': {
        'imageData': imageData.data, // Uint8ClampedArray
        'width': imageData.width,
        'height': imageData.height,
      }
    });
  }

  void dispose() {
    _worker?.terminate();
    _worker = null;
    _resultController.close();
  }

  // --- Analysis Logic (Ported from Mobile App) ---
  
  Map<String, dynamic> analyzePose(Map<dynamic, dynamic> result, String exerciseName) {
    // Convert JS keypoints to List<List<double>>
    // JS sends: [[y, x, score], ...]
    final rawKeypoints = result['keypoints'] as List;
    List<List<double>> keypoints = [];
    for (var k in rawKeypoints) {
      keypoints.add((k as List).map((e) => (e as num).toDouble()).toList());
    }
    
    final score = result['score'] as double;

    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    // Helper to get angle safely
    double? getAngle(int idx1, int idx2, int idx3) {
      if (idx1 >= keypoints.length || idx2 >= keypoints.length || idx3 >= keypoints.length) return null;
      if (keypoints[idx1][2] > 0.2 && keypoints[idx2][2] > 0.2 && keypoints[idx3][2] > 0.2) {
        return _calculateAngle(keypoints[idx1], keypoints[idx2], keypoints[idx3]);
      }
      return null;
    }

    // Helper to get average angle from both sides if visible, or fallback to one side
    double? getAverageAngle(int left1, int left2, int left3, int right1, int right2, int right3) {
      double? left = getAngle(left1, left2, left3);
      double? right = getAngle(right1, right2, right3);
      if (left != null && right != null) return (left + right) / 2;
      return left ?? right;
    }

    // Helper to get Y coordinate safely
    double? getKeypointY(int index) {
      if (index < keypoints.length && keypoints[index][2] > 0.2) {
        return keypoints[index][0];
      }
      return null;
    }

    if (score > 0.4) {
      
      // 1. Squat (深蹲)
      if (exerciseName.contains('深蹲')) {
        // Hip-Knee-Ankle (Knee Angle)
        double? kneeAngle = getAverageAngle(11, 13, 15, 12, 14, 16);
        // Shoulder-Hip-Knee (Hip Angle)
        double? hipAngle = getAverageAngle(5, 11, 13, 6, 12, 14);

        if (kneeAngle != null) angles['knee'] = kneeAngle;
        if (hipAngle != null) angles['hip'] = hipAngle;

        if (kneeAngle != null && hipAngle != null) {
          if (hipAngle > 165) {
             feedback = "屁股向前推 (夾緊)";
             color = Colors.white;
          } else {
             // Descending or Bottom
             if (kneeAngle < 30) {
               feedback = "太深了 (小心)"; // Extreme depth only
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
      } 
      // 2. Deadlift (硬舉)
      else if (exerciseName.contains('硬舉')) {
        // Shoulder-Hip-Knee (Hip Hinge)
        double? angle = getAverageAngle(5, 11, 13, 6, 12, 14);
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
      }
      // 3. Bench Press (臥推)
      else if (exerciseName.contains('臥推')) {
        // Shoulder-Elbow-Wrist
        double? angle = getAverageAngle(5, 7, 9, 6, 8, 10);
        if (angle != null) {
          if (angle < 90) {
            feedback = "底部位置";
            color = Colors.green;
          } else if (angle > 170) {
            feedback = "手肘微收，不要鎖死";
            color = Colors.red;
            problemKeypoints.addAll([7, 8]); // Elbows
          } else if (angle > 160) {
            feedback = "推起吐氣";
            color = Colors.white;
          } else {
            feedback = "肩胛骨鎖定，核心收緊，挺胸";
            color = Colors.yellow;
          }
        }
      }
      // 4. Push Up (伏地挺身)
      else if (exerciseName.contains('伏地挺身')) {
        // Shoulder-Elbow-Wrist
        double? armAngle = getAverageAngle(5, 7, 9, 6, 8, 10);
        // Shoulder-Hip-Ankle (Body Line)
        double? bodyAngle = getAverageAngle(5, 11, 15, 6, 12, 16);
        const double LOCKOUT_ANGLE = 170; // 定義接近伸直的角度
        const double DEPTH_ANGLE = 90;    // 定義達到深度的角度

        if (bodyAngle != null && bodyAngle < 150) {
           feedback = "腰部塌陷！收緊核心";
           color = Colors.red;
           problemKeypoints.addAll([11, 12]); // Hips
        } else if (armAngle != null && armAngle > LOCKOUT_ANGLE) {
          // 動作推到頂端，準備或結束狀態
          feedback = "回到頂端，準備下一次！";
          color = Colors.blue; 
        }else if (armAngle != null) {
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
      }
      // 5. Pull Up (引體向上)
      else if (exerciseName.contains('引體向上')) {
        //動作幅度 (手肘角度): 肩-肘-腕 的平均角度 (接近頂端時最小)
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10); 
        
        //身體穩定度 (軀幹角度): 肩-髖-膝/踝 的平均角度 (理想上接近180度)
        double? trunkAngle = getAverageAngle(5, 11, 13, 6, 12, 14); // 假設13, 14是膝蓋
        
        if (trunkAngle != null && trunkAngle < 140) {
            feedback = "身體晃動或腰部反弓！收緊核心和臀部";
            color = Colors.red;
            problemKeypoints.addAll([11, 12]); //標記髖部
        } 
        else if (elbowAngle != null) {
            const double FULL_EXTENSION_ANGLE = 175; //手臂完全伸直的角度 (底部)
            
            //判斷是否處於底部（完全伸展）
            if (elbowAngle > FULL_EXTENSION_ANGLE) {
                //完全放鬆至底部，為下一次動作做準備
                feedback = "完全放鬆肩胛！有力向上拉";
                color = Colors.blue; 
            } 
            else {
            feedback = "背部啟動發力";
            color = Colors.yellow;
          }
        }
      }
      // 7. Shoulder Press (肩推)
      else if (exerciseName.contains('肩推')) {
        double? angle = getAverageAngle(5, 7, 9, 6, 8, 10);
        if (angle != null) {
          if (angle > 160) {
            feedback = "推起伸直";
            color = Colors.green; 
          } else if (angle < 90) {
            feedback = "核心收緊";
            color = Colors.white;
          } else {
            feedback = "不要過度挺腰";
            color = Colors.yellow;
          }
        }
      }
      // 8. Lateral Raise (側平舉)
      else if (exerciseName.contains('側平舉')) {
        // 這是判斷手臂相對於軀幹抬高程度
        double? shoulderAbductionAngle = getAverageAngle(11, 5, 7, 12, 6, 8); 
        
        // 確保手臂不會伸得太直或彎曲太多
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10);
        
        // 避免晃動或聳肩代償 
        double? leftWristY = getKeypointY(9);
        double? rightWristY = getKeypointY(10);
        double? leftShoulderY = getKeypointY(5);
        double? rightShoulderY = getKeypointY(6);
        
        double? wristYPosition;
        if (leftWristY != null && rightWristY != null) {
          wristYPosition = (leftWristY + rightWristY) / 2;
        }
        
        double? shoulderYPosition;
        if (leftShoulderY != null && rightShoulderY != null) {
          shoulderYPosition = (leftShoulderY + rightShoulderY) / 2;
        }
        
        // 理想的微彎角度應在 140 度到 170 度之間
        const double MIN_ELBOW_BEND = 140; 
        const double MAX_ELBOW_BEND = 175; // 避免完全伸直
        
        if (elbowAngle != null && (elbowAngle < MIN_ELBOW_BEND || elbowAngle > MAX_ELBOW_BEND)) {
            feedback = "保持手肘微彎，不要太直或太彎";
            color = Colors.orange;
            problemKeypoints.addAll([7, 8]); // 標記手肘
        }
        else if (shoulderAbductionAngle != null && shoulderYPosition != null && wristYPosition != null) {
            const double TOP_ANGLE = 95; // 接近 90 度，防止抬太高
            const double BOTTOM_ANGLE = 20; // 完全放下，但不過度休息
            const double MAX_LIFT_HEIGHT_DIFF = 0.05; // 允許手腕比肩膀高，防止聳肩過高
            
            //完全放下
            if (shoulderAbductionAngle < BOTTOM_ANGLE) {
                feedback = "完全放下！保持張力，準備提起";
                color = Colors.blue; 
            } 
            //拉至頂端
            else if (shoulderAbductionAngle > TOP_ANGLE) { 
                // 檢查是否抬得太高
                if ((shoulderYPosition - wristYPosition) > MAX_LIFT_HEIGHT_DIFF) {
                    feedback = "抬太高了！手腕不要超過肩膀高度";
                    color = Colors.red;
                    problemKeypoints.addAll([5, 6, 9, 10]); // 標記肩膀和手腕
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
      }

      // 9. Bicep Curl (彎舉)
      else if (exerciseName.contains('彎舉')) {
        // 判斷二頭肌是否完全收縮/伸展
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10); 

        //角度變小，表示上臂向前抬起，肩膀代償
        double? shoulderAngle = getAverageAngle(7, 5, 11, 8, 6, 12); // 假設11, 12是髖部
        
        // 理想的上臂固定角度
        const double MAX_SHOULDER_FLARE = 150; 

        if (shoulderAngle != null && shoulderAngle < MAX_SHOULDER_FLARE) {
            feedback = "上臂前移代償！固定手肘，收緊核心";
            color = Colors.red;
            problemKeypoints.addAll([5, 6]); // 標記肩膀
        } 
        else if (elbowAngle != null) {
            const double FULL_EXTENSION_ANGLE = 170; // 手臂完全伸直的角度 (底部)
            const double PEAK_CONTRACTION_ANGLE = 40; // 二頭肌完全收縮的角度 (頂部)
            
            // 判斷是否處於底部（完全伸展）
            if (elbowAngle > FULL_EXTENSION_ANGLE) {
                // 完全放鬆至底部
                feedback = "完全伸展！準備收縮";
                color = Colors.blue; 
            } 
            // 判斷是否拉至頂端 (手肘角度達到收縮要求) 
            else if (elbowAngle < PEAK_CONTRACTION_ANGLE) { 
                // 達到目標收縮點
                feedback = "完美收縮！緩慢放下感受離心";
                color = Colors.green;
            } 
            // D. 中間過程
            else {
                feedback = "持續發力，專注二頭肌收縮";
                color = Colors.yellow;
            }
        }
      }
      // 10. Triceps (三頭)
      else if (exerciseName.contains('三頭')) {
        // 判斷三頭肌是否完全伸展/收縮
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10);

        // 角度變小，上臂向前移動或肘部向後移動，代償。
        double? upperArmAngle = getAverageAngle(11, 5, 7, 12, 6, 8); 
        
        // 上臂固定角度
        const double MAX_UPPER_ARM_MOVE = 100;

        if (upperArmAngle != null && upperArmAngle < MAX_UPPER_ARM_MOVE) {
            feedback = "上臂移動代償！將手肘鎖定在身體兩側";
            color = Colors.red;
            problemKeypoints.addAll([5, 6, 7, 8]); // 標記肩膀和手肘
        }
        else if (elbowAngle != null) {
            const double PEAK_CONTRACTION_ANGLE = 170; // 完全伸直的角度
            const double BOTTOM_STRETCH_ANGLE = 90;    // 完全收縮的角度
            
            // 判斷是否處於頂部（完全伸直）
            if (elbowAngle > PEAK_CONTRACTION_ANGLE) {
                // 三頭肌完全收縮，達到頂峰
                feedback = "完美收縮！感受三頭肌鎖緊";
                color = Colors.green;
            } 
            // 判斷是否拉至底部
            else if (elbowAngle < BOTTOM_STRETCH_ANGLE) { 
                // 角度太小，表示拉伸太深或休息了
                feedback = "保持張力不要完全休息";
                color = Colors.yellow;
            } 
            else {
                feedback = "保持張力，有力下壓";
                color = Colors.white;
            }
        }
      }
      // 11. Crunch (捲腹)
      else if (exerciseName.contains('捲腹')) {
        // 1. 捲曲幅度角度 (Shoulder-Hip-Knee - SHK)
        double? shkAngle = getAverageAngle(5, 11, 13, 6, 12, 14); 
        
        // 判斷頭部相對於肩膀是否過度前傾，代償
        double? neckAngle = getAngle(0, 5, 11);

        const double PEAK_CRUNCH_ANGLE = 120; // 捲腹頂峰
        const double REST_CRUNCH_ANGLE = 160; // 休息/放鬆狀態
        const double MAX_NECK_FLEXION = 100; // 頸部角度 (如果頭-肩-髖角度小於此，則可能過度前傾)

        // 代償檢查
        if (neckAngle != null && neckAngle < MAX_NECK_FLEXION) {
            feedback = "避免拉脖子！下巴與胸口保持一個拳頭距離";
            color = Colors.red;
            problemKeypoints.addAll([0, 5]); // 標記頭部和肩膀
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
      }
    }
    return {
      'feedback': feedback,
      'color': color,
      'problemKeypoints': problemKeypoints,
      'angles': angles,
    };
  }

  double _calculateAngle(List<double> a, List<double> b, List<double> c) {
    // a, b, c are [y, x, score]
    // atan2(y, x) -> but image coordinates y is down.
    // We need (x, y)
    
    final radians = atan2(c[0] - b[0], c[1] - b[1]) - atan2(a[0] - b[0], a[1] - b[1]);
    double angle = (radians * 180.0 / pi).abs();
    
    if (angle > 180.0) {
      angle = 360 - angle;
    }
    return angle;
  }
}
