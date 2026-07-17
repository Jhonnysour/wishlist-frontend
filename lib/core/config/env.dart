import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Resolves the backend base URL per platform.
///
/// Precedence:
///   1. `--dart-define=API_BASE_URL=...` (use this for a real phone on the LAN,
///      e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000`).
///   2. Android emulator -> `10.0.2.2` (the host machine's loopback alias).
///   3. Web / iOS simulator / desktop -> `localhost`.
class Env {
  const Env._();

  /// Optional compile-time override. Empty string when not provided.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// All endpoints live under the `/api/v1` prefix.
  static String get apiV1BaseUrl => '$apiBaseUrl/api/v1';
}
