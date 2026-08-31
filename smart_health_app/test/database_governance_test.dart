import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_health_app/services/database_service.dart';
import 'package:smart_health_app/models/health_record.dart';

void main() {
  // 初始化 sqflite_ffi 内存数据库
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;

  setUpAll(() {
    dbService = DatabaseService();
  });

  group('App 3 大数据治理单元测试集', () {
    test('【场景 3】运动时长 /60 换算准确性断言 (防 60 倍放大 BUG)', () async {
      const dateStr = '2026-09-01';
      final baseTs = DateTime.parse('2026-09-01 10:00:00').millisecondsSinceEpoch ~/ 1000;

      // 连续插入 150 条 motion_state = 1 的记录 (每 2 秒一条，共 300 秒 = 5 分钟)
      for (int i = 0; i < 150; i++) {
        await dbService.insertHealthRecord(HealthRecord(
          timestamp: baseTs + (i * 2),
          heartRate: 75,
          spo2: 98,
          steps: 100 + i,
          motionState: 1,
        ));
      }

      await dbService.generateDailySummary(dateStr);
      final summaries = await dbService.getDailySummaries(
        startTime: baseTs - 3600,
        endTime: baseTs + 86400,
      );

      expect(summaries, isNotEmpty);
      final summary = summaries.firstWhere((s) => s.date == dateStr);

      expect(summary.exerciseMinutes, equals(5),
          reason: '300 秒运动换算为分钟数必须精确等于 5 分钟 (验证 /60 换算已修复)');
      print('  [PASS] 场景 3 成功通过！150条记录(300秒) 准确换算 exerciseMinutes = ${summary.exerciseMinutes} 分钟');
    });

    test('【场景 4A】脱腕 0 值过滤断言 (防 MIN/AVG 被 0 拉低)', () async {
      const dateStr = '2026-09-02';
      final baseTs = DateTime.parse('2026-09-02 10:00:00').millisecondsSinceEpoch ~/ 1000;

      // 插入 5 条正常测量记录 (心率 70-78)
      for (int i = 0; i < 5; i++) {
        await dbService.insertHealthRecord(HealthRecord(
          timestamp: baseTs + (i * 2),
          heartRate: 70 + (i * 2), // 70, 72, 74, 76, 78 -> avg = 74
          spo2: 98,
        ));
      }

      // 插入 10 条脱腕 0 值记录 (heartRate = 0)
      for (int i = 0; i < 10; i++) {
        await dbService.insertHealthRecord(HealthRecord(
          timestamp: baseTs + 20 + (i * 2),
          heartRate: 0,
          spo2: 0,
        ));
      }

      await dbService.generateDailySummary(dateStr);
      final summaries = await dbService.getDailySummaries(
        startTime: baseTs - 3600,
        endTime: baseTs + 86400,
      );

      expect(summaries, isNotEmpty);
      final summary = summaries.firstWhere((s) => s.date == dateStr);

      expect(summary.minHeartRate, equals(70),
          reason: '每日最低心率必须过滤 0 值，准确等于测得的最小值 70');
      expect(summary.avgHeartRate, equals(74.0),
          reason: '每日平均心率必须过滤 0 值，平均为 (70+72+74+76+78)/5 = 74.0');

      print('  [PASS] 场景 4A 成功通过！脱腕 0 值被完全过滤，minHeartRate = ${summary.minHeartRate}, avgHeartRate = ${summary.avgHeartRate}');
    });

    test('【场景 4B】ts=0 未同步时间戳防御断言 (防 1970 垃圾记录与 90 天清理误删)', () async {
      // 插入未同步时间戳 (ts = 0，即 1970-01-01)
      await dbService.insertHealthRecord(HealthRecord(
        timestamp: 0,
        heartRate: 80,
        spo2: 99,
      ));

      final records = await dbService.getRecentRecords(1);
      expect(records, isNotEmpty);

      final savedTs = records.first.timestamp;
      expect(savedTs, greaterThanOrEqualTo(1600000000),
          reason: '未同步的 ts=0 记录插入时必须被自动校正为 2020 年之后的真实秒级时间戳');

      // 模拟执行 90 天数据清理
      await dbService.cleanOldRecords(daysToKeep: 90);

      final recordsAfterClean = await dbService.getRecentRecords(1);
      expect(recordsAfterClean, isNotEmpty,
          reason: '校正后的记录时间戳不属于 90 天前的旧垃圾，绝不会被 cleanOldRecords 误删');

      print('  [PASS] 场景 4B 成功通过！ts=0 被成功校正为时间戳 $savedTs，清理后记录完整保留。');
    });
  });
}
