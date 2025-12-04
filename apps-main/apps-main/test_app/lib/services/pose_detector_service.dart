import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Request object sent to Isolate
class InferenceRequest {
  final int id;
  final Uint8List? yBytes;
  final Uint8List? uBytes;
  final Uint8List? vBytes;
  final Uint8List? rgbBytes; // Added for file-based inference
  final int width;
  final int height;
  final int rotation;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final String exerciseName;
  final bool isFile; // Flag to indicate file-based inference

  InferenceRequest({
    required this.id,
    this.yBytes,
    this.uBytes,
    this.vBytes,
    this.rgbBytes,
    required this.width,
    required this.height,
    required this.rotation,
    this.yRowStride = 0,
    this.uvRowStride = 0,
    this.uvPixelStride = 0,
    required this.exerciseName,
    this.isFile = false,
  });
}

// Response object received from Isolate
class InferenceResponse {
  final int id;
  final Map<String, dynamic>? result;
  final String? error;

  InferenceResponse({required this.id, this.result, this.error});
}

class PoseDetectorService {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  
  final StreamController<Map<String, dynamic>> _resultController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get resultStream => _resultController.stream;

  // Completer map for request-response matching (for file inference)
  final Map<int, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  bool _isIsolateReady = false;
  bool _isBusy = false;
  int _requestIdCounter = 0;

