import 'dart:math';

/// Cryptographically secure, dependency-free RFC-4122 v4 UUID generator.
class UuidUtils {
  UuidUtils._();

  static final Random _random = Random.secure();

  /// Generates a standard lowercase RFC-4122 v4 UUID string.
  static String generate() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));

    // Set version to 4 (0100)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122 (10xx)
    values[8] = (values[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

