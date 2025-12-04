// lib/services/plan_service.dart
import '../models/user_model.dart';

import '../models/workout_plan_model.dart';

class PlanService {
  // 靜態方法，可以直接呼叫
  static List<WorkoutPlan> getPredefinedPlans() {
    return [
      // --- 輕度計畫 ---
      const WorkoutPlan(
        name: '輕度 - 居家徒手入門',
        description: '為初學者設計的全身性居家訓練，無需器材，專注於建立基礎肌力。',
        targetLevel: FitnessLevel.light,
        days: [
          WorkoutDay(
            dayLabel: '第一天',
            focus: '全身循環',
            exercises: [
              RecommendedExercise(name: '開合跳', sets: '3 組，每組 30 秒'),
              RecommendedExercise(name: '深蹲', sets: '3 組，每組 12 下'),
              RecommendedExercise(name: '伏地挺身 (可跪姿)', sets: '3 組，盡力做'),
              RecommendedExercise(name: '平板支撐', sets: '3 組，每組 30 秒'),
            ],
          ),
          // 輕度可以只安排一天，讓使用者重複做
        ],
      ),
      // --- 中度計畫 ---
      const WorkoutPlan(
        name: '中度 - 三日分化訓練',
        description: '適合有健身房經驗者，將全身肌群分三天進行更集中的刺激。',
        targetLevel: FitnessLevel.medium,
        days: [
          WorkoutDay(
            dayLabel: '第一天',
            focus: '胸 & 三頭',
            exercises: [
              RecommendedExercise(name: '槓鈴臥推', sets: '4 組，每組 8-12 下'),
              RecommendedExercise(name: '啞鈴上胸臥推', sets: '3 組，每組 10-15 下'),
              RecommendedExercise(name: '繩索夾胸', sets: '3 組，每組 12-15 下'),
              RecommendedExercise(name: '三頭下壓', sets: '4 組，每組 12-15 下'),
            ],
          ),
          WorkoutDay(
            dayLabel: '第二天',
            focus: '背 & 二頭',
            exercises: [
              RecommendedExercise(name: '引體向上', sets: '4 組，盡力做'),
              RecommendedExercise(name: '槓鈴划船', sets: '4 組，每組 8-12 下'),
              RecommendedExercise(name: '滑輪下拉', sets: '3 組，每組 12-15 下'),
              RecommendedExercise(name: '啞鈴彎舉', sets: '4 組，每組 12-15 下'),
            ],
          ),
          WorkoutDay(
            dayLabel: '第三天',
            focus: '腿 & 肩',
            exercises: [
              RecommendedExercise(name: '槓鈴深蹲', sets: '4 組，每組 8-12 下'),
              RecommendedExercise(name: '腿推舉', sets: '3 組，每組 12-15 下'),
              RecommendedExercise(name: '啞鈴肩推', sets: '4 組，每組 10-12 下'),
              RecommendedExercise(name: '啞鈴側平舉', sets: '3 組，每組 15 下'),
            ],
          ),
        ],
      ),
      // --- 重度計畫可以先留空，或複製中度的來修改 ---
      const WorkoutPlan(
        name: '重度 - 五日進階分化',
        description: '為追求極限的進階者設計，最大化各肌群的刺激與恢復週期。',
        targetLevel: FitnessLevel.heavy,
        days: [
          // (這裡可以先留空，或之後再補上詳細課表)
        ],
      ),
    ];
  }
}