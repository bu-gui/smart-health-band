class DailySummary {
  final String date;
  final double avgHeartRate;
  final int minHeartRate;
  final int maxHeartRate;
  final double avgSpo2;
  final int minSpo2;
  final int totalSteps;
  final int exerciseMinutes;
  final int fallCount;
  final int lowSpo2Count;

  DailySummary({
    required this.date,
    this.avgHeartRate = 0,
    this.minHeartRate = 0,
    this.maxHeartRate = 0,
    this.avgSpo2 = 0,
    this.minSpo2 = 0,
    this.totalSteps = 0,
    this.exerciseMinutes = 0,
    this.fallCount = 0,
    this.lowSpo2Count = 0,
  });

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      date: map['date'] as String,
      avgHeartRate: (map['avg_heart_rate'] as num?)?.toDouble() ?? 0,
      minHeartRate: map['min_heart_rate'] as int? ?? 0,
      maxHeartRate: map['max_heart_rate'] as int? ?? 0,
      avgSpo2: (map['avg_spo2'] as num?)?.toDouble() ?? 0,
      minSpo2: map['min_spo2'] as int? ?? 0,
      totalSteps: map['total_steps'] as int? ?? 0,
      exerciseMinutes: map['exercise_minutes'] as int? ?? 0,
      fallCount: map['fall_count'] as int? ?? 0,
      lowSpo2Count: map['low_spo2_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'avg_heart_rate': avgHeartRate,
      'min_heart_rate': minHeartRate,
      'max_heart_rate': maxHeartRate,
      'avg_spo2': avgSpo2,
      'min_spo2': minSpo2,
      'total_steps': totalSteps,
      'exercise_minutes': exerciseMinutes,
      'fall_count': fallCount,
      'low_spo2_count': lowSpo2Count,
    };
  }

  double get stepsCompletionRate => totalSteps > 0 ? (totalSteps / 8000 * 100).clamp(0, 999) : 0;
}
