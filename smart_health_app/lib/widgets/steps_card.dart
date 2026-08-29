import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 步数卡片组件
/// 显示今日步数、环形进度条、完成百分比和目标信息
class StepsCard extends StatelessWidget {
  /// 当前步数
  final int steps;

  /// 目标步数
  final int goal;

  const StepsCard({
    super.key,
    this.steps = 0,
    this.goal = 8000,
  });

  /// 完成进度（0.0 ~ 1.0）
  double get progress => (steps / goal).clamp(0.0, 1.0);

  /// 完成百分比
  int get percentage => (steps / goal * 100).clamp(0, 999).toInt();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：走路图标 + "今日步数"
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk,
                  color: AppColors.steps,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '今日步数',
                style: TextStyle(fontSize: 15, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // 环形进度条
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _RingPainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$steps',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 14,
                            color: progress >= 1.0
                                ? AppColors.safe
                                : AppColors.steps,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // 右侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '目标 $goal 步',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '还差 ${goal > steps ? goal - steps : 0} 步',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryText,
                      ),
                    ),
                    // 达标提示
                    if (progress >= 1.0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8EE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已达标',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.safe),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 环形进度条绘制器
class _RingPainter extends CustomPainter {
  /// 当前进度（0.0 ~ 1.0）
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    // 绘制背景环
    final bgPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 绘制进度环
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppColors.steps
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * 3.141592653589793 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
