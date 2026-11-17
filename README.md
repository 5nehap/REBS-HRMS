# REBS HRMS — Offline-Capable Employee Workspace

Flutter Developer Assignment implementing an offline-first Employee Workspace with MVC + Repository pattern, GetX state management, SQLite offline persistence, and Dio HTTP networking.

---

## Network & Physical Device Configuration

The application uses a centralized API configuration in `lib/app/core/config/app_config.dart`:

```dart
static const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);
```

### Running on Physical Android Device

On physical Android devices, `localhost` resolves to the phone itself rather than your development machine. To connect to your local Node.js mock API:

1. Connect your Android phone and PC to the same Wi-Fi/LAN network.
2. Find your PC's local IP address (`ipconfig` on Windows or `ifconfig` on macOS/Linux). For example: `192.168.29.112`.
3. Start the mock backend:
   ```bash
   cd mock_api
   node server.js
   ```
4. Run the Flutter app with `--dart-define`:
   ```bash
   flutter run --dart-define="API_BASE_URL=http://YOUR_PC_IP:3000/api/v1"
   ```
   Example:
   ```bash
   flutter run --dart-define="API_BASE_URL=http://192.168.29.112:3000/api/v1"
   ```

### Running on Android Emulator

Android emulators map the host machine loopback to `10.0.2.2`:

```bash
flutter run --dart-define="API_BASE_URL=http://10.0.2.2:3000/api/v1"
```

### Running on Windows / Desktop / Web

Desktop platforms can use the default localhost base URL directly:

```bash
flutter run
```

---

## Security & Cleartext Traffic

- `android/app/src/main/AndroidManifest.xml` enforces production network security.
- `android/app/src/debug/AndroidManifest.xml` enables `android:usesCleartextTraffic="true"` solely in debug builds to allow development against local HTTP mock APIs without weakening production security.

---

## Architecture Overview

```
View (GetView)
  └── Controller (GetxController)
        └── Business Logic (AttendanceLogic / LeaveLogic / SyncLogic)
              └── Repository (AttendanceRepository / LeaveRepository / EmployeeRepository)
                    ├── Remote Data Source (ApiProvider with Dio)
                    └── Local Data Source (LocalDatabase with SQLite)
```

- **Offline Attendance**: Attendance events are saved to local SQLite first (`PENDING`), immediately attempt synchronization when online, and automatically retry on reconnection or app resume.
- **Leave Management**: Online-only submission with dynamic balance checks, overlap prevention, calendar-day calculation in company timezone (`Asia/Kolkata`), and offline viewing of cached leave records.
