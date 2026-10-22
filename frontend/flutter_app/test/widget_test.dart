import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/app.dart';

void main() {
  testWidgets('AirthAI app loads and shows splash brand', (WidgetTester tester) async {
    // Set standard mobile screen dimensions
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AirthAIApp());

    // Expect splash screen title
    expect(find.text('AirthAI'), findsWidgets);

    // Pump past the 2-second splash timer and finish animations
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
