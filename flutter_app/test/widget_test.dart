import 'package:flutter_test/flutter_test.dart';
import 'package:edulink_app/main.dart';

void main() {
  testWidgets('EduLinkApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EduLinkApp());
    expect(find.byType(EduLinkApp), findsOneWidget);
  });
}
