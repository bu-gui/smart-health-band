import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_info.dart';

class BleService {
  static const String _deviceName = 'SmartHealthBand';
  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _notifyUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _writeUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  static const String _readUuid = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  StreamSubscription? _notifySubscription;

  bool _isScanning = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const List<int> _reconnectDelays = [5000, 10000, 20000];

  // 回调
  Function(Map<String, dynamic> data)? onDataReceived;
  Function()? onDisconnected;
  Function(BluetoothDevice device)? onDeviceFound;
  Function(bool connected)? onConnectionStateChanged;
  Function(List<ScanResult> results)? onScanResults;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get device => _device;

  /// 开始扫描设备
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;

    FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where((r) => r.device.platformName == _deviceName).toList();
      if (filtered.isNotEmpty) {
        onScanResults?.call(filtered);
        onDeviceFound?.call(filtered.first.device);
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    _isScanning = false;
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  /// 连接设备
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _device = device;
      onConnectionStateChanged?.call(false);

      await device.connect(timeout: const Duration(seconds: 15));
      _isConnected = true;
      onConnectionStateChanged?.call(true);

      // 发现服务
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final characteristic in service.characteristics) {
            final uuid = characteristic.uuid.toString().toLowerCase();
            if (uuid == _notifyUuid) {
              await characteristic.setNotifyValue(true);
              _notifySubscription = characteristic.onValueReceived.listen(_onNotifyData);
            } else if (uuid == _writeUuid) {
              _writeCharacteristic = characteristic;
            } else if (uuid == _readUuid) {
              _readCharacteristic = characteristic;
            }
          }
        }
      }

      // 监听断开
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          onConnectionStateChanged?.call(false);
          onDisconnected?.call();
          _attemptReconnect();
        }
      });

      return true;
    } catch (e) {
      _isConnected = false;
      onConnectionStateChanged?.call(false);
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _device?.disconnect();
    _device = null;
    _writeCharacteristic = null;
    _readCharacteristic = null;
    _isConnected = false;
    _reconnectAttempts = 0;
    onConnectionStateChanged?.call(false);
  }

  /// 自动重连
  Future<void> _attemptReconnect() async {
    if (_device == null || _reconnectAttempts >= _reconnectDelays.length) return;

    final delay = _reconnectDelays[_reconnectAttempts];
    _reconnectAttempts++;

    await Future.delayed(Duration(milliseconds: delay));
    if (_device != null && !_isConnected) {
      try {
        await _device!.connect(timeout: const Duration(seconds: 15));
        _isConnected = true;
        _reconnectAttempts = 0;
        onConnectionStateChanged?.call(true);

        // 重新订阅
        final services = await _device!.discoverServices();
        for (final service in services) {
          if (service.uuid.toString().toLowerCase() == _serviceUuid) {
            for (final characteristic in service.characteristics) {
              if (characteristic.uuid.toString().toLowerCase() == _notifyUuid) {
                await characteristic.setNotifyValue(true);
                _notifySubscription = characteristic.onValueReceived.listen(_onNotifyData);
              }
            }
          }
        }
      } catch (e) {
        _attemptReconnect();
      }
    }
  }

  /// 处理 Notify 数据
  void _onNotifyData(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      onDataReceived?.call(data);
    } catch (e) {
      // 解析失败，忽略
    }
  }

  /// 发送指令
  Future<bool> sendCommand(String command) async {
    if (_writeCharacteristic == null) return false;
    try {
      await _writeCharacteristic!.write(utf8.encode(command));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 读取设备信息
  Future<DeviceInfo> readDeviceInfo() async {
    if (_readCharacteristic == null) return DeviceInfo.empty();
    try {
      final value = await _readCharacteristic!.read();
      final jsonString = utf8.decode(value);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DeviceInfo.fromJson(json);
    } catch (e) {
      return DeviceInfo.empty();
    }
  }

  /// 发送预设指令
  Future<bool> resetSteps() => sendCommand('reset_steps');
  Future<bool> setPage(int page) => sendCommand('set_page:$page');
  Future<bool> syncTime() => sendCommand('sync_time:${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
  Future<bool> startMeasure() => sendCommand('start_measure');
  Future<bool> stopMeasure() => sendCommand('stop_measure');

  void dispose() {
    _notifySubscription?.cancel();
  }
}
