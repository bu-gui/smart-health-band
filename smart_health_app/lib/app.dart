import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_colors.dart';
import '../pages/device_page.dart';
import '../pages/monitor_page.dart';
import '../pages/analysis_page.dart';
import '../pages/settings_page.dart';

/// 应用主配置文件
/// 包含主题配置和底部导航栏
class SmartHealthApp extends ConsumerStatefulWidget {
  const SmartHealthApp({super.key});

  @override
  ConsumerState<SmartHealthApp> createState() => _SmartHealthAppState();
}

class _SmartHealthAppState extends ConsumerState<SmartHealthApp> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DevicePage(),
    MonitorPage(),
    AnalysisPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartHealth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.primaryText,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.primaryText),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.bluetooth, '设备', 0),
                  _buildNavItem(Icons.favorite_border, '监测', 1),
                  _buildNavItem(Icons.show_chart, '分析', 2),
                  _buildNavItem(Icons.settings_outlined, '设置', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部导航项
  Widget _buildNavItem(IconData icon, String label, int index) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: selected ? AppColors.primary : AppColors.secondaryText),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primary : AppColors.secondaryText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
