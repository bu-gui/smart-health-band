import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionsHelper {
  PermissionsHelper._();

  static int get _androidApiLevel {
    if (!Platform.isAndroid) return 0;
    final version = Platform.operatingSystemVersion;
    final regex = RegExp(r'API\s+(\d+)');
    final match = regex.firstMatch(version);
    if (match != null) return int.parse(match.group(1)!);
    return 0;
  }

  static Future<bool> hasBlePermissions() async {
    if (!Platform.isAndroid) return true;

    final apiLevel = _androidApiLevel;
    if (apiLevel >= 31) {
      final scan = await ph.Permission.bluetoothScan.status;
      final connect = await ph.Permission.bluetoothConnect.status;
      return scan.isGranted && connect.isGranted;
    } else if (apiLevel >= 29) {
      return await ph.Permission.locationWhenInUse.isGranted;
    } else {
      return await ph.Permission.location.isGranted;
    }
  }

  static Future<PermissionResult> requestBlePermissions() async {
    if (!Platform.isAndroid) {
      return const PermissionResult(granted: true);
    }

    final apiLevel = _androidApiLevel;

    if (apiLevel >= 31) {
      final results = await [
        ph.Permission.bluetoothScan,
        ph.Permission.bluetoothConnect,
      ].request();

      final scanGranted =
          results[ph.Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted =
          results[ph.Permission.bluetoothConnect]?.isGranted ?? false;

      if (scanGranted && connectGranted) {
        return const PermissionResult(granted: true);
      }

      final scanDenied =
          results[ph.Permission.bluetoothScan]?.isPermanentlyDenied ?? false;
      final connectDenied =
          results[ph.Permission.bluetoothConnect]?.isPermanentlyDenied ?? false;

      if (scanDenied || connectDenied) {
        return const PermissionResult(
          granted: false,
          permanentlyDenied: true,
          message: '蓝牙权限已被永久拒绝，请在系统设置中手动开启',
        );
      }

      return const PermissionResult(granted: false, message: '需要蓝牙权限才能搜索和连接设备');
    }

    if (apiLevel >= 29) {
      final status = await ph.Permission.locationWhenInUse.request();
      if (status.isGranted) {
        return const PermissionResult(granted: true);
      }
      if (status.isPermanentlyDenied) {
        return const PermissionResult(
          granted: false,
          permanentlyDenied: true,
          message: '位置权限已被永久拒绝。Android 10及以上系统需要位置权限才能扫描蓝牙设备，请在系统设置中手动开启。',
        );
      }
      return const PermissionResult(
        granted: false,
        message: '需要位置权限才能扫描蓝牙设备（Android 10及以上系统要求）',
      );
    }

    final status = await ph.Permission.location.request();
    if (status.isGranted) {
      return const PermissionResult(granted: true);
    }
    if (status.isPermanentlyDenied) {
      return const PermissionResult(
        granted: false,
        permanentlyDenied: true,
        message: '位置权限已被永久拒绝，请在系统设置中手动开启',
      );
    }
    return const PermissionResult(granted: false, message: '需要位置权限才能扫描蓝牙设备');
  }

  static Future<bool> openAppSettings() {
    return ph.openAppSettings();
  }
}

class PermissionResult {
  final bool granted;
  final bool permanentlyDenied;
  final String? message;

  const PermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
    this.message,
  });
}
