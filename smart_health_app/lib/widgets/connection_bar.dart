import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 连接状态栏组件，显示在监测页顶部
/// 显示设备名称、电池电量、信号强度和连接状态
class ConnectionBar extends StatelessWidget {
  /// 设备名称
  final String deviceName;

  /// 电池电量百分比（0-100）
  final int battery;

  /// 是否已连接
  final bool isConnected;

  /// 是否正在连接中
  final bool isConnecting;

  const ConnectionBar({
    super.key,
    required this.deviceName,
    this.battery = 0,
    this.isConnected = false,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 连接状态指示灯
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnecting
                  ? AppColors.warning
                  : (isConnected ? AppColors.safe : AppColors.secondaryText),
            ),
          ),
          const SizedBox(width: 8),
          // 设备名称
          Expanded(
            child: Text(
              deviceName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
          // 电池图标（低于20%红色警告）
          Icon(
            Icons.battery_full,
            size: 18,
            color: battery <= 20 ? AppColors.alert : AppColors.safe,
          ),
          const SizedBox(width: 4),
          Text(
            '$battery%',
            style: TextStyle(
              fontSize: 13,
              color: battery <= 20 ? AppColors.alert : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
