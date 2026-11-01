class AppConfig {
  AppConfig._();

  static const String appName = 'CampusOS';
  static const String appVersion = '1.0.1';

  /// Backend API Base URL
  /// Deployed production backend (PythonAnywhere)
  /// Preserves environment variable override via `--dart-define=API_BASE_URL=...`
  static const String _defaultUrl = 'https://campusos.pythonanywhere.com';
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _defaultUrl);

  /// Default API Network Timeout
  static const Duration apiTimeout = Duration(seconds: 15);
}
