import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static final _dateFormatter = DateFormat('yyyy-MM-dd');
  static final _timeFormatter = DateFormat('HH:mm');
  static final _dateTimeFormatter = DateFormat('MM/dd HH:mm');
  static final _fullDateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _weekdayFormatter = DateFormat('E', 'zh_CN');

  static String formatDate(DateTime dt) => _dateFormatter.format(dt);
  static String formatTime(DateTime dt) => _timeFormatter.format(dt);
  static String formatDateTime(DateTime dt) => _dateTimeFormatter.format(dt);
  static String formatFullDateTime(DateTime dt) => _fullDateTimeFormatter.format(dt);
  static String formatWeekday(DateTime dt) => _weekdayFormatter.format(dt);

  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '今天 ${formatTime(dt)}';
    } else if (diff.inDays == 1) {
      return '昨天 ${formatTime(dt)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formatDate(dt);
    }
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$h小时$m分钟' : '$h小时';
  }

  static DateTime get todayStart => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  static DateTime get todayEnd => todayStart.add(const Duration(days: 1));

  static DateTime daysAgo(int days) => todayStart.subtract(Duration(days: days));
}
