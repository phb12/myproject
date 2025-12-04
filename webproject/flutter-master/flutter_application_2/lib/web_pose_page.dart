import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'services/web_pose_service.dart';

class WebPosePage extends StatefulWidget {
  const WebPosePage({super.key});

  @override
  State<WebPosePage> createState() => _WebPosePageState();
}

class _WebPosePageState extends State<WebPosePage> {
  final WebPoseService _poseService = WebPoseService();
  
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement; // For frame extraction
  
  // UI State
  bool _isLoading = true;
  String _status = "載入模型中...";
  String _feedback = "";
  String _currentLabel = ""; // Track current detected exercise
  Color _feedbackColor = Colors.white;
  List<List<double>>? _currentKeypoints;
  
  // Loop
  Timer? _timer;

  String _getCameraInstruction(String label) {
    if (label.contains('深蹲') || 
        label.contains('硬舉') || 
        label.contains('伏地挺身') ||
        label.contains('臥推') ||
        label.contains('划船')) {
      return "💡 建議拍攝角度：側面 (Side View)";
    } else if (label.contains('肩推') || 
               label.contains('側平舉') || 
               label.contains('二頭彎舉')) {
      return "💡 建議拍攝角度：正面 (Front View)";
    }
    return "💡 請確保全身入鏡";
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _poseService.initialize();
      
      // Setup Video Element
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..loop = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain';
        
      // Register view factory
      // Register view factory
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        'video-view',
        (int viewId) => _videoElement!,
      );
      
      _poseService.resultStream.listen((data) {
        if (!mounted) return;
        setState(() {
          // Convert dynamic list to List<List<double>>
          _currentKeypoints = (data['keypoints'] as List).map((k) {
             return (k as List).map((e) => (e as num).toDouble()).toList();
          }).toList();
          
          final analysis = data['analysis'];
          _feedback = analysis['feedback'];
          _currentLabel = data['label'] ?? ""; // Update label
          _feedbackColor = analysis['color'] == Colors.white ? Colors.white : 
                           analysis['color'] == Colors.red ? Colors.redAccent :
                           analysis['color'] == Colors.green ? Colors.greenAccent :
                           analysis['color'] == Colors.blue ? Colors.blueAccent : Colors.yellowAccent;
        });
      });

      setState(() {
        _isLoading = false;
        _status = "請上傳影片";
      });
    } catch (e) {
      setState(() {
        _status = "初始化失敗: $e";
      });
    }
  }

  void _uploadVideo() {
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();
    input.onChange.listen((e) {
      if (input.files!.isEmpty) return;
      final file = input.files!.first;
      final url = html.Url.createObjectUrlFromBlob(file);
      
      _videoElement!.src = url;
      _videoElement!.onLoadedData.listen((_) {
        _startProcessing();
      });
    });
  }

  void _startProcessing() {
    _canvasElement = html.CanvasElement(width: _videoElement!.videoWidth, height: _videoElement!.videoHeight);
    final ctx = _canvasElement!.context2D;
    
    _timer?.cancel();
    // Process every ~100ms (10fps) to balance load
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_videoElement!.paused || _videoElement!.ended) return;
      
      ctx.drawImage(_videoElement!, 0, 0);
      try {
        final imageData = ctx.getImageData(0, 0, _canvasElement!.width!, _canvasElement!.height!);
        _poseService.processFrame(imageData);
      } catch (e) {
        print("Frame processing error: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI 動作分析 (影片版)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_status, style: const TextStyle(color: Colors.white)),
            ),
            
          Expanded(
            child: Stack(
              children: [
                // Video View
                if (!_isLoading)
                  const HtmlElementView(viewType: 'video-view'),
                  
                // Overlay Painter
                if (_currentKeypoints != null)
                  CustomPaint(
                    painter: PosePainter(_currentKeypoints!),
                    size: Size.infinite,
                  ),
                  
                // Feedback Overlay
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      // Camera Angle Instruction
                      if (_currentKeypoints != null && _feedback.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getCameraInstruction(_currentLabel),
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ),
                      
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _feedback.isEmpty ? "請開始動作" : _feedback,
                            style: TextStyle(
                              color: _feedbackColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _uploadVideo,
              icon: const Icon(Icons.upload_file),
              label: const Text("上傳影片"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<List<double>> keypoints; // [y, x, score] normalized 0..1
  PosePainter(this.keypoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    final pointPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Draw points
    for (var kp in keypoints) {
      if (kp[2] > 0.3) {
        canvas.drawCircle(Offset(kp[1] * size.width, kp[0] * size.height), 4, pointPaint);
      }
    }
    
    // Edges
    final edges = [
      [0, 1], [0, 2], [1, 3], [2, 4], [5, 6], [5, 7], [7, 9], [6, 8], [8, 10], [5, 11], [6, 12], [11, 12], [11, 13], [13, 15], [12, 14], [14, 16]
    ];
    
    for (var edge in edges) {
      if (edge[0] >= keypoints.length || edge[1] >= keypoints.length) continue;
      
      final p1 = keypoints[edge[0]];
      final p2 = keypoints[edge[1]];
      if (p1[2] > 0.3 && p2[2] > 0.3) {
        canvas.drawLine(
          Offset(p1[1] * size.width, p1[0] * size.height),
          Offset(p2[1] * size.width, p2[0] * size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
