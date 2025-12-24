// lib/pages/training_session_page.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/exercise_model.dart';
import '../models/workout_log_model.dart';
import '../models/set_log_model.dart';
import '../models/plan_item_model.dart';
import './training_summary_page.dart';
import '../services/database_helper.dart';
import '../services/mock_data_service.dart';
import '../services/pose_detector_service.dart';
import '../services/pose_detector_service.dart';
import '../ui/pose_painter.dart';

import '../services/health_service.dart';
import '../models/user_model.dart';
import '../utils/calorie_calculator.dart';

class TrainingSessionPage extends StatefulWidget {
  final PlanItem currentItem;
  final List<PlanItem> remainingItems; 
  final BodyPart bodyPart; 
  final String account;
  final bool enableAi;

  const TrainingSessionPage({
    super.key,
    required this.currentItem,
    required this.remainingItems,
    required this.bodyPart,
    required this.account,
    this.enableAi = false,
  });

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> with WidgetsBindingObserver {
  Timer? _timer;
  late PlanItem _currentPlanItem;
  late List<PlanItem> _todoQueue;

  int _currentSet = 1;
  int _totalSets = 3; 
  int _countdownSeconds = 5;
  int _restTimeInSeconds = 60; 

  bool _isResting = false;
  bool _isPreparing = true;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _setsData = [];

  // --- AI / Camera Variables ---
  CameraController? _cameraController;
  PoseDetectorService? _poseDetectorService;
  bool _isDetecting = false;
  List<List<double>>? _currentKeypoints;
  String _aiFeedback = "";
  Color _feedbackColor = Colors.white;
  Set<int> _problemKeypoints = {};
  bool _showCamera = false;
  int _frameCount = 0;
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;
  ResolutionPreset _currentResolutionPreset = ResolutionPreset.medium; // Default to Medium
  // final RepCounter _repCounter = RepCounter(); // Removed
  // int _currentReps = 0; // Removed
  bool _isCounting = false;
  int _sensorOrientation = 0;



  // --- Health & Calorie Variables ---
  StreamSubscription<int>? _heartRateSubscription;
  int _currentHeartRate = 0;
  double _totalCaloriesBurned = 0.0;
  final List<int> _heartRateReadings = []; // [NEW] Collect HR samples
  User? _userProfile;
  Timer? _calorieTimer;

  String _debugInfo = "Init...";
  DateTime? _lastFrameTime;

  bool get _isBodyweightExercise {
    final name = _currentPlanItem.exerciseName;
    return name.contains('伏地挺身') || 
           name.contains('引體向上') || 
           name.contains('捲腹') ||
           name.contains('波比跳') ||
           name.contains('開合跳');
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPlanItem = widget.currentItem;
    _todoQueue = List.from(widget.remainingItems);
    _initCurrentExercise();
    _initAI();
    if (widget.enableAi) {
      _startCamera();
    }
    _initHealthAndUser();
  }

  Future<void> _initHealthAndUser() async {
    // 1. Load User Profile for Weight/Age/Gender
    final user = await DatabaseHelper.instance.getUserByAccount(widget.account);
    if (mounted) {
      setState(() {
        _userProfile = user;
      });
    }

    // 2. Request Health Permissions and Start Listening
    bool granted = await HealthService.instance.requestPermissions();
    if (granted) {
      _heartRateSubscription = HealthService.instance.heartRateStream.listen((hr) {
        if (mounted) {
          setState(() {
            _currentHeartRate = hr;
            if (hr > 0) {
              _heartRateReadings.add(hr);
            }
          });
        }
      });
      
      // 3. Start Calorie Calculation Timer (every 5 seconds)
      _calorieTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _calculateCalories();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法連接 Apple Health (權限被拒或未設定)'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateCalories() {
    if (_userProfile == null || _currentHeartRate <= 0) return;
    
    // Parse user data
    double weight = double.tryParse(_userProfile!.weight) ?? 70.0;
    int age = int.tryParse(_userProfile!.age) ?? 30;
    String gender = _userProfile!.gender ?? 'Male';
    
    // Calculate for the last 5 seconds (5/60 minutes)
    double burned = CalorieCalculator.calculateCalories(
      heartRate: _currentHeartRate,
      weightKg: weight,
      age: age,
      gender: gender,
      durationMinutes: 5 / 60.0,
    );
    
    if (mounted) {
      setState(() {
        _totalCaloriesBurned += burned;
      });
    }
  }


  Future<void> _initAI() async {
    _poseDetectorService = PoseDetectorService();
    await _poseDetectorService?.initialize();
    
    // Listen to results from Isolate
    _poseDetectorService?.resultStream.listen((result) {
      if (!mounted) return;
      _analyzePose(result);
    });
  }

  Future<void> _startCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        // Use current lens direction
        final camera = cameras.firstWhere(
          (camera) => camera.lensDirection == _currentLensDirection,
          orElse: () => cameras.first,
        );
        _sensorOrientation = camera.sensorOrientation;

          _cameraController = CameraController(
            camera,
            _currentResolutionPreset, // Use variable
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );

        await _cameraController?.initialize();
        if (!mounted) return;

        setState(() {
          _showCamera = true;
        });

        _cameraController?.startImageStream((image) {
          if (_isDetecting) return;
          _frameCount++;
          
          // Throttling: Relaxed to 30 FPS (33ms) since Isolate handles the load
          final now = DateTime.now();
          if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < 33) {
            return;
          }
          _lastFrameTime = now;

          // Use sensor orientation directly
          _poseDetectorService?.processFrame(image, _sensorOrientation, _currentPlanItem.exerciseName);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相機啟動失敗: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要相機權限才能使用 AI 教練')));
    }
  }

  void _stopCamera() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _showCamera = false;
      _currentKeypoints = null;
    });
  }

  void _toggleCameraLens() async {
    final cameras = await availableCameras();
    final newDirection = _currentLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
        
    // Check if the new direction is available
    final hasNewCamera = cameras.any((camera) => camera.lensDirection == newDirection);
    
    if (!hasNewCamera) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到該鏡頭 (模擬器可能只有一個鏡頭)')),
      );
      return;
    }

    if (_cameraController != null) {
      await _cameraController!.stopImageStream();
      await _cameraController!.dispose();
      _cameraController = null;
    }
    
    setState(() {
      _currentLensDirection = newDirection;
    });
    
    _startCamera();
  }

  void _toggleResolution() async {
    if (_cameraController != null) {
      await _cameraController!.stopImageStream();
      await _cameraController!.dispose();
      _cameraController = null;
    }

    setState(() {
      if (_currentResolutionPreset == ResolutionPreset.low) {
        _currentResolutionPreset = ResolutionPreset.medium;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切換至標準畫質 (平衡)')));
      } else if (_currentResolutionPreset == ResolutionPreset.medium) {
        _currentResolutionPreset = ResolutionPreset.high;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切換至高畫質 (精準)')));
      } else {
        _currentResolutionPreset = ResolutionPreset.low;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切換至低畫質 (流暢)')));
      }
    });

    _startCamera();
  }

  String _debugOverlayText = "";
  
  // FPS Calculation
  int _frameCounter = 0;
  DateTime? _lastFpsTime;
  double _currentFps = 0.0;
  double _currentConfidence = 0.0; // [NEW] Track confidence score

  // --- Pose Analysis Logic (Received from Isolate) ---
  void _analyzePose(Map<String, dynamic> result) {
    setState(() {
      // Calculate FPS
      _frameCounter++;
      final now = DateTime.now();
      if (_lastFpsTime == null) {
        _lastFpsTime = now;
      } else if (now.difference(_lastFpsTime!).inMilliseconds >= 1000) {
        _currentFps = _frameCounter / (now.difference(_lastFpsTime!).inMilliseconds / 1000.0);
        _frameCounter = 0;
        _lastFpsTime = now;
      }

      _currentKeypoints = (result['keypoints'] as List).map((e) => (e as List).cast<double>()).toList();
      
      // Update confidence score
      if (result.containsKey('debug_max_score')) {
        _currentConfidence = (result['debug_max_score'] as double);
      } else {
        _currentConfidence = 0.0;
      }

      final classification = result['classification'] as Map<String, dynamic>;
      final label = classification['label'];
      // final score = classification['score'];

      String feedback = "偵測中...";
      Color color = Colors.white;

      if (result.containsKey('feedback')) {
        feedback = result['feedback'];
        color = Color(result['color']);
      }
      
      _debugOverlayText = "FPS: ${_currentFps.toStringAsFixed(1)}";
      
      
      // Only show FPS as requested
      // if (result.containsKey('debug_max_score')) {
      //   _debugOverlayText += "\nScore: ${(result['debug_max_score'] as double).toStringAsFixed(2)}\nType: ${result['debug_input_type']}";
      // }

      _aiFeedback = feedback;
      _feedbackColor = color;
      _problemKeypoints = result['problemKeypoints'] ?? {};

      // Rep Counting Removed
      // if (_isCounting && result.containsKey('angles')) {
      //   final angles = result['angles'] as Map<String, double>;
      //   if (_repCounter.checkRep(_currentPlanItem.exerciseName, angles, label)) {
      //     _currentReps++;
      //     _repsController.text = _currentReps.toString();
      //   }
      // }
    });
  }

  // Removed _calculateAngle as it is no longer needed here

  void _initCurrentExercise() {
    setState(() {
      _currentSet = 1;
      _setsData.clear();
      _weightController.text = _currentPlanItem.weight;
      _repsController.text = ''; 
      _totalSets = int.tryParse(_currentPlanItem.sets) ?? 3;
      _isPreparing = true;
      _isResting = false;
      _countdownSeconds = 5;
      _currentConfidence = 0.0; // Reset confidence
      // _repCounter.reset();
      // _currentReps = 0;
    });
    _startCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    _cameraController?.dispose();
    _poseDetectorService?.close();
    _heartRateSubscription?.cancel();
    _calorieTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_showCamera) {
         _startCamera();
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          if (_isPreparing) _isPreparing = false;
          if (_isResting) {
            _isResting = false;
            if (_setsData.isNotEmpty) {
               _weightController.text = _setsData.last['weight'].toString();
               _repsController.text = _setsData.last['reps'].toString();
            }
          }
        });
      }
    });
  }

  void _skipRest() {
    _timer?.cancel();
    setState(() {
      _isResting = false;
       if (_setsData.isNotEmpty) {
          _weightController.text = _setsData.last['weight'].toString();
          _repsController.text = _setsData.last['reps'].toString();
       }
    });
  }

  void _finishSet() async {
    if (!_formKey.currentState!.validate()) return;
    
    _setsData.add({
      'setNumber': _currentSet,
      'weight': double.tryParse(_weightController.text) ?? 0.0,
      'reps': int.tryParse(_repsController.text) ?? 0,
    });

    if (_currentSet < _totalSets) {
      setState(() {
        _isResting = true;
        _currentSet++;
        _countdownSeconds = _restTimeInSeconds; 
      });
      _startCountdown();
    } else {
      await _saveCurrentExerciseData();

      if (_todoQueue.isNotEmpty) {
        if (!mounted) return;
        _showNextSelectionDialog();
      } else {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('太棒了！今日課表全部完成！'), backgroundColor: Colors.green));
      }
    }
  }

  Future<void> _saveCurrentExerciseData() async {
    BodyPart detectedBodyPart = widget.bodyPart;
    
    final mockPart = MockDataService.getBodyPartByName(_currentPlanItem.exerciseName);
    if (mockPart != null) {
    detectedBodyPart = mockPart;
  }

  // Calculate Avg/Max HR
  int avgHr = 0;
  int maxHr = 0;
  if (_heartRateReadings.isNotEmpty) {
    maxHr = _heartRateReadings.reduce(max);
    avgHr = _heartRateReadings.reduce((a, b) => a + b) ~/ _heartRateReadings.length;
  }

  final workoutLog = WorkoutLog(
    exerciseName: _currentPlanItem.exerciseName,
    totalSets: _totalSets,
    completedAt: DateTime.now(),
    bodyPart: detectedBodyPart, 
    account: widget.account,
    calories: _totalCaloriesBurned,
    avgHeartRate: avgHr,
    maxHeartRate: maxHr,
  );
  
  final workoutLogId = await DatabaseHelper.instance.insertWorkoutLog(workoutLog);
    
    for (var setData in _setsData) {
      final setLog = SetLog(
        workoutLogId: workoutLogId,
        setNumber: setData['setNumber'],
        weight: setData['weight'],
        reps: setData['reps'],
      );
      await DatabaseHelper.instance.insertSetLog(setLog);
    }
  }

  Future<void> _showNextSelectionDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text('動作完成！'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('請選擇下一個動作：', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _todoQueue.length,
                  itemBuilder: (context, index) {
                    final item = _todoQueue[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(item.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.sets} 組'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _switchToNextExercise(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: const Text('休息一下 (返回首頁)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _switchToNextExercise(PlanItem nextItem) {
    setState(() {
      _todoQueue.remove(nextItem);
      _currentPlanItem = nextItem;
    });
    _initCurrentExercise();
  }

  @override
  Widget build(BuildContext context) {
    String statusText;
    if (_isPreparing) {
      statusText = '準備開始...';
    } else if (_isResting) {
      statusText = '休息中';
    } else {
      statusText = '第 $_currentSet / $_totalSets 組';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_currentPlanItem.exerciseName),
            Text(
              '剩餘動作: ${_todoQueue.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (widget.enableAi) ...[
            if (_showCamera)
              IconButton(
                icon: const Icon(Icons.cameraswitch),
                onPressed: _toggleCameraLens,
              ),
            IconButton(
              icon: Icon(_showCamera ? Icons.videocam_off : Icons.videocam),
              onPressed: () {
                if (_showCamera) {
                  _stopCamera();
                } else {
                  _startCamera();
                }
              },
            ),
             if (_showCamera)
              IconButton(
                icon: Icon(
                  _currentResolutionPreset == ResolutionPreset.low ? Icons.sd : 
                  (_currentResolutionPreset == ResolutionPreset.medium ? Icons.hd : Icons.high_quality)
                ),
                tooltip: '切換畫質',
                onPressed: _toggleResolution,
              ),
          ]
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 1. Top Area: Camera or Status/Countdown
          Expanded(
            child: Stack(
              children: [
                // Camera View
                // Camera View
                if (_showCamera && _cameraController != null && _cameraController!.value.isInitialized)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: Builder(
                          builder: (context) {
                            var scale = _cameraController!.value.aspectRatio;
                            // If portrait, invert aspect ratio
                            if (_sensorOrientation == 90 || _sensorOrientation == 270) {
                              scale = 1 / scale;
                            }
                            return AspectRatio(
                              aspectRatio: scale,
                              child: Stack(
                            children: [
                              CameraPreview(_cameraController!),
                              if (_currentKeypoints != null && _currentConfidence > 0.3)
                                CustomPaint(
                                  painter: PosePainter(
                                    keypoints: _currentKeypoints!,
                                    problemKeypoints: _problemKeypoints,
                                    scaleX: 1.0,
                                    scaleY: 1.0,
                                    isFrontCamera: _currentLensDirection == CameraLensDirection.front,
                                  ),
                                  child: Container(),
                                ),
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _aiFeedback,
                                      style: TextStyle(color: _feedbackColor, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              // Debug Overlay
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  color: Colors.black54,
                                  child: Text(
                                    _debugOverlayText,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ),
                              
                              // Countdown Overlay (Visible during Preparing or Resting)
                              if (_isPreparing || _isResting)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black45, // Semi-transparent background
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            statusText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            '$_countdownSeconds',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 120,
                                              fontWeight: FontWeight.bold,
                                              shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                                            ),
                                          ),
                                          // Optional: Show Guide Image here too if needed
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                              /*
                              Positioned(
                                top: 40,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    '$_currentReps',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              */


                              
                              // Heart Rate & Calorie Overlay
                              
                              // Heart Rate Overlay (Centered)
                              // 移除卡路里顯示，只保留心率，並置中
                              if (_currentHeartRate > 0)
                                Positioned(
                                  top: 60, // Slightly lower than before
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.favorite, color: Colors.white, size: 24),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$_currentHeartRate BPM',
                                            style: const TextStyle(
                                              color: Colors.white, 
                                              fontSize: 24, 
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),


                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

                // Non-Camera Status View (Only visible if Camera is OFF)
                if (!_showCamera)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isPreparing || _isResting) ...[
                          // Guide Image
                          Builder(
                            builder: (context) {
                              // Use data-driven approach instead of hardcoded paths
                              final exercise = MockDataService.getExerciseByName(_currentPlanItem.exerciseName);
                              final imagePath = exercise?.imagePath;
                              
                              if (imagePath != null) {
                                return Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Image.asset(imagePath, height: 200),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                        Text(statusText, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
                        const SizedBox(height: 20),
                        if (_isPreparing || _isResting)
                          Text('$_countdownSeconds', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 2. Bottom Area: Inputs and Buttons
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isPreparing && !_isResting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: _buildTrainingInputFields(),
                    ),
                  
                  Row(
                    children: [
                      if (_isResting)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _skipRest,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                            child: const Text('跳過休息', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      if (_isResting) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isPreparing || _isResting) ? null : _finishSet,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            disabledBackgroundColor: Theme.of(context).colorScheme.primary.withAlpha(77),
                            disabledForegroundColor: Colors.white.withAlpha(128),
                          ),
                          child: Text(_isResting ? '休息中...' : '完成第 $_currentSet 組', style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrainingInputFields() {
    return Row(
      children: [
        if (!_isBodyweightExercise) ...[
          Expanded(
            child: TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: '重量 (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
              validator: (v) => v == null || v.isEmpty ? '請輸入' : null
            )
          ),
          const SizedBox(width: 24),
        ],
        Expanded(
          child: TextFormField(
            controller: _repsController,
            decoration: const InputDecoration(labelText: '次數 (Reps)'),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            validator: (v) => v == null || v.isEmpty ? '請輸入' : null
          )
        )
      ]
    );
  }
}