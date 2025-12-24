import './exercise_model.dart';

class WorkoutLog {
  final int? id;
  final String exerciseName;
  final int totalSets;
  final DateTime completedAt;
  final BodyPart bodyPart;
  final String account; 
  final double calories;      // [NEW]
  final int avgHeartRate;     // [NEW] 
  final int maxHeartRate;     // [NEW]

  const WorkoutLog({
    this.id,
    required this.exerciseName,
    required this.totalSets,
    required this.completedAt,
    required this.bodyPart,

    required this.account,
    this.calories = 0.0,      // Default 0
    this.avgHeartRate = 0,    // Default 0
    this.maxHeartRate = 0,    // Default 0
  });

  WorkoutLog copyWith({
    int? id,
    String? exerciseName,
    int? totalSets,
    DateTime? completedAt,
    BodyPart? bodyPart,
    String? account, // 【新增】
  }) {
    return WorkoutLog(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      totalSets: totalSets ?? this.totalSets,
      completedAt: completedAt ?? this.completedAt,
      bodyPart: bodyPart ?? this.bodyPart,

      account: account ?? this.account,
      calories: calories ?? this.calories,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'totalSets': totalSets,
      'completedAt': completedAt.toIso8601String(),
      'bodyPart': bodyPart.name,

      'account': account,
      'calories': calories,
      'avg_heart_rate': avgHeartRate,
      'max_heart_rate': maxHeartRate,
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
      exerciseName: map['exerciseName'],
      totalSets: map['totalSets'],
      completedAt: DateTime.parse(map['completedAt']),
      bodyPart: part,

      account: map['account'] ?? 'unknown',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      avgHeartRate: (map['avg_heart_rate'] as num?)?.toInt() ?? 0,
      maxHeartRate: (map['max_heart_rate'] as num?)?.toInt() ?? 0,
    );
  }
}