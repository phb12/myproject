
enum RepState {
  neutral, // Standing / Start position
  descending, // Going down
  bottom, // At the bottom / peak contraction
  ascending, // Going up
}

class RepCounter {
  RepState _state = RepState.neutral;
  int _count = 0;
  
  // Thresholds for Squat
  static const double SQUAT_STAND_THRESHOLD = 160.0; // Knee angle > 160 means standing
  static const double SQUAT_BOTTOM_THRESHOLD = 100.0; // Knee angle < 100 means bottom (Full Squat)

  int get count => _count;
  RepState get state => _state;

  void reset() {
    _count = 0;
    _state = RepState.neutral;
  }

  /// Returns true if a rep is completed
  bool checkRep(String exerciseName, Map<String, double> angles, String detectedClass) {
    if (exerciseName.contains('深蹲')) {
      return _checkSquat(angles, detectedClass);
    }
    // Add other exercises here
    return false;
  }

  bool _checkSquat(Map<String, double> angles, String detectedClass) {
    // Optional: Use detectedClass to validate
    // if (!detectedClass.contains('squat') && !detectedClass.contains('chair')) return false;

    final double? kneeAngle = angles['knee'];
    final double? hipAngle = angles['hip'];

    if (kneeAngle == null || hipAngle == null) return false;

    // State Machine
    switch (_state) {
      case RepState.neutral:
      case RepState.ascending:
        // Check if going down
        if (kneeAngle < SQUAT_STAND_THRESHOLD && kneeAngle > SQUAT_BOTTOM_THRESHOLD) {
          _state = RepState.descending;
        }
        break;
        
      case RepState.descending:
        // Check if reached bottom
        if (kneeAngle <= SQUAT_BOTTOM_THRESHOLD) {
          _state = RepState.bottom;
        } else if (kneeAngle >= SQUAT_STAND_THRESHOLD) {
           // Aborted rep, went back up without hitting bottom
           _state = RepState.neutral;
        }
        break;

      case RepState.bottom:
        // Check if going up
        if (kneeAngle > SQUAT_BOTTOM_THRESHOLD) {
          _state = RepState.ascending;
        }
        break;
    }

    // Check for completion (Back to neutral/standing from ascending/bottom)
    if ((_state == RepState.ascending || _state == RepState.bottom) && kneeAngle >= SQUAT_STAND_THRESHOLD) {
      _count++;
      _state = RepState.neutral;
      return true;
    }

    return false;
  }
}
