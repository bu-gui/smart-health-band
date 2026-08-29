import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_health_app/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartHealthApp()));
    await tester.pump(const Duration(seconds: 1));

    // Verify that the bottom navigation bar is present
    // "设备" appears in both DevicePage AppBar title and bottom nav item
    expect(find.text('设备'), findsNWidgets(2));
    expect(find.text('监测'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
