// 運動指導圖片輔助類別 (負責根據運動名稱取得對應的示範圖)
class ExerciseGuideHelper {
  // 取得示範圖片路徑
  static String? getGuideImage(String exerciseName) {
    if (exerciseName.contains('深蹲') || exerciseName.contains('Squat')) {
      return 'assets/images/guide_squat.png';
    } else if (exerciseName.contains('彎舉') || exerciseName.contains('Curl')) { // 二頭彎舉
      return 'assets/images/guide_curl.png';
    } else if (exerciseName.contains('肩推') || exerciseName.contains('Shoulder Press')) {
      return 'assets/images/guide_shoulder_press.png';
    } else if (exerciseName.contains('臥推') || exerciseName.contains('Bench Press')) {
      return 'assets/images/guide_bench_press.png';
    } else if (exerciseName.contains('伏地挺身') || exerciseName.contains('Push Up')) {
      return 'assets/images/guide_push_up.png';
    } else if (exerciseName.contains('引體向上') || exerciseName.contains('Pull Up')) {
      return 'assets/images/guide_pull_up.png';
    } else if (exerciseName.contains('捲腹') || exerciseName.contains('Crunch')) {
      return 'assets/images/guide_crunch.png';
    } else if (exerciseName.contains('硬舉') || exerciseName.contains('Deadlift')) {
      return 'assets/images/guide_deadlift.png';
    } else if (exerciseName.contains('側平舉') || exerciseName.contains('Lateral Raise')) {
      return 'assets/images/guide_lateral_raise.png';
    } else if (exerciseName.contains('三頭下壓') || exerciseName.contains('Tricep Pushdown')) {
      return 'assets/images/guide_tricep_pushdown.png';
    }
    // Return null if no specific image exists to avoid confusion
    return null;
  }
}
