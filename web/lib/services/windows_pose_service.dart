import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera_windows/camera_windows.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart'; // For Color
import '../analyzers/exercise_analyzer.dart';
import '../analyzers/squat_analyzer.dart';
import '../analyzers/deadlift_analyzer.dart';
import '../analyzers/bench_press_analyzer.dart';
import '../analyzers/push_up_analyzer.dart';
import '../analyzers/pull_up_analyzer.dart';
import '../analyzers/shoulder_press_analyzer.dart';
import '../analyzers/lateral_raise_analyzer.dart';
import '../analyzers/curl_analyzer.dart';
import '../analyzers/tricep_extension_analyzer.dart';
import '../analyzers/crunch_analyzer.dart';

class WindowsPoseService {
  Interpreter? _interpreter;
  Interpreter? _classifierInterpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  
  // Current Analyzer
  ExerciseAnalyzer? _analyzer;
  String _currentExerciseName = "偵測中...";
  
  // Stream controller for results
  final _resultController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get resultStream => _resultController.stream;

  // Model input shape
  static const int inputSize = 256;

  Future<void> initialize() async {
    try {
      // Default analyzer
      _analyzer = SquatAnalyzer();

      // Load MoveNet
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset('assets/models/movenet_thunder.tflite', options: options);
      _interpreter!.allocateTensors();

      // Load Classifier
      try {
        _classifierInterpreter = await Interpreter.fromAsset('assets/models/pose_classifier.tflite');
        _classifierInterpreter!.allocateTensors();
        
        final labelData = await rootBundle.loadString('assets/models/pose_labels.txt');
        _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
        print('WindowsPoseService: Classifier loaded with ${_labels.length} labels');
      } catch (e) {
        print('WindowsPoseService Warning: Classifier not found ($e). Auto-classification disabled.');
      }
      
      _isLoaded = true;
      print('WindowsPoseService: Models loaded');
      
    } catch (e) {
      print('WindowsPoseService Error: $e');
      throw e;
    }
  }

  // Auto Classification Flag
  bool _autoClassification = true;
  void setAutoClassification(bool enabled) {
    _autoClassification = enabled;
  }

  // Not strictly needed if auto-classification works, but kept for manual override if needed
  void setExercise(String exerciseName) {
    _setAnalyzer(exerciseName);
  }

  void _setAnalyzer(String exerciseName) {
    if (_currentExerciseName == exerciseName) return; // No change

    if (exerciseName.contains('深蹲') || exerciseName.contains('squat')) {
      _analyzer = SquatAnalyzer();
    } else if (exerciseName.contains('硬舉') || exerciseName.contains('deadlift')) {
      _analyzer = DeadliftAnalyzer();
    } else if (exerciseName.contains('臥推') || exerciseName.contains('bench_press')) {
      _analyzer = BenchPressAnalyzer();
    } else if (exerciseName.contains('伏地挺身') || exerciseName.contains('push_up')) {
      _analyzer = PushUpAnalyzer();
    } else if (exerciseName.contains('引體向上') || exerciseName.contains('pull_up')) {
      _analyzer = PullUpAnalyzer();
    } else if (exerciseName.contains('肩推') || exerciseName.contains('shoulder_press')) {
      _analyzer = ShoulderPressAnalyzer();
    } else if (exerciseName.contains('側平舉') || exerciseName.contains('lateral_raise')) {
      _analyzer = LateralRaiseAnalyzer();
    } else if (exerciseName.contains('彎舉') || exerciseName.contains('curl')) {
      _analyzer = CurlAnalyzer();
    } else if (exerciseName.contains('三頭') || exerciseName.contains('tricep')) {
      _analyzer = TricepExtensionAnalyzer();
    } else if (exerciseName.contains('捲腹') || exerciseName.contains('crunch')) {
      _analyzer = CrunchAnalyzer();
    }
    
    _currentExerciseName = exerciseName;
  }

  Future<void> processFrame(CameraImage cameraImage) async {
    if (!_isLoaded || _interpreter == null) return;

    // 1. Convert CameraImage to img.Image
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final Uint8List bytes = cameraImage.planes[0].bytes;
    final img.Image image = img.Image.fromBytes(
      width: width, 
      height: height, 
      bytes: bytes.buffer,
      order: img.ChannelOrder.bgra, 
    ); 

    await _processImage(image);
  }

  Future<void> processFrameFromBytes(Uint8List bytes) async {
    if (!_isLoaded || _interpreter == null) return;
    
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return;
    
    await _processImage(image);
  }
  
  Future<void> processFrameFromRawBgra(Uint8List bytes, int width, int height) async {
    if (!_isLoaded || _interpreter == null) return;
    
    final img.Image image = img.Image.fromBytes(
      width: width, 
      height: height, 
      bytes: bytes.buffer,
      order: img.ChannelOrder.rgba, // Flutter uses RGBA often
    );
    
    await _processImage(image);
  }

