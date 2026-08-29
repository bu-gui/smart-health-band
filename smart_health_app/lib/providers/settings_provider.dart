import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../services/database_service.dart';
import 'health_provider.dart';

/// 用户设置状态管理器
class SettingsNotifier extends StateNotifier<UserSettings> {
  final DatabaseService _db;

  SettingsNotifier(this._db) : super(const UserSettings()) {
    _loadSettings();
  }

  /// 从数据库加载用户设置
  Future<void> _loadSettings() async {
    final age = await _db.getSetting('age');
    final gender = await _db.getSetting('gender');
    final height = await _db.getSetting('height');
    final weight = await _db.getSetting('weight');
    final stepGoal = await _db.getSetting('daily_step_goal');
    final hrUpper = await _db.getSetting('hr_upper_limit');
    final hrLower = await _db.getSetting('hr_lower_limit');
    final spo2Lower = await _db.getSetting('spo2_lower_limit');
    final fallEnabled = await _db.getSetting('fall_alert_enabled');
    final fallMode = await _db.getSetting('fall_alert_mode');

    state = UserSettings(
      age: int.tryParse(age ?? '') ?? 25,
      gender: gender ?? 'male',
      height: double.tryParse(height ?? '') ?? 170.0,
      weight: double.tryParse(weight ?? '') ?? 65.0,
      dailyStepGoal: int.tryParse(stepGoal ?? '') ?? 8000,
      heartRateUpperLimit: int.tryParse(hrUpper ?? '') ?? 120,
      heartRateLowerLimit: int.tryParse(hrLower ?? '') ?? 50,
      spo2LowerLimit: int.tryParse(spo2Lower ?? '') ?? 95,
      fallAlertEnabled: fallEnabled != 'false',
      fallAlertMode: fallMode ?? 'both',
    );
  }

  /// 更新用户设置并持久化到数据库
  Future<void> updateSettings(UserSettings newSettings) async {
    await _db.setSetting('age', newSettings.age.toString());
    await _db.setSetting('gender', newSettings.gender);
    await _db.setSetting('height', newSettings.height.toString());
    await _db.setSetting('weight', newSettings.weight.toString());
    await _db.setSetting('daily_step_goal', newSettings.dailyStepGoal.toString());
    await _db.setSetting('hr_upper_limit', newSettings.heartRateUpperLimit.toString());
    await _db.setSetting('hr_lower_limit', newSettings.heartRateLowerLimit.toString());
    await _db.setSetting('spo2_lower_limit', newSettings.spo2LowerLimit.toString());
    await _db.setSetting('fall_alert_enabled', newSettings.fallAlertEnabled.toString());
    await _db.setSetting('fall_alert_mode', newSettings.fallAlertMode);
    state = newSettings;
  }

  /// 保存上次连接的设备ID
  Future<void> setLastConnectedDevice(String deviceId) async {
    await _db.setSetting('last_device_id', deviceId);
  }

  /// 获取上次连接的设备ID
  Future<String?> getLastConnectedDevice() async {
    return _db.getSetting('last_device_id');
  }
}

/// 用户设置状态提供者
final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return SettingsNotifier(db);
});
