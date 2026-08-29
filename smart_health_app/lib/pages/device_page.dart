import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../utils/app_colors.dart';
import '../utils/permissions_helper.dart';

/// 设备连接页（Tab 1）
/// - 顶部标题 "设备"
/// - 扫描按钮（圆形蓝色按钮，蓝牙图标）
/// - 设备列表（显示设备名和 RSSI 信号强度）
/// - 点击设备连接，显示连接进度
/// - 连接成功后显示设备信息（固件版本、硬件版本、序列号）
/// - 自动重连状态显示
/// - 记住最近连接设备
class DevicePage extends ConsumerWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设备'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 扫描按钮
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon:
                          bleState.connectionState ==
                              BleConnectionState.scanning
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.bluetooth_searching,
                              color: Colors.white,
                              size: 36,
                            ),
                      onPressed:
                          bleState.connectionState ==
                              BleConnectionState.scanning
                          ? () => ref.read(bleProvider.notifier).stopScan()
                          : bleState.connectionState ==
                                BleConnectionState.connected
                          ? null
                          : () => ref.read(bleProvider.notifier).startScan(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bleState.connectionState == BleConnectionState.scanning
                        ? '正在扫描...'
                        : bleState.connectionState ==
                              BleConnectionState.connected
                        ? '已连接'
                        : '点击扫描设备',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 权限被永久拒绝时显示引导卡片
            if (bleState.permissionsPermanentlyDenied) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFCC80), width: 1),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '权限未开启',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bleState.errorMessage ?? '需要蓝牙相关权限才能搜索设备',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await PermissionsHelper.openAppSettings();
                        },
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('前往系统设置'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(bleProvider.notifier).retryAfterSettings(),
                      child: const Text(
                        '已开启，重试',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 设备列表
            if (bleState.scanResults.isNotEmpty) ...[
              const Text(
                '发现设备',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              ...bleState.scanResults.map(
                (result) => _buildDeviceItem(context, ref, result),
              ),
            ],

            // 已连接设备信息
            if (bleState.connectionState == BleConnectionState.connected &&
                bleState.deviceInfo.firmwareVersion.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '设备信息',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('设备型号', bleState.deviceInfo.model),
                    _buildInfoRow('固件版本', bleState.deviceInfo.firmwareVersion),
                    _buildInfoRow('硬件版本', bleState.deviceInfo.hardwareVersion),
                    _buildInfoRow('序列号', bleState.deviceInfo.serialNumber),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => ref.read(bleProvider.notifier).disconnect(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE5E5),
                    foregroundColor: AppColors.alert,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('断开连接', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],

            // 连接中状态
            if (bleState.connectionState == BleConnectionState.connecting) ...[
              const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      '正在连接...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 错误信息（权限拒绝时已在卡片中显示，不重复展示）
            if (bleState.errorMessage != null &&
                !bleState.permissionsPermanentlyDenied) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  bleState.errorMessage!,
                  style: const TextStyle(fontSize: 13, color: AppColors.alert),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建设备列表项
  Widget _buildDeviceItem(
    BuildContext context,
    WidgetRef ref,
    ScanResult result,
  ) {
    final rssi = result.rssi;
    String signalText;
    IconData signalIcon;
    if (rssi >= -50) {
      signalText = '强';
      signalIcon = Icons.signal_cellular_4_bar;
    } else if (rssi >= -70) {
      signalText = '中';
      signalIcon = Icons.signal_cellular_alt;
    } else {
      signalText = '弱';
      signalIcon = Icons.network_cell;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.watch, color: AppColors.primary, size: 24),
        ),
        title: Text(
          result.device.platformName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
          ),
        ),
        subtitle: Text(
          '信号: $signalText (${rssi}dBm)',
          style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        trailing: Icon(signalIcon, color: AppColors.secondaryText, size: 20),
        onTap: () =>
            ref.read(bleProvider.notifier).connectToDevice(result.device),
      ),
    );
  }

  /// 构建设备信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
