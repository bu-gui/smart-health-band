class HealthRecord {
  final int? id;
  final int timestamp;
  final int heartRate;
  final int spo2;
  final int steps;
  final int motionState;
  final bool isFallAlert;
  final int signalQuality;
  final int battery;

  HealthRecord({
    this.id,
    required this.timestamp,
    this.heartRate = 0,
    this.spo2 = 0,
    this.steps = 0,
    this.motionState = 0,
    this.isFallAlert = false,
    this.signalQuality = 0,
    this.battery = 0,
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as int?,
      timestamp: map['timestamp'] as int,
      heartRate: map['heart_rate'] as int? ?? 0,
      spo2: map['spo2'] as int? ?? 0,
      steps: map['steps'] as int? ?? 0,
      motionState: map['motion_state'] as int? ?? 0,
      isFallAlert: (map['is_fall_alert'] as int? ?? 0) == 1,
      signalQuality: map['signal_quality'] as int? ?? 0,
      battery: map['battery'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'heart_rate': heartRate,
      'spo2': spo2,
      'steps': steps,
      'motion_state': motionState,
      'is_fall_alert': isFallAlert ? 1 : 0,
      'signal_quality': signalQuality,
      'battery': battery,
    };
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  String get motionText {
    switch (motionState) {
      case 0: return '静止';
      case 1: return '轻度活动';
      case 2: return '中度活动';
      case 3: return '剧烈运动';
      default: return '未知';
    }
  }

  bool get isHeartRateValid => heartRate > 0;
  bool get isSpo2Valid => spo2 >= 70 && spo2 <= 100;
  bool get isHeartRateAbnormal => heartRate > 120 || heartRate < 50;
  bool get isSpo2Low => spo2 > 0 && spo2 < 90;
  bool get isSpo2Warning => spo2 > 0 && spo2 < 95;
}
