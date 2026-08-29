import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_record.dart';
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/user_settings.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';

/// 健康数据状态类
class HealthState {
  /// 最新的健康记录
  final HealthRecord? latestRecord;

  /// 心率值
  final int heartRate;

  /// 血氧值
  final int spo2;

  /// 步数
  final int steps;

  /// 运动状态
  final int motionState;

  /// 信号质量
  final int signalQuality;

  /// 电量
  final int battery;

  /// 是否跌倒告警
  final bool isFallAlert;

  /// 最后更新时间
  final DateTime? lastUpdateTime;

  /// 是否显示跌倒告警弹窗
  final bool showFallAlert;

  const HealthState({
    this.latestRecord,
    this.heartRate = 0,
    this.spo2 = 0,
    this.steps = 0,
    this.motionState = 0,
    this.signalQuality = 0,
    this.battery = 0,
    this.isFallAlert = false,
    this.lastUpdateTime,
    this.showFallAlert = false,
  });

  /// 运动状态文字描述
  String get motionText {
    switch (motionState) {
      case 0: return '静止';
      case 1: return '轻度活动';
      case 2: return '中度活动';
      case 3: return '剧烈运动';
      default: return '未知';
    }
  }

  /// 心率是否在正常范围（60-100）
  bool get isHeartRateNormal => heartRate >= 60 && heartRate <= 100;

  /// 血氧是否偏低告警
  bool get isSpo2Warning => spo2 > 0 && spo2 < 95;

  /// 血氧是否严重偏低
  bool get isSpo2Critical => spo2 > 0 && spo2 < 90;

  /// 复制并更新部分字段
  HealthState copyWith({
    HealthRecord? latestRecord,
    int? heartRate,
    int? spo2,
    int? steps,
    int? motionState,
    int? signalQuality,
    int? battery,
    bool? isFallAlert,
    DateTime? lastUpdateTime,
    bool? showFallAlert,
  }) {
    return HealthState(
      latestRecord: latestRecord ?? this.latestRecord,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      steps: steps ?? this.steps,
      motionState: motionState ?? this.motionState,
      signalQuality: signalQuality ?? this.signalQuality,
      battery: battery ?? this.battery,
      isFallAlert: isFallAlert ?? this.isFallAlert,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      showFallAlert: showFallAlert ?? this.showFallAlert,
    );
  }
}

/// 健康数据状态管理器
class HealthNotifier extends StateNotifier<HealthState> {
  final BleService _bleService;
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  final UserSettings Function() _getSettings;
  StreamSubscription? _dataSubscription;
  DateTime? _lastFallAlertTime;
  DateTime? _lastHrAlertTime;
  DateTime? _lastSpo2AlertTime;

  HealthNotifier(this._bleService, this._databaseService, this._notificationService, this._getSettings)
      : super(const HealthState()) {
    _setupDataListener();
  }

  /// 设置蓝牙数据监听
  void _setupDataListener() {
    _bleService.onDataReceived = (data) {
      final record = HealthRecord(
        timestamp: data['ts'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        heartRate: data['hr'] as int? ?? 0,
        spo2: data['spo2'] as int? ?? 0,
        steps: data['steps'] as int? ?? 0,
        motionState: data['motion'] as int? ?? 0,
        isFallAlert: data['fall'] as bool? ?? false,
        signalQuality: data['sq'] as int? ?? 0,
        battery: data['bat'] as int? ?? 0,
      );

      // 存储到数据库
      _databaseService.insertHealthRecord(record);

      // 触发告警通知（跌倒/心率/血氧）
      unawaited(_handleAlerts(record));

      // 处理跌倒告警（3秒去重）
      if (record.isFallAlert) {
        final now = DateTime.now();
        if (_lastFallAlertTime == null || now.difference(_lastFallAlertTime!).inSeconds > 3) {
          _lastFallAlertTime = now;
          state = state.copyWith(showFallAlert: true, isFallAlert: true);
        }
      }

      // 更新状态
      state = HealthState(
        latestRecord: record,
        heartRate: record.heartRate,
        spo2: record.spo2,
        steps: record.steps,
        motionState: record.motionState,
        signalQuality: record.signalQuality,
        battery: record.battery,
        isFallAlert: record.isFallAlert,
        lastUpdateTime: DateTime.now(),
        showFallAlert: state.showFallAlert,
      );
    };
  }

  /// 触发健康告警通知（带去重）
  Future<void> _handleAlerts(HealthRecord record) async {
    if (record.isFallAlert) {
      await _notificationService.showFallAlert(
        time: _fmtTime(DateTime.now()),
        heartRate: record.heartRate,
      );
      return;
    }

    final s = _getSettings();
    final now = DateTime.now();

    // 心率越限告警（60 秒去重）
    if (record.heartRate > 0 &&
        (record.heartRate > s.heartRateUpperLimit || record.heartRate < s.heartRateLowerLimit)) {
      if (_lastHrAlertTime == null || now.difference(_lastHrAlertTime!).inSeconds > 60) {
        _lastHrAlertTime = now;
        final type = record.heartRate > s.heartRateUpperLimit ? '过高' : '过低';
        await _notificationService.showHeartRateAlert(heartRate: record.heartRate, type: type);
      }
    }

    // 血氧过低告警（60 秒去重）
    if (record.spo2 > 0 && record.spo2 < s.spo2LowerLimit) {
      if (_lastSpo2AlertTime == null || now.difference(_lastSpo2AlertTime!).inSeconds > 60) {
        _lastSpo2AlertTime = now;
        await _notificationService.showSpo2Alert(spo2: record.spo2);
      }
    }
  }

  /// 格式化时间字符串
  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// 关闭跌倒告警弹窗
  void dismissFallAlert() {
    state = state.copyWith(showFallAlert: false, isFallAlert: false);
  }

  /// 重置健康数据状态
  void reset() {
    state = const HealthState();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}

/// 数据库服务提供者
final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

/// 健康数据状态提供者
final healthProvider = StateNotifierProvider<HealthNotifier, HealthState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final dbService = ref.watch(databaseServiceProvider);
  final notif = ref.watch(notificationServiceProvider);
  return HealthNotifier(bleService, dbService, notif, () => ref.read(settingsProvider));
});
