class CalorieCalculator {
  /// Calculates calories burned per minute using the Keytel formula.
  /// 
  /// [heartRate] - Beats per minute (bpm)
  /// [weightKg] - Weight in Kilograms (kg)
  /// [age] - Age in years
  /// [gender] - "Male", "Female", "男", "女" (defaults to Male if unknown)
  /// [durationMinutes] - Duration of the activity in minutes (default 1)
  ///
  /// Returns total calories burned in the given duration.
  static double calculateCalories({
    required int heartRate,
    required double weightKg,
    required int age,
    required String gender,
    double durationMinutes = 1.0,
  }) {
    if (heartRate <= 0) return 0.0;

    // Normalize gender string
    bool isMale = true;
    final g = gender.toLowerCase();
    if (g.contains('female') || g.contains('女') || g == 'f') {
      isMale = false;
    }

    // Keytel Formula
    // Male: ((-55.0969 + (0.6309 x HR) + (0.1988 x W) + (0.2017 x A)) / 4.184) * T
    // Female: ((-20.4022 + (0.4472 x HR) - (0.1263 x W) + (0.074 x A)) / 4.184) * T

    double caloriesPerMinute;

    if (isMale) {
      caloriesPerMinute = (-55.0969 + (0.6309 * heartRate) + (0.1988 * weightKg) + (0.2017 * age)) / 4.184;
    } else {
      caloriesPerMinute = (-20.4022 + (0.4472 * heartRate) - (0.1263 * weightKg) + (0.074 * age)) / 4.184;
    }

    if (caloriesPerMinute < 0) return 0.0;

    return caloriesPerMinute * durationMinutes;
  }
}
