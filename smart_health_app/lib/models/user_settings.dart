class UserSettings {
  final int age;
  final String gender; // 'male' / 'female'
  final double height; // cm
  final double weight; // kg
  final int dailyStepGoal;
  final int heartRateUpperLimit;
  final int heartRateLowerLimit;
  final int spo2LowerLimit;
  final bool fallAlertEnabled;
  final String fallAlertMode; // 'vibrate' / 'sound' / 'both' / 'silent'

  const UserSettings({
    this.age = 25,
    this.gender = 'male',
    this.height = 170.0,
    this.weight = 65.0,
    this.dailyStepGoal = 8000,
    this.heartRateUpperLimit = 120,
    this.heartRateLowerLimit = 50,
    this.spo2LowerLimit = 95,
    this.fallAlertEnabled = true,
    this.fallAlertMode = 'both',
  });

  UserSettings copyWith({
    int? age,
    String? gender,
    double? height,
    double? weight,
    int? dailyStepGoal,
    int? heartRateUpperLimit,
    int? heartRateLowerLimit,
    int? spo2LowerLimit,
    bool? fallAlertEnabled,
    String? fallAlertMode,
  }) {
    return UserSettings(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      heartRateUpperLimit: heartRateUpperLimit ?? this.heartRateUpperLimit,
      heartRateLowerLimit: heartRateLowerLimit ?? this.heartRateLowerLimit,
      spo2LowerLimit: spo2LowerLimit ?? this.spo2LowerLimit,
      fallAlertEnabled: fallAlertEnabled ?? this.fallAlertEnabled,
      fallAlertMode: fallAlertMode ?? this.fallAlertMode,
    );
  }
}
