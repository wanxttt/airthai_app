import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/routing/route_guards.dart';
import 'package:airthai/core/routing/route_names.dart';
import 'package:airthai/features/landing/presentation/screens/landing_screen.dart';
import 'package:airthai/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:airthai/features/legal/presentation/screens/terms_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Landing & Legal Compliance Tests', () {
    test('Public routes include home, privacy, and terms', () {
      expect(RouteGuards.isProtectedRoute(RouteNames.landing), isFalse);
      expect(RouteGuards.isProtectedRoute(RouteNames.privacy), isFalse);
      expect(RouteGuards.isProtectedRoute(RouteNames.terms), isFalse);
    });

    testWidgets('PrivacyPolicyScreen renders data protection sections and contact info', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('AirthAI Privacy Policy'), findsOneWidget);
      expect(find.text('1. Introduction & Overview'), findsOneWidget);
      expect(find.text('2. Information We Collect'), findsOneWidget);
      expect(find.text('4. AI Business Copilot & Model Privacy'), findsOneWidget);
      expect(find.text('6. Zero Third-Party Data Monetization'), findsOneWidget);
      expect(find.textContaining('privacy@airthai.in'), findsOneWidget);
    });

    testWidgets('TermsScreen renders statutory disclaimer, subscription quotas, and Indian jurisdiction', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: TermsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('IMPORTANT STATUTORY DISCLAIMER'), findsOneWidget);
      expect(find.textContaining('AirthAI is NOT a chartered accounting firm'), findsOneWidget);
      expect(find.text('5. Subscription Plans, Quotas & Fair Usage'), findsOneWidget);
      expect(find.text('9. Governing Law & Jurisdiction'), findsOneWidget);
      expect(find.textContaining('legal@airthai.in'), findsOneWidget);
    });

    testWidgets('LandingScreen renders hero, capabilities, pricing, and FAQ', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Brand & Navigation
      expect(find.text('AirthAI'), findsWidgets);
      expect(find.text('Capabilities'), findsOneWidget);
      expect(find.text('Accounting & GST'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);
      expect(find.text('FAQ'), findsOneWidget);

      // Hero Value Proposition
      expect(find.text('Run your business on accurate numbers, from invoice to tax return.'), findsOneWidget);
      expect(find.text('GST-COMPLIANT BILLING & DOUBLE-ENTRY LEDGER'), findsOneWidget);
      expect(find.text('Start Free Account'), findsOneWidget);

      // Hero Interactive Card
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);
      expect(find.text('Shree Ganesh Hardware'), findsOneWidget);
      expect(find.text('₹17,700.00'), findsOneWidget);
      expect(find.text('Ledger Vouchers Balanced'), findsOneWidget);

      // Pricing Cards
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('Enterprise'), findsOneWidget);

      // FAQ
      expect(find.text('How does offline billing work if my internet connection drops?'), findsOneWidget);
    });

    testWidgets('LandingScreen renders without overflow on 360px mobile width', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AirthAI'), findsWidgets);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);

      // Verify mobile drawer opening and closing
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Accounting & GST Returns'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);

      await tester.tap(find.text('Accounting & GST Returns'));
      await tester.pumpAndSettle();
      expect(find.text('Accounting & GST Returns'), findsNothing);
    });

    testWidgets('LandingScreen renders without overflow on 390px mobile width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AirthAI'), findsWidgets);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);
    });

    testWidgets('LandingScreen renders without overflow on 768px tablet width', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AirthAI'), findsWidgets);
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);
    });

    testWidgets('LandingScreen renders without overflow on 1024px desktop width', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AirthAI'), findsWidgets);
      expect(find.text('Capabilities'), findsOneWidget);
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);
    });

    testWidgets('LandingScreen renders without overflow on 1440px wide desktop width', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AirthAI'), findsWidgets);
      expect(find.text('Capabilities'), findsOneWidget);
      expect(find.text('Tax Invoice • INV-2026-27-0042'), findsOneWidget);
    });

    testWidgets('Legal screens render cleanly across 360px to 1440px viewports', (tester) async {
      for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: PrivacyPolicyScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Privacy Policy'), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            home: TermsScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Terms & Conditions'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
