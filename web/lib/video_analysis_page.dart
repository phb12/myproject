import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary
import 'package:video_player/video_player.dart';
import 'package:file_selector/file_selector.dart';
// import 'package:video_thumbnail/video_thumbnail.dart'; // Removed
// import 'package:path_provider/path_provider.dart'; // Not needed for memory capture
import 'services/windows_pose_service.dart';
import 'painters/pose_painter.dart';

class VideoAnalysisPage extends StatefulWidget {
  const VideoAnalysisPage({super.key});

  @override
  State<VideoAnalysisPage> createState() => _VideoAnalysisPageState();
}

class _VideoAnalysisPageState extends State<VideoAnalysisPage> {
  // Services
  final WindowsPoseService _poseService = WindowsPoseService();
  VideoPlayerController? _videoController;
  final GlobalKey _videoKey = GlobalKey(); // Key for RepaintBoundary
  
  // State
  String? _videoPath;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  String _status = "";
  
  // Analysis Results: Map<TimestampMs, Map<String, dynamic>>
  final Map<int, Map<String, dynamic>> _analysisResults = {};
  
  // Current display data
  List<List<double>>? _currentKeypoints;
  String _currentFeedback = "";
  Color _currentFeedbackColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _poseService.initialize();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'videos',
      extensions: <String>['mp4', 'avi', 'mov', 'mkv'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    
    if (file == null) return;

    setState(() {
      _videoPath = file.path;
      _status = "影片載入中...";
      // Clear previous results
      _analysisResults.clear();
      _currentKeypoints = null;
      _currentFeedback = "";
      _analysisProgress = 0.0;
      _isAnalyzing = false;
    });

    await _initializeVideo(File(file.path));
  }

