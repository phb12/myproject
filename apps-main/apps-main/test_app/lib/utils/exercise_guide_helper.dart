class ExerciseGuideHelper {
  static String? getGuideImage(String exerciseName) {
    if (exerciseName.contains('深蹲')) {
      return 'assets/images/guide_squat.png';
    } else if (exerciseName.contains('彎舉')) {
      return 'assets/images/guide_curl.png';
    } else if (exerciseName.contains('肩推')) {
      return 'assets/images/guide_shoulder_press.png';
    } else if (exerciseName.contains('臥推')) {
      return 'assets/images/guide_bench_press.png';
    } else if (exerciseName.contains('伏地挺身')) {
      return 'assets/images/guide_push_up.png';
    } else if (exerciseName.contains('引體向上')) {
      return 'assets/images/guide_pull_up.png';
    }
    // Return null if no specific image exists to avoid confusion
    return null;
  }
}
