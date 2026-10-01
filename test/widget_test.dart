import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_code_editor/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MobileIDEApp());

    // Verify the root widget mounts
    expect(find.byType(MobileIDEApp), findsOneWidget);
  });
}