  Future<void> _initializeVideo(File file) async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }
    
    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    
    _videoController!.addListener(_onVideoTick);

    setState(() {
      _status = "影片已載入";
    });
  }

  void _onVideoTick() {
    // During analysis, we don't want to update UI from playback tick conflicting with seek
    // But analysis creates its own state loop.
    if (_isAnalyzing) return; 

    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    final int currentMs = _videoController!.value.position.inMilliseconds;
    
    if (_analysisResults.isNotEmpty) {
      int? closestTime;
      int minDiff = 100000;
      
      for (var time in _analysisResults.keys) {
        final diff = (time - currentMs).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestTime = time;
        }
      }
      
      if (closestTime != null && minDiff < 200) { 
        final result = _analysisResults[closestTime];
        if (result != null) {
           setState(() {
             _currentKeypoints = (result['keypoints'] as List).map((k) {
                return (k as List).map((e) => (e as num).toDouble()).toList();
             }).toList();
             
             final analysis = result['analysis'];
             final label = result['label'] ?? "";
             final score = result['score'] ?? 0.0;
             
             if (analysis != null) {
                // Show label and score
                String scoreText = (score * 100).toStringAsFixed(0);
                String displayLabel = "動作: $label ($scoreText%)";
                String feedback = analysis['feedback'] ?? "";
                
                _currentFeedback = "$displayLabel\n$feedback";
                _currentFeedbackColor = analysis['color'] ?? Colors.white;
             }
           });
           return;
        }
      }
    }
    
    if (_currentKeypoints != null) {
       setState(() {
         _currentKeypoints = null;
         _currentFeedback = "";
       });
    }
  }

  Future<void> _startAnalysis() async {
    if (_videoPath == null || _videoController == null) return;
    
    setState(() {
      _isAnalyzing = true;
      _status = "分析中...";
      _analysisResults.clear();
      _analysisProgress = 0.0;
    });

    // Pause video for analysis
    await _videoController!.pause();

    try {
      final int durationMs = _videoController!.value.duration.inMilliseconds;
      const int stepMs = 200; // Analyze every 200ms (slower to allow seek/render)
      
      Completer<Map<String, dynamic>>? nextResult;
      
      // Subscribe to results
      final sub = _poseService.resultStream.listen((data) {
        if (nextResult != null && !nextResult!.isCompleted) {
          nextResult!.complete(data);
        }
      });

      for (int t = 0; t <= durationMs; t += 300) { // Optimize: 300ms step
        if (!mounted) break;
        
        setState(() {
            _analysisProgress = t / durationMs;
            _status = "分析中... ${(t/1000).toStringAsFixed(1)}s / ${(durationMs/1000).toStringAsFixed(1)}s";
        });

        // 1. Seek to time
        await _videoController!.seekTo(Duration(milliseconds: t));
        
        // 2. Wait for frame to render
        // Optimize: Reduce delay to 50ms
        await Future.delayed(const Duration(milliseconds: 50)); 
        
        // 3. Capture frame
        if (_videoKey.currentContext == null) continue;
        
        RenderRepaintBoundary? boundary = _videoKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
        
        if (boundary != null) {
           ui.Image image = await boundary.toImage(pixelRatio: 1.0);
           
           // Optimize: Use rawRgba to avoid PNG encoding overhead (extremely slow)
           ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
           
           if (byteData != null) {
              final rawBytes = byteData.buffer.asUint8List();
              
              // 4. Prepare waiter
              nextResult = Completer();
              
              // 5. Process using raw bytes
              await _poseService.processFrameFromRawBgra(rawBytes, image.width, image.height);
              
              // 6. Wait for result
              try {
                final result = await nextResult!.future.timeout(const Duration(seconds: 2));
                _analysisResults[t] = result;
              } catch (e) {
                print("Timeout analyzing frame at $t ms");
              }
           }
        }
      }
      
      await sub.cancel();
      
      // Restore state
      // await _videoController!.seekTo(Duration.zero); // Removed: Keep at end
      
      setState(() {
        _status = "分析完成";
        _isAnalyzing = false;
        _analysisProgress = 1.0;
      });
      
      // Trigger update to show last frame
      if (mounted) {
         _onVideoTick();
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
            _status = "錯誤: $e";
            _isAnalyzing = false;
        });
      }
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('影片動作分析 (Windows)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Video Area
          // Video Area
          Expanded(
            child: Center(
              child: (_videoController != null && _videoController!.value.isInitialized)
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Video (Wrapped in RepaintBoundary for capture)
                          RepaintBoundary(
                            key: _videoKey,
                            child: VideoPlayer(_videoController!),
                          ),
                          
                          // 2. Pose Overlay
                          if (_currentKeypoints != null)
                            CustomPaint(
                              painter: PosePainter(
                                _currentKeypoints!,
                                _videoController!.value.size,
                                isMirrored: false,
                              ),
                            ),

                          // 2.5 Feedback Overlay
                          if (_currentFeedback.isNotEmpty)
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black54,
                                child: Text(
                                  _currentFeedback,
                                  style: TextStyle(
                                    color: _currentFeedbackColor, 
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            
                          // 3. Analysis Progress Overlay
                          if (_isAnalyzing)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text("分析中... ${(_analysisProgress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white)),
                                    Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Text('請選擇影片', style: TextStyle(color: Colors.grey)),
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              children: [

                   
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Text(_status, style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _pickVideo, 
                      icon: const Icon(Icons.video_file), 
                      label: const Text('選擇影片'),
                    ),
                    const SizedBox(width: 16),
                    if (_videoController != null && !_isAnalyzing)
                       ElevatedButton.icon(
                         onPressed: () async {
                           if (_videoController!.value.isPlaying) {
                             _videoController!.pause();
                           } else {
                             // Check if we are close to the end (within 500ms)
                             final pos = _videoController!.value.position;
                             final dur = _videoController!.value.duration;
                             if (pos >= dur - const Duration(milliseconds: 500)) {
                               await _videoController!.seekTo(Duration.zero);
                               await Future.delayed(const Duration(milliseconds: 200));
                             }
                             await _videoController!.play();
                           }
                           setState(() {});
                         },
                         icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                         label: Text(_videoController!.value.isPlaying ? '暫停' : '播放'),
                       ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: (_videoController != null && !_isAnalyzing) ? _startAnalysis : null,
                      icon: const Icon(Icons.analytics),
                      label: const Text('開始分析'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
