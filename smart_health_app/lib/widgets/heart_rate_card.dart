import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 心率卡片组件
/// 显示实时心率数值，带脉搏跳动动画和正常/异常状态标签
class HeartRateCard extends StatefulWidget {
  /// 心率值（bpm）
  final int heartRate;

  /// 数据是否有效
  final bool isValid;

  const HeartRateCard({
    super.key,
    this.heartRate = 0,
    this.isValid = true,
  });

  @override
  State<HeartRateCard> createState() => _HeartRateCardState();
}

class _HeartRateCardState extends State<HeartRateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startPulse();
  }

  /// 启动脉搏跳动动画循环
  void _startPulse() async {
    while (mounted) {
      await _pulseController.forward();
      await _pulseController.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNormal = widget.heartRate >= 60 && widget.heartRate <= 100;
    final displayColor = !widget.isValid
        ? AppColors.secondaryText
        : isNormal
            ? AppColors.safe
            : AppColors.heartRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：心形图标 + "心率"
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE5E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: AppColors.heartRate,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '心率',
                style: TextStyle(fontSize: 15, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 心率数值 + 脉搏动画
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isValid ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Text(
                  widget.isValid ? '${widget.heartRate}' : '--',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: displayColor,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'bpm',
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
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isNormal
                      ? const Color(0xFFE8F8EE)
                      : const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.isValid ? (isNormal ? '正常' : '异常') : '无信号',
                  style: TextStyle(
                    fontSize: 12,
                    color: isNormal ? AppColors.safe : AppColors.heartRate,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
