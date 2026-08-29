import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ble_provider.dart';
import '../providers/health_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/connection_bar.dart';
import '../widgets/heart_rate_card.dart';
import '../widgets/spo2_card.dart';
import '../widgets/steps_card.dart';
import '../widgets/motion_status_card.dart';
import '../widgets/fall_alert_dialog.dart';

/// 实时监测页（Tab 2）
/// - 顶部连接状态栏
/// - 心率+血氧双列卡片
/// - 步数全宽卡片（环形进度条）
/// - 运动状态+信号质量双列小卡片
/// - 跌倒告警弹窗监听
class MonitorPage extends ConsumerStatefulWidget {
  const MonitorPage({super.key});

  @override
  ConsumerState<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends ConsumerState<MonitorPage> {
  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final healthState = ref.watch(healthProvider);
    final settings = ref.watch(settingsProvider);

    // 监听跌倒告警
    if (healthState.showFallAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FallAlertDialog.show(
          context: context,
          heartRate: healthState.heartRate,
          time: healthState.lastUpdateTime ?? DateTime.now(),
          onDismiss: () => ref.read(healthProvider.notifier).dismissFallAlert(),
          onEmergency: () {
            ref.read(healthProvider.notifier).dismissFallAlert();
            _handleEmergency();
          },
        );
      });
    }

    final isConnected = bleState.connectionState == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 连接状态栏
            ConnectionBar(
              deviceName: bleState.connectedDevice?.platformName ?? 'SmartHealthBand',
              battery: healthState.battery,
              isConnected: isConnected,
              isConnecting: bleState.connectionState == BleConnectionState.connecting,
            ),
            // 页面标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '实时监测',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                ),
              ),
            ),
            // 内容区域
            Expanded(
              child: isConnected
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 心率 + 血氧 双列
                          Row(
                            children: [
                              Expanded(
                                child: HeartRateCard(
                                  heartRate: healthState.heartRate,
                                  isValid: healthState.heartRate > 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Spo2Card(
                                  spo2: healthState.spo2,
                                  isValid: healthState.spo2 >= 70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 步数卡片
                          StepsCard(
                            steps: healthState.steps,
                            goal: settings.dailyStepGoal,
                          ),
                          const SizedBox(height: 12),
                          // 运动状态 + 信号质量
                          MotionStatusCard(
                            motionState: healthState.motionState,
                            signalQuality: healthState.signalQuality,
                          ),
                          const SizedBox(height: 24),
                          // 紧急求助按钮
                          _buildEmergencyButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 64, color: AppColors.secondaryText.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('设备未连接', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                          const SizedBox(height: 8),
                          const Text('请先在设备页连接手环', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建紧急求助按钮
  Widget _buildEmergencyButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleEmergency,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.alert.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: AppColors.alert,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '紧急求助',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.alert,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击拨打紧急联系人电话',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.phone,
                  color: AppColors.alert,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 处理紧急求助
  void _handleEmergency() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '紧急求助',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.alert,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '选择要拨打的紧急联系电话',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              // 120 急救电话
              _buildEmergencyOption(
                icon: Icons.local_hospital,
                title: '120 急救中心',
                subtitle: '医疗急救服务',
                color: AppColors.alert,
                onTap: () => _makePhoneCall('120'),
              ),
              const SizedBox(height: 12),
              // 110 报警电话
              _buildEmergencyOption(
                icon: Icons.local_police,
                title: '110 报警服务',
                subtitle: '公安报警服务',
                color: const Color(0xFF1E88E5),
                onTap: () => _makePhoneCall('110'),
              ),
              const SizedBox(height: 12),
              // 119 火警电话
              _buildEmergencyOption(
                icon: Icons.fire_truck,
                title: '119 火警电话',
                subtitle: '消防救援服务',
                color: const Color(0xFFFF6D00),
                onTap: () => _makePhoneCall('119'),
              ),
              const SizedBox(height: 12),
              // 紧急联系人（示例）
              _buildEmergencyOption(
                icon: Icons.contact_phone,
                title: '紧急联系人',
                subtitle: '点击设置紧急联系人',
                color: AppColors.primary,
                onTap: () => _showSetEmergencyContactDialog(),
              ),
              const SizedBox(height: 12),
              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建紧急选项
  Widget _buildEmergencyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.phone, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 拨打电话
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法拨打电话: $phoneNumber')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拨打电话失败: $e')),
        );
      }
    }
  }

  /// 显示设置紧急联系人对话框
  void _showSetEmergencyContactDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('设置紧急联系人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入紧急联系人电话号码',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '请输入电话号码',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = textController.text.trim();
              if (phone.isNotEmpty) {
                Navigator.pop(context);
                _makePhoneCall(phone);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('拨打'),
          ),
        ],
      ),
    );
  }
}
