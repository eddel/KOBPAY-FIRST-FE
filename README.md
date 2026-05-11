# KOBPAY Mobile

Flutter client for KOBPAY.

## Quick start
```powershell
flutter pub get
flutter run
```

## API base URL
Configured in `lib/core/config/app_config.dart`:
- Android emulator: update `_androidEmulatorBaseUrl`
- iOS simulator: update `_iosSimulatorBaseUrl`
- Physical device: update `_deviceBaseUrl`

You can also override at runtime:
```powershell
flutter run --dart-define=API_BASE_URL=http://<your-ip>:4000
```
