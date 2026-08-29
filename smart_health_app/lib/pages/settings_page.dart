import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/ble_provider.dart';
import '../models/user_settings.dart';
import '../utils/app_colors.dart';
import '../services/database_service.dart';

/// 设置页（Tab 4）
/// - 个人信息（年龄、性别、身高、体重）
/// - 步数目标设置
/// - 心率告警设置
/// - 血氧告警设置
/// - 跌倒告警设置
/// - 数据管理（清除历史数据、导出CSV）
/// - 关于
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isExporting = false;
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bleState = ref.watch(bleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置'),
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
            // 个人信息
            _buildSectionTitle('个人信息'),
            _buildSettingsCard([
              _buildSettingRow('年龄', '${settings.age} 岁', () => _showAgePicker(settings)),
              _buildDivider(),
              _buildSettingRow('性别', settings.gender == 'male' ? '男' : '女', () => _showGenderPicker(settings)),
              _buildDivider(),
              _buildSettingRow('身高', '${settings.height.toInt()} cm', () => _showHeightPicker(settings)),
              _buildDivider(),
              _buildSettingRow('体重', '${settings.weight.toInt()} kg', () => _showWeightPicker(settings)),
            ]),
            const SizedBox(height: 24),

            // 运动目标
            _buildSectionTitle('运动目标'),
            _buildSettingsCard([
              _buildSettingRow('每日步数目标', '${settings.dailyStepGoal} 步', () => _showStepGoalPicker(settings)),
            ]),
            const SizedBox(height: 24),

            // 告警设置
            _buildSectionTitle('告警设置'),
            _buildSettingsCard([
              _buildSettingRow('心率上限', '${settings.heartRateUpperLimit} bpm', () => _showHrUpperPicker(settings)),
              _buildDivider(),
              _buildSettingRow('心率下限', '${settings.heartRateLowerLimit} bpm', () => _showHrLowerPicker(settings)),
              _buildDivider(),
              _buildSettingRow('血氧下限', '${settings.spo2LowerLimit}%', () => _showSpo2LowerPicker(settings)),
              _buildDivider(),
              _buildSwitchRow('跌倒告警', settings.fallAlertEnabled, (val) {
                ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(fallAlertEnabled: val));
              }),
            ]),
            const SizedBox(height: 24),

            // 数据管理
            _buildSectionTitle('数据管理'),
            _buildSettingsCard([
              _buildActionRow(
                '清除30天前数据',
                _isClearing ? '处理中...' : '',
                () => _showClearDataConfirm(),
                icon: Icons.delete_outline,
                color: AppColors.alert,
              ),
              _buildDivider(),
              _buildActionRow(
                '导出 CSV',
                _isExporting ? '导出中...' : '',
                () => _exportCSV(),
                icon: Icons.file_download_outlined,
                color: AppColors.primary,
              ),
            ]),
            const SizedBox(height: 24),

            // 关于
            _buildSectionTitle('关于'),
            _buildSettingsCard([
              _buildInfoRow('App 版本', '1.0.0'),
              _buildDivider(),
              _buildInfoRow('设备固件', bleState.deviceInfo.firmwareVersion.isNotEmpty 
                  ? bleState.deviceInfo.firmwareVersion 
                  : '--'),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
    );
  }

  /// 构建设置卡片容器
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  /// 构建可点击的设置行
  Widget _buildSettingRow(String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, color: AppColors.primaryText)),
            Row(
              children: [
                if (value.isNotEmpty)
                  Text(value, style: const TextStyle(fontSize: 15, color: AppColors.secondaryText)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.secondaryText, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建带图标的操作行
  Widget _buildActionRow(String title, String status, VoidCallback onTap, {
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: status.isNotEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, color: AppColors.primaryText)),
              ],
            ),
            if (status.isNotEmpty)
              Text(status, style: const TextStyle(fontSize: 14, color: AppColors.secondaryText))
            else
              const Icon(Icons.chevron_right, color: AppColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }

  /// 构建开关设置行
  Widget _buildSwitchRow(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: AppColors.primaryText)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// 构建只读信息行
  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: AppColors.primaryText)),
          Text(value, style: const TextStyle(fontSize: 15, color: AppColors.secondaryText)),
        ],
      ),
    );
  }

  /// 构建分割线
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 0.5, color: AppColors.divider),
    );
  }

  // ===== Picker 方法 =====

  /// 显示年龄选择器
  void _showAgePicker(UserSettings settings) {
    _showNumberPicker('年龄', 1, 120, settings.age, (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(age: val));
    });
  }

  /// 显示身高选择器
  void _showHeightPicker(UserSettings settings) {
    _showNumberPicker('身高 (cm)', 100, 220, settings.height.toInt(), (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(height: val.toDouble()));
    });
  }

  /// 显示体重选择器
  void _showWeightPicker(UserSettings settings) {
    _showNumberPicker('体重 (kg)', 30, 200, settings.weight.toInt(), (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(weight: val.toDouble()));
    });
  }

  /// 显示步数目标选择器
  void _showStepGoalPicker(UserSettings settings) {
    _showNumberPicker('每日步数目标', 1000, 30000, settings.dailyStepGoal, (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(dailyStepGoal: val));
    }, step: 500);
  }

  /// 显示心率上限选择器
  void _showHrUpperPicker(UserSettings settings) {
    _showNumberPicker('心率上限 (bpm)', 80, 200, settings.heartRateUpperLimit, (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(heartRateUpperLimit: val));
    });
  }

  /// 显示心率下限选择器
  void _showHrLowerPicker(UserSettings settings) {
    _showNumberPicker('心率下限 (bpm)', 30, 80, settings.heartRateLowerLimit, (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(heartRateLowerLimit: val));
    });
  }

  /// 显示血氧下限选择器
  void _showSpo2LowerPicker(UserSettings settings) {
    _showNumberPicker('血氧下限 (%)', 85, 98, settings.spo2LowerLimit, (val) {
      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(spo2LowerLimit: val));
    });
  }

  /// 通用数字选择器（底部弹出）
  void _showNumberPicker(String title, int min, int max, int current, Function(int) onConfirm, {int step = 1}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        int temp = current;
        return Container(
          padding: const EdgeInsets.all(20),
          height: 320,
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
              const SizedBox(height: 16),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  diameterRatio: 2.0,
                  onSelectedItemChanged: (index) {
                    temp = min + index * step;
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: (max - min) ~/ step + 1,
                    builder: (context, index) {
                      final value = min + index * step;
                      final selected = value == current;
                      return Center(
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontSize: selected ? 28 : 20,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? AppColors.primary : AppColors.secondaryText,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onConfirm(temp);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('确认', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示性别选择器
  void _showGenderPicker(UserSettings settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('男', textAlign: TextAlign.center),
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(gender: 'male'));
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0.5),
              ListTile(
                title: const Text('女', textAlign: TextAlign.center),
                onTap: () {
                  ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(gender: 'female'));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 显示清除数据确认对话框
  void _showClearDataConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认清除'),
        content: const Text('确定要清除30天前的历史数据吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearOldData();
            },
            child: const Text('确认', style: TextStyle(color: AppColors.alert)),
          ),
        ],
      ),
    );
  }

  /// 清除30天前的历史数据
  Future<void> _clearOldData() async {
    setState(() => _isClearing = true);

    try {
      final db = DatabaseService();
      await db.clearRecordsBeforeDays(30);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('30天前的历史数据已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  /// 导出 CSV 文件
  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);

    try {
      // 1. 从数据库获取数据
      final db = DatabaseService();
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final endTime = now;

      final records = await db.getHealthRecords(
        startTime: startTime.millisecondsSinceEpoch ~/ 1000,
        endTime: endTime.millisecondsSinceEpoch ~/ 1000,
      );

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无数据可导出')),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      // 2. 生成 CSV 内容
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('时间,心率(bpm),血氧(%),步数,运动状态,跌倒告警,信号质量,电量(%)');

      for (final record in records) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(record.timestamp * 1000);
        final formattedTime = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

        csvBuffer.writeln(
          '$formattedTime,'
          '${record.heartRate},'
          '${record.spo2},'
          '${record.steps},'
          '${record.motionText},'
          '${record.isFallAlert ? '是' : '否'},'
          '${record.signalQuality},'
          '${record.battery}',
        );
      }

      // 3. 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final fileName = 'health_data_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}.csv';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvBuffer.toString(), encoding: utf8);

      // 4. 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '健康数据导出',
        text: 'SmartHealth 健康数据导出 (${records.length} 条记录)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出 ${records.length} 条记录')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
