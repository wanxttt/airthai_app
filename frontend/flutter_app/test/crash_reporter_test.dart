import 'package:flutter_test/flutter_test.dart';
import 'package:airthai/core/monitoring/crash_reporter.dart';

void main() {
  group('CrashReporter Unit Tests', () {
    test('sanitizes password and bearer tokens from error strings', () {
      const raw = 'Unhandled error with password: Secret123 and Bearer abc.def.ghi';
      final clean = CrashReporter.sanitize(raw);

      expect(clean, contains('password=***'));
      expect(clean, contains('Bearer ***'));
      expect(clean, isNot(contains('Secret123')));
      expect(clean, isNot(contains('abc.def.ghi')));
    });

    test('sanitizes credit card numbers from error strings', () {
      const raw = 'Card transaction failed: 4111 2222 3333 4444 expired';
      final clean = CrashReporter.sanitize(raw);

      expect(clean, contains('****-****-****-****'));
      expect(clean, isNot(contains('4111')));
    });

    test('initialize registers error handlers without throwing', () {
      expect(() => CrashReporter.initialize(), returnsNormally);
      expect(() => CrashReporter.recordError(Exception('test'), null, reason: 'unit test'), returnsNormally);
    });
  });
}

