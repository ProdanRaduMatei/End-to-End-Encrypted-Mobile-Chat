import 'dart:io';

class AppConfig {
  static String get baseUrl {
    // Android emulator uses special alias
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    // iOS simulator (and macOS desktop) can use localhost
    return "http://localhost:8000";
  }
}
