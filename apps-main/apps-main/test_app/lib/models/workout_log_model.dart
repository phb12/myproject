import './exercise_model.dart';

class WorkoutLog {
  final int? id;
  final String exerciseName;
  final int totalSets;
  final DateTime completedAt;
  final BodyPart bodyPart;
  final String account; // 【新增】帳號欄位

  const WorkoutLog({
    this.id,
    required this.exerciseName,
    required this.totalSets,
    required this.completedAt,
    required this.bodyPart,
    required this.account, // 【新增】
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
      account: account ?? this.account, // 【新增】
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'totalSets': totalSets,
      'completedAt': completedAt.toIso8601String(),
      'bodyPart': bodyPart.name,
      'account': account, // 【新增】
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
      account: map['account'] ?? 'unknown', // 【新增】如果舊資料沒有帳號，給預設值
    );
  }
}