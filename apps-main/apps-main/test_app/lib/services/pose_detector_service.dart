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

import 'analyzers/exercise_analyzer.dart';
import 'analyzers/squat_analyzer.dart';
import 'analyzers/deadlift_analyzer.dart';
import 'analyzers/bench_press_analyzer.dart';
import 'analyzers/push_up_analyzer.dart';
import 'analyzers/pull_up_analyzer.dart';
import 'analyzers/shoulder_press_analyzer.dart';
import 'analyzers/lateral_raise_analyzer.dart';
import 'analyzers/bicep_curl_analyzer.dart';
import 'analyzers/tricep_pushdown_analyzer.dart';
import 'analyzers/crunch_analyzer.dart';
import 'analyzers/walking_analyzer.dart';


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
      // Switch to Lightning for speed
      final movenetData = await rootBundle.load('assets/models/movenet_lightning.tflite');
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

    // Optimize: Avoid copying if possible. Passing direct bytes view.
    // NOTE: If camera plugin recycles these buffers too quickly before isolate reads them, 
    // we might see glitches. If so, revert to fromList (copy).
    // Testing availability of direct passing.
    final yBytes = image.planes[0].bytes;
    final uBytes = image.planes[1].bytes;
    final vBytes = image.planes[2].bytes;

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
      // Enable XNNPACK which is highly optimized for CPU inference on Mobile
      final movenetOptions = InterpreterOptions()..threads = 4;
      
      // Attempt to add XNNPack delegate
      // Note: If running on emulator x86, this might fail or fallback.
      // On real devices (ARM), this is critical for speed.
      try {
        if (Platform.isAndroid || Platform.isIOS) {
             movenetOptions.addDelegate(XNNPackDelegate());
        }
      } catch (e) {
        print("Isolate: XNNPackDelegate not supported or failed: $e");
      }
      
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
          
          // Run Inference
          var outputBuffer = List.filled(1 * 1 * 17 * 3, 0.0).reshape([1, 1, 17, 3]);
          movenetInterpreter.run(tensorData, outputBuffer);

          // Post-process
          List<List<double>> keypoints = [];
          var rawKeypoints = outputBuffer[0][0];
          
          double maxScore = 0.0;

          double padX = inputTensor['padX'];
          double padY = inputTensor['padY'];
          // Lightning is 192x192
          double contentWidth = 192.0 - 2 * padX;
          double contentHeight = 192.0 - 2 * padY;

          for (var kp in rawKeypoints) {
            double y = kp[0];
            double x = kp[1];
            double score = kp[2];
            if (score > maxScore) maxScore = score;

            double yPx = y * 192.0;
            double xPx = x * 192.0;
            double yContent = yPx - padY;
            double xContent = xPx - padX;
            double yOrig = yContent / contentHeight;
            double xOrig = xContent / contentWidth;

            keypoints.add([yOrig, xOrig, score]); 
          }
          
          var classificationResult = _runClassification(classifierInterpreter, labels, keypoints);
          var analysisResult = _analyzePose(keypoints, classificationResult, message.exerciseName);

          var finalResult = <String, dynamic>{
            'keypoints': keypoints,
            'classification': classificationResult,
            'debug_max_score': maxScore, 
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
      
      const int targetSize = 192; // Lightning
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

      const int targetSize = 192; // Lightning
      final int srcW = req.width;
      final int srcH = req.height;
      final int rotation = req.rotation;

      // Determine logical dimensions based on rotation
      final bool isRotated90 = rotation == 90 || rotation == 270;
      final int logicalSrcW = isRotated90 ? srcH : srcW;
      final int logicalSrcH = isRotated90 ? srcW : srcH;

      // Calculate Scaling (Letterboxing)
      double scale = min(targetSize / logicalSrcW, targetSize / logicalSrcH);
      int newW = (logicalSrcW * scale).round();
      int newH = (logicalSrcH * scale).round();

      int padX = (targetSize - newW) ~/ 2;
      int padY = (targetSize - newH) ~/ 2;

      final int totalPixels = targetSize * targetSize;
      final Uint8List input = Uint8List(totalPixels * 3);

      final int startY = padY;
      final int endY = padY + newH;
      final int startX = padX;
      final int endX = padX + newW;

      final double invScale = 1.0 / scale;
      
      // Optimization: Handle rotation outside the loop to avoid 'if' checks per pixel
      if (rotation == 90) {
        _fillBufferRotated90(
          input, req, startX, endX, startY, endY, padX, padY, invScale, targetSize, srcW, srcH
        );
      } else if (rotation == 270) {
        _fillBufferRotated270(
          input, req, startX, endX, startY, endY, padX, padY, invScale, targetSize, srcW, srcH
        );
      } else {
         // Default 0 (or 180 which is rare for back cam, but treating as 0 for basic logic or just generic)
         // For simplicity in this optimization step, we focus on 0/90/270. 180 can fall back to generic if needed, 
         // but here we implements 0.
        _fillBufferRotated0(
           input, req, startX, endX, startY, endY, padX, padY, invScale, targetSize, srcW, srcH
        );
      }

      return {
        'tensor': input,
        'padX': padX.toDouble(),
        'padY': padY.toDouble(),
      };
    } catch (e) {
      print("Preprocess Error: $e");
      return null;
    }
  }

  // Optimized Loop for Rotation 0
  static void _fillBufferRotated0(
      Uint8List input, InferenceRequest req, 
      int startX, int endX, int startY, int endY, 
      int padX, int padY, double invScale, int targetSize, int srcW, int srcH) {
    
    final yBytes = req.yBytes!;
    final uBytes = req.uBytes!;
    final vBytes = req.vBytes!;
    final yRowStride = req.yRowStride;
    final uvRowStride = req.uvRowStride;
    final uvPixelStride = req.uvPixelStride;

    for (int y = startY; y < endY; y++) {
      int logicalY = ((y - padY) * invScale).floor();
      if (logicalY >= srcH) logicalY = srcH - 1; 

      int pixelIndex = (y * targetSize + startX) * 3;
      
      // Optimization: Calculate row pointers once per row
      int yRowOffset = logicalY * yRowStride;
      int uvRowOffset = (logicalY >> 1) * uvRowStride;

      for (int x = startX; x < endX; x++) {
        int logicalX = ((x - padX) * invScale).floor();
        if (logicalX >= srcW) logicalX = srcW - 1;

        // Src coords for Rot 0 are just logical coords
        // srcX = logicalX, srcY = logicalY
        
        int yIndex = yRowOffset + logicalX;
        // int uvIndex = (logicalY ~/ 2) * uvRowStride + (logicalX ~/ 2) * uvPixelStride;
        // Optimized:
        int uvIndex = uvRowOffset + (logicalX >> 1) * uvPixelStride;

        int yValue = yBytes[yIndex];
        int uValue = uBytes[uvIndex];
        int vValue = vBytes[uvIndex];

        _yuvToRgb(yValue, uValue, vValue, input, pixelIndex);
        pixelIndex += 3;
      }
    }
  }

  // Optimized Loop for Rotation 90 (Common for Portrait)
  static void _fillBufferRotated90(
      Uint8List input, InferenceRequest req, 
      int startX, int endX, int startY, int endY, 
      int padX, int padY, double invScale, int targetSize, int srcW, int srcH) {
    
    final yBytes = req.yBytes!;
    final uBytes = req.uBytes!;
    final vBytes = req.vBytes!;
    final yRowStride = req.yRowStride;
    final uvRowStride = req.uvRowStride;
    final uvPixelStride = req.uvPixelStride;

    for (int y = startY; y < endY; y++) {
      int logicalY = ((y - padY) * invScale).floor(); // 0..srcH (which is width of phone)
      // Clamp not strictly needed if Letterboxing is correct, but safe
      if (logicalY >= srcW) logicalY = srcW - 1; // logicalSrcH is srcW

      int pixelIndex = (y * targetSize + startX) * 3;

      for (int x = startX; x < endX; x++) {
        int logicalX = ((x - padX) * invScale).floor(); // 0..srcW (which is height of phone)
        if (logicalX >= srcH) logicalX = srcH - 1; // logicalSrcW is srcH

        // ROTATION 90 Mapping:
        // visual x,y corresponds to:
        // srcX = logicalY
        // srcY = srcH - 1 - logicalX
        
        int srcX = logicalY;
        int srcY = srcH - 1 - logicalX;

        int yIndex = srcY * yRowStride + srcX;
        int uvIndex = (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;

        int yValue = yBytes[yIndex];
        int uValue = uBytes[uvIndex];
        int vValue = vBytes[uvIndex];

        _yuvToRgb(yValue, uValue, vValue, input, pixelIndex);
        pixelIndex += 3;
      }
    }
  }

  // Optimized Loop for Rotation 270 (Reverse Portrait)
  static void _fillBufferRotated270(
      Uint8List input, InferenceRequest req, 
      int startX, int endX, int startY, int endY, 
      int padX, int padY, double invScale, int targetSize, int srcW, int srcH) {
    
    final yBytes = req.yBytes!;
    final uBytes = req.uBytes!;
    final vBytes = req.vBytes!;
    final yRowStride = req.yRowStride;
    final uvRowStride = req.uvRowStride;
    final uvPixelStride = req.uvPixelStride;

    for (int y = startY; y < endY; y++) {
      int logicalY = ((y - padY) * invScale).floor();
      if (logicalY >= srcW) logicalY = srcW - 1;

      int pixelIndex = (y * targetSize + startX) * 3;

      for (int x = startX; x < endX; x++) {
        int logicalX = ((x - padX) * invScale).floor();
        if (logicalX >= srcH) logicalX = srcH - 1;

        // ROTATION 270 Mapping:
        // srcX = srcW - 1 - logicalY
        // srcY = logicalX
        
        int srcX = srcW - 1 - logicalY;
        int srcY = logicalX;

        int yIndex = srcY * yRowStride + srcX;
        int uvIndex = (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;

        int yValue = yBytes[yIndex];
        int uValue = uBytes[uvIndex];
        int vValue = vBytes[uvIndex];

        _yuvToRgb(yValue, uValue, vValue, input, pixelIndex);
        pixelIndex += 3;
      }
    }
  }

  // Inline-able YUV conversion
  static void _yuvToRgb(int y, int u, int v, Uint8List output, int offset) {
      final int c = y - 16;
      final int d = u - 128;
      final int e = v - 128;
      
      int r = (298 * c + 409 * e + 128) >> 8;
      int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
      int b = (298 * c + 516 * d + 128) >> 8;

      // Manual clamping is faster than .clamp() method overhead in tight loops in some Dart versions,
      // but .clamp is intrinsified. Stick to simple if/ternary if needed, but .clamp(0,255) is fine.
      // Using branchless clamp if possible, or just standard.
      output[offset] = r.clamp(0, 255);
      output[offset + 1] = g.clamp(0, 255);
      output[offset + 2] = b.clamp(0, 255);
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

  // Refactored to use Strategy Pattern
  static Map<String, dynamic> _analyzePose(List<List<double>> keypoints, Map<String, dynamic> classification, String exerciseName) {
    final score = classification['score'];
    ExerciseAnalyzer? analyzer;

    // Factory logic (simple string matching)
    if (exerciseName.contains('深蹲')) {
      analyzer = SquatAnalyzer();
    } else if (exerciseName.contains('硬舉')) {
      analyzer = DeadliftAnalyzer();
    } else if (exerciseName.contains('臥推')) {
      analyzer = BenchPressAnalyzer();
    } else if (exerciseName.contains('伏地挺身')) {
      analyzer = PushUpAnalyzer();
    } else if (exerciseName.contains('引體向上')) {
      analyzer = PullUpAnalyzer();
    } else if (exerciseName.contains('肩推')) {
      analyzer = ShoulderPressAnalyzer();
    } else if (exerciseName.contains('側平舉')) {
      analyzer = LateralRaiseAnalyzer();
    } else if (exerciseName.contains('彎舉')) {
      analyzer = BicepCurlAnalyzer();
    } else if (exerciseName.contains('三頭')) {
      analyzer = TricepPushdownAnalyzer();
    } else if (exerciseName.contains('捲腹')) {
      analyzer = CrunchAnalyzer();
    } else if (exerciseName.contains('走路') || exerciseName.contains('walking')) {
        analyzer = WalkingAnalyzer();
    }

    if (score > 0.4 && analyzer != null) {
      return analyzer.analyze(keypoints);
    }

    // Default return
    return {
      'feedback': "偵測中...",
      'color': Colors.white,
      'problemKeypoints': <int>{},
      'angles': <String, double>{},
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
