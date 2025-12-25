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
  
  // Action Selection
  final List<String> _actions = [
    '選擇動作',
    '深蹲',
    '硬舉',
    '臥推',
    '伏地挺身',
    '引體向上',
    '肩推',
    '側平舉',
    '二頭彎舉',
    '三頭下壓', 
    '捲腹',
  ];
  String _selectedAction = '選擇動作';
  
  // Analysis Results: Map<TimestampMs, Map<String, dynamic>>
  final Map<int, Map<String, dynamic>> _analysisResults = {};
  
  // Current display data
  List<List<double>>? _currentKeypoints;
  String _currentFeedback = "";
  Color _currentFeedbackColor = Colors.white;
  String _currentLabel = "";
  Map<String, double> _currentAngles = {};

  // Angle Configurations (Min, Max, BestMin, BestMax)
  // Maps: Exercise Label -> { Angle Name -> [Min, Max, GreenMin, GreenMax] }
  static const Map<String, Map<String, List<double>>> _angleConfigs = {
    '深蹲': {
      'knee': [0, 180, 0, 100], 
      'hip': [0, 180, 0, 165], 
    },
    'squat': { // English alias
      'knee': [0, 180, 0, 100], 
      'hip': [0, 180, 0, 165], 
    },
    '硬舉': {
      'hip': [0, 180, 0, 120],
      'knee': [0, 180, 140, 180],
    },
    'deadlift': { // English alias
      'hip': [0, 180, 0, 120],
      'knee': [0, 180, 140, 180],
    },
    '臥推': {
      'elbow': [0, 180, 0, 90], 
    },
    'bench_press': { // English alias
      'elbow': [0, 180, 0, 90], 
    },
    '伏地挺身': {
      'elbow': [0, 180, 0, 90],
    },
    'push_up': { // English alias
      'elbow': [0, 180, 0, 90],
    },
    '肩推': {
      'elbow': [0, 180, 90, 180], 
    },
    'shoulder_press': { 
      'elbow': [0, 180, 90, 180], 
    },
    '引體向上': {
      'elbow': [0, 180, 0, 175], // Pull hard
      'body': [0, 180, 140, 180], // Keep straight
    },
    'pull_up': {
      'elbow': [0, 180, 0, 175],
      'body': [0, 180, 140, 180],
    },
    '側平舉': {
      'shoulder': [0, 180, 20, 90], // Lift range
      'elbow': [0, 180, 140, 175], // Slight bend
    },
    'lateral_raise': {
      'shoulder': [0, 180, 20, 90],
      'elbow': [0, 180, 140, 175],
    },
    '二頭彎舉': {
      'elbow': [0, 180, 40, 170], // Full range
      'shoulder': [0, 180, 0, 30], // Stable
    },
    'curl': {
      'elbow': [0, 180, 40, 170],
      'shoulder': [0, 180, 0, 30],
    },
    '三頭下壓': {
      'elbow': [0, 180, 90, 170],
      'shoulder': [0, 180, 0, 30],
    },
    'tricep_extension': {
      'elbow': [0, 180, 90, 170],
      'shoulder': [0, 180, 0, 30],
    },
    'tricep_pushdown': {
      'elbow': [0, 180, 90, 170],
      'shoulder': [0, 180, 0, 30],
    },
    '捲腹': {
      'hip': [0, 180, 0, 120], // Crunch
      'neck': [0, 180, 100, 180], // Safe neck
    },
    'crunch': {
      'hip': [0, 180, 0, 120],
      'neck': [0, 180, 100, 180],
    },
  };

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
                
                // Translate label
                String displayLabelText = label;
                const labelMap = {
                  'squat': '深蹲',
                  'deadlift': '硬舉',
                  'bench_press': '臥推',
                  'push_up': '伏地挺身',
                  'pull_up': '引體向上',
                  'shoulder_press': '肩推',
                  'lateral_raise': '側平舉',
                  'curl': '二頭彎舉',
                  'tricep_extension': '三頭下壓', 
                  'tricep_pushdown': '三頭下壓', // Handle potential alias
                  'crunch': '捲腹',
                };
                
                String displayLabel;
                if (_selectedAction != '選擇動作') {
                   displayLabelText = _selectedAction;
                   // Use score if it matches, otherwise maybe hide it? 
                   // For simplicity, just show label or keep score if relevant. 
                   // But score is for the *detected* label. 
                   // If manually selected, score is irrelevant/misleading.
                   // Let's show: "動作: 深蹲 (手動)"
                   displayLabel = "動作: $displayLabelText";
                } else {
                   if (labelMap.containsKey(label)) {
                     displayLabelText = labelMap[label]!;
                   }
                   displayLabel = "動作: $displayLabelText ($scoreText%)";
                }
                String feedback = analysis['feedback'] ?? "";
                
                if (analysis['angles'] != null) {
                   _currentAngles = Map<String, double>.from(analysis['angles']);
                } else {
                   _currentAngles = {};
                }
                _currentLabel = label;
                
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
         _currentLabel = "";
         _currentAngles = {};
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



  void _onActionChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedAction = newValue;
    });
    
    if (newValue == '選擇動作') {
      _poseService.setAutoClassification(true);
    } else {
      _poseService.setAutoClassification(false);
      _poseService.setExercise(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('影片動作分析', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Video Area
          // Video Area
          Expanded(
            child: Row(
              children: [
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
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('請選擇影片', style: TextStyle(color: Colors.white, fontSize: 24)), 
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Action Selector
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedAction,
                                  dropdownColor: Colors.grey[800],
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  alignment: AlignmentDirectional.center,
                                  items: _actions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Center(child: Text(value)),
                                    );
                                  }).toList(),
                                  onChanged: _isAnalyzing ? null : _onActionChanged,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _isAnalyzing ? null : _pickVideo, 
                              icon: const Icon(Icons.video_file), 
                              label: const Text('選擇影片'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _buildAngleDashboard(),
              ],
            ),
          ),
          
          // Controls
          if (_videoController != null && _videoController!.value.isInitialized)
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
                    // Action Selector
                    if (!_isAnalyzing) ...[
                      // Action Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAction,
                            dropdownColor: Colors.grey[800],
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            alignment: AlignmentDirectional.center, // Center the selected item content
                            items: _actions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Center(child: Text(value)), // Center the list items
                              );
                            }).toList(),
                            onChanged: _isAnalyzing ? null : _onActionChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    
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

  Widget _buildAngleDashboard() {
    // Determine configs based on _selectedAction or detected label
    Map<String, List<double>> config = _angleConfigs[_selectedAction] ?? _angleConfigs[_currentLabel] ?? {};
    
    // Label translation
    const Map<String, String> angleLabels = {
      'knee': '膝蓋角度',
      'hip': '髖部角度',
      'elbow': '手肘角度',
      'back': '背部角度',
    };
    
    return Container(
      width: 250,
      height: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("關節角度監控", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: config.keys.map((key) {
                final value = _currentAngles[key] ?? 0.0;
                final range = config[key] ?? [0, 180, 0, 0]; // Default range
                final label = angleLabels[key] ?? key;
                
                return _buildGauge(label, value, range);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(String label, double value, List<double> range) {
    if (range.length < 4) range = [0, 180, 0, 0];
    final double min = range[0];
    final double max = range[1];
    final double greenMin = range[2];
    final double greenMax = range[3];
    
    double percent = (value - min) / (max - min);
    percent = percent.clamp(0.0, 1.0);
    
    // Use LayoutBuilder for responsive width if possible, but fixed 218 is fine for 250 container
    final double trackWidth = 218.0;

    double greenStart = (greenMin - min) / (max - min);
    double greenEnd = (greenMax - min) / (max - min);
    
    bool isGood = value >= greenMin && value <= greenMax;
    Color valueColor = isGood ? Colors.greenAccent : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text("${value.toStringAsFixed(0)}°", style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 12,
            child: Stack(
              children: [
                // Background Track
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Green Zone
                if (greenMax > greenMin)
                Positioned(
                  left: greenStart * trackWidth, 
                  width: (greenEnd - greenStart) * trackWidth, 
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                ),
                // Marker
                Positioned(
                  left: (percent * trackWidth) - 2, // Center the marker
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: valueColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              ],
            ),
          ),
          // Recommended Label
          if (greenMax > greenMin)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "推薦: ${greenMin.toStringAsFixed(0)}° - ${greenMax.toStringAsFixed(0)}°",
              style: TextStyle(color: Colors.green.withOpacity(0.7), fontSize: 10),
            ),
          )
        ],
      ),
    );
  }
}
