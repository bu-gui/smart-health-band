import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'health_alert',
      '健康告警',
      channelDescription: '健康数据异常告警',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showFallAlert({required String time, required int heartRate}) async {
    await showNotification(
      title: '⚠️ 检测到跌倒！',
      body: '时间: $time\n心率: $heartRate bpm',
      payload: 'fall_alert',
    );
  }

  Future<void> showHeartRateAlert({required int heartRate, required String type}) async {
    await showNotification(
      title: '心率异常',
      body: '当前心率: $heartRate bpm ($type)',
      payload: 'hr_alert',
    );
  }

  Future<void> showSpo2Alert({required int spo2}) async {
    await showNotification(
      title: '血氧过低',
      body: '当前血氧: $spo2%',
      payload: 'spo2_alert',
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
