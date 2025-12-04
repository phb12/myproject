//建議課程 目前沒用到
import './user_model.dart'; 

// 一個完整的訓練計畫
class WorkoutPlan {
  final String name;
  final String description;
  final FitnessLevel targetLevel; // 這個計畫對應哪個強度等級
  final List<WorkoutDay> days;

  const WorkoutPlan({
    required this.name,
    required this.description,
    required this.targetLevel,
    required this.days,
  });
}

// 計畫中的每一天
class WorkoutDay {
  final String dayLabel; // 例如 "第一天" 或 "Day 1"
  final String focus;    // 當天的訓練重點，例如 "胸 & 三頭"
  final List<RecommendedExercise> exercises;

  const WorkoutDay({
    required this.dayLabel,
    required this.focus,
    required this.exercises,
  });
}

// 推薦的訓練動作
class RecommendedExercise {
  final String name;
  final String sets; // 例如 "3-4 組，每組 8-12 下"

  const RecommendedExercise({
    required this.name,
    required this.sets,
  });
}