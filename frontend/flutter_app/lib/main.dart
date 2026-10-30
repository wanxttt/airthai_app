import 'package:flutter/material.dart';
import 'app.dart';
import 'core/monitoring/crash_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.initialize();

  runApp(const AirthAIApp());
}