  Future<void> _processImage(img.Image image) async {
    // 2. Letterbox Resize
    final int targetSize = inputSize;
    
    final double scale = (targetSize / image.width) < (targetSize / image.height)
        ? (targetSize / image.width)
        : (targetSize / image.height);
        
    final int newWidth = (image.width * scale).round();
    final int newHeight = (image.height * scale).round();
    
    final int padX = (targetSize - newWidth) ~/ 2;
    final int padY = (targetSize - newHeight) ~/ 2;

    final img.Image resizedContent = img.copyResize(image, width: newWidth, height: newHeight);
    final img.Image paddedImage = img.Image(width: targetSize, height: targetSize);
    img.fill(paddedImage, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(paddedImage, resizedContent, dstX: padX, dstY: padY);

    // 3. Prepare Input Tensor
    final inputBytes = Uint8List(1 * targetSize * targetSize * 3);
    int pixelIndex = 0;
    
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = paddedImage.getPixel(x, y);
        inputBytes[pixelIndex++] = pixel.r.toInt();
        inputBytes[pixelIndex++] = pixel.g.toInt();
        inputBytes[pixelIndex++] = pixel.b.toInt();
      }
    }
    
    // Reshape output
    var outputBox = List.filled(1 * 1 * 17 * 3, 0.0).reshape([1, 1, 17, 3]);

    // 4. Run Inference (MoveNet)
    _interpreter!.run(inputBytes.reshape([1, 256, 256, 3]), outputBox);

    // 5. Process Output & Inverse Map Coordinates
    final rawKeypoints = outputBox[0][0]; 
    
    List<List<double>> keypoints = [];
    for (var k in rawKeypoints) {
      double y = k[0]; 
      double x = k[1]; 
      double score = k[2];
      
      double yPx = y * targetSize;
      double xPx = x * targetSize;
      double yContent = yPx - padY;
      double xContent = xPx - padX;
      double yOriginal = yContent / scale;
      double xOriginal = xContent / scale;
      double yFinal = yOriginal / image.height;
      double xFinal = xOriginal / image.width;
      
      keypoints.add([yFinal, xFinal, score]);
    }

    // 6. Run Classification (if loaded)
    Map<String, dynamic> classificationResult = {'label': 'Unknown', 'score': 0.0};
    
    if (_classifierInterpreter != null && _labels.isNotEmpty) {
      classificationResult = _runClassification(keypoints);
      
      // Update Analyzer if score is high enough
      if (_autoClassification && classificationResult['score'] > 0.8) { // Confidence threshold
         String label = classificationResult['label'];
         _setAnalyzer(label);
      }
    }

    // 7. Analyze with current analyzer
    final AnalysisResult analysis = _analyzer?.analyze(keypoints) ?? AnalysisResult(
        feedback: "偵測中...", color: Colors.white
    );

    // 8. Stream Result
    _resultController.add({
      'keypoints': keypoints,
      'label': classificationResult['label'], // Show detectable label
      'score': classificationResult['score'], 
      'analysis': {
         'feedback': analysis.feedback,
         'color': analysis.color, // Send Color object directly or value? Color object is fine within Flutter
         'problemKeypoints': analysis.problemKeypoints,
         'angles': analysis.angles,
      },
    });
  }

  Map<String, dynamic> _runClassification(List<List<double>> keypoints) {
     if (_classifierInterpreter == null) return {'label': 'Unknown', 'score': 0.0};

     // Flatten keypoints: [x, y, score, x, y, score...] 
     // Note: Mobile used [x, y, score]. Let's check mobile impl again.
     // Mobile: input.add(kp[1]); // x
     // Mobile: input.add(kp[0]); // y
     // Mobile: input.add(kp[2]); // score
     
     List<double> input = [];
     for (var kp in keypoints) {
       input.add(kp[1]); // x
       input.add(kp[0]); // y
       input.add(kp[2]); // score
     }
     
     var inputTensor = [input];
     var outputBuffer = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
     
     _classifierInterpreter!.run(inputTensor, outputBuffer);
     
     List<double> scores = outputBuffer[0];
     double maxScore = -1;
     int maxIndex = -1;
     
     for (int i = 0; i < scores.length; i++) {
       if (scores[i] > maxScore) {
         maxScore = scores[i];
         maxIndex = i;
       }
     }
     
     if (maxIndex != -1) {
       return {
         'label': _labels[maxIndex],
         'score': maxScore,
       };
     }
     
     return {'label': 'Unknown', 'score': 0.0};
  }

  void dispose() {
    _interpreter?.close();
    _classifierInterpreter?.close();
    _resultController.close();
  }
}
