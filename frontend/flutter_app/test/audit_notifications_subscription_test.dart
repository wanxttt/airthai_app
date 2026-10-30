import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/audit_service.dart';
import 'package:airthai/core/services/notification_service.dart';
import 'package:airthai/core/services/subscription_service.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audit, Notifications & Subscription Foundation Tests', () {
    setUp(() {
      SessionManager.instance.setAuthMode(AuthMode.devMock);
      NotificationService.instance.resetMockData();
      SubscriptionService.instance.resetMockData();
    });

    tearDown(() {
      SessionManager.instance.setAuthMode(AuthMode.restBackend);
    });
    test('NotificationService retrieves alerts and calculates unread count', () async {
      final service = NotificationService.instance;
      final res = await service.getNotifications();

      expect(res.success, isTrue);
      expect(res.data, isNotEmpty);
      expect(service.unreadCountNotifier.value, greaterThan(0));

      final firstUnread = res.data!.firstWhere((n) => !n.isRead);
      final markRes = await service.markAsRead(firstUnread.id);

      expect(markRes.success, isTrue);
      expect(markRes.data!.isRead, isTrue);
    });

    test('NotificationService markAllAsRead sets all alerts to read status', () async {
      final service = NotificationService.instance;
      final markAllRes = await service.markAllAsRead();

      expect(markAllRes.success, isTrue);
      expect(service.unreadCountNotifier.value, equals(0));

      final unreadListRes = await service.getNotifications(isRead: false);
      expect(unreadListRes.data, isEmpty);
    });

    test('SubscriptionService returns active plan, usage counters, and remaining days', () async {
      final service = SubscriptionService.instance;
      final res = await service.getCurrentSubscription();

      expect(res.success, isTrue);
      final sub = res.data!;
      expect(sub.status, equals('ACTIVE'));
      expect(sub.daysRemaining, greaterThan(0));
      expect(sub.plan.name, contains('Starter'));
      expect(sub.usage.maxInvoicesMonthly, equals(50));
      expect(sub.usage.currentUsers, equals(1));
    });

    test('SubscriptionService lists available plans and switches plan', () async {
      final service = SubscriptionService.instance;
      final plansRes = await service.getPlans();

      expect(plansRes.success, isTrue);
      expect(plansRes.data!.length, greaterThanOrEqualTo(3));

      // Switch to Professional plan
      final changeRes = await service.changePlan('plan_professional_dev');
      expect(changeRes.success, isTrue);

      final updatedSub = await service.getCurrentSubscription();
      expect(updatedSub.data!.plan.name, equals('Professional'));
      expect(updatedSub.data!.usage.maxUsers, equals(5));
      expect(updatedSub.data!.usage.maxInvoicesMonthly, equals(500));
    });

    test('AuditService retrieves audit records with action and entity information', () async {
      final service = AuditService.instance;
      final res = await service.getAuditLogs();

      expect(res.success, isTrue);
      expect(res.data, isNotEmpty);

      final log = res.data!.first;
      expect(log.action, isNotEmpty);
      expect(log.entityName, isNotEmpty);
      expect(log.userName, isNotNull);
      expect(log.timestamp, isNotNull);
    });

    testWidgets('AppShell notification bell shows badge and opens notifications dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      NotificationService.instance.unreadCountNotifier.value = 3;

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(),
        ),
      );
      await tester.pump();

      // Find the notification button (bell icon)
      final bellFinder = find.byIcon(Icons.notifications_none_rounded);
      expect(bellFinder, findsOneWidget);

      // Tap notification bell
      await tester.tap(bellFinder);
      await tester.pumpAndSettle();

      // Notifications dialog opens
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      // Tap Mark all read
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      // Dialog dismisses and unread count is cleared
      expect(NotificationService.instance.unreadCountNotifier.value, equals(0));
    });
  });
}

