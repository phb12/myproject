import 'exercise_model.dart';

class WorkoutLog {
  final String? id;
  final String exerciseName;
  final int totalSets;
  final DateTime completedAt;
  final BodyPart bodyPart;
  final String account;
  final int duration;
  final List<Map<String, dynamic>> setsDetail; // Added setsDetail

  const WorkoutLog({
    this.id,
    required this.exerciseName,
    required this.totalSets,
    required this.completedAt,
    required this.bodyPart,
    required this.account,
    this.duration = 0,
    this.setsDetail = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'totalSets': totalSets,
      'completedAt': completedAt.toIso8601String(),
      'bodyPart': bodyPart.name,
      'account': account,
      'duration': duration,
      'setsDetail': setsDetail,
    };
  }

  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    BodyPart part = BodyPart.shoulders; 
    final bodyPartString = map['bodyPart'] as String?;
    
    if (bodyPartString != null && bodyPartString.isNotEmpty) {
      try {
        part = BodyPart.values.firstWhere((e) => e.name == bodyPartString);
      } catch (e) {}
    }

    return WorkoutLog(
      id: map['id'],
      exerciseName: map['exerciseName'] ?? '',
      totalSets: map['totalSets'] ?? 0,
      completedAt: DateTime.tryParse(map['completedAt'] ?? '') ?? DateTime.now(),
      bodyPart: part,
      account: map['account'] ?? 'unknown',
      duration: map['duration'] ?? 0,
      setsDetail: List<Map<String, dynamic>>.from(map['setsDetail'] ?? []),
    );
  }
}
