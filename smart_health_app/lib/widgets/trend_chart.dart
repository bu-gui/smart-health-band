import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 图表类型枚举
enum ChartType { line, bar }

/// 通用趋势图组件
/// 支持折线图和柱状图，可配置正常范围、数据点标注和时间标签
class TrendChart extends StatelessWidget {
  /// 图表类型
  final ChartType chartType;

  /// 数据点列表
  final List<FlSpot> spots;

  /// 底部时间标签列表
  final List<String> labels;

  /// 图表标题
  final String title;

  /// 图表副标题
  final String? subtitle;

  /// 折线颜色
  final Color lineColor;

  /// 正常范围下限
  final double? normalMin;

  /// 正常范围上限
  final double? normalMax;

  /// 告警阈值
  final double? warningThreshold;

  /// 柱状图颜色
  final Color barColor;

  /// 目标线数值
  final double? targetLine;

  /// Y轴最小值
  final double minY;

  /// Y轴最大值
  final double maxY;

  const TrendChart({
    super.key,
    this.chartType = ChartType.line,
    required this.spots,
    required this.labels,
    required this.title,
    this.subtitle,
    this.lineColor = AppColors.heartRate,
    this.normalMin,
    this.normalMax,
    this.warningThreshold,
    this.barColor = AppColors.steps,
    this.targetLine,
    this.minY = 0,
    this.maxY = 200,
  });

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: chartType == ChartType.line
                ? _buildLineChart()
                : _buildBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final lineBarsData = [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: lineColor,
        barWidth: 2,
        dotData: FlDotData(show: spots.length <= 24),
        belowBarData: BarAreaData(
          show: true,
          color: lineColor.withValues(alpha: 0.1),
        ),
      ),
    ];

    final titlesData = FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= labels.length) {
              return const SizedBox();
            }
            if (labels.length > 12 && index % (labels.length ~/ 6) != 0) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                labels[index],
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            );
          },
          reservedSize: 24,
        ),
      ),
    );

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.divider, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: titlesData,
        lineBarsData: lineBarsData,
      ),
    );
  }

  Widget _buildBarChart() {
    final barGroups = List.generate(spots.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: spots[index].y,
            color: barColor,
            width: labels.length > 15 ? 8 : 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final titlesData = FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= labels.length) {
              return const SizedBox();
            }
            if (labels.length > 12 && index % (labels.length ~/ 6) != 0) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                labels[index],
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            );
          },
          reservedSize: 24,
        ),
      ),
    );

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.divider, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: titlesData,
        barGroups: barGroups,
      ),
    );
  }
}