  Future<void> initialize() async {
    if (_isIsolateReady) return; // Already initialized

    _receivePort = ReceivePort();
    final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;

    // Load models in Main Isolate
    try {
      final movenetData = await rootBundle.load('assets/models/movenet_thunder.tflite');
      final movenetBytes = movenetData.buffer.asUint8List();

      final classifierData = await rootBundle.load('assets/models/pose_classifier.tflite');
      final classifierBytes = classifierData.buffer.asUint8List();

      final labelContent = await rootBundle.loadString('assets/models/pose_labels.txt');

      _isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateInitData(
          _receivePort!.sendPort,
          rootIsolateToken,
          movenetBytes,
          classifierBytes,
          labelContent,
        ),
      );
    } catch (e) {
      print("Main Isolate: Failed to load assets: $e");
      return;
    }

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _isIsolateReady = true;
        print("PoseDetectorService: Isolate Ready");
      } else if (message is InferenceResponse) {
        _isBusy = false;
        
        // Check if there is a pending completer for this ID
        if (_pendingRequests.containsKey(message.id)) {
          if (message.error != null) {
            print("Isolate Error (File): ${message.error}");
            _pendingRequests[message.id]?.complete(null);
          } else {
            _pendingRequests[message.id]?.complete(message.result);
          }
          _pendingRequests.remove(message.id);
        } else {
          // Stream mode (Camera)
          if (message.error != null) {
            print("Isolate Error (Stream): ${message.error}");
          } else if (message.result != null) {
            _resultController.add(message.result!);
          }
        }
      }
    });
  }
  
  // Alias for backward compatibility if needed, but VideoAnalysisPage should call initialize()
  Future<void> loadModels() => initialize();

  void processFrame(CameraImage image, int rotation, String exerciseName) {
    if (!_isIsolateReady || _isBusy || _sendPort == null) return;

    _isBusy = true;
    final id = _requestIdCounter++;

    final yBytes = Uint8List.fromList(image.planes[0].bytes);
    final uBytes = Uint8List.fromList(image.planes[1].bytes);
    final vBytes = Uint8List.fromList(image.planes[2].bytes);

    final request = InferenceRequest(
      id: id,
      yBytes: yBytes,
      uBytes: uBytes,
      vBytes: vBytes,
      width: image.width,
      height: image.height,
      rotation: rotation,
      yRowStride: image.planes[0].bytesPerRow,
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      exerciseName: exerciseName,
      isFile: false,
    );

    _sendPort!.send(request);
  }

  // New method for File Inference via Isolate
  Future<Map<String, dynamic>?> detectFromFile(File imageFile, String exerciseName) async {
    if (!_isIsolateReady || _sendPort == null) {
      await initialize();
      // Wait a bit for isolate to be ready if it wasn't
      int retries = 0;
      while (!_isIsolateReady && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
      if (!_isIsolateReady) return null;
    }

    final id = _requestIdCounter++;
    final completer = Completer<Map<String, dynamic>?>();
    _pendingRequests[id] = completer;

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        _pendingRequests.remove(id);
        return null;
      }

      // Convert image to RGB bytes
      // image.getBytes() returns RGBA or RGB depending on format, usually RGBA for decoded images
      // We need to ensure it's what we expect. 
      // For simplicity, let's send the raw decoded bytes and handle in Isolate, 
      // OR just send the file path? No, Isolate can't read assets easily but can read files.
      // Sending bytes is safer.
      
      // Ensure RGB format
      final rgbImage = image.convert(format: img.Format.uint8, numChannels: 3);
      final rgbBytes = rgbImage.getBytes();

      final request = InferenceRequest(
        id: id,
        rgbBytes: rgbBytes,
        width: rgbImage.width,
        height: rgbImage.height,
        rotation: 0, // Files are usually upright or handled by decoder
        exerciseName: exerciseName,
        isFile: true,
      );

      _sendPort!.send(request);
      
      return completer.future;
    } catch (e) {
      print("Error in detectFromFile: $e");
      _pendingRequests.remove(id);
      return null;
    }
  }

  void close() {
    _isolate?.kill();
    _receivePort?.close();
    _resultController.close();
  }

  // --- Isolate Entry Point ---
  static void _isolateEntry(_IsolateInitData initData) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(initData.token);
    final receivePort = ReceivePort();
    initData.sendPort.send(receivePort.sendPort);

    Interpreter? movenetInterpreter;
    Interpreter? classifierInterpreter;
    List<String>? labels;
    
    String? loadingError;
    try {
      final movenetOptions = InterpreterOptions()..threads = 4;
      
      // NNAPI and GPU Delegates are not fully supported or performant in this version.
      // Reverting to optimized CPU execution.

      // Use fromBuffer instead of fromAsset
      movenetInterpreter = Interpreter.fromBuffer(initData.movenetBytes, options: movenetOptions);
      classifierInterpreter = Interpreter.fromBuffer(initData.classifierBytes);
      
      // Use passed label content
      labels = initData.labelContent.split('\n').where((s) => s.isNotEmpty).toList();
      
      print("Isolate: Models loaded successfully from buffer");
    } catch (e, stack) {
      print("Isolate: Failed to load models: $e");
      loadingError = "Load Failed: $e\n$stack";
    }

    // Process Loop
    await for (final message in receivePort) {
      if (message is InferenceRequest) {
        try {
          if (movenetInterpreter == null || classifierInterpreter == null || labels == null) {
            initData.sendPort.send(InferenceResponse(id: message.id, error: loadingError ?? "Models not loaded (Unknown reason)"));
            continue;
          }

          // Check Input Type (Once)
          var inputType = movenetInterpreter.getInputTensor(0).type;
          
          Map<String, dynamic>? inputTensor;
          
          if (message.isFile) {
             inputTensor = _preprocessRGB(message);
          } else {
             inputTensor = _preprocessYUV(message);
          }

          if (inputTensor == null) {
             initData.sendPort.send(InferenceResponse(id: message.id, error: "Preprocessing failed"));
             continue;
          }

          var tensorData = inputTensor['tensor'];
          
          // Debug: Print first pixel
          // var firstPixel = tensorData[0][0][0];
          // print("Isolate: Input Type: $inputType, First Pixel: $firstPixel");

          // Run Inference
          var outputBuffer = List.filled(1 * 1 * 17 * 3, 0.0).reshape([1, 1, 17, 3]);
          movenetInterpreter.run(tensorData, outputBuffer);

          // Post-process
          List<List<double>> keypoints = [];
          var rawKeypoints = outputBuffer[0][0];
          
          double maxScore = 0.0;

          double padX = inputTensor['padX'];
          double padY = inputTensor['padY'];
          double contentWidth = 256.0 - 2 * padX;
          double contentHeight = 256.0 - 2 * padY;

          for (var kp in rawKeypoints) {
            double y = kp[0];
            double x = kp[1];
            double score = kp[2];
            if (score > maxScore) maxScore = score;

            double yPx = y * 256.0;
            double xPx = x * 256.0;
            double yContent = yPx - padY;
            double xContent = xPx - padX;
            double yOrig = yContent / contentHeight;
            double xOrig = xContent / contentWidth;

            keypoints.add([yOrig, xOrig, score]); 
          }
          
          // print("Isolate: Max Score: $maxScore");

          var classificationResult = _runClassification(classifierInterpreter, labels, keypoints);
          var analysisResult = _analyzePose(keypoints, classificationResult, message.exerciseName);

          var finalResult = <String, dynamic>{
            'keypoints': keypoints,
            'classification': classificationResult,
            'debug_max_score': maxScore, // Send back for debugging
            'debug_input_type': inputType.toString(),
          };
          finalResult.addAll(analysisResult);

          initData.sendPort.send(InferenceResponse(id: message.id, result: finalResult));

        } catch (e) {
          initData.sendPort.send(InferenceResponse(id: message.id, error: e.toString()));
        }
      }
    }
  }
  
  static Map<String, dynamic>? _preprocessRGB(InferenceRequest req) {
    try {
      if (req.rgbBytes == null) return null;
      
      const int targetSize = 256;
      final int srcW = req.width;
      final int srcH = req.height;
      
      // Calculate scaling (Letterboxing)
      double scale = min(targetSize / srcW, targetSize / srcH);
      int newW = (srcW * scale).round();
      int newH = (srcH * scale).round();
      
      int padX = (targetSize - newW) ~/ 2;
      int padY = (targetSize - newH) ~/ 2;
      
      // req.rgbBytes is flat [r, g, b, r, g, b...]
      // We need to sample from it.
      
      var input = List.generate(targetSize, (y) {
        return List.generate(targetSize, (x) {
          if (x < padX || x >= padX + newW || y < padY || y >= padY + newH) {
            return [0, 0, 0];
          }
          
          int logicalX = ((x - padX) / scale).floor().clamp(0, srcW - 1);
          int logicalY = ((y - padY) / scale).floor().clamp(0, srcH - 1);
          
          int index = (logicalY * srcW + logicalX) * 3;
          
          return [
            req.rgbBytes![index],
            req.rgbBytes![index + 1],
            req.rgbBytes![index + 2]
          ];
        });
      });
      
      return {
        'tensor': [input],
        'padX': padX.toDouble(),
        'padY': padY.toDouble(),
      };
    } catch (e) {
      print("Preprocess RGB Error: $e");
      return null;
    }
  }


  // --- Static Helpers for Isolate ---
  
  static Map<String, dynamic>? _preprocessYUV(InferenceRequest req) {
    try {
      if (req.yBytes == null || req.uBytes == null || req.vBytes == null) {
        return null;
      }

      const int targetSize = 256;
      final int srcW = req.width;
      final int srcH = req.height;
      final int rotation = req.rotation;

      final bool isRotated90 = rotation == 90 || rotation == 270;
      final int logicalSrcW = isRotated90 ? srcH : srcW;
      final int logicalSrcH = isRotated90 ? srcW : srcH;

      double scale = min(targetSize / logicalSrcW, targetSize / logicalSrcH);
      int newW = (logicalSrcW * scale).round();
      int newH = (logicalSrcH * scale).round();

      int padX = (targetSize - newW) ~/ 2;
      int padY = (targetSize - newH) ~/ 2;

      // Generate [256, 256, 3] flat buffer
      final int totalPixels = targetSize * targetSize;
      final Uint8List input = Uint8List(totalPixels * 3);
      // Uint8List is already initialized to 0, so we don't need to fill padding with 0s manually.
      
      final int startY = padY;
      final int endY = padY + newH;
      final int startX = padX;
      final int endX = padX + newW;

      // Pre-calculate reciprocal scale for faster multiplication
      final double invScale = 1.0 / scale;

      for (int y = startY; y < endY; y++) {
        // Calculate logicalY once per row
        int logicalY = ((y - padY) * invScale).floor();
        
        // Clamp logicalY to be safe
        if (logicalY < 0) logicalY = 0;
        if (logicalY >= srcH) logicalY = srcH - 1;

        int pixelIndex = (y * targetSize + startX) * 3;

        for (int x = startX; x < endX; x++) {
          int logicalX = ((x - padX) * invScale).floor();
          
          // Clamp logicalX
          if (logicalX < 0) logicalX = 0;
          if (logicalX >= srcW) logicalX = srcW - 1;

          int srcX, srcY;
          if (rotation == 90) {
            srcX = logicalY;
            srcY = srcH - 1 - logicalX; 
          } else if (rotation == 270) {
             srcX = srcW - 1 - logicalY;
             srcY = logicalX;
          } else if (rotation == 180) {
            srcX = srcW - 1 - logicalX;
            srcY = srcH - 1 - logicalY;
          } else {
            srcX = logicalX;
            srcY = logicalY;
          }

          // Double check bounds (though clamping above should handle it)
          // srcX = srcX.clamp(0, srcW - 1);
          // srcY = srcY.clamp(0, srcH - 1);

          final int yIndex = srcY * req.yRowStride + srcX;
          final int uvIndex = (srcY ~/ 2) * req.uvRowStride + (srcX ~/ 2) * req.uvPixelStride;

          final int yValue = req.yBytes![yIndex];
          final int uValue = req.uBytes![uvIndex];
          final int vValue = req.vBytes![uvIndex];

          // Inline YUV to RGB (Integer approximation)
          // R = Y + 1.402 * (V - 128)
          // G = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)
          // B = Y + 1.772 * (U - 128)
          
          // Using integer math for speed (approximate)
          // C = Y - 16 (but we use Y directly as 0-255)
          // D = U - 128
          // E = V - 128
          // R = (298 * C + 409 * E + 128) >> 8
          // ... simpler version:
          
          final int c = yValue - 16;
          final int d = uValue - 128;
          final int e = vValue - 128;
          
          int r = (298 * c + 409 * e + 128) >> 8;
          int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
          int b = (298 * c + 516 * d + 128) >> 8;

          input[pixelIndex++] = r.clamp(0, 255);
          input[pixelIndex++] = g.clamp(0, 255);
          input[pixelIndex++] = b.clamp(0, 255);
        }
      }

      return {
        'tensor': input, // Flat buffer
        'padX': padX.toDouble(),
        'padY': padY.toDouble(),
      };
    } catch (e) {
      print("Preprocess Error: $e");
      return null;
    }
  }

  static int _yuv2r(int y, int u, int v) {
    return (y + (1.370705 * (v - 128))).clamp(0, 255).toInt();
  }

  static int _yuv2g(int y, int u, int v) {
    return (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).clamp(0, 255).toInt();
  }

  static int _yuv2b(int y, int u, int v) {
    return (y + (1.732446 * (u - 128))).clamp(0, 255).toInt();
  }

  static Map<String, dynamic> _runClassification(Interpreter interpreter, List<String> labels, List<List<double>> keypoints) {
    List<double> input = [];
    for (var kp in keypoints) {
      input.add(kp[1]); // x
      input.add(kp[0]); // y
      input.add(kp[2]); // score
    }
    
    var inputTensor = [input];
    var outputBuffer = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);
    
    interpreter.run(inputTensor, outputBuffer);
    
    List<double> scores = outputBuffer[0];
    double maxScore = -1;
    int maxIndex = -1;
    
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    
    return {
      'label': labels[maxIndex],
      'score': maxScore,
    };
  }

  // Copied from original service, made static
  static Map<String, dynamic> _analyzePose(List<List<double>> keypoints, Map<String, dynamic> classification, String exerciseName) {
    final score = classification['score'];
    String feedback = "偵測中...";
    Color color = Colors.white;
    Set<int> problemKeypoints = {};
    Map<String, double> angles = {};

    double _calculateAngle(List<double> a, List<double> b, List<double> c) {
      final radians = atan2(c[0] - b[0], c[1] - b[1]) - atan2(a[0] - b[0], a[1] - b[1]);
      double angle = (radians * 180.0 / pi).abs();
      if (angle > 180.0) angle = 360 - angle;
      return angle;
    }

    double? getAngle(int idx1, int idx2, int idx3) {
      if (keypoints[idx1][2] > 0.2 && keypoints[idx2][2] > 0.2 && keypoints[idx3][2] > 0.2) {
        return _calculateAngle(keypoints[idx1], keypoints[idx2], keypoints[idx3]);
      }
      return null;
    }

    double? getAverageAngle(int left1, int left2, int left3, int right1, int right2, int right3) {
      double? left = getAngle(left1, left2, left3);
      double? right = getAngle(right1, right2, right3);
      if (left != null && right != null) return (left + right) / 2;
      return left ?? right;
    }

    if (score > 0.4) {
      if (exerciseName.contains('深蹲')) {
        double? kneeAngle = getAverageAngle(11, 13, 15, 12, 14, 16);
        double? hipAngle = getAverageAngle(5, 11, 13, 6, 12, 14);
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
      } 
      else if (exerciseName.contains('硬舉')) {
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
      else if (exerciseName.contains('臥推')) {
        double? angle = getAverageAngle(5, 7, 9, 6, 8, 10);
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
      }
      else if (exerciseName.contains('伏地挺身')) {
        double? armAngle = getAverageAngle(5, 7, 9, 6, 8, 10);
        double? bodyAngle = getAverageAngle(5, 11, 15, 6, 12, 16);
        const double LOCKOUT_ANGLE = 170; 
        const double DEPTH_ANGLE = 90;    

        if (bodyAngle != null && bodyAngle < 150) {
           feedback = "腰部塌陷！收緊核心";
           color = Colors.red;
           problemKeypoints.addAll([11, 12]);
        } else if (armAngle != null && armAngle > LOCKOUT_ANGLE) {
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
      else if (exerciseName.contains('引體向上')) {
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10); 
        double? trunkAngle = getAverageAngle(5, 11, 13, 6, 12, 14); 
        
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
      }
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
      else if (exerciseName.contains('側平舉')) {
        double? shoulderAbductionAngle = getAverageAngle(11, 5, 7, 12, 6, 8); 
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10);
        
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
      }
      else if (exerciseName.contains('彎舉')) {
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10); 
        double? shoulderAngle = getAverageAngle(7, 5, 11, 8, 6, 12); 
        
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
      }
      else if (exerciseName.contains('三頭')) {
        double? elbowAngle = getAverageAngle(5, 7, 9, 6, 8, 10);
        double? upperArmAngle = getAverageAngle(11, 5, 7, 12, 6, 8); 
        
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
      }
      else if (exerciseName.contains('捲腹')) {
        double? shkAngle = getAverageAngle(5, 11, 13, 6, 12, 14); 
        double? neckAngle = getAngle(0, 5, 11);

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
      }
    }
    return {
      'feedback': feedback,
      'color': color,
      'problemKeypoints': problemKeypoints,
      'angles': angles,
    };
  }

  static double? getKeypointY(List<List<double>> keypoints, int index) {
      if (index < keypoints.length && keypoints[index][2] > 0.2) {
        return keypoints[index][0];
      }
      return null;
  }
}

class _IsolateInitData {
  final SendPort sendPort;
  final RootIsolateToken token;
  final Uint8List movenetBytes;
  final Uint8List classifierBytes;
  final String labelContent;

  _IsolateInitData(
    this.sendPort,
    this.token,
    this.movenetBytes,
    this.classifierBytes,
    this.labelContent,
  );
}
