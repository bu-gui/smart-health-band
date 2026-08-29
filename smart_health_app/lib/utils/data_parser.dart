import 'dart:convert';
import '../models/health_record.dart';

class DataParser {
  /// 解析 BLE 推送的 JSON 数据
  static HealthRecord? parseHealthData(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return HealthRecord(
        timestamp: json['ts'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        heartRate: json['hr'] as int? ?? 0,
        spo2: json['spo2'] as int? ?? 0,
        steps: json['steps'] as int? ?? 0,
        motionState: json['motion'] as int? ?? 0,
        isFallAlert: json['fall'] as bool? ?? false,
        signalQuality: json['sq'] as int? ?? 0,
        battery: json['bat'] as int? ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// 判断是否为跌倒告警消息
  static bool isFallAlert(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return json['fall'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 解析设备信息
  static Map<String, dynamic>? parseDeviceInfo(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
