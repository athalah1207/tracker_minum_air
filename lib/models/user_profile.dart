class UserProfile {
  double weightKg;
  int dailyGoalMl;
  int streakDays;

  UserProfile({
    required this.weightKg,
    required this.dailyGoalMl,
    this.streakDays = 0,
  });

  // Hitung otomatis target air harian (Standar: BB (kg) * 35 ml)
  static int calculateGoal(double weight) {
    return (weight * 35).round();
  }
}