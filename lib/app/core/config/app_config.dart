class AppConfig {
  AppConfig._();

  static const String appName = 'REBS HRMS';
  static const String appVersion = '1.0.0';

  // Base API configuration (configurable per environment)
  // - Localhost for desktop/browser: 'http://localhost:3000/api/v1'
  // - Android emulator: 'http://10.0.2.2:3000/api/v1'
  // - Physical device on LAN: 'http://<YOUR_PC_IP>:3000/api/v1'
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 10000;

  // Local Database configuration
  static const String databaseName = 'rebs_hrms.db';
  static const int databaseVersion = 1;
}
