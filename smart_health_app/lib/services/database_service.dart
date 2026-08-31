import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/health_record.dart';
import '../models/daily_summary.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_health.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE health_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        heart_rate INTEGER DEFAULT 0,
        spo2 INTEGER DEFAULT 0,
        steps INTEGER DEFAULT 0,
        motion_state INTEGER DEFAULT 0,
        is_fall_alert INTEGER DEFAULT 0,
        signal_quality INTEGER DEFAULT 0,
        battery INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_summaries (
        date TEXT PRIMARY KEY,
        avg_heart_rate REAL DEFAULT 0,
        min_heart_rate INTEGER DEFAULT 0,
        max_heart_rate INTEGER DEFAULT 0,
        avg_spo2 REAL DEFAULT 0,
        min_spo2 INTEGER DEFAULT 0,
        total_steps INTEGER DEFAULT 0,
        exercise_minutes INTEGER DEFAULT 0,
        fall_count INTEGER DEFAULT 0,
        low_spo2_count INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_health_records_timestamp ON health_records(timestamp)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_records_timestamp ON health_records(timestamp)');
    }
  }

  // ===== 健康记录 CRUD =====

  Future<int> insertHealthRecord(HealthRecord record) async {
    final db = await database;
    var finalRecord = record;
    // 防御：当手环未同步时间（ts < 2020年戳）时，使用手机本地真实时间戳，防止 1970 年记录污染数据库并被 90 天清理误删
    if (finalRecord.timestamp < 1600000000) {
      finalRecord = HealthRecord(
        id: record.id,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        heartRate: record.heartRate,
        spo2: record.spo2,
        steps: record.steps,
        motionState: record.motionState,
        isFallAlert: record.isFallAlert,
        signalQuality: record.signalQuality,
        battery: record.battery,
      );
    }
    return db.insert('health_records', finalRecord.toMap());
  }

  Future<List<HealthRecord>> getHealthRecords({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startTime, endTime],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  Future<List<HealthRecord>> getRecentRecords(int limit) async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  Future<HealthRecord?> getLatestRecord() async {
    final db = await database;
    final maps = await db.query(
      'health_records',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HealthRecord.fromMap(maps.first);
  }

  // 按小时聚合的心率数据（用于图表）
  Future<List<Map<String, dynamic>>> getHourlyHeartRate({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        (timestamp / 3600) * 3600 as hour,
        AVG(heart_rate) as avg_hr,
        MIN(heart_rate) as min_hr,
        MAX(heart_rate) as max_hr
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ? AND heart_rate > 0
      GROUP BY hour
      ORDER BY hour ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 按天聚合的心率数据
  Future<List<Map<String, dynamic>>> getDailyHeartRate({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        date(timestamp, 'unixepoch', 'localtime') as day,
        AVG(heart_rate) as avg_hr,
        MIN(heart_rate) as min_hr,
        MAX(heart_rate) as max_hr
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ? AND heart_rate > 0
      GROUP BY day
      ORDER BY day ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 按小时聚合的血氧数据
  Future<List<Map<String, dynamic>>> getHourlySpo2({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        (timestamp / 3600) * 3600 as hour,
        AVG(spo2) as avg_spo2,
        MIN(spo2) as min_spo2
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ? AND spo2 >= 70
      GROUP BY hour
      ORDER BY hour ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 按天聚合的血氧数据
  Future<List<Map<String, dynamic>>> getDailySpo2({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        date(timestamp, 'unixepoch', 'localtime') as day,
        AVG(spo2) as avg_spo2,
        MIN(spo2) as min_spo2
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ? AND spo2 >= 70
      GROUP BY day
      ORDER BY day ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 按小时聚合的步数数据
  Future<List<Map<String, dynamic>>> getHourlySteps({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        (timestamp / 3600) * 3600 as hour,
        MAX(steps) - MIN(steps) as steps
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ?
      GROUP BY hour
      ORDER BY hour ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 按天聚合的步数数据
  Future<List<Map<String, dynamic>>> getDailySteps({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        date(timestamp, 'unixepoch', 'localtime') as day,
        MAX(steps) as steps
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ?
      GROUP BY day
      ORDER BY day ASC
    ''', [startTime, endTime]);
    return maps;
  }

  // 异常事件记录
  Future<List<Map<String, dynamic>>> getAbnormalEvents({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT timestamp, heart_rate, spo2, is_fall_alert,
        CASE
          WHEN is_fall_alert = 1 THEN 'fall'
          WHEN spo2 > 0 AND spo2 < 90 THEN 'low_spo2'
          WHEN heart_rate > 120 THEN 'high_hr'
          WHEN heart_rate > 0 AND heart_rate < 50 THEN 'low_hr'
        END as event_type
      FROM health_records
      WHERE timestamp >= ? AND timestamp < ?
        AND (is_fall_alert = 1 OR (spo2 > 0 AND spo2 < 90) OR heart_rate > 120 OR (heart_rate > 0 AND heart_rate < 50))
      ORDER BY timestamp DESC
    ''', [startTime, endTime]);
    return maps;
  }

  // ===== 每日汇总 =====

  Future<void> generateDailySummary(String date) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        AVG(CASE WHEN heart_rate > 0 THEN heart_rate END) as avg_hr,
        MIN(CASE WHEN heart_rate > 0 THEN heart_rate END) as min_hr,
        MAX(CASE WHEN heart_rate > 0 THEN heart_rate END) as max_hr,
        AVG(CASE WHEN spo2 >= 70 THEN spo2 END) as avg_spo2,
        MIN(CASE WHEN spo2 >= 70 THEN spo2 END) as min_spo2,
        MAX(steps) as total_steps,
        CAST(SUM(CASE WHEN motion_state >= 1 THEN 1 ELSE 0 END) * 2 / 60 AS INTEGER) as exercise_minutes,
        SUM(CASE WHEN is_fall_alert = 1 THEN 1 ELSE 0 END) as fall_count,
        SUM(CASE WHEN spo2 > 0 AND spo2 < 95 THEN 1 ELSE 0 END) as low_spo2_count
      FROM health_records
      WHERE date(timestamp, 'unixepoch', 'localtime') = ?
    ''', [date]);

    if (maps.isNotEmpty) {
      final m = maps.first;
      final summary = DailySummary(
        date: date,
        avgHeartRate: (m['avg_hr'] as num?)?.toDouble() ?? 0,
        minHeartRate: (m['min_hr'] as num?)?.toInt() ?? 0,
        maxHeartRate: (m['max_hr'] as num?)?.toInt() ?? 0,
        avgSpo2: (m['avg_spo2'] as num?)?.toDouble() ?? 0,
        minSpo2: (m['min_spo2'] as num?)?.toInt() ?? 0,
        totalSteps: (m['total_steps'] as num?)?.toInt() ?? 0,
        exerciseMinutes: (m['exercise_minutes'] as num?)?.toInt() ?? 0,
        fallCount: (m['fall_count'] as num?)?.toInt() ?? 0,
        lowSpo2Count: (m['low_spo2_count'] as num?)?.toInt() ?? 0,
      );
      await db.insert(
        'daily_summaries',
        summary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<DailySummary>> getDailySummaries({
    required int startTime,
    required int endTime,
  }) async {
    final db = await database;
    final startDate = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTime * 1000);
    final maps = await db.query(
      'daily_summaries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      ],
      orderBy: 'date DESC',
    );
    return maps.map((m) => DailySummary.fromMap(m)).toList();
  }

  Future<DailySummary?> getLatestDailySummary() async {
    final db = await database;
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'daily_summaries',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    if (maps.isEmpty) return null;
    return DailySummary.fromMap(maps.first);
  }

  // ===== 用户设置 =====

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  // ===== 数据清理 =====

  Future<void> cleanOldRecords({int daysToKeep = 90}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffTimestamp = cutoff.millisecondsSinceEpoch ~/ 1000;
    await db.delete(
      'health_records',
      where: 'timestamp < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  Future<int> getDatabaseSize() async {
    final db = await database;
    // 简单估算：记录数量
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM health_records')) ?? 0;
    return count * 100; // 粗略估算字节数
  }

  Future<void> clearRecordsBeforeDays(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffTimestamp = cutoff.millisecondsSinceEpoch ~/ 1000;
    await db.delete(
      'health_records',
      where: 'timestamp < ?',
      whereArgs: [cutoffTimestamp],
    );
  }
}
