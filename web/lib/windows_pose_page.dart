import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer
import 'services/windows_pose_service.dart';
import 'painters/pose_painter.dart';

class PosePage extends StatefulWidget {
  const PosePage({super.key});

  @override
  State<PosePage> createState() => _PosePageState();
}

class _PosePageState extends State<PosePage> {
  final WindowsPoseService _poseService = WindowsPoseService();
  String _status = "初始化中...";
  String _feedback = "";
  Color _feedbackColor = Colors.white;
  List<List<double>>? _currentKeypoints;
  
  CameraController? _cameraController;
  Timer? _timer; // Timer for snapshot loop
  int _cameraId = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _status = "載入模型...");
      await _poseService.initialize();
      
      setState(() => _status = "開啟相機...");
      List<CameraDescription> cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() => _status = "找不到相機");
        return;
      }
      
      // _cameraId = int.parse(cameras[0].name); // Removed: Windows camera name is a string, parsing fails.
      
      
      // Ensure previous controller is disposed
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
      
      // Use local variable for atomic assignment after init if possible, or just check mounted
      final controller = CameraController(
        cameras[0], 
        ResolutionPreset.medium, 
        enableAudio: false
      );
      
      _cameraController = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      
      // Listen to service results
      _poseService.resultStream.listen((data) {
        if (!mounted) return;
        setState(() {
          _currentKeypoints = (data['keypoints'] as List).map((k) {
             return (k as List).map((e) => (e as num).toDouble()).toList();
          }).toList();
          
          final analysis = data['analysis'];
          _feedback = analysis['feedback'] ?? "";
          _feedbackColor = analysis['color'] ?? Colors.white;
        });
        _isProcessing = false; // Release lock
      });

      // Start Snapshot Loop (Workaround for missing startImageStream on Windows)
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
         if (_isProcessing || !mounted || _cameraController == null || !_cameraController!.value.isInitialized) return;
         
         _isProcessing = true;
         try {
           final XFile file = await _cameraController!.takePicture();
           final bytes = await file.readAsBytes();
           // Optional: delete file immediately? XFile usually is a temp file.
           
           await _poseService.processFrameFromBytes(bytes);
         } catch (e) {
           print("Snapshot Error: $e");
         } finally {
            _isProcessing = false;
         }
      });

      setState(() => _status = "");
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "錯誤: $e");
      print(e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI 動作分析 (Windows 版)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
            
          // Painter Overlay
          if (_currentKeypoints != null && _cameraController != null)
             Positioned.fill(
               child: CustomPaint(
                 painter: PosePainter(
                   _currentKeypoints!,
                   _cameraController!.value.previewSize!, // Size of the video source
                   isMirrored: true, // Usually selfies are mirrored
                 ), 
               ),
             ),

          // Status & Feedback
          if (_status.isNotEmpty)
            Center(child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 18))),
            
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _feedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
