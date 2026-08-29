import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_info.dart';
import '../services/ble_service.dart';
import '../utils/permissions_helper.dart';

/// 蓝牙连接状态枚举
enum BleConnectionState { disconnected, scanning, connecting, connected }

/// 蓝牙状态数据类
class BleState {
  /// 当前连接状态
  final BleConnectionState connectionState;

  /// 扫描结果列表
  final List<ScanResult> scanResults;

  /// 已连接的蓝牙设备
  final BluetoothDevice? connectedDevice;

  /// 设备信息
  final DeviceInfo deviceInfo;

  /// 错误信息
  final String? errorMessage;

  /// 权限是否被永久拒绝（需要引导用户去系统设置）
  final bool permissionsPermanentlyDenied;

  const BleState({
    this.connectionState = BleConnectionState.disconnected,
    this.scanResults = const [],
    this.connectedDevice,
    this.deviceInfo = const DeviceInfo(),
    this.errorMessage,
    this.permissionsPermanentlyDenied = false,
  });

  /// 复制并更新部分字段
  BleState copyWith({
    BleConnectionState? connectionState,
    List<ScanResult>? scanResults,
    BluetoothDevice? connectedDevice,
    DeviceInfo? deviceInfo,
    String? errorMessage,
    bool clearError = false,
    bool clearDevice = false,
    bool? permissionsPermanentlyDenied,
  }) {
    return BleState(
      connectionState: connectionState ?? this.connectionState,
      scanResults: scanResults ?? this.scanResults,
      connectedDevice: clearDevice
          ? null
          : (connectedDevice ?? this.connectedDevice),
      deviceInfo: deviceInfo ?? this.deviceInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      permissionsPermanentlyDenied:
          permissionsPermanentlyDenied ?? this.permissionsPermanentlyDenied,
    );
  }
}

/// 蓝牙状态管理器
class BleNotifier extends StateNotifier<BleState> {
  final BleService _bleService;

  BleNotifier(this._bleService) : super(const BleState()) {
    _setupCallbacks();
  }

  /// 设置蓝牙服务回调
  void _setupCallbacks() {
    _bleService.onScanResults = (results) {
      state = state.copyWith(scanResults: results);
    };
    _bleService.onConnectionStateChanged = (connected) {
      if (connected) {
        state = state.copyWith(connectionState: BleConnectionState.connected);
        _readDeviceInfo();
      } else {
        state = state.copyWith(
          connectionState: BleConnectionState.disconnected,
          clearDevice: true,
        );
      }
    };
    _bleService.onDisconnected = () {
      // 自动重连由 BleService 内部处理
    };
  }

  /// 检查并请求 BLE 所需权限，返回是否已获得权限
  Future<bool> _ensurePermissions() async {
    final hasPermission = await PermissionsHelper.hasBlePermissions();
    if (hasPermission) return true;

    final result = await PermissionsHelper.requestBlePermissions();
    if (!result.granted) {
      state = state.copyWith(
        connectionState: BleConnectionState.disconnected,
        errorMessage: result.message,
        permissionsPermanentlyDenied: result.permanentlyDenied,
      );
      return false;
    }
    return true;
  }

  /// 开始扫描蓝牙设备（自动先请求权限）
  Future<void> startScan() async {
    state = state.copyWith(
      connectionState: BleConnectionState.scanning,
      scanResults: [],
      clearError: true,
      permissionsPermanentlyDenied: false,
    );

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) return;

    await _bleService.startScan();
    if (state.scanResults.isEmpty) {
      state = state.copyWith(connectionState: BleConnectionState.disconnected);
    }
  }

  /// 停止扫描蓝牙设备
  Future<void> stopScan() async {
    await _bleService.stopScan();
    if (!_bleService.isConnected) {
      state = state.copyWith(connectionState: BleConnectionState.disconnected);
    }
  }

  /// 连接到指定蓝牙设备
  Future<bool> connectToDevice(BluetoothDevice device) async {
    final hasPermission = await _ensurePermissions();
    if (!hasPermission) return false;

    state = state.copyWith(
      connectionState: BleConnectionState.connecting,
      clearError: true,
    );
    final success = await _bleService.connect(device);
    if (!success) {
      state = state.copyWith(
        connectionState: BleConnectionState.disconnected,
        errorMessage: '连接失败，请重试',
      );
    }
    return success;
  }

  /// 断开蓝牙连接
  Future<void> disconnect() async {
    await _bleService.disconnect();
    state = state.copyWith(
      connectionState: BleConnectionState.disconnected,
      clearDevice: true,
    );
  }

  /// 清除权限拒绝状态（从系统设置返回后调用）
  Future<void> retryAfterSettings() async {
    state = state.copyWith(
      clearError: true,
      permissionsPermanentlyDenied: false,
    );
    await startScan();
  }

  /// 读取设备信息
  Future<void> _readDeviceInfo() async {
    final info = await _bleService.readDeviceInfo();
    state = state.copyWith(deviceInfo: info);
  }

  /// 重置步数
  Future<bool> resetSteps() => _bleService.resetSteps();

  /// 设置手环页面
  Future<bool> setPage(int page) => _bleService.setPage(page);

  /// 同步时间
  Future<bool> syncTime() => _bleService.syncTime();

  /// 开始测量
  Future<bool> startMeasure() => _bleService.startMeasure();

  /// 停止测量
  Future<bool> stopMeasure() => _bleService.stopMeasure();

  /// 发送自定义指令
  Future<bool> sendCommand(String cmd) => _bleService.sendCommand(cmd);

  /// 获取蓝牙服务实例
  BleService get bleService => _bleService;

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
}

/// 蓝牙服务提供者
final bleServiceProvider = Provider<BleService>((ref) => BleService());

/// 蓝牙状态提供者
final bleProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  return BleNotifier(ref.watch(bleServiceProvider));
});
