// lib/pages/video_analysis_page.dart

import 'dart:io';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/exercise_model.dart';
import '../services/pose_detector_service.dart';
import '../utils/exercise_guide_helper.dart';
import '../ui/pose_painter.dart';

class VideoAnalysisPage extends StatefulWidget {
  final Exercise exercise;

  const VideoAnalysisPage({
    super.key,
    required this.exercise,
  });

  @override
  State<VideoAnalysisPage> createState() => _VideoAnalysisPageState();
}

class _VideoAnalysisPageState extends State<VideoAnalysisPage> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  String _analysisFeedback = "";
  Color _feedbackColor = Colors.white;
  final PoseDetectorService _poseDetectorService = PoseDetectorService();
  
  // Store analysis results: Timestamp (ms) -> Analysis Data
  Map<int, Map<String, dynamic>> _analysisResults = {};
  Map<String, dynamic>? _currentFrameAnalysis;


  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _poseDetectorService.initialize();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _poseDetectorService.close();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _videoController?.dispose();
      setState(() {
        _videoFile = File(video.path);
        _analysisResults.clear();
        _currentFrameAnalysis = null;
        _analysisFeedback = "";
        _progress = 0.0;
        
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
            _videoController!.addListener(() {
              // Update UI for progress bar and time text
              if (mounted) setState(() {});
              _onVideoPositionChanged();
            });
          });
      });
    }
  }

  void _onVideoPositionChanged() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    final int currentPos = _videoController!.value.position.inMilliseconds;
    
    // Find the closest analysis result (within 200ms window)
    // We analyze every 200ms, so we look for keys close to currentPos
    // Simple approach: Round to nearest 200
    int targetKey = (currentPos / 200).round() * 200;
    
    if (_analysisResults.containsKey(targetKey)) {
      final result = _analysisResults[targetKey];
      if (_currentFrameAnalysis != result) {
        setState(() {
          _currentFrameAnalysis = result;
          if (result != null) {
             _analysisFeedback = result['feedback'] ?? "";
             _feedbackColor = result['color'] ?? Colors.white;
          }
        });
      }
    }
  }

  Future<void> _analyzeVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResults.clear();
      _progress = 0.0;
      _analysisFeedback = ""; // Clear feedback at start
    });

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String framesDir = path.join(tempDir.path, 'frames');
      final Directory framesDirectory = Directory(framesDir);
      
      if (framesDirectory.existsSync()) {
        framesDirectory.deleteSync(recursive: true);
      }
      framesDirectory.createSync();

      final int durationMs = _videoController!.value.duration.inMilliseconds;
      final int intervalMs = 200; // Analyze every 0.2 seconds
      int count = 0;

      for (int timeMs = 0; timeMs < durationMs; timeMs += intervalMs) {
        if (!mounted) return;
        setState(() {
          _progress = timeMs / durationMs;
        });

        final String? fileName = await VideoThumbnail.thumbnailFile(
          video: _videoFile!.path,
          thumbnailPath: framesDir,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 512,
          quality: 75,
          timeMs: timeMs,
        );
        
        if (!mounted) return;

        if (fileName != null) {
          final file = File(fileName);
          // Use new detectFromFile method which runs in Isolate
          final result = await _poseDetectorService.detectFromFile(file, widget.exercise.name);
          
          if (result != null) {
            // Result already contains analysis from Isolate
            _analysisResults[timeMs] = {
              'keypoints': result['keypoints'],
              'problemKeypoints': result['problemKeypoints'],
              'feedback': result['feedback'],
              'color': result['color'],
            };
            count++;
          }
        }
      }

      setState(() {
        _isAnalyzing = false;
        _progress = 1.0;
        _analysisFeedback = "分析完成！播放影片以查看結果。";
        _feedbackColor = Colors.green;
      });

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisFeedback = "發生錯誤: $e";
        _feedbackColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('影片錄製分析'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_videoFile == null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 50, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text('請上傳您的訓練影片', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              )
            else if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_videoController!),
                    // Overlay PosePainter
                    if (_currentFrameAnalysis != null)
                      CustomPaint(
                        painter: PosePainter(
                          keypoints: _currentFrameAnalysis!['keypoints'],
                          problemKeypoints: _currentFrameAnalysis!['problemKeypoints'] ?? {},
                          scaleX: 1.0, // VideoPlayer scales to fit, so 1.0 relative to widget size should work if aspect ratio matches
                          scaleY: 1.0,
                        ),
                        size: Size.infinite,
                      ),
                    if (_analysisFeedback.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _feedbackColor, width: 2),
                          ),
                          child: Text(
                            _analysisFeedback,
                            style: TextStyle(
                              color: _feedbackColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    // VideoProgressIndicator removed from here to move below controls or keep it? 
                    // Keeping it here is fine, but I added another one in _buildVideoControls. 
                    // Let's remove this one to avoid duplication and have a cleaner UI.

                    if (_isAnalyzing)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "正在分析... ${(_progress * 100).toInt()}%",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: _progress,
                                backgroundColor: Colors.grey,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_videoController != null && _videoController!.value.isInitialized)
                _buildVideoControls(),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.upload_file),
              label: Text(_videoFile == null ? '選擇影片' : '重新選擇'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),

            const SizedBox(height: 16),

            if (_videoFile != null)
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeVideo,
                icon: _isAnalyzing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Icon(Icons.analytics),
                label: Text(_isAnalyzing ? '分析中...' : '開始分析'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),

            const SizedBox(height: 32),


          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () {
                _videoController!.seekTo(Duration.zero);
                _videoController!.play();
              },
            ),
            PopupMenuButton<double>(
              initialValue: _videoController!.value.playbackSpeed,
              tooltip: '播放速度',
              onSelected: (speed) {
                _videoController!.setPlaybackSpeed(speed);
                setState(() {});
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 0.5, child: Text("0.5x")),
                const PopupMenuItem(value: 1.0, child: Text("1.0x")),
                const PopupMenuItem(value: 1.5, child: Text("1.5x")),
                const PopupMenuItem(value: 2.0, child: Text("2.0x")),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("${_videoController!.value.playbackSpeed}x"),
              ),
            ),
          ],
        ),
        VideoProgressIndicator(
          _videoController!,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_videoController!.value.position)),
            Text(_formatDuration(_videoController!.value.duration)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
