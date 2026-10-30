import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/copilot_service.dart';
import 'package:airthai/features/copilot/presentation/widgets/copilot_dialog.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Read-Only AI Business Copilot Tests', () {
    setUp(() {
      SessionManager.instance.setAuthMode(AuthMode.devMock);
    });

    tearDown(() {
      SessionManager.instance.setAuthMode(AuthMode.restBackend);
    });
    test('CopilotService retrieves status and availability', () async {
      final res = await CopilotService.instance.getStatus();
      expect(res.success, isTrue);
      expect(res.data!['isAvailable'], isTrue);
      expect(res.data!['mode'], equals('READ_ONLY'));
    });

    test('CopilotService retrieves canonical suggestion questions', () async {
      final res = await CopilotService.instance.getSuggestions();
      expect(res.success, isTrue);
      expect(res.data, isNotEmpty);
      expect(res.data!.length, greaterThanOrEqualTo(6));

      final questions = res.data!.map((s) => s.question).toList();
      expect(questions, contains('How much did my business sell during a selected period?'));
      expect(questions, contains('Which customers have outstanding payments?'));
      expect(questions, contains('Which products are low in stock?'));
      expect(questions, contains('What were the major recorded expenses?'));
      expect(questions, contains("How do this month's sales compare with the previous month?"));
      expect(questions, contains('What business issues should I review based on available records?'));
    });

    test('CopilotService answers sales inquiry with deterministic figures', () async {
      final res = await CopilotService.instance.query('How much did my business sell during a selected period?');
      expect(res.success, isTrue);
      final data = res.data!;
      expect(data.answer, contains('total sales reached'));
      expect(data.dataUsed, isNotEmpty);
      expect(data.calculationDefinition, isNotNull);
      expect(data.caveats, isNotEmpty);
      expect(data.recommendedNextStep, isNotEmpty);
      expect(data.deterministicFigures?['totalSales'], equals(142500.0));
    });

    test('CopilotService answers outstanding receivables question', () async {
      final res = await CopilotService.instance.query('Which customers have outstanding payments?');
      expect(res.success, isTrue);
      final data = res.data!;
      expect(data.answer, contains('outstanding balance'));
      expect(data.deterministicFigures?['totalReceivables'], equals(17700.0));
    });

    test('CopilotService answers low-stock inventory question', () async {
      final res = await CopilotService.instance.query('Which products are low in stock?');
      expect(res.success, isTrue);
      final data = res.data!;
      expect(data.answer, contains('reorder threshold'));
      expect(data.deterministicFigures?['lowStockCount'], equals(1));
    });

    test('CopilotService strictly blocks write/mutation requests', () async {
      final res = await CopilotService.instance.query('Create invoice for 5000 for customer ABC');
      expect(res.success, isTrue);
      final data = res.data!;
      expect(data.answer, contains('strictly read-only'));
      expect(data.answer, contains('cannot create records'));
      expect(data.recommendedNextStep, contains('Navigate to the relevant section'));
    });

    testWidgets('CopilotDialog renders canonical questions and displays structured response', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CopilotDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('AI Business Copilot'), findsOneWidget);
      expect(find.text('READ-ONLY'), findsOneWidget);

      // Verify suggestions exist
      expect(find.text('Quick Insights'), findsOneWidget);
      final sugChip = find.text('Which products are low in stock?');
      expect(sugChip, findsOneWidget);

      // Tap suggestion chip
      await tester.tap(sugChip);
      await tester.pumpAndSettle();

      // Verify structured response is displayed
      expect(find.text('Source-Grounded'), findsOneWidget);
      expect(find.textContaining('reorder threshold'), findsOneWidget);
      expect(find.text('Data Sources Used:'), findsOneWidget);
      expect(find.text('Caveats & Scope:'), findsOneWidget);
      expect(find.textContaining('Recommended Next Step:'), findsOneWidget);
    });

    testWidgets('AppShell top bar includes Copilot button and opens CopilotDialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(),
        ),
      );
      await tester.pumpAndSettle();

      // Find copilot button
      final copilotFinder = find.byIcon(Icons.auto_awesome_rounded);
      expect(copilotFinder, findsOneWidget);

      // Tap copilot button
      await tester.tap(copilotFinder);
      await tester.pumpAndSettle();

      // Verify CopilotDialog opens
      expect(find.text('AI Business Copilot'), findsOneWidget);
      expect(find.text('READ-ONLY'), findsOneWidget);

      // Close dialog
      final closeFinder = find.byIcon(Icons.close_rounded);
      expect(closeFinder, findsOneWidget);
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('AI Business Copilot'), findsNothing);
    });
  });
}

