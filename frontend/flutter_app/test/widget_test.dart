import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/app.dart';

void main() {
  testWidgets('AirthAI app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AirthAIApp());

    expect(find.text('AirthAI'), findsOneWidget);
  });
}
