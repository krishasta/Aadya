import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_bluetooth_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SOLinkBleApp());
    expect(find.text('SOLink BLE Provisioning'), findsOneWidget);
  });
}
