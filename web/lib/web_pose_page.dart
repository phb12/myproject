import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'services/web_pose_service.dart';
import 'painters/pose_painter.dart';

class PosePage extends StatefulWidget {
  const PosePage({super.key});

  @override
  State<PosePage> createState() => _PosePageState();
}

class _PosePageState extends State<PosePage> {
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
        ..style.objectFit = 'contain'
        ..style.transform = 'scaleX(-1)'; // Mirror the video for "selfie" feel
        
      // Register view factory
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        'video-view',
        (int viewId) => _videoElement!,
      );

      // Initialize Camera
      try {
        final stream = await html.window.navigator.mediaDevices!.getUserMedia({
            'video': {
                'facingMode': 'user', // Prefer front camera
                'width': {'ideal': 640},
                'height': {'ideal': 480}
            }
        });
        _videoElement!.srcObject = stream;
        _videoElement!.onLoadedMetadata.listen((_) {
            _startProcessing();
        });
      } catch (cameraError) {
        String errorMsg = "無法存取攝影機: $cameraError";
        if (cameraError.toString().contains("NotReadableError") || 
            cameraError.toString().contains("Device in use")) {
           errorMsg = "無法存取攝影機。請檢查是否有其他分頁或程式正在使用相機，並將其關閉後重試。";
        } else if (cameraError.toString().contains("NotAllowedError") || 
                   cameraError.toString().contains("Permission denied")) {
           errorMsg = "請允許瀏覽器使用攝影機權限。";
        }
        
        setState(() {
          _status = errorMsg;
        });
        return;
      }
      
      _poseService.resultStream.listen((data) {
        // Unlock flow control when result is received
        _isProcessing = false;
        
        if (!mounted) return;
        setState(() {
          // Convert dynamic list to List<List<double>>
          _currentKeypoints = (data['keypoints'] as List).map((k) {
             return (k as List).map((e) => (e as num).toDouble()).toList();
          }).toList();
          
          final analysis = data['analysis'];
          _feedback = analysis['feedback'] ?? "";
          _currentLabel = data['label'] ?? "Unknown"; // Update label
          _feedbackColor = analysis['color'] == Colors.white ? Colors.white : 
                           analysis['color'] == Colors.red ? Colors.redAccent :
                           analysis['color'] == Colors.green ? Colors.greenAccent :
                           analysis['color'] == Colors.blue ? Colors.blueAccent : Colors.yellowAccent;
        });
      });

      setState(() {
        _isLoading = false;
        _status = "";
      });
    } catch (e) {
      setState(() {
        _status = "初始化失敗: $e";
      });
    }
  }

  // Optional: Allow switching to upload if needed, but remove default upload button
  void _uploadVideo() {
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();
    input.onChange.listen((e) {
      if (input.files!.isEmpty) return;
      final file = input.files!.first;
      final url = html.Url.createObjectUrlFromBlob(file);
      
      // Stop camera if running
      if (_videoElement!.srcObject != null) {
        final stream = _videoElement!.srcObject as html.MediaStream;
        stream.getTracks().forEach((track) => track.stop());
        _videoElement!.srcObject = null;
      }
      
      // When uploading video, we usually don't want to mirror it? 
      // Or maybe we do if it's a selfie video. Let's keep it mirrored for consistency
      // or Reset it if needed. For now, consistent mirror is safer UI.

      _videoElement!.src = url;
      _videoElement!.onLoadedData.listen((_) {
        _startProcessing();
      });
    });
  }

  bool _isProcessing = false; // 流量控制：避免堆積 Frame 導致延遲

  void _startProcessing() {
    // 確保 Canvas 與影片尺寸相符
    _canvasElement ??= html.CanvasElement();
    
    _timer?.cancel();
    // 縮短 Timer 間隔，改由 _isProcessing 控制實際頻率
    // 設為 33ms (約 30FPS) 讓它盡可能快地檢查是否可以傳送下一張
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (_videoElement == null || _videoElement!.paused || _videoElement!.ended) return;
      
      // 關鍵修正：如果上一張還沒算完，就直接丟棄這一張 (Drop Frame)
      // 這能解決「延遲 4-5 秒」的問題，確保永遠只顯示最新的結果
      if (_isProcessing) return; 

      // 同步 Canvas 尺寸 (例如串流加載完成後)
      if (_canvasElement!.width != _videoElement!.videoWidth || 
          _canvasElement!.height != _videoElement!.videoHeight) {
          _canvasElement!.width = _videoElement!.videoWidth;
          _canvasElement!.height = _videoElement!.videoHeight;
      }
      
      if (_canvasElement!.width == 0 || _canvasElement!.height == 0) return;

      // 使用 willReadFrequently 優化頻繁讀取操作
      final ctx = _canvasElement!.getContext('2d', {'willReadFrequently': true}) as html.CanvasRenderingContext2D;
      
      ctx.drawImage(_videoElement!, 0, 0);
      try {
        final imageData = ctx.getImageData(0, 0, _canvasElement!.width!, _canvasElement!.height!);
        
        _isProcessing = true; // 鎖定：開始處裡
        _poseService.processFrame(imageData);
      } catch (e) {
        print("Frame processing error: $e");
        _isProcessing = false; // 解鎖：發生錯誤也要釋放
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
        title: const Text('AI 動作分析 (即時攝影機)', style: TextStyle(color: Colors.white)),
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
                    painter: PosePainter(
                      _currentKeypoints!, 
                      Size(_videoElement!.videoWidth.toDouble(), _videoElement!.videoHeight.toDouble()),
                      isMirrored: true, // Front camera usually needs mirroring
                    ),
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
              label: const Text("切換影片模式"),
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
