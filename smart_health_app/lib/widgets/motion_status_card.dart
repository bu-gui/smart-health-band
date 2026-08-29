import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 运动状态和信号质量双列小卡片
/// 左侧显示当前运动状态，右侧显示信号质量等级
class MotionStatusCard extends StatelessWidget {
  /// 运动状态（0=静止, 1=轻度活动, 2=中度活动, 3=剧烈运动）
  final int motionState;

  /// 信号质量（0-100）
  final int signalQuality;

  const MotionStatusCard({
    super.key,
    this.motionState = 0,
    this.signalQuality = 0,
  });

  /// 运动状态文字描述
  String get motionText {
    switch (motionState) {
      case 0:
        return '静止';
      case 1:
        return '轻度活动';
      case 2:
        return '中度活动';
      case 3:
        return '剧烈运动';
      default:
        return '未知';
    }
  }

  /// 运动状态对应图标
  IconData get motionIcon {
    switch (motionState) {
      case 0:
        return Icons.accessibility_new;
      case 1:
        return Icons.directions_walk;
      case 2:
        return Icons.directions_run;
      case 3:
        return Icons.fitness_center;
      default:
        return Icons.help_outline;
    }
  }

  /// 运动状态对应颜色
  Color get motionColor {
    switch (motionState) {
      case 0:
        return AppColors.secondaryText;
      case 1:
        return AppColors.safe;
      case 2:
        return AppColors.steps;
      case 3:
        return AppColors.heartRate;
      default:
        return AppColors.secondaryText;
    }
  }

  /// 信号质量文字描述
  String get signalText {
    if (signalQuality >= 80) return '优秀';
    if (signalQuality >= 50) return '良好';
    if (signalQuality >= 20) return '一般';
    return '差';
  }

  /// 信号强度条数（1-4）
  int get signalBars {
    if (signalQuality >= 80) return 4;
    if (signalQuality >= 50) return 3;
    if (signalQuality >= 20) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 运动状态卡片
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(motionIcon, color: motionColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  motionText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 信号质量卡片
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 信号强度条形图
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 6,
                      height: 8 + index * 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index < signalBars
                            ? AppColors.spo2
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  signalText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
