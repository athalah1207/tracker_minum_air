class UserProfile {
  String id;
  String name;
  double weightKg;
  int dailyGoalMl;
  int streakDays;

  UserProfile({
    required this.id,
    required this.name,
    required this.weightKg,
    required this.dailyGoalMl,
    this.streakDays = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final weight = (json['weightKg'] as num?)?.toDouble() ?? 60.0;
    return UserProfile(
      id: (json['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Pengguna',
      weightKg: weight,
      dailyGoalMl: (json['dailyGoalMl'] as num?)?.toInt() ?? calculateGoal(weight),
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weightKg': weightKg,
        'dailyGoalMl': dailyGoalMl,
        'streakDays': streakDays,
      };

  // Perkiraan awal aplikasi, bukan resep medis untuk kebutuhan cairan setiap orang.
  static int calculateGoal(double weight) => (weight * 35).round();
}
