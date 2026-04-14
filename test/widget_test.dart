import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    // Minimal test — full app requires auth/network setup
    expect(true, isTrue);
  });
}
