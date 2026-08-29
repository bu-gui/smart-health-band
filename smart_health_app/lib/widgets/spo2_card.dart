import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 血氧卡片组件
/// 显示血氧饱和度百分比，带多级状态标签（正常/偏低/过低）
class Spo2Card extends StatelessWidget {
  /// 血氧值（%）
  final int spo2;

  /// 数据是否有效
  final bool isValid;

  const Spo2Card({
    super.key,
    this.spo2 = 0,
    this.isValid = true,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = isValid && spo2 < 95 && spo2 >= 90;
    final isCritical = isValid && spo2 < 90;
    final displayColor = !isValid
        ? AppColors.secondaryText
        : isCritical
            ? AppColors.alert
            : isWarning
                ? AppColors.warning
                : AppColors.spo2;

    // 根据状态确定标签文字和颜色
    String statusText;
    Color statusColor;
    Color statusBg;
    if (!isValid) {
      statusText = '无信号';
      statusColor = AppColors.secondaryText;
      statusBg = AppColors.background;
    } else if (isCritical) {
      statusText = '过低';
      statusColor = AppColors.alert;
      statusBg = const Color(0xFFFFE5E5);
    } else if (isWarning) {
      statusText = '偏低';
      statusColor = AppColors.warning;
      statusBg = const Color(0xFFFFF8E1);
    } else {
      statusText = '正常';
      statusColor = AppColors.safe;
      statusBg = const Color(0xFFE8F8EE);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：肺图标 + "血氧"
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F4FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.air,
                  color: AppColors.spo2,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '血氧',
                style: TextStyle(fontSize: 15, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 血氧数值
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isValid ? '$spo2' : '--',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w500,
                  color: displayColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 12, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
