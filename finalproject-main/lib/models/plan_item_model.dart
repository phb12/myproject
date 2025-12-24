// lib/models/plan_item_model.dart

class PlanItem {
  final int? id;
  final int dayOfWeek; // 1=週一, 2=週二, ..., 7=週日
  final String exerciseName;
  final String sets; // 儲存預設組數，例如 "4"
  final String weight; // 儲存預設重量，例如 "60.0"

  PlanItem({
    this.id,
    required this.dayOfWeek,
    required this.exerciseName,
    required this.sets,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'exerciseName': exerciseName,
      'sets': sets,
      'weight': weight,
    };
  }

  factory PlanItem.fromMap(Map<String, dynamic> map) {
    return PlanItem(
      id: map['id'],
      dayOfWeek: map['dayOfWeek'],
      exerciseName: map['exerciseName'],
      sets: map['sets'],
      weight: map['weight'],
    );
  }
}