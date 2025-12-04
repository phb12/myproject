// lib/models/set_log_model.dart

class SetLog {
  final int? id;
  final int workoutLogId; // 用來關聯到是哪一筆總的訓練紀錄
  final int setNumber;    // 第幾組
  final double weight;     // 重量
  final int reps;         // 次數

  SetLog({
    this.id,
    required this.workoutLogId,
    required this.setNumber,
    required this.weight,
    required this.reps,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutLogId': workoutLogId,
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
    };
  }

  factory SetLog.fromMap(Map<String, dynamic> map) {
    return SetLog(
      id: map['id'],
      workoutLogId: map['workoutLogId'],
      setNumber: map['setNumber'],
      weight: map['weight'],
      reps: map['reps'],
    );
  }
}