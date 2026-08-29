import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/date_helper.dart';

/// 跌倒告警全屏弹窗
/// 检测到跌倒事件时弹出，提供"我没事"和"紧急求助"两个操作按钮
class FallAlertDialog extends StatelessWidget {
  /// 跌倒时的心率值
  final int heartRate;

  /// 跌倒发生时间
  final DateTime time;

  /// "我没事"回调
  final VoidCallback onDismiss;

  /// "紧急求助"回调
  final VoidCallback onEmergency;

  const FallAlertDialog({
    super.key,
    required this.heartRate,
    required this.time,
    required this.onDismiss,
    required this.onEmergency,
  });

  /// 显示跌倒告警弹窗
  static Future<void> show({
    required BuildContext context,
    required int heartRate,
    required DateTime time,
    required VoidCallback onDismiss,
    required VoidCallback onEmergency,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FallAlertDialog(
        heartRate: heartRate,
        time: time,
        onDismiss: onDismiss,
        onEmergency: onEmergency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 警告图标
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.alert,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // 告警标题
            const Text(
              '检测到跌倒！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.alert,
              ),
            ),
            const SizedBox(height: 16),
            // 跌倒时间
            Text(
              '时间: ${DateHelper.formatTime(time)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            // 跌倒时心率
            Text(
              '心率: $heartRate bpm',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            // 操作按钮
            Row(
              children: [
                // "我没事"按钮（灰色描边）
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '我没事',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // "紧急求助"按钮（红色填充）
                Expanded(
                  child: ElevatedButton(
                    onPressed: onEmergency,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.alert,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '紧急求助',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
