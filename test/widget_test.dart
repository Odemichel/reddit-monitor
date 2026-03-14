import 'package:flutter_test/flutter_test.dart';
import 'package:aerox_reddit_monitor/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const AeroXMonitorApp());
    expect(find.text('AeroX Reddit Monitor'), findsOneWidget);
  });
}
