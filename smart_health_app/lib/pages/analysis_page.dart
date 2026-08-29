import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_colors.dart';
import '../utils/date_helper.dart';
import '../widgets/trend_chart.dart';
import '../providers/health_provider.dart';
import '../services/database_service.dart';

/// 图表数据状态类
class ChartData {
  final List<FlSpot> spots;
  final List<String> labels;
  final String subtitle;

  const ChartData({
    required this.spots,
    required this.labels,
    required this.subtitle,
  });
}

/// 时间段类型
enum PeriodType { day, week, month }

/// 数据分析页（Tab 3）
/// - 页面标题 "数据分析"
/// - 时间段切换（24小时/7天/30天 Segmented Control）
/// - 心率趋势折线图
/// - 血氧趋势折线图
/// - 步数统计柱状图
/// - 今日健康报告卡片
/// - 异常事件列表
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  int _selectedPeriod = 0; // 0=24h, 1=7d, 2=30d
  final List<String> _periods = ['24小时', '7天', '30天'];

  // 图表数据缓存
  ChartData? _heartRateData;
  ChartData? _spo2Data;
  ChartData? _stepsData;
  Map<String, dynamic>? _dailyReport;
  List<Map<String, dynamic>>? _abnormalEvents;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AnalysisPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当页面重新显示时刷新数据
    _loadData();
  }

  /// 获取当前时间段类型
  PeriodType get _currentPeriodType {
    switch (_selectedPeriod) {
      case 0:
        return PeriodType.day;
      case 1:
        return PeriodType.week;
      case 2:
        return PeriodType.month;
      default:
        return PeriodType.day;
    }
  }

  /// 计算时间范围
  (int startTime, int endTime) _getTimeRange() {
    final now = DateTime.now();
    final endTime = now.millisecondsSinceEpoch ~/ 1000;
    int startTime;

    switch (_currentPeriodType) {
      case PeriodType.day:
        startTime = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
        break;
      case PeriodType.week:
        startTime = endTime - 7 * 24 * 3600;
        break;
      case PeriodType.month:
        startTime = endTime - 30 * 24 * 3600;
        break;
    }

    return (startTime, endTime);
  }

  /// 加载所有数据
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseService();
      final (startTime, endTime) = _getTimeRange();

      // 并行加载所有数据
      await Future.wait([
        _loadHeartRateData(db, startTime, endTime),
        _loadSpo2Data(db, startTime, endTime),
        _loadStepsData(db, startTime, endTime),
        _loadDailyReport(db),
        _loadAbnormalEvents(db, startTime, endTime),
      ]);
    } catch (e) {
      debugPrint('加载数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 加载心率数据
  Future<void> _loadHeartRateData(DatabaseService db, int startTime, int endTime) async {
    List<Map<String, dynamic>> data;

    if (_currentPeriodType == PeriodType.day) {
      data = await db.getHourlyHeartRate(startTime: startTime, endTime: endTime);
    } else {
      data = await db.getDailyHeartRate(startTime: startTime, endTime: endTime);
    }

    if (data.isEmpty) {
      _heartRateData = const ChartData(spots: [], labels: [], subtitle: '暂无数据');
      return;
    }

    final spots = <FlSpot>[];
    final labels = <String>[];
    double sumHr = 0;
    int minHr = 999;
    int maxHr = 0;
    int validCount = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final avgHr = (item['avg_hr'] as num?)?.toDouble() ?? 0;
      final min = (item['min_hr'] as num?)?.toInt() ?? 0;
      final max = (item['max_hr'] as num?)?.toInt() ?? 0;

      if (avgHr > 0) {
        spots.add(FlSpot(i.toDouble(), avgHr));
        sumHr += avgHr;
        validCount++;
        if (min > 0 && min < minHr) minHr = min;
        if (max > maxHr) maxHr = max;
      }

      // 生成标签
      if (_currentPeriodType == PeriodType.day) {
        final hour = DateTime.fromMillisecondsSinceEpoch((item['hour'] as int) * 1000).hour;
        labels.add('${hour.toString().padLeft(2, '0')}:00');
      } else {
        final day = item['day'] as String;
        labels.add(day.substring(5)); // MM-DD
      }
    }

    final avgHr = validCount > 0 ? (sumHr / validCount).round() : 0;
    final subtitle = validCount > 0
        ? '平均 $avgHr  最低 ${minHr == 999 ? 0 : minHr}  最高 $maxHr'
        : '暂无数据';

    _heartRateData = ChartData(spots: spots, labels: labels, subtitle: subtitle);
  }

  /// 加载血氧数据
  Future<void> _loadSpo2Data(DatabaseService db, int startTime, int endTime) async {
    List<Map<String, dynamic>> data;

    if (_currentPeriodType == PeriodType.day) {
      data = await db.getHourlySpo2(startTime: startTime, endTime: endTime);
    } else {
      data = await db.getDailySpo2(startTime: startTime, endTime: endTime);
    }

    if (data.isEmpty) {
      _spo2Data = const ChartData(spots: [], labels: [], subtitle: '暂无数据');
      return;
    }

    final spots = <FlSpot>[];
    final labels = <String>[];
    double sumSpo2 = 0;
    int minSpo2 = 100;
    int validCount = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final avgSpo2 = (item['avg_spo2'] as num?)?.toDouble() ?? 0;
      final min = (item['min_spo2'] as num?)?.toInt() ?? 100;

      if (avgSpo2 >= 70) {
        spots.add(FlSpot(i.toDouble(), avgSpo2));
        sumSpo2 += avgSpo2;
        validCount++;
        if (min < minSpo2) minSpo2 = min;
      }

      // 生成标签
      if (_currentPeriodType == PeriodType.day) {
        final hour = DateTime.fromMillisecondsSinceEpoch((item['hour'] as int) * 1000).hour;
        labels.add('${hour.toString().padLeft(2, '0')}:00');
      } else {
        final day = item['day'] as String;
        labels.add(day.substring(5));
      }
    }

    final avgSpo2 = validCount > 0 ? (sumSpo2 / validCount).round() : 0;
    final subtitle = validCount > 0
        ? '平均 $avgSpo2  最低 ${minSpo2 == 100 ? 0 : minSpo2}'
        : '暂无数据';

    _spo2Data = ChartData(spots: spots, labels: labels, subtitle: subtitle);
  }

  /// 加载步数数据
  Future<void> _loadStepsData(DatabaseService db, int startTime, int endTime) async {
    List<Map<String, dynamic>> data;

    if (_currentPeriodType == PeriodType.day) {
      data = await db.getHourlySteps(startTime: startTime, endTime: endTime);
    } else {
      data = await db.getDailySteps(startTime: startTime, endTime: endTime);
    }

    if (data.isEmpty) {
      _stepsData = const ChartData(spots: [], labels: [], subtitle: '暂无数据');
      return;
    }

    final spots = <FlSpot>[];
    final labels = <String>[];
    int totalSteps = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      int steps;

      if (_currentPeriodType == PeriodType.day) {
        steps = (item['steps'] as num?)?.toInt() ?? 0;
      } else {
        steps = (item['steps'] as num?)?.toInt() ?? 0;
      }

      spots.add(FlSpot(i.toDouble(), steps.toDouble()));
      totalSteps += steps;

      // 生成标签
      if (_currentPeriodType == PeriodType.day) {
        final hour = DateTime.fromMillisecondsSinceEpoch((item['hour'] as int) * 1000).hour;
        labels.add(hour.toString().padLeft(2, '0'));
      } else {
        final day = item['day'] as String;
        labels.add(day.substring(5));
      }
    }

    final subtitle = '总计 ${totalSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} 步';

    _stepsData = ChartData(spots: spots, labels: labels, subtitle: subtitle);
  }

  /// 加载今日健康报告
  Future<void> _loadDailyReport(DatabaseService db) async {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 生成今日汇总数据
    await db.generateDailySummary(dateStr);
    final summary = await db.getLatestDailySummary();

    if (summary != null) {
      _dailyReport = {
        'avgHeartRate': summary.avgHeartRate.round(),
        'avgSpo2': summary.avgSpo2.round(),
        'totalSteps': summary.totalSteps,
        'exerciseMinutes': summary.exerciseMinutes,
        'fallCount': summary.fallCount,
        'minHeartRate': summary.minHeartRate,
      };
    } else {
      // 使用实时数据作为后备
      final healthState = ref.read(healthProvider);
      _dailyReport = {
        'avgHeartRate': healthState.heartRate,
        'avgSpo2': healthState.spo2,
        'totalSteps': healthState.steps,
        'exerciseMinutes': 0,
        'fallCount': 0,
        'minHeartRate': healthState.heartRate,
      };
    }
  }

  /// 加载异常事件
  Future<void> _loadAbnormalEvents(DatabaseService db, int startTime, int endTime) async {
    _abnormalEvents = await db.getAbnormalEvents(startTime: startTime, endTime: endTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('数据分析'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _loadData,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间段切换
            _buildSegmentedControl(),
            const SizedBox(height: 20),
            // 心率趋势图
            _buildHeartRateChart(),
            const SizedBox(height: 12),
            // 血氧趋势图
            _buildSpo2Chart(),
            const SizedBox(height: 12),
            // 步数统计图
            _buildStepsChart(),
            const SizedBox(height: 12),
            // 今日健康报告
            _buildDailyReport(),
            const SizedBox(height: 12),
            // 异常事件
            _buildAbnormalEvents(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建时间段切换控件
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final selected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedPeriod != index) {
                  setState(() {
                    _selectedPeriod = index;
                    // 清除缓存，重新加载
                    _heartRateData = null;
                    _spo2Data = null;
                    _stepsData = null;
                    _abnormalEvents = null;
                  });
                  _loadData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Text(
                  _periods[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 构建心率趋势图
  Widget _buildHeartRateChart() {
    final data = _heartRateData;

    if (data == null || data.spots.isEmpty) {
      return _buildEmptyChart('❤️ 心率趋势', '暂无数据');
    }

    return TrendChart(
      chartType: ChartType.line,
      spots: data.spots,
      labels: data.labels,
      title: '❤️ 心率趋势',
      subtitle: data.subtitle,
      lineColor: AppColors.heartRate,
      normalMin: 60,
      normalMax: 100,
      minY: 40,
      maxY: 140,
    );
  }

  /// 构建血氧趋势图
  Widget _buildSpo2Chart() {
    final data = _spo2Data;

    if (data == null || data.spots.isEmpty) {
      return _buildEmptyChart('🫁 血氧趋势', '暂无数据');
    }

    return TrendChart(
      chartType: ChartType.line,
      spots: data.spots,
      labels: data.labels,
      title: '🫁 血氧趋势',
      subtitle: data.subtitle,
      lineColor: AppColors.spo2,
      warningThreshold: 95,
      minY: 85,
      maxY: 100,
    );
  }

  /// 构建步数统计图
  Widget _buildStepsChart() {
    final data = _stepsData;

    if (data == null || data.spots.isEmpty) {
      return _buildEmptyChart('🏃 步数统计', '暂无数据');
    }

    // 计算Y轴最大值
    final maxSteps = data.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = ((maxSteps / 500).ceil() * 500).toDouble();

    return TrendChart(
      chartType: ChartType.bar,
      spots: data.spots,
      labels: data.labels,
      title: '🏃 步数统计',
      subtitle: data.subtitle,
      barColor: AppColors.steps,
      targetLine: 8000,
      minY: 0,
      maxY: maxY > 0 ? maxY : 1500,
    );
  }

  /// 构建空图表占位
  Widget _buildEmptyChart(String title, String subtitle) {
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: AppColors.secondaryText.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '暂无数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建今日健康报告
  Widget _buildDailyReport() {
    final report = _dailyReport;

    final items = [
      ('平均心率', '${report?['avgHeartRate'] ?? 0} bpm', AppColors.heartRate),
      ('平均血氧', '${report?['avgSpo2'] ?? 0}%', AppColors.spo2),
      ('总步数', '${report?['totalSteps'] ?? 0}', AppColors.steps),
      ('运动时长', '${report?['exerciseMinutes'] ?? 0}分钟', AppColors.safe),
      ('跌倒次数', '${report?['fallCount'] ?? 0} 次', AppColors.primaryText),
      ('最低心率', '${report?['minHeartRate'] ?? 0} bpm', AppColors.heartRate),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 今日健康报告', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    const SizedBox(height: 4),
                    Text(item.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: item.$3)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建异常事件列表
  Widget _buildAbnormalEvents() {
    final events = _abnormalEvents;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ 异常事件', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          const SizedBox(height: 12),
          if (events == null || events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('暂无异常事件', style: TextStyle(fontSize: 14, color: AppColors.secondaryText)),
              ),
            )
          else
            Column(
              children: events.take(10).map((event) {
                final timestamp = event['timestamp'] as int;
                final time = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
                final eventType = event['event_type'] as String;

                String title;
                String subtitle;
                Color color;
                IconData icon;

                switch (eventType) {
                  case 'fall':
                    title = '检测到跌倒';
                    subtitle = DateHelper.formatFullDateTime(time);
                    color = AppColors.alert;
                    icon = Icons.warning;
                    break;
                  case 'low_spo2':
                    final spo2 = event['spo2'] as int;
                    title = '血氧过低';
                    subtitle = '${DateHelper.formatTime(time)} - $spo2%';
                    color = AppColors.spo2;
                    icon = Icons.air;
                    break;
                  case 'high_hr':
                    final hr = event['heart_rate'] as int;
                    title = '心率过高';
                    subtitle = '${DateHelper.formatTime(time)} - $hr bpm';
                    color = AppColors.heartRate;
                    icon = Icons.favorite;
                    break;
                  case 'low_hr':
                    final hr = event['heart_rate'] as int;
                    title = '心率过低';
                    subtitle = '${DateHelper.formatTime(time)} - $hr bpm';
                    color = AppColors.heartRate;
                    icon = Icons.favorite_border;
                    break;
                  default:
                    title = '异常事件';
                    subtitle = DateHelper.formatTime(time);
                    color = AppColors.warning;
                    icon = Icons.error_outline;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
